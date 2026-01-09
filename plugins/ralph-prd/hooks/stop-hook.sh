#!/bin/bash

# Ralph PRD Loop Stop Hook
# Prevents session exit when a ralph-prd-loop is active
# Checks prd.json for incomplete stories and feeds prompt back

set -euo pipefail

# Event logging for external monitoring
EVENT_LOG=".claude/ralph-prd-events.jsonl"

emit_event() {
  local event="$1"
  shift
  local data="$*"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Create event JSON and append to log
  echo "{\"event\":\"$event\",\"timestamp\":\"$timestamp\",$data}" >> "$EVENT_LOG"
}

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if ralph-prd-loop is active (JSON format)
RALPH_STATE_FILE=".claude/ralph-prd-loop.local.json"

# Backward compatibility: Check for old .md format and migrate
OLD_STATE_FILE=".claude/ralph-prd-loop.local.md"
if [[ -f "$OLD_STATE_FILE" ]] && [[ ! -f "$RALPH_STATE_FILE" ]]; then
  echo "⚠️  Migrating state file to JSON format..." >&2
  # Run migration script if available
  if [[ -x "$(dirname "$0")/../scripts/migrate-state-to-json.sh" ]]; then
    "$(dirname "$0")/../scripts/migrate-state-to-json.sh"
  else
    echo "⚠️  Migration script not found. Please run manually:" >&2
    echo "   ./scripts/migrate-state-to-json.sh" >&2
    exit 0
  fi
fi

# Verify file exists and is not a symlink (prevent path traversal)
if [[ ! -f "$RALPH_STATE_FILE" ]] || [[ -L "$RALPH_STATE_FILE" ]]; then
  # No active loop or symlink detected - allow exit
  if [[ -L "$RALPH_STATE_FILE" ]]; then
    echo "⚠️  Ralph PRD loop: State file is a symlink (security risk)" >&2
    echo "   File: $RALPH_STATE_FILE" >&2
    rm -f "$RALPH_STATE_FILE"
  fi
  exit 0
fi

# Verify the resolved path is within expected directory
RESOLVED_STATE_FILE=$(realpath "$RALPH_STATE_FILE" 2>/dev/null)
EXPECTED_DIR=$(realpath ".claude" 2>/dev/null)
if [[ ! "$RESOLVED_STATE_FILE" == "$EXPECTED_DIR"/* ]]; then
  echo "⚠️  Ralph PRD loop: State file path traversal detected" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Resolved: $RESOLVED_STATE_FILE" >&2
  rm -f "$RALPH_STATE_FILE"
  exit 0
fi

# Parse JSON state file using jq
if ! ITERATION=$(jq -r '.iteration' "$RALPH_STATE_FILE" 2>/dev/null); then
  echo "⚠️  Ralph PRD loop: Failed to parse state file" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Ensure it's valid JSON format" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

MAX_ITERATIONS=$(jq -r '.maxIterations' "$RALPH_STATE_FILE")
COMPLETION_PROMISE=$(jq -r '.completionPromise // "null"' "$RALPH_STATE_FILE")

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph PRD loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Ralph loop is stopping. Run /ralph-prd-loop again to start fresh." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph PRD loop: State file corrupted" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Ralph loop is stopping. Run /ralph-prd-loop again to start fresh." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  emit_event "loop_stopped" "\"reason\":\"max_iterations\",\"iteration\":$ITERATION,\"maxIterations\":$MAX_ITERATIONS"
  echo "🛑 Ralph PRD loop: Max iterations ($MAX_ITERATIONS) reached."
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input with validation
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

# Validate transcript path to prevent command injection
if [[ ! "$TRANSCRIPT_PATH" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
  echo "⚠️  Ralph PRD loop: Invalid transcript path format" >&2
  echo "   Path contains unsafe characters" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Resolve to absolute path and verify it exists as a regular file
if ! TRANSCRIPT_PATH=$(realpath "$TRANSCRIPT_PATH" 2>/dev/null) || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph PRD loop: Transcript file not found or not accessible" >&2
  echo "   This is unusual and may indicate a Claude Code internal issue." >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format - one JSON per line)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Ralph PRD loop: No assistant messages found in transcript" >&2
  echo "   Transcript: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a transcript format issue" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Extract last assistant message with explicit error handling
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "⚠️  Ralph PRD loop: Failed to extract last assistant message" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Parse JSON with error handling
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)

# Check if jq succeeded
if [[ $? -ne 0 ]]; then
  echo "⚠️  Ralph PRD loop: Failed to parse assistant message JSON" >&2
  echo "   Error: $LAST_OUTPUT" >&2
  echo "   This may indicate a transcript format issue" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "⚠️  Ralph PRD loop: Assistant message contained no text content" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using grep/sed (safe, no code execution)
  # First extract lines containing promise tags, then extract content
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | grep -o '<promise>[^<]*</promise>' | sed 's/<promise>\(.*\)<\/promise>/\1/' | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' ' || echo "")

  # Use = for literal string comparison
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    emit_event "loop_stopped" "\"reason\":\"completion_promise\",\"iteration\":$ITERATION,\"promise\":\"$COMPLETION_PROMISE\""
    echo "✅ Ralph PRD loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi
fi

# Check prd.json for incomplete stories
PRD_FILE="prd.json"

if [[ ! -f "$PRD_FILE" ]]; then
  echo "⚠️  Ralph PRD loop: prd.json not found" >&2
  echo "   Expected: $PRD_FILE in current directory" >&2
  echo "   Did you run /prd-convert first?" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if there are any stories with passes: false
INCOMPLETE_STORIES=$(jq -r '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>&1)

if [[ $? -ne 0 ]]; then
  echo "⚠️  Ralph PRD loop: Failed to parse prd.json" >&2
  echo "   Error: $INCOMPLETE_STORIES" >&2
  echo "   Check that prd.json is valid JSON" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# If all stories are complete, stop the loop
if [[ "$INCOMPLETE_STORIES" -eq 0 ]]; then
  emit_event "loop_stopped" "\"reason\":\"all_complete\",\"iteration\":$ITERATION"
  echo "✅ Ralph PRD loop: All user stories completed (passes: true)"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt from JSON
PROMPT_TEXT=$(jq -r '.prompt' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]] || [[ "$PROMPT_TEXT" == "null" ]]; then
  echo "⚠️  Ralph PRD loop: State file corrupted or incomplete" >&2
  echo "   File: $RALPH_STATE_FILE" >&2
  echo "   Problem: No prompt text found" >&2
  echo "   Ralph loop is stopping. Run /ralph-prd-loop again to start fresh." >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in JSON using secure temp file
TEMP_FILE=$(mktemp "${RALPH_STATE_FILE}.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT

jq --arg nextIter "$NEXT_ITERATION" '.iteration = ($nextIter | tonumber)' "$RALPH_STATE_FILE" > "$TEMP_FILE"
chmod 600 "$TEMP_FILE"  # Ensure restrictive permissions
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Get next story info for status message
NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first | "\(.id): \(.title)"' "$PRD_FILE" 2>/dev/null || echo "unknown")
NEXT_STORY_ID=$(echo "$NEXT_STORY" | cut -d: -f1)

# Emit iteration event
emit_event "iteration_started" "\"iteration\":$NEXT_ITERATION,\"incompleteStories\":$INCOMPLETE_STORIES,\"nextStory\":\"$NEXT_STORY_ID\""

# Build system message with iteration count, completion promise, and story info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph PRD iteration $NEXT_ITERATION | $INCOMPLETE_STORIES stories remaining | Next: $NEXT_STORY | To stop: <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE!)"
else
  SYSTEM_MSG="🔄 Ralph PRD iteration $NEXT_ITERATION | $INCOMPLETE_STORIES stories remaining | Next: $NEXT_STORY"
fi

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0

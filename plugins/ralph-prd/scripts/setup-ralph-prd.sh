#!/bin/bash

# Ralph PRD Loop Setup Script
# Creates state file for in-session Ralph PRD loop

set -euo pipefail

# Parse arguments
MAX_ITERATIONS=0

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph PRD Loop - Autonomous agent for completing user stories

USAGE:
  /ralph-prd-loop [OPTIONS]

OPTIONS:
  --max-iterations <n>    Maximum iterations before auto-stop (default: unlimited)
  -h, --help              Show this help message

DESCRIPTION:
  Starts a Ralph PRD Loop coordinator that spawns FRESH Task agents per story.

  YOU ARE A COORDINATOR - you spawn Task agents, you do NOT implement code yourself.
  Each story gets a fresh Claude instance with ~150k token context window.

  This prevents context exhaustion on large features.

REQUIREMENTS:
  - prd.json must exist in the current directory
  - Run /prd-convert first to create prd.json from a markdown PRD
  - Optional: Create progress.txt and AGENTS.md for learnings

EXAMPLES:
  /ralph-prd-loop
  /ralph-prd-loop --max-iterations 20

STOPPING:
  The loop stops when:
  - All stories in prd.json have passes: true
  - Max iterations is reached (if set)
  - A Task agent fails (coordinator stops and reports error)

MONITORING:
  # Check PRD status:
  jq '.userStories[] | {id, title, passes}' prd.json

  # View events:
  tail -f .claude/ralph-prd-events.jsonl

  # View progress:
  tail -20 progress.jsonl
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    *)
      echo "❌ Error: Unknown option: $1" >&2
      echo "   Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Validate prd.json exists
PRD_FILE="prd.json"
if [[ ! -f "$PRD_FILE" ]]; then
  echo "❌ Error: prd.json not found in current directory" >&2
  echo "" >&2
  echo "   Ralph PRD loop requires a prd.json file to work." >&2
  echo "" >&2
  echo "   Steps to create prd.json:" >&2
  echo "     1. Create a markdown PRD:" >&2
  echo "        /prd-create \"your feature description\"" >&2
  echo "     2. Convert it to JSON:" >&2
  echo "        /prd-convert tasks/prd-your-feature.md" >&2
  echo "" >&2
  echo "   Or manually create prd.json with this structure:" >&2
  echo "   {" >&2
  echo "     \"project\": \"MyProject\"," >&2
  echo "     \"branchName\": \"ralph/feature-name\"," >&2
  echo "     \"description\": \"Feature description\"," >&2
  echo "     \"userStories\": [...]" >&2
  echo "   }" >&2
  exit 1
fi

# Validate prd.json is valid JSON
if ! jq empty "$PRD_FILE" 2>/dev/null; then
  echo "❌ Error: prd.json is not valid JSON" >&2
  echo "" >&2
  echo "   Check the file for syntax errors:" >&2
  echo "     jq . prd.json" >&2
  exit 1
fi

# Validate prd.json has required fields
if ! jq -e '.userStories' "$PRD_FILE" >/dev/null 2>&1; then
  echo "❌ Error: prd.json is missing 'userStories' field" >&2
  echo "" >&2
  echo "   Expected structure:" >&2
  echo "   {" >&2
  echo "     \"project\": \"...\","  >&2
  echo "     \"branchName\": \"...\","  >&2
  echo "     \"description\": \"...\","  >&2
  echo "     \"userStories\": [" >&2
  echo "       { \"id\": \"US-001\", \"title\": \"...\", \"passes\": false, ... }" >&2
  echo "     ]" >&2
  echo "   }" >&2
  exit 1
fi

# Count total and incomplete stories
TOTAL_STORIES=$(jq -r '.userStories | length' "$PRD_FILE")
INCOMPLETE_STORIES=$(jq -r '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")

if [[ "$TOTAL_STORIES" -eq 0 ]]; then
  echo "❌ Error: prd.json has no user stories" >&2
  echo "" >&2
  echo "   Add at least one user story to prd.json" >&2
  exit 1
fi

if [[ "$INCOMPLETE_STORIES" -eq 0 ]]; then
  echo "✅ All user stories already complete!" >&2
  echo "" >&2
  echo "   All $TOTAL_STORIES stories in prd.json have passes: true" >&2
  echo "   No work needed. Create a new prd.json for a different feature." >&2
  exit 0
fi

# Initialize progress.txt if it doesn't exist
if [[ ! -f "progress.txt" ]]; then
  cat > progress.txt <<EOF
# Ralph Progress Log
Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Codebase Patterns
(Add reusable patterns here as you discover them)

---
EOF
  echo "📝 Created progress.txt for tracking learnings"
fi

# Initialize event log
mkdir -p .claude
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EVENT_LOG=".claude/ralph-prd-events.jsonl"
echo "{\"event\":\"loop_started\",\"timestamp\":\"$STARTED_AT\",\"maxIterations\":$MAX_ITERATIONS,\"totalStories\":$TOTAL_STORIES,\"incompleteStories\":$INCOMPLETE_STORIES,\"prdFile\":\"$PRD_FILE\"}" > "$EVENT_LOG"

# Output setup message
PROJECT_NAME=$(jq -r '.project // "Unknown"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$PRD_FILE")

cat <<EOF
🚀 Ralph PRD Loop - Coordinator Mode Initialized

Project: $PROJECT_NAME
Branch: $BRANCH_NAME
Total stories: $TOTAL_STORIES
Incomplete stories: $INCOMPLETE_STORIES
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)

🆕 NEW ARCHITECTURE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
You are now a COORDINATOR. You will:
1. Read prd.json to find incomplete stories
2. Spawn Task agents (one per story)
3. Each Task agent gets FRESH CONTEXT (~150k tokens)
4. Monitor progress and handle failures

🎯 Key difference from old version:
- OLD: Single session, context accumulates → context exhaustion
- NEW: Fresh Task agent per story → no accumulation → unlimited stories

To monitor progress:
  scripts/check-stories.sh
  scripts/view-progress.sh
  scripts/monitor-events.sh

⚠️  WARNING: This loop will run until all stories are complete or max-iterations
    is reached. Each iteration spawns a FRESH Task agent for ONE story.

═══════════════════════════════════════════════════════════
Next Steps (for coordinator):
1. Verify branch: $BRANCH_NAME
2. Read prd.json to find next incomplete story
3. Spawn Task agent with implement-story.md instructions
4. Wait for Task agent to complete
5. Check if story.passes == true
6. If yes: Continue to next story
7. If no: Report failure and stop
7. Loop continues automatically...
═══════════════════════════════════════════════════════════
EOF

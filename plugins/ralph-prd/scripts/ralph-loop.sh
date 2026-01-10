#!/bin/bash
# Ralph PRD Loop - Bash wrapper that spawns fresh Claude CLI instances per story
# Usage: ./ralph-loop.sh [prd-file] [max-iterations]

set -euo pipefail

# Configuration
PRD_FILE="${1:-prd.json}"
MAX_ITERATIONS="${2:-50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_FILE="$PLUGIN_DIR/prompts/implement-story.md"
EVENTS_LOG=".claude/ralph-prd-events.jsonl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validate inputs
if [ ! -f "$PRD_FILE" ]; then
  echo -e "${RED}❌ Error: PRD file not found: $PRD_FILE${NC}"
  echo "Run this script from your project root where prd.json exists."
  exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}❌ Error: Prompt file not found: $PROMPT_FILE${NC}"
  echo "Expected at: $PROMPT_FILE"
  exit 1
fi

# Validate prd.json is valid JSON
if ! jq empty "$PRD_FILE" 2>/dev/null; then
  echo -e "${RED}❌ Error: $PRD_FILE is not valid JSON${NC}"
  exit 1
fi

# Check if userStories exists
if [ "$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null)" == "0" ]; then
  echo -e "${RED}❌ Error: No user stories found in $PRD_FILE${NC}"
  exit 1
fi

# Initialize
mkdir -p .claude
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"timestamp\":\"$STARTED_AT\",\"event\":\"loop_started\",\"maxIterations\":$MAX_ITERATIONS,\"prdFile\":\"$PRD_FILE\"}" >> "$EVENTS_LOG"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ralph PRD Loop - Autonomous Story Implementation        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}PRD File:${NC} $PRD_FILE"
echo -e "${BLUE}Max Iterations:${NC} $MAX_ITERATIONS"
echo -e "${BLUE}Events Log:${NC} $EVENTS_LOG"
echo ""

# Get branch name
BRANCH=$(jq -r '.branchName // "main"' "$PRD_FILE")
echo -e "${BLUE}Branch:${NC} $BRANCH"

# Check if on correct branch (informational only)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo -e "${YELLOW}⚠️  Note: Currently on branch '$CURRENT_BRANCH', PRD specifies '$BRANCH'${NC}"
  echo -e "${YELLOW}   Claude will check out the correct branch during implementation.${NC}"
fi

echo ""
echo -e "${GREEN}Starting implementation loop...${NC}"
echo ""

# Main loop
ITERATION=0
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))

  # Check if all stories complete
  INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
  if [ "$INCOMPLETE" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ All stories completed successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"loop_completed\",\"iterations\":$ITERATION}" >> "$EVENTS_LOG"
    exit 0
  fi

  # Find next story
  STORY_ID=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first | .id' "$PRD_FILE")
  STORY_TITLE=$(jq -r "[.userStories[] | select(.id == \"$STORY_ID\")][0] | .title" "$PRD_FILE")
  STORY_PRIORITY=$(jq -r "[.userStories[] | select(.id == \"$STORY_ID\")][0] | .priority" "$PRD_FILE")

  if [ "$STORY_ID" = "null" ] || [ -z "$STORY_ID" ]; then
    echo -e "${RED}❌ Error: Could not find next incomplete story${NC}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"loop_error\",\"reason\":\"no_incomplete_story\"}" >> "$EVENTS_LOG"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Iteration $ITERATION of $MAX_ITERATIONS${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}📝 Story:${NC} $STORY_ID (Priority: $STORY_PRIORITY)"
  echo -e "${YELLOW}   Title:${NC} $STORY_TITLE"
  echo -e "${YELLOW}   Remaining:${NC} $INCOMPLETE stories"
  echo ""

  # Log story start
  echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"story_started\",\"storyId\":\"$STORY_ID\",\"title\":\"$STORY_TITLE\",\"iteration\":$ITERATION}" >> "$EVENTS_LOG"

  # Spawn fresh Claude CLI instance
  echo -e "${BLUE}🚀 Spawning fresh Claude CLI instance...${NC}"
  echo ""

  # Claude CLI invocation with security restrictions
  # --print: Non-interactive mode, exits after response
  # --add-dir: Restrict access to current directory only (security)
  # --allowed-tools: Whitelist only necessary tools (security)
  # --permission-mode acceptEdits: Auto-accept edits without prompts
  # --chrome: Enable Chrome extension for browser testing
  # --system-prompt: Load instructions from file

  # Run Claude and capture output to log file
  STORY_LOG=".claude/story-$STORY_ID-$(date +%s).log"

  if claude --print \
    --add-dir "$(pwd)" \
    --allowed-tools "Read,Write,Edit,MultiEdit,Glob,Grep,Bash(git:*),Bash(npm:*),Bash(npx:*),Bash(node:*),Bash(jq:*),Bash(date:*),Bash(echo:*),Bash(cat:*),Bash(mkdir:*),Bash(touch:*),Bash(chmod:*),Bash(mv:*),Bash(cp:*),Bash(ls:*),Bash(find:*),Bash(grep:*),Bash(sed:*),Bash(awk:*),Bash(tsc:*),Bash(eslint:*),Bash(prettier:*),TodoWrite,Task,mcp__plugin_compound-engineering_pw__*" \
    --permission-mode acceptEdits \
    --chrome \
    --system-prompt "$(cat "$PROMPT_FILE")" \
    "Implement story $STORY_ID from $PRD_FILE" > "$STORY_LOG" 2>&1; then

    echo ""
    echo -e "${GREEN}✅ Claude CLI completed successfully${NC}"
    echo -e "${GREEN}   Log saved to: $STORY_LOG${NC}"

  else
    EXIT_CODE=$?
    echo ""
    echo -e "${RED}❌ Claude CLI exited with error (code: $EXIT_CODE)${NC}"
    echo -e "${RED}   Check log: $STORY_LOG${NC}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"story_failed\",\"storyId\":\"$STORY_ID\",\"reason\":\"claude_exit_error\",\"exitCode\":$EXIT_CODE}" >> "$EVENTS_LOG"

    # Check if story was still marked complete despite error
    PASSES=$(jq -r "[.userStories[] | select(.id == \"$STORY_ID\")][0] | .passes" "$PRD_FILE")
    if [ "$PASSES" = "true" ]; then
      echo -e "${YELLOW}⚠️  Note: Story was marked complete despite error${NC}"
      echo -e "${GREEN}   Continuing to next story...${NC}"
      continue
    else
      echo -e "${RED}   Story failed. Loop stopped.${NC}"
      exit 1
    fi
  fi

  # Verify story was marked complete
  PASSES=$(jq -r "[.userStories[] | select(.id == \"$STORY_ID\")][0] | .passes" "$PRD_FILE")

  if [ "$PASSES" = "true" ]; then
    echo -e "${GREEN}✅ Story $STORY_ID marked complete in prd.json${NC}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"story_completed\",\"storyId\":\"$STORY_ID\",\"iteration\":$ITERATION}" >> "$EVENTS_LOG"
  else
    echo -e "${RED}❌ Story $STORY_ID not marked complete (passes still false)${NC}"
    echo -e "${RED}   This means the story failed quality checks or implementation.${NC}"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"story_failed\",\"storyId\":\"$STORY_ID\",\"reason\":\"not_marked_complete\"}" >> "$EVENTS_LOG"

    echo ""
    echo -e "${YELLOW}To recover:${NC}"
    echo "  1. Check what went wrong: git log, git diff"
    echo "  2. Fix the issue manually or simplify the story in prd.json"
    echo "  3. Run ralph-loop.sh again to continue"
    echo ""
    exit 1
  fi

  # Brief pause between iterations
  sleep 1
done

# Max iterations reached
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚠️  Max iterations ($MAX_ITERATIONS) reached${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
echo -e "${YELLOW}Remaining stories:${NC} $REMAINING"
echo ""
echo "To continue: Run ./ralph-loop.sh again"
echo ""
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"loop_stopped\",\"reason\":\"max_iterations\",\"remainingStories\":$REMAINING}" >> "$EVENTS_LOG"
exit 1

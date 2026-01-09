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
  Starts a Ralph PRD Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until all user stories in prd.json
  have passes: true, or the iteration limit is reached.

  To signal completion, output: <promise>ALL_STORIES_COMPLETE</promise>
  (This happens automatically when all stories are complete)

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
  - You output <promise>ALL_STORIES_COMPLETE</promise>

MONITORING:
  # View current iteration and remaining stories:
  head -10 .claude/ralph-prd-loop.local.md

  # Check PRD status:
  jq '.userStories[] | {id, title, passes}' prd.json

  # View progress:
  tail -20 progress.txt
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

# Create state file for stop hook (markdown with YAML frontmatter)
mkdir -p .claude

COMPLETION_PROMISE="ALL_STORIES_COMPLETE"

cat > .claude/ralph-prd-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: "$COMPLETION_PROMISE"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
prd_file: "$PRD_FILE"
---

You are now in Ralph PRD loop. Follow the instructions in the command output.
EOF

# Output setup message
PROJECT_NAME=$(jq -r '.project // "Unknown"' "$PRD_FILE")
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$PRD_FILE")

cat <<EOF
🔄 Ralph PRD loop activated!

Project: $PROJECT_NAME
Branch: $BRANCH_NAME
Total stories: $TOTAL_STORIES
Incomplete stories: $INCOMPLETE_STORIES
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)

The stop hook is now active. When you try to exit, the loop will:
1. Check if all stories have passes: true
2. If not, feed the same prompt back to you
3. You'll see your previous work in files and git history
4. Iterate on the next story with passes: false

To monitor progress:
  jq '.userStories[] | {id, title, passes}' prd.json
  tail -20 progress.txt
  head -10 .claude/ralph-prd-loop.local.md

⚠️  WARNING: This loop will run until all stories are complete or max-iterations
    is reached. Each iteration works on ONE story at a time.

═══════════════════════════════════════════════════════════
Next Steps:
1. Check your current git branch matches: $BRANCH_NAME
2. Read prd.json to understand all user stories
3. Pick the highest priority story with passes: false
4. Implement it, test it, commit it
5. Update that story's passes field to true in prd.json
6. Append progress to progress.txt
7. Loop continues automatically...
═══════════════════════════════════════════════════════════
EOF

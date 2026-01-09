#!/bin/bash

# Ralph PRD Story Status Checker
# Utility to check status of user stories in prd.json
# Usage: ./check-stories.sh [prd.json] [--json]

set -euo pipefail

# Parse arguments
JSON_OUTPUT=false
PRD_FILE="prd.json"

for arg in "$@"; do
  case $arg in
    --json)
      JSON_OUTPUT=true
      ;;
    *)
      PRD_FILE="$arg"
      ;;
  esac
done

if [[ ! -f "$PRD_FILE" ]]; then
  echo "❌ Error: $PRD_FILE not found" >&2
  exit 1
fi

if ! jq empty "$PRD_FILE" 2>/dev/null; then
  echo "❌ Error: $PRD_FILE is not valid JSON" >&2
  exit 1
fi

# Count stories
TOTAL=$(jq -r '.userStories | length' "$PRD_FILE")
COMPLETE=$(jq -r '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
INCOMPLETE=$(jq -r '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")

# JSON output for machine consumption
if [[ "$JSON_OUTPUT" == "true" ]]; then
  jq -n \
    --arg total "$TOTAL" \
    --arg complete "$COMPLETE" \
    --arg incomplete "$INCOMPLETE" \
    --argjson stories "$(jq '.userStories' "$PRD_FILE")" \
    --argjson nextStory "$(jq '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first // null' "$PRD_FILE")" \
    '{
      total: ($total | tonumber),
      complete: ($complete | tonumber),
      incomplete: ($incomplete | tonumber),
      stories: $stories,
      nextStory: $nextStory
    }'
  exit 0
fi

# Human-readable output
echo "📊 PRD Story Status"
echo "───────────────────"
echo "Total:      $TOTAL"
echo "Complete:   $COMPLETE ✓"
echo "Incomplete: $INCOMPLETE"
echo ""

# Display all stories with status
echo "📝 User Stories:"
echo ""

jq -r '.userStories[] |
  if .passes then
    "  ✓ \(.id): \(.title) [DONE]"
  else
    "  ○ \(.id): \(.title) [TODO - Priority \(.priority)]"
  end
' "$PRD_FILE"

echo ""

# Show next story to work on
if [[ $INCOMPLETE -gt 0 ]]; then
  NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first | "  → \(.id): \(.title)"' "$PRD_FILE")
  echo "🎯 Next Story:"
  echo "$NEXT_STORY"
else
  echo "🎉 All stories complete!"
fi

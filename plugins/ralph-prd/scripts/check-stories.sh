#!/bin/bash

# Ralph PRD Story Status Checker
# Utility to check status of user stories in prd.json

set -euo pipefail

PRD_FILE="${1:-prd.json}"

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

# Display summary
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

#!/bin/bash

# View Ralph PRD progress in human-readable format
# Usage: ./scripts/view-progress.sh [progress.jsonl]

set -euo pipefail

PROGRESS_FILE="${1:-progress.jsonl}"

if [[ ! -f "$PROGRESS_FILE" ]]; then
  echo "No progress file found: $PROGRESS_FILE"
  exit 1
fi

echo "Ralph PRD Progress Report"
echo "========================="
echo ""

# Summary stats
TOTAL_STORIES=$(jq -s '[.[] | select(.action == "completed")] | unique_by(.storyId) | length' "$PROGRESS_FILE")
TOTAL_TIME=$(jq -s '[.[] | select(.durationMinutes) | .durationMinutes] | add // 0' "$PROGRESS_FILE")
ITERATIONS=$(jq -s '[.[] | .iteration] | max // 0' "$PROGRESS_FILE")

echo "Total Stories Completed: $TOTAL_STORIES"
echo "Total Time: ${TOTAL_TIME} minutes"
echo "Latest Iteration: $ITERATIONS"
echo ""
echo "========================="
echo ""

# Detailed entries
jq -r '
  "## \(.timestamp) - \(.storyId) (\(.action))",
  "Iteration: \(.iteration)",
  "Summary: \(.summary)",
  "Files: \(.filesChanged | join(", "))",
  (if .durationMinutes then "Duration: \(.durationMinutes) min" else "" end),
  "",
  "Learnings:",
  (.learnings | map("  - \(.)") | join("\n")),
  "",
  "---",
  ""
' "$PROGRESS_FILE"

# Consolidated learnings
echo ""
echo "========================="
echo "All Learnings (Consolidated)"
echo "========================="
echo ""

jq -r '.learnings[]' "$PROGRESS_FILE" | sort -u | sed 's/^/- /'

#!/bin/bash

# Monitor Ralph PRD events in real-time
# Usage: ./scripts/monitor-events.sh [events.jsonl]

set -euo pipefail

EVENT_LOG="${1:-.claude/ralph-prd-events.jsonl}"

if [[ ! -f "$EVENT_LOG" ]]; then
  echo "⚠️  No event log found: $EVENT_LOG"
  echo "   Start a Ralph PRD loop to create it"
  exit 1
fi

echo "📡 Monitoring Ralph PRD events..."
echo "   Event log: $EVENT_LOG"
echo "   Press Ctrl+C to stop"
echo ""

# Display existing events first
if [[ -s "$EVENT_LOG" ]]; then
  echo "=== Existing Events ==="
  jq -r '"\(.timestamp) [\(.event)] \(. | del(.event, .timestamp) | to_entries | map("\(.key)=\(.value)") | join(" "))"' "$EVENT_LOG"
  echo ""
fi

echo "=== Live Events ==="

# Tail and format new events
tail -f "$EVENT_LOG" | while read -r line; do
  echo "$line" | jq -r '
    if .event == "loop_started" then
      "🚀 Loop started | stories=\(.totalStories) incomplete=\(.incompleteStories) max=\(.maxIterations)"
    elif .event == "iteration_started" then
      "🔄 Iteration \(.iteration) | incomplete=\(.incompleteStories) next=\(.nextStory)"
    elif .event == "loop_stopped" then
      if .reason == "all_complete" then
        "✅ Loop stopped | All stories complete! | iterations=\(.iteration)"
      elif .reason == "max_iterations" then
        "🛑 Loop stopped | Max iterations reached | \(.iteration)/\(.maxIterations)"
      elif .reason == "completion_promise" then
        "✅ Loop stopped | Promise fulfilled: \(.promise)"
      else
        "🛑 Loop stopped | reason=\(.reason)"
      end
    else
      "\(.timestamp) [\(.event)] \(. | del(.event, .timestamp) | to_entries | map("\(.key)=\(.value)") | join(" "))"
    end
  '
done

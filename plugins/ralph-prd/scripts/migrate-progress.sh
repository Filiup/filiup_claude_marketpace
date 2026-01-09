#!/bin/bash

# Migrate old progress.txt to progress.jsonl format
# Usage: ./scripts/migrate-progress.sh [progress.txt] [output.jsonl]

set -euo pipefail

INPUT_FILE="${1:-progress.txt}"
OUTPUT_FILE="${2:-progress.jsonl}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE"
  exit 1
fi

if [[ -f "$OUTPUT_FILE" ]]; then
  echo "Output file already exists: $OUTPUT_FILE"
  echo "Backup or remove it first to proceed"
  exit 1
fi

echo "Migrating $INPUT_FILE to $OUTPUT_FILE..."
echo ""
echo "⚠️  Note: This is a best-effort migration. Some fields may be incomplete."
echo "   You may need to manually edit the JSONL file to add missing data."
echo ""

# Parse markdown format and convert to JSONL
# Format: ## [Date/Time] - [Story ID]
#         - What was implemented
#         - Files changed
#         - **Learnings for future iterations:**
#           - Learning 1
#           - Learning 2
#         ---

awk '
BEGIN {
  entry_count = 0
  in_entry = 0
  story_id = ""
  timestamp = ""
  summary = ""
  files = ""
  learnings = ""
  in_learnings = 0
}

# Match entry header: ## [Date/Time] - [Story ID]
/^## / {
  # Output previous entry if exists
  if (in_entry == 1 && story_id != "") {
    print_entry()
  }

  in_entry = 1
  in_learnings = 0
  entry_count++

  # Extract story ID and timestamp
  line = substr($0, 4)  # Remove "## "
  split(line, parts, " - ")
  timestamp = parts[1]
  story_id = parts[2]

  # Convert timestamp to ISO format (rough approximation)
  gsub(/\//, "-", timestamp)
  if (timestamp !~ /T/) {
    timestamp = timestamp "T00:00:00Z"
  }

  summary = ""
  files = ""
  learnings = ""
  next
}

# Match separator
/^---$/ {
  if (in_entry == 1 && story_id != "") {
    print_entry()
  }
  in_entry = 0
  in_learnings = 0
  story_id = ""
  next
}

# Match learnings section
/\*\*Learnings for future iterations:\*\*/ {
  in_learnings = 1
  next
}

# Inside entry
in_entry == 1 {
  line = $0
  gsub(/^[[:space:]]*-[[:space:]]*/, "", line)  # Remove leading "- "

  if (in_learnings == 1 && line ~ /^[[:space:]]*-/) {
    # Learning item
    gsub(/^[[:space:]]*-[[:space:]]*/, "", line)
    if (learnings == "") {
      learnings = "\"" line "\""
    } else {
      learnings = learnings ",\"" line "\""
    }
  } else if (line ~ /Files? changed:/) {
    # Files line
    gsub(/Files? changed:[[:space:]]*/, "", line)
    gsub(/,/, "\",\"", line)
    files = "\"" line "\""
  } else if (line != "" && summary == "" && in_learnings == 0) {
    # First non-empty line is summary
    summary = line
  }
}

END {
  # Output last entry if exists
  if (in_entry == 1 && story_id != "") {
    print_entry()
  }

  print "Migrated " entry_count " entries" > "/dev/stderr"
}

function print_entry() {
  # Escape quotes in text fields
  gsub(/"/, "\\\"", summary)

  printf "{\"timestamp\":\"%s\",\"iteration\":%d,\"storyId\":\"%s\",\"action\":\"completed\",\"summary\":\"%s\",\"filesChanged\":[%s],\"learnings\":[%s]}\n",
    timestamp,
    entry_count,
    story_id,
    summary,
    (files == "" ? "" : files),
    (learnings == "" ? "" : learnings)
}
' "$INPUT_FILE" > "$OUTPUT_FILE"

echo ""
echo "✅ Migration complete!"
echo "   Input:  $INPUT_FILE"
echo "   Output: $OUTPUT_FILE"
echo ""
echo "View formatted output: ./scripts/view-progress.sh $OUTPUT_FILE"

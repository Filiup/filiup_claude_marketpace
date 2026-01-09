#!/bin/bash

# Migrate ralph-prd-loop.local.md (YAML frontmatter) to ralph-prd-loop.local.json
# This is a one-time migration for backward compatibility

set -euo pipefail

OLD_STATE_FILE=".claude/ralph-prd-loop.local.md"
NEW_STATE_FILE=".claude/ralph-prd-loop.local.json"

if [[ ! -f "$OLD_STATE_FILE" ]]; then
  echo "No old state file found: $OLD_STATE_FILE"
  echo "Nothing to migrate."
  exit 0
fi

if [[ -f "$NEW_STATE_FILE" ]]; then
  echo "⚠️  New state file already exists: $NEW_STATE_FILE"
  echo "   Remove it first to re-migrate, or backup the old file:"
  echo "   mv $OLD_STATE_FILE ${OLD_STATE_FILE}.backup"
  exit 1
fi

echo "Migrating state file to JSON format..."
echo "  From: $OLD_STATE_FILE"
echo "  To:   $NEW_STATE_FILE"
echo ""

# Parse YAML frontmatter and extract fields
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$OLD_STATE_FILE")

ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/')
PRD_FILE=$(echo "$FRONTMATTER" | grep '^prd_file:' | sed 's/prd_file: *//' | sed 's/^"\(.*\)"$/\1/')

# Extract prompt (everything after closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$OLD_STATE_FILE")

# Create JSON file
jq -n \
  --arg active "$ACTIVE" \
  --arg iteration "$ITERATION" \
  --arg maxIterations "$MAX_ITERATIONS" \
  --arg completionPromise "$COMPLETION_PROMISE" \
  --arg startedAt "$STARTED_AT" \
  --arg prdFile "$PRD_FILE" \
  --arg prompt "$PROMPT_TEXT" \
  '{
    active: ($active == "true"),
    iteration: ($iteration | tonumber),
    maxIterations: ($maxIterations | tonumber),
    completionPromise: $completionPromise,
    startedAt: $startedAt,
    prdFile: $prdFile,
    prompt: $prompt
  }' > "$NEW_STATE_FILE"

echo "✅ Migration complete!"
echo ""
echo "Backing up old file..."
mv "$OLD_STATE_FILE" "${OLD_STATE_FILE}.backup"
echo "  Backup: ${OLD_STATE_FILE}.backup"
echo ""
echo "New state file created: $NEW_STATE_FILE"
echo ""
echo "You can now use the JSON format. The stop hook will automatically use it."

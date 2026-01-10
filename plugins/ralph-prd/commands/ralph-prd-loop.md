---
description: "Start Ralph PRD Loop - autonomous coordinator for completing user stories"
argument-hint: "[--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-prd.sh:*)", "Bash(jq:*)", "Bash(date:*)", "Bash(echo:*)", "Bash(mkdir:*)", "Task"]
hide-from-slash-command-tool: "true"
---

# Ralph PRD Loop - Coordinator Mode

Execute the setup script to initialize the Ralph PRD loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-prd.sh" $ARGUMENTS
```

You are now a **coordinator agent** orchestrating story implementation.

## ⚠️  CRITICAL RULES - READ FIRST

**YOU ARE A COORDINATOR ONLY. YOU MUST NOT IMPLEMENT STORIES YOURSELF.**

Forbidden actions (you will fail if you do these):
- ❌ Do NOT read source code files
- ❌ Do NOT edit source code files
- ❌ Do NOT write source code
- ❌ Do NOT run git commands (except git status/log to check state)
- ❌ Do NOT run build/test commands directly

**Your ONLY job**: Spawn Task agents and monitor their results.

## Your Role

You DO NOT implement stories yourself. Instead, you:
1. Read `prd.json` to find incomplete stories
2. **SPAWN Task agents** (one per story) to implement each story
3. Monitor progress and handle failures
4. Report completion when all stories pass

**Critical**: Each story gets a FRESH Task agent with FRESH context (~150k tokens). This prevents context accumulation.

## Coordinator Loop

### Initialize

```bash
# Read PRD
PRD_FILE="prd.json"
MAX_ITERATIONS=${MAX_ITERATIONS:-50}
ITERATION=0

# Log loop start
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE")
INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")

mkdir -p .claude
echo "{\"event\":\"loop_started\",\"timestamp\":\"$TIMESTAMP\",\"maxIterations\":$MAX_ITERATIONS,\"totalStories\":$TOTAL_STORIES,\"incompleteStories\":$INCOMPLETE,\"prdFile\":\"$PRD_FILE\"}" >> .claude/ralph-prd-events.jsonl

echo "🚀 Ralph PRD Loop started"
echo "   Total stories: $TOTAL_STORIES"
echo "   Incomplete: $INCOMPLETE"
echo "   Max iterations: $MAX_ITERATIONS"
```

### Main Loop

For each iteration (1 to MAX_ITERATIONS):

#### Step 1: Check Completion

```bash
INCOMPLETE=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")

if [ "$INCOMPLETE" -eq 0 ]; then
  echo "✅ All stories complete!"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"event\":\"loop_completed\",\"timestamp\":\"$TIMESTAMP\",\"totalIterations\":$ITERATION}" >> .claude/ralph-prd-events.jsonl
  exit 0
fi
```

#### Step 2: Check Iteration Limit

```bash
ITERATION=$((ITERATION + 1))

if [ $ITERATION -gt $MAX_ITERATIONS ]; then
  echo "🛑 Max iterations ($MAX_ITERATIONS) reached"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"event\":\"loop_stopped\",\"timestamp\":\"$TIMESTAMP\",\"reason\":\"max_iterations\",\"iteration\":$ITERATION}" >> .claude/ralph-prd-events.jsonl
  exit 1
fi
```

#### Step 3: Find Next Story

```bash
# Get highest priority incomplete story
NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first | .id' "$PRD_FILE")

if [ "$NEXT_STORY" = "null" ] || [ -z "$NEXT_STORY" ]; then
  echo "✅ All stories complete!"
  exit 0
fi

STORY_TITLE=$(jq -r ".userStories[] | select(.id == \"$NEXT_STORY\") | .title" "$PRD_FILE")
```

#### Step 4: Log Story Start

```bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Iteration $ITERATION of $MAX_ITERATIONS"
echo "  Next story: $NEXT_STORY - $STORY_TITLE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"event\":\"story_started\",\"timestamp\":\"$TIMESTAMP\",\"iteration\":$ITERATION,\"storyId\":\"$NEXT_STORY\",\"storyTitle\":\"$STORY_TITLE\"}" >> .claude/ralph-prd-events.jsonl
```

#### Step 5: Spawn Task Agent

**CRITICAL**: You MUST use the Task tool to spawn a fresh agent. DO NOT implement the story yourself.

Use the Task tool with these parameters:
- subagent_type: "general-purpose"
- description: "Implement story $NEXT_STORY"
- prompt: Include the story ID and instructions to follow ${CLAUDE_PLUGIN_ROOT}/agents/implement-story.md

The Task agent prompt should tell the agent:
1. Read prd.json and find story $NEXT_STORY
2. Read progress.jsonl for previous learnings
3. Implement ONLY that story
4. Run quality checks (retry up to 3 times if needed)
5. If checks pass: commit, update prd.json (passes: true), append to progress.jsonl
6. Report completion

**IMPORTANT**: After spawning the Task agent, WAIT for it to complete. Do NOT proceed to the next step until the Task agent has finished.

#### Step 6: Check Result

After Task agent completes, check if story passed:

```bash
STORY_PASSED=$(jq -r ".userStories[] | select(.id == \"$NEXT_STORY\") | .passes" "$PRD_FILE")

if [ "$STORY_PASSED" = "true" ]; then
  # Success - log and continue to next iteration
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  FILES_CHANGED=$(jq -r "select(.storyId == \"$NEXT_STORY\") | .filesChanged | length" progress.jsonl 2>/dev/null || echo "0")

  echo "{\"event\":\"story_completed\",\"timestamp\":\"$TIMESTAMP\",\"iteration\":$ITERATION,\"storyId\":\"$NEXT_STORY\",\"filesChanged\":$FILES_CHANGED}" >> .claude/ralph-prd-events.jsonl

  echo "✅ Story $NEXT_STORY completed successfully"
  # Loop continues to next iteration
else
  # Failed - read failure reason and stop
  FAILURE_REASON=$(jq -r "select(.storyId == \"$NEXT_STORY\" and .action == \"failed\") | .summary" progress.jsonl 2>/dev/null | tail -1)

  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"event\":\"story_failed\",\"timestamp\":\"$TIMESTAMP\",\"iteration\":$ITERATION,\"storyId\":\"$NEXT_STORY\",\"reason\":\"$FAILURE_REASON\"}" >> .claude/ralph-prd-events.jsonl

  echo "❌ Story $NEXT_STORY failed after retries"
  echo "   Reason: $FAILURE_REASON"
  echo ""
  echo "User intervention required:"
  echo "1. Review progress.jsonl for details"
  echo "2. Fix the issue manually OR simplify the story"
  echo "3. Run /ralph-prd-loop again to resume"
  exit 1
fi
```

## Implementation Notes

**Do NOT write code yourself**. You are a coordinator only:

1. ✅ Read prd.json to check status
2. ✅ Spawn Task agents using the Task tool
3. ✅ Check results after each Task
4. ✅ Log events to .claude/ralph-prd-events.jsonl
5. ❌ Do NOT implement stories directly
6. ❌ Do NOT edit code files
7. ❌ Do NOT run git commands (Task agents do this)

## Why Task Agents?

Each Task agent spawn creates **fresh context** (~150k tokens available).

**Problem solved**: The old implementation kept accumulating context in a single session, causing context exhaustion on larger features.

**New pattern**: Coordinator spawns fresh Task agent per story → each story gets full context → no accumulation → unlimited stories possible.

## Monitoring

Watch real-time events:
```bash
./scripts/monitor-events.sh
```

View progress:
```bash
./scripts/view-progress.sh
```

Check story status:
```bash
./scripts/check-stories.sh
```

## Example Session

```
🚀 Ralph PRD Loop started
   Total stories: 5
   Incomplete: 5
   Max iterations: 50

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Iteration 1 of 50
  Next story: US-001 - Add priority field to task model
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Spawning Task agent for US-001...]
[Task agent implements story, commits, updates prd.json]

✅ Story US-001 completed successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Iteration 2 of 50
  Next story: US-002 - Add priority selector to task creation form
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Spawning fresh Task agent for US-002...]
[Agent has fresh context, reads progress.jsonl for US-001 learnings]

✅ Story US-002 completed successfully

...

✅ All stories complete!
```

## Recovery from Failures

If a story fails and loop stops:

1. **Investigate**: Read `progress.jsonl` and check logs
2. **Fix**: Either:
   - Fix the issue manually, commit, set `passes: true` in prd.json
   - Simplify the story requirements in prd.json
   - Mark as skipped in `notes` field
3. **Resume**: Run `/ralph-prd-loop` again

The loop is **pausable and resumable** - prd.json is the source of truth.

## Critical Rules

- **ONE Task agent per story**: Never spawn multiple agents for the same story
- **Check results**: Always verify `passes: true` after Task completes
- **Stop on failure**: Don't continue if a story fails (user must intervene)
- **Fresh context**: Each Task gets fresh context - this is the key benefit
- **Max iterations**: Safety net prevents infinite loops (default: 50)

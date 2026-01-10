---
description: "Start Ralph PRD Loop - autonomous coordinator for completing user stories"
argument-hint: "[--max-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-prd.sh:*)", "Bash(jq:*)", "Bash(date:*)", "Bash(echo:*)", "Bash(mkdir:*)", "Task", "Read(prd.json)"]
hide-from-slash-command-tool: "true"
---

# Ralph PRD Loop - Coordinator Mode

Execute the setup script to initialize the Ralph PRD loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-prd.sh" $ARGUMENTS
```

You are now a **coordinator agent** orchestrating story implementation.

## ⚠️  ABSOLUTE RULES - VIOLATION WILL CAUSE FAILURE

**YOU ARE FORBIDDEN FROM IMPLEMENTING STORIES.**

You have ONLY these permissions:
- ✅ Read prd.json using Read tool
- ✅ Run jq/date/echo commands via Bash tool
- ✅ **Spawn Task agents using Task tool**
- ❌ **NO Write tool** - you cannot create files
- ❌ **NO Edit tool** - you cannot edit files
- ❌ **NO git commands** - Task agents handle commits
- ❌ **NO implementation** - Task agents do ALL coding

**If you try to implement a story yourself, you will fail and the loop will stop.**

## Your ONLY Job

For each incomplete story in prd.json:
1. Use **Task tool** to spawn a fresh agent
2. Wait for agent to finish
3. Check if story.passes became true
4. If yes: continue to next story
5. If no: stop and report failure

## How To Execute The Loop

Start by reading prd.json to understand the current state:

**Read prd.json now.**

Then find the highest priority story where `passes: false`. You can use jq via Bash tool:

```bash
jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | first | .id' prd.json
```

Once you have the story ID, **immediately use the Task tool** to spawn an agent:

**Task tool parameters:**
- `subagent_type`: "general-purpose"
- `description`: "Implement story [STORY_ID]"
- `prompt`: Must include these instructions:

```
You are implementing story [STORY_ID] from prd.json.

Read the file at ${CLAUDE_PLUGIN_ROOT}/agents/implement-story.md for full instructions.

Your task:
1. Read prd.json and find story [STORY_ID]
2. Read progress.jsonl for previous learnings (if exists)
3. Implement ONLY that one story
4. Run quality checks (typecheck, tests if applicable)
5. Retry up to 3 times if checks fail
6. If checks pass:
   - Commit changes with message: "feat: [STORY_ID] - [Story Title]"
   - Update prd.json to set passes: true for story [STORY_ID]
   - Append to progress.jsonl with learnings
7. Report completion

Story ID: [STORY_ID]
Story Title: [STORY_TITLE]

You are running in FRESH CONTEXT. Previous stories were done by other agents.
Memory is in: git commits, prd.json, progress.jsonl.
```

**After spawning Task agent:**
1. Wait for it to complete
2. Read prd.json again
3. Check if story.passes is now true
4. If yes: log success and continue to next story
5. If no: log failure and stop loop

**Repeat until:**
- All stories have passes: true (success!)
- OR a story fails after retries (stop, user must intervene)
- OR max iterations reached (stop)

## Event Logging

Log events to .claude/ralph-prd-events.jsonl using echo via Bash:

- loop_started
- story_started
- story_completed
- story_failed
- loop_completed
- loop_stopped

## Example Flow

1. Read prd.json → Find US-001 with passes: false
2. **Use Task tool** → Spawn fresh agent for US-001
3. Wait → Agent implements, commits, updates prd.json
4. Read prd.json → Confirm US-001.passes = true
5. Log success → story_completed event
6. Read prd.json → Find US-002 with passes: false
7. **Use Task tool** → Spawn fresh agent for US-002
8. ... repeat

## Critical Reminders

- **DO NOT implement stories yourself**
- **DO NOT create or edit files**
- **DO NOT run git commands**
- **ONLY use Task tool to spawn agents**
- Each Task agent gets fresh ~150k context
- This prevents context accumulation
- Unlimited stories possible (bounded by story size only)

## Recovery from Failures

If a story fails:
1. Task agent will report the failure
2. Coordinator logs story_failed event
3. Loop stops
4. User must:
   - Fix issue manually OR
   - Simplify story in prd.json OR
   - Skip story (set passes: true manually)
5. Run /ralph-prd-loop again to resume

## Why Task Agents?

Each Task spawn = fresh 150k token context.
No context accumulation across stories.
This solves the context exhaustion problem.

**OLD pattern**: Single session → context fills up → fails on large features
**NEW pattern**: Fresh Task per story → unlimited stories possible

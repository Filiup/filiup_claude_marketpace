---
description: "Show help for Ralph PRD plugin"
hide-from-slash-command-tool: "true"
---

# Ralph PRD Plugin Help

Autonomous AI agent loop for completing PRs using structured PRD workflow.

## Quick Start

```bash
# 1. Create a PRD
/prd-create "Add task priority system"
# → Output: tasks/prd-task-priority.md

# 2. Convert to JSON
/prd-convert tasks/prd-task-priority.md
# → Output: prd.json

# 3. Start the loop
/ralph-prd-loop --max-iterations 20
# → Iterates through stories automatically
```

## Commands

### `/prd-create "DESCRIPTION"`
Generate a structured Product Requirements Document.
- Asks clarifying questions
- Creates markdown PRD in tasks/

### `/prd-convert PATH_TO_PRD.md`
Convert markdown PRD to prd.json format.
- Parses user stories
- Creates executable JSON with passes:true/false tracking
- Archives previous run if needed

### `/ralph-prd-loop [--max-iterations N]`
Start the autonomous implementation loop.
- Reads prd.json
- Picks highest priority story with passes:false
- Implements → tests → commits → updates status
- Loops until all stories complete

### `/cancel-ralph-prd`
Stop an active Ralph PRD loop.
- Removes loop state file
- Can resume later with /ralph-prd-loop

## Workflow

1. **Write PRD** - Describe what you want to build
2. **Convert to JSON** - Structure into implementable stories
3. **Run loop** - Claude autonomously implements each story
4. **Monitor** - Track progress in prd.json and progress.txt

## Monitoring

```bash
# Check story status
jq '.userStories[] | {id, title, passes}' prd.json

# View progress log
tail -20 progress.txt

# Check loop state
head -10 .claude/ralph-prd-loop.local.md

# Use utility script
./plugins/ralph-prd/scripts/check-stories.sh
```

## Files

- `prd.json` - User stories with pass/fail tracking
- `progress.txt` - Learnings and patterns from each iteration
- `AGENTS.md` - Directory-specific knowledge for future work
- `.claude/ralph-prd-loop.local.md` - Loop state (temporary)

## Story Guidelines

**Each story must complete in ONE iteration:**
- ✅ Add a database column
- ✅ Add a UI component
- ❌ "Build entire dashboard" (too big - split it!)

**Acceptance criteria must be verifiable:**
- ✅ "Add status column with default 'pending'"
- ❌ "Works correctly" (too vague)

## Stopping

Loop stops when:
- All stories have passes:true
- Max iterations reached (if set)
- Manual cancellation (/cancel-ralph-prd)

## Troubleshooting

**"prd.json not found"**
→ Run /prd-convert first

**"All stories already complete"**
→ All passes:true, create new feature

**Loop not stopping**
→ Check: `jq '[.userStories[] | select(.passes == false)]' prd.json`

**Commits failing**
→ Fix quality checks (typecheck, tests) and loop continues

## More Info

For detailed documentation, see:
- Plugin README: `plugins/ralph-prd/README.md`
- Setup script help: `/ralph-prd-loop --help`
- Original concept: https://github.com/snarktank/ralph

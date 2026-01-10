---
description: "Start Ralph PRD Loop - autonomous implementation of PRD stories"
argument-hint: "[max-iterations]"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "false"
---

# Ralph PRD Loop

Implements all incomplete user stories from prd.json by spawning fresh Claude CLI instances per story.

## How It Works

Ralph uses a **bash wrapper pattern** (inspired by [snarktank/ralph](https://github.com/snarktank/ralph)) that spawns fresh `claude --print` CLI processes per story:

```
Bash Wrapper (ralph-loop.sh)
  ├─> Find next incomplete story (jq query on prd.json)
  ├─> Spawn fresh Claude CLI process
  │   ├─ Load prompts/implement-story.md as system prompt
  │   ├─ Fresh context window (~150k tokens)
  │   ├─ Implement story
  │   ├─ Run quality checks (typecheck, tests)
  │   ├─ Commit if passing
  │   ├─ Update prd.json (passes: true)
  │   ├─ Append to progress.jsonl
  │   └─ Exit (context discarded)
  ├─> Verify result in prd.json
  └─> Loop to next story (spawn fresh Claude CLI)
```

**Key benefit**: Each story gets fresh ~150k token context. No context accumulation. Unlimited stories possible.

## Usage

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/ralph-loop.sh" prd.json $ARGUMENTS
```

**Arguments**:
- First arg: PRD file (default: prd.json)
- Second arg: Max iterations (default: 50)

**Example**:
```bash
/ralph-prd-loop          # Use prd.json, max 50 iterations
/ralph-prd-loop 20       # Use prd.json, max 20 iterations
```

## What Happens

1. **Bash wrapper reads prd.json**
   - Finds highest priority story where `passes: false`
   - Checks you're in git repo

2. **Spawns fresh Claude CLI**
   ```bash
   claude --print \
     --add-dir "$(pwd)" \
     --allowed-tools "Read,Write,Edit,Bash(git:*),Bash(npm:*),..." \
     --permission-mode acceptEdits \
     --chrome \
     --system-prompt "$(cat prompts/implement-story.md)" \
     "Implement story US-001 from prd.json"
   ```

3. **Claude implements story**
   - Reads prd.json to find assigned story
   - Reads progress.jsonl for previous learnings
   - Implements the story
   - Runs quality checks (max 3 retries)
   - Commits if passing
   - Updates prd.json + progress.jsonl
   - Exits

4. **Bash wrapper verifies**
   - Checks if story.passes = true in prd.json
   - If yes: continues to next story
   - If no: stops loop, reports failure

5. **Repeat until all complete**

## Security

The bash wrapper uses multiple security layers:

- `--add-dir "$(pwd)"` - Restricts file access to project directory only
- `--allowed-tools` - Whitelist only: Read, Write, Edit, git, npm, jq, browser tools
- `--permission-mode acceptEdits` - Auto-approve edits in project dir
- **Cannot access**: ~/Documents, ~/.ssh, system files
- **Cannot run**: rm, curl, wget, arbitrary bash commands

All changes are committed to git → easily reversible with `git reset --hard`.

## Progress Monitoring

### Check story status:
```bash
jq '.userStories[] | {id, title, passes}' prd.json
```

### View recent events:
```bash
tail -20 .claude/ralph-prd-events.jsonl
```

### Watch in real-time (separate terminal):
```bash
tail -f .claude/ralph-prd-events.jsonl
```

### Check progress learnings:
```bash
jq -r '.learnings[]?' progress.jsonl | sort -u
```

## How Fresh Context Works

**Each `claude --print` spawn = separate OS process = fresh ~150k token context.**

```
Iteration 1: Fresh Claude CLI process → US-001 → Implement + Commit → Exit (context discarded)
Iteration 2: Fresh Claude CLI process → US-002 → Implement + Commit → Exit (context discarded)
Iteration 3: Fresh Claude CLI process → US-003 → Implement + Commit → Exit (context discarded)
```

**No context accumulation** → Can handle 50+ story features.

**Memory preserved via:**
- **Git commits**: Code state (ground truth)
- **prd.json**: Story status (passes: true/false)
- **progress.jsonl**: Learnings from previous Claude instances

## Stopping the Loop

The loop stops when:
1. **All stories complete** - All passes: true in prd.json
2. **Story fails** - Claude instance couldn't complete story after retries
3. **Max iterations** - Safety limit reached (default: 50)
4. **User cancels** - Ctrl+C

To resume: Just run `/ralph-prd-loop` again - picks up where it left off.

## Recovery from Failures

If a story fails:
1. Claude reports the error (quality checks failed, etc.)
2. Bash wrapper logs story_failed event
3. Loop stops

**To recover:**
- Fix issue manually, commit, mark passes: true in prd.json OR
- Simplify story requirements in prd.json OR
- Skip story (set passes: true with note in story.notes)

Then run `/ralph-prd-loop` again to continue.

## Architecture Benefits

**Problem**: Single-session agents accumulate context over iterations → context exhaustion on large features

**Solution**: Bash wrapper spawns fresh Claude CLI processes per story

✅ Each story gets full ~150k token context
✅ No context accumulation across stories
✅ Can handle unlimited stories (limited only by story size, not count)
✅ Pausable/resumable (prd.json = state)
✅ Quality gates per story (typecheck, tests)
✅ Fresh process = true isolation (OS-level)

## Comparison to snarktank/ralph

| Aspect | snarktank/ralph | ralph-prd plugin |
|--------|----------------|------------------|
| Loop orchestrator | Bash script (ralph.sh) | Bash script (ralph-loop.sh) |
| Fresh instances | `amp --dangerously-allow-all` | `claude --print` with security flags |
| Story instructions | prompt.md | prompts/implement-story.md |
| State tracking | prd.json + progress.txt | prd.json + progress.jsonl |
| Memory preservation | Git + files | Git + files |
| Context per story | Fresh ~150k tokens | Fresh ~150k tokens |
| Scalability | Unlimited stories | Unlimited stories |

## Example Output

```
╔═══════════════════════════════════════════════════════════╗
║  Ralph PRD Loop - Autonomous Story Implementation        ║
╚═══════════════════════════════════════════════════════════╝

PRD File: prd.json
Max Iterations: 50
Branch: ralph/add-priority-system

Starting implementation loop...

═══════════════════════════════════════════════════════════
  Iteration 1 of 50
═══════════════════════════════════════════════════════════
📝 Story: US-001 (Priority: 1)
   Title: Add priority column to tasks table
   Remaining: 4 stories

🚀 Spawning fresh Claude CLI instance...

[Claude implements story, runs tests, commits]

✅ Claude CLI completed successfully
✅ Story US-001 marked complete in prd.json

═══════════════════════════════════════════════════════════
  Iteration 2 of 50
═══════════════════════════════════════════════════════════
📝 Story: US-002 (Priority: 2)
   Title: Display priority indicator on task cards
   Remaining: 3 stories

...
```

## Notes

- This command just invokes the bash wrapper
- Real loop logic is in scripts/ralph-loop.sh
- Each Claude CLI invocation is a separate OS process
- Bash wrapper has no LLM context (just orchestration)
- Architecture ensures no context exhaustion

# Ralph PRD Plugin

Autonomous AI agent loop for completing PRs using structured PRD workflow. Convert PRDs to JSON with user stories, track progress with `passes:true/false`, and iterate until completion.

## Overview

Ralph PRD implements the ["Ralph Wiggum" pattern](https://x.com/natfriedman/status/1808499369577234768) for autonomous AI development, adapted from [snarktank/ralph](https://github.com/snarktank/ralph) to work natively with Claude Code.

**How it works:**
1. You write a Product Requirements Document (PRD) describing your feature
2. Convert it to `prd.json` with structured user stories
3. Start the Ralph loop - coordinator spawns Task agents per story
4. Each Task agent gets **fresh context** (~150k tokens) to implement one story
5. Loop continues until all stories have `passes: true`

## Architecture

**Problem**: Traditional single-session agents accumulate context over many iterations, eventually hitting context window limits and failing on larger features.

**Solution**: Ralph PRD uses a **coordinator + Task agent** pattern:

```
┌──────────────────────────────────────────┐
│  Coordinator Agent (minimal context)    │
│  - Reads prd.json                        │
│  - Finds next incomplete story           │
│  - Spawns Task agent per story           │
│  - Monitors progress                     │
└──────────────────────────────────────────┘
                  │
                  ├─> Task Agent 1 (US-001) → Fresh 150k context → Impl + Commit → Exit
                  │
                  ├─> Task Agent 2 (US-002) → Fresh 150k context → Impl + Commit → Exit
                  │
                  └─> Task Agent 3 (US-003) → Fresh 150k context → Impl + Commit → Exit
```

**Key benefits**:
- ✅ Each story gets full context window (~150k tokens)
- ✅ No context accumulation across stories
- ✅ Can handle 50+ story features (limited only by story size, not total count)
- ✅ Pausable/resumable (prd.json = state)
- ✅ Quality gates per story (typecheck, tests)

**Memory mechanism**:
- **Code state**: Git commits (ground truth)
- **Story status**: prd.json (`passes: true/false`)
- **Learnings**: progress.jsonl (for future Task agents to read)

## Installation

**Prerequisites:** jq (1.6+), git (2.0+), Claude Code CLI (1.0+), bash (4.0+)

**Quick Install:**
```bash
# Via Claude Code commands
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace
/plugin install ralph-prd@filiup_marketplace
```

**Updating after git changes:**
```bash
/plugin marketplace update filiup_marketplace
```

**Detailed Guide:** See [INSTALL.md](../../INSTALL.md) for:
- Step-by-step installation
- Prerequisites with version requirements
- Platform-specific instructions (macOS, Linux, Windows)
- Verification steps
- Troubleshooting common issues

## Commands

### `/prd-create` - Generate a PRD

Creates a structured Product Requirements Document from a feature description.

```bash
/prd-create "Add task priority system with filtering"
```

**Output:** `tasks/prd-[feature-name].md`

### `/prd-convert` - Convert PRD to JSON

Converts a markdown PRD to the `prd.json` format Ralph uses.

```bash
/prd-convert tasks/prd-task-priority.md
```

**Output:** `prd.json` in current directory

**prd.json structure:**
```json
{
  "project": "MyApp",
  "branchName": "ralph/task-priority",
  "description": "Task Priority System - Add priority levels to tasks",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add priority field to database",
      "description": "As a developer, I need to store task priority...",
      "acceptanceCriteria": [
        "Add priority column to tasks table",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### `/ralph-prd-loop` - Start the autonomous loop

Starts the Ralph loop to iteratively implement all user stories.

```bash
/ralph-prd-loop
/ralph-prd-loop --max-iterations 20
```

**What happens:**
1. **Coordinator** reads `prd.json` and finds highest priority story with `passes: false`
2. **Spawns fresh Task agent** for that story (fresh context ~150k tokens)
3. **Task agent**:
   - Reads prd.json, progress.jsonl for context
   - Implements the single story
   - Runs quality checks (typecheck, tests, lint) with retries
   - Commits if checks pass: `feat: US-001 - Add priority field to database`
   - Updates prd.json (`passes: true`)
   - Appends learnings to progress.jsonl
   - Exits (context discarded)
4. **Coordinator** checks result and spawns next Task agent
5. Repeats until all stories have `passes: true`

**Key benefit**: Each story gets fresh context → no context accumulation → unlimited stories possible

### `/cancel-ralph-prd` - Stop the loop

Cancel an active Ralph PRD loop.

```bash
/cancel-ralph-prd
```

Removes the loop state file. You can resume later by running `/ralph-prd-loop` again - it will pick up where it left off based on `prd.json` status.

### `/help` - Quick reference

Show quick reference guide for Ralph PRD plugin.

```bash
/help
```

## Workflow Example

```bash
# 1. Create a PRD
/prd-create "Add user authentication with email and password"

# 2. Convert to JSON
/prd-convert tasks/prd-user-authentication.md

# 3. Review the generated stories
jq '.userStories[] | {id, title, priority, passes}' prd.json

# 4. Start the Ralph loop
/ralph-prd-loop --max-iterations 20

# Claude will now:
# - Implement US-001 (database schema)
# - Test & commit
# - Mark US-001 as passes:true
# - Move to US-002 (backend logic)
# - ... continue until all stories complete
```

## Monitoring Progress

### Check story status
```bash
jq '.userStories[] | {id, title, passes}' prd.json
```

### View progress log
```bash
tail -20 progress.txt
```

### Check loop state
```bash
head -10 .claude/ralph-prd-loop.local.md
```

### Use the utility script
```bash
./plugins/ralph-prd/scripts/check-stories.sh
```

Output:
```
📊 PRD Story Status
───────────────────
Total:      4
Complete:   2 ✓
Incomplete: 2

📝 User Stories:

  ✓ US-001: Add priority field to database [DONE]
  ✓ US-002: Display priority indicator on task cards [DONE]
  ○ US-003: Add priority selector to task edit [TODO - Priority 3]
  ○ US-004: Filter tasks by priority [TODO - Priority 4]

🎯 Next Story:
  → US-003: Add priority selector to task edit
```

## Files Created

- `prd.json` - User stories with pass/fail tracking
- `progress.txt` - Learnings and patterns discovered during implementation
- `AGENTS.md` - Directory-specific learnings for future agents/developers
- `.claude/ralph-prd-loop.local.md` - Loop state (temporary)

## Story Size Guidelines

**Each story must be completable in ONE Task agent context window (~150k tokens).**

Each story gets its own fresh Task agent. If a story is too large to implement within one context window, it will fail.

✅ **Right-sized stories:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

❌ **Too big (split these):**
- "Build the entire dashboard" → Split into: schema, queries, UI components, filters
- "Add authentication" → Split into: schema, middleware, login UI, session handling
- "Refactor the API" → Split into one story per endpoint

**Rule of thumb:** If you can't describe it in 2-3 sentences, it's too big.

## Story Ordering

Stories execute in priority order. **Earlier stories must not depend on later ones.**

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views

## Acceptance Criteria

Each criterion must be **verifiable**, not vague.

✅ **Good (verifiable):**
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Typecheck passes"

❌ **Bad (vague):**
- "Works correctly"
- "Good UX"
- "Handles edge cases"

**Always include:**
- "Typecheck passes" (every story)
- "Tests pass" (stories with testable logic)
- "Verify in browser using MCP browser" (UI stories)

## Browser Testing

UI stories are NOT complete until visually verified. Ralph uses MCP browser tools to:
1. Navigate to the relevant page
2. Interact with the UI
3. Verify changes work as expected
4. Take screenshots for documentation

## Progress Tracking

Ralph maintains two types of learnings:

### `progress.txt` - Iteration Log
Each iteration appends:
```markdown
## 2025-01-09 14:30 - US-003
- Implemented priority selector dropdown in task edit modal
- Files changed: src/components/TaskEditModal.tsx, src/types/task.ts
- **Learnings for future iterations:**
  - This codebase uses Radix UI for dropdowns
  - Always update TypeScript types in src/types/ when adding fields
  - Modal state is managed via Zustand store
---
```

### `AGENTS.md` - Reusable Patterns
Directory-specific learnings that help future work:
```markdown
# src/components/

## Patterns
- All modals use Radix UI Dialog primitive
- Form state managed with React Hook Form
- Validation schemas in src/lib/validations/

## Gotchas
- Modal components must be wrapped in DialogProvider
- Always add data-testid for testing
```

## Stopping the Loop

The loop stops when:
1. **All stories complete** - All `passes: true` in prd.json
2. **Max iterations reached** - If `--max-iterations` was set
3. **Completion promise** - Claude outputs `<promise>ALL_STORIES_COMPLETE</promise>`

## Advanced Usage

### Archive previous runs
If you have an existing prd.json and want to start a new feature, the converter will automatically archive the old run to `archive/YYYY-MM-DD-feature-name/`.

### Manual intervention
If Ralph gets stuck, you can:
1. Manually edit prd.json to mark stories complete
2. Update progress.txt with context
3. Resume the loop - it will pick up where it left off

### Custom quality checks
Ralph runs whatever checks your project uses. Common examples:
- `npm run typecheck`
- `npm run lint`
- `npm test`
- `cargo check`
- `pytest`

Add project-specific checks to your CI/CD and Ralph will respect them.

## Differences from snarktank/ralph

This plugin adapts the Amp-based workflow to Claude Code:

| snarktank/ralph | ralph-prd plugin |
|-----------------|------------------|
| External bash loop | Coordinator agent |
| Spawns fresh `amp` CLI per story | Spawns fresh Task agent per story |
| Amp skills/ | Claude Code agents/ |
| `$AMP_CURRENT_THREAD_ID` | Not needed (no threads) |
| dev-browser skill | MCP browser tools |
| Fresh process = fresh context | Fresh Task = fresh context |

## Troubleshooting

### "prd.json not found"
Run `/prd-convert tasks/your-prd.md` first to create prd.json.

### "All stories already complete"
All stories have `passes: true`. Create a new feature or reset:
```bash
jq '(.userStories[] | .passes) = false' prd.json > prd.json.tmp && mv prd.json.tmp prd.json
```

### Loop isn't stopping
Check for incomplete stories:
```bash
jq '[.userStories[] | select(.passes == false)]' prd.json
```

### Commits failing quality checks
Ralph won't commit broken code. Check:
```bash
npm run typecheck
npm test
```

Fix issues and the next iteration will handle it.

## Credits

- Original Ralph pattern by [Nat Friedman](https://x.com/natfriedman/status/1808499369577234768)
- Amp implementation by [snarktank/ralph](https://github.com/snarktank/ralph)
- Claude Code adaptation by the community

## License

MIT

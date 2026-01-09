---
description: "Cancel active Ralph PRD Loop"
allowed-tools: ["Bash(test -f .claude/ralph-prd-loop.local.md:*)", "Bash(rm .claude/ralph-prd-loop.local.md)", "Read(.claude/ralph-prd-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph PRD Loop

To cancel the Ralph PRD loop:

1. Check if `.claude/ralph-prd-loop.local.md` exists using Bash: `test -f .claude/ralph-prd-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Ralph PRD loop found."

3. **If EXISTS**:
   - Read `.claude/ralph-prd-loop.local.md` to get the current iteration number from the `iteration:` field
   - Remove the file using Bash: `rm .claude/ralph-prd-loop.local.md`
   - Report: "Cancelled Ralph PRD loop (was at iteration N)" where N is the iteration value

4. Remind the user they can resume by running `/ralph-prd-loop` again - it will pick up where it left off based on prd.json status.

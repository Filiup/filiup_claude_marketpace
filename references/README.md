# Reference Implementations

This directory contains git submodules of the projects that inspired ralph-prd plugin.

## Submodules

### snarktank-ralph/
**Repository:** https://github.com/snarktank/ralph

Original Ralph implementation for Amp CLI. This is the source of:
- PRD workflow design
- `prd.json` structure with user stories
- `passes:true/false` tracking pattern
- PRD creation and conversion skills

**Key files to reference:**
- `prompt.md` - Ralph agent instructions
- `prd.json.example` - PRD structure example
- `skills/prd/SKILL.md` - PRD creation skill
- `skills/ralph/SKILL.md` - PRD conversion skill

### claude-plugins-official/
**Repository:** https://github.com/anthropics/claude-plugins-official

Official Claude Code plugins repository. We specifically used:
- `plugins/ralph-loop/` - Loop mechanism with stop hooks

**Key files to reference:**
- `plugins/ralph-loop/hooks/stop-hook.sh` - Stop hook pattern
- `plugins/ralph-loop/commands/ralph-loop.md` - Loop command structure

## Usage for AI Agents

These references are included to help AI agents understand:
1. The original design patterns and philosophy
2. How the Amp-based workflow was adapted to Claude Code
3. Implementation details when debugging or extending the plugin

## Updating References

```bash
# Update all submodules to latest
git submodule update --remote

# Update specific submodule
cd references/snarktank-ralph
git pull origin main
cd ../..
git add references/snarktank-ralph
git commit -m "Update snarktank-ralph reference"
```

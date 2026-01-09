# Claude Code Marketplace - Ralph PRD Plugin

A custom Claude Code marketplace featuring the **ralph-prd** plugin - an autonomous AI agent for completing PRs through structured PRD workflows.

## What is ralph-prd?

An autonomous AI agent loop that implements the ["Ralph Wiggum" pattern](https://x.com/natfriedman/status/1808499369577234768) for iterative software development. Based on [snarktank/ralph](https://github.com/snarktank/ralph), adapted to work natively with Claude Code.

### Key Features

- **PRD Management** - Create Product Requirements Documents and convert them to structured JSON
- **Story Tracking** - User stories with `passes:true/false` status tracking
- **Autonomous Loop** - Claude implements stories iteratively until completion
- **Progress Preservation** - Learnings and patterns saved in `progress.txt` and `AGENTS.md`
- **Browser Testing** - UI story verification via MCP browser integration
- **Git Integration** - Automatic commits after successful test runs

### How It Works

```
1. Write PRD          → /prd-create "Add dark mode toggle"
2. Convert to JSON    → /prd-convert tasks/prd-dark-mode.md
3. Start Ralph loop   → /ralph-prd-loop --max-iterations 20

Ralph loop:
- Picks highest priority story with passes:false
- Implements the story
- Runs quality checks (typecheck, tests)
- Commits if checks pass
- Updates story to passes:true
- Repeats until all stories complete
```

---

## Quick Start

### 1. Add Marketplace

```bash
# Add this marketplace directly from GitHub
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace
```

### 2. Install Plugin

```bash
# Install ralph-prd
/plugin install ralph-prd@filiup_marketplace
```

### 3. Verify Installation

```bash
# Check plugin loaded
/plugin list

# Try help
/help
```

### 4. Create Your First PRD

```bash
cd ~/your-project
/prd-create "Add user authentication with email and password"
```

**That's it!** See [INSTALL.md](INSTALL.md) for detailed setup and [plugins/ralph-prd/README.md](plugins/ralph-prd/README.md) for complete documentation.

---

## Requirements

- **Claude Code CLI** - [Install instructions](https://github.com/anthropics/claude-code)
- **jq** - JSON processor (`brew install jq` or `apt install jq`)
- **Git** - For version control
- **Bash 4.0+** - Usually pre-installed

---

## Repository Structure

```
filiup_marketplace/
├── .claude-plugin/
│   └── marketplace.json       # Marketplace metadata
├── README.md                   # This file
├── INSTALL.md                  # Detailed installation & troubleshooting
├── plugins/
│   └── ralph-prd/             # Ralph PRD plugin
│       ├── .claude-plugin/
│       │   └── plugin.json    # Plugin metadata
│       ├── commands/          # 5 slash commands
│       │   ├── prd-create.md
│       │   ├── prd-convert.md
│       │   ├── ralph-prd-loop.md
│       │   ├── cancel-ralph-prd.md
│       │   └── help.md
│       ├── hooks/
│       │   ├── hooks.json
│       │   └── stop-hook.sh   # Loop mechanism
│       ├── scripts/
│       │   ├── setup-ralph-prd.sh
│       │   └── check-stories.sh
│       └── README.md          # Plugin documentation
└── references/                # Reference implementations (submodules)
    ├── README.md              # Reference guide
    ├── snarktank-ralph/       # Original Amp-based Ralph
    └── claude-plugins-official/ # Official ralph-loop plugin
```

---

## Example Workflow

```bash
# Navigate to your project
cd ~/projects/my-app

# 1. Create PRD
/prd-create "Add task priority system with filtering"
# → Creates tasks/prd-task-priority.md

# 2. Review and edit PRD if needed
vim tasks/prd-task-priority.md

# 3. Convert to JSON
/prd-convert tasks/prd-task-priority.md
# → Creates prd.json with structured stories

# 4. Review stories
jq '.userStories[] | {id, title, priority}' prd.json

# 5. Start autonomous loop
/ralph-prd-loop --max-iterations 20
# → Claude implements each story automatically

# 6. Monitor progress
tail -f progress.txt
jq '.userStories[] | {id, passes}' prd.json

# 7. Cancel if needed
/cancel-ralph-prd
```

---

## References

This repository includes submodules of the projects that inspired ralph-prd:

- **[snarktank/ralph](references/snarktank-ralph/)** - Original Amp-based Ralph implementation
  - PRD workflow design and `prd.json` structure
  - Source of PRD creation and conversion patterns

- **[claude-plugins-official](references/claude-plugins-official/)** - Official Claude Code plugins
  - Ralph-loop plugin with stop hook mechanism
  - Loop implementation patterns

See [references/README.md](references/README.md) for detailed reference guide.

---

## Documentation

- **[INSTALL.md](INSTALL.md)** - Complete installation guide, troubleshooting, and advanced setup
- **[Plugin README](plugins/ralph-prd/README.md)** - Full plugin documentation with examples
- **[Plugin Commands](plugins/ralph-prd/commands/)** - Individual command documentation

---

## Adding More Plugins

This marketplace supports multiple plugins. To add your own:

```bash
# 1. Create plugin directory
mkdir -p plugins/my-plugin

# 2. Add plugin structure
cd plugins/my-plugin
mkdir -p .claude-plugin commands hooks scripts

# 3. Create plugin.json
cat > .claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "description": "My awesome plugin",
  "author": {
    "name": "Your Name",
    "email": "your@email.com"
  }
}
EOF

# 4. Add commands and commit
git add plugins/my-plugin
git commit -m "Add my-plugin"

# 5. Install
/plugin install my-plugin@filiup_marketplace
```

---

## Troubleshooting

**Plugin not found?**
```bash
# Verify marketplace is added
/plugin marketplace list

# Re-add if needed
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace
```

**Commands not working?**
```bash
# Reinstall plugin
/plugin uninstall ralph-prd@filiup_marketplace
/plugin install ralph-prd@filiup_marketplace
```

**Need jq?**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

See [INSTALL.md](INSTALL.md) for comprehensive troubleshooting.

---

## Credits

- **Ralph pattern** - [Nat Friedman](https://x.com/natfriedman/status/1808499369577234768)
- **Amp implementation** - [snarktank/ralph](https://github.com/snarktank/ralph)
- **Claude Code** - [Anthropic](https://github.com/anthropics/claude-code)

---

## License

MIT

## Contributing

Contributions welcome! Open an issue or submit a PR.

---

**Ready to try autonomous coding?** Follow the [Quick Start](#quick-start) above! 🚀

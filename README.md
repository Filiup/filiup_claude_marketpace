# Filiup Claude Code Marketplace

Custom Claude Code marketplace for community plugins.

## Available Plugins

### 📋 ralph-prd - Autonomous PRD Implementation

Autonomous AI agent loop that implements features through structured PRD workflows.

**Quick Start:**
```bash
/plugin install ralph-prd@filiup_marketplace
/prd-create "Your feature description"
```

**Documentation:** [plugins/ralph-prd/README.md](plugins/ralph-prd/README.md)

---

## Installation

### 1. Add Marketplace

```bash
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace
```

### 2. Install Plugins

```bash
# Install available plugins
/plugin install ralph-prd@filiup_marketplace
```

### 3. Verify

```bash
/plugin list
```

**Detailed Guide:** See [INSTALL.md](INSTALL.md) for prerequisites, troubleshooting, and platform-specific instructions.

---

## Repository Structure

```
filiup_marketplace/
├── .claude-plugin/
│   └── marketplace.json         # Marketplace metadata
├── README.md                     # This file
├── INSTALL.md                    # Installation guide
├── plugins/
│   └── ralph-prd/               # Ralph PRD plugin
│       ├── README.md            # Plugin documentation
│       ├── commands/            # Slash commands
│       ├── hooks/               # Stop hook for loop
│       ├── scripts/             # Utility scripts
│       └── examples/            # Example files
└── todos/                        # Development tracking
```

---

## Documentation

- **[INSTALL.md](INSTALL.md)** - Installation guide and troubleshooting
- **[ralph-prd README](plugins/ralph-prd/README.md)** - Plugin documentation and examples

---

## Adding Plugins to This Marketplace

Want to add your own plugin? Follow the structure:

```bash
mkdir -p plugins/my-plugin/.claude-plugin
mkdir -p plugins/my-plugin/commands

# Create plugin.json with metadata
# Add your commands as .md files
# Commit and install
```

See existing plugins for examples.

---

## Contributing

Contributions welcome! Open an issue or submit a PR.

**License:** MIT

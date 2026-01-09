# Ralph PRD Plugin - Installation Guide

## Quick Install (Recommended)

### Option 1: Via Claude Code Commands

```bash
# 1. Add filiup_marketplace to Claude Code
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace

# 2. Install ralph-prd plugin
/plugin install ralph-prd@filiup_marketplace
```

### Option 2: Via UI

In Claude Code:
1. Run `/plugin`
2. Select **Discover**
3. Choose **filiup_marketplace**
4. Select **ralph-prd**
5. Click **Install**

---

## Verify Installation

```bash
# Check plugin is installed
/plugin list

# Try help command
/help

# Test a command
/prd-create "Test feature"
```

---

## System Requirements

### Required Software

#### Claude Code CLI
- **Version:** v1.0.0 or higher
- **Installation:** See [Claude Code Installation Guide](https://claude.ai/claude-code)
- **Verify:**
  ```bash
  claude --version
  # or if using npx:
  npx claude-code --version
  ```

#### jq - JSON Processor
- **Version:** 1.6 or higher
- **Required for:** Parsing prd.json, state files, events
- **Installation:**
  ```bash
  # Ubuntu/Debian
  sudo apt update && sudo apt install jq

  # macOS
  brew install jq

  # Fedora/RHEL
  sudo dnf install jq

  # Windows (via Chocolatey)
  choco install jq

  # Or download: https://stedolan.github.io/jq/download/
  ```
- **Verify:**
  ```bash
  jq --version
  # Should output: jq-1.6 or higher
  ```

#### Git
- **Version:** 2.0 or higher
- **Required for:** Branch management, commits
- **Verify:**
  ```bash
  git --version
  ```

#### Bash
- **Version:** 4.0 or higher
- **Pre-installed on:** Most Linux/macOS systems
- **Verify:**
  ```bash
  bash --version
  # Should show: GNU bash, version 4.x or 5.x
  ```

### Optional Software

#### MCP Browser Plugin (Playwright)
- **Purpose:** Automated UI testing for user stories
- **Installation:** Via Claude Code plugins
- **Check availability:**
  ```bash
  ls ~/.claude/plugins/compound-engineering/pw/
  ```
- **Documentation:** See [MCP Playwright docs](https://github.com/compound-engineering/mcp-plugins)

---

## Post-Installation Testing

### 1. Create Test PRD

```bash
cd ~/projects/test-ralph
/prd-create "Simple counter button"
```

### 2. Or Create Test prd.json

```bash
cat > prd.json <<'EOF'
{
  "project": "TestApp",
  "branchName": "ralph/test",
  "description": "Test feature",
  "userStories": [
    {
      "id": "US-001",
      "title": "Test story",
      "description": "As a tester, I verify the plugin works",
      "acceptanceCriteria": [
        "Story loads correctly",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF
```

### 3. Verify Story Checking

```bash
# Check story status
jq '.userStories[] | {id, title, passes}' prd.json
```

### 4. Test Loop

```bash
# Show help (validates prd.json)
/ralph-prd-loop --help

# Run single iteration
/ralph-prd-loop --max-iterations 1
```

---

## Troubleshooting

### Marketplace Not Found

**Solution:**
```bash
# Check marketplace is added
/plugin marketplace list

# Re-add if needed
/plugin marketplace add https://github.com/Filiup/filiup_claude_marketpace
```

### Plugin Not Found

**Solution:**
```bash
# Verify plugin structure
ls -la /path/to/filiup_marketplace/plugins/ralph-prd/

# Should contain:
# .claude-plugin/, commands/, hooks/, scripts/, README.md
```

### Command Not Found

**Cause:** Plugin not loaded

**Solution:**
```bash
# Check installation
/plugin list

# Reinstall
/plugin uninstall ralph-prd@filiup_marketplace
/plugin install ralph-prd@filiup_marketplace

# Restart Claude Code
```

### jq Not Found

**Cause:** Missing dependency

**Solution:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install jq

# macOS
brew install jq

# Verify
jq --version
```

### Script Permission Errors

**Cause:** Scripts not executable (shouldn't happen from git)

**Solution:**
```bash
cd /path/to/filiup_marketplace/plugins/ralph-prd
chmod +x hooks/*.sh scripts/*.sh

# Commit fix
git add hooks/*.sh scripts/*.sh
git commit -m "Fix script permissions"
```

---

## Updating

### Update Marketplace

```bash
cd /path/to/filiup_marketplace
git pull

# Or
/plugin marketplace update filiup_marketplace
```

### Update Plugin

```bash
/plugin update ralph-prd@filiup_marketplace
```

---

## Uninstall

### Remove Plugin

```bash
/plugin uninstall ralph-prd@filiup_marketplace
```

### Remove Marketplace (optional)

```bash
/plugin marketplace remove filiup_marketplace
```

---

## Development

### Making Changes

```bash
# 1. Edit files
vim /path/to/filiup_marketplace/plugins/ralph-prd/commands/prd-create.md

# 2. Commit
cd /path/to/filiup_marketplace
git add .
git commit -m "Update prd-create command"

# 3. Reinstall to see changes
/plugin update ralph-prd@filiup_marketplace
```

### Adding Plugins to Marketplace

```bash
# Create plugin directory
mkdir -p /path/to/filiup_marketplace/plugins/my-plugin

# Add plugin files
cd /path/to/filiup_marketplace/plugins/my-plugin
mkdir -p .claude-plugin commands hooks scripts

# Commit
cd /path/to/filiup_marketplace
git add plugins/my-plugin
git commit -m "Add my-plugin"

# Install
/plugin install my-plugin@filiup_marketplace
```

---

## Next Steps

After successful installation:

1. Read plugin documentation: `plugins/ralph-prd/README.md`
2. Create your first PRD: `/prd-create "Your feature"`
3. Convert and run: `/prd-convert` → `/ralph-prd-loop`

Happy autonomous coding! 🚀

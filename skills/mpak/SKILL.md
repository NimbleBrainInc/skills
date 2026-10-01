---
name: mpak
description: Guide for using the mpak CLI to discover, install, run, and manage MCP server bundles and Agent Skills. Covers bundle lifecycle, skill installation, configuration, and integration with Claude Code and Claude Desktop. Triggers include "how do I use mpak", "install a bundle", "add an MCP server", "mpak help".
license: MIT
compatibility: Node.js 18+, npm. For running Python bundles, Python 3.13+ and uv. For Claude Code integration, Claude Code CLI (`claude`). For Claude Desktop, access to claude_desktop_config.json.
allowed-tools: Read Bash Glob Grep WebFetch AskUserQuestion
metadata:
  area: mpak
  version: "0.1.0"
  author: NimbleBrain
---

# mpak Guide

mpak is the package manager for MCP servers and Agent Skills — npm for AI agents. Use it to discover, install, run, and manage MCP server bundles and markdown-based skills from the mpak registry.

## Quick Start

```
> /mpak-guide
```

## Installation

```bash
npm install -g @nimblebrain/mpak
```

Verify:

```bash
mpak --version
```

Enable shell completions (optional):

```bash
# bash
eval "$(mpak completion bash)"

# zsh
eval "$(mpak completion zsh)"

# fish
mpak completion fish | source
```

## Concepts

mpak distributes two package types:

| Type | What it is | Example |
|------|-----------|---------|
| **Bundle** | A pre-packaged MCP server (`.mcpb` file). Python, Node, or binary. Vendored deps, no network calls at startup. | `@nimblebraininc/granola` |
| **Skill** | A markdown file (`SKILL.md`) that teaches an AI agent a new behavior or workflow. | `@nimblebraininc/build-mcpb` |

## Bundles

### Discover bundles

```bash
# Search the registry
mpak search "meeting notes"
mpak bundle search "github" --type python

# View bundle details (trust level, tools, versions, platforms)
mpak bundle show @scope/bundle-name
```

`bundle show` displays the trust level (L1–L4), available tools, platform artifacts, and install instructions.

### Install and run a bundle

```bash
# Pull a bundle (downloads the .mcpb file)
mpak bundle pull @scope/bundle-name

# Run a bundle (downloads if needed, extracts to ~/.mpak/cache/, starts the server)
mpak bundle run @scope/bundle-name

# Or use the top-level alias
mpak run @scope/bundle-name
```

`bundle run` is the primary command. It handles download, extraction, config resolution, and server startup in one step. The server runs over stdio — designed to be wired into Claude Code or Claude Desktop.

### Platform selection

mpak auto-detects your OS and architecture. To override:

```bash
mpak bundle pull @scope/bundle-name --os darwin --arch arm64
```

Valid values: `--os` accepts `darwin`, `linux`, `win32`. `--arch` accepts `x64`, `arm64`.

### Version pinning

Pin to a specific version with `@version`:

```bash
mpak bundle pull @scope/bundle-name@1.2.0
mpak bundle run @scope/bundle-name@1.2.0
```

### Bundle configuration

Some bundles require configuration (API keys, paths, etc.). mpak resolves config in this priority order:

1. Environment variables from parent process (highest)
2. Stored config (`~/.mpak/config.json`)
3. Default values from bundle manifest
4. Interactive prompts (TTY only, lowest)

Manage stored config:

```bash
# Set config values
mpak config set @scope/bundle-name API_KEY=sk-abc123 REGION=us-east-1

# View stored config (values masked)
mpak config get @scope/bundle-name

# List all configured packages
mpak config list

# Clear config
mpak config clear @scope/bundle-name          # all keys
mpak config clear @scope/bundle-name API_KEY   # specific key
```

### Run a local bundle file

Test a `.mcpb` file without publishing:

```bash
mpak bundle run --local ./my-server-0.1.0-darwin-arm64.mcpb
```

## Skills

### Discover and install skills

```bash
# Search for skills
mpak skill search "contributor"
mpak skill search "frontend" --category design --surface claude-code

# View skill details
mpak skill show @scope/skill-name

# Install to ~/.claude/skills/
mpak skill install @scope/skill-name

# Force reinstall
mpak skill install @scope/skill-name --force

# List installed skills
mpak skill list
```

Once installed, skills are automatically available in Claude Code as slash commands or trigger-based behaviors.

### Skill authoring

Validate and pack a skill for publishing:

```bash
# Validate against the Agent Skills spec
mpak skill validate ./my-skill/

# Create a .skill bundle
mpak skill pack ./my-skill/
```

Read `references/SKILL_AUTHORING.md` for the full skill format specification.

## Connecting Bundles to Claude Code

This is the most common workflow: install a bundle from mpak and wire it into Claude Code as an MCP server.

### Step 1: Add the server

```bash
# User-scoped (available in all projects)
claude mcp add --transport stdio --scope user <server-name> -- mpak bundle run @scope/bundle-name

# Project-scoped (shared with team via .mcp.json)
claude mcp add --transport stdio --scope project <server-name> -- mpak bundle run @scope/bundle-name
```

Example:

```bash
claude mcp add --transport stdio --scope user granola -- mpak bundle run @nimblebraininc/granola
```

### Step 2: Restart Claude Code

The MCP server connects on session start. After adding a new server, restart Claude Code for it to take effect.

### Step 3: Verify

```bash
claude mcp list          # List all configured servers
claude mcp get granola   # Check a specific server
```

### Removing a server

```bash
claude mcp remove --scope user <server-name>
```

### Switching to a local dev server

When developing a bundle locally, point Claude Code at the source instead of the published bundle:

```bash
# Remove the mpak-based server
claude mcp remove --scope user <server-name>

# Add the local dev server (Python example)
claude mcp add --transport stdio --scope user <server-name> -- uv run --directory /path/to/server python -m my_server.server

# Add the local dev server (Node example)
claude mcp add --transport stdio --scope user <server-name> -- node /path/to/server/dist/index.js
```

## Connecting Bundles to Claude Desktop

Edit the Claude Desktop config file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "granola": {
      "command": "mpak",
      "args": ["bundle", "run", "@nimblebraininc/granola"]
    }
  }
}
```

If the bundle needs config, add environment variables:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "mpak",
      "args": ["bundle", "run", "@scope/bundle-name"],
      "env": {
        "API_KEY": "your-key-here"
      }
    }
  }
}
```

Restart Claude Desktop after editing the config.

## Trust & Security

Every bundle on the registry is scanned across 25 security controls and assigned a trust level:

| Level | Name | What it means |
|-------|------|---------------|
| L1 | Basic | SBOM present, no secrets/malware, valid manifest, tools declared |
| L2 | Standard | + vulnerability scanning, dependency pinning, static analysis, author identity |
| L3 | Verified | + bundle signatures, build attestation, input validation, repo health |
| L4 | Attested | + behavioral analysis, reproducible builds, commit linkage |

View a bundle's trust level:

```bash
mpak bundle show @scope/bundle-name
```

## Troubleshooting

### Bundle runs stale code after update

If `mpak bundle pull` downloads a new version but `mpak bundle run` still uses old code, the extracted cache at `~/.mpak/cache/<package>/` is stale. Clear it:

```bash
rm -rf ~/.mpak/cache/<scope>-<package>/
```

Then `mpak bundle run` will re-extract from the latest `.mcpb`.

### Wrong platform artifact downloaded

Verify your platform detection:

```bash
node -e "console.log(process.platform, process.arch)"
```

If mpak downloads the wrong artifact, force the correct platform:

```bash
mpak bundle pull @scope/bundle-name --os darwin --arch arm64
```

### MCP server not connecting in Claude Code

1. Verify the server is configured: `claude mcp list`
2. Check the command works standalone: `mpak bundle run @scope/bundle-name`
3. Restart Claude Code — MCP servers connect on session start
4. Check if the bundle needs config: `mpak config get @scope/bundle-name`

### Bundle needs an API key or config

If a bundle prompts for config interactively but you're running it headless (via Claude Code), set config beforehand:

```bash
mpak config set @scope/bundle-name API_KEY=your-key
```

## Key Directories

| Path | Purpose |
|------|---------|
| `~/.mpak/cache/` | Extracted bundle cache (where `bundle run` executes from) |
| `~/.mpak/config.json` | Stored per-package configuration |
| `~/.claude/skills/` | Installed skills directory |
| `$CWD/.mpak/` | Default workspace for stateful bundles (`MPAK_WORKSPACE` env var) |

## Complete Command Reference

Read `references/CLI_REFERENCE.md` for the full command reference with all flags and options.

## Rules

- Always use `mpak bundle run` (not `bundle pull`) when the goal is to start a server — `run` handles download, extraction, and startup in one step.
- When wiring a bundle to Claude Code, prefer `--scope user` for personal tools and `--scope project` for team-shared servers.
- After adding or changing an MCP server in Claude Code, always remind the user to restart their session.
- When a bundle isn't working, check the cache (`~/.mpak/cache/`) before assuming the bundle is broken.
- When switching between published and local dev servers, remove the old config first to avoid conflicts.
- Never hardcode API keys in `.mcp.json` or `claude_desktop_config.json` — use `mpak config set` or environment variables.

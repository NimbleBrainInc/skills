# mpak CLI Reference

Complete command reference for mpak v0.3.3+.

## Global

```
mpak [options] [command]
```

| Option | Description |
|--------|-------------|
| `-v, --version` | Output the current version |
| `-h, --help` | Display help |

## Top-Level Aliases

| Command | Alias for |
|---------|-----------|
| `mpak search <query>` | Unified search across bundles and skills |
| `mpak run [package]` | `mpak bundle run [package]` |

### `mpak search <query>`

| Flag | Description |
|------|-------------|
| `--type <type>` | Filter by type: `bundle` or `skill` |
| `--sort <field>` | Sort by: `downloads`, `recent`, `name` |
| `--limit <number>` | Limit results (default: 20) |
| `--offset <number>` | Pagination offset (default: 0) |
| `--json` | Output as JSON |

---

## Bundle Commands

### `mpak bundle search <query>`

Search public bundles in the registry.

| Flag | Description |
|------|-------------|
| `--type <type>` | Filter by server type: `node`, `python`, `binary` |
| `--sort <field>` | Sort by: `downloads`, `recent`, `name` |
| `--limit <number>` | Limit results |
| `--offset <number>` | Pagination offset |
| `--json` | Output as JSON |

### `mpak bundle show <package>`

Show detailed information about a bundle: trust level, tools, versions, platforms, install instructions.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak bundle pull <package>`

Download a `.mcpb` bundle file from the registry. Supports version pinning: `@scope/name@1.0.0`.

| Flag | Description |
|------|-------------|
| `-o, --output <path>` | Output file path |
| `--os <os>` | Target OS: `darwin`, `linux`, `win32` |
| `--arch <arch>` | Target architecture: `x64`, `arm64` |
| `--json` | Output download info as JSON |

### `mpak bundle run [package]`

Run an MCP server. Downloads and extracts to `~/.mpak/cache/` if not cached. Resolves config, starts the server over stdio.

| Flag | Description |
|------|-------------|
| `--update` | Force re-download even if cached |
| `-l, --local <path>` | Run a local `.mcpb` bundle file |

Environment: sets `MPAK_WORKSPACE` to `$CWD/.mpak` by default.

---

## Skill Commands

### `mpak skill search <query>`

Search skills in the registry.

| Flag | Description |
|------|-------------|
| `--tags <tags>` | Filter by tags (comma-separated) |
| `--category <category>` | Filter by category |
| `--surface <surface>` | Filter by surface: `claude-code`, `claude-api`, `claude-ai` |
| `--sort <field>` | Sort by: `downloads`, `recent`, `name` |
| `--limit <number>` | Limit results |
| `--offset <number>` | Pagination offset |
| `--json` | Output as JSON |

### `mpak skill show <name>`

Show detailed information about a skill: version, description, category, tags, triggers, examples, download stats.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak skill pull <name>`

Download a `.skill` bundle file to the current directory. Verifies SHA256. Supports version pinning: `@scope/name@1.0.0`.

| Flag | Description |
|------|-------------|
| `-o, --output <path>` | Output file path |
| `--json` | Output as JSON |

### `mpak skill install <name>`

Download and extract a skill to `~/.claude/skills/<skill-name>/`. Verifies SHA256. Supports version pinning.

| Flag | Description |
|------|-------------|
| `--force` | Overwrite existing installation |
| `--json` | Output as JSON |

### `mpak skill list`

List all installed skills in `~/.claude/skills/`.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak skill validate <path>`

Validate a skill directory against the Agent Skills spec. Checks directory structure, `SKILL.md` existence, frontmatter parsing, schema validation.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak skill pack <path>`

Validate then create a `.skill` ZIP bundle from a skill directory. Outputs SHA256.

| Flag | Description |
|------|-------------|
| `-o, --output <path>` | Output file path |
| `--json` | Output as JSON |

---

## Config Commands

Manage per-package configuration values stored in `~/.mpak/config.json`.

### `mpak config set <package> <key=value...>`

Store one or more config values for a package.

```bash
mpak config set @scope/bundle API_KEY=sk-123 REGION=us-east-1
```

### `mpak config get <package>`

Show stored config for a package. Values are masked in output.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak config list`

List all packages with stored config.

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON |

### `mpak config clear <package> [key]`

Clear all config for a package, or a specific key.

```bash
mpak config clear @scope/bundle          # all keys
mpak config clear @scope/bundle API_KEY   # specific key
```

---

## Shell Completions

### `mpak completion <shell>`

Generate shell completion scripts. Supported: `bash`, `zsh`, `fish`.

```bash
eval "$(mpak completion bash)"
eval "$(mpak completion zsh)"
mpak completion fish | source
```

# MCP Server Conventions (Python)

## Critical

Package names MUST be scoped: `@<github_owner>/<name>`

Name must match the registry regex: `/^@[a-zA-Z0-9][a-zA-Z0-9-]{0,38}\/[a-z0-9][a-z0-9-]{0,213}$/`

The owner segment (before `/`) accepts mixed case — the registry normalizes it to lowercase. The package name (after `/`) must be lowercase.

Registry rejects other formats (e.g., `ai.nimbletools/name`, underscores in name).

## Naming

| Aspect | Value |
|--------|-------|
| Package scope | `@<github_owner>/<name>` |
| Module / package | `mcp_<name>` (underscores) |
| Source directory | `src/mcp_<name>/` |
| Environment variable | `<NAME>_API_KEY` |

## Concept Mapping

| Concept | Python |
|---------|--------|
| Response models | Pydantic `BaseModel` |
| Tool input validation | Python type hints + FastMCP |
| HTTP client | `aiohttp.ClientSession` |
| Tool registration | `@mcp.tool()` decorator |
| Response formatting | Return Pydantic model directly |
| Error handling | `try/except APIError` |

## Manifest (MCPB v0.4)

### Required vs Optional Fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | **Yes** | Must match `/^@[a-zA-Z0-9][a-zA-Z0-9-]{0,38}\/[a-z0-9][a-z0-9-]{0,213}$/` |
| `version` | **Yes** | Valid semver (e.g., `0.1.0`) |
| `description` | **Yes** | Short description |
| `server.type` | **Yes** | `python`, `node`, or `binary` |
| `server.mcp_config` | **Yes** | Must have `command` (string) and `args` (string array) |
| `server.entry_point` | **Yes** | Module path (Python) or `build/index.js` (TypeScript) |
| `manifest_version` | Recommended | `"0.4"` |
| `author` | Recommended | `{ "name": "..." }` |
| `user_config` | If server needs config | Each entry needs `type`; use `sensitive: true` for secrets |
| `tools` | Recommended | Array of `{ "name": "...", "description": "..." }` |
| `display_name` | Optional | Human-readable name |
| `long_description` | Optional | Extended description |
| `license` | Optional | SPDX identifier |
| `keywords` | Optional | Array of strings |
| `repository` | Optional | `{ "type": "git", "url": "..." }` |
| `compatibility` | Optional | Platforms, runtimes |
| `_meta` | Recommended | MTF permissions block |

### Variable Resolution

- `${user_config.<field>}` — resolves to the user's configured value for that field (used in `server.mcp_config.env`)

Never use file paths (`${__dirname}/...`) for Python — breaks after bundling.

### mpak.json

Required for package claiming on the mpak registry. Must exist in the repo root:

```json
{
  "name": "@<github_owner>/<name>",
  "maintainers": ["<github-username>"]
}
```

The `name` field must exactly match the `name` in `manifest.json`.

### manifest.json Example

```json
{
  "manifest_version": "0.4",
  "name": "@<github_owner>/<name>",
  "version": "0.1.0",
  "description": "...",
  "author": { "name": "NimbleBrain Inc" },
  "user_config": {
    "api_key": {
      "type": "string",
      "title": "API Key",
      "description": "Your API key from...",
      "sensitive": true,
      "required": true
    }
  },
  "server": {
    "type": "python",
    "entry_point": "mcp_<name>.server",
    "mcp_config": {
      "command": "python",
      "args": ["-m", "mcp_<name>.server"],
      "env": {
        "<NAME>_API_KEY": "${user_config.api_key}"
      }
    }
  },
  "tools": [
    { "name": "tool_name", "description": "What it does" }
  ],
  "_meta": {
    "org.mpaktrust": {
      "mtf_version": "0.1",
      "permissions": {
        "network": "outbound",
        "filesystem": "none",
        "subprocess": "none",
        "environment": "read",
        "native": "none"
      }
    }
  }
}
```

`server.mcp_config` is **required** — the registry uses it to generate the MCP client configuration. Both `command` and `args` must be present.

## user_config (API Keys)

Required format for `mpak config set` compatibility:

```json
{
  "user_config": {
    "api_key": {
      "type": "string",
      "title": "Human Readable Title",
      "description": "Where to get this key",
      "sensitive": true,
      "required": true
    }
  }
}
```

- Field names: lowercase with underscores (`api_key`, `database_uri`)
- Use `sensitive: true` for secrets (not `secret`)
- Reference via `${user_config.<field_name>}` in env mapping

## server.json

All servers require a `server.json` for registry metadata. This is what mpak uses to ingest and announce bundles.

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "io.<github_owner>/<name>",
  "title": "<Display Name>",
  "description": "...",
  "version": "0.1.0",
  "websiteUrl": "https://github.com/<github_owner>",
  "repository": {
    "url": "https://github.com/<github_owner>/mcp-<name>",
    "source": "github"
  },
  "packages": [
    {
      "registryType": [
        "mcpb",
        "pypi"
      ],
      "registryBaseUrl": "https://pypi.org",
      "identifier": "mcp-<name>",
      "version": "0.1.0",
      "transport": { "type": "stdio" },
      "environmentVariables": [
        {
          "name": "<NAME>_API_KEY",
          "description": "...",
          "isRequired": true,
          "isSecret": true
        }
      ]
    }
  ],
  "_meta": {
    "io.modelcontextprotocol.registry/publisher-provided": {
      "tool": "mcpb",
      "version": "0.4"
    },
    "org.mpaktrust": {
      "mtf_version": "0.1",
      "permissions": {
        "network": ["<api-hostname>"],
        "filesystem": "none",
        "subprocess": "none"
      }
    }
  }
}
```

## Entry Points

Python uses dual transport — both are required:

```python
# ASGI entrypoint (container deployment)
app = mcp.http_app()

# Stdio entrypoint (mpak / Claude Desktop)
if __name__ == "__main__":
    mcp.run()
```

| Context | Command | Entrypoint |
|---------|---------|------------|
| Containers | `uvicorn module.server:app` | `app = mcp.http_app()` |
| mpak / Claude Desktop | `python -m module.server` | `__main__` block |

The `app` object must exist at module level.

## Build System

`pyproject.toml` with hatchling:

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/mcp_<name>"]
```

Without this, `uv sync` won't install the package and module imports silently fail.

## Version Management

Three files must stay in sync:

| File | Field |
|------|-------|
| `manifest.json` | `version` |
| `pyproject.toml` | `version` |
| `src/mcp_<name>/__init__.py` | `__version__` |

Bump all at once: `make bump VERSION=0.2.0`

## Versioning Policy

All servers stay at v0.x.y until the MCP ecosystem stabilizes.

- **x** (minor): Notable changes, including breaking changes to tool definitions
- **y** (patch): Bug fixes and minor improvements

## Release Process

```bash
make bump VERSION=0.2.0
git add -A && git commit -m "Bump version to 0.2.0"
git tag v0.2.0 && git push origin main v0.2.0
gh release create v0.2.0 --title "v0.2.0" --notes "- changelog"
```

## Tooling

| Aspect | Tool |
|--------|------|
| Package manager | uv |
| Linting | ruff |
| Formatting | ruff |
| Type checking | ty |
| Testing | pytest + pytest-asyncio |

## Build Workflow (CI)

Uses mcpb-pack v2 with release trigger. Build matrix:

```yaml
strategy:
  matrix:
    include:
      - os: linux
        arch: amd64
        runner: ubuntu-latest
      - os: linux
        arch: arm64
        runner: ubuntu-24.04-arm
      - os: darwin
        arch: arm64
        runner: macos-latest
```

CI pipeline: `uv sync --dev` → `ruff format --check` → `ruff check` → `ty check` → `pytest`

## Template Substitutions

Immediately after cloning, `cd` into `mcp-<name>` and replace all template placeholders:

1. Rename the package directory:
   ```bash
   mv src/mcp_example src/mcp_<name>
   ```
2. Replace across all files (`*.py`, `*.toml`, `*.json`, `*.md`, `Makefile`, `.env.example`):
   - `mcp_example` → `mcp_<name>` (package name in imports, paths, logger)
   - `mcp-example` → `mcp-<name>` (project/bundle name)
   - `@nimblebraininc/example` → `@<github_owner>/<name>` (registry identifier)
   - `ExampleClient` → `<Name>Client` (class name)
   - `ExampleAPIError` → `<Name>APIError` (class name)
   - `EXAMPLE_API_KEY` → `<NAME>_API_KEY` (env var)
   - `https://api.example.com/v1` → leave as TODO for Phase 3 to fill with actual API URL
   - `https://example.com/settings/api` → leave as TODO for Phase 3
   - `mcp-server-example` → `mcp-server-<name>` (User-Agent)
   - `FastMCP("Example")` → `FastMCP("<display>")` (server display name)
   - `"example"` in `pyproject.toml` keywords → `"<name>"`
   - Update `pyproject.toml` URLs to use `mcp-<name>` repo name
   - Update README title and description to reference `<display>` instead of "Example"

After substitutions, grep for any remaining `example`/`Example`/`EXAMPLE`. Fix any hits. Then confirm to the user: "Template customized — all placeholder names replaced with `<name>`."

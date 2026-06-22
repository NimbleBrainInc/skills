# MCP Server Conventions (TypeScript)

## Critical

Package names MUST be scoped: `@<github_owner>/<name>`

Name must match the registry regex: `/^@[a-zA-Z0-9][a-zA-Z0-9-]{0,38}\/[a-z0-9][a-z0-9-]{0,213}$/`

The owner segment (before `/`) accepts mixed case — the registry normalizes it to lowercase. The package name (after `/`) must be lowercase.

Registry rejects other formats (e.g., `ai.nimbletools/name`, underscores in name).

## Naming

| Aspect | Value |
|--------|-------|
| Package scope | `@<github_owner>/<name>` |
| Module / package | `mcp-<name>` (hyphens) |
| Source directory | `src/` |
| Environment variable | `<NAME>_API_KEY` |

## Concept Mapping

| Concept | TypeScript |
|---------|------------|
| Response models | Zod `z.object()` in `types.ts` |
| Tool input validation | Zod schemas in `schemas.ts` |
| HTTP client | `fetch()` built-in |
| Tool registration | `server.registerTool()` call |
| Response formatting | `formatters.ts` → JSON.stringify |
| Error handling | `try/catch` → `errorResponse()` |

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
- `${__dirname}` — resolves to the bundle's install directory at runtime (use this for the entry point path)

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
  "display_name": "<Display Name>",
  "version": "0.1.0",
  "description": "...",
  "long_description": "...",
  "author": { "name": "NimbleBrain Inc", "email": "hello@nimblebrain.ai" },
  "license": "MIT",
  "keywords": [],
  "repository": {
    "type": "git",
    "url": "https://github.com/<github_owner>/mcp-<name>"
  },
  "compatibility": {
    "platforms": ["darwin", "linux", "win32"],
    "runtimes": { "node": ">=24.0.0" }
  },
  "user_config": {
    "api_key": {
      "type": "string",
      "title": "<Service> API Key",
      "description": "Your API key from...",
      "sensitive": true,
      "required": true
    }
  },
  "server": {
    "type": "node",
    "entry_point": "build/index.js",
    "mcp_config": {
      "command": "node",
      "args": ["${__dirname}/build/index.js", "--stdio"],
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

`${__dirname}/build/index.js` resolves correctly after bundling.

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
        "npm"
      ],
      "registryBaseUrl": "https://registry.npmjs.org",
      "identifier": "@<github_owner>/<name>",
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

After editing `manifest.json`, always run `make sync` to propagate the version to `package.json`, `server.json`, and `src/constants.ts`.

## Entry Points

TypeScript uses stdio only:

```typescript
const transport = new StdioServerTransport();
await server.connect(transport);
```

| Context | Command |
|---------|---------|
| mpak / Claude Desktop | `node build/index.js --stdio` |
| Local dev | `npm run dev` (uses tsx) |

## Build System

`tsconfig.json` with `outDir: "build"`. Key npm scripts:

```json
{
  "scripts": {
    "build": "tsc",
    "start": "node build/index.js --stdio",
    "dev": "tsx src/index.ts --stdio",
    "lint": "biome check src/ tests/",
    "format": "biome format --write src/ tests/",
    "format:check": "biome format src/ tests/",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "check": "npm run format:check && npm run lint && npm run typecheck && npm run test"
  }
}
```

Entry point is `build/` not `dist/`.

## Version Management

`manifest.json` is the single source of truth:

| File | Synced by |
|------|-----------|
| `manifest.json` | Edit directly |
| `package.json` | `make sync` |
| `server.json` | `make sync` |
| `src/constants.ts` | `make sync` |

Bump: `make bump VERSION=0.2.0` (updates manifest, then syncs).

Never edit `package.json`, `server.json`, or `src/constants.ts` versions manually.

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
| Package manager | npm |
| Linting | Biome |
| Formatting | Biome |
| Type checking | tsc --noEmit |
| Testing | Vitest |
| Dev runner | tsx |

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

CI pipeline: `npm ci` → `format:check` → `lint` → `typecheck` → `test` → `build` → bundle test

## Critical Notes

- Use **exact dependency versions** (no `^` or `~`) in `package.json` — range specifiers are L2 MTF security findings
- Use `.js` extensions in all imports (Node ESM requirement): `import ... from "./foo.js"`
- Never edit `src/constants.ts` manually — use `make sync`
- Never edit `.github/workflows/` — shared infrastructure
- The embedded SKILL.md lives in `src/` and is copied to `build/` during compilation

## Template Substitutions

Immediately after cloning, `cd` into `mcp-<name>` and replace all template placeholders across `*.ts`, `*.json`, `*.md`, `Makefile`, `CLAUDE.md`:

- `YOUR_SERVER_NAME` → `<name>`
- `YOUR_DISPLAY_NAME` → `<display>`
- `YOUR_REPO_NAME` → `mcp-<name>`
- `YOUR_API_KEY_ENV_VAR` → `<NAME>_API_KEY`
- `YOUR_API_HOST` → leave as TODO for Phase 3
- `YOUR_API_BASE_URL` → leave as TODO for Phase 3
- `YOUR_GITHUB_USERNAME` → `<github_owner>` (already detected in Phase 0b)
- `YOUR_SERVICE` → `<display>`

After substitutions, grep for any remaining `YOUR_`. Fix any hits. Then confirm to the user: "Template customized — all placeholder names replaced with `<name>`."

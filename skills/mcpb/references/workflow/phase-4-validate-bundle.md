# Phase 4: Validate Bundle

Validate the manifest, build the project, create the bundle, run MTF compliance scan, and verify the server responds correctly at runtime.

## 4a: Manifest Validation

Check `manifest.json` against the mpak registry schema. See `references/CONVENTIONS.md` for the full manifest format per language.

**Registry validation checklist** (read `manifest.json` and verify each):

1. **Name format** — must match `/^@[a-zA-Z0-9][a-zA-Z0-9-]{0,38}\/[a-z0-9][a-z0-9-]{0,213}$/` (e.g., `@JoeCardoso13/stripe`). The registry normalizes the owner to lowercase.
2. **Version** — valid semver string (e.g., `0.1.0`)
3. **server.type** — must be one of: `python`, `node`, `binary`
4. **server.mcp_config** — required object with:
   - `command` (string, required) — e.g., `"python"` or `"node"`
   - `args` (array of strings, required) — e.g., `["-m", "mcp_stripe.server"]`
   - `env` (object, optional) — maps env vars to `${user_config.<field>}` references
5. **user_config entries** — each must have:
   - `type` (required) — e.g., `"string"`
   - `sensitive: true` for secrets (API keys, tokens)
   - Referenced via `${user_config.<field>}` in `server.mcp_config.env`
6. **tools array** — each entry needs `name` (required) and `description` (recommended)
7. **Python-specific:** `server.type: "python"`, `entry_point` is module path
8. **TypeScript-specific:** `server.type: "node"`, `entry_point: "build/index.js"`, `${__dirname}` prefix in args

**mpak.json check** — verify `mpak.json` exists in repo root with:
```json
{
  "name": "@<github_owner>/<name>",
  "maintainers": ["<github_owner>"]
}
```
This file is required for package claiming on the registry. The `name` must match `manifest.json`.

## 4b: Build Validation

- **Python:** `uv sync` succeeds, entry point module is importable
- **TypeScript:** `npm run build` succeeds, `build/index.js` exists

## 4c: Bundle Inspection

- **Python:** `make bundle` (vendors deps into `deps/`, packs with `npx @anthropic-ai/mcpb pack`)
- **TypeScript:** `make bundle` (builds, prunes dev deps, packs)
- Both: no accidental large files (.git, node_modules), manifest.json present in bundle root

## 4d: MTF Compliance (if mpak-scanner available)

```bash
mpak-scanner scan .
```

## 4e: Runtime Validation

The MCP protocol requires an initialize handshake before any method calls. Send `initialize`, then `notifications/initialized`, then `tools/list`:

**Python:**
```bash
printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","method":"tools/list","id":2}\n' | uv run python -m mcp_<name>.server 2>/dev/null
```

**TypeScript:**
```bash
printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","method":"tools/list","id":2}\n' | node build/index.js --stdio 2>/dev/null
```

Both: server responds with valid JSON-RPC `initialize` result followed by `tools/list` result. No garbage on stdout (logs go to stderr).

## Gate

**Criteria:**
- [ ] `manifest.json` passes registry schema validation
- [ ] `mpak.json` exists with matching name
- [ ] Build succeeds and entry point is valid
- [ ] Bundle builds without accidental large files
- [ ] MTF scan passes (if mpak-scanner available)
- [ ] Runtime `tools/list` returns valid JSON-RPC response

**If any criterion fails:** Fix the issue and re-run the failing check.

**When all pass:** Proceed to Phase 5.

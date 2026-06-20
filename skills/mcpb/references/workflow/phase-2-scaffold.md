# Phase 2: Scaffold

Phase 0 created the repo from template and customized all placeholders. Verify the project structure is intact before implementation begins.

## 2a: Verify Structure

**Python** — check that these exist:
- `src/mcp_<name>/server.py`, `api_client.py`, `api_models.py`, `__init__.py`
- `tests/`
- `manifest.json`, `server.json`, `pyproject.toml`, `Makefile`
- `.github/workflows/ci.yml`, `.github/workflows/build-bundle.yml`
- `.gitignore`, `.mcpbignore`

**TypeScript** — check that these exist:
- `src/index.ts`, `config.ts`, `constants.ts`, `types.ts`, `schemas.ts`, `formatters.ts`
- `src/handlers/`, `src/utils/apiClient.ts`, `src/utils/errorResponse.ts`
- `tests/`
- `manifest.json`, `server.json`, `package.json`, `tsconfig.json`, `Makefile`
- `.github/workflows/ci.yml`, `.github/workflows/build-bundle.yml`
- `.gitignore`, `.mcpbignore`

If any files are missing, create them following the patterns in `references/PATTERNS.md`.

> **Fallback:** If `.gitignore` is missing (e.g., manual repo without template), generate it using the canonical content from `references/PATTERNS.md`. This prevents build artifacts (`bundle/`, `deps/`, `*.mcpb`), scanner reports, and secrets from being committed.

See `references/PATTERNS.md` for full directory structure reference.

## Gate

**Criteria:**
- [ ] All expected files exist for the chosen language
- [ ] Any missing files have been created from `references/PATTERNS.md`

**If any criterion fails:** Create missing files before proceeding.

**When all pass:** Proceed to Phase 3.

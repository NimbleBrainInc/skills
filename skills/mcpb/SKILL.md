---
name: mcpb
description: Build MCP servers end-to-end — scaffold a production-ready Python or TypeScript server from API docs, implement tools, validate the MCPB bundle, embed a skill resource, and release to the mpak registry. Covers the full lifecycle from API analysis to published bundle. Use when building a new MCP server, wrapping an API as MCP, or creating an integration. Triggers include "build an MCP server", "create a server for X", "/mcpb".
license: MIT
compatibility: Python 3.13+, uv, ruff, ty OR Node.js 22+, npm. Docker, mpak CLI. Claude Code or Codex with filesystem access.
allowed-tools: Read Write Bash Glob Grep WebFetch AskUserQuestion
metadata:
  area: build
  version: "0.1.0"
  author: NimbleBrain
---

# Build MCPB

Build MCP servers end-to-end: scaffold from API docs, implement tools, validate the bundle, create an embedded skill resource, and release to the mpak registry. Supports Python (FastMCP) and TypeScript (@modelcontextprotocol/sdk).

## Pipeline

Work through each phase in order. Read the linked workflow file for detailed instructions. Each phase has a gate that must pass before proceeding.

- [ ] **Phase 0 — Bootstrap:** Language, service name, repo creation, template setup. Read [references/workflow/phase-0-bootstrap.md](references/workflow/phase-0-bootstrap.md)
- [ ] **Phase 1 — API Analysis:** Fetch docs, identify resources, propose tools for approval. Read [references/workflow/phase-1-api-analysis.md](references/workflow/phase-1-api-analysis.md)
- [ ] **Phase 2 — Scaffold:** Verify project structure from template. Read [references/workflow/phase-2-scaffold.md](references/workflow/phase-2-scaffold.md)
- [ ] **Phase 3 — Implement & Verify:** Write tool logic, models, client; lint, typecheck, test. Read [references/workflow/phase-3-implement-and-verify.md](references/workflow/phase-3-implement-and-verify.md)
- [ ] **Phase 4 — Validate Bundle:** Manifest, build, bundle, MTF scan, runtime. Read [references/workflow/phase-4-validate-bundle.md](references/workflow/phase-4-validate-bundle.md)
- [ ] **Phase 5 — Embed Skill:** Create in-package skill resource, wire, verify. Read [references/workflow/phase-5-embed-skill.md](references/workflow/phase-5-embed-skill.md)
- [ ] **Phase 6 — Release:** Commit, push, cut release, verify publication. Read [references/workflow/phase-6-release.md](references/workflow/phase-6-release.md)

## References

Load the `{lang}`-appropriate file based on the language established in Phase 0c (`PY` for Python, `TS` for TypeScript).
- `references/CONVENTIONS-PY.md` / `CONVENTIONS-TS.md` — Naming, manifest, concept mapping, build system, entry points, template substitutions
- `references/PATTERNS-PY.md` / `PATTERNS-TS.md` — Implementation order, code patterns, directory structure, test patterns, CI workflows
- `references/SKILL_FORMAT-PY.md` / `SKILL_FORMAT-TS.md` — Embedded skill resource format, file location, wiring pattern

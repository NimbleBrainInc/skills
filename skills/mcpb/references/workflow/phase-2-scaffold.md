# Phase 2: Scaffold

Phase 0 created the repo from template and customized all placeholders. Verify the project structure is intact before implementation begins.

## 2a: Verify Structure

Verify that all expected files exist. The canonical directory structure is defined in:

`references/PATTERNS-{lang}.md` → "Directory Structure"

If any files are missing, create them from `references/PATTERNS-{lang}.md`.

> **Fallback:** If `.gitignore` is missing (e.g., manual repo without template), generate it using the canonical content from `references/PATTERNS-{lang}.md` → ".gitignore". This prevents build artifacts (`bundle/`, `deps/`, `*.mcpb`), scanner reports, and secrets from being committed.

## Gate

**Criteria:**
- [ ] All expected files exist for the chosen language
- [ ] Any missing files have been created from `references/PATTERNS-{lang}.md`

**If any criterion fails:** Create missing files before proceeding.

**When all pass:** Proceed to Phase 3.

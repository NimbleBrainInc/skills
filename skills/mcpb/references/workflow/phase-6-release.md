# Phase 6: Release

The contributor created and owns the repo — there is no PR to open. The goal is: code on `main` → GitHub Release → `build-bundle.yml` triggers → bundles built and published to the mpak registry.

## 6a: Pre-flight Checks

Before committing, verify the release will succeed:

1. **Version consistency** — Read the version from `manifest.json` and confirm it matches across all version sources.
   See `references/CONVENTIONS-{lang}.md` → "Version Management" for the files to verify.
   If anything is out of sync, run `make bump VERSION=<version>` to fix.
2. **`mpak.json`** — Must exist in the repo root with `name` matching `manifest.json`. Without it, the registry announce fails silently after the bundle builds.
3. **No secrets in working tree** — Check for `.env` files or anything containing real API keys. Warn the contributor if found; do not stage them.
4. **Skill resource wired** — Verify SKILL.md exists at the expected path
   (see `references/SKILL_FORMAT-{lang}.md` → "File Location") and the resource
   is registered in server code.

## 6b: Stage and Commit

Do not use `git add -A`. Review first, then stage explicitly:

1. Run `git status` and show the contributor what will be committed.
2. Stage server source, tests, skills, manifests, config, and workflow files. Do NOT stage `.env`, credentials, or debug artifacts.
3. Derive the version from `manifest.json` for the commit message:

```bash
VERSION=$(jq -r .version manifest.json)
git add <files...>
git commit -m "Add <service> MCP server v${VERSION}"
```

## 6c: Push

Do NOT push on the contributor's behalf. Ask them:

"Push your changes to GitHub: `git push origin main`"

## 6d: Verify CI

After the push, actively monitor CI — don't just point to a URL:

```bash
gh run list --repo <github_owner>/mcp-<name> --branch main --limit 1
gh run watch --repo <github_owner>/mcp-<name>
```

If CI fails: read the logs with `gh run view <run-id> --log-failed`, help the contributor diagnose and fix, then create a new commit (not amend).

## 6e: Cut Release

Once CI passes, derive the tag from `manifest.json`:

```bash
VERSION=$(jq -r .version manifest.json)
gh release create "v${VERSION}" --title "v${VERSION}" --generate-notes
```

## 6f: Monitor Bundle Build

The release triggers `build-bundle.yml` on 3 runners (linux-amd64, linux-arm64, darwin-arm64). Track it:

```bash
gh run list --repo <github_owner>/mcp-<name> --workflow=build-bundle.yml --limit 1
gh run watch --repo <github_owner>/mcp-<name>
```

If a runner fails, check logs with `gh run view <run-id> --log-failed`. Common issues:
- **Dependency vendor fails** — version conflicts in `pyproject.toml` / `package.json`
- **mcpb pack fails** — `manifest.json` format issues (re-check against Phase 4a checklist)
- **OIDC announce fails** — `mpak.json` missing or `name` doesn't match manifest

## Gate

**Criteria:**
- [ ] All 3 bundle runners succeed (linux-amd64, linux-arm64, darwin-arm64)
- [ ] Bundle is announced to the mpak registry

**If any criterion fails:** Check logs, fix the issue, create a new commit, and re-release.

**When all pass:**

"Your `<display>` MCP server is built, bundled, and announced to the mpak registry. It may take several minutes to propagate. Once live, anyone can run it:

```
mpak run @<github_owner>/<name>
```

To check availability:
```bash
mpak search <name>
```

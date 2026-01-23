# Skills Repository

Production-ready Agent Skills for Claude Code and AI coding assistants.

## Before Starting Work

**Always pull latest before making changes:**

```bash
git pull
```

This prevents conflicts with release-please commits that may have been merged.

## Before Pushing

**Always validate skills before pushing:**

```bash
./scripts/validate.sh
```

This checks all skill frontmatter against the registry schema. Catches invalid categories, malformed metadata, etc.

## DO NOT Manually Edit Version Files

**These files are managed automatically by release-please. Never edit them:**

- `version.txt` - updated when release PR merges
- `CHANGELOG.md` - auto-generated from commits
- `SKILL.md` `metadata.version` - synced at publish time
- `.release-please-manifest.json` - updated when release PR merges

If you accidentally edit these, **revert the changes** before committing. Only commit content changes to SKILL.md, not version bumps.

## Architecture

This is a **monorepo with independent versioning**. Each skill:
- Has its own version (in `version.txt` and `SKILL.md` metadata)
- Releases independently via release-please
- Gets its own tag (e.g., `blog-editor/v1.2.0`)
- Is announced separately to mpak.dev registry

## Directory Structure

```
skills/
├── .github/workflows/
│   ├── release-please.yml  # Creates releases + publishes
│   └── validate.yml        # Validates on PRs
├── release-please-config.json
├── .release-please-manifest.json
├── {skill-name}/
│   ├── SKILL.md           # Skill definition (frontmatter + content)
│   ├── version.txt        # Current version (managed by release-please)
│   └── CHANGELOG.md       # Auto-generated changelog
```

## Versioning Workflow

### Version Ownership (Who Updates What)

| File | Updated By | When |
|------|------------|------|
| `version.txt` | **release-please only** | When release PR merges |
| `.release-please-manifest.json` | **release-please only** | When release PR merges |
| `SKILL.md` `metadata.version` | **publish workflow** | At publish time (syncs from manifest) |

**IMPORTANT: Never manually bump versions.** release-please handles ALL version updates automatically based on your commit messages.

### Making Changes

1. **Edit the skill** (SKILL.md or supporting files)
2. **Commit with conventional commit format**:
   ```bash
   git commit -m "feat(skill-name): description of change"
   ```
3. **Push to main**
4. **release-please creates a PR** titled "chore(main): release skill-name X.Y.Z"
5. **Merge the PR** to publish

That's it. Do not touch version files.

### If Skill is Referenced in mcp-registry

Some skills are linked to MCP servers in `apps/mcp-registry`. After the release PR merges:

1. Update `servers/{server}/server.json` → `_meta["ai.nimbletools.mcp/v1"].skill.version`
2. Commit and push to mcp-registry

### Conventional Commits

The commit scope MUST match the skill directory name:

| Commit | Result |
|--------|--------|
| `fix(blog-editor): typo` | Patch bump (1.0.0 -> 1.0.1) |
| `feat(blog-editor): new feature` | Minor bump (1.0.0 -> 1.1.0) |
| `feat(blog-editor)!: breaking change` | Major bump (1.0.0 -> 2.0.0) |
| `chore(blog-editor): update deps` | No release (chore is ignored) |

### Never Do This

- Manually edit `version.txt` after initial creation
- Manually edit `.release-please-manifest.json` after adding a skill
- Manually edit `SKILL.md` version field
- Commit version bumps (e.g., "chore: bump version to X.Y.Z")

## Adding a New Skill

1. **Create directory**:
   ```bash
   mkdir new-skill
   ```

2. **Create SKILL.md** with frontmatter:
   ```markdown
   ---
   name: new-skill
   description: What it does. When to use it. Triggers include "phrase".
   metadata:
     version: 1.0.0
     category: category-name
     tags:
       - tag1
   ---

   # New Skill

   [Content...]
   ```

3. **Create version.txt**:
   ```
   1.0.0
   ```

4. **Add to release-please-config.json**:
   ```json
   "new-skill": {
     "release-type": "simple",
     "component": "new-skill"
   }
   ```

5. **Add to .release-please-manifest.json**:
   ```json
   "new-skill": "1.0.0"
   ```

6. **Commit**:
   ```bash
   git add .
   git commit -m "feat(new-skill): initial skill"
   git push
   ```

## Common Tasks

### Check Current Versions

```bash
cat .release-please-manifest.json | jq .
```

### Check Pending Release PRs

```bash
gh pr list --label "autorelease: pending"
```

### View Recent Releases

```bash
gh release list --limit 10
```

### Validate All Skills Locally

The validate workflow runs on PRs. To validate locally:

```bash
# Check SKILL.md exists and has required fields
for dir in */; do
  if [ -f "$dir/SKILL.md" ]; then
    echo "Checking $dir..."
    # Extract and validate frontmatter
    awk '/^---$/{if(f)exit;f=1;next}f' "$dir/SKILL.md" | yq .
  fi
done
```

## Workflow Files

### release-please.yml

Triggers on push to main. Two jobs:
1. **release-please**: Analyzes commits, creates/updates release PRs, creates releases
2. **publish**: When release created, packs skill into `.skill` bundle, uploads to release, announces to registry

### validate.yml

Triggers on push/PR to main. Validates all SKILL.md files have required frontmatter.

## Registry Announcement

Skills are announced to `https://api.mpak.dev/v1/skills/announce` with:
- Scoped name: `@nimblebraininc/{skill-name}`
- Version from manifest
- SKILL.md frontmatter as metadata
- SHA256 of the `.skill` bundle

## Troubleshooting

### Release PR Not Created

- Ensure commit uses conventional format with skill name as scope
- Check that the commit touched files in the skill directory
- Verify skill is listed in `release-please-config.json`

### Publish Failed

- Check workflow logs: `gh run view <run-id> --log-failed`
- Common issues:
  - OIDC token failure (permissions)
  - Registry announcement failure (retry usually works)

### Version Mismatch

- `version.txt` is source of truth
- `SKILL.md` metadata.version is synced at publish time
- If they drift, the publish workflow corrects it

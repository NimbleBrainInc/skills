# Agent Skills

A collection of production-ready skills for Claude Code and other AI coding assistants.

## Available Skills

| Skill | Description |
|-------|-------------|
| [blog-editor](./blog-editor) | Brutal content editor for blog posts and articles |
| [contrarian-thought-partner](./contrarian-thought-partner) | Adversarial critique for stress-testing ideas |
| [docs-auditor](./docs-auditor) | Audit documentation against codebase for accuracy |
| [qa-tester](./qa-tester) | Comprehensive QA engineer for test design and edge cases |
| [seo-optimizer](./seo-optimizer) | SEO analysis and optimization for content |
| [skill-author](./skill-author) | Create new skills from natural language descriptions |
| [strategic-thought-partner](./strategic-thought-partner) | Collaborative strategic thinking for decision-makers |
| [whitepaper-editor](./whitepaper-editor) | Technical white paper review with source verification |

## Installation

### Using mpak CLI

```bash
# Install a skill
mpak skill install @nimblebraininc/blog-editor

# List available skills
mpak skill search
```

### Manual Installation

Copy the skill folder to your project's `.claude/skills/` directory:

```bash
cp -r blog-editor /path/to/project/.claude/skills/
```

## Usage

Once installed, skills are automatically available in Claude Code. Invoke them by:

1. Using the Skill tool directly
2. Triggering with natural language (e.g., "review this draft" triggers blog-editor)

## Creating Your Own Skills

Use the `skill-author` skill to create new skills:

```
Build me a skill that reviews PRs for security issues
```

Or follow the [Agent Skills Specification](https://agentskills.io/specification).

## Publishing Skills

This repository uses the [skill-pack](https://github.com/NimbleBrainInc/skill-pack) GitHub Action to automatically:

1. Validate skills on push
2. Package skills into `.skill` bundles on release
3. Upload bundles to GitHub releases
4. Announce to the mpak registry

### Creating a Release

```bash
# Tag a release
git tag v1.0.0
git push origin v1.0.0

# Create release on GitHub (triggers skill-pack)
gh release create v1.0.0 --generate-notes
```

## Contributing

1. Fork this repository
2. Create a new skill in its own directory
3. Include a `SKILL.md` with proper frontmatter
4. Submit a pull request

### Skill Requirements

Each skill must have:

- A directory named after the skill (kebab-case)
- A `SKILL.md` file with YAML frontmatter containing:
  - `name` (must match directory name)
  - `description` (what it does and when to use it)
  - `metadata.version` (semver)

Example:

```markdown
---
name: my-skill
description: Does X when Y. Use when Z. Triggers include "phrase 1", "phrase 2".

metadata:
  version: 1.0.0
  category: development
  tags:
    - tag1
    - tag2
---

# My Skill

[Skill content...]
```

## License

MIT

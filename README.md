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

## Versioning

This repository uses **independent versioning** with [release-please](https://github.com/googleapis/release-please). Each skill has its own version and releases independently.

### How It Works

1. Make changes to a skill
2. Commit with [conventional commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat(blog-editor): add tone detection"
   ```
3. Push to main
4. release-please creates a PR for that skill (e.g., "chore(main): release blog-editor 1.2.0")
5. Merge the PR to publish

### Conventional Commits

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix(skill):` | Patch (1.0.0 -> 1.0.1) | `fix(blog-editor): typo in prompt` |
| `feat(skill):` | Minor (1.0.0 -> 1.1.0) | `feat(blog-editor): add tone analysis` |
| `feat(skill)!:` | Major (1.0.0 -> 2.0.0) | `feat(blog-editor)!: new output format` |

### Tag Format

Tags follow the pattern `{skill-name}/v{version}`:
- `blog-editor/v1.2.0`
- `skill-author/v2.0.0`

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
- A `version.txt` file with the current version

Example structure:

```
my-skill/
├── SKILL.md
└── version.txt
```

Example SKILL.md:

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

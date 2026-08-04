# Skill Authoring Guide

How to create and publish an mpak skill.

## Directory Structure

```
my-skill/
├── SKILL.md          # Required — main skill file with YAML frontmatter
├── references/       # Optional — supporting docs the skill can read
│   ├── GUIDE.md
│   └── PATTERNS.md
├── scripts/          # Optional — helper scripts
├── assets/           # Optional — images or other assets
├── CHANGELOG.md      # Optional — version history
└── version.txt       # Optional — version string
```

## SKILL.md Format

### Frontmatter (YAML)

```yaml
---
name: my-skill                    # Required — must match directory name
description: >-                   # Required — one-line description shown in
  What this skill does and when    #   search results and skill listings
  to use it.
version: 0.1.0                   # Required — semver
license: Apache-2.0              # Recommended
compatibility: >-                # What the skill needs to run
  Python 3.13+, uv, gh CLI
allowed-tools: Read Write Bash   # Space-separated tool names the skill uses
metadata:
  tags:                          # Searchable tags
    - mcp
    - automation
  category: development          # One of: development, productivity, design, etc.
  triggers:                      # Phrases that activate this skill
    - build something
    - /my-command
  keywords:                      # Additional search terms
    - automation
  surfaces:                      # Where the skill works
    - claude-code
    - claude-api
    - claude-ai
  author:
    name: Your Name
    url: https://example.com
  examples:                      # Optional — example prompts
    - prompt: Do the thing
      context: When starting fresh
---
```

### Body Content

The body is pure markdown — no executable code. Write instructions **to the agent** in imperative voice.

**Effective structure:**

1. **Title & one-line purpose** — what the skill does
2. **Quick Start** — how users invoke it (e.g., `/my-command`)
3. **Calibration** — if the skill has multiple paths, ask the user which one
4. **Process sections** — step-by-step procedures with numbered lists
5. **Rules** — hard constraints the agent must follow

**Tips:**

- Use tables for tool selection guides, decision matrices, field mappings
- Use numbered lists for sequential steps, bullets for options
- Reference files in `references/` with `Read references/FILENAME.md`
- Be opinionated — guide specific workflows, don't explain generically
- Include "learn more" options so users can dig deeper without blocking progress

## Validation

```bash
mpak skill validate ./my-skill/
```

Checks:
- Directory exists
- `SKILL.md` exists
- Frontmatter parses correctly
- Schema validation (name, description required)
- Directory name matches skill name

## Packing

```bash
mpak skill pack ./my-skill/ -o my-skill-0.1.0.skill
```

Creates a `.skill` ZIP bundle with SHA256 verification.

## Publishing

Skills are published to the mpak registry via GitHub releases, similar to bundles. The registry verifies provenance and runs security scans.

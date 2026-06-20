# NimbleBrain Skills

Agent Skills for building on and working with NimbleBrain — installable into Claude Code, Cursor, and any agent that supports the [Agent Skills standard](https://agentskills.io).

Each skill is a self-contained directory (`skills/<name>/SKILL.md` + optional `references/`). Skills are coarse and named for what you're doing — you install the one that matches your task, not a pile of micro-skills.

## Install

```bash
# one skill (the common case)
npx skills add nimblebraininc/skills --skill synapse

# the whole set
npx skills add nimblebraininc/skills

# list what's available
npx skills add nimblebraininc/skills --list
```

Or as a Claude Code plugin marketplace:

```bash
claude plugin marketplace add nimblebraininc/skills
```

## Available skills

| Skill | Install | What it does |
|-------|---------|--------------|
| [`synapse`](./skills/synapse) | `--skill synapse` | Build a Synapse UI for an MCP server — a React app that renders in the NimbleBrain host. |
| [`mcpb`](./skills/mcpb) | `--skill mcpb` | Build an MCP server end-to-end: scaffold from API docs → implement → validate the bundle → release to mpak. |
| [`contributor`](./skills/contributor) | `--skill contributor` | Get started contributing to NimbleBrain open source: find work, set up your env, file issues, check on your work. |

## Contributing

A skill is a directory `skills/<name>/` containing a `SKILL.md` with YAML frontmatter:
- **`name`** — kebab-case, must equal the directory name.
- **`description`** — what it does *and* when to use it, with trigger phrases (this is the activation surface).
- Optional `license`, `compatibility`, `allowed-tools`, and free-form `metadata` (`area`, `version`, `author`).

Keep the `SKILL.md` body focused; push depth into `references/`. See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

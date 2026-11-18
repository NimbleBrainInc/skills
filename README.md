# NimbleBrain Skills

Agent Skills for [NimbleBrain](https://github.com/NimbleBrainInc/nimblebrain), the
open-source runtime that runs agents and MCP apps on your own machine with any model.
They install into Claude Code, Cursor, Codex and any agent that supports the
[Agent Skills standard](https://agentskills.io).

## Start here: `nimblebrain`

```bash
npx skills add nimblebraininc/skills --skill nimblebrain
```

The [`nimblebrain`](./skills/nimblebrain) skill sets NimbleBrain up on your machine,
connects your agent to it over MCP, and works inside it. Ask your agent to "set up
NimbleBrain". If you would rather run it yourself, `npx nimblebrain` does the same
setup and installs this skill for your agent at the end.

## Building for NimbleBrain

Install the one for the job.

| Skill | Install | What it does |
|-------|---------|--------------|
| [`synapse`](./skills/synapse) | `--skill synapse` | Build a Synapse UI for an MCP server: a React app that renders inside NimbleBrain, Claude and ChatGPT. |
| [`mcpb`](./skills/mcpb) | `--skill mcpb` | Build an MCP server end to end: scaffold from API docs, implement, validate the bundle, release to mpak. |
| [`mcp-best-practices`](./skills/mcp-best-practices) | `--skill mcp-best-practices` | Name, describe and shape an MCP server's tools so a model calls them well. |

## Contributing to NimbleBrain

| Skill | Install | What it does |
|-------|---------|--------------|
| [`contributor`](./skills/contributor) | `--skill contributor` | Contribute to NimbleBrain open source: find work, set up your environment, file issues, check on your work. |

## Other ways to install

```bash
# everything
npx skills add nimblebraininc/skills

# list what's here
npx skills add nimblebraininc/skills --list

# as Claude Code plugins
claude plugin marketplace add nimblebraininc/skills
claude plugin install nimblebrain@nimblebrain-skills
claude plugin install nimblebrain-builder@nimblebrain-skills
claude plugin install nimblebrain-contributor@nimblebrain-skills
```

The plugins group the skills above: `nimblebrain` is the flagship skill,
`nimblebrain-builder` the three building skills, `nimblebrain-contributor` the
contributor skill.

## Writing a skill

A skill is a directory `skills/<name>/` containing a `SKILL.md` with YAML frontmatter:

- **`name`**: kebab-case, equal to the directory name.
- **`description`**: what it does *and* when to use it, with trigger phrases. This is
  what an agent reads to decide whether to load the skill.
- Optional `license`, `compatibility`, `allowed-tools`, and free-form `metadata`
  (`area`, `version`, `author`).

Keep the `SKILL.md` body focused and push depth into `references/`. A new skill also
goes into a plugin in `.claude-plugin/marketplace.json`.

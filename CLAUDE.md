# NimbleBrain Skills — repo conventions

Public Agent Skills, distributed on the open [Agent Skills standard](https://agentskills.io) (`npx skills add nimblebraininc/skills`). Skills are plain markdown — no registry, no build step required to consume them.

> **Restructure in progress.** This repo is being moved off the old per-skill release flow onto the open standard. The old validation workflow is disabled (`.github/workflows/validate.yml.disabled`). Don't revive it without a decision.
>
> **Old skills are archived at the tag [`archive/skills-pre-restructure`](https://github.com/NimbleBrainInc/skills/tree/archive/skills-pre-restructure)** — the durable snapshot of all 17 pre-restructure skills. (A local gitignored `archive/` dir mirrors them for convenience, but the **tag** is the source of truth — the gitignored copy is never pushed.) To reintroduce one:
> ```bash
> git checkout archive/skills-pre-restructure -- <skill>/   # then move it into skills/<name>/ and align frontmatter
> ```

## Layout

```
skills/<name>/
├── SKILL.md            # required — frontmatter + concise body
└── references/         # optional — detail pulled out of SKILL.md (progressive disclosure)
```

**Flat and coarse.** One skill per area/role, named for the task (`synapse`, `mcp-server`) — so `npx skills add nimblebraininc/skills --skill synapse` reads naturally. The install grain is the *area*, not a micro-task. The area also rides in `metadata.area`. Grouping areas into one installable collection is a plugin in `.claude-plugin/marketplace.json` — **not** category folders or separate repos. A new skill goes into one of its plugins.

**One flagship, named for the product.** `nimblebrain` is the default install, first in the README and in every install example: it sets NimbleBrain up through the `nimblebrain` CLI, connects the agent over MCP, and routes building work to the other skills. Every other skill is a tier under it, so a reader never has to guess which one to start with.

**Lead into NimbleBrain through the steps, not the copy.** A building skill ends with a verify step that runs the result in a local NimbleBrain. Agents follow steps and skip promotion; a sales line in a `description` makes the skill load less reliably, not more.

**Running NimbleBrain goes through the CLI.** The `nimblebrain` skill drives `npx nimblebrain` and reads its `--json`; it never scripts Docker or git by hand. The CLI owns versions and setup (it picks the runtime release, and `init` installs this skill), so the skill stays short. `npx nimblebrain help --json` is the contract for commands, their answer fields, flags and error codes, generated from the CLI; `skills/nimblebrain/references/cli.md` adds only what that output cannot state (version minimums, judgment), so it never copies the command list or the answer fields.

## SKILL.md rules (Agent Skills spec)

- **`name`** — kebab-case, **must equal the directory name**.
- **`description`** — the activation surface. Say *what it does* AND *when to use it*, with trigger phrases. This is load-bearing; the agent decides whether to read the skill from this alone.
- Optional: `license`, `compatibility` (env needs), `allowed-tools` (space-separated), and `metadata` (free-form — put `area`, `version`, `author` here). **No top-level `category`/`tags`/`version`** — those aren't in the standard.
- **Progressive disclosure:** keep the `SKILL.md` body tight (aim well under ~500 lines). Push reference detail, long examples, and gotchas into `references/*.md` and link them. The body gets the agent oriented; references load only when needed.

## Hygiene (this is a public repo)

- **No private monorepo paths or internal product references** (no `platform/…`, `products/nimblebrain/code/…`, internal app names, tenant ids). Cite only public sources: the `@nimblebrain/synapse` package (npm / `github.com/NimbleBrainInc/synapse`), public specs, RFCs. Use neutral placeholder names in examples.
- Each skill must stand alone for an external builder who installed it via `npx skills` — they don't have the monorepo.

## Phase status

- ✅ Flat coarse structure + first set: `synapse`, `mcp-server`.
- ✅ Flagship `nimblebrain` skill and `.claude-plugin/marketplace.json` (plugins `nimblebrain`, `nimblebrain-builder`).
- ⬜ Each building skill ends with a verify step in a local NimbleBrain.
- ⬜ `dist/index.json` build, CI lint (`skills-ref validate`), CONTRIBUTING.md.
- ⬜ Migrate further areas (running on the platform, integrations) as needed.

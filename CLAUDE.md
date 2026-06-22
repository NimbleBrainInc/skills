# NimbleBrain Skills — repo conventions

Public Agent Skills, distributed on the open [Agent Skills standard](https://agentskills.io) (`npx skills add nimblebraininc/skills`). Skills are plain markdown — no registry, no build step required to consume them.

> **Restructure in progress.** This repo is being moved off the old per-skill release-please + mpak-announce flow onto the open standard. The old workflows are disabled (`.github/workflows/*.disabled`). Don't revive them without a decision.
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

**Flat and coarse.** One skill per area/role, named for the task (`synapse`, `mcpb`, `contributor`) — so `npx skills add nimblebraininc/skills --skill synapse` reads naturally. The install grain is the *area*, not a micro-task. The area also rides in `metadata.area`. Grouping several areas into one installable collection is a future `.claude-plugin/marketplace.json` plugin — **not** category folders or separate repos.

## SKILL.md rules (Agent Skills spec)

- **`name`** — kebab-case, **must equal the directory name**.
- **`description`** — the activation surface. Say *what it does* AND *when to use it*, with trigger phrases. This is load-bearing; the agent decides whether to read the skill from this alone.
- Optional: `license`, `metadata` (free-form — put `area`, `version`, `author` here). **No top-level `category`/`tags`/`version`** — those aren't in the standard.
- **Progressive disclosure:** keep the `SKILL.md` body tight (aim well under ~500 lines). Push reference detail, long examples, and gotchas into `references/*.md` and link them. The body gets the agent oriented; references load only when needed.

## Hygiene (this is a public repo)

- **No private monorepo paths or internal product references** (no `platform/…`, `products/nimblebrain/code/…`, internal app names, tenant ids). Cite only public sources: the `@nimblebrain/synapse` package (npm / `github.com/NimbleBrainInc/synapse`), public specs, RFCs. Use neutral placeholder names in examples.
- Each skill must stand alone for an external builder who installed it via `npx skills` — they don't have the monorepo.

## Phase status

- ✅ Flat coarse structure + first set: `synapse`, `mcpb`, `contributor` (ported from `contributor-toolkit`).
- ⬜ Archive `NimbleBrainInc/contributor-toolkit` (its two skills now live here).
- ⬜ `.claude-plugin/marketplace.json`, `dist/index.json` build, CI lint (`skills-ref validate`), CONTRIBUTING.md.
- ⬜ Migrate further areas (running on the platform, integrations) as needed.

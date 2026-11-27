---
name: mcp-server
description: Builds an MCP server, or the server half of an MCP app, for NimbleBrain or any MCP host, and reviews an existing server's tools so a model calls them well. Designs the tools before code, implements them with nimblebrain-server-sdk, tests them on both protocol eras against a golden record, serves over HTTP, connects the server to a local NimbleBrain, and ships it as a container. Use to wrap an API or a system as MCP tools, add tools to a server, or audit a server's names, descriptions, schemas, annotations and boundary. Triggers include "build an MCP server for X", "wrap this API as MCP", "add a tool to my MCP server", "review this MCP server", "why won't the model call my tool".
license: MIT
compatibility: Python 3.13+ with uv (the default), or Node.js 24+ with npm (TypeScript). npx, for the MCP Inspector. Reviewing needs only a running server or its launch command, in any language.
allowed-tools: Read Write Edit Bash Glob Grep WebFetch AskUserQuestion
metadata:
  area: build
  version: "0.2.0"
  author: NimbleBrain
---

# MCP server

Two ways in: **build** a server, or **review** one. Both judge the server by what it
advertises over the wire, against the rungs in `references/design.md`.

A server built here is a plain MCP server: any MCP host can connect to it. It runs as a
service over streamable HTTP, and a host connects to it by URL. NimbleBrain works this
way: it never downloads or runs a bundle. An `.mcpb` bundle is only for desktop hosts
that install a local server from a file, and it is optional (`references/packaging.md`).

## Build a server

### 1. Connector or app

Ask first, in one question:

- **A connector** is a server alone. The agent uses it through its tools (search a
  ticket system, send an email).
- **An app** is a server plus an interface people use inside the host (a task board the
  agent and the team both edit). This skill builds its server; the `synapse` skill builds
  the interface, at step 8.

Start with the server either way. An app is a connector with an interface added, so
nothing is thrown away.

Also settle: the system or API it wraps, how it authenticates (API key, OAuth, none),
and whether its data is one person's or shared.

### 2. Start a repository, with maintained servers as the reference

Python with `nimblebrain-server-sdk` is the default. Start a new repository
(`references/python.md` has the commands and the layout), and read two maintained public
servers for how each part is done, rather than copying a template that drifts:

- [`NimbleBrainInc/todosforagents`](https://github.com/NimbleBrainInc/todosforagents): a
  store, paging, a UI, prompts, a local runtime, golden records of its surface.
- [`NimbleBrainInc/mcp-careers`](https://github.com/NimbleBrainInc/mcp-careers): a small
  stateless server shipped as a container, with a person-confirmed write.

TypeScript is the fallback, for a person who asks for it or a Node codebase
(`references/typescript.md`). Read the reference for the language now.

### 3. Propose the tools, then design them

Read the API's documentation (and an OpenAPI document if it has one): auth, base URL,
the resources and their operations, pagination, error shapes. Then propose the tool set
to the person before writing code:

```
Acme Tickets API: https://api.acme.example/v2, bearer token
Proposed tools (5):
  acme_search_tickets  reads    find tickets by text, status or assignee
  acme_get_ticket      reads    one whole ticket, with its comments
  acme_add_comment     adds     comment on a ticket
  acme_update_ticket   changes  set status, assignee or priority
  acme_list_queues     reads    the queues a ticket can move to
Proceed?
```

Design for what the agent will be asked to do, not one tool per endpoint: fewer tools
that each do a whole task are easier to choose between. Apply every rung in
`references/design.md` to the proposal (names, the description's *when to call*, a
`description` on every property, bounded results, the annotation kind, the boundary)
and fix what fails before you write a handler. Wait for the person's yes.

### 4. Implement

With `nimblebrain-server-sdk` (`references/python.md`):

- **Annotate every tool** `READS`, `ADDS` or `CHANGES`. An unannotated tool reads to a
  host as a destructive write.
- **Fail through the error contract.** Raise `ServiceError(ErrorCode.X, "...")`, or
  `ServiceError.from_upstream(status, detail=...)` for an upstream failure, and call
  `add_error_contract(mcp)` once. Never return a dict that describes an error.
- **Bound listings.** `listing_row` turns an unbounded field into a preview, and each row
  carries a `uri` that a resource template reads back whole.
- **Give every tool a `title`, a typed result and its hints.** A Pydantic return type
  becomes the `outputSchema`; set `idempotent_hint` and `open_world_hint` when you know them.
- **Start every error message with its code** (`bad_input: …`) and name the rule that
  failed. Some clients show the model only the text.
- **Publish a skill** for the agent: a `skills/<name>/SKILL.md` registered with
  `add_skills`, served at `skill://<name>/SKILL.md`. Never register `skill://` resources
  by hand.
- **A write that must come from a person** (an application, a signup) returns a
  confirmation link instead of writing; the person confirms on a page with a human check.
  Never fetch a caller's URL you only pass along. `references/security.md`.

In TypeScript, write the same four against the protocol (`references/typescript.md`).

### 5. Test

Unit tests with the upstream mocked, every tool's success and failure paths, run on
both protocol eras (`2026-07-28` and `2025-11-25`), since a host may connect on either
(TypeScript: `2025-11-25` only, per `references/typescript.md`).
Record the advertised surface in golden files, one per protocol era, so a changed
description, schema or annotation fails the test and shows in review
(`references/python.md`). Then the whole check: format, lint, types, tests, and
`uv sync --locked` in Python, or `npm run check` in TypeScript. Do not move on with a
failing check.

### 6. Serve it over HTTP, with a Server Card

Run the server over streamable HTTP on loopback, at a URL like
`http://127.0.0.1:8000/mcp`. With SDK 0.8.0 or later, call `add_server_card(mcp,
title=..., description=...)` so a host can name and describe the server before it
connects; check `curl -s http://127.0.0.1:8000/mcp/server-card`. An app's server also
passes `placements`. Commands and rules: `references/python.md`.

### 7. Connect it to a local NimbleBrain, and review the live surface

The `nimblebrain` skill sets up a local NimbleBrain (`npx nimblebrain`); use it if none
is running. Then, with the server running:

```bash
npx nimblebrain mcp add http://127.0.0.1:8000/mcp --json
```

This needs CLI 0.3.0 or later and runtime v0.76.0 or later (`npx nimblebrain update`
moves an older install; `UPDATE_REQUIRED` says so). It accepts only `localhost`,
`127.0.0.1` and `::1` URLs, adds the server to the workspace the coding agent is
connected to, and reads its Server Card for the name and placements. The server stays
added across restarts of either side. **On Linux**, NimbleBrain reaches the host through
the Docker bridge, so bind the server to the bridge address (usually `172.17.0.1`) or
`0.0.0.0`, not `127.0.0.1`; say that `0.0.0.0` also exposes it to the network.
The [CLI guide](https://docs.nimblebrain.ai/cli/nimblebrain/#developing-a-server) has the
details.

Ask the agent in that workspace to do a real task with the tools, including a write. Then
smoke-test it with a fresh agent: a subagent with no context, told only the server's URL
and a persona, follows the server's own skill end to end, including failure cases, and
reports where the skill, descriptions or errors left it guessing. Then review the live
surface: run the review flow below against the running server, and fix every finding
before calling the build done.

### 8. An app: hand off to `synapse`

For an app, the `synapse` skill builds the interface: a `ui://` resource the server
serves with FastMCP's `AppConfig`, and the tools bound to it. Install it if it is
missing (`npx skills add nimblebraininc/skills --skill synapse`).

### 9. Write the server's `server.json` for deployment

Every server gets a `server.json` beside its Server Card: an MCP Registry `ServerDetail`
with its `$schema`, restating the card's `name`, `title`, `description`, `version`,
`icons` and `_meta["ai.nimblebrain/host"].placements`, plus the production `remotes`
(`[{"type": "streamable-http", "url": "<deployed URL>"}]`) and, for a published package,
`packages`. The card serves a host that has only a URL (a local NimbleBrain's `mcp add`);
`server.json` is what an operator adds to a deployed NimbleBrain's connectors catalog,
and what `mcp-publisher` lists on the official MCP Registry. The code is the one source
of metadata: compare `curl -s <url>/server-card` with `server.json` and keep them in
agreement. Example, rules and publishing: `references/deploy.md`.

### 10. Ship it as a container

A server a host reaches by URL ships as an image: a locked dependency set, digest-pinned
images, build and push on merge with a staging roll, and releases that retag the image
staging ran. Serve the MCP endpoint stateless, so any replica answers any request. After launch, a breaking change to a tool's inputs takes a new tool name,
because connected clients keep old schemas. `references/deploy.md`.

### 11. Package it (optional)

Only if people will run it on their own machine: publish the package to PyPI or npm,
then wrap it in a bundle for desktop hosts. `references/packaging.md`. Add the package
to `server.json`'s `packages` once it is published.

### Done

Report: the repository, the tools and their kinds, the checks that passed, the URL it
serves on, its `server.json` (in agreement with the card), that it is connected in
NimbleBrain and which task the agent completed with it, what the fresh-agent smoke test
found, and the review's findings and how each was resolved.

## Review a server

For any MCP server, in any language. The output is a ranked list of findings against the
rungs, with passes and unchecked rungs stated.

1. **Read the advertised surface, not the source.** Run the server (or take its URL) and
   read `tools/list`, `resources/list`, `resources/templates/list`, `prompts/list` and
   `initialize` with the MCP Inspector CLI, naming the protocol era. The commands, and
   why source review misleads, are in `references/design.md`.
2. **Record the protocol version it negotiated and the eras it serves**, and the size of
   each description and of the whole `tools/list` payload.
3. **Apply every rung in `references/design.md`** (Find, Choose, Fill, Read, Act, Trust)
   to every advertised tool, resource and prompt. For resources and prompts, add
   `references/resources-and-prompts.md`; for Trust, read `references/security.md`.
4. **Cite, don't paraphrase.** Each finding names its rung and quotes the rule from
   `references/spec-citations.md` or `references/security.md` at the strength the source
   gives it (`MUST`, `SHOULD`, or this skill's reasoning).
5. **Verify each finding against the wire** before reporting it. A rule the framework
   already satisfies is not a finding.

The review is done when the completion criterion at the end of `references/design.md`
holds.

### Report shape

Lead with the surface as it stands, then the findings ranked by what they cost.

```
SURFACE REVIEW — example-server (3 tools, 0 resources, 0 prompts)

PROTOCOL    2026-07-28 negotiated (auto) · serves 2026-07-28 and 2025-11-25
            citations pinned to 2026-07-28

SURFACE     tools/list payload 12,400 chars (~3,100 tokens, loaded every conversation)
            create_invoice 835 · upgrade 303 · list_customers 443

FINDINGS
  1  Choose   create_invoice describes capability, states no trigger
              → model has no cue to volunteer it; highest-yield fix
  2  Act      list_customers carries no annotations
              → reads to the host as a destructive write; it may ask to confirm a read
  3  Fill     create_invoice — 4 of 4 params carry no schema description
              → on this framework the docstring Args block never reaches the schema
  4  Find     `upgrade` is generic; collides across aggregated servers

PASSES      Find (charset/length), Read (isError, outputSchema), Trust (audience
            validation, SSRF guard on fetch targets)

UNCHECKED   Trust (scope minimization) — server declares no scopes to inspect
```

Then, briefly: what to fix first and why that order. Rank by whether the model's or the
host's behaviour changes, not by how many rules a fix touches.

## References

- `references/design.md`: the rungs, reading the surface with the Inspector, the completion criterion
- `references/spec-citations.md`: MCP `2026-07-28` and vendor rules to quote in findings
- `references/security.md`: the boundary rules (tokens, SSRF, state handles, person-confirmed writes, scopes, local servers)
- `references/resources-and-prompts.md`: field, URI-scheme and error rules for those primitives
- `references/python.md`: starting a repository, `nimblebrain-server-sdk`, and golden records
- `references/typescript.md`: the TypeScript template, and writing the same against the protocol
- `references/deploy.md`: shipping as a container, changing a live server safely, `server.json`, a catalog entry, and the official MCP Registry
- `references/packaging.md`: publishing the package, and a `uv` bundle for desktop hosts

# The NimbleBrain Ecosystem

> Agent-facing reference. Read this before orienting a new contributor so you can explain
> the ecosystem at whatever depth they need — from a one-liner to a deep technical dive.

---

## The Stack at a Glance

```
NimbleBrain Platform (Studio + AI agent)
        │  uses
        ▼
    Skills  ──────────────────────────────────────────────┐
        │  compose tools from                             │
        ▼                                               published via
   MCP Servers (MCPB bundles)                            mpak
        │  distributed by                                 │
        ▼                                                 │
      mpak  ◄─────────────────────────────────────────────┘
   (build + distribute + execute)
        │  implements
        ▼
   MCPB bundle format
        │  runs over
        ▼
   MCP Protocol
```

---

## Layer 1: MCP Protocol

The **Model Context Protocol** (MCP, by Anthropic) standardizes how AI assistants
interact with external tools. An MCP server exposes:

- **Tools** — functions the AI can call (e.g., `query_database`, `send_email`)
- **Resources** — data the AI can read (e.g., file contents, API responses)
- **Prompts** — templated interactions

Servers communicate over stdio (local) or HTTP (remote). The protocol handles capability
negotiation, request/response framing, and error handling.

**One-liner for users:** "MCP is the standard that lets AI assistants use real tools — like
Notion, Stripe, or a database — as if they were built in."

> **Resources:** See `RESOURCES.md` → *MCP Specification*

---

## Layer 2: MCPB Bundle Format

The **MCPB specification** (by the MCP community) defines how to package an MCP server
into a portable, self-contained bundle:

```
bundle.mcpb  (ZIP archive)
├── manifest.json     ← how to run the server + what config it needs
├── src/              ← server source code
└── deps/             ← vendored dependencies (no install step needed)
```

The `manifest.json` is the core:
- `mcp_config` — exact command to spawn the server
- `user_config` — declares required credentials (API keys, settings) with types and
  sensitivity flags

**Why not just use pip or npm?** MCP servers are standalone services, not libraries.
Traditional package managers create shared dependency trees, require the user to figure
out execution, and have no concept of "this needs an API key." MCPB bundles vendor
everything, declare exactly how to run, and carry their configuration schema with them.

**Analogy for Docker users:** MCPB bundles are like Docker images — platform-specific,
self-contained, with a declared entry point — but 4x smaller and with no daemon required.

> **Resources:** See `RESOURCES.md` → *MCPB Specification*

---

## Layer 3: mpak

**mpak** (by NimbleBrain) is the infrastructure that turns MCPB from a spec into a
usable ecosystem. It has three components:

### mcpb-pack (GitHub Action)

Automates bundle creation in CI/CD on every GitHub Release:
1. Detects runtime (Python → `uv`, Node → `npm`)
2. Vendors dependencies into the bundle
3. Runs `mcpb pack` to create the `.mcpb` file
4. Uploads the bundle to the GitHub Release as a binary asset
5. Announces to the mpak registry using OIDC (no API keys — GitHub vouches for identity)

Runs in a **matrix** across 3 platforms simultaneously:

| Runner | Platform |
|--------|----------|
| ubuntu-latest | linux/amd64 |
| ubuntu-24.04-arm | linux/arm64 |
| macos-latest | darwin/arm64 |

Each runner independently builds and announces its artifact. The registry is idempotent —
the first announce creates the version, the rest add their platform artifacts to it.

### mpak.dev (Registry)

The distribution registry. Complements the MCP Registry (which handles *discovery*)
with *distribution*:

| MCP Registry | mpak Registry |
|--------------|---------------|
| "What servers exist?" | "Where do I download them?" |
| Links to source repos | Links to platform-specific bundles |
| Source-oriented | Artifact-oriented |

mpak does **not** store artifacts — bundles stay on GitHub Releases. The registry indexes
metadata, resolves the right platform artifact for your machine, and verifies provenance.

**Security model:** OIDC-based. No credentials to steal. GitHub cryptographically signs
a token proving a bundle came from a specific repo. `@nimblebraininc/*` packages can
only be announced by workflows running in the `NimbleBrainInc` GitHub org. Once
published, versions are **immutable** — no silent replacements possible.

### mpak CLI

The user-facing tool. One command to run any published MCP server:

```bash
mpak run @nimblebraininc/stripe      # fetches, caches, configures, and runs
mpak search notion                   # discover available servers
mpak config set @org/server key=val  # store credentials
```

Cold start (first run): ~2–5 seconds. Warm start (cached): milliseconds.

> **Resources:** See `RESOURCES.md` → *mpak Registry*, *mpak CLI Documentation*,
> *mpak Whitepaper*, *mpak CLI Source*, *mcpb-pack Action Source*

---

## Layer 4: Skills

**Skills** are reusable workflow compositions that sit on top of MCP servers. Where an
MCP server exposes raw tools (e.g., `create_invoice`, `list_customers`), a skill composes
those tools into a complete workflow (e.g., "onboard a new customer end-to-end").

In the embedded model, each MCP server contains a single `SKILL.md` file inside the
server package, exposed as an MCP resource at `skill://<name>/usage`. The server's
`instructions` parameter tells the LLM to read the skill resource before using tools.

Skills are:
- A single Markdown file (`SKILL.md`) — no frontmatter, no separate validation
- Embedded inside the server package (`src/mcp_<name>/SKILL.md` for Python, `src/SKILL.md` for TypeScript)
- Exposed as an MCP resource the LLM reads automatically
- Shipped with the `.mcpb` bundle — always version-consistent with the server

> **Resources:** See `RESOURCES.md` → *mpak CLI Documentation*

---

## Layer 5: NimbleBrain Platform

**NimbleBrain Studio** is a business automation platform. Users talk to the AI
agent to automate workflows using the tools they already use: Notion, HubSpot, Linear,
Stripe, etc.

Under the hood, the AI agent uses MCP servers to call those external services. The open source
ecosystem (servers + skills built by contributors) is what gives the AI agent its breadth of
integrations.

**The contributor's place in this:** Every integration you build becomes a tool the AI agent can
use to automate real business workflows for real users.

> **Resources:** See `RESOURCES.md` → *NimbleBrain Website*, *NimbleBrain Docs*

---

## What a Contributor Actually Ships

A GitHub repo under `NimbleBrainInc/` containing:

```
mcp-<service>/
# if Python
├── src/mcp_<service>/
│   ├── server.py        ← FastMCP server with 5+ tools
│   ├── api_client.py    ← async HTTP client for the target API
│   └── SKILL.md         ← embedded skill resource
├── tests/
├── .github/workflows/
│   ├── ci.yml           ← lint + test + bundle on every push
│   ├── scan.yml         ← MTF security scan on every push
│   └── build-bundle.yml ← multi-platform build + announce on release
├── manifest.json        ← MCPB runtime contract
├── server.json          ← registry metadata (not shipped to users)
├── mpak.json            ← package metadata
└── Makefile             ← build automation

# if TypeScript
├── src/
│   ├── index.ts         ← MCP server entry point, registers all tools
│   ├── utils/apiClient.ts ← async HTTP client for the target API
│   └── SKILL.md         ← embedded skill resource
├── tests/
├── .github/workflows/
│   ├── ci.yml           ← lint + test + bundle on every push
│   ├── scan.yml         ← MTF security scan on every push
│   └── build-bundle.yml ← multi-platform build + announce on release
├── manifest.json        ← MCPB runtime contract
├── server.json          ← registry metadata (not shipped to users)
├── mpak.json            ← package metadata
└── Makefile             ← build automation
```

When the contributor cuts a GitHub Release, the CI/CD handles everything:
build → bundle → upload → announce → mpak registry. The contributor never
touches the bundling or publishing machinery directly.

---

## The Full Release Flow (Big Picture)

```
Contributor cuts GitHub Release
        │
        ├── build-bundle.yml triggers (3 parallel runners)
        │     Each runner:
        │       vendor deps → mcpb pack → upload to Release → announce
        │
        ▼
mpak registry receives announce
        │
        ├── OIDC verification (GitHub vouches for repo identity)
        ├── SHA256 verification (bundle integrity)
        ├── ACID transaction (packages/versions/artifacts/provenance tables)
        ├── 200 OK returned to mcpb-pack
        │
        └── async: MTF security scan + Discord notification
                │
                └── scan result written back to DB (trust level on artifact)
```

Users can then: `mpak run @nimblebraininc/<service>` — and it just works.

# Resources

> Organized by ecosystem layer (mirrors ECOSYSTEM.md). For each resource: use the
> summary to explain it to the user — no fetching needed. Share the URL when the user
> wants to go deeper on their own.

---

## MCP Protocol

### MCP Specification
**URL:** https://modelcontextprotocol.io
**Summary:** The official specification for the Model Context Protocol, published by
Anthropic. Covers the protocol's wire format, capability negotiation, tool/resource/prompt
definitions, and transport layers (stdio and HTTP). This is the foundational standard all
MCP servers conform to — every tool call, every response, every error follows this spec.
**When to surface:** User is curious about what MCP actually is, wants to understand the protocol
deeply, is curious about how tool calls work under the hood, or is building a server outside
of FastMCP and needs to understand raw protocol behavior.

---

## MCPB Bundle Format

### MCPB Specification
**URL:** https://github.com/modelcontextprotocol/mcpb
**Summary:** The MCPB spec defines the bundle format for packaging MCP servers: a ZIP
archive containing source code, vendored dependencies, and a `manifest.json` that declares
how to execute the server and what configuration it requires. It is a community spec
maintained alongside the MCP project. Understanding it is useful for debugging bundle
issues or understanding what `mcpb-pack` produces.
**When to surface:** User is curious about what a `.mcpb` file is, wants to understand the bundle
format, is debugging a bundle validation error, or wonders what `manifest.json` fields mean.

---

## mpak

### mpak Registry
**URL:** https://mpak.dev
**Summary:** The mpak registry is where published MCP server bundles live. Users can
browse available packages, see version history, and find platform-specific artifacts.
It complements the MCP Registry (discovery) by handling distribution — linking to
downloadable artifacts rather than source repositories.
**When to surface:** User wants to see what integrations are already published, wants
to explore the ecosystem before picking what to build, or asks "what's already on mpak?"

### mpak CLI Documentation
**URL:** https://docs.mpak.dev
**Summary:** Full reference documentation for the mpak CLI. Covers all commands:
`run`, `search`, `pull`, `list`, `config set/get`, version pinning, cache management, and
offline usage. Also covers `mpak skill` commands for standalone skills (not needed for embedded skill resources in server repos).
**When to surface:** User wants to know how to use a specific mpak CLI command, asks
about configuration management, version pinning, or skill installation.

### mpak Whitepaper
**URL:** https://mpak.dev/mpak-whitepaper.pdf
**Summary:** The technical paper by Mathew Goldsborough (NimbleBrain) explaining why
mpak exists and how it works. Covers: the gap between MCPB-as-spec and
MCPB-as-ecosystem; why npm/pip/uv are the wrong mental model for MCP servers
(servers are standalone services, not libraries); the three-component architecture
(mcpb-pack, registry, CLI); the OIDC-based provenance model (no credentials to steal —
GitHub cryptographically vouches for bundle identity); multi-platform build convergence;
and the full security threat model. Highly recommended for anyone wanting to understand
the design philosophy before contributing.
**When to surface:** User is curious about why mpak exists, how it differs from pip/npm, how the
security or publishing model works, or wants deeper technical understanding before diving in.

### mpak CLI Source
**URL:** https://github.com/NimbleBrainInc/mpak
**Summary:** The open source TypeScript implementation of the mpak CLI. Useful for
understanding exactly how bundle resolution, caching, and execution work, or for
contributing to the CLI itself.
**When to surface:** User wants to contribute to the CLI, is debugging unexpected CLI
behavior, or wants to understand the implementation in detail.

### mcpb-pack Action Source
**URL:** https://github.com/NimbleBrainInc/mcpb-pack
**Summary:** The open source GitHub Action that automates bundle creation in CI/CD.
Auto-detects the runtime, vendors dependencies, runs `mcpb pack`, uploads to GitHub
Releases, and announces to the mpak registry via OIDC. This is what runs automatically
in every server repo's `build-bundle.yml` on release.
**When to surface:** User wants to understand what CI does when they cut a release,
is debugging a failed bundle build, or wants to customize the build process.

---

## NimbleBrain Platform

### NimbleBrain Website
**URL:** https://nimblebrain.ai
**Summary:** The NimbleBrain product site. Covers what NimbleBrain Studio is, how
Nira (the AI agent) works, use cases for business automation, and the broader product
vision. Good starting point for understanding what the platform does and why the open
source ecosystem matters to real users.
**When to surface:** User is curious about what NimbleBrain actually builds, wants to understand
the product context for their contribution, or is evaluating whether this is the right
ecosystem to contribute to.

### NimbleBrain Docs
**URL:** https://docs.nimblebrain.ai
**Summary:** Documentation for the NimbleBrain platform. Covers Studio, Nira, skill
authoring guidelines, and how published servers and skills are consumed by the platform.
**When to surface:** User wants to understand how their published server will be used
in NimbleBrain Studio, or asks how Nira discovers and uses MCP servers and skills.

---

## Contribution

### NimbleBrain Org Issues & Roadmap
**URL:** https://github.com/NimbleBrainInc/.github
**Summary:** The central coordination point for NimbleBrain open source. Open issues
represent available integrations to build, bugs to fix, and features to propose. Issues
labeled `integration` are new MCP server proposals; `good first issue` labels entry-level
work. This is where contributors pick up work, file new proposals, and track project status.
**When to surface:** Any time a user wants to find available work, file a new issue,
check project status, or understand what integrations the community has already requested.

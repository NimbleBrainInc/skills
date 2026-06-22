---
name: synapse
description: Build a Synapse UI for an MCP server — a React app built to one inlined HTML file, served as a `ui://` resource and rendered in the NimbleBrain host. Works with any MCP server (Python/FastMCP or TypeScript). Use when building a Synapse app or UI, adding a frontend to an MCP server, making a server "visual" or "interactive", or wiring a `ui://` resource.
license: MIT
compatibility: Node.js 22+, npm (for the React/Vite UI build). The MCP server itself can be Python (FastMCP) or TypeScript.
allowed-tools: Read Write Bash Glob Grep WebFetch
metadata:
  area: synapse
  version: "0.1.0"
  author: NimbleBrain
---

# Synapse — build a UI for an MCP Server

Give an MCP server an interactive UI. The UI is a React app built to **one inlined HTML file** with `@nimblebrain/synapse` + Vite, served by the server as the MCP resource `ui://<name>/main`, and mounted by the NimbleBrain host in a sandboxed iframe wired to a `postMessage` bridge. The UI calls the server's **existing tools** over that bridge — it is data-layer-agnostic and needs no special server framework.

**Target `@nimblebrain/synapse@^0.10.1`** (published on npm). The package *is* the documentation — read its exported types before writing code.

## Pre-flight — read the SDK's types (the real docs)

From the installed package (`node_modules/@nimblebrain/synapse/dist/*.d.ts`) or the public repo (`github.com/NimbleBrainInc/synapse`):
- the `react` entry — hooks (`useSynapse`, `useCallTool`, `useDataSync`, `useTheme`, `useVisibleState`, …).
- the `ui` entry — the **component library** (`AppFrame`, `ListDetailLayout`, `ListRow`, `Table`, `Badge`, `Prose`, `tokens`, …). Don't hand-roll styling.
- the type exports — `ToolCallResult`, `SynapseTheme`, the `Synapse` interface.

Then read **`references/gotchas.md`** (non-obvious API facts that each save a debugging cycle) and **`references/host-contract.md`** (the manifest + bridge contract). Skim these first; they're short and they're the difference between working and "why is every tool call returning `unauthenticated`."

## Process

1. **Analyze the server** — language (Python/FastMCP or TS), transport (stdio vs HTTP-native/edge-fronted), the tool list + return shapes, and deploy shape (`.mcpb` bundle vs a container image — the container needs a Node build stage, step 7).

2. **Scaffold `ui/`** — `package.json` (`react`/`react-dom` `^19`, `@nimblebrain/synapse@^0.10.1`, `vite`, `vite-plugin-singlefile`, `typescript`; add `marked` + `dompurify` only if you render markdown), `vite.config.ts` (`react()`, `viteSingleFile()`, `synapseVite()`, `build.assetsInlineLimit: Infinity`), a strict `tsconfig.json`, `index.html`, and `.gitignore` (`node_modules/`, `dist/`, `.vite/`). **Commit `package-lock.json`** so the build can `npm ci`.

3. **Build `App.tsx`** — `<SynapseProvider name="<server>">`; `import "@nimblebrain/synapse/ui/fonts"` once. Use the package's **`AppFrame` shell** (with `AppFrame.Body bleed` hosting `ListDetailLayout`/`SidebarLayout`) — **never** a hand-rolled `height:100vh` (gotcha D). Drive data with a thin `useCall<T>()` wrapper around `useSynapse().callTool(name, args)`; refresh with `useDataSync`; theme with `tokens`/`useTheme`; push agent context with `useVisibleState`. **Master lists use `ListRow`, not `Table`** (gotcha D — a `Table` overflows a fixed-width rail and paints over the detail pane).

4. **Sanitize any rendered HTML — do not skip (stored-XSS).** If you render server- or agent-authored markdown (notes, descriptions, research output) via `Prose` / `dangerouslySetInnerHTML`, run it through **DOMPurify first**: `DOMPurify.sanitize(marked.parse(md, { async: false }) as string)`. The iframe runs with `allow-scripts` and a `script-src 'unsafe-inline'` CSP, so **sanitization — not the CSP — is the only thing stopping an injected `<script>`/`onerror` from running with full tool-bridge authority** (read/exfiltrate/mutate everything the tools can reach). Plain `<Text>{value}</Text>` is safe (React escapes). Full chain: gotcha K.

5. **Serve the UI as a resource** — `@mcp.resource("ui://<name>/main", mime_type="text/html")` returning the built `ui/dist/index.html`. Resolve the path via an env var (`<APP>_UI_DIR`) with a `__file__`-relative fallback (gotcha E — an installed package lands in site-packages, so a `__file__`-relative `ui/dist` lookup misses). Make it a **bare file read**: no DB/auth session, identity-free HTML, all tenant data fetched at runtime through the bridge.

6. **Declare the host placement** — add `_meta["ai.nimblebrain/host"]` to `manifest.json`: one `placements[]` entry (`slot: "sidebar.apps"`, `resourceUri: "ui://<name>/main"`, `route`, `label`, `icon`). Full contract + options: `references/host-contract.md`.

7. **Container-deployed servers — multi-stage build.** A `.mcpb` bundle gets `ui/dist` from release CI; a container image must build it: a `node:22` builder stage runs `npm ci && npm run build`, then the runtime `COPY --from=builder …/ui/dist` (so the runtime stays Node-free) and sets the UI-dir env var. Strip the `ui/` source from the runtime layer — only `dist` ships.

8. **Local preview** — `cd ui && npm run dev` → open `/__preview`. For an **edge-fronted** server (identity from HTTP headers + a DB), the real server can't be driven over the stdio preview, so every call returns `unauthenticated` — point `synapseVite({ serverCmd })` at a **seeded stdio mock** behind an env flag (gotcha F).

9. **Verify** — `npx tsc --noEmit` **and** `npm run build` (Vite/esbuild won't type-check on its own). Then run the **server project's own lint/format/test gate** (e.g. `make verify`, `ruff format --check`), not just the UI type-check — a format-only diff will redden CI even when types pass. Confirm the server serves `ui://<name>/main` as `text/html`.

## Out of scope
- Host-side rendering — the host already implements placement → iframe → bridge; you build the bundle + declare the placement, nothing more.
- Declarative host "commands"/toolbars — they don't exist. In-app buttons live inside the iframe and call tools via `useCallTool`.

---
name: synapse
description: Build a Synapse UI for an MCP server — a React app built to one inlined HTML file, served as a `ui://` resource and mounted by any MCP Apps host (Claude, ChatGPT, NimbleBrain). Works with any MCP server (Python/FastMCP or TypeScript). Use when building a Synapse app or UI, adding a frontend to an MCP server, making a server "visual" or "interactive", or wiring a `ui://` resource.
license: MIT
compatibility: Node.js 22+, npm (for the React/Vite UI build). The MCP server itself can be Python (FastMCP) or TypeScript.
allowed-tools: Read Write Bash Glob Grep WebFetch
metadata:
  area: synapse
  version: "0.3.0"
  author: NimbleBrain
---

# Synapse — build a UI for an MCP Server

Give an MCP server an interactive UI. The UI is a React app built to **one inlined HTML file** with `@nimblebrain/synapse` + Vite, served by the server as the MCP resource `ui://<name>/main`, and mounted by an **MCP Apps** host (Claude, ChatGPT, NimbleBrain) in a sandboxed iframe wired to a `postMessage` bridge. The UI calls the server's **existing tools** over that bridge — it is data-layer-agnostic and needs no special server framework. Every host speaks the same bridge; they differ in which capabilities they declare, and the SDK behaves predictably when one is missing. Read Portability below before you write components.

**Target `@nimblebrain/synapse@^0.20.0`** (published on npm), with its peers `@modelcontextprotocol/ext-apps@^1.7.5` and `@modelcontextprotocol/sdk@^1.29.0`. A caret range on `0.x` does not cross a minor, so an app stays on its pin until someone bumps it deliberately. **On NimbleBrain, 0.20.0 needs a host release that declares `message`, `updateModelContext` and the `ai.nimblebrain/*` extensions** ([nimblebrain#1239](https://github.com/NimbleBrainInc/nimblebrain/issues/1239)): on an earlier host, chat, model context, host actions and key forwarding do nothing and the file picker rejects. The package *is* the documentation — read its exported types before writing code. Its guides live at `synapse.nimblebrain.ai`.

## Pre-flight — read the SDK's types (the real docs)

From the installed package (`node_modules/@nimblebrain/synapse/dist/*.d.ts`) or the public repo (`github.com/NimbleBrainInc/synapse`):
- the `react` entry — `AppProvider` and its hooks (`useApp`, `useCallTool`, `useCallToolAsTask`, `useDataSync`, `useTheme`, `useHostContext`, `useModelContext`, `useSendMessage`, `useAction`, `useFileUpload`, `useToolResult`, `useToolInput`, `useResize`).
- the `ui` entry — the **component library** (`AppFrame`, `ListDetailLayout`, `ListRow`, `Table`, `Badge`, `Prose`, `ConfirmDialog`, `tokens`, …). Don't hand-roll styling.
- the type exports — `ToolCallResult`, `Theme`, the `App` interface (including `hostCapabilities`), `HostCapabilityError`, `hostSupports`, `NIMBLEBRAIN_EXTENSIONS`.

Then read **`references/gotchas.md`** (non-obvious API facts that each save a debugging cycle) and **`references/host-contract.md`** (the NimbleBrain manifest declaration + the bridge). Skim these first; they're short and they're the difference between working and "why is every tool call returning `unauthenticated`."

## Portability — this is an MCP app, not a NimbleBrain app

Claude, ChatGPT and NimbleBrain all speak MCP Apps. Each declares what it offers in its
`ui/initialize` answer (`hostCapabilities`), and **every gated Synapse call checks that declaration
before it sends**, then does one documented thing when the capability is missing (`resize` is never
gated, and `useDataSync` only listens):

- **a request with an answer rejects with `HostCapabilityError`, without sending** — `useCallTool`
  (`serverTools`), `readServerResource` (`serverResources`), `downloadFile`, `useCallToolAsTask`
  (tasks), and the file picker;
- **a fire-and-forget call sends nothing** — `useSendMessage` (`message`), `useModelContext`
  (`updateModelContext`), `useAction`, `forwardKeys`; `openLink` opens the URL itself;
- **a hook that waits on the host keeps its initial value** — `useToolResult`/`useToolInput` stay
  `null`, `useDataSync` never fires where the host does not relay `notifications/resources/list_changed` (or without your server
  announcing, step 5).

**The portable subset** is the handshake, theme and host context, tool input/results, `callTool`,
`sendMessage`, `updateModelContext` and `resize`. An app built on that behaves the same everywhere.
**The NimbleBrain extensions** are exactly three (`synapse/action`, `synapse/request-file`,
`synapse/keydown`), each used only where the host declares `ai.nimblebrain/<name>` in
`hostCapabilities.experimental`.

A no-op is still invisible to the user, so read the declaration and hide what the host can't do:
`hostSupports(app, "requestFile")`, `app.hostCapabilities.message`, `app.supportsTasks`.
`<AppProvider>` renders nothing until the handshake completes, so all of these are settled before
any component reads them — and where the handshake never returns (the built HTML opened directly),
nothing under the provider renders at all.
Per-hook table, the extension list, serving one app to Claude and ChatGPT, and the two connection
entry points: **`references/portability.md`**.

## Process

1. **Analyze the server** — language (Python/FastMCP or TS), transport (stdio vs HTTP-native/edge-fronted), the tool list + return shapes, and deploy shape (`.mcpb` bundle vs a container image — the container needs a Node build stage, step 7).

2. **Scaffold `ui/`** — `package.json` (`react`/`react-dom` `^19`, `@nimblebrain/synapse@^0.20.0`, `@modelcontextprotocol/ext-apps@^1.7.5`, `@modelcontextprotocol/sdk@^1.29.0`, `vite`, `vite-plugin-singlefile`, `typescript`; add `marked` + `dompurify` only if you render markdown), `vite.config.ts` (`react()`, `viteSingleFile()`, `synapseVite()`, `build.assetsInlineLimit: Infinity`), a strict `tsconfig.json`, `index.html`, and `.gitignore` (`node_modules/`, `dist/`, `.vite/`). **Commit `package-lock.json`** so the build can `npm ci`.

3. **Build `App.tsx`** — `<AppProvider name="<server>" version="<version>">`. One side-effect import goes in the Vite entry (`main.tsx`): `import "@nimblebrain/synapse/ui/base"` (the root-height chain `AppFrame` fills — applied before first paint; gotcha M). **Don't import fonts** — the SDK ships none, and typography arrives from the host like every other theme value (gotcha N). Use the package's **`AppFrame` shell** (with `AppFrame.Body bleed` hosting `ListDetailLayout`/`SidebarLayout`) — **never** a hand-rolled `height:100vh` (gotcha D). Drive data with `useCallTool(name)` or a thin `useCall<T>()` wrapper around `useApp().callTool(name, args)`; re-read in `useDataSync(() => …)`, which fires when your server announces a write (step 5) — the callback names no tool, so the answer is always to re-read; theme with `tokens`/`useTheme`; push agent context with `useModelContext`. **Master lists use `ListRow`, not `Table`** (gotcha D — a `Table` overflows a fixed-width rail and paints over the detail pane).

4. **Sanitize any rendered HTML — do not skip (stored-XSS).** If you render server- or agent-authored markdown (notes, descriptions, research output) via `Prose` / `dangerouslySetInnerHTML`, run it through **DOMPurify first**: `DOMPurify.sanitize(marked.parse(md, { async: false }) as string)`. The iframe runs with `allow-scripts` and a `script-src 'unsafe-inline'` CSP, so **sanitization — not the CSP — is the only thing stopping an injected `<script>`/`onerror` from running with full tool-bridge authority** (read/exfiltrate/mutate everything the tools can reach). Plain `<Text>{value}</Text>` is safe (React escapes). Full chain: gotcha K.

5. **Serve the UI as a resource, and announce writes.** `@mcp.resource("ui://<name>/main")` returning the built `ui/dist/index.html`, served as the spec's MIME type `text/html;profile=mcp-app` (the default for a `ui://` URI in `fastmcp` 3.4+; pass `mime_type` explicitly anywhere else). Resolve the path via an env var (`<APP>_UI_DIR`) with a `__file__`-relative fallback (gotcha E — an installed package lands in site-packages, so a `__file__`-relative `ui/dist` lookup misses). Make it a **bare file read**: no DB/auth session, identity-free HTML, all tenant data fetched at runtime through the bridge. Then make every tool that writes send `notifications/resources/list_changed` after the write commits — that is the only thing `useDataSync` fires on, and it covers every writer (the agent, another view, a webhook):
   ```python
   from fastmcp import Context
   from mcp.types import ResourceListChangedNotification

   @mcp.tool()
   async def save_item(item: Item, ctx: Context) -> dict:
       stored = store.save(item)
       await ctx.session.send_notification(ResourceListChangedNotification(), related_request_id=ctx.request_id)
       return stored
   ```
   `related_request_id` makes it travel in the call's own response over HTTP. Announce once per write, not per row. Full guide: `synapse.nimblebrain.ai/docs/guides/keep-ui-in-sync/`.

6. **Register the app with its host.** The bundle from steps 2–5 is the same either way; only registration differs. *Targeting the NimbleBrain host* — add `_meta["ai.nimblebrain/host"]` to `manifest.json`: one `placements[]` entry (`slot: "sidebar.apps"`, `resourceUri: "ui://<name>/main"`, `route`, `label`, `icon`). Full contract + options: `references/host-contract.md`. *Targeting Claude or ChatGPT* — the host renders the resource your tool names: bind it with `_meta.ui.resourceUri` on the tool, serve that one resource under `text/html;profile=mcp-app` (never a second copy under another MIME), declare `ui.visibility` and `ui.csp`, and — if the server needs sign-in — `securitySchemes` plus a `401` challenge. Python servers get all of it from `nimblebrain-synapse`'s `SynapseUI`. Then run `npx @nimblebrain/synapse check --target claude,chatgpt <server-url>`. Details: `references/portability.md`.

7. **Container-deployed servers — multi-stage build.** A `.mcpb` bundle gets `ui/dist` from release CI; a container image must build it: a `node:22` builder stage runs `npm ci && npm run build`, then the runtime `COPY --from=builder …/ui/dist` (so the runtime stays Node-free) and sets the UI-dir env var. Strip the `ui/` source from the runtime layer — only `dist` ships.

8. **Local preview** — `cd ui && npm run dev` → open `/__preview`. For an **edge-fronted** server (identity from HTTP headers + a DB), the real server can't be driven over the stdio preview, so every call returns `unauthenticated` — point `synapseVite({ serverCmd })` at a **seeded stdio mock** behind an env flag (gotcha F).

9. **Verify** — `npx tsc --noEmit` **and** `npm run build` (Vite/esbuild won't type-check on its own). Then run the **server project's own lint/format/test gate** (e.g. `make verify`, `ruff format --check`), not just the UI type-check — a format-only diff will redden CI even when types pass. **Toggle the preview between light and dark and eyeball every surface** — theme-blind color passes `tsc`/`build` and only breaks in one mode. Every `tokens.*` is backed in both; your own vars are not (gotcha L). Confirm the server serves `ui://<name>/main` as `text/html;profile=mcp-app`, and that a write through the preview refreshes the view (the preview relays your server's `list_changed`, gotcha F).

## Out of scope
- Host-side rendering — the host already implements placement → iframe → bridge; you build the bundle + declare the placement, nothing more.
- Declarative host "commands"/toolbars — they don't exist. In-app buttons live inside the iframe and call tools via `useCallTool`.

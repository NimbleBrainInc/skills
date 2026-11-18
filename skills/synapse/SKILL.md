---
name: synapse
description: Builds a Synapse UI for any MCP server — a React app built to one inlined HTML file, served as a `ui://` resource for MCP Apps hosts (Claude, ChatGPT, NimbleBrain). Use to add a frontend to an MCP server. Triggers include "build a Synapse app", "make this interactive", "wire a ui:// resource".
license: MIT
compatibility: Node.js 22+, npm (for the React/Vite UI build). The MCP server itself can be Python (FastMCP) or TypeScript.
allowed-tools: Read Write Bash Glob Grep WebFetch
metadata:
  area: synapse
  version: "0.5.0"
  author: NimbleBrain
---

# Synapse — build a UI for an MCP Server

Give an MCP server an interactive UI. The UI is a React app built to **one inlined HTML file** with `@nimblebrain/synapse` + Vite, served by the server as the MCP resource `ui://<name>/main`, and mounted by an **MCP Apps** host (Claude, ChatGPT, NimbleBrain) in a sandboxed iframe wired to a `postMessage` bridge. The UI calls the server's **existing tools** over that bridge — it is data-layer-agnostic and needs no special server framework. Every host speaks the same bridge; they differ in which capabilities they declare, and the SDK behaves predictably when one is missing. Read Portability below before you write components.

**Target `@nimblebrain/synapse@^0.40.0`** — the release these names ship in. Its peers are `@modelcontextprotocol/ext-apps@^2.0.0`, `@modelcontextprotocol/client@^2.0.0` and `@modelcontextprotocol/core@^2.0.0` (which need `zod@^4.2` and Node 20+). A caret range on `0.x` does not cross a minor, so an app stays on its pin until someone bumps it deliberately, and its `CHANGELOG.md` names what each minor breaks. The package *is* the documentation — read its exported types before writing code. Its guides live at `synapse.nimblebrain.ai`.

## Pre-flight — read the SDK's types (the real docs)

From the installed package (`node_modules/@nimblebrain/synapse/dist/*.d.ts`) or the public repo (`github.com/NimbleBrainInc/synapse`):
- the `react` entry — `AppProvider` and its hooks (`useApp`, `useCallTool`, `useCallToolAsTask`, `useDataSync`, `useTheme`, `useHostContext`, `useModelContext`, `useSendMessage`, `useOpen`, `useOpenConnectorSettings`, `useNotify`, `useTrail`, `useFileUpload`, `useToolResult`, `useToolInput`, `useResize`, `useToolAllowed`).
- the `ui` entry — the **component library** (`AppFrame`, `ListDetailLayout`, `ListRow`, `Table`, `Badge`, `Prose`, `ConfirmDialog`, `tokens`, …). Don't hand-roll styling.
- the type exports — `ToolCallResult`, `Theme`, the `App` interface (including `hostCapabilities`), `HostCapabilityError`, `hostSupports`, `NIMBLEBRAIN_EXTENSIONS`.

Then read **`references/gotchas.md`** (non-obvious API facts that each save a debugging cycle) and **`references/host-contract.md`** (the catalog-entry `_meta` block + the bridge). Skim these first; they're short and they're the difference between working and "why is every tool call returning `unauthenticated`."

## Portability — this is an MCP app, not a NimbleBrain app

Claude, ChatGPT and NimbleBrain all speak MCP Apps. Each declares what it offers in its
`ui/initialize` answer (`hostCapabilities`), and **every gated Synapse call checks that declaration
before it sends**, then does one documented thing when the capability is missing (`resize` is never
gated, and `useDataSync` only listens):

- **a request with an answer rejects with `HostCapabilityError`, without sending** — `useCallTool`
  (`serverTools`), `readServerResource` (`serverResources`), `downloadFile`, `useCallToolAsTask`
  (tasks), the file picker and `uploadFiles`;
- **a request whose answer is only whether it happened resolves `false`, without sending** —
  `useOpen`, `useOpenConnectorSettings`, `useNotify`; each rejects with the host's reason when a
  host that serves it refuses;
- **a fire-and-forget call sends nothing** — `useSendMessage` (`message`), `useModelContext`
  (`updateModelContext`), `useTrail` (which returns `false`), `forwardKeys`; `openLink` opens the
  URL itself;
- **a hook that waits on the host keeps its initial value** — `useToolResult`/`useToolInput` stay
  `null`; `useDataSync` fires on a write only where the host relays `notifications/resources/list_changed`
  and your server announces it (step 5). Everywhere, it also re-reads when a tab hidden for a minute
  or more is shown again, and it runs calls at least 3 s apart (`{ minIntervalMs }` changes that).

**The portable subset** is the handshake, theme and host context, tool input/results, `callTool`,
`sendMessage`, `updateModelContext` and `resize`. An app built on that behaves the same everywhere.
**The NimbleBrain extensions** are `ai.nimblebrain/open`, `open-connector-settings`, `notify`,
`location` (with `navigate` back from the host), `request-file`, `upload-files` and `keydown`;
`NIMBLEBRAIN_EXTENSIONS` is the list in code. Each name is both the method and the identifier the
host declares in `hostCapabilities.experimental` to offer it, and an extension is used only where
it is declared.

A no-op is still invisible to the user, so read the declaration and hide what the host can't do:
`hostSupports(app, "requestFile")`, `app.hostCapabilities.message`, `app.supportsTasks`.
`<AppProvider>` renders nothing until the handshake completes, so all of these are settled before
any component reads them — and where the handshake never returns (the built HTML opened directly),
nothing under the provider renders at all.
Per-hook table, the extension list, serving one app to Claude and ChatGPT, and the two connection
entry points: **`references/portability.md`**.

## Process

1. **Analyze the server** — language (Python/FastMCP or TS), the tool list + return shapes, where identity comes from (the MCP session, or HTTP headers a proxy in front of the server sets), and how it is deployed. NimbleBrain connects to a server over HTTP by URL, so the server runs as a service, often from a container image (which needs a Node build stage, step 7). A `.mcpb` bundle is only for desktop hosts.

2. **Scaffold `ui/`** — `package.json` (`react`/`react-dom` `^19`, `@nimblebrain/synapse@^0.40.0`, `@modelcontextprotocol/ext-apps@^2.0.0`, `@modelcontextprotocol/client@^2.0.0`, `@modelcontextprotocol/core@^2.0.0`, `zod@^4.2`, `vite`, `vite-plugin-singlefile`, `typescript`; add `marked` + `dompurify` only if you render markdown), `vite.config.ts` (`react()`, `viteSingleFile()`, `synapseVite()`, `build.assetsInlineLimit: Infinity`), a strict `tsconfig.json`, `index.html`, and `.gitignore` (`node_modules/`, `dist/`, `.vite/`). **Commit `package-lock.json`** so the build can `npm ci`.

3. **Build `App.tsx`** — `<AppProvider name="<server>" version="<version>">`. One side-effect import goes in the Vite entry (`main.tsx`): `import "@nimblebrain/synapse/ui/base"` (the root-height chain `AppFrame` fills — applied before first paint; gotcha M). **Don't import fonts** — the SDK ships none, and typography arrives from the host like every other theme value (gotcha N). Use the package's **`AppFrame` shell** (with `AppFrame.Body bleed` hosting `ListDetailLayout`/`SidebarLayout`) — **never** a hand-rolled `height:100vh` (gotcha D). Drive data with `useCallTool(name)` or a thin `useCall<T>()` wrapper around `useApp().callTool(name, args)`; re-read in `useDataSync(() => …)`, which fires when your server announces a write (step 5) — the callback names no tool, so the answer is always to re-read; theme with `tokens`/`useTheme`; push agent context with `useModelContext`. **Master lists use `ListRow`, not `Table`** (gotcha D — a `Table` overflows a fixed-width rail and paints over the detail pane).

4. **Sanitize any rendered HTML — do not skip (stored-XSS).** If you render server- or agent-authored markdown (notes, descriptions, research output) via `Prose` / `dangerouslySetInnerHTML`, run it through **DOMPurify first**: `DOMPurify.sanitize(marked.parse(md, { async: false }) as string)`. The iframe runs with `allow-scripts` and a `script-src 'unsafe-inline'` CSP, so **sanitization — not the CSP — is the only thing stopping an injected `<script>`/`onerror` from running with full tool-bridge authority** (read/exfiltrate/mutate everything the tools can reach). Plain `<Text>{value}</Text>` is safe (React escapes). Full chain: gotcha K.

5. **Serve the UI as a resource, and announce writes.** On FastMCP 4, `@mcp.resource("ui://<name>/main", app=AppConfig(prefers_border=True, csp=ResourceCSP()))` (from `fastmcp.apps`) returning the built `ui/dist/index.html`, served as the spec's MIME type `text/html;profile=mcp-app` (FastMCP's default for a `ui://` URI; pass `mime_type` explicitly anywhere else). Full walkthrough, including a build-keyed bound URI so hosts don't render a cached build: `synapse.nimblebrain.ai/docs/quickstart-python/`. Resolve the path via an env var (`<APP>_UI_DIR`) with a `__file__`-relative fallback (gotcha E — an installed package lands in site-packages, so a `__file__`-relative `ui/dist` lookup misses). Make it a **bare file read**: no DB/auth session, identity-free HTML, all tenant data fetched at runtime through the bridge. Then make every tool that writes send `notifications/resources/list_changed` after the write commits — that is the only thing `useDataSync` fires on, and it covers every writer (the agent, another view, a webhook):
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

6. **Register the app with its host.** The UI and resource from steps 2–5 are the same either way; only registration differs. *Targeting the NimbleBrain host* — NimbleBrain reads the `_meta["ai.nimblebrain/host"]` block from the server's connectors-catalog entry, which an operator adds: one `placements[]` entry (`slot: "sidebar.apps"`, `resourceUri: "ui://<name>/main"`, a `route` named after your server, `label`); the app's name and icon are the entry's `title` and `icons`. Write that block for the operator, and keep the same `_meta` in an MCPB `manifest.json` if you also ship one. Full contract + options: `references/host-contract.md`. *Targeting Claude or ChatGPT* — the host renders the resource your tool names: bind it with `_meta.ui.resourceUri` on the tool, serve that one resource under `text/html;profile=mcp-app` (never a second copy under another MIME), declare `ui.visibility` and `ui.csp`, and — if the server needs sign-in — `securitySchemes` plus a `401` challenge. On FastMCP 4, `AppConfig(resource_uri=..., visibility=[...])` on the tool and `AppConfig(csp=ResourceCSP(...))` on the resource write the `ui.*` keys; ChatGPT's own keys (`openai/widgetAccessible`, which defaults to false and leaves the UI read-only) go in plain `meta=`: `synapse.nimblebrain.ai/docs/guides/chatgpt/`. Then run `npx @nimblebrain/synapse check --target nimblebrain,claude,chatgpt <server-url>` for the hosts you target. Details: `references/portability.md`.

7. **Container-deployed servers — multi-stage build.** A container image must build the UI: a `node:22` builder stage runs `npm ci && npm run build`, then the runtime `COPY --from=builder …/ui/dist` (so the runtime stays Node-free) and sets the UI-dir env var. Strip the `ui/` source from the runtime layer — only `dist` ships. (A `.mcpb` bundle for desktop hosts gets `ui/dist` from its release CI.)

8. **Local preview** — `cd ui && npm run dev` → open `/__preview`. The preview starts your server over stdio from a `manifest.json` (gotcha F). For a server whose identity comes from HTTP headers and a DB, the real server can't be driven that way, so every call returns `unauthenticated` — point `synapseVite({ serverCmd })` at a **seeded stdio mock** behind an env flag (gotcha F).

9. **Verify** — `npx tsc --noEmit` **and** `npm run build` (Vite/esbuild won't type-check on its own). Then run the **server project's own lint/format/test gate** (e.g. `make verify`, `ruff format --check`), not just the UI type-check — a format-only diff will redden CI even when types pass. **Toggle the preview between light and dark and eyeball every surface** — theme-blind color passes `tsc`/`build` and only breaks in one mode. Every `tokens.*` is backed in both; your own vars are not (gotcha L). Confirm the server serves `ui://<name>/main` as `text/html;profile=mcp-app`, and that a write through the preview refreshes the view (the preview relays your server's `list_changed`, gotcha F).

10. **Run it in NimbleBrain.** The `nimblebrain` skill sets up a local NimbleBrain (`npx nimblebrain`). Serve your server over HTTP, connect it to a workspace as [Connect it to NimbleBrain](https://docs.nimblebrain.ai/server-sdk/quickstart/#5-connect-it-to-nimblebrain) describes (that section runs NimbleBrain from a source checkout), and have the agent call your tools, including a write. A server connected by URL has no catalog entry, so it gets no placement and no sidebar entry: the app itself (the host's theme and fonts, a write by the agent refreshing the view, the NimbleBrain extensions it uses) shows in NimbleBrain only once it is installed from the step-6 catalog entry.

## Out of scope
- Host-side rendering — the host already implements placement → iframe → bridge; you build and serve the UI and write the placement for the catalog entry, nothing more.
- Declarative host "commands"/toolbars — they don't exist. In-app buttons live inside the iframe and call tools via `useCallTool`.

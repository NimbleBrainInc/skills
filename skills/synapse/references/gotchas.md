# Synapse UI — non-obvious facts (read before coding)

Each of these costs a debugging cycle if you don't know it. They were learned by reading the `@nimblebrain/synapse` source and by shipping real apps.

## A. The call shapes
`connect()` / `<AppProvider>` / `useApp()` is the whole connection surface. An example that imports anything else is written against an API this package does not have, and it fails to compile.
- `useModelContext(factory, deps)` pushes when `deps` change; `useModelContext()` returns a push function. Both debounce 250 ms.
- `useCallTool<T>(name)` returns `{ call, isPending, error, data }` — you `await call(args)`, you don't get a bare tool function. It reaches the app's **own** server only; there is no target-server argument.
- Imperative path (cleaner for many-tool apps): `useApp().callTool(name, args)` → `ToolCallResult { data, isError, content?, _meta? }`. The result is validated against the spec's `CallToolResult`, and a malformed one **rejects**.
- `.data` is **`JSON.parse` of the first `text` content block** (raw string on parse failure). So a Python tool returning a `dict` arrives as `.data`. A tool that returns a structured `{ "error": ... }` dict is **not** an MCP `isError` — check `data.error` yourself.

## B. There's a whole component library — don't hand-roll styling
`@nimblebrain/synapse/ui` exports: `Avatar, Badge, Breadcrumb, Button, TextLink, Card, ConfirmDialog, Drawer, EmptyState, ListRow, PageHeader, Pagination, Prose, SearchField, SegmentedControl, Spinner, StatusDot, Table, Tabs`; layouts `AppFrame, ListDetailLayout (+useListDetail), PageLayout, SidebarLayout (+useSidebar), useBreakpoint`; primitives `Stack, Inline, Spacer, Divider`; typography `Heading, Text`; plus `tokens, textStyle, headingStyle`.
- `tokens.*` are **CSS `var(--…, fallback)` references** resolved against host-injected variables, so light/dark switches with **no React re-render**. Every color var they reference is backed in both themes by the SDK's own neutral default layer, with the host's values layered on top (gotcha L).
- **The SDK ships no fonts.** Font tokens fall back to web-safe system stacks (`system-ui`, `ui-monospace`, `Georgia`), so an app renders correctly with no host, no network and no font files. A host that wants its own typeface sends `@font-face` CSS as `styles.css.fonts` in the host context and the SDK injects it — there is **no font import**, by design (gotcha N).

## C. `Inline`/`Stack` use short enums, not CSS longhands (tsc-only catch)
`justify` ∈ `start | center | end | between | around` (NOT `space-between`/`flex-end`); `align` ∈ `start | center | end | stretch | baseline`. Wrong values only fail at `tsc`, never at runtime.

## D. The master/detail list-overlap trap
`ListDetailLayout.List` is a fixed-width (`listWidth`, default 320), `flexShrink:0` column. A `Table` placed there can't shrink below its intrinsic content width (`table-layout:auto` ignores `width:100%` as a cap), so it **spills horizontally over the detail pane**. Rules:
1. **Use `ListRow` for master lists** — its `minmax(0,1fr)` title track truncates instead of overflowing. Reserve `Table` for full-width surfaces.
2. Make `listWidth` responsive, e.g. `clamp(220px, 34%, 340px)`.
3. Use **`AppFrame` + `AppFrame.Body bleed`** as the shell hosting `ListDetailLayout`, not a hand-rolled `height:100vh` header. `AppFrame` sets `height:100%` + bg/fg/font; the `bleed` body is `flex:1; minHeight:0; overflow:hidden`, which is the flex context the responsive breakpoints need.

`ListDetailLayout.List` clips horizontal overflow by default as of **0.10.1** (`overflow: hidden auto`); on `≤0.10.0` add `style={{ overflowX: "hidden" }}` yourself.

## E. Serving the built HTML from an installed package
When the server is installed as a package (e.g. `pip install` / `uv pip install` into site-packages), a `Path(__file__)…/ui/dist` lookup **misses** — `__file__` is now in site-packages, not your source tree. Resolve the bundle via an **env var** (`<APP>_UI_DIR`) baked into the deploy image, with a `__file__`-relative fallback for source-tree dev. Keep the handler a **bare file read** (no DB/auth session) so the shell still loads when readiness probes fail.

## F. The `synapseVite()` preview has sharp edges
- It **spawns your server over stdio**, deriving the command from `manifest.server.mcp_config` (rewriting `python` → `uv run python` when a `pyproject.toml` exists), proxies `tools/call`, `resources/read` and `resources/list` over `POST /__mcp`, injects theme tokens, and defaults to dark with a toggle.
- It **does not inject HTTP identity headers.** An edge-fronted server that reads `x-tenant-id`/`x-workspace-id` and needs a DB returns `unauthenticated` for every call in preview. Drive it instead with a **seeded stdio mock** that returns `{ content: [{ type: "text", text: JSON.stringify(payload) }] }`, wired via `synapseVite({ serverCmd })` behind an env flag.
- It **relays your server's `notifications/resources/list_changed`** to the app (over `GET /__events`), as a host does, so `useDataSync` fires in preview exactly when your server announces a write — a UI-initiated write included. If a write in preview doesn't refresh the view, the server isn't announcing it, and it won't refresh in a real host either. Announce only after a write commits: a read that announces makes every view refresh forever. Nothing else the server sends is relayed.

## G. Build config is load-bearing
`vite-plugin-singlefile` + `build.assetsInlineLimit: Infinity` produce one inlined HTML (`viteSingleFile()` is build-only — a no-op in dev). `synapseVite()` reads only `manifest.name` + `manifest.server.mcp_config`.

## H. Bridge & hooks
The bridge is the MCP **Apps spec (`2026-01-26`)** plus three NimbleBrain `synapse/*` extensions (`action`, `request-file`, `keydown`), each used only when the host declares it in `hostCapabilities.experimental`. Live refresh is **not** one of them: `useDataSync` rides the spec's `notifications/resources/list_changed`, which your server sends and a host relays. File download is not one either — `downloadFile` sends the spec's `ui/download-file`.

**Every call checks the host's declaration before it sends.** A request with an answer (`callTool`, `readServerResource`, `downloadFile`, `callToolAsTask`, the file picker) rejects with `HostCapabilityError` without sending; a fire-and-forget call (`sendMessage`, `updateModelContext`, `action`) sends nothing; a hook waiting on the host keeps its initial value. So a missing capability never leaves a promise pending — but a no-op is still invisible to the user, so read `app.hostCapabilities` / `hostSupports(app, …)` and hide what the host can't do. Per-hook table: `portability.md`.

`@nimblebrain/synapse/react` exports `AppProvider` and its hooks: `useApp, useTheme, useHostContext, useToolResult, useToolInput, useResize, useCallTool, useCallToolAsTask, useDataSync, useModelContext, useSendMessage, useAction, useFileUpload`. Outside React, the package root exposes the same extensions as functions over an `App`: `callToolAsTask`, `action`, `pickFile`/`pickFiles`, `downloadFile`, plus `hostSupports`, `HostCapabilityError` and `NIMBLEBRAIN_EXTENSIONS`.

## J. Package hard rules
Per the SDK's own contributor docs: never hand-type ext-apps method strings or message param shapes (import the constants/types from `@modelcontextprotocol/ext-apps`); never `as any` a content block. There are two entry points: `connect()` / `<AppProvider>` for an app, and `connectUI()` (`@nimblebrain/synapse/host`) — a small push-first client for a self-contained component. It speaks MCP Apps inside a frame, renders baked-in data standalone, and exposes `capabilities()` so a widget can branch on what the host offers. `connectUI()` is widget-shaped, not a substitute for `AppProvider` in a full app (`portability.md`).

## K. Sanitize any HTML sink for server/agent-authored content (stored-XSS)
`Prose` renders via `dangerouslySetInnerHTML` under a "caller supplies trusted, pre-sanitized HTML" contract — it does **not** sanitize. `marked.parse()` does **not** sanitize either (marked removed its `sanitize` option years ago). The host iframe runs with `allow-scripts` and a `script-src 'unsafe-inline'` CSP (the single-file bundle needs inline scripts), so an injected `<script>` or `onerror=` **executes inside the iframe — which holds the live tool bridge** and can call every tool with the operator's authority.

Any value originating from the **server, the agent, or web-research** (CRM notes/dossiers, descriptions, anything an LLM wrote from a scraped page) is attacker-influenceable. Sanitize:
```ts
import DOMPurify from "dompurify";
import { marked } from "marked";
export function markdownToHtml(md: string): string {
  return DOMPurify.sanitize(marked.parse(md, { async: false }) as string);
}
```
The CSP is **not** the backstop — sanitization is. The danger is only the `html=`/`dangerouslySetInnerHTML` path; plain `<Text>{value}</Text>` is safe because React escapes it.

## L. A `var()` fallback is a safety net, not a theme
A CSS `var()` fallback is a **static literal** — it fires exactly when the var is unset, which is the moment there is no theme signal to branch on. So an unbacked theme-sensitive var resolves to the *same* value in both modes, and a light value under a dark theme is how you get white-on-white: correct in light, passing `tsc` and `build`, broken only once someone toggles.

**Every token in the `@nimblebrain/synapse/ui` contract is already safe from this.** `applyTheme` writes a theme-*aware* neutral default layer for the active mode before overlaying the host's variables, and a regression test enforces a total partition — each referenced var is either declared theme-invariant or backed in both modes, so none can ship unbacked. That holds against an incomplete host, a standalone `connect()` widget, and third-party hosts alike ([synapse#17](https://github.com/NimbleBrainInc/synapse/issues/17)). It applies on connection, so the one place it doesn't reach is `ui` components mounted with no Synapse connection at all — a bare Storybook-style render, where every var is unset and the light literals are what you get.

The exposure is **your own** vars. A `var(--custom, #fff)` you introduce outside the contract has nothing backing it in dark. Give it a value in both modes, or derive it from a contract token. Either way, **toggle the preview between light and dark and eyeball every surface** (gotcha F) — it is the only check that catches this class, and it costs seconds.

## M. `AppFrame` fills the pane — the root-height chain is supplied for you (≥0.11)
`AppFrame` is `height: 100%`, which only fills if its ancestor chain (`#root` → `body` → `html`) has a definite height. A Synapse app iframe is a bare document, so before **0.11** an app that didn't add `html, body, #root { height: 100% }` to its own `index.html` collapsed to **content height** — full width, short height (an empty board renders as a thin band over dead space). As of **0.11**, `AppFrame` injects that chain itself on render (a `nb-synapse-base` `<style>`), so a bare `index.html` works and you don't hand-roll root height. **`import "@nimblebrain/synapse/ui/base"` in `main.tsx`** to apply it *before first paint* (no layout jump), or for a full-pane app that renders without `AppFrame`. The reset uses a percentage chain (not `100vh`/`dvh`) on purpose — percentages resolve against the actual allocated pane, staying correct when a host gives the app a pane shorter than the viewport (a viewport unit would overflow with a second scrollbar).

## N. Fonts come from the host — there is no font import
A CSS custom property can **name** a font family but cannot **load** one, and an app iframe is its own document that inherits no `@font-face` from the host page. So a `--font-sans` token naming a family is not enough on its own.

The SDK ships no font data and exposes no font import. A `@nimblebrain/synapse/ui/fonts` subpath in an old example does not resolve at build time.

The host sends `@font-face` CSS in the spec's `hostContext.styles.css.fonts`, and the SDK injects it into the app document beside the token variables. As an app author there is nothing to wire and nothing to read. Three consequences worth knowing:
- **Sending no fonts is a supported configuration, not a degraded one.** With no host, no network and no font files the app renders in `system-ui` / `ui-monospace` / `Georgia`.
- **The CSS is applied once, from the first host context that carries it** — the handshake, or the first later change that sends it. A host that swaps its typeface after that does not move a running app.
- If you *are* the host: send the `@font-face` rules in the `ui/initialize` answer, resend them with every host-context change that carries `styles`, give every `--font-*` token value a **web-safe tail** (`"'Your Sans', system-ui, sans-serif"`, never `"'Your Sans'"`), and check the frame's CSP — a `srcdoc` iframe without `allow-same-origin` has an **opaque origin**, so `font-src 'self'` matches nothing and only a `data:` URI works unconditionally.

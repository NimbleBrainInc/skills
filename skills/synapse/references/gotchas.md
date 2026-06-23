# Synapse UI — non-obvious facts (read before coding)

Each of these costs a debugging cycle if you don't know it. They were learned by reading the `@nimblebrain/synapse` source and by shipping real apps.

## A. API has drifted — target 0.10.x, not 0.4.x
Old (`0.4.x`) examples call `synapse.callTool(...)` directly. On **0.10.x**:
- `useCallTool<T>(name)` returns `{ call, isPending, error, data }` — you `await call(args)`, you don't get a bare tool function.
- Imperative path (cleaner for many-tool apps): `useSynapse().callTool(name, args)` → `ToolCallResult { data, isError, content?, _meta? }`.
- `.data` is **`JSON.parse` of the first `text` content block** (raw string on parse failure); a non-CallToolResult object passes through as-is. So a Python tool returning a `dict` arrives as `.data`. A tool that returns a structured `{ "error": ... }` dict is **not** an MCP `isError` — check `data.error` yourself.

## B. There's a whole component library — don't hand-roll styling
`@nimblebrain/synapse/ui` exports: `Avatar, Badge, Button, TextLink, Card, Drawer, EmptyState, ListRow, Pagination, Prose, SearchField, SegmentedControl, Spinner, StatusDot, Table`; layouts `AppFrame, ListDetailLayout (+useListDetail), SidebarLayout (+useSidebar), useBreakpoint`; primitives `Stack, Inline, Spacer, Divider`; typography `Heading, Text`; plus `tokens, textStyle, headingStyle`.
- `tokens.*` are **CSS `var(--…, fallback)` references** resolved against host-injected variables, so light/dark switches with **no React re-render** — but not every token is host-backed, and the unbacked ones fall back to light in *every* theme (gotcha L).
- Brand fonts load via a **side-effect import**: `import "@nimblebrain/synapse/ui/fonts"`.

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
- It **spawns your server over stdio**, deriving the command from `manifest.server.mcp_config` (rewriting `python` → `uv run python` when a `pyproject.toml` exists), proxies `tools/call` over `POST /__mcp`, injects theme tokens, and defaults to dark with a toggle.
- It **does not inject HTTP identity headers.** An edge-fronted server that reads `x-tenant-id`/`x-workspace-id` and needs a DB returns `unauthenticated` for every call in preview. Drive it instead with a **seeded stdio mock** that returns `{ content: [{ type: "text", text: JSON.stringify(payload) }] }`, wired via `synapseVite({ serverCmd })` behind an env flag.
- It **deliberately does not emit `synapse/data-changed` for UI-initiated tool calls** (infinite-loop guard). So in preview, UI mutations only refresh via your own `onDone`/reload callbacks — `useDataSync` fires only for agent-initiated changes.

## G. Build config is load-bearing
`vite-plugin-singlefile` + `build.assetsInlineLimit: Infinity` produce one inlined HTML (`viteSingleFile()` is build-only — a no-op in dev). `synapseVite()` reads only `manifest.name` + `manifest.server.mcp_config`.

## H. Bridge & hooks
The bridge is the MCP **ext-apps spec (`2026-01-26`)** plus NimbleBrain `synapse/*` extensions (`data-changed`, `persist-state`, `action`, `request-file`, `download-file`) that degrade to no-ops in non-NimbleBrain hosts. `data-changed` is keyed on the **bare server name** (entity-blind), which is why any MCP server — not just a particular framework — gets live refresh for free. Available hooks: `useSynapse, useCallTool, useCallToolAsTask, useDataSync, useTheme, useHostContext, useVisibleState, useFileUpload, useChat, useAction, useAgentAction, useStore`.

## J. Package hard rules
Per the SDK's own contributor docs: never hand-type ext-apps method strings or message param shapes (import the constants/types from `@modelcontextprotocol/ext-apps`); never `as any` a content block; use `connect()` for standalone widgets vs `createSynapse()`/`SynapseProvider` for host apps.

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

## L. Not every `tokens.*` is host-backed — three fall back to light in *every* theme
`tokens.*` are `var(--…, fallback)` refs (gotcha B), but the host injects only a **subset** of the vars they reference. It sets `--color-background-primary`/`-secondary`, `--color-text-primary`/`-secondary`/`-accent`, `--color-border-primary`, `--color-ring-primary` — in **both** themes. It does **not** set `--color-background-tertiary`, `--color-text-tertiary`, `--color-border-secondary`, so these three tokens always resolve to their **hardcoded light fallbacks**, theme-blind:

| Token | References | Unset → resolves to |
|---|---|---|
| `tokens.bgSubtle` | `--color-background-tertiary` | `#f3f4f6` (light) |
| `tokens.fgFaint` | `--color-text-tertiary` | `#9ca3af` (light) |
| `tokens.borderStrong` | `--color-border-secondary` | `#d1d5db` (light) |

A surface painted `bgSubtle` with `fg` text (which **is** dark-aware → near-white in dark) is **white-on-white in dark mode** — and looks perfect in light, passes `tsc`/`build`, and renders fine until you toggle the theme. For surfaces use `bg` / `bgRaised`, for borders `border`, for text `fg` / `fgMuted` (all host-backed in both themes). **A token's fallback is a safety net, not a theme — an unset var leaks its light fallback into dark.** Which vars the host sets is its contract and can shift between SDK/host versions, so don't memorize the list: **toggle the preview to dark and verify every surface** (gotcha F — the preview defaults to dark, with a toggle in its header).

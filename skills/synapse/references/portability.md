# Portability — what the SDK does in a host that isn't NimbleBrain

A Synapse app is an **MCP app**: one inlined HTML file served as a `ui://` resource and mounted
over the [MCP ext-apps](https://modelcontextprotocol.io/extensions/apps/overview) (`2026-01-26`)
`postMessage` bridge. From 0.19.0, `@nimblebrain/synapse` runs on the spec's own client —
`@modelcontextprotocol/ext-apps`'s `App` owns the transport, the handshake and the wire schemas —
and is the framework on top of it: theme injection, parsed tool results, multi-subscriber events,
resize, and the NimbleBrain extensions. It is not a private protocol.

NimbleBrain is the host the SDK is developed and verified against, and it implements a small set
of `synapse/*` extensions on top of the spec. Everything below was read out of
`@nimblebrain/synapse@0.19.0` source, so you can re-check any row at
`github.com/NimbleBrainInc/synapse`.

## Feature-detect at runtime

`<AppProvider>` renders **nothing** until the `ui/initialize` handshake completes, so by the time a
component reads `useApp().isNimbleBrainHost` (or `hostInfo`, or `supportsTasks`) it is settled, and
it does not change afterwards. `{app.isNimbleBrainHost && <Upload/>}` is therefore safe.

Two consequences of the provider gate:

- **Where the handshake never returns, nothing renders.** Opening the built HTML directly, or a
  host that never answers `ui/initialize`, leaves a blank pane. The preview (gotcha F) answers the
  handshake, so develop there.
- **A handshake the spec's client refuses is thrown during render**, so it reaches your nearest
  error boundary. A host that answers with fields outside the spec (an unknown
  `styles.variables` key, pre-spec `serverInfo`/`capabilities` naming) cannot connect at all.

Branching on the host identity is for hiding an affordance the host can't fulfil. It is not
needed to avoid a crash: every extension below either no-ops or throws something catchable.

## Per-hook

The SDK checks the host's capabilities for exactly two things, `downloadFile` and tasks. Every
other spec call goes out regardless, and **no request carries a deadline** (a picker waiting on a
person, a blocking task result and a slow tool all need that). So the column that matters is
**how each call fails where the host ignores it**.

| Hook / function | Wire | In a host that doesn't implement it |
|---|---|---|
| `AppProvider`, `useApp` | the `ui/initialize` handshake and the `App` handle | works |
| `useTheme`, `useHostContext` | ext-apps host context and `ui/notifications/host-context-changed` | works. `fontFaces` rides the `synapse/fontFaces` context key — absent, the web-safe token fallbacks stay in force (gotcha N). Host-specific context fields are absent elsewhere — type them optional |
| `useToolResult`, `useToolInput`, `useResize` | ext-apps tool notifications and `ui/notifications/size-changed` | works |
| `useCallTool`, `app.callTool` | `tools/call` — **request** | a host that drops the call leaves the promise **pending forever**: `isPending` stays `true`, no error arrives. A host that answers with an error rejects, and `useCallTool` sets `error`. The call reaches the app's own server only |
| `app.readServerResource` | `resources/read` — **request** | same pending-forever shape as `useCallTool` |
| `useDataSync` | `notifications/resources/list_changed`, inbound, from the app's own server | fires wherever the host relays it (capability `serverResources.listChanged`). The SDK does not read that capability, so there is nothing to check: where the host doesn't relay, the hook is simply quiet. **It also needs your server to announce its writes** — without that it is quiet on every host |
| `useModelContext`, `app.updateModelContext` | `ui/update-model-context` — request, fire-and-forget | returns nothing and swallows the failure: where unsupported it vanishes without a trace |
| `useSendMessage`, `app.sendMessage` | `ui/message` — request, fire-and-forget | same as `useModelContext`. The optional `context` argument becomes `_meta.context` on NimbleBrain only |
| `app.openLink` | `ui/open-link` — **request** | falls back to `window.open(url, "_blank", "noopener")` **only on an explicit rejection** — a host that ignores the request never settles it, so the fallback never runs and links quietly do nothing |
| `downloadFile(app, …)` | `ui/download-file` — **request** | **rejects without sending** when the host didn't advertise the `downloadFile` capability. Resolves `{ isError: true }` when the host declined or the user cancelled. Handle the promise |
| `useCallToolAsTask`, `callToolAsTask` | MCP 2025-11-25 tasks — `tools/call` with a `task` param, then `tasks/*` | **throws** unless the host negotiated `experimental["io.modelcontextprotocol/tasks"]` (`app.supportsTasks`). Fall back to `callTool` |
| `useFileUpload` (`pickFile`, `pickFiles`) | `synapse/request-file` **(extension)** | **throws** `pickFile is not supported in this host` — an explicit host check, not a failed request |
| `useAction`, `action(app, …)` | `synapse/action`, outbound **(extension)** | **silent no-op** — guarded, returns without sending |
| `connect({ forwardKeys })` | `synapse/keydown` **(extension)** | not sent — forwarding only starts on a NimbleBrain host |

## What you actually lose

Only the handshake, theming, host context and the tool notifications are unconditional. Tool calls,
resource reads, agent-visible state and chat are spec but ride **optional** host capabilities, and
the SDK sends them without checking. Since no request has a deadline, a host that doesn't proxy tool
calls leaves every `useCallTool` **pending forever** — indistinguishable from a slow server, so
probe once at startup rather than debugging it per component. Agent-visible state and chat fail the
other way: they vanish with nothing to observe at all. The `connectUI()` path models this properly —
`capabilities().pull` plus `HostUnsupportedError` — worth copying if you target unknown hosts.

Beyond that, a non-NimbleBrain host costs you **the file picker** (it throws) and **host actions and
keyboard forwarding** (silent). Live refresh and file download are spec, so they travel to any host
that relays `list_changed` and advertises `downloadFile`.

## Two connection entry points

`connect()` / `<AppProvider>` (→ `App`) is **this skill's path** — a full app in a pane, and a
component rendered from a tool result alike (`useToolResult` / `useToolInput` / `useResize`). The
spec plus the `synapse/*` extensions above, each degrading as the table says.

`connectUI()` (→ `SynapseUIClient`, from `@nimblebrain/synapse/host`) is the explicitly cross-host
one: it feature-detects the browsing context, selects a per-host adapter, and exposes
`capabilities()` (`pull`, `sendPrompt`, `openLink`) so a widget can branch on what the host
actually offers, throwing `HostUnsupportedError` where it doesn't. Push-first and widget-shaped —
the tool output that spawned it arrives at render via `data()` / `onData()`. It is not a substitute
for `AppProvider` in a full app.

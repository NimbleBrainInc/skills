# Portability — what the SDK does in a host that isn't NimbleBrain

A Synapse app is an **MCP app**: one inlined HTML file served as a `ui://` resource and mounted
over the [MCP ext-apps](https://modelcontextprotocol.io/extensions/apps/overview) (`2026-01-26`)
`postMessage` bridge. `@nimblebrain/synapse` calls itself an "Agent-aware app SDK for the MCP
ext-apps protocol", peer-depends on `@modelcontextprotocol/ext-apps`, and imports its method
constants from it. It is an enhancement layer over the spec, not a private protocol.

NimbleBrain is the host the SDK is developed and verified against, and it implements a small set
of `synapse/*` extensions on top of the spec. Everything below was read out of
`@nimblebrain/synapse@0.13.0` — `dist/*.d.ts` and the shipped `dist/*.js` — so you can re-check any
row from npm or `github.com/NimbleBrainInc/synapse`.

## Feature-detect at runtime

`useSynapse().isNimbleBrainHost` is a boolean on the `Synapse` interface, assigned inside the
`ui/initialize` response handler. Two consequences, both easy to get wrong:

- **It is `false` until the handshake resolves.** `SynapseProvider` renders `children` immediately,
  beside `ThemeInjector` and with no ready gate, so a read during first render says "not
  NimbleBrain" on NimbleBrain.
- **It carries no subscription.** Unlike `useTheme`/`useHostContext`, nothing re-renders when it
  flips, so the first answer is the only one React ever sees.

So `{synapse.isNimbleBrainHost && <Upload/>}` hides the feature on the host that supports it.

The option with no failure mode of its own is to **skip the check** and handle the failure at the
call — `pickFile` throws synchronously and is cheap to `try`/`catch`. `await synapse.ready` and
ready-gated state both work too, but `ready` *is* the `ui/initialize` request on the same
undeadlined transport, so anywhere the handshake never returns (the built HTML opened directly, the
preview path in gotcha F) a `ready`-gated feature never renders at all.

## Per-hook

Every ext-apps host capability below is optional and the SDK checks none of them, so the column
that matters is **how each call fails**. That follows the call type: a *request* rides a transport
with no deadline and hangs unresolved; a *notification* carries no `id` and no promise, so it is
dropped without a trace. Neither surfaces an error **where the host ignores the call** — that is
the silent case. A host that answers with a JSON-RPC error does reject, and `useCallTool` sets
`error`, clears `isPending` and rethrows.

| Hook / method | Wire | In a host that doesn't implement it |
|---|---|---|
| `useSynapse` | the `ui/initialize` handshake and the `Synapse` handle | works |
| `useCallTool`, `callTool` | ext-apps `tools/call` — **request** | gated on `serverTools`. A host that omits it and drops the call leaves the promise **pending forever**: `isPending` stays `true`, no error arrives, the spinner never stops |
| `useCallToolAsTask` | MCP 2025-11-25 tasks — `tools/call` with a `task` param, then `tasks/result` / `tasks/get` / `tasks/cancel` | **throws** unless the host advertised `tasks.requests.tools.call` at init; the message tells you to fall back to `callTool`. This gate is the MCP tasks utility, not an ext-apps host capability — `McpUiHostCapabilities` has no `tasks` member at all, so a host can only advertise it as an undeclared extra key. Assume this throws anywhere but NimbleBrain |
| `useTheme` | ext-apps host context (`theme`, `styles.variables`) | works. `fontFaces` rides the `synapse/fontFaces` context key — absent, the web-safe token fallbacks stay in force (gotcha N) |
| `useHostContext` | ext-apps `ui/notifications/host-context-changed` | works. Host-specific fields are absent (NimbleBrain publishes `workspace`) — type them optional and tolerate `undefined` |
| `useVisibleState` | ext-apps `ui/update-model-context` — **notification** | gated on `updateModelContext`. Silently dropped where unsupported — there is no promise, so there is nothing to catch |
| `useChat` | ext-apps `ui/message` — **notification** | gated on `message`. Delivered where supported, silently dropped where not. The optional `context` argument is a NimbleBrain-only `_meta.context` and is never attached elsewhere |
| `readResource` | ext-apps `resources/read` — **request** | gated on `serverResources`; same pending-forever shape as `useCallTool` |
| `openLink` | ext-apps `ui/open-link` — **request** | gated on `openLinks`. Falls back to `window.open(url, "_blank", "noopener")` **only on an explicit rejection** — a host that ignores the request never settles the promise, so the fallback never runs and links quietly do nothing |
| `useFileUpload` | `synapse/request-file` **(extension)** | **throws** `pickFile is not supported in this host` (and `pickFiles …` from the multi-file picker) — an explicit `isNimbleBrainHost` guard, not a failed request |
| `useAction` | `synapse/action`, outbound **(extension)** | **silent no-op** — guarded, returns without sending |
| `useAgentAction` | `synapse/action`, inbound **(extension)** | the callback never fires |
| `useDataSync` | `synapse/data-changed`, inbound **(extension)** | the callback never fires — no agent-driven refresh. Drive reloads from your own `onDone`, as you already must in preview (gotcha F) |
| `downloadFile` | `synapse/download-file`, outbound **(extension)** | the notification is sent **unguarded** and dropped on the floor: nothing downloads, nothing throws, and there is no local anchor fallback. Downloading itself is not the problem — ext-apps has `ui/download-file` behind the `downloadFile` host capability; a portable app sends that request itself instead of calling `synapse.downloadFile()` |
| `useStore` | in memory, plus `synapse/persist-state` / `synapse/state-loaded` **(extensions)** | the store works. Persistence is silently swallowed (`.catch(() => {})`) and nothing rehydrates. `visibleToAgent: true` is spec rather than an extension, so it outlives persistence — but it routes through `setVisibleState` and rides the same optional `updateModelContext` gate as `useVisibleState` above, and is dropped just as silently |

`SynapseOptions.forwardKeys` sends `synapse/keydown`, also unguarded and also dropped elsewhere.

## What you actually lose

Only the handshake, theming and host context are unconditional. Tool calls, resource reads,
agent-visible state and chat are spec but ride **optional** host capabilities (`serverTools`,
`serverResources`, `updateModelContext`, `message`), and the SDK sends them without checking
`hostCapabilities` — it extracts only `tasks` at init. Since `SynapseTransport.request()` sets no
timeout, a host that doesn't proxy tool calls leaves every `useCall<T>()` **pending forever**:
`isPending` stays `true`, no error arrives, and the spinner never stops. That failure is
indistinguishable from a slow server, so probe once at startup rather than debugging it per
component. Agent-visible state and chat fail the other way — they are notifications, so they
vanish with nothing to observe at all. The `connectUI()` path models this properly —
`capabilities().pull` plus `HostUnsupportedError` — worth copying if you target unknown hosts.

Beyond that, a non-NimbleBrain host costs you **agent-driven refresh**
(`useDataSync` / `useAgentAction` go quiet), **file pick and file download**, and **state that
survives a reload**. Two of those fail loudly (`useFileUpload` throws) and the rest fail quietly,
which is the more expensive kind: a `downloadFile` button that does nothing looks like a bug in
your app.

## Three connection entry points

`connect()` / `AppProvider` (→ `App`) is the ext-apps widget path: a component rendered from a
tool result, with `useToolResult` / `useToolInput` / `useResize`. Pure spec.

`createSynapse()` / `SynapseProvider` (→ `Synapse`) is **this skill's path** — a full app in a
pane, ext-apps plus the `synapse/*` extensions above. Host-neutral for everything in the spec rows.

`connectUI()` (→ `SynapseUIClient`, 0.13.0+) is the explicitly cross-host one: it feature-detects
the browsing context, selects a per-host adapter, and exposes `capabilities()` (`pull`,
`sendPrompt`, `openLink`) so a widget can branch on what the host actually offers, throwing
`HostUnsupportedError` where it doesn't. Push-first and widget-shaped — the tool output that
spawned it arrives at render via `data()` / `onData()`. It is not a substitute for
`SynapseProvider` in a full app.

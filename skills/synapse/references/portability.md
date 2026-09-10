# Portability — what the SDK does in a host that isn't NimbleBrain

A Synapse app is an **MCP app**: one inlined HTML file served as a `ui://` resource and mounted
over the [MCP ext-apps](https://modelcontextprotocol.io/specification/2025-06-18/user-interaction/ext-apps)
`postMessage` bridge. `@nimblebrain/synapse` calls itself an "Agent-aware app SDK for the MCP
ext-apps protocol", peer-depends on `@modelcontextprotocol/ext-apps`, and imports its method
constants from it. It is an enhancement layer over the spec, not a private protocol.

NimbleBrain is the host the SDK is developed and verified against, and it implements a small set
of `synapse/*` extensions on top of the spec. Everything below was read out of
`@nimblebrain/synapse@0.13.0` — `dist/*.d.ts` and the shipped `dist/*.js` — so you can re-check any
row from npm or `github.com/NimbleBrainInc/synapse`.

## Feature-detect at runtime

`useSynapse().isNimbleBrainHost` is a boolean on the `Synapse` interface, resolved from the
`ui/initialize` handshake. Branch on it before calling anything in a **throws** row below.

## Per-hook

| Hook / method | Wire | In a host that doesn't implement it |
|---|---|---|
| `useSynapse` | the `ui/initialize` handshake and the `Synapse` handle | works |
| `useCallTool`, `callTool` | ext-apps `tools/call` | works |
| `useCallToolAsTask` | MCP 2025-11-25 tasks — `tools/call` with a `task` param, then `tasks/result` / `tasks/get` / `tasks/cancel` | **throws** unless the host advertised `tasks.requests.tools.call` at init. The message tells you to fall back to `callTool` |
| `useTheme` | ext-apps host context (`theme`, `styles.variables`) | works. `fontFaces` rides the `synapse/fontFaces` context key — absent, the web-safe token fallbacks stay in force (gotcha N) |
| `useHostContext` | ext-apps `ui/notifications/host-context-changed` | works. Host-specific fields are absent (NimbleBrain publishes `workspace`) — type them optional and tolerate `undefined` |
| `useVisibleState` | ext-apps `ui/update-model-context` | works |
| `useChat` | ext-apps `ui/message` | the message is delivered. The optional `context` argument is a NimbleBrain-only `_meta.context` and is simply not attached elsewhere |
| `readResource` | ext-apps `resources/read` | works |
| `openLink` | ext-apps `ui/open-link` | works, and on rejection falls back to `window.open(url, "_blank", "noopener")` |
| `useFileUpload` | `synapse/request-file` **(extension)** | **throws** `pickFile is not supported in this host` — an explicit `isNimbleBrainHost` guard, not a failed request |
| `useAction` | `synapse/action`, outbound **(extension)** | **silent no-op** — guarded, returns without sending |
| `useAgentAction` | `synapse/action`, inbound **(extension)** | the callback never fires |
| `useDataSync` | `synapse/data-changed`, inbound **(extension)** | the callback never fires — no agent-driven refresh. Drive reloads from your own `onDone`, as you already must in preview (gotcha F) |
| `downloadFile` | `synapse/download-file`, outbound **(extension)** | the notification is sent **unguarded** and dropped on the floor: nothing downloads, nothing throws, and there is no local anchor fallback |
| `useStore` | in memory, plus `synapse/persist-state` / `synapse/state-loaded` **(extensions)** | the store works. Persistence is silently swallowed (`.catch(() => {})`) and nothing rehydrates. `visibleToAgent: true` still works — it routes through `ui/update-model-context` |

`SynapseOptions.forwardKeys` sends `synapse/keydown`, also unguarded and also dropped elsewhere.

## What you actually lose

Tool calls, theming, host context, agent-visible state and chat are all spec — an app that sticks
to them runs anywhere. What a non-NimbleBrain host costs you is **agent-driven refresh**
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

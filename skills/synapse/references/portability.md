# Portability — the contract every Synapse call keeps

A Synapse app is an **MCP app**: one inlined HTML file served as a `ui://` resource and mounted
over the [MCP Apps](https://modelcontextprotocol.io/extensions/apps/overview) (`2026-01-26`)
`postMessage` bridge. `@nimblebrain/synapse` runs on the spec's own client
(`@modelcontextprotocol/ext-apps`'s `App` owns the transport, the handshake and the wire schemas),
and adds a framework on top: theme injection, parsed tool results, multi-subscriber events,
resize, and three NimbleBrain extensions. It is not a private protocol. Claude, ChatGPT and
NimbleBrain all speak it.

Hosts differ in **what they offer**, not in how they speak. Each host lists what it offers in its
answer to `ui/initialize`, as `hostCapabilities`. Everything below can be re-checked against
`github.com/NimbleBrainInc/synapse`.

## The contract

Synapse reads `hostCapabilities` once, when the app connects. Every method and hook checks the
declaration **before it sends**, and does exactly one of three things when the capability is
missing:

- **A request with an answer rejects with `HostCapabilityError`, without sending.** Requests carry
  no deadline, because a file picker waits on a person and a task result blocks until the task
  ends. A request the host never answers would therefore stay pending forever, so it is never sent.
  `error.capability` names what the host did not declare.
- **A fire-and-forget call sends nothing.**
- **A hook that waits for the host keeps its initial value.**

Nothing is gated on the host's name.

| Hook / function | Needs | Without it |
|---|---|---|
| `AppProvider`, `useApp` | nothing (the handshake) | works |
| `useTheme`, `useHostContext` | nothing | neutral defaults; host-only context fields (`workspace`) are `undefined`, so type them optional |
| `useToolResult`, `useToolInput` | nothing | `null` until the host sends one; a host that mounts the app without a tool call never does |
| `useResize`, `app.resize` | nothing | always sent — the spec gates it on nothing |
| `useCallTool`, `app.callTool` | `serverTools` | `HostCapabilityError`; `useCallTool`'s `error` holds it |
| `app.readServerResource` | `serverResources` | `HostCapabilityError` |
| `useDataSync` | a host that relays `notifications/resources/list_changed` (declared as `serverResources.listChanged`) | the callback never runs. The hook only listens and does not read the declaration. **It also needs your server to announce its writes**, otherwise it stays silent on every host |
| `useModelContext`, `app.updateModelContext` | `updateModelContext` | no-op |
| `useSendMessage`, `app.sendMessage` | `message` | no-op. The optional `context` becomes `_meta.context` only on a host that identifies as NimbleBrain |
| `app.openLink` | `openLinks` | opens the URL with `window.open` instead (also when the host refuses) |
| `downloadFile(app, …)` | `downloadFile` | `HostCapabilityError`. Resolves `{ isError: true }` when the host declined or the user cancelled |
| `useCallToolAsTask`, `callToolAsTask` | `experimental["io.modelcontextprotocol/tasks"]` with `requests.tools.call` | `HostCapabilityError`. Check `app.supportsTasks`; fall back to `callTool` |
| `useAction`, `action(app, …)` | `experimental["ai.nimblebrain/action"]` | no-op |
| `useFileUpload` (`pickFile`, `pickFiles`) | `experimental["ai.nimblebrain/request-file"]` | `HostCapabilityError` |
| `connect({ forwardKeys })` | `experimental["ai.nimblebrain/keydown"]` | keys are not captured; the browser handles them |

## Decide what to offer from the declaration

`<AppProvider>` renders **nothing** until the handshake completes, so `app.hostCapabilities`,
`app.supportsTasks` and `hostSupports(app, …)` are settled before any component reads them, and
they do not change afterwards. Hide an affordance the host cannot fulfil, instead of letting the
user press it and then showing a no-op or an error:

```tsx
import { hostSupports } from "@nimblebrain/synapse";
import { useApp, useFileUpload, useSendMessage } from "@nimblebrain/synapse/react";

const app = useApp();
const canAttach = hostSupports(app, "requestFile");
const canChat = app.hostCapabilities.message !== undefined;
```

Two consequences of the provider gate:

- **Where the handshake never returns, nothing renders.** Opening the built HTML directly, or a
  host that never answers `ui/initialize`, leaves a blank pane. The preview (gotcha F) answers the
  handshake, so develop there.
- **If the spec's client rejects the handshake, the error is thrown during render**, and your
  nearest error boundary catches it. A host whose answer has fields outside the spec (an unknown
  `styles.variables` key, `serverInfo`/`capabilities` in place of
  `hostInfo`/`hostCapabilities`) cannot connect at all.

## The portable subset

These are defined by the spec, and every host that renders apps is expected to support them:

- the handshake, host context and theme;
- tool input and results;
- `callTool` on your own server;
- `sendMessage`;
- `updateModelContext`;
- `resize`.

An app built only on these behaves the same in Claude, ChatGPT and NimbleBrain. Everything else in
the table is still spec surface, but hosts may leave it out, so read the declaration before you
offer it.

## The NimbleBrain extensions — the complete list

| Extension | Method | Declared as (`hostCapabilities.experimental`) |
|---|---|---|
| Host actions (`action`, `useAction`) | `synapse/action` | `ai.nimblebrain/action` |
| File picker (`pickFile`, `pickFiles`, `useFileUpload`), answered `{ files }` | `synapse/request-file` | `ai.nimblebrain/request-file` |
| Keyboard forwarding (`forwardKeys`) | `synapse/keydown` | `ai.nimblebrain/keydown` |

`NIMBLEBRAIN_EXTENSIONS` (package root) is the same table in code. The extensions are declared under
`experimental` because MCP Apps has no field for extensions, and `experimental` is the only part of
`hostCapabilities` whose contents a spec client keeps. Two NimbleBrain fields also ride inside spec
messages, and other hosts ignore them: `workspace` in the host context, and `_meta.context` on
`sendMessage`. The host's typeface arrives as font-face descriptors in the host context (gotcha N),
and an app with no fonts from the host falls back to web-safe stacks.

Live refresh and file download are **not** extensions. `useDataSync` rides the spec's
`notifications/resources/list_changed`, and `downloadFile` rides `ui/download-file`.

An app does not read or write host-held state. There is no persistence channel, and nothing the
host sends to the app triggers an action in it. An app reaches **its own server** and nothing else:
`callTool` takes no target server, and cross-server work belongs to the agent.

## Serving one app to Claude and ChatGPT

Every MCP Apps host reads the same metadata, so a server serves the component **once**:

- one `ui://` resource, served as `text/html;profile=mcp-app`;
- bound to its tool by `_meta.ui.resourceUri` on the tool descriptor;
- `ui.visibility` saying who may call each tool: `["model"]`, `["app"]`, or both;
- `ui.csp` declaring the origins the component loads from (`connectDomains`, `resourceDomains`);
- a server that requires sign-in declares `securitySchemes` on each tool, answers an
  unauthenticated request with a `401` carrying `resource_metadata`, and publishes
  protected-resource metadata whose `resource` equals the server URL exactly.

Do not serve a second copy under another MIME type or bind it with a host-specific key. Leave
`ui.domain` unset unless the component needs a stable origin: each host then gives the frame its
own sandbox origin.

For a Python server, `nimblebrain-synapse`'s `SynapseUI` emits all of this from one declaration:
the resource, the tool `_meta`, the `io.modelcontextprotocol/ui` extension declaration, and an
`auth_error_result` helper for the sign-in challenge. Its README has the API.

Check a running server against each host's requirements before you submit it:

```bash
npx @nimblebrain/synapse check --target claude,chatgpt https://your-server.example.com/mcp
```

## Two connection entry points

`connect()` / `<AppProvider>` (→ `App`) is **this skill's path**: a full app in a pane, or a
component rendered from a tool result (`useToolResult` / `useToolInput` / `useResize`), bound by
the contract above.

`connectUI()` (→ `SynapseUIClient`, from `@nimblebrain/synapse/host`, and `window.SynapseUI` in
the IIFE that `SynapseUI` inlines) is the small push-first client for a self-contained component
that only renders a tool's output. It speaks MCP Apps and nothing else. Inside a frame it runs the
`ui/*` handshake. Opened standalone, it renders the data baked into the page. The tool output
arrives through `data()` / `onData()`. `capabilities()` (`pull`, `sendPrompt`, `openLink`) says
what the host offers. `callTool()` rejects with `HostUnsupportedError` where the host has no pull,
and with `ToolCallError` when the result reports `isError`. It does not replace `AppProvider` in a
full app.

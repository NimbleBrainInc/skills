# NimbleBrain host contract — how the host finds and renders your UI

This is **one host's** registration extension. The bridge in §3 is the MCP ext-apps spec, which any
conforming host implements; the `_meta["ai.nimblebrain/host"]` block in §1 is NimbleBrain-specific.
Claude and ChatGPT need no such block: they render the resource a tool names in
`_meta.ui.resourceUri` (`portability.md`). Which hooks ride the spec and which ride the extensions:
`portability.md`.

NimbleBrain connects to your server by URL and never downloads or runs its code. It learns about the
server from a **catalog entry**: an MCP Registry `ServerDetail` record (the shape of a `server.json`)
that an operator adds to the workspace's connectors catalog. The host integration is that entry's
`_meta["ai.nimblebrain/host"]` block plus the `ui://` resource your server serves. The SDK never
mentions this contract. If you also ship an MCPB `manifest.json` for desktop hosts, keep the same
`_meta` block there.

## 1. Declare surfaces: `_meta["ai.nimblebrain/host"]`

The minimal, common case is a single sidebar app:

```yaml
servers:
  - name: com.example/tasks
    title: Tasks                         # the app's name in NimbleBrain
    description: A task board
    version: "1.0.0"
    remotes:
      - type: streamable-http
        url: https://tasks.example.com/mcp
    _meta:
      ai.nimblebrain/host:
        hostVersion: "1.0"
        placements:
          - slot: sidebar.apps           # where in host chrome it appears
            resourceUri: ui://tasks/main # the resource your server serves (§2)
            route: tasks                 # registers /w/<workspace>/app/tasks
            label: Tasks                 # the sidebar entry's text
```

Fields (the extension identifier `ai.nimblebrain/host` is kebab-case; every field inside it is camelCase, as in MCP's own schema):
- **`hostVersion`** — `"1.0"`. It is the contract's major version and changes only on a breaking change; every field is part of `1.0` and is turned on by declaring it. The host skips a catalog connector that declares another major.
- **No `name`, `icon`, `category`, `primaryView` or `briefing`.** The host names your app from the catalog entry's `title` (or `name`) and shows the entry's `icons`. Each `icons[].src` must be an `http(s)` URL: the host drops a catalog entry whose icon is not. The host ignores those keys like any unknown key.
- **`placements[]`** — each entry registers a surface in host chrome. `slot` ∈ `sidebar.apps` (or any `sidebar.<group>`) `| sidebar | sidebar.bottom | main | settings`; `resourceUri` is your `ui://` resource; plus `priority` (lower first, default `100`), `label`, `icon`, `route`. A placement `icon` (a Lucide name) shows only on a `sidebar.bottom` entry; a `sidebar.apps` entry shows the connector's catalog icon. A `settings` placement is your connector's section on its settings page and ignores `label` and `route`. **A placement is the "register a button in host chrome" mechanism — there is no separate `commands`/toolbar API.**
- **`route`** — name it after your server (`tasks`, `tasks/archive`). A route belongs to one server: the host drops a placement whose route is one of the host's own views or is already held by another connector in the workspace.
- **Other grants** — `hooks` (inbound webhooks), `notifications` (an outbox resource the host polls), `adminTools` and `recordArguments`. Each is a grant the operator reviews; see [the manifest reference](https://docs.nimblebrain.ai/host/manifest/). The counts an app shows on the workspace overview are not declared here: the server reports them over MCP with the facets extension.

The host reads this block from the catalog entry, registers the placements, and renders the `ui://` resource in a sandboxed iframe. You don't write any host code.

## 2. Serve the UI resource

Your server exposes the built single-file HTML as an MCP resource at the `resourceUri`:

```python
# Python / FastMCP
@mcp.resource("ui://tasks/main", mime_type="text/html;profile=mcp-app")
def app_ui() -> str:
    return load_ui()   # bare file read of ui/dist/index.html — see gotcha E for path resolution
```

The HTML must be **identity-free and static** — never bake user or workspace data into it. All data is fetched at runtime through the bridge (which carries the verified identity). The handler must not open a DB/auth session, so the shell still loads when the server's readiness probe is failing.

## 3. The bridge (what the iframe and host exchange)

The host mounts the HTML in a sandboxed iframe and speaks the MCP **Apps spec (`2026-01-26`)** over `postMessage`. It declares the spec capabilities it serves and the `ai.nimblebrain/*` extensions in its `ui/initialize` answer; those extensions work here and degrade as `portability.md` describes on other hosts. The `@nimblebrain/synapse` React SDK wraps all of it — you use hooks, not raw messages:

- `useApp().callTool(name, args)` / `useCallTool(name)` → invoke your server's tools (`tools/call`).
- `useDataSync(cb)` → re-fetch when your **server** announces a write. The server sends `notifications/resources/list_changed`, and the host relays it verbatim to that server's views. It covers every writer (the agent, another view, a webhook), and a write the server doesn't announce refreshes nothing.
- `useTheme()` / `tokens` → host theme (light/dark via CSS variables).
- `useModelContext(...)` → push the UI's current state so the agent can see what the user is looking at.
- `useHostContext()` → workspace + host context.
- `useTrail(trail, navigate)` → report where the app is; the host shows the title and breadcrumb and calls `navigate(id)` when the user picks a level. Make `navigate` resolve any record URI, not only the levels on screen: it is also how the app is opened at a record.
- `useOpen()` → ask the host to show what a URI names. `useOpenConnectorSettings()` → this connector's settings page. `useNotify()` → a notice labelled with your app.

**Being opened at a record.** When the agent or another app opens a URI, the host finds the one app whose server advertises a resource template (`resources/templates/list`) the URI expands from, shows it, and hands it the URI as `navigate` once the app has reported its trail. So give each record kind a URI template your server serves a read at, stamp that URI on the rows your tools return, and report it as the record's trail entry. A URI two apps claim opens neither.

The UI talks **only** to your server's own tools over this bridge. It never reaches the host's internals, and it never needs server-to-server calls.

## Mental model
- NimbleBrain connects to your **server** by URL; the operator's catalog entry describes it.
- **This skill** gives that server a UI.
- The contract = *declare placements on the catalog entry* + *serve a `ui://` resource* + *call your own tools over the bridge*. Everything else is the host's job.

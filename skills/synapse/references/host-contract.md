# NimbleBrain host contract — how the host finds and renders your UI

This is **one host's** registration extension. The bridge in §3 is the MCP ext-apps spec, which any
conforming host implements; the `_meta["ai.nimblebrain/host"]` manifest block in §1 is
NimbleBrain-specific. Claude and ChatGPT need no manifest: they render the resource a tool names in `_meta.ui.resourceUri` (`portability.md`). Which
hooks ride the spec and which ride the extensions: `portability.md`.

The host integration is a **manifest declaration** plus a **served resource**. The SDK never mentions this contract — it lives in the bundle `manifest.json`.

## 1. Declare surfaces: `_meta["ai.nimblebrain/host"]`

Add this block to your bundle's `manifest.json`. The minimal, common case is a single sidebar app:

```jsonc
{
  "_meta": {
    "ai.nimblebrain/host": {
      "host_version": "1.1",
      "name": "Tasks",
      "icon": "list-todo",
      "category": "productivity",
      "placements": [
        {
          "slot": "sidebar.apps",            // where in host chrome it appears
          "resourceUri": "ui://tasks/main",  // the resource your server serves (§2)
          "route": "@owner/your-server",     // stable app route
          "label": "Tasks",
          "icon": "list-todo"
        }
      ]
    }
  }
}
```

Fields:
- **`host_version`** — `"1.0"` or `"1.1"`.
- **`placements[]`** — each entry registers a surface in host chrome. `slot` ∈ `sidebar | sidebar.apps | sidebar.bottom | main`; `resourceUri` is your `ui://` resource; plus `priority`, `label`, `icon`, `route`, `size`. **A placement is the "register a button in host chrome" mechanism — there is no separate `commands`/toolbar API.**
- **`primaryView`** — `{ "resourceUri": "ui://…" }` for the default view.
- **`settings`** — a settings-tab panel: `{ id, label, icon, resourceUri }`.
- **`briefing.facets[]`** — dashboard cards. Each resolves via one of `entity` | `resource` | `tool`. **Use `tool` or `resource` facets** (`{ name, label, type, tool, metric }`); the `entity` path is for the declarative data framework only.

The host parses this at install, registers the placements, and renders the `ui://` resource in a sandboxed iframe. You don't write any host code.

## 2. Serve the UI resource

Your server exposes the built single-file HTML as an MCP resource at the `resourceUri`:

```python
# Python / FastMCP
@mcp.resource("ui://tasks/main", mime_type="text/html;profile=mcp-app")
def app_ui() -> str:
    return load_ui()   # bare file read of ui/dist/index.html — see gotcha E for path resolution
```

The HTML must be **identity-free and static** — never bake tenant/workspace data into it. All data is fetched at runtime through the bridge (which carries the verified identity). The handler must not open a DB/auth session, so the shell still loads when the server's readiness probe is failing.

## 3. The bridge (what the iframe and host exchange)

The host mounts the HTML in a sandboxed iframe and speaks the MCP **Apps spec (`2026-01-26`)** over `postMessage`. From the host release that closes [nimblebrain#1239](https://github.com/NimbleBrainInc/nimblebrain/issues/1239), it declares the spec capabilities it serves and the three `ai.nimblebrain/*` extensions in its `ui/initialize` answer. The file picker, host actions and keyboard forwarding then work here, and degrade as `portability.md` describes on other hosts. The `@nimblebrain/synapse` React SDK wraps all of it — you use hooks, not raw messages:

- `useApp().callTool(name, args)` / `useCallTool(name)` → invoke your server's tools (`tools/call`).
- `useDataSync(cb)` → re-fetch when your **server** announces a write. The server sends `notifications/resources/list_changed`, and the host relays it verbatim to that server's views. It covers every writer (the agent, another view, a webhook), and a write the server doesn't announce refreshes nothing.
- `useTheme()` / `tokens` → host theme (light/dark via CSS variables).
- `useModelContext(...)` → push the UI's current state so the agent can see what the user is looking at.
- `useHostContext()` → workspace + host context.

The UI talks **only** to your server's own tools over this bridge. It never reaches the host's internals, and it never needs server-to-server calls.

## Mental model
- **mpak** = capabilities (executable bundles).
- **this skill** = how to give a bundle a UI.
- The contract = *declare placements in the manifest* + *serve a `ui://` resource* + *call your own tools over the bridge*. Everything else is the host's job.

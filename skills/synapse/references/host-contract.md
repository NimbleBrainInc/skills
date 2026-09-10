# Host contract — how the NimbleBrain host finds and renders your UI

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
- **`host_version`** — the newest block you declare: `"1.0"` / `"1.1"` (placements and briefing), `"1.2"` (inbound webhooks), `"1.3"` (a notifications outbox), `"1.4"` (lifecycle, §4).
- **`placements[]`** — each entry registers a surface in host chrome. `slot` ∈ `sidebar | sidebar.apps | sidebar.bottom | main`; `resourceUri` is your `ui://` resource; plus `priority`, `label`, `icon`, `route`, `size`. **A placement is the "register a button in host chrome" mechanism — there is no separate `commands`/toolbar API.**
- **`primaryView`** — `{ "resourceUri": "ui://…" }` for the default view.
- **`settings`** — a settings-tab panel: `{ id, label, icon, resourceUri }`.
- **`briefing.facets[]`** — dashboard cards. Each resolves via one of `entity` | `resource` | `tool`. **Use `tool` or `resource` facets** (`{ name, label, type, tool, metric }`); the `entity` path is for the declarative data framework only.

The host parses this at install, registers the placements, and renders the `ui://` resource in a sandboxed iframe. You don't write any host code.

## 2. Serve the UI resource

Your server exposes the built single-file HTML as an MCP resource at the `resourceUri`:

```python
# Python / FastMCP
@mcp.resource("ui://tasks/main", mime_type="text/html")
def app_ui() -> str:
    return load_ui()   # bare file read of ui/dist/index.html — see gotcha E for path resolution
```

The HTML must be **identity-free and static** — never bake tenant/workspace data into it. All data is fetched at runtime through the bridge (which carries the verified identity). The handler must not open a DB/auth session, so the shell still loads when the server's readiness probe is failing.

## 3. The bridge (what the iframe and host exchange)

The host mounts the HTML in a sandboxed iframe and speaks the MCP **ext-apps spec (`2026-01-26`)** over `postMessage`. The `@nimblebrain/synapse` React SDK wraps all of it — you use hooks, not raw messages:

- `useSynapse().callTool(name, args)` / `useCallTool(name)` → invoke your server's tools (`tools/call`).
- `useDataSync(cb)` → re-fetch when the **agent** mutates data (the host broadcasts `data-changed` keyed on the bare server name; UI-initiated calls don't fire it).
- `useTheme()` / `tokens` → host theme (light/dark via CSS variables).
- `useVisibleState(...)` → push the UI's current state so the agent can see what the user is looking at.
- `useHostContext()` → workspace + host context.

The UI talks **only** to your server's own tools over this bridge. It never reaches the host's internals, and it never needs server-to-server calls.

## 4. Lifecycle: being told you were installed, and that you are going away

A UI is not the only thing a server needs the host for. If yours holds
per-workspace state somewhere else — a tenancy at a vendor, a bucket, a sending
domain — it has to set that up when it is installed and release it when it is
removed, and nothing in MCP tells you either moment.

Declare `lifecycle` (with `host_version: "1.4"`) and the host calls two of your
own tools:

```jsonc
{
  "_meta": {
    "ai.nimblebrain/host": {
      "host_version": "1.4",
      "lifecycle": {
        "on_ready": "workspace_ready",         // called with { reason: "install" | "resume" }
        "on_removing": "workspace_removing"    // called with no arguments, before teardown
      }
    }
  }
}
```

Both optional; declare either alone.

- **`on_ready`** fires the first time your server is reachable in a workspace and
  on later reconnects until one call succeeds. `reason` answers one question —
  *was this the user's install?* — and `"resume"` is every other cause (a host
  restart, a reconnect, a re-auth, a redeploy). Its text result is shown to the
  user as a notice on the install, so write it for them.
- **`on_removing`** fires immediately before the connector is uninstalled, while
  your server is still reachable. It is the only moment you can release
  per-workspace state you hold at a third party.

Four rules bind:

1. **Handlers must be idempotent.** Delivery is at-least-once, and a fresh
   install delivers **two** `on_ready` calls in a racy order. Write "make this
   true", not "do this once".
2. **They must be callable with no arguments** — no required property in the
   `inputSchema` — and must **accept and ignore arguments they do not declare**,
   because the host sends `reason` whether or not your schema mentions it.
   FastMCP/pydantic and the MCP TypeScript SDK already do this.
3. **Return quickly.** `on_ready` runs inside the install the user is watching.
   Record the intent and let your own background work converge it.
4. **Never assume `on_removing` arrives.** It is best-effort and never blocks the
   uninstall — the host may have been down, or your server unreachable. Pair it
   with something of your own that converges, or you are leaking a third-party
   resource on a call nothing guarantees.

There is no `pre_install` and no `post_uninstall`: the notification is a tool
call on *your* server, so before it is reachable and after it is gone there is
nothing to call. Same asymmetry as Kubernetes `postStart`/`preStop`, VS Code
`activate`/`deactivate`, Chrome `onInstalled`/`onSuspend`.

```python
@mcp.tool()
def workspace_ready(reason: str = "resume") -> str:
    state = request_tenancy(current_workspace())   # upsert, not insert
    if reason == "install":
        return "Setting up your workspace. It will be ready in a few seconds."
    return f"Workspace: {state}."

@mcp.tool()
def workspace_removing() -> str:
    release_tenancy(current_workspace())
    return "Releasing your workspace."
```

## Mental model
- **mpak** = capabilities (executable bundles).
- **this skill** = how to give a bundle a UI.
- The contract = *declare placements in the manifest* + *serve a `ui://` resource* + *call your own tools over the bridge*. Everything else is the host's job.

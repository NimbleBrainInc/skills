# Deploying: the server's `server.json`

Every server ships a `server.json` beside its Server Card. Both describe the same server, for different readers:

| | Server Card | `server.json` |
|---|---|---|
| What it is | An MCP Server Card ([SEP-2127](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/2127)), served by the running server at `<mcp-url>/server-card` | An MCP Registry `ServerDetail` ([format](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/server-json/generic-server-json.md)), a file in the repository |
| Who reads it | A host that has only a URL: a local NimbleBrain's `npx nimblebrain mcp add` | An operator adding the server to a deployed NimbleBrain's [connectors catalog](https://docs.nimblebrain.ai/config/connectors-catalog/), and the [official MCP Registry](https://github.com/modelcontextprotocol/registry) |
| Where it comes from | Code: `FastMCP(...)` and `add_server_card(...)` | Written by hand, restating the card's values |
| What only it carries | Nothing: it restates `serverInfo` | `remotes` (the deployed URL) and, for a published package, `packages` |

## One source of metadata

The card is built from code, so the code is the source. `server.json` restates the same values and adds where the server is deployed:

| Field | Value |
|---|---|
| `$schema` | the Registry schema URL the current [format docs](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/server-json/generic-server-json.md) name |
| `name` | the reverse-DNS name, one slash: the `FastMCP("com.acme/tickets")` name |
| `title`, `description` | the `add_server_card(title=, description=)` values (each 1 to 100 characters) |
| `version` | the package version, never a range |
| `websiteUrl`, `icons` | the `FastMCP(website_url=, icons=)` values; Registry icons must be `https:` |
| `_meta["ai.nimblebrain/host"]` | `{"host_version": "1.0", "placements": [...]}`, the card's placements (an app only) |
| `remotes` | `[{"type": "streamable-http", "url": "<deployed URL>/mcp"}]` |
| `packages` | for a package published to PyPI or npm (`references/packaging.md`) |

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "com.acme/tickets",
  "title": "Acme Tickets",
  "description": "Search, read and update Acme support tickets.",
  "version": "1.2.0",
  "websiteUrl": "https://acme.example/tickets",
  "repository": { "url": "https://github.com/acme/mcp-tickets", "source": "github" },
  "icons": [{ "src": "https://acme.example/tickets.png", "mimeType": "image/png", "sizes": ["128x128"] }],
  "remotes": [{ "type": "streamable-http", "url": "https://tickets.acme.example/mcp" }],
  "packages": [
    {
      "registryType": "pypi",
      "registryBaseUrl": "https://pypi.org",
      "identifier": "mcp-acme-tickets",
      "version": "1.2.0",
      "transport": { "type": "stdio" },
      "environmentVariables": [
        { "name": "ACME_API_KEY", "description": "Your Acme API key", "isRequired": true, "isSecret": true }
      ]
    }
  ],
  "_meta": {
    "ai.nimblebrain/host": {
      "host_version": "1.0",
      "placements": [
        { "slot": "sidebar.apps", "resourceUri": "ui://tickets/board", "label": "Tickets", "route": "tickets" }
      ]
    }
  }
}
```

A connector without an interface leaves out `_meta`. A server that is only deployed, with no published package, leaves out `packages`.

Keep the two in agreement, in a test or a release step: with the server running, compare `curl -s http://127.0.0.1:8000/mcp/server-card` field by field (`name`, `title`, `description`, `version`, `icons`, and the placements under `_meta`) to `server.json`. Bump `server.json`'s `version` (and each package's) in the same change as the package version.

## In a deployed NimbleBrain

NimbleBrain connects only to an entry's `remotes`; an entry with only `packages` is not installable. An operator adds the record to the deployment's catalog directory, inside a `servers:` list (a catalog file is a list of `ServerDetail` records), and NimbleBrain reads its `title`, `icons` and `_meta["ai.nimblebrain/host"]`. The host block can carry more than placements (webhooks, notifications, admin-only tools); those are grants the operator reviews in the catalog entry, and a card's are ignored. The fields are in the [manifest reference](https://docs.nimblebrain.ai/host/manifest/). Use an HTTPS URL in `remotes`.

## On the official MCP Registry

A server can be listed on the official MCP Registry with `mcp-publisher`, from the directory that holds `server.json`:

```bash
mcp-publisher login github     # or: login dns / login http, for a domain namespace
mcp-publisher publish
```

The Registry's rules, from its [publishing guide](https://github.com/modelcontextprotocol/registry/blob/main/docs/modelcontextprotocol-io/quickstart.mdx) and [requirements](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/server-json/official-registry-requirements.md):

- **The name proves its namespace.** GitHub login grants `io.github.<user>/*` (and `io.github.<org>/*` to the org's owners); `com.acme/*` needs a DNS or HTTP proof for `acme.com`.
- **Each package proves its owner.** A PyPI package's README carries `mcp-name: <server name>` (an HTML comment works: `<!-- mcp-name: com.acme/tickets -->`); an npm package's `package.json` carries `"mcpName"`.
- **Only `io.modelcontextprotocol.registry/publisher-provided` survives in `_meta`.** The Registry drops other keys, `ai.nimblebrain/host` included, so a catalog entry built from a Registry listing restates the placements.

Publish after the package is on PyPI or npm, since the Registry checks it.

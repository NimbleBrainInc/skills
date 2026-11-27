# Deploying

A server a host connects to by URL ships as a container image, and carries a `server.json`
that says where it runs. [`NimbleBrainInc/mcp-careers`](https://github.com/NimbleBrainInc/mcp-careers)
is a working reference for everything on this page: its `Dockerfile`, `.github/workflows/`,
`renovate.json`, `tests/test_dockerfile_pins.py` and `deploy/README.md`.

## Ship it as a container

The rule behind each part: **a commit builds the same bytes every time, and production runs
the bytes staging ran.**

| Part | Rule | Why |
|---|---|---|
| `uv.lock` | Committed; CI and the image both install with `uv sync --locked` | A dependency changes only in a reviewed lock change |
| `Dockerfile` | Every `FROM` and `COPY --from` image pinned as `tag@sha256:<digest>`; runs as a non-root user | A rebuild of the same commit pulls the same bytes |
| CI's uv | Read from the Dockerfile's `COPY --from=ghcr.io/astral-sh/uv:<version>@sha256:…` line, never a second copy | A green `uv sync --locked` in CI is a verdict from the image's own uv |
| A test | Fails if an image loses its digest, or CI stops reading the pin | The two rules above stay true without anyone remembering them |
| On a pull request | Format, lint, types, tests | |
| On merge to main | Build, push `<image>:<short-sha>`, roll staging | Each commit has one immutable image |
| On a `vX.Y.Z` tag | Refuse a tag that disagrees with `server.json`; retag the staging image as the version, no rebuild; roll production | Production runs what staging ran, and a version number is never burned on a mismatch |
| Renovate | A release wait on dependencies; the server SDK bumped only by hand | A v0.x SDK minor may break the API |
| `/health` | Liveness only: touches no database or outside service | A slow dependency must not restart healthy pods |
| The MCP endpoint | `mcp.http_app(stateless_http=True, json_response=True)` | A 2025-era client opens a session that lives in one pod's memory; behind more than one replica, a follow-up reaching another pod is refused `Session not found`. 2026-07-28 clients are sessionless already |

```dockerfile
FROM python:3.13-slim@sha256:<digest>
COPY --from=ghcr.io/astral-sh/uv:<version>@sha256:<digest> /uv /usr/local/bin/uv
WORKDIR /app
ENV UV_PYTHON_DOWNLOADS=never UV_COMPILE_BYTECODE=1 PATH="/app/.venv/bin:$PATH"
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project --no-cache
COPY README.md ./
COPY src ./src
RUN uv sync --locked --no-dev --no-editable --no-cache
RUN useradd --uid 10001 --no-create-home app
USER 10001
CMD ["uvicorn", "mcp_<service>.server:app", "--host", "0.0.0.0", "--port", "8080"]
# app = mcp.http_app(stateless_http=True, json_response=True), in server.py
```

Test statelessness the way it fails: start two app instances (each with its lifespan), open
on one, and send the follow-up to the other. A single-process test never sees the bug.

Credentials that push images or change a deployment belong to CI environments limited to
`main` or to `v*` tags, never to repository secrets a pull request can read. Jobs that need
them skip until they exist, so the pipeline can merge before the infrastructure does.

## Change a live server without breaking connected clients

A connected client can keep an old copy of a tool's schema until it reconnects, and some
keep it longer. So:

- **Additive changes are safe in place:** a new optional parameter, a reworded description,
  a new tool.
- **A breaking change takes a new tool name:** removing a parameter, newly requiring one,
  or changing a type. Add the new tool, keep the old one for a release, then remove it.

The golden records (`python.md`) show every surface change in review, which is where this
gets caught.

## The server's `server.json`

Every server ships a `server.json` beside its Server Card. Both describe the same server, for different readers:

| | Server Card | `server.json` |
|---|---|---|
| What it is | An MCP Server Card ([SEP-2127](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/2127)), served by the running server at `<mcp-url>/server-card` | An MCP Registry `ServerDetail` ([format](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/server-json/generic-server-json.md)), a file in the repository |
| Who reads it | A host that has only a URL: a local NimbleBrain's `npx nimblebrain mcp add` | An operator adding the server to a deployed NimbleBrain's [connectors catalog](https://docs.nimblebrain.ai/config/connectors-catalog/), and the [official MCP Registry](https://github.com/modelcontextprotocol/registry) |
| Where it comes from | Code: `FastMCP(...)` and `add_server_card(...)` | Written by hand, restating the card's values |
| What only it carries | Nothing: it restates `serverInfo` | `remotes` (the deployed URL) and, for a published package, `packages` |

### One source of metadata

The card is built from code, so the code is the source. `server.json` restates the same values and adds where the server is deployed:

| Field | Value |
|---|---|
| `$schema` | the Registry schema URL the current [format docs](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/server-json/generic-server-json.md) name |
| `name` | the reverse-DNS name, one slash: the `FastMCP("com.acme/tickets")` name |
| `title`, `description` | the `add_server_card(title=, description=)` values (each 1 to 100 characters) |
| `version` | the package version, never a range |
| `websiteUrl`, `icons` | the `FastMCP(website_url=, icons=)` values; Registry icons must be `https:` |
| `_meta["ai.nimblebrain/host"]` | `{"hostVersion": "1.0", "placements": [...]}`, the card's placements (an app only) |
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
      "hostVersion": "1.0",
      "placements": [
        { "slot": "sidebar.apps", "resourceUri": "ui://tickets/board", "label": "Tickets", "route": "tickets" }
      ]
    }
  }
}
```

A connector without an interface leaves out `_meta`. A server that is only deployed, with no published package, leaves out `packages`.

Keep the two in agreement, in a test or a release step: with the server running, compare `curl -s http://127.0.0.1:8000/mcp/server-card` field by field (`name`, `title`, `description`, `version`, `icons`, and the placements under `_meta`) to `server.json`. Bump `server.json`'s `version` (and each package's) in the same change as the package version.

### In a deployed NimbleBrain

NimbleBrain connects only to an entry's `remotes`; an entry with only `packages` is not installable. An operator adds the record to the deployment's catalog directory, inside a `servers:` list (a catalog file is a list of `ServerDetail` records), and NimbleBrain reads its `title`, `icons` and `_meta["ai.nimblebrain/host"]`. The host block can carry more than placements (webhooks, notifications, admin-only tools); those are grants the operator reviews in the catalog entry, and a card's are ignored. The fields are in the [manifest reference](https://docs.nimblebrain.ai/host/manifest/); the identifier `ai.nimblebrain/host` is kebab-case and every field inside it camelCase (`hostVersion`, `adminTools`). Use an HTTPS URL in `remotes`.

### On the official MCP Registry

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

# Packaging (optional)

Packaging is for people who will run the server on their own machine. A host that connects by URL, NimbleBrain included, needs none of it: NimbleBrain connects to a running server over streamable HTTP and never downloads or runs a bundle. An `.mcpb` bundle ([MCPB](https://github.com/modelcontextprotocol/mcpb)) is for desktop hosts that install a local server from a file.

So the order is: publish the package, then, if desktop users need it, wrap the published package in a bundle. The published pattern for a local Python server is a **`uv`-type bundle that installs the released package from PyPI**, not a bundle that vendors the source. [Todos for Agents](https://github.com/NimbleBrainInc/todosforagents) ships this way; its [`release.yml`](https://github.com/NimbleBrainInc/todosforagents/blob/main/.github/workflows/release.yml) and [`mcpb/`](https://github.com/NimbleBrainInc/todosforagents/tree/main/mcpb) are a working reference.

## 1. Publish the package

**Python.** Give the package a console script or a `python -m` entrypoint that serves stdio, then publish to PyPI with trusted publishing (OIDC from the release workflow, so no API token exists). Before publishing, start the exact wheel you built the way a user will: `uvx --from dist/<wheel> <command>`. Once it is on PyPI, `uvx <package>` runs it anywhere.

**TypeScript.** Publish to npm with a `bin` entry, so `npx <package>` runs it.

Tag-driven release, in order: the tag equals the package version; build once; run the full check suite on the tagged tree; smoke-start the built artifact; publish.

## 2. Wrap it in a `uv` bundle (Python)

A `uv` bundle (manifest version 0.4 or later) carries no code. It holds a project that depends on exactly the released version, a lock made against PyPI, the manifest and an icon. The host runs it with `uv run --frozen`, so every user gets the locked set.

```
mcpb/
├── manifest.json
├── pyproject.toml   # depends on <package>==<version> and nothing else; [tool.uv] package = false
├── uv.lock          # made in the release, after PyPI serves the version
├── icon.png
└── .mcpbignore      # .venv/, __pycache__/, *.mcpb
```

```json
{
  "manifest_version": "0.4",
  "name": "@acme/tickets",
  "version": "1.2.0",
  "description": "…",
  "icon": "icon.png",
  "server": {
    "type": "uv",
    "entry_point": "mcp_acme",
    "mcp_config": {
      "command": "uv",
      "args": ["run", "--directory", "${__dirname}", "--frozen", "--no-dev", "python", "-m", "mcp_acme"],
      "env": { "ACME_API_KEY": "${user_config.api_key}" }
    }
  },
  "user_config": {
    "api_key": { "type": "string", "title": "Acme API key", "sensitive": true, "required": true }
  }
}
```

- Secrets come in through `user_config` with `sensitive: true`, never a default.
- Keep the manifest's version, the `mcpb/pyproject.toml` pin and the package version equal, and hold them equal with a test.
- If the manifest lists `tools` and `prompts`, a test holds that list equal to what the server advertises.

A TypeScript server bundles as `server.type: "node"` with its production `node_modules`.

## 3. Build and release the bundle

After the PyPI publish, in the same tag-triggered workflow:

1. Lock the bundle: `uv lock --directory mcpb --refresh`, retried until PyPI serves the new version (its index can list an upload before it resolves).
2. Start the bundle's own command from that lock (`uv run --directory mcpb --frozen --no-dev python -m <module>`) and check it answers.
3. Pack it with [`NimbleBrainInc/mcpb-pack`](https://github.com/NimbleBrainInc/mcpb-pack) (`directory: mcpb`, `upload: false`); a `uv` bundle vendors nothing. A pin older than v3.1.0 also needs `announce: false`.
4. Create the GitHub release with the bundle and its `uv.lock`. Desktop users install the bundle from there.

`mcpb-pack` v3 reads `manifest.json` only and does not read `server.json`. The server's `server.json` (`references/deploy.md`) is still kept, for deployment and the official MCP Registry: add the published package to its `packages`. Pin it and the other actions to a commit SHA in a release workflow.

Then install the bundle in a desktop host, configure it, and call a tool, before you announce the release.

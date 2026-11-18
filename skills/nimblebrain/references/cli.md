# The `nimblebrain` CLI

The CLI installs and operates a NimbleBrain runtime on this machine: it checks the
machine, starts the runtime's release images in Docker, takes the model key, connects a
coding agent, and updates or removes the install. It has no commands for what happens
inside the runtime. Apps, connectors, tasks and chat go through the workspace's MCP
endpoint.

Run it with `npx nimblebrain`. The CLI is versioned on its own: it installs the newest
NimbleBrain release, or the one `--runtime` names, from `v0.73.0` on. `--version` is the
CLI's version; `status` reports both.

## Commands

| Command | Does |
|---|---|
| `init` (the default) | Checks the machine, starts the runtime, connects the agent named by `--agent`, installs this skill for it. On a machine that already has an install, reports it and changes nothing. |
| `doctor` | Checks Docker, Compose v2, memory, disk, CPU architecture and the port. Installs nothing. |
| `status` | Version, health, URL, each workspace's MCP URL, the connected agent. |
| `key` | Takes the model key at a hidden prompt, stores it readable by this user only, and restarts the runtime so it takes effect. Interactive only: a person runs it. |
| `up` / `down` | Start or stop the runtime. Data survives `down`. |
| `logs` | Recent runtime log lines. |
| `update` | Moves to the newest runtime release (or `--runtime`), keeping data. Never backwards. |
| `uninstall` | Removes the containers, images and the data volume. Asks to confirm unless `--yes` is passed. |

## Flags

| Flag | Meaning |
|---|---|
| `--json` | One JSON object on stdout, nothing else there. Progress goes to stderr. |
| `--yes` | Take the default at every prompt. With no terminal attached, the CLI behaves as if this were set, and fails rather than wait for input. |
| `--agent <name>` | `claude-code`, `cursor`, `codex` or `none`: the agent `init` connects. |
| `--port <n>` | The local port (default `27246`). |
| `--provider <name>` | For `key`: `anthropic` (default), `openai`, `google`, `greenpt`, `nebius` or `xai`. |
| `--runtime <tag>` | For `init` and `update`: the NimbleBrain release to install, such as `v0.74.0`. Default: the newest. |
| `--home <dir>` | Where the install lives (default `~/.nimblebrain-local`, or `NIMBLEBRAIN_HOME`). |

## The JSON

Every command answers `{"ok": true, ...}` or `{"ok": false, "error": "<CODE>", "fix": "<one sentence>"}`.
The exit code is `0` when `ok` is true, `1` when it is false, `2` for a bad command or
flag.

`status --json`, healthy:

```json
{
  "ok": true,
  "version": "0.74.0",
  "cli_version": "0.1.0",
  "health": "ok",
  "url": "http://127.0.0.1:27246",
  "workspaces": [{ "id": "ws_8f3a…", "name": "Default", "mcp": "http://127.0.0.1:27246/mcp/ws_8f3a…" }],
  "agent": { "connected": "claude-code", "skill": "nimblebrain" },
  "model_key": "set"
}
```

`model_key` is `set` or `missing`, read from the install's `.env`. The key itself never appears in any output.

`init` on a machine that already has an install answers its status with `"already": true` and changes nothing. When `init` could not connect the agent, it still succeeds and adds `"manual"`: the exact command or setting to add by hand. When it ends on `MODEL_KEY_MISSING`, the failure carries the full status too, so the agent still learns the URL and MCP endpoints.

## Error codes

| `error` | Means |
|---|---|
| `DOCKER_MISSING` | Docker is not installed. |
| `DOCKER_NOT_RUNNING` | Docker is installed but not running. |
| `DOCKER_PERMISSION` | This user may not use Docker's socket. |
| `COMPOSE_MISSING` | Docker Compose v2 is not installed. |
| `ARCH_UNSUPPORTED` | No runtime image for this CPU architecture. |
| `LOW_MEMORY` | Docker has less memory than the runtime needs. |
| `PORT_IN_USE` | Another process holds the port. |
| `NOT_INSTALLED` | There is no install in the CLI's home (`~/.nimblebrain-local`, or `NIMBLEBRAIN_HOME`). Run `npx nimblebrain`. |
| `NOT_OURS` | An install the CLI did not make holds the name or the data volume. |
| `USAGE` | An unknown command or flag (exit 2). |
| `NETWORK` | A download failed. |
| `MODEL_KEY_MISSING` | The runtime is up; chat needs a key (`npx nimblebrain key`). |
| `HEALTH_TIMEOUT` | The runtime did not report healthy in time. |
| `AGENT_UNSUPPORTED` | `--agent` names an agent the CLI cannot connect. |
| `START_FAILED` | Compose could not start the runtime; `message` is its last error line. |
| `NEEDS_TERMINAL` | `key` was run with no terminal attached. A person runs it. |
| `CANCELLED` | The person declined, or `uninstall` ran without `--yes` and no terminal. Nothing changed. |
| `RUNTIME_UNSUPPORTED` | The release `--runtime` names is older than this CLI supports, or its Compose file cannot be driven. |
| `INTERRUPTED` | The CLI was stopped before it finished; `exit_code` says how. Run `status`, then the same command again. |

`references/troubleshooting.md` gives the cause and fix for each.

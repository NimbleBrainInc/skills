# The `nimblebrain` CLI

The CLI installs and operates a NimbleBrain runtime on this machine: it checks the
machine, starts the runtime's release images in Docker, takes the model key, connects a
coding agent, adds MCP servers running on this machine, and updates or removes the
install. Everything else inside the runtime (apps, connectors, tasks, chat) goes through
the workspace's MCP endpoint.

Run it with `npx nimblebrain`. The CLI is versioned on its own: it installs the newest
NimbleBrain release, or the one `--runtime` names, from `v0.73.0` on. `--version` is the
CLI's version; `status` reports both.

## Commands

| Command | Does |
|---|---|
| `init` (the default) | Checks the machine, starts the runtime, connects the agent named by `--agent`, installs this skill for it. On a machine that already has an install, reports it and changes nothing. |
| `doctor` | Checks Docker, Compose v2, CPU architecture, memory and the port. Installs nothing. |
| `status` | Version, health, URL, each workspace's MCP URL, the connected agent, whether a model key is set, and the telemetry answer. |
| `key` | Takes the model key at a hidden prompt, stores it readable by this user only, and restarts the runtime so it takes effect. Interactive only: a person runs it. |
| `local-model [model]` | Runs NimbleBrain's own agents on a model served by Ollama on this machine instead of a hosted key: checks Ollama, downloads the model if missing (default `gemma4:e4b`; asks first at a terminal), refuses one without tool calling, prepares a copy with a 32k context window, and restarts the runtime. Needs a runtime release that takes a local model. |
| `up` / `down` | Start or stop the runtime. Data survives `down`. |
| `logs` | Recent runtime log lines. |
| `update` | Moves to the newest runtime release (or `--runtime`), keeping data. Never backwards. |
| `uninstall` | Removes the containers, images and the data volume. Asks to confirm unless `--yes` is passed; with `--json` or no terminal attached it needs `--yes`, or it answers `CANCELLED`. |
| `mcp add <url>` | Adds an MCP server running on this machine to a workspace, by its `localhost`, `127.0.0.1` or `[::1]` URL. See *A server on this machine* below. |
| `mcp list` | The servers in a workspace: name, URL and status. |
| `mcp remove <serverName>` | Removes a server from a workspace. |
| `telemetry [on\|off\|status]` | Whether this install sends anonymous usage data. `on` and `off` record a person's answer and need the runtime running. |

## Flags

| Flag | Meaning |
|---|---|
| `--json` | One JSON object on stdout, nothing else there. Progress goes to stderr. |
| `--yes` | Take the default at every prompt. With no terminal attached, the CLI behaves as if this were set, and fails rather than wait for input. |
| `--agent <name>` | `claude-code`, `cursor`, `codex` or `none`: the agent `init` connects. |
| `--port <n>` | The local port (default `27246`). |
| `--provider <name>` | For `key`: `anthropic` (default), `openai`, `google`, `greenpt`, `nebius` or `xai`. |
| `--local-model <model>` | For `init`: run on this Ollama model instead of a hosted key, without asking. Pass it only when the person chose a local model. |
| `--runtime <tag>` | For `init` and `update`: the NimbleBrain release to install, such as `v0.74.0`. Default: the newest. |
| `--telemetry <on\|off>` | For `init`: an answer the person already gave about anonymous usage data. Never pass it on your own judgment. |
| `--name <serverName>` | For `mcp add`: the name to add the server under. Default: the name in its Server Card, else the URL's host and port. Lowercase letters, digits and hyphens. |
| `--workspace <id>` | For `mcp`: the workspace to act in. Default: the first workspace `status` lists, the one `init` connected the agent to. |
| `--home <dir>` | Where the install lives (default `~/.nimblebrain-local`, or `NIMBLEBRAIN_HOME`). A home whose folder has another name is a separate install, with its own containers, data volume and port; pass the same `--home` to every command for it. Give a second install `--agent none`: the agent has one `nimblebrain` server, which a second install would take over and its `uninstall` would remove. |

## The JSON

Every command answers `{"ok": true, ...}` or `{"ok": false, "error": "<CODE>", "message": "...", "fix": "<one sentence>"}`.
The exit code is `0` when `ok` is true, `1` when it is false, `2` for a bad command or
flag.

`status --json`, healthy:

```json
{
  "ok": true,
  "version": "0.74.0",
  "cli_version": "0.1.1",
  "health": "ok",
  "url": "http://127.0.0.1:27246",
  "workspaces": [{ "id": "ws_8f3a…", "name": "Default", "mcp": "http://127.0.0.1:27246/mcp/ws_8f3a…" }],
  "agent": { "connected": "claude-code", "skill": "nimblebrain" },
  "model_key": "set",
  "local_model": null,
  "telemetry": { "state": "on" }
}
```

`model_key` is `set` or `missing`, read from the install's `.env`. The key itself never appears in any output. `local_model` names the Ollama model NimbleBrain's agents run on (`nimblebrain-gemma4-e4b`), or is `null` for a hosted key; with one set, a missing key is not an error.

`telemetry.state` is `on`, `off` or `undecided`. While it is `undecided`, `telemetry.ask` holds the question to put to the person and `telemetry.set` the command that records the answer (`npx nimblebrain telemetry on` or `off`); nothing is sent before a yes. `telemetry.locked` is present when no one can change it here (`do_not_track`, `no_destination` or `operator`).

`host_loopback` is `false` on an install whose release cannot reach servers on this machine; `mcp add` then answers `UPDATE_REQUIRED` until `npx nimblebrain update`.

## A server on this machine

To try an MCP server the person is building against their local NimbleBrain: run it over
HTTP on `127.0.0.1` (for example `http://127.0.0.1:8000/mcp`), then add it once with
`npx nimblebrain mcp add http://127.0.0.1:8000/mcp --json`. It stays added across
restarts of the server and across `down`, `up` and `update`; NimbleBrain reconnects at the
same URL.

```json
{"ok": true, "serverName": "notes", "url": "http://127.0.0.1:8000/mcp", "dialed": "http://host.docker.internal:8000/mcp", "placements": [], "wsId": "ws_..."}
```

`dialed` is where NimbleBrain, inside Docker, connects. Its title, icon and placements come
from the server's Server Card at `<url>/server-card`, if it has one. A server that is not
running yet is still added, with a `warning`; it connects once started. On Linux,
`host.docker.internal` is the Docker bridge, not this machine's loopback: the server must
listen on the bridge address (usually `172.17.0.1`) or `0.0.0.0`, and `0.0.0.0` exposes it
to the network unless a firewall stops it, so say so before suggesting it.

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
| `NOT_OURS` | An install the CLI did not make holds this home's Compose project or data volume. The project takes the home folder's name, so two homes whose folders share a name collide. |
| `USAGE` | An unknown command, flag or flag value (`--port`, `--telemetry`, `--provider` on `key`), or `update --runtime` naming a release older than the install (exit 2). |
| `NETWORK` | A download failed. |
| `MODEL_KEY_MISSING` | The runtime is up; chat needs a key (`npx nimblebrain key`). |
| `HEALTH_TIMEOUT` | The runtime did not report healthy in time. |
| `AGENT_UNSUPPORTED` | `--agent` names an agent the CLI cannot connect. |
| `START_FAILED` | Compose could not start the runtime; `message` is its last error line. |
| `NEEDS_TERMINAL` | `key` was run with no terminal attached. A person runs it. |
| `CANCELLED` | The person declined, or `uninstall` ran without `--yes` while `--json` was passed or no terminal was attached. Nothing changed. |
| `RUNTIME_UNSUPPORTED` | The release `--runtime` names is older than this CLI supports, or its Compose file cannot be driven. |
| `NOT_RUNNING` | `telemetry on\|off` and every `mcp` command need the runtime up (`npx nimblebrain up`). |
| `TELEMETRY_LOCKED` | `DO_NOT_TRACK` or the install's configuration decides telemetry; nothing to change. |
| `LOCAL_MODEL_UNREACHABLE` | Ollama does not answer on `127.0.0.1:11434`. The person installs and starts it (https://ollama.com/download). |
| `LOCAL_MODEL_MISSING` | Ollama does not have the model, and it was not downloaded (declined, or the download failed). |
| `LOCAL_MODEL_NO_TOOLS` | The model cannot call tools, which NimbleBrain's agents need. Choose one listed on https://docs.nimblebrain.ai/config/local-models/. |
| `LOCAL_CONTEXT_SMALL` | `doctor`: the model's context window is below 32k. Run `npx nimblebrain local-model` again. |
| `INTERRUPTED` | The CLI was stopped before it finished; `exit_code` says how. Run `status`, then the same command again. |
| `UPDATE_REQUIRED` | `mcp add` on a release that cannot reach servers on this machine. Run `npx nimblebrain update`. |
| `WORKSPACE_NOT_FOUND` | `--workspace` names no workspace on this install. |
| `SERVER_NOT_FOUND` | `mcp remove` names no server in the workspace. |
| `DIRECT_URL_NOT_ALLOWED` | The runtime does not take a server by URL: the install was not made by `npx nimblebrain`, or predates this feature. |
| `URL_NOT_LOOPBACK` | `mcp add` was given a URL off this machine. Only `localhost`, `127.0.0.1` and `[::1]` are accepted. |
| `URL_INVALID` | `mcp add` was not given a full MCP URL. |
| `INVALID_SERVER_NAME` | `--name` is not lowercase letters, digits and hyphens. |
| `NAME_TAKEN` | The workspace already has a server by that name. |
| `NAME_IS_CATALOG_ENTRY` | The name belongs to a catalog connector. |
| `REQUEST_FAILED` | The runtime refused or failed the request; `message` says why. |

`references/troubleshooting.md` gives the cause and fix for each.

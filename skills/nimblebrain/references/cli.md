# The `nimblebrain` CLI

The CLI installs and operates a NimbleBrain runtime on this machine. Apps, connectors,
tasks and chat go through the workspace's MCP endpoint, not the CLI. The one exception is
`mcp`, a thin client for adding an MCP server you are building on this machine: the
runtime stores and connects it, and the CLI stores nothing.

**For every command, flag and error code, run `npx nimblebrain help --json`.** It is
generated from the CLI itself, so it matches the version that runs: each command with its
arguments, each flag with the commands it applies to, and each error code with its fix and
exit code. This file covers only what that output does not: what the answers carry, and the
judgment around the commands.

## Version

The CLI is versioned apart from the runtime. `npx nimblebrain --version` is the CLI's
version; `status` reports both (`cli_version` and `version`). This skill relies on:

| Feature | Needs CLI |
|---|---|
| `mcp add`, `mcp list`, `mcp remove` | 0.3.0 |
| Starting an installed Ollama | 0.4.0 |
| `open`, `help --json` | 0.5.0 |

`npx` can run an older cached copy. When `--version` is below what you need, or a command
answers `USAGE` for something this skill names, run it as `npx nimblebrain@latest`. The
CLI installs the newest runtime release, or the one `--runtime` names.

## Reading an answer

Run every command with `--json`: one JSON object on stdout, progress and notices on
stderr. Each answer is `{"ok": true, ...}` or
`{"ok": false, "error": "<CODE>", "message": "...", "fix": "<one sentence>"}`, and the
exit code is `0` when `ok` is true.

Give the answer's `fix`, not the one in `help --json`. The answer's is written for this
machine and this install: it names the step for this OS, and carries `--home` when the
install lives somewhere other than the default. A failure can carry more: `MODEL_KEY_MISSING`
from `init` carries the full status, so the URL and MCP endpoints still arrive;
`WORKSPACE_NOT_FOUND` lists the `workspaces` there are; `NOT_RUNNING` from `open` carries
the `url`; `INTERRUPTED` carries `exit_code`. `references/troubleshooting.md` gives the
cause behind each code.

`status --json`, healthy:

```json
{
  "ok": true,
  "version": "0.76.0",
  "cli_version": "0.5.0",
  "health": "ok",
  "url": "http://127.0.0.1:27246",
  "workspaces": [{ "id": "ws_8f3a…", "name": "Default", "mcp": "http://127.0.0.1:27246/mcp/ws_8f3a…" }],
  "agent": { "connected": "claude-code", "skill": "nimblebrain" },
  "model_key": "set",
  "host_loopback": true,
  "local_model": null,
  "telemetry": { "state": "on" }
}
```

- `model_key` is `set` or `missing`. The key itself never appears in any output.
- `local_model` names the Ollama model NimbleBrain's agents run on, or is `null` for a
  hosted key; with one set, a missing key is not an error.
- `host_loopback` says whether the installed release can reach a server on this machine.
  It is `false` before runtime `v0.76.0`; `update` makes it `true`.
- `telemetry.state` is `on`, `off` or `undecided`. While it is `undecided`,
  `telemetry.ask` holds the question to put to the person and `telemetry.set` the command
  that records the answer; nothing is sent before a yes. `telemetry.locked` is present
  when no one can change it here (`do_not_track`, `no_destination` or `operator`).
- `updates` appears on answers that carry the status when a newer CLI or runtime is
  known: `{"cli": {"current", "latest"}, "runtime": {"current", "latest"}}`. Tell the
  person; a newer runtime is `update`, a newer CLI is `npx nimblebrain@latest`.

Other answers:

- `init` on a machine that already has an install answers its status with
  `"already": true` and changes nothing. When it could not connect the agent, it still
  succeeds and adds `manual`: the exact command or setting to add by hand.
- `update` answers the status with `from` (the previous release), or `"already": true`
  when there was nothing newer. When an agent is connected, `skill_update` says whether
  this skill was refreshed: `updated`, `unchanged`, `failed` (then
  `npx skills update nimblebrain -g`) or `not_installed`.
- `open` answers `url` and `opened`. `opened: false` (no display, an SSH session) still
  succeeds, so give the person the `url`. It never starts NimbleBrain.
- `init` (choosing a local model), `local-model`, `up` and `doctor` carry
  `ollama_started`, the command that started Ollama, when they started it. Tell the person
  what was started.

## Judgment the CLI leaves to you

The rules on the model key, telemetry and `uninstall` are in `SKILL.md`. Beyond those:

- **Ollama:** when it is installed but not running, `init`, `local-model` and `up` start it
  the way it was installed: the macOS app, Homebrew's service (which also starts it at
  every login), or the Linux service, never with `sudo`. At a terminal they ask first;
  with `--yes`, `--json` or no terminal they take the default, yes, so say so before
  running them. `doctor` starts it only on a person's yes. The CLI never installs Ollama.
- **A second install** needs its own `--home` whose folder has another name, passed to
  every command for it, and `--agent none`: the agent has one `nimblebrain` server, which
  a second install would take over and its `uninstall` would remove.

Environment variables the CLI reads:

| Variable | Effect |
|---|---|
| `NIMBLEBRAIN_HOME` | The default `--home`. |
| `DO_NOT_TRACK=1`, `NB_TELEMETRY_DISABLED=1` | Telemetry stays off and cannot be turned on (`TELEMETRY_LOCKED`). `DO_NOT_TRACK=1` also stops the update check. |
| `NIMBLEBRAIN_NO_UPDATE_CHECK=1`, or `CI` set | No update check, so no `updates` field and no notice. |

## Developing a server

Run the server over HTTP on `127.0.0.1`, then add it once:

```bash
npx nimblebrain mcp add http://127.0.0.1:8000/mcp --json
```

```json
{ "ok": true, "serverName": "notes", "url": "http://127.0.0.1:8000/mcp", "dialed": "http://host.docker.internal:8000/mcp", "placements": [], "wsId": "ws_8f3a…" }
```

- The runtime reads the server's Server Card at `<url>/server-card` for its title, icon
  and sidebar placements, and its name unless `--name` gives one. The runtime lowercases
  the name and turns any other character into a hyphen.
- `dialed` is where the runtime, inside Docker, connects. On Linux,
  `host.docker.internal` is the Docker bridge, so the server must listen on the bridge
  address or `0.0.0.0`; `0.0.0.0` can expose it to the network, so say so before
  suggesting it.
- A `warning` means the server is not running yet: the row is stored, and it connects once
  the server starts and is reconnected from the Connectors page. A `notice` passes on the
  runtime's message about the new server.
- The server stays added across `down`, `up` and `update`, and a restarted server
  reconnects at the same URL, so add it once, not on every restart.
- Without `--workspace`, `mcp` acts in the workspace `init` connected (the first in
  `status`'s `workspaces`).

`mcp list` answers `{ "ok": true, "wsId": "…", "servers": [{ "serverName", "displayName", "url", "state", "status", "statusReason", "toolCount" }] }`;
use it to see whether the server connected and how many tools it offers, and to find the
name for `mcp remove`, which answers `{ "ok": true, "serverName": "…", "wsId": "…" }`.

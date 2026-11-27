# The `nimblebrain` CLI

The CLI installs and operates a NimbleBrain runtime on this machine. Apps, connectors,
tasks and chat go through the workspace's MCP endpoint, not the CLI. The one exception is
`mcp`, a thin client for adding an MCP server you are building on this machine: the
runtime stores and connects it, and the CLI stores nothing.

**For every command, flag and error code, run `npx nimblebrain help --json`.** It is
generated from the CLI itself, so it matches the version that runs: each command with its
arguments and its `answer` (the fields of `{"ok": true, ...}` and what each carries), each
flag with the commands it applies to, and each error code with its default fix and exit
code. This file covers only what that output cannot state: the version each feature needs,
how to read a failure, and the judgment around the commands.

## Version

`npx nimblebrain --version` is the CLI's version. This skill relies on:

| Feature | Needs CLI |
|---|---|
| `mcp add`, `mcp list`, `mcp remove` | 0.3.0 |
| Starting an installed Ollama, `help --json` | 0.4.0 |
| `open` | 0.5.0 |
| Each command's `answer` in `help --json` | 0.6.0 |
| Finishing an install whose first start failed (`status.phase`, `INSTALL_INCOMPLETE`) | 0.8.0 |
| `use`, `init --use`, `model_source`, running on a Claude or ChatGPT subscription | 0.9.0 |
| `--model`, a second install's free port and its own agent server name (`port_moved`, `agent.server`) | 0.9.0 |
| The numbered coding-agent question, a `timeline` line per turn in `agent-worker.log` | 0.9.0 |

Running on a subscription also needs a runtime that passes the agent worker's settings:
`v0.87.0` or newer, and `v0.87.1` or newer for title and summary runs on the fast model
and the model in the composer. An older runtime answers `RUNTIME_UNSUPPORTED` from `use`,
and `update` moves to the newest.

`npx` can run an older cached copy. When `--version` is below what you need, or a command
answers `USAGE` for something this skill names, run it as `npx nimblebrain@latest`.

## Reading an answer

Run every command with `--json`. Each answer is `{"ok": true, ...}` or
`{"ok": false, "error": "<CODE>", "message": "...", "fix": "<one sentence>"}`, and the
exit code is `0` when `ok` is true.

Give the answer's `fix`, not the default in `help --json`. The answer's is written for this
machine and this install: it names the step for this OS, and carries `--home` when the
install lives somewhere other than the default. A failure can carry more:
`WORKSPACE_NOT_FOUND` lists the `workspaces` there are; `NOT_RUNNING` from `open` carries
the `url`; `INTERRUPTED` carries `exit_code`. `references/troubleshooting.md` gives the
cause behind each code.

Fields that ask something of you:

- `updates`: tell the person. A newer runtime is `update`; a newer CLI is
  `npx nimblebrain@latest`.
- `skill_update: "failed"` from `update`: refresh this skill with
  `npx skills update nimblebrain -g`.
- `ollama_started`: tell the person what was started.
- `model_source.ask` from `init`: nothing runs NimbleBrain's agents yet. Put the question
  to the person with its `options` (`SKILL.md`), then run the `set` command it names with
  their answer.
- `port_moved`: the install is on another port than 27246. Tell the person, and use the
  `url` the answer gives.
- `billed_to` from `use`: tell the person what their turns are billed to.

## Judgment the CLI leaves to you

The rules on the model key, telemetry and `uninstall` are in `SKILL.md`. Beyond those:

- **`init --local-model`:** pass it only when the person chose a local model. It answers
  the model question without asking, and the model it names can start a download of
  several GB and start Ollama.
- **Ollama:** when it is installed but not running, `init`, `local-model` and `up` start it
  the way it was installed: the macOS app, Homebrew's service (which also starts it at
  every login), or the Linux service, never with `sudo`. At a terminal they ask first;
  with `--yes`, `--json` or no terminal they take the default, yes, so say so before
  running them. `doctor` starts it only on a person's yes. The CLI never installs Ollama.
- **A first start that failed** leaves the install `phase: "starting"`. `logs`, `down`,
  `status` and `uninstall` work on it; the other commands answer `INSTALL_INCOMPLETE`. Run
  `logs --json` to find why, and once that is addressed run `npx nimblebrain` again: it
  finishes the same install, keeping its project, port, release, and any key already
  entered.
- **A subscription (`use claude|codex`)** bills the person's plan and counts against its
  limits, so run it only on their say-so. It runs only on macOS for now
  (`PLATFORM_UNSUPPORTED`, `HOST_LOOPBACK_UNREACHABLE` elsewhere). It starts a small agent
  worker on `127.0.0.1` and installs a login item (`~/Library/LaunchAgents`) so the worker
  starts at login and after a crash; `down`, `use api|local` and `uninstall` remove it.
  Say so before running it. The CLI checks the agent's own CLI is signed in to a
  subscription, not an API key, and refuses otherwise with the command that fixes it.
  Claude turns run on Sonnet by default; `--model` picks another (`opus`, `haiku`, or a
  full model id). A run with a spend budget still runs on NimbleBrain's own engine, so it
  needs a key or a local model.
- **A second install** needs its own `--home`, passed to every command for it. It picks a
  free port when 27246 is taken (`port_moved`) and registers with the coding agent under
  its own name (`nimblebrain-<folder>`), so it leaves the first install's registration
  alone. An explicit `--port` that is taken is still `PORT_IN_USE`. On a CLI before 0.9.0,
  pass `--port` and `--agent none` instead: there the agent has one `nimblebrain` server,
  which a second install would take over.

Environment variables `help --json` does not list:

| Variable | Effect |
|---|---|
| `DO_NOT_TRACK=1` | Telemetry stays off and cannot be turned on (`TELEMETRY_LOCKED`). `DO_NOT_TRACK=1` also stops the update check. |
| `NIMBLEBRAIN_NO_UPDATE_CHECK=1`, or `CI` set | No update check, so no `updates` field and no notice. |

## Developing a server

Run the server over HTTP on `127.0.0.1`, then add it once:

```bash
npx nimblebrain mcp add http://127.0.0.1:8000/mcp --json
```

- The runtime reads the server's Server Card at `<url>/server-card` for its title, icon,
  sidebar placements and, unless `--name` gives one, its name. The runtime lowercases the
  name and turns any other character into a hyphen.
- On Linux, `dialed`'s `host.docker.internal` is the Docker bridge, so the server must
  listen on the bridge address or `0.0.0.0`; `0.0.0.0` can expose it to the network, so
  say so before suggesting it.
- The server stays added across `down`, `up` and `update`, and a restarted server
  reconnects at the same URL, so add it once, not on every restart. One added before it
  was running connects once it starts and is reconnected from the Connectors page.
- `mcp list` shows whether it connected and how many tools it offers, and the name
  `mcp remove` takes.

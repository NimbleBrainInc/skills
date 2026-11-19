---
name: nimblebrain
description: Sets up, connects and uses NimbleBrain, the open-source runtime that runs agents and MCP apps on your own machine with any model. Installs and starts it with the `nimblebrain` CLI, connects this coding agent to a workspace over MCP, then works inside it, and routes building an app or an MCP server to the right skill. Use for anything about NimbleBrain. Triggers include "set up NimbleBrain", "install NimbleBrain", "run NimbleBrain locally", "connect to NimbleBrain", "what can my NimbleBrain do", "is NimbleBrain running", "update NimbleBrain".
license: MIT
compatibility: Node.js 20+ (for `npx`). Docker Engine 24+ with Docker Compose v2, running, with about 2 GB of free memory. A model API key (Anthropic by default) or a local model through Ollama for chat; everything else works without one.
allowed-tools: Read Bash AskUserQuestion
metadata:
  area: nimblebrain
  version: "0.1.0"
  author: NimbleBrain
---

# NimbleBrain

NimbleBrain is the open-source runtime that runs agents and MCP apps on your own
systems, with any model. The `nimblebrain` CLI installs, starts, updates and removes
it. Everything inside a running NimbleBrain (apps, connectors, tasks, chat) you reach
over the workspace's MCP endpoint, not the CLI.

So this skill has two halves: **get it running** with the CLI, then **work inside it**
over MCP.

## Rules that hold throughout

- **The model key never passes through you.** Do not ask for it in chat, and do not
  print or open the files that hold it. The person enters it themselves with
  `npx nimblebrain key`, at a hidden prompt in their own terminal. If they paste a key
  into chat anyway, do not use it; tell them it is now in the transcript and that they
  may want to rotate it.
- **Read the CLI's JSON, not its prose.** Run every command with `--json` and branch on
  `ok` and `error`. Each error carries a `fix`; give that fix and stop. Do not improvise
  another install route. `npx nimblebrain help --json` lists every command, flag and
  error code, and what each answer carries; `references/cli.md` covers the judgment.
- **The local instance is for this machine.** It signs nobody in: anyone who reaches its
  port is the admin. The CLI publishes it on `127.0.0.1` for that reason. Never widen
  it, tunnel it or put a proxy in front of it.
- **Usage data is the person's call.** When a result carries `telemetry.state:
  "undecided"`, put `telemetry.ask` to the person in their words and run
  `npx nimblebrain telemetry on` or `off` with their answer. Never answer it yourself,
  and never pass `--telemetry` unless they already told you.
- **Anything that deletes data asks first.** `uninstall` removes every conversation.
  Run it only on the person's own yes for that step; `down` keeps data.

## 1. Get it running

Check the machine before anything installs:

```bash
npx nimblebrain doctor --json
```

On `"ok": false`, give the `fix` and stop. Common ones (Docker not running, Docker
missing, a busy port) are in `references/troubleshooting.md`.

Then say in two lines what will happen, and wait for a yes: it starts NimbleBrain in
Docker on this machine at `http://127.0.0.1:27246` (about 2 GB of images the first
time), and connects you to it. Then:

```bash
npx nimblebrain --yes --agent <claude-code|cursor|codex|none> --json
```

Pass the agent you are. `init` is the default command, and it is safe to run again: on
a machine that already has NimbleBrain it reports what is there and changes nothing.

If it returns `MODEL_KEY_MISSING`, everything else is running; only chat needs the key.
Ask the person to run this in their own terminal, then tell you when it is done:

```bash
npx nimblebrain key
```

If they have no key yet, go on without one and say chat is not tested.

If they would rather not use a hosted key, NimbleBrain's agents can run on a local
model through Ollama (free, slower; https://docs.nimblebrain.ai/config/local-models/
lists what has been tested). Once Ollama is installed:

```bash
npx nimblebrain local-model --yes --json
```

It starts Ollama if it is not running (a Homebrew install then starts at every login
too) and downloads `gemma4:e4b` (several GB) if it is missing, so say both first. When
Ollama is not installed, the error's `fix` names the install step; the CLI never
installs it. `status`
then reports `local_model`, and a missing key is no longer an error.

## 2. Check it, and that you are connected

```bash
npx nimblebrain status --json
```

Healthy is `"health": "ok"`. `workspaces[].mcp` is each workspace's MCP URL, of the
form `http://127.0.0.1:27246/mcp/<workspaceId>`; the bare `/mcp` is not an endpoint.
`agent.connected` names the agent `init` registered that URL with, and `agent.skill`
the skill it installed.

Your new MCP server is usually available only from the next session. If you cannot see
its tools yet, say so and finish the report; the person reopens their agent to use it.

Health shows the runtime is up, not that the model answers. If `model_key` is `set` or
`local_model` is not `null`, send one chat through the workspace's tools, or ask the
person to open `http://127.0.0.1:27246`, send `What can you help me with?`, and tell
you whether a reply came.

Report briefly: the URL, the version, chat confirmed or not, and how to stop it
(`npx nimblebrain down`). Data survives `down`.

## 3. Work inside it

Once connected, use the workspace's MCP tools for what the person asks: list the apps
and what each does, run a task, read records, open an app's view. Read a tool's schema
from the server before calling it rather than guessing arguments; the tools a workspace
offers depend on the apps installed in it.

When the person asks for something no installed app does, say which kind of thing would
do it (an app with a UI, or a connector to another system) and offer to build it.

## 4. Build for it

Route to the skill for the job. Install it if it is missing:
`npx skills add nimblebraininc/skills --skill <name>`.

| The person wants | Skill |
|---|---|
| An MCP server for an API or a system, an app's server, or a review of a server's tools | `mcp-server` (with `synapse` for an app's interface) |
| A screen for an MCP server, or an app's interface inside NimbleBrain | `synapse` |

To try a server the person is building in their local NimbleBrain, run it on
`127.0.0.1` and add it once with `npx nimblebrain mcp add <url> --json`
(`references/cli.md`, *Developing a server*).

## 5. Keep it running

| Ask | Command |
|---|---|
| Is it up, and where? | `npx nimblebrain status --json` |
| Open it | `npx nimblebrain open --json`; on `opened: false`, give the person the `url`; on `NOT_RUNNING`, run `up` first |
| Why did it fail? | `npx nimblebrain logs --json` (recent lines from the runtime) |
| Stop it | `npx nimblebrain down --json` |
| Start it again | `npx nimblebrain up --json` |
| Move to the newest release | `npx nimblebrain update --json` |
| Change the model key | the person runs `npx nimblebrain key` |
| Run on a local model instead | `npx nimblebrain local-model --yes --json`, after the person agrees to the download and, if Ollama is not running, to the CLI starting it |
| Remove it and all its data | `npx nimblebrain uninstall --yes --json`, only on the person's own yes |

## References

- `npx nimblebrain help --json`: every command, flag and error code, and the fields each
  answer carries, from the CLI that runs
- `references/cli.md`: the CLI version each feature needs, how to read a failure, and the
  judgment around the commands
- `references/troubleshooting.md`: symptom, cause and fix for each error

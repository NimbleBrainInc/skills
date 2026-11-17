---
name: nimblebrain
description: Sets up, connects and uses NimbleBrain, the open-source runtime that runs agents and MCP apps on your own machine with any model. Installs and starts it with the `nimblebrain` CLI, connects this coding agent to a workspace over MCP, then works inside it, and routes building an app or an MCP server to the right skill. Use for anything about NimbleBrain. Triggers include "set up NimbleBrain", "install NimbleBrain", "run NimbleBrain locally", "connect to NimbleBrain", "what can my NimbleBrain do", "is NimbleBrain running", "update NimbleBrain".
license: MIT
compatibility: Node.js 20+ (for `npx`). Docker Engine 24+ with Docker Compose v2, running, with about 2 GB of free memory. A model API key (Anthropic by default) for chat; everything else works without one.
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
  another install route. `references/cli.md` lists the commands, fields and errors.
- **The local instance is for this machine.** It signs nobody in: anyone who reaches its
  port is the admin. The CLI publishes it on `127.0.0.1` for that reason. Never widen
  it, tunnel it or put a proxy in front of it.
- **Anything that deletes data asks first.** `uninstall` removes every conversation.
  Run it, or `down --volumes`, only on the person's own yes for that step.

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

## 2. Check it, and that you are connected

```bash
npx nimblebrain status --json
```

Healthy is `"health": "ok"`. `workspaces[].mcp` is each workspace's MCP URL, of the
form `http://127.0.0.1:27246/mcp/<workspaceId>`; the bare `/mcp` is not an endpoint.
`agent.connected` names the agent `init` registered that URL with, and `agent.skill`
the version of this skill it installed, matched to the runtime.

Your new MCP server is usually available only from the next session. If you cannot see
its tools yet, say so and finish the report; the person reopens their agent to use it.

Health shows the runtime is up, not that the key works. If a key is set, send one chat
through the workspace's tools, or ask the person to open `http://127.0.0.1:27246`,
send `What can you help me with?`, and tell you whether a reply came.

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
| A screen for an MCP server, or an app inside NimbleBrain | `synapse` |
| An MCP server for an API or a system | `mcpb` |
| To find, install or publish a server bundle | `mpak` |
| A review of an MCP server's tool design | `mcp-best-practices` |

Each of those finishes by running the result in this NimbleBrain, so the person sees it
working where they will use it.

## 5. Keep it running

| Ask | Command |
|---|---|
| Is it up, and where? | `npx nimblebrain status --json` |
| Why did it fail? | `npx nimblebrain logs --json` (recent lines from the runtime) |
| Stop it | `npx nimblebrain down --json` |
| Start it again | `npx nimblebrain up --json` |
| Move to the newest release | `npx nimblebrain update --json` |
| Change the model key | the person runs `npx nimblebrain key` |
| Remove it and all its data | `npx nimblebrain uninstall --json`, only on its own yes |

## References

- `references/cli.md`: every command, flag, JSON field and error code
- `references/troubleshooting.md`: symptom, cause and fix for each error

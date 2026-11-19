# Troubleshooting

Find the error, give the fix, and stop. The rule about the model key holds while
diagnosing: never print or open the files that hold it.

| `error`, or symptom | Cause | Fix |
|---|---|---|
| `DOCKER_MISSING` | Docker is not installed. | The person installs Docker Desktop or Docker Engine from `https://docs.docker.com/get-docker/`, then you run `doctor` again. |
| `DOCKER_NOT_RUNNING` | Docker is installed but not running. | The person starts Docker Desktop (or the Docker service). Run `doctor` again once it is up. |
| `DOCKER_PERMISSION` | On Linux, this user is usually not in the `docker` group. | The person follows `https://docs.docker.com/engine/install/linux-postinstall/` and signs in again. Do not run Docker as root for them. |
| `COMPOSE_MISSING` | The Compose v2 plugin is missing. | Update Docker Desktop, or install the plugin: `https://docs.docker.com/compose/install/`. |
| `ARCH_UNSUPPORTED` | The runtime publishes no image for this CPU. | Say so and stop. Do not force another platform: under emulation the runtime crashes. |
| `LOW_MEMORY` | Docker has less memory than the runtime needs (about 2 GB). | The person raises Docker's memory in its settings, then you run `init` again. |
| `PORT_IN_USE` | Another process holds port 27246, often another NimbleBrain. | Run `status`: if this install is already running, there is nothing to do. Otherwise the person stops the other process, or you pass `--port` on their say-so. |
| `NOT_INSTALLED` | There is no install in the CLI's home (`~/.nimblebrain-local`, or `NIMBLEBRAIN_HOME`). | Run `npx nimblebrain` to install it, or pass the `--home` the install uses. |
| `USAGE` | An unknown command, flag or flag value, or `update --runtime` naming an older release (exit 2). | Check `npx nimblebrain --help` and fix the command. |
| `AGENT_UNSUPPORTED` | `--agent` names an agent the CLI cannot connect. | Pass `--agent claude-code`, `cursor`, `codex` or `none`. |
| `START_FAILED` | Compose could not start the runtime; `message` is its last error line. | Run `logs --json`, report the last error line as written, then run the command again once it is addressed. |
| `NEEDS_TERMINAL` | `key` was run with no terminal attached. | The person runs `npx nimblebrain key` in their own terminal. Never pass the key yourself. |
| `CANCELLED` | The person declined, or `uninstall` ran without `--yes` under `--json` or with no terminal. Nothing changed. | If the person said yes, run `npx nimblebrain uninstall --yes --json`; otherwise stop. |
| `RUNTIME_UNSUPPORTED` | The release `--runtime` names is older than this CLI supports, or its Compose file cannot be driven. | Pass a newer `--runtime`, or leave it out for the newest release. |
| `NOT_OURS` | An install the CLI did not make holds this home's Compose project or data volume. | Report it and stop. Never remove another install's data. For a second install, use a `--home` whose folder has another name. |
| `NETWORK` | A download failed: no network, or the image registry is unreachable. | Check the connection, then run the same command again. |
| `MODEL_KEY_MISSING` | No key is stored. Everything but chat works. | The person runs `npx nimblebrain key` in their own terminal. |
| `NOT_RUNNING` | `open`, `telemetry on`/`off` or an `mcp` command was run while the runtime is stopped. | Run `npx nimblebrain up --json`, then the command again. |
| `UPDATE_REQUIRED` | `mcp add` on an install from before runtime `v0.76.0`, which cannot reach this machine. | Run `npx nimblebrain update --json`, then `mcp add` again. Data survives the update. |
| `URL_NOT_LOOPBACK`, `URL_INVALID` | The URL is not an `http(s)` URL on `localhost`, `127.0.0.1` or `::1`. | Use the server's loopback URL, such as `http://127.0.0.1:8000/mcp`. |
| `NAME_TAKEN`, `NAME_IS_CATALOG_ENTRY`, `INVALID_SERVER_NAME` | The name is in use in the workspace, belongs to a catalog connector, or is empty or reserved once lowercased with other characters turned into hyphens. | Pass another `--name`; for `NAME_TAKEN`, `mcp list` shows what holds it. |
| `WORKSPACE_NOT_FOUND` | `--workspace` names no workspace. | Pick one from the answer's `workspaces` (or `status --json`) and pass it with `--workspace`. |
| `SERVER_NOT_FOUND` | `mcp remove` names no server in the workspace. | Run `npx nimblebrain mcp list --json` for the names, then remove by one of them. |
| `DIRECT_URL_NOT_ALLOWED` | The instance is not a local install made by `npx nimblebrain`, so it adds servers only from its catalog. | Run `npx nimblebrain update --json`, or add the server to the instance's connector catalog. |
| `REQUEST_FAILED` | The runtime refused the request for another reason; `message` carries its text. | Run `logs --json`, report the last error line as written, then run the command again once it is addressed. |
| `mcp add` succeeds with a `warning`, or the server shows as not running | The server was not running when it was added, or it listens where Docker cannot reach it. | Start the server; on Linux it must listen on the bridge address or `0.0.0.0`. Then reconnect it from the Connectors page. |
| `TELEMETRY_LOCKED` | `DO_NOT_TRACK` (or `NB_TELEMETRY_DISABLED`) is set, or this install has nowhere to send data. | Nothing to do: telemetry stays off. Tell the person if they asked to turn it on. |
| `LOCAL_MODEL_UNREACHABLE` | Ollama does not answer on `127.0.0.1:11434`: it is not installed, the person declined starting it, or it did not answer within 30 seconds of a start. | Give the error's `fix`, which names the step for this machine (`brew install ollama`, the download page, opening the app, or `sudo systemctl start ollama`); never install Ollama yourself. Then run the same command again. From `up`, NimbleBrain is already running; only its own agents wait on Ollama. |
| `LOCAL_MODEL_MISSING` | The model is not on Ollama: the download was declined, failed, or ran out of disk. | With the person's yes, run `npx nimblebrain local-model --yes --json` again, or `ollama pull <model>` first. |
| `LOCAL_MODEL_NO_TOOLS` | The model cannot call tools. | Use a model with tool calling, such as `gemma4:e4b`. |
| `LOCAL_CONTEXT_SMALL` | `doctor` found the model's context window below 32k, so long prompts would be cut. | Run `npx nimblebrain local-model --yes --json` again. |
| `INTERRUPTED` | The CLI was stopped (a signal, Ctrl-C, a killed session) before it answered. | Run `npx nimblebrain status --json` to see what is in place, then run the same command again; `init` is safe to repeat. |
| `HEALTH_TIMEOUT` | The runtime is still starting, or it exited. | Run `logs --json` and report the last error line as written. |
| Chat shows an error | The key is wrong, expired, out of credit, or for another provider. | The person runs `npx nimblebrain key` again. |
| The agent connects, then fails with `-32022` or "unsupported protocol version" | The agent's MCP client is older than the revision the runtime serves. | Update the agent. |
| The agent cannot see NimbleBrain's tools right after `init` | The agent loads MCP servers when a session starts. | The person opens a new session. |

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
| `NOT_OURS` | An install the CLI did not make holds the name or the data volume. | Report it and stop. Never remove another install's data. |
| `NETWORK` | A download failed: no network, or the image registry is unreachable. | Check the connection, then run the same command again. |
| `MODEL_KEY_MISSING` | No key is stored. Everything but chat works. | The person runs `npx nimblebrain key` in their own terminal. |
| `HEALTH_TIMEOUT` | The runtime is still starting, or it exited. | Run `logs --json` and report the last error line as written. |
| Chat shows an error | The key is wrong, expired, out of credit, or for another provider. | The person runs `npx nimblebrain key` again. |
| The agent connects, then fails with `-32022` or "unsupported protocol version" | The agent's MCP client is older than the revision the runtime serves. | Update the agent. |
| The agent cannot see NimbleBrain's tools right after `init` | The agent loads MCP servers when a session starts. | The person opens a new session. |

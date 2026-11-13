---
name: setup
description: Sets up the open source NimbleBrain runtime on this machine with Docker Compose, then checks that it is healthy and answers one chat. Pulls the published images on x86-64 and builds them from the public source on Apple Silicon and other arm64 hosts. Use to run NimbleBrain locally. Triggers include "set up NimbleBrain", "install NimbleBrain locally", "run NimbleBrain on my machine".
license: MIT
compatibility: Docker Engine 24+ with Docker Compose v2 or later, running, and about 2 GB of free memory. curl. On arm64 hosts (Apple Silicon), also git, the Docker buildx plugin, about 5 GB of free disk, and network access to GitHub, Docker Hub (the base images and the Dockerfile syntax image) and the package sources the runtime's Dockerfile installs from. A model API key (Anthropic by default) for the chat; the rest works without one.
allowed-tools: Read Write Bash AskUserQuestion
metadata:
  area: setup
  version: "0.1.0"
  author: NimbleBrain
---

# NimbleBrain Setup

You are setting up NimbleBrain, the open-source runtime that runs agents and MCP apps on your systems, in your own infrastructure, with any model (`github.com/NimbleBrainInc/nimblebrain`, Apache-2.0), on the user's own machine. The route is Docker Compose with the runtime repo's own compose file, documented at `docs.nimblebrain.ai/deploy/docker/`: two containers, one folder, the user's own model key. Done means the health endpoint answers and the user has seen one chat reply.

This skill installs release `v0.68.0`. Every image name and clone below uses that tag, so a rerun gets the same thing and an update is a deliberate change.

**Which hosts it supports.** The images published at `ghcr.io/nimblebraininc` are `linux/amd64` only. On an x86-64 Docker host the skill pulls them. On an arm64 Docker host (Apple Silicon Macs, arm64 Linux) there is no image to pull, so the skill clones the public runtime repo at the same tag and builds both images on the machine. That build needs the Docker buildx plugin and takes about six minutes the first time (measured on an Apple Silicon Mac with Colima). If buildx is missing, the skill stops before writing anything and says how to add it. It does not run the amd64 images under emulation: under QEMU the runtime crashes at startup.

**Without a model key.** The containers start, the health check passes and the web UI loads, but every chat fails until a key is added. The user can still finish every step except the chat in step 8, and add a key later. The report then says the chat is untested.

Work through the steps in order, from step 1 every time, reruns included. Run each command yourself and read its output before the next step. When a step fails, look the symptom up in `references/TROUBLESHOOTING.md`, give the fix, and stop there. Do not improvise a different install route.

## Rules that hold for every step

- **The model key never passes through you.** Do not ask for it in chat. Do not open, print or search `.env` files or shell history. Do not run `docker compose config`, `docker inspect` on a container, or a bare `env`: each prints the key. If the user pastes a key into chat anyway, do not use it or repeat it; tell them it is in the transcript and that they may want to rotate it.
- **Write only inside the folder chosen in step 4.** Nothing else in the home directory, the shell profile or another project changes. The one exception is step 10, which on its own yes adds one entry to the coding agent's MCP config.
- **Install nothing.** If Docker, git or buildx is missing, name the fix and stop.
- **The `dev` sign-in adapter is for this machine only.** It checks no credential: anyone who can reach the port is the admin. The compose file below publishes the port on `127.0.0.1` for that reason. Never widen it, tunnel it or put a proxy in front of it. A shared or networked instance needs the `oidc` or `workos` adapter (`docs.nimblebrain.ai/config/instance-json/`).

## 1. Check Docker and the host

```bash
docker info >/dev/null && echo "docker: running"
docker compose version
docker info --format '{{.Architecture}}'
```

If any line prints an error instead, match the error as printed against the troubleshooting table, give that row's fix and stop. If no row matches, report the error line as written and stop. Do not install or start Docker yourself.

The last line is the architecture of the Docker host, which decides the route. On a Mac it is the Linux VM Docker runs in, not macOS. `x86_64` is the **pull** route. `aarch64` or `arm64` is the **build** route. Anything else: tell the user the runtime publishes no image for it and stop.

On the build route only, check the two tools it needs:

```bash
git --version
docker buildx version
```

If either is missing, stop here, before step 2, and tell the user why: the published images are `linux/amd64` only, so on this host the images must be built from source, and the runtime's Dockerfile uses `COPY --parents`, which only the buildx builder supports. Without buildx, Compose falls back to the classic builder and the build fails. Give the fix from the troubleshooting table, then end the run.

## 2. Say what will happen, and wait for a yes

Say this in three lines, in your own words, then wait:

1. Pull route: I will create one folder (default `~/nimblebrain-local`) with two files, pull two images (`ghcr.io/nimblebraininc/nimblebrain-runtime:v0.68.0` and `nimblebrain-web:v0.68.0`, about 2 GB on disk), and start two containers. Build route: the same folder, plus a clone of the public runtime repo at `v0.68.0` inside it; I will build the two images on this machine (about six minutes the first time, about 1.9 GB of images plus about 2.4 GB of build cache) instead of pulling them. Either way the web UI will be at `http://localhost:27246`.
2. You will put your own model API key in a file in that folder. I will not read it. Chats spend against the key the containers start with, and I will tell you if a key exported in this shell would be used in its place. Without a key everything starts, but chat does not work.
3. There is no account and no sign-in; it is reachable from this machine only. I will finish by showing how to stop it and how to remove everything.

On a rerun, the three lines say what is already in place. Do not continue without a clear yes.

## 3. Check for images already on the machine

Pull route:

```bash
docker image inspect --format '{{.RepoTags}} {{len .RepoDigests}}' ghcr.io/nimblebraininc/nimblebrain-runtime:v0.68.0 ghcr.io/nimblebraininc/nimblebrain-web:v0.68.0 2>/dev/null || true
```

No line for an image means step 7 pulls it. A line ending in `0` is an image built on this machine under the published name. Compose runs an image that is present and does not pull over it, and the image removal command in step 9 would delete it. Tell the user and ask before going on.

Build route:

```bash
docker image inspect --format '{{.RepoTags}}' nimblebrain-setup/runtime:v0.68.0 nimblebrain-setup/web:v0.68.0 2>/dev/null || true
```

A line for an image means an earlier run of this skill built it, and step 7 reuses it.

## 4. Choose the folder

Use the folder from step 2's plan, `~/nimblebrain-local`, unless the user named another when they said yes. Do not default to `~/nimblebrain`, which is where a default clone of the runtime repo lands. `<folder>` in every later command is the absolute path chosen here.

```bash
ls -la <folder> 2>/dev/null || echo "free"
grep -q '^name: nimblebrain-setup$' <folder>/docker-compose.yml 2>/dev/null && echo "ours" || true
```

Create the folder if it does not exist. Reuse it, on the user's yes, only if it holds nothing but `instance.json`, `docker-compose.yml`, `.env` and, on the build route, `runtime/`, and any `docker-compose.yml` there printed `ours`. Otherwise ask for another folder. That includes a checkout of the runtime repo: its own compose file publishes the port on every interface, so this skill does not start it.

On a Mac with Colima (`docker context show` prints `colima`, or `colima-<profile>` for a named profile), keep the folder inside a folder Colima shares with its VM. By default that is only the home folder, and a bind mount from anywhere else fails. This lists the shared folders:

```bash
colima ssh -- findmnt -t virtiofs,9p,fuse.sshfs -o TARGET
```

Never overwrite, merge into or delete an existing file. Write only the files from step 5 that are missing.

## 5. Write the files

`instance.json` names the identity provider. The runtime does not start without it.

```json
{
  "auth": {
    "adapter": "dev"
  }
}
```

`docker-compose.yml` is the runtime repo's own compose file with four changes. It pins `v0.68.0` instead of `latest`. It has no `./skills` mount, because the runtime repo does not ship that folder. It publishes the port on loopback. It names its project, so the containers and the `nimblebrain-setup_workspace` volume do not take their names from the folder. The pull route also drops the two `build:` keys, which need a source checkout; the build route keeps them, pointed at its clone.

Pull route:

```yaml
name: nimblebrain-setup

services:
  platform:
    image: ghcr.io/nimblebraininc/nimblebrain-runtime:v0.68.0
    restart: unless-stopped
    volumes:
      - workspace:/data
      - type: bind
        source: ./instance.json
        target: /data/instance.json
        read_only: true
        bind:
          create_host_path: false
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - GOOGLE_GENERATIVE_AI_API_KEY=${GOOGLE_GENERATIVE_AI_API_KEY:-}
      - GREENPT_API_KEY=${GREENPT_API_KEY:-}
      - NEBIUS_API_KEY=${NEBIUS_API_KEY:-}
      - XAI_API_KEY=${XAI_API_KEY:-}
    networks:
      - internal

  web:
    image: ghcr.io/nimblebraininc/nimblebrain-web:v0.68.0
    restart: unless-stopped
    ports:
      - "127.0.0.1:27246:8080"
    environment:
      - PLATFORM_URL=http://platform:27247
    depends_on:
      platform:
        condition: service_healthy
    networks:
      - internal

volumes:
  workspace:

networks:
  internal:
```

Build route: first clone the runtime repo at the tag, unless `<folder>/runtime` is already there from an earlier run.

```bash
git clone --depth 1 --branch v0.68.0 https://github.com/NimbleBrainInc/nimblebrain.git <folder>/runtime
```

git warns that the tag is not a commit and that HEAD is detached. Both are expected.

Then write this compose file. It is the pull route's file with each `image:` line replaced by a local name and a `build:` key. The local names keep a local build from looking like a published image.

```yaml
name: nimblebrain-setup

services:
  platform:
    image: nimblebrain-setup/runtime:v0.68.0
    build: ./runtime
    restart: unless-stopped
    volumes:
      - workspace:/data
      - type: bind
        source: ./instance.json
        target: /data/instance.json
        read_only: true
        bind:
          create_host_path: false
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - GOOGLE_GENERATIVE_AI_API_KEY=${GOOGLE_GENERATIVE_AI_API_KEY:-}
      - GREENPT_API_KEY=${GREENPT_API_KEY:-}
      - NEBIUS_API_KEY=${NEBIUS_API_KEY:-}
      - XAI_API_KEY=${XAI_API_KEY:-}
    networks:
      - internal

  web:
    image: nimblebrain-setup/web:v0.68.0
    build: ./runtime/web
    restart: unless-stopped
    ports:
      - "127.0.0.1:27246:8080"
    environment:
      - PLATFORM_URL=http://platform:27247
    depends_on:
      platform:
        condition: service_healthy
    networks:
      - internal

volumes:
  workspace:

networks:
  internal:
```

Write no `nimblebrain.json`. The runtime keeps its config in the `workspace` volume and boots without one.

## 6. The model key

Compose takes a variable from the shell before it reads `.env`, so first see which key variables the shell you run commands from already exports. This prints names only:

```bash
for v in ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_GENERATIVE_AI_API_KEY GREENPT_API_KEY NEBIUS_API_KEY XAI_API_KEY; do printenv "$v" >/dev/null && echo "$v: exported in this shell"; done; true
```

If any is exported, tell the user that the shell's value will be used and the same line in `.env` ignored, and ask which key they want. It may be a work key they did not mean to spend. If they want the file's key, start every `docker compose up` in this skill as `env -u <NAME> docker compose up -d`, with one `-u <NAME>` for each exported variable. If they want the shell's `ANTHROPIC_API_KEY`, no `.env` is needed; go to step 7.

Otherwise tell the user, with the real path filled in:

> Open `<folder>/.env` in your editor, add one line, and save:
> `ANTHROPIC_API_KEY=<your key>`
> Tell me when it is saved. I will not open the file.

Keys for the other providers go in the same file under their own variable names. Wait for the user to say it is saved, then check only that the file is there and not empty:

```bash
test -s <folder>/.env && echo "present" || echo "missing or empty"
```

If the user has no key yet, they may go on without one. Compose then warns that `ANTHROPIC_API_KEY` is not set on every `docker compose` command, and the containers start anyway. Skip step 8 and say so in the report.

## 7. Start it and wait for health

Check that no other folder already runs this setup under the same project name:

```bash
docker compose ls -a --filter name=nimblebrain-setup
docker volume ls -q --filter name=nimblebrain-setup_workspace
```

Stop and ask the user, without starting, reusing or removing anything, if the project row's CONFIG FILES is a path other than `<folder>/docker-compose.yml`, or if the volume exists and step 4 created the folder new. Either means another copy of this setup owns that name and its data.

Build route only, build both images first. It prints a long build log. The first run takes about six minutes; a rerun with the build cache is much faster.

```bash
cd <folder> && docker compose build
```

Then start it:

```bash
cd <folder> && docker compose up -d
```

On the pull route the first run pulls both images. The `web` container starts only after the `platform` container passes its health check, so the command can take a minute or more after the pull or build. On a rerun it leaves running, unchanged containers alone. Then poll the health endpoint through the published port for up to 2 minutes:

```bash
for i in $(seq 1 24); do curl -fsS http://localhost:27246/v1/health && break; sleep 5; done
```

Healthy is `{"status":"ok"}`. A curl error line before it, such as `curl: (52) Empty reply from server`, is normal while the containers finish starting. If the ok does not arrive, run `docker compose ps` and `docker compose logs --tail 50 platform` from the folder and use the troubleshooting table.

## 8. One real chat

Skip this step if the user went on without a key in step 6.

The health endpoint shows the runtime is up; it does not show that the key works. The supported way to chat is the web UI, so ask the user:

> Open http://localhost:27246 and send: `What can you help me with?`
> Tell me whether you got a reply.

There is no sign-in screen. A reply means the model call worked. An error in the chat means the key or the provider; see the table. Do not script a chat against `/v1/*`; the user confirms the reply in the web UI.

Report success only after the user confirms the reply.

## 9. Report

Give the user all of this, briefly:

- **Where it is:** `http://localhost:27246`, and the folder path. Which route ran (pulled or built) and the release, `v0.68.0`.
- **Chat:** confirmed, or not tested because there is no key yet. To add one later, put the line in `<folder>/.env`, then run `docker compose up -d` from the folder.
- **Stop it:** `docker compose down` from the folder. Until you run that, it starts again whenever Docker starts. Data stays in the volume, and `docker compose up -d` starts it again.
- **Update it:** the steps are in `references/TROUBLESHOOTING.md` under "Updating"; offer to run them when the user asks.
- **Remove everything this created:**
  1. `docker compose down -v` from the folder removes the containers, the network and the volume `nimblebrain-setup_workspace`, with every conversation in it.
  2. `rm -rf <folder>`, after step 1. The folder holds the `.env` file with the key and, on the build route, the runtime clone.
  3. Optional, the images. Pull route, and only for images this setup pulled: `docker image rm ghcr.io/nimblebraininc/nimblebrain-runtime:v0.68.0 ghcr.io/nimblebraininc/nimblebrain-web:v0.68.0`. Build route: `docker image rm nimblebrain-setup/runtime:v0.68.0 nimblebrain-setup/web:v0.68.0`. The build cache stays until `docker builder prune`, which clears the cache of every project on this Docker host, not only this one.

  Offer to run these; run them only on a clear yes, and never as part of setup itself.
- **Telemetry:** the runtime logs that it collects anonymous usage telemetry (`nimblebrain.ai/telemetry/`). In `v0.68.0` it sends events only when the container has a `POSTHOG_API_KEY`, and this compose file passes none. To turn it off explicitly, add `- NB_TELEMETRY_DISABLED=1` to the `platform` environment, then `docker compose up -d`.
- **What this did not do:** it created no account, installed no software, changed nothing outside the folder and Docker, installed no connectors, and set up no sign-in. The instance is for this machine only.

## 10. Offer to connect a coding agent (separate yes)

Ask as its own question, after the report. Say plainly what it means:

> I can add this instance's workspace MCP endpoint to your coding agent. That lets the agent call every tool in the workspace: the built-in ones (conversations, files, tasks) and every connector you install in NimbleBrain later, with the access those connectors have. Because this instance uses the dev sign-in, which checks no credential, any program on this machine that reaches the port, the agent included, can call the admin-only tools the web app's settings use (user and workspace management, model configuration), even though they are not in the agent's tool list (`docs.nimblebrain.ai/connect/mcp-endpoint/`). Do you want that?

On yes, follow `docs.nimblebrain.ai/connect/external-clients/` with these differences:

- The user copies the server URL from **Workspace settings → MCP**. It ends in `/mcp/ws_<id>`. The id in the browser address bar (`/w/<id>/`) lacks the `ws_` prefix, so do not build the URL from it. Keep the copied `/mcp/ws_<id>` path and use the host `http://localhost:27246`, the only port this setup publishes; the settings page shows port 27247, which is not published.
- For Claude Code, name the entry `nimblebrain-local`, so it cannot be confused with an entry for a hosted workspace. Run `claude mcp get nimblebrain-local` first; if an entry exists, stop and ask. Ask whether the entry should apply in this project only (the default) or everywhere, then run `claude mcp add --transport http nimblebrain-local http://localhost:27246/mcp/ws_<id>` for this project, or `claude mcp add --transport http --scope user nimblebrain-local http://localhost:27246/mcp/ws_<id>` for everywhere. Both keep the entry in Claude Code's own config, outside the folder. Do not use `--scope project`: it writes `.mcp.json` into the current repository.
- Only after the add succeeds, give the undo command for the scope used: `claude mcp remove nimblebrain-local`, run from the same project directory, or with `--scope user`.

## References

- `TROUBLESHOOTING.md` - Symptom, cause and fix for each step, and how to update

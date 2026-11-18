# TypeScript: the fallback

Use TypeScript when the person asks for it or the server must live in a Node codebase. Python with `nimblebrain-server-sdk` is the default because the SDK does the host-facing work (annotations, the error contract, skills, the Server Card) in one call each; in TypeScript you write each against the protocol yourself. Everything a host expects is documented as wire behaviour: the "Wire (any SDK)" tabs under [MCP extensions](https://docs.nimblebrain.ai/extensions/overview/) and [skills published by a server](https://docs.nimblebrain.ai/using/skills/#skills-published-by-an-mcp-server).

## Start from the template

[`NimbleBrainInc/mcp-server-template-typescript`](https://github.com/NimbleBrainInc/mcp-server-template-typescript) is a GitHub template on `@modelcontextprotocol/sdk` with Zod schemas, Biome, Vitest, a stdio entrypoint (`src/index.ts`) and a streamable HTTP one (`src/server.ts`). It needs Node.js 24 or later.

```bash
gh repo create <owner>/mcp-<service> --template NimbleBrainInc/mcp-server-template-typescript --private --clone
cd mcp-<service> && npm install && npm run check
```

Replace the `YOUR_*` placeholders its README lists, then implement in its order: response types (`src/utils/types.ts`), the API client, input schemas (`src/utils/schemas.ts`), one handler per tool (`src/handlers/`), and the registrations in `src/app.ts`.

**Protocol era.** The template is on `@modelcontextprotocol/sdk` 1.x, which answers the `2025-11-25` `initialize` handshake and not `server/discover`: an Inspector probe with `--protocol-era modern` fails, and `auto` or `legacy` connects. Hosts that also speak `2025-11-25` connect to it. Say so in the review report rather than filing it as a defect of the surface.

## Annotations

The SDK takes raw hints. Give every tool the hints for its kind (`design.md`, rung 5):

```ts
server.registerTool(
  "acme_get_ticket",
  {
    description: "…when to call it, and when not…",
    inputSchema: GetTicketSchema.shape,
    annotations: { readOnlyHint: true },                          // reads
    // annotations: { readOnlyHint: false, destructiveHint: false }  // adds
    // annotations: { readOnlyHint: false, destructiveHint: true }   // changes
  },
  (args) => getTicket(client, args),
);
```

Give every Zod field a `.describe(...)`: that is the property `description` the model reads while filling arguments.

## Errors

A handler catches and returns `{ content: [{ type: "text", text }], isError: true }` (the template's `errorResponse`). Make the text actionable and safe: name what the caller should change, and keep the upstream's raw body, URLs and secrets out of it; log those to stderr. To match the shape the Python SDK sends, also return `structuredContent: { error: { code, retryable, message } }` with a code from the [error contract's set](https://docs.nimblebrain.ai/server-sdk/errors/#the-codes).

## ES modules: no `__dirname`

The template is `"type": "module"`, where `__dirname` and `__filename` do not exist and referencing them throws at startup. Resolve files relative to the module:

```ts
import { fileURLToPath } from "node:url";
const here = fileURLToPath(new URL(".", import.meta.url));   // or import.meta.dirname
```

`${__dirname}` inside an MCPB `manifest.json` is different: the host substitutes it when it starts a bundle, and it belongs only there.

## Skills

The template's `skills/example-skill/SKILL.md` is a placeholder that nothing serves. To publish a skill from a TypeScript server, implement the MCP Skills extension on the wire: declare `io.modelcontextprotocol/skills`, answer `skills/list` and `skills/get` with each file's SHA-256 digest and size, and serve each file with `resources/read` at `skill://<name>/<file>`. The steps are in the wire tab of [skills published by an MCP server](https://docs.nimblebrain.ai/using/skills/#skills-published-by-an-mcp-server). A `SKILL.md` needs Agent Skills frontmatter (`name` equal to its directory, and `description`). Registering `skill://` resources without the extension publishes nothing a host loads as a skill.

Check the result with `--method skills/list --verify` in the Inspector.

## Tests

Pair a real `McpServer` with a `Client` over `InMemoryTransport`, mock the API client with `vi.fn()`, and assert on what each tool returns, including `isError` for each failure path (the template's `tests/server.test.ts`).

## Serve over streamable HTTP

```bash
ACME_API_KEY=... PORT=3000 npm run dev:http      # http://127.0.0.1:3000/mcp
```

`src/server.ts` binds `HOST` (default `127.0.0.1`). Set `HOST=0.0.0.0` only for the Linux case in `SKILL.md`.

## Server Card

No helper exists in TypeScript. A server can serve the card itself at `GET <mcp-path>/server-card` (`/mcp/server-card`) with media type `application/mcp-server-card+json`: `name` in reverse-DNS form with one slash, `version`, a 1 to 100 character `description` and optional `title`, matching what `serverInfo` reports. The [Server Card guide](https://docs.nimblebrain.ai/server-sdk/server-card/) lists the fields and the rules a reader holds it to. Without one, the server still connects, named by its `serverInfo`.

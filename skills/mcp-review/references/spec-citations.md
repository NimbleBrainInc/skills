# Citations

Quote from here so a finding cites a rule rather than an opinion. Each entry names its source; follow the link when a review turns on the exact wording, because the MCP specification is versioned and moves.

Sources: the MCP specification (`modelcontextprotocol.io/specification/draft/`), Anthropic's tool-use documentation, and OpenAI's function-calling guide.

## Tool names

MCP specification, *Server / Tools → Tool Names*. All `SHOULD`-level:

> Tool names **SHOULD** be between 1 and 128 characters in length (inclusive).
> Tool names **SHOULD** be considered case-sensitive.
> The following **SHOULD** be the only allowed characters: uppercase and lowercase ASCII letters (A-Z, a-z), digits (0-9), underscore (\_), hyphen (-), and dot (.)
> Tool names **SHOULD NOT** contain spaces, commas, or other special characters.
> Tool names **SHOULD** be unique within a server.

Valid examples the spec gives: `getUser`, `DATA_EXPORT_v2`, `admin.tools.list`.

On collisions across aggregated servers:

> Tool name uniqueness is scoped to a single server. Clients or proxies that aggregate tools from multiple servers **MAY** encounter naming collisions (for example, two servers each exposing a `search` tool) and **SHOULD** implement a disambiguation strategy such as prefixing tool names with a server identifier. The server `name` (from `serverInfo`) is not guaranteed to be unique across servers and **SHOULD NOT** be relied upon for disambiguation.

The obligation sits on the client and it is a `SHOULD`. A server publishing a generic name is depending on behaviour no client owes it.

## Name, title and display precedence

MCP specification, `BaseMetadata`:

> `name` — The programmatic name of the entity.
> `title` — Intended for UI and end-user contexts, optimized to be human-readable and easily understood, even by those unfamiliar with domain-specific terminology. If not provided, the name should be used for display (except for Tool, where `annotations.title` should be given precedence over using `name`, if present).

## Descriptions

The MCP specification says only that `description` is a "Human-readable description of functionality". It sets no length limit and gives no guidance on phrasing — that is vendor territory.

**Anthropic**, tool-use documentation, on what earns a call:

> Write detailed descriptions — Claude uses these to decide when to use the tool. Be prescriptive about *when* to call it, not just what it does (e.g. "Call this when the user asks about current prices or recent events").

and, in the Opus 4.8 migration guidance, on where that belongs:

> The same lever works at the tool-description level, not just the system prompt: prescriptive descriptions that state *when* to call a tool give meaningful lift over descriptions that only state what the tool does. Make the trigger condition part of each capability's own `description`.

Anthropic's list of tool-definition practices also asks for specific names (`get_current_weather` over `weather`), a `description` on every property, `enum` for fixed value sets, an accurate `required` list, and a small total tool count.

**OpenAI**, function-calling guide: asks for "clear and detailed function names, parameter descriptions, and instructions", and recommends keeping "fewer than 20 functions available at the start of a turn" for accuracy. The current guide states **no** maximum description length.

### The 1024-character question

OpenAI historically rejected function descriptions over 1024 characters with a "String should have at most 1024 characters" error, and tooling still carries workarounds for it. That limit is absent from the current documentation, and community testing reports far longer descriptions being accepted, but OpenAI never announced a change either way.

So: no specification and no current vendor documentation imposes a limit. Treat 1024 as a self-imposed ceiling only where a server targets ChatGPT or the OpenAI directory, and say that is what you are doing rather than presenting it as a rule.

## Input schemas

MCP specification, *Server / Tools → Data Types*:

> `inputSchema`: JSON Schema defining expected parameters
> - **MUST** be a valid JSON Schema object (not `null`)
> - For tools with no parameters, use one of these valid approaches:
>   - `{ "type": "object", "additionalProperties": false }` — **Recommended**: explicitly accepts only empty objects
>   - `{ "type": "object" }` — accepts any object (including with properties)

## Results and errors

MCP specification, *Server / Tools → Error Handling*, distinguishes two channels:

> **Protocol Errors** indicate issues with the request structure itself that models are less likely to be able to fix: Unknown tool, Malformed requests, Server errors.
> **Tool Execution Errors** contain actionable feedback that language models can use to self-correct and retry with adjusted parameters: API failures, Input validation errors (e.g., date in wrong format, value out of range), Business logic errors. They are reported in tool results with `isError: true`.
> Clients **SHOULD** provide tool execution errors to language models to enable self-correction.

The spec's own example of actionable text: `"Invalid departure date: must be in the future. Current date is 08/08/2025."`

On output schemas:

> If an output schema is provided: Servers **MUST** provide structured results that conform to this schema. Clients **SHOULD** validate structured results against this schema.

and, for compatibility:

> For backwards compatibility, a tool that returns structured content SHOULD also return the serialized JSON in a TextContent block.

## Determinism and caching

MCP specification, *Server / Tools*:

> Servers **SHOULD** return tools in a deterministic order (i.e., the same ordering across requests when the underlying set of tools has not changed). Deterministic ordering enables clients to reliably cache the tool list and improves LLM prompt cache hit rates when tools are included in model context.

The advertised set also has a stability rule:

> This set **MAY** be empty and **MAY** change over time, but **MUST NOT** vary per-connection or as a side effect of other requests on the connection. The set **MAY** vary by the authorization presented on the request — for example, returning only the tools the caller's granted scopes permit — since credentials are per-request input, not connection state.

## Annotations are hints

MCP specification, `ToolAnnotations`:

> NOTE: all properties in ToolAnnotations are **hints**. They are not guaranteed to provide a faithful description of tool behavior (including descriptive properties like `title`). Clients should never make tool use decisions based on ToolAnnotations received from untrusted servers.

and in the tool data types:

> For trust & safety and security, clients **MUST** consider tool annotations to be untrusted unless they come from trusted servers.

The four behavioural hints and their defaults: `readOnlyHint` (default false), `destructiveHint` (default true, meaningful only when `readOnlyHint` is false), `idempotentHint` (default false, same condition), `openWorldHint` (default true).

## Human in the loop

MCP specification, *Server / Tools → User Interaction Model*:

> For trust & safety and security, there **SHOULD** always be a human in the loop with the ability to deny tool invocations.

Applications **SHOULD** make clear which tools are exposed, indicate when tools are invoked, and present confirmation prompts.

## Stateful tools

MCP has no protocol-level session, so cross-call state rides an explicit handle returned by a creation tool and passed back as an ordinary argument. The specification's design guidance, from *Server / Tools → Stateful Tools*, asks servers to consider authorization on every call, opaque rather than structured handles, a stated lifetime in the creation tool's description, and an expiry error the model can recover from. The matching attack is in `security.md`.

# Citations

Quote from here so a finding cites a rule rather than an opinion.

**These transcriptions are a cache, not the authority.** Every block carries its source link. The MCP specification is versioned and moves, so before a finding turns on exact wording — or on a rule being in force for the version the server negotiated — open the link and re-derive it. A quote that cannot be re-derived is not a citation.

Sources: the [MCP specification](https://modelcontextprotocol.io/specification/draft) (draft), [Anthropic's Define tools page](https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use), and [OpenAI's function-calling guide](https://developers.openai.com/api/docs/guides/function-calling).

## Tool names

MCP specification, [*Server / Tools* → Tool Names](https://modelcontextprotocol.io/specification/draft/server/tools#tool-names). All `SHOULD`-level:

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

MCP specification, [`schema/draft/schema.ts`](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/draft/schema.ts), `BaseMetadata`:

On `name`:

> Intended for programmatic or logical use, but used as a display name in past specs or fallback (if title isn't present).

On `title`:

> Intended for UI and end-user contexts — optimized to be human-readable and easily understood, even by those unfamiliar with domain-specific terminology. If not provided, the name should be used for display (except for Tool, where `annotations.title` should be given precedence over using `name`, if present).

The same file states the rule outright, on `Tool.annotations`:

> Display name precedence order is: `title`, `annotations.title`, then `name`.

Quote that line rather than deriving the order from the two clauses above.

## Descriptions

The MCP specification says only that `description` is a "Human-readable description of functionality". It sets no length limit and gives no guidance on phrasing — that is vendor territory.

**Anthropic**, [Define tools](https://platform.claude.com/docs/en/agents-and-tools/tool-use/implement-tool-use) → *Best practices for tool definitions*. Five items; these two carry the description and naming rules:

> **Provide extremely detailed descriptions.** This is by far the most important factor in tool performance. Your descriptions should explain every detail about the tool, including:
>
> * What the tool does
> * When it should be used (and when it shouldn't)
> * What each parameter means and how it affects the tool's behavior
> * Any important caveats or limitations, such as what information the tool does not return if the tool name is unclear. The more context you can give Claude about your tools, the better it will be at deciding when and how to use them. Aim for at least 3–4 sentences for each tool description, more if the tool is complex.

> **Use meaningful namespacing in tool names.** When your tools span multiple services or resources, prefix names with the service (for example, `github_list_prs`, `slack_send_message`). This makes tool selection unambiguous as your library grows, and is especially important when using [tool search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool).

The remaining three: prefer descriptions but use `input_examples` for complex tools; consolidate related operations into fewer tools rather than one per action; and design tool responses to return only high-signal information.

The same page constrains the name itself — `name` "Must match the regex `^[a-zA-Z0-9_-]{1,64}$`". That is tighter than MCP's 1–128 characters, and it does not admit the dot MCP allows, so a name legal under the specification can still be rejected by this API.

**Not in that list**, though all three are good practice and all three appear in the page's tool-definition example and its good-versus-poor description comparison: a `description` on every property, `enum` for a fixed value set, and an accurate `required` list. Cite them to the example, not to the practices list.

**OpenAI**, function-calling guide: asks for "clear and detailed function names, parameter descriptions, and instructions", and recommends keeping "fewer than 20 functions available at the start of a turn" for accuracy — adding, in its own words, "though this is just a soft suggestion." The current guide states **no** maximum description length.

### The 1024-character question

OpenAI historically rejected function descriptions over 1024 characters with a "String should have at most 1024 characters" error, and tooling still carries workarounds for it. That limit is absent from the current documentation, and community testing reports far longer descriptions being accepted, but OpenAI never announced a change either way.

So: no specification and no current vendor documentation imposes a limit. Treat 1024 as a self-imposed ceiling only where a server targets ChatGPT or the OpenAI directory, and say that is what you are doing rather than presenting it as a rule.

## Input schemas

MCP specification, [*Server / Tools* → Data Types](https://modelcontextprotocol.io/specification/draft/server/tools#data-types):

> `inputSchema`: JSON Schema defining expected parameters
> - **MUST** be a valid JSON Schema object (not `null`)
> - For tools with no parameters, use one of these valid approaches:
>   - `{ "type": "object", "additionalProperties": false }` - **Recommended**: explicitly accepts only empty objects
>   - `{ "type": "object" }` - accepts any object (including with properties)

## Results and errors

MCP specification, [*Server / Tools* → Error Handling](https://modelcontextprotocol.io/specification/draft/server/tools#error-handling), distinguishes two channels:

> **Protocol Errors** indicate issues with the request structure itself that models are less likely to be able to fix: Unknown tool, Malformed requests, Server errors.
> **Tool Execution Errors** contain actionable feedback that language models can use to self-correct and retry with adjusted parameters: API failures, Input validation errors (e.g., date in wrong format, value out of range), Business logic errors. They are reported in tool results with `isError: true`.
> Clients **SHOULD** provide tool execution errors to language models to enable self-correction.

The spec's own example of actionable text: `"Invalid departure date: must be in the future. Current date is 08/08/2025."`

On output schemas, from [*Server / Tools* → Tool Result](https://modelcontextprotocol.io/specification/draft/server/tools#tool-result):

> If an output schema is provided: Servers **MUST** provide structured results that conform to this schema. Clients **SHOULD** validate structured results against this schema.

and, from the same section, for compatibility:

> For backwards compatibility, a tool that returns structured content SHOULD also return the serialized JSON in a TextContent block.

## Determinism and caching

MCP specification, [*Server / Tools* → Capabilities](https://modelcontextprotocol.io/specification/draft/server/tools#capabilities):

> Servers **SHOULD** return tools in a deterministic order (i.e., the same ordering across requests when the underlying set of tools has not changed). Deterministic ordering enables clients to reliably cache the tool list and improves LLM prompt cache hit rates when tools are included in model context.

The advertised set also has a stability rule:

> This set **MAY** be empty and **MAY** change over time (see List Changed Notification), but **MUST NOT** vary per-connection or as a side effect of other requests on the connection. The set **MAY** vary by the authorization presented on the request — for example, returning only the tools the caller's granted scopes permit — since credentials are per-request input, not connection state.

## Pagination

MCP specification, [*Utilities* → Pagination](https://modelcontextprotocol.io/specification/draft/server/utilities/pagination#implementation-guidelines):

> 1. Servers **SHOULD**:
>    * Provide stable cursors
>    * Handle invalid cursors gracefully

The same page lists what pagination covers — `resources/list`, `resources/templates/list`, `prompts/list` and `tools/list`. Nothing in the specification paginates a `tools/call` result, so these are list-surface rules and a cursor finding against tool output has no source.

Clients **MUST** treat cursors as opaque tokens. A server that encodes meaning in a cursor is relying on behaviour no client owes it — the same shape as publishing a generic tool name.

## Annotations are hints

MCP specification, [`schema/draft/schema.ts`](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/draft/schema.ts), `ToolAnnotations`:

> NOTE: all properties in `ToolAnnotations` are **hints**. They are not guaranteed to provide a faithful description of tool behavior (including descriptive properties like `title`). Clients should never make tool use decisions based on ToolAnnotations received from untrusted servers.

The [tools page](https://modelcontextprotocol.io/specification/draft/server/tools#data-types) states the trust rule itself:

> For trust & safety and security, clients **MUST** consider tool annotations to be untrusted unless they come from trusted servers.

The four behavioural hints and their defaults, also from `schema.ts`: `readOnlyHint` (default false), `destructiveHint` (default true, meaningful only when `readOnlyHint` is false), `idempotentHint` (default false, same condition), `openWorldHint` (default true).

## Human in the loop

MCP specification, [*Server / Tools* → User Interaction Model](https://modelcontextprotocol.io/specification/draft/server/tools#user-interaction-model):

> For trust & safety and security, there **SHOULD** always be a human in the loop with the ability to deny tool invocations.

Applications **SHOULD** make clear which tools are exposed, indicate when tools are invoked, and present confirmation prompts.

## Stateful tools

MCP has no protocol-level session, so cross-call state rides an explicit handle returned by a creation tool and passed back as an ordinary argument. The specification's design guidance, from [*Server / Tools* → Stateful Tools](https://modelcontextprotocol.io/specification/draft/server/tools#stateful-tools), asks servers to consider opaque rather than structured handles, a stated lifetime in the creation tool's description, and an expiry error the model can recover from. On authorization it splits by auth model:

> **Authorization.** For authenticated servers, a handle is a name, not a capability. The server should validate the caller's authorization against the handle on every call. For unauthenticated servers, where the handle is necessarily a bearer token, it should be generated with sufficient entropy (e.g., a UUIDv4) and given a bounded lifetime.

So an unauthenticated server whose handle is the credential is following the guidance, not breaking it. The matching attack is in `security.md`.

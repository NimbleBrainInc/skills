# Designing and reviewing a server's surface

These are rules to apply, not a document to read. Every rung ends in a checkable bar, and the completion criterion at the bottom binds you to all of them. Designing a surface and reviewing one are the same work and finish the same way: in build mode you apply the rungs to the tools you propose before writing code, and again to what the running server advertises; in review mode you apply them to an existing server's advertised set.

An MCP server publishes two things. The **surface** is everything it advertises: names, titles, descriptions, schemas, annotations, resource metadata. The **boundary** is everything crossing into it: arguments, tokens, URIs, state handles.

Two frames carry the whole thing:

**The surface is prompt.** Every advertised character is text a model reads and reasons over, spending the same window and the same attention as a system prompt. Judge it as prompt, not as API documentation. A description that reads well to a developer and gives the model no reason to act is a defect.

**The boundary is untrusted.** Every argument is model output, and model output is shaped by whatever the model just read. Judge each entry point as if the argument were chosen by an attacker, because a prompt injection three tool calls ago means it may have been.

The rungs are grounded in the MCP specification (the `2026-07-28` revision) and the tool-authoring guidance from Anthropic and OpenAI.

## Read the advertised surface, never the source alone

Frameworks reshape what the source appears to say, and they disagree with each other. One Python docstring with an `Args:` and a `Returns:` block, read over the wire:

| framework | what the tool advertises |
|---|---|
| `mcp` 2.3 (`MCPServer`) | the whole docstring, `Args:` and `Returns:` included, as the description; properties carry no `description` |
| `fastmcp` 4.2 | `Args:` lifted into per-property `description`; both blocks stripped from the tool description |

Same source, opposite surfaces, and on FastMCP whatever the `Returns:` block said never reaches the model. A decorator injects metadata the source never names; a wrapper rewrites a description. Reviewing source is reviewing intent, and reviewing it against one framework's behaviour is reviewing a coincidence. Review what ships.

Ask the running server, with the client upstream maintains, the [MCP Inspector](https://github.com/modelcontextprotocol/inspector) CLI. Always name the protocol era: an ad-hoc run otherwise speaks only the legacy `initialize` handshake, and a server that serves only `2026-07-28` (whose handshake is `server/discover`) refuses it.

```bash
I="npx -y @modelcontextprotocol/inspector --cli --protocol-era auto"

# streamable HTTP (the transport is detected from a /mcp path)
$I http://127.0.0.1:8000/mcp --method tools/list
# stdio
$I <server-command> --method tools/list

# the other primitives
$I <target> --method resources/list
$I <target> --method resources/templates/list
$I <target> --method prompts/list

# the protocol version agreed, the capabilities and extensions, the instructions
$I <target> --method initialize
```

`auto` negotiates the newest version both sides speak, and `--method initialize` prints the result on either era (over `server/discover` on `2026-07-28`). Then ask which eras the server serves at all, since a host may connect on either: rerun with `--protocol-era modern` (`2026-07-28` only) and `--protocol-era legacy` (`2025-11-25`, `initialize`). Two more checks are worth their seconds: `--method tools/list --strict` reports schema portability problems, and `--method skills/list --verify` checks every server-published skill file against its listed digest.

The Inspector carries the session id streamable HTTP requires, holds the connection while the server answers, and prints what a client receives, `_meta` and vendor extensions included. Hand-rolled JSON-RPC works until a transport adds a requirement, then fails quietly: a bare `tools/list` over HTTP is a `400`, and a stdio server whose stdin closes at `EOF` can exit before answering, printing nothing and returning `0`.

Measure sizes while you are there: description length per tool, and the whole `tools/list` payload. That payload loads into context in every conversation where the server is enabled, so it is a standing cost, not a one-off.

**Record the protocol version the server negotiated, and the eras it serves, and name them in the report.** The citations in `spec-citations.md` are pinned to `2026-07-28`. For a server that negotiates `2025-11-25`, open the cited rule on that version's page and confirm it was in force before filing it.

## The rungs

Ordered by what the model and the host do with the surface. Apply every rung to every advertised tool, resource and prompt in scope.

A rung that restates a specification rule carries that rule's strength and no more. `spec-citations.md` records which are `MUST` and which are `SHOULD`; check it before a finding claims more force than the source gives it, and say so when a rung is this skill's reasoning rather than anyone's rule.

### 1. Find: names

- Names use only `A-Z`, `a-z`, `0-9`, `_`, `-`, `.`, run 1 to 128 characters, and carry no spaces, commas or other special characters. These are `SHOULD`s. The Anthropic API admits the same length but not the dot (`^[a-zA-Z0-9_-]{1,128}$`), so the spec's own `admin.tools.list` example will not survive that surface. Use `_` or `-`.
- Names are specific enough to mean something alone. `get_current_weather` over `weather`; `create_invoice` over `create`.
- The advertised list is deterministically ordered. This is the spec's `SHOULD` on `tools/list`, and it is what lets a client cache the list and keeps prompt-cache hits alive. It governs the surface, not what a call returns.
- A paginated list returns stable cursors and handles an invalid cursor gracefully (`-32602`). These are `SHOULD`s, and they reach every list operation: `tools/list`, `resources/list`, `resources/templates/list`, `prompts/list`.
- Names survive aggregation. Uniqueness is scoped to one server, and a host that merges several servers *should* disambiguate but is not required to. A bare `search`, `upgrade` or `query` is a bet on client behaviour: prefix it, or accept that a user with five connectors has given the model an ambiguous referent. Anthropic asks for the same prefixing directly, as "meaningful namespacing in tool names" (`github_list_prs`, `slack_send_message`).
- `title` and `annotations.title` are for humans; `name` is what the model reasons about. For tools, display precedence runs `title`, then `annotations.title`, then `name`.

### 2. Choose: descriptions

- **The description states when to call, not only what the tool does.** This is the highest-yield rung. Anthropic calls the description "by far the most important factor in tool performance" and asks it to cover "When it should be used (and when it shouldn't)", alongside what the tool does, what each parameter means, and the caveats, aiming for at least three or four sentences. A description that states capability and stops is the failure this rung exists to catch.
- It states the boundary too: when *not* to call, and what to do when a required argument is missing. Without it the model's likeliest move on a near-miss is silence, not a clarifying question.
- One meaning lives in one place. Server `instructions` and a tool description that argue the same point twice pay tokens in every request and teach nothing the second time. Guidance longer than a description belongs in a server-published skill, which loads only when the work matches.
- Nothing in the description is aimed at a human maintainer. Authoring conventions, changelog notes and rationale belong in the commit, not in a payload the model pays for.
- No hard length limit exists in the spec or in either vendor's current documentation. Read `spec-citations.md` § The 1024-character question before invoking that number.

### 3. Fill: input schemas

- Every property carries its own `description`. Argument guidance belongs in schema metadata, which the model reads while filling arguments, not in prose it read while choosing a tool.
- `required` lists exactly what is genuinely required; everything else has a sensible default.
- A parameter with a fixed set of values is an `enum`, unless the set is runtime-configured or the handler deliberately absorbs unknown values, in which case a static enum makes the schema reject at the boundary what the code is written to tolerate. Say which case applies.
- A parameter the server accepts but ignores says so in its description. Silent no-op parameters teach the model that its arguments do not matter.
- `inputSchema` is a valid JSON Schema object, never null. For a tool with no parameters the spec permits both `{"type": "object", "additionalProperties": false}` (its recommendation) and `{"type": "object"}`; the second is not a finding.

### 4. Read: results, output schemas, errors

- Tool execution failures return a result with `isError: true` and text the model can act on. They are not JSON-RPC errors: that channel is for unknown tools and malformed requests, which the model cannot fix. A returned object that merely *describes* an error, without `isError`, is scored as a success by the host and by the model.
- Error text names what to change. The specification's own example, `Invalid departure date: must be in the future. Current date is 08/08/2025.`, recovers; `400 Bad Request` does not. It also leaks nothing: no upstream response body, URL, secret or another tenant's data.
- An `outputSchema`, where present, matches what the server actually returns, and the server also returns the serialized JSON in a text block for clients that ignore structured content.
- A listing returns bounded rows: an unbounded field (a body, a description) travels as a preview or not at all, with an id or `uri` the whole record is read from. Anthropic's "return only high-signal information" is the quotable source; the bound itself is this skill's reasoning.
- The spec states no ordering rule for what a *call* returns. Pagination and its cursor rules govern the list operations, not tool results, so a results-ordering finding here is this skill's reasoning rather than a quotable rule.

### 5. Act: annotations

The host reads annotations to decide what to ask the user before a call. They are hints, not enforcement, so this rung checks that each hint is present and true.

- Every tool carries annotations. Under the spec's defaults an unannotated tool has `readOnlyHint: false` and `destructiveHint: true`: it declares itself a destructive write, and a host may ask the user to confirm a call that only reads.
- Each tool is exactly one of three kinds, and its hints say which:

  | kind | the tool | hints |
  |---|---|---|
  | reads | reads and changes nothing | `readOnlyHint: true` |
  | adds | writes without losing anything already there | `readOnlyHint: false`, `destructiveHint: false` |
  | changes | overwrites, removes, sends, or acts on what is there | `readOnlyHint: false`, `destructiveHint: true` |

  `nimblebrain-server-sdk` names these `READS`, `ADDS` and `CHANGES`. A read that records an audit row on the way is still a read.
- The hint matches the behaviour. `readOnlyHint` on a tool that writes, or `destructiveHint: false` on one that deletes, is a lie the client is entitled to believe. Check it against the handler, not the name.
- `idempotentHint` (default false) and `openWorldHint` (default true) are worth setting when they are known; their absence is not a finding.

### 6. Trust: the boundary

- Every argument is validated server-side. Path-shaped arguments are resolved and confined; URL-shaped arguments are checked against SSRF (private ranges, link-local `169.254.0.0/16`, loopback, redirects). The spec addresses SSRF to clients and to authorization servers, so for an ordinary server this is analogy: sound, but not a rule you can quote.
- Tokens are audience-validated. A server **must not** accept a token that was not issued for it, and must not forward a client's token to a downstream API.
- State handles carry the weight the server's auth model gives them. On an **authenticated** server a handle is a name, not a capability: bind it to the principal and re-verify on every call. On an **unauthenticated** server the handle *is* the bearer token by the spec's own design, so the bar is entropy and a bounded lifetime, not binding. Filing "possession grants access" against the second case is a finding the source does not make.
- Annotations are never the control. A tool that must not run without consent enforces that itself.
- Scopes are two bars, not one. The **published set** is a finding on its own: the spec's named mistakes include publishing every possible scope in `scopes_supported` and using wildcard or omnibus scopes. The **challenge** is the softer bar: the spec sanctions minimum, recommended and extended compositions there, so a broad challenge is only a finding against the composition the server actually claims.
- A local server on HTTP is reachable by every process on the machine. The spec asks a server meant to run locally to restrict that (an authorization token, or stdio); binding to `0.0.0.0` widens it to the network.

Read `security.md` before writing up this rung.

For servers exposing resources or prompts, read `resources-and-prompts.md`: those primitives have their own field rules, URI-scheme rules and error codes, and a missing resource is a protocol error where a failing tool is a result.

To quote a rule in a finding, take the citation from the reference files rather than paraphrasing: `spec-citations.md` for the surface rules, `security.md` for the boundary ones.

## Completion criterion

The work is done when every tool, resource and prompt in scope (the whole advertised set when reviewing, the proposed or changed items when building) has been checked against every rung; each finding names its rung and quotes the rule it breaks; and rungs that pass are reported as passing rather than omitted. A rung you could not check is reported as unchecked, with the reason. Silence on a rung reads as a pass, so never let it stand in for one.

Verify each finding against the advertised surface before reporting it. A rule that a framework already satisfies is not a finding, and reporting it costs the reader more than it saves.

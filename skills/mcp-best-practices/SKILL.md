---
name: mcp-best-practices
description: Best practices for MCP servers — how to name, describe and schema a tool so a model actually calls it, how resources and prompts differ, and what the boundary must never trust. Applies while authoring a new surface or as an audit of an existing one, grounded in the MCP specification and the tool-authoring guidance from Anthropic and OpenAI. Triggers include "MCP best practices", "name this tool", "audit this MCP server", "why won't the model call my tool", "/mcp-best-practices".
license: MIT
compatibility: Any MCP server, any language. Reads a running server over tools/list, resources/list and prompts/list, on HTTP or stdio.
allowed-tools: Read Bash Glob Grep WebFetch
metadata:
  area: authoring
  version: "0.1.0"
  author: NimbleBrain
---

# MCP server best practices

These are rules to apply, not a document to read. Every rung below ends in a checkable bar, and the completion criterion at the bottom binds you to all of them — whether you are authoring a surface or auditing one, the work is the same and finishes the same way.

An MCP server publishes two things. The **surface** is everything it advertises — names, titles, descriptions, schemas, annotations, resource metadata. The **boundary** is everything crossing into it — arguments, tokens, URIs, state handles.

Two frames carry the whole thing:

**The surface is prompt.** Every advertised character is text a model reads and reasons over, spending the same window and the same attention as a system prompt. Judge it as prompt, not as API documentation. A description that reads well to a developer and gives the model no reason to act is a defect.

**The boundary is untrusted.** Every argument is model output, and model output is shaped by whatever the model just read. Judge each entry point as if the argument were chosen by an attacker, because a prompt injection three tool calls ago means it may have been.

Scope: the surface and the boundary. Building a server end to end — scaffolding, bundling, releasing — is the `mcpb` skill.

## Read the advertised surface, never the source alone

Frameworks reshape what the source appears to say. A Python docstring's `Args:` block does not reach the input schema; a decorator injects metadata the source never names; a wrapper rewrites a description. Reviewing source is reviewing intent. Review what ships.

Ask the server for it:

```bash
# Over HTTP
curl -s -X POST "$URL" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# Over stdio — same wire, same instrument
printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"audit","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | <server-command>
```

Read the wire, not the server object. Importing the module and calling an SDK method is reviewing the source one layer down — it inherits whatever the framework renamed this release, and it prints the SDK's field names rather than the ones a client receives. The two commands above are the whole instrument, and they do not age.

Measure sizes while you are there — description length per tool, and the whole `tools/list` payload. That payload loads into context in every conversation where the server is enabled, so it is a standing cost, not a one-off.

**Capture the negotiated `protocolVersion` from `initialize` too, and name it in the report.** The citations here are transcribed from the draft specification, which moves — several quoted rules postdate `2025-11-25`, and no list of which ones stays accurate. So the obligation is per-citation rather than per-list: before filing, open the link on the citation you are quoting and confirm the rule was in force for the version the server negotiated.

## The rungs

Ordered by what the model does with the surface. Apply every rung to every advertised tool, resource and prompt.

A rung that restates a specification rule carries that rule's strength and no more. `references/spec-citations.md` records which are `MUST` and which are `SHOULD`; check it before a finding claims more force than the source gives it, and say so when a rung is this skill's reasoning rather than anyone's rule.

### 1. Find — names

- Names use only `A-Z`, `a-z`, `0-9`, `_`, `-`, `.`, run 1–128 characters, and carry no spaces, commas or other special characters. These are `SHOULD`s. The Anthropic API is harder — `^[a-zA-Z0-9_-]{1,64}$` — which rejects the dot and anything past 64 characters, so the spec's own `admin.tools.list` example will not survive that surface.
- Names are specific enough to mean something alone. `get_current_weather` over `weather`; `create_invoice` over `create`.
- The advertised list is deterministically ordered. This is the spec's `SHOULD` on `tools/list`, and it is what lets a client cache the list and keeps prompt-cache hits alive — it governs the surface, not what a call returns.
- Names survive aggregation. Uniqueness is scoped to one server, and a host that merges several servers *should* disambiguate but is not required to. A bare `search`, `upgrade`, or `query` is a bet on client behaviour — prefix it, or accept that a user with five connectors has given the model an ambiguous referent. Anthropic asks for the same prefixing directly, as "meaningful namespacing in tool names" (`github_list_prs`, `slack_send_message`).
- `title` and `annotations.title` are for humans; `name` is what the model reasons about. For tools, display precedence runs `title` → `annotations.title` → `name` — `annotations.title` outranks only `name`, and only when `title` is absent.

### 2. Choose — descriptions

- **The description states when to call, not only what the tool does.** This is the highest-yield rung. Anthropic calls the description "by far the most important factor in tool performance" and asks it to cover "When it should be used (and when it shouldn't)", alongside what the tool does, what each parameter means, and the caveats — aiming for at least three or four sentences. A description that states capability and stops is the failure this skill exists to catch.
- It states the boundary too — when *not* to call, and what to do when a required argument is missing. Without it the model's likeliest move on a near-miss is silence, not a clarifying question.
- One meaning lives in one place. Server `instructions` and a tool description that argue the same point twice pay tokens in every request and teach nothing the second time.
- Nothing in the description is aimed at a human maintainer. Authoring conventions, changelog notes and rationale belong in the commit, not in a payload the model pays for.
- No hard length limit exists in the spec or in either vendor's current documentation. Read `references/spec-citations.md` § The 1024-character question before invoking that number — it is not a rule, and the reason matters.

### 3. Fill — input schemas

- Every property carries its own `description`. Argument guidance belongs in schema metadata, which the model reads while filling arguments, not in prose it read while choosing a tool.
- `required` lists exactly what is genuinely required; everything else has a sensible default.
- A parameter with a fixed set of values is an `enum` — unless the set is runtime-configured or the handler deliberately absorbs unknown values, in which case a static enum makes the schema reject at the boundary what the code is written to tolerate. Say which case applies.
- A parameter the server accepts but ignores says so in its description. Silent no-op parameters teach the model that its arguments do not matter.
- `inputSchema` is a valid JSON Schema object, never null. For a tool with no parameters the spec permits both `{"type": "object", "additionalProperties": false}` (its recommendation) and `{"type": "object"}` — the second is not a finding.

### 4. Read — results, output schemas, errors

- Tool execution failures return a result with `isError: true` and text the model can act on. They are not JSON-RPC errors — that channel is for unknown tools and malformed requests, which the model cannot fix.
- Error text names what to change. The specification's own example — `Invalid departure date: must be in the future. Current date is 08/08/2025.` — recovers; `400 Bad Request` does not.
- An `outputSchema`, where present, matches what the server actually returns, and the server also returns the serialized JSON in a text block for clients that ignore structured content.
- Paginated results use stable cursors. The spec asks for that and no more — it states no ordering rule for what a *call* returns, so a results-ordering finding is this skill's reasoning, not a quotable rule.

### 5. Trust — the boundary

- Every argument is validated server-side. Path-shaped arguments are resolved and confined; URL-shaped arguments are checked against SSRF (private ranges, link-local `169.254.0.0/16`, loopback, redirects). The spec addresses SSRF to clients and to authorization servers, so for an ordinary server this is analogy — sound, but not a rule you can quote.
- Tokens are audience-validated. A server **must not** accept a token that was not issued for it, and must not forward a client's token to a downstream API.
- State handles carry the weight the server's auth model gives them. On an **authenticated** server a handle is a name, not a capability — bind it to the principal and re-verify on every call. On an **unauthenticated** server the handle *is* the bearer token by the spec's own design, so the bar is entropy and a bounded lifetime, not binding. Filing "possession grants access" against the second case is a finding the source does not make.
- Annotations are hints, never enforcement. `readOnlyHint` on a tool that writes is a lie the client is entitled to believe.
- Scopes are two bars, not one. The **published set** is a finding on its own — the spec's named mistakes include publishing every possible scope in `scopes_supported` and using wildcard or omnibus scopes. The **challenge** is the softer bar: the spec sanctions minimum, recommended and extended compositions there, so a broad challenge is only a finding against the composition the server actually claims.

Read `references/security.md` before writing up this rung.

For servers exposing resources or prompts, read `references/resources-and-prompts.md` — those primitives have their own field rules, URI-scheme rules and error codes.

To quote a rule in a finding, take the citation from the reference files rather than paraphrasing — `spec-citations.md` for the surface rules, `security.md` for the boundary ones.

## Completion criterion

The work is done when every tool, resource and prompt in scope — the whole advertised set when auditing, the one item when authoring — has been checked against every rung; each finding names its rung and quotes the rule it breaks; and rungs that pass are reported as passing rather than omitted. A rung you could not check is reported as unchecked, with the reason. Silence on a rung reads as a pass, so never let it stand in for one.

Verify each finding against the advertised surface before reporting it. A rule that a framework already satisfies is not a finding, and reporting it costs the reader more than it saves.

## Report shape

Lead with the surface as it stands, then the findings ranked by what they cost.

```
SURFACE REVIEW — example-server (3 tools, 0 resources, 0 prompts)

SURFACE     tools/list payload 12,400 chars (~3,100 tokens, loaded every conversation)
            create_invoice 835 · upgrade 303 · list_customers 443

FINDINGS
  1  Choose   create_invoice describes capability, states no trigger
              → model has no cue to volunteer it; highest-yield fix
  2  Fill     4 of 4 params carry no schema description
              → Args prose sits in the description instead
  3  Find     `upgrade` is generic; collides across aggregated servers

PASSES      Find (charset/length), Read (isError, outputSchema), Trust (audience
            validation, SSRF guard on fetch targets)

UNCHECKED   Trust (scope minimization) — server declares no scopes to inspect
```

Then, briefly: what to fix first and why that order. Rank by whether the model's behaviour changes, not by how many rules a fix touches.

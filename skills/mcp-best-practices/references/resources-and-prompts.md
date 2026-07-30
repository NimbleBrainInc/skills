# Resources and prompts

Read this when the server advertises either primitive. Source: the MCP specification, *Server / Resources* and *Server / Prompts*.

The rungs in `SKILL.md` still apply — the surface is prompt, the boundary is untrusted — but both primitives differ from tools in who decides when they are used, and that changes what a good description is doing.

## Who controls what

The specification assigns each primitive a controller, and it is the most load-bearing sentence in either page:

- **Tools are model-controlled.** The model discovers and invokes them on its own. Descriptions are aimed at the model's decision to call.
- **Resources are application-driven.** The host decides how to bring them into context — a picker, a search, an automatic heuristic.
- **Prompts are user-controlled.** They are surfaced for a person to select explicitly, typically as slash commands. The spec is careful that this "refers to who decides when the prompt is used, not who authors its content."

So a prompt `description` is read by a human choosing from a menu, and a tool `description` is read by a model deciding whether to act. A prompt description written in trigger language ("Call this when…") is aimed at the wrong reader. Review each against its actual audience.

Resources sit in between: the `description` may reach a model, a picker UI, or both, depending on the host. Write it to be legible to either, and use `annotations` to say which.

## Resources

### Fields

`uri` (unique identifier), `name`, optional `title`, optional `description`, optional `mimeType`, optional `size` in bytes, optional `icons`. `name`/`title` follow the same `BaseMetadata` split as tools — `name` programmatic, `title` for display.

Set `mimeType` wherever it is known. It is what lets a host decide whether to render, embed, or hand the resource to the model.

### URI schemes

- `https://` — use **only** when the client can fetch the resource itself without going through the MCP server. Otherwise the spec says to prefer another scheme, "even if the server will itself be downloading resource contents over the internet." A server that exposes `https://` URIs it intends to proxy is misusing the scheme.
- `file://` — filesystem-like, and it need not map to a real filesystem. Non-regular files may carry an XDG MIME type such as `inode/directory`.
- `git://` — version control integration.
- Custom schemes are allowed and **MUST** conform to RFC 3986.

### Annotations

`audience` (`"user"`, `"assistant"`, or both), `priority` (0.0 to 1.0, where 1 is effectively required and 0 entirely optional), and `lastModified` (ISO 8601). Hosts use these to filter by audience, decide what to pull into context, and sort by recency.

A resource with no `audience` gives the host nothing to filter on. If a resource is only ever for the human, or only ever for the model, say so — it is the difference between a picker entry and context spend.

### Errors

Sharper than the tool rules, and worth checking directly:

> If the requested resource does not exist, servers **MUST** return a JSON-RPC error with code `-32602` (Invalid Params). Servers **SHOULD** return `-32603` for internal errors.
> Servers **MUST NOT** return an empty `contents` array for a non-existent resource. An empty array is ambiguous—it could mean the resource exists but has no content, or that it doesn't exist at all.

Clients **SHOULD** also accept `-32002`, which earlier protocol versions used for not-found.

Note the inversion against tools: a missing resource is a **protocol** error, where a failing tool call is a **result** with `isError: true`. Getting this backwards is a common finding.

### Capabilities and templates

A server declaring `resources` **MUST** answer `resources/list`. `listChanged` and `subscribe` are independent optional features — declare each only if it is implemented, and omit the object's contents entirely (`"resources": {}`) if neither is.

Resource templates expose parameterized resources via RFC 6570 URI templates, listed at `resources/templates/list`, with arguments completable through the completion API.

### Security

Servers **MUST** validate all resource URIs, **MUST** properly encode binary data, and **MUST** sanitize file paths to prevent directory traversal when serving `file://`. Access controls and permission checks on sensitive resources are `SHOULD`.

## Prompts

### Fields

`name` (unique identifier), optional `title`, optional `description`, optional `icons`, and optional `arguments`. Each argument has a `name`, a `description`, and a `required` flag.

Argument descriptions matter here for the same reason schema property descriptions matter for tools: they are what a completion UI and the model both read when filling in values. An argument with no description is a blank box.

Arguments may be auto-completed through the completion API, which is worth wiring for any argument with a discoverable value set.

### Messages

A prompt returns `messages`, each with a `role` of `user` or `assistant` and one content block: text, image, audio, `resource_link`, or an embedded `resource`.

Image and audio data **MUST** be base64-encoded with a valid MIME type. An embedded resource **MUST** carry a valid URI, the appropriate MIME type, and either text or a base64 blob.

Prefer `resource_link` over an embedded resource when the client can fetch it — embedding spends context the host may not have wanted to spend.

### Errors

Standard JSON-RPC codes, again unlike tools. `SHOULD`-level here, where the resources not-found code above is a `MUST`:

- Invalid prompt name — `-32602`
- Missing required arguments — `-32602`
- Internal errors — `-32603`

### Security

> Implementations **MUST** carefully validate all prompt inputs and outputs to prevent injection attacks or unauthorized access to resources.

Servers **SHOULD** validate prompt arguments before processing. Treat a prompt that interpolates an argument into message text as a template injection surface — the argument reaches the model as instructions.

## Capability hygiene, both primitives

For resources and prompts alike: the advertised set **MUST NOT** vary per-connection or as a side effect of other requests, though it **MAY** vary by the authorization presented, since credentials are per-request input rather than connection state.

If `listChanged` is declared, the notification should actually fire — a `SHOULD` in the spec, but one worth raising. A declared capability that never emits is worse than an undeclared one, because clients subscribe and then trust a list that has gone stale.

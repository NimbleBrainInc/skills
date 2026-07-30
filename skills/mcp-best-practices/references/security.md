# The boundary

Read this when the server does OAuth, proxies a third-party API, holds state across calls, or ships to run on a user's machine. Source: the MCP specification's *Security Best Practices* page, plus the per-primitive security sections.

The frame from `SKILL.md` holds throughout: **the boundary is untrusted**. Arguments arrive as model output, and model output is shaped by whatever the model last read — a web page, a document, another tool's result. Review each entry point as if the argument were attacker-chosen.

## Token passthrough

The one unambiguous `MUST NOT` in the whole page:

> MCP servers **MUST NOT** accept any tokens that were not explicitly issued for the MCP server.

Two distinct failures hide here, and a review should name which one it found:

1. **Audience validation failure** — the server accepts a token issued for some other service. Check that the audience claim is verified against the server's own resource identifier, and that verification is on rather than configured off.
2. **Passthrough** — the server forwards a client's token unmodified to a downstream API. The downstream then trusts it as if it came from the server.

What it costs: rate limits and request validation keyed to audience are bypassed; the server cannot tell its clients apart in logs; a stolen token turns the server into an exfiltration proxy.

**Review move.** Find where the token is verified and confirm the audience check is not disabled by configuration. Then follow every outbound call and confirm the credential is the server's own, not the caller's.

## Confused deputy

Applies to any server that proxies a third-party API using a static client ID while letting MCP clients register dynamically.

The attack: a user authorizes once, the third-party authorization server sets a consent cookie for the static client ID, and an attacker later registers a client with their own `redirect_uri` and sends the user a crafted link. The cookie suppresses the consent screen, and the authorization code lands on the attacker's server.

Required protections, all `MUST`:

- Per-client consent stored server-side, checked **before** forwarding to the third party.
- A consent page naming the requesting client, the scopes, and the registered `redirect_uri`, with CSRF protection and framing denied.
- Consent cookies using the `__Host-` prefix with `Secure`, `HttpOnly`, `SameSite=Lax`, signed or server-side, bound to the specific `client_id`.
- `redirect_uri` validated by **exact string match** against the registered value — no patterns, no wildcards.
- A cryptographically random, single-use, short-lived `state`, stored **only after** consent is approved and validated at the callback.

The ordering is the subtle part: setting the state cookie before consent approval renders the consent screen decorative.

## SSRF

**Read this one as an extension by analogy, not as a rule the specification states.** The spec scopes SSRF to MCP *clients* fetching OAuth-discovery URLs, and addresses its `SHOULD`s to them — there is no server-side SSRF obligation in the text. The mitigations transfer intact to any server that fetches a URL the caller influenced (a fetch target, a webhook, a metadata document), which is why they are here, but a finding raised on this section cites reasoning rather than a quotable rule. Say which you are doing.

Block private and reserved ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, loopback `127.0.0.0/8` and `::1`, link-local `169.254.0.0/16` (which is the cloud metadata endpoint), and IPv6 `fc00::/7`, `fe80::/10`. Require HTTPS outside loopback.

Three traps worth checking specifically:

- **Redirects.** Validation on the first URL means nothing if the fetcher follows a redirect to `169.254.169.254` unchecked. Apply the same rules to every hop, or stop following redirects.
- **Hand-rolled IP parsing.** The spec is blunt that attackers use octal, hex and IPv4-mapped IPv6 forms that custom parsers miss. A regex over the hostname is not a control.
- **DNS rebinding.** A domain can resolve safely at validation and to an internal address at fetch time. Pin the resolution between check and use, or put an egress proxy in the path.

## State handle hijacking

For any server that returns a handle — a cart, a job, a workflow, a session-ish id — and takes it back as a tool argument.

> MCP servers that implement authorization **MUST** verify all inbound requests. MCP servers **MUST NOT** treat possession of a state handle as authentication.

The bar: handles are generated with a secure random source, bound server-side to the authenticated principal (key state as `<user_id>:<handle>` with the user id taken from the verified token, never from the request), rejected when presented by anyone else, and expired.

**Review move.** Find the handler that accepts the handle and confirm it re-derives the principal from the token and compares. A lookup keyed on the handle alone is the bug, and it reads as ordinary code.

## Scope minimization

The failure is a token carrying `files:*`, `db:*`, `admin:*` because the server published every scope in `scopes_supported` and the client asked for all of them.

Review for: a minimal baseline scope set covering only low-risk discovery and reads; targeted `WWW-Authenticate` challenges that escalate when a privileged operation is first attempted; and tolerance for down-scoped tokens.

Named mistakes: publishing every possible scope, wildcard or omnibus scopes (`*`, `all`, `full-access`), bundling unrelated privileges to preempt future prompts, returning the whole catalog in every challenge, and treating scopes claimed in a token as sufficient without server-side authorization logic.

## Local servers

For anything distributed to run on a user's machine:

> MCP servers intending for their servers to be run locally **SHOULD** implement measures to prevent unauthorized usage from malicious processes: Use the `stdio` transport to limit access to just the MCP client. Restrict access if using an HTTP transport, such as: Require an authorization token. Use unix domain sockets or other Interprocess Communication (IPC) mechanisms with restricted access.

A local server on an unauthenticated HTTP port is reachable by any process on the machine, and by a web page via DNS rebinding.

## Per-primitive requirements

**Resources** — servers **MUST** validate all resource URIs, **MUST** properly encode binary data, and **MUST** sanitize file paths against directory traversal when serving `file://`. Access controls and permission checks on sensitive resources are `SHOULD`.

**Prompts** — implementations **MUST** carefully validate all prompt inputs and outputs to prevent injection attacks or unauthorized access to resources. Servers **SHOULD** validate prompt arguments before processing.

**Tools** — servers **MUST** validate all tool inputs, implement access controls, rate limit invocations, and sanitize outputs.

## What this page does not cover

The client-side attacks — OAuth authorization URL validation, `javascript:` scheme injection, stdio proxy privilege escalation, mix-up attacks, localhost redirect URI impersonation — are real and documented on the same specification page, but they are obligations on the MCP *client*. Reviewing a server, note them only where the server hands a client a URL to open.

# Phase 5: Embed Skill

Create an in-package skill resource that guides LLMs on how to select and compose the server's tools effectively.

## 5a: Analyze Tools

Extract all tool registrations from the server entry point.
See `references/CONVENTIONS-{lang}.md` → "Concept Mapping" for the pattern name.

## 5b: Draft SKILL.md

Generate a **draft** embedded skill file — or edit the generic scaffolded one, if it exists.
See `references/SKILL_FORMAT-{lang}.md` → "File Location" for the correct path.

The draft should contain:

1. **Tool selection table** — each tool with a one-line description and when to use it
2. **Context reuse rules** — which tool outputs feed into subsequent calls
3. **Multi-step workflow patterns** — 2-3 composed workflows showing how to chain tools

The frontmatter should contain the name and description of the skill.

Example structure:
```markdown
---
name: mcp-<name>-service
description: Provides knowledge of how to use MCP <name> most effectivelly. It's loaded into the agent's context when running the MCP.
---

## Tools

| Tool | Use when... |
|------|-------------|
| `list_items` | You need to browse or search items |
| `get_item` | You have an item ID and need full details |
| `create_item` | You need to create a new item |

## Context Reuse

- Use the `id` from `list_items` results when calling `get_item`
- Use the `id` from `create_item` response for follow-up `get_item` calls

## Workflows

### 1. Inventory Check
1. `list_items` with category filter
2. For each item: `get_item` to get full details
3. Summarize findings

### 2. Create and Verify
1. `create_item` with required fields
2. `get_item` with the returned ID to confirm creation
```

## 5c: Review with Contributor

The embedded skill created so far is inherently unopinionated — it was created generically based on common knowledge and basic patterns. The contributor might have a specific idea of how to use the MCP already in mind though. So it's important to make this step interactive and request confirmation before moving on.

**Show the draft to the contributor and ask for their input.** Present the full SKILL.md content and ask:

```
=> Here's the draft embedded skill for your server:

   [show SKILL.md content]

=> This guides how an LLM will select and compose your tools. Consider:
   - Are the right workflows represented?
   - Are there tool combinations or sequencing patterns you'd add?
   - Any context reuse rules that aren't obvious from the tool signatures?
   - Should any workflows be removed or reframed?

=> Let me know if it needs change, or approve to continue.
```

Iterate with the contributor until they approve the SKILL.md. This may involve multiple rounds — the contributor might add domain-specific workflows, adjust tool selection guidance, or refine context reuse rules that only someone familiar with the API would know.

Do **not** proceed to wiring (5d) until the contributor has explicitly approved the skill content.

## 5d: Wire the Resource

Wire the skill resource per `references/SKILL_FORMAT-{lang}.md` → "Wiring Pattern"
(TypeScript bundling step included there).

## 5e: Verify

Same command as Phase 4e with `resources/list` instead of `tools/list`. Only the executor differs:

- **Python:** `... | uv run python -m mcp_<name>.server 2>/dev/null`
- **TypeScript:** `... | node build/index.js --stdio 2>/dev/null`

Full command:
```bash
printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","method":"resources/list","id":2}\n' | <executor> 2>/dev/null
```

The response should include a resource with `uri: "skill://<name>/usage"`.

> **Note:** The embedded skill is encouraged but not mandatory per mpak spec. If no meaningful workflows exist yet (e.g., the server has only 1-2 tools), it's acceptable to skip this phase and add the skill later.

## 5f: Integration & LLM Smoke Tests

### Integration tests

**Python:**
```bash
make test-integration         # real API calls (needs <NAME>_API_KEY in .env)
```

Real API calls against the live service. The template scaffolds `tests-integration/test_core_tools.py` as a stub — you must replace it with real tests.

**How to write them:** Open `api_client.py` and list every public method (skip `__init__`, `close`, `_request`, `_ensure_session`, and dunder methods). For each method, write a test:

- **Read methods** (list, get, search): Call with minimal valid parameters, assert the response has the expected shape (list, dict, or model with expected keys).
- **Write methods** (create, update, delete): Create a test resource, verify it, then clean it up in a `finally` block. If no delete method exists, mark the resource as completed/archived and leave a comment.
- **Chained methods:** Some methods need an ID from a prior call (e.g., `list_workspaces` returns a GID needed by `search_tasks`). Chain them — call the list method first, use the first result's ID.
- **Tier-gated methods:** If the API has premium endpoints that may not be available on the user's plan, write a `has_<feature>_access` helper that probes the endpoint and returns `False` on 401/402/403. Use `pytest.skip()` in the test if access is unavailable.

See `references/PATTERNS-PY.md` → "Integration Test Patterns (Python)" for concrete examples.

**How to run them:**

1. Ask the contributor to add their API key to `.env` (e.g., `ASANA_API_KEY=xxx`). The `.env` file is already in `.gitignore` and `.mcpbignore`. The contributor was asked for this key at the start of the process — they should have it ready.
2. Run `make test-integration`.
3. All tests should pass or skip (for tier-gated features). Fix any failures before proceeding.
4. If the contributor says auth setup is too complex for now (e.g., OAuth flows, multi-step app configuration), proceed — the tests are written and ready to run later. Do not skip writing the tests.

### LLM smoke tests

**Python:**
```bash
make test-llm                 # needs <NAME>_API_KEY + ANTHROPIC_API_KEY in .env
```

Verify Claude Haiku selects the correct tool given the skill resource. Requires both the service API key and `ANTHROPIC_API_KEY`.

**How to write them:** The template scaffolds `get_server_context()` and `get_anthropic_client()` — leave those as-is. Replace the commented-out test stub with 3–5 real tests, one per key tool. Extract a `call_llm()` helper to avoid repeating the system prompt construction across tests.

Each test sends a natural language prompt and asserts the LLM selected the expected tool. Include concrete values for any required parameters in the prompt (IDs, coordinates, dates) — without them, the LLM will ask for clarification instead of calling the tool.

See `references/PATTERNS-PY.md` → "LLM smoke tests" for the `call_llm()` helper pattern and the concrete-identifiers rule.

**How to run them:**

1. Ask the contributor to add `ANTHROPIC_API_KEY` to `.env` alongside the service API key.
2. Run `make test-llm`.
3. All tests should pass. If a test fails because the LLM picked the wrong tool, adjust the prompt to be more specific before touching the SKILL.md.
4. If the contributor does not have an `ANTHROPIC_API_KEY`, proceed — the tests are written and ready to run later. Do not skip writing the tests.

**Working through failures:** These tests can be challenging depending on the target API's auth method, plan-gated endpoints, and rate limits. Work through failures interactively with the contributor:
- If auth is complex (OAuth, multi-step), help the contributor get a working token and update the test fixtures
- If endpoints are plan-gated, use the tier-skip pattern (see PATTERNS-PY.md) to gracefully skip inaccessible endpoints
- If the contributor doesn't have the required API keys or wants to move on, that's fine — these tests are recommended but **not blocking** for initial release

## Gate

**Criteria:**
- [ ] Contributor has approved the SKILL.md content
- [ ] Skill resource is wired in server code
- [ ] `resources/list` includes `skill://<name>/usage`
- [ ] Integration tests written with real assertions (not stubs or TODOs)
- [ ] Integration tests pass (recommended, not blocking)
- [ ] LLM smoke tests written with real assertions (not stubs or TODOs)
- [ ] LLM smoke tests pass (recommended, not blocking)

**If any criterion fails:** Revisit the relevant sub-step above. For integration/LLM tests, discuss with the contributor whether to fix now or defer.

**When all pass (or non-blocking items deferred):** Proceed to Phase 6.

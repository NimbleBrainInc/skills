# Phase 5: Embed Skill

Create an in-package skill resource that guides LLMs on how to select and compose the server's tools effectively.

## 5a: Analyze Tools

Extract the server's tool surface:
- **Python:** Extract all `@mcp.tool()` functions from `server.py`
- **TypeScript:** Extract all `server.registerTool()` calls from `src/index.ts`

## 5b: Draft SKILL.md

Generate a **draft** embedded skill file — or edit the generic scaffolded one, if it exists:
- **Python:** `src/mcp_<name>/SKILL.md`
- **TypeScript:** `src/SKILL.md`

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

**Python:** Add to `server.py`:
- `from importlib.resources import files` import
- `SKILL_CONTENT = files("mcp_<name>").joinpath("SKILL.md").read_text()`
- `instructions=` parameter on `FastMCP(...)` constructor
- `@mcp.resource("skill://<name>/usage")` decorated function returning `SKILL_CONTENT`

**TypeScript:** Add to `src/index.ts`:
- `import { readFileSync } from "fs"` and `import { join } from "path"`
- `const SKILL_CONTENT = readFileSync(join(__dirname, "SKILL.md"), "utf-8")`
- `instructions` in `McpServer` constructor
- `server.resource("skill-usage", "skill://<name>/usage", ...)` registration

**TypeScript bundling:** Since `.mcpbignore` excludes both `src/` and `*.md`:
1. Add to Makefile `build` target: `cp src/SKILL.md build/SKILL.md`
2. Add to `.mcpbignore`: `!build/SKILL.md`

See `references/SKILL_FORMAT.md` for complete wiring examples in both languages.

## 5e: Verify

Run MCP runtime validation (same as Phase 4e) and confirm `resources/list` includes `skill://<name>/usage`:

**Python:**
```bash
printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","method":"resources/list","id":2}\n' | uv run python -m mcp_<name>.server 2>/dev/null
```

**TypeScript:**
```bash
printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","method":"resources/list","id":2}\n' | node build/index.js --stdio 2>/dev/null
```

The response should include a resource with `uri: "skill://<name>/usage"`.

> **Note:** The embedded skill is encouraged but not mandatory per mpak spec. If no meaningful workflows exist yet (e.g., the server has only 1-2 tools), it's acceptable to skip this phase and add the skill later.

## Gate

**Criteria:**
- [ ] Contributor has approved the SKILL.md content
- [ ] Skill resource is wired in server code
- [ ] `resources/list` includes `skill://<name>/usage`

**If any criterion fails:** Revisit the relevant sub-step above.

**When all pass:** Proceed to Phase 6.

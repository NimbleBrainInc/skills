# Embedded Skill Resource Format (TypeScript)

## Overview

An embedded skill resource is a single `SKILL.md` file that lives **inside** the MCP server package and is exposed as an MCP resource at `skill://<name>/usage`. It is NOT a standalone artifact — there is no `mpak skill validate` and no separate distribution step. The skill ships automatically with the `.mcpb` bundle.

## File Location

`src/SKILL.md`

## Frontmatter

The file begins with YAML frontmatter containing the skill's identity:

```yaml
---
name: mcp-<name>-service
description: Provides knowledge of how to use MCP <name> most effectively. It's loaded into the agent's context when running the MCP.
---
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier, following the `mcp-<name>-service` convention |
| `description` | Yes | One-line summary of what the skill provides |

## Content Structure

After the frontmatter, the Markdown body should contain:

1. **Tool selection table** — lists each tool with a one-line description and when to use it
2. **Context reuse rules** — which tool outputs to feed into subsequent calls (e.g., "use the `id` from `list_items` when calling `get_item`")
3. **Multi-step workflow patterns** — 2–3 composed workflows showing how to chain tools for real tasks

## Wiring Pattern

```typescript
import { readFileSync } from "fs";
import { join } from "path";

const SKILL_CONTENT = readFileSync(join(__dirname, "SKILL.md"), "utf-8");

const server = new McpServer({
  name: SERVER_NAME,
  version: VERSION,
  instructions: "Read the skill resource at skill://<name>/usage before using tools.",
});

server.resource("skill-usage", "skill://<name>/usage", async (uri) => ({
  contents: [{ uri: uri.href, text: SKILL_CONTENT, mimeType: "text/markdown" }],
}));
```

### Bundling Note

The `.mcpbignore` excludes both `src/` and `*.md`, so the SKILL.md must be copied during build:

1. **Makefile** — add a copy step to the `build` target: `cp src/SKILL.md build/SKILL.md`
2. **`.mcpbignore`** — add `!build/SKILL.md` to override the `*.md` exclusion

At runtime, `readFileSync(join(__dirname, "SKILL.md"))` works because `__dirname` resolves to `build/`.

## Quality Checklist

- [ ] Covers all tools exposed by the server
- [ ] Composes 2+ tools per workflow pattern
- [ ] Context reuse specified (which outputs feed into which inputs)
- [ ] Resource URI matches `skill://<name>/usage`
- [ ] Server `instructions` parameter directs the LLM to read the skill resource

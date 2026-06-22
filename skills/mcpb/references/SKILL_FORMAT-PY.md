# Embedded Skill Resource Format (Python)

## Overview

An embedded skill resource is a single `SKILL.md` file that lives **inside** the MCP server package and is exposed as an MCP resource at `skill://<name>/usage`. It is NOT a standalone artifact — there is no `mpak skill validate` and no separate distribution step. The skill ships automatically with the `.mcpb` bundle.

## File Location

`src/mcp_<name>/SKILL.md`

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

```python
from importlib.resources import files

SKILL_CONTENT = files("mcp_<name>").joinpath("SKILL.md").read_text()

mcp = FastMCP(
    "<Service>",
    instructions="Read the skill resource at skill://<name>/usage before using tools.",
)

@mcp.resource("skill://<name>/usage")
def get_skill() -> str:
    """Tool selection guide and workflow patterns for this server."""
    return SKILL_CONTENT
```

## Quality Checklist

- [ ] Covers all tools exposed by the server
- [ ] Composes 2+ tools per workflow pattern
- [ ] Context reuse specified (which outputs feed into which inputs)
- [ ] Resource URI matches `skill://<name>/usage`
- [ ] Server `instructions` parameter directs the LLM to read the skill resource

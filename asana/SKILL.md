---
name: asana
description: Guides Asana tool usage with correct workspace/project discovery, task creation, and GID handling. Use when interacting with Asana tools. Triggers include "asana", "task", "project", "my tasks", "create task".
metadata:
  version: 1.0.0
  category: operations
  tags:
    - asana
    - tasks
    - projects
    - workspaces
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Asana Integration

## Critical Rule: Discover GIDs Before Any Operation

**NEVER guess workspace GIDs, project GIDs, or tool names.** Asana requires exact numeric GID strings. Wrong GIDs return "You do not have access" errors.

Before ANY operation, resolve GIDs by calling discovery tools first.

## GID Format

Asana GIDs are **numeric strings**: `"1208518288356318"`

Not UUIDs. Not prefixed. Always extract from a tool response in the current conversation.

## Tool Names

The tool name is `ASANA_CREATE_A_TASK`, **NOT** `ASANA_CREATE_TASK` or `asana_create_task`. Common tools:

| Tool | Purpose |
|------|---------|
| `ASANA_GET_MULTIPLE_WORKSPACES` | List user's workspaces (get GIDs) |
| `ASANA_GET_MULTIPLE_PROJECTS` | List projects in a workspace |
| `ASANA_GET_MULTIPLE_TASKS` | List tasks by workspace or project |
| `ASANA_CREATE_A_TASK` | Create a task |
| `ASANA_SEARCH_TASKS_IN_WORKSPACE` | Search tasks by text |
| `ASANA_UPDATE_A_TASK` | Update a task |
| `ASANA_CREATE_SUBTASK` | Create a subtask |
| `ASANA_CREATE_TASK_COMMENT` | Add comment to a task |
| `ASANA_GET_SECTIONS_IN_PROJECT` | List sections in a project |
| `ASANA_ADD_TASK_TO_SECTION` | Move task to a section |

If uncertain about a tool name, call `get_connection_tools` once. Do not re-fetch on every turn.

## Quick Start: List My Tasks

```
Step 1: ASANA_GET_MULTIPLE_WORKSPACES -> extract workspace gid
Step 2: ASANA_GET_MULTIPLE_TASKS(workspace=<gid>, assignee="me")
```

## Quick Start: Create a Task

```
Step 1: ASANA_GET_MULTIPLE_WORKSPACES -> extract workspace gid
Step 2: ASANA_GET_MULTIPLE_PROJECTS(workspace=<gid>) -> find project gid
Step 3: ASANA_CREATE_A_TASK(name=..., workspace=<gid>, projects=[<project_gid>])
```

## Situational Handling

### Situation: User asks "what's in my Asana?" or "show my tasks"

**Required action:** Discover workspace, then list tasks assigned to user.

```
Step 1: ASANA_GET_MULTIPLE_WORKSPACES -> get workspace gid
Step 2: ASANA_GET_MULTIPLE_TASKS(workspace=<gid>, assignee="me")
```

### Situation: User asks to create a task

**Required action:** Resolve workspace and project GIDs before creating.

```
Step 1: ASANA_GET_MULTIPLE_WORKSPACES -> get workspace gid
Step 2: ASANA_GET_MULTIPLE_PROJECTS(workspace=<gid>) -> find target project
Step 3: ASANA_CREATE_A_TASK(name=..., workspace=<gid>, projects=[<project_gid>])
```

If user names a project (e.g., "in G&A Tasking"), match against the project list from step 2.

**If no project specified:** Ask the user which project. Do not create without a project unless explicitly told to.

### Situation: Subsequent operations in same conversation

**Required action:** Reuse GIDs already discovered. Do not re-fetch workspace or project GIDs you already have.

### Situation: User asks to search tasks

**Required action:** Resolve workspace GID first, then search.

```
Step 1: ASANA_GET_MULTIPLE_WORKSPACES -> get workspace gid
Step 2: ASANA_SEARCH_TASKS_IN_WORKSPACE(workspace_gid=<gid>, text="query")
```

### Situation: User asks to update or complete a task

**Required action:** Find the task first, then update with its GID.

```
Step 1: Find the task (search or list)
Step 2: ASANA_UPDATE_A_TASK(task_gid=<gid>, completed=true)
```

## Parameter Reference

### ASANA_CREATE_A_TASK

| Parameter | Required | Format | Notes |
|-----------|----------|--------|-------|
| `name` | Yes | String | Task title |
| `workspace` | Yes | GID string | From `ASANA_GET_MULTIPLE_WORKSPACES` |
| `projects` | Recommended | Array of GID strings | From `ASANA_GET_MULTIPLE_PROJECTS` |
| `assignee` | No | GID string or `"me"` | Task assignee |
| `due_on` | No | `"YYYY-MM-DD"` | Due date (no time) |
| `due_at` | No | ISO 8601 | Due datetime (mutually exclusive with `due_on`) |
| `notes` | No | String | Task description (plain text) |

**Pass GIDs as plain strings:** `"1234567890"`, not `{"gid": "1234567890"}`.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Tool X not found" | Wrong tool name | Call `get_connection_tools` once to see exact names |
| "You do not have access to this workspace" | Wrong workspace GID | Call `ASANA_GET_MULTIPLE_WORKSPACES` and use a GID from the response |
| "You do not have access to this projects" | Wrong project GID | Call `ASANA_GET_MULTIPLE_PROJECTS` with correct workspace GID |
| "Not a recognized ID" | Fabricated or stale GID | Always extract GIDs from tool responses in this conversation |
| "Not a valid GID type: 'object'" | Passed object instead of string | Pass GID as plain string, not as an object |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Guess tool name `asana_create_task` | Use exact name `ASANA_CREATE_A_TASK` |
| Create task with invented workspace GID | Call `ASANA_GET_MULTIPLE_WORKSPACES` first |
| Create task with invented project GID | Call `ASANA_GET_MULTIPLE_PROJECTS` first |
| Re-fetch `get_connection_tools` every turn | Fetch once, reuse tool names for the conversation |
| Pass GID as object `{"gid": "..."}` | Pass as plain string `"1234567890"` |
| Try multiple GIDs hoping one works | Discover the correct GID via list tools |
| Re-discover workspace GID on every turn | Cache GIDs within the conversation |

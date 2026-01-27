---
name: folk-crm
description: Guides Folk CRM tool usage with correct routing for groups, people, and companies. Use when interacting with Folk CRM tools. Triggers include "folk", "group", "leads", "contacts", "CRM".
metadata:
  version: 1.1.0
  category: operations
  tags:
    - folk
    - crm
    - contacts
    - companies
    - groups
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Folk CRM Integration

## Quick Start: Querying a Group

When user asks about contacts in a group, pipeline, or filtered by status:

```
User: "Show leads in Demo Management with status Follow up 1"

Step 1: find_people_in_group("Demo Management", status="Follow up 1")

Done. One call.
```

Do NOT start with `find_person` or `browse_people` for group queries.

## Critical Rule: IDs Must Never Be Guessed

Folk uses opaque UUIDs (e.g., `per_00000000-0000-0000-0000-example00001`). Never fabricate or partially reconstruct an ID. Always get the exact ID from a search result before using it in subsequent calls.

If unsure of an ID, search again.

## Situational Handling

### Situation: User asks about a group, pipeline, view, or status

Trigger phrases: "in the X group", "leads with status Y", "show me the pipeline", "Demo Management", "follow-up list"

**Required action:** Use group tools directly.

```
Step 1: find_people_in_group(group_name, status=...)
```

If you don't know the group name, call `list_groups()` first.

If looking for companies in a group, use `find_companies_in_group` instead.

### Situation: User asks about a specific person by name

Trigger phrases: "find John Smith", "look up Sarah", "what's Alice's email"

**Required action:** Search, then optionally get details.

```
Step 1: find_person("John Smith")
Step 2 (only if full details needed): get_person_details(person_id)
```

Use `find_person` for existence checks. Only call `get_person_details` when the user needs complete information.

### Situation: User wants to act on a person (note, reminder, update)

**Required action:** Search first, then act with the exact ID.

```
Step 1: find_person("Sarah") → get ID
Step 2: add_note(person_id="per_...", content="...")
```

### Situation: User asks to create a contact

**Required action:** Search first to avoid duplicates, then create.

```
Step 1: find_person("New Name") → confirm no match
Step 2: add_person(first_name="New", last_name="Name", ...)
```

### Situation: User asks to delete or update

**Required action:** Always confirm with the user before proceeding.

### Situation: Multiple search matches

**Required action:** Ask the user to choose. Never assume.

```
find_person("John") returns 3 matches → list them, ask which one.
```

## Date Handling

All date/time parameters use ISO 8601: `2026-01-15T14:30:00Z`

When user says "tomorrow" or "next Tuesday", calculate the actual date.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Group not found" | Wrong group name | Check `available_groups` in response, or call `list_groups()` |
| "Person not found" | Spelling mismatch | Try partial name (first name only), ask user |
| "Invalid ID format" | Hallucinated or truncated ID | Search again, use exact ID from response |
| "Duplicate detected" | Person already exists | Confirm with user before creating |
| "Rate limited" | Too many requests | Wait, reduce batch size |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| `find_person` or `browse_people` then manually filter for group/status | `find_people_in_group` with status parameter |
| Fetching `get_person_details` on multiple people to find custom fields | `find_people_in_group` returns status and custom fields directly |
| Guessing or reconstructing an ID from memory | Always use the exact ID from a search result |
| Calling `get_person_details` just to check if someone exists | Use `find_person` (minimal payload) |
| Creating a person without searching first | Always `find_person` first to avoid duplicates |

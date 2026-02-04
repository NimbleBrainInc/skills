---
name: folk-crm
description: Guides Folk CRM tool usage with correct routing for groups, people, and companies. Use when interacting with Folk CRM tools. Triggers include "folk", "group", "leads", "contacts", "CRM".
metadata:
  version: 1.2.0
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

## ID Format

Folk IDs are a short prefix + UUID v4: `per_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

The `find_person` tool returns IDs in this exact format:

```json
{
  "found": true,
  "matches": [
    {"id": "per_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", "name": "Full Name", "email": "..."}
  ],
  "total": 1
}
```

You must copy the `id` value exactly from the search result. If you do not have an ID from a search result in the current conversation, call `find_person` or `find_company` again.

## Quick Start: Querying a Group

When user asks about contacts in a group, pipeline, or filtered by status:

```
User: "Show leads in Demo Management with status Follow up 1"

Step 1: find_people_in_group("Demo Management", status="Follow up 1")

Done. One call.
```

Do NOT start with `find_person` or `browse_people` for group queries.

## Situational Handling

### Situation: User asks about a group, pipeline, view, or status

Trigger phrases: "in the X group", "leads with status Y", "show me the pipeline", "Demo Management", "follow-up list"

**Required action:** Use group tools directly.

```
Step 1: find_people_in_group(group_name, status=...)
```

If you don't know the group name, call `list_groups()` first.

If looking for companies in a group, use `find_companies_in_group` instead.

### Situation: Quick lookup (email, phone, exists?)

Trigger phrases: "what's X's email", "find X", "do we have X"

**Required action:** Search only.

```
find_person("John Smith")
```

### Situation: Full profile ("tell me about X", "what do you know about X")

**Required action:** Search, details, and notes.

```
Step 1: find_person("Sarah") -> get person_id
Step 2: get_person_details(person_id)
Step 3: get_notes(person_id)
```

Notes contain interaction history. Always include when user wants the full picture.

### Situation: User wants to act on a person (note, reminder, update)

**Required action:** Search first, then act with the exact ID from the result.

```
Step 1: find_person("Sarah") -> get per_xxxxxxxx-xxxx-... ID from matches
Step 2: add_note(person_id=<exact ID from step 1>, content="...")
```

### Situation: User asks to set a reminder

**Required action:** Search, disambiguate if needed, then set reminder with exact ID.

```
Step 1: find_person("Eloi") -> get per_xxxxxxxx-xxxx-... ID from matches
Step 2: set_reminder(
    person_id=<exact ID from step 1>,
    reminder="Follow up on proposal",
    when="2026-01-28T09:00:00Z"
)
```

When the user says "tomorrow" or "next Tuesday", calculate the actual ISO 8601 datetime.

### Situation: User asks to create a contact

**Required action:** Search first to avoid duplicates, then create.

```
Step 1: find_person("New Name") -> confirm no match
Step 2: add_person(first_name="New", last_name="Name", ...)
```

### Situation: User asks to delete or update

**Required action:** Always confirm with the user before proceeding.

### Situation: Multiple search matches

**Required action:** Ask the user to choose. Never assume.

```
find_person("John") returns 3 matches -> list them, ask which one.
```

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Invalid person ID" | ID not in `prefix_uuid` format | Call `find_person` and use the exact ID from the result |
| "Group not found" | Wrong group name | Check `available_groups` in response, or call `list_groups()` |
| "Person not found" | Spelling mismatch | Try partial name (first name only), ask user |
| "Duplicate detected" | Person already exists | Confirm with user before creating |
| "Rate limited" | Too many requests | Wait, reduce batch size |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| `find_person` or `browse_people` then manually filter for group/status | `find_people_in_group` with status parameter |
| Fetching `get_person_details` on multiple people to find custom fields | `find_people_in_group` returns status and custom fields directly |
| Calling `get_person_details` just to check if someone exists | Use `find_person` (minimal payload) |
| Creating a person without searching first | Always `find_person` first to avoid duplicates |
| "Tell me about X" without calling `get_notes` | `get_person_details` + `get_notes` for full profile |

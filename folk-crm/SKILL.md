---
name: folk-crm
description: Connection skill for Folk CRM MCP server. Provides guidance on ID handling, tool selection, and error recovery for AI assistants interacting with Folk CRM.
metadata:
  version: 1.0.0
  category: connection-skill
  tags:
    - folk
    - crm
    - contacts
    - companies
    - mcp
  surfaces:
    - nimblebrain-studio
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Folk CRM Integration

This skill provides behavioral guidance for interacting with the Folk CRM MCP server.

## ID Handling (CRITICAL)

Folk uses opaque UUIDs for all entities. These IDs are **not memorable, not reconstructible, and must never be guessed**.

**ID Format Examples:**
- Person: `per_8475e434-0dd0-41e2-954a-d96b3bc6020e`
- Company: `com_3f2a1b9c-8d7e-4f6a-b5c4-1a2b3c4d5e6f`

### The Cardinal Rule

**NEVER fabricate, guess, or partially reconstruct an ID.**

Common mistake (DO NOT DO THIS):
```
find_person returns: per_8475e434-0dd0-41e2-954a-d96b3bc6020e
You use:             per_8475e434-5a4f-4ba8-8f5b-f6e3fd3d8dab  ← WRONG
```

The second half looks plausible but is hallucinated. This will fail silently or affect the wrong record.

### Required Workflow

1. **Search first** - Call `find_person("Name")` or `find_company("Name")`
2. **Extract the exact ID** - Copy the ID verbatim from the response
3. **Use immediately** - Pass that exact ID to subsequent operations
4. **Never cache mentally** - If unsure, search again

**Correct pattern:**
```
User: "Add a note to John Smith's profile"

Step 1: find_person("John Smith")
Response: {
  "found": true,
  "matches": [{"id": "per_8475e434-0dd0-41e2-954a-d96b3bc6020e", "name": "John Smith", "email": "john@example.com"}]
}

Step 2: add_note(person_id="per_8475e434-0dd0-41e2-954a-d96b3bc6020e", content="...")
```

### Disambiguation

When multiple matches are returned, **always confirm with the user** before proceeding:

```
find_person("John") returns 3 matches:
- John Smith (john@acme.com)
- John Doe (john.doe@example.com)
- Johnny Walker (johnny@drinks.com)

Ask: "I found 3 people named John. Which one did you mean?"
```

Never assume. The cost of affecting the wrong record is high.

## Tool Selection Guide

Folk tools are organized in tiers. Use the right tier for the task:

### Tier 1: Search (Start Here)
- `find_person(name)` - Find people by name
- `find_company(name)` - Find companies by name

**Always start with search.** These return minimal payloads (id, name, email) to save tokens.

### Tier 2: Details (After Finding)
- `get_person_details(person_id)` - Full person info
- `get_company_details(company_id)` - Full company info

Only call these when you need complete information. Don't fetch full details just to check if someone exists.

### Tier 3: Browse (Exploration)
- `browse_people(page, per_page)` - Paginated list
- `browse_companies(page, per_page)` - Paginated list

Use sparingly. Prefer search over browsing.

### Tier 4: Mutations (With Caution)
- `add_person(...)` - Create new person
- `add_company(...)` - Create new company
- `update_person(person_id, ...)` - Update existing
- `update_company(company_id, ...)` - Update existing
- `delete_person(person_id)` - Delete (confirm first!)
- `delete_company(company_id)` - Delete (confirm first!)

**Before creating:** Always search first to avoid duplicates.
**Before deleting:** Always confirm with user.

### Tier 5: Notes & Reminders
- `add_note(person_id, content)` - Add a note
- `get_notes(person_id)` - Retrieve notes
- `set_reminder(person_id, reminder, when)` - Set reminder
- `log_interaction(person_id, type, when)` - Log interaction

These require a valid person_id. Search first.

## Date Handling

All date/time parameters use ISO 8601 format:

- **Date only:** `2026-01-15`
- **Date and time:** `2026-01-15T14:30:00Z`
- **With timezone:** `2026-01-15T14:30:00-10:00`

When the user says "tomorrow" or "next week", calculate the actual date and use ISO format.

**Example:**
```
User: "Remind me to follow up with Sarah next Tuesday"

1. Calculate: next Tuesday = 2026-01-21
2. find_person("Sarah") → get ID
3. set_reminder(person_id="per_...", reminder="Follow up", when="2026-01-21")
```

## Error Recovery

### "Person not found"
- Check spelling in search query
- Try partial name (first name only)
- Ask user to clarify

### "Invalid ID format"
- You likely hallucinated or truncated the ID
- Search again and use the exact ID from response

### "Duplicate detected"
- Search returned existing match
- Confirm with user before creating duplicate

### "Rate limited"
- Wait a moment and retry
- Reduce batch size if doing bulk operations

## Best Practices

1. **Token efficiency** - Use find_* for existence checks, not get_*_details
2. **Confirm destructive actions** - Always ask before delete/update
3. **Handle ambiguity** - Multiple matches = ask user to choose
4. **Provide context** - When reporting results, include name and email for verification
5. **Chain thoughtfully** - Find → Confirm → Act, never skip steps

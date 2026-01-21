---
name: googlesheets
description: Connection skill for Google Sheets MCP integration. Provides guidance on spreadsheet ID extraction, tool chaining, and avoiding common hallucination patterns. Use when searching sheets, listing tables, or reading data.
metadata:
  version: 1.0.0
  category: data
  tags:
    - google-sheets
    - spreadsheets
    - data
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Google Sheets Integration

This skill provides behavioral guidance for interacting with Google Sheets via MCP tools.

## ID Handling (CRITICAL)

Google Sheets uses 44-character alphanumeric IDs. These IDs are **returned by search tools and must be extracted exactly**.

**ID Format Example:**
- Spreadsheet: `11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4`

### The Cardinal Rule

**NEVER use memorized or training-data IDs. ALWAYS extract from the actual tool response.**

The most common failure mode:
```
GOOGLESHEETS_SEARCH_SPREADSHEETS returns:
  {"id": "11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4", "name": "hubspot-crm-exports"}

You use: 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms  <- WRONG (Google's example spreadsheet)
```

The ID `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms` is Google's famous "Example Spreadsheet" from tutorials. It exists in training data but is NOT the user's spreadsheet.

### Required Workflow: Search Then Use

```
Step 1: GOOGLESHEETS_SEARCH_SPREADSHEETS(query="hubspot")
Response: {
  "spreadsheets": [
    {"id": "11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4", "name": "hubspot-crm-exports-2025-12-01"},
    {"id": "1H578KWaJSHyf4DpZr3YulBKTlNTXNffffkTSmNSqjG0", "name": "hubspot-crm-exports-2025-06-01"}
  ]
}

Step 2: Parse JSON, locate the "id" field for the desired sheet

Step 3: GOOGLESHEETS_LIST_TABLES(spreadsheet_id="11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4")
```

**The ID in step 3 MUST match the ID from step 1 exactly.**

## Tool Chaining Patterns

### Pattern: Find Sheet by Name, Then Access

```
User: "What's in the hubspot export sheet?"

1. GOOGLESHEETS_SEARCH_SPREADSHEETS(query="hubspot export")
2. Extract spreadsheet_id from response
3. GOOGLESHEETS_LIST_TABLES(spreadsheet_id=<extracted_id>)
4. GOOGLESHEETS_GET_TABLE_DATA(spreadsheet_id=<extracted_id>, range=<table_range>)
```

### Pattern: User Provides URL

If user provides a Google Sheets URL, extract the ID from between `/d/` and `/edit`:

```
URL: https://docs.google.com/spreadsheets/d/11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4/edit
ID:  11t2duqAVMcA2rfVaGf94QWx_OBcz1vaN6i1fUXqC-q4
```

### Pattern: Disambiguation

When search returns multiple matches, confirm with user:

```
GOOGLESHEETS_SEARCH_SPREADSHEETS("report") returns 3 sheets:
- "Q4 Sales Report" (modified Dec 15)
- "Annual Report 2025" (modified Jan 10)
- "Bug Report Tracker" (modified Jan 18)

Ask: "I found 3 sheets matching 'report'. Which one?"
```

Never assume. Different sheets may have similar names.

## Tool Reference

### Search & Discovery

| Tool | Purpose | Key Parameter |
|------|---------|---------------|
| `GOOGLESHEETS_SEARCH_SPREADSHEETS` | Find sheets by name | `query` |
| `GOOGLESHEETS_LIST_TABLES` | Get sheets/ranges in a spreadsheet | `spreadsheet_id` |

### Data Operations

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `GOOGLESHEETS_GET_TABLE_DATA` | Read cell data | `spreadsheet_id`, `range` |
| `GOOGLESHEETS_BATCH_UPDATE` | Write/update cells | `spreadsheet_id`, `data` |
| `GOOGLESHEETS_CREATE_SPREADSHEET` | Create new sheet | `title` |

### Range Format

Ranges use A1 notation:
- Single cell: `Sheet1!A1`
- Range: `Sheet1!A1:D10`
- Full column: `Sheet1!A:A`
- Full row: `Sheet1!1:1`

Sheet names with spaces require quotes: `'My Sheet'!A1:B10`

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Spreadsheet not found" | Wrong ID used | Search again, extract exact ID from response |
| "Invalid spreadsheet_id" | Hallucinated/memorized ID | Never guess IDs, always extract from search |
| "Range not found" | Sheet name mismatch | Use LIST_TABLES first to see actual sheet names |
| "Permission denied" | User doesn't have access | Verify the sheet is shared with user's account |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Use a memorized spreadsheet ID | Extract ID from search response |
| Guess the ID format | Parse the actual JSON response |
| Assume sheet names | Call LIST_TABLES to discover sheets |
| Skip search when user says sheet name | Always search first, names can be partial matches |
| Use "Example Spreadsheet" ID | That's Google's demo, not user data |

## ID Extraction Checklist

Before calling any tool that requires `spreadsheet_id`:

1. [ ] Did I just call SEARCH_SPREADSHEETS?
2. [ ] Did I parse the JSON response?
3. [ ] Did I extract the exact `id` field value?
4. [ ] Am I using that exact string (not a similar-looking one)?
5. [ ] Is this ID from THIS conversation (not memorized)?

If any answer is "no", search first.

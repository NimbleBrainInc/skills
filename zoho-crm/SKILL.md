---
name: zoho-crm
description: Guides Zoho CRM tool usage with correct module routing for leads, contacts, deals, and tasks. Use when interacting with Zoho CRM tools. Triggers include "zoho", "leads", "contacts", "deals", "tasks", "overdue", "CRM".
metadata:
  version: 1.0.0
  category: operations
  tags:
    - zoho
    - crm
    - leads
    - contacts
    - deals
    - tasks
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Zoho CRM Integration

## Critical: Tasks Are a Separate Module

Zoho CRM has **separate modules** for different record types:

| Module | Purpose | Key Fields |
|--------|---------|------------|
| Leads | Unqualified prospects | Lead_Status, Email, Phone |
| Contacts | Qualified individuals | Account_Name, Email, Phone |
| Deals | Sales opportunities | Stage, Amount, Closing_Date |
| Accounts | Companies/organizations | Account_Name, Industry |
| **Tasks** | Action items with due dates | Subject, Due_Date, Status, Priority |

**Tasks are NOT fields on Leads.** They are standalone records that can be associated with Leads, Contacts, Deals, or Accounts via the `What_Id` field.

## Quick Start: Finding Overdue Tasks

When user asks about "overdue" items, they almost always mean **Tasks**:

```
User: "What are the overdue tasks?" or "What leads are overdue?"

Step 1: ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Due_Date:less_than:TODAY)")
```

Done. One call to the Tasks module with a date filter.

## Situational Handling

### Situation: User asks about "overdue" anything

Trigger phrases: "overdue tasks", "overdue leads", "what's past due", "follow-ups due", "what do I need to do"

**Required action:** Query the Tasks module, NOT Leads.

```
ZOHOCRM_SEARCH_RECORDS(
  module="Tasks",
  criteria="(Due_Date:less_than:TODAY)"
)
```

Optional filters:
- By status: `(Due_Date:less_than:TODAY)and(Status:equals:Not Started)`
- By priority: `(Due_Date:less_than:TODAY)and(Priority:equals:Highest)`

### Situation: User asks about leads/contacts/deals

Trigger phrases: "show me leads", "list contacts", "what deals are closing"

**Required action:** Query the appropriate module directly.

```
# List leads
ZOHOCRM_SEARCH_RECORDS(module="Leads")

# Leads by status
ZOHOCRM_SEARCH_RECORDS(module="Leads", criteria="(Lead_Status:equals:Contacted)")

# Deals closing this month
ZOHOCRM_SEARCH_RECORDS(module="Deals", criteria="(Closing_Date:between:2026-02-01,2026-02-28)")
```

### Situation: User asks to create a task

**Required action:** Use the Tasks module with required fields.

```
ZOHOCRM_CREATE_RECORD(
  module="Tasks",
  data={
    "Subject": "Follow up with lead",
    "Due_Date": "2026-02-10",
    "Status": "Not Started",
    "Priority": "High"
  }
)
```

To associate with a Lead/Contact/Deal, include `What_Id`:
```
data={
  "Subject": "Follow up",
  "Due_Date": "2026-02-10",
  "What_Id": "7170963000000598816"  # Lead/Contact/Deal ID
}
```

### Situation: User asks about a specific lead's tasks

**Required action:** Search Tasks filtered by the associated record.

```
Step 1: Find the Lead ID (if not known)
ZOHOCRM_SEARCH_RECORDS(module="Leads", criteria="(Full_Name:contains:John)")

Step 2: Search Tasks associated with that Lead
ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(What_Id:equals:<lead_id>)")
```

### Situation: User asks to update a task

**Required action:** Get task ID first, then update.

```
Step 1: ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Subject:contains:follow up)")
Step 2: ZOHOCRM_UPDATE_RECORD(module="Tasks", id=<task_id>, data={"Status": "Completed"})
```

## Module Field Reference

### Tasks Module

| Field | Type | Values |
|-------|------|--------|
| Subject | String | Task title |
| Due_Date | Date | YYYY-MM-DD format |
| Status | Picklist | Not Started, Deferred, In Progress, Completed, Waiting for input |
| Priority | Picklist | Highest, High, Normal, Low, Lowest |
| What_Id | Lookup | Associated record ID (Lead, Contact, Deal) |
| Owner | Lookup | Assigned user |

### Leads Module

| Field | Type | Values |
|-------|------|--------|
| First_Name | String | |
| Last_Name | String | |
| Full_Name | String | Auto-generated |
| Email | Email | |
| Lead_Status | Picklist | Not Contacted, Contacted, Working, Qualified, etc. |
| Lead_Source | Picklist | Advertisement, Web, Referral, etc. |

## Criteria Syntax

Zoho uses COQL-style criteria:

```
(Field_Name:operator:value)
(Field1:equals:value1)and(Field2:contains:value2)
(Field1:equals:value1)or(Field2:equals:value2)
```

| Operator | Usage | Example |
|----------|-------|---------|
| equals | Exact match | `(Status:equals:Completed)` |
| contains | Partial match | `(Subject:contains:follow)` |
| starts_with | Prefix match | `(Full_Name:starts_with:John)` |
| less_than | Date/number comparison | `(Due_Date:less_than:2026-02-01)` |
| greater_than | Date/number comparison | `(Amount:greater_than:10000)` |
| between | Range | `(Due_Date:between:2026-02-01,2026-02-28)` |

**Special value:** `TODAY` - use for current date comparisons.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Module not found" | Wrong module name | Use exact names: Leads, Contacts, Deals, Accounts, Tasks |
| "Invalid criteria" | Malformed COQL | Check parentheses and operator syntax |
| "Field not found" | Wrong field name | Use API names (Full_Name, not "Full Name") |
| "No records found" | Query too restrictive | Broaden criteria, check spelling |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Search Leads for "overdue" items | Search Tasks module with Due_Date filter |
| Look for "Next_Action" field on Leads | Tasks are a separate module, not a field |
| Ask user for field names | Check available fields via ZOHOCRM_GET_FIELDS |
| Assume Tasks are part of Leads | Tasks are standalone records linked via What_Id |
| Use date strings like "today" | Use literal dates (2026-02-05) or TODAY keyword |

## Common Queries

```
# All overdue tasks
ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Due_Date:less_than:TODAY)")

# Overdue tasks not completed
ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Due_Date:less_than:TODAY)and(Status:not_equal:Completed)")

# High priority tasks
ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Priority:equals:High)")

# Tasks due this week
ZOHOCRM_SEARCH_RECORDS(module="Tasks", criteria="(Due_Date:between:2026-02-03,2026-02-09)")

# All leads with status "Contacted"
ZOHOCRM_SEARCH_RECORDS(module="Leads", criteria="(Lead_Status:equals:Contacted)")

# Deals closing this month
ZOHOCRM_SEARCH_RECORDS(module="Deals", criteria="(Closing_Date:between:2026-02-01,2026-02-28)")
```

# Phase 1: API Analysis

Fetch and analyze the target service's API documentation, identify resources and operations, and propose a tool set for the contributor to approve.

## 1a: Fetch and Analyze

1. **Fetch and analyze** the API documentation (use WebFetch)
2. **Identify**:
   - Authentication method (Bearer token, API key, OAuth)
   - Base URL for API calls
   - Available resources and CRUD operations
   - Pagination patterns
   - Response schemas

3. **Check for OpenAPI/Swagger spec** at common paths:
   - `/openapi.json`, `/swagger.json`, `/api/openapi.json`

## 1b: Propose Tools

Present summary to user for approval:
```
=> Analyzing [Service] API...
   Base URL: https://api.example.com/v1
   Auth: Bearer token
   Resources found: [list]

=> Proposed tools ([count]):
   [Resource]: list_X, get_X, create_X, update_X
   ...

=> Proceed? [Y/n]
```

## Gate

**Criteria:**
- [ ] API documentation fetched and analyzed
- [ ] Authentication method, base URL, resources, and schemas identified
- [ ] Proposed tool list presented to contributor
- [ ] Contributor has approved the tool set

**If any criterion fails:** Revisit analysis or adjust proposed tools per contributor feedback.

**When all pass:** Proceed to Phase 2.

---
name: docs-auditor
description: Systematically audit documentation against actual codebase to determine accuracy, staleness, and relevance. Use when auditing docs for accuracy, cleaning up stale docs after refactoring, validating docs match implementation, or building documentation health reports.
metadata:
  version: 1.0.7
  category: development
  tags:
    - documentation
    - audit
    - code-quality
    - maintenance
    - accuracy
  triggers:
    - audit the docs
    - check if docs are stale
    - validate documentation
    - docs match implementation
    - documentation health report
    - find outdated docs
  surfaces:
    - claude-code
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Documentation Auditor

Systematically audit documentation against the actual codebase to determine accuracy, staleness, and relevance.

## When to Use This Skill

Invoke this skill when:
- Auditing documentation for accuracy
- Cleaning up stale docs after refactoring
- Validating that docs match implementation
- Building a documentation health report

## Methodology

### Phase 1: Document Classification

For each document, determine its **type**:

| Type | Description | Validation Approach |
|------|-------------|---------------------|
| **Architecture** | System design, module structure | Cross-reference with actual directory structure and imports |
| **API Reference** | Endpoints, schemas, contracts | Check against route files and schema definitions |
| **Implementation Guide** | How to do X | Verify code patterns still exist |
| **Feature Spec** | What a feature does | Check if feature exists and behaves as described |
| **Migration/Plan** | One-time work | Check if work is complete (then archive or delete) |
| **Concept/Philosophy** | Design principles | Usually still valid unless product direction changed |

### Phase 2: Extract Verifiable Claims

Read the document and extract **verifiable claims**:

```
CLAIM: "Files are organized in src/services/"
VERIFICATION: Check if path exists
RESULT: TRUE/FALSE

CLAIM: "Use AuthService for authentication"
VERIFICATION: Check if class exists and is used
RESULT: TRUE/FALSE

CLAIM: "Data isolation is enforced via tenant_id"
VERIFICATION: Check entity definitions and access patterns
RESULT: TRUE/FALSE
```

### Phase 3: Code Cross-Reference

For each claim, determine what code to check:

| Claim Type | What to Check |
|------------|---------------|
| Directory structure | `ls`, `find` commands |
| Class/function exists | `Grep` for definition |
| Import patterns | `Grep` for import statements |
| API endpoints | Check route files |
| Database schema | Check entity/model files |
| Configuration | Check config files |

### Phase 4: Accuracy Assessment

Rate each document:

| Rating | Meaning | Action |
|--------|---------|--------|
| **ACCURATE** | All claims verified | Keep as-is |
| **MOSTLY_ACCURATE** | Minor discrepancies | Update specific sections |
| **OUTDATED** | Major claims false | Rewrite or delete |
| **OBSOLETE** | Describes removed features | Delete or archive |
| **ASPIRATIONAL** | Describes future state | Keep but label as "Target" |

## Output Format

For each document audited, produce:

```markdown
## [Document Name]

**Path:** `docs/path/to/file.md`
**Type:** Architecture | API | Guide | Spec | Migration | Concept
**Rating:** ACCURATE | MOSTLY_ACCURATE | OUTDATED | OBSOLETE | ASPIRATIONAL

### Verifiable Claims

| Claim | Verification | Result |
|-------|--------------|--------|
| [claim 1] | [how checked] | TRUE/FALSE |
| [claim 2] | [how checked] | TRUE/FALSE |

### Accuracy Score
X/Y claims verified (Z%)

### Recommendation
- **Action:** KEEP | UPDATE | DELETE | ARCHIVE | MARK_AS_TARGET
- **Reason:** [1-2 sentences]
- **If UPDATE, changes needed:**
  - [ ] Change X to Y
  - [ ] Remove section Z
  - [ ] Add missing info about W
```

## Staleness Signals

Watch for these indicators of stale docs:

### High-Confidence Staleness
- References deleted files/directories
- References renamed classes/functions
- Describes deprecated features
- Migration plan for completed work

### Medium-Confidence Staleness
- Old dates (>6 months) with no updates
- References "TODO" or "Phase 2" without completion
- Diagrams that don't match code structure

### Low-Confidence Staleness
- Generic descriptions that might still apply
- Conceptual content without specific code references

## Audit Workflow

### Single Document Audit

```
1. Read the document fully
2. Classify by type
3. Extract 5-10 verifiable claims
4. For each claim:
   a. Determine verification method
   b. Execute verification (read code, check paths)
   c. Record result
5. Calculate accuracy score
6. Determine rating and recommendation
7. Output structured report
```

### Batch Audit (Directory)

```
1. List all documents in directory
2. Quick-scan each (first 50 lines)
3. Prioritize by likely staleness (dates, keywords)
4. Full audit highest-priority first
5. Group results by recommendation
6. Produce summary report
```

## Common Directories to Cross-Reference

Adapt these to the project structure:

```
src/                    # Source code root
src/services/           # Service implementations
src/routes/ or src/api/ # API endpoints
src/models/ or src/db/  # Database schema
src/config/             # Configuration
tests/                  # Test files
```

## Example Audit

### Input Document: `docs/AUTHENTICATION.md`

**Quick Scan:**
- Title mentions "Authentication System"
- References JWT tokens and session management
- Last updated 8 months ago

**Verifiable Claims:**
1. "AuthService class handles all authentication" -> Grep for AuthService
2. "Sessions stored in Redis" -> Check config and imports
3. "JWT tokens expire after 24 hours" -> Check token configuration

**Results:**
1. TRUE - AuthService exists at src/services/auth.ts
2. FALSE - Sessions now stored in database, Redis removed
3. TRUE - Token expiry configured as 24h

**Rating:** MOSTLY_ACCURATE (2/3 claims valid)
**Action:** UPDATE
**Changes needed:**
- [ ] Update session storage section (Redis -> Database)
- [ ] Add note about migration date

## Self-Improvement

After each audit session, identify:
1. **New staleness signals** discovered
2. **False positives** (docs flagged stale but actually valid)
3. **Missed staleness** (docs marked valid but actually stale)

Use these patterns to improve future audits.


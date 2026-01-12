---
name: qa-tester
description: Comprehensive QA engineer that designs test strategies, writes test cases, identifies edge cases, and validates implementations. Use when writing tests, reviewing test coverage, planning QA strategy, identifying edge cases, or validating feature implementations. Triggers include "write tests for", "test this feature", "what are the edge cases", "review test coverage", or "QA this".

metadata:
  version: 1.0.0
  category: testing
  tags:
    - testing
    - qa
    - quality
    - edge-cases
  triggers:
    - "write tests for"
    - "test this feature"
    - "what are the edge cases"
    - "review test coverage"
    - "QA this"
  author:
    name: NimbleBrain
    url: https://github.com/NimbleBrainInc
---

# QA Tester

Design comprehensive test strategies, identify edge cases, and write effective tests. Think like a QA engineer whose job is to break things before users do.

## Quick Start

When asked to test a feature, immediately produce:

```markdown
## Test Plan: [Feature]

### Happy Path
1. [Primary use case test]

### Edge Cases
1. [Boundary condition]
2. [Null/empty input]
3. [Concurrent access]

### Error Cases
1. [Expected failure mode]
```

## Core Mindset

**Assume the code is broken.** Your job is to prove it. Every feature has bugs. Find them.

**Think adversarially.** What would a malicious user do? What would a confused user do? What happens at 3 AM when the database is slow?

**Edge cases are not edge cases.** They're where bugs live. The happy path usually works. The edges don't.

## Test Strategy Framework

### Phase 1: Understand the Feature

Before writing tests, answer:
- What is this feature supposed to do?
- Who uses it and how?
- What are the inputs and outputs?
- What are the dependencies?
- What can go wrong?

### Phase 2: Identify Test Categories

**Functional Tests**
- Does the feature work as specified?
- Do all user flows complete successfully?
- Are outputs correct for given inputs?

**Boundary Tests**
- What happens at minimum values?
- What happens at maximum values?
- What happens just outside valid ranges?

**Error Handling Tests**
- Does invalid input produce clear errors?
- Are errors recoverable?
- Do errors leak sensitive information?

**Integration Tests**
- Does it work with dependent services?
- What happens when dependencies fail?
- Are race conditions possible?

**Performance Tests**
- How does it perform under load?
- Are there memory leaks?
- What are the response time characteristics?

### Phase 3: Edge Case Identification

#### Universal Edge Cases (Always Check)

**Null/Empty/Missing**
```
- null input
- undefined input
- empty string ""
- empty array []
- empty object {}
- whitespace-only string "   "
- missing required fields
```

**Boundary Values**
```
- 0
- -1
- 1
- MAX_INT / MIN_INT
- MAX_SAFE_INTEGER (JS)
- Empty and single-element collections
- Exactly at limit (e.g., 100 items when limit is 100)
- One over limit (101 items)
```

**String Edge Cases**
```
- Very long strings (10K+ characters)
- Unicode characters (emoji, RTL text, combining characters)
- Special characters (<>&"'\;)
- SQL injection attempts (' OR '1'='1)
- XSS attempts (<script>alert('xss')</script>)
- Newlines and tabs in unexpected places
- Leading/trailing whitespace
```

**Numeric Edge Cases**
```
- Floating point precision (0.1 + 0.2)
- Negative numbers where positive expected
- Very large numbers
- Very small decimals
- NaN and Infinity
- Scientific notation (1e10)
```

**Date/Time Edge Cases**
```
- Leap years (Feb 29)
- DST transitions
- Timezone boundaries
- Unix epoch (1970-01-01)
- Year 2038 problem
- Far future dates
- Invalid dates (Feb 30)
```

**Collection Edge Cases**
```
- Empty collection
- Single item
- Duplicate items
- Very large collections (1M+ items)
- Deeply nested structures
- Circular references
```

#### Domain-Specific Edge Cases

**Authentication/Authorization**
```
- Expired tokens
- Invalid tokens
- Missing tokens
- Tokens for deleted users
- Concurrent session limits
- Permission boundaries
- Role changes mid-session
```

**File Operations**
```
- Zero-byte files
- Very large files (>2GB)
- Corrupted files
- Missing files
- Permission denied
- Disk full
- Filename with special characters
```

**Network Operations**
```
- Timeout
- Connection refused
- DNS failure
- Partial response
- Slow response (>30s)
- SSL/TLS errors
- Redirect loops
```

**Concurrency**
```
- Simultaneous requests
- Race conditions
- Deadlocks
- Data consistency
- Optimistic locking failures
- Retry storms
```

**State Management**
```
- Stale state
- Inconsistent state
- State corruption
- Recovery after crash
- Partial updates
```

### Phase 4: Test Case Design

#### Test Case Template

```markdown
### TC-[ID]: [Title]

**Preconditions:**
- [State that must exist before test]

**Steps:**
1. [Action]
2. [Action]
3. [Action]

**Expected Result:**
- [What should happen]

**Actual Result:**
- [Fill in during execution]

**Pass/Fail:** [P/F]
```

#### Equivalence Partitioning

Divide inputs into classes where all values should behave the same:

```
Input: Age (0-120)
Partitions:
- Invalid: < 0 (test: -1)
- Valid: 0-120 (test: 25)
- Invalid: > 120 (test: 121)
```

Test one representative from each partition.

#### Boundary Value Analysis

Test at and around boundaries:

```
Valid range: 1-100
Test: 0, 1, 2, 50, 99, 100, 101
```

### Phase 5: Test Implementation

#### Unit Test Structure (AAA Pattern)

```typescript
describe('FeatureName', () => {
  describe('methodName', () => {
    it('should [expected behavior] when [condition]', () => {
      // Arrange
      const input = setupTestData();

      // Act
      const result = feature.method(input);

      // Assert
      expect(result).toBe(expectedValue);
    });
  });
});
```

#### Test Naming Convention

```
[Unit]_[Scenario]_[ExpectedBehavior]

Examples:
- createUser_withValidData_returnsUserId
- createUser_withDuplicateEmail_throwsConflictError
- createUser_withMissingName_returnsValidationError
```

## Output Formats

### Test Plan Document

```markdown
# Test Plan: [Feature Name]

## Overview
[Brief description of what's being tested]

## Scope
- **In Scope:** [What will be tested]
- **Out of Scope:** [What won't be tested]

## Test Environment
- [Environment requirements]

## Test Data Requirements
- [Data needed for testing]

---

## Test Cases

### Happy Path Tests

| ID | Description | Priority |
|----|-------------|----------|
| HP-01 | [Description] | High |
| HP-02 | [Description] | High |

### Edge Case Tests

| ID | Description | Edge Case Type | Priority |
|----|-------------|----------------|----------|
| EC-01 | [Description] | Boundary | High |
| EC-02 | [Description] | Null input | Medium |

### Error Handling Tests

| ID | Description | Expected Error | Priority |
|----|-------------|----------------|----------|
| EH-01 | [Description] | [Error type] | High |

### Integration Tests

| ID | Description | Dependencies | Priority |
|----|-------------|--------------|----------|
| IT-01 | [Description] | [Services] | High |

---

## Coverage Analysis

### Covered Scenarios
- [x] Primary happy path
- [x] Input validation
- [x] Error handling
- [x] Boundary conditions

### Not Covered (Risk Accepted)
- [ ] [Scenario] - Reason: [why not testing]

---

## Risks
- [Risk and mitigation]
```

### Quick Edge Case List

```markdown
## Edge Cases: [Feature]

### Must Test (Critical)
- [ ] Empty input
- [ ] Maximum length input
- [ ] Unauthorized access attempt
- [ ] [Domain-specific critical case]

### Should Test (Important)
- [ ] Special characters in input
- [ ] Concurrent requests
- [ ] [Domain-specific important case]

### Could Test (Nice to Have)
- [ ] Performance under load
- [ ] [Edge case with low probability]
```

## Anti-Patterns

**Don't:**
- Test only the happy path
- Write tests that pass with any implementation
- Test implementation details instead of behavior
- Skip error case testing
- Assume inputs will be valid
- Write flaky tests that sometimes fail
- Test trivial getters/setters

**Do:**
- Test behaviors, not implementations
- Make tests deterministic
- Test error messages and codes
- Consider security implications
- Think about concurrent access
- Document why each test exists
- Keep tests independent

## Integration with Codebase

When writing tests:
1. Check existing test patterns in the codebase
2. Follow established naming conventions
3. Use existing test utilities and fixtures
4. Respect the test directory structure
5. Run existing tests to ensure no regression

## Test Quality Checklist

Before considering tests complete:

```
[ ] Happy path covered
[ ] All input validation tested
[ ] Null/empty cases handled
[ ] Boundary values tested
[ ] Error cases return proper messages
[ ] No flaky tests
[ ] Tests are independent
[ ] Tests document expected behavior
[ ] Edge cases identified and tested
[ ] Security considerations addressed
```

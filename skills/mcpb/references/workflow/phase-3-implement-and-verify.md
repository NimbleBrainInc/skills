# Phase 3: Implement & Verify

Write tool logic, models, and client code, then run all checks to ensure the implementation is correct before bundling.

## Concept Mapping

See `references/CONVENTIONS-{lang}.md` → "Concept Mapping" for language-specific patterns.

## Implementation

Implement in the order specified in `references/PATTERNS-{lang}.md` → "Implementation Order".
See `references/PATTERNS-{lang}.md` for complete code examples.

For manifest and server.json fields, see `references/CONVENTIONS-{lang}.md`.

## Verify

Run all checks and fix any issues before proceeding. See `references/PATTERNS-{lang}.md`
→ "Build & Test Commands" for the full command set.

```bash
make check
```

**Python only:** Also run `make test-integration` (needs `<NAME>_API_KEY`) and `make test-llm`
(needs `ANTHROPIC_API_KEY`). Three test layers — see `references/PATTERNS-{lang}.md`
→ "Test Patterns" for complete examples. At minimum, `make check` must pass.

## Gate

**Criteria:**
- [ ] All tool logic, models, and client code implemented
- [ ] Linting passes with no errors
- [ ] Type checking passes with no errors
- [ ] Unit tests pass (`make check`)

**If any criterion fails:** Fix the reported issues and re-run checks.

**When all pass:** Proceed to Phase 4.

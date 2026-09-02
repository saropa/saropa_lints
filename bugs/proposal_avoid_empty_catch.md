# PROPOSAL: Flag Empty `catch` Blocks That Silently Swallow Errors

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_empty_catch` to flag `catch` blocks whose body is empty (no statements) — an empty catch silently discards the exception with no logging, rethrow, or fallback handling, making failures invisible and debugging the eventual downstream symptom far harder than it needs to be.

**Closes gap:** many_lints `avoid_empty_catch`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

An empty `catch {}` block is one of the most common ways a real bug goes unnoticed for months: an operation fails, nothing is logged, nothing is reported, and the caller proceeds as if the operation succeeded. It is almost always a debugging leftover ("let me just not crash here for now") that was never revisited.

---

## Detection / Behavior

Flag any `CatchClause` whose block body contains zero statements.

### Should flag (bad code)

```dart
try {
  await _saveDraft();
} catch (e) {
  // LINT — exception silently discarded, no logging, no rethrow
}
```

### Should pass (good code)

```dart
try {
  await _saveDraft();
} catch (e, stackTrace) {
  logger.error('Failed to save draft', error: e, stackTrace: stackTrace); // OK
}
```

---

## Proposed Tier

Tier: Essential
Justification: Silently swallowed exceptions are a correctness/observability defect with no legitimate justification in production code; this belongs alongside saropa's other error-handling essentials.

---

## Edge Cases

1. **`catch (_) {}` immediately followed by a comment explaining the deliberate no-op (e.g. "intentionally ignored: best-effort cache warm")** — needs discussion; consider allowing a documented exception via a comment-detection heuristic, or require `// ignore:` with justification per project convention rather than special-casing comments in the rule itself.
2. **`on SpecificException catch (e) {}`** — should flag same as bare `catch`; narrowing the type does not excuse silence.
3. **`catch (e) { /* rethrow below via finally */ }` where a sibling `finally` block does the real work** — should flag; the catch body itself is still empty and the intent is unclear from the catch alone.
4. **Empty catch block with only a `// TODO: handle this` comment** — should still flag; a TODO is not handling.

---

## Alternatives Considered

- **Require catch blocks to always log or rethrow** — rejected as the rule's exact mechanism; flagging emptiness alone is simpler and covers the overwhelming majority of real cases without needing to recognize what counts as "sufficient" handling.

---

## Decision

---

## Implementation Notes

---

## Commits

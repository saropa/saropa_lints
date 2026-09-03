# PROPOSAL: Require a Blank Line Before a Trailing `return` in a Multi-Statement Block

**Status: Duplicate** — already exists as `prefer_blank_line_before_return` (alias `newline_before_return`) in `formatting_rules.dart`

Created: 2026-09-02
Type: New rule
Related rules: `newline_before_case`, `newline_before_constructor`, `newline_before_method`, `no_blank_line_before_single_return`

---

## Summary

Add `newline_before_return` to flag a `return` statement that immediately follows a preceding statement with no blank line, when the block contains more than one statement before the `return`. The blank line visually marks "everything above was setup, this is the result".

**Closes gap:** `awesome_lints` `newline_before_return` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

In a function body with several lines of setup logic, the `return` statement is the single most important line — it's the answer the reader is looking for. Without a blank line separating it from the setup code, the eye has to parse every statement in sequence to find where the setup ends and the result begins.

---

## Detection / Behavior

### Should flag (bad code)

```dart
int computeTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total; // LINT — no blank line before the return
}
```

### Should pass (good code)

```dart
int computeTotal(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }

  return total; // OK — blank line separates setup from the result
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure whitespace/formatting preference with zero behavioral impact; overlaps by design with `no_blank_line_before_single_return`, which governs the opposite case (single-statement blocks).

---

## Edge Cases

1. **`return` is the only statement in the block** — should pass; this case is governed by `no_blank_line_before_single_return` instead, which forbids a blank line there.
2. **Early-return guard clauses (`if (x == null) return;`)** — should pass; guard-clause returns immediately following their own `if` are a distinct idiom, not a "final result" return.
3. **`return` inside a `switch` case body** — should follow the same rule as any other block; needs discussion on whether case bodies are exempt given `newline_before_case` already governs spacing there.
4. **Arrow function bodies (`=>`)** — should pass; no block statement exists to insert a blank line into.

---

## Alternatives Considered

- **Merge this rule and `no_blank_line_before_single_return` into one rule with a single/multi-statement branch** — considered; kept separate to match the two independent upstream rule names being ported and to allow independent enable/disable.

---

## Decision

---

## Implementation Notes

---

## Commits

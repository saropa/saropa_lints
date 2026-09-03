# PROPOSAL: Flag an Unnecessary Blank Line Before a Lone `return`

**Status: Duplicate** — already exists as `prefer_no_blank_line_before_return` in `stylistic_whitespace_constructor_rules.dart`

Created: 2026-09-02
Type: New rule
Related rules: `newline_before_return`

---

## Summary

Add `no_blank_line_before_single_return` to flag a blank line immediately before a `return` statement when that `return` is the only statement in its block (function body, `if` branch, etc.). When there is no setup logic to separate from, the blank line adds vertical space without adding meaning.

**Closes gap:** `dart_code_linter` `no_blank_line_before_single_return` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`newline_before_return`-style rules push toward a habit of always inserting a blank line before `return`, but applied blindly it produces the opposite of the intended effect on trivial one-liner functions: a single-statement body padded with a leading blank line reads as unfinished or accidentally double-spaced. This rule targets exactly the degenerate case that a blanket "always blank-line before return" habit gets wrong.

---

## Detection / Behavior

### Should flag (bad code)

```dart
bool isEven(int value) {

  return value % 2 == 0; // LINT — blank line before the only statement in the block
}
```

### Should pass (good code)

```dart
bool isEven(int value) {
  return value % 2 == 0; // OK — no blank line needed, nothing to separate from
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure whitespace/formatting preference with zero behavioral impact.

---

## Edge Cases

1. **Block opens with a DartDoc or inline comment above the `return`, then a blank line** — needs discussion; the comment may count as a second "statement" for spacing purposes.
2. **`return` is the sole statement in an `if` branch nested inside a larger multi-statement function** — should flag the same way; scope is the immediate block, not the whole function.
3. **Arrow function bodies (`=>`)** — should pass; no block statement exists.
4. **Block contains only a `return` plus trailing comments after it** — should still flag the leading blank line; trailing content doesn't change the "single statement" classification.

---

## Alternatives Considered

- **Fold into `newline_before_return` as a negative case** — rejected; kept as an independent rule to match the separate upstream rule name and allow independent enable/disable per team preference.

---

## Decision

---

## Implementation Notes

---

## Commits

# PROPOSAL: Require a Blank Line Before Each `case` Clause

**Status: Duplicate** — already exists as `prefer_blank_line_before_case` (alias `newline_before_case`) in `formatting_rules.dart`

Created: 2026-09-02
Type: New rule
Related rules: `newline_before_constructor`, `newline_before_method`, `newline_before_return`

---

## Summary

Add `newline_before_case` to flag a `case` clause in a `switch` statement/expression that immediately follows the previous case's body with no blank line separating them, when the previous case's body has more than a trivial single statement.

**Closes gap:** `awesome_lints` `newline_before_case` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Long `switch` statements read as a wall of code when each case's body butts directly against the next `case` keyword — there's no visual anchor for where one branch ends and the next begins. A blank line between multi-statement case bodies gives the eye a resting point, the same way blank lines separate top-level members.

---

## Detection / Behavior

### Should flag (bad code)

```dart
switch (status) {
  case Status.loading:
    showSpinner();
    logEvent('loading');
  case Status.error: // LINT — no blank line before this case, previous case had multiple statements
    showError();
}
```

### Should pass (good code)

```dart
switch (status) {
  case Status.loading:
    showSpinner();
    logEvent('loading');

  case Status.error: // OK — blank line separates the cases
    showError();
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure whitespace/formatting preference with zero behavioral impact.

---

## Edge Cases

1. **Single-statement case bodies (`case Status.idle: return;`)** — should pass without a blank line; the rule only applies once a case body grows beyond a trivial one-liner.
2. **First `case` in the switch** — should pass; there is no previous case to separate from.
3. **Fall-through cases sharing one body (`case a: case b: doThing();`)** — should pass between the grouped labels; blank-line requirement applies only between distinct bodies.
4. **Switch expressions (Dart 3 pattern-matching arrows)** — needs discussion; arrow-bodied switch expressions are typically kept dense and may warrant exclusion.

---

## Alternatives Considered

- **Require blank lines unconditionally, even for single-statement cases** — rejected; would force blank lines into short, enum-like switches where the noise reduction argument doesn't apply.

---

## Decision

---

## Implementation Notes

---

## Commits

# PROPOSAL: Avoid Unnecessary Else After Control Flow

**Status: Open**

Created: 2026-09-02

**Closes gap:** `flutter_skill_lints` `avoid_unnecessary_else_after_control_flow` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags `else` blocks that follow an `if` body ending in `return`, `throw`, `break`, or `continue` — the else is dead structure since the if-body already exits.

## Detection / Behavior

```dart
// Bad
if (x == null) {
  return;
} else {
  doSomething();
}

// Good
if (x == null) return;
doSomething();
```

## Quick Fix

Remove the `else` keyword and unindent the else-body one level.

## Alternatives Considered

- Dart's built-in `unnecessary_null_checks` and the analyzer's early-return hints partially overlap but don't cover all four control-flow exits. This rule is a superset.

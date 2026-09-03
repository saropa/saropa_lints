# PROPOSAL: Class Member Ordering Rule

**Status: Open**

Created: 2026-09-02

**Closes gap:** `mvvm_linter` `class_order_rule` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Enforces a canonical ordering of class members: static fields, instance fields, constructors, static methods, instance methods, overrides. Reduces cognitive load when navigating unfamiliar classes.

## Detection / Behavior

```dart
// Bad — methods before fields, constructor buried
class Foo {
  void doWork() {}
  final int x;
  Foo(this.x);
}

// Good — fields, constructor, methods
class Foo {
  final int x;
  Foo(this.x);
  void doWork() {}
}
```

## Quick Fix

Reorder members to match the canonical ordering. Complex due to potential comment/annotation attachment — may require manual intervention.

## Alternatives Considered

- DCM's `member-ordering` covers the same concept. This proposal tracks the mvvm_linter parity specifically.

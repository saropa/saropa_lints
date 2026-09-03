# PROPOSAL: Avoid Missing Controller

**Status: Open**

Created: 2026-09-02

**Closes gap:** `flutter_skill_lints` `avoid_missing_controller` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags widgets that use controller-dependent widgets (TextField, ListView, PageView, ScrollView, TabBarView) without providing an explicit controller, relying on implicit internal controllers that cannot be disposed or observed.

## Detection / Behavior

```dart
// Bad — implicit controller, no dispose path
Widget build(BuildContext context) => TextField();

// Good — explicit controller, can be disposed
final _controller = TextEditingController();
Widget build(BuildContext context) => TextField(controller: _controller);
```

## Quick Fix

None — manual refactor required. The developer must create and manage the controller lifecycle.

## Alternatives Considered

- Saropa's `require_controller_dispose` (`disposal_rules.dart`) covers the dispose side but not the "missing controller argument" side. This rule is complementary.

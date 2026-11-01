# BUG: `avoid_retaining_disposed_widgets` — flags Widget fields that the class's `dispose()` sets to null

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_retaining_disposed_widgets`
File: `lib/src/rules/resources/memory_management_rules.dart` (rule name at line ~1773)
Severity: False positive (reported as severity 8, error)
Rule version: v2 | Updated: 17.0.1-beta.6

---

## Summary

A non-widget helper class stores `Widget` references for an animation. Its `dispose()` sets every such field to null. The rule still reports each field as an error.

---

## Attribution Evidence

```bash
grep -rn "'avoid_retaining_disposed_widgets'" lib/src/rules/
# Expected: lib/src/rules/resources/memory_management_rules.dart:1773
```

**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp3`

---

## Reproducer

```dart
class CardExitController {
  CardExitController(this.controller);

  final AnimationController controller;

  List<Widget>? _lastCards; // LINT — should NOT lint
  Widget? _ghost; // LINT — should NOT lint

  void dispose() {
    _ghost = null;
    _lastCards = null;
    controller.dispose();
  }
}
```

Real site: `contacts` app, `lib/components/home/section/in_focus_card_exit.dart` lines 68-69. `dispose()` at line 227 clears both fields.

**Frequency:** Always, for a class that holds Widget fields and clears them in `dispose()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the class has a `dispose()` that assigns null to the Widget/State field. |
| **Actual** | `[avoid_retaining_disposed_widgets]` on each field, severity error. |

---

## Root Cause

Unknown. The rule appears to check only the field type, not whether `dispose()` releases the reference.

---

## Suggested Fix

Exempt a field when a `dispose()` method of the same class assigns `null` to it. Add fixture cases to the rule's fixture file and a test in the matching rules test file.

---

## Resolution

Fixed 2026-10-31. The rule now collects the names of fields assigned `null` (`x = null` / `this.x = null`) inside the class's own `dispose()` and skips non-static fields whose declarators are all cleared. Fields not cleared, partially cleared declarations, and static fields are still reported. Fixture cases added; verified with `dart run saropa_lints:scan --tier comprehensive` on a scratch copy (cleared fields silent, 3 uncleared/static cases flagged).

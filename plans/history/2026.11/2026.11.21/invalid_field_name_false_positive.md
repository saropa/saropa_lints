# BUG: `invalid_field_name` — fires on a local with a record type whose field names come from a called API

**Status: Fixed**

Rule: `invalid_field_name`
File: `lib/src/rules/data/type_rules.dart`
Severity: False positive
Sites in downstream app: 1 site in 1 file

---

## Summary

The record type annotation is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'invalid_field_name'" lib/src/rules/
# Expected: lib/src/rules/data/type_rules.dart:NN
```

---

## Reproducer

```dart
final ({DateTime when, bool isMoved}) fit = Slots.defaultSlotFor(); // LINT, but should NOT lint
// The record field names are dictated by the return type of defaultSlotFor().
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: field names in a record type annotation must match the declared return type of the initializer. |
| **Actual** | The record type annotation is reported. |

---

## Suggested Fix

Skip record-type annotations on declarations whose initializer is a call returning that record type. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)

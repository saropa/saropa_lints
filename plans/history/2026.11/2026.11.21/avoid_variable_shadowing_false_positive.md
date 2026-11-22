# BUG: `avoid_variable_shadowing` — fires on wildcard `_` local declarations

**Status: Fixed**

Rule: `avoid_variable_shadowing`
File: `lib/src/rules/core/class_constructor_rules.dart`
Severity: False positive
Sites in downstream app: 3 sites in 2 files

---

## Summary

The wildcard local is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_variable_shadowing'" lib/src/rules/
# Expected: lib/src/rules/core/class_constructor_rules.dart:NN
```

---

## Reproducer

```dart
void run(MapController map) {
  final bool _ = map.move(target, zoom); // LINT, but should NOT lint
}
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: `_` is a non-binding wildcard (Dart 3) and never shadows or is shadowed. |
| **Actual** | The wildcard local is reported. |

---

## Suggested Fix

Ignore declarations named exactly `_`. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)

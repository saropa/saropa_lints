# BUG: `avoid_implicitly_nullable_extension_types` — fires on extension type with non-nullable generic list representation

**Status: Fixed**

Rule: `avoid_implicitly_nullable_extension_types`
File: `lib/src/rules/data/type_rules.dart`
Severity: False positive
Sites in downstream app: 1 site in 1 file

---

## Summary

The declaration is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_implicitly_nullable_extension_types'" lib/src/rules/
# Expected: lib/src/rules/data/type_rules.dart:NN
```

---

## Reproducer

```dart
extension type NormalizedEntries<T>._(List<PopupMenuEntry<T>> entries) {} // LINT, but should NOT lint
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the representation type `List<...>` is non-nullable. |
| **Actual** | The declaration is reported. |

---

## Suggested Fix

Flag only when the representation type is nullable or a bare type parameter; a parameterized `List<X>` is non-nullable. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)

# BUG: `avoid_memory_intensive_operations` - False positive on non-string operation in loop

**Status: Fixed**

Created: 2026-04-29
Resolved: 2026-04-29
Rule: `avoid_memory_intensive_operations`
File: `lib/src/rules/core/performance_rules.dart` (line ~2455)
Severity: False positive

---

## Summary

The rule flagged a non-string operation in a layout loop as if it were string `+=` concatenation.

---

## Attribution Evidence

```bash
rg "'avoid_memory_intensive_operations'" d:/src/saropa_lints/lib/src/rules
# d:/src/saropa_lints/lib/src/rules/core/performance_rules.dart:2455
```

---

## Reproducer

```dart
for (final child in children) {
  maxScrollObstructionExtent += child.geometry.maxScrollObstructionExtent; // OK (numeric accumulation)
}
```

Frequency: Always

---

## Resolution

- Replaced variable-name heuristic detection for loop `+=` with type-based detection that only reports when the right-hand expression is `String`.
- Added fixture regression coverage for numeric `+=` accumulation in `avoid_memory_intensive_operations_fixture.dart`.
- Added integration assertion that the fixture reports exactly one violation for the BAD string-concatenation line.

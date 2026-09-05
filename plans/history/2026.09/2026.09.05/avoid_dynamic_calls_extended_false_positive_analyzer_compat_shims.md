# BUG: `avoid_dynamic_calls_extended` — False positive on intentional analyzer-compat dynamic dispatch

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_dynamic_calls_extended`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v1

---

## Summary

The rule fires 12 times on dynamic dispatch that is intentional and guarded. Two distinct patterns:

1. **Analyzer-version compatibility shims** (`analyzer_metadata_compat_utils.dart`, `element_identifier_utils.dart`): These files deliberately use `dynamic` to duck-type across analyzer API versions that changed method signatures. Every dynamic call is wrapped in `try/on NoSuchMethodError`/`on TypeError`/`on Object` catch blocks that return safe fallbacks. This is the documented cross-version compatibility pattern — there is no common interface.

2. **`Object.toString()` on `dynamic`-typed values** (`cross_file_baseline.dart`, `health_config.dart`, `baseline_date.dart`, `project_context_cross_file.dart`): Calls to `.toString()` on values typed `dynamic` by SDK design (e.g. `ProcessResult.stdout`, `YamlList` elements, `Map` values with no generic args). `.toString()` is defined on `Object` and cannot throw `NoSuchMethodError`.

---

## Attribution Evidence

```bash
grep -rn "'avoid_dynamic_calls_extended'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:NNNN:    'avoid_dynamic_calls_extended',
```

---

## Reproducer

```dart
// Pattern 1: Analyzer compat shim — intentional dynamic dispatch
bool hasDeprecated(Element element) {
  try {
    return (element as dynamic).hasDeprecated as bool; // LINT — but should NOT lint
  } on NoSuchMethodError {
    return false; // This analyzer version lacks the API
  }
}

// Pattern 2: .toString() on dynamic — safe Object method
final output = result.stdout?.toString(); // LINT — but should NOT lint
```

**Frequency:** Always.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when dynamic call is inside a `try/on NoSuchMethodError` guard, or when calling `toString()`/`hashCode`/`==` (Object methods) |
| **Actual** | `[avoid_dynamic_calls_extended] Calling a method on a receiver typed dynamic...` |

---

## Suggested Fix

1. If the dynamic call is inside a `try` block with `on NoSuchMethodError` or `on Object` catch, suppress — the developer has explicitly handled the failure mode.
2. If the called method is an `Object` method (`toString`, `hashCode`, `runtimeType`, `==`), suppress — these are always safe on `dynamic`.

---

## Affected Files

- `element_identifier_utils.dart:22,36` — duck-type `.element`/`.staticElement`
- `project_context_cross_file.dart:34` — `.toString()` on map value
- `analyzer_metadata_compat_utils.dart:41,63,71` — compat shim for `.metadata`/`.hasDeprecated`/`.isDeprecated`
- `cross_file_baseline.dart:69,76,83` — `.toString()` after type check
- `health_config.dart:88` — `item.toString()` on YamlList element
- `baseline_date.dart:137,246` — `result.stdout?.toString()`

---

## Environment

- saropa_lints version: current (unreleased)

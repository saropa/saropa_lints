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

---

## Finish Report (2026-09-05)

`AvoidDynamicCallsRule` (`lib/src/rules/data/avoid_dynamic_calls_extended_rules.dart`) flagged two classes of intentional, guarded dynamic dispatch as violations: calls to `Object`-defined members (`toString`, `hashCode`, `runtimeType`, `noSuchMethod`) on a `dynamic` receiver, and dynamic dispatch performed inside a `try` block whose catch clause handles `NoSuchMethodError`/`TypeError`/`Object` — the documented cross-analyzer-version duck-typing pattern used throughout the codebase's own compat shims.

Two exemptions were added to `AvoidDynamicCallsRule`: `_isObjectMethod`/`_isObjectProperty` (static `Set<String>` lookups against `{toString, noSuchMethod}` and `{hashCode, runtimeType}` respectively) skip Object-defined members before reporting on `MethodInvocation`, `PropertyAccess`, and `PrefixedIdentifier` nodes; `_isInsideTryCatchGuard` walks the AST parent chain from the offending node, stopping at the nearest `FunctionBody` boundary, and returns true if an enclosing `TryStatement`'s `catchClauses` include a bare `catch` or an `on NoSuchMethodError`/`on TypeError`/`on Object` clause. `==` was already excluded via the pre-existing `_operatorInvocationTokens` set (comparison/logical operators are deliberately not treated as "unchecked" dispatch) and required no change.

Fixing the false positive left the existing `example/lib/type_safety/avoid_dynamic_calls_extended_fixture.dart` BAD case at the end of `DynamicProxy.noSuchMethod()` silently passing for the wrong reason: `fallback.toString()` would now be exempted by the new Object-method guard instead of exercising the narrowed `noSuchMethod`-override exemption it was written to test. Changed the fixture to `fallback.describe()` (a non-Object method) to keep that regression case load-bearing, and added three new fixture blocks: `_goodObjectMethodsOnDynamic()` (toString/hashCode/runtimeType/`==` on a dynamic receiver, all unflagged), `_goodTryCatchGuardedDynamicCall()` (method call guarded by `on NoSuchMethodError`), and `_goodTryCatchGuardedPropertyAccess()` (property access guarded by `on TypeError`).

**Verification:** `dart run saropa_lints scan example/lib/type_safety --tier comprehensive --resolve --format json` was run against the fixture directory (the standalone scan CLI requires `--resolve` for dynamic-type detection; `--files` filtering from the repo root under-discovered files in this environment, so the directory form was used instead). The `avoid_dynamic_calls_extended` diagnostics returned fired on exactly the 13 lines carrying `expect_lint` markers (22, 28, 35, 42, 65, 68, 77, 94, 110, 112, 115, 124, 153) and did not fire on any line inside the three new GOOD blocks (160–177, 183–191, 194–200) or the two try/catch-guarded call sites. `test/rules/data/avoid_dynamic_calls_extended_test.dart` was inspected and requires no change — per project convention it only pins rule metadata (`code.lowerCaseName`, message content) and fixture-file existence; it does not execute the rule.

CHANGELOG entry already present under `## [16.0.0-beta.4] — Unreleased` → Maintenance (bundled with 11 other false-positive fixes in the same release pass): "`avoid_dynamic_calls_extended` now exempts Object methods and try/catch-guarded duck-typing."

### Known gaps not addressed by this fix

- **Catch-block/finally leakage:** `_isInsideTryCatchGuard` walks up to the nearest enclosing `TryStatement` without distinguishing whether the originating node sits in the `try` body, a `catch` body, or a `finally` block. A fresh, unguarded dynamic call written inside the `catch` or `finally` block of a `NoSuchMethodError`-handling try would be incorrectly exempted, since its parent chain still passes through the same `TryStatement`. Not covered by the fixture; no known real-world instance in this codebase's own compat shims (all guarded calls sit in the `try` body only).
- **Object-method tear-offs:** `PropertyAccess`/`PrefixedIdentifier` handling only checks `_isObjectProperty` (`hashCode`, `runtimeType`), not `_isObjectMethod`. A tear-off of `toString` without a call (`final f = dynamicValue.toString;`) is a `PropertyAccess`/`PrefixedIdentifier` node with `propertyName`/`identifier` `'toString'` and is still flagged, even though tearing off a guaranteed-safe Object method carries the same safety guarantee as calling it. No fixture case exercises this; left as a follow-up if reported.
- **Exception-type name matching is textual:** `_isInsideTryCatchGuard` compares `exceptionType.toSource()` against literal strings `'NoSuchMethodError'`, `'TypeError'`, `'Object'`. A prefixed/aliased import (`core.TypeError`, or a type alias) would not match and the call would still be flagged. Not exercised by the fixture; no known occurrence in this codebase.

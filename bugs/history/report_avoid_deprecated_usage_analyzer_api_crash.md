# Bug: AvoidDeprecatedUsageRule crashes with analyzer 9 — NoSuchMethodError: SimpleIdentifierImpl has no getter 'staticElement'

**Status:** Fixed (released in 6.0.10)  
**Rule:** `avoid_deprecated_usage`  
**Affected:** 6.0.9 (published)  
**Fix:** 6.0.10 — `lib/src/rules/code_quality_rules.dart`: compatibility helper `elementFromIdentifier` uses `.element` (analyzer 9+) and `.staticElement` (older) in try/catch so the plugin no longer crashes under analyzer 9.

---

## Summary

When a consumer used **saropa_lints 6.0.9** with analyzer 9.x, `dart analyze` crashed with `NoSuchMethodError: Class 'SimpleIdentifierImpl' has no instance getter 'staticElement'`. AvoidDeprecatedUsageRule was reading the resolved element from `methodName`/`propertyName`/`constructorName`; analyzer 9 removed `staticElement` in favor of `element`. Fix: local helper tries `id.element` then `id.staticElement` (in try/catch) and is used in all three visitor callbacks so the rule works on both analyzer versions.

---

## Environment

| Item | Value |
|------|--------|
| Consumer SDK | Dart 3.x / Flutter 3.41.2 |
| Resolved analyzer | 9.0.0 (transitive via saropa_lints) |
| analysis_server_plugin | 0.3.4 |
| saropa_lints (failing) | 6.0.9 from pub.dev |
| Plugin load path | Analysis server loads plugin by **version** from its cache; path dependency does not override. |

---

## Reproduction

1. Create a Dart or Flutter project with: `dev_dependencies: saropa_lints: ^6.0.9` and `analysis_options.yaml` plugin `saropa_lints: version: "6.0.9"`.
2. Run `dart analyze` on a project that has method calls, property access, or constructor calls.

**Result:** Analysis fails with the `NoSuchMethodError`. Exit code 4.

---

## Stack trace (representative)

```text
An error occurred while executing an analyzer plugin: NoSuchMethodError: Class 'SimpleIdentifierImpl' has no instance getter 'staticElement'.
...
#2      AvoidDeprecatedUsageRule.runWithReporter.<anonymous closure> (package:saropa_lints/src/rules/code_quality_rules.dart:8743)
```

---

## Root cause

1. **Analyzer 9 API:** `SimpleIdentifier` / `Identifier` no longer expose `staticElement`; the public getter is **`element`**.
2. **Rule:** AvoidDeprecatedUsageRule in 6.0.9 accessed `.staticElement` (or equivalent) on `node.methodName` / `node.propertyName` / `node.constructorName`, causing the crash.
3. **Plugin resolution:** Only a published new version (e.g. 6.0.10) and consumer plugin version bump fix the crash for normal analysis.

---

## Fix (implemented in 6.0.10)

**File:** `lib/src/rules/code_quality_rules.dart` — `AvoidDeprecatedUsageRule.runWithReporter`

- Added `Element? elementFromIdentifier(dynamic id)`: tries `id.element`, then `id.staticElement`, each in try/catch; returns null if missing or not `Element`.
- Replaced direct element access in callbacks: `elementFromIdentifier(node.methodName)`, `elementFromIdentifier(node.propertyName)`, `elementFromIdentifier(node.constructorName)`.

---

## References

- Rule: `avoid_deprecated_usage` — `lib/src/rules/code_quality_rules.dart` (class `AvoidDeprecatedUsageRule`).
- [SimpleIdentifier — analyzer 9.0.0](https://pub.dev/documentation/analyzer/9.0.0/dart_ast_ast/SimpleIdentifier-class.html).
- Fixture: `example_core/lib/code_quality/avoid_deprecated_usage_fixture.dart`.

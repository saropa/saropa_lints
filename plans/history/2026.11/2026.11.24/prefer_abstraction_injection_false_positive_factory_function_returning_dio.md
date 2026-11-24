# BUG: `prefer_abstraction_injection` — Flags a factory-function parameter because its return type is named `Dio`

**Status: Open**

Created: 2026-11-24
Rule: `prefer_abstraction_injection`
File: `lib/src/rules/architecture/dependency_injection_rules.dart` (line ~1470)
Severity: False positive
Rule version: v2 | saropa_lints 17.7.9

---

## Summary

The rule regex-matches the parameter's type source against `\bDio\b` (among `Impl`, `Http`, `Socket`, ...). A parameter typed `Dio Function()?` is a factory closure, which is itself the injection seam (tests pass a fake factory). It is not an injected concrete instance. The only function-type guard is `functionTypedSuffix == null`, so generic function types (`Dio Function()`) slip through. Expected: skip parameters whose type is a `GenericFunctionType`.

---

## Attribution Evidence

```bash
grep -rn "'prefer_abstraction_injection'" lib/src/rules/
# lib/src/rules/architecture/dependency_injection_rules.dart:1470
```

---

## Reproducer

```dart
class FeedStore {}
class FeedCache {}

class CustomFeedSource {
  CustomFeedSource({
    required this.cache,
    FeedStore? store,
    Dio Function()? dioFactory, // LINT — but should NOT lint: closure is the seam; type source "Dio Function()?" matches \bDio\b
  }) : store = store ?? FeedStore(),
       _dioFactory = dioFactory ?? Dio.new;

  final FeedStore store;
  final FeedCache cache;
  final Dio Function() _dioFactory;
}
```

**Frequency:** Always for function-typed params whose return type contains a listed word

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for `Dio Function()` parameters; `FeedStore` / `FeedCache` are not flagged either (no listed pattern) |
| **Actual** | `[prefer_abstraction_injection] Injecting concrete implementation. Prefer injecting abstract types for testability. {v2}` on the constructor parameter |

Note: the downstream project's ignore comment attributes the finding to `FeedStore`. By reading the rule, `FeedStore` cannot match any pattern, so the reported parameter is `dioFactory`. The lints export omits suppressed findings, so this is derived from the rule source, not observed output.

---

## Root Cause

`typeStr = param.type?.toSource()` then `_isLikelyConcrete(typeStr)` regex-matches the whole string. For a generic function type the string includes the return type. The guard `param.functionTypedSuffix == null` covers only `void f()` style parameters, not `Dio Function()`.

## Suggested Fix

If `param.type is GenericFunctionType` (or the type source contains `Function(`), skip.

## Fixture Gap

1. `Dio Function()? factory` — NO lint
2. `DioImpl client` — LINT

---

## Environment

- saropa_lints version: 17.7.9
- Triggering project/file: jupiter-tablet `lib/sources/feed/feed_source.dart` (CustomFeedSource constructor)

# BUG: `prefer_static_method` — Singleton Facade Whose Instance Methods Are The Public API

**Status: Open**

Created: 2026-10-29
Rule: `prefer_static_method`
File: `lib/src/rules/architecture/structure_rules.dart (line ~2124)`
Severity: False positive

---

## Summary

A singleton class (`static final instance`, private constructor) exposes thin instance methods that delegate to another singleton. The rule reports every one as "could be static". Making them static is not a local change: every caller uses `Class.instance.method()`, and calling a static through an instance is a compile error. The instance API is the contract (and the seam tests substitute through).

---

## Attribution Evidence

```bash
grep -rn "'prefer_static_method'" lib/src/rules/
# lib/src/rules/architecture/structure_rules.dart:2133:    'prefer_static_method',
# class PreferStaticMethodRule (structure_rules.dart:2124)
```

---

## Reproducer

```dart
// Standalone, compiles with plain `dart`.
class _Cache {
  _Cache._();
  static final _Cache instance = _Cache._();
  final Map<String, String> _data = <String, String>{};
  String? get(String k) => _data[k];
}

class CacheService {
  CacheService._privateConstructor();

  static final CacheService instance = CacheService._privateConstructor();

  /// Delegates to another singleton; reads no field of CacheService.
  String? cacheGetValue(String key) => _Cache.instance.get(key); // LINT - should NOT lint

  void dispose() => _Cache.instance._data.clear(); // LINT - should NOT lint
}

void main() => print(CacheService.instance.cacheGetValue('a'));
```
Project source: `lib/database/drift_middleware/system_data/user_env_override_cache_service.dart:20-100` (class `UserEnvOverrideCacheService`, constructor at line 21, `instance` at line 23). 249 references to `UserEnvOverrideCacheService` exist in `lib/` and `test/` outside that file, all through `.instance`.

**Frequency:** Always, for any singleton wrapper that forwards to another object.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on instance methods of a singleton (`static final X instance` + private constructor) |
| **Actual** | `[prefer_static_method] Method does not reference any instance members and could be static. ... {v4}` at 28:16-40, 68:11-24, 71:7-20, 75:8-24, 81:8-25, 86:8-24, 90:8-24, 93:8-21, 96:8-26, 99:8-15 |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (UserEnvOverrideCacheService)
      ├─ ConstructorDeclaration (_privateConstructor)
      ├─ FieldDeclaration (static final instance)
      └─ MethodDeclaration (cacheGetValue)   <- token `node.name` reported
          └─ ExpressionFunctionBody
              └─ MethodInvocation (EnvOverrideCache.instance.cacheGetValue)
```

---

## Root Cause

`runWithReporter` (structure_rules.dart:2147-2175) visits each `MethodDeclaration` and skips only: extension / extension-type members, `static`, getters/setters/operators, `@override`, abstract (lines ~2149-2166). It then runs `_ThisUsageFinder` (structure_rules.dart:2191+) over the body. No `this`, no bare instance member -> `usesThis == false` -> `reporter.atToken(node.name, code)` at line 2172.

There is no check of the enclosing class shape. A class that is a singleton (private/named private constructor and a `static` field of its own type) is not exempt, although for such a class the instance methods are the only way callers reach the object.

---

## Why the Code Is Correct

- Converting to static changes every call site (`Class.instance.m()` becomes a compile error), so the rule's own advice ("can be called without constructing the class") is not available: callers never construct the class.
- The class exists to give tests and startup code one stable instance seam (its doc comment says "kept so every existing `.instance` call site keeps compiling unchanged").
- Behavior is identical either way, so this is an API-shape decision the rule cannot see.

---

## Affected Project Locations

`lib/database/drift_middleware/system_data/user_env_override_cache_service.dart` lines 28, 68, 71, 75, 81, 86, 90, 93, 96, 99 (ten methods of one class). Other `*CacheService` singletons in the project follow the same pattern and will report the same way.

---

## Suggested Fix

Skip the report when the enclosing class is a singleton:
- it has no generative public constructor (all constructors are private), and
- it declares a `static` field or getter whose type is the class itself (commonly named `instance`).

Optionally also skip when the class has a `factory` constructor returning a `static` instance.

---

## Fixture Cases

```dart
// LINT expected (plain utility, no singleton shape)
class Util { int add(int a, int b) => a + b; }

// OK expected (singleton: private ctor + static self-typed field)
class Svc {
  Svc._();
  static final Svc instance = Svc._();
  String ping() => 'pong';
}

// OK expected (factory singleton)
class Svc2 {
  Svc2._();
  static final Svc2 _i = Svc2._();
  factory Svc2() => _i;
  String ping() => 'pong';
}
```

---

## Environment

- saropa_lints: 17.0.1-beta.2 (installed in the downstream project); rule line numbers below read from the local checkout (pubspec 17.0.1-beta.3), where the cited logic is unchanged.
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Downstream project: Saropa Contacts (`/Users/craighathaway/Documents/src/contacts`), Flutter app.
- Diagnostic `source` / `owner` in Problems panel: `saropa_lints` / `saropaLintsLsp`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).

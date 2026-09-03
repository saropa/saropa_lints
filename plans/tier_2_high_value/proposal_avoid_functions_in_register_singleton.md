# PROPOSAL: Flag Non-Trivial Function Bodies Passed to `get_it`'s `registerSingleton`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `get_it` service-locator package)
Related rules: none

---

## Summary

Add `avoid-functions-in-register-singleton` (saropa id: `avoid_functions_in_register_singleton`) to flag
passing a factory function/closure with meaningful logic to `GetIt.registerSingleton(...)`, when
`registerSingletonAsync`, `registerLazySingleton`, or `registerFactory` is the correct API for
deferred/complex construction. `registerSingleton` expects an already-constructed instance argument — a
closure that does real work there is either a misuse (the closure itself is being passed as the "instance",
which won't type-check as intended) or defers construction to the wrong lifecycle point.

**Closes gap:** `dart_code_metrics_presets` `avoid-functions-in-register-singleton` (get_it preset). No
`get_it`-specific rules exist in saropa at all. Implementing this proposal as specified fully closes this
competitive gap — see `plans/GAP_ANALYSIS.md` "Uncovered ecosystem packages" section.

---

## Motivation

`get_it`'s registration API has multiple methods with different construction-timing semantics
(`registerSingleton` = eager, `registerLazySingleton` = deferred factory, `registerFactory` = new instance
per resolve, `registerSingletonAsync` = async eager). Passing a function literal where an already-built
instance is expected is a common `get_it` beginner mistake that either fails at compile time in obvious cases
or, when the instance's own type happens to also be callable/constructible in a way the compiler accepts,
produces confusing runtime registration behavior. saropa has zero `get_it` awareness today despite it being
one of the most widely used Flutter DI/service-locator packages.

---

## Detection / Behavior

### Should flag (bad code)

```dart
GetIt.I.registerSingleton<ApiClient>(
  () => ApiClient(baseUrl: Env.apiUrl), // LINT — avoid_functions_in_register_singleton: closure passed where an instance is expected; use registerLazySingleton
);
```

### Should pass (good code)

```dart
GetIt.I.registerSingleton<ApiClient>(
  ApiClient(baseUrl: Env.apiUrl), // OK — already-constructed instance
);

GetIt.I.registerLazySingleton<ApiClient>(
  () => ApiClient(baseUrl: Env.apiUrl), // OK — factory closure is the correct argument shape here
);
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `get_it` dependency note)
Justification: Only fires in projects depending on `get_it`; construction-timing footgun rather than a
universal Dart concern, matching saropa's placement for other single-package DI rules.

---

## Edge Cases

1. **A trivial pass-through closure that just calls a zero-arg constructor with no other logic**
   (`() => ApiClient()`) — still flag; `registerSingleton`'s parameter type is the instance itself, so any
   closure argument is a shape mismatch regardless of how simple the closure body is.
2. **`registerFactory`/`registerLazySingleton`/`registerSingletonAsync` calls** — should pass; these methods
   correctly expect a factory closure as their argument.
3. **A variable holding a pre-built instance passed to `registerSingleton`** (`registerSingleton(myClient)`)
   — should pass; only literal function/closure arguments are flagged.
4. **Project does not depend on `get_it`** — must not fire; gate on package presence like saropa's other
   ecosystem-specific rules.

---

## Alternatives Considered

- **Type-check whether the argument actually satisfies `registerSingleton`'s expected type parameter** —
  considered as a more precise detection than "is it a function literal", but a simple AST shape check
  (function-literal argument to `registerSingleton`) is sufficient to catch the real-world mistake pattern
  and avoids needing full generic-type resolution against `get_it`'s API surface.

---

## Decision

---

## Implementation Notes

---

## Commits

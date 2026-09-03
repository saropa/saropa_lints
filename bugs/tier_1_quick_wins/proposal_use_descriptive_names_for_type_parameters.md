# PROPOSAL: Flag Single-Letter Generic Type Parameters Beyond a Simple `T`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_shadowing_type_parameters_class_methods`

---

## Summary

Add `use_descriptive_names_for_type_parameters` to flag generic type parameters named with a bare single letter (`K`, `V`, `E`, `S`, ...) when a class/function declares more than one type parameter, or when a single type parameter's meaning isn't self-evident from a lone `T`. Multi-parameter generics (`class Cache<K, V, E>`) become hard to read without descriptive names (`class Cache<Key, Value, ExpiryPolicy>`).

**Closes gap:** `solid_lints` `use_descriptive_names_for_type_parameters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `solid_lints` gap list.

---

## Motivation

A single generic parameter named `T` is an established, unambiguous Dart convention (`List<T>`, `Future<T>`) and should stay exempt. But once a declaration has two or more type parameters, single letters lose their meaning fast — `Map<K, V>` is fine only because it is universally recognized; a project's own `Repository<K, V, E>` is not. Descriptive names cost nothing at the call site (type parameters are almost never referenced by name outside the declaration) and materially improve readability of the declaration itself.

---

## Detection / Behavior

Flag a `TypeParameter` whose name is a single letter (case-insensitive) when the enclosing `TypeParameterList` has 2+ entries, excluding the well-known `K`/`V` pair on `Map`-shaped generic classes (configurable allowlist).

### Should flag (bad code)

```dart
class Repository<K, V, E> { // LINT on V, E — single-letter names in a 3-param generic
  V? get(K key) => null;
}
```

### Should pass (good code)

```dart
class Repository<Key, Value, ErrorType> { // OK — descriptive names
  Value? get(Key key) => null;
}

class Box<T> {} // OK — single type parameter, T is conventional
```

---

## Proposed Tier

Tier: Pedantic
Justification: Pure readability/style preference with no correctness impact and a real risk of friction against established `K, V` conventions.

---

## Edge Cases

1. **`Map<K, V>`-shaped classes intentionally mirroring the SDK convention** — should pass via a default allowlist for the `K, V` pair specifically.
2. **Single type parameter named something other than `T` (e.g. `X`)** — should flag; the "single letter is fine" exemption should be `T` specifically (or a configurable set: `T`, `E`, `K`, `V`), not any letter.
3. **Type parameters with bounds (`<K extends Comparable<K>, V>`)** — should flag the same as unbounded ones; the bound doesn't make the name self-documenting.
4. **Extension type parameters (`extension MyExt<K, V> on Map<K, V>`)** — should flag identically to class/function type parameters.

---

## Alternatives Considered

- **Flag every single-letter type parameter including lone `T`** — rejected; would conflict with idiomatic Dart/Flutter SDK style and generate excessive noise for the single most common case.

---

## Decision

---

## Implementation Notes

---

## Commits

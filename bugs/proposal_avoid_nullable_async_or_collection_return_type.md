# PROPOSAL: Flag Nullable `Future<T>?` / Collection Return Types

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_nullable_async_or_collection_return_type` to flag function/method return types of the shape `Future<T>?` (a nullable `Future`, distinct from `Future<T?>`) and nullable collection types (`List<T>?`, `Map<K, V>?`, `Set<T>?`) where an empty collection or a non-null, already-resolved `Future` would express "nothing here" just as well without forcing every caller to null-check before awaiting or iterating.

**Closes gap:** flutter_skill_lints `avoid_nullable_async_or_collection_return_type`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A nullable `Future<T>?` is almost always a bug waiting to happen: callers `await` it expecting a `Future`, and `await null` behaves differently from awaiting a genuinely absent value in ways that surprise most developers, while the *usual* intent ("there might be no value") is already expressible as `Future<T?>`. Likewise, `List<T>?`/`Map<K,V>?`/`Set<T>?` forces every call site to null-check before a `for`/`.map()`/`.isEmpty`, when an empty collection carries the same "nothing here" meaning with none of the null-safety ceremony — the classic "null vs. empty collection" API design smell.

---

## Detection / Behavior

Flag any function/method declared return type matching `Future<...>?` (nullable at the `Future` level, not the inner type) or `List<...>?`/`Map<...,...>?`/`Set<...>?`.

### Should flag (bad code)

```dart
Future<User>? maybeFetchUser(String id) { // LINT — nullable Future; prefer Future<User?>
  if (id.isEmpty) return null;
  return _api.getUser(id);
}

List<String>? getTags() => _tags.isEmpty ? null : _tags; // LINT — prefer returning [] instead of null
```

### Should pass (good code)

```dart
Future<User?> maybeFetchUser(String id) async { // OK — Future always resolves, inner value may be null
  if (id.isEmpty) return null;
  return _api.getUser(id);
}

List<String> getTags() => _tags; // OK — empty list instead of null
```

---

## Proposed Tier

Tier: Recommended
Justification: A nullable `Future` is a well-known async-safety footgun (matches saropa's existing "no silent async" / nullable-safe collection principles from CLAUDE.md); default-on placement is warranted given the low false-positive rate.

---

## Edge Cases

1. **`FutureOr<T>?` return type** — should flag the same; the nullable-at-the-Future-level concern applies identically.
2. **Nullable collection type used specifically to distinguish "not yet loaded" (`null`) from "loaded but empty" (`[]`) — a legitimate tri-state** — needs discussion; this is the strongest counter-argument to a blanket ban. Consider allowing suppression with justification for documented tri-state loading patterns, since collapsing "not loaded" and "empty" does lose real information in some UI-state models.
3. **Generic type parameter itself resolves to a nullable collection (`T extends List<int>?`)** — should pass; the rule targets the declared return type syntax, not resolved generic instantiations, to keep detection predictable.
4. **Private helper method never called with a null-necessitating branch (dead code path always returns non-null)** — should still flag; the signature itself is the problem regardless of current call sites.

---

## Alternatives Considered

- **Only flag `Future<T>?`, not nullable collections** — rejected; both are instances of the same "null instead of a proper empty/optional-inner-value representation" smell, and grouping them under one rule (matching the upstream flutter_skill_lints rule name) keeps the surface area consistent.

---

## Decision

---

## Implementation Notes

---

## Commits

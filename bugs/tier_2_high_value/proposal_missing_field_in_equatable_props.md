# PROPOSAL: Flag Instance Field Missing from Equatable's Props/hashParameters List

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_equatable_call_on_equality_base_class` (if present)

---

## Summary

Add `missing_field_in_equatable_props` to flag a class extending/mixing `Equatable` (or implementing an equivalent `hashParameters`/`props`-list value-equality pattern) that declares an instance field not included in its `props` (or `hashParameters`) getter override. A field left out of `props` silently breaks value equality — two instances that differ only in that field compare equal.

**Closes gap:** `fast_equatable_lint` `missing_field_in_equatable_props` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Equatable`'s `==`/`hashCode` are entirely derived from the `props` list the author maintains by hand. Adding a new field to the class and forgetting to add it to `props` is one of the most common `Equatable` bugs — it compiles cleanly, tests that don't specifically check the new field pass, and the class silently treats two logically-different instances as equal (breaking `Set`/`Map` dedup, Bloc/Cubit state-change detection, and Riverpod `select` comparisons alike).

---

## Detection / Behavior

Flag a class extending `Equatable` (or a project-recognized equivalent) that has an instance field (excluding `static`, excluding fields explicitly excluded via a project convention like `@EquatableIgnore`) whose name does not appear as an identifier reference inside the `props`/`hashParameters` getter body.

### Should flag (bad code)

```dart
class UserState extends Equatable {
  final String name;
  final bool isLoading; // LINT — field not included in props

  const UserState(this.name, this.isLoading);

  @override
  List<Object?> get props => [name];
}
```

### Should pass (good code)

```dart
class UserState extends Equatable {
  final String name;
  final bool isLoading;

  const UserState(this.name, this.isLoading);

  @override
  List<Object?> get props => [name, isLoading]; // OK — every field represented
}
```

---

## Proposed Tier

Tier: Essential
Justification: Directly prevents a silent correctness bug (broken value equality) with no legitimate reason for the common case of omission; matches the bar for saropa's other Essential-tier state-management correctness rules.

---

## Edge Cases

1. **Field intentionally excluded from equality (e.g. a cache/derived field, a `Timer`, a callback)** — needs an opt-out; recommend a project-recognized `// equatable-ignore` line comment or `@EquatableIgnore` annotation, consistent with saropa's existing `// ignore:` verification pattern.
2. **Field referenced inside `props` via a transformation (`hashCode` of a nested object, `list.length` instead of `list`)** — should pass; the rule checks the field identifier appears somewhere in the `props` expression, not that it appears bare.
3. **Getter/computed property (not a stored field) omitted from `props`** — out of scope; this rule targets stored instance fields only, since computed getters are typically derived from already-included fields.
4. **Class with `Equatable`-style value equality implemented by hand (manual `==`/`hashCode` override, no `props` getter)** — out of scope for this rule; would need separate detection of manual equality overrides missing a field, which is a different AST shape.

---

## Alternatives Considered

- **Reverse rule: flag a `props` entry with no matching field** — worth considering as a companion rule (`extraneous_equatable_prop` or similar) in a follow-up; out of scope here since the source package only specifies the missing-field direction.

---

## Decision

---

## Implementation Notes

---

## Commits

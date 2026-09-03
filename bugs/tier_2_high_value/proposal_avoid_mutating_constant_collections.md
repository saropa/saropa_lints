# PROPOSAL: Flag Attempts to Mutate a `const` Collection

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_unnecessary_null_aware_elements`, collection rules in `lib/src/rules/data/collection_rules.dart`

---

## Summary

Add `avoid_mutating_constant_collections` to flag calls like `.add()`, `.remove()`, `.clear()`, `.addAll()`, `[]=` on a `List`/`Map`/`Set` literal or variable known to be `const`. Mutating a `const` collection throws `UnsupportedError` at runtime — this is a real bug the analyzer's static type system does not catch on its own because the mutating method calls are otherwise type-correct.

**Closes gap:** DCM `avoid-mutating-constant-collections` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`const <int>[1, 2, 3].add(4)` compiles cleanly and crashes at runtime with `Unsupported operation: Cannot add to an unmodifiable list` — there is no compile-time error because `List<int>` doesn't distinguish growable from const-immutable at the type level. This is a frequent trap for developers who declare a `static const` collection for "shared default" purposes and then mutate a reference to it, expecting a normal growable list. DCM ships this exact check as prior art. It's a genuine correctness bug class, not a style preference.

---

## Detection / Behavior

Flag a method invocation (`add`, `addAll`, `remove`, `removeAt`, `removeWhere`, `removeLast`, `clear`, `insert`, `insertAll`, `sort`, `shuffle`, `[]=` via `IndexExpression` assignment, `retainWhere`) whose target resolves (via `staticElement`/declaration lookup) to:
- A collection literal marked `const` (`const [1, 2, 3]`, `const {1: 'a'}`).
- A variable/field declared `static const` or top-level `const` whose initializer is a collection literal.

### Should flag (bad code)

```dart
const defaultTags = <String>['flutter', 'dart'];

void addTag(String tag) {
  defaultTags.add(tag); // LINT — mutating a const collection throws UnsupportedError
}
```

### Should pass (good code)

```dart
const defaultTags = <String>['flutter', 'dart'];

void addTag(String tag) {
  final tags = List<String>.of(defaultTags); // OK — copy into a growable list first
  tags.add(tag);
}
```

---

## Proposed Tier

Tier: Essential
Justification: This is a guaranteed runtime crash (`UnsupportedError`), not a style issue — the same severity class as null-safety and type-mismatch bugs saropa already places in Essential. It should fire for every project by default since there is no legitimate reason to call a mutating method on a known-const collection.

---

## Edge Cases

1. **Mutating a *copy* of a const collection** (`List.of(constList)`, `[...constList]`) — should pass; the copy is a fresh growable collection, not the const instance.
2. **`final` (not `const`) collection holding a `const` literal value** — should still flag; `final tags = const ['a', 'b']; tags.add('c');` — the variable being `final` vs `const` doesn't change the runtime immutability of the referenced literal.
3. **`UnmodifiableListView` / `List.unmodifiable(...)`** — separate case, not `const`, but arguably related; out of scope for this rule (different construct), could be a follow-up rule (`avoid_mutating_unmodifiable_collections`).
4. **Reassigning the whole variable** (`defaultTags = [...]`) rather than mutating in place — should pass for `final`/`var`; for a `const`-declared variable this is already a compile error caught by the analyzer, out of scope.
5. **Mutation through an intermediate variable of inferred type** (`var x = constList; x.add(1);`) — should flag; `x`'s static element still resolves back to the const literal's element/type.

---

## Alternatives Considered

- **Rely on the runtime crash to catch this** — rejected; the whole point of static analysis is to catch this before the crash occurs, especially since it's easy to miss in a rarely-exercised code path.
- **Only flag direct calls on collection literals, skip variable tracking** — rejected as too narrow; the DCM check and the real-world bug pattern both involve a `const` field mutated through a reference, not just inline literals.

---

## Decision

---

## Implementation Notes

---

## Commits

# PROPOSAL: Flag Assignments Between Incompatible Generic Collection Types

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `lib/src/rules/data/collection_rules.dart`, `lib/src/rules/data/type_rules.dart`

---

## Summary

Add `avoid_not_assignable_collection_types` to flag assignments/casts/argument passes where a collection's generic type parameter is not actually compatible with the target — cases that compile because of Dart's covariant generics but are logically unsound and risk a runtime `TypeError` on later access (e.g. treating `List<Animal>` interchangeably with `List<Dog>` in a way that lets an incompatible element get inserted).

**Closes gap:** DCM `avoid-not-assignable-collection-types` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Dart generics are covariant, so `List<Dog>` is assignable to `List<Animal>` — but writing through that `List<Animal>` reference with a non-`Dog` `Animal` throws `TypeError` at runtime. This is a well-known Dart footgun that the analyzer allows because covariance is a deliberate language design choice, not a bug — it means the compiler cannot catch the misuse, only a linter that specifically tracks "this collection reference started life as a more specific type and is now being written to through a wider-typed alias" can. DCM ships this as prior art precisely because the type system doesn't close the hole.

---

## Detection / Behavior

Flag the specific unsound pattern: a variable/parameter declared with a collection type `Collection<Wide>` that is *assigned from* an expression whose static type is the narrower `Collection<Narrow>` (where `Narrow` is a strict subtype of `Wide`), when the resulting reference is subsequently used to insert/write an element that is a valid `Wide` but not a valid `Narrow`. As a conservative first pass (matching what's staticaly detectable without full flow analysis), flag the assignment site itself whenever a narrower-typed collection literal/variable is assigned to a wider-typed collection variable AND that wider variable is mutated (via `add`/`[]=`/`addAll`) anywhere in the same function body.

### Should flag (bad code)

```dart
class Animal {}
class Dog extends Animal {}
class Cat extends Animal {}

void addCat(List<Dog> dogs) {
  final List<Animal> animals = dogs; // LINT — List<Dog> assigned to List<Animal>, then mutated below
  animals.add(Cat()); // runtime TypeError: dogs list can't hold a Cat
}
```

### Should pass (good code)

```dart
class Animal {}
class Dog extends Animal {}
class Cat extends Animal {}

void addCat(List<Dog> dogs) {
  final List<Animal> animals = List<Animal>.of(dogs); // OK — copy breaks the aliasing
  animals.add(Cat());
}
```

---

## Proposed Tier

Tier: Professional
Justification: This is a genuine runtime-crash risk (`TypeError` on covariant generic write), but detecting it precisely requires tracking assignment plus later mutation within the same scope — more involved analysis than an Essential/Recommended rule, and it can only be done conservatively (same-function-body heuristic) without full data-flow analysis, so it needs a tier where developers doing deeper type-safety review opt in.

---

## Edge Cases

1. **Read-only use of the wider-typed alias (no mutation)** — should pass; covariance is safe as long as nothing is written back through the wider reference.
2. **Mutation happens in a different function/closure than the assignment** — should discuss; the first-pass heuristic (same function body) will miss this false negative. Document as a known limitation rather than attempting full whole-program flow analysis.
3. **`Map<K, V>` value-type covariance** (`Map<String, Dog>` assigned to `Map<String, Animal>`, then `[key] = Cat()`) — should flag using the same pattern, extended to `Map`/`Set`.
4. **Generic type parameters that are `final`/invariant by convention (immutable value classes)** — should pass if the wider variable is never mutated, per the base rule.
5. **Assignment through a generic function parameter** (`void f<T extends Animal>(List<T> list)`) — should pass; type parameter is resolved per-call-site by the analyzer, out of scope for a single-file static heuristic.

---

## Alternatives Considered

- **Full data-flow/escape analysis to catch the pattern across function boundaries** — rejected for the initial rule; too complex for a per-file AST-based linter and would require whole-program analysis akin to item 5 (`avoid-never-passed-parameters`) in this same gap batch. Ship the conservative same-scope heuristic first.
- **Flag every covariant collection assignment regardless of subsequent mutation** — rejected; would be extremely noisy (covariant assignment alone is legal and common), producing false positives dwarfing the real bug catches.

---

## Decision

---

## Implementation Notes

---

## Commits

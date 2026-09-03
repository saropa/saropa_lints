# PROPOSAL: Flag Variables Declared With a Wider Type Than Their Single Assigned Subtype

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `subtype_annotating` to flag a variable or field declared with a broad/interface type (e.g. `Widget`, `num`, an abstract base class) that is, throughout its scope, ALWAYS assigned instances of one specific concrete subtype and never reassigned to a different subtype — the declared type should be narrowed to that concrete subtype for clarity and to catch accidental future type-widening.

**Closes gap:** essential_lints `subtype_annotating` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Declaring `Widget child = Container(...)` when `child` is never reassigned to anything but a `Container` instance hides the actual, more useful type from readers and from the analyzer's own type-narrowing — a reader (or an IDE's autocomplete) sees only `Widget`'s surface, not `Container`'s specific members, and a future edit that reassigns `child` to some unrelated `Widget` subtype passes silently where a narrower declared type would have caught the drift as a compile error. essential_lints ships this as a readability/type-precision convention.

---

## Detection / Behavior

Flag a local variable, field, or top-level variable declared with an explicit type annotation where the declared static type is broader (a supertype, interface, or mixin) than the type of every value ever assigned to it in its scope, provided (a) it is assigned at least once with a concrete subtype literal/constructor/expression whose static type is knowable, (b) every assignment across its lifetime resolves to the SAME concrete subtype, and (c) nothing downstream (an override signature, a field in an external API, a return type contract) requires the wider declared type.

### Should flag (bad code)

```dart
Widget buildChild() {
  // LINT — subtype_annotating: `child` is only ever assigned Container
  // instances; declare it as Container for a narrower, more useful type.
  Widget child = Container(color: Colors.red);
  child = Container(color: Colors.blue);
  return child;
}
```

### Should pass (good code)

```dart
Widget buildChild(bool useCard) {
  // OK — genuinely reassigned across different subtypes, so the wider
  // Widget type is required.
  Widget child = Container(color: Colors.red);
  if (useCard) {
    child = Card(child: Text('hi'));
  }
  return child;
}

@override
Widget build(BuildContext context) {
  // OK — override signature requires the Widget return type / declared
  // type even though this build() only ever returns a Container.
  return Container();
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Style/precision rule with meaningful false-positive risk (see Edge Cases) — appropriate for a deep readability pass, not a default-on rule for most projects.

---

## Edge Cases

1. **Needs discussion — verify against upstream `essential_lints` source before implementing; semantics below are inferred from the rule name and general Dart-typing conventions, not confirmed against source.** The exact scope (does it apply to fields as well as locals? does it consider generic type parameters?) is unconfirmed.
2. **Override signatures / interface contracts** — should pass; a `build()` override, an interface method parameter, or an abstract class field whose type is fixed by a contract must keep the wider type regardless of what's actually assigned.
3. **Nullable widening (`Widget? child`)** — should pass if the only "widening" is nullability itself and the non-null branch is always the same concrete subtype; nullability is a distinct, independently-meaningful signal from subtype breadth.
4. **Late-initialized fields assigned from a constructor parameter of the declared (wide) type** — should pass; the rule should only fire when the concrete subtype is knowable from static analysis of the assignment expressions themselves, not when the value flows in from an external caller through a parameter typed as the wide interface.
5. **Generic collections (`List<Widget> children = [Container(), Container()]`)** — out of scope for v1; narrowing a collection's type parameter based on runtime-uniform element types is a much harder inference and likely belongs in a separate, more specialized rule if pursued at all.

---

## Alternatives Considered

- **Restrict to `var`-inferred vs. explicitly-annotated distinction** — considered scoping this only to explicitly-typed declarations (skip `var`/type-inferred ones, since those already get the narrow type from the analyzer). This matches the motivating case (someone explicitly widens the type) and avoids re-litigating type inference; recommend keeping this restriction in the actual implementation.
- **Quick fix that rewrites the declared type automatically** — plausible follow-up once the base detection is validated against real code and the "needs discussion" items above are resolved; not proposed for the initial version given the confirmed-semantics gap.

---

## Decision

---

## Implementation Notes

---

## Commits

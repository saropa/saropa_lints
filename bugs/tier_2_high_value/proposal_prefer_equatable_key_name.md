# PROPOSAL: Prefer a Consistent `props` Getter Name/Shape Across Equatable Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `require_equatable_props_override`, `list_all_equatable_fields`

---

## Summary

Flag an `Equatable`/`EquatableMixin` subclass whose equality-defining getter is declared under a non-canonical name or with an incompatible return shape instead of the standard `List<Object?> get props`.

**Closes gap:** DCM `prefer-equatable-key-name` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Equatable's contract requires overriding exactly `List<Object?> get props`. In practice, developers occasionally introduce a differently-named or differently-shaped equality getter alongside it — a leftover `List<Object?> get equalityProps` from a refactor, a `List<dynamic> get props` with the wrong generic type, or a `get keyFields` that was meant to feed `props` but never got wired up — leaving the class silently defaulting to identity equality (or a subtly wrong comparison) while looking correct at a glance. `require_equatable_props_override` in `lib/src/rules/packages/equatable_rules.dart` already flags a class with *no* `props` getter at all; this proposal is narrower and complementary — it flags the case where a `props`-shaped getter exists but its name or return type doesn't match Equatable's exact contract, which `require_equatable_props_override`'s exact-name check would not catch as a false "has props" pass. Confirmed by grep — zero matches for `prefer_equatable_key_name` in `lib/src/rules/`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Person extends Equatable {
  final String name;
  final int age;
  const Person(this.name, this.age);

  @override
  List<Object?> get equalityProps => [name, age]; // LINT — wrong getter name, does nothing for Equatable

  // No `props` override at all — falls back to identity equality
}
```

```dart
class Order extends Equatable {
  final String id;
  const Order(this.id);

  @override
  List<dynamic> get props => [id]; // LINT — return type should be List<Object?>, not List<dynamic>
}
```

### Should pass (good code)

```dart
class Person extends Equatable {
  final String name;
  final int age;
  const Person(this.name, this.age);

  @override
  List<Object?> get props => [name, age]; // OK — canonical name and type
}
```

```dart
class Order extends Equatable {
  final String id;
  const Order(this.id);

  @override
  List<Object?> get props => [id]; // OK
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: A near-miss naming/typing mistake that is uncommon in practice (most projects that use Equatable correctly name `props` from the start, since IDEs and templates default to it) but costly when it happens (silent fallback to identity equality). Pedantic fits because it's a low-frequency, high-specificity check rather than a broadly applicable convention — Comprehensive is reserved for the more common Riverpod naming gaps in this batch, whereas this rule catches a rarer copy-paste/refactor slip.

---

## Edge Cases

1. **A getter named `props` but declared without `@override` (so it doesn't actually override Equatable's abstract member and the analyzer may separately flag a missing override error)** — should still flag as a `prefer_equatable_key_name`-class issue if the return type also mismatches; if only the `@override` annotation is missing, that's better left to the Dart analyzer's own `override` diagnostics, and this rule should focus on name/type mismatches specifically.
2. **A private helper getter that legitimately isn't meant to be `props` (e.g. `_debugProps` used only for logging)** — should pass; only public getters whose name is a near-miss of `props` (e.g. `Props`, `prop`, `equalityProps`, `keyFields`) in a class that has NO working `props` override should be flagged, since a private, differently-purposed getter isn't a naming mistake.
3. **A class with both a correct `props` getter and an unrelated, differently-named getter with a `List` return type** — should pass; if a correct `props` override already exists, an additional differently-named list getter is not evidence of a mistake and should not be flagged.
4. **Subtype return like `List<Object>` (non-nullable element type) instead of `List<Object?>`** — should flag; while `List<Object>` is assignable, Equatable's own signature is `List<Object?>` and matching it exactly avoids `@override` type-compatibility ambiguity when nullable fields are later added to `props`.

---

## Alternatives Considered

- **Rely solely on the Dart analyzer's own "missing override" diagnostics** — rejected as insufficient; the analyzer only flags a *missing* abstract override, not a *near-miss-named* getter sitting unused alongside a class that appears equality-complete at a glance — exactly the silent-failure case this rule targets.
- **Fold into `require_equatable_props_override`** — rejected; that rule's detection is "no `props` getter found → flag the whole class." Adding near-miss-name detection would complicate its single responsibility; keeping it a separate, more targeted rule (as DCM does) keeps each diagnostic message precise about what's actually wrong.

# PROPOSAL: Flag `props` List Order Not Matching Field Declaration Order

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `list_all_equatable_fields` (completeness check — this rule is complementary, checking ordering instead)

---

## Summary

Flag an `Equatable`/`EquatableMixin` subclass whose `props` getter lists fields in a different order than the class's own field declaration order.

**Closes gap:** DCM `sort-equatable-props` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`list_all_equatable_fields` (in `lib/src/rules/packages/equatable_rules.dart`) already answers "does `props` contain every field?" — but it says nothing about *order*. When `props` lists fields out of declaration order, two problems compound over time: (1) code review diffs on `props` become harder to eyeball against the field list above it — a reviewer has to mentally re-sort both lists to confirm nothing was dropped or duplicated when a field is added; (2) it's a common early signal that `props` was hand-maintained by copy-pasting from an old version of the class rather than kept in sync, which is exactly the kind of drift that eventually produces a genuinely missing field (the bug `list_all_equatable_fields` catches). This proposal is the ordering counterpart to that existing completeness check, matching DCM's own split between `add-equatable-props` (completeness, saropa's `list_all_equatable_fields`) and `sort-equatable-props` (ordering, this proposal). Confirmed by grep — zero matches for `prefer_sorted_equatable_props` in `lib/src/rules/`.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Person extends Equatable {
  final String name;
  final int age;
  final String email;

  const Person(this.name, this.age, this.email);

  @override
  List<Object?> get props => [age, name, email]; // LINT — declared order is name, age, email
}
```

### Should pass (good code)

```dart
class Person extends Equatable {
  final String name;
  final int age;
  final String email;

  const Person(this.name, this.age, this.email);

  @override
  List<Object?> get props => [name, age, email]; // OK — matches field declaration order
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Stylistic/maintainability convention (order doesn't affect equality correctness — `props` order has no runtime semantic difference for `==`/`hashCode` as long as the *set* of fields is complete and consistent) but has real code-review value at scale. Comprehensive matches the tier used for other maintainability-not-correctness Equatable rules like `prefer_equatable_stringify` and `prefer_immutable_annotation`, both `info`-level in the existing file.

---

## Edge Cases

1. **`props` includes a computed expression not directly a field reference (e.g. `name.toLowerCase()`, or a nested `[...super.props, extra]`)** — should skip ordering comparison for that entry (or skip the whole check for the getter) rather than guessing where a derived expression "belongs" in field order; only compare simple field-identifier entries (`SimpleIdentifier`, `PrefixedIdentifier` referencing `this.field`) against the declared field order, reusing the same identifier-extraction approach `list_all_equatable_fields`'s `_extractIdentifiers()` already uses.
2. **`props` includes extra entries not present as declared fields (e.g. a getter-derived value)** — out of scope for ordering; `list_all_equatable_fields` already governs completeness, so this rule should only compare the relative order of entries that ARE declared instance fields, ignoring interleaved non-field entries for position purposes.
3. **Fields declared across multiple `FieldDeclaration` statements combining several variables each (e.g. `final String a, b;`)** — order should follow declaration source order, including each variable's position within a combined declaration.
4. **Static/const fields** — excluded from both the "expected order" list and the comparison, consistent with `list_all_equatable_fields`'s existing `!member.isStatic` filter.
5. **A class with `props` complete but reordered AND missing a field simultaneously** — both rules should fire independently (this rule on the reordering, `list_all_equatable_fields` on the omission); no need to suppress one in favor of the other since they diagnose different problems.

---

## Alternatives Considered

- **Auto-fix that reorders `props` to match field order** — a natural quick-fix candidate once the rule exists (rewrite the `ListLiteral` contents to declared order), but out of scope for this proposal per repo convention (`bugs/ISSUE_REPORT_GUIDE.md` structure keeps quick-fix requests as separate `proposal_fix_*` files); should be filed as a follow-up `proposal_fix_prefer_sorted_equatable_props` once the base rule lands.
- **Fold ordering into `list_all_equatable_fields` as an additional check on the same visitor** — rejected; that rule's `runWithReporter` already has two early-return branches (no getter → flag whole class; has getter → check missing fields) with a single, clear responsibility. Bolting an unrelated ordering check onto the same rule would mean one diagnostic message trying to describe two different problems (missing vs. misordered), reducing message clarity — matching DCM's own choice to ship these as two separate rules.

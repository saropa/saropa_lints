# PROPOSAL: Flag Getters Declared Outside the Class Member List Grouping

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `getters_in_member_list` to flag a getter (`Type get name => ...`) that is declared scattered among unrelated members (methods, overrides) instead of grouped with the class's fields/computed-property section. Enforces a consistent, navigable member ordering: fields, then getters/setters, then constructors/methods.

**Closes gap:** `essential_lints` `getters_in_member_list` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Classes that mix data-shape members (fields, getters, setters) freely among behavior members (methods) force readers to scan the whole class body to find "what does this object look like" versus "what does it do." Grouping getters with the other property-shaped members near the top of the class keeps the public data contract scannable in one place, independent of when each member was added.

---

## Detection / Behavior

Flag a `MethodDeclaration` with `isGetter == true` whose position in the class member list is separated from the class's field declarations and other getters/setters by one or more method declarations (i.e. a getter appears *after* at least one regular method, when fields/getters exist earlier that it could have been grouped with).

### Should flag (bad code)

```dart
class Order {
  final List<Item> items;

  Order(this.items);

  void addItem(Item item) {
    items.add(item);
  }

  double get total => items.fold(0, (sum, i) => sum + i.price); // LINT — getter declared after a method
}
```

### Should pass (good code)

```dart
class Order {
  final List<Item> items;

  double get total => items.fold(0, (sum, i) => sum + i.price); // OK — grouped with fields

  Order(this.items);

  void addItem(Item item) {
    items.add(item);
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Pure member-ordering convention with no correctness impact; opt-in style enforcement only.

---

## Edge Cases

1. **Single getter, no methods before it** — should pass; nothing to reorder against.
2. **Getter that overrides an interface member (`@override`)** — needs discussion; overrides are often kept near other overrides rather than the field block, so consider exempting `@override` getters.
3. **Extension methods / mixins** — should apply the same grouping rule within the extension/mixin body.
4. **Getter defined via arrow body vs block body** — both should flag identically; body syntax is irrelevant to placement.

---

## Alternatives Considered

- **Full member-ordering rule (fields → constructors → getters/setters → methods)** — deferred; broader ordering enforcement is a larger rule (`members_ordering`-style) and risks conflicting with existing style rules already in saropa_lints. This proposal scopes to getters only, matching the source package.

---

## Decision

Implemented (2026-09-04).

---

## Implementation Notes

- **Rule name string:** `getters_in_member_list`
- **Rule class:** `GettersInMemberListRule` in `lib/src/rules/code_quality/getters_in_member_list_rules.dart`
- **Category:** `code_quality` (chosen over `stylistic/` to match the sibling member-ordering rule `initializers_ordering`, which lives in `code_quality` despite also being a pure-convention rule)
- **Tier recommendation:** Pedantic, per the proposal's own justification (pure convention, no correctness impact, opt-in only). NOT wired into `lib/src/tiers.dart` — see below.
- **Detection:** walks `ClassDeclaration` / `MixinDeclaration` / `ExtensionDeclaration` member lists (via the `.bodyMembers` analyzer-12-compat shim in `lib/src/analyzer_compat.dart`, not raw `.members`) in source order, tracking two booleans: `hasEarlierPropertyMember` (a field/getter/setter has been seen) and `sawBehaviorMember` (a regular, non-getter/setter method has been seen). A plain (non-`@override`) getter is flagged only when both are true at the point it's encountered.
- **Deviation from the literal proposal text:** constructors are explicitly excluded from `sawBehaviorMember`. The proposal's own BAD/GOOD examples require this — the GOOD example places the constructor *after* the getter, and the BAD example's flagged getter trails a *method*, not the constructor that precedes it. Treating constructors as behavior members caused a false positive on the proposal's own GOOD-shaped test case (constructor-first, then field, then getter, then method — a common Dart idiom); fixed by leaving constructors uncounted by either tracking flag.
- **Edge case 2 (`@override` getters):** resolved as "exempt", per the proposal's own suggestion — an `@override` getter is never flagged regardless of its position.
- **Edge case 3 (extensions/mixins):** implemented — the same walk runs on `MixinDeclaration` and `ExtensionDeclaration` bodies, not just `ClassDeclaration`.
- **Files:**
  - `lib/src/rules/code_quality/getters_in_member_list_rules.dart` (rule)
  - `test/rules/code_quality/getters_in_member_list_test.dart` (5 oracle-backed unit tests, all passing)
  - `example/lib/code_quality/getters_in_member_list_fixture.dart` (fixture; verified firing exactly once, at the expected line, via a throwaway harness script — see Issues)
- **Issues / follow-up required by the task's own scope restriction:** per instruction, `lib/saropa_lints.dart` (`_allRuleFactories`), `lib/src/tiers.dart`, and `lib/src/rules/all_rules.dart` were deliberately NOT touched (avoids conflicting with other in-flight rule-addition tasks in this repo). Consequently the rule is **not yet reachable via the scan CLI or the analyzer plugin** — it exists only as a standalone class. Firing was verified two ways instead: (1) `dart test test/rules/code_quality/getters_in_member_list_test.dart` (5/5 pass, oracle harness instantiates the rule directly, bypassing the registry), and (2) a throwaway script running the same oracle harness against the actual fixture file content, confirming a single diagnostic at fixture line 24 matching the `// expect_lint:` marker on line 23. Before this rule is usable, someone must add `GettersInMemberListRule.new` to `_allRuleFactories` in `lib/saropa_lints.dart` and add `'getters_in_member_list'` to `pedanticOnlyRules` (or another tier set) in `lib/src/tiers.dart`; `all_rules.dart` needs no change since `code_quality` is already exported.
- **Unrelated observation:** mid-task, the newly-created rule and test files (but not the fixture) were deleted from disk by an unknown external process between two verification runs in this session — consistent with a concurrent/parallel process in the same working tree. Files were recreated from this session's own content and re-verified; flagging here in case it recurs.

---

## Commits

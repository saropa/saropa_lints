# PROPOSAL: Flag Getters Declared Outside the Class Member List Grouping

**Status: Implemented**

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

## Finish Report (2026-09-04)

### Issues

- **Proposal's own "Implementation Notes" / "Issues" section is stale and factually wrong.** It states `lib/saropa_lints.dart` (`_allRuleFactories`) and `lib/src/tiers.dart` were "deliberately NOT touched" and that the rule is "not yet reachable via the scan CLI or the analyzer plugin." That is false as of this review: `GettersInMemberListRule.new` is registered in `_allRuleFactories` (`lib/saropa_lints.dart:2918`), `'getters_in_member_list'` is in `pedanticOnlyRules` (`lib/src/tiers.dart:3325`), it's exported from `all_rules.dart:203`, and it's mapped in `rule_category_map.dart:922`. The rule is fully live. This stale text will mislead the next reader into re-doing registration work or filing a false "not wired up" bug — it should be corrected, not left standing.
- **Enums are not covered — a real false-negative gap, not just a documented limitation.** `runWithReporter` (lines 116-124) hooks `ClassDeclaration`, `MixinDeclaration`, `ExtensionDeclaration` but not `EnumDeclaration`. Enhanced enums (Dart 2.17+) can declare fields, getters, methods, and constructors exactly like a class body, so a getter scattered among enum methods is silently missed. This isn't a hard case: `lib/src/analyzer_compat.dart:94-101` already defines `EnumDeclaration.bodyMembers` (and `ExtensionTypeDeclaration.bodyMembers` at line 157-164), and `SaropaContext` already exposes `addEnumDeclaration`/`addExtensionTypeDeclaration` (`lib/src/native/saropa_context.dart:745`, `:770`) — `_checkMembers` already takes a plain `List<ClassMember>`, so both are a 4-line addition, not new plumbing.
- **CHANGELOG.md mislabels the tier.** The entry (`CHANGELOG.md` line 101) describes `getters_in_member_list` as "Stylistic opt-in," but the actual registration is in `pedanticOnlyRules`, not `stylisticRules`. Pedantic and Stylistic have different enablement semantics in this project (tier preset vs. opt-in rule pack) — a reader following the changelog to enable it via the stylistic pack won't get it.
- **No ROADMAP.md entry.** Grep of `ROADMAP.md` for `getters_in_member_list` / `GettersInMemberList` returns nothing. Per this project's own registration checklist (root `CLAUDE.md`, "Adding a New Lint Rule" step 3), every new rule needs a ROADMAP entry; this one is missing.

### Concerns

- **`@override` exemption is name-only, not type-checked.** Line 161's check is `a.name.name == 'override'` — a false positive is very unlikely (nobody names a custom annotation exactly `@override`), but it means the exemption would also silently apply to any hypothetical non-`dart:core` `@override`-named annotation. Low risk, but worth a one-line comment noting it's intentionally a syntactic check (matches how the rest of the codebase likely does override detection — not verified here).
- **Static getters/fields are not distinguished from instance ones.** A `static` getter declared after an instance method (or vice versa) is treated identically to instance members for grouping purposes. Static and instance members are frequently grouped separately by convention (statics at the top or bottom), so a class that intentionally separates `static final` constants from instance fields/getters could get a technically-correct-per-this-rule flag that fights an equally valid, different convention. Not a bug, but a plausible source of pushback once this rule sees real-world pedantic-tier usage.
- **Constructor exemption is a byproduct of matching two hand-picked examples, not a general design decision.** The rationale (lines 148-153, and proposal "Implementation Notes") is "the proposal's own GOOD/BAD examples require it." That's a legitimate reason, but it means the constructor-exclusion behavior was reverse-engineered from two examples rather than derived from a stated ordering policy (e.g., "constructors are body/init noise, not behavior"). Future edits to this rule should re-derive the rule from a stated policy, not just re-fit new examples, or the exemption will drift.
- **Fixture is not exercised by an automated `expect_lint`-runner tied to `dart test`.** Per the proposal's own "Issues" note, the fixture's correctness was checked once via "a throwaway harness script," not via a persisted test. `test/scan/fixture_lint_integration_test.dart` exists in this repo and may already do fixture-wide `expect_lint` verification for other rules — if `getters_in_member_list_fixture.dart` isn't wired into that (not confirmed either way here), a future edit to the rule could silently desync the fixture from the five inline-code oracle tests without any test failing.

### Opportunities

- **Extend `runWithReporter` to `addEnumDeclaration` and `addExtensionTypeDeclaration`.** As noted under Issues, the compat shim and context hooks already exist; this is two more `context.addXDeclaration(...)` lines reusing the existing `_checkMembers`, not a rewrite.
- **Fix the CHANGELOG tier label** (`Stylistic opt-in` → `Pedantic`) in the same pass as any other doc cleanup, since it's a one-line, low-risk correction.
- **Add a ROADMAP.md entry** to close the gap called out in root `CLAUDE.md`'s own rule-addition checklist.

### Recommendations

1. **(High)** Correct the stale "not wired into tiers.dart" / "not reachable" claims in this proposal's own Implementation Notes section — leaving factually wrong status text in a proposal marked "Implemented" will cost someone real time later.
2. **(High)** Fix the CHANGELOG.md tier mislabel (Stylistic → Pedantic) so users following the changelog can actually find/enable the rule.
3. **(Medium)** Add `EnumDeclaration` (and ideally `ExtensionTypeDeclaration`) coverage — cheap, closes a real false-negative gap, and the plumbing is already in the codebase.
4. **(Medium)** Add a ROADMAP.md entry per the project's own checklist.
5. **(Low)** Add test coverage for the currently-untested branches: a setter used as the "earlier property member," an operator method counted as behavior, `MixinDeclaration`/`ExtensionDeclaration` bodies (the rule explicitly handles them per "Implementation Notes" edge case 3, but no test or fixture exercises either), and multiple getters after a single offending method (verify each is flagged independently).
6. **(Low)** Confirm whether `test/scan/fixture_lint_integration_test.dart` (or equivalent) actually runs `expect_lint` assertions against `getters_in_member_list_fixture.dart`; if not, either wire it in or note explicitly that fixture verification for this rule is manual-only.

## Commits

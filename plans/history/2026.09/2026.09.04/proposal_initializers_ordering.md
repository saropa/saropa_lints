# PROPOSAL: Require Constructor Initializer List to Match Field Declaration Order

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `getters_in_member_list`

---

## Summary

Add `initializers_ordering` to flag a constructor initializer list (`: field1 = x, field2 = y, ...`) whose entries are ordered differently from the order the corresponding fields are declared in the class body. Dart already evaluates the class's field initializers top-to-bottom regardless of initializer-list order, so mismatched ordering is purely a readability trap.

**Closes gap:** `many_lints` `initializers_ordering` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a constructor's initializer list order doesn't match field declaration order, a reader checking "what does field X get initialized to" has to cross-reference two different orderings instead of scanning linearly. This is purely cosmetic but cheap to enforce and removes a recurring nit in code review.

---

## Detection / Behavior

Flag a `ConstructorDeclaration` whose `initializers` (excluding `super(...)`/`this(...)` redirecting calls and assertion initializers) are not in the same relative order as the matching field declarations in the enclosing class.

### Should flag (bad code)

```dart
class Point {
  final int x;
  final int y;

  Point(int a, int b)
      : y = b, // LINT — y initialized before x, but x is declared first
        x = a;
}
```

### Should pass (good code)

```dart
class Point {
  final int x;
  final int y;

  Point(int a, int b)
      : x = a, // OK — matches declaration order
        y = b;
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: Cosmetic ordering rule with zero runtime/correctness impact.

---

## Edge Cases

1. **Initializer list mixing field assignments with `assert(...)`** — asserts are excluded from the ordering comparison; only field-assignment initializers are checked against each other.
2. **`super(...)` call present in the initializer list** — should not itself count toward ordering (it isn't a field-declaration-order concept); only relative order among field assignments is checked.
3. **Fields declared via constructor shorthand (`this.x`) mixed with explicit initializer-list assignments for other fields** — should compare only the initializer-list entries against the subset of fields they touch, in declared order.
4. **Single-field initializer list** — should pass; nothing to compare.

---

## Alternatives Considered

- **Auto-fix that reorders the initializer list** — recommended as a companion quick fix since reordering is mechanical and safe (no side effects between pure field assignments); include in initial implementation if straightforward.

---

## Decision

Implemented.

---

## Implementation Notes

- **Rule class:** `InitializersOrderingRule` in `lib/src/rules/code_quality/initializers_ordering_rules.dart` (pre-existing from a prior interrupted session; only the fixture/test/bugfix work was done in this pass).
- **Rule name string:** `initializers_ordering`.
- **Tier:** Pedantic, per the proposal's own "Proposed Tier" section — cosmetic ordering rule with zero runtime/correctness impact, consistent with the proposal's justification. Fully registered in all three required places: `lib/saropa_lints.dart`, `lib/src/tiers.dart` (`pedanticOnlyRules`), and `lib/src/rules/all_rules.dart`.
- **Files added:**
  - `example/lib/code_quality/initializers_ordering_fixture.dart` — 6 classes: 2 BAD (two-field swap, three-field partial regression) with line-precise `// expect_lint: initializers_ordering` markers, and 4 GOOD near-misses (already-ordered fields, `assert(...)` interleaved between correctly-ordered fields, a `super(...)` redirect call, and a single-field initializer list).
  - `test/rules/code_quality/initializers_ordering_test.dart` — 6 oracle-backed tests via `test/support/resolved_rule_harness.dart` (`reportedRuleCodes`), mirroring the fixture's cases.
- **Bug found and fixed in the pre-existing rule class** (it did not compile, then did not fire, before this pass):
  1. `_fieldDeclarationOrder` called `parent.members` directly on a `ClassDeclaration`, which does not compile against the pinned `analyzer` 12.1.0 — `ClassDeclaration.members` was removed; members now live under `.body` (`ClassBody`/`BlockClassBody`). Fixed by using the repo's existing `.bodyMembers` compat shim (`lib/src/analyzer_compat.dart`), the same pattern used elsewhere in the codebase (e.g. `documentation_rules.dart`).
  2. Even after fixing the compile error, the rule never fired: `_fieldDeclarationOrder` used `node.parent` (the `ConstructorDeclaration`'s direct AST parent) and checked `is! ClassDeclaration`. In analyzer 12's declaring-constructors AST, a constructor's direct parent is the intermediate `ClassBody` node (`BlockClassBody`), not `ClassDeclaration` — so the type check always failed, `declOrder` was always empty, and the rule silently never reported. Fixed by walking up with `node.thisOrAncestorOfType<ClassDeclaration>()` instead, which is stable across analyzer AST-shape versions and is the pattern used elsewhere in this codebase (e.g. `structure_rules.dart`, `avoid_mounted_check_in_finally_rules.dart`).
- **False-positive risks checked and covered by fixture/tests:** `assert(...)` initializers and `super(...)`/`this(...)` redirecting calls are correctly excluded from the ordering comparison (verified — GOOD cases pass); fields not found in the enclosing class are skipped rather than flagged (defensive, not directly exercised by a fixture case since it requires an unusual resolution edge case); single-initializer lists never fire (verified). No `.contains()`-style substring matching is used — detection is purely structural (declaration-index comparison), so no name-matching false-positive class applies here.
- **Verification:** `dart test test/rules/code_quality/initializers_ordering_test.dart` — 6/6 passing (resolved-analyzer oracle harness, not the syntactic scan CLI). Confirms both BAD fixture cases are flagged and all 4 GOOD cases are silent.

---

## Finish Report (2026-09-04)

### Issues
None identified. All 6 existing tests (`test/rules/code_quality/initializers_ordering_test.dart`) pass. Registration is complete in all three required places (`lib/saropa_lints.dart:2919`, `lib/src/tiers.dart:3326` under `pedanticOnlyRules`, `lib/src/rules/all_rules.dart:204`), contradicting the "Not wired into tiers.dart yet" note this proposal's own Implementation Notes section left behind — that note is now stale and should be corrected or removed.

### Concerns
- **Enclosing-declaration scope is `ClassDeclaration` only** (`initializers_ordering_rules.dart:156`, `_fieldDeclarationOrder`). `thisOrAncestorOfType<ClassDeclaration>()` returns `null` for a constructor inside an `EnumDeclaration`. Enum constructors commonly have initializer lists (e.g. `const Suit(this.symbol) : ...` isn't representative, but multi-field enum constructors with explicit `ConstructorFieldInitializer` entries do exist), and those are silently skipped — a false-negative gap, not tested or documented as an explicit exclusion. Worth either extending to enums or stating the exclusion explicitly in the doc comment (currently only mentions "assert/super/this excluded," not "enums excluded").
- **`requiredPatterns => const {':'}`** (line 77): the comment claims this "skips parsing for the large fraction of files with no constructors at all," but a bare `':'` substring matches ternary expressions, named-parameter defaults, switch/case labels, and any `dart:...`/`package:...` import string — i.e. almost every non-trivial Dart file. The pre-filter is real but far weaker than the comment implies; it will rarely skip a file in practice. Not a correctness bug, just a misleading efficiency claim.
- **Only the first regression is reported per constructor** (loop `return`s at the first `indices[i] < indices[i-1]`, lines 135-140). A constructor with multiple out-of-order pairs needs multiple lint-fix-relint cycles to fully clean up. Standard practice for this rule shape, but worth a one-line doc note since a reader might expect all violations flagged at once.
- Bug-history in this same file's Implementation Notes (two real defects: `.members` not compiling against analyzer 12, then `node.parent` never matching `ClassDeclaration` under the declaring-constructors AST shape) shows the fragility of relying on AST shape assumptions here. The fix (`thisOrAncestorOfType`) is the right general pattern, but it's evidence this exact code path failed silently once already (rule registered, tests green due to being new, but zero real detections) — worth a smoke check after any future analyzer bump that this rule still fires, since the failure mode is silent-zero-lints, not a crash.

### Opportunities
- **Edge case 3 from this proposal is implemented but untested.** The proposal explicitly calls out "fields declared via constructor shorthand (`this.x`) mixed with explicit initializer-list assignments for other fields" (line 68) as a case to handle, and the implementation does handle it correctly (only `ConstructorFieldInitializer` nodes participate; `this.x` shorthand params never enter `fieldInitializers`, so they're implicitly skipped rather than mis-ordering the comparison). But neither the fixture nor the test file has a case exercising this — a class with a `this.`-shorthand parameter plus 2+ explicit initializer-list entries, in both a passing and failing arrangement. This is the one edge case in the proposal with zero direct coverage; the "fields not found in the enclosing class are skipped" comment at line 118-121 covers a different (unresolved-field) scenario, not this one.
- **Auto-fix companion, proposed as "Alternatives Considered" (line 75) and flagged as "recommended... if straightforward,"** was not implemented. Reordering `ConstructorFieldInitializer` entries to match `declOrder` is a pure structural transform (no side-effect risk between field assignments, per the proposal's own reasoning) and would be a good quick-fix candidate for a follow-up pass — ordering issues are exactly the class of lint people want auto-fixed rather than hand-corrected.
- The declaration-index map building (`_fieldDeclarationOrder`) walks every `FieldDeclaration` including static fields, which cannot appear in a constructor initializer list. This is harmless (relative order is preserved either way) but the map could be pre-filtered on `!member.fields.isStatic` for a marginally cleaner mental model — not a bug, low priority.

### Recommendations
1. **(Coverage)** Add one fixture class + one test case for the `this.x` shorthand mixed with explicit field initializers (edge case 3) — both a GOOD case (correctly ordered subset) and, if easy to construct, confirmation that a `this.x` field's position never taints the comparison of the remaining explicit entries.
2. **(Doc accuracy)** Correct or remove the stale "Not wired into `lib/src/tiers.dart` yet" line in this file's own Implementation Notes section — the rule is fully registered in all three required places today.
3. **(Doc precision, low priority)** Add "enum declarations are not currently checked" to the rule's DartDoc alongside the existing assert/super/this exclusions, so the scope limitation is discoverable without reading the source.
4. **(Follow-up, optional)** Consider the auto-fix companion the proposal already flagged as low-risk and recommended — natural next increment, not required for this rule to ship as-is.

## Follow-up (2026-09-04)

All four Finish Report recommendations addressed in `lib/src/rules/code_quality/initializers_ordering_rules.dart`:

1. **Enum support added** (Concern + Recommendation 3, reversed): rather than documenting enums as excluded, `_fieldDeclarationOrder` now also walks `EnumDeclaration.bodyMembers` when the constructor's enclosing declaration is an enum, not a class. Two new fixture cases (`EnumBad`/`EnumOk`) and two new tests cover this.
2. **`this.x` shorthand coverage added** (Opportunity/Recommendation 1): `ThisShorthandOk`/`ThisShorthandBad` fixture classes plus two matching tests confirm the shorthand field's position is invisible to the ordering comparison and does not shield an out-of-order pair among the remaining explicit entries.
3. **Doc accuracy fixed** (Recommendation 2): the stale "Not wired into tiers.dart yet" line above is corrected.
4. **`requiredPatterns` comment corrected** (Concern 2): no longer claims the `:` pre-filter skips "the large fraction of files with no constructors" — now states plainly that it is a weak filter that rarely triggers in practice, kept because it is still a correct free check.
5. **Static-field filtering added** (Opportunity 3, minor): `_fieldDeclarationOrder` now skips `FieldDeclaration`s with `isStatic == true` when building the index map.
6. **Multi-regression behavior documented** (Concern 3): the rule's doc comment now states only the first out-of-order entry is reported per constructor.
7. **Auto-fix companion (Recommendation 4) NOT implemented** — deferred as an optional follow-up, consistent with the Finish Report's own "optional" framing; not required for this rule to ship.

Verification: `dart test test/rules/code_quality/initializers_ordering_test.dart` — 10/10 passing (6 original + 4 new: this.x-ok, this.x-bad, enum-bad, enum-ok).

## Commits

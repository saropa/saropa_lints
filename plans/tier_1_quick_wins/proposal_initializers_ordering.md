# PROPOSAL: Require Constructor Initializer List to Match Field Declaration Order

**Status: Open**

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
- **Tier:** Recommend **Pedantic**, per the proposal's own "Proposed Tier" section — cosmetic ordering rule with zero runtime/correctness impact, consistent with the proposal's justification. (Not wired into `lib/src/tiers.dart` yet — central registration is out of scope for this pass per instructions; someone still needs to add the name string to `pedanticOnlyRules` and the `MyRule.new` factory to `lib/saropa_lints.dart`.)
- **Files added:**
  - `example/lib/code_quality/initializers_ordering_fixture.dart` — 6 classes: 2 BAD (two-field swap, three-field partial regression) with line-precise `// expect_lint: initializers_ordering` markers, and 4 GOOD near-misses (already-ordered fields, `assert(...)` interleaved between correctly-ordered fields, a `super(...)` redirect call, and a single-field initializer list).
  - `test/rules/code_quality/initializers_ordering_test.dart` — 6 oracle-backed tests via `test/support/resolved_rule_harness.dart` (`reportedRuleCodes`), mirroring the fixture's cases.
- **Bug found and fixed in the pre-existing rule class** (it did not compile, then did not fire, before this pass):
  1. `_fieldDeclarationOrder` called `parent.members` directly on a `ClassDeclaration`, which does not compile against the pinned `analyzer` 12.1.0 — `ClassDeclaration.members` was removed; members now live under `.body` (`ClassBody`/`BlockClassBody`). Fixed by using the repo's existing `.bodyMembers` compat shim (`lib/src/analyzer_compat.dart`), the same pattern used elsewhere in the codebase (e.g. `documentation_rules.dart`).
  2. Even after fixing the compile error, the rule never fired: `_fieldDeclarationOrder` used `node.parent` (the `ConstructorDeclaration`'s direct AST parent) and checked `is! ClassDeclaration`. In analyzer 12's declaring-constructors AST, a constructor's direct parent is the intermediate `ClassBody` node (`BlockClassBody`), not `ClassDeclaration` — so the type check always failed, `declOrder` was always empty, and the rule silently never reported. Fixed by walking up with `node.thisOrAncestorOfType<ClassDeclaration>()` instead, which is stable across analyzer AST-shape versions and is the pattern used elsewhere in this codebase (e.g. `structure_rules.dart`, `avoid_mounted_check_in_finally_rules.dart`).
- **False-positive risks checked and covered by fixture/tests:** `assert(...)` initializers and `super(...)`/`this(...)` redirecting calls are correctly excluded from the ordering comparison (verified — GOOD cases pass); fields not found in the enclosing class are skipped rather than flagged (defensive, not directly exercised by a fixture case since it requires an unusual resolution edge case); single-initializer lists never fire (verified). No `.contains()`-style substring matching is used — detection is purely structural (declaration-index comparison), so no name-matching false-positive class applies here.
- **Verification:** `dart test test/rules/code_quality/initializers_ordering_test.dart` — 6/6 passing (resolved-analyzer oracle harness, not the syntactic scan CLI). Confirms both BAD fixture cases are flagged and all 4 GOOD cases are silent.

---

## Commits

# Tier 1 Quick Wins — Batch 1 Implementation

Implemented 3 new lint rules from the tier_1_quick_wins proposal backlog, identified 13 duplicate proposals already covered by existing rules, and hardened all 3 new rules based on code review findings.

## Rules Implemented

### avoid_focused_tests (Essential)
- **File:** `lib/src/rules/testing/test_rules.dart`
- **Detection:** Flags `test()`, `testWidgets()`, and `group()` calls with `solo: true` named argument
- **Tier:** Essential (WARNING severity) — solo:true silently disables the rest of the test suite in CI
- **Scoped to:** `FileType.test` only, with `requiredPatterns => {'solo'}` pre-filter

### avoid_exit_outside_entrypoint (Recommended)
- **File:** `lib/src/rules/flow/control_flow_rules.dart`
- **Detection:** Flags `exit()` calls outside the top-level `main()` function
- **Tier:** Recommended (WARNING severity) — process-kill hidden in non-entrypoint code
- **Handles:** Prefix-imported `io.exit()` (still flagged), `Isolate.exit()` (correctly skipped via uppercase-target heuristic)

### avoid_labeled_statements (Comprehensive)
- **File:** `lib/src/rules/flow/control_flow_rules.dart`
- **Detection:** Uses `RecursiveAstVisitor` via `context.addCompilationUnit()` because `LabeledStatement` has no dedicated visitor callback
- **Tier:** Comprehensive (INFO severity) — readability rule, not a correctness check
- **Cost:** `RuleCost.high` (full AST walk per file)

## Duplicates Identified (13 proposals)

Marked as Duplicate in proposal docs — already covered by existing rules:
1. `avoid_empty_catch` → `AvoidSwallowingExceptionsRule`
2. `avoid_continue` → `AvoidContinueRule`
3. `prefer_first` → `PreferFirstRule`
4. `prefer_first_or_null` → `PreferFirstRule` alias
5. `avoid_single_child_in_flex` → `AvoidSingleChildColumnRowRule`
6. `avoid_positional_record_fields` → `AvoidPositionalRecordFieldAccessRule`
7. `avoid_duplicate_collection_elements` → multiple existing duplicate-element rules
8. `prefer_stateless_widgets` → `AvoidUnnecessaryStatefulWidgetsRule`
9. `prefer_center_over_align` → already implemented
10. `prefer_primary_constructors` → `PreferPrimaryConstructorRule`
11. `empty_container` → `AvoidUnnecessaryContainersRule`
12. `prefer_iterable_any` → `PreferAnyOrEveryRule`
13. `prefer_iterable_every` → `PreferAnyOrEveryRule`

## Code Review Findings (all fixed)

1. **Missing testWidgets in solo:true check** — `AvoidFocusedTestsRule` only matched `test` and `group`, omitting `testWidgets`. Fixed.
2. **Impact/severity mismatch** — `LintImpact.error` with `DiagnosticSeverity.WARNING`. Aligned to `LintImpact.warning`.
3. **Prefix-imported exit() bypassed rule** — `io.exit(1)` was silently exempted because `node.target != null`. Fixed with uppercase-target heuristic to distinguish class receivers from library prefixes.
4. **RuleCost.low for full AST walk** — `AvoidLabeledStatementsRule` uses `RecursiveAstVisitor` but declared low cost. Changed to `RuleCost.high`.
5. **Missing requiredPatterns** — `AvoidFocusedTestsRule` scanned every test file. Added `requiredPatterns => {'solo'}`.

## Test Results

- `test/rules/testing/test_rules_test.dart` — 63 pass
- `test/rules/flow/control_flow_rules_test.dart` — 72 pass
- `test/integrity/` — 2689 pass
- Total after fixes: 2824 pass

## Finish Report (2026-09-03)

Three new lint rules shipped as the first batch of the tier_1_quick_wins backlog: `avoid_focused_tests` (Essential), `avoid_exit_outside_entrypoint` (Recommended), and `avoid_labeled_statements` (Comprehensive). All three are registered in `_allRuleFactories`, assigned to correct tiers, and pass instantiation + integrity tests.

Thirteen proposals were identified as duplicates of already-implemented rules and marked accordingly in their proposal docs.

Five code review findings were discovered and fixed: missing `testWidgets` coverage, impact/severity alignment, prefix-import bypass, cost misclassification, and missing pre-filter patterns.

Remaining backlog: ~105 genuinely new proposals in `plans/tier_1_quick_wins/` still at Status: Open.

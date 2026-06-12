# Quick Fix Batches 16–18 (2026-06-10)

Continuation of the incremental QUICK_FIX_PLAN program to expand quick-fix coverage. Three batches landed, adding quick fixes to 8 previously fix-less rules and dropping the quick-fix audit from 1701 to 1693 unfixed rules. This record was split out of the active `plans/QUICK_FIX_PLAN.md` so the active plan carries only remaining work.

## Batch 16 — control flow + structure (EASY/MEDIUM)

**+4 fixes (2 new producers, 1 reuse covering 3 rules):**

- `avoid_unnecessary_if` and `prefer_returning_condition` — `ReturnConditionFix` (`lib/src/fixes/control_flow/return_condition_fix.dart`). Both report at the `IfStatement`; the producer reconstructs `return <cond>;` (then-branch returns `true`) or `return !(<cond>);` (then-branch returns `false`), wrapping the condition in parens on negation. For the no-else `avoid_unnecessary_if` shape it also consumes the following sibling `return <opposite-bool>;`.
- `avoid_collapsible_if` — `CollapseNestedIfFix` (`lib/src/fixes/control_flow/collapse_nested_if_fix.dart`). Merges `if (a) { if (b) { body } }` into `if ((a) && (b)) body`, parenthesizing both conditions so a low-precedence operator can't bind incorrectly against the inserted `&&`.
- `avoid_classes_with_only_static_members` — reuses `AddAbstractFinalFix` (rule reports at the class name token; the fix walks up to the `ClassDeclaration` and inserts `abstract final `, same idiom as `prefer_abstract_final_static_class`).

All 4 wired; presence test +4 (192 pass). `dart analyze --fatal-infos` clean. Existing example fixtures cover all four rules. Audit 1701 → 1697 (Δ = −4). Commit `077794c9`.

## Batch 17 — null-aware call rewrite (MEDIUM)

**+1 fix:**

- `prefer_null_aware_method_calls` — `PreferNullAwareCallFix` (`lib/src/fixes/control_flow/prefer_null_aware_call_fix.dart`). Handles both reported shapes: `if (x != null) { x.foo(args); }` → `x?.foo(args);` and `x != null ? x.foo() : null` → `x?.foo()`. Inserts `?` before the receiver's `.` token, reusing the original source for receiver/member/args verbatim. Ternary is matched before the enclosing `if` so a guard ternary nested inside an `if` resolves to the correct node.

Wired; presence test +1 (193 pass). `dart analyze --fatal-infos` clean. Existing fixture `example/lib/control_flow/prefer_null_aware_method_calls_fixture.dart` covers it. Audit 1697 → 1696 (Δ = −1). Commit `077794c9`.

## Batch 18 — deletion fixes: named-argument + redundant nullable (EASY)

**+3 fixes (2 new producers, 1 reused across 2 rules):**

- `avoid_icon_size_override` and `avoid_riverpod_string_provider_name` — `RemoveNamedArgumentFix` (`lib/src/fixes/common/remove_named_argument_fix.dart`). Both rules report at the `NamedExpression`. Deletes the argument plus its separating comma (trailing comma preferred, else leading) so the surviving argument list stays valid; `dart format` tidies residual whitespace.
- `avoid_nullable_parameters_with_default_values` — `RemoveTypeQuestionFix` (`lib/src/fixes/type/remove_type_question_fix.dart`). Rule reports at the parameter `TypeAnnotation`; deletes the single trailing `?` char (uniform across named/generic/function/record forms), guarded by a check that the annotation really ends in `?`.

Wired; presence test +3 (196 pass) — added imports for `widget_patterns_avoid_prefer_rules.dart` and `riverpod_rules.dart`. New/modified files `dart analyze --fatal-infos` clean (4 pre-existing `unnecessary_null_comparison`/`dead_code` warnings at `type_rules.dart:391`/`2378` predate this work and are unrelated). Fixtures already cover all three rules. Audit 1696 → 1693 (Δ = −3). Commit `b0629b8c`.

## Finish Report (2026-06-10)

**Scope (LINTER variant, A):** Dart analyzer-plugin quick fixes. 4 new fix producers wired to 8 rules across Batches 16–18. No `extension/` changes.

**Files added:**

- `lib/src/fixes/control_flow/return_condition_fix.dart`
- `lib/src/fixes/control_flow/collapse_nested_if_fix.dart`
- `lib/src/fixes/control_flow/prefer_null_aware_call_fix.dart`
- `lib/src/fixes/common/remove_named_argument_fix.dart`
- `lib/src/fixes/type/remove_type_question_fix.dart`

**Files modified:** `lib/src/rules/flow/control_flow_rules.dart`, `lib/src/rules/architecture/structure_rules.dart`, `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`, `lib/src/rules/packages/riverpod_rules.dart`, `lib/src/rules/data/type_rules.dart`, `test/scan/rule_quick_fix_presence_test.dart`, `CHANGELOG.md`, `plans/QUICK_FIX_PLAN.md`.

**Validation:** `dart analyze --fatal-infos` clean on all new/modified files; presence test 196 pass (+8); control_flow / structure / integrity / code_quality / type / riverpod rule suites pass with no regressions; existing `example/` fixtures cover all 8 rules; audit 1701 → 1693 (−8). Commits `077794c9`, `b0629b8c`.

**No bug archive** — no `bugs/*.md` closed.

# Comment coverage backfill queue (DOC-01)

**Date:** 2026-06-10
**Source:** `scripts/modules/_code_comment_metrics.py` (publish-banner heuristics).
**Parent plan:** [COMMENT_COVERAGE_PLAN.md](../../../COMMENT_COVERAGE_PLAN.md) — satisfies DOC-01.

## How this queue was produced

Scanned the same roots the publish banner uses — `lib/`, `test/`, `bin/`,
`packages/*/lib/`, `extension/src/`, `scripts/` — counting "comment lines"
with the module's string-aware heuristics (`//`, `/* */` outside strings for
Dart/TS; `tokenize.COMMENT` for Python). Files under 40 physical lines are
excluded: too small to carry the Part 2 documentation surface that makes a
backfill batch worthwhile.

Ranking: zero-comment files first, then ascending comment density, with larger
files breaking ties — the order Part 1 of the plan specifies.

**What this ranking catches:** files that are statistical outliers on raw
comment-line density. **What it cannot catch:** whether existing comments meet
the Part 2 bar (WHY not WHAT, invariants, branch/loop intent), or whether a
high-density file is full of noise. Density is a queue signal, never proof of
quality — a file can leave this list and still fail Part 2.

- Total files scanned (>= 40 lines): **1108**
- Zero-comment files: **0** (Wave 1/2 added at least a thin note everywhere)

## Overall top 25 (metric-faithful)

| # | File | Lang | Lines | Comment lines | Density |
| - | ---- | ---- | -----:| -------------:| -------:|
| 1 | `test/report/violation_export_test.dart` | dart:test | 846 | 10 | 1.2% |
| 2 | `test/project_health/health_config_test.dart` | dart:test | 80 | 1 | 1.2% |
| 3 | `extension/src/vibrancy/views/report-script.ts` | ts:ext | 1,463 | 19 | 1.3% |
| 4 | `lib/src/cli/project_health/health_html_template.dart` | dart:lib | 602 | 8 | 1.3% |
| 5 | `extension/src/views/violationsDashboardStyles.ts` | ts:ext | 1,297 | 18 | 1.4% |
| 6 | `test/project_health/maintainability_index_test.dart` | dart:test | 72 | 1 | 1.4% |
| 7 | `extension/src/vibrancy/views/report-styles.ts` | ts:ext | 930 | 13 | 1.4% |
| 8 | `test/report/violation_parser_test.dart` | dart:test | 278 | 4 | 1.4% |
| 9 | `test/rules/widget/widget_patterns_rules_test.dart` | dart:test | 797 | 12 | 1.5% |
| 10 | `extension/src/test/vibrancy/problems/problem-actions.test.ts` | ts:ext | 320 | 5 | 1.6% |
| 11 | `test/rules/platforms/ios_security_quick_fix_presence_test.dart` | dart:test | 191 | 3 | 1.6% |
| 12 | `scripts/modules/_code_comment_metrics.py` | py:scripts | 692 | 11 | 1.6% |
| 13 | `extension/src/test/vibrancy/services/ci-generator.test.ts` | ts:ext | 313 | 5 | 1.6% |
| 14 | `extension/src/test/vibrancy/providers/tree-commands.test.ts` | ts:ext | 438 | 7 | 1.6% |
| 15 | `test/rules/widget/widget_layout_rules_test.dart` | dart:test | 553 | 9 | 1.6% |
| 16 | `test/rules/code_quality/code_quality_rules_test.dart` | dart:test | 784 | 13 | 1.7% |
| 17 | `extension/src/test/vibrancy/providers/tree-items.test.ts` | ts:ext | 596 | 10 | 1.7% |
| 18 | `extension/src/test/rulePacks/rulePackYaml.test.ts` | ts:ext | 119 | 2 | 1.7% |
| 19 | `test/rules/platforms/ios_rules_test.dart` | dart:test | 650 | 11 | 1.7% |
| 20 | `extension/src/test/vibrancy/services/indicator-config.test.ts` | ts:ext | 118 | 2 | 1.7% |
| 21 | `extension/src/test/vibrancy/state/context-state.test.ts` | ts:ext | 118 | 2 | 1.7% |
| 22 | `extension/src/test/vibrancy/scoring/diff-narrator.test.ts` | ts:ext | 117 | 2 | 1.7% |
| 23 | `test/rules/core/naming_style_rules_test.dart` | dart:test | 291 | 5 | 1.7% |
| 24 | `test/rules/stylistic/stylistic_control_flow_rules_test.dart` | dart:test | 403 | 7 | 1.7% |
| 25 | `extension/src/test/vibrancy/services/save-task-runner.test.ts` | ts:ext | 115 | 2 | 1.7% |

## lib/ product code — top 15 (DOC-02 candidates)

The overall ranking is dominated by test and webview files; `lib/` product
code is the highest-risk surface, so this break-out is the recommended source
for the first DOC-02 batch (pick the top 10).

| # | File | Lang | Lines | Comment lines | Density |
| - | ---- | ---- | -----:| -------------:| -------:|
| 1 | `lib/src/cli/project_health/health_html_template.dart` | dart:lib | 602 | 8 | 1.3% |
| 2 | `lib/src/cli/cross_file_analyzer.dart` | dart:lib | 738 | 13 | 1.8% |
| 3 | `lib/src/cli/cross_file_html_reporter.dart` | dart:lib | 157 | 3 | 1.9% |
| 4 | `lib/src/init/init_runner.dart` | dart:lib | 750 | 17 | 2.3% |
| 5 | `lib/src/cli/cross_file_duplicates.dart` | dart:lib | 77 | 2 | 2.6% |
| 6 | `lib/src/cli/cross_file_dead_imports_semantic.dart` | dart:lib | 188 | 5 | 2.7% |
| 7 | `lib/src/cli/cross_file_unused_symbols_semantic.dart` | dart:lib | 250 | 7 | 2.8% |
| 8 | `lib/src/report/diagnostic_statistics.dart` | dart:lib | 267 | 8 | 3.0% |
| 9 | `lib/src/init/composite_plugin_scaffold.dart` | dart:lib | 98 | 3 | 3.1% |
| 10 | `lib/src/fixes/control_flow/use_positive_form_fix.dart` | dart:lib | 65 | 2 | 3.1% |
| 11 | `lib/src/init/preflight.dart` | dart:lib | 188 | 6 | 3.2% |
| 12 | `lib/src/fixes/code_quality/prefer_returning_conditional_expressions_fix.dart` | dart:lib | 61 | 2 | 3.3% |
| 13 | `lib/src/fixes/unnecessary_code/remove_unnecessary_enum_argument_fix.dart` | dart:lib | 58 | 2 | 3.4% |
| 14 | `lib/src/fixes/control_flow/invert_operator_fix.dart` | dart:lib | 57 | 2 | 3.5% |
| 15 | `lib/src/fixes/widget_layout/replace_shrink_wrap_true_with_false_fix.dart` | dart:lib | 57 | 2 | 3.5% |

## Re-running

```
py -3 -P d:/tmp/comment_queue.py   # ad-hoc generator (throwaway)
```

Re-rank on demand; this snapshot is a queue, not a definition of "done".

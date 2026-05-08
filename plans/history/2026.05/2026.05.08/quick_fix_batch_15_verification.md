# Quick-fix Batch 15 — verification record

**Date:** 2026-05-08  
**Plan slice:** `plans/QUICK_FIX_PLAN.md` Batch 15

## Scope

- `avoid_redundant_semantics` — `UnwrapRedundantSemanticsFix`
- `require_baseline_text_baseline` — `AddColumnTextBaselineFix`
- `avoid_unconstrained_dialog_column` — `AddMainAxisSizeMinFix`

## Evidence

- Fix producers under `lib/src/fixes/accessibility/` and `lib/src/fixes/widget_layout/`.
- Presence regression: `dart test test/scan/rule_quick_fix_presence_test.dart`.
- Fixtures: `example/lib/accessibility/avoid_redundant_semantics_fixture.dart` (expanded); baseline/dialog cases already live in `example/lib/widgets/layout_crash_rules_fixture.dart`.

## Doc repair

`widget_layout_constraints_rules.dart` carried a misplaced `avoid_spacer_in_wrap` section header/doc block immediately before `RequireBaselineTextBaselineRule`; it was corrected to `require_baseline_text_baseline` documentation (Spacer-in-Wrap remains implemented in `widget_layout_flex_scroll_rules.dart`).

## Audit delta

Re-run `python scripts/list_rules_without_fixes.py` after merge; expect net **−3** rules lacking fix producers vs the 2026-05-08 baseline (**1698** / **109**).

# Quick-fix Batch 14 — verification record

**Date:** 2026-05-08  
**Plan slice:** QF-03 / `plans/QUICK_FIX_PLAN.md` Batch 14 candidate set

## Scope

Mechanical fixes for three structure/import rules:

- `avoid_duplicate_exports`
- `avoid_duplicate_named_imports`
- `prefer_trailing_underscore_for_unused`

## Evidence

- Fix wiring: producers registered via `fixGenerators` on each rule (`lib/src/rules/structure_rules.dart` and associated fix producers under `lib/src/fixes/`).
- Presence regression: `dart test test/scan/rule_quick_fix_presence_test.dart` passes (2026-05-08).
- Audit delta snapshot (same day):

  ```
  Quick-fix audit: 1698 rule(s) lack fix producers across 109 rule file(s).
  ```

  Source: `python scripts/list_rules_without_fixes.py` (script prints summary line; full list under `reports/<date>/…_list_rules_without_fixes.log`).

## Follow-up

Treat the 1698 / 109 figures as the post–Batch 14 baseline when planning Batch 15+; re-run the script after each batch and append a dated row here or in sibling history files.

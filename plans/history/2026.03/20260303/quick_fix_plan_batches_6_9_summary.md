# Quick Fix Plan — Batches 6–9 completed (summary)

**Completed:** 2026-03-03. **Delivered:** +10 quick fixes (no new rules, no tier changes).

**Rules that received quick fixes:** `avoid_synchronous_file_io`, `avoid_constant_assert_conditions`, `avoid_duplicate_switch_case_conditions`, `avoid_redundant_else`, `avoid_adjacent_strings`, `avoid_duplicate_map_keys`, `avoid_unconditional_break`, `no_equal_then_else`, `avoid_only_rethrow`, `avoid_returning_null_for_void`.

**Fix classes added:** ReplaceSyncFileIoFix, RemoveConstantAssertFix, RemoveDuplicateSwitchCaseFix, RemoveRedundantElseFix, CombineAdjacentStringsFix, RemoveDuplicateMapEntryFix, RemoveUnconditionalBreakFix, ReplaceWithThenBranchFix, RemoveTryCatchOnlyRethrowFix, ReplaceReturnNullWithReturnFix.

**Tests:** Unit tests added in performance_rules_test, control_flow_rules_test, code_quality_rules_test, collection_rules_test, exception_rules_test, return_rules_test (each verifies `rule.fixGenerators` is not empty).

**Full plan and checklist:** See [QUICK_FIX_PLAN.md](../QUICK_FIX_PLAN.md) in bugs (retained for future batches).

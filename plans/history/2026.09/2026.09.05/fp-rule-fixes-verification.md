# False-Positive Rule Fixes — Verification and Bug Archival

A self-scan of `lib/` against the comprehensive tier reported 305 findings, of
which 295 were false positives across 13 rules. All 12 rule-level fixes (one rule
— `require_ios_deployment_target_consistency` — was already fixed) were
implemented in a prior session. This session verified and closed the work.

## Finish Report (2026-09-05)

### Changes verified

All 12 rule fixes were confirmed working via:

1. **Unit tests** — 573 tests across 10 test suites, 0 failures.
2. **Self-scan** — `dart run saropa_lints scan lib/ --tier comprehensive --format json`
   on the fixed codebase. Key reductions from the original 305 findings:
   - `avoid_stack_trace_in_production`: 49 → 0
   - `avoid_platform_specific_imports`: 46 → 5
   - `require_catch_logging`: 25 → 2
   - `avoid_global_state`: 21 → 6
   - `avoid_dynamic_calls_extended`: 12 → 0
   - `avoid_unsafe_cast`: 10 → 0
   - `avoid_case_sensitive_path_comparison`: 7 → 1
   - `require_cache_expiration`: 5 → 0
   - `avoid_swallowing_exceptions`: 4 → 1
   - `avoid_string_substring`: 4 → 0 (not in scan output)
   - `avoid_nullable_interpolation`: 3 → 0 (not in scan output)
   - `require_url_validation`: 2 → 0
   - `avoid_unbounded_cache_growth`: 2 → 0
   Total: ~168 false positives eliminated.

### Bug archival

Seven bug reports moved from `bugs/` to `plans/history/2026.09/2026.09.05/`:
- `avoid_case_sensitive_path_comparison_false_positive_non_path_comparisons.md`
- `avoid_stack_trace_in_production_false_positive_cli_tool.md`
- `avoid_string_substring_false_positive_guarded_by_regex_or_indexof.md`
- `avoid_unsafe_cast_false_positive_guarded_casts.md`
- `require_cache_expiration_false_positive_content_addressed_caches.md`
- `require_catch_logging_false_positive_intentional_fallback.md`
- `require_url_validation_false_positive_local_file_paths.md`

Six more had been archived in the prior session. The remaining one —
`plans/history/2026.09/2026.09.05/avoid_nullable_interpolation_false_positive_regexpmatch_group_guaranteed_by_pattern.md`
— was fixed in v8 (`_isMatchGroupAccess` guard added to `AvoidNullableInterpolationRule`).

### Code-review finding addressed

`_ruleMetadataToJson` in `violation_export.dart` had a null-metadata fallback map
missing `requiresReview` and `defaultReviewState` keys that the accompanying
comment claimed were always present. Added the two missing keys. `correction` is
intentionally omitted to match `toJson()`'s conditional emit.

### Remaining scan findings (not false positives)

The post-fix scan reports 501 total findings across `lib/`. The remaining
non-zero counts for the 13 targeted rules are genuine findings:
- `avoid_platform_specific_imports` (5): real `dart:io` imports in non-CLI code
- `avoid_global_state` (6): real mutable top-level state
- `require_catch_logging` (2): catch blocks genuinely lacking logging
- `avoid_case_sensitive_path_comparison` (1): real unguarded comparison
- `avoid_swallowing_exceptions` (1): real swallowed exception

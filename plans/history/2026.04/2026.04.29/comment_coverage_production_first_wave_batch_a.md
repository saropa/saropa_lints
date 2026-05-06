# Comment coverage: production-first wave (batch A)

## Scope completed
- Production files:
  - `scripts/modules/_code_comment_metrics.py`
  - `extension/src/securityHotspotReviewState.ts`
  - `extension/src/views/projectVibrancyCliRunner.ts`
  - `scripts/modules/_duplicated_messages.py`
  - `extension/src/vibrancy/views/known-issues-script.ts`
  - `lib/src/cli/cross_file_html_reporter_part.dart`
  - `lib/src/cli/cross_file_unused_l10n.dart`
  - `scripts/modules/_comment_coverage_report.py`
- Test files:
  - `test/violation_export_test.dart`
  - `test/avoid_inert_animation_value_in_build_rule_test.dart`
  - `test/performance_rules_test.dart`

## Notes
- Applied deeper rationale comments in scanner/parser/control-flow sections for Python and TypeScript production utilities.
- Added lifecycle/state-transition and orchestration/error-path comments in extension runtime files.
- Added concise arrange/act/assert intent comments in high-churn tests to raise baseline readability without adding noise.
- Re-ranked low-comment production outliers after edits; next batch candidates remain concentrated in large `extension/src/vibrancy/views/*` and provider files.

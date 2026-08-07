# Bulk Lint Report Fix (2026-08-06)

209 dart analyzer lint issues resolved across 119 files in `lib/` and `test/`. The issues were reported in `bugs/20260806_lint_reports.json` from the IDE's dart analysis LSP.

## Finish Report (2026-08-06)

### Approach

`dart fix --apply` handled 206 of 209 fixes automatically. Three manual fixes:

1. **`saropa_lint_rule.dart` — `prefer_collection_literals`:** Changed `Map<LintImpact, LinkedHashSet<ViolationRecord>>` to `Map<LintImpact, Set<ViolationRecord>>` with set literals. Verified no code uses `LinkedHashSet`-specific APIs; Dart set literals instantiate `LinkedHashSet` at runtime, preserving insertion-order guarantees.
2. **`saropa_lint_rule.dart` — `avoid_renaming_method_parameters`:** Renamed `ruleContext` → `context` in `registerNodeProcessors` to match the base `AnalysisRule` signature. No shadowing — the only usage passes it to `SaropaContext()`.
3. **`plan_c_fixture_expect_lint_contract_test.dart` — `unintended_html_in_doc_comment`:** Wrapped `<category>/` in backticks to prevent HTML interpretation.

### Intentionally Skipped (6 issues)

| Lint | File | Reason |
|------|------|--------|
| `fixme` | `comment_utils.dart:107` | False positive — the word "FIXME" appears in documentation explaining rule behavior |
| `implementation_imports` | `saropa_fix.dart:44` | Intentional — requires internal `analysis_server_plugin` API |
| `implementation_imports` | `scan_runner.dart:22` | Intentional — requires internal package API |
| `library_private_types_in_public_api` | `project_context_ast_violations.dart:152` | `_BatchedViolation` in `part of` file — API design decision |
| `library_private_types_in_public_api` | `project_context_project_file.dart:25` | `_ProjectInfo` in `part of` file — API design decision |
| `prefer_interpolation_to_compose_strings` | `disposal_rules.dart:1014` | Raw string concatenation with `RegExp.escape()` — interpolation would require double-escaping backslashes |

### Hardening Pass

- Removed dead field `_isProjectRootInitialized` from `saropa_lint_rule.dart` — declared but never read or reassigned.
- Added `scripts/check_dart_fix.py` — CI/pre-push script that runs `dart fix --dry-run` and fails non-zero if fixable issues exist, preventing future lint report accumulation.

### Verification

- `dart fix --apply` completed without errors
- `dart test test/integrity/` — 48 tests passed
- `dart test test/support/ test/native/` — 48 tests passed
- Deep review confirmed all `unnecessary_nullable` removals are correct against `analyzer ^12.1.0` API

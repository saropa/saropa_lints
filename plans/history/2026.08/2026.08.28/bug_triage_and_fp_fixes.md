# Bug Triage and False-Positive Fixes — 2026-08-28

Seven bug reports in `bugs/` were reviewed, updated, and resolved in a single pass. Five were false-positive bugs on existing rules, two were feature proposals.

## Finish Report (2026-08-28)

### False-Positive Fixes (5 rules)

**`avoid_context_in_async_static` (v2→v3)** — Added `_allContextUsagesInAwaitedArgs()` fast-path that walks the method body and suppresses the diagnostic when every `BuildContext` usage is consumed synchronously inside an awaited call's argument list (e.g., `await showDialog(context: context)`). Falls through to the existing `checkAsyncStaticBody` flow analysis when any usage appears outside awaited args. New `_ContextUsageCollector` visitor skips closures to avoid cross-scope false negatives.

**`avoid_datetime_constructor` and `avoid_datetime_constructor_unvalidated` (v1→v2)** — Added `componentsFromValidDateTime()` static method that suppresses the diagnostic when all three date components (year, month, day) are property accesses on a DateTime-typed expression. Day arithmetic (`dt.day ± N`) is allowed on the day component only, since Dart documents rollover behavior. Month/year arithmetic is not suppressed because rollover there changes the date semantically. Uses `toSource()` string comparison to verify all three components share the same receiver, consistent with `ReplaceDateOnlyFix`.

**`require_error_widget`** — Already implemented. The `_ErrorHandlingVisitor.visitMethodInvocation` method already recognizes any method invocation whose receiver is the snapshot parameter as delegated error handling. Bug report status updated; no code changes needed.

**`avoid_large_list_copy`** — Already implemented. The `_isToListRequired` method (lines 2341–2438) already handles `??` operators, named/positional arguments, variable declarations, return types, cascades, property access, collection literals, switch arms, records, and yield statements. A 13-case regression test suite was added to prove coverage. No code changes needed.

**`no_equal_nested_conditions`** — Already implemented. The `_NestedConditionChecker` already tracks reassigned variables via `_reassignedBefore` set and suppresses diagnostics when condition variables are reassigned between outer and inner checks. Three fixture cases added (`??=`, compound `+=`, different-variable-reassigned). No code changes needed.

### Feature: Enum Size Threshold (avoid_wildcard_cases_with_enums v5→v6)

Added `maxEnumSize = 20` constant. The rule now resolves the switch expression's type to `EnumElement`, counts declared constants (excluding synthetic `values`/`index`), and suppresses the diagnostic when the enum exceeds the threshold. Falls back to the existing string heuristic when type resolution is unavailable (scan CLI without `--resolve`). No per-rule configuration system exists in the project, so the threshold is a hardcoded `static const`.

### Feature: Stale Ignore Detection CLI

New `--find-stale-ignores` flag on the `scan` CLI. Algorithm: the scan CLI does not honor `// ignore:` directives (rules fire regardless), so the detector parses all `// ignore:` comments referencing saropa_lints rules from `allSaropaRuleNames`, then checks whether the scan produced a matching diagnostic on the target line. No match = stale. Handles both standalone ignores (own line → suppresses next line) and inline ignores (end of code line → suppresses same line). Skips `// ignore_for_file:` (deferred to Phase 2). Exits 1 if any stale ignores found.

**Known limitation:** path matching between `ScanDiagnostic.filePath` and the file list relies on both sides producing identical path strings. The scan CLI normalizes paths, but if `ScanDiagnostic` stores a different representation, stale ignores could be missed. End-to-end testing on a real project is recommended.

### Files Changed

- `lib/src/rules/core/context_rules.dart` — new fast-path + visitor (+143 lines)
- `lib/src/rules/data/json_datetime_rules.dart` — new `componentsFromValidDateTime` + helpers (+150 lines)
- `lib/src/rules/code_quality/code_quality_control_flow_rules.dart` — enum threshold + EnumElement resolution (+51 lines)
- `lib/src/scan/stale_ignore_detector.dart` — new file, stale ignore detection module
- `bin/scan.dart` — `--find-stale-ignores` handler + help text (+110 lines)
- `lib/src/scan/scan_cli_args.dart` — `findStaleIgnores` field + flag parsing
- `lib/scan.dart` — exports for stale ignore module
- `example/lib/` — 4 fixture files extended/created
- `test/` — 2 test files added/extended
- `CHANGELOG.md` — 3 entries (Fixed, Changed, Added)
- 7 bug reports archived to `plans/history/2026.08/2026.08.28/`

### Test Results

229 tests pass (code_quality_rules_test.dart + avoid_large_list_copy_fp_test.dart).

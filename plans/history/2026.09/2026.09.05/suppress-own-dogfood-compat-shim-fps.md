# Suppress Own-Dogfood False Positives in Analyzer Compat Shims

`analyzer_compat.dart` uses dynamic dispatch, bare catches, and silent exception swallowing by design — each pattern probes whether an analyzer API exists in the running version and falls back if it does not. Six saropa_lints rules (`avoid_dynamic_calls_extended`, `avoid_unsafe_cast`, `avoid_catch_all`, `require_catch_logging`, `avoid_swallowing_exceptions`, `document_analyzer_ignore_rationale`) flagged these patterns as violations. All are verified false positives in this file's context.

`scan_runner.dart:794` casts `reg.context` to `ResolvedScanRuleContext` — safe by construction because the scan runner itself registered that context type. `avoid_unsafe_cast` flagged it.

## Finish Report (2026-09-05)

### Changes

- **`lib/src/analyzer_compat.dart`**: Added `// ignore_for_file:` directives with rationales for 6 rules. Added rationale to the existing inline `deprecated_member_use` ignore on line 217. Fixed `avoid_nullable_interpolation` by replacing `m[0]` with `m.group(0)!` in `DiagnosticCodeLowerCaseCompat.lowerCaseName` — semantically identical, now null-safe.
- **`lib/src/scan/scan_runner.dart`**: Added `avoid_unsafe_cast` to the existing inline ignore on the `ResolvedScanRuleContext` cast.
- **`CHANGELOG.md`**: Maintenance entry appended.

### Scope

Metadata-only (ignore directives) plus one equivalent accessor swap. No behavioral change.

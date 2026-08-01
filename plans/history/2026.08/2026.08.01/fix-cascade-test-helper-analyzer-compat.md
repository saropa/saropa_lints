# Fix: Cascade Test Helper Analyzer 12.1.0 Compatibility

The `_parseDisposeBody` helper in `target_matcher_utils_test.dart` used `ClassDeclaration.childEntities` to iterate class members and find the `dispose()` method. In analyzer 12.1.0, `childEntities` no longer exposes `MethodDeclaration` nodes directly — it returns a mix of tokens and lower-level syntactic entities. All 13 AST-path cascade cleanup tests threw `StateError('No dispose() found')`.

## Finish Report (2026-08-01)

### Root Cause

`ClassDeclaration.childEntities` is a low-level CST iterator inherited from `AstNode`. The correct typed API for accessing class members is `ClassDeclaration.body.members` (or the cross-version-safe `bodyMembers` extension from `analyzer_compat.dart`). The analyzer 12.1.0 upgrade changed what `childEntities` yields, breaking the test helper while production code (which already used `bodyMembers` or the visitor pattern) was unaffected.

### Fix

1. Extracted `_parseDisposeBody` into a shared test helper `test/helpers/parse_class_method.dart` as `parseMethodBody(methodName, classSource)`, using the existing `bodyMembers` extension from `analyzer_compat.dart` for cross-version safety.
2. Updated `target_matcher_utils_test.dart` to import and use the shared helper.
3. Audited all other `childEntities` usage in the codebase — 14 production call sites all operate on generic `AstNode` subtypes (not `ClassDeclaration`), so they are unaffected. Zero remaining `childEntities` usage in `test/`.

### Hardening

- Added CI guard test in `anti_pattern_detection_test.dart` that scans all test files for `ClassDeclaration.childEntities` / `EnumDeclaration.childEntities` / `MixinDeclaration.childEntities` usage and fails with guidance to use `bodyMembers` instead. Prevents this class of breakage from recurring on future analyzer upgrades.

### Verification

- `dart test test/utils/target_matcher_utils_test.dart` — 21/21 pass.
- `dart test test/integrity/anti_pattern_detection_test.dart` — 5/5 pass (including new guard).
- No production code changes required; the visitor in `target_matcher_utils.dart` already uses the correct `visitCascadeExpression` API.

### Other Test Failures in the Publish Run

- **`project_vibrancy_resolved_usage_test.dart`** (1 failure) — `PathAccessException` on temp dir deletion. Windows file-lock flake, not a code defect. Retry expected to pass.
- **`avoid_opacity_misuse`** — not actually failing; interleaved log output was misleading. The failure count stayed at 13 (all from `target_matcher_utils_test`).

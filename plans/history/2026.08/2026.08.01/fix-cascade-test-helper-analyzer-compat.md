# Fix: Cascade Test Helper Analyzer 12.1.0 Compatibility

The `_parseDisposeBody` helper in `target_matcher_utils_test.dart` used `ClassDeclaration.childEntities` to iterate class members and find the `dispose()` method. In analyzer 12.1.0, `childEntities` no longer exposes `MethodDeclaration` nodes directly — it returns a mix of tokens and lower-level syntactic entities. All 13 AST-path cascade cleanup tests threw `StateError('No dispose() found')`.

## Finish Report (2026-08-01)

### Root Cause

`ClassDeclaration.childEntities` is a low-level CST iterator inherited from `AstNode`. The correct typed API for accessing class members is `ClassDeclaration.body.members`, which returns `NodeList<ClassMember>`. The analyzer 12.1.0 upgrade changed what `childEntities` yields, breaking the test helper while production code (which already used `body.members` or the visitor pattern) was unaffected.

### Fix

Single-line change in `test/utils/target_matcher_utils_test.dart:13`:
`decl.childEntities` → `decl.body.members`

### Verification

- `dart test test/utils/target_matcher_utils_test.dart` — 21/21 pass.
- No production code changes required; the visitor in `target_matcher_utils.dart` already uses the correct `visitCascadeExpression` API.
- Other diffs in this changeset are formatting-only (dart format adjustments to `disposal_rules.dart`, `equality_rules.dart`, `target_matcher_utils.dart`).

### Other Test Failures in the Publish Run

- **`project_vibrancy_resolved_usage_test.dart`** (1 failure) — `PathAccessException` on temp dir deletion. Windows file-lock flake, not a code defect. Retry expected to pass.
- **`avoid_opacity_misuse`** — not actually failing; interleaved log output was misleading. The failure count stayed at 13 (all from `target_matcher_utils_test`).

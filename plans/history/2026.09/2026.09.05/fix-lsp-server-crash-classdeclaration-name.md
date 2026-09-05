# Fix: LSP server crash — ClassDeclaration.name removed in analyzer 12.x

The `avoid_unnecessary_factory_constructor` rule used `ClassDeclaration.name.lexeme`
to read the enclosing class name. In analyzer 12.1.0, `ClassDeclaration.name` (a
`SimpleIdentifier`) was removed — the stable accessor is `nameToken` (a `Token`).
The compile error (exit 255) prevented the LSP server from building at all, causing
`vscode-languageclient` to restart the server 5 times in 3 minutes before giving up.

## Finish Report (2026-09-05)

**Root cause:** `enclosingClass.name.lexeme` at `unnecessary_code_rules.dart:465`.
`ClassDeclaration.name` was removed in the analyzer package version pinned by the
project (12.1.0). Other rules in the codebase already use `.nameToken.lexeme`.

**Fix 1 — compile error:** Changed `.name.lexeme` → `.nameToken.lexeme` at the
single call site. Grepped full `lib/` tree — no other broken usages.

**Fix 2 — `avoid_unsafe_cast` false negative:** `_conditionHasIsCheck` in
`type_safety_rules.dart` recursed into `||` branches, suppressing the lint when
an `is` check appeared in a disjunction. An `is` check inside `||` does not
guarantee the type in the then-body (`if (v is List || other)` enters the body
when `other` is true even if `v` is not a List). Removed `||` recursion; only
`&&` compounds are now recognized as guards. Updated fixture with a BAD case
for `||` and converted the existing GOOD case to use `&&`.

**Fix 3 — CI compile gate:** Added a `dart compile kernel` step to
`.github/workflows/ci.yml` that compile-checks all 4 `bin/` entry points
(`lsp_server`, `project_health`, `severity_report`, `doctor`). Catches
build-breaking API changes the analyzer package introduces at runtime load
time, not at static analysis time.

**Verification:**
- All 38 tests in `unnecessary_code_rules_test.dart` pass.
- All 36 tests in `type_safety_rules_test.dart` pass.
- All 4 entry points compile cleanly via `dart compile kernel`.
- No other `ClassDeclaration.name.` references remain in `lib/`.

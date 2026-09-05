# Fix: scan CLI silently excludes example_packages/ fixtures

The scan CLI (`dart run saropa_lints scan`) produced zero diagnostics for rules
like `prefer_sorted_equatable_props` and `avoid_unnecessary_factory_constructor`
when scanning fixture files under `example_packages/` or `example/`. The prior
session diagnosed this as a missing `addClassDeclaration` visitor dispatch; that
diagnosis was incorrect — the dispatch was fully wired up.

## Finish Report (2026-09-05)

### Root cause

Three independent file-exclusion bugs conspired to silently drop fixture files:

1. **`scan_runner.dart` line 941**: the hardcoded exclusion `n.contains('/example')`
   matched `/example_packages/` as a substring when the file path was absolute
   (which happens when `--files` joins the relative filename onto
   `p.absolute(targetPath)`).

2. **`bin/scan.dart`**: `ScanRunner` was constructed without setting
   `applyExclusionsToFileList`, so it defaulted to `true` — meaning the hardcoded
   exclusions filtered even files the user explicitly named via `--files`. The LSP
   server already set this to `false` for the same reason.

3. **`saropa_lint_rule.dart` `shouldSkipFile`**: the `skipFixtureFiles` exemption
   for example directories only checked `contains('/example/')` and
   `contains('/examples/')`. This missed:
   - **`/example_packages/`** — package-specific test fixtures (equatable,
     riverpod, etc.).
   - **Relative paths** — `listSync` returns paths like `example_packages/lib/...`
     (no leading `/`), so the `contains` check never matched.

### Changes

| File | Change |
|------|--------|
| `lib/src/scan/scan_runner.dart` | Tightened `n.contains('/example')` to `n.contains('/example/')` plus `n.contains('/examples/')` — no longer matches `/example_packages/`. |
| `bin/scan.dart` | Set `applyExclusionsToFileList: dartFiles.isEmpty` so that explicitly named `--files` bypass the hardcoded exclusion chain. |
| `lib/src/saropa_lint_rule.dart` | Added `/example_packages/` to the `isInExample` check, and added `startsWith('example/')` / `startsWith('examples/')` / `startsWith('example_packages/')` guards for relative paths. |
| `CHANGELOG.md` | Added internal maintenance entry describing the three-part fix. |

### Verification

- `prefer_sorted_equatable_props`: 2 diagnostics on 2 BAD fixture cases (with
  `--files` and without).
- `avoid_unnecessary_factory_constructor`: 2 diagnostics on 2 BAD fixture cases
  (with `--files --resolve`).
- All 32 equatable rules tests pass.
- Existing `scan_runner_test.dart` tests pass (they already set
  `applyExclusionsToFileList: false` explicitly).

### --no-exclude flag (added in same session)

Added `--no-exclude` CLI flag to disable all hardcoded path exclusions
(`example/`, `build/`, `.dart_tool/`, etc.) so every `.dart` file is scanned.
User-supplied `--exclude-globs` still apply — this only bypasses the opinionated
defaults. Wired through `ScanCliArgs.noExclude` → `ScanRunner.noExclude` →
`_resolveDartFiles` → `_findDartFiles` / `_shouldInclude`.

End-to-end verification:
- Normal scan: 175 files with diagnostics.
- `--no-exclude`: 262 files (includes `example/`, `build/`, `bin/`).
- `--no-exclude --exclude-globs "**/example/**"`: 188 files (user globs applied).

### _findRegExpPattern type fix

Fixed `avoid_nullable_interpolation`'s regex-pattern lookup passing an
`InterpolationExpression` (the visitor callback node) to `_findRegExpPattern`,
which expects `Expression`. Changed to pass `inner` (the unwrapped expression
from `node.expression`). This fixed 4 process-level test failures in
`scan_cli_args_test.dart`.

### Misdiagnosis note

The prior handover attributed the problem to missing `addClassDeclaration` /
`addCompilationUnit` visitor dispatch in the scan runner. Investigation confirmed
the `CapturingRuleVisitorRegistry`, `CompatVisitor`, and `ScanWalker` all
correctly dispatch these callbacks. The actual cause was upstream file exclusion
at three layers.

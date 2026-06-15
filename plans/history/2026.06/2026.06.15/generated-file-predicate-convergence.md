# Generated-file detection converged onto one shared predicate

The list of code-generator suffixes plus gen-l10n table detection was re-implemented inline in six
CLI scanners with inconsistent coverage — `cross_file_duplicates` checked 2 suffixes, the cross-file
unused-symbol / unused-l10n / missing-mirror-test passes checked 3 plus a `/generated/` substring,
and `project_vibrancy` checked the full set plus the gen-l10n tables. The drift meant the scanners
disagreed on what counts as generated, and extending the list required editing several files. A single
shared predicate already existed for the Project Map size scanner; the other consumers now delegate to
it.

## Finish Report (2026-06-15)

### Scope

(A) Dart analyzer/CLI only. Files: `lib/src/cli/generated_dart_files.dart` (predicate),
`lib/src/cli/cross_file_analyzer.dart`, `cross_file_analyzer_helpers.dart`, `cross_file_duplicates.dart`,
`cross_file_unused_l10n.dart`, `cross_file_unused_symbols_semantic.dart`, `project_vibrancy.dart`
(consumers), `test/cli/generated_dart_files_test.dart` (new).

### What changed

`isGeneratedDartPath(relPosix)` is now the single source of truth. It was extended with a `generated`
path-segment check (whole-segment, so `lib/generated/x.dart` and `lib/foo/generated/x.dart` match but
a hand-written `auto_generated_notes.dart` does not) so it subsumes the `/generated/` directory
convention the cross-file passes used. It is case-insensitive and covers the full codegen-suffix set
(`.g.dart`, `.freezed.dart`, `.mocks.dart`, `.gr.dart`, `.config.dart`, `.chopper.dart`, `.gen.dart`,
`.drift.dart`, the protobuf `.pb*.dart` family) plus gen-l10n tables (`app_localizations*` / `intl_*`
under any `l10n/` directory, which also catches wrapper variants such as
`remote_app_localizations.dart`).

The six consumers delegate to it. The two `_isGeneratedDart` helpers became one-line delegates; the
inline suffix blocks were replaced with a predicate call. `project_vibrancy` kept its separate size-cap
and header-marker fallbacks — only its name-based block was replaced — so its broader generated-file
handling is unchanged. Where a consumer previously checked a narrower suffix subset, it now agrees with
the others (an intentional fix, not a regression: generated files should be excluded uniformly from
unused / duplicate / mirror-test analysis).

### Verification

- `dart analyze` on all seven changed files: no issues.
- `dart test`: `cross_file_test.dart` + `cross_file_unused_l10n_test.dart` + `size_scanner_test.dart`
  (25 passing), `project_vibrancy_cli_test.dart` + `project_vibrancy_coverage_quality_test.dart`
  (19 passing, including the existing codegen-suffix and header-marker suppression cases), and the new
  `generated_dart_files_test.dart` (4 passing — suffixes, generated-segment vs substring, l10n
  wrappers, case-insensitivity).

### Notes for the reviewer

- The predicate broadening (whole-`generated`-segment, full suffix set, l10n) only ever excludes MORE
  files from name-based detection; no consumer's test fixture depended on a generated file being
  treated as hand-written, confirmed by the passing suites above.
- `cross_file_unused_l10n` now skips `app_localizations*` from its source scan; this is correct because
  that scan looks for key USAGE in app code, and the generated table holds key definitions, not usage.

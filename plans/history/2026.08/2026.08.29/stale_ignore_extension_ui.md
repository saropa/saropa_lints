# Stale ignore commands: VS Code extension UI

The `--find-stale-ignores` / `--fix-stale-ignores` scan CLI flags shipped in a prior session with no extension surface — discoverable only via CLI flag, which a prior handover flagged as a defect ("do NOT bury features in --params! it must be exposed to a UI"). This closes that gap by wiring the CLI into the VS Code extension's command palette, sidebar, and Problems panel.

## Changes

### New command module
`extension/src/stale-ignore-commands.ts` registers two commands:
- `saropaLints.findStaleIgnores` — spawns `dart run saropa_lints:scan <root> --find-stale-ignores --format json --json-file-path <path> -q` via `runInWorkspaceAsync` (async, cancellable, progress notification — appropriate given the scan runs all rules before diffing ignores, which can take 30s+ on large projects). Parses the JSON output and publishes each stale ignore as a `DiagnosticSeverity.Warning` on the comment line, so results appear as squiggly lines in the editor and entries in the Problems panel (`source: 'Saropa Lints'`, `code: <ruleName>`).
- `saropaLints.fixStaleIgnores` — confirms via a modal `showWarningMessage` before running `dart run saropa_lints:scan <root> --fix-stale-ignores`, which auto-removes stale ignore comments from disk. Clears the diagnostic collection on success.

### Manifest / registration
- `extension/package.json` — two `contributes.commands` entries (icons `search-remove` / `trash`).
- `extension/package.nls.json` — command titles.
- `extension/src/extension.ts` — imports and calls `registerStaleIgnoreCommands(context)` alongside the existing `registerCrossFileCommands(context)`.
- `extension/src/views/sectionedSidebar.ts` — two new `LeafItem` rows in `buildActionItems()`, placed after "Initialize / Update config", so the feature is visible without knowing the command palette exists.
- `extension/src/i18n/locales/en.json` — new `staleIgnores.*` namespace (progress, error, info, confirm, diagnostic, sidebar sub-keys), 18 keys total across all locale-relevant strings.
- `CHANGELOG.md` — entry under the existing `## [15.2.3] — Unreleased` section.

### Exit-code semantics (the two bugs fixed during review)
The scan CLI's two flags have **different** exit-code contracts, which the first draft conflated:
- `--find-stale-ignores`: exit 0 = clean, exit 1 = stale ignores found (expected, not an error).
- `--fix-stale-ignores`: exit 0 = success (nothing to fix, or fixed), exit 1 = **genuine failure** (stale ignores detected but no files could be modified — e.g. deleted between detection and fix, per `bin/scan.dart:547-552`). There is no "expected" non-zero exit for fix.

The first draft reused the same `isExpectedNonZeroExit(stderr)` heuristic for both commands. Since that failure path in `_runFixStaleIgnores` prints its message to **stdout**, not stderr, empty-stderr made the heuristic swallow the real failure and the UI showed a false "Stale ignore comments removed" success toast. Fixed: the fix-command handler now checks `result.ok` directly with no exemption, falling back to `result.stdout` for the error message when stderr is empty.

### Diagnostic range bug (also fixed during review)
The CLI's `commentText` field is `line.trim()` (leading whitespace stripped) — for the normal case of an indented ignore comment inside a class/function, using `commentText.length` as the range's end column produced a squiggly that started at column 0 (correct) but ended mid-comment, before the indentation offset was accounted for. Fixed by using `Number.MAX_SAFE_INTEGER` as the end column, which VS Code clamps to the actual end-of-line regardless of indentation — a standard pattern for "underline the whole line" diagnostics.

## Test coverage

New `extension/src/test/views/staleIgnoreCommands.test.ts` (9 tests, following the existing `crossFileCommands.test.ts` convention of stubbing `setup.runInWorkspaceAsync` / `projectRoot.getProjectRoot` / `pubspecReader.hasSaropaLintsDep` and asserting the literal CLI argument array):
1. `find` — exact argv shape (`run saropa_lints:scan <root> --find-stale-ignores --format json --json-file-path <path> -q`).
2. `find` — "none found" info toast on zero results.
3. `find` — genuine failure (non-empty stderr) surfaces an error message.
4. `find` — exit 1 with empty stderr is treated as findings, not a failure (regression guard for the exit-code semantics above).
5. `fix` — exact argv shape after user confirms the modal dialog.
6. `fix` — declining the confirmation dialog does not invoke the CLI.
7. `fix` — exit 1 with empty stderr on the fix path IS a genuine failure (direct regression test for the bug this review caught — asserts the false-success toast does NOT appear).
8. Missing workspace root shows an error.
9. Missing `saropa_lints` pubspec dependency shows an error.

Both `stale-ignore-commands.ts` and its test file were added to `extension/tsconfig.test.json`'s explicit `include` list (the test build uses an enumerated file list, not a glob, so a new test file is silently excluded from `npm run test` unless added here).

Ran: `node --max-old-space-size=8192 node_modules/typescript/bin/tsc -p tsconfig.test.json` (clean) then `node node_modules/mocha/bin/mocha "out-test/test/views/staleIgnoreCommands.test.js" "out-test/test/views/crossFileCommands.test.js" --timeout 10000` — 18/18 passing (9 new + 9 existing cross-file, confirming no regression). Full `npx tsc --noEmit` on the extension package also passes clean.

## Deferred

**l10n catalog regeneration NOT run.** 18 new keys × 24 locales = 432 translation gaps now exist in `extension/src/i18n/locales/*.json` and `package.nls.*.json`. Per the project's hard-stop rule on running MT pipelines without an explicit in-the-moment "run it," the command was handed to the user rather than executed:
```
py -3 D:\src\saropa_lints\extension\scripts\generate_translations.py
```
Choosing `[1]` (default, gap-closing only) at the prompt is sufficient — it does not touch existing translations. **This must run before publish** — the coverage gate (`generate_locales.py --fail-on-missing`) will fail otherwise.

**End-to-end validation against a real downstream project (`d:\src\contacts`) was not performed this session** — the commands were verified via unit tests with stubbed CLI output, confirming the exact argv shape matches `bin/scan.dart`'s parser, but not run against a live project with real stale ignores. This remains open from the prior handover.

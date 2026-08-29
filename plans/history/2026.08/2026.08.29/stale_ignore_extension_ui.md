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

## Finish Report (2026-08-29)

Following the initial commit, the handoff reflection surfaced three concerns and one candidate feature; the user selected all three follow-up actions (harden reflection items, implement the unrequested feature, commit).

### Hardening applied

1. **Sidebar visibility gating (non-issue, documented)** — verified the whole "Settings" sidebar view (`package.json` id `saropaLints.settings`) already carries `"when": "saropaLints.isDartProject"`, so the two new stale-ignore rows are hidden along with the rest of the panel on non-Dart projects. No code change; added an inline comment recording the verification so a future reader doesn't re-ask the question.

2. **Output-channel-reveal inconsistency (fixed)** — the bulk `fixStaleIgnores` command was force-revealing the Output panel on every successful run (`getSharedOutputChannel().show(true)`), unlike `cross-file-commands.ts`'s convention of only revealing Output on error and using a lighter-weight message on success. Removed the forced reveal on the fix-success path; the channel still has the full CLI transcript (`logToOutput: true`) for anyone who checks it.

3. **Silent false-negative on JSON corruption (fixed)** — the find command's JSON-read `catch` block treated ANY read/parse failure as "no stale ignores found," including genuine corruption, a partial write, or a permissions error. Since the CLI's `--format json` path (`bin/scan.dart`) unconditionally writes the output file before exiting — even for zero results — a read failure after a normal-looking exit can only mean something broke. The catch block now surfaces an error message instead of a false-clean report.

### Unrequested feature implemented: per-file quick fix

A `StaleIgnoreCodeActionProvider` (exported, registered for `{ language: 'dart' }`) offers a lightbulb quick fix — "Fix stale ignores in this file" — on any diagnostic with `source === 'Saropa Lints'`. It delegates to a new command, `saropaLints.fixStaleIgnoresInFile(uri)`, which scopes the CLI to one file via `--files <path>` rather than editing text directly in TypeScript — deliberately avoiding a second, potentially drifting implementation of the comment-removal logic (standalone vs inline, multi-rule pruning) that already lives once in `lib/src/scan/stale_ignore_detector.dart`. No confirmation dialog on this path (unlike the bulk fix): the action is invoked on a single, already-visible diagnostic, a much smaller blast radius than the whole-project sidebar/palette action.

After the scoped fix, the file is re-scanned (find, scoped to the same file) and its diagnostics are replaced via a new `updateDiagnosticsForUri()` helper that updates only that file's entries in the shared `DiagnosticCollection`, leaving every other file's diagnostics untouched.

Shared logic was extracted into `runFindScan()` and `runFixScan()`/`showFixFailure()` helpers so the whole-project commands and the new per-file command share one code path for CLI invocation, exit-code interpretation, and error reporting — no duplicated exit-code logic to drift out of sync a second time.

### Bug caught in the second review pass: JSON-path race condition (fixed)

A second review pass (targeted at the newly-added code only) found that the per-file refresh scan wrote its JSON output to one **fixed** shared path (`stale_ignores_file.json`) regardless of which file was being fixed. Two quick fixes triggered close together on two *different* files would race on that same path — one scan's write could land between the other scan's write and read, and `updateDiagnosticsForUri` would then silently apply the wrong file's (possibly empty) result to the wrong URI, clearing real diagnostics instead of refreshing them correctly.

Fixed by deriving the JSON path from an MD5 hash of the target file's path (`perFileJsonPath()`, exported for test use) — each file gets its own output path, so concurrent fixes on different files can no longer cross-contaminate. A same-file double-click race remains theoretically possible but is far lower risk (idempotent outcome — the second run's fix finds nothing left to fix) and was not further hardened.

### Test coverage added

`extension/src/test/views/staleIgnoreCommands.test.ts` grew from 9 to 15 tests, plus a new `describe('StaleIgnoreCodeActionProvider', ...)` block (2 tests) testing the provider class directly (VS Code's `registerCodeActionsProvider` is a no-op stub in the test mock, matching the existing `PubspecCodeActionProvider` test pattern in `pubspec-code-actions.test.ts`):
- JSON-corruption hardening: asserts a missing/unreadable output file surfaces an error, not a false "none found."
- Per-file fix: asserts the exact scoped CLI argument arrays for both the fix and refresh-find calls, AND (closing a gap the second review pass flagged) that a pre-seeded stale diagnostic on the target file is actually cleared from the `DiagnosticCollection` after the refresh reports it clean — not just that the CLI was called correctly.
- Race-condition regression guard: asserts `perFileJsonPath()` returns different paths for different files and a stable path for the same file across calls.
- No-confirmation-dialog guard for the per-file command.
- CodeActionProvider: offers exactly one action delegating to `fixStaleIgnoresInFile` with the document's URI, for a diagnostic sourced from `'Saropa Lints'`; ignores diagnostics from other sources.

Ran: full `npx tsc --noEmit` (clean), `node --max-old-space-size=8192 node_modules/typescript/bin/tsc -p tsconfig.test.json` (clean), `node node_modules/mocha/bin/mocha "out-test/test/views/staleIgnoreCommands.test.js" "out-test/test/views/crossFileCommands.test.js" --timeout 10000` — 25/25 passing (15 stale-ignore command tests + 2 CodeActionProvider tests + 10 cross-file, confirming no regression from the refactor).

### Still deferred

- l10n catalogs are now further behind: 2 more keys added this pass (`info.fixedInFile`, `quickFix.title`) bring the total to 20 keys × 24 locales. The translation command handed to the user earlier in this document is unchanged and still needs to run before publish.
- End-to-end validation against `d:\src\contacts` remains open — still not performed.

## Follow-up (2026-08-29, resumed session)

**Locale catalogs committed.** The user manually ran `generate_translations.py` after the prior session ended, closing the coverage gap for all 18 previously-outstanding locales down to one remaining string (`command.fixStaleIgnores.title` in `nl` — confirmed via the coverage audit report). Committed in two parts: `a001b660` (a genuine perf fix to the translation pipeline itself — deferred Qwen/Ollama self-provisioning until a locale actually has untranslated strings, found and fixed alongside the manual run; see `plans/history/2026.08/2026.08.28/i18n_deferred_qwen_provisioning.md`) and `d64e2e87` (the regenerated locale data for all 18 locales).

**End-to-end validation against `d:\src\contacts` performed.** Ran `dart run saropa_lints:scan d:/src/contacts --find-stale-ignores --tier comprehensive --format json` against the real 4528-file project. Result: 1102 stale ignores detected, exit code 1 (matches the documented "found is expected" contract). Spot-checked several entries — file paths, comment/target line pairs, and rule names parsed from the `// ignore:` comments all matched the real source correctly, confirming the path-normalization and diagnostic-matching logic in `lib/src/scan/stale_ignore_detector.dart` works against a real multi-file project, not just the unit-test-stubbed CLI output verified previously.

`--fix-stale-ignores` was deliberately NOT run against `d:\src\contacts` — that would mutate another project's source files, which requires explicit permission under the blast-radius rule. Only the read-only `--find` path was validated. If write-path validation against a live project is wanted, it needs to be requested explicitly.

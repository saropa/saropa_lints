# Doc Update: Extension-Native Rule Sources in Issue Report Guide

`bugs/ISSUE_REPORT_GUIDE.md` documented attribution and filing conventions only in terms of
Dart AST rules (`lib/src/rules/`), which are structurally incapable of inspecting non-Dart
files, file placement, or cross-file workspace conventions. This left no documented path for
filing or triaging issues about problems that surface outside `.dart` files (e.g., bug reports
not being moved to `plans/history/` after closure) — such issues risked being closed as
"out of scope for saropa_lints" by an agent unaware that extension-side checks exist at all.

## Change

Added a "Rule Sources: Dart AST vs Extension-Native" section to `bugs/ISSUE_REPORT_GUIDE.md`,
inserted before the "File Naming" section, documenting:

- **Dart AST rules** (`lib/src/rules/*.dart`) — run via `custom_lint`/LSP, scoped to resolved
  `.dart` files only; cannot see markdown, JSON/YAML, file paths, or cross-file conventions.
- **Extension-native checks** (`extension/src/...`) — run inside the VS Code extension host as
  TypeScript with full workspace API access (any file type, paths, directory structure, git
  state). Packaged inside the same extension bundle — no separate user setup.
- A routing table mapping rule engine → attribution grep root → what it can inspect.

The first draft of this section overstated the current architecture — it claimed extension-native
checks feed the same `DiagnosticCollection` and the same report data model as Dart AST findings,
implying a unified pipeline. A follow-up investigation (`Explore` agent over `extension/src/`)
found this was not accurate and the section was corrected in place:

- **No shared abstraction exists.** There is no `Rule`/`Check` interface or registry. Existing
  extension-native checks (`i18n/l10nDiagnostics.ts`, `pubspec-validation.ts`,
  `vibrancy/extension-activation.ts`, `extension.ts`'s `driftAdvisorDiagCollection`/
  `scanOnSaveDiagCollection`) are standalone modules, each with its own `DiagnosticCollection`.
  A new non-Dart check would follow this same ad hoc pattern, not plug into an existing
  extensibility point.
- **Problems panel: yes, today.** Each existing check already pushes diagnostics to its own
  collection, so Problems-panel surfacing works now without new infrastructure.
- **Web report: no, not today.** `liveDiagnosticsModel.ts`'s `buildViolationsDataFromDiagnostics`
  (which feeds `views/violationsWideReportView.ts`, the status bar, and the Issues tree) hardcodes
  `if (!uri.fsPath.endsWith('.dart')) continue;`, filtering out all non-Dart diagnostics before
  they reach the report data model. Surfacing an extension-native check in the web report requires
  a deliberate change to loosen that filter — it does not happen automatically.

The corrected guide states these constraints explicitly so a future bug filer or fix agent does
not assume web-report surfacing is free once a Problems-panel diagnostic exists.

This was originally a process-documentation-only change, prompted by a conversation about whether
extension-level checks could enforce a doc-placement convention that a Dart AST rule structurally
cannot see.

## Finish Report (2026-09-08)

The `/finish` reflection gate surfaced two follow-ups, both selected and completed:

**1. Hardened the citation.** Added a comment at the exact filter site
(`liveDiagnosticsModel.ts:113`, inside `buildViolationsDataFromDiagnostics`) pointing back to the
guide's "Rule Sources" section, so a future change to that filter does not miss the constraint the
guide now documents. The pre-existing comment on that line was correct but did not reference the
guide; the file/line citation the guide's history entry made was verified directly (not just via
the earlier subagent's grep) before extending it.

**2. Built the minimal ExtensionCheck slice.** Added
`extension/src/extensionChecks/bugArchivalCheck.ts` — a worked example of the "extension-native
check" pattern the guide describes, rather than leaving it purely aspirational. It follows the
existing ad hoc pattern (own `DiagnosticCollection`, scan on activation/open/save — same shape as
`i18n/l10nDiagnostics.ts`) rather than introducing a new shared registry, since no such
abstraction exists yet and inventing one was out of scope for a "minimal shippable slice":

- Detects a `Status: Fixed` / `Closed` / `Declined` line in a `bugs/*.md` file (excluding the
  guide itself) and publishes an Information-severity Problems-panel diagnostic on that line,
  pointing at `ISSUE_REPORT_GUIDE.md`'s archival step.
- Registered in `extension.ts`'s `activate()` alongside the other per-feature registrations
  (`registerL10nDiagnostics`, `registerL10nDeadKeys`).
- Pure detection logic (`computeBugArchivalDiagnostic`, `isBugReportFile`) is exported separately
  from the VS Code event wiring (`validateDocument`) specifically so it could be unit tested
  against a `{ getText, positionAt }` stub without extending the shared `vscode-mock.ts` (whose
  `onDidSaveTextDocument`/`onDidOpenTextDocument` mocks are no-ops that don't capture listeners).
- New user-facing string localized via `l10n('bugArchival.diagnostic.message', …)`, added to
  `en.json` under a new `bugArchival` namespace. Translated locale catalogs were NOT regenerated —
  the global rule against running the MT pipeline without an explicit in-the-moment "run it"
  applies; regeneration is a required follow-up before publish.

Confirmed and left unchanged: extension-native diagnostics from this check reach the Problems
panel today but do NOT appear in the web report (`violationsWideReportView.ts`) — that gap is
exactly what the guide's corrected "Web report: no, not today" paragraph describes, and closing it
was explicitly out of scope for this slice.

## Tests

- `extension/src/test/extensionChecks/bugArchivalCheck.test.ts` — 10 cases covering
  `isBugReportFile` (bugs/ match, guide exclusion, already-archived exclusion, Windows path
  normalization) and `computeBugArchivalDiagnostic` (open/missing status → null; Fixed/Closed/
  Declined → diagnostic; Investigating → null, confirming in-progress statuses are not flagged).
  Ran via scoped mocha: `node node_modules/mocha/bin/mocha "out-test/test/extensionChecks/**/*.test.js" --timeout 10000` — 10/10 passing.
- Added the new source and test file to `tsconfig.test.json`'s explicit `include` list and to
  `package.json`'s `test` script mocha glob (`out-test/test/extensionChecks/**/*.test.js`) — both
  are hand-maintained allowlists, not glob-discovered, so the new suite would otherwise be
  silently excluded from `npm test` and CI.
- Regression check: re-ran `liveDiagnosticsModel.test.js`, `staleIgnoreCommands.test.js`, and
  `l10nParsers.test.js` (the suites nearest the touched files) — 81/81 passing, no regressions
  from the `liveDiagnosticsModel.ts` comment addition or the new `extension.ts` registration call.
- `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json` — both clean after every change in
  this round.

## Files Changed (cumulative)

- `bugs/ISSUE_REPORT_GUIDE.md` — new "Rule Sources" section, corrected after verification.
- `CHANGELOG.md` — two `### Internal`/`### Added (Extension)` entries under `## [16.2.0] — Unreleased`.
- `extension/src/liveDiagnosticsModel.ts` — comment addition at the `.dart`-only filter, no logic change.
- `extension/src/extensionChecks/bugArchivalCheck.ts` — new file.
- `extension/src/test/extensionChecks/bugArchivalCheck.test.ts` — new file.
- `extension/src/extension.ts` — one import + one registration call.
- `extension/src/i18n/locales/en.json` — new `bugArchival.diagnostic.message` key (English only; other locales still need regeneration before publish).
- `extension/tsconfig.test.json`, `extension/package.json` — added the new source/test files to the hand-maintained include list and mocha glob.

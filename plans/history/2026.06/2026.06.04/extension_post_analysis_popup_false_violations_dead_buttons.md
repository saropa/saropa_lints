# Extension post-analysis popup: false "violations found" + dead Copy/Open Report buttons

**Trigger (user report):** "i keep getting a modal popup from saropa_lints in my projects. it says there are violations. there are 4 buttons, only the open dashboard button works - the other 3 are broken (copy, report, etc). and when the dashboard opens there are no issues." Later clarified: "it's the snackbar that pops up after a scan when i load a project." User then asked "shouldn't there ALWAYS be a report?" and directed: do both fixes.

The popup is `showAnalysisIssuesNotification` in `extension/src/setup.ts`, fired after a `dart analyze` run returns a non-zero exit. Its four actions are **View Violations** / **Copy Report** / **Open Report** / **Show Output**.

## Finish Report (2026-06-04)

### Scope

VS Code extension (TypeScript) only — `extension/src/`. The `saropa_lints` repo defaults to the LINTER /finish variant, whose scope list is (A) Dart rules / (C) docs-scripts; this change is extension code, which that list doesn't cleanly cover. No Dart (`lib/`), analyzer plugin, rule, tier, or `analysis_options*.yaml` files were touched, so the Dart-side sections (Linter-Specific Integrity, `example/` fixtures, ROADMAP, `pubspec`) are not applicable.

### Root cause

Both `reports/.saropa_lints/violations.json` (what the Findings dashboard renders) and `*_saropa_lint_report.log` (what Copy/Open Report open) are written **together, atomically**, by the analyzer plugin's `_writeReport()` (`lib/src/report/analysis_reporter.dart`), which fires on a **3-second idle debounce** inside the live Dart analysis server — gated on consolidated batch data existing. The extension's popup, by contrast, fired off the **exit code of a one-shot `dart analyze`** the extension spawns. Those two signals are decoupled: `dart analyze` exits non-zero for any analyzer issue (including core/compile errors unrelated to saropa_lints) while the plugin's debounced write may not have landed — or never lands for that invocation. Result: popup claims "N violations," dashboard is empty, and Copy/Open Report flash a transient "no report found" toast that reads as broken.

So the answer to "shouldn't there always be a report?" is **no, not as architected** — and that decoupling is the bug. The report and the dashboard data are one atomic write; the popup was simply keyed off the wrong signal.

### Changes

**(1) Honest popup, no dead buttons — `extension/src/setup.ts`**

- New exported pure function `analysisIssuesActions(renderableViolations, hasReport)` gates each button on the artifact it acts upon: `View Violations` only when there are violations the dashboard renders; `Copy Report` / `Open Report` only when `findLatestAnalysisReport(root)` returns a path; `Show Output` always (the Output channel always carries the run's diagnosis).
- `showAnalysisIssuesNotification` now counts `data.violations.length` (what the dashboard renders) instead of `summary.totalViolations` (a plugin aggregate that can diverge from / outlive the array). This guarantees the message can never claim violations the view can't show. The message is built via the existing `formatAnalysisIssuesMessage`, whose `total === 0` branch already produces the honest "analysis finished with a non-zero exit. See Output for details." text — so a no-findings run shows that with only `Show Output`.
- Notification call switched from four hard-coded actions to `...analysisIssuesActions(renderableViolations, hasReport)`.
- Added `findLatestAnalysisReport` to the existing `./reportWriter` import.

**(2) Popup driven by the plugin's real output, not the `dart analyze` exit — `extension/src/setup.ts`**

- New `awaitFreshViolations(workspaceRoot, sinceMs, timeoutMs = 6000)`: polls `reports/.saropa_lints/violations.json` mtime every 250 ms until it is strictly newer than the run-start stamp, or the 6 s deadline elapses. Returns whether a fresh write landed. The 6 s cap leaves margin over the plugin's 3 s debounce; the temp-then-rename in `ViolationExporter._writeAtomicFile` is handled by a try/catch-and-retry around the stat.
- Both run-analysis paths in `runAnalysis` (the `openEditorsOnly` branch via `runAnalysisForFiles`, and the full-workspace branch) now stamp `runStartMs` before analysis and `await awaitFreshViolations(...)` before calling `showAnalysisIssuesNotification(...)`. When fresh output lands the popup reflects real data and the report exists; when it does not, the gated notification falls through to the honest "see Output" message.
- The popup itself stays fire-and-forget (`void ….then(…)`); only the bounded file-freshness wait is awaited, so the progress toast is not pinned on user interaction.

Approach deliberately rejected: swapping the extension to run the `scan` CLI. `scan` emits a flat `ScanDiagnostic` list (rule/file/line/severity/message) with no OWASP / impact / suppression / related-rule data, writes a different `*_scan_report.log`, and does not write `violations.json` — it would degrade the dashboard and break the `dart analyze`/Problems-panel integration. The watcher/freshness approach preserves the plugin's rich data and is robust whether the spawned `dart analyze` or the live server produces the write.

### Tests

- `extension/src/test/formatAnalysisIssuesMessage.test.ts`: added a `describe('analysisIssuesActions')` block with 5 cases pinning the full gating matrix (violations+report → 4 actions; violations, no report → drop Copy/Open; no violations, report → drop View; nothing → only Show Output; Show Output always present).
- Test audit: grepped `extension/src/test/` for `showAnalysisIssuesNotification`, `formatAnalysisIssuesMessage`, `analysisIssuesActions`, `awaitFreshViolations`, `findLatestAnalysisReport`, `runAnalysis*`. No existing test pinned the old unconditional-4-buttons behavior or the old `summary.totalViolations` count. `commandCatalogRegistry.test.ts` references only the `saropaLints.runAnalysis` command id; `findLatestAnalysisReport.test.ts` covers the unchanged report-finder; `setupCompositeScaffoldGate.test.ts` only imports the module.
- Commands run:
  - `npx tsc --noEmit` (extension) → clean, exit 0.
  - `npx tsc -p tsconfig.test.json` then mocha on `formatAnalysisIssuesMessage.test.js`, `findLatestAnalysisReport.test.js`, `setupCompositeScaffoldGate.test.js` → all passing.
  - Full `npm test` → 1202 passing / 10 failing. The 10 failures are all in `crossFileCommands.test.js` and are **pre-existing**: with these changes stashed, the base full run is 1197 passing / the same 10 failing, and the suite passes in isolation. It is a shared-mock test-isolation issue in that suite, unrelated to this task and out of scope.

### Maintenance

- CHANGELOG.md: added a `### Fixed` bullet under `[Unreleased]` describing the user-facing behavior change.
- README: verified — no updates needed (no rule counts or product facts changed).
- `pubspec` / `pubspec.lock`: not touched (no release or dependency change).
- guides reviewed — no user-facing guide content affected.
- Roadmap: not applicable (no lint rule added/removed).
- No bug archive — task did not close a `bugs/*.md` file (the `bugs/` directory holds only guide docs).

### Outstanding / not verified

- On-device behavior (the popup timing on a real project load) is not exercised by the unit tests — see `## What to test`.
- Pre-existing `crossFileCommands.test.js` isolation failures remain (out of scope).
- Extension popup button labels remain hard-coded English (pre-existing; not localized via the extension i18n). Not changed here — no new l10n debt introduced.

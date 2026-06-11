# Findings Dashboard — live-diagnostics sync (+ supplementary cleanup)

**Trigger.** During a design discussion about surfacing lint findings, a screenshot showed the VS Code Findings Dashboard reporting `0 findings / grade A 100 / "Last run just now"` while the Problems panel directly below it held 38 live `saropa_lints` findings. Root cause: the dashboard read the batch `reports/.saropa_lints/violations.json` export (only written by an explicit, expensive analysis run), while the Problems panel reads the live analyzer diagnostics — two sources, free to diverge. The user asked to (#1a) make the dashboard read live diagnostics so it can never diverge, holistically (all linters, no saropa-only separation), then to clean up the now-redundant analyzer "supplementary counts" machinery.

This work is the VS Code extension only (TypeScript). No Dart lint rules changed.

## Finish Report (2026-06-11)

### Scope
**(B)** VS Code extension (`extension/`, TypeScript). Not (A) Dart rules, not (C) docs-only (CHANGELOG is incidental).

### What changed

**Part 1 — #1a live-diagnostics source.**
- New `extension/src/liveDiagnosticsModel.ts`: `buildViolationsDataFromDiagnostics(root, getDiagnostics?, tier?)` maps `vscode.languages.getDiagnostics()` into the existing `ViolationsData` contract — so every downstream consumer (grouping, rendering, filtering, suppressions, the whole webview message protocol) is untouched. Holistic: every `.dart` diagnostic from any linter becomes a `Violation`. Severity → 3-bucket (`error`/`warning`/`info`, Info+Hint→info); `code`→rule with `source` fallback; leading `[rule]` message prefix stripped; file path root-relative + forward-slashed to match `saropaLints.openFileAndFocusIssues` (`path.resolve(root, …)`) / Issues-tree (`path.relative(root, …).replaceAll('\\','/')`). Reads `getDiagnostics()` only — **triggers zero analysis** (the analyzer already produced these for the Problems panel).
- `violationsWideReportView.ts`: `rebuildDashboardHtml` now sources `raw` from `buildViolationsDataFromDiagnostics(root, undefined, cfg.get('tier'))` instead of `readViolations(root)`. The pre-existing debounced `onDidChangeDiagnostics` listener (now renamed `liveDiagnosticsListener` / `liveRefreshTimer` / `LIVE_REFRESH_DEBOUNCE_MS`) already drove the rebuild — only the data source changed. Removed the `if (!raw) → "no report yet"` whole-page empty-state branch: a live build always returns a valid (possibly-empty) model, and 0 findings renders the normal zeroed dashboard. Dropped the now-orphaned `emptyStateHtml` helper + `buildFindingsEmptyStateHtml` import.

**Part 2 — supplementary-counts cleanup (redundant under holistic).**
- Deleted `supplementaryDiagnostics.ts` + `supplementaryDiagnostics.test.ts` (the saropa-vs-other subtraction counter). `GetDiagnosticsFn` (its only surviving export) was inlined into `liveDiagnosticsModel.ts`.
- Removed two settings (`includeOtherAnalyzerFindingsInDashboard`, `includeAnalyzerTodosInDashboard`) and their two commands (`toggleInclude…`) from `package.json`, `package.nls.json` (English source keys), `extension.ts` (config-change listener branch + command registrations), and `commandCatalogRegistry.ts`.
- Removed the "other analyzer findings" / "analyzer TODOs" pills from `violationsDashboardHtml.ts`. **Preserved** the unrelated file-system TODO/HACK scanner: extracted its state into a focused `scanner: { enabled, hasDartFiles }` slice (`buildScannerSlice` in the view) and `buildScannerPromoPill` in the renderer; the scanner promo pill, ON pill, `toggleSupplementary`→`scanner` handler branch, and `toggleTodosAndHacksScanner` command all still work.

### Deep review (Section 3)
- **Logic & safety:** no recursion/race risk. The live listener is debounced (500 ms) and disposed on panel close; timers cleared. `getDiagnostics()` is a pure read — no analysis triggered, so no CPU-crush path (the explicit concern that killed the auto-run-analysis alternative).
- **Architecture:** the swap preserves the `ViolationsData` contract, so the change is localized to the producer; consumers untouched. `GetDiagnosticsFn` is the single injectable seam reused by tests.
- **Linter-Specific Integrity:** SKIPPED [B-NOT-IN-SCOPE] — no Dart rules / tiers / `LintImpact`.
- **Performance:** zero added analysis cost; render cost unchanged (existing grouping/paging). hasDartFiles is an in-memory `.some()` over the already-computed diagnostic set.
- **Docs:** module header on `liveDiagnosticsModel.ts` explains the why (0-vs-38 divergence, zero-analysis, holistic, #1a phase boundary); comments updated where the supplementary naming was removed.

### Testing (Section 4)
- **Audited:** grepped `extension/src/test/` for every changed/removed symbol (`supplementary`, `includeOtherAnalyzer*`, `includeAnalyzerTodos*`, `countSupplementaryDiagnostics`, `buildViolationsDataFromDiagnostics`, `liveDiagnosticsModel`). Only two test files matched: `violationsDashboardHtml.test.ts` (rewrote the supplementary-pills block down to scanner-only — 3 tests pinning the surviving promo behavior) and the new `liveDiagnosticsModel.test.ts`. No other test referenced the touched symbols.
- **New tests:** `liveDiagnosticsModel.test.ts` — 10 cases (count==diagnostics anti-divergence, severity mapping, root-relative path, 1-based line, code extraction incl. object/missing, `[rule]` prefix strip, `.dart` filtering, empty-as-valid-zeroed model, holistic, tier passthrough). Wired into `package.json` test list + `tsconfig.test.json`.
- **Run:** `npm run check-types` clean; `node scripts/verify-manifest-nls-keys.mjs` OK (305 keys); `npm test` = **1214 passing / 11 failing**. The 11 failures pre-exist on a clean tree (verified earlier via `git stash`: clean tree was 1219/11) and are in untouched modules (`cross-file commands` shelling to a CLI + a `languagePick` locale-coverage assertion). The passing-count delta is exactly the 15 tests removed with the deleted feature (10 supplementary-module + 5 net dashboard-pill) — zero regressions.

### Extension l10n (Section 5)
- **String audit:** no new user-facing strings added. Removed `l10n()` calls for the deleted analyzer pills; the surviving scanner promo reuses existing `findingsDash.supplementary.*` keys. `liveDiagnosticsModel.ts` renders no UI. No hardcoded display literals introduced.
- **Catalog regeneration:** NOT run, and not required. `en.json` was **not** modified (the now-unused `findingsDash.supplementary.{otherAnalyzer*,analyzerTodos*,tooltipLive}` display keys were deliberately left in place — removing them safely needs the i18n regeneration cadence, and orphaned keys are harmless). `package.nls.json` had four source keys **removed** (not added/edited); key removal needs no translation, and running `generate_translations.py` is the banned NLLB pipeline. Orphaned keys in generated `package.nls.<lang>.json` / `locales/<lang>.json` are harmless — the coverage gate and `verify-manifest-nls-keys` flag only *missing* keys.
- **Coverage gate:** `verify-manifest-nls-keys` → OK (305 keys, 0 missing). `en.json` untouched → no runtime-l10n missing introduced.

### Maintenance (Section 6)
- **CHANGELOG:** updated under `[Unreleased]` — overview sentence + two `### Changed (Extension)` bullets (live source, holistic) + one `### Removed (Extension)` bullet (the two toggles).
- **README:** verified — no updates needed (no rule/doc counts changed).
- **pubspec:** unchanged (no release/dep change).
- **Roadmap:** SKIPPED [B-NOT-IN-SCOPE] — no lint entries.
- **guides reviewed** — nothing user-facing in `doc/guides/` affected.
- **Bug archive:** No bug archive — task did not close a `bugs/*.md` file.

### Finish report
Finish report saved: `plans/history/2026.06/2026.06.11/findings-dashboard-live-diagnostics-sync.md` (this file).

### Files
- New: `extension/src/liveDiagnosticsModel.ts`, `extension/src/test/liveDiagnosticsModel.test.ts`
- Deleted: `extension/src/supplementaryDiagnostics.ts`, `extension/src/test/supplementaryDiagnostics.test.ts`
- Modified: `extension/src/views/violationsWideReportView.ts`, `extension/src/views/violationsDashboardHtml.ts`, `extension/src/views/commandCatalogRegistry.ts`, `extension/src/extension.ts`, `extension/package.json`, `extension/package.nls.json`, `extension/tsconfig.test.json`, `extension/src/test/views/violationsDashboardHtml.test.ts`, `CHANGELOG.md`

### Outstanding / not yet verified
- **#1b (enrichment) not done** — live findings carry file/line/rule/message/severity but not `correctionMessage`/OWASP/tier-aware metadata for saropa rules (needs a bundled generated rule catalog). Tracked as the next phase; out of scope here.
- **Not run in the Extension Development Host** — the model is unit-pinned and plugs into the pre-existing live-refresh listener, but the dashboard has not been launched live against a real project this session.

# Save Upgrade Report button (Package Dashboard)

**Triggered by:** User request — "add a new button next to 'Save' called 'Save Upgrade Report'; it should only report all the details about packages that have an update available."

Scope: VS Code extension (TypeScript) only — the Package Vibrancy report webview (`VibrancyReportPanel`, panel title "Saropa Package Dashboard"). No Dart lint-rule code touched.

## Finish Report (2026-06-10)

### 1. Critical note
This work will be reviewed by another AI.

### 2. Scope
Project is `saropa_lints` → LINTER variant. But the change set is **(B-equivalent) VS Code extension TypeScript**, which the linter variant's (A)/(C) buckets don't model. Handled honestly: Dart-rule-specific sections marked SKIPPED with that reason; real TypeScript review + tests performed.

- (A) Dart lint rules / analyzer plugin: **not touched**.
- (C) docs/scripts: CHANGELOG + a new history file touched.
- Extension TypeScript: the substantive change.

### 3. Deep Review
- **Logic & Safety:** New webview→host message `saveUpgradeReportJson`. Filter runs in the webview (`report-script.ts`): keeps rows where `update.status` is present and not `'up-to-date'`/`'unknown'` — the same outdated test the existing modernization filter uses (`report-script.ts` ~line 215, `hasUpdates`). No new race: reuses the existing debounce/disable pattern of the Save button (button disabled during save, re-enabled after 2s). Empty result (no outdated packages) writes a valid `[]` — acceptable, the user still gets a file and the "Saved report JSON" toast.
- **Architecture & Adherence:** Did not duplicate the save routine. Refactored `_saveReportJson(rows)` → `_saveReportJson(rows, nameSuffix)` so both reports share one method; the existing call passes `'pubspec_vibrancy'` (preserving the exact prior filename `..._pubspec_vibrancy.json`), the new call passes `'pubspec_upgrade'`. Single source of truth for the dated-folder + timestamp logic.
- **Linter-Specific Integrity:** SKIPPED [extension-only — no Dart rules, tiers, or LintImpact involved].
- **Performance:** Filter is an O(n) pass over already-materialized `packageData` on a user click; negligible.
- **Documentation Quality:** Added WHY comments at the new button (what "outdated" means + cross-reference to the shared test), at the script handler, and the webview message branch.

### 4. Testing Validation
- **A. Audit existing tests (mandatory):** Grepped `extension/src/test` for `saveReportJson`, `saveUpgrade`, `_saveReportJson`, `pubspec_vibrancy`, `pubspec_upgrade`, `buildReportHtml`, `toolbar`, `save-all`. Matches: `report-html.test.ts` (toolbar `describe` uses `includes`, no button-count assertions → unaffected) and `report-webview.test.ts` (`saves report json...` asserts filename `endsWith('pubspec_vibrancy.json')`). Because the existing save call still passes the `'pubspec_vibrancy'` suffix, that assertion still holds. No existing assertion broke.
- **B. New tests:**
  - `report-html.test.ts` → `should include save and save-upgrade buttons` (asserts `id="save-all"`, `id="save-upgrade"`, label "Save Upgrade Report").
  - `report-webview.test.ts` → `saves upgrade report json to a distinct upgrade-suffixed file` (fires `saveUpgradeReportJson`, asserts written file `endsWith('pubspec_upgrade.json')`).
- **Run:** `npm --prefix extension test` (mocha; runner ignores path-pattern flags so the full suite ran). Result: **1204 passing, 10 failing**. Both new tests pass. All 10 failures are in `cross-file commands` (dot-file generation, browser open, stderr) — untouched by this change, pre-existing and unrelated.
- **Type-check:** `npm --prefix extension run check-types` (tsc --noEmit) clean.

### 5. Project Maintenance & Tracking
- CHANGELOG: added `### Added (Extension)` bullet under `[Unreleased]`.
- README verified — no rule/doc-count change; no update needed.
- pubspec / package.json: not a release — untouched.
- Roadmap: SKIPPED [extension-only — no lint rule].
- Bug archival: SKIPPED [NO-BUG-FIXED] — feature request, no `bugs/*.md` describes it.
- l10n: new keys `saveUpgradeLabel` / `saveUpgradeTitle` added to `en.json` (the source locale) only. Other locales fall back to English until the MT pipeline runs. MT pipeline NOT run (hard prohibition).

### 6. Persist
Finish report saved: plans/history/2026.06/2026.06.10/save-upgrade-report-button.md

### Files changed
- `extension/src/vibrancy/views/report-html.ts` — new `saveUpgradeBtn`, placed after `saveBtn` in the toolbar.
- `extension/src/vibrancy/views/report-script.ts` — `save-upgrade` click handler; filters to outdated rows, posts `saveUpgradeReportJson`.
- `extension/src/vibrancy/views/report-webview.ts` — handles `saveUpgradeReportJson`; `_saveReportJson` gains a `nameSuffix` param.
- `extension/src/i18n/locales/en.json` — `saveUpgradeLabel` / `saveUpgradeTitle`.
- `extension/src/test/vibrancy/views/report-html.test.ts` — new toolbar button test.
- `extension/src/test/vibrancy/views/report-webview.test.ts` — new upgrade-save test.
- `CHANGELOG.md` — Added (Extension) bullet.
- `plans/history/2026.06/2026.06.10/save-upgrade-report-button.md` — this report.

### Outstanding
None for the requested feature. Non-English locale strings will display English until translated (by design — MT not run here).

# Write Report Replaces Copy-for-AI

The Upgrade Opportunities panel's per-card "Copy for AI" clipboard button was replaced with "Write Report" buttons at two granularities: a global header button that writes all packages' prompts to one file, and a per-card button that writes just that package's prompt. The prompt content grew too large for comfortable clipboard pasting after four new prompt sections (deprecated APIs, dual-dependency risk, local reimplementation, package health) were added. Both buttons save a dated markdown file under `reports/` and copy the file's absolute path to the clipboard.

## Finish Report (2026-08-19)

### What changed

**`extension/src/vibrancy/views/opportunities-html.ts`** — Removed `buildActions()`'s per-card `opp-copy` button with its `data-prompt` attribute embedding. Added a global `#writeReportBtn` in the page header that posts `{ type: 'writeReport' }` to the extension host, and a per-card `opp-write-card` button that posts `{ type: 'writeCardReport', package }`. The webview script listens for `reportWritten`/`reportFailed` messages to re-enable the global button; the per-card button re-enables on a timeout. Updated the file-header doc comment from "Copy for AI" to "Write Report". Added fallback for empty `writeLabel` (`|| 'Write Report'`).

**`extension/src/vibrancy/views/opportunities-panel.ts`** — Added `_cards` field to retain card data across renders. Added `_writeReport()` handler: combines all cards' `aiPrompt` values with `---` separators, writes to `reports/<timestamp>_package_opportunities.md`, copies the absolute path to clipboard. Added `_writeCardReport(packageName)` handler: writes just one package's prompt to `reports/<timestamp>_opportunity_<package>.md`. Uses `_workspaceRoot` (the scanned pubspec's folder) instead of `resolveReportFolder()` to correctly place reports in multi-root workspaces. Added `_postIfAlive()` helper to guard against `postMessage` on a disposed panel.

**`extension/src/i18n/locales/en.json`** — Removed `opportunities.card.copyForAi`. Added `opportunities.card.writeReport`, `opportunities.actions.writeReport`, `opportunities.report.noWorkspace`, `.noContent`, `.written`, `.failed`.

**`extension/src/test/vibrancy/views/opportunities-html.test.ts`** — Replaced the `data-prompt=` / `.opp-copy` assertion with a comprehensive test covering: global button present when cards exist, per-card button present only when `aiPrompt` is non-null, both absent in the empty state.

**`CHANGELOG.md`** — Added Changed entry for the button replacement. Updated existing Added bullets from "Copy for AI" to "AI prompt".

**`bugs/package_opportunities_report_insufficient.md`** — Archived to `plans/history/2026.08/2026.08.19/`.

### Hardening (post-review)

- **Disposed-panel guard**: `_postIfAlive()` wraps `postMessage` in try/catch so a panel closed during the async file write does not produce an unhandled rejection.
- **Multi-root workspace correctness**: `_writeReport()` and `_writeCardReport()` use `this._workspaceRoot` (the scanned pubspec's parent) instead of `resolveReportFolder()` which always picks `workspaceFolders[0]`.
- **writeLabel fallback**: webview script guards against empty `textContent` with `|| 'Write Report'`.
- **Stale doc comment**: file-header updated from "Copy for AI" to "Write Report".

### Verification

- `npx tsc --noEmit -p .` — clean.
- `npx tsc -p tsconfig.test.json` — clean.
- Mocha (opportunities-html, ai-prompt-bundle, dual-dependency-detector, local-reimplementation-detector) — 41/41 passing.

### Known gaps

- `OpportunitiesPanel` has no unit test file; `_writeReport()` and `_writeCardReport()` are covered only by type-checking and manual testing.
- Translation catalogs need regeneration (`generate_translations.py`) before publish — 5 new keys added, 1 removed.
- The `packageDashboard.detailPane.copyForAi` key in `en.json` (a separate panel) was intentionally left unchanged.

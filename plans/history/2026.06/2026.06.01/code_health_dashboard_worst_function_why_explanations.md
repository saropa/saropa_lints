# Code Health Dashboard — surface WHY each "worst function" scored low

The *Worst functions* table did not explain why each function scored low. The flag pills were single-word labels (`unused`, `complex`, `undocumented`) with no inline evidence; the threshold rule that fired was invisible; a reader had to triangulate across the Score / Usage / Coverage / Complexity / Changed columns to reconstruct why a given function landed on the list. This change adds inline evidence to each flag and a per-row expander arrow on the score field that lists the issues clearly.

## Finish Report (2026-06-01)

### Scope

VS Code extension only (`extension/src/views/*.ts`, `extension/src/i18n/locales/en.json`, `extension/src/test/views/projectVibrancyReportHtml.test.ts`, `CHANGELOG.md`). No Dart, no lint rules, no scoring change, no JSON payload change. Pure presentation in the Code Health Dashboard webview.

### What changed

1. **Inline evidence on every flag pill.** Each pill now reads `complex (CC 36)`, `unused (0 callers)`, `uncovered (0% tests)`, `undocumented (CC 36, no doc)`, `suspicious coverage (100% with no test)`, `test drift (tests lag the function)`, `stub-tested (thin asserts)`. The threshold rule sits in the `title=` tooltip for hover discovery. The evidence templates (`{cc}` / `{pct}` tokens) live in i18n (`codeHealth.flag.*`) and are substituted per-row at render time from `r.complexity` and `r.coveragePercent`.
2. **Score-cell expander chevron.** A chevron button (`▸` rotating to `▾`) sits beside the score pill inside `.col-score`. The column widened from 62px → 92px to accommodate it. Clicking toggles a detail row.
3. **Detail row that lists each issue with its threshold rule.** The expanded row spans all 9 columns (`colspan="9"`) and renders a `<ul>` where every flag becomes one item with three fields:
   - **label** (e.g. `complex`)
   - **evidence** (e.g. `CC 36`) — the actual measured value
   - **rule** (e.g. *"Flagged when cyclomatic complexity exceeds 10."*) — what the threshold actually is
   A row with no flags shows a short note pointing the reader to the column values above.
4. **Expand state survives sort / filter.** `state.expanded` is a `Set` keyed by `rowKey(r) = file:line:name`. `render()` checks the set when rebuilding the slice and interleaves a `<tr class="pv-detail-row">` after every expanded parent row. Sorting by complexity or applying a KPI filter no longer collapses open panels.
5. **i18n strings + tests.** Seven new flag descriptor blocks (`codeHealth.flag.<name>.{label,evidence,rule}`) plus four expander/detail strings (`codeHealth.table.expanderAriaCollapsed`, `expanderAriaExpanded`, `detailHeading`, `detailNoIssues`) added to `en.json`. Two new test cases pin the row-renderer scaffolding (`row-expander`, `flag-evidence`, `pv-detail-row`, `pv-detail-list`, `pv-detail-rule`) and the descriptor table's token preservation (`{cc}`, `{pct}` must remain in evidence templates).

### Files changed

| File | Change |
|---|---|
| `extension/src/views/projectVibrancyReportView.ts` | `codeHealthScriptStrings` gains four expander/detail keys. New `codeHealthFlagDescriptors()` builds the per-flag i18n descriptor table. Client script gains `FLAG_DESC` constant, `flagInfo(f, r)` helper, `state.expanded` map, `detailRowHtml(r)` renderer, expander-aware `rowHtml(r)`, interleaved-detail `render()`, dual-target tbody click delegate. |
| `extension/src/views/projectVibrancyReportStyles.ts` | New `rowExpanderAndDetailStyles()` (chevron, detail-panel grid layout, flag-evidence inline span, per-severity label colors). `col-score` width widened to 92px. |
| `extension/src/i18n/locales/en.json` | New `codeHealth.flag.{unused,uncovered,complex,undocumented,test_drift,stub_tested,suspicious_coverage}` blocks (label / evidence / rule). New `codeHealth.table.{expanderAriaCollapsed,expanderAriaExpanded,detailHeading,detailNoIssues}` strings. |
| `extension/src/test/views/projectVibrancyReportHtml.test.ts` | Two new tests: scaffolding pin + token-preservation pin. |
| `CHANGELOG.md` | New `[Unreleased]` section with one `### Changed (Extension)` entry. |

### Deep review notes

- **Score-pill alignment was previously `text-align: center` but is now `text-align: left`** because the cell carries two children (chevron + pill). Center alignment with two heterogeneous children read as wobbly; left is intentional. Stated explicitly in the consolidated `.col-score` rule.
- **`flagInfo(f, r)` is defensive about unknown flags** — if the CLI ever emits a flag not in `FLAG_DESC` (e.g. a future flag added on the Dart side before i18n catches up), the helper returns `{label: f.replace(/_/g, ' '), evidence: '', rule: ''}` so the pill still renders rather than crashing the client script.
- **`detailRowHtml(r)` uses `colspan="9"`** — exactly matches the thead's 9 columns. Adding a column later requires updating this number too; flagging for future work.
- **CSP**: no inline event handlers added. The expander uses delegated click handling on `#pvBody`, same channel as existing fn-link / file-link handlers. CSP `script-src 'nonce-…'` policy unchanged.
- **No scoring math touched.** `coverageScore`, `complexityScore`, `usageScore`, etc. are not re-derived in the webview — the existing CLI numbers are the source of truth. The detail panel describes what the *flag* tripped, not how the score was computed.
- **`FLAG_DESC` is shipped as a static JSON literal** embedded in the script. Cost: ~700 bytes per webview load; benefit: no async i18n resolution at row-render time. Worth it.

### Testing

- `tsc --noEmit -p extension/`: clean (exit 0).
- `tsc -p extension/tsconfig.test.json`: clean (exit 0).
- `mocha out-test/test/views/projectVibrancyReportHtml.test.js`: **21/21 passing** (19 existing + 2 new).
- `mocha out-test/test/views/**/*.test.js`: **167/167 passing**.
- Full extension `npm test`: 1185 passing. The 10 failures are all in `cross-file commands` (a feature not touched by this change and with pre-existing uncommitted state — `git log` confirms the test file has no commits since `9141c509` and the working tree has no relevant modifications). Out of scope per the "Never raise unrelated issues" rule.

### Out of scope / not done

- **`l10n.locales/*.json` for non-English locales.** Per project memory `project_i18n_mt_engine.md`, new strings ship in `en.json` only; the runtime falls back to English. No MT pipeline run (per global hard rule).
- **The three uncommitted vibrancy infrastructure files** (`extension-activation.ts`, `scan-helpers.ts`, `services/report-exporter.ts`) belong to the `[13.11.4]` "Scanned X ago" pill feature whose CHANGELOG already shipped. They are not this task's work and are left in the working tree per the "never commit another workstream's unverified feature code" rule.
- **`colspan="9"` is hard-coded.** If a new column is added to the thead later, the detail row must be widened to match. Not abstracted because abstracting a single magic number for one consumer is premature.

### Bug archive

`No bug archive — task did not close a bugs/*.md file.` This was a direct user UX feedback request, never tracked in `bugs/`.

### Finish report saved

`Finish report saved: plans/history/2026.06/2026.06.01/code_health_dashboard_worst_function_why_explanations.md`

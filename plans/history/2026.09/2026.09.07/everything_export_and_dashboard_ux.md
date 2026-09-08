# Everything Export & Dashboard UX Improvements

The Findings Dashboard lacked a way to export the full, unfiltered audit result (including suppressed findings) and had visual inconsistencies after the collapsible-sections/pill-unification work.

## Finish Report (2026-09-07)

### Changes

**Dart (`bin/audit.dart`, `lib/src/saropa_lint_rule.dart`)**
- `--include-suppressed` CLI flag on `dart run saropa_lints audit`: re-emits findings dropped by `// ignore:`, `// ignore_for_file:`, or baseline, each tagged with `suppressedBy`. Default output unchanged.
- Hot-path guard: `_resolveLocation` gained a `wantSpan` param gated on `SuppressionTracker.captureDetails`, avoiding an unconditional second binary search in in-editor analysis.
- `SuppressionTracker.reset()` now also resets `captureDetails = false`, preventing a long-lived process from retaining full diagnostic detail after a one-shot audit arms it.

**Extension — "Include suppressed" toggle (`extension/src/`)**
- `auditCliRunner.ts`: 7th param `includeSuppressed` on `spawnAuditCli()`; `AuditDiagnostic.suppressedBy?: string`; passthrough in `auditPayloadToViolationsData()`.
- `violationsReader.ts`: `Violation.suppressedBy?: string`.
- `violations-dashboard-shared.ts`: `auditScope.includeSuppressed: boolean` on input type; `DEFAULT_AUDIT_SCOPE` updated.
- `violationsWideReportView.ts`: `AuditScopeState.includeSuppressed`; 4 construction sites; `PersistedAuditScope.includeSuppressed?`; persist/hydrate/handler/CLI-threading all updated.
- `violations-dashboard-top.ts`: new checkbox field `#auditIncludeSuppressed` in `buildAuditScopeControl()`, hidden for live mode.
- `violations-dashboard-script.ts`: `auditScopeSelection()` reads checkbox; `syncAuditScopeUi()` toggles visibility.
- `violations-dashboard-tables.ts`: orange "Suppressed" pill badge on findings with `suppressedBy`.

**Extension — "Everything" export**
- `violations-dashboard-top.ts`: `buildMoreActionsMenu` gained `isAuditMode` param; conditionally renders `btn-copy-all` / `btn-save-all` items (audit mode only).
- `violations-dashboard-script.ts`: click handlers for `btn-copy-all`/`btn-save-all` posting `copyEverythingJson`/`saveEverythingJson`.
- `violationsWideReportView.ts`: shared `prepareEverythingExport()` helper; combined `copyEverythingJson`/`saveEverythingJson` handler reads `auditResult?.violations` (raw, unfiltered).

**Extension — Collapsible sections & pill unification**
- `violations-dashboard-shared.ts`: `buildCollapsibleSection()`, `resolveSectionOpen()`, `SectionOpenState`.
- All section builders (`-panels.ts`, `-tables.ts`, `-top.ts`) wrapped in `buildCollapsibleSection()`.
- `violationsDashboardHtml.ts`: threads `sectionOpenState` through to renderers.
- `violations-dashboard-script.ts`: persists open/closed state via `saveSectionState` message.
- `dashboardChromeStylesComponents.ts`: `.pill` unscoped from `.status-line .pill` to global `.pill` for consistency across sections.
- `dashboardChromeStylesSystem.ts`: chevron/summary styling for collapsible sections.

**Bugfix — Code Health KPI color regression**
- `projectVibrancyReportView.ts:680`: `kpiCard()` rendered `class="kpi-v"` without `.pill`, but CSS selectors in `dashboardChromeStylesComponents.ts` require `.kpi-v.pill` for semantic color coding. Fixed to `class="kpi-v pill"`.

**Localization**
- New `en.json` keys under `findingsDash.toolbar.*`, `findingsDash.audit.*`, `findingsDash.findings.*`, `findingsDash.kpi.*`, `wideReport.*`. All via `l10n()`.

**Hardening (reflection gate)**
- `projectVibrancyReportView.ts:680`: fixed `kpi-v` → `kpi-v pill` so Code Health KPI tiles regain semantic colors.
- `saropa_lint_rule.dart`: `SuppressionTracker.reset()` now also resets `captureDetails = false`.
- `violationsWideReportView.ts`: deduplicated everything-export prep into `prepareEverythingExport()` helper.
- Removed legacy `htmlId` field from `buildCollapsibleSection` — `getElementById('suppressions-block')` → `querySelector('[data-section-id="suppressions"]')`.
- Added `.pill` CSS cross-file documentation in chrome, healthPanel, and machineDashboard styles.
- Added `SCHEMA SYNC` comment in `suppressedDiagnosticMaps()` noting duplication with `scanDiagnosticsToJson()`.
- New test: `shows "everything" export items only in audit mode` in `violationsDashboardHtml.test.ts`.

**Suppressed Findings subsection**
- `violations-dashboard-shared.ts`: `SuppressedFindingsSlice` interface; `suppressedFindings?` on input type.
- `violationsWideReportView.ts`: `buildSuppressedFindingsSlice()` helper; wired into input; stub `unsuppress` handler.
- `violations-dashboard-panels.ts`: `buildSuppressedFindingsBlock()` + helpers (kind label, by-kind row, findings table).
- `violationsDashboardHtml.ts`: inserted after main findings, before suppressions aside.
- `violations-dashboard-script.ts`: event-delegation click handler for `[data-unsuppress]` buttons.
- `en.json`: 14 new keys under `findingsDash.suppressedFindings.*`.

**Hardening (second reflection gate)**
- `.pill.pill` doubled CSS selector: raises specificity above single-class `.pill` overrides structurally, replacing source-order dependence between chrome, healthPanel, and machineDashboard styles.
- Two new tests for suppressed findings section HTML: presence test (with slice) and absence test (without slice, using `aria-label` instead of `data-section-id` to avoid false positive from inline script querySelector string).
- `SuppressionTracker.reset()` now also resets `captureDetails = false`, preventing cost leak in long-lived processes.
- Deduplicated everything-export prep into `prepareEverythingExport()` helper.

**"Suppress all visible" bulk action**
- `violations-dashboard-top.ts`: new "Suppress all visible" menu item under "Bulk actions" group, disabled at 0 findings.
- `violations-dashboard-script.ts`: click handler posts `suppressAllVisible` message.
- `violationsWideReportView.ts`: `suppressAllVisible()` reads each affected file once, inserts `// ignore: <rule>` in descending line order (so earlier inserts don't shift later targets), with indentation preservation and modal confirmation dialog. All strings l10n'd.
- `en.json`: 6 new keys under `findingsDash.toolbar.suppressAll*`, 1 under `findingsDash.menuPalette.menuGroupBulk`.

### Test results
- `dart test test/cli/audit_include_suppressed_test.dart` — 5/5 pass
- Extension mocha — 413/413 pass
- `npx tsc --noEmit -p .` — exit 0
- `npx tsc -p tsconfig.test.json` — exit 0

### Known limitations
- All UI changes are unverified visually (no F5 + screenshot) per `.claude/rules/extension-verification.md`.
- `scripts/modules/_utils.py` has a pre-existing edge case: odd-minor stable versions are misidentified as already-converted (not introduced by this work).
- `suppressedDiagnosticMaps()` in `bin/audit.dart` hand-builds the same diagnostic JSON shape as `scanDiagnosticsToJson()` — schema duplication risk (documented with SCHEMA SYNC comment).
- Unsuppress action is a stub (shows hint message) — actual `// ignore:` comment removal is complex and deferred.

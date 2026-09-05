# WP7 Verification and Plan Archival

Session resumed from handover `20260904_2330_sidebar_collapse_wp7_and_archive` to
complete the final verification and cleanup tasks from the sidebar row-collapse
work (WP0–WP6, landed in `120f3049`).

## Finish Report (2026-09-05)

### WP7 Verification
- TypeScript type-check (`npm run check-types`): clean, zero errors.
- Test compilation (`tsc -p tsconfig.test.json`): clean.
- Mocha view tests: 225 passing, 0 failing — all 15 pre-existing failures
  fixed (see "Test fixes" below).
- Extension Development Host visual verification: not performed (requires
  interactive GUI launch).

### Test fixes (15 pre-existing failures → 0)
- **13× issuesTree.test.ts:** `IssuesTreeProvider` constructor calls
  `vscode.workspace.onDidChangeConfiguration`, but the test mock in
  `vscode-mock.ts` did not stub it → `TypeError`. Added the stub
  (`onDidChangeConfiguration` returning a disposable no-op).
- **1× languagePick.test.ts:** Test asserted `zh` at 4% coverage and `de`
  at 100%. Both locales now sit at 93% per `locale_coverage.json`. Updated
  assertions to match the current generated coverage data.
- **1× uxLabels.test.ts:** Test expected 5 sidebar panels including
  `saropaLints.help`. Help was deliberately removed in Phase 1 sidebar
  collapse (commands moved to Dashboards overflow menu). Updated to expect
  4 panels and added a negative assertion for `saropaLints.help`.

### Plan archival
- `plans/PLAN_sidebar_row_collapse.md` → `plans/history/2026.09/2026.09.04/`
- `plans/AUDIT_extension_ux_facts.md` → `plans/history/2026.09/2026.09.04/`
- Parent plan `plans/PLAN_extension_ui_redesign.md` retained — Phase 1
  (badges, empty states) and Phase 5 (style migration, tab embedding) still
  partially done. Stale path reference to archived sub-plan updated.

### Handover pruning
- 21 old handover files (Sep 3–4) moved from `docs/handover/` to
  `docs/handover/archive/` (gitignored). One active handover retained.

### Remaining work farmed out
Three focused handover documents written for independent Sonnet sessions:
1. `20260904_2345_phase1_badges_and_empty_states` — live sidebar badges +
   empty/off/error state audit (Phase 1 completion).
2. `20260904_2346_phase5_style_migration` — migrate `report-styles*.ts`
   (52KB + 99KB) onto `dashboardChromeStyles` (Phase 5).
3. `20260904_2347_phase5_tab_embedding_and_commands` — embed 4 deep-link
   tabs as real DOM panels + further command reduction (Phase 5). Depends
   on #2 ideally landing first.

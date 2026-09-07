# Sidebar Dynamic Descriptions and Badge Fix

The VS Code extension's activity bar badge showed "79" with no explanation anywhere in the sidebar. Investigation revealed the number was adoption needles (informational package feature counts), not lint violations. Sidebar row descriptions were inconsistent — some static format labels, some dynamic counts, some settings.

## Changes

### SidebarDataSnapshot (sectionedSidebar.ts)

- Introduced `SidebarDataSnapshot` interface and `getSnapshot()` — computes all sidebar-relevant data (filtered violations, health score, total/critical counts) once per refresh cycle. All three consumers (Findings row, Health row, Status badge) read from this single snapshot, eliminating duplicate `readVisibleLiveViolations` + `computeLiveHealthScore` calls and guaranteeing all rows show identical numbers.
- `loadFilteredViolations` now delegates to `getSnapshot` instead of maintaining its own cache.
- `computeStatusBadge` reads from the snapshot instead of re-parsing violations data.
- `appendHealthRow` accepts `healthScore: number | null` from the snapshot instead of calling `computeLiveHealthScore` independently.

### Badge (sectionedSidebar.ts)

- Removed `computeDashboardsBadge()` — adoption needles are informational, not problems. The activity bar badge now reflects only lint violations via `computeStatusBadge()`.
- Removed dead l10n key `dashboards.badge.needlesTooltip` from `en.json` and all 24 translated locale files.

### Dynamic row descriptions (sectionedSidebar.ts)

- Added `buildFindingsDescription(snapshot)` — shows `{count} violations · score {score}`, `No violations · score {score}`, or `Run analysis to scan` depending on state.
- Added `buildPackageDescription()` — shows `{count} packages to adopt`, `All features adopted`, or `Run scan to check dependencies`.
- 7 new l10n keys under `sidebar.dashboards.*` in `en.json`.

### Bug reports filed

- `bugs/bug_analysis_runs_dart_analyze_not_lsp.md` — Run Analysis spawns `dart analyze` instead of using the existing LSP client or live diagnostics model.
- `plans/history/2026.09/2026.09.07/bug_commands_not_found_on_activation.md` — commands fail when activation setup throws before the registration block. **Fixed.**
- `bugs/bug_prune_ignores_crashes_flutter_daemon.md` — `dart run` competes for `.dart_tool/` locks with the Flutter daemon.

## Finish Report (2026-09-07)

Scope: VS Code extension sidebar (TypeScript). Four user-reported issues triaged: (1) misleading activity bar badge, (2) slow analysis, (3) missing commands, (4) prune ignores crash. Issue 1 was fixed directly; issues 2-4 were filed as bug reports (2-3 were fixed by another session during this conversation, 4 remains open with a partial mitigation). The sidebar description consistency problem was identified during the badge investigation and addressed in the same change. Code review identified a duplicate diagnostics read, resolved by the SidebarDataSnapshot refactor.

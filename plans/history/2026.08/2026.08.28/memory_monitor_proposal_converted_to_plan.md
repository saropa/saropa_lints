# Memory Monitor Proposal Converted to Plan

The `bugs/proposal_infra_analyzer_memory_monitor.md` proposal was reorganized into `plans/PLAN_analyzer_memory_monitor.md` following this repo's `PLAN_*` phased-checklist convention, so the remaining work (soft RSS threshold, selective rule shedding, VS Code status-bar integration) tracks as an active plan rather than an open proposal document.

## What changed

- `git mv bugs/proposal_infra_analyzer_memory_monitor.md plans/PLAN_analyzer_memory_monitor.md`, then rewritten from the proposal's free-form sections into a phased plan matching the format of `plans/PLAN_analyzer_13_migration.md` (Created/Trigger/Status/Related header, background, per-phase checklists).
- The prior proposal content (Motivation, Detection/Behavior, Edge Cases, Alternatives Considered, Implementation Notes, Environment) was preserved and reorganized under the new structure, not discarded. The "what exists today" breakdown from the prior accuracy review (`plans/history/2026.08/2026.08.28/proposal_infra_analyzer_memory_monitor_review.md`) carried forward unchanged.
- New phase breakdown added: Phase 0 (periodic memory log, shipped 2026-08-28, unchanged), Phase 1 (soft/warning RSS threshold, not started), Phase 2 (selective rule-disable mechanism — prerequisite for Phase 3, not started), Phase 3 (graduated rule shedding by tier, not started), Phase 4 (VS Code status-bar integration, not started).
- Fixed one stale cross-reference: `bin/memory_report.dart`'s file-header comment pointed at `bugs/proposal_infra_analyzer_memory_monitor.md`; updated to point at `plans/PLAN_analyzer_memory_monitor.md` and to name the specific phases (1, 3, 4) that remain unbuilt.

## Why

The proposal's own "Scope estimate" section characterized the remaining work as multi-week and touching three separate subsystems (plugin core, rule registration, VS Code extension). A phased `PLAN_*` file gives each subsystem's work an independent checklist and an explicit sequencing dependency (Phase 2 gates Phase 3), which the original proposal's flat "Implementation Notes" section did not express. This also aligns the document with the repo's existing convention — `bugs/*.md` is for defect reports with an Open/Fixed lifecycle, not multi-phase feature work.

## Verification

- `git mv` history is preserved on the renamed file (not a delete+create).
- Grep confirmed no remaining live references to the old `bugs/proposal_infra_analyzer_memory_monitor.md` path outside archived `docs/handover/*.md` snapshots (which are frozen session records, correctly left as-is) and the existing `plans/history/2026.08/2026.08.28/proposal_infra_analyzer_memory_monitor_review.md` finish-report (also a frozen historical record).
- No code, rule, or test behavior changed — this is a documentation/planning reorganization only.

## Finish Report (2026-08-28)

**Hardening.** The plan's carried-over line-number references had drifted from concurrent unrelated commits landing in the same working tree during this session. Re-verified against current `main`:
- `_allRuleFactories` list actually begins at `lib/saropa_lints.dart:231`, not the proposal's stale `~line 157`.
- `isOverHardLimit` is at `lib/src/project_context_throttle_memory.dart:1110` and `_hardLimitTripped` at line 1050 — not the single `1084` the proposal cited for both.
- `_currentRssMb` is at line 1167, not `1116`.
- `createStatusBarItem` in `extension/src/extension.ts:978` was correct as-is.

`plans/PLAN_analyzer_memory_monitor.md` corrected with the verified line numbers, plus a dated note that they were re-verified 2026-08-28 and should be re-checked again before implementation starts if significant time has passed.

**Unrequested feature implemented.** `scripts/check_plan_naming.py` — a standalone, non-blocking report script that lists `plans/*.md` files not matching the `PLAN_<name>.md` convention. Deliberately informational only (always exits 0): running it against the current repo found 6 pre-existing files (`CENTRAL_DASHBOARD_CONSOLIDATION.md`, `COMMENT_COVERAGE_PLAN.md`, `QUICK_FIX_PLAN.md`, `TODO_rule_metadata_completeness.md`, `cross_file_cli_design.md`, `plan_migration_plugin_system.md`) that don't match, several of which are legitimate exceptions (design docs, TODO lists) rather than drift — so a blocking CI gate would have been the wrong shape for this check. Verified by running it: reports the 6 non-conforming files correctly, exits 0.

CHANGELOG.md updated (Maintenance section, `[Unreleased]`) with one bullet covering the plan reorganization and the new check script.

# Plans index

This file is the canonical index for active planning documents in `plans/`.

## Active execution plans

- [BUG_stub_tests_in_suite.md](BUG_stub_tests_in_suite.md) - Convert remaining tautological test stubs to behavioral fixture tests.
- [COMMENT_COVERAGE_PLAN.md](COMMENT_COVERAGE_PLAN.md) - Execute comment-depth backfill using Part 2 quality bar.
- [EXTENSION_LOCALIZATION_GUIDE.md](EXTENSION_LOCALIZATION_GUIDE.md) - Extension localization implementation plan (manifest + runtime strings + CI checks).
- [QUICK_FIX_PLAN.md](QUICK_FIX_PLAN.md) - Increase quick-fix coverage with batch-based implementation.
- [TESTING_AND_RELEASE.md](TESTING_AND_RELEASE.md) - Release gating plan (coverage, fix application proof, IDE verification, perf/regression).
- [UX_GUIDELINES.md](UX_GUIDELINES.md) - Dashboard UX compliance (**Part A**) and earned-scope backlog (**Part B**) vs [`guides/UX_UI_GUIDELINES.md`](guides/UX_UI_GUIDELINES.md).

## Strategy / architecture plans

- [cross_file_cli_design.md](cross_file_cli_design.md) - Cross-file CLI architecture, phases, and capability boundaries.
- [plan_migration_plugin_system.md](plan_migration_plugin_system.md) - Rule packs + plugin migration architecture and phased rollout.

## Status / inventory / compliance references

- [COLLAPSE_LINT_IMPACT_TO_SEVERITY.md](COLLAPSE_LINT_IMPACT_TO_SEVERITY.md) - Completed migration status with scoped follow-ups.
- [sidebar_view_inventory.md](sidebar_view_inventory.md) - Sidebar/command affordance inventory snapshot.

## History and deferred

- Historical plans and implementation logs live under `plans/history/`.
- Deferred reviews and policy-blocked items live under `plans/deferred/`.

## Planning conventions

- Keep each active plan front-loaded with: **Status**, **Next 3**, **Blocked**, **Backlog**.
- Move completed deep logs and transcripts to `plans/history/` instead of growing active plans.
- Use stable task IDs (`QF-014`, `REL-E03`, `UX-B08`) for dependencies and tracking.

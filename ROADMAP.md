<!-- AUTO-SYNC: The heading and Goal line below are updated by the publish
     script via sync_roadmap_header() in scripts/modules/_rule_metrics.py.
     Heading regex: "# Roadmap: Aiming for N,NNN"
     Goal regex:    "Goal: NNN rules (NNN implemented, NNN remaining)"
     Goal is rounded up to the nearest 100. -->
# Roadmap: Aiming for 2,200 Lint Rules
<!-- cspell:disable -->

See [CHANGELOG.md](CHANGELOG.md) for implemented rules. Goal: 2200 rules (2107 implemented, 93 remaining).

> **Clarification**: `remaining` is the arithmetic gap to the package goal (`goal - implemented`), not the number of items explicitly listed in this roadmap and not the number of plan documents.

> **When implementing**: Remove from ROADMAP, add to CHANGELOG, register in `all_rules.dart` + `tiers.dart`. See [CONTRIBUTING.md](CONTRIBUTING.md).

> **Deferred rules**: Rules we cannot implement today are documented with full justification in [plans/deferred/](plans/deferred/). Do not re-propose rules listed there without addressing the stated barrier.

> **This file is the consolidated roadmap.** It absorbs the former `plans/TODO_BUILD_NEXT.md` (build backlog) and `plans/README.md` (planning index). Sections are grouped by purpose, not by their original file.

---

## Part 1: Technical Debt & Improvements

### SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

Details and design notes for each enhancement are in the plan docs:
`plans/discussion_056_suppression_tracking.md`, `plans/history/2026.04/2026.04.28/discussion_061_tier_based_filtering.md`,
`plans/deferred/discussion_059_custom_ignore_prefixes.md`, and historical snapshots in
`plans/history/` (including `discussion_055_diagnostic_statistics.md`,
`discussion_057_related_rules.md`, `discussion_058_batch_deduplication.md`, and
`discussion_060_performance_tracking.md`).

| Enhancement | Status | Notes |
|-------------|--------|-------|
| Suppression tracking and governance ([Discussion #56](plans/discussion_056_suppression_tracking.md)) | Done | Plugin tracking, extension Suppressions sidebar, overview suppression-rate metric, and CI/export schema/reporting are complete. |
| Tier-based filtering ([Discussion #61](plans/history/2026.04/2026.04.28/discussion_061_tier_based_filtering.md)) | Done | Runtime cap via `SAROPA_TIER` / YAML (`saropa_tier`, `runtime_tier`); filters enabled set and visitor execution. |
| Custom suppression prefixes ([Discussion #59](plans/deferred/discussion_059_custom_ignore_prefixes.md)) | Deferred | Policy-blocked; do not implement custom ignore parsing under current project policy. |

#### Severity model — `LintImpact` collapse follow-ups

The `LintImpact` five-bucket enum (`critical/high/medium/low/opinionated`) was collapsed into the analyzer's three-level model (`error/warning/info`) and shipped. The core migration is complete and verified in code. Remaining follow-ups (full rationale in `plans/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md`):

| Item | Priority | Status | Notes |
|------|----------|--------|-------|
| SEV-01 — Audit `severity:` assignments rule-by-rule against MUST-fix / should-fix / info guidance | P1 | Open | Audit order: (1) security/network input + auth/storage, (2) architecture/disposal + async core, (3) naming/style and likely-overrated historical criticals. |
| SEV-02 — Update `saropa_quality_gate.yaml.example` to foreground `new_errors/new_warnings/new_info` | P1 | Done (2026-05-08) | Primary row uses `new_errors`; hotspots + `overall_warnings` documented with legacy-alias pointer. |
| SEV-03 — Rename `bin/impact_report.dart` to `severity_report.dart` with compatibility alias | P2 | Open | File is still `bin/impact_report.dart`. |
| SEV-04 — Verify internal scripts parsing `v.impact` accept `error|warning|info` value set | P2 | Open | `scripts/modules/_audit_checks.py` still carries the old `["critical","high","medium","low"]` set and color map. |

---

## Part 2: Implementable Rules

Rules below can be implemented with existing infrastructure or moderate new work. Grouped by the type of work needed.

### Platform Config Cross-Reference Rules

These rules follow the **existing Info.plist pattern**: a Dart rule fires when it detects API usage, then cross-checks a platform config file. `info_plist_utils.dart` already does this for iOS permission checks. The same approach works for other config files — each just needs a parser.

Recent additions from this bucket include `avoid_audio_in_background_without_config`, `avoid_geolocator_background_without_config`, `require_notification_icon_kept`, `require_firestore_security_rules`, and `require_env_file_gitignore` (see [CHANGELOG.md](CHANGELOG.md)).

**GitHub issues**: [#35](https://github.com/saropa/saropa_lints/issues/35), [#36](https://github.com/saropa/saropa_lints/issues/36), [#37](https://github.com/saropa/saropa_lints/issues/37), [#41](https://github.com/saropa/saropa_lints/issues/41)

The eight-rule batch originally scoped in this bucket (Android manifest, Info.plist, desktop window, background audio/geolocation, notification-icon keep, Firestore rules, `.env` gitignore) has **fully shipped** — all eight are live in `lib/src/tiers.dart` (see [CHANGELOG.md](CHANGELOG.md)). The bucket stays as a pattern reference for any future config-cross-reference rule: detect API usage in Dart, then cross-check the platform/repo config file via a small dedicated parser (the `InfoPlistChecker` model in `lib/src/info_plist_utils.dart`), gated on `ProjectContext`.

### Cross-File CLI Improvements

The CLI tool (`dart run saropa_lints:cross_file`) is functional but can be improved. See [plans/cross_file_cli_design.md](plans/cross_file_cli_design.md) for the full design.

| Improvement | Status |
|-------------|--------|
| Unused files detection | Done |
| Circular dependency detection | Done |
| Import statistics | Done |
| HTML reports | Done |
| Baseline integration | Done |
| CI exit codes | Done |
| Watch mode | In progress |
| Unused symbols detection (top-level) | Done |
| Cross-feature dependency analysis | Done |
| Dead import detection | In progress |
| Extension UI integration (commands + walkthrough + catalog) | Done |

### Project Vibrancy (planning)

Project-level code health scoring and surfacing plan snapshot lives in [plans/history/2026.04/2026.04.28/project_vibrancy_report.md](plans/history/2026.04/2026.04.28/project_vibrancy_report.md). For execution order, see the **MVP Slice (first ship)** section in that document (collectors + scoring + CLI first, UI later).

| Initiative | Status |
|------------|--------|
| Project Vibrancy MVP (collectors + scoring + CLI) | In progress (CLI JSON/text, scoped scans, CI gates including coverage-quality counts; analyzer-element usage + full plan parity ongoing — see plan snapshot) |
| Project Vibrancy UI surfaces (tree/editor/HTML/history) | In progress (function report webview; native tree, editor overlays, history/trends pending — see plan snapshot) |

---

## Part 3: Build Backlog — Cross-File / Project-Graph Rules

These rules are **deferred as single-plugin-file rules** today: the analyzer plugin is per-file, and these need **project-wide graphs** or **test-layout** knowledge. The practical "build" is extending `dart run saropa_lints:cross_file`, `ImportGraphCache`, and/or the extension sidebar so these become enforceable without false confidence from AST-only heuristics.

**Where to implement first:** `lib/src/project_context_import_location.dart` (`ImportGraphCache`, `getImporters()`, `detectCircularImports()`), `lib/src/cli/cross_file_analyzer.dart`, `bin/cross_file.dart`, design notes in [plans/cross_file_cli_design.md](plans/cross_file_cli_design.md). Top-level **unused symbols** and **cross-feature** analysis already ship in the cross-file CLI; **dead imports** and **watch** remain iterative.

Background: `plans/deferred/cross_file_analysis.md` documents the per-file limitation and "what would unblock" these.

### Provider / navigation (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 9 | `avoid_provider_circular_dependency` | ERROR | Provider graph across files — [issue #2](https://github.com/saropa/saropa_lints/issues/2) |
| 10 | `avoid_riverpod_circular_provider` | ERROR | `ref.watch` / `ref.read` dependency cycle — [issue #1](https://github.com/saropa/saropa_lints/issues/1) |
| 11 | `require_riverpod_test_override` | INFO | Overrides may live in `test/` harness files separate from tests |
| 12 | `require_go_router_deep_link_test` | INFO | Route tables vs test files |

**Implementation sketch:** Build a **directed graph** of providers (node = library or top-level provider field); cycles → ERROR. Start with **static** `ref.watch(a)` edges only; document false negatives for dynamic providers.

### Project / coverage / barrels (3)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 13 | `require_test_coverage_threshold` | INFO | LCOV or `dart test --coverage` output aggregation |
| 14 | `require_test_golden_threshold` | INFO | Golden file counts vs `matchesGoldenFile` usages |
| 15 | `require_barrel_files` | INFO | Import graph: many sibling imports → suggest barrel |

**Refs:** CLI `import-stats` / graph today; coverage is a **new CLI command** or CI wrapper, not a Dart lint visitor.

### Bloc (2)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 16 | `require_riverpod_override_in_tests` | INFO | Same multi-file override concern as #11 |
| 17 | `require_bloc_test_coverage` | INFO | Bloc/Cubit classes vs `bloc_test` usage across `test/` |

### Unused / dead code (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 18 | `require_e2e_coverage` | INFO | Integration test layout vs `lib/` features |
| 19 | `avoid_never_passed_parameters` | INFO | All call sites of a parameter (AnalysisContextCollection in future) |
| 20 | `require_missing_test_files` | INFO | For each `lib/foo.dart`, check `test/foo_test.dart` (naming convention) |
| 21 | `require_temp_file_cleanup` | INFO | `Directory.systemTemp` / `createTemp` usage vs `delete` in same file or project — conservative heuristic |

### Architecture / DI (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 22 | `avoid_getit_unregistered_access` | INFO | Registration in `injection.dart` vs `GetIt.I<>` in widgets |
| 23 | `require_crash_reporting` | INFO | Single `FirebaseCrashlytics.instance` setup vs many `recordError` call sites |
| 24 | `prefer_layer_separation` | INFO | Import direction: `domain` must not import `ui` — layer graph from path conventions |
| 25 | `require_di_module_separation` | INFO | See `plans/history/2026.03/20260301/task_require_di_module_separation.md`; also "Hard" in `plans/history/2026.03/20260302/REMAINING_ROADMAP_RULES.md` |

**Note:** Treat Part 3 as **CLI + baseline + HTML report** first; IDE squiggles only if the analyzer gains a multi-file API.

### Package-specific cross-file (follow-up batch — not in the 25 above)

Documented in `plans/deferred/cross_file_analysis.md` ("Package-Specific Cross-File" and "Misc" tables); omitted from the count above to keep the backlog at 25: `require_supabase_auth_state_listener`, `require_workmanager_unique_name`, `require_iap_restore_handling`, `handle_bloc_event_subclasses`, `require_timezone_initialization`, `avoid_envied_secrets_in_repo`, `prefer_correct_screenshots`, `prefer_intent_filter_export`, `require_resource_tracker`.

### Explicit non-candidates (do not duplicate)

- **Analyzer duplicates:** `plans/deferred/plan_additional_rules_41_through_50.md` — entire batch deferred as built-in `dart analyze` diagnostics.
- **Many "additional rules" 51–70:** same rationale in plan history — prefer domain-specific value.
- **Already implemented** examples from plan history: `return_in_generator`, `yield_in_non_generator`, `non_constant_map_element`, `abstract_field_initializer`, `avoid_inert_animation_value_in_build` — see `lib/src/rules/flow/control_flow_rules.dart`, `lib/src/rules/data/collection_rules.dart`, `lib/src/rules/architecture/compile_time_syntax_rules.dart`, `lib/src/rules/ui/animation_rules.dart`.

### Suggested build order

1. **Infrastructure:** Android XML + `.gitignore` text parsers (unlocks #1, #4, #5, #8).
2. **Firestore / ProGuard** text heuristics (#6, #7).
3. **Desktop** file probes (#3).
4. **CLI graph extensions** for #9–#12 (highest GitHub demand).
5. **Coverage / test-file presence** commands (#13–#14, #20).
6. **Layer / DI** conventions behind `--path` and config file (#24–#25).

---

## Stylistic Rule Pairs and Overlaps

Some rules intentionally conflict or overlap; the **init wizard** (`dart run saropa_lints:init --stylistic`) lets users choose which stylistic rules to enable. This is by design, not a bug.

| Relationship | Rules | Notes |
|--------------|--------|--------|
| **Intentional pair** | `avoid_cubit_usage` vs `prefer_cubit_for_simple_state` | Opposite preferences: prefer Bloc (event traceability) vs prefer Cubit for simple state. Enable one via the wizard. |
| **Narrow variant** | `prefer_expression_body_getters` vs `prefer_arrow_functions` | Getter-only vs all single-expression bodies. Can enable both or just one. |
| **Narrow variant** | `prefer_super_parameters` vs `prefer_super_key` | Both can flag `super(key: key)` on widgets; `prefer_super_key` is Flutter-widget + `Key` only. |
| **Intentional pair** | `prefer_caret_version_syntax` vs `prefer_pinned_version_syntax` | Extension-side pubspec diagnostics. Caret (default) vs exact pin. Controlled via `preferPinnedVersions` flag. |
| **Other pairs** | e.g. `prefer_type_over_var` / `prefer_var_over_explicit_type` | Documented in rule DartDoc and CHANGELOG; wizard shows both so users pick one. |

When adding or reviewing rules, check CODE_INDEX and tiers for existing stylistic opposites; document pairs in the rule's DartDoc and, if needed, in this table.

---

## Deferred Rules

Rules that cannot be implemented today are split into focused documents by barrier type:

| Document | Barrier | Rule count |
|----------|---------|------------|
| [cross_file_analysis.md](plans/deferred/cross_file_analysis.md) | Single-file AST — needs multi-Dart-file analysis | 26 |
| [unreliable_detection.md](plans/deferred/unreliable_detection.md) | Heuristic / subjective / no AST pattern | 54 |
| [external_dependencies.md](plans/deferred/external_dependencies.md) | Needs pub.dev API or maintained databases | 5 |
| [framework_limitations.md](plans/deferred/framework_limitations.md) | Blocked by analyzer/IDE API limitations | 15 |
| [compiler_diagnostics.md](plans/deferred/compiler_diagnostics.md) | Duplicates Dart compiler checks — high effort, low value | 28 |
| [not_viable.md](plans/deferred/not_viable.md) | Reviewed and permanently rejected | 14 |

**Total deferred: ~142 rules/items.** These will not be implemented until the stated barrier is addressed.

---

## Planning Documents Index

Canonical index for planning documents under `plans/`.

### Active execution plans

- `plans/BUG_stub_tests_in_suite.md` — Convert remaining tautological test stubs to behavioral fixture tests.
- `plans/COMMENT_COVERAGE_PLAN.md` — Execute comment-depth backfill using the Part 2 quality bar.
- `plans/EXTENSION_LOCALIZATION_GUIDE.md` — Extension localization implementation plan (manifest + runtime strings + CI checks).
- `plans/QUICK_FIX_PLAN.md` — Increase quick-fix coverage with batch-based implementation.
- `plans/TESTING_AND_RELEASE.md` — Release gating plan (coverage, fix-application proof, IDE verification, perf/regression).
- `plans/UX_GUIDELINES.md` — Dashboard UX compliance (**Part A**) and earned-scope backlog (**Part B**) vs `plans/guides/UX_UI_GUIDELINES.md`.

### Strategy / architecture plans

- `plans/cross_file_cli_design.md` — Cross-file CLI architecture, phases, and capability boundaries.
- `plans/plan_migration_plugin_system.md` — Rule packs + plugin migration architecture and phased rollout.

### Status / inventory / compliance references

- `plans/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md` — Completed `LintImpact → severity` migration status with scoped follow-ups (tracked above under Part 1).
- `plans/sidebar_view_inventory.md` — Sidebar/command affordance inventory snapshot.

### History and deferred

- Historical plans and implementation logs live under `plans/history/`.
- Deferred reviews and policy-blocked items live under `plans/deferred/`.

### Planning conventions

- Keep each active plan front-loaded with: **Status**, **Next 3**, **Blocked**, **Backlog**.
- Move completed deep logs and transcripts to `plans/history/` instead of growing active plans.
- Use stable task IDs (`QF-014`, `REL-E03`, `UX-B08`) for dependencies and tracking.

### Workflow for any new rule

See CONTRIBUTING.md, CLAUDE.md, `.claude/skills/lint-rules/SKILL.md`. Checklist: implement in the right `lib/src/rules/*` file, register in `lib/src/rules/all_rules.dart` **and** `lib/src/tiers.dart`, add a fixture in `example/` (only when the BAD example actually fires), add a test under `test/`, and add a `CHANGELOG.md` entry under Unreleased.

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

---

> **Package-specific rule sources** have been moved to [LINKS.md](LINKS.md#package-specific-rule-sources).

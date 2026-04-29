# PLAN: Comment coverage for worst-offender source files

**Status:** Completed 2026-04-28 — file-level `//` / `/** */` / `///` notes added for batches A–D (100 paths). Archive under `plan/history/` when you want it out of the active plan list.  
**Date:** 2026-04-28  
**Scope:** Improve *minimum useful* documentation in the **100** largest files (by physical line count) that currently register **zero** comment tokens under the publish-script metric (see below), tracked in four batches (A–D).  
**Non-goal:** Line-by-line narration, restating obvious code, or chasing a target comment density.

---

## How the list was produced

- **Scanner:** `scripts/modules/_code_comment_metrics.py` (same heuristics as the publish banner).
- **Roots:** `lib/`, `test/`, `bin/`, `packages/*/lib/`, `extension/src/`, `scripts/` (excludes `.g.dart`, `*_generated.dart`, and junk dirs such as `node_modules`, `.dart_tool`, `build`).
- **“Comment” for Dart/TS:** `//` and `/* … */` outside strings and (for TS) outside template literals / `${…}` bodies.
- **“Comment” for Python:** `#` tokens via `tokenize` (docstrings are **not** counted by the metric—adding module/class docstrings still helps humans even if the banner stays unchanged until/unless the metric is extended).
- **Ranking:** Among files with **≥ 15** physical lines and **0** comment lines as defined above, sort by **line count descending**. **Batch A:** 1–25, **B:** 26–50, **C:** 51–75, **D:** 76–100 (next slices of that same sorted list).

Re-run ranking after edits if you need an updated list.

---

## What comments should **at least** cover

These are **minimum** expectations so a maintainer can change code without reverse-engineering intent. Prefer the project norm: short **why** / **invariant** / **edge case** notes; do not restate control flow that the code already expresses (see `.cursor/rules/comment-quality-default.mdc`).

### 1. Library Dart (`lib/**`)

- **Public types and top-level functions:** A `///` summary of purpose, inputs/outputs where non-obvious, and constraints (e.g. “must run after resolver is attached”).
- **Non-trivial algorithms or branches:** One line before the block explaining the trade-off, false-positive avoidance, or protocol/security assumption.
- **Magic numbers, thresholds, and time limits:** Either named constants with `///` or an adjacent `//` explaining the source of the value (spec, empirical cap, CI budget).

### 2. Tests (`test/**`, `extension/src/test/**`)

- **File or describe-block level:** What product behavior or regression this file guards; what is intentionally *not* covered.
- **Large arrange/setup sections:** Short section headers (`// --- migration: widget binding ---`) so failures map to scenarios without reading every `expect`.
- **Fixtures and golden assumptions:** What external shape (JSON, URI, tier) is frozen and why changing it is a breaking change.

### 3. Extension product code (`extension/src/**` excluding `test/`)

- **Module entry / providers / views:** How the piece fits VS Code (activation, commands, webview, tree id); lifecycle and disposal expectations.
- **Async and file watchers:** Why ordering matters, debounce rationale, and “do not X on Y event” invariants.
- **Telemetry and user-visible strings:** Not full copy in comments—note *policy* (PII, sampling) where logic is subtle.

### 4. Scripts (`scripts/**`)

- **Pipeline and exit semantics:** How this step relates to publish/CI; what failure modes return which exit codes.
- **Non-obvious regex, path, or encoding choices:** Windows vs POSIX, UTF-8 reconfiguration, why a guard exists.

### 5. Binaries (`bin/**`)

- **CLI contract:** Flags, stdin/stdout, and what “success” means for automation.

---

## Batch A — ranks 1–25 (zero comment lines, largest first)

| Rank | Lines | Path |
|-----:|------:|------|
| 1 | 421 | `test/flutter_migration_widget_detection_test.dart` |
| 2 | 415 | `extension/src/vibrancy/providers/tree-data-provider.ts` |
| 3 | 337 | `extension/src/test/vibrancy/services/changelog-service.test.ts` |
| 4 | 332 | `extension/src/views/projectVibrancySidebarProvider.ts` |
| 5 | 314 | `extension/src/test/vibrancy/problems/problem-actions.test.ts` |
| 6 | 307 | `extension/src/test/vibrancy/services/ci-generator.test.ts` |
| 7 | 300 | `lib/src/report/quality_gate.dart` |
| 8 | 275 | `extension/src/test/vibrancy/services/freshness-watcher.test.ts` |
| 9 | 274 | `test/project_vibrancy_cli_test.dart` |
| 10 | 272 | `extension/src/vibrancy/views/comparison-html.ts` |
| 11 | 262 | `extension/src/test/vibrancy/problems/problem-registry.test.ts` |
| 12 | 259 | `extension/src/test/vibrancy/services/dependency-differ.test.ts` |
| 13 | 248 | `extension/src/test/vibrancy/services/version-comparator.test.ts` |
| 14 | 239 | `extension/src/test/vibrancy/services/bulk-updater.test.ts` |
| 15 | 238 | `extension/src/test/vibrancy/providers/code-action-provider.test.ts` |
| 16 | 213 | `extension/src/test/vibrancy/services/registry-service.test.ts` |
| 17 | 206 | `extension/src/test/vibrancy/scoring/issue-signals.test.ts` |
| 18 | 200 | `test/image_filter_quality_detection_test.dart` |
| 19 | 198 | `extension/src/test/vibrancy/scoring/vuln-classifier.test.ts` |
| 20 | 198 | `extension/src/views/projectVibrancyReportView.ts` |
| 21 | 195 | `extension/src/test/vibrancy/scoring/version-increment.test.ts` |
| 22 | 194 | `test/violation_parser_test.dart` |
| 23 | 189 | `extension/src/test/vibrancy/services/pub-dev-search.test.ts` |
| 24 | 186 | `test/quality_gate_test.dart` |
| 25 | 183 | `test/rule_packs_sdk_gates_test.dart` |

**Suggested priority within Batch A:** `lib/src/report/quality_gate.dart` (operator semantics, YAML shape, breach reporting) and extension **providers/views** that orchestrate user-visible behavior (`projectVibrancySidebarProvider.ts`, `projectVibrancyReportView.ts`, `tree-data-provider.ts`, `comparison-html.ts`) before long pure test files, unless a test file is actively flaky or ownership-heavy.

---

## Batch B — ranks 26–50 (same criteria)

| Rank | Lines | Path |
|-----:|------:|------|
| 26 | 177 | `extension/src/test/vibrancy/services/pubspec-parser.test.ts` |
| 27 | 175 | `test/state_lifecycle_dispose_scan_test.dart` |
| 28 | 175 | `extension/src/views/relatedRuleTelemetryView.ts` |
| 29 | 174 | `test/report_consolidator_test.dart` |
| 30 | 172 | `extension/src/test/vibrancy/scoring/blocker-analyzer.test.ts` |
| 31 | 156 | `extension/src/test/vibrancy/services/sbom-generator.test.ts` |
| 32 | 146 | `extension/src/test/views/crossFileCommands.test.ts` |
| 33 | 144 | `test/conditional_import_utils_test.dart` |
| 34 | 137 | `extension/src/test/vibrancy/services/vibrancy-history.test.ts` |
| 35 | 135 | `test/scan_cli_args_test.dart` |
| 36 | 135 | `scripts/modules/_timing.py` |
| 37 | 131 | `extension/src/test/vibrancy/scoring/family-conflict-detector.test.ts` |
| 38 | 124 | `extension/src/securityHotspotReviewState.ts` |
| 39 | 123 | `extension/src/test/vibrancy/services/override-parser.test.ts` |
| 40 | 122 | `extension/src/test/vibrancy/scoring/adoption-classifier.test.ts` |
| 41 | 119 | `extension/src/test/vibrancy/services/report-exporter.test.ts` |
| 42 | 116 | `extension/src/test/rulePacks/rulePackYaml.test.ts` |
| 43 | 115 | `extension/src/test/vibrancy/services/indicator-config.test.ts` |
| 44 | 115 | `extension/src/test/vibrancy/state/context-state.test.ts` |
| 45 | 114 | `extension/src/test/vibrancy/scoring/diff-narrator.test.ts` |
| 46 | 112 | `extension/src/test/vibrancy/services/save-task-runner.test.ts` |
| 47 | 108 | `extension/src/test/vibrancy/services/dep-graph.test.ts` |
| 48 | 108 | `extension/src/test/vibrancy/ui/codelens-toggle.test.ts` |
| 49 | 107 | `extension/src/test/vibrancy/services/upgrade-executor.test.ts` |
| 50 | 105 | `extension/src/test/vibrancy/scoring/alternatives.test.ts` |

**Suggested priority within Batch B:** `extension/src/securityHotspotReviewState.ts`, `extension/src/views/relatedRuleTelemetryView.ts`, and `scripts/modules/_timing.py` (small surface area, high leverage for anyone touching publish UX) before remaining vibrancy unit tests.

---

## Batch C — ranks 51–75 (same criteria)

| Rank | Lines | Path |
|-----:|------:|------|
| 51 | 102 | `test/diagnostic_statistics_test.dart` |
| 52 | 101 | `extension/src/test/vibrancy/views/detail-view-provider.test.ts` |
| 53 | 96 | `extension/src/test/vibrancy/providers/registry-commands.test.ts` |
| 54 | 93 | `extension/src/test/views/summaryTreeSuppressions.test.ts` |
| 55 | 91 | `extension/src/test/pathUtils.test.ts` |
| 56 | 89 | `extension/src/test/vibrancy/services/pub-outdated.test.ts` |
| 57 | 89 | `extension/src/test/vibrancy/services/pubdev-changelog.test.ts` |
| 58 | 88 | `bin/stub_test_report.dart` |
| 59 | 85 | `extension/src/test/vibrancy/scoring/license-classifier.test.ts` |
| 60 | 80 | `extension/src/test/vibrancy/services/lock-diff.test.ts` |
| 61 | 79 | `test/analysis_options_rule_packs_test.dart` |
| 62 | 79 | `test/diagnostic_dedup_tracker_test.dart` |
| 63 | 79 | `extension/src/test/rulePacks/rulePacksWebviewProvider.test.ts` |
| 64 | 76 | `extension/src/test/rulePacks/rulePackDefinitions.test.ts` |
| 65 | 76 | `extension/src/test/vibrancy/data/package-families.test.ts` |
| 66 | 75 | `extension/src/test/securityHotspotReviewState.test.ts` |
| 67 | 75 | `extension/src/test/views/uxLabels.test.ts` |
| 68 | 72 | `test/rule_packs_semver_test.dart` |
| 69 | 72 | `scripts/tests/test_code_comment_metrics.py` |
| 70 | 71 | `test/rule_relationship_metadata_integrity_test.dart` |
| 71 | 70 | `extension/src/test/views/summaryTreeHotspotReview.test.ts` |
| 72 | 67 | `extension/src/test/views/projectVibrancySidebar.test.ts` |
| 73 | 66 | `test/progress_tracker_dedup_test.dart` |
| 74 | 65 | `test/long_operation_method_name_match_test.dart` |
| 75 | 62 | `extension/src/test/vibrancy/test-helpers.ts` |

**Suggested priority within Batch C:** `bin/stub_test_report.dart` (why it exists for CI/stubs); `scripts/tests/test_code_comment_metrics.py` (what the scanner asserts vs known heuristic limits). Remaining rows are mostly tests—batch with adjacent production edits or a dedicated test-doc sweep.

---

## Batch D — ranks 76–100 (same criteria)

| Rank | Lines | Path |
|-----:|------:|------|
| 76 | 60 | `extension/src/test/views/suppressionsTree.test.ts` |
| 77 | 57 | `extension/src/test/sidebarToggleLabel.test.ts` |
| 78 | 56 | `extension/src/test/views/fileRiskFormatAge.test.ts` |
| 79 | 56 | `extension/src/test/views/relatedRuleTelemetry.test.ts` |
| 80 | 55 | `extension/src/test/vibrancy/services/lock-diff-notifier.test.ts` |
| 81 | 54 | `extension/src/test/vibrancy/services/override-age.test.ts` |
| 82 | 53 | `test/pubspec_lock_resolver_test.dart` |
| 83 | 53 | `test/security_rule_metadata_test.dart` |
| 84 | 53 | `extension/src/test/vibrancy/services/flutter-releases.test.ts` |
| 85 | 51 | `test/rule_packs_pubspec_markers_test.dart` |
| 86 | 49 | `extension/src/test/owaspExport.test.ts` |
| 87 | 48 | `extension/src/relatedRuleTelemetry.ts` |
| 88 | 47 | `test/rule_timing_tracker_test.dart` |
| 89 | 44 | `extension/src/views/projectVibrancyTypes.ts` |
| 90 | 43 | `test/project_vibrancy_coverage_quality_test.dart` |
| 91 | 43 | `extension/src/test/views/projectVibrancySidebarUiState.test.ts` |
| 92 | 38 | `test/init_composite_plugin_scaffold_test.dart` |
| 93 | 38 | `extension/src/test/vibrancy/services/cache-service.test.ts` |
| 94 | 32 | `extension/src/vibrancy/services/cache-service.ts` |
| 95 | 30 | `test/element_identifier_utils_test.dart` |
| 96 | 30 | `extension/src/test/vibrancy/problems/problem-collector.test.ts` |
| 97 | 28 | `test/rule_tags_test.dart` |
| 98 | 27 | `extension/src/test/vibrancy/scoring/purl-builder.test.ts` |
| 99 | 25 | `test/rule_pack_registry_test.dart` |
| 100 | 22 | `lib/src/models/violation.dart` |

**Suggested priority within Batch D:** `lib/src/models/violation.dart` (shared domain shape for package + extension), then `extension/src/vibrancy/services/cache-service.ts`, `extension/src/views/projectVibrancyTypes.ts`, and `extension/src/relatedRuleTelemetry.ts` (cross-feature contracts) before the smallest tests.

---

## Acceptance checklist (per file)

- [ ] At least one **file-level** or **primary-export** note explains purpose and boundaries.
- [ ] Any **non-obvious branch, guard, or empty catch** has a one-line **why** (or references a plan/bug id in prose, not a bare URL dump).
- [ ] **Tests:** scenario grouping or “what would break if this regressed” is obvious within ~30 seconds of reading the top of the file.
- [ ] Re-run publish (or a local scan) if you want the **numeric** zero-comment count to drop for that path; optional follow-up: extend the Python metric to count docstrings for `scripts/` only.

---

## Follow-ups (optional)

- Extend `_code_comment_metrics` to report **docstring lines** for Python and/or `///` density for Dart **separately** from line/block comments.
- Add a **non-interactive** script (e.g. `python scripts/list_comment_offenders.py`) that prints top *N* for CI or pre-commit dashboards—only if the team wants ongoing enforcement; otherwise this PLAN is documentation-only.

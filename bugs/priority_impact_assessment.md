# Feature: Priority-based violation ordering in reports

## Status: Planned

## Problem

A large Flutter project can produce hundreds of lint violations. The current
report lists them flat — grouped by impact level but otherwise unordered. A
developer looking at the report has no guidance on **which violations to fix
first** for maximum benefit.

The goal: violations in high-traffic, high-dependency files should rank above
violations in leaf files used once. A memory leak in `contact_tab.dart` (a main
tab rendered on every app launch) matters more than the same leak in
`map_explorer_screen.dart` (a rarely visited sub-screen).

## Prerequisite: fix report deduplication

The current report contains massive duplication — the same file:line:rule triple
repeated 10-15 times. The root cause is documented in
[violation_deduplication.md](violation_deduplication.md) (consecutive
re-analysis of the same file bypasses the clear guard in `_clearFileData`).
Session boundary detection is tracked separately in
[report_session_management.md](report_session_management.md). Both must be
fixed before prioritization work will produce meaningful results.

**Evidence from sample report** (contacts project, 2026-02-07):

| File:Line | Rule | Duplicates |
|-----------|------|------------|
| `contact_tab.dart:112` | `avoid_closure_memory_leak` | ~15x |
| `contact_tab.dart:134` | `avoid_closure_memory_leak` | ~15x |
| `contact_tab.dart:337` | `avoid_redundant_async` | ~15x |
| `contact_group_add_contact.dart:80` | `avoid_context_in_async_static` | ~10x |
| `map_explorer_screen.dart:61` | `avoid_redundant_async` | ~6x |

The "hundreds of errors" will likely collapse to dozens once deduplicated.

## Proposed approach: three phases

### Phase 1 — File importance score (import fan-in)

**Scope**: saropa_lints plugin feature, runs for all users.

For each analyzed file, count how many other project files import it (directly
or transitively). Files with high fan-in are structural foundations — a bug
there affects many screens.

**Score calculation**:

```text
file_importance = direct_importers + (transitive_importers * 0.5)
```

**Categories** (based on score):

| Score range | Label | Meaning |
|-------------|-------|---------|
| 20+ | Critical path | Core utilities, data layer, shared widgets |
| 10-19 | High traffic | Screen-level files with many dependents |
| 3-9 | Moderate | Feature-specific files |
| 0-2 | Leaf | Standalone screens, one-off widgets |

**Report output change**: add an `IMPORTANCE` column to the violation list and a
`FILE IMPORTANCE` summary section. Sort violations within each impact group by
file importance descending.

**Data source**: the analyzer already resolves imports for each file. During
analysis, `ProgressTracker` can accumulate an import graph incrementally — each
file's `import` directives are visible in `CustomLintResolver`. After all files
are analyzed, compute fan-in counts.

**Key constraint**: `custom_lint` analyzes files individually. The full import
graph is only complete after all files have been visited. The importance scores
must be computed lazily — either during `_writeReport()` or on a second pass.

**Files to modify**:

| File | Change |
|------|--------|
| `lib/src/saropa_lint_rule.dart` | Add import tracking to `ProgressTracker`: `Map<String, Set<String>> _importGraph`, populated in `recordFile()` via resolver. Add `computeFileImportance()` method. |
| `lib/src/report/analysis_reporter.dart` | Call `computeFileImportance()` in `_writeReport()`. Add `FILE IMPORTANCE` section. Sort violation list by importance within impact groups. Add importance column to violation output. |

**Acceptance criteria**:
- Report includes a `FILE IMPORTANCE` section ranking files by import fan-in
- Violations within each impact group are sorted by file importance (highest first)
- Each violation line includes an importance label (critical/high/moderate/leaf)
- No performance regression: import tracking adds < 1ms per file

### Phase 2 — Architectural layer classification

**Scope**: saropa_lints plugin feature, convention-based.

Classify files into architectural layers using directory path conventions common
in Flutter projects:

| Layer | Path patterns | Weight |
|-------|--------------|--------|
| Entry point | `main.dart`, `app.dart` | 5x |
| Navigation/routing | `**/routes/**`, `**/router/**`, `**/navigation/**` | 4x |
| State management | `**/bloc/**`, `**/provider/**`, `**/riverpod/**`, `**/store/**` | 4x |
| Data layer | `**/database/**`, `**/repository/**`, `**/api/**`, `**/service/**` | 3x |
| Shared components | `**/components/**`, `**/widgets/**`, `**/shared/**` | 3x |
| Screen (top-level) | `**/views/**`, `**/screens/**`, `**/pages/**` | 2x |
| Utilities | `**/utils/**`, `**/helpers/**`, `**/extensions/**` | 2x |
| Models/DTOs | `**/models/**`, `**/entities/**`, `**/dto/**` | 1x |
| Tests | `test/**` | 0.5x |

**Combined score**:

```text
priority_score = lint_impact * file_importance * layer_weight
```

**Report output change**: add `PRIORITY SCORE` column, sort all violations by
combined score descending (across impact groups, not just within them). Add a
`TOP 20 PRIORITY FIXES` summary at the top of the report.

**Files to modify**:

| File | Change |
|------|--------|
| `lib/src/report/analysis_reporter.dart` | Add `_classifyLayer(String path)` method. Compute combined priority score. Add `TOP 20 PRIORITY FIXES` section. Re-sort violations by priority score. |

**Acceptance criteria**:
- Files are classified into layers based on path conventions
- Combined priority score accounts for impact, importance, and layer
- Report starts with `TOP 20 PRIORITY FIXES` (most impactful violations first)
- Layer classification is configurable via `analysis_options_custom.yaml`

### Phase 3 — Full dependency graph export (future / external tool)

**Scope**: standalone script or companion tool, not part of the lint plugin.

Build a complete dependency graph including:
- Import/export relationships (static, from analyzer)
- Widget tree nesting (approximate, from `build()` method analysis)
- Navigation routes (heuristic, from GoRouter/Navigator patterns)

Output as a structured format (JSON or DOT) that can be visualized or queried
externally.

**This phase is deliberately deferred** because:
- Navigation routing is not statically analyzable in Flutter (routes are often
  runtime values, string-based, or generated)
- Widget tree relationships require deep AST traversal of `build()` methods
  across the entire project — expensive and fragile
- A `custom_lint` plugin sees files individually; whole-project graph analysis
  is better suited to a standalone tool
- Phase 1 + Phase 2 provide 80% of the prioritization value

**Deliverable**: a `scripts/dependency_graph.dart` script that:
- Parses the project using `package:analyzer`
- Outputs `reports/dependency_graph.json` with nodes (files) and edges (imports)
- Optionally outputs DOT format for Graphviz visualization
- Includes layer classification and importance scores

## Non-goals

- **Real-time prioritization in the IDE**: the plugin reports violations as they
  are found. Prioritization applies to the report file only.
- **Automatic fix ordering**: the plugin does not auto-fix in priority order.
  Prioritization guides the developer; they choose what to fix.
- **Cross-project comparison**: each report is for one project. Comparing
  violation counts across projects is out of scope.

## Original motivation

Sample report excerpt (contacts project, deduplicated):

```text
user_preference_io.dart:307  | require_yield_after_db_write | high | critical-path
user_preference_io.dart:471  | require_yield_after_db_write | high | critical-path
user_preference_io.dart:484  | require_yield_after_db_write | high | critical-path
contact_tab.dart:112         | avoid_closure_memory_leak    | high | high-traffic
contact_tab.dart:134         | avoid_closure_memory_leak    | high | high-traffic
contact_tab.dart:175         | prefer_return_await           | high | high-traffic
contact_tab.dart:337         | avoid_redundant_async         | high | high-traffic
map_explorer_screen.dart:61  | avoid_redundant_async         | high | leaf
map_explorer_screen.dart:68  | prefer_return_await           | high | leaf
theme_utils.dart:28          | avoid_redundant_async         | high | moderate
theme_utils.dart:103         | require_yield_after_db_write | high | moderate
debug.dart:509               | avoid_redundant_async         | high | leaf
user_country_io.dart:31      | require_location_timeout     | high | moderate
user_country_io.dart:119     | require_yield_after_db_write | high | moderate
```

With importance labels, the developer immediately sees: fix `user_preference_io`
and `contact_tab` first (critical-path and high-traffic), defer
`map_explorer_screen` and `debug.dart` (leaf files).

## Related

- [report_session_management.md](report_session_management.md) — prerequisite
  bug fix for deduplication

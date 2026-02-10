# Feature: Priority-based violation ordering in reports

## Status: Planned

## Problem

A large Flutter project produces hundreds of lint violations. The current report
groups them by impact level but gives no guidance on **what to fix first**. The
developer sees a flat list and has to guess which files matter most.

A memory leak in `contact_tab.dart` (a main tab rendered on every app launch,
imported by 12 other files) matters far more than the same leak in
`map_explorer_screen.dart` (visited once, imported by nothing). The report
should make this obvious.

The existing `TOP FILES` section is just a count of violations per file. That
tells you where the _most_ violations are, not where the most _important_ ones
are. A utility file with 30 style warnings ranks above a core service with 2
critical memory leaks.

## Prerequisites

- [violation_deduplication.md](violation_deduplication.md) — same violation
  repeated 10-15x due to consecutive re-analysis bypass
- [report_session_management.md](report_session_management.md) — session
  boundary detection for clean per-build reports (fixed)

Deduplication must land first. Prioritization on duplicated data is meaningless.

## What the developer sees (end state)

### New report section: PROJECT STRUCTURE

Full import hierarchy from entry points down. Every project file, every edge.
The developer can see their architecture at a glance.

```text
PROJECT STRUCTURE (147 files, 312 import edges)

main.dart [entry] (fan-in: 0, fan-out: 3)
├── app.dart [entry] (fan-in: 1, fan-out: 5)
│   ├── routes/app_router.dart [routing] (fan-in: 1, fan-out: 12)
│   │   ├── views/home/home_screen.dart [screen] (fan-in: 2, fan-out: 8)
│   │   │   ├── views/home/contact_tab.dart [screen] (fan-in: 1, fan-out: 6)
│   │   │   │   ├── components/contact/contact_card.dart [shared] (fan-in: 4, fan-out: 2)
│   │   │   │   ├── components/contact/contact_avatar.dart [shared] (fan-in: 7, fan-out: 1)
│   │   │   │   └── ...
│   │   │   ├── views/home/favorites_tab.dart [screen] (fan-in: 1, fan-out: 4)
│   │   │   └── views/home/recents_tab.dart [screen] (fan-in: 1, fan-out: 3)
│   │   ├── views/contact/contact_view_screen.dart [screen] (fan-in: 3, fan-out: 7)
│   │   ├── views/country/map_explorer_screen.dart [screen] (fan-in: 1, fan-out: 2)
│   │   └── ...
│   ├── theme/theme_utils.dart [utility] (fan-in: 8, fan-out: 1)
│   └── database/isar_middleware/core_db.dart [data] (fan-in: 6, fan-out: 3)
│       ├── database/.../user_preference_io.dart [data] (fan-in: 4, fan-out: 2)
│       └── database/.../user_country_io.dart [data] (fan-in: 3, fan-out: 2)
├── config/app_config.dart [utility] (fan-in: 1, fan-out: 0)
└── utils/_dev/debug.dart [utility] (fan-in: 2, fan-out: 0)

Standalone (no inbound imports from project files):
  data/country/country_capital_city_data.dart [model] (fan-in: 0)
```

Yes, this will be large for big projects. That's the point — the developer needs
the full picture, not a summary.

### New report section: FILE IMPORTANCE

Every file ranked by priority score. Replaces the current `TOP FILES` count.

```text
FILE IMPORTANCE (sorted by priority score)

  Score | Fan-in | Layer      | Issues | File
  ------+--------+------------+--------+-------------------------------------
    180 |     12 | data       |      6 | database/.../user_preference_io.dart
    160 |      8 | utility    |      2 | theme/theme_utils.dart
    120 |      4 | shared     |      0 | components/contact/contact_avatar.dart
     96 |      1 | screen     |      4 | views/home/contact_tab.dart
     48 |      3 | data       |      4 | database/.../user_country_io.dart
     12 |      0 | screen     |      2 | views/country/map_explorer_screen.dart
      6 |      0 | utility    |      1 | utils/_dev/debug.dart
```

Files with zero issues still appear — they show which high-importance files are
clean (and which low-importance files have problems that can wait).

### New report section: FIX PRIORITY

Replaces the current flat `ALL VIOLATIONS` list. Every violation, sorted by
priority score descending. The developer starts at the top and works down.

```text
FIX PRIORITY (19 violations, sorted by priority = impact * importance * layer)

  Priority | Impact   | File                                  | Line | Rule                         | Summary
  ---------+----------+---------------------------------------+------+------------------------------+--------
       540 | high     | database/.../user_preference_io.dart   |  307 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  471 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  484 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  524 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  583 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  592 | require_yield_after_db_write | DB write without yieldToUI()
       480 | high     | theme/theme_utils.dart                 |  103 | require_yield_after_db_write | DB write without yieldToUI()
       480 | high     | theme/theme_utils.dart                 |   28 | avoid_redundant_async        | Async without await
       288 | high     | views/home/contact_tab.dart            |  112 | avoid_closure_memory_leak    | Closure retains State ref
       288 | high     | views/home/contact_tab.dart            |  134 | avoid_closure_memory_leak    | Closure retains State ref
       288 | high     | views/home/contact_tab.dart            |  175 | prefer_return_await          | Missing return await
       288 | high     | views/home/contact_tab.dart            |  337 | avoid_redundant_async        | Async without await
       144 | high     | database/.../user_country_io.dart      |   31 | require_location_timeout     | Location request no timeout
       144 | high     | database/.../user_country_io.dart      |   80 | prefer_return_await          | Missing return await
       144 | high     | database/.../user_country_io.dart      |  119 | require_yield_after_db_write | DB write without yieldToUI()
       144 | high     | database/.../user_country_io.dart      |  219 | prefer_return_await          | Missing return await
        36 | high     | views/country/map_explorer_screen.dart |   61 | avoid_redundant_async        | Async without await
        36 | high     | views/country/map_explorer_screen.dart |   68 | prefer_return_await          | Missing return await
        18 | high     | utils/_dev/debug.dart                  |  509 | avoid_redundant_async        | Async without await
```

Same violations as the current report. Completely different order. The developer
immediately sees: the six `user_preference_io` DB write violations are the
highest priority — not because there are many of them, but because the file is
a critical-path data layer dependency imported by 12 other files.

## Scoring model

### File importance (import fan-in)

```text
file_importance = direct_importers + (indirect_importers * 0.3)
```

| Importance | Score  | Meaning |
|------------|--------|---------|
| Critical   | 20+    | Core utilities, base services, shared widgets |
| High       | 10-19  | Main screens, state management, data layer |
| Moderate   | 3-9    | Feature screens, feature-specific components |
| Low        | 1-2    | Leaf screens, one-off utilities |
| Standalone | 0      | No project files import this |

### Architectural layer (path-based)

Classify by directory path. First match wins.

| Layer        | Path patterns | Weight |
|--------------|--------------|--------|
| Entry        | `main.dart`, `app.dart` | 5 |
| Routing      | `routes/`, `router/`, `navigation/` | 4 |
| State        | `bloc/`, `provider/`, `riverpod/`, `store/`, `cubit/` | 4 |
| Data         | `database/`, `repository/`, `api/`, `service/` | 3 |
| Shared       | `components/`, `widgets/`, `shared/`, `common/` | 3 |
| Screen       | `views/`, `screens/`, `pages/`, `features/` | 2 |
| Utility      | `utils/`, `helpers/`, `extensions/`, `config/` | 2 |
| Model        | `models/`, `entities/`, `dto/` | 1 |
| Test         | `test/` | 0.5 |
| Other        | (no match) | 1 |

### Lint impact (already exists in plugin)

| Impact      | Numeric |
|-------------|---------|
| Critical    | 5 |
| High        | 4 |
| Medium      | 2 |
| Low         | 1 |
| Opinionated | 0.5 |

### Combined priority score

```text
priority = lint_impact_numeric * (file_importance + 1) * layer_weight
```

The `+1` prevents standalone files (importance 0) from zeroing out the score.

## Implementation

### New class: ImportGraphTracker

Add to `lib/src/saropa_lint_rule.dart`. Collects import edges during analysis,
computes scores at report time.

**Data structures**:

```dart
class ImportGraphTracker {
  ImportGraphTracker._();

  /// file_path -> set of import URIs (raw strings from import directives)
  static final Map<String, Set<String>> _rawImports = {};

  /// file_path -> set of resolved absolute paths this file imports
  static final Map<String, Set<String>> _importsOf = {};

  /// file_path -> set of files that import this file (reverse graph)
  static final Map<String, Set<String>> _importedBy = {};

  /// Computed importance scores (populated by compute())
  static final Map<String, double> _importanceScores = {};

  /// Layer classifications (populated by compute())
  static final Map<String, String> _layers = {};

  static bool _computed = false;
}
```

**Collection** — in `SaropaLintRule.run()`, after `ProgressTracker.recordFile(path)`,
on first visit only:

```dart
if (wasFirstVisit) {
  ImportGraphTracker.collectImports(path, content);
}
```

Extract imports using regex on the already-loaded content string:

```dart
static final _importRe = RegExp(r"^import\s+'([^']+)'\s*;", multiLine: true);

static void collectImports(String filePath, String content) {
  if (_rawImports.containsKey(filePath)) return;
  final uris = <String>{};
  for (final match in _importRe.allMatches(content)) {
    uris.add(match.group(1)!);
  }
  _rawImports[filePath] = uris;
}
```

This is reliable for Dart (import syntax is strict). Runs once per file. No AST
needed. Operates on the raw content string already loaded by the analyzer.

**Resolution** — convert import URIs to absolute file paths:

- Relative imports (`../foo.dart`): resolve against the importing file's
  directory
- Package self-imports (`package:myapp/foo.dart`): resolve via the project's
  `lib/` directory
- `package:` imports of other packages: ignore (external dependencies, not in
  the project graph)
- `dart:` imports: ignore (SDK, not in the project graph)

**Computation** — called once in `_writeReport()`, before rendering:

```dart
static void compute() {
  if (_computed) return;
  _computed = true;

  _resolveAllImports();    // raw URIs -> absolute paths
  _buildReverseGraph();    // _importedBy from _importsOf
  _computeFanIn();         // direct + 0.3 * indirect
  _classifyLayers();       // path-based layer assignment
}
```

**Fan-in** — direct count from `_importedBy[path].length`. Indirect count via
BFS/DFS on the reverse graph, counting all transitive importers.

**Layer** — match file path against the layer table. First directory segment
match wins. `main.dart` and `app.dart` match by filename regardless of
directory.

### Report generation changes

In `AnalysisReporter._writeCombinedReport()`:

1. Call `ImportGraphTracker.compute()` at the top
2. Add `_writeProjectStructure()` — depth-first tree walk from entry points
   (files with `void main(` in content or fan-in 0). Show every file with
   layer tag, fan-in, and fan-out. Mark circular imports with
   `[circular -> file]`. List standalone files (fan-in 0, no `main()`) at the
   end.
3. Replace `_writeTopFiles()` with `_writeFileImportance()` — all files sorted
   by `(file_importance + 1) * layer_weight`, with score/fan-in/layer/issues
   columns.
4. Replace `_writeViolationList()` with `_writePrioritizedViolations()` — all
   violations sorted by combined priority score descending. Columns: priority,
   impact, file, line, rule, summary (truncated problem message).

### Files to modify

| File | Change |
|------|--------|
| `lib/src/saropa_lint_rule.dart` | Add `ImportGraphTracker` class (~150 lines). Add `collectImports()` call in `SaropaLintRule.run()` for first-visit files. Expose `wasFirstVisit` from `ProgressTracker.recordFile()` return value. |
| `lib/src/report/analysis_reporter.dart` | Call `ImportGraphTracker.compute()`. Add `_writeProjectStructure()`, `_writeFileImportance()`, `_writePrioritizedViolations()`. Replace `_writeTopFiles()` and `_writeViolationList()`. |

### Performance budget

| Operation | Cost | When |
|-----------|------|------|
| Import extraction (regex) | ~0.1ms per file | Once per file, during analysis |
| URI resolution | ~0.01ms per import | Once, during `compute()` |
| Reverse graph + BFS | ~5ms for 200 files | Once, during `compute()` |
| Tree rendering | ~10ms for 200 files | Once, during report write |
| **Total overhead** | **< 20ms per report** | Negligible |

## Edge cases

| Case | Handling |
|------|----------|
| Circular imports (A -> B -> A) | Track visited set during tree walk. Show `[circular -> A]` at cycle point. Still count both directions in fan-in. |
| `part`/`part of` directives | Treat as same compilation unit. Collapse part files into their library file for scoring and tree display. |
| `package:` self-imports | Resolve via project's `lib/` directory. Count as internal graph edges. |
| Barrel files (index.dart re-exports) | Score naturally high (high fan-in). Mark as `[barrel]` in tree if file has only export directives and no declarations. |
| `export` directives | Track as dependency edges alongside imports. A file that exports another creates a graph edge. |
| Generated files (`.g.dart`, `.freezed.dart`) | Exclude from graph (already skipped by `skipGeneratedCode`). |
| Conditional imports (`dart.library.io`) | Use the first URI. Platform-specific resolution not needed for scoring. |
| Very large projects (1000+ files) | Output everything. The report is a reference document. |
| No `main.dart` found | Use all files with fan-in 0 as tree roots. |
| Files outside `lib/` | Include if analyzed. Classify `bin/` as entry, `test/` as test layer. |

## Acceptance criteria

- [ ] Report includes `PROJECT STRUCTURE` section showing full import tree
- [ ] Report includes `FILE IMPORTANCE` section with every analyzed file ranked
- [ ] Report includes `FIX PRIORITY` section with all violations sorted by
      combined priority score
- [ ] Priority score formula: `impact_numeric * (fan_in + 1) * layer_weight`
- [ ] Circular imports detected and marked, don't cause infinite loops
- [ ] Standalone files (fan-in 0) listed separately in structure tree
- [ ] Performance overhead < 20ms per report write
- [ ] No changes to Problems tab output (report file only)
- [ ] `ImportGraphTracker.reset()` called in session reset to prevent stale data

## Non-goals

- **IDE integration**: priority scores appear in the report file only, not in
  VS Code's Problems tab
- **Auto-fix ordering**: the developer decides what to fix; scores guide, not
  automate
- **Runtime analysis**: scoring is static (imports + paths); no runtime profiling
  or coverage data
- **Cross-project comparison**: scores are relative within a project
- **Widget tree / navigation graph**: these require deep AST traversal and are
  not statically reliable in Flutter; import graph provides sufficient
  structural insight

## Related

- [violation_deduplication.md](violation_deduplication.md) — prerequisite: fix
  duplicate violations in ImpactTracker
- [report_session_management.md](report_session_management.md) — prerequisite:
  clean per-build session boundaries (fixed)

# Extension-Driven Triage and Priority-Based Fix Ordering

**Status:** Triage and extension UI flow implemented in `extension/`; priority ordering **implemented in plugin** (2026-03: import collection + project info wiring; Windows path key fix). Remaining gap: performance target (`<20ms`) for priority compute/report overhead.  
**Priority:** High  
**Impact:** User adoption, retention, upgrade experience, and actionable fix order

---

## Overview

This document describes two connected aspects of the saropa_lints experience:

1. **Extension-driven setup and triage** — No init command line. The VS Code extension is the primary way to set up and configure saropa_lints. Triage is data-driven and happens in the extension UI. *Which rules to enable and how to configure.*

2. **Priority-based violation ordering in reports** — Once violations exist, the report should answer *what to fix first* by ranking violations using file importance (import graph, layers) and impact, so developers see an ordered fix list instead of a flat one.

Both rely on the same violation data (export, deduplication). Triage gets you to “these rules are on and these issues exist”; priority ordering makes the report say “fix these first.”

---

## Design Principles (shared)

1. **Extension-first.** Setup, analysis, and triage happen in the extension. Users do not run `dart run saropa_lints:init` (or any init CLI). The extension owns the experience.
2. **Analyze first, then decide.** Data drives decisions: run analysis, get per-rule counts (and later priority scores), then present triage and fix order in the UI/report.
3. **Same triage model.** Critical rules always on; zero-issue rules auto-enabled; remaining rules grouped by volume (e.g. Group A/B/C/D) with group-level or per-rule choices; stylistic rules triaged separately and opt-in.

---

# Part 1: Extension-Driven Setup and Triage

## Implementation status (as of 2026-03)

- **Done:** Violation export (`reports/.saropa_lints/violations.json`) with `summary.issuesByRule`; extension consumes it. Data-driven triage in extension (critical, volume groups A–D, zero-issue count, stylistic) via `triageUtils.ts` and Config view; right-click enable/disable writes RULE OVERRIDES in `analysis_options_custom.yaml`. CLI init is headless-only; extension is the documented path for interactive setup. Minimal `analysis_options_custom.yaml` (createCustomOverridesFile, migrateToMinimalFormat); packages auto-detected from pubspec; no long stylistic block in new/minimal file.
- **Addressed (2026-03):** Extension invokes `dart run saropa_lints:write_config` to write `analysis_options.yaml`. Init no longer used by extension for normal flow; init remains for CI/scripting. `write_config_runner.dart` + `bin/write_config.dart` + unit tests in `test/init/write_config_test.dart`.

## Problem (setup and config)

### The Old World (CLI init)

The previous init wizard asked users to make decisions before they had information:

1. Pick a tier without knowing what issues exist in their project
2. Walk through stylistic rule categories one by one (up to 143 prompts)
3. Get hit with potentially thousands of violations after all that effort

That led to overwhelm, no visibility into what matters for *their* project, and desire to uninstall rather than configure. No manageable upgrade path when new versions add rules.

### The Custom Config File

`analysis_options_custom.yaml` is 272 lines, mostly a wall of stylistic rules with full descriptions in YAML comments. It lists 170+ stylistic rules, platform settings, package settings, and overrides. Users are expected to read and manually toggle — nobody does. It's unworkable.

The custom config also duplicates what can be inferred:

- **Packages** can be auto-detected from `pubspec.yaml`
- **Platforms** can be auto-detected from `pubspec.yaml` (Flutter) or inferred
- **Stylistic rules** should go through the same triage as other rules
- **Rule overrides** are the only thing that genuinely needs a user-editable file

## Where Things Live

| Concern | Where it lives |
|--------|-----------------|
| **Running analysis** | Extension: "Run analysis" (Overview, Issues empty state, command palette). Under the hood: invokes Dart analyzer + plugin; plugin writes `reports/.saropa_lints/violations.json` (Violation Export API). |
| **Per-rule issue counts** | From `violations.json` (or extended export): rule → count. Used for triage and for "N issues" in UI. |
| **Triage UI** | Extension: Overview/Dashboard + Config view. No terminal wizard. |
| **Writing config** | Extension writes `analysis_options.yaml` (and minimal `analysis_options_custom.yaml` if needed). No requirement to shell out to an init command for normal flow. |
| **Platform/package detection** | Extension (or a small headless library/script the extension calls) reads `pubspec.yaml` and sets platform/package context. No manual config for these. |
| **User overrides** | Minimal `analysis_options_custom.yaml`: only explicit rule overrides (rule_name: true/false). Optional override UI in Config view. |

So: **no init command line**. The extension runs analysis, reads violation data, and drives triage and config writing. CLI init is deprecated or removed; the extension is the only supported path for setup and triage.

## Data Flow

1. **Enable Saropa Lints** (extension): ensure `pubspec.yaml` has `saropa_lints` and `analysis_options.yaml` references the plugin (one-click setup).
2. **Run analysis** (extension): user clicks "Run analysis"; extension triggers Dart analysis (e.g. run `dart analyze` or rely on Dart extension); plugin produces `violations.json`.
3. **Load triage data**: extension reads `violations.json` and (if needed) rule metadata (tier, category, impact, stylistic flag). Compute per-rule counts.
4. **Present triage** in extension UI (Overview + Config):
   - Critical: always on; show count and link to Issues (filter by critical).
   - Zero-issue rules: auto-enabled; show "N rules already passing, enabled."
   - Rules with issues: grouped by volume (e.g. 1–5, 6–20, 21–100, 100+). In Config (or a dedicated Triage view): group-level Enable all / Disable all, optional "Review list" for smaller groups with per-rule toggles.
   - Stylistic: same grouping, separate section; opt-in; "Disable all stylistic?" option.
5. **Apply decisions**: extension writes `analysis_options.yaml` (diagnostics: rule → true/false). User overrides in `analysis_options_custom.yaml` are preserved and merged.
6. **Subsequent runs**: extension can compare current counts to last run (e.g. from workspace state or `reports/.saropa_lints/history.json`), show "N fixed", "M new", and suggest re-triaging rules that dropped to zero or moved groups.

## Extension UX (aligned with Cohesion / WOW plan)

- **Overview / Dashboard**: Key number (e.g. total or critical), primary CTA "Run analysis" or "View N issues", links to Summary / Config / Logs. After triage: show "N rules enabled, M issues to address" and link to Issues.
- **Config view**: Not read-only. Tier row → quick pick to set tier and apply (if tier still used as a shortcut); **Rule toggles** driven by triage: show groups (e.g. "Group A: 34 rules, 87 issues") with [Enable all] [Disable all] [Review]. Optional per-rule list for "Review". Stylistic section with same pattern and "Disable all stylistic?"
- **No terminal wizard**: All choices in extension UI. No `dart run saropa_lints` for init.
- **Status / progress**: Shown in Overview and Summary (e.g. "Last run: 2 min ago", "Down from 120 → 98"). No separate CLI status command required; extension is the status surface.

## Triage Logic (unchanged from original design, applied in extension)

- **Critical rules** (essential tier, security, crash, memory): always enabled; show counts and link to Issues.
- **Auto-enable zero-issue rules**: Rules with 0 issues in current analysis → set to `true`; they catch future violations.
- **Bulk triage by volume**: Remaining rules grouped by issue count (e.g. A: 1–5, B: 6–20, C: 21–100, D: 100+). User makes group-level Enable all / Disable all; for smaller groups, optional "Review list" with per-rule toggles.
- **Stylistic**: Same grouping, separate section; opt-in; option to disable all stylistic.
- **Re-run behavior**: New rules in new version → triage like above. Disabled rules that now have 0 issues → offer to auto-enable. User overrides (from custom config) preserved.

## Configuration Output

- **analysis_options.yaml**: Plugins + `saropa_lints` block. Under `diagnostics`, rules are `true` or `false`. Written by the extension after triage (and after any tier preset if used).
- **analysis_options_custom.yaml**: Minimal. Only explicit user overrides (rule_name: true/false). Optional: platform overrides if auto-detection is wrong. No long list of stylistic rules; stylistic goes through triage and into main analysis_options.

Platform and package detection (from `pubspec.yaml`) are used to filter which rules apply; results can be shown in Config ("Detected: Riverpod, Flutter") with optional overrides in custom config.

## Eliminating the Old Custom Config

| Old content | New approach |
|------------|----------------|
| Analysis settings (e.g. max_issues) | In `analysis_options.yaml` under `saropa_lints:`; extension can offer a setting. |
| Platform settings | Auto-detected from `pubspec.yaml`; override in minimal custom config if needed. |
| Package settings | Auto-detected from `pubspec.yaml`; no config needed. |
| Stylistic rules (170+ lines) | Triage in extension; output goes to `analysis_options.yaml` diagnostics. |
| Rule overrides | Minimal `analysis_options_custom.yaml` or Config view overrides. |

Migration: If an existing `analysis_options_custom.yaml` is present, extension (or a one-time migration) reads explicit overrides, keeps them, and rewrites the file to the minimal format; optionally back up as `.bak`.

## CLI and Backend

- **Init CLI**: **Removed or deprecated.** Extension is the only supported way to do setup and triage. If we keep a headless "apply triage" for scripts/CI, it should be an implementation detail (e.g. library or a non-interactive script that reads violations + decisions and writes YAML), not the main user-facing init.
- **Analysis**: Still performed by Dart analyzer + saropa_lints plugin. Extension triggers analysis (via Dart extension or `dart analyze`) and consumes `violations.json`.
- **Status**: No separate CLI status command; extension Overview and Summary provide status and progress.

## What Gets Preserved vs Removed (triage)

| Area | Change |
|------|--------|
| Tier selection prompt (CLI) | **Removed.** Replaced by extension triage UI (and optional tier quick pick in Config). |
| Per-rule stylistic walkthrough (CLI) | **Removed.** Replaced by bulk stylistic triage in extension. |
| `dart run saropa_lints:init` | **Headless only.** Extension uses `write_config` instead; init kept for CI/scripting. |
| `dart run saropa_lints` (default init) | **Removed.** No interactive init in CLI. |
| Tier presets (e.g. recommended.yaml) | **Optional.** Can remain for "zero-config" include; extension may set tier or write diagnostics directly. |
| Platform/package manual config | **Replaced** by auto-detection; override in minimal custom config or Config view. |
| analysis_options_custom.yaml (long form) | **Replaced** by minimal overrides-only file. |
| Data-driven triage (critical, zero-issue, groups, stylistic) | **Preserved** and implemented in extension UI. |
| User rule overrides | **Preserved** in minimal custom config and/or Config view. |
| Post-write validation | Preserved (extension or backend can validate after writing). |
| Dry-run / reset | If needed, as extension actions (e.g. "Reset triage" or "Preview changes") rather than CLI flags. |

## Implementation Notes (triage)

1. **Violation export**: Ensure `violations.json` (or equivalent) provides enough to compute per-rule counts and link to severity/impact. Add category/stylistic in export or bundle rule metadata in extension.
2. **Extension writes YAML**: Extension must be able to write `analysis_options.yaml` (and optionally `analysis_options_custom.yaml`) with the same structure the plugin expects. No dependency on init CLI for this.
3. **Modularization**: Any remaining "triage engine" (grouping, default decisions, merge with overrides) can live in a Dart library or a small Node/TS helper used by the extension; the extension owns UI and orchestration.
4. **First-run**: After "Enable", extension can offer "Run analysis" → then "Here are your issues" and "Configure rules" (triage) so the flow is: Enable → Run analysis → Triage in Config/Overview → ongoing use.

## Success Criteria (triage)

- Users never need to run an init command; the extension is the single place for setup and triage.
- "Run analysis" and "Configure rules" (triage) are clear in the extension (Overview + Config).
- Triage is data-driven: critical always on, zero-issue auto-enabled, rest by volume groups and stylistic opt-in.
- analysis_options (and minimal custom overrides) are written by the extension; behavior matches VSCODE_EXTENSION_COHESION_WOW_PLAN (one-click setup, init from UI, config actions in place).

---

# Part 2: Priority-Based Violation Ordering in Reports

## Problem (fix order)

A large Flutter project produces hundreds of lint violations. The current report groups them by impact level but gives no guidance on **what to fix first**. The developer sees a flat list and has to guess which files matter most.

A memory leak in `contact_tab.dart` (a main tab rendered on every app launch, imported by 12 other files) matters far more than the same leak in `map_explorer_screen.dart` (visited once, imported by nothing). The report should make this obvious.

The existing `TOP FILES` section is just a count of violations per file. That tells you where the *most* violations are, not where the most *important* ones are. A utility file with 30 style warnings ranks above a core service with 2 critical memory leaks.

## Prerequisites (priority ordering)

- [violation_deduplication.md](violation_deduplication.md) — same violation repeated due to duplicate reporting during analysis; counts are now deduplicated by `(ruleName, offset)` (offset-level dedup), not just by line.
- [report_session_management.md](report_session_management.md) — session boundary detection for clean per-build reports (fixed)

Deduplication must land first. Prioritization on duplicated data is meaningless.

## Implementation status (priority ordering, 2026-03)

- **Done:** `ImportGraphTracker` in `lib/src/report/import_graph_tracker.dart`; report sections in `analysis_reporter.dart`.
- **Done (wiring):** `ImportGraphTracker.collectImports` from `SaropaContext._shouldSkipCurrentFile` immediately after `ProgressTracker.recordFile`; `ImportGraphTracker.setProjectInfo` from `AnalysisReporter.initialize` with `ProjectContext.getPackageName`. Regex collects `import` / `export` URIs (not only single-quote `import` as in older sketch).
- **Done (Windows):** `_coerceToRegisteredPath` / `_pathsSameFile` so resolved edges match registered file keys when separators differ.
- **Tests:** `test/import_graph_tracker_test.dart` (package edge resolution, idempotent collect).
- **Done (2026-03 follow-up):** Batch JSON field `ig` + `ConsolidatedData.mergedRawImports` + merge in `ReportConsolidator`; report hydrates graph from merged snapshot when non-empty. Relative vs absolute file paths aligned for FIX PRIORITY / FILE IMPORTANCE issue column.
- **Done (correctness):** Progress/report counts are deduplicated by `(ruleName, offset)` and the consolidated report omits the legacy flat `ALL VIOLATIONS` section.
- **Benchmarked (2026-03 follow-up):** Added `test/import_graph_tracker_perf_test.dart` to measure synthetic overhead for `ImportGraphTracker.compute()` plus ordering/traversal work. On this machine, the synthetic “200 files chain + 500 violations” case now measures ~31ms total (compute ~24ms), improved from ~60-80ms; the “<20ms” target still needs optimization.
- **Extension UI follow-ups:** The extension-side triage prompts/history UX is implemented in this workspace (`extension/src/extension.ts`, `extension/src/views/triageTree.ts`, `extension/src/runHistory.ts`, `extension/src/views/overviewTree.ts`), so these items are no longer blocked by a missing extension repo.

## What the developer sees (end state)

### New report section: PROJECT STRUCTURE

Full import hierarchy from entry points down. Every project file, every edge. The developer can see their architecture at a glance.

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

Yes, this will be large for big projects. That's the point — the developer needs the full picture, not a summary.

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

Files with zero issues still appear — they show which high-importance files are clean (and which low-importance files have problems that can wait).

### New report section: FIX PRIORITY

Replaces the current flat `ALL VIOLATIONS` list. Every violation, sorted by priority score descending. The developer starts at the top and works down.

```text
FIX PRIORITY (19 violations, sorted by priority = impact * importance * layer)

  Priority | Impact   | File                                  | Line | Rule                         | Summary
  ---------+----------+---------------------------------------+------+------------------------------+--------
       540 | high     | database/.../user_preference_io.dart   |  307 | require_yield_after_db_write | DB write without yieldToUI()
       540 | high     | database/.../user_preference_io.dart   |  471 | require_yield_after_db_write | DB write without yieldToUI()
       ... (same violations as current report, different order)
        18 | high     | utils/_dev/debug.dart                  |  509 | avoid_redundant_async        | Async without await
```

Same violations as the current report. Completely different order. The developer immediately sees: the six `user_preference_io` DB write violations are the highest priority — not because there are many of them, but because the file is a critical-path data layer dependency imported by 12 other files.

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

## Implementation (priority ordering)

### New class: ImportGraphTracker

Add to `lib/src/saropa_lint_rule.dart`. Collects import edges during analysis, computes scores at report time.

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

**Collection** — in `SaropaLintRule.run()`, after `ProgressTracker.recordFile(path)`, on first visit only:

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

This is reliable for Dart (import syntax is strict). Runs once per file. No AST needed. Operates on the raw content string already loaded by the analyzer.

**Resolution** — convert import URIs to absolute file paths:

- Relative imports (`../foo.dart`): resolve against the importing file's directory
- Package self-imports (`package:myapp/foo.dart`): resolve via the project's `lib/` directory
- `package:` imports of other packages: ignore (external dependencies, not in the project graph)
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

**Fan-in** — direct count from `_importedBy[path].length`. Indirect count via BFS/DFS on the reverse graph, counting all transitive importers.

**Layer** — match file path against the layer table. First directory segment match wins. `main.dart` and `app.dart` match by filename regardless of directory.

### Report generation changes

In `AnalysisReporter._writeCombinedReport()`:

1. Call `ImportGraphTracker.compute()` at the top
2. Add `_writeProjectStructure()` — depth-first tree walk from entry points (files with `void main(` in content or fan-in 0). Show every file with layer tag, fan-in, and fan-out. Mark circular imports with `[circular -> file]`. List standalone files (fan-in 0, no `main()`) at the end.
3. Replace `_writeTopFiles()` with `_writeFileImportance()` — all files sorted by `(file_importance + 1) * layer_weight`, with score/fan-in/layer/issues columns.
4. Replace `_writeViolationList()` with `_writePrioritizedViolations()` — all violations sorted by combined priority score descending. Columns: priority, impact, file, line, rule, summary (truncated problem message).

### Files to modify (priority)

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
| **Total overhead** | **~31ms observed** for synthetic “200-file chain” case in unit perf test | Improved, but still needs optimization to meet “< 20ms per report” |

## Edge cases (priority ordering)

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

## Acceptance criteria (priority ordering)

- [x] Report includes `PROJECT STRUCTURE` section showing full import tree *(per isolate; see limitation above)*
- [x] Report includes `FILE IMPORTANCE` section with every analyzed file ranked *(capped rows + “omitted” line when over limit)*
- [x] Report includes `FIX PRIORITY` section with all violations sorted by combined priority score *(capped inline rows when over limit)*
- [x] Priority score formula: `impact_numeric * (fan_in + 1) * layer_weight`
- [x] Circular imports detected and marked, don't cause infinite loops *(tree uses `[shown above]` for revisits)*
- [x] Standalone files (fan-in 0) listed separately in structure tree
- [ ] Performance overhead < 20ms per report write *(benchmarked locally: ~31ms for synthetic “200-file chain” case; improved but still above <20ms)*
- [x] No changes to Problems tab output (report file only)
- [x] `ImportGraphTracker.reset()` called in session reset to prevent stale data

## Non-goals (priority ordering)

- **IDE integration**: priority scores appear in the report file only, not in VS Code's Problems tab
- **Auto-fix ordering**: the developer decides what to fix; scores guide, not automate
- **Runtime analysis**: scoring is static (imports + paths); no runtime profiling or coverage data
- **Cross-project comparison**: scores are relative within a project
- **Widget tree / navigation graph**: these require deep AST traversal and are not statically reliable in Flutter; import graph provides sufficient structural insight

**Future link:** The extension could later consume priority scores (e.g. from extended violation export or report) to show "high-priority issues" or fix order in the UI, while the report remains the primary reference.

---

# Related and references

- [violation_deduplication.md](violation_deduplication.md) — prerequisite for priority ordering; fix duplicate violations in ImpactTracker
- [report_session_management.md](report_session_management.md) — prerequisite for clean per-build session boundaries (fixed)
- [VSCODE_EXTENSION_COHESION_WOW_PLAN.md](VSCODE_EXTENSION_COHESION_WOW_PLAN.md) — extension design and cohesion
- VIOLATION_EXPORT_API.md (if present) — violation export contract
- Issues tree and views: Extension plan for Issues tree by severity and structure

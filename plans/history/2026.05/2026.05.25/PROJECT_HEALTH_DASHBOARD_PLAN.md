# Project Health Dashboard (size map · dead-ends · coverage · comments · git · hot spots)

**Severity**: Feature — net-new analyst surface that composes existing engines
**Date**: 2026-05-24
**Status**: Proposed — awaiting sign-off on phase order

A unified "project health" view: a WizTree/WinDirStat-style **size map** of the
codebase overlaid with **dead-weight**, **test coverage**, **comment density**,
and **git churn**, distilled into ranked **HOT SPOTS** (🔥) and exported as
JSON/Markdown an AI agent can act on, plus interactive charts in the extension.

The guiding constraint, carried from the Amigo extension review: **facts get
surfaced loudly; heuristics get surfaced as report-only and never wired to bulk
deletion.** Size, LOC, comment ratio, coverage %, and git churn are facts.
"Unused" is a heuristic. They are presented at different confidence tiers.

---

<!-- cspell:disable -->

## Execution snapshot

### Status (updated 2026-05-25)

**Shipped + tested on the `project_health` CLI (53 tests, analyze-clean, e2e-verified):**
- [x] Phase 0 + 1 (size): file walk, `FileHealth`/`FolderHealth`, memory-flat NDJSON streaming, folder rollups, top-N.
- [x] Phase 2b: complexity (cognitive/cyclomatic/variables/booleans/nesting/exits), class LCOM, Maintainability Index (token Halstead, single parse/file) — `--complexity`.
- [x] Phase 1 dead-weight overlay (`--deadweight`, composes cross_file) + Phase 2 coverage (`--coverage`/`--lcov`) + git signals churn/recency/bus-factor (`--git`).
- [x] Phase 3: 🔥 hot-spot ranking (6 axes) + Markdown AI-fix worklist (`--format markdown`).
- [x] Phase 4 (report side): self-contained ECharts HTML — treemap + churn×complexity scatter + hot-spot table (`--format html`).
- [x] Phase 5 (assets): unused asset/font scanner (`--assets`).

**Also shipped + verified (2026-05-25, 63 tests):**
- [x] Phase 5: transitive dead private islands (`--islands`) — false-positive-fixed (top-level var/enum/mixin references seed roots); verified it finds a real dead config cluster in `saropa_lints.dart` that `unused_element` misses.
- [x] Phase 2/4: temporal coupling (`--coupling`) + stub-test density (`--stubs`).
- [x] Phase 6: fix workflow (`--fix`) — reviewable `git rm` script, never in-place, never comment-out.
- [x] Phase 4 (UI): extension command `saropaLints.openProjectHealthDashboard` + sidebar "Saropa Project Map" leaf + command-catalog entry (literal title to avoid the translation gate). Verified: `tsc --noEmit` clean + 17 catalog-sync tests pass.

### Gap assessment (2026-05-25): what makes it actually useful

The data engine is complete; the UI, scaling machinery, and trust/workflow layer
are thin. Ordered by impact:

**A. Trust + workflow gaps (block real adoption):**
- [x] **Pinpoint findings to function + line** (2026-05-25). `FileComplexity.topFunctions` carries the worst functions (name + line + scores) into JSON, the Markdown worklist, and the AI prompts.
- [x] **AI-fix handoff** (2026-05-25). `--format prompts` emits one self-contained, copy-paste-ready agent task per hot spot, naming the exact functions/lines + dead symbols + coverage + churn, with behavior-preserving + confidence constraints. Verified e2e (names `_isInSafeIfBlock` line 888).
- [x] **Baseline / trend / diff** (2026-05-25). `--update-baseline` / `--baseline <path>` capture exact aggregates and compare; non-zero exit on regression (rising complexity/dead-code, falling coverage). Verified e2e.
- [x] **Coverage staleness warning** (2026-05-25). Warns when `lcov.info` predates HEAD — stale coverage reported as unverified.
- [x] **Suppression / allowlist** (2026-05-25). `.saropa_health.yaml` allowlists dead files/symbols/islands/assets + shared excludes; `--config <path>` override. Verified e2e (suppressing `_loadAnalysisConfig` removes it from islands). 76 tests.
- [x] **Drill-down (click-to-open) + free-text search** (2026-05-25). Webview rows open the file; type-to-filter box over the hot-spot table; sortable columns.
- [x] **Maintainability Index saturation** fixed (2026-05-25) — ranks by the unclamped raw MI so files that all clamp to 0 order correctly.
- [x] **Config file** (2026-05-25). `.saropa_health.yaml` — excludes + allowlist; `--config`.
- [x] **Dead-weight integration test** (2026-05-25) — real temp package: flags the unimported file, spares the imported one.

**B. Committed scope not finished:**
- [x] Beautiful report (2026-05-25): stat-card header, collapsible panels, theme-aware (system light/dark), sortable hot-spot table, health-ramp treemap, reduced-motion. Verified structurally (`--format html`). (Renders in a browser; not yet screenshot-verified.)
- [x] Async / non-blocking extension command (2026-05-25) — `views/projectMapView.ts` spawns the scan async under a cancellable `withProgress`; in-flight guard reuses the panel. tsc-clean + 17 catalog tests pass. (Runtime render not screenshot-verified.)
- [x] Vendor ECharts offline (2026-05-25) — `extension/media/echarts.min.js` (Apache-2.0, ~1 MB, ships in the .vsix only, never in a consumer's app); the webview swaps the CDN `<script>` for the vendored copy + a CSP, so charts render in-editor with no network.
- [x] Fan-in/fan-out coupling + instability + public-API doc coverage (2026-05-25).
- [x] Hierarchical folder treemap with drill-down (2026-05-25, `folder_tree.dart` + ECharts breadcrumb).
- [x] Caching/incremental warm-rescan (2026-05-25, `--cache`, content-hash parse reuse; cold→warm 11.7s→8.6s on lib/src).

**Moved to dedicated deferred plans (2026-05-26):**
- **Isolate worker pool** — cold-scan CPU parallelism. See [deferred/PROJECT_HEALTH_isolate_worker_pool.md](deferred/PROJECT_HEALTH_isolate_worker_pool.md).
- **Adaptive huge-workspace auto-defaults** — auto-aggregate mode over a file-count threshold. See [deferred/PROJECT_HEALTH_adaptive_huge_workspace.md](deferred/PROJECT_HEALTH_adaptive_huge_workspace.md).

**C. WOW backlog (ranked by impact-per-effort):**
1. ~~AI-fix handoff~~ ✅ done.
2. ~~Health time-machine~~ ✅ done (2026-05-25) — `--history`, git-archive per tag.
3. ~~Refactoring-ROI ranking~~ ✅ done.
4. ~~PR/diff health gate~~ ✅ via `--baseline`.
5. ~~In-editor heat (CodeLens)~~ ✅ done (2026-05-25) — opt-in, off by default + toggle command.
6. ~~"What-if" cleanup simulator~~ ✅ ~~NL exec summary~~ ✅ ~~cycle-cut suggestions~~ ✅ (2026-05-25, `--cycles`).

### Deferred items

Both moved to standalone plans under [deferred/](deferred/) on 2026-05-26 so the
parent plan tracks shipped scope only:

- [deferred/PROJECT_HEALTH_isolate_worker_pool.md](deferred/PROJECT_HEALTH_isolate_worker_pool.md) — cold-scan CPU parallelism; intentionally not built (throughput-only, would destabilize the verified core for an unmeasured gain).
- [deferred/PROJECT_HEALTH_adaptive_huge_workspace.md](deferred/PROJECT_HEALTH_adaptive_huge_workspace.md) — auto-aggregate defaults above a file-count threshold; no real-user trigger yet.

### Next build order (active)

1. ~~Pinpoint findings + AI-fix handoff~~ ✅ done (2026-05-25).
2. ~~Baseline + trend~~ ✅ done. ~~Coverage staleness~~ ✅ done.
3. ~~Suppression + config~~ ✅ done (2026-05-25).
4. ~~Async + beautiful webview~~ ✅ done (2026-05-25) — async cancellable webview, vendored offline ECharts, beautiful report. (Drill-down/click-to-open is a remaining nicety; charts + sorting work.)
5. ~~Refactoring-ROI~~ ✅ ~~PR/diff gate~~ ✅ (via baseline). Remaining WOW: health time-machine; in-editor CodeLens heat; what-if simulator; NL exec summary.

### Resolved decisions

- **Results store: NDJSON shards** (approved 2026-05-24). Dependency-free append-only shards under `reports/.saropa_lints/health/` + in-memory aggregate index; SQLite deferred unless full-set interactive filtering later requires it. See the "Scaling to huge projects" section.
- **Charts library: Apache ECharts** (approved 2026-05-24). One Apache-2.0 bundle covers every view this dashboard needs — treemap, scatter, radar, sankey, force-directed graph, heatmap, sunburst — with no framework and full offline operation in a webview (bundle the single JS file). Chosen over D3 (more code, same result) and Chart.js (no treemap/sankey).

### Open decisions (resolve before the phase they gate)

- **Delivery surface for the CLI** (gates Phase 0): new `bin/project_health.dart` that composes existing engines (recommended) vs. overloading `bin/cross_file.dart`. A dedicated binary keeps cross_file focused on the import graph.

---

## Goal

One command and one dashboard that answer:

1. **Where is the bulk?** Biggest/longest files and folders by bytes and LOC (treemap).
2. **What is dead weight?** Unused files, unused symbols, dead imports, unused l10n, unused assets — overlaid on the size map so "this 4,000-line file is also 60% unreferenced" is obvious.
3. **What is under-tested?** Per-file line coverage from lcov.
4. **What is under-documented?** Comment-line ratio and public-API doc coverage.
5. **What is volatile?** Git churn, recency, author spread — the files that change most.
6. **What are the HOT SPOTS?** A ranked, 🔥-tagged shortlist where several bad axes coincide (e.g., large + low-coverage + high-churn).
7. **What should an AI fix first?** A prioritized, checkbox worklist in Markdown, plus a versioned JSON schema for programmatic consumption.

---

## What already exists (reuse map — do NOT rebuild)

Investigated 2026-05-24. The dashboard composes these; it does not replace them.

| Capability | Where | Reuse for |
|---|---|---|
| Project file enumeration + import graph | `ImportGraphCache` in [cross_file_analyzer.dart](../lib/src/cli/cross_file_analyzer.dart) | the master file list + importer lookups |
| Unused files (no importers) | `cross_file` `unused-files` | dead-weight overlay |
| Unused top-level symbols (semantic) | [cross_file_unused_symbols_semantic.dart](../lib/src/cli/cross_file_unused_symbols_semantic.dart) | dead-symbol density per file |
| Dead imports | [cross_file_dead_imports_semantic.dart](../lib/src/cli/cross_file_dead_imports_semantic.dart) | dead-weight |
| Unused l10n keys | [cross_file_unused_l10n.dart](../lib/src/cli/cross_file_unused_l10n.dart) | dead-weight |
| Duplicate blocks | [cross_file_duplicates.dart](../lib/src/cli/cross_file_duplicates.dart) | optional column |
| Per-function coverage % + lcov correlation | [project_vibrancy.dart](../lib/src/cli/project_vibrancy.dart), [project_vibrancy_coverage_quality.dart](../lib/src/cli/project_vibrancy_coverage_quality.dart) | file coverage rollup |
| Per-function complexity + doc hints | `project_vibrancy` | complexity/doc rollup |
| Git-changed files since ref (`--since`) | `bin/project_vibrancy.dart` `_changedDartFilesSince` | basis for git-churn helper |
| Git path awareness | [project_context_path_bloom_git.dart](../lib/src/project_context_path_bloom_git.dart) | git root resolution |
| HTML report scaffold | [cross_file_html_reporter.dart](../lib/src/cli/cross_file_html_reporter.dart), `cross_file_html_reporter_part.dart` | treemap/chart host page |
| Extension cross-file commands + webview wiring | [extension/src/cross-file-commands.ts](../extension/src/cross-file-commands.ts) | command + webview pattern |
| Existing dashboards | `saropaLints.openConfigDashboard`, `saropaLints.openProjectVibrancyReport` | UI conventions, nls pattern |

**Built-in analyzer overlap (important):** in-library **private** dead code
(`unused_element`, `unused_field`, `unused_local_variable`) is already detected
soundly by the Dart analyzer, with IDE "Remove unused" fixes. The dashboard
**surfaces** these (counts per file) but does not reimplement detection. The only
private gap worth new code is **transitive dead islands** (Phase 5).

---

## Genuine gaps (the actual build)

| Gap | Phase | FP risk |
|---|---|---|
| File/folder **size rollup** (bytes + LOC + code/comment/blank split) | 1 | none (fact) |
| **Treemap** visualization + dead-weight overlay | 1 / 4 | none |
| File-level **coverage rollup** from lcov | 2 | none (data freshness only) |
| **Comment-density** per file + public-API doc coverage rollup | 2 | none |
| **Git churn / recency / author-spread** per file | 2 | none |
| **Hot-spot ranking** + 🔥 tiers | 3 | none (derived) |
| **JSON + Markdown export** for AI consumption | 0 / 3 | none |
| **Interactive charts** (treemap, churn×coverage scatter, top-N bars) | 4 | none |
| **Unused assets / fonts / data files** scanner | 5 | moderate (dynamic paths) |
| **Transitive dead private islands** | 5 | low |
| **Complexity metrics** (cognitive, variable count, boolean-expr, NPath) | 2b | none (AST fact) |
| **Class metrics** (LCOM cohesion, field/method counts, DIT/NOC) | 2b | none |
| **Coupling** (fan-in/fan-out, instability) from import graph | 2b | none |
| **Maintainability Index** composite (0–100) per file | 2b | none |
| **Stub-test density** (reuse existing stub scanner) | 2 | none |
| **Bus factor** (single-author concentration, git blame) | 2 | none |
| **Temporal coupling** (git co-commit "changes together") | 2 / 4 | none |
| **Churn × complexity hotspot map** (the signature view) | 4 | none |
| **AI-fix handoff** (per-hotspot agent-ready prompt bundle) | 3 | n/a (output) |
| **Fix workflows** (quarantine/patch, `@Deprecated` assist) | 6 | n/a (action) |

---

## Architecture

New code under `lib/src/cli/project_health/`:

```
project_health/
  health_model.dart          # FileHealth + FunctionMetric + ClassMetric + FolderHealth + report
  size_scanner.dart          # bytes, total/code/comment/blank LOC per file
  comment_scanner.dart       # comment ratio + public-API doc coverage rollup
  complexity_scanner.dart    # cognitive complexity, variable count, boolean-expr, NPath, nesting
  class_metrics.dart         # LCOM cohesion, field/method counts, DIT/NOC, public surface
  coupling_metrics.dart      # fan-in/fan-out + instability from ImportGraphCache
  maintainability_index.dart # 0–100 composite (Halstead vol + cyclomatic + LOC + comment%)
  git_signals.dart           # churn, last-modified, author count, bus factor (blame)
  temporal_coupling.dart     # co-commit "changes together" pairs from git log
  coverage_rollup.dart       # lcov line% per file (wraps project_vibrancy lcov reader)
  stub_test_density.dart     # reuse existing stub scanner; per-file stub counts
  deadweight_overlay.dart    # composes cross_file unused-* into per-file dead counts
  hotspot_ranking.dart       # normalization + 🔥 tier assignment (tunable thresholds)
  ai_fix_handoff.dart        # per-hotspot agent-ready prompt bundle
  health_export_json.dart    # versioned JSON schema
  health_export_markdown.dart# AI-fix worklist
  health_html_reporter.dart  # ECharts treemap + scatter + radar + sankey host page
```

CLI entry: `bin/project_health.dart` →
`dart run saropa_lints:project_health`.

```
dart run saropa_lints:project_health \
  --path .              # project root (default: cwd)
  --format html|json|markdown|text   # default: text summary
  --output-dir reports/.saropa_lints/health
  --lcov coverage/lcov.info
  --top 25              # hot-spot list length
  --since <git-ref>     # restrict git signals / scope
  --exclude <glob>      # repeatable; same contract as cross_file
  --min-comment-ratio / --max-file-loc / --min-coverage   # hot-spot thresholds
  --no-git --no-coverage --no-deadweight   # opt out of slow/optional sections
```

Extension: new command `saropaLints.openProjectHealthDashboard` + webview,
mirroring the vibrancy report wiring in [cross-file-commands.ts](../extension/src/cross-file-commands.ts);
add `package.json` contribution + `package.nls.*` strings.

### Core data model

```dart
/// One row per source file. Every field has a concrete consumer in the
/// dashboard, export, or ranking — no doc-only fields.
class FileHealth {
  final String path;            // project-relative, posix
  final int bytes;              // File.lengthSync()
  final int loc;                // total lines
  final int codeLoc;            // non-blank, non-comment
  final int commentLoc;         // comment lines
  final int blankLoc;
  final double commentRatio;    // commentLoc / max(codeLoc,1)
  final double? coveragePct;    // null when no lcov data for the file
  final int? churn;             // commits touching the file (null when --no-git)
  final DateTime? lastModified; // last commit date
  final int? authorCount;
  final int deadSymbols;        // from cross_file unused-symbols
  final bool isUnusedFile;      // zero importers
  final int builtinUnusedCount; // unused_element/_field/_local from analyzer pass
  final int stubTests;          // always-pass tests defined here (existing stub scanner)
  // Complexity rollups (per-function details live in FunctionMetric):
  final int maxCyclomatic;      // from project_vibrancy
  final int maxCognitive;       // cognitive complexity (nesting-weighted)
  final int maxVariableCount;   // most locals in any one function ("overrun")
  final int maxBooleanTerms;    // most &&/||/! in any one condition
  final int maxNesting;         // deepest block nesting (policy: <=3)
  final double maintainabilityIndex; // 0–100 composite, higher = healthier
  // Coupling / cohesion:
  final int fanIn;              // afferent: files importing this
  final int fanOut;             // efferent: files this imports
  final double instability;     // fanOut / max(fanIn+fanOut, 1)
  final double worstLcom;       // least-cohesive class in the file (split candidate)
  // Git knowledge risk:
  final double busFactorPct;    // % of lines by the single top author (blame)
  // Ranking:
  final double hotspotScore;    // normalized composite (Phase 3)
  final List<String> fireFlags; // axes this file tops: size/coverage/comments/churn/complexity
}

/// Per-function detail (drives the complexity table and AI-fix targeting).
class FunctionMetric {
  final String file; final String name; final int lineStart; final int lineEnd;
  final int cyclomatic; final int cognitive; final int variableCount;
  final int parameterCount; final int maxBooleanTerms; final int exitPoints;
  final double? coveragePct; // uncovered functions feed the AI-fix worklist
}

/// Per-class detail (god-object / split detection).
class ClassMetric {
  final String file; final String name;
  final int fieldCount; final int methodCount; final int publicMembers;
  final int dit; final int noc; final double lcom; // cohesion: high = should split
}
```

`FolderHealth` is the recursive rollup (sum bytes/LOC, weighted averages) that
the treemap and folder table consume.

---

## Sidebar integration (joins the existing dashboards)

The activity-bar container `saropaLints` already hosts an **"Editor dashboards"**
tree ([extension/src/views/sectionedSidebar.ts](../extension/src/views/sectionedSidebar.ts),
`buildEditorDashboardItems`) with five leaves: Lints Config, Package Dashboard,
Code Health Dashboard, Findings Dashboard, Command Catalog. The new dashboard is
a **sixth leaf** in that same tree — no new activity-bar slot, so it sits with
the others exactly as the user expects.

- **Sidebar label: "Saropa Project Map"** (renamed from "Project Map" 2026-05-26 for brand consistency). Avoids collision with the existing **"Code Health Dashboard"** (which is function-level vibrancy). Pairing: *Code Health* = per-function quality; *Saropa Project Map* = project-wide size/dead-weight/hotspots. Command id stays `saropaLints.openProjectHealthDashboard`.
- New `extension/src/views/projectHealthDashboardView.ts` mirroring `projectVibrancyReportView.ts`: opens an **editor-tab webview panel**, with the existing **in-flight guard** (re-invocation reveals the open panel instead of spawning a second) and a `refreshProjectHealthDashboardIfOpen()` for post-scan updates.
- Wiring deltas: add the command + `package.nls.*` strings (all locales) in `extension/package.json`; register it in `extension.ts`; add the leaf (icon + label + command) to `buildEditorDashboardItems`; bump [plans/sidebar_view_inventory.md](sidebar_view_inventory.md) (5→6 leaves, new audit date).

---

## Performance & async architecture (background, non-blocking)

The data sources are heavy (analyzer resolution, `git blame`/`log`, lcov parse,
full file walk), so nothing runs on the UI thread and slow sections never block
fast ones.

**Out-of-process (extension side, TS):**
- The scan runs as a **spawned Dart process** (`dart run saropa_lints:project_health`), as the extension already does for cross_file/vibrancy — heavy work is off the Node event loop by construction.
- Launch under `vscode.window.withProgress` (notification, cancellable) — **never blocks** the editor; the user keeps working.
- **Stream NDJSON** from the CLI: each section (`size`, `deadweight`, `coverage`, `git`, `complexity`, `hotspots`) is emitted as it completes and pushed to the webview, which **renders progressively** behind skeletons instead of waiting for the slowest section.
- **Stale-while-revalidate:** on open, paint the last cached report instantly, then refresh in the background and diff-update.
- **Reuse panel + lazy charts:** render the treemap first; defer scatter/sankey/radar computation until their tab is focused. Cancellation supersedes any in-flight run; file-watch refresh is debounced and **off by default** (opt-in setting — the full scan is too heavy to run per save).

**In-process (Dart CLI):**
- **Isolate worker pool** for per-file work (size, comment classify, complexity AST) — reuse the existing batching in [project_context_parallel_batch.dart](../lib/src/project_context_parallel_batch.dart); scale to cores.
- **Single shared analyzer context** (as `project_vibrancy` already builds) — never re-resolve per file.
- **Content-hash + HEAD-sha cache** under `reports/.saropa_lints/health/cache.json`: recompute only changed files (reuse [project_context_incremental_priority.dart](../lib/src/project_context_incremental_priority.dart) patterns); git signals keyed by commit sha.
- **Batched git** (`git log --name-only`, one `git blame` per file pooled) rather than a process per metric.
- **Section toggles** (`--no-git --no-coverage --no-complexity --no-deadweight`) so users trade completeness for speed.
- **Acceptance:** opening the dashboard returns control to the editor immediately; size map paints before git/complexity finish; a warm cache run is materially faster than cold; cancelling closes cleanly with no orphan process.

---

## Visual design (theme-aware, tasteful, accessible)

Explicitly requested: colors, decorations, panels, groups, headers, animations,
expanders. The bar is **polished and native-feeling**, not gratuitous — every
treatment is theme-derived and respects user accessibility settings.

- **Theme integration first.** All CSS uses `var(--vscode-*)` tokens; the ECharts theme is derived from the same tokens, so the dashboard matches the user's light/dark/high-contrast theme automatically. This is the single biggest "looks built-in" lever.
- **Layout:**
  - **Summary header band** at top — big stat cards: project grade (Maintainability Index → A–F), total LOC/files, % dead, coverage %, top-3 risks. Animated count-up on load.
  - **Collapsible panels (expanders)** per concern — Size Map · Hotspots · Coverage · Complexity · Dead-ends · Git/Knowledge. Each has a **section header** with icon + count badge + chevron. Collapse state **persisted** in webview/workspace state so it reopens as left.
- **Grouping:** hotspots grouped by **🔥 tier** with colored group headers; metrics arranged as cards.
- **Color system (single source of truth):** one health ramp (green→amber→red for badness) defined once and reused for treemap fills, severity chips, coverage rings, and the 🔥 tiers. No rainbow / novelty colors.
- **Decorations:** stat cards with subtle border/shadow, count badges, **coverage progress rings**, **mini sparklines** for trend, pill chips for tags/flags.
- **Animations (tasteful, gated):** ECharts enter transitions (bars grow, treemap zoom, scatter fade), smooth CSS expander collapse, **skeleton shimmer** while a section loads, number count-up. All wrapped in `prefers-reduced-motion` — motion disabled when the user opts out.
- **States:** skeletons while scanning; friendly empty states with the corrective action ("No lcov found — run `flutter test --coverage`"); **per-section error isolation** (one section failing doesn't blank the dashboard).
- **Interaction:** hover tooltips, click-a-rectangle/row → open the file at the offending line, sortable/filterable table, search, tier-filter toggles, per-hotspot "Copy fix prompt".
- **Performance guardrails (tie to async section):** **virtualize** the file table (thousands of rows) and cap initial treemap depth so first paint stays fast.
- **Copy/voice:** dashboard labels, empty states, and tooltips follow the no-first-person rule (second/third person), per the global UX copy rule.

---

## Scaling to huge projects (first-class constraint)

Target the worst realistic case: a monorepo with **tens of thousands of Dart
files, millions of LOC, and deep git history**. The dashboard must stay usable
there, which means two non-negotiables: **bounded memory/time on the scan**, and
**aggregate-first presentation** — the point of the tool is to surface the worst
items, not to render everything. "Show me all 50,000 files" is never the default,
because an overwhelming view is a useless view.

### Core principle: surface, don't enumerate

The dashboard defaults to **folder rollups + top-N / above-threshold** items and
drills down on demand. Listing every file is opt-in (`--all`), never the landing
view. This single choice bounds both compute and render cost and is also better
UX.

### Memory discipline (do NOT blow out dev PCs)

This is a hard requirement, not a nice-to-have. **RAM use must be bounded and
roughly flat regardless of project size** — a 100k-file scan must not use
materially more memory than a 5k-file scan. Concrete rules:

- **Configurable soft ceiling, default ~512 MB for the CLI process** (`--max-memory-mb`). Approaching it triggers self-throttle (shrink batch size, drop isolate count, defer the heaviest section), then partial-with-banner — never unbounded growth, never OOM.
- **Never cache all file contents.** Read a file, extract its metrics, **discard** it. The existing `unused-symbols` engine's `Map<path,String>` of every file is the anti-pattern to avoid; the new scanners read-process-release and only ever hold the current batch.
- **Full rows live on disk, not in RAM.** Every `FileHealth` row is appended to NDJSON immediately. The **in-memory aggregate index is provably small** — O(folders) rollups + fixed-size top-N heaps + fixed-size quantile sketches — **never O(files) of full rows.**
- **Streaming/approximate percentiles.** Tier cutoffs use a bounded **quantile sketch** (t-digest / P²) or a disk two-pass over the NDJSON — *never* an in-memory array of all values across all files.
- **Parsed AST over resolved AST.** The element model is the real memory hog. Cheap metrics use lightweight `parseFile` (no element model retained). Resolution runs in a **single context with a bounded cache, processed in batches and evicted** — not N resolved contexts, not all units resident.
- **Bounded isolate pool, small messages.** Worker count is capped (≈ cores−1, with an upper bound); each isolate does parsed-AST work and returns **small result records (paths + numbers), never ASTs or file contents** — inter-isolate copying of big payloads is itself a memory multiplier. Heavy resolution stays in the main isolate's single context.
- **Stream-parse git, never buffer.** `git log --name-only` / `git blame` output is read line-by-line and reduced on the fly (extract the number, drop the text); deep history never materializes as one big string.
- **Intern path strings** in the import graph (path → int id) so adjacency at 100k files stays in tens of MB, not hundreds.
- **Extension/webview side:** the Node process and renderer hold only **aggregates + the visible window**, never the full row set (enforced by the windowed messaging in Presentation).

### Processing at scale (CLI)

- **Resolution tiering.** Cheap **parsed-AST** metrics (size, comment ratio, cognitive/cyclomatic complexity, variable count, nesting, boolean terms) need no element resolution — run them on *all* files fast. Expensive **resolved/semantic** passes (cross-file unused symbols, dead imports, LCOM) are scoped or opt-in, never forced across a 50k-file tree.
- **Bounded-memory streaming.** Process in bounded batches; emit each `FileHealth` row to an **on-disk results store** (NDJSON shards under `reports/.saropa_lints/health/`) instead of holding all rows in RAM. Aggregations (folder rollups, bounded quantile sketches, top-N heaps) are computed **incrementally** in a single streaming pass — never materialize the full row set to sort it. See "Memory discipline" above for the hard rules.
- **Persistent index + incremental.** First scan builds the index once; later scans recompute only files whose content hash changed (and git metrics only when HEAD moved). Huge projects pay full cost once.
- **Git at scale is sampled, not exhaustive.** Churn/bus-factor/temporal-coupling default to a **bounded history window** (e.g. last N commits / `--since`); full history is opt-in. **Mega-commits** (touch > K files — merges, reformats, generated dumps) are excluded from temporal coupling as noise. Pair counting is **top-K with threshold pruning**, never all-pairs materialized.
- **O(n²) guards.** Duplicate detection, coupling, and any all-pairs metric run under explicit caps; above the cap they sample or switch to approximate counts, labeled as such.
- **Budgets + graceful degradation.** Each section has a time/memory budget; on exceed it emits **partial results with an explicit "truncated: N of M processed" marker** — never hangs, never OOMs, and never reports partial data as complete (per the production-quality honesty rule).
- **Scope controls.** `--path <subdir>`, include/exclude globs, `--since` (changed files only), and per-package scoping let users analyze a slice of a monorepo instead of the whole thing.

### Presentation at scale (webview)

- **Aggregate-first treemap.** Default to **folder-level** rectangles; files materialize only when a folder is expanded/zoomed (lazy fetch). Cap rendered nodes per level; "zoom to fit" navigation rather than 50k rectangles at once.
- **Virtualized, paginated tables.** The file table renders only the visible window; defaults to top-N by hotspot score with filters; "load all" is explicit. ECharts scatter uses `large`/progressive rendering or **density binning** above a point threshold so it never overplots.
- **Collapsed graphs.** Dependency and temporal-coupling graphs default to **module/folder nodes** with top-K edges; expand a node to reveal its files. Avoids the hairball.
- **Windowed messaging.** The CLI streams **aggregates + top-N first**; the webview requests detail windows on demand (scroll/expand triggers a follow-up query) so the message channel never ships the whole dataset at once.
- **Adaptive defaults.** On launch the extension counts workspace files; above a threshold it auto-enables aggregate-first mode, defers the heaviest sections (git, semantic dead-code) to explicit user action, and shows a banner: *"Large workspace (48,000 files) — showing folder rollups. Expand to drill in; enable git metrics in settings."*

### Export at scale

- JSON and Markdown default to **top-N / above-threshold**; `--all` opts into the full set. Full JSON is **sharded/streamed**, not one giant object. The Markdown AI-worklist is inherently bounded (hotspots only) so an agent gets a finite, prioritized queue rather than 50k items.

### Resolved: results store = NDJSON shards

**Decided 2026-05-24: NDJSON shards** (dependency-free). Each scan writes
append-only `*.ndjson` shards under `reports/.saropa_lints/health/`; an
in-memory aggregate index (folder rollups, bounded quantile sketches, top-N
heaps — provably small, never O(files) of full rows) is built in the streaming
pass, and windowed detail is served by seeking the relevant shard. Zero new dependencies. SQLite is **not** adopted now; revisit
only if profiling later shows interactive arbitrary-filter queries over the full
row set need a real index — and that would be a separate, approved decision.

### Acceptance (scale)

- A synthetic 50k-file project scans **under the configured ceiling (default ~512 MB)** with peak RSS **roughly flat versus a 5k-file project** — memory must not scale with file count.
- Profiling confirms no all-files-resident structures (no full content map, no all-values percentile array, no N resolved contexts).
- First paint shows folder aggregates fast; file-level detail loads only on drill-down.
- When a section hits its budget, the UI shows "truncated: N of M" — partial is never presented as complete.
- Warm-cache rescan touches only changed files.

---

## Phases

Ordered by dependency and risk. No time estimates (per project policy);
each phase lists acceptance criteria that must pass before the next begins.

### Phase 0 — Foundation: file walk + model + JSON

- Build `FileHealth` for every Dart file from `ImportGraphCache.getFilePaths()`, populated with size fields only at first.
- `health_export_json.dart` writes a versioned (`schemaVersion`) report: metadata (`generatedAt` UTC, project path, tool version, which sections ran) + `files[]` + `folders[]`.
- **Acceptance:** `--format json` emits valid JSON for this repo; row count == file count; bytes/LOC match a spot-checked file.

### Phase 1 — Size map + dead-weight overlay (the WizTree view)

- `size_scanner.dart`: bytes via `lengthSync`, LOC split (code/comment/blank) via a lightweight line classifier (handles `//`, `///`, `/* */`, string-literal edge cases conservatively — a `//` inside a string must not count as a comment line).
- `deadweight_overlay.dart`: run existing `unused-files` + `unused-symbols`, attach `isUnusedFile` and `deadSymbols` per file.
- `health_html_reporter.dart`: **treemap** (rectangle area = bytes or LOC, toggle), colored by dead-weight density (green→red), folder drill-down. Reuse the cross_file HTML scaffold.
- **Acceptance:** treemap renders; largest files appear largest; an unused file is visibly flagged; opening the report from the extension works.

### Phase 2 — Coverage, comments, git columns

- `coverage_rollup.dart`: wrap the lcov reader already in `project_vibrancy_coverage_quality.dart`; per-file line %. Warn in metadata when `lcov.info` mtime predates `HEAD` (stale coverage is unverified, not "fine").
- `comment_scanner.dart`: comment ratio (from Phase 1 split) + public-API doc coverage (public declarations with a `///` doc / total public declarations), rolled up from the vibrancy doc-hint pass.
- `git_signals.dart`: per file, `git log --follow --format=%an -- <path>` → churn (commit count), last-commit date, distinct author count, and **bus factor** (% of current lines attributed to the top author via `git blame --line-porcelain`). Single batched `git log` where possible; degrade gracefully (null fields) when not a git repo or git absent.
- `temporal_coupling.dart`: parse `git log --name-only` commit-by-commit; count file pairs that change in the same commit; emit pairs whose co-change ratio exceeds a threshold (the "changes together" signal). Cross-module pairs are the interesting ones — flag when the pair is not in the same directory/feature.
- `stub_test_density.dart`: reuse the existing stub-test scanner (the one behind [plans/BUG_stub_tests_in_suite.md](plans/BUG_stub_tests_in_suite.md)); attach per-file stub counts so the always-pass-test problem is visible and trackable in the dashboard.
- **Acceptance:** coverage %, comment ratio, churn, bus factor, stub counts populated for this repo; a known co-changing file pair appears in temporal coupling; `--no-git`/`--no-coverage` cleanly null the respective fields; stale-lcov warning fires when applicable.

### Phase 2b — Complexity, coupling & maintainability

- `complexity_scanner.dart` (per function, into `FunctionMetric`): **cognitive complexity** (nesting-weighted), **variable count** (your "overrun" signal), **boolean-term count** per condition, **exit-point count**, **max nesting**, and NPath. Cyclomatic is reused from `project_vibrancy` rather than recomputed.
- `class_metrics.dart` (per class, into `ClassMetric`): **LCOM** (lack of cohesion — methods sharing no fields ⇒ split candidate), field/method counts, public-member surface, DIT/NOC.
- `coupling_metrics.dart`: **fan-in/fan-out** straight from `ImportGraphCache`; **instability** `Ce/(Ca+Ce)`.
- `maintainability_index.dart`: 0–100 composite (Halstead volume + cyclomatic + LOC + comment%) per file — the single sortable headline score; weights are named constants documented WHY.
- Roll the per-function/per-class worsts up to `FileHealth` (`maxCognitive`, `maxVariableCount`, `worstLcom`, …).
- **Acceptance:** a deeply-nested function scores higher cognitive than its cyclomatic; a function with many locals is flagged on `maxVariableCount`; a god-class shows high LCOM; fan-in/fan-out match the import graph; Maintainability Index is in [0,100] and inversely tracks the bad axes on spot-checked files.

### Phase 3 — Hot-spot ranking + 🔥 + Markdown export

- `hotspot_ranking.dart`: min-max normalize each "badness" axis (LOC, bytes, 1−coverage, 1−commentRatio, churn, churn×(1−coverage) risk product). `hotspotScore` = weighted sum (weights are named constants, documented WHY, tunable via flags). `fireFlags` lists axes where the file is in the top percentile.
- 🔥 tiers: 🔥 (tops one axis) / 🔥🔥 (two) / 🔥🔥🔥 (three or the churn×low-coverage risk quadrant). Thresholds are percentile-based, not absolute, so the list is meaningful on any project size.
- `health_export_markdown.dart`: **AI-fix worklist** — sections per tier, each hot spot as a heading with its metrics and a checkbox list of concrete suggested actions, e.g.:

  ```markdown
  ### 🔥🔥🔥 lib/foo/bar.dart — 4,212 LOC · 8% coverage · 2% comments · 47 commits
  - [ ] Split: file exceeds size threshold (target ≤ N LOC); candidate seams: <top-level groups>
  - [ ] Test: 8% line coverage; uncovered functions: <list>
  - [ ] Document: 3/41 public declarations have doc comments; undocumented: <list>
  - [ ] Remove dead: 6 unreferenced private symbols — <names> (verify: not reflection/generated)
  ```

- `ai_fix_handoff.dart`: for each hot spot, emit an **agent-ready prompt bundle** — the file path, the specific complexity offenders (function names + scores), uncovered line ranges from lcov, undocumented public declarations, and the dead-symbol list — formatted as a self-contained task an AI agent can act on without re-deriving context. Exposed in the dashboard as a per-hotspot "Copy fix prompt" action and as a `--emit-fix-prompts` CLI mode.
- **Acceptance:** hot-spot list is stable and ordered; Markdown export is valid and suggested actions reference real per-file data (no placeholders); a generated fix prompt names the actual offending functions/lines for a known hotspot; re-running on unchanged code yields identical ranking (deterministic).

### Phase 4 — Interactive charts + extension dashboard

- Charts in the webview (all via **Apache ECharts**, bundled for offline use):
  - **Treemap** (Phase 1, now interactive: hover metrics, click to drill/open file; toggle area = bytes|LOC, color = deadness|coverage).
  - ★ **Churn × complexity hotspot map** (x = churn, y = cognitive complexity, bubble = LOC, color = coverage) — the signature view; top-right = refactor first.
  - **Churn × coverage scatter** — the risk quadrant; bottom-right = high-change/low-test danger.
  - ★ **Temporal coupling** sankey/force graph — "changes together" pairs from git co-commits, highlighting cross-module links.
  - **Code-DNA radar** per file/module across size, complexity, coverage, comments, churn, coupling — compare two modules' shape at a glance.
  - **Top-N bar** charts (largest files, lowest coverage, lowest comments, worst maintainability).
  - Sortable, filterable table of all `FileHealth` rows.
- Extension command `saropaLints.openProjectHealthDashboard`, surfaced as the **sixth "Editor dashboards" leaf** ("Saropa Project Map") per the Sidebar-integration section, streams NDJSON from the CLI and renders progressively per the Performance and Visual-design sections. Per-hotspot "Copy fix prompt" button wired to `ai_fix_handoff` output; "Export JSON"/"Export Markdown" buttons.
- **Acceptance:** opens from the sidebar leaf AND the command palette; editor stays responsive during the scan; the size map paints before slower sections finish; charts interactive; collapse state persists across reopen; theme matches light/dark/high-contrast; reduced-motion disables animation; export buttons write artifacts; works with and without lcov/git.

### Phase 5 — New dead-end scanners

- **`unused-assets`** (mirrors `unused-l10n`): parse `pubspec.yaml` `flutter: assets:`/`fonts:`; for each declared asset, regex-search `lib/`+`test/` for the path string (word-boundary). Report declared-but-unreferenced. Separately, list on-disk asset files neither declared nor referenced (orphans). **Report-only**; flag dynamically-constructed-path matches as "low confidence."
- **Transitive dead private islands**: per-library reachability from live roots (public API surface, `@override`/`@pragma`/`main`/test entry points, annotations). Report private clusters reachable from no live root — the case `unused_element` misses because members reference each other.
- **Acceptance:** asset scanner finds a seeded unused asset and does NOT flag a dynamically-referenced one without marking it low-confidence; island detector flags a seeded mutually-referencing dead private pair and does NOT flag a pair reachable from a public method.

### Phase 6 — Fix workflows

- **No comment-out option.** It violates [.claude/rules/global.md](../.claude/rules/global.md) ("No commented-out code: Delete unused code") and converts dead code into a worse smell.
- In-library private dead code → defer to the **existing Dart IDE "Remove unused" fix** (no new code).
- Cross-file / asset removals (heuristic) → **`--fix` writes a reviewable git patch** to `reports/.saropa_lints/health/dead_code_removal.patch`, or **quarantine-moves** assets to `reports/.saropa_lints/quarantine/`. Never in-place bulk `rm`. Never auto-applied.
- Optional `@Deprecated('unused — slated for removal')` assist for suspected-dead **public** symbols that cannot be proven dead.
- **Acceptance:** `--fix` produces a patch that `git apply --check` accepts; nothing is deleted without the user applying the patch; no commented-out code is ever emitted.

---

## Export contract (for AI consumption)

- **JSON** (`schemaVersion`, stable keys): `{ meta, files[], folders[], hotspots[], sections: {...which ran} }`. Primary machine interface; versioned so downstream agents can pin.
- **Markdown**: prioritized, checkbox worklist grouped by 🔥 tier, each item a concrete action with the data that justifies it. Designed to be pasted to an agent as "fix these in order."
- Both carry the **confidence tier** per finding: `fact` (size/coverage/comments/git) vs `heuristic` (dead-ends/assets), so an agent treats deletions conservatively.

---

## False-positive guardrails (carried from the Amigo review)

- **Facts vs heuristics are visually and structurally separated.** Size/LOC/coverage/comments/git never carry deletion suggestions. Dead-ends do, but only as report/patch.
- **Roots respected for dead detection:** package public exports, `bin/`/`test/`/`example/`/`tool/`/`web/` entry points, conditional imports, generated files (`*.g.dart`, `*.freezed.dart`), `@pragma`/`@visibleForTesting`/reflection.
- **Coverage staleness is surfaced, not hidden** — stale lcov is reported "unverified," never silently treated as current.
- **Asset matching is heuristic** — dynamic-path matches are labeled low-confidence, never auto-removed.
- **Determinism:** same inputs → identical report (required for baseline/CI use and for diffing in the extension).

---

## Cross-cutting deliverables (per repo policy)

- [CHANGELOG.md](../CHANGELOG.md): entry under `[Unreleased]` per phase landed.
- [ROADMAP.md](../ROADMAP.md): dashboard + scanners listed.
- [CODEBASE_INDEX.md](../CODEBASE_INDEX.md): new `project_health/` module + `bin/project_health.dart`.
- [CODE_INDEX.md](../CODE_INDEX.md): new helpers (size/comment/complexity/coupling/git/hotspot/export).
- `extension/package.json`: new `saropaLints.openProjectHealthDashboard` command; `extension/package.nls.*` strings (all locales); ECharts bundled as a vendored dependency.
- [extension/src/views/sectionedSidebar.ts](../extension/src/views/sectionedSidebar.ts): sixth "Editor dashboards" leaf; new `projectHealthDashboardView.ts`.
- [plans/sidebar_view_inventory.md](sidebar_view_inventory.md): refresh leaf count (5→6) + audit date.
- `analysis_options.yaml`: any new `example_*` fixture dirs excluded.
- Tests: per-helper unit tests (size split edge cases, comment classifier, complexity/LCOM, git-signal parsing, hotspot ranking determinism, export schema) plus extension tests (in-flight guard, NDJSON streaming render, collapse-state persistence). Positive tests, not just null/empty defensive ones.

---

## Later / optional (deferred WOW features)

Not in the committed phases above; revisit once the core dashboard ships. Each
reuses data the core already produces.

- **Health time-machine** — re-run the scan at each git tag and chart the trajectory (complexity/coverage/dead-code over releases). Shows direction, not just a snapshot.
- **Refactoring-ROI ranking** — fuse complexity + churn + coverage + bus factor into one prioritized "fix this for maximum risk reduction" list.
- **"What-if" cleanup simulator** — quantify the payoff of deleting the dead set ("−18k LOC, −12%, −230 KB") before acting.
- **Knowledge/bus-factor treemap** — color the size map by primary author; flag files with no backup expert.
- **Cycle-cut suggestions** — for each import cycle `cross_file` finds, recommend the single edge to remove.
- **In-editor heat** — CodeLens/gutter decorations driven by the same data ("🔥 hotspot · 8% covered" above a function).
- **PR health gate** — wire into the existing baseline system; CI comment when a PR worsens hotspots or adds uncovered lines.
- **Natural-language exec summary** — auto-written project health paragraph with the top risks and the single biggest win.
- **Flutter bundle-size attribution** — estimate which files/packages drive app size (heavier; needs tree-shake or `--analyze-size` integration).

## Out of scope (explicit)

- Reimplementing `unused_element`/`unused_field`/`unused_local_variable` — analyzer already does this.
- Auto-deleting any file or symbol.
- Non-Dart language analysis beyond asset/data file references.
- Replacing `project_vibrancy` or `cross_file` — the dashboard composes them.

---

## Risks

- **Performance on large repos.** Git `blame` (bus factor) and `log --name-only` (temporal coupling) plus analyzer resolution are the costs. Mitigation: batch git calls, reuse the single analyzer context `project_vibrancy` already builds, cache git output, make git/coverage/deadweight/complexity sections individually skippable.
- **Huge projects (10k–100k+ files).** Memory blowup, O(n²) metrics, hairball graphs, and unrenderable 50k-node views. Mitigation: the dedicated **"Scaling to huge projects"** section — resolution tiering, bounded-memory NDJSON streaming, aggregate-first presentation with drill-down, top-N/threshold defaults, git sampling, and budget-bounded partial results that are never reported as complete.
- **lcov dependency.** Coverage is only as good as the last `flutter test --coverage`. Surfaced as a freshness warning, never assumed.
- **ECharts bundle.** New extension dependency (approved). Bundle the single JS file for offline webview use; pin the version and vendor it rather than CDN-load (no network in webviews, supply-chain control).
- **Hot-spot weighting is subjective.** Mitigation: percentile-based, tunable via flags, weights documented with rationale.

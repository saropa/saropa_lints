# BUG: Infrastructure — Analyzer OOM Crash on Large Projects (4000+ Files)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-08-27
Rule: N/A — infrastructure / plugin-wide
File: Plugin entry point (`analyzer_plugin` integration)
Severity: Critical — crashes the entire Dart analysis server, blocking all analysis
Rule version: N/A | Since: unknown | Updated: 2026-08-27

---

## Summary

The saropa_lints in-process analyzer plugin crashes the Dart analysis server via OOM on projects with 4000+ Dart files and 700+ rules enabled. The plugin resolves types for every rule and retains several GB of resolved AST, exceeding the analysis server's default heap limit. The analyzer repeatedly crashes and restarts in a loop, making IDE analysis unusable.

---

## Attribution Evidence

This is an infrastructure bug in the saropa_lints analyzer plugin itself, not a specific rule. The plugin runs in-process inside the Dart analysis server via `analyzer_plugin: ^0.14.8`.

```bash
# Plugin integration — saropa_lints IS an analyzer plugin
grep -rn "analyzer_plugin" pubspec.yaml
# pubspec.yaml:NN:   analyzer_plugin: ^0.14.8
```

The `analysis_options.yaml` comment in the consuming project (written by saropa_lints authors) acknowledges the issue:

> "MEMORY: this in-process plugin resolves types for every rule and can retain several GB of resolved AST on large projects. The VS Code extension's scan-on-save (out-of-process, ~3 GB fixed) covers the same diagnostics for a fraction of the cost"

---

## Reproducer

1. A Flutter project with ~4335 non-generated Dart files (lib/ + test/, excluding .g.dart, .freezed.dart, l10n)
2. `analysis_options.yaml` with `plugins: saropa_lints:` block active
3. Tier: recommended (793 of 2335 rules enabled)
4. `max_issues: 3000` in `analysis_options_custom.yaml`
5. Open the project in VS Code (or any IDE using the Dart analysis server)

**Result:** The analysis server allocates memory until it hits the heap limit, crashes, restarts, and crashes again in a loop. No analysis diagnostics are usable — neither saropa_lints nor standard Dart/Flutter lints.

**Frequency:** Always — 100% reproducible on the Saropa Contacts project. The only workaround is commenting out the entire `plugins:` block (850+ lines), which disables all saropa_lints diagnostics.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Plugin analyzes files incrementally without exceeding available memory; analysis server remains stable |
| **Actual** | Plugin retains full resolved AST for all files simultaneously; analysis server OOM-crashes in a restart loop |

---

## Root Cause

### Hypothesis A: No incremental / lazy type resolution

The plugin resolves types for every registered rule across every file in the project simultaneously, retaining the full resolved AST in memory. With 4335 files × 793 rules, the retained AST exceeds the analysis server's heap limit (typically 4 GB on 64-bit, but the server may impose a lower default).

The comment in the consuming project's `analysis_options.yaml` confirms this is a known characteristic: "this in-process plugin resolves types for every rule and can retain several GB of resolved AST on large projects."

### Hypothesis B: max_issues accumulation

`max_issues: 3000` retains up to 3000 diagnostic objects in memory. Each diagnostic may reference AST nodes that pin resolved type graphs, preventing GC of file-level ASTs that are otherwise finished.

### Hypothesis C: analyzer 12.x memory regression

saropa_lints pins `analyzer_plugin: ^0.14.8` which caps at `analyzer ^12`. The consuming project resolves `analyzer 12.1.0`. Newer analyzer versions (13.x+) may have improved memory characteristics for plugin hosts. The pin exists because `analyzer_plugin 0.15.0` pulls `analyzer 13.1.0` which breaks the `meta` version constraint.

---

## Suggested Fix

Options (not mutually exclusive):

1. **Lazy / streaming analysis** — resolve types per-file and release the AST after collecting diagnostics, rather than retaining the full resolved AST across all files.
2. **File-count or memory-budget gate** — detect project size at startup and refuse to run in-process above a threshold (e.g. 2000 files), with a clear message directing users to the out-of-process VS Code extension scan-on-save.
3. **Reduce retained state** — after collecting diagnostics for a file, release references to the resolved AST nodes. Only retain the diagnostic message strings and locations.
4. **Lower default max_issues** — reduce from 3000 to 500 as the default, and document the memory trade-off.
5. **Unpin analyzer to ^13** — upgrade `analyzer_plugin` to 0.15.x when the `meta` constraint is resolved, gaining any memory improvements in the newer analyzer.
6. **Chunk-based analysis** — analyze files in batches (e.g. 500 at a time), reporting diagnostics incrementally and releasing previous batches.

---

## Workaround (current)

Comment out the entire `plugins: saropa_lints:` block in `analysis_options.yaml`. This disables all saropa_lints diagnostics but restores analyzer stability.

The VS Code extension (scan-on-save, out-of-process at ~3 GB fixed) is the intended alternative, but when that extension is also disabled the user has no saropa_lints coverage at all.

---

## Environment

- saropa_lints version: 15.2.2 (resolved) / 15.0.3 (analysis_options.yaml pin)
- saropa_lints source version: 15.2.4
- Dart SDK version: 3.13.1 (stable)
- Flutter version: 3.47.1 (stable)
- analyzer version: 12.1.0 (resolved)
- analyzer_plugin version: ^0.14.8 (pubspec constraint)
- Platform: Windows 11 Pro 10.0.22631
- IDE: VS Code
- Project size: 4335 non-generated Dart files, 793 rules enabled, max_issues: 3000
- Triggering project: Saropa Contacts (`d:\src\contacts`)

---

## Fix Applied (2026-08-27)

Five mitigations implemented, addressing hypotheses A–C:

1. **Register trackers for hard-relief eviction** (`main.dart`) — ImpactTracker, SuppressionTracker, and ProgressTracker per-file maps are now registered with MemoryPressureHandler at priority < 50, so they shed on hard RSS trip. A truncated summary is acceptable vs OOM crash.

2. **Stop accumulating records after hard RSS trip** (`saropa_lint_rule.dart`) — `_trackViolation` and `_trackSuppression` bail early when `MemoryPressureHandler.isOverHardLimit`, preventing re-filling the trackers that were just cleared.

3. **Lower hard RSS default from 6144 MB to 4096 MB** (`project_context_throttle_memory.dart`) — 6 GB exceeded the analysis server's typical heap limit, so the valve never tripped before OOM. 4 GB fires early enough to pause rules before the OS kills the process. Still overridable via `SAROPA_LINTS_MAX_RSS_MB`.

4. **Large-project warning at >2000 files** (`saropa_lint_rule.dart`) — `discoverFiles()` now emits a stderr warning when the project exceeds 2000 Dart files, advising users to verify `lane: light` and consider the VS Code extension scan-on-save.

5. **Include tracker sizes in memory estimate** (`project_context_throttle_memory.dart`, `main.dart`) — Added `estimatedBytes` getters to ImpactTracker/SuppressionTracker and a `registerEstimator` API on MemoryPressureHandler, so soft auto-relief accounts for violation/suppression accumulation.

### What this does NOT fix

- The analyzer's own resolved element/AST model remains the dominant memory cost on `lane: full`. Only `lane: light` (the default) avoids that cost entirely.
- Upgrading to `analyzer ^13` (hypothesis C) is blocked by the `meta` version constraint; tracked separately.

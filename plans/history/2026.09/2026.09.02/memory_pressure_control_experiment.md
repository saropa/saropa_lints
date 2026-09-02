# Completed: Memory pressure control experiment (Phase 4)

**Source:** `bugs/infra_analysis_server_7gb_memory_with_plugin.md` — Phase 4, Item 8
**Status:** COMPLETED 2026-08-07

## Results

| Condition | dart.exe RSS (contacts, ~3,900 files) |
|-----------|---------------------------------------|
| With saropa_lints (400+ rules) | 10,800 MB |
| Without saropa_lints | 3,000 MB |
| Delta (plugin overhead) | ~7,800 MB |
| Plugin's own caches (LRU-capped) | ~150 MB max |
| Analyzer element model retention | ~7,650 MB |

## Root cause

The plugin's 400+ rules trigger 308 call sites of `.staticType`, `.library`,
`.allSupertypes`, `.enclosingElement` across 68 rule files. Each call forces
lazy cross-library type resolution, causing the analyzer to load and retain
`LibraryElement` trees for every transitively referenced package across all
3,900 files. Without the plugin, the analyzer only resolves types for open
files.

The plugin's own caches do NOT retain analyzer objects — all 7 static caches
store strings/ints/bools only.

## Decision

Filing upstream rejected — Flutter team won't change the analyzer for a
plugin. Instead: implement `memory_mode: balanced | full` config to skip
type-heavy rules on unchanged files during re-analysis passes.

See handover: `docs/handover/20260807_1930_memory_mode_balanced_plan.md`

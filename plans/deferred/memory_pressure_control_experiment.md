# Deferred: Memory pressure control experiment (Phase 4)

**Source:** `bugs/infra_analysis_server_7gb_memory_with_plugin.md` — Phase 4, Item 8

## Goal

Measure analysis-server memory with and without the saropa_lints plugin to
determine what fraction of the 7.8 GB observed on the `contacts` project
(~3,900 Dart files) is plugin caches vs the analyzer's own resolved element
model.

## Why deferred

Requires manual VS Code testing — open the project, wait for full analysis,
record RSS in Task Manager, then repeat with the plugin removed from
`analysis_options.yaml`. Cannot be automated from the CLI.

## Steps

1. Open `D:\src\contacts` in VS Code with saropa_lints enabled.
2. Wait for analysis to complete (watch Output > Dart Analysis Server).
3. Record `dart.exe language-server` RSS from Task Manager.
4. Comment out the saropa_lints plugin reference in `analysis_options.yaml`.
5. Restart the analysis server (`Dart: Restart Analysis Server` command).
6. Wait for analysis to complete again.
7. Record RSS without the plugin.
8. Compare: if the plugin accounts for >50% of RSS, continue cache
   optimization. If the analyzer's baseline is >4 GB, file upstream.

## Result determines

- Whether to file an upstream Dart SDK issue about analyzer memory.
- Whether further plugin-side cache optimization is worthwhile beyond the
  LRU caps already implemented (Phases 1-2).

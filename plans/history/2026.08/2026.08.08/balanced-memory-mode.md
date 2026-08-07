# Balanced Memory Mode

The Dart analysis server's RSS grew to 11 GB on large projects (~3,900 files) because every incremental re-analysis re-ran all type-heavy rules on all files, triggering lazy cross-library type resolution that the analyzer retains in memory. A new `memory_mode: balanced` setting (default) skips type-heavy rules on files whose source text has not changed since the last pass, avoiding the dominant cause of RSS growth.

## Finish Report (2026-08-08)

### What changed

**New file:** `lib/src/config/memory_mode.dart` — `MemoryMode` enum (`balanced`/`full`) and `MemoryModeConfig` static holder with `markCli()` for scan CLI override.

**`lib/src/native/saropa_context.dart`** — balanced-mode skip gate in `_wrapCallback`: when `shouldApplyBalancedFiltering` is true, a file's source text is unchanged, the rule declares `usesTypeResolution`, and the rule previously passed on that file, the callback returns early. Optimistic pass recording at the end of `_shouldSkipCurrentFile` marks type-heavy rules as "passed" before the callback runs; violations revoke the record via `revokeRulePassed`.

**`lib/src/native/config_loader.dart`** — `_loadMemoryMode()` parses `memory_mode:` from the `saropa_lints:` block in `analysis_options_custom.yaml` (scoped to avoid matching unrelated sections) or the `SAROPA_MEMORY_MODE` env var. A shared `_parseMemoryMode()` helper eliminates duplication between the two branches.

**`lib/src/saropa_lint_rule.dart`** — `usesTypeResolution` getter (default `false`) on `SaropaLintRule`. `SaropaDiagnosticReporter._trackViolation` calls `FileContentCache.revokeRulePassed` (gated behind `shouldApplyBalancedFiltering`).

**`lib/src/project_context_project_file.dart`** — `FileContentCache.revokeRulePassed()` method added.

**`lib/src/scan/scan_runner.dart`** — `MemoryModeConfig.markCli()` in `_prepare()` forces full mode for CLI scans.

**65 rule files** — `@override bool get usesTypeResolution => true;` added to every `SaropaLintRule` subclass that uses resolved type information.

### Review findings addressed

- Config parser scoped to `saropa_lints:` block (matching `_loadLogLevel` pattern) to prevent false matches from other YAML sections.
- Bookkeeping (`recordRulePassed`/`revokeRulePassed`) gated behind `shouldApplyBalancedFiltering` so `full` mode incurs zero new overhead.
- Warning text on invalid config values changed from "Using balanced" to "Keeping current mode" for accuracy.
- Dead code removed: `_lastChangeResult` map and `wasUnchangedOnLastCheck()` method had zero callers.
- Cross-file staleness tradeoff documented in code comment and CHANGELOG: dependency API changes may produce stale diagnostics on unchanged dependent files until the file is edited or the analysis server restarts.

### Hardening pass

- **Import-graph invalidation**: `ImportGraphTracker.rawImportersOf()` added — a lightweight pre-`compute()` reverse lookup using raw import URIs. `FileContentCache.hasChanged()` now cascades pass-record invalidation to direct importers of a changed file. This eliminates the cross-file staleness gap for direct dependencies.
- **`_isCli` reset**: `MemoryModeConfig.resetForTest()` added to clear both mode and CLI flag, preventing state leakage between tests.
- **Bookkeeping gated**: `recordRulePassed`/`revokeRulePassed` calls are now gated behind `shouldApplyBalancedFiltering`, so `full` mode incurs zero new overhead.

### Known limitations

- **Transitive staleness**: if file C changes and file B imports C, B's pass records are cleared. But if file A imports B (not C directly), A's pass records remain — A is re-analyzed only when B's source text also changes. Restart the analysis server to force full re-evaluation.
- **LRU eviction**: the `_passedRules` cache is capped at 500 files. Projects with more hot files silently fall back to always-run for evicted entries (safe but reduces savings).
- **Initial peak unaffected**: the optimization only applies to re-analysis passes. The first full analysis still peaks high.
- **Basename matching heuristic**: `rawImportersOf` matches import URIs by basename suffix, which could over-invalidate if two different files share the same basename (e.g., `models/user.dart` and `views/user.dart`). Over-invalidation is safe (extra re-analysis, not missed violations).

### Test evidence

- `resolved_rule_harness_self_test.dart`: 54 tests pass (all rules compile and fire correctly).
- `defensive_coding_test.dart`: 52 tests pass (no regressions in defensive helpers).
- `test/config/memory_mode_test.dart`: 11 new tests covering `MemoryModeConfig` defaults/full/CLI/reset states and `FileContentCache` record/revoke/invalidate lifecycle.

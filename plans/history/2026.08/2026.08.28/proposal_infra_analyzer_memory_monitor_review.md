# Finish Report: Review of Analysis Server Memory Monitor Proposal

The proposal at `bugs/proposal_infra_analyzer_memory_monitor.md` overstated how much of its design already exists in `MemoryPressureHandler`, claiming "soft/hard thresholds" and an extension path for "graduated rule shedding" where only a single hard RSS cutoff and an all-or-nothing cache/rule pause currently exist.

## Findings

Verification against `lib/src/project_context_throttle_memory.dart` showed:

- `MemoryPressureHandler.isOverHardLimit` (line 1084) implements one hard threshold with hysteresis (`_hardLimitMb`, release margin `_rssRecoveryMarginMb`) — there is no separate soft/warning threshold.
- On trip, `relieve(clearAll: true)` clears every registered cache and rule execution pauses entirely; there is no tier-aware (INFO/WARNING) selective shedding mechanism to extend.
- Rule registration (`_allRuleFactories` in `lib/saropa_lints.dart`) is all-or-nothing; no runtime path exists to selectively disable a rule subset by tier.
- The proposal's edge case for tracking "multiple analysis servers" via `ProcessInfo.currentRss` is not achievable with that API, which only reads the calling process's own RSS.
- The proposal did not reference the per-file memory budget added in commit `9c9c662b` (2026-08-27), which is a related and more recent mitigation.
- The `Related rules` line pointed at `bugs/infra_analyzer_oom_crash_large_projects.md`, which had already been archived to `plans/history/2026.08/2026.08.27/` with Status: Fixed.

## Changes Applied

`bugs/proposal_infra_analyzer_memory_monitor.md` was edited to:

1. Correct the related-bug reference to its archived history path.
2. Clarify the multiple-analysis-server edge case: `ProcessInfo.currentRss` cannot observe sibling processes; cross-process tracking needs a separate mechanism.
3. Replace the Implementation Notes section with an explicit "what exists today" vs. "what is new" breakdown, noting the absence of a soft threshold and of any tier-based rule-shedding mechanism, and referencing the per-file memory budget from commit `9c9c662b`.
4. Add a scope estimate (multi-week effort across plugin core, rule registration, and the VS Code extension) rather than implying a small extension.

## Minimal Slice Shipped

Following the review, the "periodic memory log" bullet from the proposal's Implementation Notes was implemented as a minimal, self-contained slice:

- `MemoryPressureHandler._refreshHardLimit` (`lib/src/project_context_throttle_memory.dart`) now writes a `[memory] RSS <n>MB (cap <n>MB)` line to `reports/.saropa_lints/plugin.log` on a 30-second wall-clock cooldown, reusing the existing throttled refresh call site rather than adding a second polling loop.
- `dart run saropa_lints:memory_report [path]` (`bin/memory_report.dart`, new) reads that log and reports sample count, min/max/latest RSS, and percent-of-cap — the CLI is a separate process and cannot read the live analysis server's memory directly, so this is a post-crash diagnostic, not a live monitor.
- Wired into the CLI dispatcher (`bin/saropa_lints.dart`) as `memory-report`.

An independent review pass (delegated subagent, `general-purpose`/sonnet) verified the regex against the actual log line format, checked for architectural duplication (none found), and flagged one real gap: no test exercised the *write* side of the periodic log (only the CLI's read/parse side was tested). Two new test-only seams were added to `MemoryPressureHandler` (`refreshForTesting`, `resetMemoryLogCooldownForTesting`, mirroring the existing `setHardLimitTrippedForTest` pattern) and covered in `test/report/memory_pressure_periodic_log_test.dart` (2 tests: the line is written, and the 30s cooldown suppresses a duplicate on immediate re-refresh). Both pass, alongside the 4 pre-existing `test/bin/memory_report_test.dart` read-side tests.

The review's other findings were accepted without code changes:
- Every log write already `fsync`s synchronously (`PluginLogger._appendToFile`); the periodic call adds one such write per 30s while the RSS valve is armed — judged acceptable at that cadence, consistent with the proposal's stated sampling interval.
- `bin/memory_report.dart` builds its log path via manual `Platform.pathSeparator` concatenation rather than `package:path`'s `join` — this matches `PluginLogger.setProjectRoot`'s own path construction (the producer of the file being read), so it was left as-is rather than switched to match an unrelated test file's convention.
- Log rotation truncates `plugin.log` when it grows large (`PluginLogger._rotateIfNeeded`), so `memory_report`'s min/max is only valid for the current file's window, not the full session — not fixed here; the tool's output does not currently caveat this.

## Status

The proposal remains `Status: Open`. This review corrected inaccurate claims about existing infrastructure and shipped one of its four Implementation Notes bullets (periodic memory log) as a minimal, tested slice. The warning threshold, graduated rule shedding, and status-bar integration remain unbuilt and undesigned beyond the corrected proposal text.

# PROPOSAL: Analysis Server Memory Monitor

**Status: Open**

<!-- Status values: Open → Accepted → In Progress → Closed -->

Created: 2026-08-27
Type: Tooling / Infrastructure
Related rules: N/A (infrastructure — relates to `plans/history/2026.08/2026.08.27/infra_analyzer_oom_crash_large_projects.md`, Status: Fixed)

---

## Summary

A cross-project utility that monitors the Dart analysis server's memory usage and takes corrective action (warning, restart, or rule shedding) before OOM crashes occur. Belongs in saropa_lints infrastructure so all consuming projects benefit without per-project configuration.

---

## Motivation

The Dart analysis server OOM-crashes on large projects (4000+ files, 1400+ transitive dependencies). The base server alone can consume 3.9 GB; with saropa_lints enabled, memory exceeds 6 GB. Crashes are silent — the server dies and VS Code restarts it, which crashes again in a loop. No diagnostic is emitted before the crash.

Current mitigations (RSS hard limit in saropa_lints, `--old_gen_heap_size` VM arg, folder exclusions) are reactive and per-project. A proactive monitor would:
- Warn when memory crosses a configurable threshold (e.g. 70% of `--old_gen_heap_size`)
- Auto-shed non-essential saropa_lints rules before the hard limit
- Log memory trends so crashes can be correlated with specific file edits or analysis passes
- Surface the problem to the user via a VS Code notification or status bar indicator

---

## Detection / Behavior

### Should trigger (high memory)

```
[saropa_lints:memory] WARNING: Analysis server RSS at 4.2 GB (70% of 6 GB limit).
  Active rules: 793 | Files analyzed: 4335 | Trackers: 1847 violations, 312 suppressions
  Action: shedding INFO-tier rules (estimated -800 MB)
```

### Should not trigger (normal operation)

Analysis server RSS stays below the warning threshold. No output, no overhead beyond periodic RSS sampling (once per 30s).

---

## Proposed Tier

N/A — infrastructure utility, not a lint rule. Ships as part of the saropa_lints analyzer plugin and/or VS Code extension.

---

## Edge Cases

1. **Multiple analysis servers** — VS Code can spawn multiple language server processes (crash-restart, sub-packages). `ProcessInfo.currentRss` only reads the current process's own RSS, not other processes' — a monitor running in-process (as `MemoryPressureHandler` does) cannot observe a sibling server's memory this way. Cross-process tracking would need a different approach (e.g. `ps`/`tasklist` polling by process name), which is a separate, heavier mechanism.
2. **Non-saropa_lints memory** — the base analyzer is the dominant consumer. Rule shedding only helps when saropa_lints is the marginal cost. The monitor should distinguish base vs plugin memory if possible.
3. **Windows vs macOS/Linux** — RSS measurement APIs differ by platform. Use `ProcessInfo.currentRss` (already used by `MemoryPressureHandler`).
4. **Extension-only mode** — when the in-process plugin is disabled and only the VS Code extension runs (scan-on-save), the monitor should track the extension's out-of-process scanner instead.

---

## Alternatives Considered

1. **Per-project VS Code tasks** — rejected; doesn't scale across projects and requires manual setup.
2. **External watchdog script** — rejected; requires separate installation and can't interact with saropa_lints rule state.
3. **Rely solely on `--old_gen_heap_size`** — insufficient; the VM flag is a hard limit that triggers GC but doesn't shed rules or warn before OOM.

---

## Implementation Notes

### What exists today

`MemoryPressureHandler` in `project_context_throttle_memory.dart` already:
- Samples real process RSS via `ProcessInfo.currentRss` (`_currentRssMb`, line 1116), throttled to avoid a syscall per node
- Enforces a **single hard limit** (`isOverHardLimit` / `_hardLimitTripped`, line 1084) with hysteresis — trips at `_hardLimitMb`, releases at `_hardLimitMb - _rssRecoveryMarginMb`
- On trip, clears **all** registered caches at once (`relieve(clearAll: true)`) and pauses rule execution entirely — there is no notion of shedding by rule tier/severity
- Recently gained a per-file memory budget (commit `9c9c662b`, 2026-08-27) — this proposal should define how the monitor's threshold/warning logic interacts with that budget rather than treating RSS as the only signal

There is **no soft/warning threshold today** — only the one hard cutoff — and **no graduated shedding by rule tier**. Both are new capabilities, not extensions of an existing mechanism:

- A warning notification channel (stderr message or VS Code diagnostic) at a new soft threshold (e.g. 70% of hard limit)
- Graduated rule shedding by tier (INFO → WARNING → …) before the hard limit — requires a new runtime mechanism to selectively disable a subset of registered rules (rules are currently all-or-nothing via `_allRuleFactories` in `saropa_lints.dart`); no such selective-disable path exists yet
- A periodic memory log for post-crash diagnosis
- Integration with the VS Code extension status bar (if extension is installed)

### Scope estimate

This touches the plugin core (new threshold + shedding logic), rule registration (selective tier disable), and the VS Code extension (status bar, notifications) across Windows/macOS/Linux RSS differences. Rough order: multi-week effort, not a small extension of `MemoryPressureHandler`. Two findings narrow the surface somewhat:

- The extension already creates a status bar item (`extension/src/extension.ts`, `createStatusBarItem`) for vibrancy data — a memory indicator could reuse that infra rather than building new UI plumbing.
- A minimal slice of the periodic-memory-log item shipped 2026-08-28: `MemoryPressureHandler._refreshHardLimit` now writes a `[memory] RSS <n>MB (cap <n>MB)` line to `reports/.saropa_lints/plugin.log` on a 30s cadence, and `dart run saropa_lints:memory_report [path]` summarizes that trend (min/max/latest RSS, % of cap) for post-crash diagnosis. This covers only the "periodic memory log" bullet — the warning threshold, graduated rule shedding, and status-bar integration remain unbuilt.

---

## Environment

- Triggering project: Saropa Contacts (4335 files, 1412 deps, analyzer baseline 3.9 GB)
- saropa_lints version: 15.2.4
- Dart SDK: 3.13.1
- Platform: Windows 11 Pro

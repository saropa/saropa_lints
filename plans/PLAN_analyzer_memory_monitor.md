# Analyzer Memory Monitor Plan

**Created:** 2026-08-27
**Status:** Not started — Phase 0 (periodic memory log) shipped 2026-08-28 as a minimal slice; Phases 1-3 below are unbuilt.
**Trigger:** Dart analysis server OOM-crashes on large projects (4000+ files, 1400+ transitive deps). No diagnostic is emitted before the crash — see `plans/history/2026.08/2026.08.27/infra_analyzer_oom_crash_large_projects.md` (Status: Fixed, the reactive mitigation).
**Related:** `plans/history/2026.08/2026.08.28/proposal_infra_analyzer_memory_monitor_review.md` (accuracy review + Phase 0 finish-report)

---

## Background

The base analyzer alone can consume 3.9 GB on a large project; with saropa_lints enabled, memory exceeds 6 GB. Crashes are silent — the server dies, VS Code restarts it, and it crashes again in a loop. Current mitigations (`MemoryPressureHandler`'s single hard RSS limit, `--old_gen_heap_size`, folder exclusions) are reactive and per-project, not proactive or diagnostic.

### What exists today

`MemoryPressureHandler` (`lib/src/project_context_throttle_memory.dart`) already:
- Samples real process RSS via `ProcessInfo.currentRss` (`_currentRssMb`, line 1167), throttled to avoid a syscall per node
- Enforces a **single hard limit** (`isOverHardLimit`, line 1110 / `_hardLimitTripped`, line 1050) with hysteresis — trips at `_hardLimitMb`, releases at `_hardLimitMb - _rssRecoveryMarginMb`
- On trip, clears **all** registered caches at once (`relieve(clearAll: true)`) and pauses rule execution entirely — no notion of shedding by rule tier/severity
- Has a per-file memory budget (commit `9c9c662b`, 2026-08-27) — any new threshold/warning logic must define how it interacts with this budget rather than treating RSS as the only signal

There is **no soft/warning threshold** — only the one hard cutoff — and **no graduated shedding by rule tier**. Rule registration (`_allRuleFactories` in `lib/saropa_lints.dart`, list begins line 231) is currently all-or-nothing; a selective per-rule/tier disable path does not exist and is a prerequisite for Phase 2 below.

Line numbers above verified 2026-08-28 against current `main` (they had drifted from the original proposal's claims due to concurrent unrelated commits — re-verify again before starting implementation if significant time has passed).

### Phase 0 — shipped 2026-08-28

A minimal slice of the "periodic memory log" idea shipped ahead of this plan:
- `MemoryPressureHandler._refreshHardLimit` writes a `[memory] RSS <n>MB (cap <n>MB)` line to `reports/.saropa_lints/plugin.log` on a 30s cooldown.
- `dart run saropa_lints:memory_report [path]` (new CLI, `bin/memory_report.dart`) summarizes that trend (min/max/latest RSS, % of cap) for post-crash diagnosis, with a CAVEAT when the log was rotated and a one-shot warning when RSS sampling is unavailable on the platform.
- Tests: `test/bin/memory_report_test.dart`, `test/report/memory_pressure_periodic_log_test.dart`.

This covers diagnosis after the fact. It does not warn before a crash, shed rules, or surface anything in the UI — that's Phases 1-3.

---

## Detection / Behavior (target end state)

### Should trigger (high memory)

```
[saropa_lints:memory] WARNING: Analysis server RSS at 4.2 GB (70% of 6 GB limit).
  Active rules: 793 | Files analyzed: 4335 | Trackers: 1847 violations, 312 suppressions
  Action: shedding INFO-tier rules (estimated -800 MB)
```

### Should not trigger (normal operation)

Analysis server RSS stays below the warning threshold. No output, no overhead beyond periodic RSS sampling (already implemented, Phase 0).

---

## Phase 1: Soft/warning RSS threshold

- [ ] Add a second, lower threshold (e.g. `_softLimitMb`, default 70% of `_hardLimitMb`) to `MemoryPressureHandler`, alongside the existing hard limit — with its own hysteresis so it doesn't flap
- [ ] On crossing the soft threshold, emit a warning via `PluginLogger` (reuse the Phase 0 log line format) distinct from the hard-limit trip message
- [ ] Decide how the soft threshold interacts with the existing per-file memory budget (added 2026-08-27) — do not treat RSS as the only signal
- [ ] Unit tests mirroring the existing hard-limit hysteresis tests
- [ ] No VS Code surfacing yet (that's Phase 3) — stderr/log only

## Phase 2: Selective rule-disable mechanism (prerequisite for Phase 3 shedding)

- [ ] Design how `_allRuleFactories` (`lib/saropa_lints.dart`, list begins line 231) can register rules with disable/enable toggled at runtime, keyed by tier — today registration is all-or-nothing
- [ ] Confirm this doesn't conflict with the existing tier system in `lib/src/tiers.dart` (essential/recommended/professional/comprehensive/pedantic) — graduated shedding is a runtime overlay on top of the configured tier, not a replacement for it
- [ ] Add tests proving a shed rule stops firing and a restored rule resumes firing without a full plugin restart

## Phase 3: Graduated rule shedding by tier

- [ ] On crossing the soft threshold from Phase 1, shed INFO-tier rules first via the Phase 2 mechanism; escalate toward the hard limit if RSS keeps climbing
- [ ] Restore shed rules once RSS drops back below the soft threshold (with hysteresis, matching the hard-limit pattern)
- [ ] Log which rules were shed and the estimated memory recovered (best-effort estimate is acceptable — exact per-rule memory accounting is out of scope)
- [ ] Tests: shed → restore cycle, ordering (INFO before WARNING before ERROR-tier), no shedding of essential/security rules

## Phase 4: VS Code extension integration

- [ ] Status bar indicator — reuse the existing `createStatusBarItem` infra in `extension/src/extension.ts:978` (already used for vibrancy data) rather than building new UI plumbing
- [ ] Surface the Phase 1 warning and Phase 3 shedding events as a status bar state (not just a notification) so it's visible without a toast
- [ ] i18n: any new user-facing string goes through `l10n()` per `.claude/rules/i18n.md` — do not hardcode
- [ ] Manual test: trigger a soft-threshold crossing on a large project, confirm the status bar updates

---

## Edge Cases

1. **Multiple analysis servers** — VS Code can spawn multiple language server processes (crash-restart, sub-packages). `ProcessInfo.currentRss` only reads the current process's own RSS, not siblings' — an in-process monitor (as `MemoryPressureHandler` is) cannot observe a sibling server's memory this way. Cross-process tracking would need `ps`/`tasklist` polling by process name — a separate, heavier mechanism, not in scope for Phases 1-4.
2. **Non-saropa_lints memory** — the base analyzer is the dominant consumer. Rule shedding only helps when saropa_lints is the marginal cost; Phase 3 should log both figures where distinguishable.
3. **Windows vs macOS/Linux** — RSS measurement differs by platform. Continue using `ProcessInfo.currentRss` (already in use); Phase 0 already found and fixed a Windows-only console-encoding gotcha (ASCII-only CLI output, see `memory_report.dart`).
4. **Extension-only mode** — when the in-process plugin is disabled and only the VS Code extension runs (scan-on-save), Phase 4 should track the extension's out-of-process scanner instead of the plugin's in-process RSS.

---

## Alternatives Considered

1. **Per-project VS Code tasks** — rejected; doesn't scale across projects and requires manual setup.
2. **External watchdog script** — rejected; requires separate installation and can't interact with saropa_lints rule state.
3. **Rely solely on `--old_gen_heap_size`** — insufficient; the VM flag is a hard limit that triggers GC but doesn't shed rules or warn before OOM.

---

## Scope Estimate

Multi-week effort across the plugin core (Phases 1 and 3), rule registration (Phase 2, the hardest prerequisite — no selective-disable path exists today), and the VS Code extension (Phase 4) across Windows/macOS/Linux RSS differences. Phase 0 (periodic log) is the only piece shipped so far.

---

## Environment (originating report)

- Triggering project: Saropa Contacts (4335 files, 1412 deps, analyzer baseline 3.9 GB)
- saropa_lints version: 15.2.4
- Dart SDK: 3.13.1
- Platform: Windows 11 Pro

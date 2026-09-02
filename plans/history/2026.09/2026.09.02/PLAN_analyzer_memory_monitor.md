# Analyzer Memory Monitor Plan

**Created:** 2026-08-27
**Status:** Phases 0-4 implemented 2026-08-31 (soft threshold, severity-based shedding, status bar integration). Needs real-project validation.
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

- [x] Add a second, lower threshold (e.g. `_softLimitMb`, default 70% of `_hardLimitMb`) to `MemoryPressureHandler`, alongside the existing hard limit — with its own hysteresis so it doesn't flap
- [x] On crossing the soft threshold, emit a warning via `PluginLogger` (reuse the Phase 0 log line format) distinct from the hard-limit trip message
- [x] Decide how the soft threshold interacts with the existing per-file memory budget (added 2026-08-27) — do not treat RSS as the only signal
- [x] Unit tests mirroring the existing hard-limit hysteresis tests
- [x] No VS Code surfacing yet (that's Phase 3) — stderr/log only

## Phase 2: Selective rule-disable mechanism (prerequisite for Phase 3 shedding)

- [x] Design how `_allRuleFactories` (`lib/saropa_lints.dart`, list begins line 231) can register rules with disable/enable toggled at runtime, keyed by tier — today registration is all-or-nothing
- [x] Confirm this doesn't conflict with the existing tier system in `lib/src/tiers.dart` (essential/recommended/professional/comprehensive/pedantic) — graduated shedding is a runtime overlay on top of the configured tier, not a replacement for it
- [x] Add tests proving a shed rule stops firing and a restored rule resumes firing without a full plugin restart

## Phase 3: Graduated rule shedding by tier

- [x] On crossing the soft threshold from Phase 1, shed INFO-tier rules first via the Phase 2 mechanism; escalate toward the hard limit if RSS keeps climbing
- [x] Restore shed rules once RSS drops back below the soft threshold (with hysteresis, matching the hard-limit pattern)
- [x] Log which rules were shed and the estimated memory recovered (best-effort estimate is acceptable — exact per-rule memory accounting is out of scope)
- [x] Tests: shed → restore cycle, ordering (INFO before WARNING before ERROR-tier), no shedding of essential/security rules

## Phase 4: VS Code extension integration

- [x] Status bar indicator — reuse the existing `createStatusBarItem` infra in `extension/src/extension.ts:978` (already used for vibrancy data) rather than building new UI plumbing
- [x] Surface the Phase 1 warning and Phase 3 shedding events as a status bar state (not just a notification) so it's visible without a toast
- [x] i18n: any new user-facing string goes through `l10n()` per `.claude/rules/i18n.md` — do not hardcode
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

## Phase 5: Further Memory & Speed Savings (research 2026-08-31)

### Current architecture (recap)

The two-lane system already isolates type-resolving rules from the in-process analyzer:
- **Light lane** (in-process): syntactic rules only, +0.6% RSS over baseline
- **Full lane** (scan daemon): all rules including type-resolving, separate process with RSS-based recycle

Within the daemon, one `getResolvedUnit()` call per file feeds all rules via a shared `ScanWalker` — already optimal for per-file work. The `AnalysisContextCollection` retains resolved element models indefinitely; the only relief is daemon recycle on RSS threshold or 500 requests.

Cross-file analysis is decoupled: runs as a CLI batch, writes a `cross_file_snapshot.json`, rules read the snapshot — no live cross-file resolution in-process.

### Finding 1: ~200+ rule classes falsely claim `usesTypeResolution`

**Impact: HIGH — these rules are excluded from the light lane unnecessarily**

At least 200+ rule classes override `usesTypeResolution => true` but perform only syntactic/AST analysis (string matching, operator counting, directive checking, source text comparison). Worst offenders by volume:

| File | False claims / Total | Notes |
|------|---------------------|-------|
| `structure_rules.dart` | ~55 / 58 | Only 3 classes use `.element`/`.staticType` |
| `stylistic_rules.dart` | ~40 / 46 | Only ~6 classes use resolved types |
| `stylistic_additional_rules.dart` | ~23 / 24 | Only 1 class uses `.staticType` |
| `complexity_rules.dart` | 14 / 15 | Only 1 class uses `.staticType` |
| `config_rules.dart` | 13 / 13 | No class uses resolved types (2 have empty run methods) |
| `api_network_rules.dart` | ~7 / 10+ | Only 3-4 classes use `.staticType`/`.element` |
| `control_flow_rules.dart` | ~10 / 13 | Only ~3 classes use `.staticType` |

**Fix:** Audit each rule class and flip `usesTypeResolution => false` where no resolved-type access exists. This moves hundreds of rules into the light lane, reducing daemon load and enabling balanced-mode skipping in-process.

**Risk:** Low — `usesTypeResolution` is a self-classification flag. Setting it `false` for a rule that truly doesn't resolve types is always correct. The flag was likely set `true` at the file level rather than per-class.

**Effort:** Medium — mechanical audit of ~66 rule files, but each class must be individually verified. A grep-based script could automate most of it.

### Finding 2: `.staticType` heavy hitters genuinely need type resolution

The top 5 consumers (206 of ~306 total call sites) — `async_rules.dart`, `collection_rules.dart`, `migration_rules.dart`, `code_quality_avoid_rules.dart`, `type_rules.dart` — **cannot** be converted to syntactic checks. They inspect resolved types on arbitrary expressions (method return values, interpolation, binary operands, inferred variables) where no AST type annotation exists. No savings available here.

### Finding 3: Daemon balanced-mode filtering is disabled

`MemoryModeConfig.markCli()` disables balanced filtering for all CLI/daemon scans. The daemon could skip type-heavy rules on unchanged files across requests (the same optimization that balanced mode provides in-process), since it already receives `changeFile()` notifications.

**Fix:** Implement daemon-side balanced filtering — track which files have changed since last scan and skip type-heavy rules on unchanged files. The `FileContentCache` pass-tracking infrastructure already exists.

**Risk:** Medium — daemon scans are expected to be comprehensive (CI, baseline scans). This should only apply to save-triggered incremental scans, not full scans.

**Effort:** Medium — wire the existing balanced-mode logic into the daemon's `_scanFilesResolved` loop for incremental scan requests.

### Finding 4: No resolved-model eviction between files

After `_scanSingleFileResolved()` returns, the `ResolvedUnitResult` goes out of scope but the analyzer's internal `AnalysisContextCollection` cache retains the resolved element model graph indefinitely. Between files, there is no GC hint or explicit eviction.

**Fix (speculative):** The Dart analyzer's `AnalysisDriver` has `removeFile()` and `dispose()` APIs, but evicting mid-scan would force re-resolution if a later file imports the evicted one. A more practical approach: after completing a scan batch, call `applyPendingFileChanges()` or rebuild the collection for the next batch. This trades re-prewarm time for memory.

**Risk:** High — analyzer internals are not designed for selective eviction. Could cause correctness issues or worse performance from re-resolution.

**Effort:** High — requires deep analyzer SDK knowledge and benchmarking.

### Finding 5: Per-file GC hints between scans

Between files in `_scanFilesResolved`, there is no explicit GC trigger or memory check. Adding a `if (rss > threshold) { /* force GC or bail */ }` check between files could prevent runaway growth within a single batch.

**Fix:** Add RSS sampling between files (reuse `MemoryPressureHandler` sampling) and short-circuit the scan if RSS exceeds the daemon's recycle threshold.

**Risk:** Low — worst case, a scan completes with fewer files and the extension re-requests the remainder after daemon recycle.

**Effort:** Low — a few lines in the scan loop.

### Recommendations (priority order)

1. **Fix false `usesTypeResolution` claims** — highest ROI, lowest risk. Moves ~200+ rules to light lane.
2. **Per-file RSS check in daemon scan loop** — trivial to add, prevents OOM mid-batch.
3. **Daemon balanced-mode for incremental scans** — medium effort, saves significant memory on save-triggered scans.
4. **Resolved-model eviction** — defer unless the above three are insufficient. High risk, uncertain reward.

---

## Scope Estimate

Multi-week effort across the plugin core (Phases 1 and 3), rule registration (Phase 2, the hardest prerequisite — no selective-disable path exists today), and the VS Code extension (Phase 4) across Windows/macOS/Linux RSS differences. Phase 0 (periodic log) is the only piece shipped so far.

---

## Finish Report (2026-08-31)

### Phase 5 research — memory and speed savings audit

Investigated four optimization avenues for reducing the analyzer's memory footprint beyond the Phase 1-4 shedding infrastructure.

**Primary finding:** ~200+ rule classes across 9 files falsely declare `usesTypeResolution => true` despite performing only syntactic analysis. These rules are unnecessarily excluded from the light lane (in-process, +0.6% RSS) and forced into the scan daemon's full lane. Flipping each class to `false` moves it in-process with near-zero memory cost. The false claims originated from file-level blanket overrides rather than per-class evaluation.

**Secondary finding:** The top 5 `.staticType` consumers (async, collection, migration, type, code-quality rules — 206 of ~306 total resolved-type call sites) genuinely require type resolution for correctness. No syntactic replacement is possible.

**Additional opportunities identified:** (a) per-file RSS check in the daemon scan loop to prevent mid-batch OOM; (b) daemon-side balanced-mode filtering for incremental scans; (c) resolved-model eviction (high risk, deferred).

**Code review of uncommitted Phases 1-4 implementation** surfaced: `_refreshSoftLimit` exceeds 50-line function limit (76 lines), `_updateShedLevel` rebuilds shed set unnecessarily when level unchanged, `memoryPressureWatcher.ts` uses raw `fs.watch` without debounce and duplicates the reports-dir path, tooltip logic duplicates the suffix decision tree, and the `SAROPA_LINTS_SHED_RULES` env-var opt-in is buried (user flagged this — needs visible UI surface in `analysis_options_custom.yaml`).

**Bug fixes applied during finish review:**
- Recovery thresholds in `_refreshSoftLimit` go negative when `_hardLimitMb < 366` (e.g. `SAROPA_LINTS_MAX_RSS_MB=300` → soft=210, recovery=210-256=-46, never true). Fixed both soft-recovery and de-escalation checks with `.clamp(0, threshold)`.
- `_updateShedLevel` rebuilt the shed rule name set (iterating 2300+ rules) even when the level hadn't changed. Added early-return guard.

**Not changed (deferred to implementation session):** `memoryPressureWatcher.ts` fs.watch issues (null filename on macOS, missing-directory ENOENT, no debounce), `_refreshSoftLimit` function length (76 lines), reports-dir path duplication, tooltip decision-tree duplication, env-var-only opt-in surface.

## Finish Report (2026-09-01)

### Phase 5 Finding 1 completion + shed-rules UI surface

**`usesTypeResolution` audit completed:** 180 false claims flipped to `false` across 9 rule files (structure_rules: 56, stylistic_rules: 44, api_network_rules: 38, stylistic_additional_rules: 23, complexity_rules: 14, config_rules: 13, platform_rules: 5, control_flow_rules: 0 needed, debug_rules: 0 — left `true`, genuinely uses `.element`/`formalParameters`). Integrity test unskipped and now guards both directions. Test regex extended with `formalParameters` to catch modern element-model resolution APIs that the analyzer's API surface renamed from `staticElement`.

**VS Code memory-pressure notification added:** When the analyzer soft limit trips but `shed_rules` is not enabled, the extension now shows a `showWarningMessage` toast with "Enable" (opens `analysis_options_custom.yaml`) and "Learn More" buttons. Fires once per session. A persistent status-bar suffix and tooltip line also appear when soft limit is tripped with shedding off, so the user has ongoing visibility even after dismissing the toast.

**`shed_rules` YAML surface completed (from prior session):** `analysis_options_custom.yaml` top-level key, generated by `dart run saropa_lints:init` with a commented template line. Env var still works (precedence) with a new warning on unrecognized values like `=1` or typos.

**Code review fixes:** `_tryRead` change-detection predicate extended to include `softLimitTripped` (was silently dropping state transitions when shedding was disabled). `_loadShedRulesConfig` now warns on unrecognized env-var and yaml values (previously silent no-op on typos). `getStats()` exposes `shedEnabled` field, `memory_state.json` includes it, and the extension reads it.

**Deferred:** `_loadOutputConfig` env-var-then-yaml deduplication (reads two env vars with different types — doesn't fit the shared helper cleanly). Phase 5 Finding 4 (resolved-model eviction — high risk, deferred unless other optimizations prove insufficient).

## Finish Report (2026-09-01 session 2)

### Phase 5 Findings 2-5 resolution + deferred refactors

**Reports-dir single source of truth:** Extracted `REPORTS_DIR` and `SAROPA_LINTS_DATA_DIR` constants plus `reportsPath()`, `saropaLintsDataPath()`, `reportsUri()`, `saropaLintsDataUri()` helpers into `extension/src/reportsPaths.ts`. Replaced 27 hardcoded `'reports'`/`'.saropa_lints'` string literals across 18 production TypeScript files. Test files left with literals (test-internal paths, no shared-constant benefit).

**Config loader deduplication:** Extracted `_resolveEnvThenYaml()` helper in `config_loader.dart`, replacing duplicated env-var-then-yaml lookup logic in `_loadShedRulesConfig` and `_loadMemoryMode`. The helper centralizes env-var read (with platform safety catch), yaml fallback (with optional deprecation-aware reader), and unrecognized-value warnings. `_loadOutputConfig` left untouched — it reads two env vars with incompatible types (int + string).

**Phase 5 Finding 2 (`.staticType` heavy hitters):** Closed as documented — top 5 consumers (206 of ~306 call sites) genuinely require type resolution. No optimization available.

**Phase 5 Finding 3 (daemon balanced-mode filtering):** Already implemented by existing infrastructure. `balanced` mode filters in-process (analysis server) where `_isCli=false`, skips CLI. `aggressive` mode filters everywhere. No additional code change needed.

**Phase 5 Finding 4 (resolved-model eviction):** Deferred — high risk, analyzer SDK internals not designed for selective mid-scan eviction. Would need benchmarking to determine if memory savings outweigh re-resolution costs.

**Phase 5 Finding 5 (per-file RSS check):** Implemented in `scan_runner.dart`. After each `_scanSingleFileResolved()` call, samples `ProcessInfo.currentRss` (guarded with try/catch), compares against `MemoryPressureHandler.hardRssLimitMb` (fallback: 1500 MB), and breaks with a warning when exceeded. Partial diagnostics collected so far are still returned.

---

## Environment (originating report)

- Triggering project: Saropa Contacts (4335 files, 1412 deps, analyzer baseline 3.9 GB)
- saropa_lints version: 15.2.4
- Dart SDK: 3.13.1
- Platform: Windows 11 Pro

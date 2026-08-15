# PLAN: Scan-only diagnostics — retire the in-process plugin as the default

**Status: Proposed (2026-08-14)**
**Owner decision that triggered this:** in-process delivery has never worked for the
maintainer ("i havent seen a live squiggle ever") and costs 7.8 GB+ on large projects.
Everything runs externally; the analysis server carries zero saropa_lints load.

---

## Problem (measured, not estimated)

| Configuration | Analysis-server RSS on `D:\src\contacts` (~3,900 files) | Evidence |
|---|---|---|
| Plugin loaded, recommended tier (790–1,036 rules) | 7.8–13.6 GB, OOM crashes | [infra_analysis_server_7gb_memory_with_plugin.md](../plans/history/2026.08/2026.08.07/infra_analysis_server_7gb_memory_with_plugin.md), user screenshots 2026-08-08 |
| Plugin removed (control experiment 2026-08-07) | ~3 GB | handover `20260807_1930_memory_mode_balanced_plan.md` |
| Scan CLI, full recommended tier, out-of-process | ~46 MB, transient | 2026-06-28 incident file |

Root cause is structural: any in-process rule touching resolved types (308 call
sites across 68 rule files) forces the analyzer's lazy cross-library type
resolution, and the analyzer retains that resolved model for the whole project.
The analyzer resolves types BEFORE dispatching to plugin callbacks, so no
callback-side gating (tier caps, balanced mode, RSS valve) can release it.
Balanced mode was measured to be CPU-only — it does not reduce RSS.

## The decisive new measurement (2026-08-14, this plan's origin)

Single-file scan of `D:\src\contacts\lib\main.dart`, recommended tier
(1,036 rules loaded, type resolution included, 8 real findings):

- Cold (first run, includes compile + context build): **14 s**
- Warm (every subsequent run): **5 s**

Command: `dart run saropa_lints scan D:/src/contacts --tier recommended
--files D:/src/contacts/lib/main.dart --format json` (exit 1 = issues found).

5 s save-to-findings out-of-process beats an in-process pipeline that has
never reliably surfaced a squiggle and costs 8 GB resident.

---

## Design

### Lane 1 — extension: save-triggered scan → Problems panel

1. `onDidSaveTextDocument` (Dart files in a saropa_lints-enabled workspace)
   → enqueue the saved file.
2. A single serialized scan queue runs
   `dart run saropa_lints scan <root> --tier <configured> --files <f...> --format json`
   from the workspace root. **Never two scans concurrently from the same cwd**
   — dart's build-snapshot/pub lock makes concurrent scans hang each other
   (fenced in the performance-campaign skill; root cause of the dashboards-hub
   hang). Coalesce saves that arrive while a scan is running into the next
   batch (`--files a.dart b.dart ...`).
3. Parse the JSON `diagnostics` array into a `vscode.DiagnosticCollection`
   (source: `saropa_lints`). Replace that file's entries wholesale on each
   scan; this yields squiggles in the edited file AND Problems-panel rows.
4. Debounce: 1–2 s after last save before launching, so save-all does one scan.
5. Status bar item while scanning ("Saropa: scanning 2 files…") and on
   completion ("Saropa: 8 issues, 5 s"). All strings via `l10n()` /
   `en.json` (i18n rules apply from the first commit).

### Lane 2 — in-process plugin becomes opt-in (default OFF)

**Status: Done (2026-08-15), parts A and B both landed.**

- Part A (prior session): `saropaLints.scanOnSave.enabled` removed; the
  master `saropaLints.enabled` toggle alone gates scan-on-save.
- Part B (this session): `generatePluginsYaml`/`replacePluginsSection`
  (`lib/src/init/config_writer.dart`) now wrap a brand-new project's
  `plugins:` block in the extension's own disable sentinels
  (`pluginsDisabledBeginMarker`/`pluginsDisabledEndMarker`, matching
  `DISABLE_BEGIN_MARKER`/`DISABLE_END_MARKER` in `extension/src/setup.ts`)
  so it is written commented out from the start — both `init_runner.dart`
  (`dart run saropa_lints:init`) and `write_config_runner.dart` (the
  extension's headless writer) apply this. An existing project's live/off
  state is preserved through regeneration (tier change, `--reset`, Enable)
  either way — nothing is force-flipped for a project already using it.
  The extension's `runEnable` no longer calls `restorePluginsIntegration()`
  as a side effect of enabling scan-on-save, decoupling the two. Memory
  cost is documented directly inside the generated `plugins:` block
  (`# MEMORY:` comment lines) next to the sentinel, not just here.
- The 14.5.9 OFF-sentinel kill switch (`kIntegrationOffSentinel` in
  `lib/src/native/config_loader.dart`) guarantees a stale compiled plugin
  that loads anyway runs 0 rules — the belt to this plan's braces.
- Users who explicitly want in-process squiggles back can uncomment the
  block in `analysis_options.yaml` themselves. No dedicated extension
  command for this yet — out of scope for this increment.

### Lane 3 — whole-project baseline scan (background, killable)

**Status: Done (2026-08-15), on-demand only.**

- **Measured**: `dart run saropa_lints scan D:/src/contacts --tier
  recommended --format json` (4,478 files) ran at a steady **~3 files/s**,
  projecting a **~25 minute** full pass — squarely "tens of minutes." Per
  this section's own original criterion, the baseline scan is on-demand
  only, **never on-activation**.
- Implemented as the `saropaLints.scanOnSave.runBaselineScan` command
  (Command Palette: "Saropa Lints: Scan Whole Project for Issues"), not
  wired to `activate()`.
- **Killable**: runs inside a cancelable `vscode.window.withProgress`
  notification; `ScanOnSaveController.runBaselineScanCommand()` checks
  `token.isCancellationRequested` between chunks only, matching "a kill
  loses at most one chunk."
- **Chunked**: `chunkFiles`/`runBaselineScan`
  (`extension/src/scanOnSave/baselineScanRunner.ts`) split the project's
  file list into 200-file batches (`BASELINE_SCAN_CHUNK_SIZE`) and stream
  each chunk's diagnostics into the shared `scanOnSaveDiagCollection` as
  soon as it resolves, via the SAME `ScanDaemonManager`/`ScanDaemonClient`
  Lane 1 uses (one warm `AnalysisContextCollection` serves save-triggered
  AND baseline requests).
- File discovery: a new daemon protocol command
  (`{"id","cmd":"listFiles"}` → `{"id","ok":true,"files":[...]}` in
  `bin/scan_daemon.dart`) wraps a new public `ScanRunner.discoverDartFiles`
  (`lib/src/scan/scan_runner.dart`) so the extension gets the same
  exclusion-aware file list the scan CLI itself would use, without
  duplicating exclusion globs on the TS side.
- Verified: `extension/src/test/scanOnSave/baselineScanRunner.test.ts`
  (chunking + orchestration, 8 tests) and
  `extension/src/test/scanOnSave/scanDaemonClient.test.ts`
  (`daemonResponseToFileList`, 4 new tests) — full `scanOnSave/**` suite
  **39/39 passing**, `tsc -p tsconfig.test.json` clean. Dart-side
  `ScanRunner.discoverDartFiles` has new tests in
  `test/scan/scan_runner_test.dart` (`ScanRunner.discoverDartFiles` group);
  **could not run `dart test` this session** — an unrelated, pre-existing
  compile break in `lib/src/rules/architecture/lifecycle_rules.dart`
  (`_BackgroundWorkVisitor` undefined, from another session's in-progress
  uncommitted edit) currently blocks the whole package from compiling.
  `dart analyze lib/src/scan/scan_runner.dart bin/scan_daemon.dart` reports
  no issues.

## What this makes obsolete (do not build further)

- Balanced memory mode as a RAM measure (already disproven; keep for CPU).
- RuntimeTierCap tuning, RSS-valve Windows fallback, cache LRU work — all
  exist to make in-process survivable; scan-only makes them legacy for the
  default path. Leave the code; stop investing.
- The compiled-plugin-cache verification blocker disappears for the default
  path: the scanner is an ordinary CLI, testable locally before publish.

## Known limitations (accepted)

- No keystroke-live squiggles by default; feedback arrives ~5 s after save.
  Accepted: the live path never worked for the maintainer and cost 8 GB.
- Cross-file effects (editing A invalidates findings in B) only refresh when
  B is next saved/scanned. Err toward stale-but-cheap; the baseline scan
  (Lane 3) is the corrective sweep.
- Warm 5 s includes `dart run` startup each time. If p95 drifts, the
  fallback is a warm persistent scanner process with its own memory budget —
  prior art: `plans/PLAN_vibrancy_usage_collector_element_resolution.md`
  Phases 3–5 (killable chunked subprocess, NDJSON streaming). Do NOT start
  there; ship the simple spawn-per-save first and measure.

## Acceptance criteria (fill with measurements, same instrumentation before/after)

1. Analysis-server RSS on contacts over a ≥2 h editing session: within the
   plugin-off baseline (≤ ~3.5 GB), zero OOM. Measured with
   `scripts/watch_dart_memory.py` (per-PID attribution).
2. Save-to-Problems-panel latency, single file, contacts, recommended tier:
   p95 ≤ 8 s warm.
3. Scan process peak RSS ≤ 500 MB; process exits (no orphans) after each run
   and on window close.
4. Zero concurrent-scan hangs: saving 5 files rapidly produces coalesced
   batches, never parallel scans.
5. Findings parity: the same file scanned by CLI and (legacy) in-process
   plugin reports the same rule hits, or differences are itemized.

## Build order

1. Lane 1 (save → scan → DiagnosticCollection) — the user-visible win.
2. Lane 2 default-off flip + setting documentation.
3. Lane 3 baseline scan, after measuring full-project duration.

## References

- `lib/src/scan/scan_runner.dart` — scan CLI (shares `_wrapCallback` hot path).
- `extension/src/pluginLiveness.ts`, `extension/src/violationsReader.ts` —
  existing diagnostics plumbing to reuse/replace.
- `extension/src/setup.ts` — enable/disable sentinel machinery.
- `.claude/skills/saropa-lints-performance-campaign/` — Option 4 lineage,
  fenced wrong paths (concurrent scans, analyzer bumps, leak hunting).
- Handovers: `docs/handover/_archive/20260807_*.md` (memory investigation
  arc), `docs/handover/20260808_1430_analysis_optimizer.md` (balanced mode
  is CPU-only), `docs/handover/20260814_2220_off_sentinel_kill_switch.md`
  (OFF sentinel).

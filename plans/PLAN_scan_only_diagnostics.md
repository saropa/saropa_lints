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

- The extension's existing disable path (`disablePluginsIntegration`,
  sentinel comment markers in `analysis_options.yaml`) becomes the default
  state for new setups; `init` stops emitting a live `plugins:` block.
- The 14.5.9 OFF-sentinel kill switch (`kIntegrationOffSentinel` in
  `lib/src/native/config_loader.dart`) guarantees a stale compiled plugin
  that loads anyway runs 0 rules — the belt to this plan's braces.
- Users who explicitly want in-process squiggles can re-enable via the
  existing toggle; document the memory cost next to the setting.

### Lane 3 — whole-project baseline scan (background, killable)

On activation (or on demand via command), run one full-project scan to
populate the Problems panel for files not yet saved this session.

- Must be **killable and killed** on deactivate/window close — orphan dart
  daemons are a known past bug (handover `20260807_1200_orphan_daemon_bug`).
- Chunk `--files` batches (e.g. 200 files) so partial results stream in and
  a kill loses at most one chunk.
- Duration on contacts is UNMEASURED — first task of this lane is measuring
  it; if a full pass is tens of minutes, make it on-demand only, not
  on-activation.

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

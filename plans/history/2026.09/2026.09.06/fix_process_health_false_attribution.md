# Process Health: fix false attribution and per-process breakdown

The Process Health status bar aggregated ALL Dart process RSS system-wide and compared it against the 4GB/6GB thresholds, coloring the saropa_lints status bar red for memory owned by unrelated processes (analysis servers, Flutter daemons). A 12.5GB analysis server from a second VS Code window made the saropa_lints indicator go red with "Memory usage is critical" — falsely attributing blame. The tooltip showed only an aggregate count with no per-process breakdown, making it non-actionable.

## Changes

### Core fix — saropa-owned thresholds (`processMonitor.ts`)

`assessHealth()` now compares `saropaRssBytes` (scan daemon, CLI scans) against the configured thresholds instead of `totalRssBytes`. The system-wide Dart total is still shown in the tooltip as informational but never drives the red/yellow color. `systemHealthStatusBarText()` and the critical notification also show saropa-owned RSS.

### Per-process tooltip breakdown (`extension.ts`)

The tooltip is restructured into three sections:
- **Saropa Lints** — owned process count and RSS with top 3 listed by RSS. Shows ✓ when healthy.
- **Flutter daemons** — count and orphan status (unchanged from prior behavior).
- **Other Dart processes** — informational only. Top 3 listed by RSS. Hints when 2+ analysis servers detected ("close unused VS Code windows").

The tooltip building logic was extracted from `updateMemoryStatusBar` (108 lines) into a dedicated `buildProcessTooltipLines` helper to stay within the 50-line function limit.

### Process labeling (`processQuery.ts`)

New `processLabel()` parses command lines into human-readable labels: "scan daemon", "analysis server", "analysis server (no heap cap)", "Flutter daemon", "frontend compiler", "build runner". New `isAnalysisServerProcess()` predicate centralizes analysis server detection (used by both `processLabel` and the tooltip hint).

### Snapshot changes (`types.ts`, `processQuery.ts`)

`DartProcessSnapshot` carries a `processes: DartProcessInfo[]` field so the tooltip can render per-process detail without re-querying.

### Test (`statusBarSeverity.test.ts`)

New regression test pins the false-attribution fix: 12GB `totalRssBytes` with 29MB `saropaRssBytes` must remain Healthy. Existing memory-trigger tests updated to set `saropaRssBytes` (the field thresholds now compare).

## Finish Report (2026-09-06)

### Defects found during review

1. **otherCount/otherRss double-counted daemons** — the "Other Dart processes" header derived count and RSS from `processCount - saropaProcessCount`, which included Flutter daemons already shown in their own section. Fixed by deriving both from the filtered `otherProcs` array.
2. **Daemon filter mismatch** — the "other" filter used a bare `\bdaemon\b` regex while the daemon section used `isDaemonProcess` (which also requires `flutter_tools.snapshot`). Non-Flutter daemon processes could fall through both filters. Fixed by using `isDaemonProcess` consistently.
3. **Duplicated analysis server detection** — inline filter in the tooltip duplicated pattern knowledge from `processLabel`. Extracted into shared `isAnalysisServerProcess` predicate.

### Hardening (reflection gate)

1. **Single source of truth for saropa count/RSS** — the tooltip now derives saropa process count and RSS from the filtered `processes` array directly, not from the scalar snapshot fields. Eliminates the risk of `isSaropaProcess` and `buildSnapshot` drifting apart.
2. **Daemon filter coupling documented** — `buildProcessTooltipLines` JSDoc notes the coupling between the "other" exclusion filter and `isDaemonProcess`/`isSaropaProcess`.
3. **Negative otherRss guard** — moot after switching from subtraction to array-reduce.

### RSS trend indicator

`ProcessMonitor` tracks saropa-owned RSS in a 5-sample ring buffer. `computeRssTrend()` (pure function, exported for testing) compares the average of the older half to the newer half with a 10% threshold:
- **↑ Rising** — newer average exceeds older by >10%. Early leak warning.
- **→ Stable** — within ±10%. Normal operation.
- **↓ Falling** — newer average is >10% lower. Cache eviction or process exit.
- No arrow shown when fewer than 5 samples exist (session too young).

The trend arrow is appended to the saropa tooltip header line. Six tests pin the trend computation (unknown, stable, rising, falling, within-threshold, zero-division guard).

### Not addressed (out of scope)

- Stretch goals from the proposal (RSS sparkline chart, kill-orphans action) — deferred to separate proposals.
- Dead translated locale keys (`processCount`, `saropaProcessCount`) — harmless; cleaned at next translation regen.
- `processLabel` returns English strings — these are technical identifiers consistent across locales.
- Test fixture `processCount:1` with `processes:[]` — scalar disagrees with array but no current test subject iterates the array.

### Verification status

TypeScript compiles clean. All 45 systemHealth tests pass. **Unverified** in the Extension Development Host — tooltip rendering in both themes needs F5 confirmation.

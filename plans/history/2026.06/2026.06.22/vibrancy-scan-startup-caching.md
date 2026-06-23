# Package Vibrancy — startup scan re-ran every hour despite an unchanged project

The extension's Package Vibrancy scan re-ran in full — a 10-minute, network-bound, foreground operation with a blocking progress notification — on every VS Code restart that occurred more than 60 minutes after the previous scan, even when `pubspec.lock` and all scan settings were byte-identical. The startup skip-gate gated reuse on an arbitrary time window rather than on the change signal that actually determines whether results can differ, so unchanged projects paid the full scan cost repeatedly.

## Finish Report (2026-06-22)

### Defect

The startup skip-gate decided whether to reuse cached scan results via `isFingerprintFresh`, which required all three of: matching `pubspec.lock` hash, matching scan-config hash, AND a scan timestamp within `startupScanSkipTtlMinutes` (default 60). The lock+config hash is the exact correctness signal — when both match, the dependency set is unchanged and a re-scan cannot produce a different result. The added time ceiling forced a foreground re-scan once per hour regardless, producing the recurring 10-minute blocking popup on large projects.

The per-package API cache (`CacheService`, `globalState`, 24h TTL) was already persistent across restarts and was not the defect; the defect was the gate forcing the scan to run at all.

### Change

Correctness and freshness were decoupled:

1. **Instant rehydrate (correctness).** `isFingerprintFresh` was replaced by `isFingerprintValid(fp, lockHash, configHash)` in `extension/src/vibrancy/services/startup-gate.ts`, which checks lock+config only, with no time component. When valid, the startup gate rehydrates and republishes cached results instantly with no progress notification, regardless of fingerprint age. `getStartupScanSkipTtlMinutes` is retained only as an enable/disable switch: `0` restores the legacy always-foreground-scan behaviour.

2. **Silent background refresh (freshness).** A new `fingerprintAgeMs(fp)` helper (clamped at 0 for clock skew) and config getter `getBackgroundRefreshStalenessHours` (default 24, `0` disables) drive `maybeScheduleBackgroundRefresh` in `extension-activation.ts`. After an instant rehydrate, if the cached data exceeds the staleness window, a fire-and-forget refresh runs with no progress UI.

3. **Silent scan path.** `runScan` / `runScanInner` gained a `silent` option. `runScanInner` now defines the scan body as an inner `executeScan(progress)` function invoked either under `vscode.window.withProgress` (foreground) or with a no-op `SILENT_PROGRESS` sink (background). A silent refresh coalesced against an in-flight scan is dropped rather than escalated into a foreground toast.

4. **Faster cold scans.** The hard-coded scan concurrency of 3 was replaced by `getScanConcurrency` (default 6, clamped to [1, 16]) in `scan-helpers.ts`, roughly halving genuine cold-scan wall time. Documented to raise above default only with a GitHub token configured, to avoid unauthenticated rate limits.

### Surfaces

- `extension/src/vibrancy/services/startup-gate.ts` — `isFingerprintValid`, `fingerprintAgeMs` replace `isFingerprintFresh`.
- `extension/src/vibrancy/services/config-service.ts` — `getBackgroundRefreshStalenessHours`, `getScanConcurrency`; reworded `getStartupScanSkipTtlMinutes` doc.
- `extension/src/vibrancy/extension-activation.ts` — gate rewiring, `maybeScheduleBackgroundRefresh`, `silent` threaded through `runScan` / `runScanInner`, `executeScan` extraction.
- `extension/src/vibrancy/scan-helpers.ts` — configurable concurrency.
- `extension/package.json`, `extension/package.nls.json` — two new settings + reworded descriptions.
- `CHANGELOG.md` — `[14.1.0]` overview clause + two `Changed (Extension)` bullets.

### Verification

- `tsc --noEmit -p ./` (extension `lint` script): clean.
- `tsc -p tsconfig.test.json`: clean.
- Mocha, `scan-helpers.test.js` + `startup-gate.test.js`: 24 passing. The `isFingerprintFresh` test block was rewritten to `isFingerprintValid` (validity is age-independent) and `fingerprintAgeMs` (elapsed + clock-skew clamp). The abort test's dep count was raised above the new default concurrency so it still distinguishes early-stop from natural completion.

### Not done here

Translated manifest catalogs (`package.nls.<lang>.json`) are stale for the three new config-description keys; regeneration runs the NLLB translation pipeline and was deliberately not executed.

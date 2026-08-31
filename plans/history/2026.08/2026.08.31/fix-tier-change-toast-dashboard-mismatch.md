# Fix: Tier-change toast count mismatch with Findings Dashboard

The tier-change notification (toast) read its violation count from the on-disk `violations.json` file via `readViolations()`, while the Findings Dashboard read from live VS Code diagnostics via `buildViolationsDataFromDiagnostics()`. After a tier change triggers analysis server restart, `getDiagnostics()` returns empty (mid-analysis) while `violations.json` retains stale counts from the previous run. This produced a "toast says 171, dashboard shows 0" mismatch that made both features appear broken.

## Finish Report (2026-08-31)

### Root Cause

`saropaLints.setTier` (extension.ts) called `readViolations(root)` — a synchronous read of `reports/.saropa_lints/violations.json` — to compute pre-tier and post-tier violation counts for the toast. The Findings Dashboard (`violationsWideReportView.ts`) independently reads `vscode.languages.getDiagnostics()`. After a tier change, the analysis server restarts; `getDiagnostics()` returns empty until re-analysis completes, while the disk file retains the previous run's data.

### Fix

1. **Deferred toast:** `setTier` no longer reads `violations.json` or shows the toast synchronously. It stores tier-change metadata (`tierLabel`, `previousTier`, `isUpgrade`, `preTierTotal`) in a module-level `pendingTierChangeInfo` variable.

2. **Resolved in `debouncedRefresh`:** When the violations file watcher fires (analysis complete → `violations.json` written), `debouncedRefresh` checks for a pending tier change. If present, it computes counts from `readVisibleViolations()` (live diagnostics, same source as the dashboard), applies auto-filter logic, and fires the toast. Both surfaces now read identical data at the same moment.

3. **Safety fallback:** A 15-second `setTimeout` fires if `debouncedRefresh` never triggers (plugin not loaded, `violations.json` never written). Shows a zero-count "Tier changed to X" confirmation so the user knows the tier change took effect.

4. **Pre-tier baseline:** Changed from `readViolations()` (disk) to `readVisibleViolations()` (live diagnostics) so the delta computation uses the same source as the post-tier count.

5. **Re-analyzing indicator:** The `setTier` handler posts `analysisProgress: started` to the Findings Dashboard, showing a "Re-analyzing..." progress state during the analysis gap. Cleared with `analysisProgress: completed` when `debouncedRefresh` resolves or the 15s fallback fires.

6. **Hardening:** The fallback timer handle (`tierChangeFallbackTimer`) is tracked, cancelled on rapid re-entry (second `setTier` before first resolves), cancelled when `debouncedRefresh` resolves the pending info, and cleaned up on extension dispose.

### Files Changed

- `extension/src/extension.ts` — added `pendingTierChangeInfo` + `tierChangeFallbackTimer` state; rewrote `setTier` handler to defer; added tier-change resolution in `debouncedRefresh`; added 15s fallback timer; dispose cleanup; `analysisProgress` signals.
- `extension/src/views/violationsWideReportView.ts` — added `postDashboardAnalysisProgress()` export.
- `CHANGELOG.md` — added fix entry under 15.2.6.

### Risk

The toast now arrives ~300ms+ later (after `debouncedRefresh` debounce). This delay matches the existing regression-nudge pattern and is imperceptible to users. The 15s fallback is conservative; if the analysis server is healthy, `debouncedRefresh` fires within 1-3 seconds of the tier change.

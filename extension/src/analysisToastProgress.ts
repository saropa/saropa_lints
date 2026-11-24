/**
 * Progress-aware gating for the "N issues found" analysis toast.
 *
 * Problem this solves: `runAnalysis` reads live diagnostics, which are only a
 * partial snapshot while the server's workspace scan is still running. Every
 * auto-trigger during a build (pubspec.lock writes, config changes) therefore
 * stacked a fresh warning toast carrying an incomplete count ("12 issues",
 * then "20 issues", ...). A count without a denominator is misleading, so
 * while the scan is in flight the count is shown only inside ONE updating
 * progress notification with a percentage, and the final toast fires once the
 * scan completes.
 */

import * as vscode from 'vscode';
import { l10n } from './i18n/runtime';
import { isScanInFlight, scanPercent, type ScanProgressSnapshot } from './scanProgressMath';

export type { ScanProgressSnapshot };

/** How often the progress notification re-reads scan state. */
const POLL_INTERVAL_MS = 1000;

/** Upper bound so a scan that never reports `done` cannot pin the notification forever. */
const MAX_WAIT_MS = 10 * 60 * 1000;

// Set by extension.ts once the LSP client exists. A provider (not a direct
// import) keeps setup.ts free of a dependency on the client wrapper.
let progressProvider: (() => ScanProgressSnapshot | undefined) | undefined;

// Single-flight guard: a second trigger while a progress notification is
// already showing must not stack another one.
let trackerActive = false;

/** Register the live scan-progress source (the LSP client's latest tick). */
export function setScanProgressProvider(
  provider: (() => ScanProgressSnapshot | undefined) | undefined,
): void {
  progressProvider = provider;
}

/**
 * If a scan is in flight, show a single progress notification (percentage plus
 * the running count) and run `onSettled` when the scan finishes.
 *
 * @returns true when the caller must NOT show its own toast now — either this
 * call started the tracker, or one is already active and will notify at the
 * end. false when no scan is running and the caller should toast immediately.
 */
export function deferToastWhileScanning(
  getCount: () => number,
  onSettled: () => void,
): boolean {
  if (trackerActive) return true;
  const first = progressProvider?.();
  if (!isScanInFlight(first)) return false;

  trackerActive = true;
  void vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Saropa Lints',
      cancellable: false,
    },
    async (progress) => {
      const started = Date.now();
      let lastPercent = 0;
      // Poll until the server says done (or the safety cap trips).
      while (Date.now() - started < MAX_WAIT_MS) {
        const snap = progressProvider?.();
        if (!isScanInFlight(snap)) break;
        const percent = scanPercent(snap as ScanProgressSnapshot);
        // `increment` is a delta; report only forward movement.
        progress.report({
          increment: Math.max(0, percent - lastPercent),
          message: l10n('notify.setup.analysisScanning', {
            percent: String(percent),
            count: getCount().toLocaleString(),
          }),
        });
        lastPercent = percent;
        await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
      }
    },
  ).then(
    () => {
      trackerActive = false;
      onSettled();
    },
    () => {
      // Progress UI failure must not swallow the result; release the guard
      // and still surface the final toast.
      trackerActive = false;
      onSettled();
    },
  );
  return true;
}

/** How long to wait for a freshly restarted server to START reporting a scan. */
const SCAN_START_GRACE_MS = 20 * 1000;

/**
 * Resolve once the analysis server has finished the workspace scan that follows
 * a restart. Used by "Run analysis": after `dart.restartAnalysisServer` the
 * progress snapshot still holds the PREVIOUS run's `done` state, so "not in
 * flight" alone would return immediately and the caller would read an empty
 * Problems panel. Phase 1 therefore waits (bounded) for a scan to start;
 * phase 2 waits for it to finish. If no scan ever reports (older server, no
 * provider) the grace timeout releases the caller instead of hanging.
 *
 * @param isCancelled polled each tick so the user's Cancel stops the wait.
 */
export async function waitForScanToSettle(
  isCancelled: () => boolean,
  onTick?: (snap: ScanProgressSnapshot) => void,
): Promise<void> {
  const started = Date.now();
  let sawScan = false;
  while (Date.now() - started < MAX_WAIT_MS && !isCancelled()) {
    const snap = progressProvider?.();
    if (isScanInFlight(snap)) {
      sawScan = true;
      onTick?.(snap as ScanProgressSnapshot);
    } else if (sawScan) {
      return; // scan started and has now completed
    } else if (Date.now() - started > SCAN_START_GRACE_MS) {
      return; // no scan ever reported — do not hang
    }
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }
}

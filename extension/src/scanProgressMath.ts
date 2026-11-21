/**
 * Pure helpers for interpreting the LSP `saropa/scanProgress` tick.
 *
 * Kept free of any `vscode` import so mocha can load it without a host; the
 * notification wiring lives in analysisToastProgress.ts.
 */

/** Minimal shape of the LSP `saropa/scanProgress` payload this logic needs. */
export interface ScanProgressSnapshot {
  readonly filesScanned: number;
  readonly totalFiles: number;
  readonly done?: boolean;
}

/** True while the server reports an unfinished workspace scan. */
export function isScanInFlight(snapshot: ScanProgressSnapshot | undefined): boolean {
  if (!snapshot) return false;
  // Explicit `done` wins (a canceled scan has filesScanned < totalFiles but is
  // over); older servers fall back to the ratio. Mirrors the engine-card logic
  // so the toast and the Engines row never disagree.
  if (snapshot.done === true) return false;
  return snapshot.filesScanned < snapshot.totalFiles;
}

/** Whole-number percent clamped to 0..99 while running (100 is reserved for done). */
export function scanPercent(snapshot: ScanProgressSnapshot): number {
  if (snapshot.totalFiles <= 0) return 0;
  const raw = Math.floor((snapshot.filesScanned / snapshot.totalFiles) * 100);
  return Math.max(0, Math.min(99, raw));
}

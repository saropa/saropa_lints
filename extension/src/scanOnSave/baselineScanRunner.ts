/**
 * Lane 3 (plans/PLAN_scan_only_diagnostics.md): an on-demand, whole-project
 * baseline scan so files that were never saved this session still show up
 * in the Problems panel — Lane 1 only scans a file on save, so a project
 * opened cold shows zero diagnostics until every file has been touched.
 *
 * NOT run on activation. A measured full pass on `contacts` (4,478 files,
 * recommended tier) ran at a steady ~3 files/s — about 25 minutes end to
 * end. The plan's own threshold ("if a full pass is tens of minutes, make
 * it on-demand only, never on-activation") is met, so this is exposed only
 * as a command the user invokes deliberately.
 *
 * Chunked (200 files/batch) so partial results stream into the diagnostic
 * collection as each chunk completes, and a cancellation loses at most the
 * in-flight chunk rather than the whole pass. Reuses the same
 * `ScanDaemonManager` as Lane 1 — the daemon resolves the project's
 * AnalysisContextCollection once and serves both save-triggered and
 * baseline requests against the same warm state.
 */
import type { ScanDaemonManager } from './scanDaemonManager';
import type { ScanOnSaveDiagnostic } from './scanOnSaveRunner';

/** Batch size for chunked daemon requests — matches the plan's stated figure. */
export const BASELINE_SCAN_CHUNK_SIZE = 200;

/** Splits [files] into fixed-size batches, preserving order. Last batch may be smaller. */
export function chunkFiles(
  files: readonly string[],
  chunkSize: number = BASELINE_SCAN_CHUNK_SIZE,
): string[][] {
  if (chunkSize <= 0) throw new RangeError('chunkSize must be positive');
  const chunks: string[][] = [];
  for (let i = 0; i < files.length; i += chunkSize) {
    chunks.push(files.slice(i, i + chunkSize));
  }
  return chunks;
}

/** Progress reported after each chunk completes (or the pass fails/is canceled). */
export interface BaselineScanProgress {
  filesScanned: number;
  totalFiles: number;
  issuesFound: number;
}

export interface BaselineScanResult {
  /** True when every chunk completed without error and without cancellation. */
  completed: boolean;
  /** True when the caller canceled via [isCanceled] mid-pass. */
  canceled: boolean;
  /** Set when a chunk request failed (daemon down/timeout) — the pass stops at that chunk. */
  errorMessage?: string;
  filesScanned: number;
  totalFiles: number;
  diagnostics: ScanOnSaveDiagnostic[];
}

/**
 * Runs the chunked baseline scan: lists the project's files via the daemon,
 * then scans them in {@link BASELINE_SCAN_CHUNK_SIZE}-file batches,
 * reporting progress and streaming each chunk's diagnostics to [onChunk] as
 * soon as it resolves (so a caller can apply them to a
 * `vscode.DiagnosticCollection` incrementally rather than waiting for the
 * whole pass). Checked for cancellation between chunks only — matches the
 * plan's "a kill loses at most one chunk" contract.
 */
export async function runBaselineScan(
  daemonManager: Pick<ScanDaemonManager, 'scan' | 'listFiles'>,
  root: string,
  tier: string,
  options: {
    isCanceled: () => boolean;
    onProgress?: (progress: BaselineScanProgress) => void;
    /** [chunkFiles] is the exact batch just scanned — lets the caller clear diagnostics for files that scanned clean, not just set ones that found issues. */
    onChunk?: (chunkFiles: readonly string[], diagnostics: readonly ScanOnSaveDiagnostic[]) => void;
    /** Overrides {@link BASELINE_SCAN_CHUNK_SIZE} — test-only knob. */
    chunkSize?: number;
  },
): Promise<BaselineScanResult> {
  const files = await daemonManager.listFiles(root, tier);
  if (files === null) {
    return {
      completed: false,
      canceled: false,
      errorMessage: 'notify.commands.scanOnSaveDaemonDown',
      filesScanned: 0,
      totalFiles: 0,
      diagnostics: [],
    };
  }

  const totalFiles = files.length;
  const chunks = chunkFiles(files, options.chunkSize);
  const diagnostics: ScanOnSaveDiagnostic[] = [];
  let filesScanned = 0;

  for (const chunk of chunks) {
    if (options.isCanceled()) {
      return { completed: false, canceled: true, filesScanned, totalFiles, diagnostics };
    }
    const result = await daemonManager.scan(root, chunk, tier);
    if (result.errorMessage && !result.payload) {
      return {
        completed: false,
        canceled: false,
        errorMessage: result.errorMessage,
        filesScanned,
        totalFiles,
        diagnostics,
      };
    }
    const chunkDiagnostics = result.payload?.diagnostics ?? [];
    diagnostics.push(...chunkDiagnostics);
    filesScanned += chunk.length;
    options.onChunk?.(chunk, chunkDiagnostics);
    options.onProgress?.({ filesScanned, totalFiles, issuesFound: diagnostics.length });
  }

  return { completed: true, canceled: false, filesScanned, totalFiles, diagnostics };
}

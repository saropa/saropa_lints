/**
 * Applies scanned rename changes: every file is snapshotted, written
 * atomically, then config is re-initialized; any throw restores every
 * snapshot (same contract as compat/applyCompat.ts). I/O is injected.
 */
import type { FileChange, SkipReason } from './scanner';
import type { Finding } from './types';

export interface MigrationDeps {
  /** Atomic write (compat/atomicWrite.ts in production). */
  write(file: string, text: string): void;
  initializeConfig(): Promise<void>;
}

export interface MigrationReport {
  status: 'noChange' | 'applied' | 'failed';
  filesChanged: string[];
  hits: number;
  findings: (Finding & { file: string })[];
  skipped: { file: string; reason: SkipReason }[];
  /** Set when status is failed. */
  reason?: string;
  /** Failed only: false when any restore write itself threw. */
  restored?: boolean;
}

export async function applyRuleMigration(
  deps: MigrationDeps,
  changes: readonly FileChange[],
  skipped: { file: string; reason: SkipReason }[] = [],
): Promise<MigrationReport> {
  const findings = changes.flatMap((c) => c.findings.map((f) => ({ ...f, file: c.file })));
  const edits = changes.filter((c) => c.after !== c.before);
  const hits = changes.reduce((n, c) => n + c.hits, 0);
  if (edits.length === 0) return { status: 'noChange', filesChanged: [], hits, findings, skipped };

  const written: FileChange[] = [];
  try {
    for (const e of edits) {
      written.push(e); // pushed first: a write that throws midway may leave a partial file
      deps.write(e.file, e.after);
    }
    await deps.initializeConfig();
    return { status: 'applied', filesChanged: edits.map((e) => e.file), hits, findings, skipped };
  } catch (err) {
    let restored = true;
    for (const e of written) {
      try {
        deps.write(e.file, e.before);
      } catch {
        restored = false;
      }
    }
    return {
      status: 'failed',
      filesChanged: [],
      hits: 0,
      findings,
      skipped,
      reason: err instanceof Error ? err.message : String(err),
      restored,
    };
  }
}

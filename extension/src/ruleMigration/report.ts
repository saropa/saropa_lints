/** Pure helpers that turn scan/apply results into the numbers and names the UI shows. */
import * as path from 'node:path';
import type { MigrationReport } from './applyMigration';
import type { FileChange, ScanResult } from './scanner';

export interface ScanSummary {
  /** Files whose text would change. */
  files: { file: string; hits: number }[];
  hits: number;
}

/** Files that would be edited (findings-only files are excluded) and the total change count. */
export function summarizeScan(scan: Pick<ScanResult, 'changes'>): ScanSummary {
  const files = scan.changes.filter((c) => c.after !== c.before).map((c) => ({ file: c.file, hits: c.hits }));
  return { files, hits: files.reduce((n, f) => n + f.hits, 0) };
}

/** Narrows the scan to the picked files (all changes when `picked` is undefined). */
export function selectChanges(changes: readonly FileChange[], picked?: ReadonlySet<string>): FileChange[] {
  return picked ? changes.filter((c) => picked.has(c.file)) : [...changes];
}

export interface ReportParts {
  changedFiles: string[];
  /** Distinct "name (file:line)" strings per finding kind. */
  bareNames: string[];
  clashes: string[];
  skipped: string[];
}

export function reportParts(r: MigrationReport, rel: (f: string) => string = path.basename): ReportParts {
  const fmt = (f: { name: string; file: string; line: number }): string => `${f.name} (${rel(f.file)}:${f.line})`;
  return {
    changedFiles: r.filesChanged.map(rel),
    bareNames: r.findings.filter((f) => f.kind === 'bareName').map(fmt),
    clashes: r.findings.filter((f) => f.kind === 'clash').map(fmt),
    skipped: r.skipped.map((s) => `${rel(s.file)} (${s.reason})`),
  };
}

/** First `max` items joined, with a "+N more" tail. */
export function listSome(items: readonly string[], max = 5): string {
  const head = items.slice(0, max).join(', ');
  return items.length > max ? `${head}, +${items.length - max}` : head;
}

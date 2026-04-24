/**
 * Extension report writer — persists an audit trail of extension actions
 * to reports/YYYYMMDD/YYYYMMDD_HHMMSS_saropa_extension.md.
 *
 * Mirrors the Dart init log writer pattern: accumulate lines, flush to file.
 * Report files are written to date-stamped folders under reports/ for external inspection.
 */

import * as fs from 'fs';
import * as path from 'path';

/** Module-level buffer — lines accumulate across logReport() calls until flushed. */
const reportLines: string[] = [];
/** Captured on first logReport() call; ensures filename + date folder stay consistent through the session. */
let sessionTimestamp: string | undefined;

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function makeTimestamp(): string {
  const d = new Date();
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}

/** Extract YYYYMMDD date portion from a YYYYMMDD_HHMMSS timestamp. */
function dateFolderFromTimestamp(ts: string): string {
  return ts.slice(0, 8);
}

/**
 * Append a line to the current report buffer.
 * Lazily captures the session timestamp on first call so the report
 * filename reflects when logging started, not when it was flushed.
 */
export function logReport(line: string): void {
  if (!sessionTimestamp) sessionTimestamp = makeTimestamp();
  reportLines.push(line);
}

/** Append a markdown section heading. */
export function logSection(title: string): void {
  logReport('');
  logReport(`## ${title}`);
}

/** Reset the report buffer. */
export function clearReport(): void {
  reportLines.length = 0;
  sessionTimestamp = undefined;
}

/**
 * Optional identifying metadata attached to the extension report header so
 * each file is self-describing: you can tell which extension build wrote
 * it and which saropa_lints plugin version was resolved in `pubspec.lock`
 * at the time. Missing values are skipped rather than printed as
 * `unknown`, so a run with no resolvable lock doesn't ship misleading
 * placeholders.
 *
 * Why this matters: when diagnosing "the rule is still firing thousands
 * of times on my project", the first useful fact is *which* plugin build
 * emitted those diagnostics — and both numbers are cheap to print at
 * flush time. Previously the header had only date + workspace, forcing
 * the user into cache archaeology to answer that question.
 */
export interface FlushReportOptions {
  /** Version of the VS Code extension producing the report (e.g. `12.4.0`). */
  extensionVersion?: string;
  /**
   * Resolved saropa_lints version from the workspace's `pubspec.lock`.
   * May be `undefined` when the lock is missing, unreadable, or does not
   * declare saropa_lints — no value is better than a wrong value.
   */
  saropaLintsVersion?: string;
  /**
   * Where the resolved saropa_lints came from (e.g. `hosted`, `path`,
   * `git`). Useful for users on `dependency_overrides` / path deps who
   * are running a local build that doesn't match the hosted version.
   */
  saropaLintsSource?: string;
}

/**
 * Write the accumulated report to disk and clear the buffer.
 * Returns the file path on success, undefined on failure or empty buffer.
 */
export function flushReport(root: string, options?: FlushReportOptions): string | undefined {
  if (reportLines.length === 0) return undefined;
  const ts = sessionTimestamp ?? makeTimestamp();
  // Derive date folder from the session timestamp to avoid midnight boundary mismatch
  // (session started at 23:59 but flushed at 00:01 would write to a different date folder).
  const folder = path.join(root, 'reports', dateFolderFromTimestamp(ts));
  const header = [
    '# Saropa Lints Extension Report',
    `**Date:** ${new Date().toISOString()}`,
    `**Workspace:** ${root}`,
  ];
  // Append identifying metadata only when present — skipping undefined
  // values keeps the header honest on projects with missing lock files.
  if (options?.extensionVersion) {
    header.push(`**Extension:** v${options.extensionVersion}`);
  }
  if (options?.saropaLintsVersion) {
    const sourceSuffix = options.saropaLintsSource
      ? ` (${options.saropaLintsSource})`
      : '';
    header.push(`**saropa_lints:** ${options.saropaLintsVersion}${sourceSuffix}`);
  }
  const content = [...header, '', ...reportLines, ''].join('\n');
  const filePath = path.join(folder, `${ts}_saropa_extension.md`);
  try {
    // mkdirSync can throw on permission errors or read-only filesystems;
    // recursive:true only suppresses "already exists". Keep both operations
    // in one try block so any disk failure returns undefined gracefully.
    fs.mkdirSync(folder, { recursive: true });
    fs.writeFileSync(filePath, content, 'utf-8');
    clearReport();
    return filePath;
  } catch {
    return undefined;
  }
}

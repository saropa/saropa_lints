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
 * Write the accumulated report to disk and clear the buffer.
 * Returns the file path on success, undefined on failure or empty buffer.
 */
export function flushReport(root: string): string | undefined {
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

/**
 * Extension report writer — persists an audit trail of extension actions
 * to reports/YYYYMMDD/YYYYMMDD_HHMMSS_saropa_extension.md.
 *
 * Mirrors the Dart init log writer pattern: accumulate lines, flush to file.
 * The Logs view automatically discovers .md files in date folders.
 */

import * as fs from 'fs';
import * as path from 'path';

const reportLines: string[] = [];
let sessionTimestamp: string | undefined;

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function makeTimestamp(): string {
  const d = new Date();
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}

function makeDateFolder(): string {
  const d = new Date();
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`;
}

/** Append a line to the current report buffer. */
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
  const folder = path.join(root, 'reports', makeDateFolder());
  try {
    fs.mkdirSync(folder, { recursive: true });
  } catch { /* already exists */ }

  const header = [
    '# Saropa Lints Extension Report',
    `**Date:** ${new Date().toISOString()}`,
    `**Workspace:** ${root}`,
  ];
  const content = [...header, '', ...reportLines, ''].join('\n');
  const filePath = path.join(folder, `${ts}_saropa_extension.md`);
  try {
    fs.writeFileSync(filePath, content, 'utf-8');
    clearReport();
    return filePath;
  } catch {
    return undefined;
  }
}

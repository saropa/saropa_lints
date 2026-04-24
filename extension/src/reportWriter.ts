/**
 * Extension report writer — persists an audit trail of extension actions
 * to reports/YYYYMMDD/YYYYMMDD_HHMMSS_saropa_extension.md.
 *
 * Mirrors the Dart init log writer pattern: accumulate lines, flush to file.
 * Report files are written to date-stamped folders under reports/ for external inspection.
 *
 * Also exposes [findLatestAnalysisReport] — a locator used by the post-run
 * "Copy Report" / "Open Report" actions so users can grab the actual
 * report without hunting through date folders.
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
 * Locate the most recently written `*_saropa_lint_report.log` under
 * `<workspaceRoot>/reports/`. The Dart plugin writes these on every
 * analysis run (one per isolate batch), and their filename encodes a
 * sortable timestamp — but users can also re-run at any time, so we
 * resolve by **file mtime** rather than filename, and we scan **every**
 * date folder rather than just today's (runs near midnight land in the
 * previous date folder, and "today's folder doesn't exist" should not
 * silently fail).
 *
 * Returns the absolute path of the newest file, or `undefined` when:
 *   - `<root>/reports/` is missing
 *   - no date folder contains a `*_saropa_lint_report.log`
 *   - any I/O error occurs mid-walk
 *
 * **Why not `_saropa_extension.md`**: the user's question is always
 * "what did the *plugin* find?" — that report has the concentration /
 * triage / top-rules content. The extension's own `_saropa_extension.md`
 * is a thin audit trail and carries no diagnostic data.
 *
 * **Scan scope**: only two directory levels (`reports/<date>/*.log`). We
 * don't recurse arbitrarily — if a user has customized their layout,
 * we'd rather return `undefined` and let the caller surface a helpful
 * "no report found" message than return the wrong file.
 *
 * Complexity is O(files-in-reports-tree); the typical project has
 * dozens at most, so a linear scan is fine. Caching would be premature
 * — reports change on every run anyway.
 */
export function findLatestAnalysisReport(workspaceRoot: string): string | undefined {
  try {
    const reportsDir = path.join(workspaceRoot, 'reports');
    if (!fs.existsSync(reportsDir) || !fs.statSync(reportsDir).isDirectory()) {
      return undefined;
    }

    let newestPath: string | undefined;
    let newestMtimeMs = -Infinity;

    for (const dateEntry of fs.readdirSync(reportsDir)) {
      const dateFolder = path.join(reportsDir, dateEntry);
      // Skip non-directories and hidden/system entries (`.saropa_lints`).
      let dateStat: fs.Stats;
      try {
        dateStat = fs.statSync(dateFolder);
      } catch {
        continue;
      }
      if (!dateStat.isDirectory() || dateEntry.startsWith('.')) continue;

      for (const fileEntry of fs.readdirSync(dateFolder)) {
        if (!fileEntry.endsWith('_saropa_lint_report.log')) continue;
        const filePath = path.join(dateFolder, fileEntry);
        let fileStat: fs.Stats;
        try {
          fileStat = fs.statSync(filePath);
        } catch {
          continue;
        }
        if (!fileStat.isFile()) continue;
        // Use `mtimeMs` rather than name-sort: two runs in the same second
        // share a timestamp, and a re-written file bumps mtime but not name.
        if (fileStat.mtimeMs > newestMtimeMs) {
          newestMtimeMs = fileStat.mtimeMs;
          newestPath = filePath;
        }
      }
    }

    return newestPath;
  } catch {
    return undefined;
  }
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

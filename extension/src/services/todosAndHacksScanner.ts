/**
 * Scans workspace files for task and fix-style comment markers (tag names from options).
 * Extension-only: uses findFiles + readFile, no Dart analyzer.
 */

import * as vscode from 'vscode';
import type { TaskMarker, ScanOptions, ScanResult } from '../views/todosAndHacksTypes';
import {
  buildRegex,
  getExcludePattern,
  extractMarkersFromLines,
} from './todosAndHacksScannerCore';

const CONCURRENCY = 30;

/** Re-export for tests that import from scanner. */
export { buildRegex, getExcludePattern } from './todosAndHacksScannerCore';

/** Extract markers from file content (adds uri to core result). */
function extractMarkers(
  uri: vscode.Uri,
  content: string,
  regex: RegExp,
  isCustomRegex: boolean,
): TaskMarker[] {
  return extractMarkersFromLines(content, regex, isCustomRegex).map((m) => ({
    uri,
    lineIndex: m.lineIndex,
    tag: m.tag,
    snippet: m.snippet,
    fullLine: m.fullLine,
  }));
}

/** No single combined pattern; we call findFiles per include glob and merge. */

/**
 * Resolve the regex to use: custom if provided and valid, otherwise built-in from tags.
 */
function getRegex(options: ScanOptions): { regex: RegExp; isCustom: boolean } {
  const custom = options.customRegex?.trim();
  if (custom) {
    try {
      return { regex: new RegExp(custom), isCustom: true };
    } catch {
      // Fall back to built-in if custom regex is invalid
      return { regex: buildRegex(options.tags), isCustom: false };
    }
  }
  return { regex: buildRegex(options.tags), isCustom: false };
}

/**
 * Scan one workspace folder for task/fix markers (tags from options).
 * Uses findFiles then reads files with a concurrency limit.
 */
export async function scanWorkspace(
  workspaceFolder: vscode.WorkspaceFolder,
  options: ScanOptions,
): Promise<ScanResult> {
  const { regex, isCustom } = getRegex(options);
  const searchExclude = vscode.workspace.getConfiguration('search').get<Record<string, boolean>>('exclude');
  const excludePattern = getExcludePattern(options.excludeGlobs, searchExclude);
  const exclude = excludePattern ? new vscode.RelativePattern(workspaceFolder, excludePattern) : undefined;

  const { uris: limited, capped } = await collectFileUris(workspaceFolder, options, exclude);
  const markers = await readFilesAndExtractMarkers(limited, regex, isCustom);
  return { markers, capped };
}

/** Collect file URIs from include globs, deduplicated and capped by maxFilesToScan. */
async function collectFileUris(
  workspaceFolder: vscode.WorkspaceFolder,
  options: ScanOptions,
  exclude: vscode.RelativePattern | undefined,
): Promise<{ uris: vscode.Uri[]; capped: boolean }> {
  const maxPerGlob = Math.max(1, Math.floor(options.maxFilesToScan / options.includeGlobs.length));
  const seen = new Set<string>();
  const uris: vscode.Uri[] = [];
  let capped = false;
  for (const includeGlob of options.includeGlobs) {
    const include = new vscode.RelativePattern(workspaceFolder, includeGlob);
    const batch = await vscode.workspace.findFiles(include, exclude, maxPerGlob);
    if (batch.length >= maxPerGlob) capped = true;
    for (const u of batch) {
      const key = u.toString();
      if (!seen.has(key)) {
        seen.add(key);
        uris.push(u);
        if (uris.length >= options.maxFilesToScan) {
          capped = true;
          break;
        }
      }
    }
    if (uris.length >= options.maxFilesToScan) break;
  }
  return { uris: uris.slice(0, options.maxFilesToScan), capped };
}

/** Read files in batches and extract task markers. */
async function readFilesAndExtractMarkers(
  uris: vscode.Uri[],
  regex: RegExp,
  isCustom: boolean,
): Promise<TaskMarker[]> {
  const allMarkers: TaskMarker[] = [];
  for (let i = 0; i < uris.length; i += CONCURRENCY) {
    const batch = uris.slice(i, i + CONCURRENCY);
    const contents = await Promise.all(
      batch.map((uri) =>
        vscode.workspace.fs.readFile(uri).then(
          (buf) => Buffer.from(buf).toString('utf8'),
          () => '',
        ),
      ),
    );
    for (let j = 0; j < batch.length; j++) {
      allMarkers.push(...extractMarkers(batch[j], contents[j], regex, isCustom));
    }
  }
  return allMarkers;
}

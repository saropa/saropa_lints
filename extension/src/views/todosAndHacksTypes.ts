/**
 * Types for the task/review markers tree view (sidebar list of comment markers).
 * Extension-only: no Dart analyzer or violations.json.
 */

import * as vscode from 'vscode';

/**
 * A single task or review marker found in a file.
 * The tag identifies the kind (see scanner options for supported tag names).
 */
export interface TaskMarker {
  uri: vscode.Uri;
  lineIndex: number;
  tag: string;
  snippet: string;
  fullLine: string;
}

/** Options for the workspace scanner. */
export interface ScanOptions {
  tags: string[];
  includeGlobs: string[];
  excludeGlobs: string[];
  maxFilesToScan: number;
  /** When set, overrides the default comment regex. Must have capture group 1 = tag; optional group 2 = snippet. */
  customRegex?: string;
}

/** Result of a scan: markers and whether the file count was capped. */
export interface ScanResult {
  markers: TaskMarker[];
  capped: boolean;
}

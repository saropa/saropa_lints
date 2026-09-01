/**
 * Single source of truth for report-directory path segments.
 *
 * Every consumer that builds a path into the reports tree must import
 * from here rather than inlining the string literals — keeps the
 * directory layout refactorable from one place.
 */

import * as path from 'path';
import * as vscode from 'vscode';

// ── Directory name constants ─────────────────────────────────────────

/** Top-level reports directory under the workspace root. */
export const REPORTS_DIR = 'reports';

/** Hidden subdirectory for saropa_lints internal state files. */
export const SAROPA_LINTS_DATA_DIR = '.saropa_lints';

// ── Node `path` helpers (for fs / non-vscode consumers) ─────────────

/** Absolute path to `<root>/reports/`. */
export function reportsPath(root: string): string {
    return path.join(root, REPORTS_DIR);
}

/** Absolute path to `<root>/reports/.saropa_lints/`. */
export function saropaLintsDataPath(root: string): string {
    return path.join(root, REPORTS_DIR, SAROPA_LINTS_DATA_DIR);
}

// ── VS Code URI helpers (for workspace-relative consumers) ──────────

/** URI to `<root>/reports/`. */
export function reportsUri(root: vscode.Uri): vscode.Uri {
    return vscode.Uri.joinPath(root, REPORTS_DIR);
}

/** URI to `<root>/reports/.saropa_lints/`. */
export function saropaLintsDataUri(root: vscode.Uri): vscode.Uri {
    return vscode.Uri.joinPath(root, REPORTS_DIR, SAROPA_LINTS_DATA_DIR);
}

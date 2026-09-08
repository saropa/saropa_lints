/**
 * Extension-native check: flags a `bugs/*.md` report whose `Status:` line says
 * it is done (`Fixed`, `Closed`, `Declined`) but the file is still sitting in
 * `bugs/` instead of being archived to `plans/history/YYYY.MM/YYYYMMDD/`.
 *
 * This is a worked example of the "extension-native check" pattern documented
 * in `bugs/ISSUE_REPORT_GUIDE.md` — a check that inspects markdown content and
 * file placement, which a Dart AST rule (lib/src/rules/) structurally cannot
 * do since it only ever sees resolved `.dart` files. It follows the same
 * shape as the other ad hoc checks in this extension (l10nDiagnostics.ts,
 * pubspec-validation.ts): its own DiagnosticCollection, scan on
 * activation/open/save, no shared registry. See the guide's "Rule Sources"
 * section for why this diagnostic does NOT also appear in the web report
 * (violationsWideReportView.ts) — that view's data model is Dart-only today.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';

/** Status values that mean "this report is done and should be archived." */
const DONE_STATUSES = ['Fixed', 'Closed', 'Declined'];

/** Matches `**Status: Fixed**` / `Status: Closed` etc. on its own line. */
const STATUS_LINE_PATTERN = /^\*{0,2}Status:\s*([A-Za-z ]+?)\*{0,2}\s*$/m;

let _collection: vscode.DiagnosticCollection | undefined;

/** True for a `bugs/<name>.md` file, but not the process-documentation guide itself. */
export function isBugReportFile(fsPath: string): boolean {
  const normalized = fsPath.replaceAll('\\', '/');
  return (
    /\/bugs\/[^/]+\.md$/.test(normalized) &&
    !normalized.endsWith('/bugs/ISSUE_REPORT_GUIDE.md')
  );
}

/**
 * Pure check: given a bug report's text, returns the diagnostic to publish
 * (a done `Status:` line found) or `null` (open status, or no status line at
 * all). Separated from `validateDocument` so it can be unit tested against a
 * plain `{ getText, positionAt }` stub without a full VS Code document mock.
 */
export function computeBugArchivalDiagnostic(
  text: string,
  positionAt: (offset: number) => vscode.Position,
): vscode.Diagnostic | null {
  const match = text.match(STATUS_LINE_PATTERN);
  const status = match?.[1]?.trim();
  if (!match || !status || !DONE_STATUSES.includes(status)) return null;

  const line = positionAt(text.indexOf(match[0])).line;
  const range = new vscode.Range(line, 0, line, Number.MAX_SAFE_INTEGER);
  const diag = new vscode.Diagnostic(
    range,
    l10n('bugArchival.diagnostic.message', { status }),
    vscode.DiagnosticSeverity.Information,
  );
  diag.source = 'Saropa Lints';
  return diag;
}

/** Scans one document's text for a done `Status:` line and publishes/clears its diagnostic. */
function validateDocument(doc: vscode.TextDocument): void {
  if (!_collection || !isBugReportFile(doc.uri.fsPath)) return;

  const diag = computeBugArchivalDiagnostic(doc.getText(), (offset) => doc.positionAt(offset));
  _collection.set(doc.uri, diag ? [diag] : []);
}

/** Registers the bug-archival check. Call once at extension activation. */
export function registerBugArchivalCheck(context: vscode.ExtensionContext): void {
  _collection = vscode.languages.createDiagnosticCollection('saropa-bug-archival');
  context.subscriptions.push(_collection);

  context.subscriptions.push(vscode.workspace.onDidSaveTextDocument(validateDocument));
  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validateDocument));

  for (const doc of vscode.workspace.textDocuments) {
    validateDocument(doc);
  }
}

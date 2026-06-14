/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code views: trees, dashboards, or webview HTML builders.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { type Violation } from '../violationsReader';
import { l10n } from '../i18n/runtime';

/** Max end character for a line when requesting code actions (range is clamped by the editor). */
const APPLY_FIX_LINE_END = 4096;
/** Number of code actions to resolve when applying fix from tree (enough to find rule match). */
const APPLY_FIX_RESOLVE_COUNT = 10;

/**
 * Returns the string form of a diagnostic's code (VS Code allows code to be string, number, or { value }).
 */
function diagnosticCodeString(code: vscode.Diagnostic['code']): string {
  if (code === undefined || code === null) return '';
  if (typeof code === 'object' && code !== null && 'value' in code) {
    return String((code as { value: unknown }).value);
  }
  return String(code);
}

/**
 * Invokes the Dart analyzer's quick fix for the given violation at its file/line.
 * Prefers a code action matching the violation's rule; otherwise uses the first quick fix.
 */
export async function applyFixForViolation(v: Violation, root: string): Promise<boolean> {
  const uri = vscode.Uri.file(path.join(root, v.file));
  const line = Math.max(0, (v.line ?? 1) - 1);
  const range = new vscode.Range(line, 0, line, APPLY_FIX_LINE_END);
  const codeActions = await vscode.commands.executeCommand<vscode.CodeAction[]>(
    'vscode.executeCodeActionProvider',
    uri,
    range,
    vscode.CodeActionKind.QuickFix.value,
    APPLY_FIX_RESOLVE_COUNT,
  );
  if (!Array.isArray(codeActions) || codeActions.length === 0) {
    void vscode.window.showInformationMessage(l10n('notify.commands.issuesNoQuickFix'));
    return false;
  }
  const rule = (v.rule ?? '').toString();
  const match = codeActions.find(
    (a) =>
      (Array.isArray(a.diagnostics) &&
        a.diagnostics.some((d) => diagnosticCodeString(d?.code) === rule)) ||
      (a.title && String(a.title).toLowerCase().includes(rule.toLowerCase())),
  );
  const action = match ?? codeActions[0];
  if (action.edit) {
    await vscode.workspace.applyEdit(action.edit);
  }
  if (action.command) {
    await vscode.commands.executeCommand(action.command.command, ...(action.command.arguments ?? []));
  }
  if (!action.edit && !action.command) {
    void vscode.window.showInformationMessage(l10n('notify.commands.issuesNoQuickFix'));
    return false;
  }
  return true;
}

/**
 * D7: Fix all auto-fixable violations in a single file.
 * Processes violations bottom-up (descending line order) to avoid
 * line-number shifts invalidating subsequent fixes.
 */
export async function fixAllInFile(
  violations: Violation[],
  root: string,
  progress: vscode.Progress<{ message?: string; increment?: number }>,
): Promise<{ fixed: number; skipped: number }> {
  const sorted = [...violations].sort((a, b) => (b.line ?? 0) - (a.line ?? 0));
  let fixed = 0;
  let skipped = 0;

  for (const v of sorted) {
    progress.report({ message: `${fixed + skipped + 1}/${sorted.length}` });
    const ok = await applyFixForViolation(v, root);
    if (ok) {
      fixed++;
    } else {
      skipped++;
    }
  }
  return { fixed, skipped };
}

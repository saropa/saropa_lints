/**
 * VS Code adapter for the reciprocal deep-links OUT of a Lints finding (plan
 * requirement R5). Surfaces, in the editor lightbulb on a Drift-category finding,
 * a one-click jump into the sibling tool's live runtime view — closing the loop
 * from static finding to live confirmation.
 *
 * The decision of which jumps to offer lives in `siblingDeepLinkTargets.ts` (pure,
 * unit-tested); this file is the thin provider that maps those targets to
 * `vscode.CodeAction`s and self-gates on sibling-extension presence so a dead
 * action never appears for a tool the user does not have.
 */

import * as vscode from 'vscode';
import {
  suiteDeepLinkTargets,
  type IsInstalledFn,
} from './siblingDeepLinkTargets';

export {
  ADVISOR_EXTENSION_ID,
  LOG_CAPTURE_EXTENSION_ID,
  isDriftRuleId,
  suiteDeepLinkTargets,
} from './siblingDeepLinkTargets';

/** Extract a stable rule id from a diagnostic code (`string | number | { value }`). */
function ruleIdOfDiagnostic(diag: vscode.Diagnostic): string {
  const code = diag.code;
  if (typeof code === 'string') return code;
  if (typeof code === 'number') return String(code);
  if (code && typeof code === 'object' && 'value' in code) return String(code.value);
  return '';
}

/**
 * Code-action provider that surfaces the reciprocal deep-links on a Drift finding.
 * Registered for Dart files; VS Code passes only the diagnostics overlapping the
 * cursor/selection in `context.diagnostics`, so the targets reflect the finding
 * under the lightbulb.
 */
export class SiblingDeepLinkProvider implements vscode.CodeActionProvider {
  // Injectable presence check keeps the class testable and lets a caller stub it.
  constructor(
    private readonly isInstalled: IsInstalledFn = (id) => vscode.extensions.getExtension(id) !== undefined,
  ) {}

  static readonly providedKinds = [vscode.CodeActionKind.QuickFix];

  provideCodeActions(
    _document: vscode.TextDocument,
    _range: vscode.Range | vscode.Selection,
    context: vscode.CodeActionContext,
  ): vscode.CodeAction[] {
    const ruleIds = context.diagnostics.map(ruleIdOfDiagnostic).filter((id) => id.length > 0);
    return suiteDeepLinkTargets(ruleIds, this.isInstalled).map((target) => {
      const action = new vscode.CodeAction(target.title, vscode.CodeActionKind.QuickFix);
      action.command = { title: target.title, command: target.command, arguments: target.args };
      return action;
    });
  }
}

/** Register the Dart-file deep-link provider. No-op surface when no sibling is installed. */
export function registerSiblingDeepLinks(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.languages.registerCodeActionsProvider(
      { language: 'dart', scheme: 'file' },
      new SiblingDeepLinkProvider(),
      { providedCodeActionKinds: SiblingDeepLinkProvider.providedKinds },
    ),
  );
}

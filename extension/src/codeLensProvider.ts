/**
 * Code Lens provider for Dart files: shows "Saropa Lints: N issues — Show in Saropa"
 * above the first line when the file has violations. Click focuses the Issues view filtered to this file.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { normalizePath } from './pathUtils';
import { readViolations } from './violationsReader';

let codeLensChangeEmitter: vscode.EventEmitter<void> | undefined;

/** Call when violations.json changes so Code Lenses refresh. */
export function invalidateCodeLenses(): void {
  codeLensChangeEmitter?.fire();
}

export function registerCodeLensProvider(context: vscode.ExtensionContext): void {
  codeLensChangeEmitter = new vscode.EventEmitter<void>();
  context.subscriptions.push(codeLensChangeEmitter);

  const provider: vscode.CodeLensProvider = {
    onDidChangeCodeLenses: codeLensChangeEmitter.event,
    provideCodeLenses(
      document: vscode.TextDocument,
      _token: vscode.CancellationToken,
    ): vscode.ProviderResult<vscode.CodeLens[]> {
      const root = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
      if (!root || document.languageId !== 'dart') return [];

      const data = readViolations(root);
      if (!data?.violations?.length) return [];

      const docPath = document.uri.fsPath;
      const relativePath = normalizePath(path.relative(root, docPath));
      const count = data.violations.filter((v) => normalizePath(v.file) === relativePath).length;
      if (count === 0) return [];

      const lens = new vscode.CodeLens(new vscode.Range(0, 0, 0, 0), {
        title: count === 1 ? 'Saropa Lints: 1 issue — Show in Saropa' : `Saropa Lints: ${count} issues — Show in Saropa`,
        command: 'saropaLints.focusIssuesForFile',
        arguments: [relativePath],
      });
      return [lens];
    },
  };

  context.subscriptions.push(
    vscode.languages.registerCodeLensProvider({ language: 'dart' }, provider),
  );
}

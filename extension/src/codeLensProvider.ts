/**
 * Code Lens provider for Dart files: shows violation count and opens the Violations view
 * for this file. Placed above the first line when the file has violations.
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { normalizePath } from './pathUtils';
import { readLiveViolations } from './liveViolationsData';
import { getProjectRoot } from './projectRoot';

let codeLensChangeEmitter: vscode.EventEmitter<void> | undefined;

/** Call when live diagnostics change so Code Lenses refresh. */
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
      const root = getProjectRoot();
      if (!root || document.languageId !== 'dart') return [];

      // Live diagnostics (same source as the status bar, Issues tree, and wide
      // report) so the per-file count tracks the Problems panel instead of the
      // batch violations.json export, which goes stale between analysis runs.
      const data = readLiveViolations(root);
      if (!data?.violations?.length) return [];

      const docPath = document.uri.fsPath;
      const relativePath = normalizePath(path.relative(root, docPath));
      const fileViolations = data.violations.filter((v) => normalizePath(v.file) === relativePath);
      const count = fileViolations.length;
      if (count === 0) return [];

      // H4: Show critical count when present.
      const critical = fileViolations.filter((v) => v.impact === 'critical').length;
      const suffix = critical > 0 ? ` (${critical} critical)` : '';
      const violationText = count === 1 ? '1 violation' : `${count} violations`;

      const lens = new vscode.CodeLens(new vscode.Range(0, 0, 0, 0), {
        title: `Saropa: ${violationText}${suffix} \u2014 Show in Saropa`,
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

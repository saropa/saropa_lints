/**
 * Registers "Copy as JSON" and related File Risk context commands for Saropa tree views.
 * Kept separate from `extension.ts` so the activation entry point stays navigable.
 */

import * as vscode from 'vscode';
import { copyTreeNodesToClipboard, copyWholeTreeFromProviderRoots } from './copyTreeAsJson';
import { resolveNodesForJsonExport } from './copyTreeAsJsonSelection';
import type { FileRiskTreeProvider } from './views/fileRiskTree';
import type { IssuesTreeProvider } from './views/issuesTree';
import type { SecurityPostureTreeProvider } from './views/securityPostureTree';
import type { SuggestionsTreeProvider } from './views/suggestionsTree';
import type { SummaryTreeProvider } from './views/summaryTree';
import {
  serializeIssueNode,
  serializeSummaryNode,
  serializeSecurityNode,
  serializeFileRiskNode,
  serializeSuggestionNode,
} from './treeSerializers';

/** Register "Copy as JSON" commands for all lints tree views (not vibrancy — handled separately). */
export function registerCopyAsJsonCommands(
  context: vscode.ExtensionContext,
  providers: {
    issuesProvider: IssuesTreeProvider;
    summaryProvider: SummaryTreeProvider;
    securityProvider: SecurityPostureTreeProvider;
    fileRiskProvider: FileRiskTreeProvider;
    suggestionsProvider: SuggestionsTreeProvider;
  },
): void {
  const {
    issuesProvider,
    summaryProvider,
    securityProvider,
    fileRiskProvider,
    suggestionsProvider,
  } = providers;

  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.issues.copyAsJson', async (item: unknown, selected?: unknown[]) => {
      const nodes = resolveNodesForJsonExport(item, selected);
      if (nodes.length === 0) {
        await copyWholeTreeFromProviderRoots(
          (el) => issuesProvider.getChildren(el as never),
          serializeIssueNode,
          'Violations',
        );
        return;
      }
      await copyTreeNodesToClipboard(
        item,
        selected,
        serializeIssueNode,
        (n) => issuesProvider.getChildren(n as never),
        'Violations',
      );
    }),
    vscode.commands.registerCommand('saropaLints.summary.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSummaryNode, (n) => summaryProvider.getChildren(n as never), 'Summary'),
    ),
    vscode.commands.registerCommand('saropaLints.securityPosture.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSecurityNode, (n) => securityProvider.getChildren(n as never), 'Security Posture'),
    ),
    vscode.commands.registerCommand('saropaLints.fileRisk.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeFileRiskNode, (n) => fileRiskProvider.getChildren(n as never), 'File Risk'),
    ),
    vscode.commands.registerCommand('saropaLints.suggestions.copyAsJson', (item: unknown, selected?: unknown[]) =>
      copyTreeNodesToClipboard(item, selected, serializeSuggestionNode, (n) => suggestionsProvider.getChildren(), 'Suggestions'),
    ),

    // File Risk context menu: show violations for this file (filter without opening).
    vscode.commands.registerCommand('saropaLints.fileRisk.showViolations', (element: unknown) => {
      const filePath = extractFileRiskPath(element);
      if (filePath) void vscode.commands.executeCommand('saropaLints.focusIssuesForFile', filePath);
    }),

    // File Risk context menu: hide file (suppress from violations view).
    vscode.commands.registerCommand('saropaLints.fileRisk.hideFile', (element: unknown) => {
      const filePath = extractFileRiskPath(element);
      if (!filePath) return;
      issuesProvider.addSuppressionFile(filePath);
      // Refresh file risk tree so the hidden file disappears from ranking.
      fileRiskProvider.refresh();
      vscode.window.setStatusBarMessage('File hidden. Clear view hides on Findings Dashboard to show again.', 3000);
    }),

    // File Risk context menu: copy relative file path.
    vscode.commands.registerCommand('saropaLints.fileRisk.copyPath', (element: unknown) => {
      const filePath = extractFileRiskPath(element);
      if (filePath) void vscode.env.clipboard.writeText(filePath);
    }),
  );
}

/** Extract the relative file path from a FileRiskNode tree element. */
function extractFileRiskPath(element: unknown): string | undefined {
  if (!element || typeof element !== 'object') return undefined;
  const node = element as { kind?: string; risk?: { filePath?: string } };
  if (node.kind !== 'file' || !node.risk?.filePath) return undefined;
  return node.risk.filePath;
}

/**
 * Command registration for the Issues tree: the hide/suppress, copy-path/copy-
 * message, and apply-fix / fix-all-in-file commands wired to an
 * IssuesTreeProvider. Split out of issuesTree.ts so the provider class and its
 * command surface live in separate files. The provider is imported type-only
 * to avoid a runtime import cycle — these commands only call methods on the
 * instance passed to registerIssueCommands, they never construct one.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { Violation } from '../violationsReader';
import { readLiveViolations as readViolations } from '../liveViolationsData';
import { estimateScoreWithoutViolation } from '../healthScore';
import { logReport, logSection, flushReport } from '../reportWriter';
import { getProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';
import type { IssuesTreeProvider } from './issuesTree';
import {
  IssueTreeNode,
  FolderItem,
  FileItem,
  ViolationItem,
  SeverityItem,
} from './issuesTreeTypes';

function folderPath(e: FolderItem): string {
  return e.pathPrefix ? `${e.pathPrefix}/${e.segmentName}` : e.segmentName;
}

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
async function applyFixForViolation(v: Violation, root: string): Promise<boolean> {
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
    // D4: Return false — no fix was available.
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
    // D4: Return false — code action had no edit or command.
    return false;
  }
  return true;
}

/**
 * D7: Fix all auto-fixable violations in a single file.
 * Processes violations bottom-up (descending line order) to avoid
 * line-number shifts invalidating subsequent fixes.
 */
async function fixAllInFile(
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

export function registerIssueCommands(
  provider: IssuesTreeProvider,
  context: vscode.ExtensionContext,
): void {
  context.subscriptions.push(
    vscode.commands.registerCommand('saropaLints.hideFolder', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'folder') {
        provider.addSuppressionFolder(folderPath(element as FolderItem));
        vscode.window.setStatusBarMessage('Folder hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideFile', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'file') {
        provider.addSuppressionFile((element as FileItem).filePath);
        vscode.window.setStatusBarMessage('File hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideRule', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        provider.addSuppressionRule((element as ViolationItem).violation.rule);
        vscode.window.setStatusBarMessage('Rule hidden. Clear suppressions to show again.', 3000);
      }
    }),
    /* Programmatic equivalent of `hideRule` that takes a rule name string
       directly instead of a tree-node element. The Findings Dashboard's
       Top Rules table calls this — its rows are HTML, not IssueTreeNodes,
       so it can't reach `addSuppressionRule` through the element-based
       command above. */
    vscode.commands.registerCommand('saropaLints.suppressRuleByName', (ruleArg: unknown) => {
      if (typeof ruleArg !== 'string' || ruleArg.length === 0) return;
      provider.addSuppressionRule(ruleArg);
      vscode.window.setStatusBarMessage(
        `Rule "${ruleArg}" hidden. Clear suppressions to show again.`,
        3000,
      );
    }),
    vscode.commands.registerCommand('saropaLints.hideRuleInFile', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const v = (element as ViolationItem).violation;
        provider.addSuppressionRuleInFile(v.file, v.rule);
        vscode.window.setStatusBarMessage('Rule hidden in this file. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideSeverity', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'severity') {
        provider.addSuppressionSeverity((element as SeverityItem).severity);
        vscode.window.setStatusBarMessage('Severity hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.hideImpact', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const impact = ((element as ViolationItem).violation.impact ?? 'info').toLowerCase();
        provider.addSuppressionImpact(impact);
        vscode.window.setStatusBarMessage('Impact hidden. Clear suppressions to show again.', 3000);
      }
    }),
    vscode.commands.registerCommand('saropaLints.copyPath', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element) {
        const e = element as IssueTreeNode;
        let p = '';
        if (e.kind === 'folder') p = folderPath(e);
        else if (e.kind === 'file') p = e.filePath;
        if (p) void vscode.env.clipboard.writeText(p);
      }
    }),
    vscode.commands.registerCommand('saropaLints.copyMessage', (element: unknown) => {
      if (element && typeof element === 'object' && 'kind' in element && (element as IssueTreeNode).kind === 'violation') {
        const msg = (element as ViolationItem).violation.message ?? '';
        void vscode.env.clipboard.writeText(msg);
      }
    }),
    vscode.commands.registerCommand('saropaLints.applyFix', async (element: unknown) => {
      if (!element || typeof element !== 'object' || !('kind' in element) || (element as IssueTreeNode).kind !== 'violation') {
        return;
      }
      const v = (element as ViolationItem).violation;
      const root = getProjectRoot();
      if (!root) return;

      // D4: Estimate score delta before applying fix.
      const data = readViolations(root);
      // Default to 'warning' (was 'medium' under the 5-bucket impact taxonomy
      // retired 2026-05-03 — both are the middle bucket for unspecified rules).
      const estimate = data ? estimateScoreWithoutViolation(data, v.impact ?? 'warning') : null;

      const applied = await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: 'Applying fix…', cancellable: false },
        () => applyFixForViolation(v, root),
      );

      // D4: Show score-aware result in status bar after successful fix.
      if (applied && estimate && estimate.delta > 0) {
        const pts = estimate.delta === 1 ? 'pt' : 'pts';
        void vscode.window.setStatusBarMessage(
          `Fixed 1 ${v.impact ?? ''} issue (est. +${estimate.delta} ${pts})`,
          4000,
        );
      }

      // Report: log fix attempt.
      if (root) {
        logSection('Fix');
        logReport(`- Rule: ${v.rule} (${v.file}:${v.line})`);
        logReport(`- Result: ${applied ? 'applied' : 'no fix available'}`);
        flushReport(root);
      }
    }),
    // D7: Fix all auto-fixable violations in a file.
    vscode.commands.registerCommand('saropaLints.fixAllInFile', async (element: unknown) => {
      if (!element || typeof element !== 'object' || !('kind' in element) ||
          (element as IssueTreeNode).kind !== 'file') return;
      const fileNode = element as FileItem;
      const root = getProjectRoot();
      if (!root) return;

      // Guard: skip if the source file no longer exists (moved/deleted since last analysis).
      const absPath = path.join(root, fileNode.filePath);
      if (!fs.existsSync(absPath)) {
        void vscode.window.showWarningMessage(
          l10n('notify.commands.issuesFileNotFound', { file: fileNode.filePath }),
        );
        return;
      }

      const data = readViolations(root);
      if (!data) return;
      const fileViolations = data.violations.filter(
        (v) => v.file === fileNode.filePath,
      );
      if (fileViolations.length === 0) return;

      // D7: Confirm before bulk-fixing files with many violations.
      const fileName = path.basename(fileNode.filePath);
      if (fileViolations.length > 20) {
        const fixAllLabel = l10n('notify.commands.actionFixAll');
        const ok = await vscode.window.showWarningMessage(
          l10n('notify.commands.issuesConfirmFixAll', { count: String(fileViolations.length), fileName }),
          { modal: true },
          fixAllLabel,
        );
        if (ok !== fixAllLabel) return;
      }

      const result = await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: `Fixing violations in ${fileName}`,
          cancellable: false,
        },
        (progress) => fixAllInFile(fileViolations, root, progress),
      );

      // D7: Show result summary. Two complete localized templates instead of
      // concatenating English fragments — word order around the skipped count
      // differs across languages and can't be reordered in a built string.
      void vscode.window.showInformationMessage(
        result.skipped > 0
          ? l10n('notify.commands.issuesBulkFixResultSkipped', {
              fixed: String(result.fixed),
              skipped: String(result.skipped),
            })
          : l10n('notify.commands.issuesBulkFixResult', { fixed: String(result.fixed) }),
      );

      // Report: log bulk fix result.
      if (root) {
        logSection('Bulk Fix');
        logReport(`- File: ${fileNode.filePath}`);
        logReport(`- Fixed: ${result.fixed}, Skipped: ${result.skipped}`);
        flushReport(root);
      }

      // D7: Auto-run analysis after bulk fix to update score.
      const cfg = vscode.workspace.getConfiguration('saropaLints');
      const runAfter = cfg.get<boolean>('runAnalysisAfterConfigChange', true);
      if (runAfter && result.fixed > 0) {
        await vscode.commands.executeCommand('saropaLints.runAnalysis');
      }
    }),
  );
}

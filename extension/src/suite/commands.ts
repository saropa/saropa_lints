/**
 * Deep-link command ids contributed as Lints' public integration surface (plan
 * requirement R4). A sibling tool's envelope diagnostic may carry a
 * `fix.command` targeting one of these; they must be contributed and never
 * renamed:
 *
 * - `saropaLints.explainRule { ruleId }` — open Rule Explain (registered in
 *   `extension.ts`, which owns the Rule Explain panel; this module only adds the
 *   two new ids below).
 * - `saropaLints.enableRule { ruleId }` — add a rule to the analysis_options
 *   custom overrides so a sibling's "this crash class is covered by rule X,
 *   currently disabled — enable it" action works.
 * - `saropaLints.openFinding { id }` — round-trip a finding id from an exported
 *   envelope back to the exact source location.
 */

import * as path from 'node:path';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { invalidateDisabledRulesCache, writeRuleOverrides } from '../configWriter';
import { parseFindingId } from './envelope';

/**
 * Accept either the documented object form `{ ruleId }` (used by sibling
 * `fix.command` args) or a bare string (palette / internal callers). Returns the
 * trimmed rule id, or undefined when neither form yields one.
 */
function extractRuleId(arg: unknown): string | undefined {
  if (typeof arg === 'string' && arg.trim().length > 0) return arg.trim();
  if (arg && typeof arg === 'object' && 'ruleId' in arg) {
    const ruleId = (arg as { ruleId: unknown }).ruleId;
    if (typeof ruleId === 'string' && ruleId.trim().length > 0) return ruleId.trim();
  }
  return undefined;
}

/** Accept `{ id }` object form or a bare finding-id string. */
function extractFindingId(arg: unknown): string | undefined {
  if (typeof arg === 'string' && arg.trim().length > 0) return arg.trim();
  if (arg && typeof arg === 'object' && 'id' in arg) {
    const id = (arg as { id: unknown }).id;
    if (typeof id === 'string' && id.trim().length > 0) return id.trim();
  }
  return undefined;
}

/**
 * Register the `enableRule` and `openFinding` deep-link commands. `getRoot`
 * resolves the active project root (the same resolver `extension.ts` uses) so the
 * commands write to / read from the correct workspace folder.
 */
export function registerSuiteCommands(
  context: vscode.ExtensionContext,
  getRoot: () => string | undefined,
): void {
  context.subscriptions.push(
    // R4: enable a rule by id. The override only takes effect on the next
    // analysis pass, so the toast names the exact rule AND offers the re-run as a
    // one-tap action rather than leaving the user to guess the follow-up.
    vscode.commands.registerCommand('saropaLints.enableRule', async (arg: unknown) => {
      const ruleId = extractRuleId(arg);
      if (!ruleId) return;
      const root = getRoot();
      if (!root) {
        void vscode.window.showInformationMessage(l10n('suite.enableRule.noWorkspace'));
        return;
      }
      writeRuleOverrides(root, [{ rule: ruleId, enabled: true }]);
      invalidateDisabledRulesCache();
      const runAction = l10n('suite.enableRule.runAnalysis');
      const choice = await vscode.window.showInformationMessage(
        l10n('suite.enableRule.done', { ruleId }),
        runAction,
      );
      if (choice === runAction) {
        void vscode.commands.executeCommand('saropaLints.runAnalysis');
      }
    }),
    // R4: round-trip an exported finding id back to its source location.
    vscode.commands.registerCommand('saropaLints.openFinding', async (arg: unknown) => {
      const id = extractFindingId(arg);
      const parsed = id ? parseFindingId(id) : null;
      if (!parsed) return;
      const root = getRoot();
      if (!root) {
        void vscode.window.showInformationMessage(l10n('suite.openFinding.noWorkspace'));
        return;
      }
      const absPath = path.resolve(root, parsed.file);
      try {
        const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(absPath));
        // Finding lines are 1-based (the live model adds 1); VS Code positions are
        // 0-based, so subtract one and clamp at 0 for a defensive line 0/1.
        const line = Math.max(0, parsed.line - 1);
        const selection = new vscode.Range(line, 0, line, 0);
        await vscode.window.showTextDocument(doc, { selection, preview: true });
      } catch {
        void vscode.window.showInformationMessage(
          l10n('suite.openFinding.notFound', { file: parsed.file }),
        );
      }
    }),
  );
}

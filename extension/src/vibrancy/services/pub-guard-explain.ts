/**
 * UI for the Vibrancy pub guard: a clickable status-bar item shown when a pub
 * query was skipped, and the "Explain Last Vibrancy Skip" command it runs.
 *
 * Why a persistent item and not a transient message: a skipped scan otherwise
 * looks like a hung or empty dashboard, and a 15s toast is gone before the user
 * notices. The item stays until clicked or until no folder has a recorded skip.
 */

import * as vscode from 'vscode';
import { l10n } from '../../i18n/runtime';
import { planPubGet, runPubGetWithProjectSdk } from './flutter-cli';
import {
    buildExplainModel, buildFolderPickItems, getSkips, GuardDecision, onGuardOutcome,
} from './pub-guard-record';

/** Command id contributed in package.json. */
export const EXPLAIN_SKIP_COMMAND = 'saropaLints.packageVibrancy.explainLastSkip';

/**
 * Picks which skipped folder to explain: the only one directly, a QuickPick
 * when a multi-root workspace has several. Undefined when the user cancels.
 */
async function chooseSkip(all: readonly GuardDecision[]): Promise<GuardDecision | undefined> {
    if (all.length <= 1) { return all[0]; }
    const picked = await vscode.window.showQuickPick(buildFolderPickItems(all), {
        placeHolder: l10n('pubGuard.explain.pickFolder'),
    });
    return picked?.decision;
}

/**
 * Confirms `pub get` when the SDK would come from bare PATH: that is the
 * configuration that originally rewrote pubspec.lock with the wrong SDK, so
 * running it must be an explicit, informed choice.
 */
async function confirmPathPubGet(): Promise<boolean> {
    const run = l10n('pubGuard.explain.pathConfirmRun');
    const choice = await vscode.window.showWarningMessage(
        l10n('pubGuard.explain.pathConfirm'), { modal: true }, run);
    return choice === run;
}

/**
 * Runs the command: show the recorded decision in a modal, and on request run
 * `pub get` with the project's own SDK (dart or flutter by project type). That
 * is the one action that legitimately rewrites the lock; it is user-initiated.
 */
export async function explainLastSkip(): Promise<void> {
    const all = getSkips();
    if (all.length === 0) {
        // No silent no-op: say that nothing was recorded.
        void vscode.window.showInformationMessage(l10n('pubGuard.explain.none'));
        return;
    }
    const skip = await chooseSkip(all);
    if (!skip) { return; }
    const model = buildExplainModel(skip);
    if (model.kind !== 'skip') { return; }
    const choice = await vscode.window.showInformationMessage(
        model.title, { modal: true, detail: model.detail }, model.actionLabel);
    if (choice !== model.actionLabel) { return; }
    // A PATH-resolved SDK needs a second, explicit confirmation.
    if (planPubGet(skip.cwd).exe.source === 'path' && !(await confirmPathPubGet())) { return; }
    const result = await runPubGetWithProjectSdk(skip.cwd);
    if (result.success) {
        void vscode.window.showInformationMessage(l10n('pubGuard.explain.pubGetDone'));
    } else {
        void vscode.window.showWarningMessage(
            l10n('pubGuard.explain.pubGetFailed', { error: result.errorMessage ?? '' }));
    }
}

/**
 * Registers the command and the status-bar item. Returns disposables for
 * `context.subscriptions`.
 */
export function registerExplainSkip(): Array<{ dispose(): unknown }> {
    const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 0);
    item.command = EXPLAIN_SKIP_COMMAND;
    // Codicon prefix is a glyph (not user copy); the words are localized.
    item.text = `$(warning) ${l10n('pubGuard.statusItem.text')}`;
    item.tooltip = l10n('pubGuard.statusItem.tooltip');

    const command = vscode.commands.registerCommand(EXPLAIN_SKIP_COMMAND, async () => {
        // Clicking acknowledges the skip; the item returns only on the next skip.
        item.hide();
        await explainLastSkip();
    });
    // Show on a refused outcome; hide only when NO folder has a recorded skip
    // (an allowed pass in one folder must not hide another folder's skip).
    const unsubscribe = onGuardOutcome((safe) => {
        if (!safe) { item.show(); } else if (getSkips().length === 0) { item.hide(); }
    });
    return [item, command, { dispose: unsubscribe }];
}

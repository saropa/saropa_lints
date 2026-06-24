/**
 * Host for the dedicated "Upgrade Opportunities" dashboard webview.
 *
 * Singleton panel (one per window, revealed on re-open). It builds the card
 * data from the latest scan results — assembling each package's AI prompt from
 * the full-history opportunities + call sites — and renders the focused list.
 * Messages handle opening a code location and jumping to a package's full detail
 * in the Package Dashboard.
 */

import * as vscode from 'vscode';
import { VibrancyResult, activeFileUsages } from '../types';
import { buildAiPromptBundle } from '../services/ai-prompt-bundle';
import {
    buildOpportunitiesHtml,
    OpportunityCardData,
} from './opportunities-html';
import { l10n } from '../../i18n/runtime';

export class OpportunitiesPanel {
    private static _current: OpportunitiesPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];
    private _workspaceRoot: vscode.Uri;

    static createOrShow(
        results: readonly VibrancyResult[],
        extensionVersion: string,
        workspaceRoot: vscode.Uri,
    ): void {
        const cards = buildCards(results);
        if (OpportunitiesPanel._current) {
            OpportunitiesPanel._current._workspaceRoot = workspaceRoot;
            OpportunitiesPanel._current._panel.reveal();
            OpportunitiesPanel._current._render(cards, extensionVersion);
            return;
        }
        const panel = vscode.window.createWebviewPanel(
            'saropaUpgradeOpportunities',
            l10n('opportunities.documentTitle'),
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );
        OpportunitiesPanel._current = new OpportunitiesPanel(
            panel, cards, extensionVersion, workspaceRoot,
        );
    }

    private constructor(
        panel: vscode.WebviewPanel,
        cards: readonly OpportunityCardData[],
        extensionVersion: string,
        workspaceRoot: vscode.Uri,
    ) {
        this._panel = panel;
        this._workspaceRoot = workspaceRoot;
        this._render(cards, extensionVersion);
        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
        this._panel.webview.onDidReceiveMessage(
            msg => this._handleMessage(msg), null, this._disposables,
        );
    }

    private _render(
        cards: readonly OpportunityCardData[], extensionVersion: string,
    ): void {
        this._panel.webview.html = buildOpportunitiesHtml(cards, extensionVersion);
    }

    private async _handleMessage(msg: unknown): Promise<void> {
        if (typeof msg !== 'object' || msg === null) { return; }
        const m = msg as { type?: string; file?: string; line?: number; package?: string };
        // Jump to the exact import site so the user lands where the package is
        // used and can apply the new feature in context.
        if (m.type === 'openFile' && m.file) {
            await openAtLine(this._workspaceRoot, m.file, m.line ?? 1);
            return;
        }
        // Hand off to the Package Dashboard's detail pane for the full record.
        if (m.type === 'openPackage' && m.package) {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.showPackagePanel', m.package,
            );
        }
    }

    private _dispose(): void {
        OpportunitiesPanel._current = undefined;
        this._panel.dispose();
        while (this._disposables.length) {
            this._disposables.pop()?.dispose();
        }
    }
}

/**
 * Turn scan results into card data: keep only packages with unadopted features
 * and precompute each one's AI prompt so the webview button copies a ready
 * string. The HTML builder does the final filter+sort, but assembling the
 * prompt here keeps the renderer pure.
 */
function buildCards(
    results: readonly VibrancyResult[],
): OpportunityCardData[] {
    const cards: OpportunityCardData[] = [];
    for (const result of results) {
        if ((result.unadoptedApiNames?.length ?? 0) === 0) { continue; }
        const opportunities = result.opportunities;
        const aiPrompt = opportunities
            ? buildAiPromptBundle({
                packageName: result.package.name,
                currentVersion: result.package.version,
                latestVersion: result.updateInfo?.latestVersion ?? result.package.version,
                opportunities,
                fileUsages: activeFileUsages(result.fileUsages),
            })
            : null;
        cards.push({ result, aiPrompt });
    }
    return cards;
}

/** Open a workspace-relative file and move the cursor to the given line. */
async function openAtLine(
    workspaceRoot: vscode.Uri, relativePath: string, line: number,
): Promise<void> {
    try {
        const uri = vscode.Uri.joinPath(workspaceRoot, relativePath);
        const doc = await vscode.workspace.openTextDocument(uri);
        const editor = await vscode.window.showTextDocument(doc);
        // Lines from the scanner are 1-based; VS Code positions are 0-based.
        const pos = new vscode.Position(Math.max(0, line - 1), 0);
        editor.selection = new vscode.Selection(pos, pos);
        editor.revealRange(
            new vscode.Range(pos, pos),
            vscode.TextEditorRevealType.InCenter,
        );
    } catch {
        // File moved/renamed since the scan — surface a non-fatal notice.
        void vscode.window.showWarningMessage(
            l10n('opportunities.openFileFailed', { file: relativePath }),
        );
    }
}

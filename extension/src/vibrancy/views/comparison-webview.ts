/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import * as vscode from 'vscode';
import { ComparisonData, RankedComparison } from '../types';
import { buildComparisonHtml } from './comparison-html';
import { rankPackages } from '../scoring/comparison-ranker';
import { findPubspecYaml } from '../services/pubspec-editor';
import { l10n } from '../../i18n/runtime';

// Side-by-side package comparison webview (add package, rank, HTML from buildComparisonHtml).
interface AddPackageMessage {
    type: 'addPackage';
    name: string;
    version: string;
}

interface OpenPackageDashboardMessage {
    type: 'openPackageDashboard';
}

type ComparisonMessage = AddPackageMessage | OpenPackageDashboardMessage;

/** Singleton webview panel for package comparison. */
export class ComparisonPanel {
    public static currentPanel: ComparisonPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];

    /** Create or reveal the comparison panel. */
    static createOrShow(packages: readonly ComparisonData[]): void {
        if (ComparisonPanel.currentPanel) {
            ComparisonPanel.currentPanel._panel.reveal();
            ComparisonPanel.currentPanel._updateContent(packages);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaPackageComparison',
            'Saropa Package Comparison',
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        ComparisonPanel.currentPanel = new ComparisonPanel(panel, packages);
    }

    private constructor(
        panel: vscode.WebviewPanel,
        packages: readonly ComparisonData[],
    ) {
        this._panel = panel;
        this._updateContent(packages);

        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);

        this._panel.webview.onDidReceiveMessage(
            message => this._handleMessage(message),
            null,
            this._disposables,
        );
    }

    private _updateContent(packages: readonly ComparisonData[]): void {
        const ranked: RankedComparison = rankPackages(packages);
        this._panel.webview.html = buildComparisonHtml(ranked);
    }

    private async _handleMessage(message: ComparisonMessage): Promise<void> {
        if (message.type === 'addPackage') {
            const { name, version } = message;
            await addPackageToPubspec(name, version);
            return;
        }
        if (message.type === 'openPackageDashboard') {
            // §4.3 / §8.16 — toolbar action and empty-state CTA both dispatch
            // here; reusing the registered command keeps a single open path
            // so any future telemetry around dashboard opens fires
            // consistently regardless of entry point.
            await vscode.commands.executeCommand('saropaLints.openPackageVibrancy');
        }
    }

    private _dispose(): void {
        ComparisonPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

async function addPackageToPubspec(name: string, version: string): Promise<void> {
    const yamlUri = await findPubspecYaml();
    if (!yamlUri) {
        vscode.window.showWarningMessage(l10n('notify.vibrancy.noPubspecFound'));
        return;
    }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const text = doc.getText();
    const lines = text.split('\n');

    let depSectionIndex = -1;
    for (let i = 0; i < lines.length; i++) {
        if (/^dependencies:\s*$/.test(lines[i])) {
            depSectionIndex = i;
            break;
        }
    }

    if (depSectionIndex < 0) {
        vscode.window.showWarningMessage(l10n('notify.vibrancy.noDependenciesSection'));
        return;
    }

    let insertIndex = depSectionIndex + 1;
    while (insertIndex < lines.length) {
        const line = lines[insertIndex];
        if (/^\S/.test(line) && !line.trim().startsWith('#')) {
            break;
        }
        insertIndex++;
    }

    const constraint = version ? `^${version}` : 'any';
    const newLine = `  ${name}: ${constraint}\n`;

    const edit = new vscode.WorkspaceEdit();
    const position = new vscode.Position(insertIndex, 0);
    edit.insert(yamlUri, position, newLine);

    const applied = await vscode.workspace.applyEdit(edit);
    if (applied) {
        await doc.save();
        vscode.window.showInformationMessage(l10n('notify.vibrancy.addedToPubspec', { name, constraint }));
    } else {
        vscode.window.showWarningMessage(l10n('notify.vibrancy.failedToAddToPubspec', { name }));
    }
}

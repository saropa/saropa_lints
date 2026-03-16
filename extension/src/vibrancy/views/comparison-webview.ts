import * as vscode from 'vscode';
import { ComparisonData, RankedComparison } from '../types';
import { buildComparisonHtml } from './comparison-html';
import { rankPackages } from '../scoring/comparison-ranker';
import { findPubspecYaml } from '../services/pubspec-editor';

interface AddPackageMessage {
    type: 'addPackage';
    name: string;
    version: string;
}

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
            'Package Comparison',
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

    private async _handleMessage(message: AddPackageMessage): Promise<void> {
        if (message.type !== 'addPackage') { return; }

        const { name, version } = message;
        await addPackageToPubspec(name, version);
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
        vscode.window.showWarningMessage('No pubspec.yaml found');
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
        vscode.window.showWarningMessage('Could not find dependencies section');
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
        vscode.window.showInformationMessage(`Added ${name}: ${constraint} to pubspec.yaml`);
    } else {
        vscode.window.showWarningMessage(`Failed to add ${name} to pubspec.yaml`);
    }
}

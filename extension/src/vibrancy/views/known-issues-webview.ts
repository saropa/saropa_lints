import * as vscode from 'vscode';
import { buildKnownIssuesHtml } from './known-issues-html';

/** Singleton webview panel for browsing the known issues library. */
export class KnownIssuesPanel {
    public static currentPanel: KnownIssuesPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];

    static createOrShow(): void {
        if (KnownIssuesPanel.currentPanel) {
            KnownIssuesPanel.currentPanel._panel.reveal();
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaKnownIssuesBrowser',
            'Known Issues Library',
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        KnownIssuesPanel.currentPanel = new KnownIssuesPanel(panel);
    }

    private constructor(panel: vscode.WebviewPanel) {
        this._panel = panel;
        this._panel.webview.html = buildKnownIssuesHtml();

        this._panel.onDidDispose(
            () => this._dispose(), null, this._disposables,
        );
    }

    private _dispose(): void {
        KnownIssuesPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

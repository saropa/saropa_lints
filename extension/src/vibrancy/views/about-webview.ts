import * as vscode from 'vscode';
import { buildAboutHtml } from './about-html';

/** Singleton webview panel showing extension info and links. */
export class AboutPanel {
    public static currentPanel: AboutPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];

    static createOrShow(version: string): void {
        if (AboutPanel.currentPanel) {
            AboutPanel.currentPanel._panel.reveal();
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaAbout',
            'About Saropa Package Vibrancy',
            vscode.ViewColumn.One,
            { enableScripts: false },
        );

        AboutPanel.currentPanel = new AboutPanel(panel, version);
    }

    private constructor(panel: vscode.WebviewPanel, version: string) {
        this._panel = panel;
        this._panel.webview.html = buildAboutHtml(version);

        this._panel.onDidDispose(
            () => this._dispose(), null, this._disposables,
        );
    }

    private _dispose(): void {
        AboutPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

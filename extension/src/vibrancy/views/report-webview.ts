import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { buildReportHtml } from './report-html';

/** Singleton webview panel for the vibrancy report. */
export class VibrancyReportPanel {
    public static currentPanel: VibrancyReportPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];

    static createOrShow(results: VibrancyResult[]): void {
        if (VibrancyReportPanel.currentPanel) {
            VibrancyReportPanel.currentPanel._panel.reveal();
            VibrancyReportPanel.currentPanel._updateContent(results);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaVibrancyReport',
            'Package Vibrancy Report',
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        VibrancyReportPanel.currentPanel = new VibrancyReportPanel(
            panel, results,
        );
    }

    private constructor(panel: vscode.WebviewPanel, results: VibrancyResult[]) {
        this._panel = panel;
        this._updateContent(results);

        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
    }

    private _updateContent(results: VibrancyResult[]): void {
        this._panel.webview.html = buildReportHtml(results);
    }

    private _dispose(): void {
        VibrancyReportPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

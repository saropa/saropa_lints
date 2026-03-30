import * as vscode from 'vscode';
import { ReportOptions, buildReportHtml } from './report-html';

/** Singleton webview panel for the vibrancy report. */
export class VibrancyReportPanel {
    private static _currentPanel: VibrancyReportPanel | undefined;
    public static get currentPanel(): VibrancyReportPanel | undefined {
        return VibrancyReportPanel._currentPanel;
    }
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];
    private _pubspecUri: string | null;

    static createOrShow(options: ReportOptions): void {
        if (VibrancyReportPanel.currentPanel) {
            VibrancyReportPanel.currentPanel._panel.reveal();
            VibrancyReportPanel.currentPanel._updateContent(options);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaVibrancyReport',
            'Package Vibrancy Report',
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        VibrancyReportPanel._currentPanel = new VibrancyReportPanel(
            panel, options,
        );
    }

    private constructor(panel: vscode.WebviewPanel, options: ReportOptions) {
        this._panel = panel;
        this._pubspecUri = options.pubspecUri;
        this._updateContent(options);

        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);

        /* Handle messages from the webview (e.g. "Open pubspec.yaml"). */
        this._panel.webview.onDidReceiveMessage(
            msg => this._handleMessage(msg),
            null,
            this._disposables,
        );
    }

    private _updateContent(options: ReportOptions): void {
        this._pubspecUri = options.pubspecUri;
        this._panel.webview.html = buildReportHtml(options);
    }

    private async _handleMessage(msg: { type: string }): Promise<void> {
        if (msg.type === 'openPubspec' && this._pubspecUri) {
            try {
                const uri = vscode.Uri.parse(this._pubspecUri);
                const doc = await vscode.workspace.openTextDocument(uri);
                await vscode.window.showTextDocument(doc);
            } catch {
                /* File may have been moved or workspace closed since render. */
                vscode.window.showErrorMessage('Could not open pubspec.yaml.');
            }
        }
    }

    private _dispose(): void {
        VibrancyReportPanel._currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

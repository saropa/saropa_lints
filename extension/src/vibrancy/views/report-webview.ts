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
            'Saropa Package Vibrancy',
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

    private async _handleMessage(
        msg: { type: string; package?: string; path?: string; line?: number; data?: unknown },
    ): Promise<void> {
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

        else if (msg.type === 'openPubspecEntry' && this._pubspecUri && msg.package) {
            try {
                const uri = vscode.Uri.parse(this._pubspecUri);
                const doc = await vscode.workspace.openTextDocument(uri);
                const editor = await vscode.window.showTextDocument(doc);
                /* Jump to the line containing the package name. */
                const text = doc.getText();
                const idx = text.indexOf(`${msg.package}:`);
                if (idx >= 0) {
                    const pos = doc.positionAt(idx);
                    editor.selection = new vscode.Selection(pos, pos);
                    editor.revealRange(
                        new vscode.Range(pos, pos),
                        vscode.TextEditorRevealType.InCenter,
                    );
                }
            } catch {
                vscode.window.showErrorMessage('Could not open pubspec.yaml.');
            }
        }

        else if (msg.type === 'searchImport' && msg.package) {
            /* Open "Find in Files" pre-filled with the package import pattern. */
            await vscode.commands.executeCommand('workbench.action.findInFiles', {
                query: `package:${msg.package}/`,
                isRegex: false,
                triggerSearch: true,
            });
        }

        else if (msg.type === 'openOtherProject') {
            /* Pops the file picker in the host and (on selection) opens
               the chosen pubspec.yaml's folder in a new VS Code window. */
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openOtherProject',
            );
        }

        else if (msg.type === 'rescan') {
            /* Run the scan, then reopen the report so the panel refreshes
               with the fresh results. showReport calls createOrShow which
               detects the existing panel and rebuilds its HTML via
               _updateContent, so the rescan button resets naturally. */
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.scan');
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
        }

        else if (msg.type === 'openSourceFolder' && msg.package) {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openSourceFolder',
                msg.package,
            );
        }

        else if (msg.type === 'openFileRef' && msg.path) {
            await this._openFileReference(msg.path, msg.line);
        }

        else if (msg.type === 'saveReportJson' && Array.isArray(msg.data)) {
            await this._saveReportJson(msg.data);
        }
    }

    private async _openFileReference(filePath: string, line?: number): Promise<void> {
        try {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) { return; }
            const isAbsolute = /^[a-zA-Z]:[\\/]/.test(filePath) || filePath.startsWith('/');
            const uri = isAbsolute
                ? vscode.Uri.file(filePath)
                : vscode.Uri.joinPath(workspaceFolder.uri, filePath);
            const doc = await vscode.workspace.openTextDocument(uri);
            const editor = await vscode.window.showTextDocument(doc);
            const targetLine = Math.max(0, (line ?? 1) - 1);
            const pos = new vscode.Position(targetLine, 0);
            editor.selection = new vscode.Selection(pos, pos);
            editor.revealRange(
                new vscode.Range(pos, pos),
                vscode.TextEditorRevealType.InCenter,
            );
        } catch {
            vscode.window.showErrorMessage(`Could not open file reference: ${filePath}`);
        }
    }

    private async _saveReportJson(rows: unknown[]): Promise<void> {
        try {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) { return; }
            const now = new Date();
            const y = now.getFullYear().toString();
            const m = String(now.getMonth() + 1).padStart(2, '0');
            const d = String(now.getDate()).padStart(2, '0');
            const hh = String(now.getHours()).padStart(2, '0');
            const mm = String(now.getMinutes()).padStart(2, '0');
            const ss = String(now.getSeconds()).padStart(2, '0');
            const ymd = `${y}${m}${d}`;
            const timestamp = `${hh}${mm}${ss}`;
            const dir = vscode.Uri.joinPath(workspaceFolder.uri, 'reports', ymd);
            await vscode.workspace.fs.createDirectory(dir);
            const file = vscode.Uri.joinPath(
                dir,
                `${ymd}_${timestamp}pubspec_vibrancy.json`,
            );
            const content = JSON.stringify(rows, null, 2);
            await vscode.workspace.fs.writeFile(
                file,
                new TextEncoder().encode(content),
            );
            vscode.window.showInformationMessage(`Saved report JSON: ${file.fsPath}`);
        } catch {
            vscode.window.showErrorMessage('Could not save report JSON.');
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

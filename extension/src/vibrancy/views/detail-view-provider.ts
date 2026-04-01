import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { buildDetailViewHtml } from './detail-view-html';
import { findPubspecYaml, buildVersionEdit } from '../providers/tree-commands';
import { openFileAtLine } from './view-actions';

/** View ID for the package details webview in the sidebar. */
export const DETAIL_VIEW_ID = 'saropaLints.packageVibrancy.details';

/** Provides the Package Details webview in the sidebar. */
export class DetailViewProvider implements vscode.WebviewViewProvider {
    private _view: vscode.WebviewView | undefined;
    private _currentResult: VibrancyResult | null = null;

    constructor(private readonly _extensionUri: vscode.Uri) {}

    /** Called by VS Code when the webview view becomes visible. */
    resolveWebviewView(
        webviewView: vscode.WebviewView,
        _context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken,
    ): void {
        this._view = webviewView;

        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this._extensionUri],
        };

        webviewView.webview.html = buildDetailViewHtml(this._currentResult);

        webviewView.webview.onDidReceiveMessage(
            message => this._handleMessage(message),
        );
    }

    /** Update the detail view with a new package result. */
    update(result: VibrancyResult): void {
        this._currentResult = result;
        if (this._view) {
            this._view.webview.html = buildDetailViewHtml(result);
        }
    }

    /** Clear the detail view to show the placeholder state. */
    clear(): void {
        this._currentResult = null;
        if (this._view) {
            this._view.webview.html = buildDetailViewHtml(null);
        }
    }

    /** Reveal and focus the detail view. */
    focus(): void {
        if (this._view) {
            this._view.show(true);
        }
    }

    /** Get the currently displayed package result. */
    getCurrentResult(): VibrancyResult | null {
        return this._currentResult;
    }

    private async _handleMessage(message: { type: string; package?: string; url?: string; path?: string; line?: number }): Promise<void> {
        switch (message.type) {
            case 'upgrade':
                if (message.package) {
                    await this._handleUpgrade(message.package);
                }
                break;

            case 'changelog':
                if (message.package) {
                    await vscode.commands.executeCommand(
                        'saropaLints.packageVibrancy.showChangelog',
                        message.package,
                    );
                }
                break;

            case 'openUrl':
                if (message.url) {
                    await vscode.env.openExternal(vscode.Uri.parse(message.url));
                }
                break;

            case 'openFile':
                if (message.path) {
                    await openFileAtLine(message.path, message.line ?? 1);
                }
                break;

            case 'fullDetails':
                if (message.package) {
                    await vscode.commands.executeCommand(
                        'saropaLints.packageVibrancy.showPackagePanel',
                        message.package,
                    );
                }
                break;
        }
    }

    private async _handleUpgrade(packageName: string): Promise<void> {
        const result = this._currentResult;
        if (!result || result.package.name !== packageName) {
            return;
        }

        const latest = result.updateInfo?.latestVersion;
        if (!latest) {
            return;
        }

        const targetVersion = `^${latest}`;

        const yamlUri = await findPubspecYaml();
        if (!yamlUri) {
            return;
        }

        const doc = await vscode.workspace.openTextDocument(yamlUri);
        const edit = buildVersionEdit(doc, packageName, targetVersion);
        if (!edit) {
            vscode.window.showWarningMessage(
                `Could not locate version constraint for ${packageName}`,
            );
            return;
        }

        const wsEdit = new vscode.WorkspaceEdit();
        wsEdit.replace(yamlUri, edit.range, edit.newText);
        await vscode.workspace.applyEdit(wsEdit);
        await doc.save();

        vscode.window.showInformationMessage(
            `Updated ${packageName} to ${targetVersion}`,
        );
    }
}

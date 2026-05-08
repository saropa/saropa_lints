/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import * as vscode from 'vscode';
import { buildKnownIssuesHtml } from './known-issues-html';

/** Workspace-persisted recent package search queries for Known Issues. */
export const KNOWN_ISSUES_RECENT_WS_KEY = 'saropa.knownIssues.recentSearches';

/** Singleton webview panel for browsing the known issues library. */
export class KnownIssuesPanel {
    public static currentPanel: KnownIssuesPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private readonly _extensionContext: vscode.ExtensionContext;
    private _disposables: vscode.Disposable[] = [];

    static createOrShow(extensionContext: vscode.ExtensionContext): void {
        if (KnownIssuesPanel.currentPanel) {
            KnownIssuesPanel.currentPanel._panel.reveal();
            void KnownIssuesPanel.currentPanel._hydrateRecent();
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaKnownIssuesBrowser',
            'Saropa Known Issues',
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        KnownIssuesPanel.currentPanel = new KnownIssuesPanel(panel, extensionContext);
    }

    private constructor(panel: vscode.WebviewPanel, extensionContext: vscode.ExtensionContext) {
        this._panel = panel;
        this._extensionContext = extensionContext;
        this._panel.webview.html = buildKnownIssuesHtml();

        this._disposables.push(
            this._panel.webview.onDidReceiveMessage((msg: unknown) => {
                if (!msg || typeof msg !== 'object') {
                    return;
                }
                const rec = msg as { type?: string; queries?: unknown };
                if (rec.type === 'saveKnownIssuesRecent' && Array.isArray(rec.queries)) {
                    const qs = rec.queries
                        .filter((q): q is string => typeof q === 'string')
                        .slice(0, 12);
                    void this._extensionContext.workspaceState.update(KNOWN_ISSUES_RECENT_WS_KEY, qs);
                }
            }),
        );

        void this._hydrateRecent();

        this._panel.onDidDispose(
            () => this._dispose(),
            null,
            this._disposables,
        );
    }

    private async _hydrateRecent(): Promise<void> {
        const queries = this._extensionContext.workspaceState.get<string[]>(
            KNOWN_ISSUES_RECENT_WS_KEY,
            [],
        );
        if (queries.length === 0) {
            return;
        }
        await this._panel.webview.postMessage({
            type: 'hydrateKnownIssuesRecent',
            queries,
        });
    }

    private _dispose(): void {
        KnownIssuesPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

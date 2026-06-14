/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import * as vscode from 'vscode';
import { ReportOptions, buildReportHtml } from './report-html';
import { PackageDetailPaneController, PaneMessage } from './package-detail-pane-controller';
import { ReviewStateService } from '../services/review-state';
import { CacheService } from '../services/cache-service';
import { l10n } from '../../i18n/runtime';

/** Singleton webview panel for the vibrancy report. */
export class VibrancyReportPanel {
    private static _currentPanel: VibrancyReportPanel | undefined;
    public static get currentPanel(): VibrancyReportPanel | undefined {
        return VibrancyReportPanel._currentPanel;
    }
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];
    private _pubspecUri: string | null;
    /* Retained so the docked detail pane can look up the selected package's
       VibrancyResult on demand (master-detail round-trip) without re-scanning. */
    private _options: ReportOptions | null = null;
    /* Host controller for the docked detail pane (lazy fetch + review state).
       Null only if the extension never called configure() (defensive). */
    private _pane: PackageDetailPaneController | null = null;

    /* Services for the detail pane, injected once at activation so the panel
       can run the same lazy fetches + review persistence the standalone panel
       did. Static because the panel is a singleton recreated across rescans. */
    private static _reviewState: ReviewStateService | undefined;
    private static _cache: CacheService | undefined;

    /** Wire the detail-pane services. Call once during activation. */
    static configure(reviewState: ReviewStateService, cache?: CacheService): void {
        VibrancyReportPanel._reviewState = reviewState;
        VibrancyReportPanel._cache = cache;
    }

    static createOrShow(options: ReportOptions): void {
        if (VibrancyReportPanel.currentPanel) {
            VibrancyReportPanel.currentPanel._panel.reveal();
            VibrancyReportPanel.currentPanel._updateContent(options);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            'saropaVibrancyReport',
            'Saropa Package Dashboard',
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

        /* Detail-pane controller: pushes rendered detail bodies into the pane.
           Only created when the host wired review-state via configure(). */
        if (VibrancyReportPanel._reviewState) {
            this._pane = new PackageDetailPaneController(
                (html, packageName) => this._panel.webview.postMessage({
                    type: 'packageDetailHtml', package: packageName, html,
                }),
                VibrancyReportPanel._reviewState,
                VibrancyReportPanel._cache,
            );
        }

        /* Handle messages from the webview (e.g. "Open pubspec.yaml"). */
        this._panel.webview.onDidReceiveMessage(
            msg => this._handleMessage(msg),
            null,
            this._disposables,
        );
    }

    private _updateContent(options: ReportOptions): void {
        this._pubspecUri = options.pubspecUri;
        this._options = options;
        /* New HTML means the script re-inits; wait for its ready signal again
           before flushing any queued package selection. */
        this._ready = false;
        this._panel.webview.html = buildReportHtml(options);
    }

    /** Package the pane should open once the webview is ready. */
    private _pendingSelect: string | null = null;
    /** True once the dashboard script signals it has wired its listeners. A
     *  fresh webview drops messages sent before that, so a select requested
     *  right after open is queued here and flushed on the ready signal. */
    private _ready = false;

    /** Reveal the open dashboard and select a package in the docked detail pane.
     *  Entry point for "View Full Details" from hover / sidebar / command
     *  catalog, replacing the standalone PackageDetailPanel. The caller must
     *  ensure the dashboard exists first (e.g. run the showReport command). */
    static requestSelect(packageName: string): void {
        const p = VibrancyReportPanel.currentPanel;
        if (!p) { return; }
        p._panel.reveal();
        p._pendingSelect = packageName;
        if (p._ready) { p._flushPendingSelect(); }
    }

    private _flushPendingSelect(): void {
        if (this._pendingSelect) {
            this._panel.webview.postMessage({ type: 'selectPackage', package: this._pendingSelect });
            this._pendingSelect = null;
        }
    }

    private async _handleMessage(
        msg: { type: string; package?: string; path?: string; line?: number; url?: string; data?: unknown }
            & PaneMessage,
    ): Promise<void> {
        if (msg.type === 'dashboardReady') {
            this._ready = true;
            this._flushPendingSelect();
            return;
        }

        if (msg.type === 'requestPackageDetail' && msg.package) {
            /* Master-detail: hand the selected package to the pane controller,
               which renders its rich body and runs the lazy fetches. */
            const result = this._options?.results.find(r => r.package.name === msg.package);
            if (result) { this._pane?.select(result); }
            return;
        }

        /* Pane actions (navigation, upgrade, review status/notes, retry) are
           owned by the pane controller — it holds the selected package + review
           state. openFile is the pane's own message; openFileRef below is the
           dashboard table's. */
        if (this._pane && (
            msg.type === 'openUrl' || msg.type === 'openFile' || msg.type === 'upgrade'
            || msg.type === 'setReviewStatus' || msg.type === 'addReviewNote'
            || msg.type === 'retryFetches'
        )) {
            await this._pane.handleMessage(msg);
            return;
        }

        if (msg.type === 'openPubspec' && this._pubspecUri) {
            try {
                const uri = vscode.Uri.parse(this._pubspecUri);
                const doc = await vscode.workspace.openTextDocument(uri);
                await vscode.window.showTextDocument(doc);
            } catch {
                /* File may have been moved or workspace closed since render. */
                vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotOpenPubspec'));
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
                vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotOpenPubspec'));
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
               _updateContent, so the rescan button resets naturally.

               Use the `rescan` command (not `scan`) so the per-package
               pub.dev cache is cleared first.  Without this the 24h TTL
               makes "Rescan" a no-op for any package whose entry is still
               within the window — users clicking the button see the same
               stale versions and conclude the button is broken. */
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.rescan');
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
            await this._saveReportJson(msg.data, 'pubspec_vibrancy');
        }

        else if (msg.type === 'saveUpgradeReportJson' && Array.isArray(msg.data)) {
            await this._saveReportJson(msg.data, 'pubspec_upgrade');
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
            vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotOpenFileRef', { filePath }));
        }
    }

    private async _saveReportJson(
        rows: unknown[],
        nameSuffix: string,
    ): Promise<void> {
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
                `${ymd}_${timestamp}${nameSuffix}.json`,
            );
            const content = JSON.stringify(rows, null, 2);
            await vscode.workspace.fs.writeFile(
                file,
                new TextEncoder().encode(content),
            );
            vscode.window.showInformationMessage(l10n('notify.vibrancy.savedReportJson', { path: file.fsPath }));
        } catch {
            vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotSaveReportJson'));
        }
    }

    private _dispose(): void {
        VibrancyReportPanel._currentPanel = undefined;
        this._pane?.dispose();
        this._pane = null;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

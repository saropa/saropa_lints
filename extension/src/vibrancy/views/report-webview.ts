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
import { escapeHtml } from './html-utils';
import { reportsUri } from '../../reportsPaths';
// Phase 5 Settings tab: the flat key list to read from config, plus the
// grouping helper that turns raw values into the shape report-html.ts renders.
import { ALL_VIBRANCY_SETTING_KEYS, buildVibrancySettingGroups } from './settings-tab';
// Full report tab embed (PLAN_ext_ui_package_tabs.md §4 Tab 4, §5 step 1 -- the first tab
// converted, easiest per the plan's own complexity audit): the model builder needs an async
// project-source scan, so it is computed lazily here (not inside report-html.ts, which must stay
// a pure synchronous renderer) and cached until the next rescan invalidates it.
import { buildFeatureInventoryReport } from '../services/feature-inventory-export';
import { getEmbeddedBodyHtml as getFeatureInventoryEmbeddedBodyHtml } from './feature-inventory-html';
import { FeatureInventoryReport } from '../services/feature-inventory-types';
// Upgrades tab embed (PLAN_ext_ui_package_tabs.md §4 Tab 3, §5 step 2): same lazy-build-and-cache
// shape as the Full report tab above -- `buildOpportunityCards` also runs an async project-source
// scan. `handleOpportunitiesEmbeddedMessage` mirrors `OpportunitiesPanel`'s own message switch so
// actions taken from the embedded tab behave identically to the standalone panel.
import {
    buildOpportunityCards, handleOpportunitiesEmbeddedMessage,
} from './opportunities-panel';
// OpportunityCardData is declared in opportunities-html.ts (the HTML builder that defines its
// shape) and only imported, not re-exported, by opportunities-panel.ts -- pull the type from its
// declaring module instead of adding a re-export shim that would give it two import paths.
import { getEmbeddedBodyHtml as getUpgradesEmbeddedBodyHtml, OpportunityCardData } from './opportunities-html';
// Known issues tab embed (PLAN_ext_ui_package_tabs.md §4 Tab 5): reuses the SAME workspaceState
// key and message-type names KnownIssuesPanel already uses for its own standalone recent-searches
// persistence, so a search recorded from either surface shows up as "recent" in the other.
import { KNOWN_ISSUES_RECENT_WS_KEY } from './known-issues-webview';

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

    /* Cached Feature Inventory model for the embedded "Full report" tab. Null until the first
       async build completes; reset to null on every _updateContent (fresh scan results, or the
       panel reopening) so the embed never shows a report computed from a stale package list. */
    private _featureInventoryReport: FeatureInventoryReport | null = null;
    /* True while `_buildFeatureInventoryReport` is in flight, so a tab-bar switch or another
       refresh in the meantime does not kick off a second concurrent source scan. */
    private _featureInventoryBuildInFlight = false;

    /* Cached Upgrade Opportunities cards for the embedded "Upgrades" tab. Same lifecycle as the
       Feature Inventory fields above: null on every _updateContent, rebuilt lazily on first
       request, kept until the next fresh scan invalidates it. */
    private _opportunityCards: readonly OpportunityCardData[] | null = null;
    private _opportunityBuildInFlight = false;

    /* Services for the detail pane, injected once at activation so the panel
       can run the same lazy fetches + review persistence the standalone panel
       did. Static because the panel is a singleton recreated across rescans. */
    private static _reviewState: ReviewStateService | undefined;
    private static _cache: CacheService | undefined;
    /* Known issues tab embed (PLAN_ext_ui_package_tabs.md §4 Tab 5): the recent-searches
       persistence needs `workspaceState`, which only an ExtensionContext exposes -- injected the
       same way as the review-state/cache services above rather than threaded through
       ReportOptions (it is host wiring, not renderer input). */
    private static _extensionContext: vscode.ExtensionContext | undefined;

    /** Wire the detail-pane services (and, since Tab 5, the extension context for the Known
     *  issues embed's recent-searches persistence). Call once during activation. */
    static configure(
        reviewState: ReviewStateService, cache?: CacheService,
        extensionContext?: vscode.ExtensionContext,
    ): void {
        VibrancyReportPanel._reviewState = reviewState;
        VibrancyReportPanel._cache = cache;
        VibrancyReportPanel._extensionContext = extensionContext;
    }

    /** Show the in-dashboard progress bar (indeterminate) when a scan begins.
     *  No-op if the panel is closed — the toast still covers that case. */
    static postScanStarted(): void {
        VibrancyReportPanel.currentPanel?._panel.webview.postMessage({ type: 'scanStarted' });
    }

    /** Drive the determinate fill + phase label from the scan's progress sink. */
    static postScanProgress(percent: number, message: string): void {
        VibrancyReportPanel.currentPanel?._panel.webview.postMessage({
            type: 'scanProgress', percent, message,
        });
    }

    /** Hide the progress bar. The happy path also rebuilds the panel HTML via
     *  publishResults; this covers the cancel/abort path where no rebuild runs. */
    static postScanFinished(): void {
        VibrancyReportPanel.currentPanel?._panel.webview.postMessage({ type: 'scanFinished' });
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
                message => this._panel.webview.postMessage(message),
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
        /* Settings tab (Phase 5): read every managed packageVibrancy.* key
           fresh on each render so the form always reflects the current
           workspace settings, including edits made outside the dashboard
           (Settings UI, settings.json, another window). Cheap -- 54 sync
           config reads, no I/O. */
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const rawValues: Record<string, unknown> = {};
        for (const key of ALL_VIBRANCY_SETTING_KEYS) {
            rawValues[key] = config.get(key);
        }
        /* Fresh options (new scan results, or the panel simply reopening) means any cached Full
           report model is for the OLD package list -- drop it so the embed rebuilds from the
           current `options.results` rather than silently showing stale data next to a table that
           just refreshed. */
        this._featureInventoryReport = null;
        this._featureInventoryBuildInFlight = false;
        // Same invalidation reasoning as Feature Inventory above, for the Upgrades tab's cards.
        this._opportunityCards = null;
        this._opportunityBuildInFlight = false;
        // Assign _options BEFORE calling the embed builders: both
        // `_getFullReportEmbed` and `_getUpgradesEmbed` fire async builders
        // (`_buildFeatureInventoryReport`, `_buildOpportunityCardsReport`)
        // that synchronously snapshot `this._options` before their first
        // `await`.  If we called them inside the object literal, they would
        // read the OLD _options (or null on first open), causing the Full
        // report tab to show "Generating…" forever and the Upgrades tab to
        // render stale data from the previous scan.
        this._options = {
            ...options,
            vibrancySettingGroups: buildVibrancySettingGroups(rawValues),
        };
        // Now _options carries the current scan results, so the builders
        // will snapshot the right data when they fire.
        this._options = {
            ...this._options,
            fullReportBodyHtml: this._getFullReportEmbed(),
            upgradesBodyHtml: this._getUpgradesEmbed(),
        };
        /* New HTML means the script re-inits; wait for its ready signal again
           before flushing any queued package selection. */
        this._ready = false;
        this._panel.webview.html = buildReportHtml(this._options);
    }

    /**
     * Returns the Full report tab's body HTML to render right now. Always returns a string
     * (never `undefined`) so the tab embeds from the very first render instead of falling back to
     * the old deep-link card while the scan is in flight -- see `getEmbeddedBodyHtml`'s doc
     * comment on `ReportOptions.fullReportBodyHtml` for why `undefined` is reserved for callers
     * that never wire this field at all (existing tests constructing `ReportOptions` directly).
     *
     * Mirrors `AnalysisOptimizerWebviewProvider.getEmbeddedBodyHtml`'s shape: if no report is
     * cached and no build is already running, kick one off (fire-and-forget) and return a loading
     * placeholder now; `_buildFeatureInventoryReport`'s completion re-renders the whole panel,
     * which calls back into this method and gets the real report that time.
     */
    private _getFullReportEmbed(): string {
        if (this._featureInventoryReport) {
            return getFeatureInventoryEmbeddedBodyHtml(this._featureInventoryReport);
        }
        if (!this._featureInventoryBuildInFlight) {
            this._featureInventoryBuildInFlight = true;
            void this._buildFeatureInventoryReport();
        }
        return `<div class="pkg-tab-panel dash-empty" aria-live="polite">
            <p class="dash-empty-body">${escapeHtml(l10n('packageDashboard.tabs.fullReportGenerating'))}</p>
        </div>`;
    }

    /**
     * Runs the async project-source scan (`buildFeatureInventoryReport`) and caches the result,
     * then re-renders the panel so the Full report tab picks up the real content in place of the
     * loading placeholder. Silently leaves the report null on failure (no workspace root, or the
     * scan itself throwing) -- the tab then just keeps showing the loading placeholder rather than
     * an error, matching this report's existing "best-effort" posture elsewhere in this file.
     */
    private async _buildFeatureInventoryReport(): Promise<void> {
        try {
            const options = this._options;
            const root = this._pubspecUri
                ? vscode.Uri.joinPath(vscode.Uri.parse(this._pubspecUri), '..')
                : null;
            if (!root || !options) { return; }
            this._featureInventoryReport = await buildFeatureInventoryReport(
                options.results, root, { extensionVersion: options.extensionVersion },
            );
        } catch {
            /* Best-effort: leave `_featureInventoryReport` null so the tab keeps showing the
               loading placeholder rather than a half-built report or an uncaught rejection. */
        } finally {
            this._featureInventoryBuildInFlight = false;
            /* Re-render now that the async work has settled. On success, swap in the real report;
               on failure, keep whatever was already showing (the loading placeholder) rather than
               calling `_getFullReportEmbed()` again -- that would see `_featureInventoryReport`
               still null and immediately kick off ANOTHER scan, retrying forever on a permanent
               failure (e.g. no workspace root). The next genuine `_updateContent` (rescan, reopen)
               resets both cache fields and gets a fresh attempt. Guard on `_options`/the panel --
               both can go away while the scan was running (panel closed, window reload). */
            if (this._options) {
                if (this._featureInventoryReport) {
                    this._options = {
                        ...this._options,
                        fullReportBodyHtml: getFeatureInventoryEmbeddedBodyHtml(this._featureInventoryReport),
                    };
                }
                // Assigning `.html` again reloads the document, so the client script's
                // `dashboardReady` handshake must run again too (same reasoning as `_updateContent`).
                this._ready = false;
                this._panel.webview.html = buildReportHtml(this._options);
            }
        }
    }

    /**
     * Returns the Upgrades tab's body HTML to render right now. Same shape as
     * {@link _getFullReportEmbed}: a cached result renders immediately, otherwise a build is
     * kicked off (if one is not already running) and a loading placeholder renders in the
     * meantime, replaced in place once {@link _buildOpportunityCardsReport} resolves.
     */
    private _getUpgradesEmbed(): string {
        if (this._opportunityCards) {
            return getUpgradesEmbeddedBodyHtml(this._opportunityCards, this._options?.extensionVersion ?? '');
        }
        if (!this._opportunityBuildInFlight) {
            this._opportunityBuildInFlight = true;
            void this._buildOpportunityCardsReport();
        }
        return `<div class="pkg-tab-panel dash-empty" aria-live="polite">
            <p class="dash-empty-body">${escapeHtml(l10n('packageDashboard.tabs.upgradesGenerating'))}</p>
        </div>`;
    }

    /**
     * Runs the async project-source scan (`buildOpportunityCards`) and caches the result, then
     * re-renders so the Upgrades tab picks up the real cards. Same best-effort failure handling
     * and re-render guarding as {@link _buildFeatureInventoryReport} -- see its doc comment.
     */
    private async _buildOpportunityCardsReport(): Promise<void> {
        try {
            const options = this._options;
            const root = this._pubspecUri
                ? vscode.Uri.joinPath(vscode.Uri.parse(this._pubspecUri), '..')
                : null;
            if (!root || !options) { return; }
            this._opportunityCards = await buildOpportunityCards(
                options.results, root, options.reverseDeps ?? new Map(),
            );
        } catch {
            /* Best-effort: leave `_opportunityCards` null so the tab keeps showing the loading
               placeholder rather than a half-built card list or an uncaught rejection. */
        } finally {
            this._opportunityBuildInFlight = false;
            if (this._options) {
                if (this._opportunityCards) {
                    this._options = {
                        ...this._options,
                        upgradesBodyHtml: getUpgradesEmbeddedBodyHtml(
                            this._opportunityCards, this._options.extensionVersion,
                        ),
                    };
                }
                this._ready = false;
                this._panel.webview.html = buildReportHtml(this._options);
            }
        }
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

    /** Known issues tab embed (PLAN_ext_ui_package_tabs.md §4 Tab 5): pushes any previously
     *  saved recent-search queries into the embedded tab once the client script signals
     *  `dashboardReady` (mirrors `KnownIssuesPanel._hydrateRecent`, run on the same 'ready'
     *  trigger rather than `_updateContent` -- the client would drop a message posted before its
     *  own `message` listener attaches, same reasoning as `_flushPendingSelect`'s queueing). */
    private _hydrateKnownIssuesRecent(): void {
        const queries = VibrancyReportPanel._extensionContext?.workspaceState.get<string[]>(
            KNOWN_ISSUES_RECENT_WS_KEY, [],
        ) ?? [];
        if (queries.length === 0) { return; }
        void this._panel.webview.postMessage({ type: 'hydrateKnownIssuesRecent', queries });
    }

    private async _handleMessage(
        msg: {
            type: string; package?: string; path?: string; line?: number; url?: string;
            data?: unknown; command?: string; key?: string; value?: unknown;
            upgrades?: { type: string; file?: string; line?: number; package?: string };
            queries?: unknown;
        }
            & PaneMessage,
    ): Promise<void> {
        if (msg.type === 'dashboardReady') {
            this._ready = true;
            this._flushPendingSelect();
            this._hydrateKnownIssuesRecent();
            return;
        }

        if (msg.type === 'openTab' && msg.command) {
            /* Deep-link tabs (Full report deep-link fallback, or any tab not yet embedded per
               PLAN_ext_ui_package_tabs.md's incremental rollout): the tab panel is a lightweight
               in-document card, not a copy of the target panel's markup (see packages-tabs.ts doc
               comment for why). Opening it just runs the same command the old standalone
               dashboard row used. */
            await vscode.commands.executeCommand(msg.command);
            return;
        }

        if (msg.type === 'upgradesCommand' && msg.upgrades) {
            /* Embedded Upgrades tab (PLAN_ext_ui_package_tabs.md §4 Tab 3): unwrap and forward to
               the SAME handler `OpportunitiesPanel` uses for its own onDidReceiveMessage, using
               the currently cached card list (built lazily by `_getUpgradesEmbed` -- should
               always be populated by the time a user can click anything in the tab, since the
               buttons only render once the cards exist). */
            const root = this._pubspecUri
                ? vscode.Uri.joinPath(vscode.Uri.parse(this._pubspecUri), '..')
                : null;
            if (!root || !this._opportunityCards) { return; }
            const result = await handleOpportunitiesEmbeddedMessage(
                msg.upgrades, this._opportunityCards, root,
            );
            if (result.reportResult) {
                this._panel.webview.postMessage({
                    type: result.reportResult === 'written' ? 'upgradesReportWritten' : 'upgradesReportFailed',
                });
            }
            return;
        }

        if (msg.type === 'saveKnownIssuesRecent' && Array.isArray(msg.queries)) {
            /* Embedded Known issues tab (PLAN_ext_ui_package_tabs.md §4 Tab 5): mirrors
               KnownIssuesPanel's own onDidReceiveMessage handler exactly (same message name, same
               workspaceState key) so recent searches persist identically whether the user typed
               them in the embedded tab or the standalone panel. */
            const qs = msg.queries
                .filter((q): q is string => typeof q === 'string')
                .slice(0, 12);
            void VibrancyReportPanel._extensionContext?.workspaceState.update(
                KNOWN_ISSUES_RECENT_WS_KEY, qs,
            );
            return;
        }

        if (msg.type === 'updateVibrancySetting' && msg.key !== undefined) {
            /* Settings tab (Phase 5): write straight through to the real
               setting, Workspace-scoped like the rest of the codebase's
               config writers (see setup.ts's tier/enabled writers). No
               re-render is triggered here -- the next createOrShow/rescan
               will pick up the new value via _updateContent's fresh read. */
            await vscode.workspace.getConfiguration('saropaLints.packageVibrancy')
                .update(msg.key, msg.value, vscode.ConfigurationTarget.Workspace);
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

        else if (msg.type === 'rescanAndCheckUpdates') {
            /* "Scanned X ago" pill: a full refresh from the user's point of view —
               rescan the dashboard (same fresh path as the toolbar Rescan), then
               re-run the pub.dev upgrade check so the "Update available"
               notification re-surfaces. checkForUpdatesNow clears the upgrade
               throttle, which is why this can re-prompt where the passive
               background check cannot. showReport runs before the update check so
               the dashboard repaints (resetting the pill's disabled state) without
               waiting on the network call. */
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.rescan');
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.showReport');
            await vscode.commands.executeCommand('saropaLints.checkForUpdatesNow');
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
            // Shared helper builds the `reports/` prefix; append the day-partitioned subdir.
            const dir = vscode.Uri.joinPath(reportsUri(workspaceFolder.uri), ymd);
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

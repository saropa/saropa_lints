import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { ReviewStateService } from '../services/review-state';
import { buildPackageDetailHtml } from './package-detail-html';
import { fetchVersionGap } from '../services/github-version-gap';
import { getVersionGapEnabled, getGithubToken } from '../services/config-service';
import { CacheService } from '../services/cache-service';
import { extractGitHubRepo } from '../services/github-api';

const PANEL_ID = 'saropaPackageDetail';

/**
 * Full-detail webview panel for a single package.
 * Opens in the editor area with all vibrancy data and version-gap review checklist.
 */
export class PackageDetailPanel {
    public static currentPanel: PackageDetailPanel | undefined;

    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];
    private _result: VibrancyResult;
    private readonly _reviewState: ReviewStateService;
    private readonly _cache: CacheService | undefined;

    private constructor(
        panel: vscode.WebviewPanel,
        result: VibrancyResult,
        reviewState: ReviewStateService,
        cache?: CacheService,
    ) {
        this._panel = panel;
        this._result = result;
        this._reviewState = reviewState;
        this._cache = cache;

        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
        this._panel.webview.onDidReceiveMessage(
            msg => this._handleMessage(msg),
            null,
            this._disposables,
        );

        this._render();

        // Lazy-fetch version gap data if enabled
        if (getVersionGapEnabled()) {
            this._fetchAndRenderGap();
        }
    }

    /** Show the detail panel for a package, creating or revealing as needed. */
    static createOrShow(
        result: VibrancyResult,
        reviewState: ReviewStateService,
        cache?: CacheService,
    ): void {
        if (PackageDetailPanel.currentPanel) {
            PackageDetailPanel.currentPanel._result = result;
            PackageDetailPanel.currentPanel._panel.reveal();
            PackageDetailPanel.currentPanel._render();
            if (getVersionGapEnabled()) {
                PackageDetailPanel.currentPanel._fetchAndRenderGap();
            }
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            PANEL_ID,
            `${result.package.name} — Details`,
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        PackageDetailPanel.currentPanel = new PackageDetailPanel(
            panel, result, reviewState, cache,
        );
    }

    private _render(): void {
        const reviews = this._reviewState.getReviews(
            this._result.package.name,
            this._result.package.version,
        );
        const gapItems = this._result.versionGap?.items.length ?? 0;
        const summary = gapItems > 0
            ? this._reviewState.getSummary(
                this._result.package.name,
                this._result.package.version,
                gapItems,
            )
            : null;

        this._panel.title = `${this._result.package.name} — Details`;
        this._panel.webview.html = buildPackageDetailHtml(
            this._result, reviews, summary,
        );
    }

    /**
     * Fetch version-gap data on demand, then re-render the panel.
     * The panel opens immediately; the gap section shows a spinner until data arrives.
     * Guards against stale fetches: if the user switches packages while a fetch is
     * in flight, the stale result is discarded instead of overwriting the new one.
     */
    private async _fetchAndRenderGap(): Promise<void> {
        const r = this._result;
        if (!r.updateInfo || r.updateInfo.updateStatus === 'up-to-date') { return; }

        const repoUrl = r.github?.repoUrl ?? r.pubDev?.repositoryUrl;
        if (!repoUrl) { return; }

        const parsed = extractGitHubRepo(repoUrl);
        if (!parsed) { return; }

        const token = getGithubToken() || undefined;
        const params = {
            token,
            cache: this._cache,
            packageName: r.package.name,
        };

        // Capture identity before async work to detect stale results
        const fetchTarget = r.package.name + '@' + r.package.version;

        try {
            // Fetch the main version gap (constraint version → latest)
            const gap = await fetchVersionGap(
                parsed.owner, parsed.repo,
                r.package.version, r.updateInfo.latestVersion,
                params,
            );

            // Guard: discard if user switched to a different package while fetching
            const currentTarget = this._result.package.name + '@' + this._result.package.version;
            if (fetchTarget !== currentTarget) { return; }

            // Update the result with gap data and re-render
            this._result = { ...this._result, versionGap: gap };
            this._render();
        } catch {
            // Silently fail — panel still shows everything except gap section
        }
    }

    private async _handleMessage(message: PanelMessage): Promise<void> {
        switch (message.type) {
            case 'openUrl':
                if (message.url) {
                    await vscode.env.openExternal(vscode.Uri.parse(message.url));
                }
                break;

            case 'upgrade':
                if (message.name && message.version) {
                    await vscode.commands.executeCommand(
                        'saropaLints.packageVibrancy.updateFromCodeLens',
                        { name: message.name, targetVersion: message.version },
                    );
                }
                break;

            case 'setReviewStatus':
                if (message.itemNumber !== undefined && message.status) {
                    await this._reviewState.setReview(
                        this._result.package.name,
                        this._result.package.version,
                        message.itemNumber,
                        message.status,
                    );
                }
                break;

            case 'addReviewNote':
                if (message.itemNumber !== undefined && message.notes !== undefined) {
                    // Preserve existing status when just updating notes
                    const existing = this._reviewState.getReviews(
                        this._result.package.name,
                        this._result.package.version,
                    );
                    const current = existing.find(e => e.itemNumber === message.itemNumber);
                    await this._reviewState.setReview(
                        this._result.package.name,
                        this._result.package.version,
                        message.itemNumber,
                        current?.status ?? 'reviewed',
                        message.notes,
                    );
                }
                break;
        }
    }

    private _dispose(): void {
        PackageDetailPanel.currentPanel = undefined;
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

interface PanelMessage {
    readonly type: string;
    readonly url?: string;
    readonly name?: string;
    readonly version?: string;
    readonly itemNumber?: number;
    readonly status?: 'unreviewed' | 'reviewed' | 'applicable' | 'not-applicable';
    readonly notes?: string;
}

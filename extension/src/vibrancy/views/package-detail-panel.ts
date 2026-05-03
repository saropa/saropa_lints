import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { ReviewStateService } from '../services/review-state';
import { buildPackageDetailHtml } from './package-detail-html';
import { fetchVersionGap } from '../services/github-version-gap';
import { getVersionGapEnabled, getGithubToken } from '../services/config-service';
import { CacheService } from '../services/cache-service';
import { extractGitHubRepo, fetchReadmeImages } from '../services/github-api';
import { fetchReverseDependencyCount } from '../services/pub-dev-api';
import { openFileAtLine } from './view-actions';

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
    /** Timer handle for debouncing rapid sequential re-renders from lazy fetches. */
    private _renderTimer: ReturnType<typeof setTimeout> | undefined;
    /**
     * Per-fetch error state surfaced via the partial-state banner (§8.16.3).
     * Each lazy fetch independently sets its flag on catch; the banner shows
     * when any flag is true. Reset by `retryFetches`.
     */
    private _fetchErrors: { readme: boolean; gap: boolean; reverseDeps: boolean } = {
        readme: false, gap: false, reverseDeps: false,
    };
    /** Last retry timestamp for spam-protection (§A5 risk note: 2s debounce). */
    private _lastRetryAt = 0;

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

        // Lazy-fetch additional data in parallel (version gap, README images)
        this._fetchLazyData();
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
            PackageDetailPanel.currentPanel._fetchLazyData();
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            PANEL_ID,
            `Saropa Package: ${result.package.name}`,
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );

        PackageDetailPanel.currentPanel = new PackageDetailPanel(
            panel, result, reviewState, cache,
        );
    }

    /**
     * Schedule a render after a short delay to batch rapid updates from
     * multiple lazy fetches resolving close together. Reduces visible
     * flicker from sequential full-page HTML replacements.
     */
    private _scheduleRender(): void {
        if (this._renderTimer) { clearTimeout(this._renderTimer); }
        this._renderTimer = setTimeout(() => {
            this._renderTimer = undefined;
            this._render();
        }, 100);
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
            this._result, reviews, summary, this._fetchErrors,
        );
    }

    /**
     * Launch all lazy data fetches in parallel. Each one independently
     * updates the result and re-renders when its data arrives.
     */
    private _fetchLazyData(): void {
        if (getVersionGapEnabled()) {
            this._fetchAndRenderGap();
        }
        this._fetchAndRenderReadme();
        this._fetchAndRenderReverseDeps();
    }

    /**
     * Fetch reverse dependency count from pub.dev, then re-render.
     * This scrapes pub.dev HTML so it runs lazily when the panel opens.
     */
    private async _fetchAndRenderReverseDeps(): Promise<void> {
        const r = this._result;
        // Skip if the scan already populated the count — avoids a redundant
        // fetch and re-render when the data arrived during the scan phase.
        if (r.reverseDependencyCount !== null) { return; }
        const fetchTarget = r.package.name + '@' + r.package.version;

        try {
            const count = await fetchReverseDependencyCount(
                r.package.name, this._cache,
            );

            // Guard: discard if user switched to a different package while fetching
            const currentTarget = this._result.package.name + '@' + this._result.package.version;
            if (fetchTarget !== currentTarget) { return; }

            if (count !== null) {
                this._result = { ...this._result, reverseDependencyCount: count };
                this._fetchErrors = { ...this._fetchErrors, reverseDeps: false };
                this._scheduleRender();
            }
        } catch {
            // §8.16.3 — surface the failure via the partial-state banner
            // instead of silently dropping it. The retry button on the
            // banner re-runs all lazy fetches.
            this._fetchErrors = { ...this._fetchErrors, reverseDeps: true };
            this._scheduleRender();
        }
    }

    /**
     * Fetch README from GitHub and extract logo + images, then re-render.
     * Guards against stale fetches when the user switches packages mid-flight.
     */
    private async _fetchAndRenderReadme(): Promise<void> {
        const r = this._result;
        const repoUrl = r.github?.repoUrl ?? r.pubDev?.repositoryUrl;
        if (!repoUrl) { return; }

        const parsed = extractGitHubRepo(repoUrl);
        if (!parsed) { return; }

        const token = getGithubToken() || undefined;
        const fetchTarget = r.package.name + '@' + r.package.version;

        try {
            const readme = await fetchReadmeImages(
                parsed.owner, parsed.repo,
                { token, cache: this._cache },
            );

            // Guard: discard if user switched to a different package while fetching
            const currentTarget = this._result.package.name + '@' + this._result.package.version;
            if (fetchTarget !== currentTarget) { return; }

            if (readme) {
                this._result = { ...this._result, readme };
                this._fetchErrors = { ...this._fetchErrors, readme: false };
                this._scheduleRender();
            }
        } catch {
            // §8.16.3 — surface README fetch failures via the banner.
            this._fetchErrors = { ...this._fetchErrors, readme: true };
            this._scheduleRender();
        }
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
            this._fetchErrors = { ...this._fetchErrors, gap: false };
            this._scheduleRender();
        } catch {
            // §8.16.3 — surface gap fetch failures via the banner.
            this._fetchErrors = { ...this._fetchErrors, gap: true };
            this._scheduleRender();
        }
    }

    private async _handleMessage(message: PanelMessage): Promise<void> {
        switch (message.type) {
            case 'retryFetches':
                this._handleRetryFetches();
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

    /**
     * §8.16.3 — Retry the lazy fetches that previously failed. Debounced to
     * 2s so a runaway click on the banner doesn't spam pubdev or GitHub.
     */
    private _handleRetryFetches(): void {
        const now = Date.now();
        if (now - this._lastRetryAt < 2000) { return; }
        this._lastRetryAt = now;
        this._fetchErrors = { readme: false, gap: false, reverseDeps: false };
        this._scheduleRender();
        this._fetchLazyData();
    }

    private _dispose(): void {
        PackageDetailPanel.currentPanel = undefined;
        if (this._renderTimer) { clearTimeout(this._renderTimer); }
        for (const d of this._disposables) {
            d.dispose();
        }
        this._disposables = [];
    }
}

interface PanelMessage {
    readonly type: string;
    readonly url?: string;
    readonly path?: string;
    readonly line?: number;
    readonly name?: string;
    readonly version?: string;
    readonly itemNumber?: number;
    readonly status?: 'unreviewed' | 'reviewed' | 'applicable' | 'not-applicable';
    readonly notes?: string;
}

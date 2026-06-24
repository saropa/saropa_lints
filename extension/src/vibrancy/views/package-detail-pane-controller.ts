/**
 * Host-side controller for the Package Dashboard's docked detail pane.
 *
 * This is the master-detail counterpart of [PackageDetailPanel]: it owns the
 * currently-selected package's mutable result, runs the same lazy fetches
 * (version gap, README images, reverse-dependency count), and tracks review
 * state — but instead of setting a panel's `webview.html`, it renders the detail
 * BODY via [buildPackageDetailBody] and pushes it to the dashboard webview
 * through a `post` callback, which injects it into the pane. Keeping this out of
 * report-webview.ts keeps that file focused on the dashboard shell.
 */
import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { ReviewStateService } from '../services/review-state';
import { CacheService } from '../services/cache-service';
import { buildPackageDetailBody } from './package-detail-html';
import { fetchVersionGap } from '../services/github-version-gap';
import { getVersionGapEnabled, getGithubToken } from '../services/config-service';
import { extractGitHubRepo, fetchReadmeImages } from '../services/github-api';
import { fetchReverseDependencyCount } from '../services/pub-dev-api';
import { openFileAtLine } from './view-actions';

/** Messages the pane's client delegation posts back for the selected package. */
export interface PaneMessage {
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

export class PackageDetailPaneController {
    /** The package currently shown in the pane; mutated as lazy fetches land. */
    private _result: VibrancyResult | null = null;
    private _fetchErrors = { readme: false, gap: false, reverseDeps: false };
    private _renderTimer: ReturnType<typeof setTimeout> | undefined;
    private _lastRetryAt = 0;

    /**
     * @param _post  Posts a message to the dashboard webview. Carries both the
     *   rendered detail body (`packageDetailHtml`) and pane action status
     *   (`paneAction` busy/done) so the pane can reflect a long upgrade in place.
     * @param _reviewState  Persists per-item PR/issue review status + notes.
     * @param _cache  Shared HTTP cache for the lazy fetches (optional).
     */
    constructor(
        private readonly _post: (message: { type: string; [key: string]: unknown }) => void,
        private readonly _reviewState: ReviewStateService,
        private readonly _cache?: CacheService,
    ) {}

    /** Identity token used to discard fetches that resolve after the user
     *  switched to a different package. */
    private _target(): string {
        return this._result
            ? `${this._result.package.name}@${this._result.package.version}`
            : '';
    }

    /** Select a package: render immediately from scanned data, then lazy-fetch. */
    select(result: VibrancyResult): void {
        this._result = result;
        this._fetchErrors = { readme: false, gap: false, reverseDeps: false };
        this._render();
        this._fetchLazyData();
    }

    private _render(): void {
        if (!this._result) { return; }
        const r = this._result;
        const reviews = this._reviewState.getReviews(r.package.name, r.package.version);
        const gapItems = r.versionGap?.items.length ?? 0;
        const summary = gapItems > 0
            ? this._reviewState.getSummary(r.package.name, r.package.version, gapItems)
            : null;
        const html = buildPackageDetailBody(r, reviews, summary, this._fetchErrors, { paneMode: true });
        this._post({ type: 'packageDetailHtml', package: r.package.name, html });
    }

    /** Debounce re-renders so several lazy fetches landing together don't
     *  replace the pane body multiple times in a frame. */
    private _scheduleRender(): void {
        if (this._renderTimer) { clearTimeout(this._renderTimer); }
        this._renderTimer = setTimeout(() => {
            this._renderTimer = undefined;
            this._render();
        }, 100);
    }

    private _fetchLazyData(): void {
        if (getVersionGapEnabled()) { void this._fetchGap(); }
        void this._fetchReadme();
        void this._fetchReverseDeps();
    }

    private async _fetchReverseDeps(): Promise<void> {
        const r = this._result;
        if (!r || r.reverseDependencyCount !== null) { return; }
        const target = this._target();
        try {
            const count = await fetchReverseDependencyCount(r.package.name, this._cache);
            if (target !== this._target()) { return; }
            if (count !== null) {
                this._result = { ...this._result!, reverseDependencyCount: count };
                this._fetchErrors = { ...this._fetchErrors, reverseDeps: false };
                this._scheduleRender();
            }
        } catch {
            this._fetchErrors = { ...this._fetchErrors, reverseDeps: true };
            this._scheduleRender();
        }
    }

    private async _fetchReadme(): Promise<void> {
        const r = this._result;
        if (!r) { return; }
        const repoUrl = r.github?.repoUrl ?? r.pubDev?.repositoryUrl;
        const parsed = repoUrl ? extractGitHubRepo(repoUrl) : null;
        if (!parsed) { return; }
        const target = this._target();
        try {
            const readme = await fetchReadmeImages(parsed.owner, parsed.repo, {
                token: getGithubToken() || undefined, cache: this._cache,
            });
            if (target !== this._target()) { return; }
            if (readme) {
                this._result = { ...this._result!, readme };
                this._fetchErrors = { ...this._fetchErrors, readme: false };
                this._scheduleRender();
            }
        } catch {
            this._fetchErrors = { ...this._fetchErrors, readme: true };
            this._scheduleRender();
        }
    }

    private async _fetchGap(): Promise<void> {
        const r = this._result;
        if (!r || !r.updateInfo || r.updateInfo.updateStatus === 'up-to-date') { return; }
        const repoUrl = r.github?.repoUrl ?? r.pubDev?.repositoryUrl;
        const parsed = repoUrl ? extractGitHubRepo(repoUrl) : null;
        if (!parsed) { return; }
        const target = this._target();
        try {
            const gap = await fetchVersionGap(
                parsed.owner, parsed.repo,
                r.package.version, r.updateInfo.latestVersion,
                { token: getGithubToken() || undefined, cache: this._cache, packageName: r.package.name },
            );
            if (target !== this._target()) { return; }
            this._result = { ...this._result!, versionGap: gap };
            this._fetchErrors = { ...this._fetchErrors, gap: false };
            this._scheduleRender();
        } catch {
            this._fetchErrors = { ...this._fetchErrors, gap: true };
            this._scheduleRender();
        }
    }

    /** Handle a pane action (navigation, upgrade, review, retry). */
    async handleMessage(msg: PaneMessage): Promise<void> {
        const r = this._result;
        switch (msg.type) {
            case 'openUrl':
                if (msg.url) { await vscode.env.openExternal(vscode.Uri.parse(msg.url)); }
                break;
            case 'openFile':
                if (msg.path) { await openFileAtLine(msg.path, msg.line ?? 1); }
                break;
            case 'upgrade':
                if (msg.name && msg.version) {
                    // pub get + full test suite is multi-minute. Flag the pane's
                    // Upgrade button busy across the whole run so it doesn't look
                    // idle, and clear it in `finally` so a failed/rolled-back
                    // upgrade (no dashboard rebuild) still re-enables the button.
                    this._post({ type: 'paneAction', action: 'upgrade', state: 'busy' });
                    try {
                        await vscode.commands.executeCommand(
                            'saropaLints.packageVibrancy.updateFromCodeLens',
                            { name: msg.name, targetVersion: msg.version },
                        );
                    } finally {
                        this._post({ type: 'paneAction', action: 'upgrade', state: 'done' });
                    }
                }
                break;
            case 'setReviewStatus':
                if (r && msg.itemNumber !== undefined && msg.status) {
                    await this._reviewState.setReview(
                        r.package.name, r.package.version, msg.itemNumber, msg.status,
                    );
                }
                break;
            case 'addReviewNote':
                if (r && msg.itemNumber !== undefined && msg.notes !== undefined) {
                    const existing = this._reviewState.getReviews(r.package.name, r.package.version);
                    const current = existing.find(e => e.itemNumber === msg.itemNumber);
                    await this._reviewState.setReview(
                        r.package.name, r.package.version, msg.itemNumber,
                        current?.status ?? 'reviewed', msg.notes,
                    );
                }
                break;
            case 'retryFetches':
                this._handleRetry();
                break;
        }
    }

    /** Re-run failed fetches, debounced to 2s so a runaway click can't spam
     *  pub.dev / GitHub. */
    private _handleRetry(): void {
        const now = Date.now();
        if (now - this._lastRetryAt < 2000) { return; }
        this._lastRetryAt = now;
        this._fetchErrors = { readme: false, gap: false, reverseDeps: false };
        this._scheduleRender();
        this._fetchLazyData();
    }

    dispose(): void {
        if (this._renderTimer) { clearTimeout(this._renderTimer); }
    }
}

/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 *
 * Shared leaf helpers for the package-vibrancy report view. The repo-URL
 * resolution and age/activity math here are imported by BOTH the table-cell
 * builders (report-html-table.ts) and the copy-as-JSON data builders
 * (report-html-data.ts), so they live in their own module rather than being
 * duplicated or forcing a table->data import. ReportOptions is the report's
 * input shape; it is re-exported from the report-html.ts composer so existing
 * importers keep their paths.
 */

import { VibrancyResult } from '../types';
import { scoreToGrade } from '../scoring/status-classifier';
import { l10n } from '../../i18n/runtime';

/** Options passed to the report builder beyond just results. */
export interface ReportOptions {
    readonly results: VibrancyResult[];
    readonly overrideCount: number;
    /** Names of packages that have dependency_overrides entries. */
    readonly overrideNames: ReadonlySet<string>;
    readonly pubspecUri: string | null;
    /** Extension version from package.json, shown next to the report title. */
    readonly extensionVersion: string;
    /** Optional per-package score history for inline sparkline rendering. */
    readonly packageTrends?: ReadonlyMap<string, number[]>;
    /**
     * True when a scan is currently in progress.  Used by `buildReportHtml`
     * to show a "Scan in progress" placeholder when there are no results
     * yet — without it the dashboard would render `0 packages`, `Grade E`,
     * an empty radial gauge, and an empty table, which looks broken to a
     * first-time user whose initial scan is still running.  When prior
     * results exist the dashboard keeps rendering them (stale but
     * meaningful) and the open panel auto-refreshes when the scan
     * completes via `publishResults`.
     */
    readonly isScanning?: boolean;
    // Wall-clock ms-since-epoch the displayed data was scanned at.  Drives
    // the "Scanned X ago" pill in the hero status line so users can tell at
    // a glance whether a Rescan click actually produced fresh data — without
    // it, the dashboard re-rendering with identical numbers reads as "rescan
    // did nothing" even when a scan really did run.  Undefined ⇒ no scan
    // has completed since the panel opened, or the displayed data came from
    // a pre-timestamp persisted snapshot.
    readonly lastScanTimestamp?: number;
}

/** Resolve the canonical repository URL (trailing slashes stripped). */
export function resolveRepoUrl(r: VibrancyResult): string | undefined {
    return (r.github?.repoUrl ?? r.pubDev?.repositoryUrl)
        ?.replace(/\/+$/, '');
}

export function daysSinceIsoDate(isoDate: string | null | undefined): number | undefined {
    if (!isoDate) { return undefined; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return undefined; }
    return Math.max(0, Math.floor((Date.now() - ms) / 86_400_000));
}

export function formatAgeFromDays(days: number): string {
    if (days < 30) { return `${days}d`; }
    if (days < 365) { return `${Math.floor(days / 30)}mo`; }
    return `${Math.floor(days / 365)}y`;
}

export function buildDormancyStatus(
    commitAgeDays: number | undefined,
    publishAgeDays: number | undefined,
): string | null {
    if (commitAgeDays === undefined || publishAgeDays === undefined) {
        return null;
    }
    if (commitAgeDays >= 180 && publishAgeDays >= 180) {
        return l10n('packageDashboard.dormancy.noActivity6mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays >= 90) {
        return l10n('packageDashboard.dormancy.noActivity3mo');
    }
    if (commitAgeDays >= 90 && publishAgeDays < 90) {
        return l10n('packageDashboard.dormancy.releaseActiveCodeInactive');
    }
    if (commitAgeDays < 90 && publishAgeDays >= 90) {
        return l10n('packageDashboard.dormancy.codeActiveReleaseSlow');
    }
    return null;
}

export function computeActivitySignal(r: VibrancyResult): {
    score: number | null;
    grade: ReturnType<typeof scoreToGrade> | null;
    message: string | null;
    sortValue: string;
} {
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    const commitAgeDays = r.github?.daysSinceLastCommit;
    if (publishAgeDays === undefined || commitAgeDays === undefined) {
        return { score: null, grade: null, message: null, sortValue: '' };
    }
    // Activity score focuses on "is code/release work still happening now?"
    // so both timelines use a 90-day decay and the worst leg dominates.
    const commitScore = Math.max(0, 100 - (commitAgeDays * 100 / 90));
    const releaseScore = Math.max(0, 100 - (publishAgeDays * 100 / 90));
    const score = Math.round(Math.min(commitScore, releaseScore));
    const grade = scoreToGrade(score);
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    const message = dormancy
        ? l10n('packageDashboard.activity.withDormancy', { dormancy, grade })
        : l10n('packageDashboard.activity.healthy', { grade });
    return { score, grade, message, sortValue: String(score) };
}

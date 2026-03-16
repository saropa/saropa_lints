import * as vscode from 'vscode';
import { VibrancyResult, FlaggedIssue } from '../types';
import { categoryLabel } from '../scoring/status-classifier';
import { isReplacementPackageName, getReplacementDisplayText } from '../scoring/known-issues';
import { formatSizeMB } from '../scoring/bloat-calculator';

/** Output channel name for package details logging. */
export const DETAIL_CHANNEL_NAME = 'Vibrancy Details';

/** Manages logging of package details to a dedicated output channel. */
export class DetailLogger {
    private readonly _channel: vscode.OutputChannel;

    constructor(channel: vscode.OutputChannel) {
        this._channel = channel;
    }

    /** Log details for a single package. */
    logPackage(result: VibrancyResult): void {
        const timestamp = formatTimestamp();
        this._logWithTimestamp(timestamp, '═'.repeat(50));
        this._logPackageContent(result, timestamp);
    }

    /** Log details for all packages from a scan. */
    logAllPackages(results: readonly VibrancyResult[]): void {
        if (results.length === 0) {
            return;
        }

        const timestamp = formatTimestamp();
        this._logWithTimestamp(timestamp, '══════════════════════════════════════════════════');
        this._logWithTimestamp(timestamp, `SCAN RESULTS — ${results.length} packages`);
        this._logWithTimestamp(timestamp, '══════════════════════════════════════════════════');
        this._logWithTimestamp(timestamp, '');

        for (const result of results) {
            this._logPackageContent(result, timestamp);
            this._logWithTimestamp(timestamp, '');
        }
    }

    /** Show the output channel. */
    show(): void {
        this._channel.show(true);
    }

    /** Clear the output channel. */
    clear(): void {
        this._channel.clear();
    }

    private _logPackageContent(result: VibrancyResult, timestamp: string): void {
        const displayScore = Math.round(result.score / 10);
        const catLabel = categoryLabel(result.category);

        this._logWithTimestamp(timestamp, `${result.package.name} — ${displayScore}/10 (${catLabel})`);
        this._logWithTimestamp(timestamp, '─'.repeat(50));

        this._logVersionInfo(result, timestamp);
        this._logUpdateInfo(result, timestamp);
        this._logSuggestions(result, timestamp);
        this._logCommunityInfo(result, timestamp);
        this._logAlerts(result, timestamp);
    }

    private _logVersionInfo(result: VibrancyResult, timestamp: string): void {
        const current = result.package.constraint || result.package.version;
        const latest = result.updateInfo?.latestVersion;

        if (latest && result.updateInfo?.updateStatus !== 'up-to-date') {
            this._logWithTimestamp(timestamp, `Version: ${current} → ${latest} available (${result.updateInfo.updateStatus})`);
        } else {
            this._logWithTimestamp(timestamp, `Version: ${current}`);
        }

        if (result.pubDev?.publishedDate) {
            const date = result.pubDev.publishedDate.split('T')[0];
            this._logWithTimestamp(timestamp, `Published: ${date}`);
        }

        if (result.license) {
            this._logWithTimestamp(timestamp, `License: ${result.license}`);
        }

        if (result.archiveSizeBytes !== null) {
            this._logWithTimestamp(timestamp, `Size: ${formatSizeMB(result.archiveSizeBytes)}`);
        }
    }

    private _logUpdateInfo(result: VibrancyResult, timestamp: string): void {
        if (!result.updateInfo || result.updateInfo.updateStatus === 'up-to-date') {
            return;
        }

        this._logWithTimestamp(timestamp, '');

        if (result.blocker) {
            this._logWithTimestamp(timestamp, '⚠️ Upgrade Blocked:');
            this._logIndented(timestamp, `Blocked by ${result.blocker.blockerPackage}`);
            if (result.blocker.blockerVibrancyScore !== null) {
                const blockerScore = Math.round(result.blocker.blockerVibrancyScore / 10);
                this._logIndented(timestamp, `Blocker score: ${blockerScore}/10`);
            }
        }
    }

    private _logSuggestions(result: VibrancyResult, timestamp: string): void {
        const suggestions: string[] = [];

        if (result.knownIssue?.replacement) {
            const displayReplacement = getReplacementDisplayText(
                result.knownIssue.replacement,
                result.package.version,
                result.knownIssue.replacementObsoleteFromVersion,
            );
            if (displayReplacement) {
                if (isReplacementPackageName(displayReplacement)) {
                    suggestions.push(`Consider migrating to ${displayReplacement}.`);
                } else {
                    suggestions.push(`Consider: ${displayReplacement}.`);
                }
            }
        }

        if (result.knownIssue?.migrationNotes) {
            suggestions.push(result.knownIssue.migrationNotes);
        }

        if (result.alternatives.length > 0) {
            const altNames = result.alternatives
                .slice(0, 3)
                .map(a => a.name)
                .join(', ');
            suggestions.push(`Alternatives: ${altNames}`);
        }

        if (result.isUnused) {
            suggestions.push('This package appears to be unused — consider removing it.');
        }

        if (suggestions.length === 0) {
            return;
        }

        this._logWithTimestamp(timestamp, '');
        this._logWithTimestamp(timestamp, '💡 Suggestion:');
        for (const suggestion of suggestions) {
            this._logIndented(timestamp, wrapText(suggestion, 70));
        }
    }

    private _logCommunityInfo(result: VibrancyResult, timestamp: string): void {
        const lines: string[] = [];

        if (result.github) {
            lines.push(`Stars: ${result.github.stars} | Open issues: ${result.github.openIssues}`);
            lines.push(`Closed issues (90d): ${result.github.closedIssuesLast90d} | Merged PRs (90d): ${result.github.mergedPrsLast90d}`);
        }

        if (result.pubDev?.pubPoints !== undefined) {
            lines.push(`Pub points: ${result.pubDev.pubPoints}/160`);
        }

        if (result.verifiedPublisher && result.pubDev?.publisher) {
            lines.push(`Publisher: ${result.pubDev.publisher} (verified)`);
        }

        if (result.platforms?.length) {
            lines.push(`Platforms: ${result.platforms.join(', ')}`);
        }

        if (result.drift) {
            lines.push(`Drift: ${result.drift.releasesBehind} releases behind (${result.drift.label})`);
        }

        if (lines.length === 0) {
            return;
        }

        this._logWithTimestamp(timestamp, '');
        this._logWithTimestamp(timestamp, '📊 Community:');
        for (const line of lines) {
            this._logIndented(timestamp, line);
        }
    }

    private _logAlerts(result: VibrancyResult, timestamp: string): void {
        const alerts: string[] = [];

        if (result.knownIssue) {
            const reason = result.knownIssue.reason ?? '';
            alerts.push(`${result.knownIssue.status}: ${reason}`);
        }

        if (result.github?.flaggedIssues?.length) {
            for (const issue of result.github.flaggedIssues) {
                alerts.push(formatFlaggedIssue(issue));
            }
        }

        if (alerts.length === 0) {
            return;
        }

        this._logWithTimestamp(timestamp, '');
        this._logWithTimestamp(timestamp, '🚨 Alerts:');
        for (const alert of alerts) {
            this._logIndented(timestamp, wrapText(alert, 70));
        }
    }

    private _logWithTimestamp(timestamp: string, text: string): void {
        this._channel.appendLine(`[${timestamp}] ${text}`);
    }

    private _logIndented(timestamp: string, text: string): void {
        const lines = text.split('\n');
        for (const line of lines) {
            this._channel.appendLine(`[${timestamp}]    ${line}`);
        }
    }
}

function formatTimestamp(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

function formatFlaggedIssue(issue: FlaggedIssue): string {
    return `#${issue.number}: ${issue.title} (${issue.commentCount} comments)`;
}

function wrapText(text: string, maxWidth: number): string {
    if (text.length <= maxWidth) {
        return text;
    }

    const words = text.split(' ');
    const lines: string[] = [];
    let currentLine = '';

    for (const word of words) {
        if (currentLine.length === 0) {
            currentLine = word;
        } else if (currentLine.length + 1 + word.length <= maxWidth) {
            currentLine += ' ' + word;
        } else {
            lines.push(currentLine);
            currentLine = word;
        }
    }

    if (currentLine) {
        lines.push(currentLine);
    }

    return lines.join('\n');
}

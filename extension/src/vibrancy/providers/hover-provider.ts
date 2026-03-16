import * as vscode from 'vscode';
import { VibrancyResult, UpdateInfo, FamilySplit, PackageInsight } from '../types';
import { categoryLabel } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { formatPrereleaseTag } from '../scoring/prerelease-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';

export class VibrancyHoverProvider implements vscode.HoverProvider {
    private _results = new Map<string, VibrancyResult>();
    private _splitsByPackage = new Map<string, FamilySplit>();
    private _insightsByPackage = new Map<string, PackageInsight>();

    /** Update cached results (called after scan). */
    updateResults(results: VibrancyResult[]): void {
        this._results.clear();
        for (const r of results) {
            this._results.set(r.package.name, r);
        }
    }

    /** Update detected family splits for hover display. */
    updateFamilySplits(splits: FamilySplit[]): void {
        this._splitsByPackage.clear();
        for (const split of splits) {
            for (const group of split.versionGroups) {
                for (const pkg of group.packages) {
                    this._splitsByPackage.set(pkg, split);
                }
            }
        }
    }

    /** Update consolidated insights for hover display. */
    updateInsights(insights: readonly PackageInsight[]): void {
        this._insightsByPackage.clear();
        for (const insight of insights) {
            this._insightsByPackage.set(insight.name, insight);
        }
    }

    provideHover(
        document: vscode.TextDocument,
        position: vscode.Position,
    ): vscode.Hover | null {
        if (!document.fileName.endsWith('pubspec.yaml')) { return null; }

        const wordRange = document.getWordRangeAtPosition(position, /[\w_]+/);
        if (!wordRange) { return null; }

        const word = document.getText(wordRange);
        const result = this._results.get(word);
        if (!result) { return null; }

        const split = this._splitsByPackage.get(word);
        const insight = this._insightsByPackage.get(word);
        return new vscode.Hover(
            buildHoverContent(result, split, insight), wordRange,
        );
    }
}

function buildHoverContent(
    result: VibrancyResult,
    split?: FamilySplit,
    insight?: PackageInsight,
): vscode.MarkdownString {
    const md = new vscode.MarkdownString();
    md.isTrusted = true;

    md.appendMarkdown(
        `**${result.package.name}** v${result.package.version}\n\n`,
    );
    md.appendMarkdown(`| | |\n|---|---|\n`);
    const displayScore = Math.round(result.score / 10);
    md.appendMarkdown(`| Vibrancy Score | **${displayScore}**/10 |\n`);
    md.appendMarkdown(
        `| Category | ${categoryLabel(result.category)} |\n`,
    );
    if (split) {
        const ownGroup = split.versionGroups.find(
            g => g.packages.includes(result.package.name),
        );
        const ver = ownGroup ? `v${ownGroup.majorVersion}` : '?';
        md.appendMarkdown(
            `| Family | ${split.familyLabel} (${ver} — split detected) |\n`,
        );
    }
    if (result.isUnused) {
        md.appendMarkdown(
            `| Status | **Unused** — no imports detected |\n`,
        );
    }

    if (result.vulnerabilities.length > 0) {
        const worst = worstSeverity(result.vulnerabilities);
        const icon = worst ? severityEmoji(worst) : '🛡️';
        const label = worst ? severityLabel(worst) : 'Unknown';
        md.appendMarkdown(
            `| Security | ${icon} **${result.vulnerabilities.length} vulnerability(ies)** (${label}) |\n`,
        );
    }

    if (insight && insight.problems.length > 0) {
        md.appendMarkdown(`\n---\n`);
        md.appendMarkdown(`**⚠️ Action Items** (${insight.problems.length}):\n\n`);
        for (const problem of insight.problems) {
            const emoji = problem.severity === 'high' ? '🔴'
                : problem.severity === 'medium' ? '🟡' : '🔵';
            md.appendMarkdown(`${emoji} ${problem.message}\n\n`);
        }
        if (insight.suggestedAction) {
            md.appendMarkdown(`**💡 Suggested:** ${insight.suggestedAction}\n`);
        }
        if (insight.unlocksIfFixed.length > 0) {
            md.appendMarkdown(`\n*Unlocks: ${insight.unlocksIfFixed.join(', ')}*\n`);
        }
    }

    if (result.license) {
        const tier = classifyLicense(result.license);
        md.appendMarkdown(
            `| License | ${licenseEmoji(tier)} ${result.license} |\n`,
        );
    }

    if (result.pubDev) {
        const date = result.pubDev.publishedDate.split('T')[0];
        md.appendMarkdown(`| Latest Version | ${result.pubDev.latestVersion} |\n`);
        if (result.latestPrerelease) {
            const tag = formatPrereleaseTag(result.prereleaseTag);
            md.appendMarkdown(`| Prerelease | 🧪 ${result.latestPrerelease} (${tag}) |\n`);
        }
        md.appendMarkdown(`| Published | ${date} |\n`);
        md.appendMarkdown(`| Pub Points | ${result.pubDev.pubPoints} |\n`);
    }

    if (result.github) {
        md.appendMarkdown(`| GitHub Stars | ${result.github.stars} |\n`);
        md.appendMarkdown(`| Open Issues | ${result.github.openIssues} |\n`);
    }

    if (result.drift) {
        const d = result.drift;
        const behind = d.releasesBehind === 0
            ? 'Current' : `${d.releasesBehind} Flutter releases behind`;
        md.appendMarkdown(`| Ecosystem Drift | ${behind} (${d.label}) |\n`);
    }

    if (result.bloatRating !== null && result.archiveSizeBytes !== null) {
        const sizeMB = formatSizeMB(result.archiveSizeBytes);
        md.appendMarkdown(
            `| Archive Size | ${sizeMB} (${result.bloatRating}/10 bloat) |\n`,
        );
    }

    if (result.transitiveInfo && result.transitiveInfo.transitiveCount > 0) {
        const t = result.transitiveInfo;
        const flaggedText = t.flaggedCount > 0 ? ` (${t.flaggedCount} flagged)` : '';
        md.appendMarkdown(
            `| Transitive Deps | ${t.transitiveCount}${flaggedText} |\n`,
        );
    }

    if (result.updateInfo
        && result.updateInfo.updateStatus !== 'up-to-date') {
        md.appendMarkdown(`\n---\n`);
        md.appendMarkdown(
            `**Update Available:** ${result.updateInfo.currentVersion} → ${result.updateInfo.latestVersion} (${result.updateInfo.updateStatus})\n\n`,
        );
        if (result.blocker) {
            md.appendMarkdown(
                `| Upgrade Status | Blocked by **${result.blocker.blockerPackage}** |\n`,
            );
        } else if (result.upgradeBlockStatus === 'constrained') {
            md.appendMarkdown(
                `| Upgrade Status | Constrained by your pubspec.yaml |\n`,
            );
        }
        appendChangelogSection(md, result.updateInfo);
    }

    appendFlaggedIssues(md, result);
    appendVulnerabilities(md, result);

    if (result.knownIssue?.reason) {
        md.appendMarkdown(
            `\n---\n**Known Issue:** ${result.knownIssue.reason}\n`,
        );
    }

    appendAlternatives(md, result);

    md.appendMarkdown(
        `\n[View on pub.dev](https://pub.dev/packages/${result.package.name})`,
    );

    return md;
}

function appendFlaggedIssues(
    md: vscode.MarkdownString,
    result: VibrancyResult,
): void {
    const flagged = result.github?.flaggedIssues;
    if (!flagged?.length) { return; }
    md.appendMarkdown(`\n---\n`);
    md.appendMarkdown(
        `**Flagged Issues** (${flagged.length}):\n\n`,
    );
    for (const issue of flagged.slice(0, 3)) {
        const title = truncateBody(issue.title);
        const signals = issue.matchedSignals.join(', ');
        md.appendMarkdown(
            `- [#${issue.number}](${issue.url}) ${title} *(${signals})*\n`,
        );
    }
    if (flagged.length > 3) {
        md.appendMarkdown(
            `- *...and ${flagged.length - 3} more*\n`,
        );
    }
}

function appendVulnerabilities(
    md: vscode.MarkdownString,
    result: VibrancyResult,
): void {
    if (result.vulnerabilities.length === 0) { return; }
    md.appendMarkdown(`\n---\n`);
    md.appendMarkdown(
        `**🛡️ Security Vulnerabilities** (${result.vulnerabilities.length}):\n\n`,
    );
    for (const vuln of result.vulnerabilities.slice(0, 5)) {
        const icon = severityEmoji(vuln.severity);
        const summary = truncateBody(vuln.summary);
        const fixInfo = vuln.fixedVersion
            ? ` — *fix: ${vuln.fixedVersion}*` : '';
        md.appendMarkdown(
            `${icon} [${vuln.id}](${vuln.url}): ${summary}${fixInfo}\n\n`,
        );
    }
    if (result.vulnerabilities.length > 5) {
        md.appendMarkdown(
            `*...and ${result.vulnerabilities.length - 5} more*\n`,
        );
    }
}

function appendChangelogSection(
    md: vscode.MarkdownString,
    updateInfo: UpdateInfo,
): void {
    if (updateInfo.changelog?.entries.length) {
        md.appendMarkdown(`**Changelog:**\n\n`);
        const entriesToShow = updateInfo.changelog.entries.slice(0, 5);
        for (const entry of entriesToShow) {
            const dateStr = entry.date ? ` - ${entry.date}` : '';
            md.appendMarkdown(`**v${entry.version}**${dateStr}\n\n`);
            const body = truncateBody(entry.body);
            if (body) {
                md.appendMarkdown(`${body}\n\n`);
            }
        }
        if (updateInfo.changelog.entries.length > 5) {
            md.appendMarkdown(
                `*...and ${updateInfo.changelog.entries.length - 5} more version(s)*\n\n`,
            );
        }
    } else if (updateInfo.changelog?.unavailableReason) {
        md.appendMarkdown(
            `*Changelog: ${updateInfo.changelog.unavailableReason}*\n\n`,
        );
    }
}

const truncateBody = (body: string): string =>
    !body ? '' : body.length > 200 ? body.substring(0, 197) + '...' : body;

function appendAlternatives(
    md: vscode.MarkdownString,
    result: VibrancyResult,
): void {
    if (!result.alternatives?.length) { return; }

    md.appendMarkdown(`\n---\n`);
    const hasCurated = result.alternatives.some(a => a.source === 'curated');
    const header = hasCurated ? 'Recommended Replacement' : 'Consider Also';
    md.appendMarkdown(`**${header}:**\n\n`);

    for (const alt of result.alternatives) {
        const badge = alt.source === 'curated' ? '⭐' : '💡';
        const scoreText = alt.score !== null ? ` (${Math.round(alt.score / 10)}/10)` : '';
        const likesText = alt.likes > 0 ? ` — ${alt.likes} likes` : '';
        md.appendMarkdown(
            `${badge} [${alt.name}](https://pub.dev/packages/${alt.name})${scoreText}${likesText}\n`,
        );
    }
}

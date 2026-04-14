import * as vscode from 'vscode';
import { VibrancyResult, FamilySplit, PackageInsight, activeFileUsages } from '../types';
import { categoryLabel } from '../scoring/status-classifier';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { formatRelativeTime } from '../scoring/time-formatter';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { findEnvironmentRange } from '../services/pubspec-parser';
import {
    SDK_VIBRANCY_TABLE_MD,
    PACKAGE_VIBRANCY_DOC_URL,
} from '../sdk-vibrancy-table';
import { resolveRepoUrl } from '../views/html-utils';

export class VibrancyHoverProvider implements vscode.HoverProvider {
    private _results = new Map<string, VibrancyResult>();
    private _splitsByPackage = new Map<string, FamilySplit>();
    private _insightsByPackage = new Map<string, PackageInsight>();
    private _clipboardTexts = new Map<string, string>();

    /** Get the plain markdown text for clipboard copy. */
    getClipboardText(packageName: string): string | undefined {
        return this._clipboardTexts.get(packageName);
    }

    /** Update cached results (called after scan). */
    updateResults(results: VibrancyResult[]): void {
        this._results.clear();
        // Clear stale clipboard text when scan results change.
        this._clipboardTexts.clear();
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

        const content = document.getText();
        const sdkRange = findEnvironmentRange(content, 'sdk');
        const flutterRange = findEnvironmentRange(content, 'flutter');
        const onSdkLine = sdkRange?.line === position.line;
        const onFlutterLine = flutterRange?.line === position.line;
        if (onSdkLine || onFlutterLine) {
            const lineRange = document.lineAt(position.line).range;
            const md = new vscode.MarkdownString();
            md.isTrusted = true;
            md.appendMarkdown(
                '**Dart & Flutter version history** — minimums, features, and packages:\n\n',
            );
            md.appendMarkdown(SDK_VIBRANCY_TABLE_MD);
            md.appendMarkdown(
                `\n\n[Open full doc](${PACKAGE_VIBRANCY_DOC_URL})`,
            );
            return new vscode.Hover(md, lineRange);
        }

        const wordRange = document.getWordRangeAtPosition(position, /[\w_]+/);
        if (!wordRange) { return null; }

        const word = document.getText(wordRange);
        const result = this._results.get(word);
        if (!result) { return null; }

        const split = this._splitsByPackage.get(word);
        const insight = this._insightsByPackage.get(word);
        const md = buildHoverContent(result, split, insight);

        // Store content before appending the copy link so the link
        // itself doesn't appear in the copied text.
        this._clipboardTexts.set(word, md.value);

        const encodedArg = encodeURIComponent(JSON.stringify(word));
        md.appendMarkdown(
            `\n\n[📋 Copy to Clipboard](command:saropaLints.packageVibrancy.copyHoverToClipboard?${encodedArg})`,
        );

        return new vscode.Hover(md, wordRange);
    }
}

function buildHoverContent(
    result: VibrancyResult,
    split?: FamilySplit,
    insight?: PackageInsight,
): vscode.MarkdownString {
    const md = new vscode.MarkdownString();
    md.isTrusted = true;

    // Header: package name + version + category (consistent with vibrancy report)
    const displayScore = Math.round(result.score / 10);
    md.appendMarkdown(
        `**${result.package.name}** v${result.package.version} `
        + `— **${displayScore}/10** ${categoryLabel(result.category)}\n\n`,
    );

    // --- VERSION ---
    appendHoverVersion(md, result);

    // --- COMMUNITY ---
    appendHoverCommunity(md, result);

    // --- SIZE ---
    appendHoverSize(md, result);

    // --- FILE USAGES ---
    appendHoverFileUsages(md, result);

    // --- ALERTS ---
    appendHoverAlerts(md, result, split);

    // --- VULNERABILITIES ---
    appendHoverVulnerabilities(md, result);

    // --- PLATFORMS ---
    appendHoverPlatforms(md, result);

    // --- ALTERNATIVES ---
    appendHoverAlternatives(md, result);

    // --- ACTION ITEMS ---
    appendHoverActionItems(md, insight);

    // --- LINKS ---
    appendHoverLinks(md, result);

    return md;
}

function appendHoverVersion(md: vscode.MarkdownString, r: VibrancyResult): void {
    const rows: string[] = [];
    rows.push(`| Constraint | ${r.package.constraint} |`);

    if (r.pubDev) {
        rows.push(`| Latest | ${r.pubDev.latestVersion} |`);
        if (r.pubDev.publishedDate) {
            rows.push(`| Published | ${r.pubDev.publishedDate.split('T')[0]} |`);
        }
    }
    if (r.updateInfo && r.updateInfo.updateStatus !== 'up-to-date') {
        rows.push(`| Update | ${r.updateInfo.currentVersion} → ${r.updateInfo.latestVersion} (${r.updateInfo.updateStatus}) |`);
        if (r.blocker) {
            rows.push(`| Blocked by | ${r.blocker.blockerPackage} |`);
        }
    }
    if (r.license) {
        const tier = classifyLicense(r.license);
        rows.push(`| License | ${licenseEmoji(tier)} ${r.license} |`);
    }

    md.appendMarkdown(`**VERSION**\n\n| | |\n|---|---|\n${rows.join('\n')}\n\n`);
}

function appendHoverCommunity(md: vscode.MarkdownString, r: VibrancyResult): void {
    const rows: string[] = [];
    if (r.github) {
        const gh = r.github;
        rows.push(`| Stars | ${gh.stars} |`);
        const issues = gh.trueOpenIssues ?? gh.openIssues;
        rows.push(`| Open Issues | ${issues} |`);
        if (gh.openPullRequests !== undefined) {
            rows.push(`| Open PRs | ${gh.openPullRequests} |`);
        }
        const activity = gh.closedIssuesLast90d + gh.mergedPrsLast90d;
        if (activity > 0) {
            rows.push(`| Activity (90d) | ${gh.closedIssuesLast90d} closed, ${gh.mergedPrsLast90d} merged |`);
        }
        if (gh.daysSinceLastCommit !== undefined) {
            rows.push(`| Last Commit | ${formatRelativeTime(gh.daysSinceLastCommit)} |`);
        }
    }
    if (r.pubDev?.pubPoints !== undefined) {
        rows.push(`| Pub Points | ${r.pubDev.pubPoints}/160 |`);
    }
    if (r.verifiedPublisher && r.pubDev?.publisher) {
        rows.push(`| Publisher | ✅ ${r.pubDev.publisher} |`);
    }
    if (r.transitiveInfo && r.transitiveInfo.transitiveCount > 0) {
        const flagged = r.transitiveInfo.flaggedCount > 0
            ? ` (${r.transitiveInfo.flaggedCount} flagged)` : '';
        rows.push(`| Transitive Deps | ${r.transitiveInfo.transitiveCount}${flagged} |`);
    }
    if (rows.length > 0) {
        md.appendMarkdown(`**COMMUNITY**\n\n| | |\n|---|---|\n${rows.join('\n')}\n\n`);
    }
}

function appendHoverSize(md: vscode.MarkdownString, r: VibrancyResult): void {
    const parts: string[] = [];
    if (r.archiveSizeBytes !== null) {
        const bloat = r.bloatRating !== null ? ` (${r.bloatRating}/10 bloat)` : '';
        parts.push(`Archive: ${formatSizeMB(r.archiveSizeBytes)}${bloat}`);
    }
    if (r.replacementComplexity) {
        parts.push(`Source: ${r.replacementComplexity.summary}`);
    }
    if (parts.length > 0) {
        md.appendMarkdown(`**SIZE** — ${parts.join(' · ')}\n\n`);
    }
}

function appendHoverFileUsages(md: vscode.MarkdownString, r: VibrancyResult): void {
    const active = activeFileUsages(r.fileUsages);
    if (active.length === 0) { return; }
    const count = active.length;
    const label = count === 1 ? '1 file' : `${count} files`;
    // Show first few file paths
    const shown = active.slice(0, 5);
    const lines = shown.map(u => `- \`${u.filePath}:${u.line}\``).join('\n');
    const more = count > 5 ? `\n- ...+${count - 5} more` : '';
    md.appendMarkdown(`**FILE USAGES** (${label})\n\n${lines}${more}\n\n`);
}

function appendHoverAlerts(
    md: vscode.MarkdownString, r: VibrancyResult, split?: FamilySplit,
): void {
    const alerts: string[] = [];
    if (r.github?.isArchived) {
        alerts.push('🗄️ **ARCHIVED** — repository is read-only');
    }
    if (r.knownIssue?.reason) {
        alerts.push(`❌ **Known Issue:** ${truncateBody(r.knownIssue.reason)}`);
    }
    if (r.isUnused) {
        alerts.push('⚠️ **Unused** — no imports detected');
    }
    if (split) {
        alerts.push(`⚠️ **Family split detected** (${split.familyLabel})`);
    }
    const flagged = r.github?.flaggedIssues ?? [];
    for (const issue of flagged.slice(0, 3)) {
        const title = issue.title.length > 60
            ? issue.title.substring(0, 57) + '...' : issue.title;
        alerts.push(`🚩 #${issue.number}: ${title}`);
    }
    if (alerts.length > 0) {
        md.appendMarkdown(`**ALERTS**\n\n${alerts.join('\n\n')}\n\n`);
    }
}

function appendHoverVulnerabilities(md: vscode.MarkdownString, r: VibrancyResult): void {
    if (r.vulnerabilities.length === 0) { return; }
    const worst = worstSeverity(r.vulnerabilities);
    const icon = worst ? severityEmoji(worst) : '🛡️';
    const label = worst ? severityLabel(worst) : 'Unknown';
    const lines = [`${icon} **${r.vulnerabilities.length} vulnerabilities** (${label})`];
    for (const vuln of r.vulnerabilities.slice(0, 3)) {
        const emoji = severityEmoji(vuln.severity);
        const fix = vuln.fixedVersion ? ` — fix: ${vuln.fixedVersion}` : '';
        lines.push(`- ${emoji} ${vuln.id}: ${vuln.summary}${fix}`);
    }
    if (r.vulnerabilities.length > 3) {
        lines.push(`- ...+${r.vulnerabilities.length - 3} more`);
    }
    md.appendMarkdown(`**SECURITY**\n\n${lines.join('\n')}\n\n`);
}

function appendHoverPlatforms(md: vscode.MarkdownString, r: VibrancyResult): void {
    if (!r.platforms?.length) { return; }
    const wasm = r.wasmReady ? ' · WASM' : '';
    md.appendMarkdown(`**PLATFORMS** — ${r.platforms.join(', ')}${wasm}\n\n`);
}

function appendHoverAlternatives(md: vscode.MarkdownString, r: VibrancyResult): void {
    if (!r.alternatives?.length) { return; }
    const lines = r.alternatives.map(alt => {
        const score = alt.score !== null ? ` (${Math.round(alt.score / 10)}/10)` : '';
        return `- ${alt.name}${score}`;
    });
    md.appendMarkdown(`**ALTERNATIVES**\n\n${lines.join('\n')}\n\n`);
}

function appendHoverActionItems(md: vscode.MarkdownString, insight?: PackageInsight): void {
    if (!insight || insight.problems.length === 0) { return; }
    const high = insight.problems.filter(p => p.severity === 'high').length;
    const med = insight.problems.filter(p => p.severity === 'medium').length;
    const parts: string[] = [];
    if (high > 0) { parts.push(`${high} high`); }
    if (med > 0) { parts.push(`${med} medium`); }
    const detail = parts.length > 0 ? ` (${parts.join(', ')})` : '';
    md.appendMarkdown(`**${insight.problems.length} ACTION ITEM(S)**${detail}\n\n`);
}

/** Append footer links to the hover tooltip — all as clickable markdown links. */
function appendHoverLinks(md: vscode.MarkdownString, r: VibrancyResult): void {
    const name = r.package.name;
    const pubUrl = `https://pub.dev/packages/${name}`;
    const repoUrl = resolveRepoUrl(r.github?.repoUrl, r.pubDev?.repositoryUrl);

    const links: string[] = [];
    links.push(`[pub.dev](${pubUrl})`);
    links.push(`[Changelog](${pubUrl}/changelog)`);
    links.push(`[Versions](${pubUrl}/versions)`);
    if (repoUrl) {
        links.push(`[Repository](${repoUrl})`);
        links.push(`[Open Issues](${repoUrl}/issues)`);
        links.push(`[Report Issue](${repoUrl}/issues/new)`);
    }

    // Command links for extension actions
    const encodedPkg = encodeURIComponent(JSON.stringify(name));
    links.push(`[View Full Details](command:saropaLints.packageVibrancy.showPackagePanel?${encodedPkg})`);

    md.appendMarkdown(`---\n\n${links.join(' · ')}`);
}

const truncateBody = (body: string): string =>
    !body ? '' : body.length > 200 ? body.substring(0, 197) + '...' : body;

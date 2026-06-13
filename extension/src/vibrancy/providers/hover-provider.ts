/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import * as vscode from 'vscode';
import { VibrancyResult, FamilySplit, PackageInsight, activeFileUsages } from '../types';
import { categoryLabel, categoryToGrade, scoreToGrade } from '../scoring/status-classifier';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { formatRelativeTime } from '../scoring/time-formatter';
import { formatSharedDepDetail } from '../scoring/blocker-analyzer';
import { formatSizeMB, formatSizeKB } from '../scoring/bloat-calculator';
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

    // Header: package name + version + letter grade (numeric score dropped;
    // the /10 never conveyed anything the letter didn't — see ADR in
    // category-dictionary for the letter-only rationale).
    const grade = categoryToGrade(result.category);
    md.appendMarkdown(
        `**${result.package.name}** v${result.package.version} `
        + `— **${grade}** ${categoryLabel(result.category)}\n\n`,
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
            const detail = formatSharedDepDetail(r.blocker);
            rows.push(
                `| Blocked by | ${r.blocker.blockerPackage}`
                + `${detail ? ` ${detail}` : ''} |`,
            );
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
    const publishAgeDays = daysSinceIsoDate(r.pubDev?.publishedDate);
    let commitAgeDays: number | undefined;
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
            commitAgeDays = gh.daysSinceLastCommit;
            rows.push(`| Last Commit | ${formatRelativeTime(gh.daysSinceLastCommit)} |`);
        }
    }
    if (publishAgeDays !== undefined) {
        rows.push(`| Latest Release | ${formatAgeFromDays(publishAgeDays)} ago |`);
    }
    const dormancy = buildDormancyStatus(commitAgeDays, publishAgeDays);
    if (dormancy) {
        rows.push(`| Activity Signal | ${dormancy} |`);
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

function daysSinceIsoDate(isoDate: string | null | undefined): number | undefined {
    if (!isoDate) { return undefined; }
    const ms = Date.parse(isoDate);
    if (isNaN(ms)) { return undefined; }
    return Math.max(0, Math.floor((Date.now() - ms) / 86_400_000));
}

function formatAgeFromDays(days: number): string {
    if (days < 30) { return `${days}d`; }
    if (days < 365) { return `${Math.floor(days / 30)}mo`; }
    return `${Math.floor(days / 365)}y`;
}

function buildDormancyStatus(
    commitAgeDays: number | undefined,
    publishAgeDays: number | undefined,
): string | null {
    if (commitAgeDays === undefined || publishAgeDays === undefined) {
        return null;
    }
    if (commitAgeDays >= 180 && publishAgeDays >= 180) {
        return 'No commits and no releases in 6+ months';
    }
    if (commitAgeDays >= 90 && publishAgeDays >= 90) {
        return 'No commits and no releases in 3+ months';
    }
    if (commitAgeDays >= 90 && publishAgeDays < 90) {
        return 'Release active, code inactive (3+ months without commits)';
    }
    if (commitAgeDays < 90 && publishAgeDays >= 90) {
        return 'Code active, release cadence is slower (3+ months)';
    }
    return null;
}

function appendHoverSize(md: vscode.MarkdownString, r: VibrancyResult): void {
    const parts: string[] = [];
    /* Primary line: code size — what the package contributes to the user's
       compiled app (`lib/` + declared assets). This is the number that
       matters for bloat decisions and per-app size budgets. Falls back to
       archiveSizeBytes only when the tarball analyzer could not run, so the
       line is never blank when ANY size info is available. */
    const primaryBytes = r.codeSizeBytes ?? r.archiveSizeBytes;
    if (primaryBytes !== null) {
        const bloat = r.bloatRating !== null ? ` (${r.bloatRating}/10 bloat)` : '';
        const label = r.codeSizeBytes !== null ? 'Code' : 'Archive';
        parts.push(`${label}: ${formatBytesAdaptive(primaryBytes)}${bloat}`);
    }
    /* Secondary detail: on-disk tarball total + per-folder breakdown when
       available. Shows the developer when a package's tarball mass lives
       outside `lib/` (e.g. a 21 MB `example/` of sample media) — the case
       the old bloat-by-tarball model flagged as 9/10 bloat. */
    if (r.archiveSizeBytes !== null && r.codeSizeBytes !== null) {
        parts.push(`${formatSizeMB(r.archiveSizeBytes)} on disk`);
    }
    if (r.replacementComplexity) {
        parts.push(`Source: ${r.replacementComplexity.summary}`);
    }
    if (parts.length > 0) {
        md.appendMarkdown(`**SIZE** — ${parts.join(' · ')}\n\n`);
    }

    /* Folder breakdown as a sub-line when available — surfaces the
       asymmetry that `example/` / `test/` would have penalized in the old
       model but is now a positive signal. */
    if (r.folderBreakdown) {
        const breakdown = formatFolderBreakdown(r.folderBreakdown);
        if (breakdown) { md.appendMarkdown(`${breakdown}\n\n`); }
    }

    /* Maintainer-quality flags: positive components that lifted the score.
       Only render when at least one flag is true; absent flags are not
       penalties, just non-contributions. */
    if (r.maintainerQuality) {
        const bonuses = formatMaintainerQuality(r.maintainerQuality);
        if (bonuses.length > 0) {
            md.appendMarkdown(`**HEALTH** — ${bonuses.join(' · ')}\n\n`);
        }
    }
}

/** KB for sub-MB sizes, MB above. Keeps the primary line readable across the
    full code-size range (a 40 KB `lib/` shouldn't render as `0.04 MB`). */
function formatBytesAdaptive(bytes: number): string {
    return bytes < 1024 * 1024 ? formatSizeKB(bytes) : formatSizeMB(bytes);
}

/** Render the per-folder breakdown when at least one non-lib folder has bytes. */
function formatFolderBreakdown(fb: import('../types').FolderBreakdown): string | null {
    const total = fb.lib + fb.example + fb.test + fb.tool + fb.doc + fb.other;
    if (total <= 0) { return null; }
    const parts: string[] = [];
    const pct = (n: number) => `${((n / total) * 100).toFixed(n / total < 0.001 ? 2 : 1)}%`;
    /* Only list folders that have non-trivial mass (>0.1%). A package that
       only ships `lib/` would otherwise display every folder at 0.0%. */
    if (fb.lib > 0) { parts.push(`lib ${pct(fb.lib)}`); }
    if (fb.example / total > 0.001) { parts.push(`example ${pct(fb.example)}`); }
    if (fb.test / total > 0.001) { parts.push(`test ${pct(fb.test)}`); }
    if (fb.tool / total > 0.001) { parts.push(`tool ${pct(fb.tool)}`); }
    if (fb.doc / total > 0.001) { parts.push(`doc ${pct(fb.doc)}`); }
    if (fb.other / total > 0.001) { parts.push(`other ${pct(fb.other)}`); }
    if (parts.length <= 1) { return null; }
    return `_${parts.join(' · ')}_`;
}

/** Format positive maintainer-quality components for the hover. */
function formatMaintainerQuality(q: import('../types').MaintainerQualityFlags): string[] {
    const parts: string[] = [];
    if (q.hasExample) { parts.push('+example'); }
    if (q.hasTests) { parts.push('+tests'); }
    if (q.hasTools) { parts.push('+tools'); }
    if (q.hasDocs) { parts.push('+docs'); }
    return parts;
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
    /* Alternatives only carry a raw score (no category), so we derive the
       letter via scoreToGrade — same thresholds as the gauge. The old
       "(7/10)" suffix is gone; letter is enough to rank at a glance. */
    const lines = r.alternatives.map(alt => {
        const grade = alt.score !== null ? ` (${scoreToGrade(alt.score)})` : '';
        return `- ${alt.name}${grade}`;
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

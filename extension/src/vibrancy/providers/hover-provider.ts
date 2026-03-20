import * as vscode from 'vscode';
import { VibrancyResult, FamilySplit, PackageInsight } from '../types';
import { categoryLabel } from '../scoring/status-classifier';
import { classifyLicense, licenseEmoji } from '../scoring/license-classifier';
import { worstSeverity, severityEmoji, severityLabel } from '../scoring/vuln-classifier';
import { findEnvironmentRange } from '../services/pubspec-parser';
import {
    SDK_VIBRANCY_TABLE_MD,
    PACKAGE_VIBRANCY_DOC_URL,
} from '../sdk-vibrancy-table';

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

    // Header: package name + version
    md.appendMarkdown(
        `**${result.package.name}** v${result.package.version}\n\n`,
    );

    // Compact metrics table — must-know stats only
    md.appendMarkdown(`| | |\n|---|---|\n`);
    const displayScore = Math.round(result.score / 10);
    md.appendMarkdown(
        `| Score | **${displayScore}**/10 ${categoryLabel(result.category)} |\n`,
    );

    if (result.updateInfo
        && result.updateInfo.updateStatus !== 'up-to-date') {
        md.appendMarkdown(
            `| Update | ${result.updateInfo.currentVersion} → ${result.updateInfo.latestVersion} (${result.updateInfo.updateStatus}) |\n`,
        );
    }

    if (result.license) {
        const tier = classifyLicense(result.license);
        md.appendMarkdown(
            `| License | ${licenseEmoji(tier)} ${result.license} |\n`,
        );
    }

    if (result.vulnerabilities.length > 0) {
        const worst = worstSeverity(result.vulnerabilities);
        const icon = worst ? severityEmoji(worst) : '🛡️';
        const label = worst ? severityLabel(worst) : 'Unknown';
        md.appendMarkdown(
            `| Vulns | ${icon} ${result.vulnerabilities.length} (${label}) |\n`,
        );
    }

    // Critical alerts — only show truly important flags
    if (result.github?.isArchived) {
        md.appendMarkdown(`\n**ARCHIVED** — repository is read-only\n`);
    }
    if (result.knownIssue?.reason) {
        md.appendMarkdown(
            `\n**Known Issue:** ${truncateBody(result.knownIssue.reason)}\n`,
        );
    }
    if (result.isUnused) {
        md.appendMarkdown(`\n**Unused** — no imports detected\n`);
    }
    if (split) {
        md.appendMarkdown(`\n**Family split detected** (${split.familyLabel})\n`);
    }

    // Action items summary (count only, details in panel)
    if (insight && insight.problems.length > 0) {
        const high = insight.problems.filter(p => p.severity === 'high').length;
        const med = insight.problems.filter(p => p.severity === 'medium').length;
        const parts: string[] = [];
        if (high > 0) { parts.push(`${high} high`); }
        if (med > 0) { parts.push(`${med} medium`); }
        const detail = parts.length > 0 ? ` (${parts.join(', ')})` : '';
        md.appendMarkdown(
            `\n**${insight.problems.length} action item(s)**${detail}\n`,
        );
    }

    // Links — compact footer with "View Full Details" command
    const encodedPkg = encodeURIComponent(JSON.stringify(result.package.name));
    md.appendMarkdown(
        `\n[View Full Details](command:saropaLints.packageVibrancy.showPackagePanel?${encodedPkg})`,
    );

    return md;
}

const truncateBody = (body: string): string =>
    !body ? '' : body.length > 200 ? body.substring(0, 197) + '...' : body;

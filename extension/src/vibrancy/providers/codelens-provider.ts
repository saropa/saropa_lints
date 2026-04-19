import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { findPackageRange } from '../services/pubspec-parser';
import { CodeLensDetail } from '../scoring/codelens-formatter';
import { CodeLensToggle } from '../ui/codelens-toggle';
import { PrereleaseToggle, arePrereleasesEnabled, getPrereleaseTagFilter } from '../ui/prerelease-toggle';
import { getCategoryIndicator, getIndicator } from '../services/indicator-config';
import { categoryToGrade } from '../scoring/status-classifier';
import { formatPrereleaseTag } from '../scoring/prerelease-classifier';
import { isReplacementPackageName, getReplacementDisplayText } from '../scoring/known-issues';

let globalToggle: CodeLensToggle | null = null;
let globalPrereleaseToggle: PrereleaseToggle | null = null;

/** Set the global toggle instance (called from extension-activation). */
export function setCodeLensToggle(toggle: CodeLensToggle): void {
    globalToggle = toggle;
}

/** Set the global prerelease toggle instance (called from extension-activation). */
export function setPrereleaseToggle(toggle: PrereleaseToggle): void {
    globalPrereleaseToggle = toggle;
}

/** Arguments for the updateFromCodeLens command. */
export interface UpdateFromCodeLensArgs {
    readonly packageName: string;
    readonly targetVersion: string;
    readonly pubspecPath: string;
}

export class VibrancyCodeLensProvider implements vscode.CodeLensProvider {
    private _results = new Map<string, VibrancyResult>();
    private readonly _onDidChange = new vscode.EventEmitter<void>();
    readonly onDidChangeCodeLenses = this._onDidChange.event;

    updateResults(results: VibrancyResult[]): void {
        this._results.clear();
        for (const r of results) {
            this._results.set(r.package.name, r);
        }
        this._onDidChange.fire();
    }

    /** Refresh CodeLens display (called when toggle changes). */
    refresh(): void {
        this._onDidChange.fire();
    }

    provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] {
        if (!isEnabled()) { return []; }
        if (!document.fileName.endsWith('pubspec.yaml')) { return []; }
        if (this._results.size === 0) { return []; }

        const content = document.getText();
        const detail = readDetailLevel();
        const pubspecPath = document.uri.fsPath;
        return buildLenses(content, this._results, detail, pubspecPath);
    }

    dispose(): void {
        this._onDidChange.dispose();
    }
}

function buildLenses(
    content: string,
    results: ReadonlyMap<string, VibrancyResult>,
    detail: CodeLensDetail,
    pubspecPath: string,
): vscode.CodeLens[] {
    const lenses: vscode.CodeLens[] = [];

    for (const [name, result] of results) {
        const pkgRange = findPackageRange(content, name);
        if (!pkgRange) { continue; }

        const range = new vscode.Range(
            pkgRange.line, pkgRange.startChar,
            pkgRange.line, pkgRange.endChar,
        );

        lenses.push(...buildLensesForPackage(result, range, detail, pubspecPath));
    }

    return lenses;
}

function buildLensesForPackage(
    result: VibrancyResult,
    range: vscode.Range,
    detail: CodeLensDetail,
    pubspecPath: string,
): vscode.CodeLens[] {
    const lenses: vscode.CodeLens[] = [];
    const name = result.package.name;

    lenses.push(new vscode.CodeLens(range, {
        title: formatStatusTitle(result, detail),
        command: 'saropaLints.packageVibrancy.focusPackageInTree',
        arguments: [name],
    }));

    const latestVersion = result.updateInfo?.latestVersion;
    const hasUpdate = latestVersion
        && result.updateInfo?.updateStatus !== 'up-to-date';

    if (hasUpdate) {
        const args: UpdateFromCodeLensArgs = {
            packageName: name,
            targetVersion: latestVersion,
            pubspecPath,
        };
        lenses.push(new vscode.CodeLens(range, {
            title: `→ ${latestVersion}`,
            command: 'saropaLints.packageVibrancy.updateFromCodeLens',
            arguments: [args],
        }));
    }

    if (isPrereleaseEnabled() && result.latestPrerelease) {
        const tagFilter = getPrereleaseTagFilter();
        const tag = result.prereleaseTag;
        const passesFilter = tagFilter.length === 0
            || (tag && tagFilter.some(f => f.toLowerCase() === tag.toLowerCase()));
        if (passesFilter) {
            const displayTag = formatPrereleaseTag(tag);
            const args: UpdateFromCodeLensArgs = {
                packageName: name,
                targetVersion: result.latestPrerelease,
                pubspecPath,
            };
            lenses.push(new vscode.CodeLens(range, {
                title: `🧪 ${result.latestPrerelease} (${displayTag})`,
                command: 'saropaLints.packageVibrancy.updateFromCodeLens',
                arguments: [args],
            }));
        }
    }

    return lenses;
}

function isPrereleaseEnabled(): boolean {
    if (globalPrereleaseToggle) {
        return globalPrereleaseToggle.isEnabled;
    }
    return arePrereleasesEnabled();
}

function formatStatusTitle(result: VibrancyResult, detail: CodeLensDetail): string {
    const indicator = getCategoryIndicator(result.category);
    /* Indicator + letter; the old "/10 label" was redundant with the indicator
       and added false precision the letter deliberately avoids. */
    const grade = categoryToGrade(result.category);

    let title = `${indicator} ${grade}`;

    if (detail === 'minimal') {
        return title;
    }

    if (result.isUnused) {
        title += ` · ${getIndicator('unused')} Unused`;
    }

    if (detail === 'full') {
        const replacement = result.knownIssue?.replacement;
        const displayReplacement = replacement
            ? getReplacementDisplayText(
                replacement,
                result.package.version,
                result.knownIssue?.replacementObsoleteFromVersion,
            )
            : undefined;
        if (displayReplacement) {
            const label = isReplacementPackageName(displayReplacement)
                ? `Replace with ${displayReplacement}`
                : `Consider: ${displayReplacement}`;
            title += ` · ${getIndicator('warning')} ${label}`;
        } else if (result.knownIssue?.reason) {
            title += ` · ${getIndicator('warning')} Known issue`;
        }
    }

    return title;
}

function isEnabled(): boolean {
    if (globalToggle) {
        return globalToggle.isEnabled;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return config.get<boolean>('enableCodeLens', true);
}

function readDetailLevel(): CodeLensDetail {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const level = config.get<string>('codeLensDetail', 'standard');
    if (level === 'minimal' || level === 'full') { return level; }
    return 'standard';
}

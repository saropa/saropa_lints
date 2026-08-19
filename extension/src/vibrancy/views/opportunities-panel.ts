/**
 * Host for the dedicated "Upgrade Opportunities" dashboard webview.
 *
 * Singleton panel (one per window, revealed on re-open). It builds the card
 * data from the latest scan results — assembling each package's AI prompt from
 * the full-history opportunities + call sites — and renders the focused list.
 * Messages handle opening a code location and jumping to a package's full detail
 * in the Package Dashboard.
 */

import * as vscode from 'vscode';
import { VibrancyResult, activeFileUsages, DepEdge } from '../types';
import {
    buildAiPromptBundle, DeprecatedUsage, PackageHealthSnapshot,
} from '../services/ai-prompt-bundle';
import { PackageOpportunities } from '../services/changelog-opportunities';
import {
    collectSymbolOccurrences, readDartSources, DartSource, SymbolOccurrence,
} from '../services/import-scanner';
import { worstSeverity } from '../scoring/vuln-classifier';
import {
    detectDualDependencies, attachViaConstraints, DualDependencyRisk,
} from '../scoring/dual-dependency-detector';
import { buildConstraintIndex } from '../services/shared-dep-constraints';
import { resolvePackagePaths } from '../services/package-code-analyzer';
import {
    extractDeclaredSymbols, detectLocalReimplementations, LocalReimplementation,
} from '../services/local-reimplementation-detector';
import {
    buildOpportunitiesHtml,
    OpportunityCardData,
} from './opportunities-html';
import { formatTimestamp } from '../services/report-utils';
import { l10n } from '../../i18n/runtime';

export class OpportunitiesPanel {
    private static _current: OpportunitiesPanel | undefined;
    private readonly _panel: vscode.WebviewPanel;
    private _disposables: vscode.Disposable[] = [];
    private _workspaceRoot: vscode.Uri;
    /** Retained so the "Write Report" button can build the combined file. */
    private _cards: readonly OpportunityCardData[] = [];

    static async createOrShow(
        results: readonly VibrancyResult[],
        extensionVersion: string,
        workspaceRoot: vscode.Uri,
        reverseDeps: ReadonlyMap<string, readonly DepEdge[]> = new Map(),
    ): Promise<void> {
        const cards = await buildCards(results, workspaceRoot, reverseDeps);
        if (OpportunitiesPanel._current) {
            OpportunitiesPanel._current._workspaceRoot = workspaceRoot;
            OpportunitiesPanel._current._panel.reveal();
            OpportunitiesPanel._current._render(cards, extensionVersion);
            return;
        }
        const panel = vscode.window.createWebviewPanel(
            'saropaUpgradeOpportunities',
            l10n('opportunities.documentTitle'),
            vscode.ViewColumn.One,
            { enableScripts: true, retainContextWhenHidden: true },
        );
        OpportunitiesPanel._current = new OpportunitiesPanel(
            panel, cards, extensionVersion, workspaceRoot,
        );
    }

    private constructor(
        panel: vscode.WebviewPanel,
        cards: readonly OpportunityCardData[],
        extensionVersion: string,
        workspaceRoot: vscode.Uri,
    ) {
        this._panel = panel;
        this._workspaceRoot = workspaceRoot;
        this._render(cards, extensionVersion);
        this._panel.onDidDispose(() => this._dispose(), null, this._disposables);
        this._panel.webview.onDidReceiveMessage(
            msg => this._handleMessage(msg), null, this._disposables,
        );
    }

    private _render(
        cards: readonly OpportunityCardData[], extensionVersion: string,
    ): void {
        this._cards = cards;
        this._panel.webview.html = buildOpportunitiesHtml(cards, extensionVersion);
    }

    private async _handleMessage(msg: unknown): Promise<void> {
        if (typeof msg !== 'object' || msg === null) { return; }
        const m = msg as { type?: string; file?: string; line?: number; package?: string };
        // Jump to the exact import site so the user lands where the package is
        // used and can apply the new feature in context.
        if (m.type === 'openFile' && m.file) {
            await openAtLine(this._workspaceRoot, m.file, m.line ?? 1);
            return;
        }
        // Hand off to the Package Dashboard's detail pane for the full record.
        if (m.type === 'openPackage' && m.package) {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.showPackagePanel', m.package,
            );
            return;
        }
        // Write all cards' AI prompts to a single dated report file and copy
        // the absolute path to the clipboard for pasting into an AI tool.
        if (m.type === 'writeReport') {
            await this._writeReport();
            return;
        }
        // Write a single package's AI prompt to its own dated file.
        if (m.type === 'writeCardReport' && m.package) {
            await this._writeCardReport(m.package);
        }
    }

    /**
     * Write a combined opportunities report containing every card's AI prompt,
     * copy the file's absolute path to the clipboard, and notify the webview
     * so the button re-enables.
     */
    private async _writeReport(): Promise<void> {
        try {
            // Use the scanned workspace root (beside the pubspec), not the
            // generic first workspace folder — correct in multi-root setups.
            const reportDir = vscode.Uri.joinPath(this._workspaceRoot, 'reports');
            await vscode.workspace.fs.createDirectory(reportDir);

            // Reachable even though the button shows when ranked.length > 0,
            // because ranked cards can have null aiPrompt (no opportunities).
            const sections = this._cards
                .filter(c => c.aiPrompt)
                .map(c => c.aiPrompt as string);

            if (sections.length === 0) {
                void vscode.window.showInformationMessage(
                    l10n('opportunities.report.noContent'),
                );
                this._postIfAlive({ type: 'reportFailed' });
                return;
            }

            // Combine into one markdown document with separators.
            const body = sections.join('\n\n---\n\n');
            const stamp = formatTimestamp(new Date());
            const filename = `${stamp}_package_opportunities.md`;
            const fileUri = vscode.Uri.joinPath(reportDir, filename);

            await vscode.workspace.fs.writeFile(
                fileUri, Buffer.from(body, 'utf8'),
            );

            // Copy the absolute path — the user pastes it into their AI tool.
            const absPath = fileUri.fsPath;
            await vscode.env.clipboard.writeText(absPath);

            void vscode.window.showInformationMessage(
                l10n('opportunities.report.written', { path: absPath }),
            );
            this._postIfAlive({ type: 'reportWritten' });
        } catch (err: unknown) {
            void vscode.window.showErrorMessage(l10n(
                'opportunities.report.failed',
                { error: err instanceof Error ? err.message : String(err) },
            ));
            this._postIfAlive({ type: 'reportFailed' });
        }
    }

    /**
     * Write a single package's AI prompt to its own dated file and copy the
     * path — the per-card counterpart to the global `_writeReport`.
     */
    private async _writeCardReport(packageName: string): Promise<void> {
        try {
            const card = this._cards.find(
                c => c.result.package.name === packageName,
            );
            if (!card?.aiPrompt) {
                void vscode.window.showInformationMessage(
                    l10n('opportunities.report.noContent'),
                );
                return;
            }

            const reportDir = vscode.Uri.joinPath(this._workspaceRoot, 'reports');
            await vscode.workspace.fs.createDirectory(reportDir);

            const stamp = formatTimestamp(new Date());
            // Sanitize the package name for use in a filename.
            const safeName = packageName.replace(/[^a-zA-Z0-9_-]/g, '_');
            const filename = `${stamp}_opportunity_${safeName}.md`;
            const fileUri = vscode.Uri.joinPath(reportDir, filename);

            await vscode.workspace.fs.writeFile(
                fileUri, Buffer.from(card.aiPrompt, 'utf8'),
            );

            const absPath = fileUri.fsPath;
            await vscode.env.clipboard.writeText(absPath);

            void vscode.window.showInformationMessage(
                l10n('opportunities.report.written', { path: absPath }),
            );
        } catch (err: unknown) {
            void vscode.window.showErrorMessage(l10n(
                'opportunities.report.failed',
                { error: err instanceof Error ? err.message : String(err) },
            ));
        }
    }

    /** Post a message to the webview, swallowing if the panel was disposed
     *  while an async write was in flight. */
    private _postIfAlive(msg: { type: string }): void {
        try { void this._panel.webview.postMessage(msg); } catch { /* disposed */ }
    }

    private _dispose(): void {
        OpportunitiesPanel._current = undefined;
        this._panel.dispose();
        while (this._disposables.length) {
            this._disposables.pop()?.dispose();
        }
    }
}

/**
 * Turn scan results into card data: keep only packages with unadopted
 * features that the project actually imports, and precompute each one's AI
 * prompt so the webview button copies a ready string. The HTML builder does
 * the final filter+sort, but assembling the prompt here keeps the renderer
 * pure.
 *
 * A dev-only or transitive dependency (zero active file usages — e.g.
 * `build_runner`) is excluded entirely rather than surfaced with an
 * explanatory "not imported anywhere" line: it clutters a panel whose whole
 * point is "packages worth acting on now".
 */
async function buildCards(
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Promise<OpportunityCardData[]> {
    const eligible = results.filter(r =>
        (r.unadoptedApiNames?.length ?? 0) > 0
        && activeFileUsages(r.fileUsages).length > 0);

    // Single project source read, shared by the deprecated-usage scan and the
    // local-reimplementation declaration scan — a package imported in
    // hundreds of files would otherwise pay for the walk twice.
    const sources = await readDartSources(workspaceRoot);
    const occurrences = scanDeprecatedUsage(eligible, sources);
    const dualDependencies = await computeDualDependencies(
        results, workspaceRoot, reverseDeps,
    );
    const localReimplementations = await computeLocalReimplementations(
        eligible, workspaceRoot, sources,
    );

    const cards: OpportunityCardData[] = [];
    for (const result of eligible) {
        const opportunities = result.opportunities;
        const aiPrompt = opportunities
            ? buildAiPromptBundle({
                packageName: result.package.name,
                currentVersion: result.package.version,
                latestVersion: result.updateInfo?.latestVersion ?? result.package.version,
                opportunities,
                fileUsages: activeFileUsages(result.fileUsages),
                deprecatedInUse: buildDeprecatedUsages(opportunities, occurrences),
                health: buildHealthSnapshot(result),
                flaggedIssues: result.github?.flaggedIssues ?? [],
                dualDependency: dualDependencies.get(result.package.name) ?? null,
                localReimplementations: localReimplementations.get(result.package.name) ?? [],
            })
            : null;
        cards.push({ result, aiPrompt });
    }
    return cards;
}

// Bound pub-cache I/O per package: a package's full lib/ tree is read to
// extract its declared symbol names, so cap file count the same way
// `analyzePackageCode` implicitly bounds via typical package size — this
// panel reads several packages in parallel on open, so an explicit cap
// keeps one unusually large package from dominating the wait.
const MAX_PACKAGE_SOURCE_FILES = 300;

/**
 * Detect project code that reimplements something a dependency's own
 * source already exports, by name. Reads each eligible package's `lib/`
 * tree from the local pub cache (already resolved by
 * `.dart_tool/package_config.json`, the same resolution
 * `enrichReplacementComplexity` uses for LOC metrics) and cross-references
 * declared symbol names against the project's own declarations.
 *
 * Scoped to the package's full `lib/` tree, not just its re-exported public
 * surface (following `export ... show/hide` chains is a further
 * refinement) — see the bug report this feature closes for that
 * limitation.
 */
async function computeLocalReimplementations(
    eligible: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    projectSources: readonly DartSource[],
): Promise<ReadonlyMap<string, readonly LocalReimplementation[]>> {
    if (eligible.length === 0) { return new Map(); }

    const projectDeclarations = projectSources.flatMap(extractDeclaredSymbols);
    if (projectDeclarations.length === 0) { return new Map(); }

    const packagePaths = await resolvePackagePaths(workspaceRoot);
    const out = new Map<string, readonly LocalReimplementation[]>();

    await Promise.all(eligible.map(async result => {
        // SDK packages (flutter, flutter_test, ...) have no reimplementation
        // risk worth surfacing — their APIs are the platform, not a
        // package the project chose to depend on.
        if (result.package.source === 'sdk') { return; }
        const pkgPath = packagePaths.get(result.package.name);
        if (!pkgPath) { return; }
        const packageSymbols = await readPackageSymbolNames(pkgPath.rootUri);
        if (packageSymbols.size === 0) { return; }
        const matches = detectLocalReimplementations(projectDeclarations, packageSymbols);
        if (matches.length > 0) { out.set(result.package.name, matches); }
    }));

    return out;
}

/** Read a package's `lib/` tree from pub cache and extract declared symbol names. */
async function readPackageSymbolNames(packageRoot: vscode.Uri): Promise<Set<string>> {
    const libDir = vscode.Uri.joinPath(packageRoot, 'lib');
    try {
        await vscode.workspace.fs.stat(libDir);
    } catch {
        return new Set();
    }

    const pattern = new vscode.RelativePattern(libDir, '**/*.dart');
    const files = await vscode.workspace.findFiles(pattern, null, MAX_PACKAGE_SOURCE_FILES);
    if (files.length === 0) { return new Set(); }

    const contents = await Promise.all(files.map(f => vscode.workspace.fs.readFile(f)));
    const names = new Set<string>();
    for (let i = 0; i < files.length; i++) {
        const source: DartSource = {
            path: files[i].fsPath,
            text: Buffer.from(contents[i]).toString('utf8'),
        };
        for (const decl of extractDeclaredSymbols(source)) { names.add(decl.name); }
    }
    return names;
}

/**
 * Detect direct dependencies that are also reachable transitively through
 * another direct dependency (type-identity risk), then read each
 * responsible via-package's own pubspec.yaml so the risk names its declared
 * constraint on the shared dep, not just its name. Bounded to the packages
 * actually involved in a detected risk, same I/O-bounding strategy
 * `mergeSharedDepConflicts` uses for diamond-conflict detection.
 */
async function computeDualDependencies(
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    reverseDeps: ReadonlyMap<string, readonly DepEdge[]>,
): Promise<ReadonlyMap<string, DualDependencyRisk>> {
    if (reverseDeps.size === 0) { return new Map(); }

    const directConstraints = new Map(
        results.filter(r => r.package.isDirect)
            .map(r => [r.package.name, r.package.constraint] as const),
    );
    const risks = detectDualDependencies(directConstraints, reverseDeps);
    if (risks.length === 0) { return new Map(); }

    const viaNames = new Set(risks.flatMap(r => r.sources.map(s => s.viaPackage)));
    const constraintIndex = await buildConstraintIndex(workspaceRoot, viaNames);
    const withConstraints = attachViaConstraints(risks, constraintIndex);

    return new Map(withConstraints.map(r => [r.packageName, r]));
}

/**
 * One shared symbol-occurrence pass across every eligible package's
 * deprecated-category API names, so the deprecation cross-reference costs a
 * single project source read regardless of how many packages have
 * deprecations to check — the same sharing strategy the export path
 * (`feature-inventory-export`) uses for its full candidate set. Takes
 * already-read sources (shared with the local-reimplementation scan) rather
 * than reading the project a second time.
 */
function scanDeprecatedUsage(
    results: readonly VibrancyResult[],
    sources: readonly DartSource[],
): ReadonlyMap<string, readonly SymbolOccurrence[]> {
    const candidates = new Set<string>();
    for (const result of results) {
        for (const bullet of result.opportunities?.all ?? []) {
            if (bullet.category !== 'deprecated') { continue; }
            for (const name of bullet.apiNames) { candidates.add(name); }
        }
    }
    if (candidates.size === 0) { return new Map(); }

    return collectSymbolOccurrences(sources, candidates);
}

/**
 * Deprecated-category bullets whose named API has at least one measured
 * occurrence in project source — a deprecated symbol the project never calls
 * is not a prompt-worthy risk.
 */
function buildDeprecatedUsages(
    opportunities: PackageOpportunities | null | undefined,
    occurrences: ReadonlyMap<string, readonly SymbolOccurrence[]>,
): DeprecatedUsage[] {
    if (!opportunities) { return []; }
    const out: DeprecatedUsage[] = [];
    for (const bullet of opportunities.all) {
        if (bullet.category !== 'deprecated') { continue; }
        for (const apiName of bullet.apiNames) {
            const usages = occurrences.get(apiName);
            if (usages && usages.length > 0) {
                out.push({
                    apiName, usages,
                    bulletText: bullet.text,
                    version: bullet.version,
                });
            }
        }
    }
    return out;
}

/**
 * Narrow health snapshot mapped from the already-computed `VibrancyResult` —
 * no additional fetching, the scan gathered all of this already.
 */
function buildHealthSnapshot(result: VibrancyResult): PackageHealthSnapshot {
    return {
        score: result.score,
        category: result.category,
        license: result.license,
        pubPoints: result.pubDev?.pubPoints ?? null,
        vulnerabilityCount: result.vulnerabilities.length,
        worstVulnerabilitySeverity: worstSeverity(result.vulnerabilities),
        knownIssueStatus: result.knownIssue?.status ?? null,
        knownIssueReplacement: result.knownIssue?.replacement ?? null,
    };
}

/** Open a workspace-relative file and move the cursor to the given line. */
async function openAtLine(
    workspaceRoot: vscode.Uri, relativePath: string, line: number,
): Promise<void> {
    try {
        const uri = vscode.Uri.joinPath(workspaceRoot, relativePath);
        const doc = await vscode.workspace.openTextDocument(uri);
        const editor = await vscode.window.showTextDocument(doc);
        // Lines from the scanner are 1-based; VS Code positions are 0-based.
        const pos = new vscode.Position(Math.max(0, line - 1), 0);
        editor.selection = new vscode.Selection(pos, pos);
        editor.revealRange(
            new vscode.Range(pos, pos),
            vscode.TextEditorRevealType.InCenter,
        );
    } catch {
        // File moved/renamed since the scan — surface a non-fatal notice.
        void vscode.window.showWarningMessage(
            l10n('opportunities.openFileFailed', { file: relativePath }),
        );
    }
}

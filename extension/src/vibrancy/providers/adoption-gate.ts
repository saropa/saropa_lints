import * as vscode from 'vscode';
import { CacheService } from '../services/cache-service';
import { parsePubspecYaml } from '../services/pubspec-parser';
import { fetchPackageInfo, fetchPackageMetrics, fetchPublisher } from '../services/pub-dev-api';
import { findKnownIssue } from '../scoring/known-issues';
import { classifyAdoption, AdoptionTier, AdoptionResult } from '../scoring/adoption-classifier';
import { getLatestResults } from '../extension-activation';

const DEBOUNCE_MS = 1500;

const TIER_COLORS: Record<AdoptionTier, string> = {
    healthy: 'green',
    caution: 'orange',
    warning: 'red',
    unknown: 'gray',
};

export class AdoptionGateProvider implements vscode.Disposable {
    private readonly _decorationTypes = new Map<AdoptionTier, vscode.TextEditorDecorationType>();
    private readonly _disposables: vscode.Disposable[] = [];
    private _debounceTimer: ReturnType<typeof setTimeout> | null = null;
    private _pendingNames = new Set<string>();

    constructor(private readonly _cache: CacheService) {
        for (const tier of Object.keys(TIER_COLORS) as AdoptionTier[]) {
            this._decorationTypes.set(tier, createDecorationType(tier));
        }
    }

    /** Register listeners and push subscriptions to context. */
    register(context: vscode.ExtensionContext): void {
        this._disposables.push(
            vscode.workspace.onDidChangeTextDocument(e => {
                if (isPubspecYaml(e.document)) {
                    this._scheduleCheck(e.document);
                }
            }),
            vscode.window.onDidChangeActiveTextEditor(editor => {
                if (!editor || !isPubspecYaml(editor.document)) {
                    this.clearDecorations();
                }
            }),
        );
        context.subscriptions.push(this);
    }

    /** Clear all adoption gate decorations. */
    clearDecorations(): void {
        const editor = vscode.window.activeTextEditor;
        if (!editor) { return; }
        for (const dt of this._decorationTypes.values()) {
            editor.setDecorations(dt, []);
        }
    }

    dispose(): void {
        if (this._debounceTimer) { clearTimeout(this._debounceTimer); }
        for (const dt of this._decorationTypes.values()) { dt.dispose(); }
        for (const d of this._disposables) { d.dispose(); }
    }

    private _scheduleCheck(document: vscode.TextDocument): void {
        if (!isEnabled()) { return; }
        if (this._debounceTimer) { clearTimeout(this._debounceTimer); }
        this._debounceTimer = setTimeout(
            () => this._runCheck(document),
            DEBOUNCE_MS,
        );
    }

    private async _runCheck(document: vscode.TextDocument): Promise<void> {
        const candidates = findCandidates(document.getText());
        if (candidates.length === 0) {
            this.clearDecorations();
            return;
        }

        const results = await Promise.all(
            candidates.map(name => this._classifyCandidate(name)),
        );
        this._applyDecorations(document, candidates, results);
    }

    private async _classifyCandidate(
        name: string,
    ): Promise<AdoptionResult> {
        if (this._pendingNames.has(name)) {
            return { tier: 'unknown', badgeText: '...', detail: 'Checking...' };
        }
        this._pendingNames.add(name);
        try {
            return await fetchAndClassify(name, this._cache);
        } finally {
            this._pendingNames.delete(name);
        }
    }

    private _applyDecorations(
        document: vscode.TextDocument,
        candidates: string[],
        results: AdoptionResult[],
    ): void {
        const editor = vscode.window.activeTextEditor;
        if (!editor || editor.document !== document) { return; }

        const grouped = groupByTier(candidates, results, document);
        for (const [tier, dt] of this._decorationTypes) {
            editor.setDecorations(dt, grouped.get(tier) ?? []);
        }
    }
}

function createDecorationType(
    tier: AdoptionTier,
): vscode.TextEditorDecorationType {
    return vscode.window.createTextEditorDecorationType({
        after: {
            margin: '0 0 0 2em',
            color: new vscode.ThemeColor(
                tier === 'healthy' ? 'charts.green'
                    : tier === 'caution' ? 'charts.yellow'
                        : tier === 'warning' ? 'charts.red'
                            : 'disabledForeground',
            ),
        },
        isWholeLine: false,
    });
}

/** Find package names in yaml that are not yet in scan results. */
export function findCandidates(content: string): string[] {
    const parsed = parsePubspecYaml(content);
    const allNames = [...parsed.directDeps, ...parsed.devDeps];
    const resolved = new Set(
        getLatestResults().map(r => r.package.name),
    );
    return allNames.filter(name => !resolved.has(name));
}

async function fetchAndClassify(
    name: string,
    cache: CacheService,
): Promise<AdoptionResult> {
    const [info, metrics, publisher] = await Promise.all([
        fetchPackageInfo(name, cache),
        fetchPackageMetrics(name, cache),
        fetchPublisher(name, cache),
    ]);
    const knownIssue = findKnownIssue(name);

    return classifyAdoption({
        pubPoints: metrics.pubPoints,
        verifiedPublisher: publisher !== null,
        isDiscontinued: info?.isDiscontinued ?? false,
        knownIssueStatus: knownIssue?.status ?? null,
        knownIssueReason: knownIssue?.reason ?? null,
        exists: info !== null,
    });
}

function groupByTier(
    candidates: string[],
    results: AdoptionResult[],
    document: vscode.TextDocument,
): Map<AdoptionTier, vscode.DecorationOptions[]> {
    const grouped = new Map<AdoptionTier, vscode.DecorationOptions[]>();
    const content = document.getText();
    const lines = content.split('\n');

    for (let i = 0; i < candidates.length; i++) {
        const lineIdx = findPackageLine(lines, candidates[i]);
        if (lineIdx < 0) { continue; }

        const result = results[i];
        const lineEnd = lines[lineIdx].length;
        const range = new vscode.Range(lineIdx, 0, lineIdx, lineEnd);
        const decoration: vscode.DecorationOptions = {
            range,
            renderOptions: {
                after: { contentText: `  ${result.badgeText}` },
            },
            hoverMessage: new vscode.MarkdownString(result.detail),
        };

        const list = grouped.get(result.tier) ?? [];
        list.push(decoration);
        grouped.set(result.tier, list);
    }

    return grouped;
}

function findPackageLine(lines: string[], name: string): number {
    const pattern = new RegExp(`^\\s{2}${name}\\s*:`);
    return lines.findIndex(line => pattern.test(line));
}

function isPubspecYaml(document: vscode.TextDocument): boolean {
    return document.fileName.endsWith('pubspec.yaml');
}

function isEnabled(): boolean {
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    return config.get<boolean>('enableAdoptionGate', true);
}

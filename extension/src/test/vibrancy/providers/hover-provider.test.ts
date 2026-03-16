import * as assert from 'assert';
import * as vscode from 'vscode';
import { VibrancyHoverProvider } from '../../../vibrancy/providers/hover-provider';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(name: string, score: number): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: {
            name,
            latestVersion: '2.0.0',
            publishedDate: '2025-01-15T00:00:00Z',
            repositoryUrl: null,
            isDiscontinued: false,
            isUnlisted: false,
            pubPoints: 130,
            publisher: null,
            license: null,
            description: null,
            topics: [],
        },
        github: { stars: 500, openIssues: 10, closedIssuesLast90d: 5,
            mergedPrsLast90d: 3, avgCommentsPerIssue: 2,
            daysSinceLastUpdate: 1, daysSinceLastClose: 2, flaggedIssues: [], license: null },
        knownIssue: null,
        score,
        category: 'vibrant',
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null,
        blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}

function makeMockDocument(text: string): vscode.TextDocument {
    const lines = text.split('\n');
    return {
        fileName: '/test/pubspec.yaml',
        getText(range?: vscode.Range): string {
            if (!range) { return text; }
            return lines[range.start.line]?.substring(
                range.start.character, range.end.character,
            ) ?? '';
        },
        getWordRangeAtPosition(
            pos: vscode.Position,
            _regex?: RegExp,
        ): vscode.Range | undefined {
            const line = lines[pos.line];
            if (!line) { return undefined; }
            const match = line.match(/(\w+)/);
            if (!match) { return undefined; }
            const start = line.indexOf(match[1]);
            return new vscode.Range(
                pos.line, start, pos.line, start + match[1].length,
            );
        },
    } as unknown as vscode.TextDocument;
}

describe('VibrancyHoverProvider', () => {
    let provider: VibrancyHoverProvider;

    beforeEach(() => {
        provider = new VibrancyHoverProvider();
    });

    it('should return null when no results loaded', () => {
        const doc = makeMockDocument('  http: ^1.0.0');
        const result = provider.provideHover(doc, new vscode.Position(0, 2));
        assert.strictEqual(result, null);
    });

    it('should return hover for known package', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const result = provider.provideHover(doc, new vscode.Position(0, 2));
        assert.ok(result);
        assert.ok(result instanceof vscode.Hover);
    });

    it('should include score in hover content', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover!.contents as unknown as vscode.MarkdownString;
        assert.ok(md.value.includes('9'));
        assert.ok(md.value.includes('/10'));
    });

    it('should include pub.dev link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover!.contents as unknown as vscode.MarkdownString;
        assert.ok(md.value.includes('pub.dev/packages/http'));
    });

    it('should return null for non-pubspec files', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = {
            ...makeMockDocument('  http: ^1.0.0'),
            fileName: '/test/other.yaml',
        } as unknown as vscode.TextDocument;
        const result = provider.provideHover(doc, new vscode.Position(0, 2));
        assert.strictEqual(result, null);
    });

    it('should return null for unrecognized package', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  unknown_pkg: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        assert.strictEqual(hover, null);
    });

    it('should include unused status in hover content', () => {
        const result: VibrancyResult = { ...makeResult('http', 85), isUnused: true };
        provider.updateResults([result]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover!.contents as unknown as vscode.MarkdownString;
        assert.ok(md.value.includes('Unused'));
    });

    it('should not include unused status when not unused', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover!.contents as unknown as vscode.MarkdownString;
        assert.ok(!md.value.includes('Unused'));
    });

    it('should include copy-to-clipboard command link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover!.contents as unknown as vscode.MarkdownString;
        assert.ok(md.value.includes('copyHoverToClipboard'));
    });

    it('should store clipboard text without the copy link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        provider.provideHover(doc, new vscode.Position(0, 2));
        const clipText = provider.getClipboardText('http');
        assert.ok(clipText, 'clipboard text should be stored');
        // Clipboard text should not contain the copy command link itself.
        assert.ok(!clipText!.includes('copyHoverToClipboard'));
        // But should contain the actual hover content.
        assert.ok(clipText!.includes('pub.dev/packages/http'));
    });

    it('should clear clipboard texts on updateResults', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        provider.provideHover(doc, new vscode.Position(0, 2));
        assert.ok(provider.getClipboardText('http'));
        // Rescan clears stale clipboard entries.
        provider.updateResults([]);
        assert.strictEqual(provider.getClipboardText('http'), undefined);
    });
});

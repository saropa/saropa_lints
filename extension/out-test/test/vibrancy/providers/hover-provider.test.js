"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const assert = __importStar(require("assert"));
const vscode = __importStar(require("vscode"));
const hover_provider_1 = require("../../../vibrancy/providers/hover-provider");
function makeResult(name, score) {
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
function makeMockDocument(text) {
    const lines = text.split('\n');
    return {
        fileName: '/test/pubspec.yaml',
        getText(range) {
            if (!range) {
                return text;
            }
            return lines[range.start.line]?.substring(range.start.character, range.end.character) ?? '';
        },
        getWordRangeAtPosition(pos, _regex) {
            const line = lines[pos.line];
            if (!line) {
                return undefined;
            }
            const match = line.match(/(\w+)/);
            if (!match) {
                return undefined;
            }
            const start = line.indexOf(match[1]);
            return new vscode.Range(pos.line, start, pos.line, start + match[1].length);
        },
    };
}
describe('VibrancyHoverProvider', () => {
    let provider;
    beforeEach(() => {
        provider = new hover_provider_1.VibrancyHoverProvider();
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
        const md = hover.contents;
        assert.ok(md.value.includes('9'));
        assert.ok(md.value.includes('/10'));
    });
    it('should include pub.dev link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover.contents;
        assert.ok(md.value.includes('pub.dev/packages/http'));
    });
    it('should return null for non-pubspec files', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = {
            ...makeMockDocument('  http: ^1.0.0'),
            fileName: '/test/other.yaml',
        };
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
        const result = { ...makeResult('http', 85), isUnused: true };
        provider.updateResults([result]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover.contents;
        assert.ok(md.value.includes('Unused'));
    });
    it('should not include unused status when not unused', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover.contents;
        assert.ok(!md.value.includes('Unused'));
    });
    it('should include copy-to-clipboard command link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        const hover = provider.provideHover(doc, new vscode.Position(0, 2));
        const md = hover.contents;
        assert.ok(md.value.includes('copyHoverToClipboard'));
    });
    it('should store clipboard text without the copy link', () => {
        provider.updateResults([makeResult('http', 85)]);
        const doc = makeMockDocument('  http: ^1.0.0');
        provider.provideHover(doc, new vscode.Position(0, 2));
        const clipText = provider.getClipboardText('http');
        assert.ok(clipText, 'clipboard text should be stored');
        // Clipboard text should not contain the copy command link itself.
        assert.ok(!clipText.includes('copyHoverToClipboard'));
        // But should contain the actual hover content.
        assert.ok(clipText.includes('pub.dev/packages/http'));
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
//# sourceMappingURL=hover-provider.test.js.map
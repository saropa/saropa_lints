import * as assert from 'assert';
import { DetailViewProvider, DETAIL_VIEW_ID } from '../../../vibrancy/views/detail-view-provider';
import { VibrancyResult } from '../../../vibrancy/types';
import * as vscode from 'vscode';

function makeResult(
    name: string,
    score: number,
    category: VibrancyResult['category'] = 'vibrant',
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 30,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false,
        platforms: null,
        verifiedPublisher: false,
        wasmReady: null,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('DetailViewProvider', () => {
    it('should export correct view ID', () => {
        assert.strictEqual(DETAIL_VIEW_ID, 'saropaLints.packageVibrancy.details');
    });

    it('should create provider with extension URI', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);
        assert.ok(provider);
    });

    it('should return null for current result initially', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);
        assert.strictEqual(provider.getCurrentResult(), null);
    });

    it('should update current result on update()', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);
        const result = makeResult('http', 80);

        provider.update(result);
        assert.strictEqual(provider.getCurrentResult(), result);
    });

    it('should clear current result on clear()', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);
        const result = makeResult('http', 80);

        provider.update(result);
        assert.strictEqual(provider.getCurrentResult(), result);

        provider.clear();
        assert.strictEqual(provider.getCurrentResult(), null);
    });

    it('should handle multiple update calls', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);

        const result1 = makeResult('http', 80);
        const result2 = makeResult('bloc', 60);

        provider.update(result1);
        assert.strictEqual(provider.getCurrentResult()?.package.name, 'http');

        provider.update(result2);
        assert.strictEqual(provider.getCurrentResult()?.package.name, 'bloc');
    });

    it('should implement WebviewViewProvider interface', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new DetailViewProvider(mockUri);

        assert.ok(typeof provider.resolveWebviewView === 'function');
        assert.ok(typeof provider.update === 'function');
        assert.ok(typeof provider.clear === 'function');
        assert.ok(typeof provider.focus === 'function');
    });
});

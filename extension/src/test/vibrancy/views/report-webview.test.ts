// Side-effect import must stay first so subsequent `vscode` imports bind to the Jest mock.
import '../register-vscode-mock';

/**
 * Jest tests for `VibrancyReportPanel`: webview lifecycle, `postMessage` contracts, refresh/reveal,
 * and option defaults passed into HTML generation.
 */
import * as assert from 'assert';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import { VibrancyResult } from '../../../vibrancy/types';
import { ReportOptions } from '../../../vibrancy/views/report-html';
import { VibrancyReportPanel } from '../../../vibrancy/views/report-webview';
// Imported as a namespace (not a named import) so `sinon.stub` can replace the
// exported function on the actual module object that report-webview.ts reads
// from at call time (TS compiles named imports to property access under
// `module: commonjs`, so both this test file and report-webview.ts share one
// module object).
import * as featureInventoryExport from '../../../vibrancy/services/feature-inventory-export';
import { createdPanels, messageMock, mockWorkspaceFolders, resetMocks } from '../vscode-mock';

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
        codeSizeBytes: null,
        folderBreakdown: null,
        maintainerQuality: null,
        maintainerQualityBonus: 0,
        bloatRating: null,
        license: null,
        isUnused: false,
        fileUsages: [],
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
        versionGap: null,
        overrideGap: null,
        replacementComplexity: null,
        likes: null,
        downloadCount30Days: null,
        reverseDependencyCount: null,
        readme: null,
    };
}

function makeOptions(pubspecUri: string | null = 'file:///workspace/pubspec.yaml'): ReportOptions {
    return {
        results: [makeResult('http', 80)],
        overrideCount: 0,
        overrideNames: new Set(),
        pubspecUri,
        extensionVersion: '0.0.0-test',
    };
}

describe('report-webview message handling', () => {
    function disposeCurrentPanel(): void {
        const current = (VibrancyReportPanel as any)._currentPanel;
        current?._panel?.dispose?.();
    }

    beforeEach(() => {
        disposeCurrentPanel();
        resetMocks();
    });

    afterEach(() => {
        sinon.restore();
        disposeCurrentPanel();
    });

    it('routes openSourceFolder message to tree command', async () => {
        const execStub = sinon.stub(vscode.commands, 'executeCommand').resolves(undefined);

        VibrancyReportPanel.createOrShow(makeOptions());
        assert.strictEqual(createdPanels.length, 1);

        createdPanels[0].fireMessage({
            type: 'openSourceFolder',
            package: 'http',
        });

        await Promise.resolve();

        assert.ok(execStub.calledWith(
            'saropaLints.packageVibrancy.openSourceFolder',
            'http',
        ));
    });

    it('opens relative file reference at requested line', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];

        const openedUris: string[] = [];
        (vscode.workspace as any).openTextDocument = async (uri: { fsPath: string }) => {
            openedUris.push(uri.fsPath);
            return { uri };
        };

        let revealCalled = false;
        (vscode.window as any).showTextDocument = async () => ({
            selection: null,
            revealRange: () => { revealCalled = true; },
        });

        VibrancyReportPanel.createOrShow(makeOptions());
        createdPanels[0].fireMessage({
            type: 'openFileRef',
            path: 'lib/components/country/flag/country_flag.dart',
            line: 1,
        });

        await new Promise(resolve => setTimeout(resolve, 0));

        assert.strictEqual(
            openedUris[0],
            'D:/workspace/lib/components/country/flag/country_flag.dart',
        );
        assert.strictEqual(revealCalled, true);
    });

    it('opens absolute file reference without re-joining workspace path', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];

        const openedUris: string[] = [];
        (vscode.workspace as any).openTextDocument = async (uri: { fsPath: string }) => {
            openedUris.push(uri.fsPath);
            return { uri };
        };
        (vscode.window as any).showTextDocument = async () => ({
            selection: null,
            revealRange: () => { /* no-op */ },
        });

        VibrancyReportPanel.createOrShow(makeOptions());
        createdPanels[0].fireMessage({
            type: 'openFileRef',
            path: 'D:/external/project/lib/foo.dart',
            line: 8,
        });

        await new Promise(resolve => setTimeout(resolve, 0));

        assert.strictEqual(openedUris[0], 'D:/external/project/lib/foo.dart');
    });

    it('shows error when file reference cannot be opened', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];
        (vscode.workspace as any).openTextDocument = async () => {
            throw new Error('missing');
        };

        VibrancyReportPanel.createOrShow(makeOptions());
        createdPanels[0].fireMessage({
            type: 'openFileRef',
            path: 'lib/missing.dart',
            line: 1,
        });

        await Promise.resolve();

        assert.ok(
            messageMock.errors.some(msg => msg.includes('Could not open file reference')),
        );
    });

    it('saves report json to dated reports folder', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];

        const createdDirs: string[] = [];
        const writtenFiles: Array<{ path: string; size: number }> = [];
        (vscode.workspace as any).fs.createDirectory = async (uri: { fsPath: string }) => {
            createdDirs.push(uri.fsPath);
        };
        (vscode.workspace as any).fs.writeFile = async (uri: { fsPath: string }, bytes: Uint8Array) => {
            writtenFiles.push({ path: uri.fsPath, size: bytes.length });
        };

        VibrancyReportPanel.createOrShow(makeOptions());
        createdPanels[0].fireMessage({
            type: 'saveReportJson',
            data: [{ name: 'http', score: 80 }],
        });

        await new Promise(resolve => setTimeout(resolve, 0));

        assert.ok(createdDirs.some(p => p.includes('/reports/')));
        assert.ok(writtenFiles.length > 0);
        assert.ok(writtenFiles[0].path.endsWith('pubspec_vibrancy.json'));
        assert.ok(messageMock.infos.some(msg => msg.includes('Saved report JSON')));
    });

    it('saves upgrade report json to a distinct upgrade-suffixed file', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];

        const writtenFiles: Array<{ path: string; size: number }> = [];
        (vscode.workspace as any).fs.createDirectory = async () => { /* no-op */ };
        (vscode.workspace as any).fs.writeFile = async (uri: { fsPath: string }, bytes: Uint8Array) => {
            writtenFiles.push({ path: uri.fsPath, size: bytes.length });
        };

        VibrancyReportPanel.createOrShow(makeOptions());
        // The webview already filters to outdated rows; the panel just writes
        // whatever it receives under the upgrade filename, so passing a single
        // outdated row is enough to pin the distinct suffix.
        createdPanels[0].fireMessage({
            type: 'saveUpgradeReportJson',
            data: [{ name: 'http', update: { status: 'major', latestVersion: '2.0.0' } }],
        });

        await new Promise(resolve => setTimeout(resolve, 0));

        assert.ok(writtenFiles.length > 0);
        assert.ok(writtenFiles[0].path.endsWith('pubspec_upgrade.json'));
        assert.ok(messageMock.infos.some(msg => msg.includes('Saved report JSON')));
    });

    it('kicks off the Full report build on the very first open (BUG 1 regression)', async () => {
        const rootUri = vscode.Uri.file('D:/workspace');
        mockWorkspaceFolders.value = [{ uri: rootUri }];

        /* BUG 1: `_updateContent` used to build `this._options` as a single object literal whose
           `fullReportBodyHtml: this._getFullReportEmbed()` property ran INSIDE the literal, so
           `_getFullReportEmbed` (and the `_buildFeatureInventoryReport` it kicks off) read
           `this._options` while it was still the OLD value -- `null` on the very first open. That
           null short-circuited `_buildFeatureInventoryReport`'s `if (!root || !options) return;`
           guard before it ever called the actual scan, so `buildFeatureInventoryReport` below was
           never invoked and the tab was stuck on the loading placeholder forever. */
        const buildStub = sinon.stub(featureInventoryExport, 'buildFeatureInventoryReport')
            .resolves({ generatedAt: 't', extensionVersion: 'v', groups: [], stats: {} } as any);

        VibrancyReportPanel.createOrShow(makeOptions('file:///workspace/pubspec.yaml'));

        // Flush the microtask queue so the fire-and-forget `_buildFeatureInventoryReport()` call
        // (kicked off synchronously inside `_updateContent`) gets a chance to run.
        await Promise.resolve();
        await Promise.resolve();

        assert.strictEqual(
            buildStub.called, true,
            'buildFeatureInventoryReport must be invoked on the first _updateContent, not skipped ' +
            'because this._options was still null when _getFullReportEmbed read it',
        );
    });
});

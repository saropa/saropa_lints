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
});

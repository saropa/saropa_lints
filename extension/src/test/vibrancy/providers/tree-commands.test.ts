import * as assert from 'assert';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import {
    clipboardMock, envMock, messageMock, resetMocks, workspace,
} from '../vscode-mock';
import {
    registerTreeCommands, findPackageLines,
} from '../../../vibrancy/providers/tree-commands';
import { DetailItem, PackageItem } from '../../../vibrancy/providers/tree-items';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(
    name: string, score: number, latestVersion?: string,
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category: score >= 70 ? 'vibrant' : 'quiet',
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
        publisherTrust: 0,
        updateInfo: latestVersion ? {
            currentVersion: '1.0.0',
            latestVersion,
            updateStatus: 'major' as const,
            changelog: null,
        } : null,
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

function makeMockContext(): vscode.ExtensionContext {
    const subs: { dispose: () => void }[] = [];
    return { subscriptions: subs } as unknown as vscode.ExtensionContext;
}

describe('tree-commands', () => {
    let sandbox: sinon.SinonSandbox;

    beforeEach(() => {
        sandbox = sinon.createSandbox();
        resetMocks();
        registerTreeCommands(makeMockContext());
    });

    afterEach(() => {
        sandbox.restore();
    });

    describe('copyAsJson', () => {
        it('should copy result JSON to clipboard', async () => {
            const result = makeResult('http', 80);
            const item = new PackageItem(result);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.copyAsJson', item,
            );
            const parsed = JSON.parse(clipboardMock.text);
            assert.strictEqual(parsed.package.name, 'http');
            assert.strictEqual(parsed.score, 80);
        });

        it('should show confirmation message', async () => {
            const item = new PackageItem(makeResult('bloc', 60));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.copyAsJson', item,
            );
            assert.strictEqual(messageMock.infos.length, 1);
            assert.ok(messageMock.infos[0].includes('bloc'));
        });

        it('should show warning when invoked without valid package item', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.copyAsJson', undefined,
            );
            assert.strictEqual(messageMock.warnings.length, 1);
            assert.ok(messageMock.warnings[0].includes('Packages view'));
        });
    });

    describe('openOnPubDev', () => {
        it('should open pub.dev URL for the package', async () => {
            const item = new PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openOnPubDev', item,
            );
            assert.strictEqual(envMock.openedUrls.length, 1);
            assert.ok(envMock.openedUrls[0].includes('pub.dev/packages/http'));
        });
    });

    describe('goToPackage', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(workspace, 'findFiles').resolves([]);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToPackage', 'http',
            );
            // No error thrown — graceful no-op
        });

        it('should open document and navigate to package line', async () => {
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(workspace, 'findFiles').resolves([fakeUri]);

            const fakeDoc = {
                getText: () => 'dependencies:\n  http: ^1.0.0\n  bloc: ^2.0.0',
                fileName: '/test/pubspec.yaml',
            };
            sandbox.stub(workspace, 'openTextDocument').resolves(fakeDoc);

            let shownDoc: any = null;
            let shownOptions: any = null;
            sandbox.stub(vscode.window, 'showTextDocument').callsFake(
                async (doc: any, options?: any) => {
                    shownDoc = doc;
                    shownOptions = options;
                    return {} as any;
                },
            );

            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToPackage', 'http',
            );

            assert.strictEqual(shownDoc, fakeDoc);
            assert.ok(shownOptions?.selection);
        });
    });

    describe('goToLine', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(workspace, 'findFiles').resolves([]);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToLine', 5,
            );
            assert.strictEqual(workspace.openTextDocument?.callCount ?? 0, 0);
        });

        it('should open pubspec at given 0-based line', async () => {
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(workspace, 'findFiles').resolves([fakeUri]);
            const fakeDoc = { getText: () => '', fileName: '/test/pubspec.yaml' };
            sandbox.stub(workspace, 'openTextDocument').resolves(fakeDoc as any);
            let shownSelection: any = null;
            sandbox.stub(vscode.window, 'showTextDocument').callsFake(
                async (_doc: any, options?: any) => {
                    shownSelection = options?.selection;
                    return {} as any;
                },
            );
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToLine', 3,
            );
            assert.ok(shownSelection);
            assert.strictEqual(shownSelection.start.line, 3);
        });

        it('should do nothing when line is undefined or negative', async () => {
            const showDocStub = sandbox.stub(vscode.window, 'showTextDocument').resolves({} as any);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToLine', undefined,
            );
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.goToLine', -1,
            );
            assert.strictEqual(showDocStub.callCount, 0);
        });
    });

    describe('showChangelog', () => {
        it('should open pub.dev changelog URL for package', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.showChangelog', 'http',
            );
            assert.strictEqual(envMock.openedUrls.length, 1);
            assert.ok(envMock.openedUrls[0].includes('pub.dev/packages/http/changelog'));
        });

        it('should do nothing when packageName is undefined or empty', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.showChangelog', undefined,
            );
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.showChangelog', '',
            );
            assert.strictEqual(envMock.openedUrls.length, 0);
        });
    });

    describe('suppressPackage', () => {
        it('should add package name to suppressedPackages setting', async () => {
            let updatedValue: any = null;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    [] as unknown as T,
                update: async (_key: string, value: any) => {
                    updatedValue = value;
                },
            });

            const item = new PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.suppressPackage', item,
            );
            assert.deepStrictEqual(updatedValue, ['http']);
        });

        it('should not duplicate already-suppressed package', async () => {
            let updateCalled = false;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    ['http'] as unknown as T,
                update: async () => { updateCalled = true; },
            });

            const item = new PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.suppressPackage', item,
            );
            assert.strictEqual(updateCalled, false);
        });
    });

    describe('unsuppressPackage', () => {
        it('should remove package name from suppressedPackages', async () => {
            let updatedValue: any = null;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    ['http', 'bloc'] as unknown as T,
                update: async (_key: string, value: any) => {
                    updatedValue = value;
                },
            });

            const item = new PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.unsuppressPackage', item,
            );
            assert.deepStrictEqual(updatedValue, ['bloc']);
        });
    });

    describe('bulk suppression via config-service', () => {
        const { addSuppressedPackages, clearSuppressedPackages } = require('../../services/config-service');

        it('should add multiple packages at once', async () => {
            let updatedValue: any = null;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    ['existing'] as unknown as T,
                update: async (_key: string, value: any) => {
                    updatedValue = value;
                },
            });

            const count = await addSuppressedPackages(['http', 'bloc', 'existing']);
            assert.strictEqual(count, 2);
            assert.deepStrictEqual(updatedValue, ['existing', 'http', 'bloc']);
        });

        it('should return 0 when all packages already suppressed', async () => {
            let updateCalled = false;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    ['http', 'bloc'] as unknown as T,
                update: async () => { updateCalled = true; },
            });

            const count = await addSuppressedPackages(['http', 'bloc']);
            assert.strictEqual(count, 0);
            assert.strictEqual(updateCalled, false);
        });

        it('should clear all suppressed packages', async () => {
            let updatedValue: any = null;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    ['http', 'bloc', 'provider'] as unknown as T,
                update: async (_key: string, value: any) => {
                    updatedValue = value;
                },
            });

            const count = await clearSuppressedPackages();
            assert.strictEqual(count, 3);
            assert.deepStrictEqual(updatedValue, []);
        });

        it('should return 0 when clearing empty list', async () => {
            let updateCalled = false;
            sandbox.stub(workspace, 'getConfiguration').returns({
                get: <T>(_key: string, _defaultValue?: T) =>
                    [] as unknown as T,
                update: async () => { updateCalled = true; },
            });

            const count = await clearSuppressedPackages();
            assert.strictEqual(count, 0);
            assert.strictEqual(updateCalled, false);
        });
    });

    describe('openUrl', () => {
        it('should open the given URL in external browser', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openUrl',
                'https://pub.dev/packages/http/changelog#253',
            );
            assert.strictEqual(envMock.openedUrls.length, 1);
            assert.ok(envMock.openedUrls[0].includes('changelog#253'));
        });

        it('should accept a DetailItem with url property', async () => {
            const item = new DetailItem('Latest', '2.0.0', 'https://pub.dev/packages/http/versions/2.0.0');
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openUrl', item,
            );
            assert.strictEqual(envMock.openedUrls.length, 1);
            assert.ok(envMock.openedUrls[0].includes('versions/2.0.0'));
        });

        it('should do nothing when URL is empty', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openUrl', '',
            );
            assert.strictEqual(envMock.openedUrls.length, 0);
        });

        it('should do nothing when argument is undefined', async () => {
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.openUrl', undefined,
            );
            assert.strictEqual(envMock.openedUrls.length, 0);
        });
    });

    describe('updateToLatest', () => {
        it('should do nothing when no latest version', async () => {
            const item = new PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.updateToLatest', item,
            );
        });

        it('should show warning when package line not found', async () => {
            const result = makeResult('http', 50, '2.0.0');
            const item = new PackageItem(result);
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(workspace, 'findFiles').resolves([fakeUri]);
            sandbox.stub(workspace, 'openTextDocument').resolves({
                getText: () => 'dependencies:\n  bloc: ^1.0.0',
                lineCount: 2,
                lineAt: (i: number) => ({
                    text: ['dependencies:', '  bloc: ^1.0.0'][i] ?? '',
                }),
            });
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.updateToLatest', item,
            );
            assert.strictEqual(messageMock.warnings.length, 1);
            assert.ok(messageMock.warnings[0].includes('http'));
        });
    });

    describe('commentOutUnused', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(workspace, 'findFiles').resolves([]);
            const r = { ...makeResult('http', 80), isUnused: true };
            const item = new PackageItem(r);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.commentOutUnused', item,
            );
        });
    });

    describe('deleteUnused', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(workspace, 'findFiles').resolves([]);
            const r = { ...makeResult('http', 80), isUnused: true };
            const item = new PackageItem(r);
            await vscode.commands.executeCommand(
                'saropaLints.packageVibrancy.deleteUnused', item,
            );
        });
    });
});

function makeFakeDoc(lines: string[]) {
    return {
        lineCount: lines.length,
        lineAt: (i: number) => ({ text: lines[i] ?? '' }),
    } as any;
}

describe('findPackageLines', () => {
    it('should find a single-line dependency', () => {
        const doc = makeFakeDoc(['dependencies:', '  http: ^1.0.0', '  bloc: ^2.0.0']);
        const result = findPackageLines(doc, 'http');
        assert.deepStrictEqual(result, { start: 1, end: 2 });
    });

    it('should include continuation lines for multi-line deps', () => {
        const doc = makeFakeDoc([
            'dependencies:', '  my_pkg:', '    git:',
            '      url: https://github.com/foo/bar', '  bloc: ^2.0.0',
        ]);
        const result = findPackageLines(doc, 'my_pkg');
        assert.deepStrictEqual(result, { start: 1, end: 4 });
    });

    it('should return null when package not found', () => {
        const doc = makeFakeDoc(['dependencies:', '  bloc: ^2.0.0']);
        assert.strictEqual(findPackageLines(doc, 'http'), null);
    });

    it('should handle package at end of file', () => {
        const doc = makeFakeDoc(['dependencies:', '  http: ^1.0.0']);
        const result = findPackageLines(doc, 'http');
        assert.deepStrictEqual(result, { start: 1, end: 2 });
    });
});

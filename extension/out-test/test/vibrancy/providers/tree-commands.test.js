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
const sinon = __importStar(require("sinon"));
const vscode = __importStar(require("vscode"));
const vscode_mock_1 = require("../vscode-mock");
const tree_commands_1 = require("../../../vibrancy/providers/tree-commands");
const tree_items_1 = require("../../../vibrancy/providers/tree-items");
function makeResult(name, score, latestVersion) {
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
            updateStatus: 'major',
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
function makeMockContext() {
    const subs = [];
    return { subscriptions: subs };
}
describe('tree-commands', () => {
    let sandbox;
    beforeEach(() => {
        sandbox = sinon.createSandbox();
        (0, vscode_mock_1.resetMocks)();
        // Pass a mock tree provider that returns no children (leaf-only serialization in tests).
        (0, tree_commands_1.registerTreeCommands)(makeMockContext(), { getChildren: () => [] });
    });
    afterEach(() => {
        sandbox.restore();
    });
    describe('copyAsJson', () => {
        it('should copy result JSON to clipboard in JsonNode envelope', async () => {
            const result = makeResult('http', 80);
            const item = new tree_items_1.PackageItem(result);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.copyAsJson', item);
            const parsed = JSON.parse(vscode_mock_1.clipboardMock.text);
            // New format: { type, label, data: { package: { name }, score, ... } }
            assert.strictEqual(parsed.type, 'vibrancyPackage');
            assert.strictEqual(parsed.label, 'http');
            assert.strictEqual(parsed.data.package.name, 'http');
            assert.strictEqual(parsed.data.score, 80);
        });
        it('should show confirmation message', async () => {
            const item = new tree_items_1.PackageItem(makeResult('bloc', 60));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.copyAsJson', item);
            assert.strictEqual(vscode_mock_1.messageMock.infos.length, 1);
            assert.ok(vscode_mock_1.messageMock.infos[0].includes('Vibrancy'));
        });
        it('should show warning when invoked without valid item', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.copyAsJson', undefined);
            assert.strictEqual(vscode_mock_1.messageMock.warnings.length, 1);
            assert.ok(vscode_mock_1.messageMock.warnings[0].includes('No tree item'));
        });
    });
    describe('openOnPubDev', () => {
        it('should open pub.dev URL for the package', async () => {
            const item = new tree_items_1.PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.openOnPubDev', item);
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 1);
            assert.ok(vscode_mock_1.envMock.openedUrls[0].includes('pub.dev/packages/http'));
        });
    });
    describe('goToPackage', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([]);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToPackage', 'http');
            // No error thrown — graceful no-op
        });
        it('should open document and navigate to package line', async () => {
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([fakeUri]);
            const fakeDoc = {
                getText: () => 'dependencies:\n  http: ^1.0.0\n  bloc: ^2.0.0',
                fileName: '/test/pubspec.yaml',
            };
            sandbox.stub(vscode_mock_1.workspace, 'openTextDocument').resolves(fakeDoc);
            let shownDoc = null;
            let shownOptions = null;
            sandbox.stub(vscode.window, 'showTextDocument').callsFake(async (doc, options) => {
                shownDoc = doc;
                shownOptions = options;
                return {};
            });
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToPackage', 'http');
            assert.strictEqual(shownDoc, fakeDoc);
            assert.ok(shownOptions?.selection);
        });
    });
    describe('goToLine', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([]);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToLine', 5);
            assert.strictEqual(vscode_mock_1.workspace.openTextDocument?.callCount ?? 0, 0);
        });
        it('should open pubspec at given 0-based line', async () => {
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([fakeUri]);
            const fakeDoc = { getText: () => '', fileName: '/test/pubspec.yaml' };
            sandbox.stub(vscode_mock_1.workspace, 'openTextDocument').resolves(fakeDoc);
            let shownSelection = null;
            sandbox.stub(vscode.window, 'showTextDocument').callsFake(async (_doc, options) => {
                shownSelection = options?.selection;
                return {};
            });
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToLine', 3);
            assert.ok(shownSelection);
            assert.strictEqual(shownSelection.start.line, 3);
        });
        it('should do nothing when line is undefined or negative', async () => {
            const showDocStub = sandbox.stub(vscode.window, 'showTextDocument').resolves({});
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToLine', undefined);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.goToLine', -1);
            assert.strictEqual(showDocStub.callCount, 0);
        });
    });
    describe('showChangelog', () => {
        it('should open pub.dev changelog URL for package', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.showChangelog', 'http');
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 1);
            assert.ok(vscode_mock_1.envMock.openedUrls[0].includes('pub.dev/packages/http/changelog'));
        });
        it('should do nothing when packageName is undefined or empty', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.showChangelog', undefined);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.showChangelog', '');
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 0);
        });
    });
    describe('suppressPackage', () => {
        it('should add package name to suppressedPackages setting', async () => {
            let updatedValue = null;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => [],
                update: async (_key, value) => {
                    updatedValue = value;
                },
            });
            const item = new tree_items_1.PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.suppressPackage', item);
            assert.deepStrictEqual(updatedValue, ['http']);
        });
        it('should not duplicate already-suppressed package', async () => {
            let updateCalled = false;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => ['http'],
                update: async () => { updateCalled = true; },
            });
            const item = new tree_items_1.PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.suppressPackage', item);
            assert.strictEqual(updateCalled, false);
        });
    });
    describe('unsuppressPackage', () => {
        it('should remove package name from suppressedPackages', async () => {
            let updatedValue = null;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => ['http', 'bloc'],
                update: async (_key, value) => {
                    updatedValue = value;
                },
            });
            const item = new tree_items_1.PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.unsuppressPackage', item);
            assert.deepStrictEqual(updatedValue, ['bloc']);
        });
    });
    describe('bulk suppression via config-service', () => {
        const { addSuppressedPackages, clearSuppressedPackages } = require('../../services/config-service');
        it('should add multiple packages at once', async () => {
            let updatedValue = null;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => ['existing'],
                update: async (_key, value) => {
                    updatedValue = value;
                },
            });
            const count = await addSuppressedPackages(['http', 'bloc', 'existing']);
            assert.strictEqual(count, 2);
            assert.deepStrictEqual(updatedValue, ['existing', 'http', 'bloc']);
        });
        it('should return 0 when all packages already suppressed', async () => {
            let updateCalled = false;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => ['http', 'bloc'],
                update: async () => { updateCalled = true; },
            });
            const count = await addSuppressedPackages(['http', 'bloc']);
            assert.strictEqual(count, 0);
            assert.strictEqual(updateCalled, false);
        });
        it('should clear all suppressed packages', async () => {
            let updatedValue = null;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => ['http', 'bloc', 'provider'],
                update: async (_key, value) => {
                    updatedValue = value;
                },
            });
            const count = await clearSuppressedPackages();
            assert.strictEqual(count, 3);
            assert.deepStrictEqual(updatedValue, []);
        });
        it('should return 0 when clearing empty list', async () => {
            let updateCalled = false;
            sandbox.stub(vscode_mock_1.workspace, 'getConfiguration').returns({
                get: (_key, _defaultValue) => [],
                update: async () => { updateCalled = true; },
            });
            const count = await clearSuppressedPackages();
            assert.strictEqual(count, 0);
            assert.strictEqual(updateCalled, false);
        });
    });
    describe('openUrl', () => {
        it('should open the given URL in external browser', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.openUrl', 'https://pub.dev/packages/http/changelog#253');
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 1);
            assert.ok(vscode_mock_1.envMock.openedUrls[0].includes('changelog#253'));
        });
        it('should accept a DetailItem with url property', async () => {
            const item = new tree_items_1.DetailItem('Latest', '2.0.0', 'https://pub.dev/packages/http/versions/2.0.0');
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.openUrl', item);
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 1);
            assert.ok(vscode_mock_1.envMock.openedUrls[0].includes('versions/2.0.0'));
        });
        it('should do nothing when URL is empty', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.openUrl', '');
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 0);
        });
        it('should do nothing when argument is undefined', async () => {
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.openUrl', undefined);
            assert.strictEqual(vscode_mock_1.envMock.openedUrls.length, 0);
        });
    });
    describe('updateToLatest', () => {
        it('should do nothing when no latest version', async () => {
            const item = new tree_items_1.PackageItem(makeResult('http', 80));
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.updateToLatest', item);
        });
        it('should show warning when package line not found', async () => {
            const result = makeResult('http', 50, '2.0.0');
            const item = new tree_items_1.PackageItem(result);
            const fakeUri = vscode.Uri.file('/test/pubspec.yaml');
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([fakeUri]);
            sandbox.stub(vscode_mock_1.workspace, 'openTextDocument').resolves({
                getText: () => 'dependencies:\n  bloc: ^1.0.0',
                lineCount: 2,
                lineAt: (i) => ({
                    text: ['dependencies:', '  bloc: ^1.0.0'][i] ?? '',
                }),
            });
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.updateToLatest', item);
            assert.strictEqual(vscode_mock_1.messageMock.warnings.length, 1);
            assert.ok(vscode_mock_1.messageMock.warnings[0].includes('http'));
        });
    });
    describe('commentOutUnused', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([]);
            const r = { ...makeResult('http', 80), isUnused: true };
            const item = new tree_items_1.PackageItem(r);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.commentOutUnused', item);
        });
    });
    describe('deleteUnused', () => {
        it('should do nothing when no pubspec.yaml found', async () => {
            sandbox.stub(vscode_mock_1.workspace, 'findFiles').resolves([]);
            const r = { ...makeResult('http', 80), isUnused: true };
            const item = new tree_items_1.PackageItem(r);
            await vscode.commands.executeCommand('saropaLints.packageVibrancy.deleteUnused', item);
        });
    });
});
function makeFakeDoc(lines) {
    return {
        lineCount: lines.length,
        lineAt: (i) => ({ text: lines[i] ?? '' }),
    };
}
describe('findPackageLines', () => {
    it('should find a single-line dependency', () => {
        const doc = makeFakeDoc(['dependencies:', '  http: ^1.0.0', '  bloc: ^2.0.0']);
        const result = (0, tree_commands_1.findPackageLines)(doc, 'http');
        assert.deepStrictEqual(result, { start: 1, end: 2 });
    });
    it('should include continuation lines for multi-line deps', () => {
        const doc = makeFakeDoc([
            'dependencies:', '  my_pkg:', '    git:',
            '      url: https://github.com/foo/bar', '  bloc: ^2.0.0',
        ]);
        const result = (0, tree_commands_1.findPackageLines)(doc, 'my_pkg');
        assert.deepStrictEqual(result, { start: 1, end: 4 });
    });
    it('should return null when package not found', () => {
        const doc = makeFakeDoc(['dependencies:', '  bloc: ^2.0.0']);
        assert.strictEqual((0, tree_commands_1.findPackageLines)(doc, 'http'), null);
    });
    it('should handle package at end of file', () => {
        const doc = makeFakeDoc(['dependencies:', '  http: ^1.0.0']);
        const result = (0, tree_commands_1.findPackageLines)(doc, 'http');
        assert.deepStrictEqual(result, { start: 1, end: 2 });
    });
});
//# sourceMappingURL=tree-commands.test.js.map
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
const codelens_provider_1 = require("../../../vibrancy/providers/codelens-provider");
function makeResult(name, overrides = {}) {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 85,
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
        transitiveInfo: null, alternatives: [],
        latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
        ...overrides,
    };
}
const PUBSPEC_CONTENT = [
    'name: my_app',
    'dependencies:',
    '  http: ^1.0.0',
    '  path: ^1.8.0',
    'dev_dependencies:',
    '  test: ^1.24.0',
].join('\n');
function makeMockDocument(text, fileName = '/test/pubspec.yaml') {
    return {
        fileName,
        uri: { fsPath: fileName },
        getText() { return text; },
    };
}
describe('VibrancyCodeLensProvider', () => {
    let provider;
    beforeEach(() => {
        provider = new codelens_provider_1.VibrancyCodeLensProvider();
    });
    afterEach(() => {
        provider.dispose();
    });
    it('should return empty array when no results loaded', () => {
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.deepStrictEqual(lenses, []);
    });
    it('should return empty for non-pubspec files', () => {
        provider.updateResults([makeResult('http')]);
        const doc = makeMockDocument(PUBSPEC_CONTENT, '/test/other.yaml');
        const lenses = provider.provideCodeLenses(doc);
        assert.deepStrictEqual(lenses, []);
    });
    it('should return one status CodeLens per matched package without updates', () => {
        provider.updateResults([
            makeResult('http'),
            makeResult('path'),
        ]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.strictEqual(lenses.length, 2);
    });
    it('should skip packages not found in pubspec', () => {
        provider.updateResults([makeResult('nonexistent')]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.strictEqual(lenses.length, 0);
    });
    it('should position CodeLens on the package line', () => {
        provider.updateResults([makeResult('http')]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.ok(lenses.length >= 1);
        assert.strictEqual(lenses[0].range.start.line, 2);
    });
    it('should set focusPackageInTree command on status lens', () => {
        provider.updateResults([makeResult('http')]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.strictEqual(lenses[0].command?.command, 'saropaLints.packageVibrancy.focusPackageInTree');
        assert.deepStrictEqual(lenses[0].command?.arguments, ['http']);
    });
    it('should include score in CodeLens title', () => {
        provider.updateResults([makeResult('http', { score: 85 })]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.ok(lenses[0].command?.title.includes('9/10'));
    });
    it('should include category label in title', () => {
        provider.updateResults([makeResult('http')]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.ok(lenses[0].command?.title.includes('Vibrant'));
    });
    it('should update CodeLenses when results change', () => {
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        assert.strictEqual(provider.provideCodeLenses(doc).length, 0);
        provider.updateResults([makeResult('http')]);
        assert.ok(provider.provideCodeLenses(doc).length >= 1);
        provider.updateResults([]);
        assert.strictEqual(provider.provideCodeLenses(doc).length, 0);
    });
    it('should add update lens when update available', () => {
        provider.updateResults([makeResult('http', {
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    updateStatus: 'major',
                    changelog: null,
                },
            })]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.strictEqual(lenses.length, 2);
        assert.strictEqual(lenses[1].command?.command, 'saropaLints.packageVibrancy.updateFromCodeLens');
        assert.ok(lenses[1].command?.title.includes('2.0.0'));
    });
    it('should not add update lens when up-to-date', () => {
        provider.updateResults([makeResult('http', {
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '1.0.0',
                    updateStatus: 'up-to-date',
                    changelog: null,
                },
            })]);
        const doc = makeMockDocument(PUBSPEC_CONTENT);
        const lenses = provider.provideCodeLenses(doc);
        assert.strictEqual(lenses.length, 1);
    });
    it('should fire onDidChangeCodeLenses on result update', () => {
        let fired = false;
        provider.onDidChangeCodeLenses(() => { fired = true; });
        provider.updateResults([makeResult('http')]);
        assert.strictEqual(fired, true);
    });
});
//# sourceMappingURL=codelens-provider.test.js.map
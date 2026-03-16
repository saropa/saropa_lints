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
const diagnostics_1 = require("../../../vibrancy/providers/diagnostics");
const vscode_mock_1 = require("../vscode-mock");
const PUBSPEC_CONTENT = `dependencies:
  http: ^1.0.0
  flutter_bloc: ^8.0.0
  old_pkg: ^0.1.0
`;
function makeResult(name, score, category) {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 0,
        engagementLevel: 0,
        popularity: 0,
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
describe('VibrancyDiagnostics', () => {
    let collection;
    let diagnostics;
    const uri = vscode.Uri.file('/test/pubspec.yaml');
    beforeEach(() => {
        (0, vscode_mock_1.clearTestConfig)();
        collection = new vscode_mock_1.MockDiagnosticCollection('test');
        diagnostics = new diagnostics_1.VibrancyDiagnostics(collection);
    });
    afterEach(() => {
        (0, vscode_mock_1.clearTestConfig)();
    });
    it('should create diagnostics for non-vibrant packages', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [
            makeResult('http', 80, 'vibrant'),
            makeResult('flutter_bloc', 35, 'legacy-locked'),
            makeResult('old_pkg', 5, 'end-of-life'),
        ];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags.length, 2);
    });
    it('should skip end-of-life diagnostics when setting is none', () => {
        const results = [
            makeResult('flutter_bloc', 35, 'legacy-locked'),
            makeResult('old_pkg', 5, 'end-of-life'),
        ];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags.length, 1);
        assert.strictEqual(diags[0].code, 'legacy-locked');
    });
    it('should skip vibrant packages', () => {
        const results = [makeResult('http', 85, 'vibrant')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags.length, 0);
    });
    it('should set Hint severity for end-of-life with hint setting', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
    });
    it('should set Warning severity for end-of-life with smart setting and replacement', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'smart');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            knownIssue: {
                name: 'old_pkg',
                status: 'discontinued',
                reason: undefined,
                as_of: undefined,
                replacement: 'new_pkg',
                migrationNotes: undefined,
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Warning);
    });
    it('should set Hint severity for end-of-life with smart setting but no replacement', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'smart');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
    });
    it('should set Information severity for legacy-locked', () => {
        const results = [makeResult('flutter_bloc', 30, 'legacy-locked')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Information);
    });
    // Stale packages (score < 10) use Information severity and "Review" verb
    it('should set Information severity for stale packages', () => {
        const results = [makeResult('old_pkg', 5, 'stale')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Information);
    });
    it('should use Review verb for stale messages', () => {
        const results = [makeResult('old_pkg', 5, 'stale')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].message, 'Review old_pkg (1/10)');
    });
    it('should use Deprecated label for end-of-life messages without replacement', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].message, 'Deprecated: old_pkg (1/10)');
    });
    it('should use Review verb for legacy-locked messages', () => {
        const results = [makeResult('flutter_bloc', 35, 'legacy-locked')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].message, 'Review flutter_bloc (4/10)');
    });
    it('should use Monitor verb for quiet messages', () => {
        const results = [makeResult('http', 55, 'quiet')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].message, 'Monitor http (6/10)');
    });
    it('should suggest replacement in message when known', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            knownIssue: {
                name: 'old_pkg',
                status: 'discontinued',
                reason: 'No longer maintained',
                as_of: '2024-01-01',
                replacement: 'new_pkg',
                migrationNotes: 'Use new_pkg instead.',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.ok(diags[0].message.startsWith('Replace old_pkg with new_pkg'));
    });
    it('should use Deprecated — instruction when replacement is not a package name and version below target', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            package: { name: 'old_pkg', version: '8.0.0', constraint: '^8.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
            knownIssue: {
                name: 'old_pkg',
                status: 'end_of_life',
                reason: 'Pre-v5 keychain logic.',
                as_of: '2026-03-09',
                replacement: 'Update to v9+',
                replacementObsoleteFromVersion: '9.0.0',
                migrationNotes: 'Critical update.',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.ok(diags[0].message.startsWith('Deprecated: old_pkg — Update to v9+'));
    });
    it('should not show Update to v9+ in message when already on v10', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            package: { name: 'old_pkg', version: '10.0.0', constraint: '^10.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
            knownIssue: {
                name: 'old_pkg',
                status: 'end_of_life',
                reason: 'Pre-v5 keychain logic.',
                as_of: '2026-03-09',
                replacement: 'Update to v9+',
                replacementObsoleteFromVersion: '9.0.0',
                migrationNotes: 'Critical update.',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.ok(diags[0].message.startsWith('Deprecated: old_pkg'));
        assert.ok(!diags[0].message.includes('Update to v9+'), 'must not recommend v9 when on v10');
    });
    it('should include known issue reason in message', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            knownIssue: {
                name: 'old_pkg',
                status: 'discontinued',
                reason: 'No longer maintained',
                as_of: '2024-01-01',
                replacement: 'new_pkg',
                migrationNotes: 'Use new_pkg instead.',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.ok(diags[0].message.includes('No longer maintained'));
    });
    it('should set source to Saropa Package Vibrancy', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.strictEqual(diags[0].source, 'Saropa Package Vibrancy');
    });
    it('should create Hint diagnostic for unused packages', () => {
        const result = {
            ...makeResult('http', 80, 'vibrant'),
            isUnused: true,
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.strictEqual(diags.length, 1);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
        assert.strictEqual(diags[0].code, 'unused-dependency');
        assert.ok(diags[0].message.includes('Unused dependency'));
        assert.ok(diags[0].message.includes('http'));
    });
    it('should add unused diagnostic alongside category diagnostic', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            isUnused: true,
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri);
        assert.strictEqual(diags.length, 2);
        assert.strictEqual(diags[0].code, 'end-of-life');
        assert.strictEqual(diags[1].code, 'unused-dependency');
    });
    it('should clear diagnostics', () => {
        (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        diagnostics.clear();
        assert.strictEqual(collection.get(uri), undefined);
    });
});
//# sourceMappingURL=diagnostics.test.js.map
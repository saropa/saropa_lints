import * as assert from 'assert';
import * as vscode from 'vscode';
import { VibrancyDiagnostics } from '../../../vibrancy/providers/diagnostics';
import { VibrancyResult } from '../../../vibrancy/types';
import { MockDiagnosticCollection, setTestConfig, clearTestConfig } from '../vscode-mock';

const PUBSPEC_CONTENT = `dependencies:
  http: ^1.0.0
  flutter_bloc: ^8.0.0
  old_pkg: ^0.1.0
`;

/** Category codes for the main vibrancy diagnostic (abandoned/outdated/end-of-life/stable). */
const MAIN_VIBRANCY_CATEGORY_CODES = ['abandoned', 'outdated', 'end-of-life', 'stable'];

function makeResult(
    name: string,
    score: number,
    category: VibrancyResult['category'],
): VibrancyResult {
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
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null,
        blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('VibrancyDiagnostics', () => {
    let collection: MockDiagnosticCollection;
    let diagnostics: VibrancyDiagnostics;
    const uri = vscode.Uri.file('/test/pubspec.yaml');

    beforeEach(() => {
        clearTestConfig();
        setTestConfig('saropaLints.packageVibrancy', 'inlineDiagnostics', 'all');
        collection = new MockDiagnosticCollection('test');
        diagnostics = new VibrancyDiagnostics(
            collection as unknown as vscode.DiagnosticCollection,
        );
    });

    afterEach(() => {
        clearTestConfig();
    });

    it('should create diagnostics for non-vibrant packages', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [
            makeResult('http', 80, 'vibrant'),
            makeResult('flutter_bloc', 35, 'outdated'),
            makeResult('old_pkg', 5, 'end-of-life'),
        ];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags!.length, 2);
    });

    it('should skip end-of-life diagnostics when setting is none', () => {
        const results = [
            makeResult('flutter_bloc', 35, 'outdated'),
            makeResult('old_pkg', 5, 'end-of-life'),
        ];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags!.length, 1);
        assert.strictEqual(diags![0].code, 'outdated');
    });

    it('should skip vibrant packages', () => {
        const results = [makeResult('http', 85, 'vibrant')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri);
        assert.ok(diags);
        assert.strictEqual(diags!.length, 0);
    });

    it('should set Hint severity for end-of-life with hint setting', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
    });

    it('should set Warning severity for end-of-life with smart setting and replacement', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'smart');
        const result: VibrancyResult = {
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
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Warning);
    });

    it('should set Hint severity for end-of-life with smart setting but no replacement', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'smart');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
    });

    it('should set Information severity for outdated', () => {
        const results = [makeResult('flutter_bloc', 30, 'outdated')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Information);
    });

    // Abandoned packages use Information severity and "Review" verb
    it('should set Information severity for abandoned packages', () => {
        const results = [makeResult('old_pkg', 5, 'abandoned')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Information);
    });

    it('should use Review verb for abandoned messages', () => {
        const results = [makeResult('old_pkg', 5, 'abandoned')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].message, 'Review old_pkg (1/10)');
    });

    it('should use Deprecated label for end-of-life messages without replacement', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].message, 'Deprecated: old_pkg (1/10)');
    });

    it('should use Review verb for outdated messages', () => {
        const results = [makeResult('flutter_bloc', 35, 'outdated')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].message, 'Review flutter_bloc (4/10)');
    });

    it('should use Monitor verb for stable messages', () => {
        const results = [makeResult('http', 55, 'stable')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].message, 'Monitor http (6/10)');
    });

    it('should suggest replacement in message when known', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
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
        const diags = collection.get(uri)!;
        assert.ok(diags[0].message.startsWith('Replace old_pkg with new_pkg'));
    });

    it('should use Deprecated — instruction when replacement is not a package name and version below target', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
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
        const diags = collection.get(uri)!;
        assert.ok(diags[0].message.startsWith('Deprecated: old_pkg — Update to v9+'));
    });

    it('should not show Update to v9+ in message when already on v10', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
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
        const diags = collection.get(uri)!;
        assert.ok(diags[0].message.startsWith('Deprecated: old_pkg'));
        assert.ok(!diags[0].message.includes('Update to v9+'), 'must not recommend v9 when on v10');
    });

    it('should include known issue reason in message', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
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
        const diags = collection.get(uri)!;
        assert.ok(diags[0].message.includes('No longer maintained'));
    });

    it('should set source to Package Vibrancy', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags[0].source, 'Package Vibrancy');
    });

    it('should create Hint diagnostic for unused packages', () => {
        const result: VibrancyResult = {
            ...makeResult('http', 80, 'vibrant'),
            isUnused: true,
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags.length, 1);
        assert.strictEqual(diags[0].severity, vscode.DiagnosticSeverity.Hint);
        assert.strictEqual(diags[0].code, 'unused-dependency');
        assert.ok(diags[0].message.includes('Unused dependency'));
        assert.ok(diags[0].message.includes('http'));
    });

    it('should add unused diagnostic alongside category diagnostic', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
            ...makeResult('old_pkg', 5, 'end-of-life'),
            isUnused: true,
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri)!;
        assert.strictEqual(diags.length, 2);
        assert.strictEqual(diags[0].code, 'end-of-life');
        assert.strictEqual(diags[1].code, 'unused-dependency');
    });

    it('should clear diagnostics', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'end-of-life')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        diagnostics.clear();
        assert.strictEqual(collection.get(uri), undefined);
    });

    it('should not emit vibrancy diagnostic for path-overridden packages', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
            ...makeResult('old_pkg', 5, 'abandoned'),
            package: {
                name: 'old_pkg',
                version: '1.0.0',
                constraint: '^0.1.0',
                source: 'path',
                isDirect: true,
                section: 'dependencies',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri) ?? [];
        const categoryDiags = diags.filter(d => typeof d.code === 'string' && MAIN_VIBRANCY_CATEGORY_CODES.includes(d.code));
        assert.strictEqual(categoryDiags.length, 0, 'path-overridden package should not get main vibrancy diagnostic');
    });

    it('should not emit vibrancy diagnostic for git-overridden packages', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const result: VibrancyResult = {
            ...makeResult('old_pkg', 5, 'abandoned'),
            package: {
                name: 'old_pkg',
                version: '1.0.0',
                constraint: '^0.1.0',
                source: 'git',
                isDirect: true,
                section: 'dependencies',
            },
        };
        diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
        const diags = collection.get(uri) ?? [];
        const categoryDiags = diags.filter(d => typeof d.code === 'string' && MAIN_VIBRANCY_CATEGORY_CODES.includes(d.code));
        assert.strictEqual(categoryDiags.length, 0, 'git-overridden package should not get main vibrancy diagnostic');
    });

    it('should still emit vibrancy diagnostic for hosted (non-overridden) packages', () => {
        setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
        const results = [makeResult('old_pkg', 5, 'abandoned')];
        diagnostics.update(uri, PUBSPEC_CONTENT, results);
        const diags = collection.get(uri) ?? [];
        const abandonedDiags = diags.filter(d => d.code === 'abandoned');
        assert.strictEqual(abandonedDiags.length, 1, 'hosted package should still get abandoned diagnostic');
    });

    describe('inlineDiagnostics mode', () => {
        it('none mode: no diagnostics at all', () => {
            setTestConfig('saropaLints.packageVibrancy', 'inlineDiagnostics', 'none');
            setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
            const result: VibrancyResult = {
                ...makeResult('old_pkg', 5, 'end-of-life'),
                isUnused: true,
            };
            diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
            const diags = collection.get(uri) ?? [];
            assert.strictEqual(diags.length, 0, 'none mode should show no diagnostics');
        });

        it('critical mode: per-line only for end-of-life', () => {
            setTestConfig('saropaLints.packageVibrancy', 'inlineDiagnostics', 'critical');
            setTestConfig('saropaLints.packageVibrancy', 'endOfLifeDiagnostics', 'hint');
            const results = [
                makeResult('old_pkg', 3, 'end-of-life'),
                makeResult('flutter_bloc', 8, 'abandoned'),
            ];
            diagnostics.update(uri, PUBSPEC_CONTENT, results);
            const diags = collection.get(uri) ?? [];
            const eolDiags = diags.filter(d => d.code === 'end-of-life');
            const abandonedDiags = diags.filter(d => d.code === 'abandoned');
            assert.strictEqual(eolDiags.length, 1, 'critical mode shows EOL per-line');
            assert.strictEqual(abandonedDiags.length, 0, 'critical mode hides abandoned per-line');
        });

        it('critical mode: still shows non-health diagnostics like unused', () => {
            setTestConfig('saropaLints.packageVibrancy', 'inlineDiagnostics', 'critical');
            const result: VibrancyResult = {
                ...makeResult('http', 80, 'vibrant'),
                isUnused: true,
            };
            diagnostics.update(uri, PUBSPEC_CONTENT, [result]);
            const diags = collection.get(uri) ?? [];
            const unusedDiags = diags.filter(d => d.code === 'unused-dependency');
            assert.strictEqual(unusedDiags.length, 1, 'critical mode still shows unused dependency diagnostics');
        });
    });
});

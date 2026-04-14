// Must be first import — redirects 'vscode' to the local mock
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { PubspecValidation, parseSuppressedRules } from '../pubspec-validation';
import { MockDiagnosticCollection, Diagnostic } from './vibrancy/vscode-mock';

function runValidation(
    content: string,
    opts?: { preferPinnedVersions?: boolean; pubspecUri?: ReturnType<typeof vscode.Uri.file> },
): Diagnostic[] {
    const collection = new MockDiagnosticCollection('test-pubspec');
    const validator = new PubspecValidation(collection as any);
    if (opts?.preferPinnedVersions) {
        validator.preferPinnedVersions = true;
    }
    const uri = opts?.pubspecUri ?? vscode.Uri.file('/test/pubspec.yaml');
    validator.update(uri, content);
    return (collection.get(uri) ?? []) as Diagnostic[];
}

function findByCode(
    diagnostics: Diagnostic[],
    code: string,
): Diagnostic[] {
    return diagnostics.filter(d => d.code === code);
}

// ── avoid_any_version ──────────────────────────────────────────

describe('avoid_any_version', () => {
    it('flags dependency with "any" constraint', () => {
        const content = [
            'dependencies:',
            '  http: any',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('http'));
    });

    it('does not flag caret constraint', () => {
        const content = [
            'dependencies:',
            '  http: ^1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 0);
    });

    it('flags any in dev_dependencies too', () => {
        const content = [
            'dev_dependencies:',
            '  test: any',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 1);
    });
});

// ── dependencies_ordering ──────────────────────────────────────

describe('dependencies_ordering', () => {
    it('flags unsorted dependencies', () => {
        const content = [
            'dependencies:',
            '  zebra: ^1.0.0',
            '  alpha: ^2.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 1);
    });

    it('passes sorted dependencies', () => {
        const content = [
            'dependencies:',
            '  alpha: ^1.0.0',
            '  beta: ^2.0.0',
            '  gamma: ^3.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('is case-insensitive', () => {
        const content = [
            'dependencies:',
            '  Alpha: ^1.0.0',
            '  beta: ^2.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag SDK deps before pub deps', () => {
        // SDK deps conventionally come first — not a sorting violation
        const content = [
            'dependencies:',
            '  flutter:',
            '    sdk: flutter',
            '  flutter_localizations:',
            '    sdk: flutter',
            '',
            '  airplane_mode_checker: ^3.2.0',
            '  http: ^1.6.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag SDK deps in dev_dependencies before pub deps', () => {
        const content = [
            'dev_dependencies:',
            '  flutter_test:',
            '    sdk: flutter',
            '  integration_test:',
            '    sdk: flutter',
            '',
            '  analyzer: any',
            '  build_runner: ^2.7.1',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('still flags unsorted pub deps when SDK deps are present', () => {
        // SDK deps are fine at top, but pub deps among themselves must
        // be alphabetical — here 'http' before 'airplane' is wrong
        const content = [
            'dependencies:',
            '  flutter:',
            '    sdk: flutter',
            '',
            '  http: ^1.6.0',
            '  airplane_mode_checker: ^3.2.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('http'));
    });

    it('does not flag multiple SDK deps regardless of mutual order', () => {
        // flutter_localizations before flutter is fine — SDK deps are
        // exempt from alphabetical ordering entirely
        const content = [
            'dependencies:',
            '  flutter_localizations:',
            '    sdk: flutter',
            '  flutter:',
            '    sdk: flutter',
            '',
            '  http: ^1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('checks each section independently', () => {
        const content = [
            'dependencies:',
            '  alpha: ^1.0.0',
            '',
            'dev_dependencies:',
            '  zebra: ^1.0.0',
            '  alpha: ^2.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'dependencies_ordering');
        // Only dev_dependencies is unsorted
        assert.strictEqual(diags.length, 1);
    });
});

// ── prefer_caret_version_syntax ────────────────────────────────

describe('prefer_caret_version_syntax', () => {
    it('flags bare version without caret', () => {
        const content = [
            'dependencies:',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('^1.2.3'));
    });

    it('does not flag caret version', () => {
        const content = [
            'dependencies:',
            '  http: ^1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag range constraint', () => {
        const content = [
            'dependencies:',
            "  http: '>=1.0.0 <2.0.0'",
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag empty constraint (hosted latest)', () => {
        const content = [
            'dependencies:',
            '  http:',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 0);
    });

    it('skips dependency_overrides section', () => {
        const content = [
            'dependency_overrides:',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 0);
    });

    it('handles quoted bare version', () => {
        const content = [
            'dependencies:',
            "  http: '1.2.3'",
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 1);
    });
});

// ── SDK / path / git deps ──────────────────────────────────────

describe('SDK and path deps', () => {
    it('skips flutter SDK dependency', () => {
        const content = [
            'dependencies:',
            '  flutter:',
            '    sdk: flutter',
            '  http: ^1.0.0',
        ].join('\n');
        const diags = runValidation(content);
        // flutter SDK dep should not trigger any checks
        const flutterDiags = diags.filter(
            d => typeof d.message === 'string' && d.message.includes('flutter'),
        );
        assert.strictEqual(flutterDiags.length, 0);
    });

    it('skips path dependency', () => {
        const content = [
            'dependencies:',
            '  my_pkg:',
            '    path: ../my_pkg',
        ].join('\n');
        const diags = runValidation(content);
        assert.strictEqual(diags.length, 0);
    });

    it('skips git dependency', () => {
        const content = [
            'dependencies:',
            '  my_pkg:',
            '    git:',
            '      url: https://github.com/user/repo.git',
        ].join('\n');
        const diags = runValidation(content);
        assert.strictEqual(diags.length, 0);
    });
});

// ── Edge cases ─────────────────────────────────────────────────

describe('edge cases', () => {
    it('produces no diagnostics for minimal clean pubspec', () => {
        const content = 'name: my_app\n\nversion: 1.0.0\n\npublish_to: none\n';
        const diags = runValidation(content);
        assert.strictEqual(diags.length, 0);
    });

    it('handles Windows CRLF line endings', () => {
        const content = 'dependencies:\r\n  alpha: ^1.0.0\r\n  beta: ^2.0.0\r\n';
        const diags = runValidation(content);
        assert.strictEqual(diags.length, 0);
    });

    it('flags quoted any constraint', () => {
        const content = [
            'dependencies:',
            "  http: 'any'",
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 1);
    });
});

// ── avoid_dependency_overrides ────────────────────────────────

describe('avoid_dependency_overrides', () => {
    it('flags override without comment', () => {
        const content = [
            'dependency_overrides:',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_dependency_overrides');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('http'));
    });

    it('skips override with inline comment', () => {
        const content = [
            'dependency_overrides:',
            '  http: 1.2.3 # needed for compat testing',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_dependency_overrides');
        assert.strictEqual(diags.length, 0);
    });

    it('skips override with comment on line above', () => {
        const content = [
            'dependency_overrides:',
            '  # Pinned to fix upstream bug #123',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_dependency_overrides');
        assert.strictEqual(diags.length, 0);
    });

    it('flags multiple uncommented overrides', () => {
        const content = [
            'dependency_overrides:',
            '  http: 1.2.3',
            '  path: 2.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_dependency_overrides');
        assert.strictEqual(diags.length, 2);
    });

    it('does not flag regular dependencies section', () => {
        const content = [
            'dependencies:',
            '  http: ^1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_dependency_overrides');
        assert.strictEqual(diags.length, 0);
    });
});

// ── prefer_publish_to_none ───────────────────────────────────

describe('prefer_publish_to_none', () => {
    it('flags pubspec without publish_to field', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('my_app'));
    });

    it('does not flag pubspec with publish_to none', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
            'publish_to: none',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag pubspec with custom publish_to', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
            'publish_to: https://my-registry.example.com',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag pubspec without name field', () => {
        // Malformed pubspec — no name means we can't identify the package
        const content = 'version: 1.0.0\n';
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });

    it('diagnostic is attached to the name line', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 1);
        // name: is on line 0
        assert.strictEqual(diags[0].range.start.line, 0);
    });

    it('does not flag pubspec with topics field (pub.dev package)', () => {
        // topics: is exclusively a pub.dev feature — its presence means
        // the package is intentionally published
        const content = [
            'name: my_published_pkg',
            'version: 1.0.0',
            'topics:',
            '  - linter',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag pubspec with homepage field', () => {
        const content = [
            'name: my_published_pkg',
            'version: 1.0.0',
            'homepage: https://pub.dev/packages/my_published_pkg',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag pubspec with repository field', () => {
        const content = [
            'name: my_published_pkg',
            'version: 1.0.0',
            'repository: https://github.com/user/my_published_pkg',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_publish_to_none');
        assert.strictEqual(diags.length, 0);
    });
});

// ── prefer_pinned_version_syntax ──────────────────────────────

describe('prefer_pinned_version_syntax', () => {
    const pinned = { preferPinnedVersions: true };

    it('flags caret version constraint', () => {
        const content = [
            'dependencies:',
            '  http: ^1.2.3',
        ].join('\n');
        const diags = findByCode(
            runValidation(content, pinned), 'prefer_pinned_version_syntax',
        );
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('1.2.3'));
    });

    it('does not flag bare version (already pinned)', () => {
        const content = [
            'dependencies:',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(
            runValidation(content, pinned), 'prefer_pinned_version_syntax',
        );
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag range constraint', () => {
        const content = [
            'dependencies:',
            "  http: '>=1.0.0 <2.0.0'",
        ].join('\n');
        const diags = findByCode(
            runValidation(content, pinned), 'prefer_pinned_version_syntax',
        );
        assert.strictEqual(diags.length, 0);
    });

    it('skips dependency_overrides section', () => {
        const content = [
            'dependency_overrides:',
            '  http: ^1.2.3 # compat',
        ].join('\n');
        const diags = findByCode(
            runValidation(content, pinned), 'prefer_pinned_version_syntax',
        );
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag any constraint', () => {
        const content = [
            'dependencies:',
            '  http: any',
        ].join('\n');
        const diags = findByCode(
            runValidation(content, pinned), 'prefer_pinned_version_syntax',
        );
        assert.strictEqual(diags.length, 0);
    });

    it('does not run when preferPinnedVersions is false', () => {
        const content = [
            'dependencies:',
            '  http: ^1.2.3',
        ].join('\n');
        // Default mode — should not fire pinned check
        const diags = findByCode(runValidation(content), 'prefer_pinned_version_syntax');
        assert.strictEqual(diags.length, 0);
    });
});

// ── pubspec_ordering ──────────────────────────────────────────

describe('pubspec_ordering', () => {
    it('flags field out of recommended order', () => {
        const content = [
            'version: 1.0.0',
            '',
            'name: my_app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('name'));
        assert.ok(diags[0].message.includes('version'));
    });

    it('passes fields in correct order', () => {
        const content = [
            'name: my_app',
            '',
            'version: 1.0.0',
            '',
            'environment:',
            '  sdk: ^3.0.0',
            '',
            'dependencies:',
            '  http: ^1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('ignores unknown fields', () => {
        const content = [
            'name: my_app',
            '',
            'custom_field: value',
            '',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('reports only the first out-of-order field', () => {
        const content = [
            'dependencies:',
            '  http: ^1.0.0',
            '',
            'environment:',
            '  sdk: ^3.0.0',
            '',
            'name: my_app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 1);
    });
});

// ── newline_before_pubspec_entry ──────────────────────────────

describe('newline_before_pubspec_entry', () => {
    it('flags section without preceding blank line', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('version'));
    });

    it('passes when blank line separates sections', () => {
        const content = [
            'name: my_app',
            '',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 0);
    });

    it('accepts comment line as separator', () => {
        const content = [
            'name: my_app',
            '# Version info',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag the first line', () => {
        const content = 'name: my_app\n';
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 0);
    });

    it('flags multiple consecutive sections without blank lines', () => {
        const content = [
            'name: my_app',
            'version: 1.0.0',
            'description: A test app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 2);
    });
});

// ── prefer_commenting_pubspec_ignores ─────────────────────────

describe('prefer_commenting_pubspec_ignores', () => {
    it('flags ignored advisory without comment', () => {
        const content = [
            'ignored_advisories:',
            '  - GHSA-xxxx-yyyy-zzzz',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_commenting_pubspec_ignores');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('GHSA-xxxx-yyyy-zzzz'));
    });

    it('skips advisory with inline comment', () => {
        const content = [
            'ignored_advisories:',
            '  - GHSA-xxxx-yyyy-zzzz # not exploitable in our usage',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_commenting_pubspec_ignores');
        assert.strictEqual(diags.length, 0);
    });

    it('skips advisory with comment on line above', () => {
        const content = [
            'ignored_advisories:',
            '  # We never parse untrusted XML',
            '  - GHSA-xxxx-yyyy-zzzz',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_commenting_pubspec_ignores');
        assert.strictEqual(diags.length, 0);
    });

    it('flags multiple uncommented advisories', () => {
        const content = [
            'ignored_advisories:',
            '  - GHSA-aaaa-bbbb-cccc',
            '  - GHSA-dddd-eeee-ffff',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_commenting_pubspec_ignores');
        assert.strictEqual(diags.length, 2);
    });

    it('produces no diagnostics when no ignored_advisories section', () => {
        const content = [
            'name: my_app',
            '',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_commenting_pubspec_ignores');
        assert.strictEqual(diags.length, 0);
    });
});

// ── add_resolution_workspace ─────────────────────────────────

describe('add_resolution_workspace', () => {
    it('flags workspace root without resolution field', () => {
        const content = [
            'name: mono_root',
            '',
            'workspace:',
            '  - packages/app',
            '  - packages/shared',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'add_resolution_workspace');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('resolution'));
    });

    it('passes workspace root with resolution field', () => {
        const content = [
            'name: mono_root',
            '',
            'resolution: workspace',
            '',
            'workspace:',
            '  - packages/app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'add_resolution_workspace');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag non-workspace pubspec', () => {
        const content = [
            'name: my_app',
            '',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'add_resolution_workspace');
        assert.strictEqual(diags.length, 0);
    });
});

// ── prefer_l10n_yaml_config ──────────────────────────────────

describe('prefer_l10n_yaml_config', () => {
    it('flags generate: true under flutter section', () => {
        const content = [
            'name: my_app',
            '',
            'flutter:',
            '  generate: true',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_l10n_yaml_config');
        assert.strictEqual(diags.length, 1);
        assert.ok(diags[0].message.includes('l10n.yaml'));
    });

    it('does not flag flutter section without generate', () => {
        const content = [
            'name: my_app',
            '',
            'flutter:',
            '  uses-material-design: true',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_l10n_yaml_config');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag generate: false', () => {
        const content = [
            'name: my_app',
            '',
            'flutter:',
            '  generate: false',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_l10n_yaml_config');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag generate outside flutter section', () => {
        const content = [
            'name: my_app',
            '',
            'custom:',
            '  generate: true',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_l10n_yaml_config');
        assert.strictEqual(diags.length, 0);
    });

    it('does not flag when l10n.yaml exists alongside pubspec', () => {
        // Create a temp directory with l10n.yaml to simulate a project
        // that already follows the recommended pattern
        const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-l10n-'));
        try {
            fs.writeFileSync(path.join(tmpDir, 'l10n.yaml'), 'arb-dir: lib/l10n\n');
            const pubspecUri = vscode.Uri.file(path.join(tmpDir, 'pubspec.yaml'));
            const content = [
                'name: my_app',
                '',
                'flutter:',
                '  generate: true',
            ].join('\n');
            const diags = findByCode(
                runValidation(content, { pubspecUri }),
                'prefer_l10n_yaml_config',
            );
            // l10n.yaml exists — generate: true is required by Flutter
            // tooling, so the rule should NOT fire
            assert.strictEqual(diags.length, 0);
        } finally {
            fs.rmSync(tmpDir, { recursive: true, force: true });
        }
    });

    it('flags when l10n.yaml does not exist alongside pubspec', () => {
        // Create a temp directory WITHOUT l10n.yaml — the rule should
        // fire because there is no dedicated config file
        const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-l10n-'));
        try {
            const pubspecUri = vscode.Uri.file(path.join(tmpDir, 'pubspec.yaml'));
            const content = [
                'name: my_app',
                '',
                'flutter:',
                '  generate: true',
            ].join('\n');
            const diags = findByCode(
                runValidation(content, { pubspecUri }),
                'prefer_l10n_yaml_config',
            );
            assert.strictEqual(diags.length, 1);
        } finally {
            fs.rmSync(tmpDir, { recursive: true, force: true });
        }
    });
});

// ── parseSuppressedRules ─────────────────────────────────────

describe('parseSuppressedRules', () => {
    it('parses single rule code', () => {
        const result = parseSuppressedRules('# saropa_lints:ignore avoid_any_version');
        assert.deepStrictEqual([...result], ['avoid_any_version']);
    });

    it('parses multiple rule codes', () => {
        const result = parseSuppressedRules(
            '# saropa_lints:ignore avoid_any_version, dependencies_ordering',
        );
        assert.ok(result.has('avoid_any_version'));
        assert.ok(result.has('dependencies_ordering'));
        assert.strictEqual(result.size, 2);
    });

    it('returns empty set for normal comment', () => {
        const result = parseSuppressedRules('# This is a normal comment');
        assert.strictEqual(result.size, 0);
    });

    it('returns empty set when no rule codes after ignore', () => {
        // "saropa_lints:ignore" with nothing after it — the \s+ in the
        // regex requires at least one whitespace char, so this won't match
        const result = parseSuppressedRules('# saropa_lints:ignore');
        assert.strictEqual(result.size, 0);
    });

    it('handles extra whitespace', () => {
        const result = parseSuppressedRules(
            '#   saropa_lints:ignore   avoid_any_version  ,  dependencies_ordering  ',
        );
        assert.ok(result.has('avoid_any_version'));
        assert.ok(result.has('dependencies_ordering'));
        assert.strictEqual(result.size, 2);
    });
});

// ── Inline suppression (centralized filter) ──────────────────

describe('inline suppression', () => {
    it('suppresses avoid_any_version via comment on line above', () => {
        const content = [
            'dependencies:',
            '  # saropa_lints:ignore avoid_any_version',
            '  http: any',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 0);
    });

    it('suppresses avoid_any_version via inline comment', () => {
        const content = [
            'dependencies:',
            '  http: any # saropa_lints:ignore avoid_any_version',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        assert.strictEqual(diags.length, 0);
    });

    it('does not suppress with wrong rule code', () => {
        const content = [
            'dependencies:',
            '  # saropa_lints:ignore dependencies_ordering',
            '  http: any',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        // Wrong code — avoid_any_version should still fire
        assert.strictEqual(diags.length, 1);
    });

    it('does not suppress with unrelated comment', () => {
        const content = [
            'dependencies:',
            '  # This uses any intentionally',
            '  http: any',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'avoid_any_version');
        // Regular comment is not a suppression directive
        assert.strictEqual(diags.length, 1);
    });

    it('suppresses prefer_caret_version_syntax', () => {
        const content = [
            'dependencies:',
            '  # saropa_lints:ignore prefer_caret_version_syntax',
            '  http: 1.2.3',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'prefer_caret_version_syntax');
        assert.strictEqual(diags.length, 0);
    });

    it('suppresses newline_before_pubspec_entry via inline comment', () => {
        // The line-above position won't work here because the rule
        // already treats any comment line above as a valid separator
        // (so the diagnostic never fires). Use inline suppression
        // instead to verify the filter actually runs.
        const content = [
            'name: my_app',
            'version: 1.0.0 # saropa_lints:ignore newline_before_pubspec_entry',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 0);
    });

    it('still fires newline_before_pubspec_entry without suppression', () => {
        // Confirm the diagnostic actually fires without suppression,
        // so the test above is meaningful
        const content = [
            'name: my_app',
            'version: 1.0.0',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'newline_before_pubspec_entry');
        assert.strictEqual(diags.length, 1);
    });

    it('suppresses multiple rules on one line', () => {
        const content = [
            'name: my_app',
            'dependencies:',
            '  # saropa_lints:ignore avoid_any_version, prefer_caret_version_syntax',
            '  http: any',
        ].join('\n');
        const diags = runValidation(content);
        const anyDiags = findByCode(diags, 'avoid_any_version');
        const caretDiags = findByCode(diags, 'prefer_caret_version_syntax');
        assert.strictEqual(anyDiags.length, 0);
        assert.strictEqual(caretDiags.length, 0);
    });

    it('suppresses only the listed rule, not others on same line', () => {
        // This entry triggers both avoid_any_version and
        // dependencies_ordering (zebra before alpha is wrong).
        // Suppression targets only avoid_any_version.
        const content = [
            'dependencies:',
            '  # saropa_lints:ignore avoid_any_version',
            '  zebra: any',
            '  alpha: ^1.0.0',
        ].join('\n');
        const diags = runValidation(content);
        const anyDiags = findByCode(diags, 'avoid_any_version');
        const orderDiags = findByCode(diags, 'dependencies_ordering');
        // avoid_any_version suppressed, ordering still fires
        assert.strictEqual(anyDiags.length, 0);
        assert.strictEqual(orderDiags.length, 1);
    });

    it('suppresses pubspec_ordering when comment is adjacent to flagged field', () => {
        // The diagnostic attaches to the out-of-order field (name:
        // on line 3), so the suppression must be on line 2 (adjacent).
        // A comment on line 0 (next to version:) would NOT suppress
        // because it's not adjacent to the flagged line.
        const content = [
            'version: 1.0.0',
            '',
            '# saropa_lints:ignore pubspec_ordering',
            'name: my_app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 0);
    });

    it('does not suppress pubspec_ordering when comment is not adjacent', () => {
        // Suppression on line 0 is not adjacent to the flagged field
        // on line 3 — the diagnostic should still fire
        const content = [
            '# saropa_lints:ignore pubspec_ordering',
            'version: 1.0.0',
            '',
            'name: my_app',
        ].join('\n');
        const diags = findByCode(runValidation(content), 'pubspec_ordering');
        assert.strictEqual(diags.length, 1);
    });
});

// ── Combined ───────────────────────────────────────────────────

describe('combined checks', () => {
    it('reports multiple issues in one file', () => {
        const content = [
            'name: my_app',
            'dependencies:',
            '  zebra: any',
            '  alpha: 1.0.0',
        ].join('\n');
        const diags = runValidation(content);
        const codes = diags.map(d => d.code);
        assert.ok(codes.includes('avoid_any_version'));
        assert.ok(codes.includes('dependencies_ordering'));
        assert.ok(codes.includes('prefer_caret_version_syntax'));
        // Also flags missing publish_to and missing blank line
        assert.ok(codes.includes('prefer_publish_to_none'));
        assert.ok(codes.includes('newline_before_pubspec_entry'));
    });

    it('produces no diagnostics for clean pubspec', () => {
        const content = [
            'name: my_app',
            '',
            'version: 1.0.0',
            '',
            'publish_to: none',
            '',
            'environment:',
            '  sdk: ^3.0.0',
            '',
            'dependencies:',
            '  alpha: ^1.0.0',
            '  beta: ^2.0.0',
            '',
            'dev_dependencies:',
            '  test: ^1.0.0',
        ].join('\n');
        const diags = runValidation(content);
        assert.strictEqual(diags.length, 0);
    });
});

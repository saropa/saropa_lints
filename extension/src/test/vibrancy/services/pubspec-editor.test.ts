import * as assert from 'assert';
import {
    buildVersionEdit, readVersionConstraint,
    findPackageLines, buildBackupUri,
} from '../../../vibrancy/services/pubspec-editor';

/** Create a minimal fake TextDocument from raw text. */
function makeFakeDoc(text: string): any {
    const lines = text.split('\n');
    return {
        lineCount: lines.length,
        lineAt: (i: number) => ({ text: lines[i] ?? '' }),
    };
}

describe('pubspec-editor', () => {
    describe('buildVersionEdit', () => {
        it('should find and replace a caret constraint', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.2.0');
            const edit = buildVersionEdit(doc, 'http', '^2.0.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^2.0.0');
        });

        it('should return null for unknown package', () => {
            const doc = makeFakeDoc('dependencies:\n  http: ^1.2.0');
            const edit = buildVersionEdit(doc, 'missing', '^1.0.0');
            assert.strictEqual(edit, null);
        });

        it('should handle exact version constraints', () => {
            const doc = makeFakeDoc('  provider: 6.0.0');
            const edit = buildVersionEdit(doc, 'provider', '^6.1.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^6.1.0');
        });

        it('should handle quoted version values', () => {
            const doc = makeFakeDoc('  intl: "^0.18.0"');
            const edit = buildVersionEdit(doc, 'intl', '^0.19.0');
            assert.ok(edit);
            assert.strictEqual(edit.newText, '^0.19.0');
        });
    });

    describe('readVersionConstraint', () => {
        it('should read a caret constraint', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual(readVersionConstraint(doc, 'http'), '^1.2.0');
        });

        it('should trim whitespace from value', () => {
            const doc = makeFakeDoc('  http:   ^1.2.0  ');
            assert.strictEqual(readVersionConstraint(doc, 'http'), '^1.2.0');
        });

        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual(readVersionConstraint(doc, 'missing'), null);
        });

        it('should read exact version', () => {
            const doc = makeFakeDoc('  meta: 1.11.0');
            assert.strictEqual(readVersionConstraint(doc, 'meta'), '1.11.0');
        });
    });

    describe('findPackageLines', () => {
        it('should find a simple one-line entry', () => {
            const doc = makeFakeDoc(
                'dependencies:\n  http: ^1.2.0\n  meta: ^1.11.0',
            );
            const range = findPackageLines(doc, 'http');
            assert.deepStrictEqual(range, { start: 1, end: 2 });
        });

        it('should include continuation lines (deeper indent)', () => {
            const doc = makeFakeDoc([
                'dependencies:',
                '  http:',
                '    hosted: https://custom.pub',
                '    version: ^1.2.0',
                '  meta: ^1.11.0',
            ].join('\n'));
            const range = findPackageLines(doc, 'http');
            assert.deepStrictEqual(range, { start: 1, end: 4 });
        });

        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.2.0');
            assert.strictEqual(findPackageLines(doc, 'missing'), null);
        });
    });

    describe('buildBackupUri', () => {
        it('should produce a timestamped backup filename', () => {
            const fakeUri = { fsPath: '/project/pubspec.yaml' };
            const result = buildBackupUri(fakeUri as any);
            assert.ok(result);
            const path = result.path ?? result.fsPath ?? '';
            assert.ok(
                path.includes('pubspec.yaml.bak.'),
                `Expected backup pattern in: ${path}`,
            );
        });
    });
});

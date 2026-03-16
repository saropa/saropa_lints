import * as assert from 'assert';
import * as treeCommands from '../../../vibrancy/providers/tree-commands';

/** Create a minimal fake TextDocument from lines of text. */
function makeFakeDoc(line: string): {
    lineCount: number;
    lineAt: (i: number) => { text: string };
} {
    const lines = line.split('\n');
    return {
        lineCount: lines.length,
        lineAt: (i: number) => ({ text: lines[i] ?? '' }),
    };
}

describe('upgrade-command helpers', () => {
    describe('buildVersionEdit', () => {
        it('should build edit with the exact constraint passed', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const edit = treeCommands.buildVersionEdit(
                doc as any, 'http', '^2.0.0',
            );
            assert.strictEqual(edit?.newText, '^2.0.0');
        });

        it('should return null for unknown package', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const edit = treeCommands.buildVersionEdit(
                doc as any, 'missing', '^1.0.0',
            );
            assert.strictEqual(edit, null);
        });

        it('should preserve non-caret constraints', () => {
            const doc = makeFakeDoc('  http: >=1.0.0 <2.0.0');
            const edit = treeCommands.buildVersionEdit(
                doc as any, 'http', '>=2.0.0 <3.0.0',
            );
            assert.strictEqual(edit?.newText, '>=2.0.0 <3.0.0');
        });
    });

    describe('readVersionConstraint', () => {
        it('should read existing constraint', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const constraint = treeCommands.readVersionConstraint(
                doc as any, 'http',
            );
            assert.strictEqual(constraint, '^1.0.0');
        });

        it('should return null for missing package', () => {
            const doc = makeFakeDoc('  http: ^1.0.0');
            const constraint = treeCommands.readVersionConstraint(
                doc as any, 'missing',
            );
            assert.strictEqual(constraint, null);
        });

        it('should trim whitespace from constraint', () => {
            const doc = makeFakeDoc('  http:   ^1.0.0  ');
            const constraint = treeCommands.readVersionConstraint(
                doc as any, 'http',
            );
            assert.strictEqual(constraint, '^1.0.0');
        });

        it('should handle range constraints', () => {
            const doc = makeFakeDoc('  http: >=1.0.0 <2.0.0');
            const constraint = treeCommands.readVersionConstraint(
                doc as any, 'http',
            );
            assert.strictEqual(constraint, '>=1.0.0 <2.0.0');
        });
    });
});

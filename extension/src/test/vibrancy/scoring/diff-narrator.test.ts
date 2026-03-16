import * as assert from 'assert';
import { summarizeDiff, narrateDiff } from '../../../vibrancy/scoring/diff-narrator';
import { LockDiff } from '../../../vibrancy/services/lock-diff';

function makeDiff(overrides: Partial<LockDiff> = {}): LockDiff {
    return {
        added: [],
        removed: [],
        upgraded: [],
        downgraded: [],
        unchangedCount: 0,
        ...overrides,
    };
}

describe('diff-narrator', () => {
    describe('summarizeDiff', () => {
        it('should summarize upgrades', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            assert.strictEqual(summarizeDiff(diff), 'Lock file: 1 upgraded');
        });

        it('should summarize multiple change types', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
                added: [{ name: 'path', version: '1.8.0' }],
            });
            const result = summarizeDiff(diff);
            assert.ok(result.includes('1 upgraded'));
            assert.ok(result.includes('1 added'));
        });

        it('should return no changes for empty diff', () => {
            assert.strictEqual(
                summarizeDiff(makeDiff()), 'Lock file: no changes',
            );
        });

        it('should include removals', () => {
            const diff = makeDiff({
                removed: [{ name: 'old', version: '1.0.0' }],
            });
            assert.ok(summarizeDiff(diff).includes('1 removed'));
        });

        it('should include downgrades', () => {
            const diff = makeDiff({
                downgraded: [{ name: 'pkg', from: '2.0.0', to: '1.0.0' }],
            });
            assert.ok(summarizeDiff(diff).includes('1 downgraded'));
        });
    });

    describe('narrateDiff', () => {
        it('should include upgrade arrows', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            const text = narrateDiff(diff);
            assert.ok(text.includes('⬆ http 1.0.0 → 1.1.0'));
        });

        it('should include added entries', () => {
            const diff = makeDiff({
                added: [{ name: 'path', version: '1.8.0' }],
            });
            const text = narrateDiff(diff);
            assert.ok(text.includes('➕ path 1.8.0'));
        });

        it('should include removed entries', () => {
            const diff = makeDiff({
                removed: [{ name: 'old', version: '2.0.0' }],
            });
            const text = narrateDiff(diff);
            assert.ok(text.includes('➖ old 2.0.0'));
        });

        it('should include downgrade arrows', () => {
            const diff = makeDiff({
                downgraded: [{ name: 'pkg', from: '3.0.0', to: '2.0.0' }],
            });
            const text = narrateDiff(diff);
            assert.ok(text.includes('⬇ pkg 3.0.0 → 2.0.0'));
        });

        it('should start with summary line', () => {
            const diff = makeDiff({
                upgraded: [{ name: 'http', from: '1.0.0', to: '1.1.0' }],
            });
            const lines = narrateDiff(diff).split('\n');
            assert.ok(lines[0].startsWith('Lock file:'));
        });

        it('should list all entries when multiple exist', () => {
            const diff = makeDiff({
                upgraded: [
                    { name: 'http', from: '1.0.0', to: '1.1.0' },
                    { name: 'path', from: '1.8.0', to: '1.9.0' },
                ],
            });
            const text = narrateDiff(diff);
            assert.ok(text.includes('⬆ http'));
            assert.ok(text.includes('⬆ path'));
        });

        it('should handle empty diff gracefully', () => {
            const text = narrateDiff(makeDiff());
            assert.ok(text.includes('no changes'));
        });
    });
});

import * as assert from 'assert';
import { diffVersionMaps } from '../../../vibrancy/services/lock-diff';

describe('lock-diff', () => {
    describe('diffVersionMaps', () => {
        it('should detect added packages', () => {
            const old = new Map<string, string>();
            const next = new Map([['http', '1.0.0']]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.added.length, 1);
            assert.strictEqual(diff.added[0].name, 'http');
        });

        it('should detect removed packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map<string, string>();
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.removed.length, 1);
            assert.strictEqual(diff.removed[0].name, 'http');
        });

        it('should detect upgraded packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map([['http', '1.1.0']]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.upgraded[0].from, '1.0.0');
            assert.strictEqual(diff.upgraded[0].to, '1.1.0');
        });

        it('should detect downgraded packages', () => {
            const old = new Map([['http', '2.0.0']]);
            const next = new Map([['http', '1.9.0']]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.downgraded.length, 1);
            assert.strictEqual(diff.downgraded[0].from, '2.0.0');
        });

        it('should count unchanged packages', () => {
            const old = new Map([['http', '1.0.0']]);
            const next = new Map([['http', '1.0.0']]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.unchangedCount, 1);
            assert.strictEqual(diff.upgraded.length, 0);
        });

        it('should handle empty maps', () => {
            const diff = diffVersionMaps(new Map(), new Map());
            assert.strictEqual(diff.added.length, 0);
            assert.strictEqual(diff.removed.length, 0);
            assert.strictEqual(diff.unchangedCount, 0);
        });

        it('should classify pre-release version upgrade correctly', () => {
            const old = new Map([['pkg', '1.0.0']]);
            const next = new Map([['pkg', '2.0.0-dev.1']]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.downgraded.length, 0);
        });

        it('should handle mixed changes', () => {
            const old = new Map([
                ['http', '1.0.0'],
                ['path', '1.8.0'],
                ['old_pkg', '2.0.0'],
            ]);
            const next = new Map([
                ['http', '1.1.0'],
                ['path', '1.8.0'],
                ['new_pkg', '3.0.0'],
            ]);
            const diff = diffVersionMaps(old, next);
            assert.strictEqual(diff.upgraded.length, 1);
            assert.strictEqual(diff.added.length, 1);
            assert.strictEqual(diff.removed.length, 1);
            assert.strictEqual(diff.unchangedCount, 1);
        });
    });
});

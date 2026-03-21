import * as assert from 'node:assert';
import { serializeVibrancyNode } from '../treeSerializers';

describe('serializeVibrancyNode', () => {
    it('returns null for non-objects', () => {
        assert.strictEqual(serializeVibrancyNode(null), null);
        assert.strictEqual(serializeVibrancyNode(undefined), null);
        assert.strictEqual(serializeVibrancyNode('x'), null);
    });

    it('serializes package nodes only when result payload exists', () => {
        const withResult = serializeVibrancyNode({
            contextValue: 'vibrancyPackage',
            label: 'pkg',
            result: { name: 'a' },
        });
        assert.strictEqual(withResult?.type, 'vibrancyPackage');
        assert.deepStrictEqual(withResult?.data, { name: 'a' });

        // Same contextValue but no result: fallback still uses `type: cv`, but must not attach package `data`.
        const noResult = serializeVibrancyNode({
            contextValue: 'vibrancyPackage',
            label: 'partial',
        });
        assert.strictEqual(noResult?.label, 'partial');
        assert.strictEqual(noResult?.data, undefined);
        assert.ok(withResult?.data);
    });

    it('does not emit vibrancyProblem without problem payload', () => {
        const node = serializeVibrancyNode({
            contextValue: 'vibrancyProblem.stale',
            label: 'Issue',
        });
        assert.notStrictEqual(node?.type, 'vibrancyProblem');
        assert.strictEqual(node?.type, 'vibrancyProblem.stale');
    });

    it('emits vibrancyProblem when problem object is present', () => {
        const node = serializeVibrancyNode({
            contextValue: 'vibrancyProblem.stale',
            label: 'Issue',
            problem: { type: 'stale', severity: 'warning' },
            packageName: 'foo',
        });
        assert.strictEqual(node?.type, 'vibrancyProblem');
        assert.deepStrictEqual(node?.data, {
            problemType: 'stale',
            severity: 'warning',
            packageName: 'foo',
        });
    });

    it('does not emit suggestion shape without action payload', () => {
        const node = serializeVibrancyNode({
            contextValue: 'vibrancySuggestion.upgrade',
            label: 'Upgrade',
        });
        assert.notStrictEqual(node?.type, 'vibrancyProblemSuggestion');
    });

    it('uses vibrancyGroup for generic nodes with children[] after earlier matchers (dispatch order)', () => {
        const node = serializeVibrancyNode({
            contextValue: 'vibrancyUnknownGroup',
            label: 'Version',
            children: [],
        });
        assert.strictEqual(node?.type, 'vibrancyGroup');
    });

    it('section group context wins over children[] when both are set', () => {
        const node = serializeVibrancyNode({
            contextValue: 'vibrancySectionGroup',
            label: 'Section',
            children: [],
            section: 'deps',
            results: [],
        });
        assert.strictEqual(node?.type, 'vibrancySectionGroup');
    });

    it('matches detail nodes by URL even without vibrancyDetailLink context', () => {
        const node = serializeVibrancyNode({
            contextValue: 'somethingElse',
            label: 'Open',
            url: 'https://example.com',
        });
        assert.strictEqual(node?.type, 'vibrancyDetail');
        assert.deepStrictEqual(node?.data, { url: 'https://example.com' });
    });
});

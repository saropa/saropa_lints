import * as assert from 'node:assert';
import { serializeOverviewNode, serializeVibrancyNode } from '../treeSerializers';

describe('serializeOverviewNode', () => {
    it('serializes embedded configSetting nodes', () => {
        const j = serializeOverviewNode({
            kind: 'configSetting',
            label: 'Tier',
            description: 'recommended',
        });
        assert.strictEqual(j?.type, 'configSetting');
        assert.strictEqual(j?.label, 'Tier');
    });

    it('serializes overview section parents by contextValue', () => {
        assert.deepStrictEqual(serializeOverviewNode({ contextValue: 'overviewSettingsSection' }), {
            type: 'overviewSettingsSection',
            label: 'Settings',
        });
        assert.deepStrictEqual(serializeOverviewNode({ contextValue: 'overviewIssuesSection' }), {
            type: 'overviewIssuesSection',
            label: 'Issues',
        });
        assert.deepStrictEqual(serializeOverviewNode({ contextValue: 'overviewSidebarSection' }), {
            type: 'overviewSidebarSection',
            label: 'Sidebar',
        });
    });

    it('falls through to TreeItem JSON for toggle-like rows', () => {
        const j = serializeOverviewNode({
            label: 'Violations (3)',
            description: 'On',
        });
        assert.strictEqual(j?.type, 'overviewItem');
        assert.strictEqual(j?.label, 'Violations (3)');
        assert.strictEqual(j?.description, 'On');
    });

    it('old overviewOptionsSection contextValue falls through to generic item', () => {
        // Regression: the removed "Workspace options" parent must not match any section branch.
        const j = serializeOverviewNode({ contextValue: 'overviewOptionsSection', label: 'Workspace options' });
        assert.strictEqual(j?.type, 'overviewItem');
    });

    it('does not treat unknown kind as config when serializeConfigNode returns null', () => {
        const j = serializeOverviewNode({
            kind: 'severity',
            label: 'High',
            description: '12',
        });
        assert.strictEqual(j?.type, 'overviewItem');
        assert.strictEqual(j?.label, 'High');
    });
});

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

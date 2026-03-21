import * as assert from 'node:assert';
import { OVERVIEW_EMBEDDED_CONFIG_KINDS } from '../overviewEmbeddedConfigKinds';

/**
 * Regression: Overview must not treat arbitrary `{ kind: '…' }` objects as config nodes
 * (would hit `renderTreeItem` with an invalid union member at runtime).
 */
describe('OVERVIEW_EMBEDDED_CONFIG_KINDS', () => {
    it('includes every ConfigTreeNode kind', () => {
        for (const k of ['configSetting', 'triageGroup', 'triageRule', 'triageInfo'] as const) {
            assert.ok(OVERVIEW_EMBEDDED_CONFIG_KINDS.has(k), `missing ${k}`);
        }
    });

    it('does not include Issue-tree or other common kind strings (false positives)', () => {
        assert.ok(!OVERVIEW_EMBEDDED_CONFIG_KINDS.has('severity'));
        assert.ok(!OVERVIEW_EMBEDDED_CONFIG_KINDS.has('folder'));
        assert.ok(!OVERVIEW_EMBEDDED_CONFIG_KINDS.has('file'));
        assert.ok(!OVERVIEW_EMBEDDED_CONFIG_KINDS.has('bogus'));
    });
});

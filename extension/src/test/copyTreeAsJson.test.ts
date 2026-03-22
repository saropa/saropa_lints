/**
 * Tests selection resolution for **Copy as JSON** (Violations tree multi-select).
 *
 * Logic lives in `copyTreeAsJsonSelection.ts` (no `vscode` import) so Mocha can run under plain Node.
 */

import * as assert from 'node:assert';
import { resolveNodesForJsonExport } from '../copyTreeAsJsonSelection';

describe('resolveNodesForJsonExport', () => {
    it('returns empty when no item and no selection', () => {
        assert.deepStrictEqual(resolveNodesForJsonExport(undefined, undefined), []);
        assert.deepStrictEqual(resolveNodesForJsonExport(null, undefined), []);
    });

    it('returns empty when no item and selection is empty array (false positive: do not treat as multi-select)', () => {
        assert.deepStrictEqual(resolveNodesForJsonExport(undefined, []), []);
    });

    it('uses single item when selection is absent (single-click / legacy)', () => {
        const a = { id: 'a' };
        assert.deepStrictEqual(resolveNodesForJsonExport(a, undefined), [a]);
    });

    it('falls back to clicked item when selection is empty array', () => {
        const solo = { id: 'solo' };
        assert.deepStrictEqual(resolveNodesForJsonExport(solo, []), [solo]);
    });

    it('prefers non-empty selection over clicked item (multi-select)', () => {
        const clicked = { id: 'clicked' };
        const x = { id: 'x' };
        const y = { id: 'y' };
        assert.deepStrictEqual(resolveNodesForJsonExport(clicked, [x, y]), [x, y]);
    });
});

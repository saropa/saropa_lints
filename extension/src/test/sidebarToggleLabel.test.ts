import * as assert from 'node:assert';
import { formatSidebarToggleLabel } from '../sidebarToggleLabel';

describe('formatSidebarToggleLabel', () => {
    it('returns base label when count is undefined', () => {
        assert.strictEqual(formatSidebarToggleLabel('Package Vibrancy', undefined), 'Package Vibrancy');
    });

    it('returns base label when count is NaN (not finite)', () => {
        assert.strictEqual(formatSidebarToggleLabel('Violations', Number.NaN), 'Violations');
    });

    it('includes zero in parentheses (valid finite count)', () => {
        assert.strictEqual(formatSidebarToggleLabel('Summary', 0), 'Summary (0)');
    });

    it('includes positive counts', () => {
        assert.strictEqual(formatSidebarToggleLabel('Package Vibrancy', 2), 'Package Vibrancy (2)');
    });
});

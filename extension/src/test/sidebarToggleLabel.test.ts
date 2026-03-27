import * as assert from 'node:assert';
import { formatSidebarToggleLabel } from '../sidebarToggleLabel';
import { buildStatusBarLabel } from '../statusBarLabel';

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

describe('buildStatusBarLabel', () => {
    it('formats compact mixed metrics for health + vibrancy', () => {
        const label = buildStatusBarLabel({
            hasHealth: true,
            healthScore: 90,
            delta: ' ▲1',
            tier: 'recommended',
            showVibrancy: true,
            vibrancyLabel: '4/10',
        });
        assert.strictEqual(label, '90% ▲1 · V4/10');
    });

    it('falls back to tier when vibrancy is hidden', () => {
        const label = buildStatusBarLabel({
            hasHealth: true,
            healthScore: 90,
            delta: '',
            tier: 'recommended',
            showVibrancy: false,
            vibrancyLabel: null,
        });
        assert.strictEqual(label, '90% · recommended');
    });

    it('keeps non-health label short but disambiguated', () => {
        const label = buildStatusBarLabel({
            hasHealth: false,
            tier: 'recommended',
            showVibrancy: true,
            vibrancyLabel: '4/10',
        });
        assert.strictEqual(label, 'Saropa Lints · V4/10');
    });
});

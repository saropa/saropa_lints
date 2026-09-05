/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'node:assert';
import { formatSidebarToggleLabel } from '../sidebarToggleLabel';
import { buildStatusBarLabel, buildStatusBarMenuItems, STATUS_BAR_TRUSTED_COMMANDS } from '../statusBarLabel';

/** Sidebar activity-bar labels with optional issue counts (finite / NaN edge cases). */

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

    it('formats health-only label without a system health suffix (moved to its own status bar item)', () => {
        const label = buildStatusBarLabel({
            hasHealth: true,
            healthScore: 85,
            delta: '',
            tier: 'recommended',
            showVibrancy: false,
            vibrancyLabel: null,
        });
        assert.strictEqual(label, '85% · recommended');
    });
});

describe('buildStatusBarMenuItems', () => {
    // Regression guard for the status bar tooltip action menu: every command
    // a menu row links to must be allow-listed, or VS Code silently refuses
    // to execute the `command:` link on click (isTrusted.enabledCommands).
    // This is the only check tying the two lists together — without it,
    // renaming a command in one place but not the other breaks the link
    // with no test failure elsewhere.
    for (const enabled of [true, false]) {
        it(`every commandId is covered by STATUS_BAR_TRUSTED_COMMANDS (enabled=${enabled})`, () => {
            const uncovered = buildStatusBarMenuItems(enabled)
                .map((item) => item.commandId)
                .filter((id) => !STATUS_BAR_TRUSTED_COMMANDS.includes(id));
            assert.deepStrictEqual(uncovered, []);
        });
    }

    it('toggle row flips between disable (enabled) and enable (disabled)', () => {
        assert.strictEqual(buildStatusBarMenuItems(true)[0].commandId, 'saropaLints.disable');
        assert.strictEqual(buildStatusBarMenuItems(false)[0].commandId, 'saropaLints.enable');
    });
});

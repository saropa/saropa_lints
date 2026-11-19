/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'node:assert';
import { formatSidebarToggleLabel } from '../sidebarToggleLabel';
import { buildUnifiedStatusText, buildStatusBarMenuItems, STATUS_BAR_TRUSTED_COMMANDS } from '../statusBarLabel';

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

describe('buildUnifiedStatusText', () => {
    it('joins switch label and score parts', () => {
        assert.strictEqual(buildUnifiedStatusText('Saropa Lints: On', ['90% ▲1', 'V9/10']), 'Saropa Lints: On · 90% ▲1 · V9/10');
    });

    it('skips missing score parts', () => {
        assert.strictEqual(buildUnifiedStatusText('Saropa Lints: On', [undefined, 'V9/10']), 'Saropa Lints: On · V9/10');
    });

    it('is just the label when Off (no score)', () => {
        assert.strictEqual(buildUnifiedStatusText('Saropa Lints: Off', []), 'Saropa Lints: Off');
    });
});

describe('buildStatusBarMenuItems', () => {
    // Regression guard for the status bar tooltip action menu: every command
    // a menu row links to must be allow-listed, or VS Code silently refuses
    // to execute the `command:` link on click (isTrusted.enabledCommands).
    for (const kind of ['on', 'off', 'partial'] as const) {
        it(`every commandId is covered by STATUS_BAR_TRUSTED_COMMANDS (${kind})`, () => {
            const uncovered = buildStatusBarMenuItems(kind)
                .map((item) => item.commandId)
                .filter((id) => !STATUS_BAR_TRUSTED_COMMANDS.includes(id));
            assert.deepStrictEqual(uncovered, []);
        });
    }

    it('no row toggles lints; Process Health opens the toggles', () => {
        for (const kind of ['on', 'off', 'partial'] as const) {
            const ids = buildStatusBarMenuItems(kind).map((item) => item.commandId);
            assert.ok(!ids.includes('saropaLints.toggleLints'));
            assert.ok(ids.includes('saropaLints.showProcessHealth'));
        }
    });
});

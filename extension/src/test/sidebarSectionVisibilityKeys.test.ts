/**
 * Ensures sidebar section constants stay empty after the activity-bar migration
 * and that `setContext` key helpers still produce stable `saropaLints.*` ids.
 */
import * as assert from 'node:assert';
import {
    SIDEBAR_SECTIONS,
    SIDEBAR_SECTION_CONFIG_KEYS,
    SIDEBAR_SECTION_COUNT,
    defaultSidebarSectionVisible,
    sidebarSectionContextKey,
} from '../sidebarSectionVisibilityKeys';

describe('sidebarSectionVisibilityKeys', () => {
    it('has no activity-bar section toggles after dashboard migration', () => {
        assert.strictEqual(SIDEBAR_SECTION_COUNT, 0);
        assert.strictEqual(SIDEBAR_SECTION_CONFIG_KEYS.length, 0);
        assert.strictEqual(SIDEBAR_SECTIONS.length, 0);
    });

    it('builds setContext keys for programmatic toggles', () => {
        assert.strictEqual(
            sidebarSectionContextKey('sidebar.showOverview'),
            'saropaLints.sidebar.showOverview',
        );
    });

    it('defaultSidebarSectionVisible keeps overview on by default', () => {
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showOverview'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showSummary'), false);
    });
});

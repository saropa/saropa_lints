import * as assert from 'node:assert';
import {
    SIDEBAR_SECTION_CONFIG_KEYS,
    SIDEBAR_SECTION_COUNT,
    defaultSidebarSectionVisible,
    sidebarSectionContextKey,
} from '../sidebarSectionVisibilityKeys';

describe('sidebarSectionVisibilityKeys', () => {
    it('keeps config and context keys in sync with package.json sidebar settings', () => {
        assert.strictEqual(SIDEBAR_SECTION_COUNT, 12);
        assert.strictEqual(SIDEBAR_SECTION_CONFIG_KEYS.length, SIDEBAR_SECTION_COUNT);
    });

    it('builds setContext keys', () => {
        assert.strictEqual(
            sidebarSectionContextKey('sidebar.showPackageDetails'),
            'saropaLints.sidebar.showPackageDetails',
        );
    });

    it('defaults core sidebar on and secondary panels off', () => {
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showOverview'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showIssues'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showConfig'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showPackageDetails'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showDriftAdvisor'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showSummary'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showTodosAndHacks'), false);
    });
});

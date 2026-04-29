import * as assert from 'node:assert';
import {
    SIDEBAR_SECTIONS,
    SIDEBAR_SECTION_CONFIG_KEYS,
    SIDEBAR_SECTION_COUNT,
    defaultSidebarSectionVisible,
    sidebarSectionContextKey,
} from '../sidebarSectionVisibilityKeys';

// Counts and context keys for sidebar section visibility must match package.json.
describe('sidebarSectionVisibilityKeys', () => {
    it('keeps config and context keys in sync with package.json sidebar settings', () => {
        assert.strictEqual(SIDEBAR_SECTION_COUNT, 14);
        assert.strictEqual(SIDEBAR_SECTION_CONFIG_KEYS.length, SIDEBAR_SECTION_COUNT);
    });

    it('builds setContext keys', () => {
        assert.strictEqual(
            sidebarSectionContextKey('sidebar.showPackageDetails'),
            'saropaLints.sidebar.showPackageDetails',
        );
    });

    it('defaults core sidebar on and secondary panels off', () => {
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showCommandCatalog'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showOverview'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showIssues'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showRulePacks'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showPackageVibrancy'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showConfig'), false);
        // Package Details defaults on — when clause gates it behind hasResults.
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showPackageDetails'), true);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showDriftAdvisor'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showSummary'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showSuppressions'), false);
        assert.strictEqual(defaultSidebarSectionVisible('sidebar.showTodosAndHacks'), false);
    });

    it('uses Triage label for sidebar.showConfig', () => {
        const configSection = SIDEBAR_SECTIONS.find((section) => section.key === 'sidebar.showConfig');
        assert.strictEqual(configSection?.label, 'Triage');
    });
});

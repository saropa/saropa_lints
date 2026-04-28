/**
 * Sidebar section config keys (relative to `saropaLints`) and matching context keys.
 * Split out so tests do not load the vscode module.
 */

/** Config key + label shown in Settings and the activity-bar-sections picker. */
export const SIDEBAR_SECTIONS: ReadonlyArray<{ readonly key: string; readonly label: string }> = [
    { key: 'sidebar.showCommandCatalog', label: 'Commands' },
    { key: 'sidebar.showOverview', label: 'Overview & options' },
    { key: 'sidebar.showFileRisk', label: 'File Risk' },
    { key: 'sidebar.showIssues', label: 'Violations' },
    { key: 'sidebar.showSummary', label: 'Summary' },
    { key: 'sidebar.showSuppressions', label: 'Suppressions' },
    { key: 'sidebar.showConfig', label: 'Triage' },
    { key: 'sidebar.showRulePacks', label: 'Config Dashboard' },
    { key: 'sidebar.showSuggestions', label: 'Suggestions' },
    { key: 'sidebar.showSecurityPosture', label: 'Security Posture' },
    { key: 'sidebar.showPackageVibrancy', label: 'Package Vibrancy' },
    { key: 'sidebar.showPackageDetails', label: 'Package Details' },
    { key: 'sidebar.showTodosAndHacks', label: 'TODOs & Hacks' },
    { key: 'sidebar.showDriftAdvisor', label: 'Drift Advisor' },
];

export const SIDEBAR_SECTION_COUNT = SIDEBAR_SECTIONS.length;

/** Keys passed to `workspace.getConfiguration('saropaLints').get(...)`. */
export const SIDEBAR_SECTION_CONFIG_KEYS: readonly string[] = SIDEBAR_SECTIONS.map((s) => s.key);

/** Full setting id and `setContext` key: `saropaLints.sidebar.showOverview`, etc. */
export function sidebarSectionContextKey(configKey: string): string {
    return `saropaLints.${configKey}`;
}

/** Default visibility when the setting is unset (matches package.json defaults). */
export function defaultSidebarSectionVisible(configKey: string): boolean {
  // Commands (searchable command index), Overview, Violations, and the two web dashboards
  // (Config Dashboard via Rule Packs + Package Vibrancy) stay on by default.
    // Package Details defaults on — its `when` clause already gates it behind
    // `packageVibrancy.hasResults`, so it only appears when there's scan data.
    // Standalone Triage is off — the same content lives under Overview & options.
    if (
        configKey === 'sidebar.showCommandCatalog' ||
        configKey === 'sidebar.showOverview' ||
        configKey === 'sidebar.showIssues' ||
    configKey === 'sidebar.showRulePacks' ||
    configKey === 'sidebar.showPackageVibrancy' ||
        configKey === 'sidebar.showPackageDetails'
    ) {
        return true;
    }
    return false;
}

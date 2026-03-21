/**
 * Sidebar section config keys (relative to `saropaLints`) and matching context keys.
 * Split out so tests do not load the vscode module.
 */

/** Config key + label shown in Settings and the sidebar-sections picker. */
export const SIDEBAR_SECTIONS: ReadonlyArray<{ readonly key: string; readonly label: string }> = [
    { key: 'sidebar.showOverview', label: 'Overview' },
    { key: 'sidebar.showIssues', label: 'Violations' },
    { key: 'sidebar.showSummary', label: 'Summary' },
    { key: 'sidebar.showConfig', label: 'Config' },
    { key: 'sidebar.showRulePacks', label: 'Rule Packs' },
    { key: 'sidebar.showSuggestions', label: 'Suggestions' },
    { key: 'sidebar.showSecurityPosture', label: 'Security Posture' },
    { key: 'sidebar.showFileRisk', label: 'File Risk' },
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
    // Core workflow: Overview, Violations, Config stay on. Everything else is opt-in.
    if (
        configKey === 'sidebar.showOverview'
        || configKey === 'sidebar.showIssues'
        || configKey === 'sidebar.showConfig'
    ) {
        return true;
    }
    return false;
}

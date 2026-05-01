/**
 * Sidebar section config keys (relative to `saropaLints`) and matching context keys.
 * Split out so tests do not load the vscode module.
 */

/**
 * Per-section activity-bar toggles. Empty after the flat-sidebar refactor:
 * duplicate trees (Summary, File Risk, Package Vibrancy sidebar, etc.) plus the
 * old Dashboards / Overview split were removed in favor of one flat
 * **Saropa Lints** view.
 */
export const SIDEBAR_SECTIONS: ReadonlyArray<{ readonly key: string; readonly label: string }> = [];

export const SIDEBAR_SECTION_COUNT = SIDEBAR_SECTIONS.length;

/** Keys passed to `workspace.getConfiguration('saropaLints').get(...)`. */
export const SIDEBAR_SECTION_CONFIG_KEYS: readonly string[] = SIDEBAR_SECTIONS.map((s) => s.key);

/** Full setting id and `setContext` key: `saropaLints.sidebar.showOverview`, etc. */
export function sidebarSectionContextKey(configKey: string): string {
    return `saropaLints.${configKey}`;
}

/** Default visibility when the setting is unset (matches package.json defaults). */
export function defaultSidebarSectionVisible(configKey: string): boolean {
    if (configKey === 'sidebar.showOverview') {
        return true;
    }
    return false;
}

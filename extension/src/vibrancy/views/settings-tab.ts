/**
 * Package Dashboard "Settings" tab (Phase 5, `PLAN_extension_ui_redesign.md`
 * §2.2/§3). Renders every `saropaLints.packageVibrancy.*` setting (54 as of
 * 2026-09-04 — the plan's "~60" estimate had drifted) as a grouped form
 * instead of leaving them only reachable through raw `settings.json` /
 * the Settings UI search box.
 *
 * Field labels are the raw dotted config key (e.g. `cacheTtlHours`), shown in
 * monospace — deliberately NOT run through l10n(). These are configuration
 * identifiers, not prose (the same exemption class as route names / `Key(...)`
 * strings in `.claude/rules/i18n.md`), and VS Code's own %key%-based manifest
 * localization for their descriptions is resolved only inside the native
 * Settings UI, not exposed to a webview at runtime — duplicating 54
 * descriptions into `en.json` by hand was judged not worth the drift risk for
 * this pass. Group titles and all other UI chrome DO go through l10n().
 */

import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { getDashboardTokens } from '../../views/dashboardChromeStyles';

/** A single packageVibrancy.* setting's current value plus the type info
 *  needed to pick a control. `nullableNumber` covers the 7 budget gates,
 *  which are `number | null` with `null` meaning "no limit". */
export type VibrancySettingType = 'boolean' | 'number' | 'nullableNumber' | 'string' | 'json';

export interface VibrancySettingField {
    readonly key: string; // dotted key WITHOUT the 'saropaLints.packageVibrancy.' prefix
    readonly type: VibrancySettingType;
    readonly value: unknown;
}

/** One card of related settings. `titleKey` is the only translated string
 *  per group — field labels stay as raw keys (see module doc). */
export interface VibrancySettingGroup {
    readonly titleKey: string;
    readonly fields: readonly VibrancySettingField[];
}

/**
 * Static group membership for all 54 fields, keyed by dotted suffix.
 * Values are supplied by the caller (report-webview.ts reads live config).
 * The 7 `budget.*` gates are deliberately ONE group ("Budget"), per the
 * plan's explicit instruction — they were 7 separate rows in the settings
 * search before this, which is exactly the "settings scattered with no
 * grouping" problem Phase 5 exists to fix.
 */
const GROUP_DEFS: ReadonlyArray<{ titleKey: string; keys: readonly string[]; types: Record<string, VibrancySettingType> }> = [
    {
        titleKey: 'packageDashboard.settingsTab.group.access',
        keys: ['githubToken', 'registries', 'siblingRepoPaths'],
        types: { githubToken: 'string', registries: 'json', siblingRepoPaths: 'json' },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.scan',
        keys: [
            'scanOnOpen', 'autoExportReportsOnScan', 'includeDevDependencies',
            'includeOverriddenPackages', 'cacheTtlHours', 'startupScanSkipTtlMinutes',
            'backgroundRefreshStalenessHours', 'scanConcurrency', 'showStartupScanSkipStatusBar',
            'suppressedPackages', 'allowlist', 'repoOverrides',
        ],
        types: {
            scanOnOpen: 'boolean', autoExportReportsOnScan: 'boolean', includeDevDependencies: 'boolean',
            includeOverriddenPackages: 'boolean', cacheTtlHours: 'number', startupScanSkipTtlMinutes: 'number',
            backgroundRefreshStalenessHours: 'number', scanConcurrency: 'number', showStartupScanSkipStatusBar: 'boolean',
            suppressedPackages: 'json', allowlist: 'json', repoOverrides: 'json',
        },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.display',
        keys: [
            'showLockDiffNotifications', 'showInStatusBar', 'enableCodeLens', 'enableAdoptionGate',
            'codeLensDetail', 'indicators', 'indicatorStyle', 'sortSdkFirst', 'endOfLifeDiagnostics',
            'inlineDiagnostics', 'annotateSectionHeaders', 'treeGrouping', 'showPrereleases', 'prereleaseTagFilter',
        ],
        types: {
            showLockDiffNotifications: 'boolean', showInStatusBar: 'boolean', enableCodeLens: 'boolean',
            enableAdoptionGate: 'boolean', codeLensDetail: 'string', indicators: 'json', indicatorStyle: 'string',
            sortSdkFirst: 'boolean', endOfLifeDiagnostics: 'string', inlineDiagnostics: 'string',
            annotateSectionHeaders: 'boolean', treeGrouping: 'string', showPrereleases: 'boolean',
            prereleaseTagFilter: 'json',
        },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.weights',
        keys: ['weights.resolutionVelocity', 'weights.engagementLevel', 'weights.popularity', 'publisherTrustBonus'],
        types: {
            'weights.resolutionVelocity': 'number', 'weights.engagementLevel': 'number',
            'weights.popularity': 'number', publisherTrustBonus: 'number',
        },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.upgrade',
        keys: [
            'upgradeAutoCommit', 'upgradeSkipTests', 'upgradeMaxSteps', 'bulkUpdateConfirmation',
            'onSaveChanges', 'onSaveChangesDetection',
        ],
        types: {
            upgradeAutoCommit: 'boolean', upgradeSkipTests: 'boolean', upgradeMaxSteps: 'number',
            bulkUpdateConfirmation: 'boolean', onSaveChanges: 'string', onSaveChangesDetection: 'string',
        },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.watch',
        keys: ['watchEnabled', 'watchIntervalHours', 'watchFilter', 'watchList'],
        types: {
            watchEnabled: 'boolean', watchIntervalHours: 'number', watchFilter: 'string', watchList: 'json',
        },
    },
    {
        // The 7 nullable budget gates -- ONE card, not 7 rows (plan's explicit requirement).
        titleKey: 'packageDashboard.settingsTab.group.budget',
        keys: [
            'budget.maxDependencies', 'budget.maxTotalSizeMB', 'budget.minAverageVibrancy',
            'budget.maxAbandoned', 'budget.maxEndOfLife', 'budget.maxOutdated', 'budget.maxUnused',
        ],
        types: {
            'budget.maxDependencies': 'nullableNumber', 'budget.maxTotalSizeMB': 'nullableNumber',
            'budget.minAverageVibrancy': 'nullableNumber', 'budget.maxAbandoned': 'nullableNumber',
            'budget.maxEndOfLife': 'nullableNumber', 'budget.maxOutdated': 'nullableNumber',
            'budget.maxUnused': 'nullableNumber',
        },
    },
    {
        titleKey: 'packageDashboard.settingsTab.group.vuln',
        keys: ['enableVulnScan', 'enableGitHubAdvisory', 'enableVersionGap', 'vulnSeverityThreshold'],
        types: {
            enableVulnScan: 'boolean', enableGitHubAdvisory: 'boolean', enableVersionGap: 'boolean',
            vulnSeverityThreshold: 'string',
        },
    },
];

/** Build the grouped settings model from a flat key->value map (report-webview.ts
 *  supplies this by reading `workspace.getConfiguration('saropaLints.packageVibrancy')`
 *  for every key listed in GROUP_DEFS). Centralizing the key list here (rather than
 *  in report-webview.ts) keeps the "which 54 keys exist" fact in one place. */
export function buildVibrancySettingGroups(rawValues: Record<string, unknown>): VibrancySettingGroup[] {
    return GROUP_DEFS.map(group => ({
        titleKey: group.titleKey,
        fields: group.keys.map(key => ({
            key,
            type: group.types[key],
            value: rawValues[key],
        })),
    }));
}

/** Flat list of every managed key, for report-webview.ts to read config with. */
export const ALL_VIBRANCY_SETTING_KEYS: readonly string[] =
    GROUP_DEFS.flatMap(g => g.keys);

/** Render one field's control. `data-key`/`data-type` drive the client script's
 *  change handler (settings-tab script below), which posts the parsed value
 *  back to the host for a `workspace.getConfiguration().update()` call. */
function buildField(field: VibrancySettingField): string {
    const id = `vs-${field.key.replace(/\./g, '-')}`;
    const common = `data-key="${escapeHtml(field.key)}" data-type="${field.type}"`;
    let control: string;
    switch (field.type) {
        case 'boolean':
            control = `<input type="checkbox" id="${id}" ${common} ${field.value ? 'checked' : ''} />`;
            break;
        case 'number':
            control = `<input type="number" id="${id}" ${common} value="${escapeHtml(String(field.value ?? 0))}" />`;
            break;
        case 'nullableNumber':
            // Empty input == null == "no limit", matching the setting's own semantics.
            control = `<input type="number" id="${id}" ${common} value="${field.value === null || field.value === undefined ? '' : escapeHtml(String(field.value))}" placeholder="${escapeHtml(l10n('packageDashboard.settingsTab.noLimit'))}" />`;
            break;
        case 'json':
            control = `<textarea id="${id}" ${common} rows="2" class="vs-json">${escapeHtml(JSON.stringify(field.value ?? null))}</textarea>`;
            break;
        default:
            control = `<input type="text" id="${id}" ${common} value="${escapeHtml(String(field.value ?? ''))}" />`;
    }
    return `<div class="vs-field">
        <label for="${id}" class="vs-label"><code>${escapeHtml(field.key)}</code></label>
        ${control}
    </div>`;
}

/** Build the full Settings tab panel (a `hidden` `<div>` toggled by the tab
 *  bar script in packages-tabs.ts). */
export function buildSettingsTab(groups: readonly VibrancySettingGroup[]): string {
    const cards = groups.map(group => `
        <section class="vs-card">
            <h3 class="vs-card-title">${escapeHtml(l10n(group.titleKey))}</h3>
            <div class="vs-card-body">
                ${group.fields.map(buildField).join('\n')}
            </div>
        </section>`).join('\n');
    return `<div id="pkg-tab-settings" class="pkg-tab-panel" role="tabpanel" aria-labelledby="pkg-tab-btn-settings" hidden>
        <p class="vs-intro">${escapeHtml(l10n('packageDashboard.settingsTab.intro'))}</p>
        <div class="vs-grid">${cards}</div>
    </div>`;
}

export function getSettingsTabStyles(): string {
    return `
${getDashboardTokens()}
.vs-intro { color: var(--vscode-descriptionForeground); margin: 0 0 var(--space-3, 8px); }
.vs-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: var(--space-4, 12px); }
.vs-card { border: 1px solid var(--vscode-panel-border); border-radius: 4px; padding: var(--space-3, 8px); }
.vs-card-title { margin: 0 0 var(--space-2, 4px); font-size: 13px; }
.vs-field { display: flex; align-items: center; justify-content: space-between; gap: var(--space-2, 4px); margin-bottom: var(--space-2, 4px); }
.vs-label code { font-size: 11px; color: var(--vscode-textPreformat-foreground); }
.vs-field input[type="text"], .vs-field input[type="number"], .vs-json { background: var(--vscode-input-background); color: var(--vscode-input-foreground); border: 1px solid var(--vscode-input-border); border-radius: 2px; padding: 2px 4px; width: 140px; }
.vs-json { width: 100%; font-family: var(--vscode-editor-font-family, monospace); font-size: 11px; }
`;
}

/** Client script: on change/input, parse the control's value per its
 *  `data-type` and post `{type:'updateVibrancySetting', key, value}` to the
 *  host. Only `String.prototype.split`/`trim` are used — no regex literals,
 *  since this string is inlined into a template-literal `<script>` block
 *  (see the template-literal regex trap documented in packages-tabs.ts). */
export function getSettingsTabScript(): string {
    return `
(function() {
    function parseValue(el) {
        var type = el.getAttribute('data-type');
        if (type === 'boolean') { return el.checked; }
        if (type === 'number') { return Number(el.value); }
        if (type === 'nullableNumber') { return el.value.trim() === '' ? null : Number(el.value); }
        if (type === 'json') {
            try { return JSON.parse(el.value); } catch (e) { return undefined; }
        }
        return el.value;
    }
    var controls = Array.prototype.slice.call(document.querySelectorAll('[data-key]'));
    controls.forEach(function(el) {
        var eventName = el.type === 'checkbox' ? 'change' : (el.tagName === 'TEXTAREA' ? 'blur' : 'change');
        el.addEventListener(eventName, function() {
            var value = parseValue(el);
            /* undefined means JSON.parse failed -- do not write a broken value to
               settings.json; leave the field as-is for the user to fix. */
            if (value === undefined) { return; }
            vscode.postMessage({ type: 'updateVibrancySetting', key: el.getAttribute('data-key'), value: value });
        });
    });
})();
`;
}

/**
 * Per-section counts for Overview → Sidebar toggles so users can see whether
 * a panel is worth enabling before turning it on.
 *
 * Violation-derived counts (Issues, Summary, Suggestions, etc.) are filled whenever
 * `violations` input is non-null — independent of `saropaLints.enabled`, so toggles stay
 * informative after a user turns “lint integration” off without deleting `violations.json`.
 *
 * **Vibrancy:** callers pass `vibrancyPackageCount` (from {@link getLatestResults} in production)
 * so this module stays free of Vibrancy activation imports and remains easy to unit test.
 */

import type { Violation, ViolationsData } from './violationsReader';
import { readRulePacksEnabled } from './rulePacks/rulePackYaml';
import { countSuggestionItems } from './suggestionCounts';

function countOwaspMappedViolations(violations: readonly Violation[]): number {
    let n = 0;
    for (const v of violations) {
        if (!v.owasp || typeof v.owasp !== 'object') continue;
        const mob = v.owasp.mobile;
        const web = v.owasp.web;
        if ((Array.isArray(mob) && mob.length > 0) || (Array.isArray(web) && web.length > 0)) {
            n++;
        }
    }
    return n;
}

function countFilesWithViolations(violations: readonly Violation[]): number {
    return new Set(violations.map((v) => v.file)).size;
}

export interface SidebarSectionCountInputs {
    readonly workspaceRoot: string | undefined;
    readonly tier: string;
    readonly violations: ViolationsData | null;
    readonly todosMarkerCount: number | undefined;
    readonly driftIssueCount: number | undefined;
    /** Latest Vibrancy scan size (`getLatestResults().length` in the extension host). */
    readonly vibrancyPackageCount: number;
}

/**
 * Returns config keys (e.g. `sidebar.showSummary`) → count or undefined when unknown / not applicable.
 */
export function buildSidebarSectionCountMap(inputs: SidebarSectionCountInputs): Map<string, number | undefined> {
    const m = new Map<string, number | undefined>();
    const root = inputs.workspaceRoot;
    if (!root) {
        return m;
    }

    m.set('sidebar.showRulePacks', readRulePacksEnabled(root).length);

    const vibrancyPackages = inputs.vibrancyPackageCount;
    m.set('sidebar.showPackageVibrancy', vibrancyPackages);
    m.set('sidebar.showPackageDetails', vibrancyPackages);

    const data = inputs.violations;
    if (data) {
        const total = data.summary?.totalViolations ?? data.violations.length;
        m.set('sidebar.showIssues', total);
        m.set('sidebar.showSummary', total);
        m.set('sidebar.showFileRisk', countFilesWithViolations(data.violations));
        m.set('sidebar.showSecurityPosture', countOwaspMappedViolations(data.violations));
        m.set('sidebar.showSuggestions', countSuggestionItems(data, root, inputs.tier));
        const erc = data.config?.enabledRuleCount;
        m.set('sidebar.showConfig', typeof erc === 'number' ? erc : undefined);
    }

    m.set('sidebar.showTodosAndHacks', inputs.todosMarkerCount);
    m.set('sidebar.showDriftAdvisor', inputs.driftIssueCount);

    return m;
}

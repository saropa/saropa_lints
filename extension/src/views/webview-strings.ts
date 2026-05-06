/**
 * Centralized user-facing strings for editor-area webview surfaces (UX
 * guidelines §18.1). Every string a real user can read should route through
 * this module rather than living inline in the HTML / CSS / script of a
 * specific surface.
 *
 * **Why centralize when the project is English-first?** Two reasons:
 *
 *   1. **Future i18n is a config switch, not a refactor.** When the team
 *      decides to ship localized strings (or even just rebrand a label
 *      consistently), one file changes. Inlining the same labels in 14
 *      surfaces means 14 changes plus a hunt for ones we missed.
 *   2. **Consistency stays free.** "Run analysis" vs "Run scan" vs
 *      "Re-run analysis" all collide today because three contributors
 *      wrote three different inline strings. Routing through STRINGS
 *      keeps the vocabulary uniform without enforcement overhead.
 *
 * **Out of scope for this module:**
 *   - Debug / log messages (English-only by design)
 *   - Identifiers, command IDs, route names, telemetry event names
 *   - Asset paths, CSS class names
 *   - Static data strings (rule names, package names, etc.)
 *
 * **When to add a key:** any time you would otherwise inline a string
 * a sighted user can read inside a webview HTML / CSS / script payload.
 * Pick the lowest-numbered domain that already covers the topic.
 *
 * **Naming convention:** `domain.subdomain.key` (e.g. `toolbar.runAnalysis`,
 * `empty.noFindings.message`). Keys are lowerCamelCase; domains are
 * lowerCamelCase nouns.
 */

import { format } from '../i18n/runtime';
import en from '../i18n/locales/en.json';

export const STRINGS = en;

/**
 * @deprecated Prefer `t('domain.key')` from `src/i18n/runtime.ts` for new
 * runtime-localized surfaces. This helper stays for backwards compatibility.
 */
export const LEGACY_STRINGS = {
    /* ──────────────────────────────────────────────────────────────────
     * Toolbar actions — buttons in the sticky band above primary tables.
     * Tier-1 / tier-2 / tier-3 vocabulary per UX guidelines §8.10.
     * ──────────────────────────────────────────────────────────────── */
    toolbar: {
        runAnalysis: 'Run analysis',
        rescan: 'Rescan',
        refresh: 'Refresh',
        copyJson: 'Copy JSON',
        saveReport: 'Save report',
        moreActions: 'More actions',
        clearAll: 'Clear all',
        resetView: 'Reset view',
    },

    /* ──────────────────────────────────────────────────────────────────
     * Empty / loading / error states (§8.16). Keep the verbs action-y;
     * "Loading…" is banned (§8.16.2).
     * ──────────────────────────────────────────────────────────────── */
    empty: {
        noFindingsTitle: 'No findings',
        noFindingsMessage: 'Run analysis to scan the workspace.',
        noFindingsCta: 'Run analysis',

        noMatchTitle: 'No matches',
        noMatchMessage: 'No rows match the current filters.',
        noMatchCta: 'Reset filters',

        noProjectTitle: 'No workspace open',
        noProjectMessage: 'Open a Flutter or Dart project to see findings.',
        noProjectCta: 'Open folder',

        noDataTitle: 'No data yet',
        noDataMessage: 'Run a scan to populate this dashboard.',
        noDataCta: 'Run analysis',
    },

    loading: {
        thinking: 'Thinking…',
        preparing: 'Preparing…',
        checking: 'Checking…',
        fetching: 'Fetching…',
        working: 'Working…',
        scanning: 'Scanning…',
        cancel: 'Cancel',
    },

    error: {
        genericTitle: 'Something went wrong',
        retry: 'Retry',
        reload: 'Reload',
        copyDetails: 'Copy details',
        unreachable: 'Could not reach {target}',
        partialSummary: '{loaded} of {total} {item} loaded. {failed} failed.',
        partialRetry: 'Retry failed',
    },

    offline: {
        banner: 'Offline — reconnect to refresh.',
        cachedFooter: 'Showing cached data from {when}.',
        reconnecting: 'Reconnecting…',
    },

    stale: {
        statusPill: 'Last successful run {when} — refresh failed',
    },

    /* ──────────────────────────────────────────────────────────────────
     * Filter / search affordances (§8.5).
     * ──────────────────────────────────────────────────────────────── */
    filter: {
        searchPlaceholder: 'Search…',
        clearSearch: 'Clear search',
        activeLabel: 'Active filters:',
        recentLabel: 'Recent ▾',
        chipRemove: 'Remove',
    },

    /* ──────────────────────────────────────────────────────────────────
     * Generic accessibility labels (§15.3). Used as aria-label fallbacks
     * when the visible text is icon-only.
     * ──────────────────────────────────────────────────────────────── */
    a11y: {
        toggleFullWidth: 'Toggle full-width layout',
        sortBy: 'Sort by {column}',
        expandRow: 'Expand row',
        collapseRow: 'Collapse row',
        selectAll: 'Select all rows',
        keyboardShortcuts: 'Keyboard shortcuts',
        announcer: 'Updates to filter and sort state are announced here.',
    },
} as const;

/**
 * Substitute `{name}` placeholders in a template with values from `params`.
 * Unmatched placeholders are left as-is (so a missing param surfaces as
 * `{name}` in the rendered string instead of silently dropping context).
 *
 * @example
 * format(STRINGS.error.unreachable, { target: 'pub.dev' })
 *   // → 'Could not reach pub.dev'
 * format(STRINGS.error.partialSummary, { loaded: 5, total: 7, item: 'packages', failed: 2 })
 *   // → '5 of 7 packages loaded. 2 failed.'
 */
export { format };

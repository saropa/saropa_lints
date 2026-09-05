/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { KnownIssue } from '../types';
import { allKnownIssues } from '../scoring/known-issues';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { getReportStyles } from './report-styles';
import { getKnownIssuesScript } from './known-issues-script';
import { getDashboardChromeStyles } from '../../views/dashboardChromeStyles';
// Embed-only (PLAN_ext_ui_package_tabs.md §4 Tab 5): the standalone panel pulls in the FULL
// getDashboardChromeStyles() bundle, but report-html.ts deliberately does NOT compose that whole
// bundle (see report-styles.ts's Pass 1 comment) -- chromeMicroAndMotion() inside it would repaint
// the embedded Upgrades tab's <code class="opp-chip"> elements in the editor monospace font, an
// unaudited side effect out of scope for either tab's plan. getEmbeddedBodyHtml therefore composes
// only the three component bands its OWN markup (.toolbar-band/.seg, .kpi-card, .chip-strip)
// actually needs, plus chromeReducedMotion() for the .kpi-card a11y guarantee.
import {
    chromeToolbarAndButtons, chromeKpiCards, chromeChipStrip,
} from '../../views/dashboardChromeStylesComponents';
import { chromeReducedMotion } from '../../views/dashboardChromeStylesSystem';
import {
    buildDashboardHero,
    buildDocumentTitle,
    buildStatusLine,
} from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';

// Static HTML for browsing curated "known issues" and replacement guidance.
/** Build the full HTML for the known issues library browser. */
export function buildKnownIssuesHtml(): string {
    const issues = Array.from(allKnownIssues().values()).flat();
    const withReplacement = issues.filter(i => i.replacement).length;
    const noReplacement = issues.length - withReplacement;
    const nonce = createWebviewCspNonce();

    const statusLineHtml = buildStatusLine([
        { glyph: '📚', label: `${issues.length} curated issues` },
        { label: `${withReplacement} with replacement`, tone: 'good' },
        { label: `${noReplacement} without`, tone: noReplacement > 0 ? 'warn' : 'neutral' },
    ]);
    const heroHtml = buildDashboardHero({
        title: 'Known Issues',
        statusLineHtml,
        extraToggleHtml: buildKeyboardShortcutsButton(),
    });

    // §15.2 — surface-level keyboard shortcuts. The overlay lists every
    // affordance the script binds (search focus, Esc to clear, sort keys)
    // so users don't have to discover them by experiment.
    const shortcuts = [
        { key: '/', label: 'Focus the search field' },
        { key: 'Esc', label: 'Clear search and reset filters' },
        { key: 'Enter', label: 'Activate focused KPI card or filter button' },
        { key: '?', label: 'Show this shortcut overlay' },
    ];

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>${escapeHtml(buildDocumentTitle('Known Issues'))}</title>
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
    <style nonce="${nonce}">${getReportStyles()}${getDashboardChromeStyles()}${getExtraStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
    <a href="#known-issues-main" class="skip-link">Skip to issues table</a>
    <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
    ${heroHtml}
    <section class="ki-controls" aria-label="Summary and filters">
    ${buildSummaryCards(issues.length, withReplacement)}
    ${buildToolbar()}
    ${buildChipStrip()}
    </section>
    <main id="known-issues-main" tabindex="-1">
    ${buildTable(issues)}
    ${buildEmptyState()}
    </main>
    ${buildKeyboardShortcutsOverlay(shortcuts)}
    <script nonce="${nonce}">var vscode = acquireVsCodeApi();</script>
    <script nonce="${nonce}">${getKnownIssuesScript()}${getKeyboardShortcutsScript()}</script>
</body>
</html>`;
}

/**
 * Body-only HTML (no `<!DOCTYPE>`/`<html>`/`<head>`/nonce-bearing tags, and no
 * `acquireVsCodeApi()` call) for embedding inside the Package Dashboard's "Known issues" tab
 * (PLAN_ext_ui_package_tabs.md §4 Tab 5), following the same `getEmbeddedBodyHtml` pattern
 * `opportunities-html.ts` (Tab 3) and `feature-inventory-html.ts` (Tab 4) already proved.
 *
 * Two things this tab needs that the earlier two did not:
 *   - The data is a static, synchronous registry (`allKnownIssues()`) with no project scan, so
 *     (unlike Tabs 3/4) `report-webview.ts` never needs to lazily build-and-cache anything here —
 *     this function can render the real content on the very first paint.
 *   - Every id the standalone panel uses (`search-input`, `pkg-body`, `visible-count`, ...) is
 *     generic enough to collide with the Package Dashboard's OWN packages-table markup once both
 *     documents' HTML coexists in one DOM. Every builder below takes the `'ki-'` idPrefix (see
 *     {@link buildSummaryCards}) to sidestep that; the hero, skip-link, and keyboard-shortcuts
 *     overlay are omitted entirely rather than prefixed, because the host dashboard already
 *     supplies its own equivalents (title/gauge header, `#dashFullWidthToggle`, `?`-triggered
 *     shortcuts overlay) and a second copy of any of those would be visually redundant or, for
 *     `#dashFullWidthToggle` specifically, a genuine duplicate-id bug.
 *
 * No `handleEmbeddedMessage` companion is exported here: the only host round-trip this tab needs
 * (persisting recent searches to `workspaceState`) reuses the existing `saveKnownIssuesRecent` /
 * `hydrateKnownIssuesRecent` message names verbatim -- see `report-webview.ts`'s message switch
 * and `getKnownIssuesEmbedScript()` in `known-issues-script.ts` for the wiring.
 */
export function getEmbeddedBodyHtml(): string {
    const issues = Array.from(allKnownIssues().values()).flat();
    const withReplacement = issues.filter(i => i.replacement).length;
    const idPrefix = 'ki-';
    return `<div class="ki-embed-body">
    <div id="ki-announcer" role="status" aria-live="polite" aria-atomic="true"></div>
    <section class="ki-controls" aria-label="Summary and filters">
    ${buildSummaryCards(issues.length, withReplacement, idPrefix)}
    ${buildToolbar(idPrefix)}
    ${buildChipStrip()}
    </section>
    <main id="ki-main">
    ${buildTable(issues, idPrefix)}
    ${buildEmptyState()}
    </main>
</div>`;
}

/**
 * CSS for {@link getEmbeddedBodyHtml}. Kept separate from `getEmbeddedBodyHtml` itself (rather
 * than folded into one function) so `report-html.ts` can put it in its single shared `<style>`
 * block while the HTML goes in `<body>`, matching how `getOpportunitiesStyles()` /
 * `getFeatureInventoryStyles()` are split from their tabs' `getEmbeddedBodyHtml`. See the import
 * comment above for exactly which chrome bands this composes and why not the full bundle.
 */
export function getKnownIssuesEmbedStyles(): string {
    return (
        chromeToolbarAndButtons()
        + chromeKpiCards()
        + chromeChipStrip()
        + chromeReducedMotion()
        // '.ki-embed-body ' scopes .search-clear so it cannot repaint the Package Dashboard's
        // OWN table search-clear button -- see getExtraStyles's doc comment.
        + getExtraStyles('.ki-embed-body ')
    );
}

/**
 * §8.5 / §14.10 — Active filter chip strip. Hidden by default; the script
 * reveals it and populates chips when filter state diverges from defaults
 * (both replacement buckets pressed). Each chip has a remove [×]; the
 * *Clear all* control resets the filter state.
 */
function buildChipStrip(): string {
    return `<div class="chip-strip" id="ki-chip-strip" hidden>
        <span class="lbl">Active filters:</span>
        <span id="ki-chip-body"></span>
        <button type="button" class="clear-all" id="ki-clear-all">Clear all</button>
    </div>`;
}

/**
 * §8.16 / §14.2 — Empty-state CTA shown when search/filter narrows the
 * table to zero rows. Carries a tier-1 *Reset filters* button so the user
 * is not stranded looking at an empty table with no cue for the next
 * action. Hidden by default; the script toggles visibility.
 */
function buildEmptyState(): string {
    return `<div id="ki-empty" class="empty-cta" role="status" hidden>
        <p class="empty-msg">No packages match the current filters.</p>
        <button type="button" class="btn tier-1" id="ki-reset-filters"
            title="Clear the search and filter selection.">Reset filters</button>
    </div>`;
}

/**
 * @param idPrefix Prepended to every id this function emits. Empty string (the default) for the
 * standalone panel, keeping its ids exactly as they were before the embed existed (test-safe --
 * `known-issues-html.test.ts` asserts on the bare ids). `'ki-'` for {@link getEmbeddedBodyHtml},
 * so `#visible-count` cannot collide with the Package Dashboard's own package-table ids when both
 * documents' markup coexist in one DOM (PLAN_ext_ui_package_tabs.md §9 "DOM id collisions").
 */
function buildSummaryCards(total: number, withReplacement: number, idPrefix = ''): string {
    /* KPI cards as preset filters (guideline §4.2 / §14.8): clicking a card sets the
       replacement filter to the matching state. Showing & Total reset; Has & No drive
       the filter to "has" / "no". The filter element used to be a binary checkbox; it
       is now a tri-state segmented control so all four cards have a unique target. */
    return `<div class="summary ki-summary-strip">
        <div class="summary-card kpi-card interactive" role="button" tabindex="0"
             data-kpi="visible" data-kpi-action="reset" title="Click to clear filters">
            <div class="kpi-k">Showing</div>
            <div class="kpi-v" id="${idPrefix}visible-count">${total}</div>
        </div>
        <div class="summary-card kpi-card interactive ki-metric-total" role="button" tabindex="0"
             data-kpi="total" data-kpi-action="reset" title="Click to clear filters">
            <div class="kpi-k">Total</div>
            <div class="kpi-v">${total}</div>
        </div>
        <div class="summary-card kpi-card interactive ki-metric-positive" role="button" tabindex="0"
             data-kpi="has" data-kpi-action="filter-has" title="Filter to packages with a replacement">
            <div class="kpi-k">Has Replacement</div>
            <div class="kpi-v">${withReplacement}</div>
        </div>
        <div class="summary-card kpi-card interactive ki-metric-gap" role="button" tabindex="0"
             data-kpi="no" data-kpi-action="filter-no" title="Filter to packages without a replacement">
            <div class="kpi-k">No Replacement</div>
            <div class="kpi-v">${total - withReplacement}</div>
        </div>
    </div>`;
}

/** @param idPrefix see {@link buildSummaryCards}. */
function buildToolbar(idPrefix = ''): string {
    // Search field wrapped so we can absolutely position a clear (X) button inside it.
    // The replacement filter is now a tri-state segmented control (`.seg`) instead of a
    // binary checkbox so the four KPI cards each map to a distinct filter state.
    return `<div class="known-issues-toolbar toolbar-band">
        <div class="toolbar-row">
            <div class="search-wrapper">
                <label class="sr-only" for="${idPrefix}search-input">Search packages</label>
                <input id="${idPrefix}search-input" type="text" class="ki-search-field"
                    placeholder="Search packages..." autocomplete="off">
                <button type="button" id="${idPrefix}search-clear" class="search-clear"
                    title="Clear search" aria-label="Clear search" hidden>&times;</button>
                <!-- §8.5.2 — recent-searches popover (workspace-persisted via host). -->
                <div id="${idPrefix}recent-searches" class="recent-searches" hidden>
                    <div class="recent-searches-head">
                        <span class="recent-searches-title">Recent searches</span>
                        <button type="button" id="${idPrefix}recent-searches-clear"
                            class="recent-searches-clear-all"
                            title="Clear all recent searches">Clear</button>
                    </div>
                    <ul id="${idPrefix}recent-searches-list" class="recent-searches-list"
                        role="listbox" aria-label="Recent searches"></ul>
                </div>
            </div>
            <span class="seg" role="group" aria-label="Replacement filter">
                <span class="seg-label">Replacement</span>
                <button type="button" class="seg-btn" data-filter="has" aria-pressed="true"
                        title="Include packages with a replacement">Has</button>
                <button type="button" class="seg-btn" data-filter="no" aria-pressed="true"
                        title="Include packages without a replacement">None</button>
            </span>
        </div>
    </div>`;
}

/** @param idPrefix see {@link buildSummaryCards}. */
function buildTable(issues: KnownIssue[], idPrefix = ''): string {
    return `<div class="table-scroll"><table>
        <thead><tr>
            <th data-col="name">Package<span class="sort-arrow"></span></th>
            <th data-col="reason">Reason<span class="sort-arrow"></span></th>
            <th data-col="replacement">Replacement<span class="sort-arrow"></span></th>
            <th data-col="migration">Migration<span class="sort-arrow"></span></th>
        </tr></thead>
        <tbody id="${idPrefix}pkg-body">
            ${issues.map(buildRow).join('\n')}
        </tbody>
    </table></div>`;
}

function buildRow(issue: KnownIssue): string {
    const name = escapeHtml(issue.name);
    const reason = issue.reason ? escapeHtml(issue.reason) : '';
    const replacement = issue.replacement
        ? escapeHtml(issue.replacement) : '';
    const migration = issue.migrationNotes
        ? escapeHtml(issue.migrationNotes) : '';
    const pubUrl = `https://pub.dev/packages/${encodeURIComponent(issue.name)}`;
    const replacementLink = issue.replacement
        ? formatReplacement(issue.replacement) : '';

    const searchText = [
        issue.name, issue.reason ?? '',
        issue.replacement ?? '', issue.migrationNotes ?? '',
    ].join(' ').toLowerCase();

    return `<tr data-name="${name}" data-reason="${reason}"
        data-replacement="${replacement}" data-migration="${migration}"
        data-searchtext="${escapeHtml(searchText)}">
        <td><a href="${pubUrl}">${name}</a></td>
        <td>${reason}</td>
        <td>${replacementLink}</td>
        <td>${migration}</td>
    </tr>`;
}

/** Package names are lowercase, alphanumeric, with underscores only. */
function isPackageName(text: string): boolean {
    return /^[a-z][a-z0-9_]*$/.test(text);
}

function formatReplacement(text: string): string {
    if (isPackageName(text)) {
        const url = `https://pub.dev/packages/${encodeURIComponent(text)}`;
        return `<a href="${url}">${escapeHtml(text)}</a>`;
    }
    return escapeHtml(text);
}

/**
 * @param scopeClass Descendant-selector prefix (e.g. `'.ki-embed-body '`, WITH the trailing
 * space) applied only to `.search-clear` below. Empty string (the default) for the standalone
 * panel, which has no ancestor to scope by and does not need one: it is the only document that
 * ever loads its own styles. The embed passes `'.ki-embed-body '` because `.search-clear` is
 * ALSO report-styles-parts.ts's class name for the Package Dashboard's own table search field,
 * with different metrics (16px vs this file's 18px) -- without the scope prefix, whichever rule
 * is concatenated last into the shared `<style>` block would win for BOTH search fields, silently
 * resizing the host dashboard's clear button. Every other selector here is Known-Issues-specific
 * (verified against report-styles-parts.ts) and does not need the same treatment.
 */
export function getExtraStyles(scopeClass = ''): string {
    return `
        .ki-metric-total .count { color: var(--vscode-foreground); }
        .ki-metric-positive .count { color: var(--vscode-testing-iconPassed); }
        .ki-metric-gap .count { color: var(--vscode-editorWarning-foreground); }
        .known-issues-toolbar {
            display: flex; gap: 16px; align-items: center;
            margin-bottom: 12px;
        }
        /* Relative wrapper anchors the absolutely-positioned clear (X)
           button inside the search field. flex:1 lets the wrapper grow
           like the bare input used to. */
        .search-wrapper {
            position: relative;
            display: flex;
            flex: 1;
            max-width: 400px;
            align-items: center;
        }
        /* Class-based (not id-based): the embed renders this input with a 'ki-'-prefixed id
           (see buildToolbar's idPrefix), so a plain #search-input rule would silently stop
           matching there. The class is present on the input in both the standalone and embedded
           markup regardless of id prefix. */
        .ki-search-field {
            flex: 1; padding: 6px 28px 6px 10px; /* right pad for clear (X) */
            font-size: 0.95em;
            color: var(--vscode-input-foreground);
            background: var(--vscode-input-background);
            border: 1px solid var(--vscode-input-border);
            border-radius: 4px; outline: none;
        }
        .ki-search-field:focus {
            border-color: var(--vscode-focusBorder);
        }
        /* Clear (X) button lives inside the input via absolute positioning.
           Hidden by default via [hidden]; known-issues-script.ts toggles it
           when the input value is non-empty after trim. */
        ${scopeClass}.search-clear {
            position: absolute;
            /* §23.1 — clear-X stays at the trailing edge of the input;
               LTR puts it on the right (end-of-line), RTL puts it on
               the left (still end-of-line because the inline axis flips). */
            inset-inline-end: 6px;
            top: 50%;
            transform: translateY(-50%);
            width: 18px;
            height: 18px;
            padding: 0;
            line-height: 16px;
            font-size: 16px;
            border: none;
            background: transparent;
            color: var(--vscode-input-foreground);
            opacity: 0.6;
            cursor: pointer;
            border-radius: 2px;
        }
        ${scopeClass}.search-clear:hover {
            opacity: 1;
            background: var(--vscode-toolbar-hoverBackground);
        }
        .filter-label {
            font-size: 0.9em; cursor: pointer;
            display: flex; align-items: center; gap: 4px;
        }
        /* §8.16 — empty-state banner shown when search/filter narrows the
           table to zero rows. Centered card with a tier-1 CTA so the
           user has an actionable next step. */
        .empty-cta {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 10px;
            padding: 24px 16px;
            margin: 12px 0;
            border: 1px dashed var(--border, var(--vscode-widget-border));
            border-radius: 6px;
            background: var(--surface-2, var(--vscode-editorWidget-background));
        }
        .empty-cta .empty-msg {
            margin: 0;
            color: var(--muted, var(--vscode-descriptionForeground));
            font-size: 0.95em;
        }
        /* §8.5.2 — search hit highlights. Bind to host find-match token so
           the highlight is visible across all four default themes; the
           foreground stays inherited so contrast against the row text
           continues to come from the host theme. */
        mark.search-hit {
            background: var(--vscode-editor-findMatchHighlightBackground,
                var(--vscode-editor-selectionBackground));
            color: inherit;
            padding: 0 1px;
            border-radius: 2px;
        }
        /* §8.5.2 — recent-searches popover. Anchored under the search input.
           Shown only when the input is focused empty AND the list has
           entries. Click an item to fill the search; X to remove a single
           entry; *Clear* to drop the whole history. */
        .recent-searches {
            position: absolute;
            top: calc(100% + 4px);
            inset-inline-start: 0;
            inset-inline-end: 0;
            z-index: 50;
            max-height: 220px;
            overflow-y: auto;
            background: var(--surface-2, var(--vscode-editorWidget-background));
            border: 1px solid var(--border, var(--vscode-widget-border));
            border-radius: 4px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
        }
        .recent-searches-head {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 4px 8px;
            border-bottom: 1px solid var(--border, var(--vscode-widget-border));
        }
        .recent-searches-title {
            font-size: 0.8em;
            color: var(--muted, var(--vscode-descriptionForeground));
            text-transform: uppercase;
            letter-spacing: 0.4px;
        }
        .recent-searches-clear-all {
            background: none;
            border: 0;
            padding: 0;
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
            font-size: 0.85em;
        }
        .recent-searches-clear-all:hover {
            text-decoration: underline;
        }
        .recent-searches-list {
            list-style: none;
            margin: 0;
            padding: 4px 0;
        }
        .recent-searches-list li {
            display: flex;
            align-items: center;
            gap: 4px;
            padding: 0;
        }
        .recent-searches-list .recent-pick {
            flex: 1;
            text-align: start;
            background: none;
            border: 0;
            padding: 4px 10px;
            color: var(--vscode-foreground);
            cursor: pointer;
            font: inherit;
        }
        .recent-searches-list .recent-pick:hover,
        .recent-searches-list .recent-pick:focus-visible {
            background: var(--vscode-list-hoverBackground);
            outline: none;
        }
        .recent-searches-list .recent-remove {
            width: 22px;
            height: 22px;
            margin-inline-end: 6px;
            border: 0;
            background: transparent;
            color: var(--muted, var(--vscode-descriptionForeground));
            cursor: pointer;
            opacity: 0.6;
            border-radius: 2px;
            font-size: 14px;
        }
        .recent-searches-list .recent-remove:hover,
        .recent-searches-list .recent-remove:focus-visible {
            opacity: 1;
            background: var(--vscode-toolbar-hoverBackground,
                var(--vscode-list-hoverBackground));
        }
    `;
}

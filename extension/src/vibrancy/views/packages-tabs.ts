/**
 * Package Dashboard tab shell (Phase 5 of the extension UI redesign,
 * `plans/PLAN_extension_ui_redesign.md` §2.2/§3 Phase 5).
 *
 * The dashboard was a single flat document before this change — there was no
 * existing tab mechanism to extend. This module adds one: a row of tab
 * buttons plus `hidden`-toggled panels, all inside the SAME document (one
 * `acquireVsCodeApi()` call, one CSP nonce — see the extension-development
 * skill's "acquireVsCodeApi once per document" constraint).
 *
 * Overview and Settings render natively in this document (their content is
 * cheap and self-contained). Upgrades / Full report / Known issues / Compare
 * each ALSO live as their OWN full `<!DOCTYPE html>` webview document with an
 * independent CSP nonce, `<script>`, and `acquireVsCodeApi()` call
 * (`opportunities-panel.ts`, `feature-inventory-export.ts`,
 * `known-issues-webview.ts`, `comparison-webview.ts`) — those standalone
 * panels are never deleted, only reused: PLAN_ext_ui_package_tabs.md converts
 * each of the four into an inline embed one at a time (easiest first), via a
 * `getEmbeddedBodyHtml()` extracted from that tab's own HTML builder so the
 * embedded and standalone renders can never visually diverge. A tab not yet
 * converted falls back to the original lightweight "deep-link" card below —
 * real navigation (the click does something concrete), not a stub label —
 * so shipping the conversions incrementally never leaves a tab broken.
 */

import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { getDashboardTokens } from '../../views/dashboardChromeStyles';

/** One tab's static identity: DOM id suffix, button label key, and (for
 *  deep-link tabs) the command it opens. Overview/Settings have no command —
 *  they render in place instead of delegating. */
export interface PackagesTabDef {
    readonly id: string;
    readonly labelKey: string;
    readonly command?: string;
    readonly descriptionKey?: string;
}

/** Canonical tab order per the plan's §2.2 "Packages" row. Exported so the
 *  webview controller (report-webview.ts) can dispatch `openTab` messages by
 *  id without duplicating this list. */
export const PACKAGES_TABS: readonly PackagesTabDef[] = [
    { id: 'overview', labelKey: 'packageDashboard.tabs.overview' },
    {
        id: 'upgrades', labelKey: 'packageDashboard.tabs.upgrades',
        command: 'saropaLints.packageVibrancy.showOpportunities',
        descriptionKey: 'packageDashboard.tabs.upgradesDesc',
    },
    {
        id: 'fullReport', labelKey: 'packageDashboard.tabs.fullReport',
        command: 'saropaLints.packageVibrancy.exportOpportunitiesReport',
        descriptionKey: 'packageDashboard.tabs.fullReportDesc',
    },
    {
        id: 'knownIssues', labelKey: 'packageDashboard.tabs.knownIssues',
        command: 'saropaLints.packageVibrancy.browseKnownIssues',
        descriptionKey: 'packageDashboard.tabs.knownIssuesDesc',
    },
    {
        id: 'compare', labelKey: 'packageDashboard.tabs.compare',
        command: 'saropaLints.packageVibrancy.comparePackages',
        descriptionKey: 'packageDashboard.tabs.compareDesc',
    },
    { id: 'settings', labelKey: 'packageDashboard.tabs.settings' },
];

/** Tab bar markup. `data-tab` drives the client-side show/hide script below;
 *  `aria-selected`/`role=tab` keep it screen-reader navigable per the design
 *  guide's accessibility gate (no opt-out for dashboard-class surfaces). */
export function buildTabBar(): string {
    const buttons = PACKAGES_TABS.map((t, i) => `
        <button type="button" class="pkg-tab-btn" role="tab" data-tab="${t.id}"
            id="pkg-tab-btn-${t.id}" aria-controls="pkg-tab-${t.id}"
            aria-selected="${i === 0 ? 'true' : 'false'}" tabindex="${i === 0 ? '0' : '-1'}">
            ${escapeHtml(l10n(t.labelKey))}
        </button>`).join('');
    return `<div class="pkg-tab-bar" role="tablist" aria-label="${escapeHtml(l10n('packageDashboard.tabs.aria'))}">${buttons}</div>`;
}

/** One deep-link tab panel: a short description plus an "Open" button that
 *  posts `openTab` to the host, which executes the real command. Kept
 *  in-document (not a redirect) so the tab bar itself never needs a reload. */
function buildDeepLinkPanel(tab: PackagesTabDef): string {
    return `<div id="pkg-tab-${tab.id}" class="pkg-tab-panel dash-empty" role="tabpanel" aria-labelledby="pkg-tab-btn-${tab.id}" hidden>
        <p class="dash-empty-body">${escapeHtml(l10n(tab.descriptionKey ?? tab.labelKey))}</p>
        <button type="button" class="btn tier-1" data-open-command="${escapeHtml(tab.command ?? '')}">
            ${escapeHtml(l10n('packageDashboard.tabs.openButton', { tab: l10n(tab.labelKey) }))}
        </button>
    </div>`;
}

/** One embedded tab panel: the caller-supplied body fragment (already stripped of any document
 *  shell / `acquireVsCodeApi()` call by its own `getEmbeddedBodyHtml`) wrapped in the same
 *  `role="tabpanel"` shell every panel uses so the tab-switch script (`getPackagesTabsScript`
 *  below) cannot tell an embedded tab apart from Overview/Settings. Deliberately NOT given the
 *  `dash-empty` class the deep-link card uses — that class centers content and caps width for a
 *  one-line description, which would squash a full report table. */
function buildEmbeddedTabPanel(tab: PackagesTabDef, bodyHtml: string): string {
    return `<div id="pkg-tab-${tab.id}" class="pkg-tab-panel" role="tabpanel" aria-labelledby="pkg-tab-btn-${tab.id}" hidden>${bodyHtml}</div>`;
}

/**
 * All four Upgrades/Full report/Known issues/Compare panels, in tab order. Each renders as an
 * inline embed when `embeddedBodies` supplies that tab's id (PLAN_ext_ui_package_tabs.md §5
 * converts them one at a time, easiest first) or falls back to the original deep-link "Open"
 * card for any tab not yet converted — the plan's explicit incremental-shipping requirement:
 * "a tab you do not convert keeps working as a deep link". Overview and Settings are built by
 * their own callers, not this function.
 */
export function buildTabPanels(embeddedBodies: Readonly<Partial<Record<string, string>>> = {}): string {
    return PACKAGES_TABS
        .filter(t => t.command)
        .map(t => {
            const body = embeddedBodies[t.id];
            return body !== undefined ? buildEmbeddedTabPanel(t, body) : buildDeepLinkPanel(t);
        })
        .join('\n');
}

/** Scoped CSS for the tab bar + deep-link panels. Draws only from the
 *  canonical `dashboardChromeStyles` token layer (`getDashboardTokens()`),
 *  not a new bespoke system — Phase 5's design-system requirement without
 *  risking the full `report-styles*.ts` migration (see plan's Phase 5
 *  Deferred note: that migration is out of scope for this pass; it is a
 *  ~150KB rewrite against a system with 10 other live consumers). */
export function getPackagesTabsStyles(): string {
    return `
${getDashboardTokens()}
.pkg-tab-bar { display: flex; gap: var(--space-2, 4px); border-bottom: 1px solid var(--vscode-panel-border); margin: var(--space-3, 8px) 0; flex-wrap: wrap; }
.pkg-tab-btn { background: none; border: none; border-bottom: 2px solid transparent; color: var(--vscode-descriptionForeground); padding: var(--space-2, 4px) var(--space-3, 8px); cursor: pointer; font-size: 13px; }
.pkg-tab-btn:hover { color: var(--vscode-foreground); }
.pkg-tab-btn[aria-selected="true"] { color: var(--vscode-foreground); border-bottom-color: var(--vscode-focusBorder); font-weight: 600; }
.pkg-tab-btn:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
.pkg-tab-panel.dash-empty { padding: var(--space-5, 24px) var(--space-3, 8px); text-align: center; color: var(--vscode-descriptionForeground); }
.pkg-tab-panel .dash-empty-body { max-width: 480px; margin: 0 auto var(--space-3, 8px); }
`;
}

/** Client-side tab switching. No regex literals — this string is inlined
 *  into a `<script>` template literal in report-html.ts, so any `\d`/`\B`
 *  would silently collapse (documented trap, see `codeHealthScanProgress.ts`
 *  and the extension-development skill). Also wires the deep-link buttons'
 *  `data-open-command` to a `postMessage`, handled by report-webview.ts's
 *  `openTab` case which runs `vscode.commands.executeCommand`. */
export function getPackagesTabsScript(): string {
    return `
(function() {
    var tabBtns = Array.prototype.slice.call(document.querySelectorAll('.pkg-tab-btn'));
    var panels = {};
    tabBtns.forEach(function(btn) {
        var id = btn.getAttribute('data-tab');
        panels[id] = document.getElementById('pkg-tab-' + id);
    });
    /* Overview's panel is the dashboard's existing <main> content, given the
       id 'pkg-tab-overview' by report-html.ts so it participates in the same
       show/hide logic as the new tabs without duplicating any markup. */
    function selectTab(id) {
        tabBtns.forEach(function(btn) {
            var active = btn.getAttribute('data-tab') === id;
            btn.setAttribute('aria-selected', active ? 'true' : 'false');
            btn.setAttribute('tabindex', active ? '0' : '-1');
        });
        Object.keys(panels).forEach(function(key) {
            var panel = panels[key];
            if (panel) { panel.hidden = key !== id; }
        });
    }
    /* Exposed globally so report-script-parts.ts's 'selectPackage' handler (fired when a
       user picks "Open in dashboard" from an embedded tab, or from the sidebar/hover while
       the dashboard is already open) can switch back to the Overview tab before opening the
       docked detail pane -- without this the pane would open behind whichever tab is
       currently visible and the click would look like it did nothing. */
    window.saropaSelectPkgTab = selectTab;
    tabBtns.forEach(function(btn) {
        btn.addEventListener('click', function() { selectTab(btn.getAttribute('data-tab')); });
    });
    /* Digit shortcuts 1-6 jump directly to a tab (Phase 7, UX_UI_GUIDELINES "every dashboard
       tab reachable by 1-9" convention -- the Rules & Tiers dashboard already had this from
       Phase 4; this tab bar did not). Ignored while focus is in a text input/select/textarea so
       typing a digit into a Settings-tab field does not hijack the view. */
    document.addEventListener('keydown', function(e) {
        var tag = (document.activeElement && document.activeElement.tagName) || '';
        if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') { return; }
        var n = parseInt(e.key, 10);
        if (!n || n < 1 || n > tabBtns.length) { return; }
        var target = tabBtns[n - 1];
        selectTab(target.getAttribute('data-tab'));
        target.focus();
    });
    /* Deep-link "Open" buttons: ask the host (report-webview.ts) to run the
       real command that opens the existing standalone panel for that tab. */
    Array.prototype.slice.call(document.querySelectorAll('[data-open-command]')).forEach(function(btn) {
        btn.addEventListener('click', function() {
            var command = btn.getAttribute('data-open-command');
            if (command) { vscode.postMessage({ type: 'openTab', command: command }); }
        });
    });
})();
`;
}

/**
 * Client-side wiring for the embedded Upgrades tab (PLAN_ext_ui_package_tabs.md §4 Tab 3).
 *
 * `opportunities-html.ts`'s standalone script (`getOpportunitiesScript`) calls its OWN
 * `acquireVsCodeApi()` -- that call must not run a second time in this shared document (VS Code
 * throws on a second call per document), so this is a SEPARATE hand-wired script that reuses the
 * document's single `vscode` handle and posts every action wrapped as `{ type: 'upgradesCommand',
 * upgrades: {...} }` (mirrors the `optimizerCommand` wrapper `configDashboardScript.ts` uses to
 * embed the Analysis Optimizer -- see `SCRIPT_OPTIMIZER_EMBED` there for the precedent this
 * follows). `report-webview.ts` unwraps `upgrades` and forwards it to
 * `handleOpportunitiesEmbeddedMessage`, which mirrors `OpportunitiesPanel`'s own
 * `onDidReceiveMessage` switch exactly, so an action from the embedded tab has identical effect
 * to the same action in the standalone panel.
 *
 * All DOM queries are scoped to `.opp-embed-body` (never bare `document`) so this cannot match
 * anything on the rest of the dashboard -- same discipline `SCRIPT_OPTIMIZER_EMBED` follows.
 * No regex literals (see this file's own doc comment on the webview template-literal backslash
 * trap): line numbers parse with `parseInt`, nothing here needs pattern matching.
 */
export function getUpgradesEmbedScript(): string {
    return `
(function wireUpgradesEmbed() {
    var embed = document.querySelector('.opp-embed-body');
    if (!embed) { return; }

    function post(inner) { vscode.postMessage({ type: 'upgradesCommand', upgrades: inner }); }

    var writeReportBtn = embed.querySelector('#writeReportBtn');
    if (writeReportBtn) {
        var writeLabel = writeReportBtn.textContent || 'Write Report';
        writeReportBtn.addEventListener('click', function() {
            if (writeReportBtn.disabled) { return; }
            writeReportBtn.disabled = true;
            writeReportBtn.textContent = '\\u2026';
            post({ type: 'writeReport' });
        });
    }
    /* Host replies with upgradesReportWritten/upgradesReportFailed (prefixed, distinct from the
       standalone panel's own bare 'reportWritten'/'reportFailed' -- this document is shared with
       every other tab's messages, so every embed's host->client reply is namespaced). */
    window.addEventListener('message', function(event) {
        var msg = event.data;
        if (!writeReportBtn || !msg) { return; }
        if (msg.type === 'upgradesReportWritten' || msg.type === 'upgradesReportFailed') {
            writeReportBtn.disabled = false;
            writeReportBtn.textContent = writeLabel;
        }
    });

    Array.prototype.slice.call(embed.querySelectorAll('.opp-write-card')).forEach(function(btn) {
        var cardLabel = btn.textContent || 'Write Report';
        btn.addEventListener('click', function() {
            if (btn.disabled) { return; }
            btn.disabled = true;
            btn.textContent = '\\u2026';
            post({ type: 'writeCardReport', package: btn.dataset.pkg });
            setTimeout(function() { btn.disabled = false; btn.textContent = cardLabel; }, 2000);
        });
    });

    Array.prototype.slice.call(embed.querySelectorAll('.opp-open')).forEach(function(btn) {
        btn.addEventListener('click', function() {
            post({ type: 'openPackage', package: btn.dataset.pkg });
        });
    });

    Array.prototype.slice.call(embed.querySelectorAll('.opp-loc')).forEach(function(link) {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            post({ type: 'openFile', file: link.dataset.file, line: parseInt(link.dataset.line, 10) || 1 });
        });
    });
})();
`;
}

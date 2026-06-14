/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import { ComparisonData, DimensionWinner, RankedComparison, VibrancyCategory } from '../types';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { isWinnerForDimension } from '../scoring/comparison-ranker';
import { CATEGORY_DICTIONARY, scoreToGrade } from '../category-dictionary';
import { getDashboardChromeStyles } from '../../views/dashboardChromeStyles';
import {
    buildDashboardHero,
    buildDocumentTitle,
    buildStatusLine,
    getFullWidthToggleScript,
} from '../../views/dashboardHero';
import {
    buildKeyboardShortcutsButton,
    buildKeyboardShortcutsOverlay,
    getKeyboardShortcutsScript,
    getKeyboardShortcutsStyles,
} from '../../views/keyboard-shortcuts';
import { pluralize } from '../../views/webview-format';
import { l10n } from '../../i18n/runtime';

/**
 * HTML builder for **side-by-side package comparison** (scores, dimension winners, size, recommendations).
 * Embeds CSS via [getComparisonStyles] and uses [escapeHtml] for any user- or registry-derived text.
 * Renders [RankedComparison] rows and highlights per-dimension winners using [isWinnerForDimension].
 */
/** Self-contained HTML/CSS for the package comparison panel inside vibrancy webviews. */

function getComparisonStyles(): string {
    return `
        ${getDashboardChromeStyles()}
        /* Comparison-specific overrides on top of the shared chrome. */
        /* §4 — let the comparison matrix scroll within its own bounds on a
         * narrow (docked) webview instead of pushing the whole page sideways. */
        .table-scroll { max-width: 100%; overflow-x: auto; }
        .recommendation {
            background: var(--surface-3);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 12px 16px;
            margin-top: 16px;
            line-height: 1.5;
            animation: rec-in 280ms ease-out;
        }
        .recommendation strong { color: var(--link); }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 8px;
        }
        th, td {
            text-align: left;
            padding: 8px 12px;
            border-bottom: 1px solid var(--vscode-widget-border);
            vertical-align: top;
        }
        th {
            background: var(--vscode-editor-inactiveSelectionBackground);
            font-weight: 600;
            white-space: nowrap;
        }
        th.dimension { width: 140px; }
        td.winner {
            font-weight: bold;
            color: color-mix(in srgb, var(--vscode-testing-iconPassed) 58%, var(--vscode-foreground));
        }
        td.loser { opacity: 0.7; }
        .pkg-header {
            text-align: center;
            font-weight: bold;
        }
        /* §15 / WCAG 1.4.1 — links in the header text block carry an underline,
         * not color alone, so color-blind users can tell them from plain text. */
        .pkg-header a {
            /* textLink dips under AA on the tinted header cell; nudge toward
             * foreground for contrast while staying link-colored (the underline
             * is the non-color cue). */
            color: color-mix(in srgb, var(--vscode-textLink-foreground) 56%, var(--vscode-foreground));
            text-decoration: underline;
        }
        .pkg-header a:hover { color: var(--vscode-textLink-activeForeground); }
        .in-project {
            display: inline-block;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.75em;
            margin-inline-start: 6px;
        }
        /* §8.10 — multiple per-package *Add to Project* buttons used to render
           with the primary --vscode-button-background, so every header cell
           shouted "primary action!" The secondary tokens demote them to a
           supporting role so the eye can land on the toolbar's tier-1
           action (when present) instead of being scattered across cells. */
        .add-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: 1px solid var(--vscode-button-border, transparent);
            padding: 4px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85em;
            margin-top: 4px;
        }
        .add-btn:hover { background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground)); }
        /* §15 — keyboard users get the same visible affordance as hover. */
        .add-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        /* §8.10 — a disabled Add button must read as inert, not silently no-op. */
        .add-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        /* Category text is normal-size, so the semantic hue is mixed toward the
         * editor foreground to clear WCAG AA while staying recognizably
         * green / blue / amber / red. */
        .vibrant { color: color-mix(in srgb, var(--vscode-testing-iconPassed) 58%, var(--vscode-foreground)); }
        .stable { color: color-mix(in srgb, var(--vscode-editorInfo-foreground) 66%, var(--vscode-foreground)); }
        .outdated { color: color-mix(in srgb, var(--vscode-editorWarning-foreground) 55%, var(--vscode-foreground)); }
        .abandoned { color: color-mix(in srgb, var(--vscode-editorWarning-foreground) 55%, var(--vscode-foreground)); }
        .eol { color: color-mix(in srgb, var(--vscode-editorError-foreground) 72%, var(--vscode-foreground)); }
        .verified { color: color-mix(in srgb, var(--vscode-testing-iconPassed) 58%, var(--vscode-foreground)); }
        .platforms { font-size: 0.9em; }
        @keyframes rec-in {
            from { opacity: 0; transform: translateY(6px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-reduced-motion: reduce) {
            .recommendation { animation: none; }
        }
    `;
}

function getComparisonScript(): string {
    return `
        const vscode = acquireVsCodeApi();

        // §15.3 — announcer helper for confirming Add to Project actions.
        function announce(message) {
            const el = document.getElementById('announcer');
            if (!el) { return; }
            el.textContent = '';
            setTimeout(() => { el.textContent = message; }, 50);
        }

        document.querySelectorAll('.add-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const name = btn.dataset.package;
                const version = btn.dataset.version;
                vscode.postMessage({ type: 'addPackage', name, version });
                // Localized announcement template carries a __NAME__ token replaced
                // with the runtime package name (l10n runs at build time, not in the webview).
                announce(${JSON.stringify(l10n('comparison.a11y.addingToProject', { name: '__NAME__' }))}.replace('__NAME__', name));
            });
        });

        // §4.3 — toolbar action: hop to the Package Dashboard so the user
        // can pick more packages to compare without closing this panel.
        const openDashBtn = document.getElementById('openPkgDashboard');
        if (openDashBtn) {
            openDashBtn.addEventListener('click', () => {
                vscode.postMessage({ type: 'openPackageDashboard' });
            });
        }
    `;
}

function formatCategory(category: VibrancyCategory | null): string {
    if (!category) { return '—'; }
    const data = CATEGORY_DICTIONARY[category];
    return `${data.emoji} ${data.label}`;
}

function getCategoryClass(category: VibrancyCategory | null): string {
    if (!category) { return ''; }
    return CATEGORY_DICTIONARY[category].cssClass;
}

interface RowDef {
    readonly label: string;
    readonly dimension?: string;
    readonly extract: (pkg: ComparisonData) => string;
    readonly className?: (pkg: ComparisonData) => string;
}

const ROWS: readonly RowDef[] = [
    {
        /* Renamed "Vibrancy Score" → "Vibrancy Grade" and the cell shows the
           letter. The underlying score is still used for winner-ranking in
           comparison-ranker so ordering remains precise. */
        label: l10n('comparison.table.row.vibrancyGrade'),
        dimension: 'Vibrancy Grade',
        extract: p => p.vibrancyScore !== null ? scoreToGrade(p.vibrancyScore) : '—',
    },
    {
        label: l10n('comparison.table.row.category'),
        extract: p => formatCategory(p.category),
        className: p => getCategoryClass(p.category),
    },
    {
        label: l10n('comparison.table.row.latestVersion'),
        extract: p => escapeHtml(p.latestVersion || '—'),
    },
    {
        label: l10n('comparison.table.row.published'),
        extract: p => p.publishedDate ?? '—',
    },
    {
        label: l10n('comparison.table.row.publisher'),
        extract: p => p.publisher
            ? `<span class="verified">${escapeHtml(p.publisher)} ✓</span>`
            : l10n('comparison.table.value.unverified'),
    },
    {
        label: l10n('comparison.table.row.pubPoints'),
        dimension: 'Pub Points',
        extract: p => p.pubPoints > 0 ? String(p.pubPoints) : '—',
    },
    {
        label: l10n('comparison.table.row.githubStars'),
        dimension: 'GitHub Stars',
        extract: p => p.stars !== null ? p.stars.toLocaleString() : '—',
    },
    {
        label: l10n('comparison.table.row.openIssues'),
        dimension: 'Open Issues',
        extract: p => p.openIssues !== null ? String(p.openIssues) : '—',
    },
    {
        /* Code Size = what the package contributes to a built app (`lib/` +
           declared `flutter.assets:`). Falls back to the gzipped archive
           total when the tarball analyzer couldn't run. The "Archive Size"
           label and field used to be the only number here, which over-
           reported by 100x+ for packages that ship example media. See
           plans/history/2026.05/2026.05.13/
           infra_vibrancy_bloat_uses_tarball_size_not_runtime.md. */
        label: l10n('comparison.table.row.codeSize'),
        dimension: 'Code Size',
        extract: p => {
            const size = p.codeSizeBytes ?? p.archiveSizeBytes;
            return size !== null ? formatSizeMB(size) : '—';
        },
    },
    {
        label: l10n('comparison.table.row.bloatRating'),
        dimension: 'Bloat Rating',
        extract: p => p.bloatRating !== null ? `${p.bloatRating}/10` : '—',
    },
    {
        label: l10n('comparison.table.row.license'),
        extract: p => escapeHtml(p.license ?? '—'),
    },
    {
        label: l10n('comparison.table.row.platforms'),
        extract: p => p.platforms.length > 0
            ? `<span class="platforms">${p.platforms.join(', ')}</span>`
            : l10n('comparison.table.value.allPlatforms'),
    },
    {
        label: l10n('comparison.table.row.inThisProject'),
        extract: p => p.inProject ? `✅ ${l10n('comparison.table.value.yes')}` : `❌ ${l10n('comparison.table.value.no')}`,
    },
];

function buildHeaderRow(packages: readonly ComparisonData[]): string {
    const cells = packages.map(pkg => {
        const url = `https://pub.dev/packages/${encodeURIComponent(pkg.name)}`;
        const inProjectBadge = pkg.inProject
            ? `<span class="in-project">${l10n('comparison.table.badge.inProject')}</span>`
            : '';
        const addBtn = !pkg.inProject
            ? `<br><button class="add-btn" data-package="${escapeHtml(pkg.name)}" data-version="${escapeHtml(pkg.latestVersion)}">${l10n('comparison.actions.addToProject')}</button>`
            : '';
        return `<th class="pkg-header"><a href="${url}">${escapeHtml(pkg.name)}</a>${inProjectBadge}${addBtn}</th>`;
    }).join('');
    return `<tr><th class="dimension"><span class="sr-only">${escapeHtml(l10n('a11y.comparisonDimension'))}</span></th>${cells}</tr>`;
}

function buildDataRow(
    row: RowDef,
    packages: readonly ComparisonData[],
    winners: readonly DimensionWinner[],
): string {
    const hasWinner = row.dimension
        ? winners.some(w => w.dimension === row.dimension)
        : false;

    const cells = packages.map(pkg => {
        const value = row.extract(pkg);
        const isWinner = row.dimension
            ? isWinnerForDimension(pkg.name, row.dimension, winners)
            : false;
        const isLoser = hasWinner && !isWinner;
        const extraClass = row.className ? row.className(pkg) : '';
        const winnerClass = isWinner ? 'winner' : isLoser ? 'loser' : '';
        return `<td class="${winnerClass} ${extraClass}">${value}</td>`;
    }).join('');

    return `<tr><th class="dimension">${row.label}</th>${cells}</tr>`;
}

function buildComparisonTable(
    packages: readonly ComparisonData[],
    winners: readonly DimensionWinner[],
): string {
    const headerRow = buildHeaderRow(packages);
    const dataRows = ROWS.map(row => buildDataRow(row, packages, winners)).join('\n');

    return `
        <div class="table-scroll"><table>
            <thead>${headerRow}</thead>
            <tbody>${dataRows}</tbody>
        </table></div>
    `;
}

/** Build the full HTML for the package comparison webview. */
export function buildComparisonHtml(ranked: RankedComparison): string {
    const { packages, winners, recommendation } = ranked;

    const nonce = createWebviewCspNonce();
    const cspWithScript = `default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';`;
    const docTitle = escapeHtml(buildDocumentTitle(l10n('comparison.title')));

    if (packages.length === 0) {
        // Empty state inherits the same chrome + hero so the page still telegraphs
        // "Saropa Package Comparison" before showing the empty-state message.
        const heroEmpty = buildDashboardHero({
            title: l10n('comparison.title'),
            statusLineHtml: buildStatusLine([
                { glyph: '📦', label: l10n('comparison.status.packagesSelected', { count: '0' }), tone: 'warn' },
            ]),
        });
        // §8.16 — every empty state names the next action with a tier-1 CTA.
        // The natural action from this empty page is to open the Package
        // dashboard where comparisons are initiated; a muted instruction
        // line alone left the user with nothing to click.
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>${docTitle}</title>
    <meta http-equiv="Content-Security-Policy" content="${cspWithScript}">
    <style nonce="${nonce}">${getComparisonStyles()}</style>
</head>
<body>
    ${heroEmpty}
    <section class="section empty-state-card" aria-label="${l10n('comparison.empty.ariaLabel')}">
        <p class="muted">${l10n('comparison.empty.message', { compare: `<strong>${l10n('comparison.empty.compareWord')}</strong>` })}</p>
        <button type="button" class="btn tier-1" id="openPackageDashboard"
            title="${l10n('comparison.empty.openDashboardTitle')}">${l10n('comparison.empty.openDashboard')}</button>
    </section>
    <script nonce="${nonce}">(function(){
        const vscode = acquireVsCodeApi();
        const btn = document.getElementById('openPackageDashboard');
        if (btn) btn.addEventListener('click', () => vscode.postMessage({ type: 'openPackageDashboard' }));
        ${getFullWidthToggleScript()}
    })();</script>
</body>
</html>`;
    }

    // Status line carries the page's identity facts: how many packages, how many dimensions
    // have a winner, and the names of the packages being compared (truncated to keep the line short).
    const dimensionsWithWinners = winners.length;
    const statusLineHtml = buildStatusLine([
        { glyph: '📦', label: l10n('comparison.status.packagesCompared', { count: String(packages.length) }) },
        { label: pluralize(dimensionsWithWinners, { one: l10n('comparison.status.dimensionsRankedOne'), other: l10n('comparison.status.dimensionsRankedOther') }) },
        {
            label: packages.map(p => p.name).slice(0, 3).join(' vs ') + (packages.length > 3 ? ` ${l10n('comparison.status.morePackages', { count: String(packages.length - 3) })}` : ''),
            title: packages.map(p => p.name).join(', '),
        },
    ]);
    const heroHtml = buildDashboardHero({
        title: l10n('comparison.title'),
        statusLineHtml,
        extraToggleHtml: buildKeyboardShortcutsButton(),
    });
    const kpiRowHtml = buildKpiRow(packages, winners);
    const toolbarHtml = buildToolbar();

    // Recommendation box moved BELOW the table per §14.7 — the comparison data is the
    // primary content and should sit above the fold; the recommendation summary is a
    // helpful synthesis but not the user's reason for opening this panel.
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>${docTitle}</title>
    <meta http-equiv="Content-Security-Policy" content="${cspWithScript}">
    <style nonce="${nonce}">${getComparisonStyles()}${getKeyboardShortcutsStyles()}</style>
</head>
<body>
    <a href="#comparison-table" class="skip-link">${l10n('comparison.a11y.skipToTable')}</a>
    <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
    ${heroHtml}
    ${kpiRowHtml}
    ${toolbarHtml}
    <main id="comparison-table" tabindex="-1">
        ${buildComparisonTable(packages, winners)}
    </main>
    <aside aria-label="${l10n('comparison.a11y.recommendation')}">
        <div class="recommendation">${recommendation}</div>
    </aside>
    ${buildKeyboardShortcutsOverlay([
        { key: '?', label: l10n('comparison.shortcuts.showOverlay') },
        { key: 'Esc', label: l10n('comparison.shortcuts.closeOverlay') },
    ])}
    <script nonce="${nonce}">${getComparisonScript()}(function(){${getFullWidthToggleScript()}${getKeyboardShortcutsScript()}})();</script>
</body>
</html>`;
}

/**
 * §4.2 / §14.8 — KPI cards summarizing the comparison: which package leads
 * (most dimension wins), the runner-up's name, and the count of dimensions
 * ranked. Cards are non-interactive on this surface (the table itself is the
 * data view; there are no rows to filter), so they read as informational
 * KPIs rather than preset filters.
 */
function buildKpiRow(
    packages: readonly ComparisonData[],
    winners: readonly DimensionWinner[],
): string {
    // Tally dimension wins per package: each DimensionWinner names one
    // winner (winnerName) and lists all values, any of which may carry
    // isWinner=true for ties. Count every isWinner mention so a tied
    // dimension credits both packages.
    const winsByPkg = new Map<string, number>();
    for (const w of winners) {
        for (const v of w.allValues) {
            if (v.isWinner) {
                winsByPkg.set(v.name, (winsByPkg.get(v.name) ?? 0) + 1);
            }
        }
    }
    const ranked = [...winsByPkg.entries()].sort((a, b) => b[1] - a[1]);
    const leader = ranked[0];
    const leaderName = leader ? leader[0] : '—';
    const leaderWins = leader ? leader[1] : 0;
    const totalDimensions = winners.length;

    return `<section class="kpi-row" aria-label="${l10n('comparison.kpi.ariaLabel')}">
        <div class="kpi-card" title="${l10n('comparison.kpi.leadingTitle')}">
            <span class="kpi-k">${l10n('comparison.kpi.leading')}</span>
            <span class="kpi-v" style="font-size: 1.4em;">${escapeHtml(leaderName)}</span>
            <span class="kpi-sub">${pluralize(leaderWins, { one: l10n('comparison.kpi.dimensionWinsOne'), other: l10n('comparison.kpi.dimensionWinsOther') })}</span>
        </div>
        <div class="kpi-card" title="${l10n('comparison.kpi.packagesTitle')}">
            <span class="kpi-k">${l10n('comparison.kpi.packages')}</span>
            <span class="kpi-v">${packages.length}</span>
            <span class="kpi-sub">${l10n('comparison.kpi.inComparison')}</span>
        </div>
        <div class="kpi-card" title="${l10n('comparison.kpi.dimensionsTitle')}">
            <span class="kpi-k">${l10n('comparison.kpi.dimensions')}</span>
            <span class="kpi-v">${totalDimensions}</span>
            <span class="kpi-sub">${l10n('comparison.kpi.ranked')}</span>
        </div>
    </section>`;
}

/**
 * §4.3 — Toolbar band for the comparison view. The dominant action is
 * adding a package back to the project (handled per-row by .add-btn after
 * its primary-button-color demotion in §8.10), so the toolbar carries
 * supporting actions only: copy the comparison output, open the package
 * dashboard to add more comparisons. No tier-1 — none of these dominates
 * strongly enough to deserve primary emphasis on this surface.
 */
function buildToolbar(): string {
    return `<section class="toolbar-band" aria-label="${l10n('comparison.toolbar.ariaLabel')}">
        <div class="toolbar-row">
            <button type="button" class="btn" id="openPkgDashboard"
                title="${l10n('comparison.toolbar.packageDashboardTitle')}">
                <span class="glyph">📦</span>${l10n('comparison.toolbar.packageDashboard')}
            </button>
        </div>
    </section>`;
}

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
            color: var(--vscode-testing-iconPassed);
        }
        td.loser { opacity: 0.7; }
        .pkg-header {
            text-align: center;
            font-weight: bold;
        }
        .pkg-header a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        .pkg-header a:hover { text-decoration: underline; }
        .in-project {
            display: inline-block;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.75em;
            margin-left: 6px;
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
            border-radius: 3px;
            cursor: pointer;
            font-size: 0.85em;
            margin-top: 4px;
        }
        .add-btn:hover { background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground)); }
        .vibrant { color: var(--vscode-testing-iconPassed); }
        .stable { color: var(--vscode-editorInfo-foreground); }
        .outdated { color: var(--vscode-editorWarning-foreground); }
        .abandoned { color: var(--vscode-editorWarning-foreground); }
        .eol { color: var(--vscode-editorError-foreground); }
        .verified { color: var(--vscode-testing-iconPassed); }
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

        document.querySelectorAll('.add-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const name = btn.dataset.package;
                const version = btn.dataset.version;
                vscode.postMessage({ type: 'addPackage', name, version });
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
        label: 'Vibrancy Grade',
        dimension: 'Vibrancy Grade',
        extract: p => p.vibrancyScore !== null ? scoreToGrade(p.vibrancyScore) : '—',
    },
    {
        label: 'Category',
        extract: p => formatCategory(p.category),
        className: p => getCategoryClass(p.category),
    },
    {
        label: 'Latest Version',
        extract: p => escapeHtml(p.latestVersion || '—'),
    },
    {
        label: 'Published',
        extract: p => p.publishedDate ?? '—',
    },
    {
        label: 'Publisher',
        extract: p => p.publisher
            ? `<span class="verified">${escapeHtml(p.publisher)} ✓</span>`
            : '— (unverified)',
    },
    {
        label: 'Pub Points',
        dimension: 'Pub Points',
        extract: p => p.pubPoints > 0 ? String(p.pubPoints) : '—',
    },
    {
        label: 'GitHub Stars',
        dimension: 'GitHub Stars',
        extract: p => p.stars !== null ? p.stars.toLocaleString() : '—',
    },
    {
        label: 'Open Issues',
        dimension: 'Open Issues',
        extract: p => p.openIssues !== null ? String(p.openIssues) : '—',
    },
    {
        label: 'Archive Size',
        dimension: 'Archive Size',
        extract: p => p.archiveSizeBytes !== null ? formatSizeMB(p.archiveSizeBytes) : '—',
    },
    {
        label: 'Bloat Rating',
        dimension: 'Bloat Rating',
        extract: p => p.bloatRating !== null ? `${p.bloatRating}/10` : '—',
    },
    {
        label: 'License',
        extract: p => escapeHtml(p.license ?? '—'),
    },
    {
        label: 'Platforms',
        extract: p => p.platforms.length > 0
            ? `<span class="platforms">${p.platforms.join(', ')}</span>`
            : 'All',
    },
    {
        label: 'In This Project',
        extract: p => p.inProject ? '✅ Yes' : '❌ No',
    },
];

function buildHeaderRow(packages: readonly ComparisonData[]): string {
    const cells = packages.map(pkg => {
        const url = `https://pub.dev/packages/${encodeURIComponent(pkg.name)}`;
        const inProjectBadge = pkg.inProject
            ? '<span class="in-project">In Project</span>'
            : '';
        const addBtn = !pkg.inProject
            ? `<br><button class="add-btn" data-package="${escapeHtml(pkg.name)}" data-version="${escapeHtml(pkg.latestVersion)}">Add to Project</button>`
            : '';
        return `<th class="pkg-header"><a href="${url}">${escapeHtml(pkg.name)}</a>${inProjectBadge}${addBtn}</th>`;
    }).join('');
    return `<tr><th class="dimension"></th>${cells}</tr>`;
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
        <table>
            <thead>${headerRow}</thead>
            <tbody>${dataRows}</tbody>
        </table>
    `;
}

/** Build the full HTML for the package comparison webview. */
export function buildComparisonHtml(ranked: RankedComparison): string {
    const { packages, winners, recommendation } = ranked;

    const nonce = createWebviewCspNonce();
    const cspWithScript = `default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';`;
    const docTitle = escapeHtml(buildDocumentTitle('Package Comparison'));

    if (packages.length === 0) {
        // Empty state inherits the same chrome + hero so the page still telegraphs
        // "Saropa Package Comparison" before showing the empty-state message.
        const heroEmpty = buildDashboardHero({
            title: 'Package Comparison',
            statusLineHtml: buildStatusLine([
                { glyph: '📦', label: '0 packages selected', tone: 'warn' },
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
    <section class="section empty-state-card" aria-label="No packages">
        <p class="muted">No packages selected for comparison. Right-click two or more packages in the Package dashboard and choose <strong>Compare</strong>.</p>
        <button type="button" class="btn tier-1" id="openPackageDashboard"
            title="Open the Saropa Package Dashboard.">Open Package Dashboard</button>
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
        { glyph: '📦', label: `${packages.length} packages compared` },
        { label: `${dimensionsWithWinners} dimension${dimensionsWithWinners === 1 ? '' : 's'} ranked` },
        {
            label: packages.map(p => p.name).slice(0, 3).join(' vs ') + (packages.length > 3 ? ` +${packages.length - 3} more` : ''),
            title: packages.map(p => p.name).join(', '),
        },
    ]);
    const heroHtml = buildDashboardHero({
        title: 'Package Comparison',
        statusLineHtml,
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
    <style nonce="${nonce}">${getComparisonStyles()}</style>
</head>
<body>
    ${heroHtml}
    ${kpiRowHtml}
    ${toolbarHtml}
    ${buildComparisonTable(packages, winners)}
    <div class="recommendation">${recommendation}</div>
    <script nonce="${nonce}">${getComparisonScript()}(function(){${getFullWidthToggleScript()}})();</script>
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

    return `<section class="kpi-row" aria-label="Comparison summary">
        <div class="kpi-card" title="Package leading by most dimension wins.">
            <span class="kpi-k">Leading</span>
            <span class="kpi-v" style="font-size: 1.4em;">${escapeHtml(leaderName)}</span>
            <span class="kpi-sub">${leaderWins} dimension win${leaderWins === 1 ? '' : 's'}</span>
        </div>
        <div class="kpi-card" title="Number of packages compared side-by-side.">
            <span class="kpi-k">Packages</span>
            <span class="kpi-v">${packages.length}</span>
            <span class="kpi-sub">in comparison</span>
        </div>
        <div class="kpi-card" title="Number of dimensions where a winner could be ranked.">
            <span class="kpi-k">Dimensions</span>
            <span class="kpi-v">${totalDimensions}</span>
            <span class="kpi-sub">ranked</span>
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
    return `<section class="toolbar-band" aria-label="Comparison actions">
        <div class="toolbar-row">
            <button type="button" class="btn" id="openPkgDashboard"
                title="Open the Package Dashboard to compare more packages.">
                <span class="glyph">📦</span>Package Dashboard
            </button>
        </div>
    </section>`;
}

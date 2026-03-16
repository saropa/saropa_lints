import { ComparisonData, DimensionWinner, RankedComparison, VibrancyCategory } from '../types';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { escapeHtml } from './html-utils';
import { isWinnerForDimension } from '../scoring/comparison-ranker';

const CATEGORY_LABELS: Record<VibrancyCategory, string> = {
    'vibrant': 'Vibrant',
    'quiet': 'Quiet',
    'legacy-locked': 'Legacy',
    'end-of-life': 'End of Life',
};

const CATEGORY_EMOJI: Record<VibrancyCategory, string> = {
    'vibrant': '🟢',
    'quiet': '🟡',
    'legacy-locked': '🟠',
    'end-of-life': '🔴',
};

function getComparisonStyles(): string {
    return `
        body {
            font-family: var(--vscode-font-family);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            padding: 16px;
            margin: 0;
        }
        h1 { font-size: 1.4em; margin-bottom: 16px; }
        .recommendation {
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 6px;
            padding: 12px 16px;
            margin-bottom: 16px;
            line-height: 1.5;
        }
        .recommendation strong { color: var(--vscode-textLink-foreground); }
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
        .add-btn {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            padding: 4px 12px;
            border-radius: 3px;
            cursor: pointer;
            font-size: 0.85em;
            margin-top: 4px;
        }
        .add-btn:hover { background: var(--vscode-button-hoverBackground); }
        .vibrant { color: var(--vscode-testing-iconPassed); }
        .quiet { color: var(--vscode-editorInfo-foreground); }
        .legacy { color: var(--vscode-editorWarning-foreground); }
        .eol { color: var(--vscode-editorError-foreground); }
        .verified { color: var(--vscode-testing-iconPassed); }
        .platforms { font-size: 0.9em; }
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
    `;
}

function formatCategory(category: VibrancyCategory | null): string {
    if (!category) { return '—'; }
    return `${CATEGORY_EMOJI[category]} ${CATEGORY_LABELS[category]}`;
}

function getCategoryClass(category: VibrancyCategory | null): string {
    if (!category) { return ''; }
    switch (category) {
        case 'vibrant': return 'vibrant';
        case 'quiet': return 'quiet';
        case 'legacy-locked': return 'legacy';
        case 'end-of-life': return 'eol';
    }
}

interface RowDef {
    readonly label: string;
    readonly dimension?: string;
    readonly extract: (pkg: ComparisonData) => string;
    readonly className?: (pkg: ComparisonData) => string;
}

const ROWS: readonly RowDef[] = [
    {
        label: 'Vibrancy Score',
        dimension: 'Vibrancy Score',
        extract: p => p.vibrancyScore !== null ? `${p.vibrancyScore}/100` : '—',
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

    if (packages.length === 0) {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <style>${getComparisonStyles()}</style>
</head>
<body>
    <h1>Package Comparison</h1>
    <p>No packages selected for comparison.</p>
</body>
</html>`;
    }

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
    <style>${getComparisonStyles()}</style>
</head>
<body>
    <h1>Package Comparison</h1>
    <div class="recommendation">${recommendation}</div>
    ${buildComparisonTable(packages, winners)}
    <script>${getComparisonScript()}</script>
</body>
</html>`;
}

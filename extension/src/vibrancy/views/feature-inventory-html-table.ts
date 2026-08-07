/**
 * Level 1 of the Package Feature Inventory report: the sortable summary table,
 * one row per package, and the package jump index above it.
 *
 * Every numeric cell carries a raw `data-sort` value so the client-side sorter
 * never has to parse a display-formatted number back into a comparable one.
 */

import { PackageFeatureRecord, FeatureInventoryReport } from '../services/feature-inventory-types';
import { escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { packageAnchor } from './feature-inventory-utils';

/** Column definitions: catalog key for the header, and its sort behavior. */
const COLUMNS: ReadonlyArray<readonly [string, 'text' | 'number']> = [
    ['featureInventory.summary.colPackage', 'text'],
    ['featureInventory.summary.colVersion', 'text'],
    ['featureInventory.summary.colFeatures', 'number'],
    ['featureInventory.summary.colAdopted', 'number'],
    ['featureInventory.summary.colUnadopted', 'number'],
    ['featureInventory.summary.colUsages', 'number'],
    ['featureInventory.summary.colScore', 'number'],
];

/** The complete summary table, with a sticky, click-to-sort header row. */
export function buildSummaryTable(report: FeatureInventoryReport): string {
    const headers = COLUMNS.map(([key, type]) =>
        `<th scope="col" data-sort-type="${type}" title="${escapeHtml(
            l10n('featureInventory.summary.sortHint'),
        )}">${escapeHtml(l10n(key))}</th>`).join('');
    const rows = report.packages.map(buildRow).join('');

    return `<h2 id="fi-summary-heading">${escapeHtml(l10n('featureInventory.summary.title'))}</h2>
    <table class="fi-table" id="fi-summary" aria-labelledby="fi-summary-heading">
        <thead><tr>${headers}</tr></thead>
        <tbody>${rows}</tbody>
    </table>`;
}

/** One package row; the name links into that package's section anchor. */
function buildRow(record: PackageFeatureRecord): string {
    const anchor = escapeHtml(packageAnchor(record.name));
    const name = escapeHtml(record.name);
    const cells = [
        `<td data-sort="${name}"><a href="#${anchor}">${name}</a></td>`,
        `<td data-sort="${escapeHtml(record.version)}">${escapeHtml(record.version)}</td>`,
        numberCell(record.counts.total),
        numberCell(record.counts.adopted),
        numberCell(record.counts.unadopted),
        numberCell(record.counts.totalUsages),
        numberCell(record.opportunityScore),
    ].join('');
    return `<tr>${cells}</tr>`;
}

function numberCell(value: number): string {
    return `<td data-sort="${value}">${escapeHtml(value.toLocaleString())}</td>`;
}

/** Jump index — a chip per package, so a long report stays navigable. */
export function buildPackageIndex(report: FeatureInventoryReport): string {
    if (report.packages.length === 0) { return ''; }
    const links = report.packages.map(p =>
        `<a href="#${escapeHtml(packageAnchor(p.name))}">${escapeHtml(p.name)}</a>`).join('');
    return `<nav class="fi-index" aria-label="${escapeHtml(
        l10n('featureInventory.controls.indexLabel'),
    )}">${links}</nav>`;
}

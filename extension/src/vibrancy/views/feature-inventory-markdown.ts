/**
 * Package Feature Inventory — Markdown twin of the HTML report.
 *
 * Same model, same hierarchy, same disclosure rules. It exists because the
 * report's primary consumer is an AI reviewer reading raw text: the HTML page
 * is for a human, this file is what gets pasted into a review prompt or diffed
 * between runs.
 *
 * Pure renderer: model in, string out. No `vscode` import.
 */

import { FeatureInventoryReport, PackageFeatureRecord } from '../services/feature-inventory-types';
import { l10n } from '../../i18n/runtime';
import { oneLine, renderPackage } from './feature-inventory-markdown-package';

/** Build the complete Markdown report. */
export function buildFeatureInventoryMarkdown(report: FeatureInventoryReport): string {
    const packages = report.packages.length === 0
        ? `_${l10n('featureInventory.empty.body')}_\n`
        : report.packages.map(renderPackage).join('\n');

    return [
        `# ${l10n('featureInventory.heroTitle')}`,
        '',
        buildMeta(report),
        '',
        buildCaveats(report.caveats),
        '',
        buildSummaryTable(report),
        '',
        `## ${l10n('featureInventory.packages.title')}`,
        '',
        packages,
    ].join('\n');
}

function buildMeta(report: FeatureInventoryReport): string {
    return l10n('featureInventory.meta', {
        timestamp: report.generatedAt,
        version: report.extensionVersion,
        packages: String(report.packages.length),
    });
}

/**
 * Measurement limits, placed above the data. A reader who sees the counts first
 * has already formed a conclusion by the time the caveats arrive.
 */
function buildCaveats(caveats: readonly string[]): string {
    const items = caveats.length === 0
        ? [`- ${l10n('featureInventory.caveats.none')}`]
        : caveats.map(c => `- ${oneLine(c)}`);
    return [
        `## ${l10n('featureInventory.caveats.title')}`,
        '',
        l10n('featureInventory.caveats.intro'),
        '',
        ...items,
    ].join('\n');
}

/** Level 1: one row per package, mirroring the HTML summary table's columns. */
function buildSummaryTable(report: FeatureInventoryReport): string {
    const headers = [
        l10n('featureInventory.summary.colPackage'),
        l10n('featureInventory.summary.colVersion'),
        l10n('featureInventory.summary.colFeatures'),
        l10n('featureInventory.summary.colAdopted'),
        l10n('featureInventory.summary.colUnadopted'),
        l10n('featureInventory.summary.colUsages'),
        l10n('featureInventory.summary.colScore'),
    ];
    const divider = headers.map(() => '---');
    const rows = report.packages.map(summaryRow);
    return [
        `## ${l10n('featureInventory.summary.title')}`,
        '',
        row(headers),
        row(divider),
        ...rows,
    ].join('\n');
}

function summaryRow(record: PackageFeatureRecord): string {
    return row([
        record.name,
        record.version,
        String(record.counts.total),
        String(record.counts.adopted),
        String(record.counts.unadopted),
        String(record.counts.totalUsages),
        String(record.opportunityScore),
    ]);
}

/** A table row with cell pipes neutralized so no value can split a column. */
function row(cells: readonly string[]): string {
    return `| ${cells.map(c => c.split('|').join('\\|')).join(' | ')} |`;
}

/**
 * Package Feature Inventory — standalone HTML report.
 *
 * The exhaustive counterpart to the three focused in-editor opportunity
 * surfaces: EVERY scanned package, EVERY mined changelog feature, in every
 * category, with usage counted from 0 to n and every usage site located.
 *
 * Written to `reports/` and opened in a browser, so unlike the webview panels
 * it ships its own stylesheet (see `feature-inventory-styles`) rather than
 * relying on `--vscode-*` theme variables, which do not exist outside VS Code.
 *
 * Pure renderer: model in, string out. No `vscode` import, fully unit-testable.
 */

import { FeatureInventoryReport } from '../services/feature-inventory-types';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { l10n } from '../../i18n/runtime';
import { getFeatureInventoryStyles } from './feature-inventory-styles';
import { getFeatureInventoryScript } from './feature-inventory-script';
import { buildPackageIndex, buildSummaryTable } from './feature-inventory-html-table';
import { buildPackageSection } from './feature-inventory-html-package';

/** Build the complete report document. */
export function buildFeatureInventoryHtml(report: FeatureInventoryReport): string {
    const nonce = createWebviewCspNonce();
    const sections = report.packages.length === 0
        ? `<p class="fi-note">${escapeHtml(l10n('featureInventory.empty.body'))}</p>`
        : report.packages.map(buildPackageSection).join('\n');

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
    <title>${escapeHtml(l10n('featureInventory.documentTitle'))}</title>
    <style nonce="${nonce}">${getFeatureInventoryStyles()}</style>
</head>
<body>
${buildHeader(report)}
${buildControls()}
${buildPackageIndex(report)}
${buildSummaryTable(report)}
<h2>${escapeHtml(l10n('featureInventory.packages.title'))}</h2>
${sections}
<script nonce="${nonce}">${getFeatureInventoryScript()}</script>
</body>
</html>`;
}

/**
 * Title, provenance, and the caveats — rendered prominently rather than
 * footnoted. A reviewing AI must weigh the measurement limits before it reads a
 * single count, so they sit above the data, not below it.
 */
function buildHeader(report: FeatureInventoryReport): string {
    const meta = escapeHtml(l10n('featureInventory.meta', {
        timestamp: report.generatedAt,
        version: report.extensionVersion,
        packages: String(report.packages.length),
    }));
    return `<header>
    <h1>${escapeHtml(l10n('featureInventory.heroTitle'))}</h1>
    <p class="fi-meta">${meta}</p>
    ${buildCaveats(report.caveats)}
</header>`;
}

/** The measurement-limit callout. Always rendered, even if the list is empty. */
function buildCaveats(caveats: readonly string[]): string {
    const items = caveats.length === 0
        ? `<li>${escapeHtml(l10n('featureInventory.caveats.none'))}</li>`
        : caveats.map(c => `<li>${escapeHtml(c)}</li>`).join('');
    return `<section class="fi-caveats" role="note">
        <h2>${escapeHtml(l10n('featureInventory.caveats.title'))}</h2>
        <p>${escapeHtml(l10n('featureInventory.caveats.intro'))}</p>
        <ul>${items}</ul>
    </section>`;
}

/** Text filter, the three mutually exclusive modes, and expand/collapse all. */
function buildControls(): string {
    const modes: ReadonlyArray<readonly [string, string]> = [
        ['unused', 'featureInventory.controls.unusedOnly'],
        ['used', 'featureInventory.controls.usedOnly'],
        ['deprecated', 'featureInventory.controls.deprecatedOnly'],
    ];
    const buttons = modes.map(([mode, key]) =>
        `<button type="button" class="fi-btn fi-mode" data-mode="${mode}" aria-pressed="false">`
        + `${escapeHtml(l10n(key))}</button>`).join('');

    return `<div class="fi-controls">
        <input type="search" id="fi-search"
            aria-label="${escapeHtml(l10n('featureInventory.controls.filterLabel'))}"
            placeholder="${escapeHtml(l10n('featureInventory.controls.filterPlaceholder'))}">
        ${buttons}
        <button type="button" class="fi-btn" id="fi-expand">${escapeHtml(
        l10n('featureInventory.controls.expandAll'))}</button>
        <button type="button" class="fi-btn" id="fi-collapse">${escapeHtml(
        l10n('featureInventory.controls.collapseAll'))}</button>
    </div>`;
}

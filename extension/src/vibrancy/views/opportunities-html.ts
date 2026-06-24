/**
 * Dedicated "Upgrade Opportunities" dashboard.
 *
 * A FOCUSED surface — distinct from the dense Package Dashboard table — that
 * answers one question: across all my dependencies, which have features I have
 * not adopted, and what do I need to act on each? It lists ONLY packages with
 * unadopted changelog features, ranked by relevance, and for each shows the
 * package, its description, README imagery, the new features, the project code
 * locations that use it, and a one-click "Copy for AI" prompt.
 *
 * Pure HTML builder: takes already-scanned results (the opportunity scan and
 * symbol cross-reference ran during the package scan) and renders a string. The
 * panel host (`opportunities-panel`) supplies the webview and message channel.
 */

import { VibrancyResult } from '../types';
import { createWebviewCspNonce, escapeHtml } from './html-utils';
import { getReportStyles } from './report-styles';
import { getPackageDetailStylesScoped } from './package-detail-styles';
import { l10n } from '../../i18n/runtime';
import { activeFileUsages } from '../types';

/** Per-package data the cards need, plus the precomputed AI prompt. */
export interface OpportunityCardData {
    readonly result: VibrancyResult;
    /** Ready-to-paste AI prompt, or null when none could be built. */
    readonly aiPrompt: string | null;
}

/**
 * Build the full Upgrade Opportunities dashboard document.
 *
 * `cards` is the host-prepared list (it owns prompt assembly so this stays a
 * pure renderer). Packages without unadopted features are filtered and the rest
 * sorted by relevance score before rendering; an empty set renders a positive
 * empty state rather than a broken-looking blank page.
 */
export function buildOpportunitiesHtml(
    cards: readonly OpportunityCardData[],
    extensionVersion: string,
): string {
    const nonce = createWebviewCspNonce();
    const ranked = [...cards]
        .filter(c => (c.result.unadoptedApiNames?.length ?? 0) > 0)
        .sort((a, b) =>
            (b.result.opportunityScore ?? 0) - (a.result.opportunityScore ?? 0));

    const body = ranked.length === 0
        ? buildEmptyState()
        : ranked.map(buildCard).join('\n');

    const subtitle = ranked.length === 0
        ? ''
        : `<p class="opp-subtitle">${escapeHtml(
            l10n('opportunities.subtitle', { count: String(ranked.length) }),
        )}</p>`;

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <title>${escapeHtml(l10n('opportunities.documentTitle'))}</title>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; img-src https: data:; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
    <style nonce="${nonce}">${getReportStyles()}${getPackageDetailStylesScoped()}${getOpportunitiesStyles()}</style>
</head>
<body>
    <header class="report-header">
        <div class="hero-text">
            <h1>${escapeHtml(l10n('opportunities.heroTitle'))} <span class="header-version">v${escapeHtml(extensionVersion)}</span></h1>
            ${subtitle}
        </div>
    </header>
    <main class="opp-list">
        ${body}
    </main>
    <script nonce="${nonce}">${getOpportunitiesScript()}</script>
</body>
</html>`;
}

/** One package card: identity, description, features, code locations, actions. */
function buildCard(card: OpportunityCardData): string {
    const r = card.result;
    const name = escapeHtml(r.package.name);
    const version = escapeHtml(r.package.version);
    const latest = r.updateInfo?.latestVersion ?? r.package.version;
    const versionNote = latest !== r.package.version
        ? escapeHtml(l10n('opportunities.card.versionUpgrade', { latest }))
        : escapeHtml(l10n('opportunities.card.versionCurrent'));

    return `<section class="opp-card">
        <div class="opp-card-head">
            <h2 class="opp-card-name">${name}</h2>
            <span class="opp-card-version">${version} · ${versionNote}</span>
        </div>
        ${buildDescription(r)}
        ${buildLogo(r)}
        ${buildFeatures(r)}
        ${buildLocations(r)}
        ${buildActions(card)}
    </section>`;
}

function buildDescription(r: VibrancyResult): string {
    const desc = r.pubDev?.description;
    if (!desc) { return ''; }
    return `<p class="opp-desc">${escapeHtml(desc)}</p>`;
}

/** README logo if one was extracted during the scan; omitted otherwise. */
function buildLogo(r: VibrancyResult): string {
    const logo = r.readme?.logoUrl;
    if (!logo) { return ''; }
    return `<img class="opp-logo" src="${escapeHtml(logo)}" alt="${escapeHtml(r.package.name)}" />`;
}

/** The unadopted features — the heart of the card. */
function buildFeatures(r: VibrancyResult): string {
    const unused = r.unadoptedApiNames ?? [];
    const chips = unused
        .map(n => `<code class="opp-chip">${escapeHtml(n)}</code>`)
        .join(' ');
    // The classified changelog bullets that introduced these features, so the
    // user reads what each does, not just the symbol name.
    const bullets = (r.opportunities?.opportunities ?? [])
        .slice(0, 8)
        .map(b => `<li>${escapeHtml(b.text)}</li>`)
        .join('');

    return `<div class="opp-features">
        <div class="opp-features-head">${escapeHtml(l10n('opportunities.card.featuresTitle'))}</div>
        <div class="opp-chips">${chips}</div>
        ${bullets ? `<ul class="opp-bullets">${bullets}</ul>` : ''}
    </div>`;
}

/** Project files that import this package — where to apply the new features. */
function buildLocations(r: VibrancyResult): string {
    const files = activeFileUsages(r.fileUsages);
    if (files.length === 0) {
        return `<p class="opp-locations opp-locations-empty">${escapeHtml(
            l10n('opportunities.card.noLocations'),
        )}</p>`;
    }
    const rows = files.slice(0, 15).map(u => {
        const line = u.importLine ?? u.exportLine ?? u.line;
        const label = `${escapeHtml(u.filePath)}:${line}`;
        // data-* drive the openFile postMessage in the card script.
        return `<li><a href="#" class="opp-loc" data-file="${escapeHtml(u.filePath)}" data-line="${line}">${label}</a></li>`;
    }).join('');
    const more = files.length > 15
        ? `<li class="opp-more">${escapeHtml(l10n('opportunities.card.moreFiles', { count: String(files.length - 15) }))}</li>`
        : '';
    return `<div class="opp-locations">
        <div class="opp-features-head">${escapeHtml(l10n('opportunities.card.locationsTitle'))}</div>
        <ul class="opp-loc-list">${rows}${more}</ul>
    </div>`;
}

/** Card actions: copy the AI prompt and open the package in the dashboard. */
function buildActions(card: OpportunityCardData): string {
    const name = escapeHtml(card.result.package.name);
    const copyBtn = card.aiPrompt
        // The prompt is embedded as an escaped data attribute the script reads,
        // so copying is a pure in-webview clipboard write (no host round-trip).
        ? `<button class="opp-btn opp-copy" data-prompt="${escapeHtml(card.aiPrompt)}">${escapeHtml(l10n('opportunities.card.copyForAi'))}</button>`
        : '';
    const openBtn = `<button class="opp-btn opp-open" data-pkg="${name}">${escapeHtml(l10n('opportunities.card.openInDashboard'))}</button>`;
    return `<div class="opp-actions">${copyBtn}${openBtn}</div>`;
}

/** Positive empty state — being fully adopted is a good outcome, not a blank. */
function buildEmptyState(): string {
    return `<section class="opp-empty">
        <div class="opp-empty-glyph">✓</div>
        <h2>${escapeHtml(l10n('opportunities.empty.title'))}</h2>
        <p>${escapeHtml(l10n('opportunities.empty.body'))}</p>
    </section>`;
}

/** Scoped styles for the cards; the report + detail styles supply the rest. */
function getOpportunitiesStyles(): string {
    return `
        .opp-subtitle { color: var(--vscode-descriptionForeground); margin: 4px 0 0; }
        .opp-list { display: flex; flex-direction: column; gap: 16px; padding: 16px; }
        .opp-card {
            border: 1px solid var(--vscode-panel-border);
            border-radius: 8px; padding: 16px;
            background: var(--vscode-editorWidget-background);
        }
        .opp-card-head { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
        .opp-card-name { margin: 0; font-size: 1.15em; }
        .opp-card-version { color: var(--vscode-descriptionForeground); font-size: 0.85em; }
        .opp-desc { margin: 8px 0; color: var(--vscode-foreground); }
        .opp-logo { max-height: 48px; max-width: 160px; margin: 4px 0; }
        .opp-features { margin: 12px 0; }
        .opp-features-head { font-weight: 600; margin-bottom: 6px; }
        .opp-chips { display: flex; flex-wrap: wrap; gap: 6px; }
        .opp-chip {
            background: var(--vscode-charts-blue, var(--vscode-textLink-foreground));
            color: var(--vscode-editor-background);
            padding: 1px 6px; border-radius: 10px; font-size: 0.8em;
        }
        .opp-bullets { margin: 8px 0 0; padding-inline-start: 18px; color: var(--vscode-descriptionForeground); }
        .opp-locations { margin: 12px 0; }
        .opp-locations-empty { color: var(--vscode-descriptionForeground); font-style: italic; }
        .opp-loc-list { margin: 0; padding-inline-start: 18px; }
        .opp-loc { color: var(--vscode-textLink-foreground); text-decoration: none; }
        .opp-loc:hover { text-decoration: underline; }
        .opp-more { color: var(--vscode-descriptionForeground); list-style: none; }
        .opp-actions { display: flex; gap: 8px; margin-top: 12px; }
        .opp-btn {
            border: 1px solid var(--vscode-button-border, transparent);
            border-radius: 4px; padding: 4px 12px; cursor: pointer; font-size: 0.85em;
            background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground);
        }
        .opp-copy { background: var(--vscode-button-background); color: var(--vscode-button-foreground); }
        .opp-btn.copied { opacity: 0.7; }
        .opp-empty { text-align: center; padding: 64px 16px; color: var(--vscode-descriptionForeground); }
        .opp-empty-glyph { font-size: 2.5em; color: var(--vscode-charts-green, var(--vscode-testing-iconPassed)); }
    `;
}

/** Card-level interactions: copy prompt (in-webview), open file, open package. */
function getOpportunitiesScript(): string {
    return `
        const vscode = acquireVsCodeApi();
        document.querySelectorAll('.opp-copy').forEach(function(btn) {
            const label = btn.textContent;
            btn.addEventListener('click', function() {
                if (btn.classList.contains('copied')) { return; }
                navigator.clipboard.writeText(btn.dataset.prompt || '').then(function() {
                    btn.textContent = '\\u2713';
                    btn.classList.add('copied');
                    setTimeout(function() { btn.textContent = label; btn.classList.remove('copied'); }, 1500);
                });
            });
        });
        document.querySelectorAll('.opp-open').forEach(function(btn) {
            btn.addEventListener('click', function() {
                vscode.postMessage({ type: 'openPackage', package: btn.dataset.pkg });
            });
        });
        document.querySelectorAll('.opp-loc').forEach(function(link) {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                vscode.postMessage({ type: 'openFile', file: link.dataset.file, line: parseInt(link.dataset.line, 10) || 1 });
            });
        });
    `;
}

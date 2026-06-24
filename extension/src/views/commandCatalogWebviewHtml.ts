/**
 * HTML, CSS, and client script for the **command catalog** webview.
 *
 * Layout follows the editor-area dashboard guidelines (UX_UI_GUIDELINES.md):
 *
 *   §4.1 Header     — title + status line (real counts; no marketing subtitle).
 *   §4.3 Toolbar    — one bordered band wrapping search, internal toggle,
 *                     collapse-all. Sticky on scroll.
 *   §8.5 / §14.10   — active-filter chip strip whenever filter state diverges
 *                     from defaults; each chip removable, plus "Clear all".
 *   §14.7           — density-first ordering: Frequent → Recent → Categories.
 *                     Frequent surfaces the user's most-used commands; Recent
 *                     keeps reverse-chronological pinning. Both come from the
 *                     same history records (count vs at).
 *   §3 / §14.6      — slim two-line rows, no per-category bordered cards,
 *                     sticky uppercase microlabel section headers — so 156
 *                     entries do not read as a single uniform wall.
 *   §8.7            — flat icon (no boxed wrap) so the icon does not compete
 *                     with the title for the eye.
 *   §8.13           — Up/Down/Home/End keyboard navigation across visible rows.
 *   §8.14           — per-row "copy command id" affordance fades in on hover;
 *                     the id is no longer rendered as a third visible line on
 *                     every row (was the dominant source of "wall of text").
 *
 * Entry: [buildCommandCatalogHtml] consumes [entriesByCategory] and
 * [buildCatalogSearchBlob] for client-side filter without round-trips to the
 * extension host until a command is picked.
 */

import * as vscode from 'vscode';
import type { CatalogCategory, CatalogEntry } from './commandCatalogRegistry';
import { catalogEntries, entriesByCategory } from './commandCatalogRegistry';
import { buildCatalogSearchBlob } from './commandCatalogSearch';
import type { CatalogHistoryRecord } from './commandCatalogHistory';
import { getStyles } from './commandCatalogStyles';
import { getScript } from './commandCatalogScript';
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';
import { l10n } from '../i18n/runtime';

/** Client-side strings for `getScript()` (webview has no direct access to `l10n`). */
function commandCatalogScriptI18nJson(): string {
  const s = 'commandCatalog.script';
  return JSON.stringify({
    moreSuffix: l10n(`${s}.moreSuffix`),
    showLess: l10n(`${s}.showLess`),
    runSingular: l10n(`${s}.runSingular`),
    runPlural: l10n(`${s}.runPlural`),
    recentWord: l10n(`${s}.recentWord`),
    expandAll: l10n(`${s}.expandAll`),
    collapseAll: l10n(`${s}.collapseAll`),
    searchChip: l10n(`${s}.searchChip`),
    internalChip: l10n(`${s}.internalChip`),
    removeFilterPrefix: l10n(`${s}.removeFilterPrefix`),
    matchOne: l10n(`${s}.matchOne`),
    matchOther: l10n(`${s}.matchOther`),
  });
}

/** Muted search hint below toolbar (HTML fragment). */
function buildCommandCatalogSearchHint(): string {
  const s = 'commandCatalog.search';
  return `${l10n(`${s}.hintLine1`)} <strong>${l10n(`${s}.hintStrongTitle`)}</strong>, <strong>${l10n(`${s}.hintStrongDesc`)}</strong>, and <strong>${l10n(`${s}.hintStrongId`)}</strong>\n    ${l10n(`${s}.hintLine2`)} <kbd>${l10n(`${s}.hintLine2kbd`)}</kbd> ${l10n(`${s}.hintLine2End`)}`;
}

/** Cap on Recent chips visible by default before "+N more" overflow (§8.10). */
const RECENT_VISIBLE_DEFAULT = 6;

/** Cap on Frequent tiles rendered (§14.7 — top-of-page primary actions). */
const FREQUENT_TILE_LIMIT = 6;

export function buildCommandCatalogHtml(
  webview: vscode.Webview,
  extensionUri: vscode.Uri,
  history: CatalogHistoryRecord[],
  /** Workspace-persisted catalog search phrases (shown in §8.5.2 popover). */
  catalogSearchRecent: string[],
): string {
  const nonce = getNonce();
  const grouped = entriesByCategory();
  const sectionsHtml = buildSectionsHtml(grouped);

  const totalCount = catalogEntries.length;
  const internalCount = catalogEntries.filter((e) => e.internal).length;
  const publicCount = totalCount - internalCount;
  const categoryCount = grouped.size;
  const historyCount = history.length;

  const codiconCss = webview.asWebviewUri(
    vscode.Uri.joinPath(extensionUri, 'media', 'codicons', 'codicon.css'),
  );

  const csp = [
    "default-src 'none'",
    `style-src ${webview.cspSource} 'nonce-${nonce}'`,
    `font-src ${webview.cspSource}`,
    `script-src 'nonce-${nonce}'`,
  ].join('; ');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy" content="${csp}">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="${codiconCss}">
  <title>${escapeHtml(l10n('commandCatalog.documentTitle'))}</title>
  <style nonce="${nonce}">
    ${getStyles()}
    ${getKeyboardShortcutsStyles()}
  </style>
</head>
<body>
  <a href="#catalog-main" class="skip-link">${escapeHtml(l10n('commandCatalog.skipLink'))}</a>
  <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
  <header class="hero">
    <div class="hero-inner">
      <h1 class="hero-title">${escapeHtml(l10n('commandCatalog.heroTitle'))}</h1>
      <p class="status-line" id="statusLine">
        <span data-stat="public"><strong>${publicCount}</strong> ${escapeHtml(l10n('commandCatalog.status.wordCommands'))}</span>
        <span class="status-sep">·</span>
        <span data-stat="categories"><strong>${categoryCount}</strong> ${escapeHtml(l10n('commandCatalog.status.wordCategories'))}</span>
        <span class="status-sep">·</span>
        <span data-stat="history" id="statHistory">
          <strong>${historyCount}</strong> ${escapeHtml(l10n('commandCatalog.status.wordRecent'))}
        </span>
        <span class="status-sep">·</span>
        <span data-stat="internal" class="status-dim" id="statInternal">
          ${escapeHtml(l10n('commandCatalog.status.internalHidden', { count: String(internalCount) }))}
        </span>
        ${buildKeyboardShortcutsButton()}
      </p>
    </div>
  </header>

  <div class="toolbar-wrap">
    <div class="toolbar-inner">
      <div class="toolbar-band" role="search">
        <div class="search-row">
          <span class="search-icon codicon codicon-search" aria-hidden="true"></span>
          <input
            type="text"
            id="search"
            class="search-input"
            placeholder="${escapeAttr(l10n('commandCatalog.search.placeholder'))}"
            autocomplete="off"
            spellcheck="false"
            aria-label="${escapeAttr(l10n('commandCatalog.search.ariaLabel'))}"
          />
          <button
            type="button"
            id="searchClear"
            class="search-clear"
            aria-label="${escapeAttr(l10n('commandCatalog.search.clearAria'))}"
            hidden
          >
            <span class="codicon codicon-close" aria-hidden="true"></span>
          </button>
          <span class="search-count" id="searchCount" aria-live="polite"></span>
          <!-- §8.5.2 — recent-searches popover. Stored in sessionStorage;
               cross-session persistence is tracked in
               plan/UX_GUIDELINES.md (Part B). -->
          <div id="catalog-recent" class="catalog-recent" hidden>
            <div class="catalog-recent-head">
              <span class="catalog-recent-title">${escapeHtml(l10n('commandCatalog.recentPopover.title'))}</span>
              <button type="button" id="catalog-recent-clear"
                class="catalog-recent-clear"
                title="${escapeAttr(l10n('commandCatalog.recentPopover.clearTitle'))}">${escapeHtml(l10n('commandCatalog.recentPopover.clearButton'))}</button>
            </div>
            <ul id="catalog-recent-list" class="catalog-recent-list"
              role="listbox" aria-label="${escapeAttr(l10n('commandCatalog.recentPopover.listAria'))}"></ul>
          </div>
        </div>
        <div class="toolbar-controls">
          <label class="checkbox-control">
            <input type="checkbox" id="showInternal" />
            <span>${escapeHtml(l10n('commandCatalog.toolbar.showInternal'))}</span>
          </label>
          <button type="button" class="text-btn" id="toggleAll" aria-pressed="false">
            ${escapeHtml(l10n('commandCatalog.toolbar.collapseAll'))}
          </button>
        </div>
      </div>
    </div>
  </div>
  <!-- §4.3 — search hint moved out of .toolbar-wrap so the toolbar band reads
       as a control surface, not a control surface plus a help paragraph.
       The hint is a one-line muted sentence below the band; full kbd-style
       formatting still renders in the same #searchHint element so any
       script that touched it keeps working. -->
  <p class="search-hint search-hint-below" id="searchHint">
    ${buildCommandCatalogSearchHint()}
  </p>

  <div
    class="filter-chip-strip"
    id="filterChips"
    role="region"
    aria-label="${escapeAttr(l10n('commandCatalog.filterChips.ariaRegion'))}"
    hidden
  >
    <span class="filter-chip-label">${escapeHtml(l10n('commandCatalog.filterChips.activeLabel'))}</span>
    <span id="filterChipsBody"></span>
    <button type="button" class="text-btn" id="clearFilters">${escapeHtml(l10n('commandCatalog.filterChips.clearAll'))}</button>
  </div>

  <section class="band band-frequent" id="frequentSection" hidden>
    <div class="band-header">
      <h2 class="section-title">${escapeHtml(l10n('commandCatalog.bands.frequentTitle'))}</h2>
    </div>
    <p class="band-hint">${escapeHtml(l10n('commandCatalog.bands.frequentHint'))}</p>
    <div class="frequent-grid" id="frequentGrid"></div>
  </section>

  <section class="band band-recent" id="historySection" ${historyCount === 0 ? 'hidden' : ''}>
    <div class="band-header">
      <h2 class="section-title">${escapeHtml(l10n('commandCatalog.bands.recentTitle'))}</h2>
      <button type="button" class="text-btn" id="clearHistory">${escapeHtml(l10n('commandCatalog.bands.recentClear'))}</button>
    </div>
    <p class="band-hint">${escapeHtml(l10n('commandCatalog.bands.recentHint'))}</p>
    <div class="history-chips" id="historyChips"></div>
    <button type="button" class="text-btn history-more" id="historyMore" hidden></button>
  </section>

  <main id="catalog-main" class="catalog">
    ${sectionsHtml}
  </main>
  <div class="no-results" id="noResults" hidden>
    <span class="codicon codicon-info no-results-icon" aria-hidden="true"></span>
    <p>${escapeHtml(l10n('commandCatalog.noResults.message'))}</p>
    <button type="button" class="text-btn" id="resetFromEmpty">${escapeHtml(l10n('commandCatalog.noResults.reset'))}</button>
  </div>
  ${buildKeyboardShortcutsOverlay([
    { key: '/', label: l10n('commandCatalog.shortcuts.focusSearch') },
    { key: '↓ / ↑', label: l10n('commandCatalog.shortcuts.navRows') },
    { key: 'Home / End', label: l10n('commandCatalog.shortcuts.homeEnd') },
    { key: 'Enter', label: l10n('commandCatalog.shortcuts.enterRun') },
    { key: 'Esc', label: l10n('commandCatalog.shortcuts.escClear') },
    { key: '?', label: l10n('commandCatalog.shortcuts.showOverlay') },
  ])}
  <script nonce="${nonce}">
    window.__COMMAND_CATALOG_I18N__ = ${commandCatalogScriptI18nJson()};
    window.__INITIAL_HISTORY__ = ${JSON.stringify(history)};
    window.__INITIAL_CATALOG_SEARCH_RECENT__ = ${JSON.stringify(catalogSearchRecent)};
    window.__RECENT_VISIBLE_DEFAULT__ = ${RECENT_VISIBLE_DEFAULT};
    window.__FREQUENT_TILE_LIMIT__ = ${FREQUENT_TILE_LIMIT};
    ${getScript()}
    ${getKeyboardShortcutsScript()}
  </script>
</body>
</html>`;
}

function buildSectionsHtml(
  grouped: Map<CatalogCategory, CatalogEntry[]>,
): string {
  const sections: string[] = [];

  for (const [category, catEntries] of grouped) {
    const slug = categorySlug(category);
    const rows = catEntries.map((e) => buildEntryHtml(e)).join('\n');
    // No surrounding card border (§14.6). The sticky header below provides the
    // grouping signal; rows breathe with margin instead of being boxed.
    sections.push(`
      <section class="category" id="${slug}" data-category="${escapeAttr(category)}">
        <button type="button" class="category-header" aria-expanded="true" aria-controls="${slug}-body">
          <span class="collapse-icon codicon codicon-chevron-down" aria-hidden="true"></span>
          <span class="category-label">${escapeHtml(category)}</span>
          <span
            class="category-count"
            data-jump-to="${slug}"
            title="${escapeAttr(l10n('commandCatalog.categoryJumpTitle', { category }))}"
          >${catEntries.length}</span>
        </button>
        <div class="category-body" id="${slug}-body" role="list">
          ${rows}
        </div>
      </section>`);
  }

  return sections.join('\n');
}

function buildEntryHtml(entry: CatalogEntry): string {
  const internalClass = entry.internal ? ' internal' : '';
  const internalBadge = entry.internal
    ? `<span class="badge internal-badge" title="${escapeAttr(l10n('commandCatalog.entry.internalBadgeTitle'))}">${escapeHtml(l10n('commandCatalog.entry.internalBadge'))}</span>`
    : '';

  // Tooltip carries the command id so the user can still see it without making
  // every row carry a permanent monospace third line. Description is also
  // included for narrow widths where it would otherwise truncate.
  const tooltip = `${entry.title}\n${entry.description}\n${entry.command}`;

  return `
    <div
      class="entry${internalClass}"
      data-command="${escapeAttr(entry.command)}"
      data-search="${escapeAttr(buildCatalogSearchBlob(entry))}"
      tabindex="0"
      role="button"
      aria-label="${escapeAttr(entry.title + '. ' + entry.description)}"
      title="${escapeAttr(tooltip)}"
    >
      <span
        class="entry-icon codicon codicon-${escapeAttr(entry.icon)}"
        aria-hidden="true"
      ></span>
      <div class="entry-text">
        <div class="entry-title-row">
          <span class="entry-title">${escapeHtml(entry.title)}</span>
          ${internalBadge}
        </div>
        <span class="entry-desc">${escapeHtml(entry.description)}</span>
      </div>
      <button
        type="button"
        class="entry-copy"
        data-copy="${escapeAttr(entry.command)}"
        title="${escapeAttr(l10n('commandCatalog.entry.copyTitle', { id: entry.command }))}"
        aria-label="${escapeAttr(l10n('commandCatalog.entry.copyAria'))}"
        tabindex="-1"
      >
        <span class="codicon codicon-copy" aria-hidden="true"></span>
      </button>
    </div>`;
}

function categorySlug(category: string): string {
  return (
    'cat-' +
    category
      .toLowerCase()
      .replaceAll(/[^a-z0-9]+/g, '-')
      .replaceAll(/^-|-$/g, '')
  );
}

function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function escapeAttr(text: string): string {
  return escapeHtml(text).replaceAll('"', '&quot;');
}

function getNonce(): string {
  const chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from({ length: 32 }, () =>
    chars[Math.floor(Math.random() * chars.length)],
  ).join('');
}

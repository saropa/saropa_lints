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
import { getPillButtonStyles } from '../vibrancy/views/pill-button-styles';
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';

/** Cap on Recent chips visible by default before "+N more" overflow (§8.10). */
const RECENT_VISIBLE_DEFAULT = 6;

/** Cap on Frequent tiles rendered (§14.7 — top-of-page primary actions). */
const FREQUENT_TILE_LIMIT = 6;

export function buildCommandCatalogHtml(
  webview: vscode.Webview,
  extensionUri: vscode.Uri,
  history: CatalogHistoryRecord[],
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
  <title>Saropa Command Catalog</title>
  <style nonce="${nonce}">
    ${getStyles()}
    ${getKeyboardShortcutsStyles()}
  </style>
</head>
<body>
  <a href="#catalog-main" class="skip-link">Skip to command catalog</a>
  <div id="announcer" role="status" aria-live="polite" aria-atomic="true"></div>
  <header class="hero">
    <div class="hero-inner">
      <h1 class="hero-title">Saropa Command Catalog</h1>
      <p class="status-line" id="statusLine">
        <span data-stat="public"><strong>${publicCount}</strong> commands</span>
        <span class="status-sep">·</span>
        <span data-stat="categories"><strong>${categoryCount}</strong> categories</span>
        <span class="status-sep">·</span>
        <span data-stat="history" id="statHistory">
          <strong>${historyCount}</strong> recent
        </span>
        <span class="status-sep">·</span>
        <span data-stat="internal" class="status-dim" id="statInternal">
          ${internalCount} context-menu only (hidden)
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
            placeholder="Search title, description, or command id…"
            autocomplete="off"
            spellcheck="false"
            aria-label="Search commands"
          />
          <button
            type="button"
            id="searchClear"
            class="search-clear"
            aria-label="Clear search"
            hidden
          >
            <span class="codicon codicon-close" aria-hidden="true"></span>
          </button>
          <span class="search-count" id="searchCount" aria-live="polite"></span>
          <!-- §8.5.2 — recent-searches popover. Stored in sessionStorage;
               cross-session persistence is tracked in
               plan/UX_GUIDELINES_REMAINING.md. -->
          <div id="catalog-recent" class="catalog-recent" hidden>
            <div class="catalog-recent-head">
              <span class="catalog-recent-title">Recent searches</span>
              <button type="button" id="catalog-recent-clear"
                class="catalog-recent-clear"
                title="Clear all recent searches">Clear</button>
            </div>
            <ul id="catalog-recent-list" class="catalog-recent-list"
              role="listbox" aria-label="Recent searches"></ul>
          </div>
        </div>
        <div class="toolbar-controls">
          <label class="checkbox-control">
            <input type="checkbox" id="showInternal" />
            <span>Show context-menu commands</span>
          </label>
          <button type="button" class="text-btn" id="toggleAll" aria-pressed="false">
            Collapse all
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
    Matches each command's <strong>title</strong>, <strong>description</strong>, and <strong>id</strong>
    (id tokens are spaced too — type <kbd>run analysis</kbd> without dots).
  </p>

  <div
    class="filter-chip-strip"
    id="filterChips"
    role="region"
    aria-label="Active filters"
    hidden
  >
    <span class="filter-chip-label">Active filters:</span>
    <span id="filterChipsBody"></span>
    <button type="button" class="text-btn" id="clearFilters">Clear all</button>
  </div>

  <section class="band band-frequent" id="frequentSection" hidden>
    <div class="band-header">
      <h2 class="section-title">Frequent</h2>
    </div>
    <p class="band-hint">Most-used across your sessions</p>
    <div class="frequent-grid" id="frequentGrid"></div>
  </section>

  <section class="band band-recent" id="historySection" ${historyCount === 0 ? 'hidden' : ''}>
    <div class="band-header">
      <h2 class="section-title">Recent</h2>
      <button type="button" class="text-btn" id="clearHistory">Clear</button>
    </div>
    <p class="band-hint">Click to run again · Newest first</p>
    <div class="history-chips" id="historyChips"></div>
    <button type="button" class="text-btn history-more" id="historyMore" hidden></button>
  </section>

  <main id="catalog-main" class="catalog">
    ${sectionsHtml}
  </main>
  <div class="no-results" id="noResults" hidden>
    <span class="codicon codicon-info no-results-icon" aria-hidden="true"></span>
    <p>No commands match your search.</p>
    <button type="button" class="text-btn" id="resetFromEmpty">Reset filters</button>
  </div>
  ${buildKeyboardShortcutsOverlay([
    { key: '/', label: 'Focus the search field' },
    { key: '↓ / ↑', label: 'Navigate visible command rows' },
    { key: 'Home / End', label: 'Jump to the first or last visible row' },
    { key: 'Enter', label: 'Run the focused command' },
    { key: 'Esc', label: 'Clear search and reset filters' },
    { key: '?', label: 'Show this shortcut overlay' },
  ])}
  <script nonce="${nonce}">
    window.__INITIAL_HISTORY__ = ${JSON.stringify(history)};
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
            title="Jump to ${escapeAttr(category)}"
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
    ? '<span class="badge internal-badge" title="Triggered from context menus only">menu</span>'
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
        title="Copy command id (${escapeAttr(entry.command)})"
        aria-label="Copy command id"
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

function getStyles(): string {
  return `
    ${getPillButtonStyles()}

    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      line-height: 1.55;
      min-height: 100vh;
    }

    /* ── Header (§4.1) ─────────────────────────────────────────────────── */

    /* Hero panel matches the Findings dashboard (the gold standard): a contained,
     * rounded, bordered surface with a focus-tinted border and a soft radial gradient,
     * mounted with a short fade-in. Was a full-bleed gradient band; converted to a
     * centered panel so the catalog reads with the same hero visual as the rest of
     * the editor dashboards (§4.1 + §14.6 zoning). */
    .hero {
      position: relative;
      max-width: 880px;
      margin: 18px auto 14px;
      padding: 18px 20px;
      border: 1px solid color-mix(in srgb, var(--vscode-focusBorder) 35%, var(--vscode-widget-border));
      border-radius: 12px;
      background:
        radial-gradient(900px 220px at 0% 0%,
          color-mix(in srgb, var(--vscode-textLink-foreground) 14%, transparent),
          transparent 60%),
        var(--vscode-editorWidget-background);
      animation: hero-in 360ms ease-out;
    }

    /* .hero-inner is now a transparent flow container — the .hero panel itself
     * carries the framing. Kept so existing markup ("hero-inner" wrapper div in the
     * page template) doesn't have to be edited and so future content (e.g. a gauge
     * cell) can be added to a 2-column grid here without touching .hero. */
    .hero-inner {
      display: block;
    }

    .hero-title {
      font-size: 1.55em;
      font-weight: 600;
      letter-spacing: 0.2px;
      margin: 0 0 4px;
    }

    @keyframes hero-in {
      from { opacity: 0; transform: translateY(-4px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @media (prefers-reduced-motion: reduce) {
      .hero { animation: none; }
    }

    .status-line {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      font-size: 0.88em;
      color: var(--vscode-descriptionForeground);
    }

    .status-line strong {
      font-weight: 600;
      color: var(--vscode-foreground);
    }

    .status-line .status-sep {
      opacity: 0.5;
    }

    .status-line .status-dim {
      opacity: 0.78;
    }

    body.show-internal .status-line #statInternal {
      opacity: 1;
    }

    /* ── Toolbar band (§4.3) ───────────────────────────────────────────── */

    .toolbar-wrap {
      position: sticky;
      top: 0;
      z-index: 5;
      background: var(--vscode-editor-background);
      border-bottom: 1px solid color-mix(in srgb, var(--vscode-widget-border) 60%, transparent);
      padding: 12px 20px 8px;
    }

    .toolbar-inner {
      max-width: 880px;
      margin: 0 auto;
    }

    .toolbar-band {
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 8px 12px;
      background: var(--vscode-editorWidget-background, var(--vscode-sideBar-background));
      border: 1px solid var(--vscode-widget-border);
      border-radius: 8px;
    }

    .search-row {
      display: flex;
      align-items: center;
      gap: 8px;
      background: var(--vscode-input-background);
      border: 1px solid var(--vscode-input-border, transparent);
      border-radius: 6px;
      padding: 6px 10px;
    }

    .search-row:focus-within {
      border-color: var(--vscode-focusBorder);
    }

    .search-icon {
      opacity: 0.7;
      flex-shrink: 0;
    }

    .search-input {
      flex: 1;
      min-width: 0;
      border: none;
      outline: none;
      background: transparent;
      color: var(--vscode-input-foreground);
      font: inherit;
    }

    .search-input::placeholder {
      color: var(--vscode-input-placeholderForeground);
    }

    /* Inline (×) clear control surfaces only when the field has content
     * (§4.3 "Inline clear control when non-empty"). */
    .search-clear {
      flex-shrink: 0;
      width: 20px;
      height: 20px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: none;
      border-radius: 50%;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
    }

    .search-clear:hover {
      background: var(--vscode-toolbar-hoverBackground);
      color: var(--vscode-foreground);
    }

    .search-clear .codicon {
      font-size: 13px;
    }

    .search-count {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      white-space: nowrap;
    }

    .toolbar-controls {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
    }

    .checkbox-control {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.86em;
      color: var(--vscode-foreground);
      cursor: pointer;
      user-select: none;
    }

    .checkbox-control input { cursor: pointer; }

    .search-hint {
      font-size: 0.82em;
      color: var(--vscode-descriptionForeground);
      margin-top: 8px;
      line-height: 1.45;
    }

    /* §4.3 — single-line variant rendered BELOW the toolbar band so the
       toolbar reads as a pure control surface. Centered to mirror the
       toolbar's max-width and indented to read as supporting copy. */
    .search-hint-below {
      max-width: 880px;
      margin: 6px auto 0;
      padding: 0 14px;
      font-size: 0.78em;
    }

    .search-hint kbd {
      font-family: var(--vscode-editor-font-family);
      font-size: 0.92em;
      padding: 1px 5px;
      border-radius: 4px;
      border: 1px solid var(--vscode-widget-border);
      background: var(--vscode-editor-inactiveSelectionBackground);
    }

    .search-hint strong {
      font-weight: 600;
      color: var(--vscode-foreground);
    }

    /* ── Active filter chip strip (§8.5 / §14.10) ──────────────────────── */

    .filter-chip-strip {
      max-width: 880px;
      margin: 8px auto 0;
      padding: 8px 14px;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      border: 1px dashed var(--vscode-widget-border);
      border-radius: 6px;
      background: color-mix(in srgb, var(--vscode-editor-inactiveSelectionBackground) 60%, transparent);
      font-size: 0.84em;
    }

    .filter-chip-label {
      color: var(--vscode-descriptionForeground);
      font-weight: 600;
    }

    .filter-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 2px 6px 2px 10px;
      border-radius: 999px;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
    }

    .filter-chip-remove {
      width: 18px;
      height: 18px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      color: inherit;
      opacity: 0.85;
    }

    .filter-chip-remove:hover {
      background: color-mix(in srgb, var(--vscode-foreground) 15%, transparent);
      opacity: 1;
    }

    .filter-chip-remove .codicon {
      font-size: 11px;
    }

    /* ── Bands: Frequent + Recent ──────────────────────────────────────── */

    .band {
      max-width: 880px;
      margin: 16px auto 0;
      padding: 0 20px;
    }

    .band-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .section-title {
      font-size: 0.78em;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--vscode-descriptionForeground);
    }

    .band-hint {
      font-size: 0.82em;
      color: var(--vscode-descriptionForeground);
      margin: 4px 0 10px;
    }

    .text-btn {
      font: inherit;
      font-size: 0.85em;
      color: var(--vscode-textLink-foreground);
      background: none;
      border: none;
      cursor: pointer;
      padding: 2px 6px;
      border-radius: 4px;
    }

    .text-btn:hover {
      background: var(--vscode-toolbar-hoverBackground);
    }

    .text-btn:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    /* Frequent: larger pinned tiles with primary-feeling weight (§14.7 tier-1). */
    .frequent-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 10px;
    }

    /* §8.10 — frequent tiles previously used a 12% --vscode-button-background
       tint that visually outweighed the actual tier-1/tier-2 toolbar buttons.
       The action-button color vocabulary belongs to actions, not to content
       cards; tiles drop to the editor's inactive-selection tone so the user's
       eye lands on the search input and toolbar buttons first. The hover
       state still lifts the tile via a subtle button-color brush so the
       affordance reads as interactive without competing for emphasis. */
    .frequent-tile {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border-radius: 8px;
      border: 1px solid var(--vscode-widget-border);
      background: var(--vscode-editor-inactiveSelectionBackground);
      cursor: pointer;
      text-align: left;
      color: inherit;
      font: inherit;
    }

    .frequent-tile:hover {
      background: color-mix(in srgb, var(--vscode-button-background) 8%, var(--vscode-editor-inactiveSelectionBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 50%, var(--vscode-widget-border));
    }

    .frequent-tile:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .frequent-tile .codicon {
      font-size: 18px;
      opacity: 0.95;
      flex-shrink: 0;
    }

    .frequent-tile .frequent-title {
      font-weight: 600;
      font-size: 0.95em;
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .frequent-tile .frequent-count {
      font-size: 0.74em;
      color: var(--vscode-descriptionForeground);
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 2px 7px;
      border-radius: 999px;
      flex-shrink: 0;
    }

    /* Recent strip (existing pill chips, capped). */
    .history-chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .history-chip { /* layout-only; visual tokens come from .saropa-pill-button */ }
    .history-chip.history-overflow { display: none; }
    .band-recent.show-all .history-chip.history-overflow { display: inline-flex; }

    .history-more {
      margin-top: 6px;
    }

    /* ── Catalog (flat list with sticky section headers) ─────────────── */

    .catalog {
      max-width: 880px;
      margin: 0 auto;
      padding: 12px 20px 48px;
    }

    .category {
      margin-bottom: 14px;
      /* No surrounding card border (§14.6). Sticky header below carries the
       * grouping signal; relying on borders for every section flattens the
       * page into uniform tiles. */
    }

    .category-header {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 8px;
      cursor: pointer;
      user-select: none;
      font: inherit;
      color: var(--vscode-descriptionForeground);
      background: var(--vscode-editor-background);
      border: none;
      border-bottom: 1px solid color-mix(in srgb, var(--vscode-widget-border) 70%, transparent);
      text-align: left;
      /* Sticky to the bottom of the toolbar band so the user always knows
       * which category they are scrolling through. */
      position: sticky;
      top: 0;
      z-index: 2;
      /* Microlabel typography per §8.1: small, uppercase, letter-spaced —
       * structural depth, not a competing headline. */
      font-size: 0.72em;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
    }

    /* Flash overlay — color is set in a static rule (var() resolves reliably
       outside keyframes) and the keyframe animates only opacity, so the
       flash still appears when var() in @keyframes fails to resolve in the
       VS Code webview (the same Chromium quirk that left chart bars all at
       100% width). The pseudo sits over the header content; pointer-events:
       none keeps clicks flowing through to the underlying button. */
    .category-header::after {
      content: '';
      position: absolute;
      inset: 0;
      background: color-mix(in srgb, var(--vscode-focusBorder) 35%, transparent);
      opacity: 0;
      pointer-events: none;
    }

    .category.flash .category-header::after {
      animation: badge-flash 0.9s ease-out;
    }

    @keyframes badge-flash {
      from { opacity: 1; }
      to   { opacity: 0; }
    }

    .collapse-icon {
      transition: transform 0.18s ease;
      opacity: 0.85;
      font-size: 12px;
    }

    .category.collapsed .collapse-icon {
      transform: rotate(-90deg);
    }

    .category.collapsed .category-body {
      display: none;
    }

    .category-label { flex: 1; }

    .category-count {
      font-size: 0.95em;
      font-weight: 600;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 1px 8px;
      border-radius: 999px;
      cursor: pointer;
      letter-spacing: 0;
      /* Click target — smooth-scrolls the category into view (§14.8 makes
       * count badges first-class actions, not inert decoration). */
    }

    /* §14.1 — count badges had cursor:pointer but no visible focus/hover
       outline, so they read as semi-static decoration at first glance.
       The outline announces "this is a click target" before the user
       commits, matching the chrome's affordance-discovery pattern. */
    .category-count:hover {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }
    .category-count:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .category-body { padding: 4px 0 8px; }

    /* ── Slim entry rows (§3 compact typography, §14.6 weight depth) ─── */

    .entry {
      position: relative;
      display: grid;
      grid-template-columns: 22px 1fr auto;
      align-items: start;
      gap: 10px;
      padding: 6px 8px;
      border-radius: 6px;
      cursor: pointer;
      border: 1px solid transparent;
    }

    .entry:hover, .entry:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
      border-color: color-mix(in srgb, var(--vscode-widget-border) 60%, transparent);
    }

    .entry:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: -1px;
    }

    .entry.kbd-active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
    }

    .entry.internal { display: none; }

    body.show-internal .entry.internal {
      display: grid;
      opacity: 0.7;
    }

    /* Flat icon — no boxed wrap (§8.7). The boxed 36×36 icon competed
     * with the title for the eye and made every row read like a button-
     * within-a-button. A bare codicon at title size keeps the title as
     * the row's primary identifier. */
    .entry-icon {
      font-size: 16px;
      line-height: 22px;
      opacity: 0.85;
      color: var(--vscode-foreground);
    }

    .entry-text {
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }

    .entry-title-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px 8px;
    }

    .entry-title {
      font-weight: 600;
      font-size: 0.95em;
    }

    .entry-desc {
      color: var(--vscode-descriptionForeground);
      font-size: 0.82em;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    /* §8.5.2 — search hit highlights inside title and description text.
       Uses the host find-match token so the highlight is visible across
       all four default themes; the foreground inherits so contrast against
       the row text stays bound to the host theme. */
    .entry mark.search-hit {
      background: var(--vscode-editor-findMatchHighlightBackground,
          var(--vscode-editor-selectionBackground));
      color: inherit;
      padding: 0 1px;
      border-radius: 2px;
    }

    /* §8.5.2 — recent-searches popover anchored under the catalog search field. */
    .search-row { position: relative; }
    .catalog-recent {
      position: absolute;
      top: calc(100% + 4px);
      inset-inline-start: 0;
      inset-inline-end: 0;
      z-index: 50;
      max-height: 220px;
      overflow-y: auto;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-widget-border);
      border-radius: 4px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    }
    .catalog-recent-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 4px 8px;
      border-bottom: 1px solid var(--vscode-widget-border);
    }
    .catalog-recent-title {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .catalog-recent-clear {
      background: none;
      border: 0;
      padding: 0;
      cursor: pointer;
      color: var(--vscode-textLink-foreground);
      font-size: 0.85em;
    }
    .catalog-recent-clear:hover { text-decoration: underline; }
    .catalog-recent-list {
      list-style: none;
      margin: 0;
      padding: 4px 0;
    }
    .catalog-recent-list li {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 0;
    }
    .catalog-recent-list .recent-pick {
      flex: 1;
      text-align: start;
      background: none;
      border: 0;
      padding: 4px 10px;
      color: var(--vscode-foreground);
      cursor: pointer;
      font: inherit;
    }
    .catalog-recent-list .recent-pick:hover,
    .catalog-recent-list .recent-pick:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
    }
    .catalog-recent-list .recent-remove {
      width: 22px;
      height: 22px;
      margin-inline-end: 6px;
      border: 0;
      background: transparent;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      opacity: 0.6;
      border-radius: 2px;
      font-size: 14px;
    }
    .catalog-recent-list .recent-remove:hover,
    .catalog-recent-list .recent-remove:focus-visible {
      opacity: 1;
      background: var(--vscode-toolbar-hoverBackground, var(--vscode-list-hoverBackground));
    }

    /* Copy-id button only fades in on row hover/focus (§8.14). The id
     * itself is not in the row body anymore — that was the single biggest
     * source of visual noise across 156 rows. The full id remains in the
     * button's title attribute and the row's tooltip. */
    .entry-copy {
      width: 24px;
      height: 24px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: 1px solid transparent;
      border-radius: 4px;
      cursor: pointer;
      color: var(--vscode-descriptionForeground);
      opacity: 0;
      transition: opacity 0.12s ease;
    }

    .entry:hover .entry-copy,
    .entry:focus-within .entry-copy,
    .entry-copy:focus-visible,
    .entry.kbd-active .entry-copy {
      opacity: 1;
    }

    .entry-copy:hover {
      background: var(--vscode-toolbar-hoverBackground);
      color: var(--vscode-foreground);
    }

    .entry-copy.copied {
      color: var(--vscode-testing-iconPassed, var(--vscode-charts-green, var(--vscode-foreground)));
      opacity: 1;
    }

    .entry-copy .codicon {
      font-size: 13px;
    }

    .badge {
      font-size: 0.7em;
      padding: 1px 6px;
      border-radius: 999px;
      white-space: nowrap;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      font-weight: 600;
    }

    .internal-badge {
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      opacity: 0.85;
    }

    .entry.search-hidden { display: none !important; }
    .category.search-hidden { display: none !important; }

    .no-results {
      text-align: center;
      padding: 48px 24px;
      color: var(--vscode-descriptionForeground);
    }

    .no-results-icon {
      font-size: 2.2em;
      opacity: 0.45;
      display: block;
      margin-bottom: 12px;
    }

    .no-results p { font-size: 1.05em; margin-bottom: 12px; }

    /* ── Responsive (narrow editor columns / split panes) ──────────────── */

    @media (max-width: 720px) {
      .hero { padding: 14px 12px; }
      .toolbar-wrap { padding: 10px 12px 6px; }
      .hero-inner,
      .toolbar-inner,
      .filter-chip-strip,
      .band,
      .catalog {
        max-width: none;
      }
      .band,
      .catalog {
        padding-inline-start: 12px;
        padding-inline-end: 12px;
      }
      .hero-title { font-size: 1.22em; }
      .frequent-grid {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 420px) {
      .entry {
        grid-template-columns: 22px 1fr;
      }
      .entry-copy {
        grid-column: 2;
        justify-self: end;
        margin-top: 4px;
      }
      .history-chip {
        max-width: 100%;
        width: 100%;
        justify-content: flex-start;
      }
      .history-chip .saropa-pill-button-title {
        white-space: normal;
        text-overflow: unset;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      .collapse-icon,
      .entry-copy { transition: none; }
      .category.flash .category-header::after { animation: none; }
    }
  `;
}

function getScript(): string {
  return String.raw`
    (function () {
      const vscode = acquireVsCodeApi();
      const RECENT_VISIBLE = window.__RECENT_VISIBLE_DEFAULT__ || 6;
      const FREQUENT_LIMIT = window.__FREQUENT_TILE_LIMIT__ || 6;

      const searchInput = document.getElementById('search');
      const searchClearBtn = document.getElementById('searchClear');
      const searchCountEl = document.getElementById('searchCount');
      const noResultsEl = document.getElementById('noResults');
      const resetFromEmptyBtn = document.getElementById('resetFromEmpty');
      const catalogEl = document.getElementById('catalog-main');
      const internalCheckbox = document.getElementById('showInternal');
      const toggleAllBtn = document.getElementById('toggleAll');
      const filterChipStrip = document.getElementById('filterChips');
      const filterChipsBody = document.getElementById('filterChipsBody');
      const clearFiltersBtn = document.getElementById('clearFilters');

      const historySection = document.getElementById('historySection');
      const historyChips = document.getElementById('historyChips');
      const clearHistoryBtn = document.getElementById('clearHistory');
      const historyMoreBtn = document.getElementById('historyMore');

      const frequentSection = document.getElementById('frequentSection');
      const frequentGrid = document.getElementById('frequentGrid');
      const statHistory = document.getElementById('statHistory');

      function safeIcon(name) {
        if (typeof name !== 'string' || !/^[a-z0-9-]+$/.test(name)) {
          return 'symbol-misc';
        }
        return name;
      }

      function escText(text) {
        const el = document.createElement('span');
        el.textContent = String(text);
        return el.innerHTML;
      }

      // ── Recent (capped) ────────────────────────────────────────────

      function renderRecent(items) {
        if (!historyChips || !historySection) return;
        historyChips.textContent = '';
        if (!items || items.length === 0) {
          historySection.hidden = true;
          if (historyMoreBtn) historyMoreBtn.hidden = true;
          historySection.classList.remove('show-all');
          return;
        }
        historySection.hidden = false;
        items.forEach((item, idx) => {
          const chip = document.createElement('button');
          chip.type = 'button';
          chip.className = 'saropa-pill-button history-chip';
          if (idx >= RECENT_VISIBLE) chip.classList.add('history-overflow');
          chip.dataset.command = item.command;

          const wrap = document.createElement('span');
          wrap.className = 'saropa-pill-button-icon';
          const ic = document.createElement('span');
          ic.className = 'codicon codicon-' + safeIcon(item.icon);
          wrap.appendChild(ic);

          const title = document.createElement('span');
          title.className = 'saropa-pill-button-title';
          title.textContent = item.title;

          chip.appendChild(wrap);
          chip.appendChild(title);
          chip.addEventListener('click', function () {
            vscode.postMessage({ type: 'executeCommand', command: item.command });
          });
          historyChips.appendChild(chip);
        });

        // "+N more" toggle: avoids letting a 25-chip wall consume the same
        // visual budget as the rest of the page.
        const overflow = items.length - RECENT_VISIBLE;
        if (historyMoreBtn) {
          if (overflow > 0) {
            historyMoreBtn.hidden = false;
            historyMoreBtn.textContent = '+' + overflow + ' more';
          } else {
            historyMoreBtn.hidden = true;
            historySection.classList.remove('show-all');
          }
        }
      }

      if (historyMoreBtn) {
        historyMoreBtn.addEventListener('click', function () {
          const expanded = historySection.classList.toggle('show-all');
          // Recompute label so a second click can collapse the strip back.
          const all = historyChips.querySelectorAll('.history-chip').length;
          const overflow = all - RECENT_VISIBLE;
          historyMoreBtn.textContent = expanded
            ? 'Show less'
            : '+' + Math.max(0, overflow) + ' more';
        });
      }

      // ── Frequent ───────────────────────────────────────────────────

      function renderFrequent(items) {
        if (!frequentGrid || !frequentSection) return;
        frequentGrid.textContent = '';
        // Frequent only earns a band when it has signal: at least one command
        // run more than once, OR three+ different commands run. This avoids
        // the §14.3 "placeholder-as-content" trap where an empty top band
        // pushes real content below the fold.
        const hasFrequencySignal =
          items.some((it) => (it.count || 1) >= 2) || items.length >= 3;
        if (!hasFrequencySignal) {
          frequentSection.hidden = true;
          return;
        }

        const ranked = [...items]
          .sort((a, b) => (b.count || 1) - (a.count || 1) || (b.at || 0) - (a.at || 0))
          .slice(0, FREQUENT_LIMIT);

        if (ranked.length === 0) {
          frequentSection.hidden = true;
          return;
        }
        frequentSection.hidden = false;

        for (const item of ranked) {
          const tile = document.createElement('button');
          tile.type = 'button';
          tile.className = 'frequent-tile';
          tile.dataset.command = item.command;

          const ic = document.createElement('span');
          ic.className = 'codicon codicon-' + safeIcon(item.icon);
          tile.appendChild(ic);

          const title = document.createElement('span');
          title.className = 'frequent-title';
          title.textContent = item.title;
          tile.appendChild(title);

          const count = document.createElement('span');
          count.className = 'frequent-count';
          const c = item.count || 1;
          count.textContent = c + (c === 1 ? ' run' : ' runs');
          tile.appendChild(count);

          tile.addEventListener('click', function () {
            vscode.postMessage({
              type: 'executeCommand',
              command: item.command,
            });
          });
          frequentGrid.appendChild(tile);
        }
      }

      function applyHistory(items) {
        renderRecent(items);
        renderFrequent(items);
        if (statHistory) {
          statHistory.innerHTML =
            '<strong>' + (items ? items.length : 0) + '</strong> recent';
        }
      }

      applyHistory(window.__INITIAL_HISTORY__ || []);

      window.addEventListener('message', function (event) {
        const msg = event.data;
        if (msg && msg.type === 'history') {
          applyHistory(msg.items || []);
        }
      });

      if (clearHistoryBtn) {
        clearHistoryBtn.addEventListener('click', function () {
          vscode.postMessage({ type: 'clearHistory' });
        });
      }

      // ── Catalog row interactions ──────────────────────────────────

      catalogEl.addEventListener('click', function (e) {
        // Copy-id has its own handler below; do not also execute the command.
        if (e.target && e.target.closest && e.target.closest('.entry-copy')) {
          return;
        }
        // Category-count badge click → smooth-scroll to that section. Doubles
        // the badge as a quick-jump (§14.8 makes count badges actionable).
        const jumpEl =
          e.target && e.target.closest && e.target.closest('[data-jump-to]');
        if (jumpEl) {
          e.stopPropagation();
          const slug = jumpEl.getAttribute('data-jump-to');
          const target = document.getElementById(slug);
          if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            target.classList.remove('flash');
            // Force reflow so the animation restarts on repeated clicks.
            void target.offsetWidth;
            target.classList.add('flash');
          }
          return;
        }
        const entry = e.target.closest('.entry');
        if (!entry) return;
        vscode.postMessage({
          type: 'executeCommand',
          command: entry.dataset.command,
        });
      });

      // Per-row "copy command id" affordance — the id no longer lives in the
      // row body, so this is the only way to extract it without using the
      // tooltip. Uses the webview's clipboard, gated behind a click gesture
      // so VS Code's permission model is satisfied.
      catalogEl.addEventListener('click', function (e) {
        const btn =
          e.target && e.target.closest && e.target.closest('.entry-copy');
        if (!btn) return;
        e.stopPropagation();
        const cmd = btn.dataset.copy || '';
        if (!cmd) return;
        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(cmd);
          }
        } catch (_) { /* no-op: clipboard write may be blocked */ }
        btn.classList.add('copied');
        setTimeout(function () { btn.classList.remove('copied'); }, 900);
      });

      // ── Keyboard nav (§8.13) ──────────────────────────────────────

      function visibleEntries() {
        return Array.prototype.filter.call(
          document.querySelectorAll('.entry'),
          function (el) {
            return !el.classList.contains('search-hidden') &&
              (!el.classList.contains('internal') ||
                document.body.classList.contains('show-internal'));
          },
        );
      }

      function focusEntry(idx) {
        const entries = visibleEntries();
        if (entries.length === 0) return;
        const next = Math.max(0, Math.min(entries.length - 1, idx));
        for (const e of entries) e.classList.remove('kbd-active');
        entries[next].classList.add('kbd-active');
        entries[next].focus({ preventScroll: false });
      }

      function currentEntryIndex() {
        const entries = visibleEntries();
        const focused = document.activeElement && document.activeElement.classList &&
          document.activeElement.classList.contains('entry')
          ? document.activeElement
          : null;
        if (!focused) return -1;
        return entries.indexOf(focused);
      }

      catalogEl.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          const entry = e.target.closest && e.target.closest('.entry');
          if (entry) {
            e.preventDefault();
            vscode.postMessage({
              type: 'executeCommand',
              command: entry.dataset.command,
            });
          }
          return;
        }
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp' ||
            e.key === 'Home' || e.key === 'End') {
          // Only act when focus is already on an entry — otherwise let Tab
          // do its normal job into the first row.
          const cur = currentEntryIndex();
          if (cur < 0 && e.key !== 'ArrowDown' && e.key !== 'Home') return;
          e.preventDefault();
          if (e.key === 'ArrowDown') focusEntry(cur < 0 ? 0 : cur + 1);
          else if (e.key === 'ArrowUp') focusEntry(cur - 1);
          else if (e.key === 'Home') focusEntry(0);
          else if (e.key === 'End') focusEntry(visibleEntries().length - 1);
        }
      });

      // ── Category header collapse / collapse-all toggle ────────────

      function setAllCollapsed(collapsed) {
        for (const section of document.querySelectorAll('.category')) {
          section.classList.toggle('collapsed', collapsed);
          const hdr = section.querySelector('.category-header');
          if (hdr) hdr.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
        }
        if (toggleAllBtn) {
          toggleAllBtn.setAttribute('aria-pressed', collapsed ? 'true' : 'false');
          toggleAllBtn.textContent = collapsed ? 'Expand all' : 'Collapse all';
        }
      }

      for (const header of document.querySelectorAll('.category-header')) {
        header.addEventListener('click', function (e) {
          // Count badge has its own jump handler — let the click bubble up
          // to the catalog listener instead of toggling the section.
          if (e.target && e.target.classList && e.target.classList.contains('category-count')) {
            return;
          }
          const section = header.parentElement;
          const collapsed = section.classList.toggle('collapsed');
          header.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
        });
      }

      if (toggleAllBtn) {
        toggleAllBtn.addEventListener('click', function () {
          const allCollapsed = Array.prototype.every.call(
            document.querySelectorAll('.category'),
            function (el) { return el.classList.contains('collapsed'); },
          );
          setAllCollapsed(!allCollapsed);
        });
      }

      // ── Filtering, search, chip strip ─────────────────────────────

      internalCheckbox.addEventListener('change', function () {
        document.body.classList.toggle('show-internal', internalCheckbox.checked);
        applySearch();
      });

      /* §8.5.2 — recent-searches storage and popover wiring for the catalog
         search input. Stored in sessionStorage; cross-session persistence is
         tracked in plan/UX_GUIDELINES_REMAINING.md. */
      var catalogRecentEl = document.getElementById('catalog-recent');
      var catalogRecentListEl = document.getElementById('catalog-recent-list');
      var catalogRecentClearEl = document.getElementById('catalog-recent-clear');
      var CAT_RECENT_KEY = 'saropa.commandCatalog.recentSearches';
      var CAT_RECENT_CAP = 10;
      var CAT_RECENT_DEBOUNCE_MS = 800;
      var catalogRecentTimer = null;

      function catRecentLoad() {
        try {
          var raw = sessionStorage.getItem(CAT_RECENT_KEY);
          if (!raw) return [];
          var p = JSON.parse(raw);
          return Array.isArray(p) ? p.filter(function (s) { return typeof s === 'string'; }) : [];
        } catch (e) { return []; }
      }
      function catRecentSave(list) {
        try { sessionStorage.setItem(CAT_RECENT_KEY, JSON.stringify(list)); } catch (e) { /* best-effort */ }
      }
      function catRecentRecord(q) {
        var t = (q || '').trim();
        if (!t) return;
        var existing = catRecentLoad().filter(function (s) { return s.toLowerCase() !== t.toLowerCase(); });
        existing.unshift(t);
        catRecentSave(existing.slice(0, CAT_RECENT_CAP));
      }
      function catRecentRemove(q) {
        catRecentSave(catRecentLoad().filter(function (s) { return s !== q; }));
        catRecentRender();
      }
      function catRecentClearAll() { catRecentSave([]); catRecentRender(); catRecentHide(); }
      function catEsc(s) {
        return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
          .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      }
      function catRecentRender() {
        if (!catalogRecentListEl) return;
        var list = catRecentLoad();
        if (list.length === 0) { catalogRecentListEl.innerHTML = ''; return; }
        catalogRecentListEl.innerHTML = list.map(function (q) {
          var s = catEsc(q);
          return '<li>' +
            '<button type="button" class="recent-pick" data-query="' + s + '">' + s + '</button>' +
            '<button type="button" class="recent-remove" data-query="' + s +
            '" aria-label="Remove ' + s + '" title="Remove">&times;</button>' +
            '</li>';
        }).join('');
      }
      function catRecentShow() {
        if (!catalogRecentEl) return;
        var list = catRecentLoad();
        if (list.length === 0) { catalogRecentEl.hidden = true; return; }
        catRecentRender();
        catalogRecentEl.hidden = false;
      }
      function catRecentHide() { if (catalogRecentEl) catalogRecentEl.hidden = true; }
      function catRecentMaybeShow() {
        if (document.activeElement === searchInput && !searchInput.value.trim()) catRecentShow();
        else catRecentHide();
      }

      searchInput.addEventListener('input', function () {
        applySearch();
        catRecentMaybeShow();
        if (catalogRecentTimer) clearTimeout(catalogRecentTimer);
        var snap = searchInput.value;
        catalogRecentTimer = setTimeout(function () {
          catalogRecentTimer = null;
          if (snap && searchInput.value === snap) catRecentRecord(snap);
        }, CAT_RECENT_DEBOUNCE_MS);
      });
      searchInput.addEventListener('focus', catRecentMaybeShow);
      searchInput.addEventListener('blur', function () { setTimeout(catRecentHide, 120); });
      searchInput.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' && searchInput.value.trim()) {
          catRecentRecord(searchInput.value);
          catRecentHide();
        } else if (e.key === 'Escape' && catalogRecentEl && !catalogRecentEl.hidden) {
          e.preventDefault();
          catRecentHide();
        }
      });
      if (catalogRecentListEl) {
        catalogRecentListEl.addEventListener('click', function (e) {
          var t = e.target;
          if (!t || !t.dataset || !t.dataset.query) return;
          var q = t.dataset.query;
          if (t.classList.contains('recent-pick')) {
            searchInput.value = q;
            applySearch();
            catRecentRecord(q);
            catRecentHide();
            searchInput.focus();
          } else if (t.classList.contains('recent-remove')) {
            e.stopPropagation();
            catRecentRemove(q);
            searchInput.focus();
          }
        });
      }
      if (catalogRecentClearEl) catalogRecentClearEl.addEventListener('click', catRecentClearAll);
      document.addEventListener('click', function (e) {
        if (!catalogRecentEl || catalogRecentEl.hidden) return;
        var row = searchInput.closest ? searchInput.closest('.search-row') : null;
        if (row && !row.contains(e.target)) catRecentHide();
      });

      searchInput.focus();

      /* §15.2 — page-level shortcuts. '/' refocuses the search from anywhere
         (the user clicks into a row, then '/' brings them back). 'Esc' on a
         focused, non-empty search clears the value; the keyboard-shortcut
         overlay's own Esc handler does not fire while it's hidden, so the
         two listeners do not collide. */
      document.addEventListener('keydown', function (e) {
        var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
        var inEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
        if (e.key === '/' && !inEditable) {
          e.preventDefault();
          searchInput.focus();
          searchInput.select && searchInput.select();
          return;
        }
        if (e.key === 'Escape' && e.target === searchInput && searchInput.value) {
          e.preventDefault();
          searchInput.value = '';
          applySearch();
        }
      });

      if (searchClearBtn) {
        searchClearBtn.addEventListener('click', function () {
          searchInput.value = '';
          searchInput.focus();
          applySearch();
        });
      }

      if (clearFiltersBtn) {
        clearFiltersBtn.addEventListener('click', function () {
          searchInput.value = '';
          internalCheckbox.checked = false;
          document.body.classList.remove('show-internal');
          applySearch();
          searchInput.focus();
        });
      }

      if (resetFromEmptyBtn) {
        resetFromEmptyBtn.addEventListener('click', function () {
          searchInput.value = '';
          internalCheckbox.checked = false;
          document.body.classList.remove('show-internal');
          applySearch();
          searchInput.focus();
        });
      }

      function renderFilterChips(query, showInternal) {
        if (!filterChipStrip || !filterChipsBody) return;
        filterChipsBody.textContent = '';

        const chips = [];
        if (query) chips.push({ kind: 'search', label: 'Search: "' + query + '"' });
        if (showInternal) chips.push({ kind: 'internal', label: 'Showing context-menu commands' });

        if (chips.length === 0) {
          filterChipStrip.hidden = true;
          return;
        }
        filterChipStrip.hidden = false;
        for (const chip of chips) {
          const el = document.createElement('span');
          el.className = 'filter-chip';
          el.innerHTML =
            escText(chip.label) +
            '<button type="button" class="filter-chip-remove" data-remove="' +
            chip.kind +
            '" aria-label="Remove filter ' + escText(chip.label) +
            '"><span class="codicon codicon-close" aria-hidden="true"></span></button>';
          filterChipsBody.appendChild(el);
        }
      }

      if (filterChipsBody) {
        filterChipsBody.addEventListener('click', function (e) {
          const btn = e.target && e.target.closest && e.target.closest('.filter-chip-remove');
          if (!btn) return;
          const kind = btn.getAttribute('data-remove');
          if (kind === 'search') {
            searchInput.value = '';
          } else if (kind === 'internal') {
            internalCheckbox.checked = false;
            document.body.classList.remove('show-internal');
          }
          applySearch();
        });
      }

      /* §8.5.2 — search-highlight helpers. The entry's title and description
         are the only text the user reads for matches; highlight token-by-token
         (the search blob is tokenized too) so multi-word queries reflect each
         hit. Wrapping happens in text nodes only — every other element stays
         intact. Stripped each pass before re-applying. */
      function clearCatalogHighlights() {
        const marks = document.querySelectorAll('.entry mark.search-hit');
        const parents = new Set();
        marks.forEach(m => {
          const parent = m.parentNode;
          parent.replaceChild(document.createTextNode(m.textContent), m);
          parents.add(parent);
        });
        parents.forEach(p => p.normalize());
      }

      function highlightCatalogEntry(entry, tokens) {
        const targets = entry.querySelectorAll('.entry-title, .entry-desc');
        targets.forEach(el => {
          tokens.forEach(tok => {
            if (!tok) return;
            const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
            const candidates = [];
            let n = walker.nextNode();
            while (n) {
              if (n.parentElement && n.parentElement.tagName === 'MARK') { n = walker.nextNode(); continue; }
              if (n.nodeValue.toLowerCase().indexOf(tok) !== -1) candidates.push(n);
              n = walker.nextNode();
            }
            candidates.forEach(node => wrapCatalogMatches(node, tok));
          });
        });
      }

      function wrapCatalogMatches(textNode, lowerTok) {
        const text = textNode.nodeValue;
        const lower = text.toLowerCase();
        const parent = textNode.parentNode;
        const tokLen = lowerTok.length;
        let lastIdx = 0;
        let idx = lower.indexOf(lowerTok);
        while (idx !== -1) {
          if (idx > lastIdx) {
            parent.insertBefore(document.createTextNode(text.substring(lastIdx, idx)), textNode);
          }
          const mark = document.createElement('mark');
          mark.className = 'search-hit';
          mark.textContent = text.substr(idx, tokLen);
          parent.insertBefore(mark, textNode);
          lastIdx = idx + tokLen;
          idx = lower.indexOf(lowerTok, lastIdx);
        }
        if (lastIdx < text.length) {
          parent.insertBefore(document.createTextNode(text.substring(lastIdx)), textNode);
        }
        parent.removeChild(textNode);
      }

      function applySearch() {
        const rawQuery = searchInput.value.toLowerCase().trim();
        const tokens = rawQuery ? rawQuery.split(/\s+/).filter(Boolean) : [];
        const query = tokens.join(' ');
        const showInternal = internalCheckbox.checked;
        let visibleCount = 0;

        clearCatalogHighlights();

        for (const section of document.querySelectorAll('.category')) {
          let sectionVisible = 0;

          for (const entry of section.querySelectorAll('.entry')) {
            const isInternal = entry.classList.contains('internal');
            const matchesSearch =
              !query || entry.dataset.search.includes(query);
            const visible = matchesSearch && (!isInternal || showInternal);

            entry.classList.toggle('search-hidden', !visible);
            if (visible) {
              sectionVisible++;
              if (tokens.length > 0) highlightCatalogEntry(entry, tokens);
            }
          }

          section.classList.toggle('search-hidden', sectionVisible === 0);

          if (query) {
            section.classList.remove('collapsed');
            const hdr = section.querySelector('.category-header');
            if (hdr) hdr.setAttribute('aria-expanded', 'true');
          }

          visibleCount += sectionVisible;
        }

        // Hide the catalog entirely (rather than show empty group headers)
        // when no entries match — see §14.2 to avoid two empty states.
        const empty = visibleCount === 0;
        noResultsEl.hidden = !empty;

        searchCountEl.textContent = query
          ? visibleCount + ' match' + (visibleCount === 1 ? '' : 'es')
          : '';

        if (searchClearBtn) searchClearBtn.hidden = !query;
        renderFilterChips(query, showInternal);
      }
    })();
  `;
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

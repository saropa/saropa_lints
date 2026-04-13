/**
 * HTML, CSS, and client script for the command catalog webview.
 */

import * as vscode from 'vscode';
import type { CatalogCategory, CatalogEntry } from './commandCatalogRegistry';
import { entriesByCategory } from './commandCatalogRegistry';
import { buildCatalogSearchBlob } from './commandCatalogSearch';
import type { CatalogHistoryRecord } from './commandCatalogHistory';

export function buildCommandCatalogHtml(
  webview: vscode.Webview,
  extensionUri: vscode.Uri,
  history: CatalogHistoryRecord[],
): string {
  const nonce = getNonce();
  const grouped = entriesByCategory();
  const sectionsHtml = buildSectionsHtml(grouped);
  const totalCount = Array.from(grouped.values()).reduce(
    (sum, list) => sum + list.length,
    0,
  );

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
  <title>Command Catalog</title>
  <style nonce="${nonce}">
    ${getStyles()}
  </style>
</head>
<body>
  <div class="hero">
    <div class="hero-inner">
      <h1 class="hero-title">Command Catalog</h1>
      <p class="hero-sub">${totalCount} commands · Search, browse, run</p>
      <div class="search-row">
        <span class="search-icon codicon codicon-search" aria-hidden="true"></span>
        <input
          type="text"
          id="search"
          class="search-input"
          placeholder="Search title, description, or command id…"
          autocomplete="off"
          spellcheck="false"
          aria-describedby="searchHint"
        />
        <span class="search-count" id="searchCount"></span>
      </div>
      <p id="searchHint" class="search-hint">
        Matches each command's <strong>title</strong>, <strong>description</strong>, and <strong>id</strong>
        (words from the id are indexed too, so you can type e.g. <kbd>run analysis</kbd> without dots).
      </p>
      <label class="toggle-row">
        <input type="checkbox" id="showInternal" />
        <span>Show context-menu-only commands</span>
      </label>
    </div>
  </div>

  <section class="history-card" id="historySection" ${history.length === 0 ? 'style="display:none"' : ''}>
    <div class="history-header">
      <h2 class="section-title">Recent</h2>
      <button type="button" class="text-btn" id="clearHistory">Clear</button>
    </div>
    <p class="history-hint">Click to run again · Newest first</p>
    <div class="history-chips" id="historyChips"></div>
  </section>

  <main id="catalog" class="catalog">
    ${sectionsHtml}
  </main>
  <div class="no-results" id="noResults" style="display:none">
    <span class="codicon codicon-info no-results-icon"></span>
    <p>No commands match your search.</p>
  </div>
  <script nonce="${nonce}">
    window.__INITIAL_HISTORY__ = ${JSON.stringify(history)};
    ${getScript()}
  </script>
</body>
</html>`;
}

function buildSectionsHtml(
  grouped: Map<CatalogCategory, CatalogEntry[]>,
): string {
  const sections: string[] = [];

  for (const [category, catEntries] of grouped) {
    const rows = catEntries.map((e) => buildEntryHtml(e)).join('\n');
    sections.push(`
      <section class="category" data-category="${escapeAttr(category)}">
        <button type="button" class="category-header" aria-expanded="true">
          <span class="collapse-icon codicon codicon-chevron-down" aria-hidden="true"></span>
          <span class="category-label">${escapeHtml(category)}</span>
          <span class="category-count">${catEntries.length}</span>
        </button>
        <div class="category-body">
          ${rows}
        </div>
      </section>`);
  }

  return sections.join('\n');
}

function buildEntryHtml(entry: CatalogEntry): string {
  const internalClass = entry.internal ? ' internal' : '';
  const internalBadge = entry.internal
    ? '<span class="badge internal-badge">context menu</span>'
    : '';

  return `
    <div class="entry${internalClass}"
         data-command="${escapeAttr(entry.command)}"
         data-search="${escapeAttr(buildCatalogSearchBlob(entry))}"
         tabindex="0"
         role="button"
         aria-label="${escapeAttr(entry.title + '. ' + entry.description)}">
      <div class="entry-icon-wrap" aria-hidden="true">
        <span class="entry-icon codicon codicon-${escapeAttr(entry.icon)}"></span>
      </div>
      <div class="entry-text">
        <div class="entry-title-row">
          <span class="entry-title">${escapeHtml(entry.title)}</span>
          ${internalBadge}
        </div>
        <span class="entry-desc">${escapeHtml(entry.description)}</span>
        <code class="entry-cmd">${escapeHtml(entry.command)}</code>
      </div>
    </div>`;
}

function getStyles(): string {
  return `
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      line-height: 1.55;
      min-height: 100vh;
    }

    .hero {
      background: linear-gradient(
        135deg,
        color-mix(in srgb, var(--vscode-button-background) 22%, transparent) 0%,
        color-mix(in srgb, var(--vscode-textLink-foreground) 12%, transparent) 100%
      );
      border-bottom: 1px solid var(--vscode-widget-border);
      padding: 20px 20px 18px;
    }

    .hero-inner {
      max-width: 880px;
      margin: 0 auto;
    }

    .hero-title {
      font-size: 1.45em;
      font-weight: 700;
      letter-spacing: -0.02em;
      margin-bottom: 4px;
    }

    .hero-sub {
      color: var(--vscode-descriptionForeground);
      font-size: 0.92em;
      margin-bottom: 14px;
    }

    .search-row {
      display: flex;
      align-items: center;
      gap: 10px;
      background: var(--vscode-input-background);
      border: 1px solid var(--vscode-input-border);
      border-radius: 8px;
      padding: 8px 12px;
      box-shadow: 0 1px 0 color-mix(in srgb, var(--vscode-widget-shadow) 40%, transparent);
    }

    .search-icon {
      opacity: 0.75;
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

    .search-count {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      white-space: nowrap;
    }

    .toggle-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 12px;
      font-size: 0.88em;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      user-select: none;
    }

    .toggle-row input { cursor: pointer; }

    .history-card {
      max-width: 880px;
      margin: 16px auto 0;
      padding: 0 20px;
    }

    .history-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .section-title {
      font-size: 0.95em;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--vscode-descriptionForeground);
    }

    .history-hint {
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

    .history-chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .history-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 10px 6px 8px;
      border-radius: 999px;
      border: 1px solid var(--vscode-widget-border);
      background: var(--vscode-editor-inactiveSelectionBackground);
      cursor: pointer;
      font-size: 0.88em;
      max-width: 100%;
      transition: background 0.12s ease, border-color 0.12s ease;
    }

    .history-chip:hover {
      background: var(--vscode-list-hoverBackground);
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-widget-border));
    }

    .history-chip:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .history-chip .chip-icon {
      width: 22px;
      height: 22px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: color-mix(in srgb, var(--vscode-button-background) 35%, transparent);
      flex-shrink: 0;
    }

    .history-chip .chip-icon .codicon {
      font-size: 13px;
    }

    .history-chip .chip-title {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .catalog {
      max-width: 880px;
      margin: 0 auto;
      padding: 8px 20px 48px;
    }

    .category {
      margin-bottom: 14px;
      border: 1px solid var(--vscode-widget-border);
      border-radius: 10px;
      overflow: hidden;
      background: color-mix(in srgb, var(--vscode-sideBar-background) 35%, var(--vscode-editor-background));
    }

    .category-header {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 12px;
      cursor: pointer;
      user-select: none;
      font: inherit;
      font-size: 1.02em;
      font-weight: 600;
      color: inherit;
      background: var(--vscode-sideBarSectionHeader-background);
      border: none;
      text-align: left;
    }

    .category-header:hover {
      filter: brightness(1.06);
    }

    .collapse-icon {
      transition: transform 0.18s ease;
      opacity: 0.85;
    }

    .category.collapsed .collapse-icon {
      transform: rotate(-90deg);
    }

    .category.collapsed .category-body {
      display: none;
    }

    .category-label { flex: 1; }

    .category-count {
      font-size: 0.78em;
      font-weight: 500;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 2px 8px;
      border-radius: 999px;
    }

    .category-body { padding: 6px 8px 10px; }

    .entry {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      padding: 10px 10px;
      border-radius: 8px;
      cursor: pointer;
      border: 1px solid transparent;
    }

    .entry:hover, .entry:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
      border-color: color-mix(in srgb, var(--vscode-widget-border) 80%, transparent);
    }

    .entry:active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
    }

    .entry.internal { display: none; }

    body.show-internal .entry.internal {
      display: flex;
      opacity: 0.72;
    }

    .entry-icon-wrap {
      flex-shrink: 0;
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 10px;
      background: color-mix(in srgb, var(--vscode-button-secondaryBackground) 90%, transparent);
      border: 1px solid var(--vscode-widget-border);
    }

    .entry-icon {
      font-size: 16px;
      opacity: 0.95;
    }

    .entry-text {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 3px;
    }

    .entry-title-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px 10px;
    }

    .entry-title {
      font-weight: 600;
      font-size: 1.02em;
    }

    .entry-desc {
      color: var(--vscode-descriptionForeground);
      font-size: 0.9em;
    }

    .entry-cmd {
      font-family: var(--vscode-editor-font-family);
      font-size: 0.75em;
      color: var(--vscode-descriptionForeground);
      opacity: 0.85;
      margin-top: 2px;
    }

    .badge {
      font-size: 0.72em;
      padding: 2px 7px;
      border-radius: 4px;
      white-space: nowrap;
    }

    .internal-badge {
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
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

    .no-results p { font-size: 1.05em; }

    .search-hint {
      font-size: 0.82em;
      color: var(--vscode-descriptionForeground);
      margin-top: 10px;
      line-height: 1.45;
      max-width: 42em;
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

    /* Narrow editor columns, sidebar webviews, split panes */
    @media (max-width: 720px) {
      .hero { padding: 14px 12px 14px; }
      .hero-inner,
      .history-card,
      .catalog {
        max-width: none;
      }
      .history-card,
      .catalog {
        padding-left: 12px;
        padding-right: 12px;
      }
      .hero-title { font-size: 1.22em; }
      .search-row {
        flex-wrap: wrap;
        row-gap: 6px;
      }
      .search-count {
        width: 100%;
        flex-basis: 100%;
        text-align: right;
        padding-left: 26px;
      }
      .toggle-row {
        align-items: flex-start;
      }
    }

    @media (max-width: 420px) {
      .entry {
        flex-direction: column;
        align-items: flex-start;
      }
      .entry-icon-wrap {
        width: 32px;
        height: 32px;
      }
      .category-header {
        flex-wrap: wrap;
        row-gap: 4px;
      }
      .category-label {
        flex-basis: calc(100% - 48px);
      }
      .history-chip {
        max-width: 100%;
        width: 100%;
        justify-content: flex-start;
      }
      .history-chip .chip-title {
        white-space: normal;
        text-overflow: unset;
      }
    }
  `;
}

function getScript(): string {
  return String.raw`
    (function () {
      const vscode = acquireVsCodeApi();
      const searchInput = document.getElementById('search');
      const searchCountEl = document.getElementById('searchCount');
      const noResultsEl = document.getElementById('noResults');
      const catalogEl = document.getElementById('catalog');
      const internalCheckbox = document.getElementById('showInternal');
      const historySection = document.getElementById('historySection');
      const historyChips = document.getElementById('historyChips');
      const clearHistoryBtn = document.getElementById('clearHistory');

      function safeIcon(name) {
        if (typeof name !== 'string' || !/^[a-z0-9-]+$/.test(name)) {
          return 'symbol-misc';
        }
        return name;
      }

      function renderHistory(items) {
        if (!historyChips || !historySection) return;
        historyChips.textContent = '';
        if (!items || items.length === 0) {
          historySection.style.display = 'none';
          return;
        }
        historySection.style.display = '';
        for (const item of items) {
          const chip = document.createElement('button');
          chip.type = 'button';
          chip.className = 'history-chip';
          chip.dataset.command = item.command;
          const wrap = document.createElement('span');
          wrap.className = 'chip-icon';
          const ic = document.createElement('span');
          ic.className = 'codicon codicon-' + safeIcon(item.icon);
          wrap.appendChild(ic);
          const title = document.createElement('span');
          title.className = 'chip-title';
          title.textContent = item.title;
          chip.appendChild(wrap);
          chip.appendChild(title);
          chip.addEventListener('click', function () {
            vscode.postMessage({ type: 'executeCommand', command: item.command });
          });
          historyChips.appendChild(chip);
        }
      }

      renderHistory(window.__INITIAL_HISTORY__ || []);

      window.addEventListener('message', function (event) {
        const msg = event.data;
        if (msg && msg.type === 'history') {
          renderHistory(msg.items || []);
        }
      });

      if (clearHistoryBtn) {
        clearHistoryBtn.addEventListener('click', function () {
          vscode.postMessage({ type: 'clearHistory' });
        });
      }

      catalogEl.addEventListener('click', function (e) {
        const entry = e.target.closest('.entry');
        if (!entry) return;
        vscode.postMessage({
          type: 'executeCommand',
          command: entry.dataset.command,
        });
      });

      catalogEl.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          const entry = e.target.closest('.entry');
          if (entry) {
            e.preventDefault();
            vscode.postMessage({
              type: 'executeCommand',
              command: entry.dataset.command,
            });
          }
        }
      });

      for (const header of document.querySelectorAll('.category-header')) {
        header.addEventListener('click', function () {
          const section = header.parentElement;
          const collapsed = section.classList.toggle('collapsed');
          header.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
        });
      }

      internalCheckbox.addEventListener('change', function () {
        document.body.classList.toggle('show-internal', internalCheckbox.checked);
        applySearch();
      });

      searchInput.addEventListener('input', applySearch);
      searchInput.focus();

      function applySearch() {
        const query = searchInput.value.toLowerCase().trim().split(/\s+/).join(' ');
        const showInternal = internalCheckbox.checked;
        let visibleCount = 0;

        for (const section of document.querySelectorAll('.category')) {
          let sectionVisible = 0;

          for (const entry of section.querySelectorAll('.entry')) {
            const isInternal = entry.classList.contains('internal');
            const matchesSearch =
              !query || entry.dataset.search.includes(query);
            const visible = matchesSearch && (!isInternal || showInternal);

            entry.classList.toggle('search-hidden', !visible);
            if (visible) sectionVisible++;
          }

          section.classList.toggle('search-hidden', sectionVisible === 0);

          if (query) {
            section.classList.remove('collapsed');
            const hdr = section.querySelector('.category-header');
            if (hdr) hdr.setAttribute('aria-expanded', 'true');
          }

          visibleCount += sectionVisible;
        }

        noResultsEl.style.display = visibleCount === 0 ? '' : 'none';
        searchCountEl.textContent = query
          ? visibleCount + ' match' + (visibleCount === 1 ? '' : 'es')
          : '';
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

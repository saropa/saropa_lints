/**
 * Sidebar webview for the command catalog.
 *
 * Renders a compact, searchable list of every extension command inside a
 * collapsible sidebar section. Recent commands appear at the top for quick
 * re-runs. The full editor-tab catalog is still available via the
 * "Open full catalog" link — this sidebar version is a lightweight entry
 * point designed to be the first thing users see.
 */

import * as vscode from 'vscode';
import { catalogEntries, entriesByCategory, catalogEntryByCommand } from './commandCatalogRegistry';
import type { CatalogCategory, CatalogEntry } from './commandCatalogRegistry';
import { buildCatalogSearchBlob } from './commandCatalogSearch';
import {
  readCommandHistory,
  recordCommandHistory,
  clearCommandHistory,
} from './commandCatalogHistory';

/**
 * View ID matching the `id` in package.json views registration.
 * Used by extension.ts when calling `registerWebviewViewProvider`.
 */
export const COMMAND_CATALOG_SIDEBAR_VIEW_ID = 'saropaLints.commandCatalogSidebar';

// catalogEntries is a static array populated at module load — this set
// will never go stale because no entries are added after initialization.
const knownCommands = new Set(catalogEntries.map((e) => e.command));

export class CommandCatalogSidebarProvider implements vscode.WebviewViewProvider {
  private _view?: vscode.WebviewView;

  constructor(
    private readonly _extensionUri: vscode.Uri,
    private readonly _context: vscode.ExtensionContext,
  ) {}

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _resolveContext: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken,
  ): void {
    this._view = webviewView;
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this._extensionUri],
    };

    webviewView.webview.html = this._buildHtml(webviewView.webview);

    webviewView.webview.onDidReceiveMessage((msg) => {
      this._handleMessage(msg);
    });
  }

  /** Re-render the sidebar (e.g. after history changes from the editor-tab catalog). */
  refresh(): void {
    if (this._view) {
      this._view.webview.html = this._buildHtml(this._view.webview);
    }
  }

  // ── Message handling ────────────────────────────────────────────────────

  private _handleMessage(message: unknown): void {
    if (!message || typeof message !== 'object') {
      return;
    }

    const rec = message as { type?: string; command?: string };

    if (rec.type === 'clearHistory') {
      void clearCommandHistory(this._context).then(() => this._postHistory());
      return;
    }

    // "Open full catalog" link inside the sidebar
    if (rec.type === 'openFullCatalog') {
      void vscode.commands.executeCommand('saropaLints.showCommandCatalog');
      return;
    }

    if (rec.type !== 'executeCommand' || !rec.command) {
      return;
    }

    if (!knownCommands.has(rec.command)) {
      return;
    }

    const entry = catalogEntryByCommand.get(rec.command);
    if (entry) {
      recordCommandHistory(this._context, rec.command, entry.title, entry.icon);
      this._postHistory();
    }

    void vscode.commands.executeCommand(rec.command);
  }

  private _postHistory(): void {
    if (!this._view) {
      return;
    }
    void this._view.webview.postMessage({
      type: 'history',
      items: readCommandHistory(this._context),
    });
  }

  // ── HTML builder ────────────────────────────────────────────────────────

  private _buildHtml(webview: vscode.Webview): string {
    const nonce = getNonce();
    const history = readCommandHistory(this._context);
    const grouped = entriesByCategory();

    const codiconCss = webview.asWebviewUri(
      vscode.Uri.joinPath(this._extensionUri, 'media', 'codicons', 'codicon.css'),
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
  <title>Commands</title>
  <style nonce="${nonce}">
    ${getSidebarStyles()}
  </style>
</head>
<body>
  <div class="search-row">
    <span class="search-icon codicon codicon-search" aria-hidden="true"></span>
    <input
      type="text"
      id="search"
      class="search-input"
      placeholder="Search commands…"
      autocomplete="off"
      spellcheck="false"
    />
    <span class="search-count" id="searchCount"></span>
  </div>

  <button type="button" class="open-full" id="openFull">
    <span class="codicon codicon-link-external" aria-hidden="true"></span>
    Open full catalog
  </button>

  <section class="history-section" id="historySection" ${history.length === 0 ? 'style="display:none"' : ''}>
    <div class="history-header">
      <span class="section-label">Recent</span>
      <button type="button" class="text-btn" id="clearHistory">Clear</button>
    </div>
    <div class="history-list" id="historyList"></div>
  </section>

  <main id="catalog" class="catalog">
    ${buildCompactSections(grouped)}
  </main>
  <div class="no-results" id="noResults" style="display:none">
    No commands match your search.
  </div>
  <script nonce="${nonce}">
    window.__INITIAL_HISTORY__ = ${JSON.stringify(history)};
    ${getSidebarScript()}
  </script>
</body>
</html>`;
  }
}

// ── Section HTML ────────────────────────────────────────────────────────────

function buildCompactSections(
  grouped: Map<CatalogCategory, CatalogEntry[]>,
): string {
  const sections: string[] = [];

  for (const [category, entries] of grouped) {
    // Only render non-internal commands in the sidebar. Internal commands
    // (context-menu-only) are excluded entirely from the DOM — unlike the
    // full editor-tab catalog which keeps them hidden via CSS toggle.
    const visibleEntries = entries.filter((e) => !e.internal);
    if (visibleEntries.length === 0) {
      continue;
    }

    const rows = visibleEntries.map((e) => buildCompactEntry(e)).join('\n');
    sections.push(`
      <section class="category collapsed" data-category="${escapeAttr(category)}">
        <button type="button" class="category-header" aria-expanded="false">
          <span class="collapse-icon codicon codicon-chevron-right" aria-hidden="true"></span>
          <span class="category-label">${escapeHtml(category)}</span>
          <span class="category-count">${visibleEntries.length}</span>
        </button>
        <div class="category-body">
          ${rows}
        </div>
      </section>`);
  }

  return sections.join('\n');
}

function buildCompactEntry(entry: CatalogEntry): string {
  return `
    <div class="entry"
         data-command="${escapeAttr(entry.command)}"
         data-search="${escapeAttr(buildCatalogSearchBlob(entry))}"
         tabindex="0"
         role="button"
         title="${escapeAttr(entry.description)}"
         aria-label="${escapeAttr(entry.title + '. ' + entry.description)}">
      <span class="entry-icon codicon codicon-${escapeAttr(entry.icon)}" aria-hidden="true"></span>
      <span class="entry-title">${escapeHtml(entry.title)}</span>
    </div>`;
}

// ── Styles (compact sidebar layout) ─────────────────────────────────────────

function getSidebarStyles(): string {
  return `
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-sideBar-background);
      line-height: 1.45;
      padding: 8px;
    }

    /* ── Search ─────────────────────────────────────────────────── */

    .search-row {
      display: flex;
      align-items: center;
      gap: 6px;
      background: var(--vscode-input-background);
      border: 1px solid var(--vscode-input-border);
      border-radius: 4px;
      padding: 4px 8px;
      margin-bottom: 6px;
    }

    .search-icon { opacity: 0.6; font-size: 14px; flex-shrink: 0; }

    .search-input {
      flex: 1;
      min-width: 0;
      border: none;
      outline: none;
      background: transparent;
      color: var(--vscode-input-foreground);
      font: inherit;
      font-size: 12px;
    }

    .search-input::placeholder {
      color: var(--vscode-input-placeholderForeground);
    }

    .search-count {
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
      white-space: nowrap;
    }

    /* ── Open full catalog link ──────────────────────────────────── */

    .open-full {
      display: flex;
      align-items: center;
      gap: 6px;
      width: 100%;
      padding: 5px 8px;
      margin-bottom: 6px;
      font: inherit;
      font-size: 12px;
      color: var(--vscode-textLink-foreground);
      background: none;
      border: 1px solid var(--vscode-widget-border);
      border-radius: 4px;
      cursor: pointer;
      text-align: left;
    }

    .open-full:hover {
      background: var(--vscode-toolbar-hoverBackground);
    }

    /* ── Recent history ──────────────────────────────────────────── */

    .history-section {
      margin-bottom: 8px;
      padding-bottom: 6px;
      border-bottom: 1px solid var(--vscode-widget-border);
    }

    .history-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 4px;
    }

    .section-label {
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--vscode-descriptionForeground);
    }

    .text-btn {
      font: inherit;
      font-size: 11px;
      color: var(--vscode-textLink-foreground);
      background: none;
      border: none;
      cursor: pointer;
      padding: 1px 4px;
      border-radius: 3px;
    }

    .text-btn:hover { background: var(--vscode-toolbar-hoverBackground); }

    .history-list {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }

    .history-item {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 3px 6px;
      border-radius: 3px;
      cursor: pointer;
      font-size: 12px;
      border: none;
      background: none;
      color: inherit;
      font: inherit;
      font-size: 12px;
      text-align: left;
      width: 100%;
    }

    .history-item:hover { background: var(--vscode-list-hoverBackground); }

    .history-item .codicon { font-size: 14px; opacity: 0.8; flex-shrink: 0; }

    .history-item-title {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    /* ── Catalog categories ──────────────────────────────────────── */

    .catalog { padding-bottom: 16px; }

    .category { margin-bottom: 2px; }

    .category-header {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 4px 6px;
      cursor: pointer;
      user-select: none;
      font: inherit;
      font-size: 12px;
      font-weight: 600;
      color: inherit;
      background: none;
      border: none;
      text-align: left;
      border-radius: 3px;
    }

    .category-header:hover { background: var(--vscode-list-hoverBackground); }

    .collapse-icon {
      transition: transform 0.15s ease;
      font-size: 12px;
      opacity: 0.7;
    }

    /* Expanded state: chevron points down */
    .category:not(.collapsed) .collapse-icon {
      transform: rotate(90deg);
    }

    .category.collapsed .category-body { display: none; }

    .category-label { flex: 1; }

    .category-count {
      font-size: 10px;
      font-weight: 500;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 1px 5px;
      border-radius: 999px;
    }

    .category-body { padding: 2px 0 4px 8px; }

    /* ── Individual entries ──────────────────────────────────────── */

    .entry {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 3px 6px;
      border-radius: 3px;
      cursor: pointer;
      font-size: 12px;
    }

    .entry:hover, .entry:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
    }

    .entry:active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
    }

    .entry-icon { font-size: 14px; opacity: 0.8; flex-shrink: 0; }

    .entry-title {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .entry.search-hidden { display: none !important; }
    .category.search-hidden { display: none !important; }

    .no-results {
      text-align: center;
      padding: 24px 8px;
      color: var(--vscode-descriptionForeground);
      font-size: 12px;
    }
  `;
}

// ── Client-side script ──────────────────────────────────────────────────────

function getSidebarScript(): string {
  return String.raw`
    (function () {
      const vscode = acquireVsCodeApi();
      const searchInput = document.getElementById('search');
      const searchCountEl = document.getElementById('searchCount');
      const noResultsEl = document.getElementById('noResults');
      const catalogEl = document.getElementById('catalog');
      const historySection = document.getElementById('historySection');
      const historyList = document.getElementById('historyList');
      const clearHistoryBtn = document.getElementById('clearHistory');
      const openFullBtn = document.getElementById('openFull');

      /* ── Icon name sanitizer ──────────────────────────────────── */

      function safeIcon(name) {
        if (typeof name !== 'string' || !/^[a-z0-9-]+$/.test(name)) {
          return 'symbol-misc';
        }
        return name;
      }

      /* ── Recent history rendering ─────────────────────────────── */

      function renderHistory(items) {
        if (!historyList || !historySection) return;
        historyList.textContent = '';
        if (!items || items.length === 0) {
          historySection.style.display = 'none';
          return;
        }
        historySection.style.display = '';

        // Show at most 5 recent items in the compact sidebar
        var maxShown = 5;
        var shown = items.slice(0, maxShown);
        for (var i = 0; i < shown.length; i++) {
          var item = shown[i];
          var btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'history-item';
          btn.dataset.command = item.command;
          var ic = document.createElement('span');
          ic.className = 'codicon codicon-' + safeIcon(item.icon);
          var title = document.createElement('span');
          title.className = 'history-item-title';
          title.textContent = item.title;
          btn.appendChild(ic);
          btn.appendChild(title);
          btn.addEventListener('click', (function (cmd) {
            return function () {
              vscode.postMessage({ type: 'executeCommand', command: cmd });
            };
          })(item.command));
          historyList.appendChild(btn);
        }
      }

      renderHistory(window.__INITIAL_HISTORY__ || []);

      /* ── Incoming messages (history updates) ──────────────────── */

      window.addEventListener('message', function (event) {
        var msg = event.data;
        if (msg && msg.type === 'history') {
          renderHistory(msg.items || []);
        }
      });

      /* ── Clear history ────────────────────────────────────────── */

      if (clearHistoryBtn) {
        clearHistoryBtn.addEventListener('click', function () {
          vscode.postMessage({ type: 'clearHistory' });
        });
      }

      /* ── Open full catalog ────────────────────────────────────── */

      if (openFullBtn) {
        openFullBtn.addEventListener('click', function () {
          vscode.postMessage({ type: 'openFullCatalog' });
        });
      }

      /* ── Command execution on click / keyboard ────────────────── */

      catalogEl.addEventListener('click', function (e) {
        var entry = e.target.closest('.entry');
        if (!entry) return;
        vscode.postMessage({
          type: 'executeCommand',
          command: entry.dataset.command,
        });
      });

      catalogEl.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          var entry = e.target.closest('.entry');
          if (entry) {
            e.preventDefault();
            vscode.postMessage({
              type: 'executeCommand',
              command: entry.dataset.command,
            });
          }
        }
      });

      /* ── Category collapse/expand ─────────────────────────────── */

      for (var h of document.querySelectorAll('.category-header')) {
        h.addEventListener('click', function () {
          var section = this.parentElement;
          var collapsed = section.classList.toggle('collapsed');
          this.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
        });
      }

      /* ── Search filtering ─────────────────────────────────────── */

      searchInput.addEventListener('input', applySearch);

      function applySearch() {
        var query = searchInput.value.toLowerCase().trim().split(/\s+/).join(' ');
        var visibleCount = 0;

        for (var section of document.querySelectorAll('.category')) {
          var sectionVisible = 0;

          for (var entry of section.querySelectorAll('.entry')) {
            var matchesSearch =
              !query || entry.dataset.search.includes(query);
            var visible = matchesSearch;

            entry.classList.toggle('search-hidden', !visible);
            if (visible) sectionVisible++;
          }

          section.classList.toggle('search-hidden', sectionVisible === 0);

          // When searching, auto-expand matching categories
          if (query && sectionVisible > 0) {
            section.classList.remove('collapsed');
            var hdr = section.querySelector('.category-header');
            if (hdr) hdr.setAttribute('aria-expanded', 'true');
          }

          visibleCount += sectionVisible;
        }

        noResultsEl.style.display = visibleCount === 0 && query ? '' : 'none';
        searchCountEl.textContent = query
          ? visibleCount + ' match' + (visibleCount === 1 ? '' : 'es')
          : '';
      }
    })();
  `;
}

// ── HTML helpers ────────────────────────────────────────────────────────────

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

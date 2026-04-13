/**
 * Searchable, categorized command catalog webview panel.
 *
 * Opens as a singleton editor tab (like the About panel). Users can browse
 * every extension command grouped by category, search/filter by title or
 * description, and click to execute.
 */

import * as vscode from 'vscode';
import {
  catalogEntries,
  type CatalogCategory,
  type CatalogEntry,
  entriesByCategory,
} from './commandCatalogRegistry';

// ── Singleton panel management ───────────────────────────────────────────────

let currentPanel: vscode.WebviewPanel | undefined;

/**
 * Show (or re-focus) the command catalog panel. Call this from the registered
 * command handler in extension.ts.
 */
export function showCommandCatalogPanel(): void {
  if (currentPanel) {
    currentPanel.reveal(vscode.ViewColumn.One);
    return;
  }

  currentPanel = vscode.window.createWebviewPanel(
    'saropaLints.commandCatalog',
    'Saropa Lints: Command Catalog',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      // Webview does not need local resource access — all content is inline.
      localResourceRoots: [],
    },
  );

  currentPanel.webview.html = buildHtml();

  // Execute commands when the user clicks an entry in the webview.
  currentPanel.webview.onDidReceiveMessage(handleMessage);

  currentPanel.onDidDispose(() => {
    currentPanel = undefined;
  });
}

// ── Message handling ─────────────────────────────────────────────────────────

interface ExecuteCommandMessage {
  type: 'executeCommand';
  command: string;
}

/** Set of known command IDs from the catalog, used to validate messages. */
const knownCommands = new Set(catalogEntries.map((e) => e.command));

function handleMessage(message: ExecuteCommandMessage): void {
  if (message.type !== 'executeCommand' || !message.command) {
    return;
  }

  // Only allow commands that exist in the catalog registry to prevent
  // arbitrary command execution from a compromised webview.
  if (!knownCommands.has(message.command)) {
    return;
  }

  vscode.commands.executeCommand(message.command);
}

// ── HTML generation ──────────────────────────────────────────────────────────

function buildHtml(): string {
  const nonce = getNonce();
  const grouped = entriesByCategory();
  const sectionsHtml = buildSectionsHtml(grouped);
  const totalCount = Array.from(grouped.values()).reduce(
    (sum, list) => sum + list.length,
    0,
  );

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Command Catalog</title>
  <style nonce="${nonce}">
    ${getStyles()}
  </style>
</head>
<body>
  <header>
    <h1>Command Catalog</h1>
    <p class="subtitle">${totalCount} commands across ${grouped.size} categories</p>
    <div class="search-container">
      <input
        type="text"
        id="search"
        placeholder="Search commands..."
        autocomplete="off"
        spellcheck="false"
      />
      <span class="search-count" id="searchCount"></span>
    </div>
    <label class="internal-toggle">
      <input type="checkbox" id="showInternal" />
      Show context-menu-only commands
    </label>
  </header>
  <main id="catalog">
    ${sectionsHtml}
  </main>
  <div class="no-results" id="noResults" style="display:none">
    No commands match your search.
  </div>
  <script nonce="${nonce}">
    ${getScript()}
  </script>
</body>
</html>`;
}

function buildSectionsHtml(
  grouped: Map<CatalogCategory, CatalogEntry[]>,
): string {
  const sections: string[] = [];

  for (const [category, entries] of grouped) {
    const rows = entries.map((e) => buildEntryHtml(e)).join('\n');
    sections.push(`
      <section class="category" data-category="${escapeAttr(category)}">
        <h2 class="category-header">
          <span class="collapse-icon">&#9660;</span>
          ${escapeHtml(category)}
          <span class="category-count">${entries.length}</span>
        </h2>
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
         data-search="${escapeAttr((entry.title + ' ' + entry.description).toLowerCase())}"
         tabindex="0"
         role="button"
         title="${escapeAttr(entry.command)}">
      <span class="entry-icon codicon codicon-${escapeAttr(entry.icon)}"></span>
      <div class="entry-text">
        <span class="entry-title">${escapeHtml(entry.title)}</span>
        ${internalBadge}
        <span class="entry-desc">${escapeHtml(entry.description)}</span>
      </div>
    </div>`;
}

// ── Styles ───────────────────────────────────────────────────────────────────

function getStyles(): string {
  return `
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      max-width: 800px;
      margin: 0 auto;
      padding: 16px 24px 40px;
      line-height: 1.5;
    }

    header { margin-bottom: 20px; }

    h1 {
      font-size: 1.5em;
      margin-bottom: 2px;
    }

    .subtitle {
      color: var(--vscode-descriptionForeground);
      font-size: 0.9em;
      margin-bottom: 12px;
    }

    /* ── Search ─────────────────────────────────────────────────────────── */

    .search-container {
      position: relative;
      margin-bottom: 8px;
    }

    #search {
      width: 100%;
      padding: 7px 10px;
      padding-right: 70px;
      border: 1px solid var(--vscode-input-border);
      background: var(--vscode-input-background);
      color: var(--vscode-input-foreground);
      border-radius: 4px;
      font-size: 1em;
      outline: none;
    }

    #search:focus {
      border-color: var(--vscode-focusBorder);
    }

    .search-count {
      position: absolute;
      right: 10px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--vscode-descriptionForeground);
      font-size: 0.85em;
      pointer-events: none;
    }

    .internal-toggle {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.85em;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      user-select: none;
    }

    .internal-toggle input { cursor: pointer; }

    /* ── Categories ─────────────────────────────────────────────────────── */

    .category { margin-bottom: 8px; }

    .category-header {
      font-size: 1.1em;
      padding: 8px 4px;
      cursor: pointer;
      user-select: none;
      display: flex;
      align-items: center;
      gap: 6px;
      border-bottom: 1px solid var(--vscode-panel-border);
    }

    .category-header:hover {
      color: var(--vscode-textLink-foreground);
    }

    .collapse-icon {
      font-size: 0.7em;
      transition: transform 0.15s;
      display: inline-block;
      width: 14px;
      text-align: center;
    }

    .category.collapsed .collapse-icon {
      transform: rotate(-90deg);
    }

    .category.collapsed .category-body {
      display: none;
    }

    .category-count {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      font-weight: normal;
      margin-left: auto;
    }

    .category-body { padding: 4px 0; }

    /* ── Entries ─────────────────────────────────────────────────────────── */

    .entry {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      padding: 6px 8px;
      border-radius: 4px;
      cursor: pointer;
    }

    .entry:hover, .entry:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
    }

    .entry:active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
    }

    .entry.internal {
      display: none;
    }

    body.show-internal .entry.internal {
      display: flex;
      opacity: 0.65;
    }

    .entry-icon {
      flex-shrink: 0;
      margin-top: 2px;
      font-size: 1em;
    }

    .entry-text {
      display: flex;
      flex-wrap: wrap;
      align-items: baseline;
      gap: 4px 8px;
    }

    .entry-title {
      font-weight: 600;
    }

    .entry-desc {
      color: var(--vscode-descriptionForeground);
      font-size: 0.9em;
    }

    .badge {
      font-size: 0.75em;
      padding: 1px 5px;
      border-radius: 3px;
      white-space: nowrap;
    }

    .internal-badge {
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
    }

    .entry.search-hidden { display: none !important; }
    .category.search-hidden { display: none !important; }

    /* ── No results ─────────────────────────────────────────────────────── */

    .no-results {
      text-align: center;
      padding: 40px;
      color: var(--vscode-descriptionForeground);
      font-size: 1.1em;
    }
  `;
}

// ── Client-side script ───────────────────────────────────────────────────────

function getScript(): string {
  // The script runs inside the webview. It handles: search filtering,
  // category collapse/expand, internal toggle, and click-to-execute.
  return `
    (function () {
      const vscode = acquireVsCodeApi();
      const searchInput = document.getElementById('search');
      const searchCountEl = document.getElementById('searchCount');
      const noResultsEl = document.getElementById('noResults');
      const catalogEl = document.getElementById('catalog');
      const internalCheckbox = document.getElementById('showInternal');

      // ── Click to execute ───────────────────────────────────────────────
      catalogEl.addEventListener('click', (e) => {
        const entry = e.target.closest('.entry');
        if (!entry) return;
        vscode.postMessage({
          type: 'executeCommand',
          command: entry.dataset.command,
        });
      });

      // Keyboard: Enter or Space on a focused entry.
      catalogEl.addEventListener('keydown', (e) => {
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

      // ── Category collapse/expand ───────────────────────────────────────
      for (const header of document.querySelectorAll('.category-header')) {
        header.addEventListener('click', () => {
          header.parentElement.classList.toggle('collapsed');
        });
      }

      // ── Internal toggle ────────────────────────────────────────────────
      internalCheckbox.addEventListener('change', () => {
        document.body.classList.toggle('show-internal', internalCheckbox.checked);
        applySearch();
      });

      // ── Search ─────────────────────────────────────────────────────────
      searchInput.addEventListener('input', applySearch);

      // Focus the search box on load for immediate typing.
      searchInput.focus();

      function applySearch() {
        const query = searchInput.value.toLowerCase().trim();
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

          // Hide the entire category header when no entries match.
          section.classList.toggle('search-hidden', sectionVisible === 0);

          // Auto-expand categories when searching, collapse when cleared.
          if (query) {
            section.classList.remove('collapsed');
          }

          visibleCount += sectionVisible;
        }

        noResultsEl.style.display = visibleCount === 0 ? '' : 'none';
        searchCountEl.textContent = query
          ? visibleCount + ' found'
          : '';
      }
    })();
  `;
}

// ── Utilities ────────────────────────────────────────────────────────────────

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function escapeAttr(text: string): string {
  return escapeHtml(text).replace(/"/g, '&quot;');
}

function getNonce(): string {
  const chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from({ length: 32 }, () =>
    chars[Math.floor(Math.random() * chars.length)],
  ).join('');
}

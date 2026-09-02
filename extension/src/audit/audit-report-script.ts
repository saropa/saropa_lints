/**
 * Client-side script for the audit report webview.
 *
 * Split out of audit-report-html.ts to keep that file under the project's
 * file-size convention and to match the vibrancy panel convention
 * (report-html.ts / report-script.ts / report-styles.ts).
 *
 * IMPORTANT (template-literal regex trap): this whole module is emitted as
 * text inside a browser <script> tag. A regex literal containing a
 * backslash escape (e.g. `\d`, `\B`) would be silently swallowed by the
 * *outer* TypeScript template literal before it ever reaches the browser.
 * Every regex below is either backslash-free (`/&/g`, `/</g`, `/"/g`) or
 * uses an explicitly doubled backslash (`\\\\`) so the emitted JS source
 * still contains a real single backslash for the browser's regex engine.
 * Do not add a bare `\d`/`\w`/etc. literal here — verify by evaluating the
 * generated function, not by `includes()` on the source (see
 * saropa-lints-extension-development skill).
 */

/**
 * Builds the inline <script> BODY (no wrapping <script nonce=...> tag —
 * the caller in audit-report-html.ts adds that with the CSP nonce).
 *
 * @param embeddedJson Pre-escaped (via jsonForScriptBlock) JSON array of
 *   ALL diagnostics, or `null` when the payload exceeded the inline size
 *   threshold and must be fetched lazily from `deferredUri`.
 * @param initialJson Pre-escaped JSON array of just the first page (used
 *   to seed client-side filtering immediately, matching the server-rendered
 *   rows, even while the full deferred payload is still loading).
 * @param deferredUri Webview-resolved URI to fetch the full diagnostics
 *   array from when `embeddedJson` is null. Null when not deferring.
 * @param root Escaped-for-script-block JSON string of the scanned project
 *   root, used to compute file paths relative to it.
 */
export function buildAuditScript(
  embeddedJson: string | null,
  initialJson: string,
  deferredUri: string | null,
  root: string,
): string {
  return `(function() {
  const vscode = acquireVsCodeApi();
  // Deferred payloads (>10MB) are not inlined — see MAX_INLINE_BYTES in
  // audit-report-panel.ts. ALL_DIAGNOSTICS starts as just the first page
  // so filtering/search work instantly; the fetch below (when present)
  // swaps in the complete array once it lands.
  let ALL_DIAGNOSTICS = ${embeddedJson ?? initialJson};
  const DEFERRED_URI = ${deferredUri === null ? 'null' : JSON.stringify(deferredUri)};
  const ROOT = ${root};
  const PAGE_SIZE = 500;
  let shownCount = Math.min(PAGE_SIZE, ALL_DIAGNOSTICS.length);
  let groupByFile = false;

  // Active filters: dimension -> Set of active values.
  const filters = {
    tier: new Set(),
    severity: new Set(),
    impact: new Set(),
    baselineStatus: new Set(),
  };

  // Initialize filters: all values active.
  document.querySelectorAll('.audit-chip').forEach(chip => {
    const dim = chip.dataset.dim;
    const val = chip.dataset.val;
    if (dim && val) filters[dim].add(val);
  });

  // Filter chip toggle.
  document.querySelectorAll('.audit-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const dim = chip.dataset.dim;
      const val = chip.dataset.val;
      if (!dim || !val) return;
      if (filters[dim].has(val)) {
        filters[dim].delete(val);
        chip.classList.remove('audit-chip-active');
      } else {
        filters[dim].add(val);
        chip.classList.add('audit-chip-active');
      }
      rerender();
    });
  });

  // Search with debounce.
  const searchInput = document.getElementById('audit-search');
  let searchTimeout;
  searchInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(rerender, 200);
  });

  // Copy JSON button.
  document.getElementById('audit-copy-json').addEventListener('click', () => {
    vscode.postMessage({ type: 'copyJson', json: JSON.stringify(ALL_DIAGNOSTICS, null, 2) });
  });

  // Save as baseline button — sends the full audit JSON back to the host.
  const saveBaselineBtn = document.getElementById('audit-save-baseline');
  if (saveBaselineBtn) {
    saveBaselineBtn.addEventListener('click', () => {
      vscode.postMessage({ type: 'saveBaseline', json: JSON.stringify(ALL_DIAGNOSTICS, null, 2) });
    });
  }

  // Toggle group-by-file.
  document.getElementById('audit-toggle-group').addEventListener('click', () => {
    groupByFile = !groupByFile;
    rerender();
  });

  // Load more button.
  const loadMoreBtn = document.getElementById('audit-load-more');
  loadMoreBtn.addEventListener('click', () => {
    shownCount = Math.min(shownCount + PAGE_SIZE, ALL_DIAGNOSTICS.length);
    rerender();
  });

  // File click: open in editor.
  document.getElementById('audit-tbody').addEventListener('click', (e) => {
    const cell = e.target.closest('.audit-clickable');
    if (!cell) return;
    vscode.postMessage({ type: 'openFile', path: cell.dataset.path });
  });

  // Sort by clicking column headers.
  let sortCol = null;
  let sortAsc = true;
  document.querySelectorAll('th[data-sort]').forEach(th => {
    th.style.cursor = 'pointer';
    th.addEventListener('click', () => {
      const col = th.dataset.sort;
      if (sortCol === col) {
        sortAsc = !sortAsc;
      } else {
        sortCol = col;
        sortAsc = true;
      }
      rerender();
    });
  });

  // Keyboard navigation: arrow keys move between rows, Enter opens file.
  let activeRowIdx = -1;
  document.addEventListener('keydown', (e) => {
    const rows = document.querySelectorAll('#audit-tbody .audit-row');
    if (!rows.length) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      activeRowIdx = Math.min(activeRowIdx + 1, rows.length - 1);
      highlightRow(rows);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      activeRowIdx = Math.max(activeRowIdx - 1, 0);
      highlightRow(rows);
    } else if (e.key === 'Escape') {
      searchInput.value = '';
      rerender();
    } else if (e.key === 'Enter' && activeRowIdx >= 0 && activeRowIdx < rows.length) {
      // Open the file at the active row.
      const cell = rows[activeRowIdx].querySelector('.audit-clickable');
      if (cell) {
        vscode.postMessage({ type: 'openFile', path: cell.dataset.path });
      }
    }
  });

  function highlightRow(rows) {
    // Remove previous highlight.
    rows.forEach(r => r.classList.remove('audit-row-active'));
    if (activeRowIdx >= 0 && activeRowIdx < rows.length) {
      rows[activeRowIdx].classList.add('audit-row-active');
      rows[activeRowIdx].scrollIntoView({ block: 'nearest' });
    }
  }

  function rerender() {
    // Reset keyboard focus on re-render.
    activeRowIdx = -1;

    const query = (searchInput.value || '').toLowerCase();
    // Only apply baseline status filter when baseline data is present.
    const hasBaselineData = filters.baselineStatus.size > 0;

    let filtered = ALL_DIAGNOSTICS.filter(d => {
      if (!filters.tier.has(d.tier || 'unknown')) return false;
      if (!filters.severity.has(d.severity)) return false;
      if (!filters.impact.has(d.impact || 'unknown')) return false;
      if (hasBaselineData && d.baselineStatus && !filters.baselineStatus.has(d.baselineStatus)) return false;
      if (query) {
        const haystack = (d.filePath + ' ' + d.ruleName + ' ' + (d.problemMessage || '')).toLowerCase();
        if (!haystack.includes(query)) return false;
      }
      return true;
    });

    // Sort.
    if (sortCol) {
      filtered.sort((a, b) => {
        let va, vb;
        switch (sortCol) {
          case 'file': va = a.filePath; vb = b.filePath; break;
          case 'line': return sortAsc ? a.line - b.line : b.line - a.line;
          case 'rule': va = a.ruleName; vb = b.ruleName; break;
          case 'severity': va = sevRank(a.severity); vb = sevRank(b.severity);
            return sortAsc ? va - vb : vb - va;
          case 'tier': va = a.tier || ''; vb = b.tier || ''; break;
          default: va = ''; vb = '';
        }
        if (typeof va === 'string') {
          const cmp = va.localeCompare(vb);
          return sortAsc ? cmp : -cmp;
        }
        return 0;
      });
    }

    // Group by file when toggled: flatten into ordered rows with a header
    // row per file so the table stays a single <tbody> (simplest DOM shape).
    const page = filtered.slice(0, shownCount);
    const tbody = document.getElementById('audit-tbody');
    if (groupByFile) {
      tbody.innerHTML = groupedRowsHtml(page);
    } else {
      tbody.innerHTML = page.map(d => rowHtml(d)).join('');
    }

    // Show filtered-empty state when filters produce zero results but
    // diagnostics exist (distinguishes "clean project" from "too narrow").
    const filteredEmpty = document.getElementById('audit-filtered-empty');
    if (ALL_DIAGNOSTICS.length > 0 && filtered.length === 0) {
      filteredEmpty.hidden = false;
    } else {
      filteredEmpty.hidden = true;
    }

    // Pagination controls.
    const pagination = document.getElementById('audit-pagination');
    const countSpan = document.getElementById('audit-shown-count');
    if (filtered.length > shownCount) {
      pagination.hidden = false;
      countSpan.textContent = shownCount + ' / ' + filtered.length;
    } else {
      pagination.hidden = true;
    }
  }

  function groupedRowsHtml(rows) {
    const byFile = new Map();
    for (const d of rows) {
      const key = d.filePath;
      if (!byFile.has(key)) byFile.set(key, []);
      byFile.get(key).push(d);
    }
    let html = '';
    for (const [file, items] of byFile) {
      const rel = relPath(file);
      html += '<tr class="audit-group-header"><td colspan="6">' + esc(rel) + ' (' + items.length + ')</td></tr>';
      html += items.map(d => rowHtml(d)).join('');
    }
    return html;
  }

  function relPath(filePath) {
    return filePath.indexOf(ROOT) === 0
      ? filePath.slice(ROOT.length + 1).split('\\\\').join('/')
      : filePath.split('\\\\').join('/');
  }

  function rowHtml(d) {
    const rel = relPath(d.filePath);
    const sevClass = 'audit-sev-' + (d.severity || '').toLowerCase();
    const baselineClass = d.baselineStatus === 'new' ? ' audit-baseline-new-row' : '';
    // Show a small badge next to the rule name when baseline data is present.
    const statusBadge = d.baselineStatus === 'new'
      ? ' <span class="audit-status-badge audit-status-new">NEW</span>'
      : d.baselineStatus === 'unchanged'
        ? ' <span class="audit-status-badge audit-status-unchanged">—</span>'
        : '';
    return '<tr class="audit-row ' + sevClass + baselineClass + '" data-baseline-status="' + escA(d.baselineStatus || '') + '">'
      + '<td class="audit-col-file audit-clickable" data-path="' + escA(d.filePath) + '" data-line="' + d.line + '">' + esc(rel) + '</td>'
      + '<td class="audit-col-line">' + d.line + ':' + d.column + '</td>'
      + '<td class="audit-col-rule"><code>' + esc(d.ruleName) + '</code>' + statusBadge + '</td>'
      + '<td class="audit-col-severity"><span class="audit-sev-pill ' + sevClass + '">' + esc(d.severity) + '</span></td>'
      + '<td class="audit-col-tier">' + esc(d.tier || '') + '</td>'
      + '<td class="audit-col-message">' + esc(d.problemMessage || '') + '</td>'
      + '</tr>';
  }

  function esc(s) { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function escA(s) { return s.replace(/&/g,'&amp;').replace(/"/g,'&quot;'); }
  function sevRank(s) { return s === 'error' ? 3 : s === 'warning' ? 2 : s === 'info' ? 1 : 0; }

  // Lazily load the full diagnostics payload when it was too large to
  // inline (>10MB — see MAX_INLINE_BYTES in audit-report-panel.ts). The
  // CSP's connect-src allows fetching webview-resolved resource URIs only.
  if (DEFERRED_URI) {
    const banner = document.getElementById('audit-loading-banner');
    fetch(DEFERRED_URI)
      .then(r => r.json())
      .then(data => {
        ALL_DIAGNOSTICS = data;
        shownCount = Math.min(PAGE_SIZE, ALL_DIAGNOSTICS.length);
        if (banner) banner.hidden = true;
        rerender();
      })
      .catch(() => {
        // Leave the first-page data in place; note the failure so the
        // "N findings" count doesn't silently look wrong to the user.
        if (banner) banner.textContent = banner.dataset.failMessage || banner.textContent;
      });
  }
})();`;
}

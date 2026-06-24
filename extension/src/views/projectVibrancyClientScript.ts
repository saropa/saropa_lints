/**
 * Client-side script for the Project Vibrancy / Code Health report webview, plus
 * the two string-data tables it interpolates (UI strings + flag descriptors).
 * Split out of projectVibrancyReportView.ts so the ~530-line script string lives
 * apart from the panel controller and HTML builders.
 */

import { getKeyboardShortcutsScript } from './keyboard-shortcuts';
import { l10n } from '../i18n/runtime';

function codeHealthScriptStrings(): Record<string, string> {
  return {
    activeFiltersLabel: l10n('codeHealth.script.activeFiltersLabel'),
    clearAll: l10n('codeHealth.script.clearAll'),
    expanderCollapsed: l10n('codeHealth.table.expanderAriaCollapsed'),
    expanderExpanded: l10n('codeHealth.table.expanderAriaExpanded'),
    detailHeading: l10n('codeHealth.table.detailHeading'),
    detailNoIssues: l10n('codeHealth.table.detailNoIssues'),
    suppressLabel: l10n('codeHealth.table.suppressLabel'),
    suppressTooltip: l10n('codeHealth.table.suppressTooltip'),
  };
}

/**
 * Localized descriptors for each flag, shipped to the client so each pill can
 * carry its evidence inline (e.g. `complex (CC 36)`) AND so the expanded detail
 * row can name the rule that fired (`Flagged when cyclomatic complexity > 10`).
 * The `evidence` template uses {cc}/{pct} tokens substituted per-row at render
 * time — knowing the threshold matters more than knowing the label.
 */
function codeHealthFlagDescriptors(): Record<string, { label: string; evidence: string; rule: string }> {
  const keys = [
    'unused', 'uncovered', 'complex', 'undocumented',
    'test_drift', 'stub_tested', 'suspicious_coverage',
  ];
  const out: Record<string, { label: string; evidence: string; rule: string }> = {};
  for (const k of keys) {
    out[k] = {
      label: l10n('codeHealth.flag.' + k + '.label'),
      evidence: l10n('codeHealth.flag.' + k + '.evidence'),
      rule: l10n('codeHealth.flag.' + k + '.rule'),
    };
  }
  return out;
}

/** Inline client script — sort, search filter, KPI flag-filter, file-link nav, toolbar buttons. */
export function buildClientScript(): string {
  const CH = codeHealthScriptStrings();
  const FLAGS = codeHealthFlagDescriptors();
  return `
(function() {
  var CH = ${JSON.stringify(CH)};
  var FLAG_DESC = ${JSON.stringify(FLAGS)};
  var vscode = acquireVsCodeApi();

  // Row data is parsed once from the JSON script block. The previous design
  // server-rendered 18,000+ <tr> elements into the DOM up front and locked the
  // browser; this approach holds rows in memory, renders a 500-row window,
  // and runs filter/sort on the array (cheap) before re-rendering.
  var dataEl = document.getElementById('pvRowData');
  var allRows = [];
  try { allRows = JSON.parse(dataEl ? dataEl.textContent : '[]'); }
  catch (e) { allRows = []; }

  var RENDER_CHUNK = 500;
  var state = {
    search: '',
    // Multi-flag set: KPI cards add/remove membership (intersection — every
    // active flag must be present on the row). A single-flag mutual-exclusive
    // state was less useful: "show me unused AND complex" is a common ask.
    flags: Object.create(null),
    flagCount: 0,
    // Numeric score cap. null = no limit. Common values: 30 (worst third),
    // 50 (D/E/F problem grades).
    scoreMax: null,
    sortKey: 'score', sortAsc: true,
    hideBoilerplate: true,
    visibleCount: RENDER_CHUNK,
    // Per-row expansion: rowKey(r) of any rows the user has expanded to read
    // the "why scored low" detail. Set (not array) so re-renders after sort or
    // filter restore the open state in O(1) per row.
    expanded: Object.create(null)
  };
  var filtered = [];

  // Names that dominate a "worst functions" list because they are tiny,
  // uncovered, and rarely called — but where touching them rarely improves
  // anything. Hidden by default; toggle uncheck to see them.
  var BOILERPLATE_NAMES = {
    'hashCode': 1, 'toString': 1, 'noSuchMethod': 1,
    'copyWith': 1, 'props': 1,
    'fromJson': 1, 'toJson': 1, 'fromMap': 1, 'toMap': 1
  };
  function isBoilerplate(name) {
    if (!name) return false;
    if (BOILERPLATE_NAMES[name]) return true;
    if (!/^[A-Za-z_$]/.test(name)) return true; // operator overrides
    return false;
  }
  function displayName(name) {
    if (!name) return '';
    return /^[A-Za-z_$]/.test(name) ? name : 'operator ' + name;
  }
  function rowKey(r) { return r.file + ':' + r.lineStart + ':' + r.name; }

  function hslForScore(s) {
    var c = Math.max(0, Math.min(100, s));
    return 'hsl(' + Math.round((c / 100) * 130) + ', 70%, 50%)';
  }
  function fmtAge(epochSec) {
    if (!epochSec) return '—';
    var sec = Math.max(0, Math.floor(Date.now() / 1000 - epochSec));
    if (sec < 60) return 'now';
    if (sec < 3600) return Math.floor(sec / 60) + 'm';
    if (sec < 86400) return Math.floor(sec / 3600) + 'h';
    var days = Math.floor(sec / 86400);
    if (days < 14) return days + 'd';
    if (days < 60) return Math.floor(days / 7) + 'w';
    if (days < 365) return Math.floor(days / 30) + 'mo';
    return Math.floor(days / 365) + 'y';
  }
  function esc(s) {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function compileFiltered() {
    var q = state.search;
    var flagSet = state.flags;
    var flagCount = state.flagCount;
    var scoreMax = state.scoreMax;
    var hideBp = state.hideBoilerplate;
    filtered = allRows.filter(function(r) {
      if (hideBp && isBoilerplate(r.name)) return false;
      if (scoreMax !== null && r.score > scoreMax) return false;
      if (flagCount > 0) {
        // AND-intersection: every active flag must be present on the row.
        for (var f in flagSet) {
          if (r.flags.indexOf(f) === -1) return false;
        }
      }
      if (q) {
        var hay = (r.name + ' ' + r.file + ' ' + r.flags.join(' ')).toLowerCase();
        if (hay.indexOf(q) === -1) return false;
      }
      return true;
    });
    sortFiltered();
  }
  function sortVal(r, key) {
    switch (key) {
      case 'score': return r.score;
      case 'name': return (r.name || '').toLowerCase();
      case 'file': return (r.file || '').toLowerCase();
      case 'line': return r.lineStart;
      case 'usage': return r.usageCount;
      case 'coverage': return r.coveragePercent;
      case 'complexity': return r.complexity;
      case 'changed': return r.lastChangedEpochSec || 0;
      default: return 0;
    }
  }
  function sortFiltered() {
    var key = state.sortKey, asc = state.sortAsc;
    filtered.sort(function(a, b) {
      var av = sortVal(a, key), bv = sortVal(b, key);
      var c = (typeof av === 'number' && typeof bv === 'number')
        ? av - bv
        : String(av).localeCompare(String(bv));
      return asc ? c : -c;
    });
  }

  // Resolve a flag's i18n descriptor and substitute per-row tokens. Returns
  // { label, evidence, rule } — evidence is the inline "why" carried on the
  // pill, rule is the threshold sentence shown in the expanded detail panel.
  // Unknown flags fall back to the bare flag name so a future CLI flag can't
  // crash the renderer.
  function flagInfo(f, r) {
    var d = FLAG_DESC[f];
    if (!d) return { label: f.replace(/_/g, ' '), evidence: '', rule: '' };
    var pct = Math.round(r.coveragePercent || 0);
    var cc = r.complexity != null ? r.complexity : 0;
    var evidence = d.evidence
      .replace('{cc}', String(cc))
      .replace('{pct}', String(pct));
    return { label: d.label, evidence: evidence, rule: d.rule };
  }

  function rowHtml(r) {
    var scoreInt = Math.round(r.score);
    var color = hslForScore(scoreInt);
    var name = displayName(r.name);
    var cut = r.file.lastIndexOf('/');
    var dir = cut >= 0 ? r.file.slice(0, cut + 1) : '';
    var base = cut >= 0 ? r.file.slice(cut + 1) : r.file;
    var changedTxt = fmtAge(r.lastChangedEpochSec);
    var changedIso = r.lastChangedEpochSec
      ? new Date(r.lastChangedEpochSec * 1000).toISOString()
      : 'No git history available';
    var key = rowKey(r);
    var isOpen = !!state.expanded[key];
    var flagPills = r.flags.map(function(f) {
      var info = flagInfo(f, r);
      var ev = info.evidence ? ' <span class="flag-evidence">(' + esc(info.evidence) + ')</span>' : '';
      var title = info.rule ? ' title="' + esc(info.rule) + '"' : '';
      return '<span class="flag-pill ' + esc(f) + '"' + title + '>' + esc(info.label) + ev + '</span>';
    }).join(' ');
    var expLabel = isOpen ? CH.expanderExpanded : CH.expanderCollapsed;
    var expander =
      '<button type="button" class="row-expander' + (isOpen ? ' open' : '') +
      '" data-row-key="' + esc(key) + '" aria-expanded="' + (isOpen ? 'true' : 'false') +
      '" aria-controls="pv-detail-' + esc(key) + '" aria-label="' + esc(expLabel) + '" title="' + esc(expLabel) + '">' +
      '<span class="chev" aria-hidden="true"></span></button>';
    return '<tr data-key="' + esc(key) + '">' +
      '<td class="col-score">' + expander +
      '<span class="score-pill" style="background:' + color + ';color:#000;" title="Score ' + scoreInt + '/100">' + scoreInt + '</span></td>' +
      '<td class="col-name"><span class="fn-link" data-file="' + esc(r.file) + '" data-line="' + r.lineStart + '" title="Open at line ' + r.lineStart + '">' + esc(name) + '</span></td>' +
      '<td class="col-file"><span class="file-link" data-file="' + esc(r.file) + '" data-line="' + r.lineStart + '" title="' + esc(r.file) + '"><span class="path-dir">' + esc(dir) + '</span><span class="path-base">' + esc(base) + '</span></span></td>' +
      '<td class="col-line">' + r.lineStart + '-' + r.lineEnd + '</td>' +
      '<td class="col-usage">' + r.usageCount.toLocaleString('en-US') + '</td>' +
      '<td class="col-coverage">' + Math.round(r.coveragePercent) + '%</td>' +
      '<td class="col-complexity">' + r.complexity + '</td>' +
      '<td class="col-changed" title="' + esc(changedIso) + '">' + esc(changedTxt) + '</td>' +
      '<td class="col-flags"><span class="flag-pills">' + flagPills + '</span></td>' +
      '</tr>';
  }

  // Inline detail row rendered immediately after its parent when expanded.
  // colspan spans the full table width so the panel reads as a single block
  // instead of fragmenting into 9 cells. The "rule" text answers the user's
  // actual question — WHY did this function land on the worst list — rather
  // than restating column values they can already see above.
  function detailRowHtml(r) {
    var key = rowKey(r);
    var scoreInt = Math.round(r.score);
    var heading = CH.detailHeading.replace('{score}', String(scoreInt));
    var items;
    if (!r.flags || r.flags.length === 0) {
      items = '<p class="pv-detail-empty">' + esc(CH.detailNoIssues) + '</p>';
    } else {
      var parts = r.flags.map(function(f) {
        var info = flagInfo(f, r);
        var ev = info.evidence ? '<span class="pv-detail-evidence">' + esc(info.evidence) + '</span>' : '';
        // The suppress button writes a // ignore_for_file: code_health:<flag>
        // directive into the file so the next scan drops this flag for the
        // whole file. Per-function suppression is intentionally NOT offered
        // here — the dashboard's "your file, your call" model is file-scoped.
        var suppressBtn = '<button type="button" class="pv-suppress-btn"' +
          ' data-suppress-file="' + esc(r.file) + '"' +
          ' data-suppress-flag="' + esc(f) + '"' +
          ' title="' + esc(CH.suppressTooltip) + '">' +
          esc(CH.suppressLabel) + '</button>';
        return '<li class="pv-detail-item ' + esc(f) + '">' +
          '<span class="pv-detail-label">' + esc(info.label) + '</span>' + ev +
          (info.rule ? '<span class="pv-detail-rule">' + esc(info.rule) + '</span>' : '') +
          suppressBtn +
          '</li>';
      });
      items = '<ul class="pv-detail-list">' + parts.join('') + '</ul>';
    }
    return '<tr class="pv-detail-row" id="pv-detail-' + esc(key) + '" data-detail-for="' + esc(key) + '">' +
      '<td colspan="9"><div class="pv-detail-panel">' +
      '<h4 class="pv-detail-heading">' + esc(heading) + '</h4>' + items +
      '</div></td></tr>';
  }

  function render() {
    var tbody = document.getElementById('pvBody');
    if (!tbody) return;
    var slice = filtered.slice(0, state.visibleCount);
    // innerHTML is the fast path for a wholesale rebuild — appendChild'ing
    // hundreds of <tr>s individually triggers a layout per insert. Each row is
    // followed by its detail panel iff state.expanded[key] is set, so sort and
    // filter operations preserve open panels (single source of truth).
    var html = [];
    for (var i = 0; i < slice.length; i++) {
      var row = slice[i];
      html.push(rowHtml(row));
      if (state.expanded[rowKey(row)]) html.push(detailRowHtml(row));
    }
    tbody.innerHTML = html.join('');
    var countEl = document.getElementById('pvShownCount');
    if (countEl) {
      var totalStr = allRows.length.toLocaleString('en-US');
      var shownStr = slice.length.toLocaleString('en-US');
      var filtStr = filtered.length.toLocaleString('en-US');
      countEl.textContent = (filtered.length === allRows.length)
        ? 'showing ' + shownStr + ' of ' + totalStr
        : 'showing ' + shownStr + ' of ' + filtStr + ' (filtered from ' + totalStr + ')';
    }
    var loadMore = document.getElementById('pvLoadMore');
    if (loadMore) {
      loadMore.hidden = slice.length >= filtered.length;
      var btn = document.getElementById('pvLoadMoreBtn');
      if (btn) {
        var remaining = filtered.length - slice.length;
        var next = Math.min(RENDER_CHUNK, remaining);
        btn.textContent = 'Show next ' + next.toLocaleString('en-US') +
          ' (' + remaining.toLocaleString('en-US') + ' more)';
      }
    }
    var emptyEl = document.getElementById('pvEmpty');
    if (emptyEl) emptyEl.hidden = !(filtered.length === 0 && allRows.length > 0);
    updateSortArrows();
    updateCopyButton();
  }
  function updateSortArrows() {
    var ths = document.querySelectorAll('th.sortable[data-sort]');
    for (var i = 0; i < ths.length; i++) {
      var th = ths[i];
      var col = th.getAttribute('data-sort');
      th.setAttribute('aria-sort',
        col === state.sortKey ? (state.sortAsc ? 'ascending' : 'descending') : 'none');
    }
  }
  function applyAll() {
    compileFiltered();
    state.visibleCount = RENDER_CHUNK;
    render();
    renderStrip();
    announce(filtered.length + ' of ' + allRows.length + ' rows match');
  }

  // --- Toolbar wiring ----------------------------------------------------
  function postCmd(type) { vscode.postMessage({ type: type }); }
  document.getElementById('rescan').addEventListener('click', function() { postCmd('rescan'); });
  document.getElementById('copyJson').addEventListener('click', function() { postCmd('copyJson'); });
  document.getElementById('openPvSettings').addEventListener('click', function() { postCmd('openProjectVibrancySettings'); });
  function wireReportBtn(id, type) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('click', function() { postCmd(type); });
  }
  wireReportBtn('copyReportPath', 'copyReportPath');
  wireReportBtn('openReportFile', 'openReportFile');
  wireReportBtn('revealReportFile', 'revealReportFile');
  var rfPath = document.getElementById('reportFilePath');
  if (rfPath) {
    rfPath.addEventListener('click', function() { postCmd('copyReportPath'); });
    rfPath.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); postCmd('copyReportPath'); }
    });
  }
  document.querySelectorAll('[data-cmd]').forEach(function(b) {
    b.addEventListener('click', function() { postCmd(b.getAttribute('data-cmd')); });
  });

  var searchEl = document.getElementById('pvSearch');
  searchEl.addEventListener('input', function() {
    state.search = (searchEl.value || '').trim().toLowerCase();
    applyAll();
  });
  var hideBpEl = document.getElementById('hideBoilerplate');
  if (hideBpEl) {
    hideBpEl.addEventListener('change', function() {
      state.hideBoilerplate = hideBpEl.checked;
      applyAll();
    });
  }
  // KPI tiles are multi-select: click multiple to AND them (e.g. unused AND
  // complex). Click an active tile again to remove it. Previously the cards
  // were mutually-exclusive single-select, which made the obvious "find
  // unused-and-complex" query impossible.
  document.querySelectorAll('.kpi-card.interactive[data-flag-filter]').forEach(function(card) {
    card.addEventListener('click', function() {
      if (card.disabled) return;
      var key = card.getAttribute('data-flag-filter');
      if (state.flags[key]) {
        delete state.flags[key];
        state.flagCount--;
        card.classList.remove('active');
      } else {
        state.flags[key] = true;
        state.flagCount++;
        card.classList.add('active');
      }
      applyAll();
    });
  });

  // Score-threshold input: empty = no cap; a number caps the table to rows
  // whose score is at or below it. Tries to parse so '30', '30.5', '  50 ' all
  // work, but ignores anything not numeric (the placeholder shows '—' as a
  // hint that empty means no limit).
  var scoreMaxEl = document.getElementById('pvScoreMax');
  if (scoreMaxEl) {
    scoreMaxEl.addEventListener('input', function() {
      var raw = (scoreMaxEl.value || '').trim();
      if (raw === '') { state.scoreMax = null; }
      else {
        var n = parseFloat(raw);
        state.scoreMax = (isFinite(n) && n >= 0 && n <= 100) ? n : null;
      }
      applyAll();
    });
  }
  // Column sort: click flips direction on the active column, otherwise sorts
  // the new column ascending (smallest/worst first).
  document.querySelectorAll('th.sortable[data-sort]').forEach(function(th) {
    th.addEventListener('click', function() {
      var col = th.getAttribute('data-sort');
      if (state.sortKey === col) state.sortAsc = !state.sortAsc;
      else { state.sortKey = col; state.sortAsc = true; }
      sortFiltered();
      state.visibleCount = RENDER_CHUNK;
      render();
    });
  });
  var loadMoreBtn = document.getElementById('pvLoadMoreBtn');
  if (loadMoreBtn) {
    loadMoreBtn.addEventListener('click', function() {
      state.visibleCount = Math.min(state.visibleCount + RENDER_CHUNK, filtered.length);
      render();
    });
  }
  var resetEmptyBtn = document.getElementById('pvResetFilters');
  if (resetEmptyBtn) resetEmptyBtn.addEventListener('click', resetFilters);
  function resetFilters() {
    state.search = '';
    state.flags = Object.create(null);
    state.flagCount = 0;
    state.scoreMax = null;
    searchEl.value = '';
    if (scoreMaxEl) scoreMaxEl.value = '';
    document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    applyAll();
  }

  // --- Filter-driven bulk copy ------------------------------------------
  // No selection checkboxes — the filters ARE the selection. *Copy filtered*
  // dumps every currently-visible row. The button label shows the live count
  // so the user knows how many rows they're about to copy before clicking.
  function updateCopyButton() {
    var btn = document.getElementById('copyFiltered');
    if (!btn) return;
    if (filtered.length === 0) {
      btn.textContent = 'Copy filtered';
      btn.setAttribute('disabled', '');
    } else {
      btn.textContent = 'Copy filtered (' + filtered.length.toLocaleString('en-US') + ')';
      btn.removeAttribute('disabled');
    }
  }

  var tbody = document.getElementById('pvBody');
  if (tbody) {
    // Delegated click handler: row-expander toggles the detail panel,
    // fn-link / file-link open the file at its line. Expander wins when its
    // ancestor chain matches because the button sits INSIDE the score cell
    // alongside the score pill — without the early-return the click would
    // fall through to no-op (score pill has no data-file).
    tbody.addEventListener('click', function(e) {
      var target = e.target;
      // Climb to a known affordance: row-expander, suppress button, or link.
      // The suppress button MUST be matched before bubbling to fn-link / file-
      // link checks because it can sit inside the detail panel below a row.
      var node = target;
      while (node && node !== tbody) {
        if (node.classList) {
          if (node.classList.contains('pv-suppress-btn')) {
            e.preventDefault();
            e.stopPropagation();
            var sFile = node.getAttribute('data-suppress-file');
            var sFlag = node.getAttribute('data-suppress-flag');
            if (!sFile || !sFlag) return;
            vscode.postMessage({ type: 'suppressFlag', file: sFile, flag: sFlag });
            return;
          }
          if (node.classList.contains('row-expander')) {
            e.preventDefault();
            var key = node.getAttribute('data-row-key');
            if (!key) return;
            if (state.expanded[key]) delete state.expanded[key];
            else state.expanded[key] = true;
            render();
            return;
          }
          if (node.classList.contains('fn-link') || node.classList.contains('file-link')) {
            var file = node.getAttribute('data-file');
            var line = Number(node.getAttribute('data-line') || '1');
            if (!file) return;
            vscode.postMessage({ type: 'openFile', file: file, line: line });
            return;
          }
        }
        node = node.parentNode;
      }
    });
  }

  // Bulk-copy format for LLM/chat paste: one line per row, file:line first
  // (clickable in most tools), then function name, then score + flags in
  // parentheses. Copies EVERY filtered row — filter narrows, button dumps.
  document.getElementById('copyFiltered').addEventListener('click', function() {
    if (filtered.length === 0) return;
    var lines = [];
    for (var i = 0; i < filtered.length; i++) {
      var r = filtered[i];
      var meta = ['score ' + Math.round(r.score)];
      if (r.flags && r.flags.length) meta.push(r.flags.join(', '));
      lines.push(r.file + ':' + r.lineStart + '  ' + displayName(r.name) +
        '  (' + meta.join(', ') + ')');
    }
    vscode.postMessage({ type: 'copyText', text: lines.join('\\n') });
  });

  // --- Active-filter strip ---------------------------------------------
  var stripEl = document.getElementById('filter-strip');
  function renderStrip() {
    if (!stripEl) return;
    // chip.key is the dismiss target: 'search', 'score', or 'flag:<name>' so
    // the X removes that specific filter only.
    var chips = [];
    if (state.search) chips.push({ key: 'search', label: 'search: "' + esc(state.search) + '"' });
    if (state.scoreMax !== null) chips.push({ key: 'score', label: 'score ≤ ' + state.scoreMax });
    for (var f in state.flags) {
      chips.push({ key: 'flag:' + f, label: 'flag: ' + f.replace(/_/g, ' ') });
    }
    if (chips.length === 0) { stripEl.hidden = true; stripEl.innerHTML = ''; return; }
    stripEl.hidden = false;
    var parts = ['<span class="lbl">' + esc(CH.activeFiltersLabel) + '</span>'];
    chips.forEach(function(chip) {
      parts.push('<span class="chip">' + chip.label +
        '<button type="button" class="x" data-chip="' + esc(chip.key) +
        '" aria-label="Remove filter">×</button></span>');
    });
    parts.push('<button type="button" class="clear-all" id="clear-all-filters">' + esc(CH.clearAll) + '</button>');
    stripEl.innerHTML = parts.join('');
    stripEl.querySelectorAll('.chip .x').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var k = btn.getAttribute('data-chip') || '';
        if (k === 'search') { state.search = ''; searchEl.value = ''; }
        else if (k === 'score') { state.scoreMax = null; if (scoreMaxEl) scoreMaxEl.value = ''; }
        else if (k.indexOf('flag:') === 0) {
          var name = k.slice(5);
          if (state.flags[name]) { delete state.flags[name]; state.flagCount--; }
          var card = document.querySelector('.kpi-card.active[data-flag-filter="' + name + '"]');
          if (card) card.classList.remove('active');
        }
        applyAll();
      });
    });
    document.getElementById('clear-all-filters').addEventListener('click', resetFilters);
  }

  function announce(message) {
    var el = document.getElementById('announcer');
    if (!el) return;
    el.textContent = '';
    setTimeout(function() { el.textContent = message; }, 50);
  }

  document.addEventListener('keydown', function(e) {
    var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
    var isEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === '/' && !isEditable) {
      e.preventDefault();
      if (searchEl) { searchEl.focus(); searchEl.select && searchEl.select(); }
    } else if (e.key === 'Escape' && e.target === searchEl && searchEl && searchEl.value) {
      e.preventDefault();
      searchEl.value = '';
      state.search = '';
      applyAll();
    }
  });

  compileFiltered();
  render();
  updateCopyButton();
  ${getKeyboardShortcutsScript()}
})();
`;
}

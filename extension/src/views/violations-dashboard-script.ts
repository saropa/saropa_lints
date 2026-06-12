/**
 * Client-side script for the editor-area Saropa Violations Dashboard.
 *
 * Extracted from violationsDashboardHtml.ts so the markup builder reads as
 * composition rather than a wall of embedded JS. This module holds the ~800-line
 * webview client script (debounced filters, sortable table, KPI clicks, chip
 * removal, group-row collapse, save/copy, drift, suppressions), the l10n string
 * map it inlines, and the default severity/impact arrays it seeds panel state
 * with. `buildScript()` returns the script body for the host HTML's
 * <script nonce> tag; nothing else consumes these symbols.
 */

import { l10n } from '../i18n/runtime';
import { getAnnouncerScript, getFullWidthToggleScript } from './dashboardHero';
import { getKeyboardShortcutsScript } from './keyboard-shortcuts';

/** Client-script strings (embedded webview JS); resolved at host HTML build time. */
function findingsDashScriptStrings(): Record<string, string> {
    return {
        analysisRunning: l10n('loading.runningAnalysis'),
        analysisComplete: l10n('loading.analysisComplete'),
        metaRunning: l10n('findingsDash.progress.runningMeta'),
        metaDone: l10n('loading.refreshingDashboard'),
        metaFailed: l10n('loading.analysisFailedDetail'),
        metaStartedDetail: l10n('loading.analysisStartedDetail'),
        announceSearchVerb: l10n('findingsDash.script.announceSearchVerb'),
        severitiesNoun: l10n('findingsDash.script.severitiesNoun'),
        impactsNoun: l10n('findingsDash.script.impactsNoun'),
        announceCleared: l10n('findingsDash.script.announceCleared'),
        filtersPrefix: l10n('findingsDash.script.announceFiltersPrefix'),
        announceStarted: l10n('findingsDash.script.announceStarted'),
        announceComplete: l10n('findingsDash.script.announceComplete'),
        announceFailed: l10n('findingsDash.script.announceFailed'),
        removeRecentTitle: l10n('findingsDash.script.removeRecentTitle'),
        removeRecentAriaPrefix: l10n('findingsDash.script.removeRecentAria'),
        bulkSelectedTpl: l10n('findingsDash.script.bulkSelectedTpl'),
    };
}

const DEFAULT_SEVERITIES: readonly string[] = ['error', 'warning', 'info'];
// Three-bucket severity model — collapsed from the prior 5-bucket
// (critical/high/medium/low/opinionated) impact taxonomy on 2026-05-03;
// see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md. DEFAULT_IMPACTS mirrors
// DEFAULT_SEVERITIES exactly and is only embedded in the webview JS state
// payload for back-compat with stored panel state; no UI surface solicits
// impact toggles anymore.
const DEFAULT_IMPACTS: readonly string[] = ['error', 'warning', 'info'];

/* ============================================================================
 * Inline client script — debounced filters, sortable table, KPI clicks,
 * chip removal, group-row collapse, save/copy, drift, suppressions.
 * ========================================================================= */

export function buildScript(): string {
  const FD = findingsDashScriptStrings();
  return `(function () {
  var vscode = acquireVsCodeApi();
  var FD = ${JSON.stringify(FD)};
  var filterDebounce = null;
  var isAnalyzing = false;

  // §15.3 — polite live-region announcer for filter / sort state changes.
  ${getAnnouncerScript()}

  function readState() {
    var gb = document.getElementById('groupBy');
    var tf = document.getElementById('textFilter');
    var sev = [];
    document.querySelectorAll('.seg-btn[data-sev][aria-pressed="true"]').forEach(function (el) {
      sev.push(el.getAttribute('data-sev'));
    });
    // Impact pills were removed (post-collapse impact mirrors severity).
    // Send the default all-impacts-on list so the host-side merge that
    // still accepts an impacts field treats it as "no filter applied".
    return {
      type: 'dashboardUpdate',
      groupBy: gb ? gb.value : undefined,
      textFilter: tf ? tf.value : '',
      severities: sev.length ? sev : ${JSON.stringify(DEFAULT_SEVERITIES)},
      impacts: ${JSON.stringify(DEFAULT_IMPACTS)}
    };
  }

  function pushState(immediate) {
    if (filterDebounce) { clearTimeout(filterDebounce); filterDebounce = null; }
    if (immediate) { vscode.postMessage(readState()); announceFilterState(); return; }
    filterDebounce = setTimeout(function () {
      vscode.postMessage(readState());
      announceFilterState();
    }, 220);
  }

  /* Gauge "pending" state — dims the ring and hides the grade while analysis
     is in flight, so a transient not-yet-settled health score never flashes a
     misleading grade (the A→E whiplash). No explicit clear is needed for the
     normal path: every host rebuild ships a fresh gauge with data-pending
     already "false", so the settled grade reveals itself on the next paint. */
  function setGaugePending(on) {
    var g = document.querySelector('.hero-gauge');
    if (g) g.setAttribute('data-pending', on ? 'true' : 'false');
  }

  function setAnalysisProgress(running, metaText) {
    isAnalyzing = running;
    setGaugePending(running);
    var box = document.getElementById('analysis-progress');
    var label = document.getElementById('analysis-progress-label');
    var meta = document.getElementById('analysis-progress-meta');
    if (box) box.hidden = !running;
    if (label) label.textContent = running ? FD.analysisRunning : FD.analysisComplete;
    if (meta) {
      meta.textContent = metaText || (running ? FD.metaRunning : FD.metaDone);
    }
    document.querySelectorAll('[data-run-analysis]').forEach(function (el) {
      if ('disabled' in el) {
        el.disabled = running;
      }
      if (running) {
        el.setAttribute('aria-disabled', 'true');
      } else {
        el.removeAttribute('aria-disabled');
      }
    });
  }

  function triggerRunAnalysis() {
    if (isAnalyzing) return;
    setAnalysisProgress(true);
    vscode.postMessage({ type: 'runAnalysis' });
  }

  // §15.3 — describe the current filter state to screen readers so users
  // navigating without a mouse know which constraints are active.
  function announceFilterState() {
    var s = readState();
    var parts = [];
    if (s.textFilter) { parts.push(FD.announceSearchVerb + ' ' + s.textFilter); }
    var sevDefaults = ${JSON.stringify(DEFAULT_SEVERITIES)}.length;
    if (s.severities.length !== sevDefaults) {
      parts.push(s.severities.length + ' ' + FD.severitiesNoun);
    }
    // Impact divergence-announcement was removed alongside the impact
    // pill UI; readState always emits the default all-impacts-on list,
    // so the branch would be permanently dead.
    if (parts.length === 0) {
      announce(FD.announceCleared);
    } else {
      announce(FD.filtersPrefix + ' ' + parts.join(', '));
    }
  }

  /* Filter inputs */
  var gb = document.getElementById('groupBy');
  if (gb) gb.addEventListener('change', function () { pushState(true); });
  var tf = document.getElementById('textFilter');

  /* §8.5.2 — recent-filters popover. Stored in sessionStorage so the list
     survives within the current panel session; cross-session persistence
     is tracked in plan/UX_GUIDELINES.md (Part B). */
  var recentEl = document.getElementById('findings-recent');
  var recentListEl = document.getElementById('findings-recent-list');
  var recentClearAllEl = document.getElementById('findings-recent-clear');
  var RECENT_KEY = 'saropa.findings.recentFilters';
  var RECENT_CAP = 10;
  var RECENT_DEBOUNCE_MS = 800;
  var recentTimer = null;

  function findingsRecentPersist() {
    try { vscode.postMessage({ type: 'saveFindingsRecent', queries: recentLoad() }); } catch (_) {}
  }

  window.addEventListener('message', function (event) {
    var m = event.data;
    if (m && m.type === 'hydrateRecentSearches' && Array.isArray(m.queries) && m.queries.length > 0) {
      recentSave(m.queries.slice(0, RECENT_CAP), true);
      recentRender();
    }
  });

  function recentLoad() {
    try {
      var raw = sessionStorage.getItem(RECENT_KEY);
      if (!raw) return [];
      var parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.filter(function (s) { return typeof s === 'string'; }) : [];
    } catch (e) { return []; }
  }
  function recentSave(list, skipHost) {
    try { sessionStorage.setItem(RECENT_KEY, JSON.stringify(list)); } catch (e) { /* best-effort */ }
    if (!skipHost) { findingsRecentPersist(); }
  }
  function recentRecord(q) {
    var t = (q || '').trim();
    if (!t) return;
    var existing = recentLoad().filter(function (s) { return s.toLowerCase() !== t.toLowerCase(); });
    existing.unshift(t);
    recentSave(existing.slice(0, RECENT_CAP));
  }
  function recentRemove(q) {
    recentSave(recentLoad().filter(function (s) { return s !== q; }));
    recentRender();
  }
  function recentClearAll() { recentSave([]); recentRender(); recentHide(); }
  function recentEsc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function recentRender() {
    if (!recentListEl) return;
    var list = recentLoad();
    if (list.length === 0) { recentListEl.innerHTML = ''; return; }
    recentListEl.innerHTML = list.map(function (q) {
      var s = recentEsc(q);
      return '<li>' +
        '<button type="button" class="recent-pick" data-query="' + s + '">' + s + '</button>' +
        '<button type="button" class="recent-remove" data-query="' + s +
        '" aria-label="' + FD.removeRecentAriaPrefix + ' ' + s + '" title="' + FD.removeRecentTitle + '">&times;</button>' +
        '</li>';
    }).join('');
  }
  function recentShow() {
    if (!recentEl) return;
    var list = recentLoad();
    if (list.length === 0) { recentEl.hidden = true; return; }
    recentRender();
    recentEl.hidden = false;
  }
  function recentHide() { if (recentEl) recentEl.hidden = true; }
  function recentMaybeShow() {
    if (!tf) return;
    if (document.activeElement === tf && !tf.value.trim()) recentShow();
    else recentHide();
  }

  if (tf) {
    tf.addEventListener('input', function () {
      pushState(false);
      recentMaybeShow();
      // Debounced commit so transient keystrokes don't spam the recent list.
      if (recentTimer) clearTimeout(recentTimer);
      var snapshot = tf.value;
      recentTimer = setTimeout(function () {
        recentTimer = null;
        if (snapshot && tf.value === snapshot) recentRecord(snapshot);
      }, RECENT_DEBOUNCE_MS);
    });
    tf.addEventListener('focus', recentMaybeShow);
    tf.addEventListener('blur', function () { setTimeout(recentHide, 120); });
    tf.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && tf.value.trim()) { recentRecord(tf.value); recentHide(); }
      else if (e.key === 'Escape' && recentEl && !recentEl.hidden) { e.preventDefault(); recentHide(); }
    });
  }
  if (recentListEl) {
    recentListEl.addEventListener('click', function (e) {
      var t = e.target;
      if (!t || !t.dataset || !t.dataset.query) return;
      var q = t.dataset.query;
      if (t.classList.contains('recent-pick')) {
        if (tf) { tf.value = q; pushState(true); recentRecord(q); recentHide(); tf.focus(); }
      } else if (t.classList.contains('recent-remove')) {
        e.stopPropagation();
        recentRemove(q);
        if (tf) tf.focus();
      }
    });
  }
  if (recentClearAllEl) recentClearAllEl.addEventListener('click', recentClearAll);
  document.addEventListener('click', function (e) {
    if (!recentEl || recentEl.hidden) return;
    var wrapper = tf && tf.closest ? tf.closest('.text-filter-field') : null;
    if (wrapper && !wrapper.contains(e.target)) recentHide();
  });

  var tfClear = document.getElementById('textFilterClear');
  if (tfClear) tfClear.addEventListener('click', function () {
    if (tf) { tf.value = ''; pushState(true); recentMaybeShow(); }
  });
  // Impact-pill click branch was removed alongside the impact toolbar row.
  // The selector is now severity-only.
  document.querySelectorAll('.seg-btn[data-sev]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var pressed = btn.getAttribute('aria-pressed') === 'true';
      btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
      pushState(true);
    });
  });

  /* Toolbar primary actions */
  bindClick('btn-run', triggerRunAnalysis);
  // Refresh was promoted out of the toolbar (it was indistinguishable from
  // Run analysis but only re-rendered from disk). The hidden #btn-refresh
  // stub keeps test selectors / keybindings resolvable; the user-clickable
  // replacement is the "Reload from disk" item in the More menu's System
  // section. Both fire the same {type:'refresh'} message so any existing
  // host-side handler keeps working unchanged.
  bindClick('btn-refresh', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-reload-disk', function () {
    vscode.postMessage({ type: 'refresh' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  // Copy JSON / Save report now live inside the More-actions overflow menu
  // (§14.4 toolbar budget). Auto-close the menu after click so the user is
  // not left with an open dropdown obscuring the table.
  bindClick('btn-copy', function () {
    vscode.postMessage({ type: 'copyFilteredJson' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  bindClick('btn-save', function () {
    vscode.postMessage({ type: 'saveFilteredJson' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  bindClick('btn-refresh-extension', function () {
    vscode.postMessage({ type: 'paletteCommand', commandId: 'saropaLints.refresh' });
  });
  bindClick('btn-run-empty', triggerRunAnalysis);
  bindClick('btn-run-empty2', triggerRunAnalysis);
  bindClick('btn-refresh-empty', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-reset-empty', function () { vscode.postMessage({ type: 'resetFilters' }); });
  bindClick('run-again', triggerRunAnalysis);

  /* Supplementary-counts toggle pills (#224). Single delegated click handler
     for all three sources (other / todos / scanner) so we do not need to
     re-bind after every dashboard rebuild — the pills come and go as their
     state changes. Activate on Enter/Space too so the role="button" pills
     are keyboard-operable.  */
  function handleToggleEvent(target) {
    if (!target || typeof target.closest !== 'function') return;
    var pill = target.closest('.pill.toggle');
    if (!pill) return;
    var source = pill.getAttribute('data-toggle');
    if (!source) return;
    vscode.postMessage({ type: 'toggleSupplementary', source: source });
  }
  document.addEventListener('click', function (e) { handleToggleEvent(e.target); });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    var t = e.target;
    if (!t || typeof t.closest !== 'function') return;
    if (!t.closest('.pill.toggle')) return;
    e.preventDefault();
    handleToggleEvent(t);
  });

  /* More actions menu */
  document.querySelectorAll('.menu-item[data-palette-cmd]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var id = btn.getAttribute('data-palette-cmd');
      if (id) vscode.postMessage({ type: 'paletteCommand', commandId: id });
      var det = btn.closest('details.more');
      if (det) det.removeAttribute('open');
    });
  });
  /* Close menu on outside click */
  document.addEventListener('click', function (e) {
    document.querySelectorAll('details.more[open]').forEach(function (det) {
      if (!det.contains(e.target)) det.removeAttribute('open');
    });
  });

  /* KPI cards as preset filters */
  document.querySelectorAll('.kpi-card.interactive').forEach(function (card) {
    function fire() {
      var kind = card.getAttribute('data-kpi-kind');
      var v = card.getAttribute('data-kpi-value') || '';
      if (kind === 'reset') {
        vscode.postMessage({ type: 'resetFilters' });
        return;
      }
      if (kind === 'sev') {
        document.querySelectorAll('.seg-btn[data-sev]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-sev') === v ? 'true' : 'false');
        });
        pushState(true);
        return;
      }
      // KpiSpec.filter.kind === 'imp' branch was removed: collectKpiCards()
      // never emits an 'imp' KPI card since the Impact axis was retired.
      if (kind === 'top-rule') {
        var input = document.getElementById('textFilter');
        if (input) { input.value = v; pushState(true); }
      }
    }
    card.addEventListener('click', fire);
    card.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
    });
  });

  /* Chart bar clicks */
  document.querySelectorAll('.bar-row[role="button"]').forEach(function (row) {
    function fire() {
      var kind = row.getAttribute('data-filter-kind');
      var v = row.getAttribute('data-filter-value');
      // Only severity bars emit clickable rows now — the Impact-mix donut /
      // bars are gone.
      if (kind === 'sev') {
        document.querySelectorAll('.seg-btn[data-sev]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-sev') === v ? 'true' : 'false');
        });
      }
      pushState(true);
    }
    row.addEventListener('click', fire);
    row.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
    });
  });

  /* Active-filter chip removal */
  document.querySelectorAll('.chip').forEach(function (chip) {
    var x = chip.querySelector('.x');
    if (!x) return;
    x.addEventListener('click', function (e) {
      e.stopPropagation();
      var token = chip.getAttribute('data-chip-token') || '';
      if (token === 'text') {
        if (tf) { tf.value = ''; pushState(true); }
      } else if (token.indexOf('sev:') === 0) {
        var sv = token.slice(4);
        var btn = document.querySelector('.seg-btn[data-sev="' + sv + '"]');
        if (btn) { btn.setAttribute('aria-pressed', 'true'); pushState(true); }
      }
      // No 'imp:' branch — impact chips are no longer emitted from
      // buildChipStrip, so any imp: token in stored state is stale and
      // a no-op is the right behavior.
    });
  });
  bindClick('chipsClearAll', function () { vscode.postMessage({ type: 'resetFilters' }); });

  /* Group-row collapse / expand */
  document.querySelectorAll('tr.group-row').forEach(function (gr) {
    function toggle() {
      var open = gr.getAttribute('aria-expanded') !== 'false';
      gr.setAttribute('aria-expanded', open ? 'false' : 'true');
      var sib = gr.nextElementSibling;
      while (sib && !sib.classList.contains('group-row')) {
        sib.style.display = open ? 'none' : '';
        sib = sib.nextElementSibling;
      }
    }
    gr.addEventListener('click', toggle);
    gr.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); }
    });
  });
  bindClick('expand-all', function () {
    document.querySelectorAll('tr.group-row[aria-expanded="false"]').forEach(function (gr) { gr.click(); });
  });
  bindClick('collapse-all', function () {
    document.querySelectorAll('tr.group-row[aria-expanded="true"]').forEach(function (gr) { gr.click(); });
  });

  /* Sortable table headers — primary click sets key; Shift+click stacks a
     secondary tie-breaker (shows ① / ② badges). */
  var sortLevels = [];
  function rowSortVal(tr, sk) {
    var sevOrder = { error: 0, warning: 1, info: 2, note: 3 };
    if (sk === 'sev') return sevOrder[tr.getAttribute('data-sev')] || 99;
    if (sk === 'rule') return tr.getAttribute('data-rule') || '';
    if (sk === 'line') return parseInt(tr.getAttribute('data-line') || '0', 10);
    return (tr.querySelector('.vmsg') || {}).textContent || '';
  }
  function cmpRows(a, b, sk, asc) {
    var av = rowSortVal(a, sk);
    var bv = rowSortVal(b, sk);
    if (av < bv) return asc ? -1 : 1;
    if (av > bv) return asc ? 1 : -1;
    return 0;
  }
  function updateSortHeaderUi() {
    document.querySelectorAll('.findings-table thead th[data-sort]').forEach(function (h) {
      h.setAttribute('aria-sort', 'none');
      var idx = h.querySelector('.sort-idx');
      if (idx) idx.textContent = '';
    });
    for (var i = 0; i < sortLevels.length && i < 2; i++) {
      var lk = sortLevels[i].key;
      var th = document.querySelector('.findings-table thead th[data-sort="' + lk + '"]');
      if (th) {
        th.setAttribute('aria-sort', sortLevels[i].asc ? 'ascending' : 'descending');
        var idx = th.querySelector('.sort-idx');
        if (idx) idx.textContent = i === 0 ? '①' : '②';
      }
    }
  }
  function sortRowsWithinGroupsMulti() {
    var tbody = document.querySelector('.findings-table tbody');
    if (!tbody || sortLevels.length === 0) return;
    var groups = [];
    var current = null;
    Array.prototype.forEach.call(tbody.children, function (tr) {
      if (tr.classList.contains('group-row')) {
        current = { header: tr, rows: [] };
        groups.push(current);
      } else if (current) {
        current.rows.push(tr);
      }
    });
    groups.forEach(function (g) {
      g.rows.sort(function (a, b) {
        for (var si = 0; si < sortLevels.length; si++) {
          var lv = sortLevels[si];
          var c = cmpRows(a, b, lv.key, lv.asc);
          if (c !== 0) return c;
        }
        return 0;
      });
    });
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    groups.forEach(function (g) {
      tbody.appendChild(g.header);
      g.rows.forEach(function (r) { tbody.appendChild(r); });
    });
    updateBulkUi();
  }

  document.querySelectorAll('.findings-table thead th[data-sort]').forEach(function (th) {
    th.addEventListener('click', function (ev) {
      var sk = th.getAttribute('data-sort');
      if (!sk) return;
      if (ev.shiftKey) {
        if (sortLevels.length === 0) {
          sortLevels = [{ key: sk, asc: true }];
        } else if (sortLevels[0].key === sk) {
          sortLevels[0].asc = !sortLevels[0].asc;
        } else if (sortLevels.length >= 2 && sortLevels[1].key === sk) {
          sortLevels[1].asc = !sortLevels[1].asc;
        } else if (sortLevels.length === 1) {
          sortLevels.push({ key: sk, asc: true });
        } else {
          sortLevels = [sortLevels[0], { key: sk, asc: true }];
        }
      } else {
        if (sortLevels.length && sortLevels[0].key === sk) {
          sortLevels[0].asc = !sortLevels[0].asc;
        } else {
          sortLevels = [{ key: sk, asc: true }];
        }
      }
      updateSortHeaderUi();
      sortRowsWithinGroupsMulti();
    });
  });

  /* Bulk row selection — copy selected violations as JSON without opening each file. */
  var bulkBar = document.getElementById('findings-bulk-bar');
  var bulkCount = document.getElementById('findings-bulk-count');
  var bulkAll = document.getElementById('bulk-select-all');

  function decodeFileAttr(enc) {
    try { return decodeURIComponent(enc || ''); } catch (e2) { return enc || ''; }
  }
  function updateBulkUi() {
    var cbs = document.querySelectorAll('.bulk-row-cb:checked');
    if (!bulkBar || !bulkCount) return;
    var n = cbs.length;
    bulkBar.hidden = n === 0;
    bulkCount.textContent = FD.bulkSelectedTpl.replace(/\{n\}/g, String(n));
    var vis = Array.prototype.filter.call(
      document.querySelectorAll('.bulk-row-cb'),
      function (cb) {
        var row = cb.closest('tr');
        return row && row.style.display !== 'none';
      },
    );
    if (bulkAll) {
      bulkAll.indeterminate = n > 0 && n < vis.length;
      bulkAll.checked = vis.length > 0 && n === vis.length;
    }
  }
  function collectBulkPayload() {
    var out = [];
    document.querySelectorAll('.bulk-row-cb:checked').forEach(function (cb) {
      out.push({
        file: decodeFileAttr(cb.getAttribute('data-file')),
        line: parseInt(cb.getAttribute('data-line') || '1', 10),
        rule: cb.getAttribute('data-rule') || ''
      });
    });
    return out;
  }
  if (bulkAll) {
    bulkAll.addEventListener('change', function () {
      Array.prototype.forEach.call(document.querySelectorAll('.bulk-row-cb'), function (cb) {
        var tr = cb.closest('tr');
        if (tr && tr.style.display === 'none') return;
        cb.checked = bulkAll.checked;
      });
      updateBulkUi();
    });
  }
  bindClick('btn-bulk-copy', function () {
    var pay = collectBulkPayload();
    if (pay.length) {
      vscode.postMessage({ type: 'copyBulkFindings', violations: pay });
    }
  });

  /* Finding-row clicks open the file. Per-row copy posts JSON. */
  bindFRows();
  function bindFRows() {
    document.querySelectorAll('tr.frow').forEach(function (row) {
      row.addEventListener('click', function (e) {
        var t = e.target;
        if (t && t.closest && t.closest('.bulk-row-cb')) return;
        if (t && t.closest && t.closest('.col-sel-bulk')) return;
        if (t && t.getAttribute && t.getAttribute('data-row-action') === 'copy') {
          e.stopPropagation();
          vscode.postMessage({
            type: 'copySingleFinding',
            file: decodeURIComponent(row.getAttribute('data-file') || ''),
            line: parseInt(row.getAttribute('data-line') || '1', 10),
            rule: row.getAttribute('data-rule') || '',
          });
          return;
        }
        openRow(row);
      });
      row.addEventListener('keydown', function (e) {
        var tgt = e.target;
        if (tgt && tgt.closest && tgt.closest('.bulk-row-cb')) return;
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openRow(row); }
      });
    });
    document.querySelectorAll('.crow').forEach(function (row) {
      if (row.classList.contains('inert')) return;
      row.addEventListener('click', function () { openRow(row); });
      row.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openRow(row); }
      });
    });
    document.querySelectorAll('.bulk-row-cb').forEach(function (cb) {
      cb.addEventListener('click', function (e) {
        e.stopPropagation();
        updateBulkUi();
      });
    });
    updateBulkUi();
  }
  function openRow(row) {
    var enc = row.getAttribute('data-file');
    var ln = parseInt(row.getAttribute('data-line') || '1', 10);
    if (!enc) return;
    try {
      vscode.postMessage({ type: 'openFile', file: decodeURIComponent(enc), line: ln });
    } catch (e) { /* ignore */ }
  }

  /* Top Rules table — Hide and Disable buttons post different message types.
     Both rely on the dashboard rebuilding via the issuesProvider tree-data
     event (Hide) or the post-disable analysis re-run (Disable), so we don't
     manipulate the DOM directly here. */
  document.querySelectorAll('.top-rules-table tr.trow').forEach(function (row) {
    var enc = row.getAttribute('data-rule-enc') || '';
    var rule = '';
    try { rule = decodeURIComponent(enc); } catch (err) { rule = ''; }
    if (!rule) return;
    var hideBtn = row.querySelector('button[data-row-action="hide-rule"]');
    if (hideBtn) {
      hideBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        vscode.postMessage({ type: 'suppressRule', rule: rule });
      });
    }
    var disableBtn = row.querySelector('button[data-row-action="disable-rule"]');
    if (disableBtn) {
      disableBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        vscode.postMessage({ type: 'disableRule', rule: rule });
      });
    }
  });

  /* Top Rules table — click a header to sort; click a row to expand its full
     message + affected-file breakdown. Sorting moves each detail row with its
     parent so the disclosure stays glued to the right rule. Rank is left
     unsortable on purpose (it is a stable noise-rank position label). */
  (function () {
    var tbl = document.querySelector('.top-rules-table');
    if (!tbl) return;
    var tbody = tbl.querySelector('tbody');
    if (!tbody) return;
    var sevOrder = { error: 0, warning: 1, info: 2, note: 3 };
    var sortState = { key: null, asc: true };

    function sortVal(tr, key) {
      if (key === 'count') return parseInt(tr.getAttribute('data-count') || '0', 10);
      if (key === 'sev') {
        var s = sevOrder[tr.getAttribute('data-sev')];
        return s == null ? 99 : s;
      }
      return (tr.getAttribute('data-rule') || '').toLowerCase();
    }
    function detailFor(tr) {
      var n = tr.nextElementSibling;
      return (n && n.classList.contains('trow-detail')) ? n : null;
    }
    function applySort(key) {
      if (sortState.key === key) { sortState.asc = !sortState.asc; }
      else { sortState.key = key; sortState.asc = true; }
      var asc = sortState.asc;
      var pairs = [];
      Array.prototype.forEach.call(tbody.querySelectorAll('tr.trow'), function (tr) {
        pairs.push({ row: tr, detail: detailFor(tr) });
      });
      pairs.sort(function (a, b) {
        var av = sortVal(a.row, key), bv = sortVal(b.row, key);
        if (av < bv) return asc ? -1 : 1;
        if (av > bv) return asc ? 1 : -1;
        return 0;
      });
      while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
      pairs.forEach(function (p) {
        tbody.appendChild(p.row);
        if (p.detail) tbody.appendChild(p.detail);
      });
      tbl.querySelectorAll('thead th[data-sort]').forEach(function (h) {
        var hk = h.getAttribute('data-sort');
        h.setAttribute('aria-sort', hk === key ? (asc ? 'ascending' : 'descending') : 'none');
      });
    }
    tbl.querySelectorAll('thead th[data-sort]').forEach(function (th) {
      th.addEventListener('click', function () {
        var k = th.getAttribute('data-sort');
        if (k) applySort(k);
      });
    });

    function toggleRow(tr) {
      var detail = detailFor(tr);
      if (!detail) return;
      var open = tr.getAttribute('aria-expanded') === 'true';
      tr.setAttribute('aria-expanded', open ? 'false' : 'true');
      detail.hidden = open;
      var chev = tr.querySelector('.trow-chev');
      if (chev) chev.textContent = open ? '▸' : '▾';
    }
    Array.prototype.forEach.call(
      tbody.querySelectorAll('tr.trow[data-expandable="true"]'),
      function (tr) {
        tr.addEventListener('click', function (e) {
          // Hide / Disable buttons own their own clicks — never toggle on them.
          if (e.target && e.target.closest && e.target.closest('.row-action')) return;
          toggleRow(tr);
        });
        tr.addEventListener('keydown', function (e) {
          if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleRow(tr); }
        });
      },
    );

    /* Affected-file rows in the expander deep-link into the source file. */
    Array.prototype.forEach.call(tbl.querySelectorAll('.trd-file[data-file]'), function (li) {
      function open() {
        try {
          vscode.postMessage({
            type: 'openFile',
            file: decodeURIComponent(li.getAttribute('data-file') || ''),
            line: parseInt(li.getAttribute('data-line') || '1', 10),
          });
        } catch (e) { /* ignore */ }
      }
      li.addEventListener('click', open);
      li.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
      });
    });
  })();

  /* TODOs / Drift section action bindings */
  bindClick('btn-enable-todos-scan', function () { vscode.postMessage({ type: 'enableTodosScan' }); });
  bindClick('btn-drift-refresh', function () { vscode.postMessage({ type: 'driftRefresh' }); });
  bindClick('btn-drift-enable', function () { vscode.postMessage({ type: 'driftEnable' }); });
  bindClick('btn-drift-disable', function () { vscode.postMessage({ type: 'driftDisable' }); });
  bindClick('btn-drift-browser', function () { vscode.postMessage({ type: 'driftOpenBrowser' }); });

  /* Suppressions block bindings */
  var supRoot = document.getElementById('suppressions-block');
  if (supRoot) {
    supRoot.querySelectorAll('.sup-row.sup-act').forEach(function (row) {
      function fire() {
        var sup = row.getAttribute('data-sup');
        if (sup === 'focus-issues') { vscode.postMessage({ type: 'focusIssues' }); return; }
        if (sup === 'rule') {
          var r = row.getAttribute('data-rule');
          if (!r) return;
          try { vscode.postMessage({ type: 'focusIssuesForRules', rules: [decodeURIComponent(r)] }); } catch (e) { /* ignore */ }
          return;
        }
        if (sup === 'file') {
          var f = row.getAttribute('data-file');
          if (!f) return;
          try { vscode.postMessage({ type: 'openFileAndFocusIssues', filePath: decodeURIComponent(f) }); } catch (e) { /* ignore */ }
        }
      }
      row.addEventListener('click', fire);
      row.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
      });
    });
    bindClick('btn-clear-view-sup', function () {
      vscode.postMessage({ type: 'clearWorkspaceSuppressions' });
    });
  }

  function bindClick(id, fn) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('click', fn);
  }

  /* Freshness pill — "Updated <rel>", clickable to refresh + self-ticking.
     A backgrounded panel does not auto-repaint (the host's diagnostics
     listener early-returns when the panel is hidden), so without these two
     behaviors the label would freeze at "just now" from its last paint and
     there would be no in-panel way to pull fresh data. tickFreshness recomputes
     the relative label from the localized {n} templates baked into the pill's
     data attributes — matching the server formatRelative buckets exactly so the
     two never disagree. */
  function tickFreshness() {
    document.querySelectorAll('.freshness-rel[data-updated-at]').forEach(function (el) {
      var iso = el.getAttribute('data-updated-at');
      var t = Date.parse(iso || '');
      if (!isFinite(t)) return;
      var diff = Date.now() - t;
      var txt;
      if (diff < 0) {
        txt = el.getAttribute('data-t-justnow');
      } else {
        var sec = Math.floor(diff / 1000);
        if (sec < 45) {
          txt = el.getAttribute('data-t-justnow');
        } else {
          var min = Math.floor(sec / 60);
          if (min < 60) {
            txt = (el.getAttribute('data-t-min') || '').replace('{n}', String(min));
          } else {
            var hr = Math.floor(min / 60);
            if (hr < 24) {
              txt = (el.getAttribute('data-t-hr') || '').replace('{n}', String(hr));
            } else {
              txt = (el.getAttribute('data-t-day') || '').replace('{n}', String(Math.floor(hr / 24)));
            }
          }
        }
      }
      if (txt != null) el.textContent = txt;
    });
  }
  // Re-tick on a slow interval and whenever the tab regains focus, so a panel
  // returning from the background immediately shows its true age.
  setInterval(tickFreshness, 30000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) tickFreshness(); });
  window.addEventListener('focus', tickFreshness);

  // Click / Enter / Space on the freshness pill (or any data-action="refresh"
  // element) re-reads the analyzer's current diagnostics — the same {type:'refresh'}
  // the More-menu "Reload from disk" item fires.
  function fireRefreshAction(target) {
    if (target && target.closest && target.closest('[data-action="refresh"]')) {
      vscode.postMessage({ type: 'refresh' });
      return true;
    }
    return false;
  }
  document.addEventListener('click', function (e) { fireRefreshAction(e.target); });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    if (fireRefreshAction(e.target)) e.preventDefault();
  });

  window.addEventListener('message', function (event) {
    var msg = event && event.data ? event.data : null;
    if (!msg) return;
    // Host posts this on the first diagnostics change of a burst (analysis is
    // streaming results in); the subsequent debounced rebuild reveals the
    // settled grade. Keeps the gauge honest even for runs the dashboard did
    // not initiate (e.g. analyze-on-save).
    if (msg.type === 'gaugePending') { setGaugePending(!!msg.pending); return; }
    if (msg.type !== 'analysisProgress') return;
    if (msg.status === 'started') {
      setAnalysisProgress(true, FD.metaStartedDetail);
      announce(FD.announceStarted);
      return;
    }
    if (msg.status === 'completed') {
      setAnalysisProgress(false, FD.metaDone);
      announce(FD.announceComplete);
      return;
    }
    if (msg.status === 'failed') {
      setAnalysisProgress(false, FD.metaFailed);
      announce(FD.announceFailed);
    }
  });

  /* Full-width toggle (guideline §4) — flips body[data-full-width] so users on ultrawide
     monitors can opt out of the readability max-width set in the stylesheet. */
  ${getFullWidthToggleScript()}

  /* §15.2 — page-level keyboard shortcuts advertised in the overlay.
     '/' focuses the text filter from anywhere; 'Esc' on a focused, non-empty
     filter clears it. Skip when the user is already typing in another input
     so the global handler doesn't steal the slash key from a search box on a
     popover or future modal. */
  document.addEventListener('keydown', function (e) {
    var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
    var isEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === '/' && !isEditable) {
      e.preventDefault();
      var input = document.getElementById('textFilter');
      if (input) { input.focus(); input.select && input.select(); }
    } else if (e.key === 'Escape' && e.target === tf && tf && tf.value) {
      e.preventDefault();
      tf.value = '';
      pushState(true);
    }
  });
  ${getKeyboardShortcutsScript()}
})();`;
}

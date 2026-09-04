/**
 * Client script for the **Lints Config** webview (postMessage bridge).
 *
 * Wires:
 * - tier radio control (posts `setTier`)
 * - pack toggle switches (posts `toggle`)
 * - rule list links (posts `showRules`)
 * - toolbar action buttons (posts `command`)
 * - native `<details class="more">` overflow menu for "Enable applicable packs"
 *   (matches the Findings dashboard's overflow-trigger pattern)
 * - KPI cards as preset filters (§14.8)
 * - chart bars + donut segments as preset filters (§6.2)
 * - text search, type select, detected/enabled segmented control
 * - sortable column headers
 * - active filter chip strip rendering (§8.5, §14.10)
 *
 * Selectors track the shared chrome class names from `views/dashboardChromeStyles.ts`
 * (.btn, .chip-strip, .chip, .seg, .seg-btn, .menu .menu-item, .bar-row, .donut .seg) so
 * the dashboard behaves the same as Findings and Code Health where the same selectors apply.
 */
export function getConfigDashboardScript(): string {
  return [
    SCRIPT_PREAMBLE,
    SCRIPT_TABS,
    SCRIPT_TIER_AND_TOGGLES,
    SCRIPT_TOOLBAR_ACTIONS,
    SCRIPT_FILTER_STATE,
    SCRIPT_FILTER_APPLY,
    SCRIPT_SORT,
    SCRIPT_KPI_AND_CHART,
    SCRIPT_FIND,
    SCRIPT_GAUGE,
    SCRIPT_DISABLED_RULES_SEARCH,
    SCRIPT_STYLISTIC,
    SCRIPT_SETTINGS_GRID,
    SCRIPT_CONFIG_FILE_TAB,
    SCRIPT_OPTIMIZER_EMBED,
    SCRIPT_INIT,
  ].join('\n');
}

/** Acquire the VS Code API and stash filter state on a single object. */
const SCRIPT_PREAMBLE = `
(function() {
  const vscode = acquireVsCodeApi();
  const state = {
    search: '',
    type: 'all',
    detectedOnly: false,
    enabledOnly: false,
    sortKey: 'label',
    sortDir: 'asc',
    /** When set, rows are filtered to a single pack — used by chart-bar/donut-segment clicks. */
    barPack: null,
    /** When set, KPI preset filter is active ('enabled' or 'applicable-sdk'). */
    kpi: null,
  };
`;

/** Tier radio control + toggle switches + rules link wiring. */
const SCRIPT_TIER_AND_TOGGLES = `
  document.querySelectorAll('.tier-btn[data-tier]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      const tier = btn.getAttribute('data-tier');
      if (tier) vscode.postMessage({ type: 'setTier', tier: tier });
    });
    btn.addEventListener('keydown', function(e) {
      if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
      e.preventDefault();
      const buttons = Array.from(document.querySelectorAll('.tier-btn[data-tier]'));
      const idx = buttons.indexOf(btn);
      if (idx < 0) return;
      const next = (e.key === 'ArrowRight' ? idx + 1 : idx - 1 + buttons.length) % buttons.length;
      buttons[next].focus();
      buttons[next].click();
    });
  });

  document.querySelectorAll('input[type=checkbox][data-pack]').forEach(function(el) {
    el.addEventListener('change', function() {
      // Version groups are mutually exclusive (dio vs dio_5, riverpod 2 vs 3, …).
      // Enabling one variant visually clears its siblings immediately so the
      // pick-one contract is obvious; the host de-duplicates the written config
      // as well, so this is feedback, not the source of truth.
      var vgroup = el.getAttribute('data-vgroup');
      if (el.checked && vgroup) {
        document.querySelectorAll('input[type=checkbox][data-vgroup="' + cssEscape(vgroup) + '"]').forEach(function(sib) {
          if (sib !== el && sib.checked) {
            sib.checked = false;
            var sibRow = sib.closest('tr[data-pack]');
            if (sibRow) sibRow.setAttribute('data-enabled', '0');
          }
        });
      }
      vscode.postMessage({ type: 'toggle', packId: el.getAttribute('data-pack'), enabled: el.checked });
    });
  });

  // Inline disclosure: each toggle shows/hides the sibling detail row that lists
  // the pack's rules. No popup — the rules stay in the table context.
  document.querySelectorAll('button.rules-toggle').forEach(function(btn) {
    btn.addEventListener('click', function() {
      const id = btn.getAttribute('data-pack');
      const detail = document.querySelector('tr.rules-detail[data-detail-for="' + cssEscape(id) + '"]');
      if (!detail) return;
      const open = btn.getAttribute('aria-expanded') === 'true';
      btn.setAttribute('aria-expanded', open ? 'false' : 'true');
      btn.classList.toggle('open', !open);
      detail.hidden = open;
    });
  });

  // Each rule code inside an expanded pack opens its explanation.
  document.querySelectorAll('a.rule-link').forEach(function(a) {
    a.addEventListener('click', function(e) {
      e.preventDefault();
      vscode.postMessage({ type: 'explainRule', rule: a.getAttribute('data-rule') });
    });
  });
`;

/**
 * Toolbar action buttons + overflow menu items. Matches the Findings dashboard's pattern:
 * `.btn[data-command]` for primary/secondary actions; `.menu .menu-item[data-command]` for
 * items inside the native `<details class="more">` overflow menu (which closes on its own
 * when the user clicks outside since `<details>` handles open/close natively).
 */
const SCRIPT_TOOLBAR_ACTIONS = `
  document.querySelectorAll('.btn[data-command], .menu-item[data-command]').forEach(function(el) {
    el.addEventListener('click', function() {
      if (el.disabled) return;
      vscode.postMessage({ type: 'command', id: el.getAttribute('data-command') });
      // After a menu-item click, close the overflow so the next user action is unambiguous.
      const containingDetails = el.closest('details.more');
      if (containingDetails) containingDetails.removeAttribute('open');
    });
  });
  // Click anywhere else on the page closes any open overflow menu (matches macOS / Windows
  // menu conventions).
  document.addEventListener('click', function(e) {
    document.querySelectorAll('details.more[open]').forEach(function(d) {
      if (!d.contains(e.target)) d.removeAttribute('open');
    });
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
      document.querySelectorAll('details.more[open]').forEach(function(d) { d.removeAttribute('open'); });
    }
  });
`;

/** Search field, type select, and the segmented-control toggles wired to {@link state}. */
const SCRIPT_FILTER_STATE = `
  const searchInput = document.getElementById('pack-search');
  const typeSelect = document.getElementById('type-filter');

  if (searchInput) {
    searchInput.addEventListener('input', function() {
      state.search = (searchInput.value || '').toLowerCase();
      applyFilters();
    });
  }
  if (typeSelect) {
    typeSelect.addEventListener('change', function() {
      state.type = typeSelect.value || 'all';
      applyFilters();
    });
  }
  // Segmented toggles for "detected only" / "enabled only". Matches the Findings dashboard's
  // segmented-control pattern instead of bare checkboxes so the visual language is shared.
  document.querySelectorAll('.seg-btn[data-toggle-filter]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      const key = btn.getAttribute('data-toggle-filter');
      const pressed = btn.getAttribute('aria-pressed') === 'true';
      btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
      if (key === 'detected') state.detectedOnly = !pressed;
      else if (key === 'enabled') state.enabledOnly = !pressed;
      applyFilters();
    });
  });
`;

/** Apply current filter state to rows + render the active-filter chip strip. */
const SCRIPT_FILTER_APPLY = `
  // Packs now live across two tables (detected / all) so every row query spans
  // all .packs-tbody bodies instead of a single #packs-tbody.
  function allPackTbodies() {
    return Array.from(document.querySelectorAll('tbody.packs-tbody'));
  }

  function anyPackFilterActive() {
    return !!(state.search || state.type !== 'all' || state.detectedOnly ||
      state.enabledOnly || state.barPack || state.kpi);
  }

  function applyFilters() {
    const tbodies = allPackTbodies();
    if (tbodies.length === 0) return;
    // When a filter is active, matches hidden inside a collapsed domain group or
    // the collapsed "All packages" section would be invisible — open the ancestor
    // <details> of every surviving row so results are actually seen.
    const filtering = anyPackFilterActive();
    // Grand totals across both pack tables for the match-count readout beside the
    // search box (idea 2): how many packs survive, and how many individual rule
    // codes match the query.
    let grandVisible = 0;
    let grandRuleMatches = 0;
    tbodies.forEach(function(tbody) {
      const rows = Array.from(tbody.querySelectorAll('tr[data-pack]'));
      let visible = 0;
      rows.forEach(function(row) {
        const label = row.getAttribute('data-label') || '';
        const type = row.getAttribute('data-type') || '';
        const detected = row.getAttribute('data-detected') === '1';
        const enabled = row.getAttribute('data-enabled') === '1';
        const pack = row.getAttribute('data-pack') || '';
        const rulesText = row.getAttribute('data-rules-text') || '';
        const domain = row.getAttribute('data-domain') || '';
        let show = true;
        // Search matches the pack name, its problem-area domain, OR any of its rule
        // codes — so "avoid_print" surfaces the pack that contains it, not just packs
        // whose label contains the term. Track a rule-only match so we can auto-expand
        // the pack's rule list to reveal what matched.
        let matchedRuleOnly = false;
        if (state.search) {
          const inLabel = label.indexOf(state.search) !== -1;
          const inDomain = domain.indexOf(state.search) !== -1;
          const inRules = rulesText.indexOf(state.search) !== -1;
          if (!inLabel && !inDomain && !inRules) show = false;
          else matchedRuleOnly = inRules && !inLabel && !inDomain;
        }
        if (state.type !== 'all' && state.type !== type) show = false;
        if (state.detectedOnly && !detected) show = false;
        if (state.enabledOnly && !enabled) show = false;
        if (state.barPack && state.barPack !== pack) show = false;
        if (state.kpi === 'enabled' && !enabled) show = false;
        if (state.kpi === 'applicable-sdk' && !(type === 'sdk' && detected)) show = false;
        row.style.display = show ? '' : 'none';
        // Keep each pack's expander detail row in lockstep with its summary row.
        const detail = tbody.querySelector('tr.rules-detail[data-detail-for="' + cssEscape(pack) + '"]');
        const toggle = row.querySelector('button.rules-toggle');
        if (detail) {
          detail.style.display = show ? '' : 'none';
          // Auto-open the rule list when the search hit a rule code (not the pack
          // name) so the matching rule is actually visible. Auto-close it again once
          // that search is cleared, but never fight a row the user expanded manually
          // for a different reason.
          if (show && matchedRuleOnly) {
            detail.hidden = false;
            if (toggle) { toggle.setAttribute('aria-expanded', 'true'); toggle.classList.add('open'); }
          } else if (state.search) {
            detail.hidden = true;
            if (toggle) { toggle.setAttribute('aria-expanded', 'false'); toggle.classList.remove('open'); }
          }
        }
        if (show) {
          visible++;
          // Count rule codes in this surviving pack that match the query (idea 2).
          if (state.search && rulesText) {
            const codes = rulesText.split(' ');
            for (let i = 0; i < codes.length; i++) {
              if (codes[i] && codes[i].indexOf(state.search) !== -1) grandRuleMatches++;
            }
          }
        }
      });
      grandVisible += visible;
      renderEmptyRow(tbody, visible);
      // Reveal the group chain when a filter is active and this table has a match.
      if (filtering && visible > 0) {
        let node = tbody.parentNode;
        while (node && node !== document) {
          if (node.tagName === 'DETAILS') node.open = true;
          node = node.parentNode;
        }
      }
    });
    renderFilterStrip();
    renderMatchCount(grandVisible, grandRuleMatches);
    highlightRuleLinks();
    renderRuleFinder();
  }

  // Per-table empty state: each pack table shows its own "no matches" row so a
  // filter that empties one table still reads clearly in the other.
  function renderEmptyRow(tbody, visible) {
    let empty = tbody.querySelector('tr.empty-row');
    const hasRows = tbody.querySelector('tr[data-pack]');
    if (visible > 0 || !hasRows) {
      if (empty) empty.remove();
      return;
    }
    if (!empty) {
      empty = document.createElement('tr');
      empty.className = 'empty-row';
      empty.innerHTML = '<td colspan="6">No packs match the current filters. ' +
        '<button type="button" class="reset-link">Reset filters</button></td>';
      tbody.appendChild(empty);
      const btn = empty.querySelector('.reset-link');
      if (btn) btn.addEventListener('click', resetFilters);
    }
  }

  function resetFilters() {
    state.search = '';
    state.type = 'all';
    state.detectedOnly = false;
    state.enabledOnly = false;
    state.barPack = null;
    state.kpi = null;
    if (searchInput) searchInput.value = '';
    if (typeSelect) typeSelect.value = 'all';
    document.querySelectorAll('.seg-btn[data-toggle-filter]').forEach(function(b) {
      b.setAttribute('aria-pressed', 'false');
    });
    document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    document.querySelectorAll('.bar-row.active, .donut .seg.active').forEach(function(b) {
      b.classList.remove('active');
    });
    const donut = document.querySelector('.donut');
    if (donut) donut.removeAttribute('data-has-active');
    applyFilters();
  }

  function renderFilterStrip() {
    const strip = document.getElementById('filter-strip');
    if (!strip) return;
    const chips = [];
    if (state.search) chips.push({ key: 'search', label: 'search: "' + escapeHtml(state.search) + '"' });
    if (state.type !== 'all') chips.push({ key: 'type', label: 'type: ' + state.type });
    if (state.detectedOnly) chips.push({ key: 'detected', label: 'detected only' });
    if (state.enabledOnly) chips.push({ key: 'enabled', label: 'enabled only' });
    if (state.barPack) chips.push({ key: 'bar', label: 'pack: ' + escapeHtml(state.barPack) });
    if (state.kpi === 'enabled') chips.push({ key: 'kpi-enabled', label: 'KPI: enabled' });
    if (state.kpi === 'applicable-sdk') chips.push({ key: 'kpi-applicable-sdk', label: 'KPI: applicable SDK' });
    if (chips.length === 0) {
      strip.hidden = true;
      strip.innerHTML = '';
      return;
    }
    strip.hidden = false;
    const html = ['<span class="lbl">Active filters:</span>'];
    chips.forEach(function(chip) {
      html.push('<span class="chip">' + chip.label +
        '<button type="button" class="x" data-chip="' + chip.key + '" aria-label="Remove ' + chip.key + '">×</button></span>');
    });
    html.push('<button type="button" class="clear-all" id="clear-all-filters">Clear all</button>');
    strip.innerHTML = html.join('');
    strip.querySelectorAll('.chip .x').forEach(function(btn) {
      btn.addEventListener('click', function() { removeChip(btn.getAttribute('data-chip')); });
    });
    const clearBtn = document.getElementById('clear-all-filters');
    if (clearBtn) clearBtn.addEventListener('click', resetFilters);
  }

  function removeChip(key) {
    if (key === 'search') { state.search = ''; if (searchInput) searchInput.value = ''; }
    else if (key === 'type') { state.type = 'all'; if (typeSelect) typeSelect.value = 'all'; }
    else if (key === 'detected') {
      state.detectedOnly = false;
      const b = document.querySelector('.seg-btn[data-toggle-filter="detected"]');
      if (b) b.setAttribute('aria-pressed', 'false');
    }
    else if (key === 'enabled') {
      state.enabledOnly = false;
      const b = document.querySelector('.seg-btn[data-toggle-filter="enabled"]');
      if (b) b.setAttribute('aria-pressed', 'false');
    }
    else if (key === 'bar') {
      state.barPack = null;
      document.querySelectorAll('.bar-row.active, .donut .seg.active').forEach(function(b) {
        b.classList.remove('active');
      });
      const donut = document.querySelector('.donut');
      if (donut) donut.removeAttribute('data-has-active');
    }
    else if (key === 'kpi-enabled' || key === 'kpi-applicable-sdk') {
      state.kpi = null;
      document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
    }
    applyFilters();
  }

  function escapeHtml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
`;

/** Sortable column headers — toggles direction; numeric vs text sort by data-sort key. */
const SCRIPT_SORT = `
  document.querySelectorAll('th.sortable[data-sort]').forEach(function(th) {
    th.addEventListener('click', function() {
      const key = th.getAttribute('data-sort');
      if (!key) return;
      if (state.sortKey === key) {
        state.sortDir = state.sortDir === 'asc' ? 'desc' : 'asc';
      } else {
        state.sortKey = key;
        state.sortDir = key === 'rules' ? 'desc' : 'asc';
      }
      applySort();
    });
  });

  function applySort() {
    const numericKeys = { rules: true, detected: true, enabled: true };
    // Sort within each table independently so detected/all stay separate groups.
    allPackTbodies().forEach(function(tbody) {
      const rows = Array.from(tbody.querySelectorAll('tr[data-pack]'));
      rows.sort(function(a, b) {
        const av = a.getAttribute('data-' + state.sortKey) || '';
        const bv = b.getAttribute('data-' + state.sortKey) || '';
        let cmp;
        if (numericKeys[state.sortKey]) {
          cmp = (parseInt(av, 10) || 0) - (parseInt(bv, 10) || 0);
        } else {
          cmp = av.localeCompare(bv);
        }
        return state.sortDir === 'asc' ? cmp : -cmp;
      });
      // Re-append each pack row followed immediately by its expander detail row so
      // the two stay paired (the detail row is a separate <tr>, not a child).
      rows.forEach(function(r) {
        tbody.appendChild(r);
        const pack = r.getAttribute('data-pack');
        const detail = tbody.querySelector('tr.rules-detail[data-detail-for="' + cssEscape(pack) + '"]');
        if (detail) tbody.appendChild(detail);
      });
    });
    document.querySelectorAll('th.sortable').forEach(function(h) {
      h.setAttribute('aria-sort',
        h.getAttribute('data-sort') === state.sortKey
          ? (state.sortDir === 'asc' ? 'ascending' : 'descending')
          : 'none');
    });
  }
`;

/** KPI cards and chart bars/donut segments wired as preset filters (§14.8, §6.2). */
const SCRIPT_KPI_AND_CHART = `
  document.querySelectorAll('.kpi-card.interactive[data-kpi-filter]').forEach(function(card) {
    card.addEventListener('click', function() {
      const key = card.getAttribute('data-kpi-filter');
      const wasActive = card.classList.contains('active');
      document.querySelectorAll('.kpi-card.active').forEach(function(c) { c.classList.remove('active'); });
      state.kpi = wasActive ? null : key;
      if (state.kpi) card.classList.add('active');
      applyFilters();
    });
  });

  // Bars and donut segments share one click contract: any element with [data-bar-pack] toggles
  // the same pack filter and cross-highlights the matching elements in the other visualization.
  document.querySelectorAll('[data-bar-pack]').forEach(function(target) {
    function trigger() {
      const pack = target.getAttribute('data-bar-pack');
      const wasActive = state.barPack === pack;
      document.querySelectorAll('.bar-row.active, .donut .seg.active').forEach(function(b) {
        b.classList.remove('active');
      });
      state.barPack = wasActive ? null : pack;
      const donut = document.querySelector('.donut');
      if (state.barPack) {
        document.querySelectorAll('[data-bar-pack="' + cssEscape(pack) + '"]').forEach(function(el) {
          el.classList.add('active');
        });
        if (donut) donut.setAttribute('data-has-active', '1');
      } else if (donut) {
        donut.removeAttribute('data-has-active');
      }
      applyFilters();
      // The clicked pack may live in the collapsed "All packages" accordion;
      // open its containing <details> and scroll the row into view.
      if (state.barPack) {
        const row = document.querySelector('tr[data-pack="' + cssEscape(state.barPack) + '"]');
        if (row) {
          const det = row.closest('details');
          if (det) det.open = true;
          row.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }
    }
    target.addEventListener('click', trigger);
    target.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); trigger(); }
    });
  });

  function cssEscape(s) {
    if (window.CSS && typeof window.CSS.escape === 'function') return window.CSS.escape(s);
    return String(s).replace(/[^a-zA-Z0-9_-]/g, '\\\\$&');
  }
`;

/**
 * Rule-finding aids that all key off the active search query:
 *  - renderMatchCount: a "N packs · M rules" readout beside the search box (idea 2).
 *  - highlightRuleLinks: wrap the matched substring in <mark> inside expanded pack
 *    rule lists (idea 3).
 *  - renderRuleFinder: a flat "Matching rules" panel listing each matching rule code
 *    once with its owning pack(s), so a rule is reachable without knowing its pack
 *    (idea 4). Clicking a code opens its explanation; clicking a pack reveals it.
 *  - focusPack: open every ancestor accordion + the pack's own rule list and scroll
 *    the row into view.
 */
const SCRIPT_FIND = `
  // Wrap each case-insensitive occurrence of q within text in <mark>. text is a lint
  // id ([a-z0-9_]) so escaping is defensive; q is a user substring of it.
  function highlightMatch(text, q) {
    if (!q) return escapeHtml(text);
    const lower = text.toLowerCase();
    let out = '';
    let i = 0;
    while (true) {
      const idx = lower.indexOf(q, i);
      if (idx === -1) { out += escapeHtml(text.slice(i)); break; }
      out += escapeHtml(text.slice(i, idx));
      out += '<mark>' + escapeHtml(text.slice(idx, idx + q.length)) + '</mark>';
      i = idx + q.length;
    }
    return out;
  }

  function renderMatchCount(packs, rules) {
    const el = document.getElementById('pack-match-count');
    if (!el) return;
    if (!anyPackFilterActive()) { el.hidden = true; el.textContent = ''; return; }
    let txt = packs + ' pack' + (packs === 1 ? '' : 's');
    // Rule count is only meaningful while text-searching; other filters act on packs.
    if (state.search) txt += ' · ' + rules + ' rule' + (rules === 1 ? '' : 's');
    el.textContent = txt;
    el.hidden = false;
  }

  // Highlight the matched substring inside already-rendered pack rule lists. Reset to
  // plain text when the code does not match (or search is cleared) so stale <mark>s do
  // not linger.
  function highlightRuleLinks() {
    const q = state.search;
    document.querySelectorAll('.rules-detail-body .rule-link').forEach(function(a) {
      const code = a.getAttribute('data-rule') || '';
      if (q && code.indexOf(q) !== -1) a.innerHTML = highlightMatch(code, q);
      else a.textContent = code;
    });
  }

  // Open a pack wherever it lives (detected table or a collapsed domain group),
  // expand its rule list, and scroll it into view.
  function focusPack(packId) {
    const row = document.querySelector('tr[data-pack="' + cssEscape(packId) + '"]');
    if (!row) return;
    let node = row.parentNode;
    while (node && node !== document) {
      if (node.tagName === 'DETAILS') node.open = true;
      node = node.parentNode;
    }
    const detail = document.querySelector('tr.rules-detail[data-detail-for="' + cssEscape(packId) + '"]');
    const toggle = row.querySelector('button.rules-toggle');
    if (detail) { detail.hidden = false; detail.style.display = ''; }
    if (toggle) { toggle.setAttribute('aria-expanded', 'true'); toggle.classList.add('open'); }
    row.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  const RULE_FINDER_CAP = 60;
  function renderRuleFinder() {
    const panel = document.getElementById('rule-finder');
    if (!panel) return;
    const q = state.search;
    if (!q) { panel.hidden = true; panel.innerHTML = ''; return; }
    // Group matching rule codes -> the pack(s) that own them. A rule can sit in
    // several overlapping packs, so collect all of them.
    const byCode = new Map();
    document.querySelectorAll('tr[data-pack]').forEach(function(row) {
      const rulesText = row.getAttribute('data-rules-text') || '';
      if (rulesText.indexOf(q) === -1) return;
      const packId = row.getAttribute('data-pack') || '';
      const packLabel = row.getAttribute('data-pack-label') || packId;
      rulesText.split(' ').forEach(function(code) {
        if (!code || code.indexOf(q) === -1) return;
        let entry = byCode.get(code);
        if (!entry) { entry = []; byCode.set(code, entry); }
        if (!entry.some(function(p) { return p.id === packId; })) entry.push({ id: packId, label: packLabel });
      });
    });
    if (byCode.size === 0) { panel.hidden = true; panel.innerHTML = ''; return; }
    const codes = Array.from(byCode.keys()).sort();
    const shown = codes.slice(0, RULE_FINDER_CAP);
    const html = ['<div class="rule-finder-head"><span class="rule-finder-title">Matching rules</span> <span class="muted">(' + byCode.size + ')</span></div><ul>'];
    shown.forEach(function(code) {
      const packLinks = byCode.get(code).map(function(p) {
        return '<a href="#" class="rf-pack" data-pack="' + escapeHtml(p.id) + '">' + escapeHtml(p.label) + '</a>';
      }).join(', ');
      html.push('<li><a href="#" class="rf-rule" data-rule="' + escapeHtml(code) + '">' + highlightMatch(code, q) +
        '</a> <span class="rf-in">in</span> ' + packLinks + '</li>');
    });
    html.push('</ul>');
    if (codes.length > RULE_FINDER_CAP) {
      html.push('<p class="hint">Showing the first ' + RULE_FINDER_CAP + ' of ' + codes.length + ' matching rules — refine your search to narrow.</p>');
    }
    panel.innerHTML = html.join('');
    panel.hidden = false;
    panel.querySelectorAll('.rf-rule').forEach(function(a) {
      a.addEventListener('click', function(e) {
        e.preventDefault();
        vscode.postMessage({ type: 'explainRule', rule: a.getAttribute('data-rule') });
      });
    });
    panel.querySelectorAll('.rf-pack').forEach(function(a) {
      a.addEventListener('click', function(e) {
        e.preventDefault();
        focusPack(a.getAttribute('data-pack'));
      });
    });
  }
`;

/** Initial render. */
/**
 * Live-filter the Disabled rules section by rule name (substring match, case-insensitive).
 * Hides empty groups and shows an inline empty-state hint when no rule matches the query.
 *
 * Why a separate filter instead of reusing the packs filter state: the disabled-rules block
 * is a different dataset (individual rule codes, not packs) and lives in its own expander —
 * sharing the packs search would surprise users who only want to narrow one of the two.
 */
const SCRIPT_DISABLED_RULES_SEARCH = `
  function applyDisabledRulesSearch() {
    const input = document.getElementById('disabled-rules-search');
    if (!input) return;
    const q = (input.value || '').trim().toLowerCase();
    let totalVisible = 0;
    document.querySelectorAll('.disabled-rules-group').forEach(function(group) {
      let groupVisible = 0;
      group.querySelectorAll('.disabled-rule-row').forEach(function(row) {
        const name = (row.getAttribute('data-rule') || '').toLowerCase();
        const show = !q || name.indexOf(q) !== -1;
        row.style.display = show ? '' : 'none';
        if (show) groupVisible++;
      });
      // Hide the whole group (including its heading) when no rule survives the filter,
      // so the user does not see lonely group headings with empty lists below.
      group.style.display = groupVisible === 0 ? 'none' : '';
      totalVisible += groupVisible;
    });
    const emptyHint = document.getElementById('disabled-rules-empty-hint');
    if (emptyHint) emptyHint.hidden = totalVisible !== 0 || !q;
  }
  (function wireDisabledRulesSearch() {
    const input = document.getElementById('disabled-rules-search');
    if (!input) return;
    input.addEventListener('input', applyDisabledRulesSearch);
  })();
`;

/**
 * Style & opinions section wiring: per-rule toggles (multi groups), pick-one
 * radios (conflicting groups), enable-all / disable-all bulk actions, and a
 * local substring search. Each write posts a message; the host writes the
 * RULE OVERRIDES section and refreshes, so we do not mutate config in the page.
 */
const SCRIPT_STYLISTIC = `
  // Multi-select group: each checkbox toggles one stylistic rule.
  document.querySelectorAll('input[type=checkbox][data-stylistic-rule]').forEach(function(el) {
    el.addEventListener('change', function() {
      vscode.postMessage({ type: 'toggleRule', rule: el.getAttribute('data-stylistic-rule'), enabled: el.checked });
    });
  });

  // Pick-one group: selecting a radio (including the "None" option, value="") sets the group.
  document.querySelectorAll('input[type=radio][data-pack][name^="stylistic-"]').forEach(function(el) {
    el.addEventListener('change', function() {
      if (!el.checked) return;
      vscode.postMessage({ type: 'selectStylistic', packId: el.getAttribute('data-pack'), rule: el.value });
    });
  });

  // Enable-all / disable-all for a multi-select group.
  document.querySelectorAll('button[data-stylistic-bulk]').forEach(function(btn) {
    btn.addEventListener('click', function() {
      vscode.postMessage({
        type: 'stylisticBulk',
        packId: btn.getAttribute('data-pack'),
        enabled: btn.getAttribute('data-stylistic-bulk') === 'enable',
      });
    });
  });

  // Local search across stylistic rule rows + radio rows; hides empty groups.
  function applyStylisticSearch() {
    const input = document.getElementById('stylistic-search');
    if (!input) return;
    const q = (input.value || '').trim().toLowerCase();
    let totalVisible = 0;
    document.querySelectorAll('.stylistic-group').forEach(function(group) {
      let groupVisible = 0;
      group.querySelectorAll('.stylistic-rule-row, .stylistic-radio-row').forEach(function(row) {
        const name = (row.getAttribute('data-rule') || '').toLowerCase();
        // The "None" radio (empty data-rule) always shows so a filtered pick-one
        // group can still be cleared.
        const show = !q || name === '' || name.indexOf(q) !== -1;
        row.style.display = show ? '' : 'none';
        if (show && name !== '') groupVisible++;
      });
      group.style.display = groupVisible === 0 && q ? 'none' : '';
      totalVisible += groupVisible;
    });
    const emptyHint = document.getElementById('stylistic-empty-hint');
    if (emptyHint) emptyHint.hidden = totalVisible !== 0 || !q;
  }
  (function wireStylisticSearch() {
    const input = document.getElementById('stylistic-search');
    if (input) input.addEventListener('input', applyStylisticSearch);
  })();
`;

/**
 * Animate the hero coverage gauge. The arc fill is driven by the `--gauge-target`
 * / `--gauge-arc` custom properties read by the shared `.gauge-fill` stroke-dasharray
 * rule. Those vars are set HERE (not from the element's inline style attribute):
 * the webview CSP pairs a style-src nonce with 'unsafe-inline', which makes the
 * browser ignore 'unsafe-inline' for inline style ATTRIBUTES, so a `--gauge-target`
 * written into the HTML style="" was dropped and the arc rendered empty. Setting it
 * via setProperty from a nonce'd script always applies. The element starts at
 * --gauge-target:0; raising it on the next frame lets the scoped transition in
 * configDashboardStyles animate the fill in (0 -> score).
 */
const SCRIPT_GAUGE = `
  (function initCoverageGauge() {
    const gauge = document.querySelector('.hero-gauge[data-gauge-target]');
    if (!gauge) return;
    const target = gauge.getAttribute('data-gauge-target') || '0';
    const arc = gauge.getAttribute('data-gauge-arc') || '100';
    const color = gauge.getAttribute('data-gauge-color');
    gauge.style.setProperty('--gauge-arc', arc);
    if (color) gauge.style.setProperty('--gauge-color', color);
    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) {
      // No animation: jump straight to the resting fill.
      gauge.style.setProperty('--gauge-target', target);
      return;
    }
    // Double rAF so the 0 start state is committed to a paint before we raise the
    // value — a single frame can be coalesced and the transition would not fire.
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        gauge.style.setProperty('--gauge-target', target);
      });
    });
  })();
`;

/**
 * Tab bar wiring (Phase 4). Click OR arrow-key navigation on `.rt-tab-btn[data-tab]` shows the
 * matching `#rt-panel-<id>` and hides the rest; `vscode.setState`/`getState` remembers the choice
 * across a full HTML rebuild (config file watcher refresh, memory-pressure update, …) — the SAME
 * persistence mechanism the Analysis Optimizer's own script already uses for its sort state (see
 * `analysisOptimizerScript.ts`), so this is a consistent pattern across the two panels rather than
 * a new one invented for this feature. Also posts `setActiveTab` so the HOST knows which tab is
 * active without needing to re-parse DOM state (used by nothing today beyond bookkeeping, but
 * keeps host and client from disagreeing about "the active tab" if a future refresh path needs it).
 */
const SCRIPT_TABS = `
  (function initTabs() {
    var bar = document.querySelector('.rt-tabbar');
    if (!bar) return;
    var buttons = Array.from(bar.querySelectorAll('.rt-tab-btn[data-tab]'));
    if (buttons.length === 0) return;

    function activate(tab, focusButton) {
      buttons.forEach(function(btn) {
        var isActive = btn.getAttribute('data-tab') === tab;
        btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
        btn.setAttribute('tabindex', isActive ? '0' : '-1');
        var panel = document.getElementById('rt-panel-' + btn.getAttribute('data-tab'));
        if (panel) panel.hidden = !isActive;
        if (isActive && focusButton) btn.focus();
      });
      bar.setAttribute('data-active-tab', tab);
      var state = vscode.getState() || {};
      state.activeTab = tab;
      vscode.setState(state);
      vscode.postMessage({ type: 'setActiveTab', tab: tab });
    }

    buttons.forEach(function(btn) {
      btn.addEventListener('click', function() { activate(btn.getAttribute('data-tab'), false); });
      btn.addEventListener('keydown', function(e) {
        if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight' && e.key !== 'Home' && e.key !== 'End') return;
        e.preventDefault();
        var idx = buttons.indexOf(btn);
        var nextIdx = idx;
        if (e.key === 'ArrowRight') nextIdx = (idx + 1) % buttons.length;
        else if (e.key === 'ArrowLeft') nextIdx = (idx - 1 + buttons.length) % buttons.length;
        else if (e.key === 'Home') nextIdx = 0;
        else if (e.key === 'End') nextIdx = buttons.length - 1;
        activate(buttons[nextIdx].getAttribute('data-tab'), true);
      });
    });

    // Digit shortcuts 1-7 jump directly to a tab (UX_UI_GUIDELINES "every dashboard tab reachable
    // by 1-9" convention). Ignored while focus is in a text input/select so typing "1" into the
    // max_issues field does not hijack the view.
    document.addEventListener('keydown', function(e) {
      var tag = (document.activeElement && document.activeElement.tagName) || '';
      if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
      var n = parseInt(e.key, 10);
      if (!n || n < 1 || n > buttons.length) return;
      activate(buttons[n - 1].getAttribute('data-tab'), true);
    });

    // Restore the remembered tab from THIS webview session's state, falling back to whatever the
    // host rendered as active (data-active-tab, from RulePacksWebviewProvider._activeTab) — the
    // client-remembered choice wins because it reflects the user's most recent in-session click,
    // which can be newer than what the host had when it built this HTML.
    var saved = (vscode.getState() || {}).activeTab;
    var initial = saved && buttons.some(function(b) { return b.getAttribute('data-tab') === saved; })
      ? saved
      : bar.getAttribute('data-active-tab');
    if (initial) activate(initial, false);
  })();
`;

/**
 * Generic settings grid (Automation / Extension tabs). Every control carries `data-setting-key`
 * matching a `saropaLints.<key>` suffix; `data-setting-array` marks the comma-separated text
 * fields that need splitting on the host side (done in `_handleUpdateSetting`, not here, so the
 * host's coercion logic has one implementation instead of duplicating it client + host).
 */
const SCRIPT_SETTINGS_GRID = `
  document.querySelectorAll('[data-setting-key]').forEach(function(el) {
    var eventName = (el.tagName === 'SELECT' || el.type === 'checkbox') ? 'change' : 'change';
    el.addEventListener(eventName, function() {
      var key = el.getAttribute('data-setting-key');
      var value = el.type === 'checkbox' ? el.checked : el.value;
      vscode.postMessage({ type: 'updateSetting', key: key, value: value });
    });
  });
`;

/**
 * Config file tab wiring: the 8 previously-UI-less `analysis_options_custom.yaml` keys.
 * Scalars/platforms post immediately on change; the three list sections (severities, banned
 * usage, diagnostic thresholds) use an explicit Add button plus a delegated remove-button
 * listener, since a new list row does not exist in the DOM yet for a `change` listener to attach to.
 */
const SCRIPT_CONFIG_FILE_TAB = `
  document.querySelectorAll('[data-scalar-key]').forEach(function(el) {
    el.addEventListener('change', function() {
      vscode.postMessage({ type: 'writeScalar', scalarKey: el.getAttribute('data-scalar-key'), value: el.value });
    });
  });

  (function wirePlatforms() {
    var boxes = document.querySelectorAll('[data-platform]');
    if (boxes.length === 0) return;
    function postAll() {
      var platforms = {};
      boxes.forEach(function(b) { platforms[b.getAttribute('data-platform')] = b.checked; });
      vscode.postMessage({ type: 'writePlatforms', platforms: platforms });
    }
    boxes.forEach(function(b) { b.addEventListener('change', postAll); });
  })();

  document.querySelectorAll('.cf-severity-level').forEach(function(sel) {
    sel.addEventListener('change', function() {
      vscode.postMessage({ type: 'writeSeverity', rule: sel.getAttribute('data-rule'), level: sel.value });
    });
  });

  var severityAddBtn = document.getElementById('cf-severity-add');
  if (severityAddBtn) {
    severityAddBtn.addEventListener('click', function() {
      var ruleInput = document.getElementById('cf-severity-rule');
      var levelSelect = document.getElementById('cf-severity-new-level');
      var rule = (ruleInput && ruleInput.value || '').trim();
      if (!rule) return;
      vscode.postMessage({ type: 'writeSeverity', rule: rule, level: levelSelect ? levelSelect.value : 'ERROR' });
      if (ruleInput) ruleInput.value = '';
    });
  }

  var bannedAddBtn = document.getElementById('cf-banned-add');
  if (bannedAddBtn) {
    bannedAddBtn.addEventListener('click', function() {
      var idInput = document.getElementById('cf-banned-identifier');
      var reasonInput = document.getElementById('cf-banned-reason');
      var identifier = (idInput && idInput.value || '').trim();
      if (!identifier) return;
      vscode.postMessage({ type: 'addBannedUsage', identifier: identifier, reason: reasonInput ? reasonInput.value : '' });
      if (idInput) idInput.value = '';
      if (reasonInput) reasonInput.value = '';
    });
  }

  var thresholdAddBtn = document.getElementById('cf-threshold-add');
  if (thresholdAddBtn) {
    thresholdAddBtn.addEventListener('click', function() {
      var ruleInput = document.getElementById('cf-threshold-rule');
      var warnInput = document.getElementById('cf-threshold-warn');
      var failInput = document.getElementById('cf-threshold-fail');
      var rule = (ruleInput && ruleInput.value || '').trim();
      if (!rule) return;
      var warn = warnInput && warnInput.value !== '' ? parseInt(warnInput.value, 10) : null;
      var fail = failInput && failInput.value !== '' ? parseInt(failInput.value, 10) : null;
      vscode.postMessage({ type: 'setDiagnosticThreshold', rule: rule, warn: warn, fail: fail });
      if (ruleInput) ruleInput.value = '';
      if (warnInput) warnInput.value = '';
      if (failInput) failInput.value = '';
    });
  }

  // Delegated remove-button handling: severities/banned-usage/thresholds rows are rebuilt on every
  // refresh, so per-row listeners would need to be re-attached each time anyway — one delegated
  // listener on document covers every current and future row without that bookkeeping.
  document.addEventListener('click', function(e) {
    var target = e.target;
    if (!target || !target.getAttribute) return;
    var removeSeverityRule = target.getAttribute('data-remove-severity');
    if (removeSeverityRule !== null) {
      vscode.postMessage({ type: 'removeSeverity', rule: removeSeverityRule });
      return;
    }
    var removeBannedId = target.getAttribute('data-remove-banned');
    if (removeBannedId !== null) {
      vscode.postMessage({ type: 'removeBannedUsage', identifier: removeBannedId });
      return;
    }
    var removeThresholdRule = target.getAttribute('data-remove-threshold');
    if (removeThresholdRule !== null) {
      vscode.postMessage({ type: 'removeDiagnosticThreshold', rule: removeThresholdRule });
      return;
    }
  });
`;

/**
 * Forwards clicks inside the embedded Analysis Optimizer card using the SAME id/class contract
 * its own standalone script (`analysisOptimizerScript.ts`) listens for — see that file for the
 * canonical list. Column-sort and the select-all checkbox bulk-select are intentionally NOT
 * replicated here (Phase 4 scope decision: the embedded card covers the primary actions —
 * scan/apply/remove/fix-syntax — sorting is a nicety available in the standalone panel via the
 * "Open standalone" deep link). Every button here posts through the SAME `vscode` handle already
 * acquired in {@link SCRIPT_PREAMBLE} — a second `acquireVsCodeApi()` call would throw (VS Code
 * allows exactly one per webview document), so this reuses it rather than re-acquiring.
 */
const SCRIPT_OPTIMIZER_EMBED = `
  (function wireOptimizerEmbed() {
    var embed = document.querySelector('.optimizer-embed-body');
    if (!embed) return;
    embed.addEventListener('click', function(e) {
      var target = e.target;
      if (!target) return;
      if (target.id === 'scan-btn') { vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'scan' } }); return; }
      if (target.id === 'open-config-btn') { vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'openConfig' } }); return; }
      if (target.id === 'fix-syntax-btn') { vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'fixSyntax' } }); return; }
      if (target.id === 'apply-all-btn') { vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'applyAll' } }); return; }
      if (target.id === 'apply-selected-btn') {
        var checked = embed.querySelectorAll('.rec-cb:checked');
        var patterns = Array.from(checked).map(function(cb) { return cb.dataset.pattern; });
        if (patterns.length > 0) vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'applySelected', patterns: patterns } });
        return;
      }
      if (target.classList.contains('apply-one-btn')) {
        vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'applyExclusion', pattern: target.dataset.pattern } });
        return;
      }
      if (target.classList.contains('remove-btn')) {
        vscode.postMessage({ type: 'optimizerCommand', optimizer: { type: 'removeExclusion', pattern: target.dataset.pattern } });
        return;
      }
      if (target.classList.contains('preview-toggle-btn')) {
        var previewRow = document.getElementById(target.dataset.target);
        if (previewRow) {
          var ownerRow = target.closest('tr');
          if (ownerRow && ownerRow.nextSibling !== previewRow) ownerRow.after(previewRow);
          previewRow.hidden = !previewRow.hidden;
        }
        return;
      }
    });
    var selectAll = embed.querySelector('#select-all-cb');
    if (selectAll) {
      selectAll.addEventListener('change', function() {
        var cbs = embed.querySelectorAll('.rec-cb');
        for (var i = 0; i < cbs.length; i++) { cbs[i].checked = selectAll.checked; }
      });
    }
  })();
`;

const SCRIPT_INIT = `
  applySort();
  applyFilters();
})();
`;

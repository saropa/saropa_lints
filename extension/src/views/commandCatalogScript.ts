/**
 * Client-side script for the command-catalog webview (search, filtering,
 * keyboard nav, frequent/recent bands). Split out of
 * commandCatalogWebviewHtml.ts so the ~700-line script string is its own
 * module. A fully static `String.raw` template — no interpolation.
 */

export function getScript(): string {
  return String.raw`
    (function () {
      const vscode = acquireVsCodeApi();
      const CC = typeof window.__COMMAND_CATALOG_I18N__ !== 'undefined' ? window.__COMMAND_CATALOG_I18N__ : {};
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

      // The sticky category sub-headers pin at top: var(--toolbar-h). Measure
      // the toolbar's rendered height and publish it so they sit just below the
      // toolbar rather than behind it. The toolbar wraps on narrow panes and
      // grows when the filter-chip strip appears, so the height is not constant;
      // a ResizeObserver re-measures on every such change (it coalesces to one
      // call per frame), with a window-resize fallback for hosts that lack it.
      const toolbarWrap = document.querySelector('.toolbar-wrap');
      function syncToolbarHeight() {
        if (!toolbarWrap) { return; }
        const h = Math.round(toolbarWrap.getBoundingClientRect().height);
        document.documentElement.style.setProperty('--toolbar-h', h + 'px');
      }
      if (toolbarWrap && typeof ResizeObserver === 'function') {
        new ResizeObserver(syncToolbarHeight).observe(toolbarWrap);
      } else {
        window.addEventListener('resize', syncToolbarHeight);
      }
      syncToolbarHeight();

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
            historyMoreBtn.textContent = CC.moreSuffix.replace(/\{count\}/g, String(overflow));
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
            ? CC.showLess
            : CC.moreSuffix.replace(/\{count\}/g, String(Math.max(0, overflow)));
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
          count.textContent = c + (c === 1 ? CC.runSingular : CC.runPlural);
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
            '<strong>' + (items ? items.length : 0) + '</strong> ' + CC.recentWord;
        }
      }

      applyHistory(window.__INITIAL_HISTORY__ || []);

      window.addEventListener('message', function (event) {
        const msg = event.data;
        if (msg && msg.type === 'history') {
          applyHistory(msg.items || []);
        }
        if (msg && msg.type === 'hydrateCatalogSearchRecent' && Array.isArray(msg.queries) && msg.queries.length > 0) {
          try {
            sessionStorage.setItem(CAT_RECENT_KEY, JSON.stringify(msg.queries.slice(0, CAT_RECENT_CAP)));
          } catch (_) { /* best-effort */ }
          catRecentRender();
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
          toggleAllBtn.textContent = collapsed ? CC.expandAll : CC.collapseAll;
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
         tracked in plan/UX_GUIDELINES.md (Part B). */
      var catalogRecentEl = document.getElementById('catalog-recent');
      var catalogRecentListEl = document.getElementById('catalog-recent-list');
      var catalogRecentClearEl = document.getElementById('catalog-recent-clear');
      var CAT_RECENT_KEY = 'saropa.commandCatalog.recentSearches';
      var CAT_RECENT_CAP = 10;
      var CAT_RECENT_DEBOUNCE_MS = 800;
      var catalogRecentTimer = null;

      (function hydrateCatRecentFromBuild() {
        var init = typeof window.__INITIAL_CATALOG_SEARCH_RECENT__ !== 'undefined'
          ? window.__INITIAL_CATALOG_SEARCH_RECENT__
          : null;
        if (init && Array.isArray(init) && init.length > 0) {
          try {
            sessionStorage.setItem(CAT_RECENT_KEY, JSON.stringify(init.slice(0, CAT_RECENT_CAP)));
          } catch (_) { /* best-effort */ }
        }
      })();

      function catRecentLoad() {
        try {
          var raw = sessionStorage.getItem(CAT_RECENT_KEY);
          if (!raw) return [];
          var p = JSON.parse(raw);
          return Array.isArray(p) ? p.filter(function (s) { return typeof s === 'string'; }) : [];
        } catch (e) { return []; }
      }
      var catRecentPersistTimer = null;
      function persistCatRecentDebounced(list) {
        if (catRecentPersistTimer) clearTimeout(catRecentPersistTimer);
        catRecentPersistTimer = setTimeout(function () {
          catRecentPersistTimer = null;
          try {
            vscode.postMessage({ type: 'saveCatalogSearchRecent', queries: list });
          } catch (_) { /* offline */ }
        }, 420);
      }
      function catRecentSave(list) {
        try { sessionStorage.setItem(CAT_RECENT_KEY, JSON.stringify(list)); } catch (e) { /* best-effort */ }
        persistCatRecentDebounced(list);
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
        if (query) chips.push({ kind: 'search', label: CC.searchChip.replace(/\{query\}/g, query) });
        if (showInternal) chips.push({ kind: 'internal', label: CC.internalChip });

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
            '" aria-label="' + escText(CC.removeFilterPrefix + chip.label) +
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
          ? (visibleCount === 1
              ? CC.matchOne.replace(/\{count\}/g, String(visibleCount))
              : CC.matchOther.replace(/\{count\}/g, String(visibleCount)))
          : '';

        if (searchClearBtn) searchClearBtn.hidden = !query;
        renderFilterChips(query, showInternal);
      }
    })();
  `;
}

/**
 * Known-issues webview **client script** returned as a single string for HTML injection.
 *
 * **Host contract:** expects element ids used below (`search-input`, `pkg-body`, chip strip,
 * KPI segments, empty state). Sorting is lexicographic on string columns; numeric columns
 * parse `data-*` attributes defensively because table cells may be placeholders.
 *
 * **Persistence:** recent searches use `sessionStorage` (panel lifetime only); see inline
 * note near `RECENT_STORAGE_KEY` for workspace-scoped follow-up.
 *
 * **Comment metric:** publish counts line comments and block comments only *outside*
 * template literals; the runtime lives mostly inside the template—keep cross-cutting
 * integration notes here.
 */
/**
 * @param idPrefix Prepended to every `getElementById` lookup for the ids that
 * {@link buildSummaryCards}/`buildToolbar`/`buildTable` in `known-issues-html.ts` render with the
 * same prefix. Empty string (the default) reproduces today's standalone-panel behavior exactly
 * (test-safe, no id changes for `KnownIssuesPanel`). `getKnownIssuesEmbedScript` below passes
 * `'ki-'` to match {@link getEmbeddedBodyHtml}'s markup.
 * @param root Element (or `document`) every query is scoped to. Left as `document` for the
 * standalone panel (its own dedicated document, safe to query globally); the embed passes the
 * `.ki-embed-body` wrapper so none of these queries can ever match the Package Dashboard's own
 * packages table, which uses several of the SAME unprefixed selectors (`th[data-col]`,
 * `.kpi-card.interactive[data-kpi]`) for its own sortable columns and KPI cards.
 */
export function getKnownIssuesScript(idPrefix = '', root: 'document' | string = 'document'): string {
    // Wire-up order: resolve DOM nodes → bind filters/chips → register sort handlers →
    // `applyFilters()` once so KPI active state matches the default filter on first paint.
    return `
        let sortCol = 'name';
        let sortAsc = true;

        // __ROOT__ is 'document' for the standalone panel (its own document, global queries are
        // safe) or a scoped element for the embed -- see this function's doc comment.
        var __ROOT__ = ${root === 'document' ? 'document' : `document.querySelector('${root}')`};
        function __id__(raw) { return __ROOT__.querySelector('#' + '${idPrefix}' + raw); }

        const searchInput = __id__('search-input');
        const searchClear = __id__('search-clear');
        const tbody = __id__('pkg-body');
        const countEl = __id__('visible-count');
        const filterButtons = Array.from(__ROOT__.querySelectorAll('.seg .seg-btn[data-filter]'));
        // These four are ALREADY 'ki-'-prefixed in known-issues-html.ts's markup for BOTH the
        // standalone panel and the embed (they never collided, so they were never candidates for
        // the idPrefix scheme above) -- queried directly, not through __id__, so the embed's
        // idPrefix='ki-' does not double-prefix them into a nonexistent '#kiki-chip-strip'.
        const chipStripEl = __ROOT__.querySelector('#ki-chip-strip');
        const chipBodyEl = __ROOT__.querySelector('#ki-chip-body');
        const clearAllEl = __ROOT__.querySelector('#ki-clear-all');
        const emptyEl = __ROOT__.querySelector('#ki-empty');
        const resetFiltersBtn = __ROOT__.querySelector('#ki-reset-filters');
        const recentEl = __id__('recent-searches');
        const recentListEl = __id__('recent-searches-list');
        const recentClearEl = __id__('recent-searches-clear');

        /* §8.5.2 — recent-searches storage. Uses sessionStorage so the list
           survives within the current panel session but resets when the panel
           is closed. Cross-session persistence (per-workspace history) is a
           follow-up that needs host-side wiring; tracked in
           plan/UX_GUIDELINES.md (Part B). */
        const RECENT_STORAGE_KEY = 'saropa.knownIssues.recentSearches';
        const RECENT_CAP = 10;
        const RECENT_COMMIT_MS = 800;
        let recentCommitTimer = null;

        window.addEventListener('message', function (event) {
            const d = event.data;
            if (d && d.type === 'hydrateKnownIssuesRecent' && Array.isArray(d.queries) && d.queries.length > 0) {
                writeRecentStorage(d.queries.filter(x => typeof x === 'string').slice(0, RECENT_CAP), false);
                renderRecent();
            }
        });

        function loadRecent() {
            try {
                const raw = sessionStorage.getItem(RECENT_STORAGE_KEY);
                if (!raw) { return []; }
                const parsed = JSON.parse(raw);
                return Array.isArray(parsed) ? parsed.filter(s => typeof s === 'string') : [];
            } catch (e) {
                return [];
            }
        }

        function writeRecentStorage(list, postToHost) {
            try {
                sessionStorage.setItem(RECENT_STORAGE_KEY, JSON.stringify(list));
            } catch (e) {
                /* sessionStorage may throw on quota or restricted contexts —
                   silently fall through; recent searches are best-effort. */
            }
            if (postToHost) {
                try {
                    vscode.postMessage({ type: 'saveKnownIssuesRecent', queries: list.slice(0, RECENT_CAP) });
                } catch (_) { /* offline / bridge missing */ }
            }
        }

        function saveRecent(list) {
            writeRecentStorage(list, true);
        }

        function recordRecent(query) {
            const trimmed = (query || '').trim();
            if (!trimmed) { return; }
            const existing = loadRecent().filter(s => s.toLowerCase() !== trimmed.toLowerCase());
            existing.unshift(trimmed);
            saveRecent(existing.slice(0, RECENT_CAP));
        }

        function removeRecent(query) {
            const list = loadRecent().filter(s => s !== query);
            saveRecent(list);
            renderRecent();
        }

        function clearAllRecent() {
            saveRecent([]);
            renderRecent();
            hideRecent();
        }

        function escapeForAttr(s) {
            return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
                .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        }

        function renderRecent() {
            if (!recentEl || !recentListEl) { return; }
            const list = loadRecent();
            if (list.length === 0) {
                recentListEl.innerHTML = '';
                return;
            }
            recentListEl.innerHTML = list.map(q => {
                const safe = escapeForAttr(q);
                return '<li>'
                    + '<button type="button" class="recent-pick" data-query="' + safe + '">'
                    + safe + '</button>'
                    + '<button type="button" class="recent-remove" data-query="' + safe
                    + '" aria-label="Remove ' + safe + '" title="Remove">&times;</button>'
                    + '</li>';
            }).join('');
        }

        function showRecent() {
            if (!recentEl) { return; }
            const list = loadRecent();
            if (list.length === 0) { recentEl.hidden = true; return; }
            renderRecent();
            recentEl.hidden = false;
        }

        function hideRecent() {
            if (recentEl) { recentEl.hidden = true; }
        }

        function maybeShowRecent() {
            // Show only when the input is focused AND empty — once the user
            // starts typing, the dropdown gets out of the way of search results.
            const focused = document.activeElement === searchInput;
            const empty = !searchInput.value.trim();
            if (focused && empty) { showRecent(); } else { hideRecent(); }
        }

        function updateSearchClearVisibility() {
            if (!searchClear || !searchInput) { return; }
            searchClear.hidden = searchInput.value.trim().length === 0;
        }

        /* Multi-toggle filter: each .seg-btn holds an aria-pressed boolean for one
           replacement bucket ("has" / "no"). Both pressed = show all rows; only one
           pressed = show only that bucket; neither pressed = show nothing (rare but
           consistent with the severity/impact filters in the Findings dashboard). */
        function isFilterActive(token) {
            const btn = filterButtons.find(b => b.getAttribute('data-filter') === token);
            return btn ? btn.getAttribute('aria-pressed') === 'true' : true;
        }

        /* §8.5.2 — search-highlight helpers. Wrap matched substrings in <mark>
           inside text nodes only so existing <a> links and other markup keep
           working. Highlights are reapplied each time applyFilters runs. */
        function highlightInRow(row, query) {
            const lowerQ = query.toLowerCase();
            const cells = row.querySelectorAll('td');
            cells.forEach(td => highlightTextNodes(td, lowerQ, query.length));
        }

        function highlightTextNodes(root, lowerQ, qLen) {
            // Collect all text nodes first so the live walker doesn't trip
            // over our DOM mutations during iteration.
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false);
            const candidates = [];
            let n = walker.nextNode();
            while (n) {
                if (n.parentElement && n.parentElement.tagName === 'MARK') {
                    n = walker.nextNode();
                    continue;
                }
                if (n.nodeValue.toLowerCase().indexOf(lowerQ) !== -1) {
                    candidates.push(n);
                }
                n = walker.nextNode();
            }
            candidates.forEach(node => wrapMatches(node, lowerQ, qLen));
        }

        function wrapMatches(textNode, lowerQ, qLen) {
            const text = textNode.nodeValue;
            const lower = text.toLowerCase();
            const parent = textNode.parentNode;
            let lastIdx = 0;
            let idx = lower.indexOf(lowerQ);
            while (idx !== -1) {
                if (idx > lastIdx) {
                    parent.insertBefore(
                        document.createTextNode(text.substring(lastIdx, idx)),
                        textNode,
                    );
                }
                const mark = document.createElement('mark');
                mark.className = 'search-hit';
                mark.textContent = text.substr(idx, qLen);
                parent.insertBefore(mark, textNode);
                lastIdx = idx + qLen;
                idx = lower.indexOf(lowerQ, lastIdx);
            }
            if (lastIdx < text.length) {
                parent.insertBefore(
                    document.createTextNode(text.substring(lastIdx)),
                    textNode,
                );
            }
            parent.removeChild(textNode);
        }

        function clearSearchHighlights() {
            // Replace each <mark.search-hit> with its text content; normalize the
            // parent so adjacent text nodes merge back into one — without this
            // the DOM grows fragmented by repeated highlight cycles.
            const marks = tbody.querySelectorAll('mark.search-hit');
            const parents = new Set();
            marks.forEach(m => {
                const parent = m.parentNode;
                parent.replaceChild(document.createTextNode(m.textContent), m);
                parents.add(parent);
            });
            parents.forEach(p => p.normalize());
        }

        function applyFilters() {
            const query = searchInput.value.trim().toLowerCase();
            const includeHas = isFilterActive('has');
            const includeNo = isFilterActive('no');
            let visible = 0;
            let totalRows = 0;

            // Strip any prior highlights before mutating display so re-applying
            // a different query doesn't double-wrap matches in stale <mark> tags.
            clearSearchHighlights();

            for (const row of tbody.querySelectorAll('tr')) {
                totalRows++;
                const text = row.dataset.searchtext || '';
                const hasReplacement = row.dataset.replacement !== '';
                const bucketIncluded = hasReplacement ? includeHas : includeNo;
                const matchesSearch = !query || text.includes(query);
                const show = matchesSearch && bucketIncluded;

                row.style.display = show ? '' : 'none';
                if (show) {
                    visible++;
                    // §8.5.2 — highlight matched substrings inside visible
                    // rows so users scanning a long list can see why each
                    // row matched. Only walks the visible (display !== none)
                    // rows so the work is bounded by what's actually shown.
                    if (query) { highlightInRow(row, query); }
                }
            }
            countEl.textContent = visible;

            // §4.2 / §14.8 — sync the active KPI card so the user sees which
            // preset is currently driving the filter. Default state (both
            // pressed, no query) lights nothing; "filter-has" / "filter-no"
            // map to the corresponding card.
            syncActiveKpiCard(query, includeHas, includeNo);
            // §8.5 / §14.10 — render the chip strip when filter state
            // diverges from defaults so the user can see and remove
            // active constraints at a glance.
            renderChipStrip(query, includeHas, includeNo);
            // §8.16 / §14.2 — empty-state banner appears only when filters
            // narrow the table to zero rows AND there were rows to begin
            // with (otherwise the upstream "no data" path applies, which
            // is not this surface's concern).
            if (emptyEl) {
                emptyEl.hidden = !(visible === 0 && totalRows > 0);
            }
            // §15.3 — announce filter state to screen readers.
            announce(visible + ' of ' + totalRows + ' packages visible');
        }

        // §15.3 — polite live-region announcer. __id__('announcer') resolves to '#announcer'
        // standalone (unchanged) or '#ki-announcer' embedded, matching getEmbeddedBodyHtml's own
        // announcer div -- see that function's doc comment.
        function announce(message) {
            const el = __id__('announcer');
            if (!el) { return; }
            el.textContent = '';
            setTimeout(() => { el.textContent = message; }, 50);
        }

        function syncActiveKpiCard(query, includeHas, includeNo) {
            // Scoped to __ROOT__ defensively: data-kpi is Known-Issues-specific today (the
            // Package Dashboard's own summary cards use data-filter, not data-kpi), but
            // scoping every query here to the embed root (rather than bare document) is the
            // convention every embedded tab follows so a future selector never silently reaches
            // outside this tab once this script and the host's share one document. NOTE: no
            // backticks in this comment -- this whole function body is one JS template literal,
            // and a stray backtick here would silently close the returned script string early.
            const cards = __ROOT__.querySelectorAll('.kpi-card.interactive[data-kpi]');
            cards.forEach(c => c.classList.remove('active'));
            const isDefault = !query && includeHas && includeNo;
            if (isDefault) { return; }
            let activeKpi = null;
            if (includeHas && !includeNo) { activeKpi = 'has'; }
            else if (!includeHas && includeNo) { activeKpi = 'no'; }
            if (!activeKpi) { return; }
            const target = __ROOT__.querySelector('.kpi-card.interactive[data-kpi="' + activeKpi + '"]');
            if (target) { target.classList.add('active'); }
        }

        function renderChipStrip(query, includeHas, includeNo) {
            if (!chipStripEl || !chipBodyEl) { return; }
            const chips = [];
            if (query) { chips.push({ key: 'search', label: 'search: "' + query + '"' }); }
            if (!includeHas) { chips.push({ key: 'has', label: 'excluding: with replacement' }); }
            if (!includeNo) { chips.push({ key: 'no', label: 'excluding: no replacement' }); }
            if (chips.length === 0) {
                chipStripEl.hidden = true;
                chipBodyEl.innerHTML = '';
                return;
            }
            chipStripEl.hidden = false;
            chipBodyEl.innerHTML = chips
                .map(c => '<span class="chip">' + c.label +
                    '<button type="button" class="x" data-chip="' + c.key + '" aria-label="Remove">×</button></span>')
                .join('');
            chipBodyEl.querySelectorAll('.chip .x').forEach(btn => {
                btn.addEventListener('click', () => removeChip(btn.getAttribute('data-chip')));
            });
        }

        function removeChip(key) {
            if (key === 'search') {
                searchInput.value = '';
                updateSearchClearVisibility();
            } else if (key === 'has') {
                const btn = filterButtons.find(b => b.getAttribute('data-filter') === 'has');
                if (btn) { btn.setAttribute('aria-pressed', 'true'); }
            } else if (key === 'no') {
                const btn = filterButtons.find(b => b.getAttribute('data-filter') === 'no');
                if (btn) { btn.setAttribute('aria-pressed', 'true'); }
            }
            applyFilters();
        }

        function resetAllFilters() {
            searchInput.value = '';
            setFilterState(true, true);
            updateSearchClearVisibility();
            applyFilters();
        }

        /* KPI card preset filters (guideline §4.2 / §14.8). data-kpi-action drives the
           filter buttons directly so the user gets one-click access to "show only with
           replacement", "show only without", or "reset everything". */
        function setFilterState(has, no) {
            filterButtons.forEach(b => {
                const t = b.getAttribute('data-filter');
                b.setAttribute('aria-pressed', (t === 'has' ? has : no) ? 'true' : 'false');
            });
        }

        function sortTable(col) {
            if (sortCol === col) {
                sortAsc = !sortAsc;
            } else {
                sortCol = col;
                sortAsc = true;
            }
            const rows = Array.from(tbody.querySelectorAll('tr'));
            rows.sort((a, b) => {
                const av = a.dataset[col] || '';
                const bv = b.dataset[col] || '';
                return sortAsc
                    ? av.localeCompare(bv)
                    : bv.localeCompare(av);
            });
            rows.forEach(r => tbody.appendChild(r));
            updateArrows();
        }

        function updateArrows() {
            // th[data-col] is also the Package Dashboard's own sortable-column marker
            // (report-html-table.ts / report-script-parts.ts) -- __ROOT__ scoping keeps this
            // table's sort arrows from being drawn on (or read from) the OTHER table's headers
            // once both scripts share one document.
            __ROOT__.querySelectorAll('th[data-col]').forEach(th => {
                const arrow = th.querySelector('.sort-arrow');
                if (th.dataset.col === sortCol) {
                    arrow.textContent = sortAsc ? ' \\u25B2' : ' \\u25BC';
                } else {
                    arrow.textContent = '';
                }
            });
        }

        searchInput.addEventListener('input', function() {
            applyFilters();
            updateSearchClearVisibility();
            // Hide recent dropdown once typing starts; re-show if cleared.
            maybeShowRecent();
            // Commit the current query to recent searches after a pause —
            // typing 'foo' should not record 'f', 'fo', 'foo'. Debounce so
            // only the settled query persists.
            if (recentCommitTimer) { clearTimeout(recentCommitTimer); }
            const snapshot = searchInput.value;
            recentCommitTimer = setTimeout(() => {
                recentCommitTimer = null;
                if (snapshot && searchInput.value === snapshot) {
                    recordRecent(snapshot);
                }
            }, RECENT_COMMIT_MS);
        });
        searchInput.addEventListener('focus', maybeShowRecent);
        searchInput.addEventListener('blur', function() {
            // Delay so a click on a recent item registers before we tear the
            // dropdown down — focusout on Chrome fires before click.
            setTimeout(hideRecent, 120);
        });
        searchInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && searchInput.value.trim()) {
                recordRecent(searchInput.value);
                hideRecent();
            }
        });
        if (recentListEl) {
            recentListEl.addEventListener('click', function(e) {
                const target = e.target;
                if (!target || !target.dataset) { return; }
                const q = target.dataset.query;
                if (!q) { return; }
                if (target.classList.contains('recent-pick')) {
                    searchInput.value = q;
                    applyFilters();
                    updateSearchClearVisibility();
                    hideRecent();
                    recordRecent(q);
                    searchInput.focus();
                } else if (target.classList.contains('recent-remove')) {
                    e.stopPropagation();
                    removeRecent(q);
                    searchInput.focus();
                }
            });
        }
        if (recentClearEl) {
            recentClearEl.addEventListener('click', clearAllRecent);
        }
        if (searchClear) {
            searchClear.addEventListener('click', function() {
                searchInput.value = '';
                applyFilters();
                updateSearchClearVisibility();
                searchInput.focus();
                maybeShowRecent();
            });
        }

        filterButtons.forEach(btn => {
            btn.addEventListener('click', function() {
                const pressed = btn.getAttribute('aria-pressed') === 'true';
                btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
                applyFilters();
            });
        });

        __ROOT__.querySelectorAll('.kpi-card.interactive[data-kpi-action]').forEach(card => {
            function fire() {
                const action = card.getAttribute('data-kpi-action');
                if (action === 'reset') {
                    searchInput.value = '';
                    setFilterState(true, true);
                    updateSearchClearVisibility();
                } else if (action === 'filter-has') {
                    setFilterState(true, false);
                } else if (action === 'filter-no') {
                    setFilterState(false, true);
                }
                applyFilters();
            }
            card.addEventListener('click', fire);
            card.addEventListener('keydown', e => {
                if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
            });
        });

        // §8.5 / §14.10 — *Clear all* in the chip strip and the empty-state
        // *Reset filters* button both dispatch to the same reset path so the
        // two affordances cannot drift out of sync.
        if (clearAllEl) { clearAllEl.addEventListener('click', resetAllFilters); }
        if (resetFiltersBtn) { resetFiltersBtn.addEventListener('click', resetAllFilters); }

        __ROOT__.querySelectorAll('th[data-col]').forEach(th => {
            th.addEventListener('click', () => sortTable(th.dataset.col));
        });

        // §4.2 / §14.8 — fire applyFilters once on load so the active KPI
        // sync runs against the initial (default) state, ensuring no card
        // is incorrectly marked active before the first user interaction.
        applyFilters();

        // The full-width toggle and the page-level '/' / Escape shortcuts below are the
        // standalone panel's OWN document-level chrome. The embed (getKnownIssuesEmbedScript,
        // root !== document) skips both: the Package Dashboard already renders its own
        // #dashFullWidthToggle (a second copy here would be a duplicate id, not a second working
        // toggle) and its own '?'-triggered shortcuts overlay with a document-level '/' handler
        // for the Overview tab's OWN search field -- adding a second global '/' handler here
        // would race that one for which input gets focused.
        ${root === 'document' ? `
        /* Full-width toggle (guideline §4) — flips body[data-full-width]. Idempotent. */
        (function() {
            var btn = document.getElementById('dashFullWidthToggle');
            if (!btn) return;
            btn.addEventListener('click', function() {
                var on = document.body.getAttribute('data-full-width') === 'true';
                document.body.setAttribute('data-full-width', on ? 'false' : 'true');
                btn.setAttribute('aria-pressed', on ? 'false' : 'true');
            });
        })();

        /* §15.2 — page-level keyboard shortcuts advertised in the overlay.
           '/' focuses the search input from anywhere on the page; 'Esc' on a
           focused, non-empty search clears it; 'Esc' on an open recent
           dropdown closes it. Skip when the user is already typing in
           another input. */
        document.addEventListener('keydown', function(e) {
            var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
            var isEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
            if (e.key === '/' && !isEditable) {
                e.preventDefault();
                if (searchInput) { searchInput.focus(); searchInput.select(); }
            } else if (e.key === 'Escape' && e.target === searchInput) {
                if (recentEl && !recentEl.hidden) {
                    e.preventDefault();
                    hideRecent();
                } else if (searchInput.value) {
                    e.preventDefault();
                    searchInput.value = '';
                    applyFilters();
                    updateSearchClearVisibility();
                }
            }
        });
        ` : ''}

        /* Close recent dropdown when clicking outside the search wrapper. Kept unconditional
           (embed included): it only reads this instance's own recentEl/searchInput closures, so
           there is nothing to collide with even when several embedded tabs' scripts each add
           their own copy of this listener. */
        document.addEventListener('click', function(e) {
            if (!recentEl || recentEl.hidden) { return; }
            const wrapper = searchInput.closest('.search-wrapper');
            if (wrapper && !wrapper.contains(e.target)) { hideRecent(); }
        });
    `;
}

/**
 * Client-side wiring for the embedded Known issues tab (PLAN_ext_ui_package_tabs.md §4 Tab 5).
 *
 * Unlike `getUpgradesEmbedScript()` (packages-tabs.ts), this is NOT a hand-written parallel
 * script -- `getKnownIssuesScript('ki-', '.ki-embed-body')` (the SAME function the standalone
 * panel calls with its defaults) already produces exactly the right id-prefixed, root-scoped
 * body, so there is nothing to duplicate. This wrapper only supplies the piece the shared
 * function cannot: an enclosing `(function(){...})()` so its `let`/`const`/`function`
 * declarations (`sortCol`, `applyFilters`, `announce`, ...) stay local to this IIFE instead of
 * colliding with same-named top-level declarations from any other script concatenated into the
 * Package Dashboard's single shared `<script>` tag (report-html.ts does NOT wrap
 * `getReportScript()`/`getPackagesTabsScript()`/etc. this way itself, so each embedded script is
 * responsible for wrapping its own contribution -- `getUpgradesEmbedScript` does the same).
 *
 * `vscode.postMessage({ type: 'saveKnownIssuesRecent', ... })` inside the wired script reuses the
 * document's single `acquireVsCodeApi()` handle (declared once in report-script-parts.ts) via the
 * bare `vscode` global -- no second call, no message-type wrapper envelope needed, because
 * `saveKnownIssuesRecent` / `hydrateKnownIssuesRecent` are already unique message names nothing
 * else in the shared document's switch handles. See report-webview.ts's `_handleMessage`.
 */
export function getKnownIssuesEmbedScript(): string {
    return `(function() {
${getKnownIssuesScript('ki-', '.ki-embed-body')}
})();`;
}

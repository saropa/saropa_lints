/** Client-side JavaScript for the known issues browser (search, filter, sort). */
export function getKnownIssuesScript(): string {
    return `
        let sortCol = 'name';
        let sortAsc = true;

        const searchInput = document.getElementById('search-input');
        const searchClear = document.getElementById('search-clear');
        const tbody = document.getElementById('pkg-body');
        const countEl = document.getElementById('visible-count');
        const filterButtons = Array.from(document.querySelectorAll('.seg .seg-btn[data-filter]'));
        const chipStripEl = document.getElementById('ki-chip-strip');
        const chipBodyEl = document.getElementById('ki-chip-body');
        const clearAllEl = document.getElementById('ki-clear-all');
        const emptyEl = document.getElementById('ki-empty');
        const resetFiltersBtn = document.getElementById('ki-reset-filters');

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

        function applyFilters() {
            const query = searchInput.value.trim().toLowerCase();
            const includeHas = isFilterActive('has');
            const includeNo = isFilterActive('no');
            let visible = 0;
            let totalRows = 0;

            for (const row of tbody.querySelectorAll('tr')) {
                totalRows++;
                const text = row.dataset.searchtext || '';
                const hasReplacement = row.dataset.replacement !== '';
                const bucketIncluded = hasReplacement ? includeHas : includeNo;
                const matchesSearch = !query || text.includes(query);
                const show = matchesSearch && bucketIncluded;

                row.style.display = show ? '' : 'none';
                if (show) { visible++; }
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
        }

        function syncActiveKpiCard(query, includeHas, includeNo) {
            const cards = document.querySelectorAll('.kpi-card.interactive[data-kpi]');
            cards.forEach(c => c.classList.remove('active'));
            const isDefault = !query && includeHas && includeNo;
            if (isDefault) { return; }
            let activeKpi = null;
            if (includeHas && !includeNo) { activeKpi = 'has'; }
            else if (!includeHas && includeNo) { activeKpi = 'no'; }
            if (!activeKpi) { return; }
            const target = document.querySelector('.kpi-card.interactive[data-kpi="' + activeKpi + '"]');
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
            document.querySelectorAll('th[data-col]').forEach(th => {
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
        });
        if (searchClear) {
            searchClear.addEventListener('click', function() {
                searchInput.value = '';
                applyFilters();
                updateSearchClearVisibility();
                searchInput.focus();
            });
        }

        filterButtons.forEach(btn => {
            btn.addEventListener('click', function() {
                const pressed = btn.getAttribute('aria-pressed') === 'true';
                btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
                applyFilters();
            });
        });

        document.querySelectorAll('.kpi-card.interactive[data-kpi-action]').forEach(card => {
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

        document.querySelectorAll('th[data-col]').forEach(th => {
            th.addEventListener('click', () => sortTable(th.dataset.col));
        });

        // §4.2 / §14.8 — fire applyFilters once on load so the active KPI
        // sync runs against the initial (default) state, ensuring no card
        // is incorrectly marked active before the first user interaction.
        applyFilters();

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
    `;
}

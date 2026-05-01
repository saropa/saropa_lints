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

            for (const row of tbody.querySelectorAll('tr')) {
                const text = row.dataset.searchtext || '';
                const hasReplacement = row.dataset.replacement !== '';
                const bucketIncluded = hasReplacement ? includeHas : includeNo;
                const matchesSearch = !query || text.includes(query);
                const show = matchesSearch && bucketIncluded;

                row.style.display = show ? '' : 'none';
                if (show) { visible++; }
            }
            countEl.textContent = visible;
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

        document.querySelectorAll('th[data-col]').forEach(th => {
            th.addEventListener('click', () => sortTable(th.dataset.col));
        });

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

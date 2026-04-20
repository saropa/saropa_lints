/** Client-side JavaScript for the known issues browser (search, filter, sort). */
export function getKnownIssuesScript(): string {
    return `
        let sortCol = 'name';
        let sortAsc = true;

        const searchInput = document.getElementById('search-input');
        const searchClear = document.getElementById('search-clear');
        const filterCheckbox = document.getElementById('filter-has-replacement');
        const tbody = document.getElementById('pkg-body');
        const countEl = document.getElementById('visible-count');

        /* Toggle the inline clear (X) button's visibility based on whether
           the trimmed input has any content. Called on every input event
           and after the button clears the field. */
        function updateSearchClearVisibility() {
            if (!searchClear || !searchInput) { return; }
            searchClear.hidden = searchInput.value.trim().length === 0;
        }

        function applyFilters() {
            /* Trim pasted whitespace (leading/trailing spaces, newlines, tabs)
               so copy-paste from package lists or terminal output still
               matches — users rarely intend to search for a literal space. */
            const query = searchInput.value.trim().toLowerCase();
            const onlyWithReplacement = filterCheckbox.checked;
            let visible = 0;

            for (const row of tbody.querySelectorAll('tr')) {
                const text = row.dataset.searchtext || '';
                const hasReplacement = row.dataset.replacement !== '';
                const matchesSearch = !query || text.includes(query);
                const matchesFilter = !onlyWithReplacement || hasReplacement;
                const show = matchesSearch && matchesFilter;

                row.style.display = show ? '' : 'none';
                if (show) { visible++; }
            }
            countEl.textContent = visible;
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
        filterCheckbox.addEventListener('change', applyFilters);

        document.querySelectorAll('th[data-col]').forEach(th => {
            th.addEventListener('click', () => sortTable(th.dataset.col));
        });
    `;
}

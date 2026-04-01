/** Client-side JavaScript for the package detail webview panel. */
export function getPackageDetailScript(): string {
    return `
        const vscode = acquireVsCodeApi();

        // Section collapse/expand
        document.querySelectorAll('.section-header').forEach(header => {
            header.addEventListener('click', () => {
                header.parentElement.classList.toggle('collapsed');
            });
        });

        // Each gap toolbar is scoped to its parent section so multiple
        // gap sections (version-gap + override-gap) don't interfere.
        document.querySelectorAll('.gap-toolbar').forEach(toolbar => {
            const section = toolbar.closest('.section');
            const searchInput = toolbar.querySelector('.gap-search');
            const filterBtns = toolbar.querySelectorAll('.filter-btn');

            function applyFilters() {
                const searchText = (searchInput?.value || '').toLowerCase();
                const activeBtn = toolbar.querySelector('.filter-btn.active');
                const activeFilter = activeBtn?.dataset.filter || 'all';
                const rows = section.querySelectorAll('.gap-table tbody tr');

                rows.forEach(row => {
                    const text = row.dataset.searchtext || '';
                    const type = row.dataset.type || '';
                    const reviewStatus = row.dataset.review || 'unreviewed';

                    let visible = text.includes(searchText);

                    if (visible && activeFilter === 'prs') { visible = type === 'pr'; }
                    if (visible && activeFilter === 'issues') { visible = type === 'issue'; }
                    if (visible && activeFilter === 'unreviewed') { visible = reviewStatus === 'unreviewed'; }

                    row.style.display = visible ? '' : 'none';
                });
            }

            if (searchInput) {
                searchInput.addEventListener('input', applyFilters);
            }

            filterBtns.forEach(btn => {
                btn.addEventListener('click', () => {
                    filterBtns.forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    applyFilters();
                });
            });
        });

        // Review status change — scoped to the row's parent table section
        document.querySelectorAll('.review-select').forEach(select => {
            select.addEventListener('change', (e) => {
                const target = e.target;
                const row = target.closest('tr');
                const itemNumber = parseInt(row.dataset.number, 10);
                const status = target.value;

                row.dataset.review = status;

                vscode.postMessage({
                    type: 'setReviewStatus',
                    itemNumber: itemNumber,
                    status: status,
                });

                // Update the summary within this section only
                updateReviewSummary(row.closest('.section'));
            });
        });

        // Notes editing with debounce
        let noteTimers = {};
        document.querySelectorAll('.notes-input').forEach(input => {
            input.addEventListener('input', (e) => {
                const target = e.target;
                const row = target.closest('tr');
                const itemNumber = parseInt(row.dataset.number, 10);

                clearTimeout(noteTimers[itemNumber]);
                noteTimers[itemNumber] = setTimeout(() => {
                    vscode.postMessage({
                        type: 'addReviewNote',
                        itemNumber: itemNumber,
                        notes: target.value,
                    });
                }, 500);
            });
        });

        // Sort by column — scoped to the clicked table
        document.querySelectorAll('.gap-table th[data-col]').forEach(th => {
            th.addEventListener('click', () => {
                const col = th.dataset.col;
                const table = th.closest('table');
                const tbody = table.querySelector('tbody');
                const rows = Array.from(tbody.querySelectorAll('tr'));
                const asc = th.dataset.sort !== 'asc';
                th.dataset.sort = asc ? 'asc' : 'desc';

                rows.sort((a, b) => {
                    const aVal = a.querySelector('[data-sort-' + col + ']')?.dataset['sort' + capitalize(col)] || '';
                    const bVal = b.querySelector('[data-sort-' + col + ']')?.dataset['sort' + capitalize(col)] || '';
                    const cmp = aVal.localeCompare(bVal, undefined, { numeric: true });
                    return asc ? cmp : -cmp;
                });

                rows.forEach(row => tbody.appendChild(row));

                // Update sort arrows within this table only
                table.querySelectorAll('th .sort-arrow').forEach(s => s.textContent = '');
                th.querySelector('.sort-arrow').textContent = asc ? ' \\u25B2' : ' \\u25BC';
            });
        });

        function capitalize(str) {
            return str.charAt(0).toUpperCase() + str.slice(1);
        }

        /** Update review summary text within a specific section. */
        function updateReviewSummary(section) {
            if (!section) { return; }
            const rows = section.querySelectorAll('.gap-table tbody tr');
            let total = rows.length;
            let triaged = 0;
            let applicable = 0;
            let notApplicable = 0;

            rows.forEach(row => {
                const status = row.dataset.review || 'unreviewed';
                if (status !== 'unreviewed') { triaged++; }
                if (status === 'applicable') { applicable++; }
                if (status === 'not-applicable') { notApplicable++; }
            });

            const summary = section.querySelector('.review-summary');
            if (summary) {
                summary.textContent = triaged + ' of ' + total + ' triaged | '
                    + applicable + ' applicable | '
                    + notApplicable + ' N/A | '
                    + (total - triaged) + ' remaining';
            }
        }

        // Action buttons — delegated to document
        document.addEventListener('click', (e) => {
            const btn = e.target.closest('[data-action]');
            if (!btn) { return; }

            const action = btn.dataset.action;
            if (action === 'openUrl') {
                vscode.postMessage({ type: 'openUrl', url: btn.dataset.url });
            } else if (action === 'openFile') {
                vscode.postMessage({ type: 'openFile', path: btn.dataset.path, line: parseInt(btn.dataset.line, 10) || 1 });
            } else if (action === 'upgrade') {
                vscode.postMessage({
                    type: 'upgrade',
                    name: btn.dataset.name,
                    version: btn.dataset.version,
                });
            } else if (action === 'changelog') {
                vscode.postMessage({
                    type: 'openUrl',
                    url: 'https://pub.dev/packages/' + btn.dataset.name + '/changelog',
                });
            }
        });
    `;
}

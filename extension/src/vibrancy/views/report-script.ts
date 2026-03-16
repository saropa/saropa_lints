/** Client-side JavaScript for the report webview (sorting + filtering). */
export function getReportScript(): string {
    return `
        const vscode = acquireVsCodeApi();
        let sortCol = 'score';
        let sortAsc = true;

        function sortTable(col) {
            if (sortCol === col) {
                sortAsc = !sortAsc;
            } else {
                sortCol = col;
                sortAsc = true;
            }
            const tbody = document.getElementById('pkg-body');
            const rows = Array.from(tbody.querySelectorAll('tr'));
            rows.sort((a, b) => {
                const av = a.dataset[col] || '';
                const bv = b.dataset[col] || '';
                const an = parseFloat(av);
                const bn = parseFloat(bv);
                if (!isNaN(an) && !isNaN(bn)) {
                    return sortAsc ? an - bn : bn - an;
                }
                return sortAsc ? av.localeCompare(bv) : bv.localeCompare(av);
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

        document.querySelectorAll('th[data-col]').forEach(th => {
            th.addEventListener('click', () => sortTable(th.dataset.col));
        });
    `;
}

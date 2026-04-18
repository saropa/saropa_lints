/** Client-side JavaScript for the report webview (sorting, filtering, search). */
export function getReportScript(): string {
    return `
        var vscode = acquireVsCodeApi();

        /* ---- Sorting state ---- */
        var sortCol = 'score';
        var sortAsc = true;

        /* ---- Filter state (shared across card, chart, and search filters) ---- */
        var activeCardFilter = null;
        var chartFilterPackage = null;
        var excludeSharedTransitives = false;

        /* ---- Sorting ---- */

        function sortTable(col) {
            if (sortCol === col) { sortAsc = !sortAsc; }
            else { sortCol = col; sortAsc = true; }
            var tbody = document.getElementById('pkg-body');
            /* Guard: bail if table body is not in the DOM yet. */
            if (!tbody) { return; }
            var rows = Array.from(tbody.querySelectorAll('tr'));
            rows.sort(function(a, b) {
                var av = a.dataset[col] || '';
                var bv = b.dataset[col] || '';
                var an = parseFloat(av);
                var bn = parseFloat(bv);
                if (!isNaN(an) && !isNaN(bn)) {
                    return sortAsc ? an - bn : bn - an;
                }
                return sortAsc ? av.localeCompare(bv) : bv.localeCompare(av);
            });
            rows.forEach(function(r) { tbody.appendChild(r); });
            updateArrows();
        }

        function updateArrows() {
            document.querySelectorAll('th[data-col]').forEach(function(th) {
                var arrow = th.querySelector('.sort-arrow');
                if (th.dataset.col === sortCol) {
                    arrow.textContent = sortAsc ? ' \\u25B2' : ' \\u25BC';
                } else {
                    arrow.textContent = '';
                }
            });
        }

        document.querySelectorAll('th[data-col]').forEach(function(th) {
            th.addEventListener('click', function() { sortTable(th.dataset.col); });
        });

        /* ---- Unified filter engine ---- */

        function applyFilters() {
            var searchVal = '';
            var searchEl = document.getElementById('search-input');
            if (searchEl) { searchVal = searchEl.value.toLowerCase(); }
            var rows = document.querySelectorAll('#pkg-body tr');
            rows.forEach(function(row) {
                var show = matchesAllFilters(row, searchVal);
                row.style.display = show ? '' : 'none';
            });
        }

        function matchesAllFilters(row, searchVal) {
            if (searchVal && (row.dataset.name || '').toLowerCase().indexOf(searchVal) === -1) {
                return false;
            }
            if (activeCardFilter && !matchesCardFilter(row, activeCardFilter)) {
                return false;
            }
            if (chartFilterPackage && row.dataset.name !== chartFilterPackage) {
                return false;
            }
            // Hide shared transitive rows when the "Exclude shared" chart
            // toggle is checked — these deps are already pulled in by
            // other direct deps, so removing any single dep won't help.
            if (excludeSharedTransitives && row.dataset.sharedTransitive === 'yes') {
                return false;
            }
            return true;
        }

        function matchesCardFilter(row, filter) {
            switch (filter) {
                case 'vibrant': case 'stable': case 'outdated':
                case 'abandoned': case 'end-of-life':
                    return row.dataset.category === filter;
                case 'updates':
                    return row.dataset.update !== 'up-to-date'
                        && row.dataset.update !== 'unknown';
                case 'unused':
                    return row.dataset.status === 'unused';
                case 'single-use':
                    return row.dataset.files === '1';
                case 'vulns':
                    return parseInt(row.dataset.vulns, 10) > 0;
                case 'overrides':
                    return row.dataset.overridden === 'yes';
                default:
                    return true;
            }
        }

        /* ---- Summary card click-to-filter ---- */

        function filterByCard(filterValue) {
            if (activeCardFilter === filterValue) {
                activeCardFilter = null;
            } else {
                activeCardFilter = filterValue;
            }
            applyFilters();
            updateCardStyles();
        }

        function updateCardStyles() {
            document.querySelectorAll('.summary-card[data-filter]').forEach(function(card) {
                card.classList.toggle('card-active', card.dataset.filter === activeCardFilter);
            });
        }

        document.querySelectorAll('.summary-card[data-filter]').forEach(function(card) {
            card.addEventListener('click', function() {
                filterByCard(card.dataset.filter);
            });
        });

        /* ---- Chart filter toggle (called from chart-script.ts) ---- */

        function toggleChartFilter(packageName) {
            if (!packageName) { return; }
            if (chartFilterPackage === packageName) {
                chartFilterPackage = null;
            } else {
                chartFilterPackage = packageName;
            }
            applyFilters();
            updateChartFilterIndicator();
        }

        function updateChartFilterIndicator() {
            var indicator = document.getElementById('chart-filter-indicator');
            if (!indicator) { return; }
            var textEl = indicator.querySelector('.filter-text');
            if (chartFilterPackage) {
                if (textEl) { textEl.textContent = 'Filtered: ' + chartFilterPackage; }
                indicator.style.display = 'flex';
            } else {
                indicator.style.display = 'none';
            }
        }

        var clearChartBtn = document.getElementById('clear-chart-filter');
        if (clearChartBtn) {
            clearChartBtn.addEventListener('click', function() {
                chartFilterPackage = null;
                applyFilters();
                updateChartFilterIndicator();
            });
        }

        /* ---- Exclude shared transitives (called from chart-script.ts) ---- */

        function setExcludeShared(exclude) {
            excludeSharedTransitives = exclude;
            applyFilters();
        }

        /* ---- Search box ---- */

        var searchInput = document.getElementById('search-input');
        if (searchInput) {
            searchInput.addEventListener('keyup', function() { applyFilters(); });
        }

        /* ---- Copy row as JSON ---- */

        document.querySelectorAll('.copy-btn').forEach(function(btn) {
            var copyIcon = btn.textContent;
            btn.addEventListener('click', function(e) {
                e.stopPropagation();
                var pkg = btn.dataset.pkg;
                var data = packageData[pkg];
                if (!data) { return; }
                /* Guard: ignore rapid re-clicks while feedback is showing */
                if (btn.classList.contains('copied')) { return; }
                var json = JSON.stringify(data, null, 2);
                navigator.clipboard.writeText(json).then(function() {
                    btn.textContent = '\\u2713';
                    btn.classList.add('copied');
                    setTimeout(function() {
                        btn.textContent = copyIcon;
                        btn.classList.remove('copied');
                    }, 1500);
                });
            });
        });

        /* ---- Open pubspec.yaml ---- */

        var pubspecBtn = document.getElementById('open-pubspec');
        if (pubspecBtn) {
            pubspecBtn.addEventListener('click', function() {
                vscode.postMessage({ type: 'openPubspec' });
            });
        }

        /* ---- Package name click -> open pubspec.yaml at entry ---- */

        document.querySelectorAll('.pkg-name-link').forEach(function(el) {
            el.addEventListener('click', function() {
                vscode.postMessage({ type: 'openPubspecEntry', package: el.dataset.pkg });
            });
        });

        /* ---- References click -> search for package imports ---- */

        document.querySelectorAll('.ref-link').forEach(function(el) {
            el.addEventListener('click', function() {
                vscode.postMessage({ type: 'searchImport', package: el.dataset.pkg });
            });
        });

        /* ---- Radial gauge animation ---- */
        /* Trigger the CSS transition after the DOM is painted by setting
           the final stroke-dasharray value on the next animation frame. */
        requestAnimationFrame(function() {
            var gaugeFill = document.querySelector('.gauge-fill');
            if (gaugeFill) {
                var target = parseFloat(gaugeFill.style.getPropertyValue('--gauge-target')) || 0;
                var arc = parseFloat(gaugeFill.style.getPropertyValue('--gauge-arc')) || 999;
                gaugeFill.setAttribute('stroke-dasharray', target + ' ' + (arc * 2));
            }
        });

        /* ---- Row expansion (chevron click toggles detail row) ---- */

        var focusedRowIdx = -1;

        document.querySelectorAll('.expand-cell').forEach(function(cell) {
            cell.addEventListener('click', function(e) {
                e.stopPropagation();
                var pkgRow = cell.closest('.pkg-row');
                if (pkgRow) { toggleDetail(pkgRow); }
            });
        });

        /* Click anywhere on the row (except links/buttons) also toggles. */
        document.querySelectorAll('.pkg-row').forEach(function(row) {
            row.addEventListener('click', function(e) {
                var tag = e.target.tagName;
                /* Don't toggle if the user clicked a link, button, or interactive element. */
                if (tag === 'A' || tag === 'BUTTON' || e.target.classList.contains('copy-btn')
                    || e.target.classList.contains('pkg-name-link')
                    || e.target.classList.contains('ref-link')) { return; }
                toggleDetail(row);
            });
        });

        function toggleDetail(pkgRow) {
            var name = pkgRow.dataset.name;
            var detailRow = document.querySelector('tr[data-detail-for="' + name + '"]');
            if (!detailRow) { return; }
            var isExpanded = pkgRow.classList.contains('expanded');
            if (isExpanded) {
                pkgRow.classList.remove('expanded');
                detailRow.style.display = 'none';
            } else {
                pkgRow.classList.add('expanded');
                detailRow.style.display = '';
            }
        }

        /* ---- Keyboard navigation ---- */

        document.addEventListener('keydown', function(e) {
            var rows = Array.from(document.querySelectorAll('.pkg-row'));
            /* Only visible rows */
            rows = rows.filter(function(r) { return r.style.display !== 'none'; });
            if (rows.length === 0) { return; }

            if (e.key === 'ArrowDown' || e.key === 'j') {
                e.preventDefault();
                focusedRowIdx = Math.min(focusedRowIdx + 1, rows.length - 1);
                highlightRow(rows);
            } else if (e.key === 'ArrowUp' || e.key === 'k') {
                e.preventDefault();
                focusedRowIdx = Math.max(focusedRowIdx - 1, 0);
                highlightRow(rows);
            } else if (e.key === 'Enter' || e.key === ' ') {
                /* Don't intercept if the user is typing in the search box. */
                if (document.activeElement && document.activeElement.id === 'search-input') { return; }
                e.preventDefault();
                if (focusedRowIdx >= 0 && focusedRowIdx < rows.length) {
                    toggleDetail(rows[focusedRowIdx]);
                }
            } else if (e.key === 'Escape') {
                /* Collapse all expanded rows and clear focus. */
                document.querySelectorAll('.pkg-row.expanded').forEach(function(row) {
                    toggleDetail(row);
                });
                focusedRowIdx = -1;
                highlightRow(rows);
            }
        });

        function highlightRow(rows) {
            rows.forEach(function(r, i) {
                r.classList.toggle('row-focused', i === focusedRowIdx);
            });
            if (focusedRowIdx >= 0 && focusedRowIdx < rows.length) {
                rows[focusedRowIdx].scrollIntoView({ block: 'nearest' });
            }
        }
    `;
}

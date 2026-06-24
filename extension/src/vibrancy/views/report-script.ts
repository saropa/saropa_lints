/**
 * Embeds the **report webview** client script as one HTML-safe string (no external `.js`).
 * The returned template is injected into the Vibrancy report panel; it uses `acquireVsCodeApi`
 * for `postMessage` back to the extension (open package, navigate, filter sync).
 *
 * **State:** sort column/direction, card/chart/search filters, footprint mode (`own` | `unique` | `total`),
 * preset selection, and package navigation history for back/forward.
 *
 * **DOM contract:** expects `#pkg-body`, rows with `.pkg-row`, `data-*` attributes for sort keys,
 * and companion detail rows managed by the sort routine (detail rows follow their parent package row).
 *
 * **Algorithms:** table sort is stable for package rows; category/score columns use locale-aware
 * string compare with deterministic tie-breakers so CI and user machines match.
 */
// Client script for the vibrancy **report** panel (sort, footprint modes, presets, charts).
// Message bridge: `acquireVsCodeApi().postMessage` for navigation + filter sync with extension.
// Table model: only `.pkg-row` participates in stable sort; detail rows are reattached in-order.
// Keyboard model: vim-ish j/k row focus; `/` focuses search from non-editable targets; Esc collapses.
/** Client-side JavaScript for the report webview (sorting, filtering, search). */
export function getReportScript(): string {
    return `
        var vscode = acquireVsCodeApi();

        /* ---- Sorting state ---- */
        var sortCol = 'score';
        var sortAsc = true;
        var isRestoringState = false;

        /* Dependency-graph depth. false = collapsed at depth 1 (direct deps
         * only) — the default so large graphs open readable; true = also show
         * the depth-2 transitive column and edges. Held at script scope so a
         * filter-driven re-render preserves the user's expand choice instead of
         * snapping back to collapsed. */
        var networkExpanded = false;

        /* ---- Filter state (shared across card, chart, and search filters) ---- */
        var activeCardFilter = null;
        var chartFilterPackage = null;
        var excludeSharedTransitives = false;
        var includeDevDependencies = true;
        var maxAgeMonths = Number.POSITIVE_INFINITY;
        var activePreset = 'none';
        var packageNavHistory = [];

        /* Footprint mode controls which size value the Size column shows
           and which size the size sort uses: 'own' | 'unique' | 'total'. */
        var footprintMode = 'own';

        /* ---- Sorting ---- */

        // Stable sort of .pkg-row only; detail rows reinserted after each parent (see DOM contract in module doc).
        function sortTable(col, keepDirection) {
            if (keepDirection) {
                sortCol = col;
            } else if (sortCol === col) { sortAsc = !sortAsc; }
            else { sortCol = col; sortAsc = true; }
            var tbody = document.getElementById('pkg-body');
            /* Guard: bail if table body is not in the DOM yet. */
            if (!tbody) { return; }
            /* Only sort package rows; detail rows follow their parent. */
            var pkgRows = Array.from(tbody.querySelectorAll('tr.pkg-row'));
            pkgRows.sort(function(a, b) {
                // Category requires deterministic lexical ordering by category
                // label, then package name as a tie-breaker.
                if (col === 'score') {
                    var ac = a.dataset.category || '';
                    var bc = b.dataset.category || '';
                    var byCategory = sortAsc ? ac.localeCompare(bc) : bc.localeCompare(ac);
                    if (byCategory !== 0) { return byCategory; }
                    var aname = a.dataset.name || '';
                    var bname = b.dataset.name || '';
                    return aname.localeCompare(bname);
                }
                /* The Size column has three precomputed values per cell;
                   sort using whichever footprint mode is active. */
                var av, bv;
                if (col === 'size') {
                    var ac = a.querySelector('.size-cell');
                    var bc = b.querySelector('.size-cell');
                    var attr = 'sizeOwn';
                    if (footprintMode === 'unique') { attr = 'sizeUnique'; }
                    else if (footprintMode === 'total') { attr = 'sizeTotal'; }
                    av = (ac && ac.dataset[attr]) || '0';
                    bv = (bc && bc.dataset[attr]) || '0';
                } else {
                    av = a.dataset[col] || '';
                    bv = b.dataset[col] || '';
                }
                var an = parseFloat(av);
                var bn = parseFloat(bv);
                if (!isNaN(an) && !isNaN(bn)) {
                    var delta = sortAsc ? an - bn : bn - an;
                    if (delta !== 0) { return delta; }
                    var anameNum = a.dataset.name || '';
                    var bnameNum = b.dataset.name || '';
                    return anameNum.localeCompare(bnameNum);
                }
                return sortAsc ? av.localeCompare(bv) : bv.localeCompare(av);
            });
            /* Re-insert each package row followed by its detail row. */
            pkgRows.forEach(function(r) {
                tbody.appendChild(r);
                var detail = document.querySelector('tr[data-detail-for="' + r.dataset.name + '"]');
                if (detail) { tbody.appendChild(detail); }
            });
            updateArrows();
            // Sort changes are also "view dirty" events — sortTable runs from
            // the column header click handler and from setFootprintMode's
            // resort, neither of which goes through applyFilters.
            updateResetViewVisibility();
            saveUIState();
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
            /* Trim pasted whitespace (leading/trailing spaces, newlines, tabs)
               so copy-paste from package lists or terminal output still
               matches — users rarely intend to search for a literal space. */
            if (searchEl) { searchVal = searchEl.value.trim().toLowerCase(); }
            var rows = document.querySelectorAll('#pkg-body tr.pkg-row');
            rows.forEach(function(row) {
                var show = matchesAllFilters(row, searchVal);
                row.style.display = show ? '' : 'none';
                /* When a package row is hidden, also hide its detail row.
                 * Use the HTML5 hidden boolean property so the default-collapsed
                 * state survives every renderer that respects the spec — see
                 * toggleDetail() below for the rationale. */
                var detailRow = document.querySelector('tr[data-detail-for="' + row.dataset.name + '"]');
                if (detailRow && !show) {
                    detailRow.hidden = true;
                    row.classList.remove('expanded');
                }
            });
            updateActiveFiltersUI(searchVal);
            // Reset-view visibility piggybacks on the filter pipeline so any
            // path that changes filter state (toolbar, chip removal, card,
            // chart, search) goes through one update site.
            updateResetViewVisibility();
            // Keep the dependency network in sync with the rows just shown/
            // hidden. renderNetwork is hoisted, so calling it here (even from
            // the init-time applyFilters that runs before its declaration) is
            // safe. It reads each row's display, so it must run after the
            // forEach above has set visibility for this pass.
            renderNetwork();
            saveUIState();
        }

        function matchesAllFilters(row, searchVal) {
            if (searchVal && (row.dataset.name || '').toLowerCase().indexOf(searchVal) === -1) {
                return false;
            }
            if (activeCardFilter && !matchesCardFilter(row, activeCardFilter)) {
                return false;
            }
            if (!includeDevDependencies && row.dataset.section === 'dev_dependencies') {
                return false;
            }
            var ageMonths = parseFloat(row.dataset.ageMonths || '');
            if (Number.isFinite(maxAgeMonths) && !isNaN(ageMonths) && ageMonths > maxAgeMonths) {
                return false;
            }
            if (!matchesPresetFilter(row)) {
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

        function saveUIState() {
            if (isRestoringState) { return; }
            var searchInput = document.getElementById('search-input');
            var ageSlider = document.getElementById('age-max');
            var includeDevToggle = document.getElementById('include-dev-toggle');
            var presetSelect = document.getElementById('filter-preset');
            var excludeSharedToggle = document.getElementById('exclude-shared-transitives');
            vscode.setState({
                sortCol: sortCol,
                sortAsc: sortAsc,
                footprintMode: footprintMode,
                activeCardFilter: activeCardFilter,
                chartFilterPackage: chartFilterPackage,
                excludeSharedTransitives: excludeSharedTransitives,
                includeDevDependencies: includeDevToggle ? !!includeDevToggle.checked : includeDevDependencies,
                maxAgeMonths: Number.isFinite(maxAgeMonths) ? maxAgeMonths : null,
                activePreset: presetSelect ? (presetSelect.value || 'none') : activePreset,
                search: searchInput ? (searchInput.value || '') : '',
                excludeSharedToggleChecked: excludeSharedToggle ? !!excludeSharedToggle.checked : excludeSharedTransitives,
                ageSliderValue: ageSlider ? parseInt(ageSlider.value || '240', 10) : 240,
            });
        }

        function matchesPresetFilter(row) {
            if (activePreset === 'none') { return true; }
            var category = row.dataset.category || '';
            var update = row.dataset.update || '';
            var status = row.dataset.status || '';
            var section = row.dataset.section || '';
            var files = parseInt(row.dataset.files || '0', 10);
            var vulns = parseInt(row.dataset.vulns || '0', 10);
            var reexport = row.dataset.reexport === 'yes';
            var ageMonths = parseFloat(row.dataset.ageMonths || '0');
            var hasUpdates = update !== 'up-to-date' && update !== 'unknown';
            if (activePreset === 'modernization') {
                return hasUpdates && ageMonths >= 12;
            }
            if (activePreset === 'risk-hotspots') {
                return vulns > 0
                    || category === 'abandoned'
                    || category === 'end-of-life'
                    || ageMonths >= 36;
            }
            if (activePreset === 'cleanup-candidates') {
                return status === 'unused' || (files === 1 && !reexport);
            }
            if (activePreset === 'direct-only') {
                return section !== 'transitive';
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
                    /* Mirror server-side rule (report-html.ts buildReportSummary):
                       a re-exported package is part of the public API surface,
                       so it doesn't belong in "easy to replace" candidates even
                       if it shows up in only one file. */
                    return row.dataset.files === '1'
                        && row.dataset.reexport !== 'yes';
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
            // KPI filter cards carry role="button"/tabindex in the markup, so
            // keyboard users can focus them; mirror the click on Enter/Space
            // (the native button activation keys) or the cards are mouse-only.
            card.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    filterByCard(card.dataset.filter);
                }
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
            // Validate stale state BEFORE the early-return on missing indicator.
            // restoreUIState() can hand us a chartFilterPackage from a previous
            // session that no longer matches any package in the current table
            // (pubspec changed, package removed, all sizes unknown so the chart
            // section disappeared). Without this, two things break:
            //   1) If the indicator IS present, it renders "Filtered: <stale>"
            //      with an "x Clear" strip pointing at nothing — the bug the
            //      user reported.
            //   2) If the indicator is NOT present (whole chart section
            //      omitted because no segments had size data), applyFilters
            //      still consults chartFilterPackage and hides every row,
            //      producing an empty table with no UI to clear the filter.
            // Anchor on .pkg-row (the table) rather than .bar-row (the chart)
            // so the filter survives a package whose size is unknown but is
            // still present in pubspec. CSS.escape isn't available in older
            // webviews, so we escape double-quotes manually for the selector.
            if (chartFilterPackage) {
                var safeName = String(chartFilterPackage).replace(/"/g, '\\\\"');
                var hasRow = document.querySelector('.pkg-row[data-name="' + safeName + '"]');
                if (!hasRow) { chartFilterPackage = null; }
            }
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

        function getAgeLabelForValue(v) {
            if (v >= 240) { return 'All'; }
            if (v >= 24) { return (Math.round((v / 12) * 10) / 10) + 'y'; }
            return v + 'mo';
        }

        function restoreUIState() {
            var state = vscode.getState();
            if (!state || typeof state !== 'object') { return; }
            isRestoringState = true;
            if (state.sortCol === 'name' || state.sortCol === 'score' || state.sortCol === 'version'
                || state.sortCol === 'update' || state.sortCol === 'published' || state.sortCol === 'size'
                || state.sortCol === 'deps' || state.sortCol === 'transitives' || state.sortCol === 'files'
                || state.sortCol === 'status' || state.sortCol === 'vulns') {
                sortCol = state.sortCol;
            }
            if (typeof state.sortAsc === 'boolean') {
                sortAsc = state.sortAsc;
            }
            if (state.footprintMode === 'own' || state.footprintMode === 'unique' || state.footprintMode === 'total') {
                footprintMode = state.footprintMode;
            }
            if (typeof state.activeCardFilter === 'string' || state.activeCardFilter === null) {
                activeCardFilter = state.activeCardFilter;
            }
            if (typeof state.chartFilterPackage === 'string' || state.chartFilterPackage === null) {
                chartFilterPackage = state.chartFilterPackage;
            }
            excludeSharedTransitives = state.excludeSharedTransitives === true;
            includeDevDependencies = state.includeDevDependencies !== false;
            if (typeof state.maxAgeMonths === 'number') {
                maxAgeMonths = state.maxAgeMonths;
            } else {
                maxAgeMonths = Number.POSITIVE_INFINITY;
            }
            if (typeof state.activePreset === 'string' && state.activePreset) {
                activePreset = state.activePreset;
            }
            var searchInput = document.getElementById('search-input');
            if (searchInput && typeof state.search === 'string') {
                searchInput.value = state.search;
            }
            var includeDevToggle = document.getElementById('include-dev-toggle');
            if (includeDevToggle) {
                includeDevToggle.checked = includeDevDependencies;
            }
            var ageSlider = document.getElementById('age-max');
            var ageLabel = document.getElementById('age-max-label');
            if (ageSlider) {
                var ageValue = 240;
                if (typeof state.ageSliderValue === 'number' && state.ageSliderValue >= 0) {
                    ageValue = Math.max(0, Math.min(240, Math.round(state.ageSliderValue)));
                    ageSlider.value = String(ageValue);
                } else if (Number.isFinite(maxAgeMonths)) {
                    ageValue = Math.max(0, Math.min(240, Math.round(maxAgeMonths)));
                    ageSlider.value = String(ageValue);
                }
                if (ageLabel) { ageLabel.textContent = getAgeLabelForValue(ageValue); }
            }
            var presetSelect = document.getElementById('filter-preset');
            if (presetSelect) {
                var opt = Array.from(presetSelect.options).some(function(o) { return o.value === activePreset; });
                presetSelect.value = opt ? activePreset : 'none';
                activePreset = presetSelect.value || 'none';
            }
            var excludeSharedToggle = document.getElementById('exclude-shared-transitives');
            if (excludeSharedToggle) {
                excludeSharedToggle.checked = state.excludeSharedToggleChecked === true;
                excludeSharedTransitives = excludeSharedToggle.checked;
            }
            updateCardStyles();
            updateChartFilterIndicator();
            updateSearchClearVisibility();
            setFootprintMode(footprintMode);
            sortTable(sortCol, true);
            applyFilters();
            isRestoringState = false;
            saveUIState();
        }

        function clearCardFilter() {
            activeCardFilter = null;
            updateCardStyles();
            applyFilters();
        }

        function clearChartFilter() {
            chartFilterPackage = null;
            updateChartFilterIndicator();
            applyFilters();
        }

        function updateActiveFiltersUI(searchVal) {
            var host = document.getElementById('active-filters');
            if (!host) { return; }
            var list = host.querySelector('.active-filters-list');
            if (!list) { return; }
            var chips = [];
            if (searchVal) {
                chips.push({ key: 'search', label: 'Search: ' + searchVal });
            }
            if (!includeDevDependencies) {
                chips.push({ key: 'dev', label: 'Dev: excluded' });
            }
            if (Number.isFinite(maxAgeMonths)) {
                chips.push({ key: 'age', label: 'Age <= ' + getAgeLabelForValue(maxAgeMonths) });
            }
            if (activePreset !== 'none') {
                chips.push({ key: 'preset', label: 'Preset: ' + activePreset.replace('-', ' ') });
            }
            if (activeCardFilter) {
                chips.push({ key: 'card', label: 'Card: ' + activeCardFilter });
            }
            if (chartFilterPackage) {
                chips.push({ key: 'chart', label: 'Chart: ' + chartFilterPackage });
            }
            if (excludeSharedTransitives) {
                chips.push({ key: 'shared', label: 'Shared transitives: excluded' });
            }
            if (chips.length === 0) {
                /* HTML5 hidden attribute paired with .active-filters[hidden]{display:none!important}
                 * in report-styles. The prior inline style.display='none' could be defeated by any
                 * later style write that cleared inline styles, leaving an empty
                 * "Active filters: ... Clear all" strip showing with no chips. */
                host.hidden = true;
                host.style.display = '';
                list.innerHTML = '';
                return;
            }
            host.hidden = false;
            host.style.display = '';
            list.innerHTML = chips.map(function(chip) {
                return '<button type="button" class="active-filter-chip" data-filter-key="' + chip.key
                    + '" title="Clear this filter">' + chip.label + ' <span aria-hidden="true">&times;</span></button>';
            }).join('');
            list.querySelectorAll('.active-filter-chip').forEach(function(chipEl) {
                chipEl.addEventListener('click', function() {
                    clearFilterByKey(chipEl.dataset.filterKey || '');
                });
            });
        }

        function clearFilterByKey(key) {
            if (key === 'search') {
                var searchInputEl = document.getElementById('search-input');
                if (searchInputEl) { searchInputEl.value = ''; }
                updateSearchClearVisibility();
            } else if (key === 'dev') {
                includeDevDependencies = true;
                var devToggle = document.getElementById('include-dev-toggle');
                if (devToggle) { devToggle.checked = true; }
            } else if (key === 'age') {
                maxAgeMonths = Number.POSITIVE_INFINITY;
                var ageMax = document.getElementById('age-max');
                var ageLabel = document.getElementById('age-max-label');
                if (ageMax) { ageMax.value = '240'; }
                if (ageLabel) { ageLabel.textContent = 'All'; }
            } else if (key === 'preset') {
                activePreset = 'none';
                var presetSelect = document.getElementById('filter-preset');
                if (presetSelect) { presetSelect.value = 'none'; }
            } else if (key === 'card') {
                activeCardFilter = null;
                updateCardStyles();
            } else if (key === 'chart') {
                clearChartFilter();
                return;
            } else if (key === 'shared') {
                excludeSharedTransitives = false;
                var exclToggle = document.getElementById('exclude-shared-transitives');
                if (exclToggle) { exclToggle.checked = false; }
            }
            applyFilters();
        }

        function clearAllFilters() {
            var searchInputEl = document.getElementById('search-input');
            if (searchInputEl) { searchInputEl.value = ''; }
            updateSearchClearVisibility();
            includeDevDependencies = true;
            var devToggle = document.getElementById('include-dev-toggle');
            if (devToggle) { devToggle.checked = true; }
            maxAgeMonths = Number.POSITIVE_INFINITY;
            var ageMaxEl = document.getElementById('age-max');
            var ageLabelEl = document.getElementById('age-max-label');
            if (ageMaxEl) { ageMaxEl.value = '240'; }
            if (ageLabelEl) { ageLabelEl.textContent = 'All'; }
            activePreset = 'none';
            var presetEl = document.getElementById('filter-preset');
            if (presetEl) { presetEl.value = 'none'; }
            activeCardFilter = null;
            updateCardStyles();
            chartFilterPackage = null;
            updateChartFilterIndicator();
            excludeSharedTransitives = false;
            var exclToggle = document.getElementById('exclude-shared-transitives');
            if (exclToggle) { exclToggle.checked = false; }
            applyFilters();
        }

        function resetViewState() {
            isRestoringState = true;
            sortCol = 'score';
            sortAsc = true;
            footprintMode = 'own';
            activeCardFilter = null;
            chartFilterPackage = null;
            excludeSharedTransitives = false;
            includeDevDependencies = true;
            maxAgeMonths = Number.POSITIVE_INFINITY;
            activePreset = 'none';
            packageNavHistory = [];

            var searchInputEl = document.getElementById('search-input');
            if (searchInputEl) { searchInputEl.value = ''; }
            updateSearchClearVisibility();

            var devToggle = document.getElementById('include-dev-toggle');
            if (devToggle) { devToggle.checked = true; }
            var ageMaxEl = document.getElementById('age-max');
            var ageLabelEl = document.getElementById('age-max-label');
            if (ageMaxEl) { ageMaxEl.value = '240'; }
            if (ageLabelEl) { ageLabelEl.textContent = 'All'; }
            var presetEl = document.getElementById('filter-preset');
            if (presetEl) { presetEl.value = 'none'; }
            var exclToggle = document.getElementById('exclude-shared-transitives');
            if (exclToggle) { exclToggle.checked = false; }

            updateCardStyles();
            updateChartFilterIndicator();
            updateBackButtonState();
            setFootprintMode('own');
            sortTable('score', true);
            applyFilters();
            isRestoringState = false;
            vscode.setState({});
            saveUIState();
        }

        var clearChartBtn = document.getElementById('clear-chart-filter');
        if (clearChartBtn) {
            clearChartBtn.addEventListener('click', function() {
                clearChartFilter();
            });
        }
        var clearAllFiltersBtn = document.getElementById('clear-all-filters');
        if (clearAllFiltersBtn) {
            clearAllFiltersBtn.addEventListener('click', function() {
                clearAllFilters();
            });
        }
        var resetViewBtn = document.getElementById('reset-view');
        if (resetViewBtn) {
            resetViewBtn.addEventListener('click', function() {
                resetViewState();
            });
        }

        /* ---- Exclude shared transitives (called from chart-script.ts) ---- */

        function setExcludeShared(exclude) {
            excludeSharedTransitives = exclude;
            applyFilters();
        }

        /* ---- Footprint mode toggle (Size column) ---- */
        /* Three buttons in the toolbar control which precomputed value the
           Size cell displays. The cell renders all three spans and CSS hides
           the inactive ones based on a class on the table. */
        function setFootprintMode(mode) {
            if (mode !== 'own' && mode !== 'unique' && mode !== 'total') { return; }
            footprintMode = mode;
            var table = document.querySelector('table');
            if (table) {
                table.classList.remove('fp-own', 'fp-unique', 'fp-total');
                table.classList.add('fp-' + mode);
            }
            updateTotalSizeSummary(mode);
            document.querySelectorAll('.footprint-btn').forEach(function(btn) {
                btn.classList.toggle('active', btn.dataset.footprint === mode);
            });
            /* If the user is currently sorted by size, re-sort to reflect the
               new mode without flipping direction. */
            if (sortCol === 'size') {
                sortAsc = !sortAsc; /* sortTable flips it back */
                sortTable('size');
            }
            // Footprint changes don't go through applyFilters or sortTable
            // (except for the size-sort path above), so trigger the dirty-view
            // check directly. Safe to call twice when sortTable also ran.
            updateResetViewVisibility();
        }
        document.querySelectorAll('.footprint-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                setFootprintMode(btn.dataset.footprint);
            });
        });
        /* Default: own — set the class so CSS reveals the right span. */
        var initialTable = document.querySelector('table');
        if (initialTable) { initialTable.classList.add('fp-own'); }
        updateTotalSizeSummary('own');
        restoreUIState();
        // restoreUIState() short-circuits when vscode.getState() returns null
        // (first-ever open of the panel), so it never reaches applyFilters
        // and the Reset/Back/Clear visibility never gets the JS update.
        // Force all three updates here so a pristine view starts with every
        // dead-action button hidden, regardless of whether the markup's
        // inline style="display:none" on the chart-filter-indicator survived
        // (a user-reported bug showed the "x Clear" strip visible on first
        // open — the inline style alone was not enough). Setting display via
        // JS overrides any CSS specificity surprise that might have left it
        // visible.
        updateResetViewVisibility();
        updateBackButtonState();
        updateChartFilterIndicator();

        function formatBytesAsMB(bytes) {
            if (!Number.isFinite(bytes) || bytes <= 0) { return '\\u2014'; }
            return (bytes / (1024 * 1024)).toFixed(1).replace(/\\.0$/, '') + ' MB';
        }

        function updateTotalSizeSummary(mode) {
            var card = document.querySelector('.summary-card.total-size');
            if (!card) { return; }
            var countEl = card.querySelector('.count');
            var labelEl = card.querySelector('.label');
            if (!countEl) { return; }
            var attr = 'totalSizeOwn';
            if (mode === 'unique') { attr = 'totalSizeUnique'; }
            else if (mode === 'total') { attr = 'totalSizeTotal'; }
            var raw = parseFloat(card.dataset[attr] || '0');
            countEl.textContent = formatBytesAsMB(raw);
            if (labelEl) {
                if (mode === 'own') { labelEl.textContent = 'Total Size*'; }
                else if (mode === 'unique') { labelEl.textContent = 'Total Size* (+unique)'; }
                else { labelEl.textContent = 'Total Size* (+all)'; }
            }
        }

        /* ---- Search box ---- */

        var searchInput = document.getElementById('search-input');
        var searchClear = document.getElementById('search-clear');
        /* Toggle the inline clear (X) button's visibility based on whether
           the trimmed input has any content. Called on every keystroke and
           after the button clears the field. */
        function updateSearchClearVisibility() {
            if (!searchClear || !searchInput) { return; }
            var hasText = searchInput.value.trim().length > 0;
            searchClear.hidden = !hasText;
        }
        if (searchInput) {
            searchInput.addEventListener('keyup', function() {
                applyFilters();
                updateSearchClearVisibility();
            });
            /* 'input' catches paste/cut/IME commits that 'keyup' misses —
               without it, pasting text wouldn't reveal the clear button
               until the user pressed another key. */
            searchInput.addEventListener('input', updateSearchClearVisibility);
        }
        if (searchClear && searchInput) {
            searchClear.addEventListener('click', function() {
                searchInput.value = '';
                applyFilters();
                updateSearchClearVisibility();
                searchInput.focus();
            });
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

        /* ---- Copy entire table as JSON ---- */
        /* Copies an array of every package's full JSON record (same shape
           as the per-row copy, so all expander content is included). */

        var copyAllBtn = document.getElementById('copy-all');
        if (copyAllBtn) {
            var copyAllLabel = copyAllBtn.innerHTML;
            copyAllBtn.addEventListener('click', function() {
                if (copyAllBtn.classList.contains('copied')) { return; }
                var all = Object.keys(packageData).map(function(k) {
                    return packageData[k];
                });
                var json = JSON.stringify(all, null, 2);
                navigator.clipboard.writeText(json).then(function() {
                    copyAllBtn.innerHTML = '\\u2713 Copied ' + all.length;
                    copyAllBtn.classList.add('copied');
                    setTimeout(function() {
                        copyAllBtn.innerHTML = copyAllLabel;
                        copyAllBtn.classList.remove('copied');
                    }, 1500);
                });
            });
        }

        var saveAllBtn = document.getElementById('save-all');
        if (saveAllBtn) {
            var saveLabel = saveAllBtn.innerHTML;
            saveAllBtn.addEventListener('click', function() {
                if (saveAllBtn.disabled) { return; }
                saveAllBtn.disabled = true;
                var all = Object.keys(packageData).map(function(k) { return packageData[k]; });
                vscode.postMessage({ type: 'saveReportJson', data: all });
                saveAllBtn.innerHTML = '\\u23F3 Saving...';
                setTimeout(function() {
                    saveAllBtn.disabled = false;
                    saveAllBtn.innerHTML = saveLabel;
                }, 2000);
            });
        }

        /* ---- Save upgrade-only report ---- */
        /* Same per-package JSON as "Save", filtered to packages with an
           available update. The outdated test mirrors the modernization
           filter (hasUpdates above): a record counts as outdated when its
           update.status is present and neither 'up-to-date' nor 'unknown'. */
        var saveUpgradeBtn = document.getElementById('save-upgrade');
        if (saveUpgradeBtn) {
            var saveUpgradeLabel = saveUpgradeBtn.innerHTML;
            saveUpgradeBtn.addEventListener('click', function() {
                if (saveUpgradeBtn.disabled) { return; }
                saveUpgradeBtn.disabled = true;
                var outdated = Object.keys(packageData).map(function(k) {
                    return packageData[k];
                }).filter(function(d) {
                    var status = d && d.update && d.update.status;
                    return !!status && status !== 'up-to-date' && status !== 'unknown';
                });
                vscode.postMessage({ type: 'saveUpgradeReportJson', data: outdated });
                saveUpgradeBtn.innerHTML = '\\u23F3 Saving...';
                setTimeout(function() {
                    saveUpgradeBtn.disabled = false;
                    saveUpgradeBtn.innerHTML = saveUpgradeLabel;
                }, 2000);
            });
        }

        var ageMax = document.getElementById('age-max');
        var ageLabel = document.getElementById('age-max-label');
        if (ageMax) {
            ageMax.addEventListener('input', function() {
                var v = parseInt(ageMax.value || '240', 10);
                maxAgeMonths = v >= 240 ? Number.POSITIVE_INFINITY : v;
                if (ageLabel) {
                    ageLabel.textContent = getAgeLabelForValue(v);
                }
                applyFilters();
            });
        }

        var includeDevToggle = document.getElementById('include-dev-toggle');
        if (includeDevToggle) {
            includeDevToggle.addEventListener('change', function() {
                includeDevDependencies = !!includeDevToggle.checked;
                applyFilters();
            });
        }
        var presetSelect = document.getElementById('filter-preset');
        if (presetSelect) {
            presetSelect.addEventListener('change', function() {
                activePreset = presetSelect.value || 'none';
                applyFilters();
            });
        }

        /* ---- Open pubspec.yaml ---- */

        var pubspecBtn = document.getElementById('open-pubspec');
        if (pubspecBtn) {
            pubspecBtn.addEventListener('click', function() {
                vscode.postMessage({ type: 'openPubspec' });
            });
        }

        /* ---- Open Another Project ---- */
        /* File picker in the extension host; opens the selected
           pubspec.yaml's folder in a new VS Code window. */
        var openOtherBtn = document.getElementById('open-other');
        if (openOtherBtn) {
            openOtherBtn.addEventListener('click', function() {
                vscode.postMessage({ type: 'openOtherProject' });
            });
        }

        /* ---- Rescan ---- */
        /* Sends a message to the extension host which runs the
           saropaLints.packageVibrancy.rescan command (clears the per-package
           pub.dev cache first so the report reflects current pub.dev state).
           Button is disabled while the request is in flight to prevent
           duplicate scans. */
        var rescanBtn = document.getElementById('rescan');
        if (rescanBtn) {
            var rescanOriginal = rescanBtn.innerHTML;
            rescanBtn.addEventListener('click', function() {
                if (rescanBtn.disabled) { return; }
                rescanBtn.disabled = true;
                rescanBtn.innerHTML = '\\u29D6 Scanning\\u2026';
                vscode.postMessage({ type: 'rescan' });
                /* Host will rebuild the webview HTML on completion, which
                   replaces this handler. The timeout is a fallback in case
                   the scan fails or is cancelled before HTML rebuild. */
                setTimeout(function() {
                    if (rescanBtn && rescanBtn.disabled) {
                        rescanBtn.disabled = false;
                        rescanBtn.innerHTML = rescanOriginal;
                    }
                }, 60000);
            });
        }

        /* ---- "Scanned X ago" pill -> rescan + re-check for package updates ---- */
        /* Same fresh rescan as the toolbar button, plus it re-runs the pub.dev
           upgrade check so the "Update available" notification re-surfaces (the
           passive background check is throttled and won't re-prompt on its own).
           The host rebuilds the webview HTML on completion, replacing this
           handler, so no manual re-enable is needed on the happy path. */
        var lastScanBtn = document.getElementById('lastScanRescan');
        if (lastScanBtn) {
            lastScanBtn.addEventListener('click', function() {
                if (lastScanBtn.getAttribute('aria-disabled') === 'true') { return; }
                lastScanBtn.setAttribute('aria-disabled', 'true');
                vscode.postMessage({ type: 'rescanAndCheckUpdates' });
            });
        }

        /* ---- Package name click -> open pubspec.yaml at entry ---- */

        document.querySelectorAll('.pkg-name-link').forEach(function(el) {
            el.addEventListener('click', function() {
                vscode.postMessage({ type: 'openPubspecEntry', package: el.dataset.pkg });
            });
        });

        /* ---- References click -> file-reference popover (fallback: search) ---- */

        document.querySelectorAll('.ref-link').forEach(function(el) {
            el.addEventListener('click', function(e) {
                e.stopPropagation();
                var refsData = el.dataset.refs || '';
                if (refsData) {
                    showRefsPopover(el, refsData);
                } else {
                    vscode.postMessage({ type: 'searchImport', package: el.dataset.pkg });
                }
            });
        });

        /* ---- Open local package folder from Size cell ---- */
        document.querySelectorAll('.size-link').forEach(function(el) {
            el.addEventListener('click', function(e) {
                e.stopPropagation();
                if (!el.dataset.pkg) { return; }
                vscode.postMessage({ type: 'openSourceFolder', package: el.dataset.pkg });
            });
        });

        /* ---- Open file reference from detail section ---- */
        document.querySelectorAll('.file-link').forEach(function(el) {
            el.addEventListener('click', function(e) {
                e.stopPropagation();
                var path = el.dataset.path;
                var line = parseInt(el.dataset.line || '1', 10);
                if (!path) { return; }
                vscode.postMessage({ type: 'openFileRef', path: path, line: line });
            });
        });

        /* ---- Dependency navigation popover + row jump history ---- */
        var navPopover = document.createElement('div');
        navPopover.className = 'dep-popover';
        navPopover.style.display = 'none';
        document.body.appendChild(navPopover);

        function hideNavPopover() {
            navPopover.style.display = 'none';
            navPopover.innerHTML = '';
        }

        function positionPopover(anchorEl) {
            var rect = anchorEl.getBoundingClientRect();
            var top = rect.bottom + 6;
            var left = Math.max(8, rect.left);
            navPopover.style.left = left + 'px';
            navPopover.style.top = top + 'px';
            navPopover.style.maxWidth = Math.max(220, window.innerWidth - left - 12) + 'px';
            var popRect = navPopover.getBoundingClientRect();
            if (popRect.right > window.innerWidth - 8) {
                navPopover.style.left = Math.max(8, window.innerWidth - popRect.width - 8) + 'px';
            }
            if (popRect.bottom > window.innerHeight - 8) {
                navPopover.style.top = Math.max(8, rect.top - popRect.height - 6) + 'px';
            }
        }

        function showDepPopover(anchorEl, ownerPkg, depListRaw) {
            var deps = (depListRaw || '').split(',').map(function(d) {
                return d.trim();
            }).filter(Boolean);
            if (deps.length === 0) { return; }
            var links = deps.map(function(dep) {
                return '<a href="#" class="dep-nav-link" data-owner="' + ownerPkg + '" data-target="' + dep + '">' + dep + '</a>';
            }).join('');
            navPopover.innerHTML = '<div class="dep-popover-title">Dependencies</div>' + links;
            navPopover.style.display = 'block';
            positionPopover(anchorEl);
            navPopover.querySelectorAll('.dep-nav-link').forEach(function(linkEl) {
                linkEl.addEventListener('click', function(e) {
                    e.preventDefault();
                    var target = linkEl.dataset.target;
                    var owner = linkEl.dataset.owner;
                    if (!target) { return; }
                    navigateToPackageRow(target, owner || null);
                    hideNavPopover();
                });
            });
        }

        function showRefsPopover(anchorEl, refsDataRaw) {
            var refs = [];
            try {
                refs = JSON.parse(decodeURIComponent(refsDataRaw || '[]'));
            } catch (_err) {
                refs = [];
            }
            if (!Array.isArray(refs) || refs.length === 0) { return; }
            var links = refs.map(function(ref) {
                if (!ref || !ref.path) { return ''; }
                var line = parseInt(ref.line || '1', 10);
                var label = ref.label || (ref.path + ':' + line);
                return '<a href="#" class="ref-nav-link" data-path="' + ref.path + '" data-line="' + line + '">' + label + '</a>';
            }).join('');
            navPopover.innerHTML = '<div class="dep-popover-title">File references</div>' + links;
            navPopover.style.display = 'block';
            positionPopover(anchorEl);
            navPopover.querySelectorAll('.ref-nav-link').forEach(function(linkEl) {
                linkEl.addEventListener('click', function(e) {
                    e.preventDefault();
                    var path = linkEl.dataset.path;
                    var line = parseInt(linkEl.dataset.line || '1', 10);
                    if (!path) { return; }
                    vscode.postMessage({ type: 'openFileRef', path: path, line: line });
                    hideNavPopover();
                });
            });
        }

        document.querySelectorAll('.dep-list-link').forEach(function(el) {
            el.addEventListener('click', function(e) {
                e.stopPropagation();
                var owner = el.dataset.pkg || '';
                showDepPopover(el, owner, el.dataset.deps || '');
            });
        });

        document.addEventListener('click', function(e) {
            if (navPopover.style.display !== 'none' && !navPopover.contains(e.target)) {
                hideNavPopover();
            }
        });

        function ensureBackButton() {
            if (document.getElementById('pkg-nav-back')) { return; }
            var toolbar = document.querySelector('.table-toolbar');
            if (!toolbar) { return; }
            var btn = document.createElement('button');
            btn.id = 'pkg-nav-back';
            btn.className = 'toolbar-btn';
            btn.textContent = '\u2190 Back';
            btn.title = 'Back to previous package';
            // Start hidden: a "Back" button with no history is dead UI. The
            // disabled flag is kept alongside hidden as a belt-and-suspenders
            // guard in case a future style rule overrides [hidden].
            btn.hidden = true;
            btn.disabled = true;
            btn.addEventListener('click', function() {
                goBackPackageNav();
            });
            toolbar.insertBefore(btn, toolbar.firstChild);
        }

        // True when any sort/filter/footprint/card/chart/search state differs from
        // the defaults that resetViewState() restores. Drives the visibility of
        // the "Reset view" toolbar button — there's no point offering "reset"
        // when nothing has been changed. The constants here must stay in lockstep
        // with the defaults declared at the top of this script and with the
        // values resetViewState() writes back; if you add a new piece of view
        // state, add it here too or "Reset view" will hide when it shouldn't.
        function isViewDirty() {
            var searchInputEl = document.getElementById('search-input');
            var hasSearch = !!(searchInputEl && searchInputEl.value && searchInputEl.value.trim().length > 0);
            return (
                sortCol !== 'score' ||
                sortAsc !== true ||
                footprintMode !== 'own' ||
                activeCardFilter !== null ||
                chartFilterPackage !== null ||
                excludeSharedTransitives !== false ||
                includeDevDependencies !== true ||
                Number.isFinite(maxAgeMonths) ||
                activePreset !== 'none' ||
                hasSearch
            );
        }

        function updateResetViewVisibility() {
            var btn = document.getElementById('reset-view');
            if (!btn) { return; }
            // Same reasoning as the Back button: a "Reset view" button shown
            // against a pristine view is misleading. Pair hidden + disabled so
            // accidental clicks via keyboard shortcuts or screen readers are
            // also a no-op rather than triggering a redundant rerender.
            var dirty = isViewDirty();
            btn.hidden = !dirty;
            btn.disabled = !dirty;
        }

        function updateBackButtonState() {
            var btn = document.getElementById('pkg-nav-back');
            if (!btn) { return; }
            // Hide entirely when there's nothing to go back to \u2014 a visible-but-disabled
            // button suggests an action is available when it isn't. Keep .disabled in
            // sync so screen readers and any [hidden]-bypassing style still get the
            // correct semantics.
            var hasHistory = packageNavHistory.length > 0;
            btn.hidden = !hasHistory;
            btn.disabled = !hasHistory;
            btn.title = hasHistory
                ? 'Back to previous package'
                : 'No previous package';
        }

        function highlightPackageRow(row) {
            document.querySelectorAll('.pkg-row.pkg-nav-focus').forEach(function(r) {
                r.classList.remove('pkg-nav-focus');
            });
            row.classList.add('pkg-nav-focus');
            row.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }

        function navigateToPackageRow(targetPkg, fromPkg) {
            var targetRow = document.querySelector('.pkg-row[data-name="' + targetPkg + '"]');
            if (!targetRow) { return; }
            if (fromPkg) {
                var fromRow = document.querySelector('.pkg-row[data-name="' + fromPkg + '"]');
                if (fromRow) {
                    packageNavHistory.push({ name: fromPkg, scrollY: window.scrollY });
                }
            }
            highlightPackageRow(targetRow);
            updateBackButtonState();
        }

        function goBackPackageNav() {
            var prev = packageNavHistory.pop();
            if (!prev) {
                updateBackButtonState();
                return;
            }
            var prevRow = document.querySelector('.pkg-row[data-name="' + prev.name + '"]');
            if (prevRow) {
                highlightPackageRow(prevRow);
                if (typeof prev.scrollY === 'number') {
                    window.scrollTo({ top: prev.scrollY, behavior: 'smooth' });
                }
            }
            updateBackButtonState();
        }

        ensureBackButton();
        updateBackButtonState();

        /* ---- Radial gauge: honor prefers-reduced-motion ----
           The fill animation is a SMIL <animate> inside .gauge-fill (see
           buildRadialGauge in report-html.ts). SMIL ignores CSS animation
           properties, so a CSS @media (prefers-reduced-motion) rule can't
           disable it — remove the element here instead. The circle's static
           stroke-dasharray attribute still paints the final fill. */
        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            var smil = document.querySelector('.gauge-fill > animate');
            if (smil && smil.parentNode) {
                smil.parentNode.removeChild(smil);
            }
        }

        /* ---- "Why this grade?" breakdown panel ----
           The gauge and the Project Grade summary card both carry
           data-breakdown-trigger and aria-controls="grade-breakdown". Clicking
           either toggles the <details id="grade-breakdown"> open and scrolls
           it into view. Inside the panel, distribution rows / signal buttons
           filter the table via the existing filterByCard pipeline, and the
           lowest-scoring package buttons jump to the corresponding row using
           the same navigation helper the dependency network uses. */
        function openGradeBreakdown() {
            var panel = document.getElementById('grade-breakdown');
            if (!panel) { return; }
            panel.open = true;
            panel.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
        document.querySelectorAll('[data-breakdown-trigger]').forEach(function(el) {
            el.addEventListener('click', function(e) {
                /* The summary card already has a click handler from the
                   filter-by-card loop above. Suppress that path so opening the
                   breakdown doesn't also toggle a category filter; the user
                   wants to read the explanation, not filter the table. */
                if (el.getAttribute('data-filter')) { e.stopPropagation(); }
                openGradeBreakdown();
            });
            el.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    openGradeBreakdown();
                }
            });
        });
        document.querySelectorAll('.grade-breakdown .breakdown-filter-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var filter = btn.getAttribute('data-filter');
                if (filter) { filterByCard(filter); }
            });
        });
        document.querySelectorAll('.grade-breakdown .breakdown-jump-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                var pkg = btn.getAttribute('data-pkg');
                if (!pkg) { return; }
                /* navigateToPackageRow scrolls AND highlights — single-arg
                   form skips the "from" row that the dependency-network
                   linkage uses for back-navigation. */
                navigateToPackageRow(pkg, null);
            });
        });

        /* ---- Lightweight dependency network diagram ----
         *
         * Layout: two columns. Left column lists each direct dependency
         * once. Right column lists each UNIQUE transitive once. Edges
         * fan from a direct to the shared transitive row it depends on.
         *
         * Why this is not the per-row-bundle layout the panel used to
         * have: that version placed each direct's 6 transitive labels in
         * a 70px vertical band (y2 = y + (j - 2) * 14) while spacing
         * direct rows only 28px apart, so adjacent rows' transitive
         * bands overlapped by ~42px. On top of that, many directs share
         * common transitives (characters, collection, meta, ...), so the
         * same label was rendered multiple times at near-identical Y —
         * which is what produced the garbled "chetracters" stacks. The
         * unique-transitive layout below renders each label exactly once
         * at a stable Y, so labels can never collide regardless of how
         * many directs reference them. */
        /* Build the network toolbar markup (zoom, reset, depth toggle). Pure
         * string builder — no DOM/closure deps — so it stays out of the big
         * render function. The toggle label names the hidden depth-2 count so
         * the user knows expanding has something to show. Strings are hardcoded
         * to match this client script's existing convention (it has no l10n
         * runtime — l10n() executes host-side, not in the webview). */
        function buildNetworkToolbar(expanded, transitiveCount) {
            var toggleLabel = expanded
                ? 'Collapse to direct deps'
                : 'Expand transitives (' + transitiveCount + ')';
            return '<div class="network-toolbar">' +
                '<button type="button" class="network-btn" data-net-act="zoom-out" title="Zoom out" aria-label="Zoom out">−</button>' +
                '<button type="button" class="network-btn" data-net-act="zoom-in" title="Zoom in" aria-label="Zoom in">+</button>' +
                '<button type="button" class="network-btn" data-net-act="reset" title="Reset view" aria-label="Reset view">Reset view</button>' +
                '<button type="button" class="network-btn network-btn-toggle" data-net-act="toggle">' + toggleLabel + '</button>' +
                '</div>';
        }

        /* Compute the SVG layout for the given visible nodes. Returns the inner
         * markup, the natural canvas size, and a name->point map used to focus a
         * clicked node. When collapsed (depth 1) only the direct column is drawn
         * — no transitive column, no edges — which is what keeps a large graph
         * readable on first open. */
        function buildNetworkLayout(nodes, transitives, expanded) {
            var rowH = 18, topPad = 24, botPad = 16, leftX = 12, leftColW = 220, rightColW = 220, gap = 120;
            var rightX = leftX + leftColW + gap;
            var posByName = Object.create(null);
            var parts = [];

            var directY = Object.create(null);
            for (var di = 0; di < nodes.length; di++) {
                directY[nodes[di].name] = topPad + di * rowH;
            }

            // Depth-2 column + edges only when expanded.
            if (expanded) {
                var transitiveY = Object.create(null);
                for (var ti = 0; ti < transitives.length; ti++) {
                    transitiveY[transitives[ti]] = topPad + ti * rowH;
                }
                // Edges first so node text renders on top of the line ends.
                for (var ei = 0; ei < nodes.length; ei++) {
                    var y1 = directY[nodes[ei].name];
                    var elinks = Array.isArray(nodes[ei].links) ? nodes[ei].links : [];
                    for (var ej = 0; ej < elinks.length; ej++) {
                        var y2 = transitiveY[elinks[ej]];
                        if (y2 == null) { continue; }
                        parts.push('<line x1="' + (leftX + leftColW) + '" y1="' + (y1 - 4) + '" x2="' + rightX + '" y2="' + (y2 - 4) + '" class="network-edge network-edge-link" data-owner="' + nodes[ei].name + '" data-target="' + elinks[ej] + '" />');
                    }
                }
                for (var tj = 0; tj < transitives.length; tj++) {
                    var ty = transitiveY[transitives[tj]];
                    posByName[transitives[tj]] = { x: rightX, y: ty };
                    parts.push('<text x="' + rightX + '" y="' + ty + '" class="network-node transitive network-node-link" data-target="' + transitives[tj] + '" role="button" tabindex="0">' + transitives[tj] + '</text>');
                }
            }

            for (var ni2 = 0; ni2 < nodes.length; ni2++) {
                var dy = directY[nodes[ni2].name];
                posByName[nodes[ni2].name] = { x: leftX, y: dy };
                parts.push('<text x="' + leftX + '" y="' + dy + '" class="network-node direct network-node-link" data-owner="' + nodes[ni2].name + '" data-target="' + nodes[ni2].name + '" role="button" tabindex="0">' + nodes[ni2].name + '</text>');
            }

            var rowCount = expanded ? Math.max(nodes.length, transitives.length) : nodes.length;
            var width = expanded ? (leftX + leftColW + gap + rightColW + 12) : (leftX + leftColW + 12);
            var height = topPad + rowCount * rowH + botPad;
            return { width: width, height: height, inner: parts.join(''), posByName: posByName };
        }

        /* Re-rendered on every applyFilters() pass (plus once at init) so the
         * graph mirrors the table instead of freezing on the page-load dataset.
         * Hoisted declaration — applyFilters() calls it before this line is
         * reached at init, which is fine because function declarations hoist. */
        function renderNetwork() {
            var host = document.getElementById('dep-network');
            if (!host) { return; }
            var raw = host.dataset.network || '[]';
            var nodes = [];
            try { nodes = JSON.parse(raw); } catch (_err) { nodes = []; }
            if (!Array.isArray(nodes) || nodes.length === 0) {
                host.textContent = 'No dependency relationship data.';
                return;
            }

            /* Mirror the table's current filter state: a package appears in the
             * graph only when its table row is visible, and an edge is drawn
             * only when BOTH endpoints are visible. The table is the source of
             * truth (applyFilters sets row.style.display), so reading that
             * display here is what keeps the graph in sync with the age slider,
             * dev-deps toggle, search, presets, and chart filters. Without this
             * the graph silently showed packages the user had filtered out. */
            var visibleNames = Object.create(null);
            document.querySelectorAll('#pkg-body tr.pkg-row').forEach(function(r) {
                if (r.style.display !== 'none') {
                    visibleNames[r.dataset.name] = true;
                }
            });
            nodes = nodes
                .filter(function(n) { return visibleNames[n.name]; })
                .map(function(n) {
                    var nLinks = Array.isArray(n.links) ? n.links : [];
                    /* Drop edges to filtered-out transitives so the right column
                     * never lists a package the table is currently hiding. */
                    return {
                        name: n.name,
                        links: nLinks.filter(function(d) { return visibleNames[d]; }),
                    };
                });
            if (nodes.length === 0) {
                host.textContent = 'No dependency relationship data for the current filters.';
                return;
            }

            // Unique depth-2 transitives in first-seen order (only drawn when
            // the graph is expanded; still counted here for the toggle label).
            var seen = Object.create(null);
            var transitives = [];
            for (var ni = 0; ni < nodes.length; ni++) {
                var nlinks = Array.isArray(nodes[ni].links) ? nodes[ni].links : [];
                for (var li = 0; li < nlinks.length; li++) {
                    if (!seen[nlinks[li]]) { seen[nlinks[li]] = true; transitives.push(nlinks[li]); }
                }
            }

            // preserveAspectRatio="xMidYMid meet" scales the content uniformly
            // to fit the fixed-height viewport — no axis squash (the failure the
            // old natural-pixel layout was guarding against), because the inner
            // coordinate system is fixed and only the viewBox changes for zoom.
            var layout = buildNetworkLayout(nodes, transitives, networkExpanded);
            host.innerHTML =
                buildNetworkToolbar(networkExpanded, transitives.length) +
                '<svg class="network-svg" role="img" aria-label="Dependency network"' +
                ' preserveAspectRatio="xMidYMid meet" viewBox="0 0 ' + layout.width + ' ' + layout.height + '">' +
                layout.inner +
                '</svg>';

            var svg = host.querySelector('.network-svg');
            if (!svg) { return; }

            // viewBox is the single source of zoom + pan. Reset to fit-all on
            // every (re)render: a filter change alters the node set, so refitting
            // is the predictable behavior; zoom/pan/focus adjust the live view.
            var natW = layout.width, natH = layout.height;
            var vb = { x: 0, y: 0, w: natW, h: natH };
            function applyViewBox() {
                svg.setAttribute('viewBox', vb.x + ' ' + vb.y + ' ' + vb.w + ' ' + vb.h);
            }
            // factor < 1 magnifies (smaller viewBox). Clamp 0.2x–4x of natural
            // so the graph can't be scaled off into empty space and lost.
            function zoomAround(cx, cy, factor) {
                var nw = Math.max(natW * 0.2, Math.min(natW * 4, vb.w * factor));
                var nh = Math.max(natH * 0.2, Math.min(natH * 4, vb.h * factor));
                vb.x = cx - (cx - vb.x) * (nw / vb.w);
                vb.y = cy - (cy - vb.y) * (nh / vb.h);
                vb.w = nw; vb.h = nh;
                applyViewBox();
            }
            function zoomCenter(factor) { zoomAround(vb.x + vb.w / 2, vb.y + vb.h / 2, factor); }
            function resetView() { vb.x = 0; vb.y = 0; vb.w = natW; vb.h = natH; applyViewBox(); }
            function focusOn(pos) {
                if (!pos) { return; }
                vb.x = pos.x - vb.w / 2;
                vb.y = pos.y - vb.h / 2;
                applyViewBox();
            }

            // Toolbar: zoom, reset, and the depth toggle (re-renders flipped).
            host.querySelectorAll('.network-btn').forEach(function(btn) {
                btn.addEventListener('click', function(e) {
                    e.stopPropagation();
                    var act = btn.getAttribute('data-net-act');
                    if (act === 'zoom-in') { zoomCenter(0.8); }
                    else if (act === 'zoom-out') { zoomCenter(1.25); }
                    else if (act === 'reset') { resetView(); }
                    else if (act === 'toggle') { networkExpanded = !networkExpanded; renderNetwork(); }
                });
            });

            // Drag empty canvas to pan; wheel to zoom around the cursor. A
            // pointerdown that lands on a node/edge is left alone so its click
            // still fires (pointer capture would otherwise swallow it).
            var dragging = false, startCX = 0, startCY = 0, startVBX = 0, startVBY = 0;
            svg.addEventListener('pointerdown', function(e) {
                if (e.button !== 0) { return; }
                var t = e.target;
                if (t && t.classList && (t.classList.contains('network-node-link') || t.classList.contains('network-edge-link'))) { return; }
                dragging = true;
                startCX = e.clientX; startCY = e.clientY;
                startVBX = vb.x; startVBY = vb.y;
                svg.classList.add('network-panning');
                try { svg.setPointerCapture(e.pointerId); } catch (_e) {}
            });
            svg.addEventListener('pointermove', function(e) {
                if (!dragging) { return; }
                var rect = svg.getBoundingClientRect();
                if (!rect.width || !rect.height) { return; }
                // Pixel delta -> viewBox units so the grabbed point tracks the
                // cursor at any zoom level.
                vb.x = startVBX - (e.clientX - startCX) * (vb.w / rect.width);
                vb.y = startVBY - (e.clientY - startCY) * (vb.h / rect.height);
                applyViewBox();
            });
            function endPan(e) {
                if (!dragging) { return; }
                dragging = false;
                svg.classList.remove('network-panning');
                try { svg.releasePointerCapture(e.pointerId); } catch (_e) {}
            }
            svg.addEventListener('pointerup', endPan);
            svg.addEventListener('pointercancel', endPan);
            svg.addEventListener('wheel', function(e) {
                e.preventDefault();
                var rect = svg.getBoundingClientRect();
                if (!rect.width || !rect.height) { return; }
                var cx = vb.x + ((e.clientX - rect.left) / rect.width) * vb.w;
                var cy = vb.y + ((e.clientY - rect.top) / rect.height) * vb.h;
                zoomAround(cx, cy, e.deltaY > 0 ? 1.1 : 0.9);
            });

            function clearNetworkSelection() {
                host.querySelectorAll('.network-selected').forEach(function(el) {
                    el.classList.remove('network-selected');
                });
            }

            // Highlight a single direct → transitive edge plus both nodes.
            function highlightEdge(owner, target) {
                clearNetworkSelection();
                host.querySelectorAll('.network-node-link[data-owner="' + owner + '"][data-target="' + owner + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
                host.querySelectorAll('.network-node.transitive[data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
                host.querySelectorAll('.network-edge-link[data-owner="' + owner + '"][data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
            }

            // Clicking a transitive highlights every incoming edge and each
            // direct that pulls it in ("who depends on X?").
            function highlightTransitive(target) {
                clearNetworkSelection();
                host.querySelectorAll('.network-node.transitive[data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
                host.querySelectorAll('.network-edge-link[data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                    var ownerAttr = el.getAttribute('data-owner') || '';
                    if (ownerAttr) {
                        host.querySelectorAll('.network-node.direct[data-owner="' + ownerAttr + '"]').forEach(function(o) {
                            o.classList.add('network-selected');
                        });
                    }
                });
            }

            host.querySelectorAll('.network-node-link').forEach(function(nodeEl) {
                function runNavigation() {
                    var owner = nodeEl.getAttribute('data-owner') || '';
                    var target = nodeEl.getAttribute('data-target') || '';
                    if (!target) { return; }
                    if (owner && owner === target) {
                        clearNetworkSelection();
                        nodeEl.classList.add('network-selected');
                    } else {
                        highlightTransitive(target);
                    }
                    // Focus the clicked node in the graph, then jump to its row.
                    focusOn(layout.posByName[target]);
                    navigateToPackageRow(target, null);
                }
                nodeEl.addEventListener('click', runNavigation);
                nodeEl.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        runNavigation();
                    }
                });
            });
            host.querySelectorAll('.network-edge-link').forEach(function(edgeEl) {
                edgeEl.addEventListener('click', function() {
                    var owner = edgeEl.getAttribute('data-owner') || '';
                    var target = edgeEl.getAttribute('data-target') || '';
                    if (!owner || !target) { return; }
                    highlightEdge(owner, target);
                    focusOn(layout.posByName[target]);
                    navigateToPackageRow(target, owner);
                });
            });
        }

        /* Initial render. restoreUIState() short-circuits (and so never calls
         * applyFilters) on a first-ever open with no saved state, so the graph
         * must be drawn explicitly here too — applyFilters covers every later
         * filter change, this covers the cold start. */
        renderNetwork();

        /* ---- Row expansion (chevron click toggles detail row) ---- */

        var focusedRowIdx = -1;

        document.querySelectorAll('.expand-cell').forEach(function(cell) {
            cell.addEventListener('click', function(e) {
                e.stopPropagation();
                var pkgRow = cell.closest('.pkg-row');
                if (pkgRow) { openDetailPane(pkgRow.dataset.name); }
            });
        });

        /* Click anywhere on the row (except links/buttons) opens the detail pane. */
        document.querySelectorAll('.pkg-row').forEach(function(row) {
            row.addEventListener('click', function(e) {
                var tag = e.target.tagName;
                /* Don't open if the user clicked a link, button, or interactive element. */
                if (tag === 'A' || tag === 'BUTTON' || e.target.classList.contains('copy-btn')
                    || e.target.classList.contains('pkg-name-link')
                    || e.target.classList.contains('ref-link')) { return; }
                openDetailPane(row.dataset.name);
            });
        });

        /* ---- Docked detail pane (master-detail). Selecting a row asks the host
         * to render that package's rich detail body and injects it here, so the
         * dashboard hosts the detail instead of a separate panel tab. ---- */
        var detailPane = document.getElementById('detail-pane');
        var detailPaneBody = document.getElementById('detail-pane-body');
        function openDetailPane(name) {
            if (!name || !detailPane || !detailPaneBody) { return; }
            document.querySelectorAll('.pkg-row.row-selected').forEach(function(r) {
                r.classList.remove('row-selected');
            });
            var sel = (window.CSS && CSS.escape) ? CSS.escape(name) : name;
            var row = document.querySelector('.pkg-row[data-name="' + sel + '"]');
            if (row) { row.classList.add('row-selected'); }
            detailPaneBody.innerHTML = '';
            detailPane.hidden = false;
            vscode.postMessage({ type: 'requestPackageDetail', package: name });
        }
        function closeDetailPane() {
            if (detailPane) { detailPane.hidden = true; }
            document.querySelectorAll('.pkg-row.row-selected').forEach(function(r) {
                r.classList.remove('row-selected');
            });
        }
        var detailPaneCloseBtn = document.getElementById('detailPaneClose');
        if (detailPaneCloseBtn) { detailPaneCloseBtn.addEventListener('click', closeDetailPane); }
        /* Delegated handlers for the injected detail body. Delegation on the
         * pane (not its children) survives every re-injection the host pushes
         * as lazy fetches land. Mirrors the standalone panel's client script. */
        function paneCapitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
        function paneApplyGapFilters(section) {
            if (!section) { return; }
            var toolbar = section.querySelector('.gap-toolbar');
            var search = toolbar ? toolbar.querySelector('.gap-search') : null;
            var searchText = ((search && search.value) || '').toLowerCase();
            var activeBtn = toolbar ? toolbar.querySelector('.filter-btn.active') : null;
            var activeFilter = (activeBtn && activeBtn.dataset.filter) || 'all';
            section.querySelectorAll('.gap-table tbody tr').forEach(function(row) {
                var text = row.dataset.searchtext || '';
                var type = row.dataset.type || '';
                var rev = row.dataset.review || 'unreviewed';
                var visible = text.indexOf(searchText) !== -1;
                if (visible && activeFilter === 'prs') { visible = type === 'pr'; }
                if (visible && activeFilter === 'issues') { visible = type === 'issue'; }
                if (visible && activeFilter === 'unreviewed') { visible = rev === 'unreviewed'; }
                row.style.display = visible ? '' : 'none';
            });
        }
        function paneUpdateReviewSummary(section) {
            if (!section) { return; }
            var rows = section.querySelectorAll('.gap-table tbody tr');
            var total = rows.length, triaged = 0, applicable = 0, notApplicable = 0;
            rows.forEach(function(row) {
                var s = row.dataset.review || 'unreviewed';
                if (s !== 'unreviewed') { triaged++; }
                if (s === 'applicable') { applicable++; }
                if (s === 'not-applicable') { notApplicable++; }
            });
            var sm = section.querySelector('.review-summary');
            if (sm) {
                sm.textContent = triaged + ' of ' + total + ' triaged | ' + applicable
                    + ' applicable | ' + notApplicable + ' N/A | ' + (total - triaged) + ' remaining';
            }
        }
        function paneSortGapTable(th) {
            var col = th.dataset.col;
            var table = th.closest('table');
            var tbody = table.querySelector('tbody');
            var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
            var asc = th.dataset.sort !== 'asc';
            th.dataset.sort = asc ? 'asc' : 'desc';
            rows.sort(function(a, b) {
                var ael = a.querySelector('[data-sort-' + col + ']');
                var bel = b.querySelector('[data-sort-' + col + ']');
                var av = ael ? (ael.dataset['sort' + paneCapitalize(col)] || '') : '';
                var bv = bel ? (bel.dataset['sort' + paneCapitalize(col)] || '') : '';
                var c = av.localeCompare(bv, undefined, { numeric: true });
                return asc ? c : -c;
            });
            rows.forEach(function(row) { tbody.appendChild(row); });
            table.querySelectorAll('th .sort-arrow').forEach(function(s) { s.textContent = ''; });
            var arrow = th.querySelector('.sort-arrow');
            if (arrow) { arrow.textContent = asc ? ' ▲' : ' ▼'; }
        }
        if (detailPane) {
            detailPane.addEventListener('click', function(e) {
                var hdr = e.target.closest('.section-header');
                if (hdr && hdr.parentElement) { hdr.parentElement.classList.toggle('collapsed'); return; }
                var fbtn = e.target.closest('.filter-btn');
                if (fbtn) {
                    var tb = fbtn.closest('.gap-toolbar');
                    if (tb) {
                        tb.querySelectorAll('.filter-btn').forEach(function(b) {
                            b.classList.remove('active'); b.setAttribute('aria-checked', 'false');
                        });
                        fbtn.classList.add('active'); fbtn.setAttribute('aria-checked', 'true');
                        paneApplyGapFilters(fbtn.closest('.section'));
                    }
                    return;
                }
                var sortTh = e.target.closest('.gap-table th[data-col]');
                if (sortTh) { paneSortGapTable(sortTh); return; }
                var retryBtn = e.target.closest('#retry-fetches');
                if (retryBtn) {
                    setPaneBtnBusy(retryBtn);
                    vscode.postMessage({ type: 'retryFetches' });
                    return;
                }
                var el = e.target.closest('[data-action]');
                if (!el) { return; }
                var action = el.dataset.action;
                if (action === 'openUrl' && el.dataset.url) {
                    e.preventDefault(); vscode.postMessage({ type: 'openUrl', url: el.dataset.url });
                } else if (action === 'openFile' && el.dataset.path) {
                    e.preventDefault();
                    vscode.postMessage({ type: 'openFile', path: el.dataset.path, line: parseInt(el.dataset.line || '1', 10) });
                } else if (action === 'upgrade') {
                    e.preventDefault();
                    setPaneBtnBusy(el);
                    vscode.postMessage({ type: 'upgrade', name: el.dataset.name, version: el.dataset.version });
                } else if (action === 'changelog') {
                    e.preventDefault();
                    vscode.postMessage({ type: 'openUrl', url: 'https://pub.dev/packages/' + el.dataset.name + '/changelog' });
                }
            });
            detailPane.addEventListener('change', function(e) {
                var sel = e.target.closest('.review-select');
                if (!sel) { return; }
                var row = sel.closest('tr');
                if (!row) { return; }
                row.dataset.review = sel.value;
                vscode.postMessage({ type: 'setReviewStatus', itemNumber: parseInt(row.dataset.number, 10), status: sel.value });
                paneUpdateReviewSummary(row.closest('.section'));
            });
            var paneNoteTimers = {};
            detailPane.addEventListener('input', function(e) {
                var notes = e.target.closest('.notes-input');
                if (notes) {
                    var row = notes.closest('tr');
                    if (!row) { return; }
                    var num = parseInt(row.dataset.number, 10);
                    clearTimeout(paneNoteTimers[num]);
                    paneNoteTimers[num] = setTimeout(function() {
                        vscode.postMessage({ type: 'addReviewNote', itemNumber: num, notes: notes.value });
                    }, 500);
                    return;
                }
                var search = e.target.closest('.gap-search');
                if (search) { paneApplyGapFilters(search.closest('.section')); }
            });
        }
        /* ---- Live scan-progress bar ----
           Driven by host postMessage during a rescan. scanStarted shows the bar
           with an indeterminate sweep; scanProgress sets a determinate fill +
           phase label; scanFinished hides it (the happy path also rebuilds the
           whole panel HTML, so this mainly covers cancel/abort where no rebuild
           occurs). Width is set via CSSOM, which the strict nonce CSP allows. */
        var scanProgressEl = document.getElementById('scan-progress');
        var scanFillEl = document.getElementById('scan-progress-fill');
        var scanLabelEl = document.getElementById('scan-progress-label');
        var scanPctEl = document.getElementById('scan-progress-pct');
        function showScanProgress() {
            if (!scanProgressEl) { return; }
            scanProgressEl.hidden = false;
            if (scanFillEl) { scanFillEl.classList.add('indeterminate'); }
            if (scanLabelEl) {
                scanLabelEl.textContent = scanProgressEl.dataset.starting || '';
            }
            if (scanPctEl) { scanPctEl.textContent = ''; }
        }
        function updateScanProgress(percent, message) {
            if (!scanProgressEl) { return; }
            scanProgressEl.hidden = false;
            var pct = Math.max(0, Math.min(100, Math.round(percent || 0)));
            if (scanFillEl) {
                /* A real percent arrived — drop the indeterminate sweep and
                   pin the fill width so the bar tracks actual progress. */
                scanFillEl.classList.remove('indeterminate');
                scanFillEl.style.width = pct + '%';
            }
            scanProgressEl.setAttribute('aria-valuenow', String(pct));
            if (scanLabelEl && message) { scanLabelEl.textContent = message; }
            if (scanPctEl) { scanPctEl.textContent = pct + '%'; }
        }
        function hideScanProgress() {
            if (!scanProgressEl) { return; }
            scanProgressEl.hidden = true;
            if (scanFillEl) {
                scanFillEl.classList.remove('indeterminate');
                scanFillEl.style.width = '0%';
            }
        }
        /* ---- Detail-pane action busy state ----
           A pane button (Upgrade / Retry) that kicks off a slow host operation
           (pub get + full test suite, or network re-fetches) gets disabled and
           relabelled with its data-busy-label so the pane doesn't look idle.
           setPaneBtnBusy is optimistic on click; the host also drives it via the
           'paneAction' message so an externally-triggered upgrade or a failed
           run (no pane re-render) leaves the button in the right state. */
        function setPaneBtnBusy(btn) {
            if (!btn || btn.disabled) { return; }
            if (!btn.dataset.origLabel) { btn.dataset.origLabel = btn.textContent; }
            btn.disabled = true;
            btn.setAttribute('aria-busy', 'true');
            btn.classList.add('btn-busy');
            btn.textContent = btn.dataset.busyLabel || btn.dataset.origLabel;
        }
        function clearPaneBtnBusy(btn) {
            if (!btn) { return; }
            if (btn.dataset.origLabel) { btn.textContent = btn.dataset.origLabel; }
            btn.disabled = false;
            btn.removeAttribute('aria-busy');
            btn.classList.remove('btn-busy');
        }
        /* Host -> client: injected detail HTML, and reveal-from-elsewhere. */
        window.addEventListener('message', function(event) {
            var msg = event.data || {};
            if (msg.type === 'packageDetailHtml' && detailPaneBody) {
                detailPaneBody.innerHTML = msg.html;
                if (detailPane) {
                    detailPane.hidden = false;
                    detailPane.scrollTop = 0;
                }
            } else if (msg.type === 'selectPackage' && msg.package) {
                openDetailPane(msg.package);
            } else if (msg.type === 'scanStarted') {
                showScanProgress();
            } else if (msg.type === 'scanProgress') {
                updateScanProgress(msg.percent, msg.message);
            } else if (msg.type === 'scanFinished') {
                hideScanProgress();
            } else if (msg.type === 'paneAction' && msg.action === 'upgrade') {
                var upBtn = detailPane
                    ? detailPane.querySelector('[data-action="upgrade"]')
                    : null;
                if (msg.state === 'busy') { setPaneBtnBusy(upBtn); }
                else if (msg.state === 'done') { clearPaneBtnBusy(upBtn); }
            }
        });
        /* Tell the host the message listener is live so a select requested
         * right after the dashboard opens (from hover / sidebar) is delivered
         * rather than dropped against a not-yet-ready webview. */
        vscode.postMessage({ type: 'dashboardReady' });

        function toggleDetail(pkgRow) {
            var name = pkgRow.dataset.name;
            var detailRow = document.querySelector('tr[data-detail-for="' + name + '"]');
            if (!detailRow) { return; }
            var isExpanded = pkgRow.classList.contains('expanded');
            if (isExpanded) {
                pkgRow.classList.remove('expanded');
                /* HTML5 hidden boolean property — more portable than
                 * style.display='none' on table rows. Some webview renderers
                 * (notably the Cursor IDE in certain builds) ignore inline
                 * display:none on <tr>, leaving the detail visible while the
                 * chevron stays right-pointing — exactly the bug this fixes. */
                detailRow.hidden = true;
            } else {
                pkgRow.classList.add('expanded');
                detailRow.hidden = false;
            }
        }

        /* ---- Keyboard navigation ---- */

        document.addEventListener('keydown', function(e) {
            var searchEl = document.getElementById('search-input');
            var typingInSearch = document.activeElement && document.activeElement.id === 'search-input';

            /* §15.2 — '/' focuses the search input from anywhere on the page.
               Skip when the user is already typing in any input so the slash
               key still types a literal slash inside text fields. */
            var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
            var inEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
            if (e.key === '/' && !inEditable) {
                e.preventDefault();
                if (searchEl) { searchEl.focus(); searchEl.select && searchEl.select(); }
                return;
            }

            /* §15.2 — Esc on a focused, non-empty search clears the value first;
               the broader Esc-collapses-rows handler below still fires on a
               second Esc when the search is already empty. Clearing the input
               by hand keeps the existing input dispatch path running so filters
               re-apply normally. */
            if (e.key === 'Escape' && typingInSearch && searchEl && searchEl.value) {
                e.preventDefault();
                searchEl.value = '';
                searchEl.dispatchEvent(new Event('input', { bubbles: true }));
                return;
            }

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
                if (typingInSearch) { return; }
                e.preventDefault();
                if (focusedRowIdx >= 0 && focusedRowIdx < rows.length) {
                    openDetailPane(rows[focusedRowIdx].dataset.name);
                }
            } else if (e.key === 'Escape') {
                /* Close the detail pane and clear focus. */
                hideNavPopover();
                closeDetailPane();
                focusedRowIdx = -1;
                highlightRow(rows);
            } else if (e.altKey && e.key === 'ArrowLeft') {
                e.preventDefault();
                goBackPackageNav();
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

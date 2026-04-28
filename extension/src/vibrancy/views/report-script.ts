/** Client-side JavaScript for the report webview (sorting, filtering, search). */
export function getReportScript(): string {
    return `
        var vscode = acquireVsCodeApi();

        /* ---- Sorting state ---- */
        var sortCol = 'score';
        var sortAsc = true;
        var isRestoringState = false;

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
                /* When a package row is hidden, also hide its detail row. */
                var detailRow = document.querySelector('tr[data-detail-for="' + row.dataset.name + '"]');
                if (detailRow && !show) {
                    detailRow.style.display = 'none';
                    row.classList.remove('expanded');
                }
            });
            updateActiveFiltersUI(searchVal);
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
                host.style.display = 'none';
                list.innerHTML = '';
                return;
            }
            host.style.display = 'flex';
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
           saropaLints.packageVibrancy.scan command. Button is disabled
           while the request is in flight to prevent duplicate scans. */
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
            btn.disabled = true;
            btn.addEventListener('click', function() {
                goBackPackageNav();
            });
            toolbar.insertBefore(btn, toolbar.firstChild);
        }

        function updateBackButtonState() {
            var btn = document.getElementById('pkg-nav-back');
            if (!btn) { return; }
            btn.disabled = packageNavHistory.length === 0;
            btn.title = packageNavHistory.length === 0
                ? 'No previous package'
                : 'Back to previous package';
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

        /* ---- Lightweight dependency network diagram ---- */
        (function renderNetwork() {
            var host = document.getElementById('dep-network');
            if (!host) { return; }
            var raw = host.dataset.network || '[]';
            var nodes = [];
            try { nodes = JSON.parse(raw); } catch (_err) { nodes = []; }
            if (!Array.isArray(nodes) || nodes.length === 0) {
                host.textContent = 'No dependency relationship data.';
                return;
            }
            var width = 860;
            var height = Math.max(220, 90 + nodes.length * 26);
            var leftX = 140;
            var rightX = 680;
            var svg = '<svg viewBox="0 0 ' + width + ' ' + height + '" class="network-svg">';
            nodes.forEach(function(n, i) {
                var y = 40 + i * 28;
                svg += '<text x="' + leftX + '" y="' + y + '" class="network-node direct network-node-link" data-owner="' + n.name + '" data-target="' + n.name + '" role="button" tabindex="0">' + n.name + '</text>';
                var links = Array.isArray(n.links) ? n.links : [];
                links.slice(0, 6).forEach(function(dep, j) {
                    var y2 = y + (j - 2) * 14;
                    svg += '<line x1="' + (leftX + 12) + '" y1="' + (y - 4) + '" x2="' + (rightX - 12) + '" y2="' + (y2 - 4) + '" class="network-edge network-edge-link" data-owner="' + n.name + '" data-target="' + dep + '" />';
                    svg += '<text x="' + rightX + '" y="' + y2 + '" class="network-node transitive network-node-link" data-owner="' + n.name + '" data-target="' + dep + '" role="button" tabindex="0">' + dep + '</text>';
                });
            });
            svg += '</svg>';
            host.innerHTML = svg;
            function clearNetworkSelection() {
                host.querySelectorAll('.network-selected').forEach(function(el) {
                    el.classList.remove('network-selected');
                });
            }
            function highlightNetworkPath(owner, target) {
                clearNetworkSelection();
                host.querySelectorAll('.network-node-link[data-owner="' + owner + '"][data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
                host.querySelectorAll('.network-edge-link[data-owner="' + owner + '"][data-target="' + target + '"]').forEach(function(el) {
                    el.classList.add('network-selected');
                });
                if (owner === target) {
                    host.querySelectorAll('.network-node-link[data-owner="' + owner + '"][data-target="' + owner + '"]').forEach(function(el) {
                        el.classList.add('network-selected');
                    });
                }
            }
            host.querySelectorAll('.network-node-link').forEach(function(nodeEl) {
                function runNavigation() {
                    var owner = nodeEl.dataset.owner || '';
                    var target = nodeEl.dataset.target || '';
                    if (!target) { return; }
                    if (owner) { highlightNetworkPath(owner, target); }
                    navigateToPackageRow(target, owner && owner !== target ? owner : null);
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
                    var owner = edgeEl.dataset.owner || '';
                    var target = edgeEl.dataset.target || '';
                    if (!owner || !target) { return; }
                    highlightNetworkPath(owner, target);
                    navigateToPackageRow(target, owner);
                });
            });
        })();

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
                hideNavPopover();
                document.querySelectorAll('.pkg-row.expanded').forEach(function(row) {
                    toggleDetail(row);
                });
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

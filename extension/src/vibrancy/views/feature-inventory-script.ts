/**
 * Client-side behavior for the Package Feature Inventory report.
 *
 * TRAP, learned the hard way in this repo: this source is embedded in a
 * TypeScript template literal, so a backslash is consumed by TS before the
 * browser ever sees it — `\d` arrives as `d` and a regex silently matches the
 * wrong thing. This module therefore contains NO backslashes and NO regular
 * expressions at all; matching uses `indexOf`, and every string is built with
 * concatenation rather than a nested template literal (`${` would interpolate
 * at build time).
 */

/** Text filter plus the mutually exclusive state/category mode buttons. */
function getFilterScript(): string {
    return `
        var featureNodes = Array.prototype.slice.call(document.querySelectorAll('.fi-feature'));
        var groupNodes = Array.prototype.slice.call(document.querySelectorAll('.fi-category, .fi-package'));
        var modeButtons = Array.prototype.slice.call(document.querySelectorAll('.fi-mode'));
        var searchBox = document.getElementById('fi-search');
        var mode = 'all';

        function matchesMode(node) {
            var state = node.getAttribute('data-state');
            if (mode === 'unused') { return state === 'unused' || state === 'partial'; }
            if (mode === 'used') { return state === 'adopted' || state === 'partial'; }
            if (mode === 'deprecated') { return node.getAttribute('data-category') === 'deprecated'; }
            return true;
        }

        function applyFilter() {
            var query = searchBox ? searchBox.value.toLowerCase() : '';
            featureNodes.forEach(function (node) {
                var text = node.getAttribute('data-text') || '';
                var visible = matchesMode(node) && (query === '' || text.indexOf(query) !== -1);
                node.classList.toggle('fi-hidden', !visible);
            });
            groupNodes.forEach(function (group) {
                // A package with no features at all (no changelog) carries a
                // disclosed note rather than rows, so it must never be filtered
                // away — hide only groups that HAD features and now show none.
                var total = group.querySelectorAll('.fi-feature').length;
                var shown = group.querySelectorAll('.fi-feature:not(.fi-hidden)').length;
                group.classList.toggle('fi-hidden', total > 0 && shown === 0);
            });
        }

        if (searchBox) { searchBox.addEventListener('input', applyFilter); }
        modeButtons.forEach(function (button) {
            button.addEventListener('click', function () {
                var next = button.getAttribute('data-mode');
                mode = mode === next ? 'all' : next;
                modeButtons.forEach(function (other) {
                    other.setAttribute('aria-pressed', other.getAttribute('data-mode') === mode ? 'true' : 'false');
                });
                applyFilter();
            });
        });
    `;
}

/** Expand-all / collapse-all, and opening a package jumped to from a link. */
function getDisclosureScript(): string {
    return `
        function setAllOpen(open) {
            Array.prototype.slice.call(document.querySelectorAll('details')).forEach(function (node) {
                node.open = open;
            });
        }
        var expandButton = document.getElementById('fi-expand');
        var collapseButton = document.getElementById('fi-collapse');
        if (expandButton) { expandButton.addEventListener('click', function () { setAllOpen(true); }); }
        if (collapseButton) { collapseButton.addEventListener('click', function () { setAllOpen(false); }); }

        function openTarget() {
            var hash = window.location.hash;
            if (!hash || hash.length < 2) { return; }
            var target = document.getElementById(hash.substring(1));
            while (target) {
                if (target.tagName === 'DETAILS') { target.open = true; }
                target = target.parentElement;
            }
        }
        window.addEventListener('hashchange', openTarget);
        openTarget();
    `;
}

/**
 * Click-to-sort on the summary table. Sort keys live in `data-sort` on each
 * cell, pre-formatted by the renderer, so the browser never has to parse a
 * localized number back out of display text.
 */
function getSortScript(): string {
    return `
        var table = document.getElementById('fi-summary');
        if (table) {
            var headers = Array.prototype.slice.call(table.querySelectorAll('thead th'));
            headers.forEach(function (header, index) {
                header.addEventListener('click', function () {
                    var body = table.tBodies[0];
                    var rows = Array.prototype.slice.call(body.rows);
                    var numeric = header.getAttribute('data-sort-type') === 'number';
                    var descending = header.getAttribute('data-sort-dir') !== 'desc';
                    rows.sort(function (a, b) {
                        var left = a.cells[index].getAttribute('data-sort') || '';
                        var right = b.cells[index].getAttribute('data-sort') || '';
                        var result = numeric
                            ? Number(left) - Number(right)
                            : left.localeCompare(right);
                        return descending ? -result : result;
                    });
                    headers.forEach(function (other) { other.removeAttribute('data-sort-dir'); });
                    header.setAttribute('data-sort-dir', descending ? 'desc' : 'asc');
                    rows.forEach(function (row) { body.appendChild(row); });
                });
            });
        }
    `;
}

/** The complete inline script, injected once under the document's CSP nonce. */
export function getFeatureInventoryScript(): string {
    return getFilterScript() + getDisclosureScript() + getSortScript();
}

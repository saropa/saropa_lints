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

/**
 * Text filter plus the mutually exclusive state/category mode buttons.
 * @param root JS expression resolving to the container element (or `'document'`
 *   for standalone use). Scoping to a container prevents queries from reaching
 *   into sibling tabs when this script is embedded in the Package Dashboard.
 */
function getFilterScript(root: string): string {
    return `
        var featureNodes = Array.prototype.slice.call(${root}.querySelectorAll('.fi-feature'));
        var groupNodes = Array.prototype.slice.call(${root}.querySelectorAll('.fi-category, .fi-package'));
        var modeButtons = Array.prototype.slice.call(${root}.querySelectorAll('.fi-mode'));
        var searchBox = ${root}.querySelector('#fi-search');
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

/**
 * Expand-all / collapse-all, and opening a package jumped to from a link.
 * @param root JS expression for the container — scopes the unqualified
 *   `details` query so "Expand all" only affects the Feature Inventory tab,
 *   not every `<details>` in the Package Dashboard (charts, filters, etc.).
 */
function getDisclosureScript(root: string): string {
    return `
        function setAllOpen(open) {
            Array.prototype.slice.call(${root}.querySelectorAll('details')).forEach(function (node) {
                node.open = open;
            });
        }
        var expandButton = ${root}.querySelector('#fi-expand');
        var collapseButton = ${root}.querySelector('#fi-collapse');
        if (expandButton) { expandButton.addEventListener('click', function () { setAllOpen(true); }); }
        if (collapseButton) { collapseButton.addEventListener('click', function () { setAllOpen(false); }); }

        function openTarget() {
            var hash = window.location.hash;
            if (!hash || hash.length < 2) { return; }
            // Hash targets are unique IDs — safe to query from document even
            // when the rest of the script is scoped to a container.
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
function getSortScript(root: string): string {
    return `
        var table = ${root}.querySelector('#fi-summary');
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

/** The complete inline script for standalone use (full document scope). */
export function getFeatureInventoryScript(): string {
    return getFilterScript('document') + getDisclosureScript('document') + getSortScript('document');
}

/**
 * IIFE-wrapped variant for embedding inside the Package Dashboard's composed
 * `<script>`. Scopes every DOM query to `#pkg-tab-fullReport` so expand/collapse,
 * sort clicks, and filter state cannot leak into sibling tabs (Overview, Settings,
 * etc.). Mirrors `getKnownIssuesEmbedScript` in `known-issues-script.ts`.
 */
export function getFeatureInventoryEmbedScript(): string {
    // Bail out if the container is missing rather than falling back to
    // `document` — that would silently reintroduce the cross-tab leak this
    // IIFE exists to prevent. The element is always present because the
    // script runs inside the same HTML that defines the tab panel.
    return `(function(){
var fiRoot=document.getElementById('pkg-tab-fullReport');
if(!fiRoot){return;}
${getFilterScript('fiRoot')}${getDisclosureScript('fiRoot')}${getSortScript('fiRoot')}
})();`;
}

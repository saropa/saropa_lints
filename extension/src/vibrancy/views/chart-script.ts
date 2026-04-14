/** Client-side JavaScript for chart interactivity (tooltips, highlights, filter). */
export function getChartScript(): string {
    return `
(function() {
    var tooltip = document.getElementById('chart-tooltip');
    if (!tooltip) return;

    /* --- Donut draw-in animation ---
     * Store each segment's final dasharray, reset to "0 C", then restore
     * after two rAF frames so the CSS transition animates the draw-in. */
    var segments = document.querySelectorAll('.donut-segment');
    var finalDash = [];
    segments.forEach(function(seg, i) {
        finalDash[i] = seg.getAttribute('stroke-dasharray');
        var r = parseFloat(seg.getAttribute('r'));
        var circ = 2 * Math.PI * r;
        seg.setAttribute('stroke-dasharray', '0 ' + circ);
    });
    requestAnimationFrame(function() {
        requestAnimationFrame(function() {
            segments.forEach(function(seg, i) {
                seg.setAttribute('stroke-dasharray', finalDash[i]);
            });
        });
    });

    /* --- Tooltip helpers ---
     * Uses DOM construction instead of innerHTML to prevent XSS from
     * package names that could contain HTML-like characters. */
    function showTooltip(e, name, sizeLabel, pct) {
        tooltip.textContent = '';
        var strong = document.createElement('strong');
        strong.textContent = name;
        tooltip.appendChild(strong);
        tooltip.appendChild(document.createElement('br'));
        tooltip.appendChild(
            document.createTextNode(sizeLabel + ' (' + pct + '%)')
        );
        tooltip.classList.add('visible');
        positionTooltip(e);
    }

    function positionTooltip(e) {
        tooltip.style.left = (e.clientX + 12) + 'px';
        tooltip.style.top = (e.clientY - 8) + 'px';
    }

    function hideTooltip() {
        tooltip.classList.remove('visible');
    }

    /* --- Cross-highlight: hovering one chart dims the other ---
     * Named segments highlight their counterpart; "Other" dims all
     * named segments to emphasize the aggregate slice. */
    function highlightSegment(packageName, isOther) {
        if (isOther) {
            segments.forEach(function(seg) {
                if (!seg.dataset.other) seg.classList.add('dimmed');
            });
            document.querySelectorAll('.bar-row:not([data-other])').forEach(
                function(row) { row.classList.add('dimmed'); }
            );
            return;
        }
        if (!packageName) return;
        segments.forEach(function(seg) {
            if (seg.dataset.package !== packageName) {
                seg.classList.add('dimmed');
            }
        });
        document.querySelectorAll('.bar-row').forEach(function(row) {
            if (row.dataset.package === packageName) {
                row.classList.add('highlighted');
            }
        });
    }

    function clearHighlight() {
        segments.forEach(function(s) { s.classList.remove('dimmed'); });
        document.querySelectorAll('.bar-row').forEach(function(r) {
            r.classList.remove('highlighted');
            r.classList.remove('dimmed');
        });
    }

    /* --- Bar row hover + click-to-filter --- */
    document.querySelectorAll('.bar-row').forEach(function(row) {
        row.addEventListener('mouseenter', function(e) {
            var label = row.querySelector('.bar-label');
            var name = label ? label.textContent : '';
            showTooltip(e, name, fmtBytes(row.dataset.size), row.dataset.pct);
            highlightSegment(row.dataset.package, !!row.dataset.other);
        });
        row.addEventListener('mousemove', positionTooltip);
        row.addEventListener('mouseleave', function() {
            hideTooltip();
            clearHighlight();
        });
        row.addEventListener('click', function() {
            /* toggleChartFilter is defined in report-script.ts (global scope) */
            if (typeof toggleChartFilter === 'function') {
                toggleChartFilter(row.dataset.package);
            }
        });
    });

    /* --- Donut segment hover + click-to-filter --- */
    segments.forEach(function(seg) {
        seg.addEventListener('mouseenter', function(e) {
            showTooltip(e, seg.dataset.name, seg.dataset.sizeLabel, seg.dataset.pct);
            highlightSegment(seg.dataset.package, !!seg.dataset.other);
        });
        seg.addEventListener('mousemove', positionTooltip);
        seg.addEventListener('mouseleave', function() {
            hideTooltip();
            clearHighlight();
        });
        seg.addEventListener('click', function() {
            /* toggleChartFilter is defined in report-script.ts (global scope) */
            if (typeof toggleChartFilter === 'function') {
                toggleChartFilter(seg.dataset.package);
            }
        });
    });

    /* --- Client-side size formatter (mirrors server-side formatSizeMB) --- */
    function fmtBytes(raw) {
        var bytes = parseInt(raw, 10);
        if (isNaN(bytes) || bytes <= 0) return '\\u2014';
        var mb = bytes / (1024 * 1024);
        if (mb < 0.01) return '<0.01 MB';
        if (mb < 1) return mb.toFixed(2) + ' MB';
        return mb.toFixed(1) + ' MB';
    }

    /* --- Include/exclude transitives toggle ---
     * Hides transitive bar rows and rebuilds the donut chart from the
     * remaining visible segments so percentages recalculate correctly. */
    var transitiveToggle = document.getElementById('include-transitives');
    if (transitiveToggle) {
        transitiveToggle.addEventListener('change', function() {
            var include = transitiveToggle.checked;
            rebuildChartWithFilter(include);
        });
    }

    /**
     * Compute the effective size of a row/segment for the current toggle state.
     * The "Other" bucket may contain transitive bytes that should be subtracted
     * when transitives are excluded — data-transitive-size tracks that amount.
     */
    function effectiveSize(el, includeTransitives) {
        var base = parseInt(el.dataset.size, 10) || 0;
        if (includeTransitives) { return base; }
        var transitiveBytes = parseInt(el.dataset.transitiveSize, 10) || 0;
        return Math.max(0, base - transitiveBytes);
    }

    function rebuildChartWithFilter(includeTransitives) {
        /* Hide/show transitive bar rows */
        var allRows = document.querySelectorAll('.bar-row');
        allRows.forEach(function(row) {
            if (row.dataset.section === 'transitive') {
                row.style.display = includeTransitives ? '' : 'none';
            }
        });

        /* Collect visible rows and compute totals in one pass */
        var visibleRows = [];
        var maxSize = 0;
        var totalSize = 0;
        allRows.forEach(function(row) {
            if (row.style.display === 'none') { return; }
            var size = effectiveSize(row, includeTransitives);
            visibleRows.push({ el: row, size: size });
            if (size > maxSize) { maxSize = size; }
            totalSize += size;
        });

        /* Update bar widths, percentages, and labels */
        visibleRows.forEach(function(item) {
            var barWidth = maxSize > 0 ? (item.size / maxSize) * 100 : 0;
            var pct = totalSize > 0 ? (item.size / totalSize) * 100 : 0;
            var fill = item.el.querySelector('.bar-fill');
            if (fill) {
                fill.style.setProperty('--bar-pct', barWidth.toFixed(1) + '%');
                /* Reset animation so bars re-grow to new width */
                fill.style.animation = 'none';
                fill.offsetHeight; /* force reflow */
                fill.style.animation = '';
            }
            var valueEl = item.el.querySelector('.bar-value');
            if (valueEl) {
                valueEl.textContent = fmtBytes(String(item.size))
                    + ' (' + pct.toFixed(1) + '%)';
            }
            item.el.dataset.pct = pct.toFixed(1);
        });

        /* Rebuild donut from visible segments */
        rebuildDonut(includeTransitives, totalSize);
    }

    function rebuildDonut(includeTransitives, totalSize) {
        var donutSvg = document.querySelector('.donut-chart');
        if (!donutSvg) return;
        var allSegs = document.querySelectorAll('.donut-segment');
        var radius = 70;
        var circ = 2 * Math.PI * radius;
        var center = 100;
        var gap = 1;
        var offset = 0;

        allSegs.forEach(function(seg) {
            var isTransitive = seg.dataset.section === 'transitive';
            if (!includeTransitives && isTransitive) {
                /* Hide by zeroing the arc length */
                seg.setAttribute('stroke-dasharray', '0 ' + circ);
                seg.style.opacity = '0';
                return;
            }
            seg.style.opacity = '';
            var size = effectiveSize(seg, includeTransitives);
            var pct = totalSize > 0 ? (size / totalSize) * 100 : 0;
            var segLen = (pct / 100) * circ;
            var dash = Math.max(0, segLen - gap) + ' ' + circ;
            var rot = (offset / circ) * 360 - 90;
            offset += segLen;
            seg.setAttribute('stroke-dasharray', dash);
            seg.setAttribute('transform',
                'rotate(' + rot.toFixed(2) + ' ' + center + ' ' + center + ')');
            seg.dataset.pct = pct.toFixed(1);
        });
    }
})();
    `;
}

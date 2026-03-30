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
})();
    `;
}

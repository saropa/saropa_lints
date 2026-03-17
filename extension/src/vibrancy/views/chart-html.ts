import { VibrancyResult } from '../types';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { escapeHtml } from './html-utils';

/** A single segment in the bar/donut charts. */
interface ChartSegment {
    readonly name: string;
    readonly sizeBytes: number;
    readonly percentage: number;
    readonly colorIndex: number;
    readonly isOther: boolean;
}

const MAX_NAMED_SEGMENTS = 8;
const MIN_PERCENTAGE = 1.0;
/** Color index for the "Other" consolidated segment (muted theme color). */
const OTHER_COLOR_INDEX = 9;

/** Build the full chart section HTML, or empty string if no size data. */
export function buildChartSection(results: VibrancyResult[]): string {
    const segments = prepareChartData(results);
    if (segments.length === 0) { return ''; }

    return `
    <section class="chart-section">
        <h2>Size Distribution</h2>
        <div class="chart-container">
            <div class="bar-chart-panel">
                ${buildBarChart(segments)}
            </div>
            <div class="donut-chart-panel">
                ${buildDonutChart(segments)}
            </div>
        </div>
        <div class="chart-tooltip" id="chart-tooltip"></div>
    </section>`;
}

/**
 * Sort packages by size descending, keep top N that each meet the minimum
 * percentage threshold, and consolidate the rest into "Other".
 */
function prepareChartData(results: VibrancyResult[]): ChartSegment[] {
    const withSize = results
        .filter(r => r.archiveSizeBytes !== null && r.archiveSizeBytes > 0)
        .map(r => ({ name: r.package.name, sizeBytes: r.archiveSizeBytes! }));

    withSize.sort((a, b) => b.sizeBytes - a.sizeBytes);

    const totalBytes = withSize.reduce((sum, p) => sum + p.sizeBytes, 0);
    if (totalBytes === 0) { return []; }

    const named: typeof withSize = [];
    const otherPool: typeof withSize = [];

    for (const pkg of withSize) {
        const pct = (pkg.sizeBytes / totalBytes) * 100;
        /* Both conditions must hold: a slot is available AND the package
         * is large enough to be visually meaningful as its own segment. */
        if (named.length < MAX_NAMED_SEGMENTS && pct >= MIN_PERCENTAGE) {
            named.push(pkg);
        } else {
            otherPool.push(pkg);
        }
    }

    const segments: ChartSegment[] = named.map((pkg, i) => ({
        name: pkg.name,
        sizeBytes: pkg.sizeBytes,
        percentage: (pkg.sizeBytes / totalBytes) * 100,
        colorIndex: i,
        isOther: false,
    }));

    if (otherPool.length > 0) {
        const otherBytes = otherPool.reduce((s, p) => s + p.sizeBytes, 0);
        const noun = otherPool.length === 1 ? 'package' : 'packages';
        segments.push({
            name: `Other (${otherPool.length} ${noun})`,
            sizeBytes: otherBytes,
            percentage: (otherBytes / totalBytes) * 100,
            colorIndex: OTHER_COLOR_INDEX,
            isOther: true,
        });
    }

    return segments;
}

/** Build horizontal bar chart rows. Bars are normalized so largest = 100%. */
function buildBarChart(segments: ChartSegment[]): string {
    const maxPct = Math.max(...segments.map(s => s.percentage));

    const rows = segments.map(seg => {
        const barWidth = (seg.percentage / maxPct) * 100;
        const sizeLabel = formatSizeMB(seg.sizeBytes);
        const pctLabel = seg.percentage.toFixed(1);
        const safeName = escapeHtml(seg.name);
        const dataAttrs = seg.isOther
            ? 'data-other="true"'
            : `data-package="${safeName}"`;

        return `<div class="bar-row" ${dataAttrs}
                data-size="${seg.sizeBytes}" data-pct="${pctLabel}">
            <div class="bar-label" title="${safeName}">${safeName}</div>
            <div class="bar-track">
                <div class="bar-fill bar-color-${seg.colorIndex}"
                     style="--bar-pct: ${barWidth.toFixed(1)}%"></div>
            </div>
            <div class="bar-value">${sizeLabel} (${pctLabel}%)</div>
        </div>`;
    }).join('\n');

    return `<div class="bar-chart">${rows}</div>`;
}

/** Build SVG donut chart using stroke-dasharray arcs on circles. */
function buildDonutChart(segments: ChartSegment[]): string {
    const size = 200;
    const radius = 70;
    const circumference = 2 * Math.PI * radius;
    const center = size / 2;
    const innerRadius = 45;
    const gap = segments.length > 1 ? 1 : 0;

    let accumulatedOffset = 0;

    const circles = segments.map(seg => {
        const segmentLength = (seg.percentage / 100) * circumference;
        const dashArray =
            `${Math.max(0, segmentLength - gap)} ${circumference}`;
        const rotation =
            (accumulatedOffset / circumference) * 360 - 90;
        accumulatedOffset += segmentLength;

        const safeName = escapeHtml(seg.name);
        const sizeLabel = formatSizeMB(seg.sizeBytes);
        const dataAttrs = seg.isOther
            ? 'data-other="true"'
            : `data-package="${safeName}"`;

        return `<circle class="donut-segment donut-color-${seg.colorIndex}"
            ${dataAttrs}
            data-size="${seg.sizeBytes}"
            data-pct="${seg.percentage.toFixed(1)}"
            data-name="${safeName}"
            data-size-label="${sizeLabel}"
            cx="${center}" cy="${center}" r="${radius}"
            fill="none"
            stroke-width="25"
            stroke-dasharray="${dashArray}"
            stroke-dashoffset="0"
            transform="rotate(${rotation.toFixed(2)} ${center} ${center})"
        />`;
    }).join('\n');

    /* Inner circle masks center to create the donut hole */
    return `<svg class="donut-chart" viewBox="0 0 ${size} ${size}"
                 width="${size}" height="${size}">
        ${circles}
        <circle cx="${center}" cy="${center}" r="${innerRadius}"
                fill="var(--vscode-editor-background)" />
    </svg>`;
}

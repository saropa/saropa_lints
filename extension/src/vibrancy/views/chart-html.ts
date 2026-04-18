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
    /** Dependency section — used to filter transitives from the chart. */
    readonly section: string;
    /** Whether this segment (or consolidation bucket) represents shared
     *  transitive deps that are already pulled in by other direct deps. */
    readonly isSharedTransitive: boolean;
    /** Consolidation bucket type for the three aggregate segments. Named
     *  segments always use 'named'. */
    readonly bucket: 'named' | 'other-direct' | 'unique-transitive' | 'shared-transitive';
    /** Count of packages consolidated into this segment (only meaningful
     *  for non-named buckets). */
    readonly packageCount: number;
}

const MAX_NAMED_SEGMENTS = 8;
const MIN_PERCENTAGE = 1.0;
/** Color index for the "Other" direct-dep consolidated segment. */
const OTHER_COLOR_INDEX = 9;
/** Color index for the "Unique transitives" consolidated segment. */
const UNIQUE_TRANSITIVE_COLOR_INDEX = 10;
/** Color index for the "Shared transitives" consolidated segment. */
const SHARED_TRANSITIVE_COLOR_INDEX = 11;

/**
 * Derive the set of shared transitive dependency names from the results.
 * A transitive is "shared" if it appears in the sharedDeps list of any
 * direct dependency's TransitiveInfo — meaning 2+ direct deps pull it in.
 */
function deriveSharedDepNames(results: VibrancyResult[]): ReadonlySet<string> {
    return new Set(
        results
            .filter(r => r.transitiveInfo)
            .flatMap(r => r.transitiveInfo!.sharedDeps),
    );
}

/** Build the full chart section HTML, or empty string if no size data. */
export function buildChartSection(results: VibrancyResult[]): string {
    const sharedDepNames = deriveSharedDepNames(results);
    const segments = prepareChartData(results, sharedDepNames);
    if (segments.length === 0) { return ''; }

    // Show the "Exclude shared" toggle when any shared transitives exist
    // in the chart data — either as a consolidation bucket or as individual
    // named segments that happen to be shared transitives.
    const hasShared = segments.some(s => s.isSharedTransitive);
    const toggleHtml = hasShared
        ? `<label class="chart-toggle">
               <input type="checkbox" id="exclude-shared" />
               Exclude shared
           </label>`
        : '';

    return `
    <section class="chart-section">
        <div class="chart-header">
            <h2>Size Distribution</h2>
            ${toggleHtml}
        </div>
        <div class="chart-container">
            <div class="bar-chart-panel">
                ${buildBarChart(segments)}
            </div>
            <div class="donut-chart-panel">
                ${buildDonutChart(segments)}
            </div>
        </div>
        <div class="chart-tooltip" id="chart-tooltip"></div>
        <div class="chart-filter-indicator" id="chart-filter-indicator" style="display:none">
            <span class="filter-text"></span>
            <button class="clear-filter-btn" id="clear-chart-filter">&times; Clear</button>
        </div>
    </section>`;
}

/**
 * Sort packages by size descending, keep top N that each meet the minimum
 * percentage threshold, and consolidate the rest into three buckets:
 *   1. "Other (N packages)" — small direct deps
 *   2. "Unique transitives (N)" — transitives used by only 1 direct dep
 *   3. "Shared transitives (N)" — transitives used by 2+ direct deps
 */
function prepareChartData(
    results: VibrancyResult[],
    sharedDepNames: ReadonlySet<string>,
): ChartSegment[] {
    const withSize = results
        .filter(r => r.archiveSizeBytes !== null && r.archiveSizeBytes > 0)
        .map(r => ({
            name: r.package.name,
            sizeBytes: r.archiveSizeBytes!,
            section: r.package.section,
            isTransitive: r.package.section === 'transitive',
            isShared: r.package.section === 'transitive'
                && sharedDepNames.has(r.package.name),
        }));

    withSize.sort((a, b) => b.sizeBytes - a.sizeBytes);

    const totalBytes = withSize.reduce((sum, p) => sum + p.sizeBytes, 0);
    if (totalBytes === 0) { return []; }

    // Partition into named segments (top N above threshold) and pools
    const named: typeof withSize = [];
    const otherDirect: typeof withSize = [];
    const uniqueTransitivePool: typeof withSize = [];
    const sharedTransitivePool: typeof withSize = [];

    for (const pkg of withSize) {
        const pct = (pkg.sizeBytes / totalBytes) * 100;
        // Both conditions must hold: a slot is available AND the package
        // is large enough to be visually meaningful as its own segment.
        if (named.length < MAX_NAMED_SEGMENTS && pct >= MIN_PERCENTAGE) {
            named.push(pkg);
        } else if (pkg.isShared) {
            sharedTransitivePool.push(pkg);
        } else if (pkg.isTransitive) {
            uniqueTransitivePool.push(pkg);
        } else {
            otherDirect.push(pkg);
        }
    }

    // Build named segments
    const segments: ChartSegment[] = named.map((pkg, i) => ({
        name: pkg.name,
        sizeBytes: pkg.sizeBytes,
        percentage: (pkg.sizeBytes / totalBytes) * 100,
        colorIndex: i,
        isOther: false,
        section: pkg.section,
        isSharedTransitive: pkg.isShared,
        bucket: 'named' as const,
        packageCount: 1,
    }));

    // "Other (N packages)" bucket — small direct deps only
    if (otherDirect.length > 0) {
        const otherBytes = otherDirect.reduce((s, p) => s + p.sizeBytes, 0);
        const noun = otherDirect.length === 1 ? 'package' : 'packages';
        segments.push({
            name: `Other (${otherDirect.length} ${noun})`,
            sizeBytes: otherBytes,
            percentage: (otherBytes / totalBytes) * 100,
            colorIndex: OTHER_COLOR_INDEX,
            isOther: true,
            section: '',
            isSharedTransitive: false,
            bucket: 'other-direct',
            packageCount: otherDirect.length,
        });
    }

    // "Unique transitives (N)" bucket — transitives used by only 1 dep
    if (uniqueTransitivePool.length > 0) {
        const uBytes = uniqueTransitivePool.reduce((s, p) => s + p.sizeBytes, 0);
        segments.push({
            name: `Unique transitives (${uniqueTransitivePool.length})`,
            sizeBytes: uBytes,
            percentage: (uBytes / totalBytes) * 100,
            colorIndex: UNIQUE_TRANSITIVE_COLOR_INDEX,
            isOther: false,
            section: 'transitive',
            isSharedTransitive: false,
            bucket: 'unique-transitive',
            packageCount: uniqueTransitivePool.length,
        });
    }

    // "Shared transitives (N)" bucket — transitives used by 2+ deps
    if (sharedTransitivePool.length > 0) {
        const sBytes = sharedTransitivePool.reduce((s, p) => s + p.sizeBytes, 0);
        segments.push({
            name: `Shared transitives (${sharedTransitivePool.length})`,
            sizeBytes: sBytes,
            percentage: (sBytes / totalBytes) * 100,
            colorIndex: SHARED_TRANSITIVE_COLOR_INDEX,
            isOther: false,
            section: 'transitive',
            isSharedTransitive: true,
            bucket: 'shared-transitive',
            packageCount: sharedTransitivePool.length,
        });
    }

    return segments;
}

/** Build horizontal bar chart rows. Bars are normalized so largest = 100%. */
function buildBarChart(segments: ChartSegment[]): string {
    const maxPct = segments.reduce((max, s) => s.percentage > max ? s.percentage : max, 0);

    const rows = segments.map(seg => {
        const barWidth = (seg.percentage / maxPct) * 100;
        const sizeLabel = formatSizeMB(seg.sizeBytes);
        const pctLabel = seg.percentage.toFixed(1);
        const safeName = escapeHtml(seg.name);
        const dataAttrs = seg.isOther
            ? 'data-other="true"'
            : `data-package="${safeName}"`;
        const sectionAttr = seg.section
            ? ` data-section="${escapeHtml(seg.section)}"` : '';
        const bucketAttr = ` data-bucket="${seg.bucket}"`;
        const sharedAttr = seg.isSharedTransitive
            ? ' data-shared="true"' : '';

        return `<div class="bar-row" ${dataAttrs}${sectionAttr}${bucketAttr}${sharedAttr}
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
        const sectionAttr = seg.section
            ? ` data-section="${escapeHtml(seg.section)}"` : '';
        const bucketAttr = ` data-bucket="${seg.bucket}"`;
        const sharedAttr = seg.isSharedTransitive
            ? ' data-shared="true"' : '';

        return `<circle class="donut-segment donut-color-${seg.colorIndex}"
            ${dataAttrs}${sectionAttr}${bucketAttr}${sharedAttr}
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

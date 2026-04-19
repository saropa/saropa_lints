import * as vscode from 'vscode';
import { VibrancyResult, activeFileUsages } from '../types';
import { categoryLabel, categoryToGrade, countByCategory } from '../scoring/status-classifier';
import { formatSizeMB } from '../scoring/bloat-calculator';
import { resolveReportFolder, formatTimestamp } from './report-utils';

/**
 * Export scan results as timestamped markdown and JSON files
 * to a report/ directory in the workspace.
 */
export async function exportReports(
    results: VibrancyResult[],
    metadata: ReportMetadata,
): Promise<string[]> {
    const folder = await resolveReportFolder();
    if (!folder) { return []; }

    const now = new Date();
    const timestamp = formatTimestamp(now);
    const isoTimestamp = now.toISOString();
    const written: string[] = [];

    const mdUri = vscode.Uri.joinPath(
        folder, `${timestamp}_saropa_vibrancy.md`,
    );
    const mdContent = buildMarkdownReport(results, metadata, isoTimestamp);
    await vscode.workspace.fs.writeFile(
        mdUri, Buffer.from(mdContent, 'utf-8'),
    );
    written.push(mdUri.fsPath);

    const jsonUri = vscode.Uri.joinPath(
        folder, `${timestamp}_saropa_vibrancy.json`,
    );
    const jsonContent = buildJsonReport(results, metadata, isoTimestamp);
    await vscode.workspace.fs.writeFile(
        jsonUri, Buffer.from(jsonContent, 'utf-8'),
    );
    written.push(jsonUri.fsPath);

    return written;
}

export interface ReportMetadata {
    readonly flutterVersion: string;
    readonly dartVersion: string;
    readonly executionTimeMs: number;
}

function buildMarkdownReport(
    results: VibrancyResult[],
    meta: ReportMetadata,
    isoTimestamp: string,
): string {
    const counts = countByCategory(results);
    const totalBytes = results.reduce(
        (sum, r) => sum + (r.archiveSizeBytes ?? 0), 0,
    );
    const totalSize = totalBytes > 0 ? formatSizeMB(totalBytes) : undefined;
    const lines = [
        ...mdHeader(meta, isoTimestamp),
        ...mdSummary(results.length, counts, totalSize),
        ...mdPackageRows(results),
    ];
    return lines.join('\n') + '\n';
}

function mdHeader(meta: ReportMetadata, isoTimestamp: string): string[] {
    return [
        '# Saropa Package Vibrancy', '',
        `| | |`, `|---|---|`,
        `| Timestamp | ${isoTimestamp} |`,
        `| Flutter | ${meta.flutterVersion} |`,
        `| Dart | ${meta.dartVersion} |`,
        `| Execution | ${meta.executionTimeMs}ms |`,
    ];
}

function mdSummary(
    total: number,
    counts: { vibrant: number; stable: number; outdated: number; abandoned: number; eol: number },
    totalSize?: string,
): string[] {
    const rows = [
        '', '## Summary', '',
        `| Total | Vibrant | Stable | Outdated | Abandoned | End of Life |`,
        `|-------|---------|--------|----------|-----------|-------------|`,
        `| ${total} | ${counts.vibrant} | ${counts.stable} | ${counts.outdated} | ${counts.abandoned} | ${counts.eol} |`,
    ];
    if (totalSize) {
        rows.push('', `**Total archive size:** ${totalSize} *(before tree shaking)*`);
    }
    return rows;
}

function mdPackageRows(results: VibrancyResult[]): string[] {
    /* Markdown export swapped "Score" (n/10) for "Grade" (letter). The
       old column conveyed the same information as Status (category label)
       just through a rounded number — redundant. Downstream automation
       that parses markdown reports should switch to the JSON sibling. */
    const rows = ['', '## Packages', '',
        '| Name | Version | Latest | Status | Grade | Files | License | Size |',
        '|------|---------|--------|--------|-------|-------|---------|------|',
    ];
    for (const r of results) {
        const latest = r.pubDev?.latestVersion ?? '';
        const label = categoryLabel(r.category);
        const grade = categoryToGrade(r.category);
        const activeUsages = activeFileUsages(r.fileUsages);
        const fileCount = activeUsages.length;
        const fileLocations = activeUsages.length <= 3
            ? activeUsages.map(u => `${u.filePath}:${u.line}`).join(', ')
            : `${fileCount} files`;
        const size = r.archiveSizeBytes !== null
            ? formatSizeMB(r.archiveSizeBytes) : '—';
        const license = r.license ?? '—';
        rows.push(
            `| ${r.package.name} | ${r.package.version} | ${latest} | ${label} | ${grade} | ${fileLocations || '—'} | ${license} | ${size} |`,
        );
    }
    return rows;
}

function buildJsonReport(
    results: VibrancyResult[],
    meta: ReportMetadata,
    isoTimestamp: string,
): string {
    const counts = countByCategory(results);
    const report = {
        audit_metadata: {
            timestamp: isoTimestamp,
            flutter_version: meta.flutterVersion,
            dart_version: meta.dartVersion,
            total_packages_scanned: results.length,
            execution_time_ms: meta.executionTimeMs,
        },
        summary: {
            total: results.length, vibrant: counts.vibrant,
            stable: counts.stable, outdated: counts.outdated,
            abandoned: counts.abandoned, end_of_life: counts.eol,
        },
        packages: results.map(mapPackageToJson),
    };
    return JSON.stringify(report, null, 2) + '\n';
}

function mapPackageToJson(r: VibrancyResult) {
    const activeUsages = activeFileUsages(r.fileUsages);
    return {
        name: r.package.name,
        installed_version: r.package.version,
        latest_version: r.pubDev?.latestVersion ?? '',
        status: categoryLabel(r.category),
        vibrancy_score: r.score,
        pub_points: r.pubDev?.pubPoints ?? 0,
        stars: r.github?.stars ?? 0,
        is_discontinued: r.pubDev?.isDiscontinued ?? false,
        is_unlisted: r.pubDev?.isUnlisted ?? false,
        pub_dev_url: `https://pub.dev/packages/${r.package.name}`,
        repository_url: r.pubDev?.repositoryUrl ?? '',
        license: r.license,
        archive_size_bytes: r.archiveSizeBytes,
        bloat_rating: r.bloatRating,
        file_usage_count: activeUsages.length,
        file_usages: activeUsages.map(u => ({
            file_path: u.filePath,
            line: u.line,
        })),
    };
}

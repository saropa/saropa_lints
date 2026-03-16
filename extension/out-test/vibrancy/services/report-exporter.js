"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.exportReports = exportReports;
const vscode = __importStar(require("vscode"));
const status_classifier_1 = require("../scoring/status-classifier");
const bloat_calculator_1 = require("../scoring/bloat-calculator");
const report_utils_1 = require("./report-utils");
/**
 * Export scan results as timestamped markdown and JSON files
 * to a report/ directory in the workspace.
 */
async function exportReports(results, metadata) {
    const folder = await (0, report_utils_1.resolveReportFolder)();
    if (!folder) {
        return [];
    }
    const now = new Date();
    const timestamp = (0, report_utils_1.formatTimestamp)(now);
    const isoTimestamp = now.toISOString();
    const written = [];
    const mdUri = vscode.Uri.joinPath(folder, `${timestamp}_saropa_vibrancy.md`);
    const mdContent = buildMarkdownReport(results, metadata, isoTimestamp);
    await vscode.workspace.fs.writeFile(mdUri, Buffer.from(mdContent, 'utf-8'));
    written.push(mdUri.fsPath);
    const jsonUri = vscode.Uri.joinPath(folder, `${timestamp}_saropa_vibrancy.json`);
    const jsonContent = buildJsonReport(results, metadata, isoTimestamp);
    await vscode.workspace.fs.writeFile(jsonUri, Buffer.from(jsonContent, 'utf-8'));
    written.push(jsonUri.fsPath);
    return written;
}
function buildMarkdownReport(results, meta, isoTimestamp) {
    const counts = (0, status_classifier_1.countByCategory)(results);
    const totalBytes = results.reduce((sum, r) => sum + (r.archiveSizeBytes ?? 0), 0);
    const totalSize = totalBytes > 0 ? (0, bloat_calculator_1.formatSizeMB)(totalBytes) : undefined;
    const lines = [
        ...mdHeader(meta, isoTimestamp),
        ...mdSummary(results.length, counts, totalSize),
        ...mdPackageRows(results),
    ];
    return lines.join('\n') + '\n';
}
function mdHeader(meta, isoTimestamp) {
    return [
        '# Saropa Package Vibrancy Report', '',
        `| | |`, `|---|---|`,
        `| Timestamp | ${isoTimestamp} |`,
        `| Flutter | ${meta.flutterVersion} |`,
        `| Dart | ${meta.dartVersion} |`,
        `| Execution | ${meta.executionTimeMs}ms |`,
    ];
}
function mdSummary(total, counts, totalSize) {
    const rows = [
        '', '## Summary', '',
        `| Total | Vibrant | Quiet | Legacy-Locked | Stale | End of Life |`,
        `|-------|---------|-------|---------------|-------|-------------|`,
        `| ${total} | ${counts.vibrant} | ${counts.quiet} | ${counts.legacy} | ${counts.stale} | ${counts.eol} |`,
    ];
    if (totalSize) {
        rows.push('', `**Total archive size:** ${totalSize} *(before tree shaking)*`);
    }
    return rows;
}
function mdPackageRows(results) {
    const rows = ['', '## Packages', '',
        '| Name | Version | Latest | Status | Score | License | Size |',
        '|------|---------|--------|--------|-------|---------|------|',
    ];
    for (const r of results) {
        const latest = r.pubDev?.latestVersion ?? '';
        const label = (0, status_classifier_1.categoryLabel)(r.category);
        const displayScore = Math.round(r.score / 10);
        const size = r.archiveSizeBytes !== null
            ? (0, bloat_calculator_1.formatSizeMB)(r.archiveSizeBytes) : '—';
        const license = r.license ?? '—';
        rows.push(`| ${r.package.name} | ${r.package.version} | ${latest} | ${label} | ${displayScore}/10 | ${license} | ${size} |`);
    }
    return rows;
}
function buildJsonReport(results, meta, isoTimestamp) {
    const counts = (0, status_classifier_1.countByCategory)(results);
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
            quiet: counts.quiet, legacy_locked: counts.legacy,
            stale: counts.stale, end_of_life: counts.eol,
        },
        packages: results.map(mapPackageToJson),
    };
    return JSON.stringify(report, null, 2) + '\n';
}
function mapPackageToJson(r) {
    return {
        name: r.package.name,
        installed_version: r.package.version,
        latest_version: r.pubDev?.latestVersion ?? '',
        status: (0, status_classifier_1.categoryLabel)(r.category),
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
    };
}
//# sourceMappingURL=report-exporter.js.map
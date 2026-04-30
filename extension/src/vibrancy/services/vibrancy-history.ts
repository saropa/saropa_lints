import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { categoryToGrade } from '../scoring/status-classifier';
import { VibrancyResult } from '../types';

/** On-disk .saropa_lints history: append snapshots, trends, optional legacy migration. */
const SCHEMA_VERSION = 1;
const MAX_SNAPSHOTS = 50;

export interface PackageSnapshot {
    readonly version: string;
    readonly score: number;
    readonly category: string;
    readonly grade: string;
}

export interface HistorySnapshot {
    readonly timestamp: string;
    readonly extensionVersion: string;
    readonly packages: Record<string, PackageSnapshot>;
}

export interface VibrancyHistory {
    readonly schemaVersion: number;
    readonly snapshots: HistorySnapshot[];
}

interface LegacyReportPackage {
    readonly name: string;
    readonly installed_version: string;
    readonly vibrancy_score: number;
    readonly status: string;
}

interface LegacyVibrancyReport {
    readonly audit_metadata?: { readonly timestamp?: string };
    readonly packages?: LegacyReportPackage[];
}

const EMPTY_HISTORY: VibrancyHistory = {
    schemaVersion: SCHEMA_VERSION,
    snapshots: [],
};

/** Timestamped vibrancy JSON written by the extension export. */
const LEGACY_VIBRANCY_JSON =
    /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_saropa_vibrancy\.json$/;

/** Full paths under `reports/` then legacy `report/`, basename deduped (reports wins). */
async function listLegacyVibrancyJsonPaths(workspaceRoot: string): Promise<string[]> {
    const seenNames = new Set<string>();
    const paths: string[] = [];
    for (const subdir of ['reports', 'report'] as const) {
        const dir = path.join(workspaceRoot, subdir);
        let files: string[];
        try {
            files = await fs.readdir(dir);
        } catch {
            continue;
        }
        for (const name of files) {
            if (!LEGACY_VIBRANCY_JSON.test(name) || seenNames.has(name)) {
                continue;
            }
            seenNames.add(name);
            paths.push(path.join(dir, name));
        }
    }
    paths.sort((a, b) => path.basename(a).localeCompare(path.basename(b)));
    return paths;
}

function historyPath(workspaceRoot: string): string {
    return path.join(workspaceRoot, '.saropa', 'vibrancy-history.json');
}

function tempHistoryPath(workspaceRoot: string): string {
    return path.join(workspaceRoot, '.saropa', 'vibrancy-history.tmp.json');
}

function backupPath(workspaceRoot: string, oldVersion: number): string {
    return path.join(
        workspaceRoot,
        '.saropa',
        `vibrancy-history.v${oldVersion}.bak.json`,
    );
}

function isPackageSnapshot(value: unknown): value is PackageSnapshot {
    if (!value || typeof value !== 'object') { return false; }
    const v = value as Record<string, unknown>;
    return typeof v.version === 'string'
        && typeof v.score === 'number'
        && typeof v.category === 'string'
        && typeof v.grade === 'string';
}

function isHistorySnapshot(value: unknown): value is HistorySnapshot {
    if (!value || typeof value !== 'object') { return false; }
    const v = value as Record<string, unknown>;
    if (typeof v.timestamp !== 'string' || typeof v.extensionVersion !== 'string') {
        return false;
    }
    const pkgs = v.packages;
    if (!pkgs || typeof pkgs !== 'object') { return false; }
    return Object.values(pkgs as Record<string, unknown>).every(isPackageSnapshot);
}

function isVibrancyHistory(value: unknown): value is VibrancyHistory {
    if (!value || typeof value !== 'object') { return false; }
    const v = value as Record<string, unknown>;
    return typeof v.schemaVersion === 'number'
        && Array.isArray(v.snapshots)
        && v.snapshots.every(isHistorySnapshot);
}

async function writeHistoryAtomic(workspaceRoot: string, history: VibrancyHistory): Promise<void> {
    const saropaDir = path.join(workspaceRoot, '.saropa');
    await fs.mkdir(saropaDir, { recursive: true });
    const outPath = historyPath(workspaceRoot);
    const tmpPath = tempHistoryPath(workspaceRoot);
    await fs.writeFile(tmpPath, JSON.stringify(history, null, 2), 'utf8');
    await fs.rename(tmpPath, outPath);
}

function buildSnapshot(
    results: readonly VibrancyResult[],
    extensionVersion: string,
): HistorySnapshot {
    const packages: Record<string, PackageSnapshot> = {};
    // Sort for deterministic serialized output, which keeps diffs predictable.
    const sorted = [...results].sort((a, b) => a.package.name.localeCompare(b.package.name));
    for (const result of sorted) {
        packages[result.package.name] = {
            version: result.package.version,
            score: result.score,
            category: result.category,
            grade: categoryToGrade(result.category),
        };
    }
    return {
        timestamp: new Date().toISOString(),
        extensionVersion,
        packages,
    };
}

function samePackages(
    left: Record<string, PackageSnapshot>,
    right: Record<string, PackageSnapshot>,
): boolean {
    const leftNames = Object.keys(left);
    const rightNames = Object.keys(right);
    if (leftNames.length !== rightNames.length) { return false; }
    for (const name of leftNames) {
        const a = left[name];
        const b = right[name];
        if (!b) { return false; }
        if (a.version !== b.version
            || a.score !== b.score
            || a.category !== b.category
            || a.grade !== b.grade) {
            return false;
        }
    }
    return true;
}

function categoryFromLegacyStatus(status: string): string | null {
    const normalized = status.trim().toLowerCase();
    if (normalized === 'vibrant') { return 'vibrant'; }
    if (normalized === 'stable') { return 'stable'; }
    if (normalized === 'outdated') { return 'outdated'; }
    if (normalized === 'abandoned') { return 'abandoned'; }
    if (normalized === 'end of life') { return 'end-of-life'; }
    return null;
}

function snapshotFromLegacyReport(report: LegacyVibrancyReport): HistorySnapshot | null {
    if (!Array.isArray(report.packages) || report.packages.length === 0) {
        return null;
    }
    const timestamp = report.audit_metadata?.timestamp;
    if (!timestamp) { return null; }
    const packages: Record<string, PackageSnapshot> = {};
    for (const pkg of report.packages) {
        const category = categoryFromLegacyStatus(pkg.status);
        if (!category || typeof pkg.installed_version !== 'string') { continue; }
        if (typeof pkg.vibrancy_score !== 'number') { continue; }
        packages[pkg.name] = {
            version: pkg.installed_version,
            score: pkg.vibrancy_score,
            category,
            grade: categoryToGrade(category as VibrancyResult['category']),
        };
    }
    if (Object.keys(packages).length === 0) { return null; }
    return {
        timestamp,
        extensionVersion: 'legacy-report',
        packages,
    };
}

async function handleSchemaMismatch(
    workspaceRoot: string,
    raw: string,
    oldVersion: number,
): Promise<void> {
    console.warn(
        `[saropa-vibrancy] History schema mismatch (found ${oldVersion}, expected ${SCHEMA_VERSION}). Resetting history.`,
    );
    try {
        const backup = backupPath(workspaceRoot, oldVersion);
        await fs.writeFile(backup, raw, 'utf8');
    } catch {
        // Backup is best-effort; failure should not block scans.
    }
}

export async function readHistory(workspaceRoot: string): Promise<VibrancyHistory> {
    const filePath = historyPath(workspaceRoot);
    try {
        const raw = await fs.readFile(filePath, 'utf8');
        const parsed = JSON.parse(raw) as unknown;
        if (!isVibrancyHistory(parsed)) { return EMPTY_HISTORY; }
        if (parsed.schemaVersion !== SCHEMA_VERSION) {
            await handleSchemaMismatch(workspaceRoot, raw, parsed.schemaVersion);
            return EMPTY_HISTORY;
        }
        return parsed;
    } catch {
        return EMPTY_HISTORY;
    }
}

export async function appendSnapshot(
    workspaceRoot: string,
    results: readonly VibrancyResult[],
    extensionVersion: string,
): Promise<boolean> {
    const history = await readHistory(workspaceRoot);
    const next = buildSnapshot(results, extensionVersion);
    const latest = history.snapshots[history.snapshots.length - 1];
    if (latest && samePackages(latest.packages, next.packages)) {
        return false;
    }

    const snapshots = [...history.snapshots, next];
    while (snapshots.length > MAX_SNAPSHOTS) {
        snapshots.shift();
    }
    await writeHistoryAtomic(workspaceRoot, {
        schemaVersion: SCHEMA_VERSION,
        snapshots,
    });
    return true;
}

export async function backfillFromLegacyReports(workspaceRoot: string): Promise<number> {
    const history = await readHistory(workspaceRoot);
    // Backfill only into an empty history file to keep this a one-time migration.
    if (history.snapshots.length > 0) { return 0; }

    const jsonPaths = await listLegacyVibrancyJsonPaths(workspaceRoot);
    if (jsonPaths.length === 0) { return 0; }

    const imported: HistorySnapshot[] = [];
    for (const filePath of jsonPaths) {
        try {
            const raw = await fs.readFile(filePath, 'utf8');
            const parsed = JSON.parse(raw) as LegacyVibrancyReport;
            const snapshot = snapshotFromLegacyReport(parsed);
            if (!snapshot) { continue; }
            const last = imported[imported.length - 1];
            if (last && samePackages(last.packages, snapshot.packages)) {
                continue;
            }
            imported.push(snapshot);
        } catch {
            // Skip malformed legacy files and continue importing others.
        }
    }
    if (imported.length === 0) { return 0; }

    const capped = imported.slice(-MAX_SNAPSHOTS);
    await writeHistoryAtomic(workspaceRoot, {
        schemaVersion: SCHEMA_VERSION,
        snapshots: capped,
    });
    return capped.length;
}

export function getPackageTrend(
    history: VibrancyHistory,
    packageName: string,
): number[] {
    const scores: number[] = [];
    for (const snapshot of history.snapshots) {
        const pkg = snapshot.packages[packageName];
        if (pkg) { scores.push(pkg.score); }
    }
    return scores;
}

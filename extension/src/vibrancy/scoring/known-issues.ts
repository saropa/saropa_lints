import knownIssuesData from '../data/known_issues.json';
import { KnownIssue } from '../types';

/** Treat "N/A", empty, and whitespace-only strings as unset. */
function normalizeOptional(value: unknown): string | undefined {
    if (typeof value !== 'string') { return undefined; }
    const trimmed = value.trim();
    if (trimmed === '' || trimmed.toLowerCase() === 'n/a') { return undefined; }
    return trimmed;
}

function normalizeIssue(raw: Record<string, unknown>): KnownIssue {
    return {
        name: raw.name as string,
        status: raw.status as string,
        reason: raw.reason as string | undefined,
        as_of: raw.as_of as string | undefined,
        replacement: normalizeOptional(raw.replacement),
        replacementObsoleteFromVersion: typeof raw.replacementObsoleteFromVersion === 'number'
            ? `${raw.replacementObsoleteFromVersion}.0.0`
            : normalizeOptional(raw.replacementObsoleteFromVersion as string),
        appliesToMinVersion: normalizeOptional(raw.appliesToMinVersion as string),
        appliesToMaxVersion: normalizeOptional(raw.appliesToMaxVersion as string),
        migrationNotes: normalizeOptional(raw.migrationNotes),
        archiveSizeBytes: typeof raw.archiveSizeBytes === 'number'
            ? raw.archiveSizeBytes : undefined,
        archiveSizeMB: typeof raw.archiveSizeMB === 'number'
            ? raw.archiveSizeMB : undefined,
        license: normalizeOptional(raw.license),
        lastUpdated: normalizeOptional(raw.lastUpdated),
        pubPoints: typeof raw.pubPoints === 'number'
            ? raw.pubPoints : undefined,
        wasmReady: typeof raw.wasmReady === 'boolean'
            ? raw.wasmReady : undefined,
        verifiedPublisher: typeof raw.verifiedPublisher === 'boolean'
            ? raw.verifiedPublisher : undefined,
        platforms: Array.isArray(raw.platforms)
            ? raw.platforms.filter(
                (p: unknown): p is string => typeof p === 'string',
            )
            : undefined,
        overrideReason: normalizeOptional(raw.overrideReason),
    };
}

// Multiple entries can share a bare package name (version-scoped variants).
const issueMap = new Map<string, KnownIssue[]>();
const { issues } = knownIssuesData as { issues: Record<string, unknown>[] };
for (const entry of issues) {
    const issue = normalizeIssue(entry);
    const existing = issueMap.get(issue.name);
    if (existing) {
        existing.push(issue);
    } else {
        issueMap.set(issue.name, [issue]);
    }
}

/**
 * True when replacement is a pub package name (safe to use in "Replace with X" and in
 * pubspec edits). False for instructions or freeform text (e.g. "Update to v9+",
 * "Update to latest version", "Use Native Channels"). Consumers should use this to
 * choose message format (Replace with X vs Deprecated — X / Consider: X) and to
 * avoid offering a code action that would write non-package text into pubspec.yaml.
 */
export function isReplacementPackageName(replacement: string): boolean {
    return /^[a-z0-9_]+$/.test(replacement.trim());
}

/** Parse version into numeric segments (e.g. "9.0.0" -> [9,0,0], "10" -> [10]). */
function parseVersionSegments(version: string): number[] {
    const base = version.trim().replace(/[-+].*$/, '');
    return base.split('.').map(s => {
        const n = parseInt(s, 10);
        return Number.isNaN(n) ? 0 : n;
    });
}

/** True when version a >= b (segment-wise comparison). */
function versionGte(a: string, b: string): boolean {
    const pa = parseVersionSegments(a);
    const pb = parseVersionSegments(b);
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
        const va = pa[i] ?? 0;
        const vb = pb[i] ?? 0;
        if (va !== vb) { return va > vb; }
    }
    return true;
}

/**
 * Returns the replacement text to show to the user, or undefined if it should not be
 * shown. When replacementObsoleteFromVersion is set (e.g. "9.0.0"), returns undefined
 * when currentVersion >= that version so we never recommend "Update to v9+" when the
 * user is already on 9 or 10. Uses explicit version string from JSON; we parse both
 * versions for comparison.
 */
export function getReplacementDisplayText(
    replacement: string,
    currentVersion: string | undefined,
    replacementObsoleteFromVersion?: string,
): string | undefined {
    if (!replacementObsoleteFromVersion || !currentVersion) {
        return replacement;
    }
    if (versionGte(currentVersion, replacementObsoleteFromVersion)) {
        return undefined;
    }
    return replacement;
}

/**
 * True when currentVersion falls within the entry's version range.
 * Min is inclusive (>=), max is exclusive (<). Absent bounds = unbounded.
 */
function matchesVersionRange(
    entry: KnownIssue,
    currentVersion: string,
): boolean {
    const { appliesToMinVersion, appliesToMaxVersion } = entry;
    if (appliesToMinVersion && !versionGte(currentVersion, appliesToMinVersion)) {
        return false;
    }
    if (appliesToMaxVersion && versionGte(currentVersion, appliesToMaxVersion)) {
        return false;
    }
    return true;
}

/** True when the entry has no version bounds (applies to all versions). */
function isUnscoped(entry: KnownIssue): boolean {
    return !entry.appliesToMinVersion && !entry.appliesToMaxVersion;
}

/**
 * Look up a package in the bundled known-issues database.
 * When currentVersion is provided, returns the version-scoped entry whose
 * range matches, falling back to an unscoped entry. When no version is
 * provided, returns an unscoped entry if one exists.
 */
export function findKnownIssue(
    packageName: string,
    currentVersion?: string,
): KnownIssue | null {
    const entries = issueMap.get(packageName);
    if (!entries || entries.length === 0) { return null; }
    if (!currentVersion) {
        // No version context — prefer unscoped entry
        return entries.find(isUnscoped) ?? entries[0];
    }
    // Prefer a scoped entry that matches the version
    const scoped = entries.find(e => !isUnscoped(e) && matchesVersionRange(e, currentVersion));
    if (scoped) { return scoped; }
    // Fall back to an unscoped entry
    return entries.find(isUnscoped) ?? null;
}

/** Return all known issues grouped by package name. */
export function allKnownIssues(): ReadonlyMap<string, readonly KnownIssue[]> {
    return issueMap;
}

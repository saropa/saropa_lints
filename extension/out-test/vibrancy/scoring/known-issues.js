"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.isReplacementPackageName = isReplacementPackageName;
exports.getReplacementDisplayText = getReplacementDisplayText;
exports.findKnownIssue = findKnownIssue;
exports.allKnownIssues = allKnownIssues;
const known_issues_json_1 = __importDefault(require("../data/known_issues.json"));
/** Treat "N/A", empty, and whitespace-only strings as unset. */
function normalizeOptional(value) {
    if (typeof value !== 'string') {
        return undefined;
    }
    const trimmed = value.trim();
    if (trimmed === '' || trimmed.toLowerCase() === 'n/a') {
        return undefined;
    }
    return trimmed;
}
function normalizeIssue(raw) {
    return {
        name: raw.name,
        status: raw.status,
        reason: raw.reason,
        as_of: raw.as_of,
        replacement: normalizeOptional(raw.replacement),
        replacementObsoleteFromVersion: typeof raw.replacementObsoleteFromVersion === 'number'
            ? `${raw.replacementObsoleteFromVersion}.0.0`
            : normalizeOptional(raw.replacementObsoleteFromVersion),
        appliesToMinVersion: normalizeOptional(raw.appliesToMinVersion),
        appliesToMaxVersion: normalizeOptional(raw.appliesToMaxVersion),
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
            ? raw.platforms.filter((p) => typeof p === 'string')
            : undefined,
        overrideReason: normalizeOptional(raw.overrideReason),
    };
}
// Multiple entries can share a bare package name (version-scoped variants).
const issueMap = new Map();
const { issues } = known_issues_json_1.default;
for (const entry of issues) {
    const issue = normalizeIssue(entry);
    const existing = issueMap.get(issue.name);
    if (existing) {
        existing.push(issue);
    }
    else {
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
function isReplacementPackageName(replacement) {
    return /^[a-z0-9_]+$/.test(replacement.trim());
}
/** Parse version into numeric segments (e.g. "9.0.0" -> [9,0,0], "10" -> [10]). */
function parseVersionSegments(version) {
    const base = version.trim().replace(/[-+].*$/, '');
    return base.split('.').map(s => {
        const n = parseInt(s, 10);
        return Number.isNaN(n) ? 0 : n;
    });
}
/** True when version a >= b (segment-wise comparison). */
function versionGte(a, b) {
    const pa = parseVersionSegments(a);
    const pb = parseVersionSegments(b);
    const len = Math.max(pa.length, pb.length);
    for (let i = 0; i < len; i++) {
        const va = pa[i] ?? 0;
        const vb = pb[i] ?? 0;
        if (va !== vb) {
            return va > vb;
        }
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
function getReplacementDisplayText(replacement, currentVersion, replacementObsoleteFromVersion) {
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
function matchesVersionRange(entry, currentVersion) {
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
function isUnscoped(entry) {
    return !entry.appliesToMinVersion && !entry.appliesToMaxVersion;
}
/**
 * Look up a package in the bundled known-issues database.
 * When currentVersion is provided, returns the version-scoped entry whose
 * range matches, falling back to an unscoped entry. When no version is
 * provided, returns an unscoped entry if one exists.
 */
function findKnownIssue(packageName, currentVersion) {
    const entries = issueMap.get(packageName);
    if (!entries || entries.length === 0) {
        return null;
    }
    if (!currentVersion) {
        // No version context — prefer unscoped entry
        return entries.find(isUnscoped) ?? entries[0];
    }
    // Prefer a scoped entry that matches the version
    const scoped = entries.find(e => !isUnscoped(e) && matchesVersionRange(e, currentVersion));
    if (scoped) {
        return scoped;
    }
    // Fall back to an unscoped entry
    return entries.find(isUnscoped) ?? null;
}
/** Return all known issues grouped by package name. */
function allKnownIssues() {
    return issueMap;
}
//# sourceMappingURL=known-issues.js.map
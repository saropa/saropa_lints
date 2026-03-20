/** A reverse-dependency edge: "dependentPackage depends on the target". */
export interface DepEdge {
    readonly dependentPackage: string;
}

/** Cache entry with TTL. */
export interface CacheEntry<T> {
    readonly data: T;
    readonly timestamp: number;
}

/** Position of a package name in pubspec.yaml. */
export interface PackageRange {
    readonly line: number;
    readonly startChar: number;
    readonly endChar: number;
}

/** A version group within a family split. */
export interface FamilyVersionGroup {
    readonly majorVersion: number;
    readonly packages: readonly string[];
}

/** Detected version split within a package family. */
export interface FamilySplit {
    readonly familyId: string;
    readonly familyLabel: string;
    readonly versionGroups: readonly FamilyVersionGroup[];
    readonly suggestion: string;
}

/** Notification for a newly detected package version. */
export interface NewVersionNotification {
    readonly name: string;
    readonly currentVersion: string;
    readonly newVersion: string;
    readonly updateType: 'patch' | 'minor' | 'major';
    /** If upgrade is blocked, the name of the blocking package. */
    readonly blockedBy: string | null;
}

/** Watch filter mode for freshness watcher. */
export type WatchFilterMode = 'all' | 'unhealthy' | 'custom';

/** A shared transitive dependency used by multiple direct deps. */
export interface SharedDep {
    readonly name: string;
    readonly usedBy: readonly string[];
}

/** Budget configuration for dependency health policy. */
export interface BudgetConfig {
    readonly maxDependencies: number | null;
    readonly maxTotalSizeMB: number | null;
    readonly minAverageVibrancy: number | null;
    readonly maxStale: number | null;
    readonly maxEndOfLife: number | null;
    readonly maxLegacyLocked: number | null;
    readonly maxUnused: number | null;
}

/** Status classification for a budget dimension. */
export type BudgetStatus = 'under' | 'warning' | 'exceeded' | 'unconfigured';

/** Result of checking one budget dimension. */
export interface BudgetResult {
    readonly dimension: string;
    readonly actual: number;
    readonly limit: number | null;
    readonly percentage: number | null;
    readonly status: BudgetStatus;
    readonly details: string;
}

/** Summary of the full dependency graph. */
export interface DepGraphSummary {
    readonly directCount: number;
    readonly transitiveCount: number;
    readonly totalUnique: number;
    readonly overrideCount: number;
    readonly sharedDeps: readonly SharedDep[];
}

/** A single entry from the dependency_overrides section. */
export interface OverrideEntry {
    readonly name: string;
    readonly version: string;
    readonly line: number;
    readonly isPathDep: boolean;
    readonly isGitDep: boolean;
}

/** Analysis result for a single override. */
export interface OverrideAnalysis {
    readonly entry: OverrideEntry;
    readonly status: 'active' | 'stale';
    readonly blocker: string | null;
    readonly addedDate: Date | null;
    readonly ageDays: number | null;
}

/** Problem types that can affect a package. */
export type ProblemType =
    | 'unhealthy'
    | 'stale-override'
    | 'family-conflict'
    | 'risky-transitive'
    | 'blocked-upgrade'
    | 'unused'
    | 'license-risk';

/** A problem affecting a package. */
export interface Problem {
    readonly type: ProblemType;
    readonly severity: 'high' | 'medium' | 'low';
    readonly message: string;
    readonly relatedPackage?: string;
}

/** Suggested action types. */
export type ActionType =
    | 'remove'
    | 'upgrade-blocker'
    | 'upgrade-family'
    | 'remove-override'
    | 'replace'
    | 'upgrade'
    | 'none';

/** Vibrancy category for display; must match VibrancyCategory in types. */
export type PackageInsightCategory = 'vibrant' | 'quiet' | 'legacy-locked' | 'stale' | 'end-of-life';

/** Consolidated insight for a package. */
export interface PackageInsight {
    readonly name: string;
    /** Internal priority for sorting (higher = address first). Not shown in UI. */
    readonly combinedRiskScore: number;
    /** Vibrancy score 0–100; used for detail view, CodeLens, and to derive A–F grade in Action Items. */
    readonly vibrancyScore: number;
    /** Category (e.g. stale, end-of-life); used for A–F grade and labels. */
    readonly category: PackageInsightCategory;
    readonly problems: readonly Problem[];
    readonly suggestedAction: string | null;
    readonly actionType: ActionType;
    readonly unlocksIfFixed: readonly string[];
}

/** A PR or issue from GitHub relevant to the version gap. */
export interface VersionGapItem {
    readonly number: number;
    readonly title: string;
    readonly url: string;
    readonly type: 'pr' | 'issue';
    readonly state: 'merged' | 'closed' | 'open';
    readonly author: string;
    readonly createdAt: string;
    readonly closedAt: string | null;
    readonly labels: readonly string[];
}

/** Result of fetching PRs/issues between two versions. */
export interface VersionGapResult {
    readonly packageName: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly owner: string;
    readonly repo: string;
    readonly items: readonly VersionGapItem[];
    readonly truncated: boolean;
    /** ISO date of the current-version release tag. */
    readonly fromDate: string | null;
    /** ISO date of the latest-version release tag. */
    readonly toDate: string | null;
}

/** Review status for a single version-gap item. */
export type ReviewStatus = 'unreviewed' | 'reviewed' | 'applicable' | 'not-applicable';

/** Persisted review state for a single version-gap item. */
export interface ReviewEntry {
    readonly packageName: string;
    readonly itemNumber: number;
    readonly status: ReviewStatus;
    readonly notes: string;
    /** ISO timestamp of when the review was last updated. */
    readonly updatedAt: string;
}

/** CI platform targets for workflow generation. */
export type CiPlatform = 'github-actions' | 'gitlab-ci' | 'shell-script';

/** Thresholds for CI vibrancy checks. */
export interface CiThresholds {
    readonly maxStale: number;
    readonly maxEndOfLife: number;
    readonly maxLegacyLocked: number;
    readonly minAverageVibrancy: number;
    readonly failOnVulnerability: boolean;
}

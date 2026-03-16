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

/** Consolidated insight for a package. */
export interface PackageInsight {
    readonly name: string;
    readonly combinedRiskScore: number;
    readonly problems: readonly Problem[];
    readonly suggestedAction: string | null;
    readonly actionType: ActionType;
    readonly unlocksIfFixed: readonly string[];
}

/** CI platform targets for workflow generation. */
export type CiPlatform = 'github-actions' | 'gitlab-ci' | 'shell-script';

/** Thresholds for CI vibrancy checks. */
export interface CiThresholds {
    readonly maxEndOfLife: number;
    readonly maxLegacyLocked: number;
    readonly minAverageVibrancy: number;
    readonly failOnVulnerability: boolean;
}

/** Status categories for package vibrancy. */
export type VibrancyCategory = 'vibrant' | 'quiet' | 'legacy-locked' | 'end-of-life';

/** Which pubspec section a dependency belongs to. */
export type DependencySection = 'dependencies' | 'dev_dependencies' | 'transitive';

/**
 * True if a dependency in this section may be suggested for removal when unused.
 * Dev dependencies (build_runner, linters, codegen) are used by tooling, not imports.
 */
export function isUnusedRemovalEligibleSection(section: DependencySection): boolean {
    return section !== 'dev_dependencies';
}

/** A dependency extracted from pubspec.lock. */
export interface PackageDependency {
    readonly name: string;
    /** Resolved version from pubspec.lock (e.g. "3.0.7"). */
    readonly version: string;
    /** Version constraint from pubspec.yaml (e.g. "^3.0.3"). */
    readonly constraint: string;
    readonly source: string;
    readonly isDirect: boolean;
    /** Which pubspec section this dependency belongs to. */
    readonly section: DependencySection;
}

/** Pub.dev metadata for a package. */
export interface PubDevPackageInfo {
    readonly name: string;
    readonly latestVersion: string;
    readonly publishedDate: string;
    readonly repositoryUrl: string | null;
    readonly isDiscontinued: boolean;
    readonly isUnlisted: boolean;
    readonly pubPoints: number;
    readonly publisher: string | null;
    readonly license: string | null;
    readonly description: string | null;
    readonly topics: readonly string[];
}

/** A GitHub issue flagged as high-signal for compatibility/deprecation. */
export interface FlaggedIssue {
    readonly number: number;
    readonly title: string;
    readonly url: string;
    readonly matchedSignals: readonly string[];
    readonly commentCount: number;
}

/** GitHub repository metrics. */
export interface GitHubMetrics {
    readonly stars: number;
    readonly openIssues: number;
    readonly closedIssuesLast90d: number;
    readonly mergedPrsLast90d: number;
    readonly avgCommentsPerIssue: number;
    readonly daysSinceLastUpdate: number;
    readonly daysSinceLastClose: number;
    readonly flaggedIssues: readonly FlaggedIssue[];
    /** SPDX license identifier from the GitHub repository, if available. */
    readonly license: string | null;
}

/** Known issue entry from bundled JSON. */
export interface KnownIssue {
    readonly name: string;
    readonly status: string;
    readonly reason?: string;
    readonly as_of?: string;
    readonly replacement?: string;
    /** When set, do not show replacement message when user's version >= this (e.g. "9.0.0" for "Update to v9+"). Parsed and compared as semver. */
    readonly replacementObsoleteFromVersion?: string;
    /** Minimum version this issue applies to (semver, inclusive). When absent, no lower bound. */
    readonly appliesToMinVersion?: string;
    /** Maximum version this issue applies to (semver, exclusive). When absent, no upper bound. */
    readonly appliesToMaxVersion?: string;
    readonly migrationNotes?: string;
    readonly archiveSizeBytes?: number;
    readonly archiveSizeMB?: number;
    readonly license?: string;
    readonly lastUpdated?: string;
    readonly pubPoints?: number;
    readonly wasmReady?: boolean;
    readonly verifiedPublisher?: boolean;
    readonly platforms?: readonly string[];
    /** Why a dependency_overrides pin is needed despite no version conflict. */
    readonly overrideReason?: string;
}

/** Live metrics from pub.dev /metrics endpoint. Null wasmReady = API failed. */
export interface PubDevMetrics {
    readonly pubPoints: number;
    readonly platforms: readonly string[];
    readonly wasmReady: boolean | null;
}

/** Granularity of available update. */
export type UpdateStatus = 'up-to-date' | 'patch' | 'minor' | 'major' | 'unknown';

/** A single version entry from CHANGELOG.md. */
export interface ChangelogEntry {
    readonly version: string;
    readonly date?: string;
    readonly body: string;
}

/** Parsed changelog entries between current and latest versions. */
export interface ChangelogInfo {
    readonly entries: readonly ChangelogEntry[];
    readonly truncated: boolean;
    readonly unavailableReason?: string;
}

/** Update information for a package. */
export interface UpdateInfo {
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly updateStatus: UpdateStatus;
    readonly changelog: ChangelogInfo | null;
}

/** Ecosystem drift relative to Flutter stable releases. */
export interface DriftInfo {
    readonly releasesBehind: number;
    readonly driftScore: number;
    readonly label: 'current' | 'recent' | 'drifting' | 'stale' | 'abandoned';
    readonly latestFlutterVersion: string;
}

/** Transitive dependency info for one direct dependency. */
export interface TransitiveInfo {
    readonly directDep: string;
    readonly transitiveCount: number;
    readonly flaggedCount: number;
    readonly transitives: readonly string[];
    readonly sharedDeps: readonly string[];
}

/** A suggested alternative package. */
export interface AlternativeSuggestion {
    readonly name: string;
    readonly source: 'curated' | 'discovery';
    readonly score: number | null;
    readonly likes: number;
}

/** Severity tier for a security vulnerability. */
export type VulnSeverity = 'critical' | 'high' | 'medium' | 'low';

/** A security vulnerability affecting a package. */
export interface Vulnerability {
    readonly id: string;
    readonly summary: string;
    readonly severity: VulnSeverity;
    readonly cvssScore: number | null;
    readonly fixedVersion: string | null;
    readonly url: string;
}

/** How a package's upgrade is blocked or available. */
export type UpgradeBlockStatus =
    | 'up-to-date'
    | 'upgradable'
    | 'blocked'
    | 'constrained';

/** Information about what blocks a package upgrade. */
export interface BlockerInfo {
    readonly blockedPackage: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly blockerPackage: string;
    readonly blockerVibrancyScore: number | null;
    readonly blockerCategory: VibrancyCategory | null;
}

/** Computed vibrancy result for one package. */
export interface VibrancyResult {
    readonly package: PackageDependency;
    readonly pubDev: PubDevPackageInfo | null;
    readonly github: GitHubMetrics | null;
    readonly knownIssue: KnownIssue | null;
    readonly score: number;
    readonly category: VibrancyCategory;
    readonly resolutionVelocity: number;
    readonly engagementLevel: number;
    readonly popularity: number;
    readonly publisherTrust: number;
    readonly updateInfo: UpdateInfo | null;
    readonly license: string | null;
    readonly drift: DriftInfo | null;
    readonly archiveSizeBytes: number | null;
    readonly bloatRating: number | null;
    readonly isUnused: boolean;
    readonly platforms: readonly string[] | null;
    readonly verifiedPublisher: boolean;
    readonly wasmReady: boolean | null;
    readonly blocker: BlockerInfo | null;
    readonly upgradeBlockStatus: UpgradeBlockStatus;
    readonly transitiveInfo: TransitiveInfo | null;
    readonly alternatives: readonly AlternativeSuggestion[];
    /** Latest prerelease version if newer than stable (e.g., '2.0.0-dev.1'). */
    readonly latestPrerelease: string | null;
    /** Prerelease tag extracted from version (e.g., 'dev', 'beta', 'rc'). */
    readonly prereleaseTag: string | null;
    /** Security vulnerabilities affecting this package version. */
    readonly vulnerabilities: readonly Vulnerability[];
}

/** A single package entry from `dart pub outdated --json`. */
export interface PubOutdatedEntry {
    readonly package: string;
    readonly current: string | null;
    readonly upgradable: string | null;
    readonly resolvable: string | null;
    readonly latest: string | null;
}

/** A single step in an upgrade plan. */
export interface UpgradeStep {
    readonly packageName: string;
    readonly currentVersion: string;
    readonly targetVersion: string;
    readonly updateType: UpdateStatus;
    readonly familyId: string | null;
    readonly order: number;
    /** Override that may become stale after this upgrade. */
    readonly mayResolveOverride: string | null;
}

/** Outcome of executing one upgrade step. */
export type StepOutcome =
    | 'success'
    | 'pub-get-failed'
    | 'test-failed'
    | 'skipped';

/** Result of executing one upgrade step. */
export interface UpgradeStepResult {
    readonly step: UpgradeStep;
    readonly outcome: StepOutcome;
    readonly output: string;
}

/** Summary report of an upgrade execution. */
export interface UpgradeReport {
    readonly steps: readonly UpgradeStepResult[];
    readonly completedCount: number;
    readonly failedAt: string | null;
}

/** Data for package comparison view. */
export interface ComparisonData {
    readonly name: string;
    readonly vibrancyScore: number | null;
    readonly category: VibrancyCategory | null;
    readonly latestVersion: string;
    readonly publishedDate: string | null;
    readonly publisher: string | null;
    readonly pubPoints: number;
    readonly stars: number | null;
    readonly openIssues: number | null;
    readonly archiveSizeBytes: number | null;
    readonly bloatRating: number | null;
    readonly license: string | null;
    readonly platforms: readonly string[];
    readonly inProject: boolean;
}

/** Dimension-wise winner info for package comparison. */
export interface DimensionWinner {
    readonly dimension: string;
    readonly winnerName: string;
    readonly value: string;
    readonly allValues: readonly { name: string; value: string; isWinner: boolean }[];
}

/** Ranked comparison result. */
export interface RankedComparison {
    readonly packages: readonly ComparisonData[];
    readonly winners: readonly DimensionWinner[];
    readonly recommendation: string;
}

/* Re-export all extended types so existing imports from '../types' continue working. */
export * from './types-extended';

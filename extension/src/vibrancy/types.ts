/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Vibrancy UI experiment: scoring, providers, and webview assets.
 */

import type { VersionGapResult } from './types-extended';
import type { ReplacementComplexity } from './services/package-code-analyzer';
import type { PackageUsage } from './services/import-scanner';
import type { PackageOpportunities } from './services/changelog-opportunities';

/** Status categories for package vibrancy. */
export type VibrancyCategory = 'vibrant' | 'stable' | 'outdated' | 'abandoned' | 'end-of-life';

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
    /** ISO date when the latest version was published. */
    readonly publishedDate: string;
    /** ISO date when the first version was published (package creation). */
    readonly createdDate?: string;
    readonly repositoryUrl: string | null;
    readonly isDiscontinued: boolean;
    readonly isUnlisted: boolean;
    readonly pubPoints: number;
    readonly publisher: string | null;
    readonly license: string | null;
    readonly description: string | null;
    readonly topics: readonly string[];
    /** Direct dependency names from the package's pubspec (keys only, sorted). */
    readonly dependencies: readonly string[];
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
    /** Combined open issues + PRs from GitHub API. Prefer trueOpenIssues when available. */
    readonly openIssues: number;
    /** Open issues only (excludes PRs). Undefined when open-PRs fetch failed. */
    readonly trueOpenIssues?: number;
    /** Number of open pull requests. Undefined when the fetch failed. */
    readonly openPullRequests?: number;
    readonly closedIssuesLast90d: number;
    readonly mergedPrsLast90d: number;
    readonly avgCommentsPerIssue: number;
    readonly daysSinceLastUpdate: number;
    readonly daysSinceLastClose: number;
    /** Days since last commit (from pushed_at). Undefined when not available. */
    readonly daysSinceLastCommit?: number;
    /** Whether the GitHub repository is archived (read-only / abandoned). */
    readonly isArchived?: boolean;
    /** Canonical GitHub URL (html_url from the API). */
    readonly repoUrl?: string;
    readonly flaggedIssues: readonly FlaggedIssue[];
    /** SPDX license identifier from the GitHub repository, if available. */
    readonly license: string | null;
}

/**
 * Bytes per top-level folder in a package tarball.
 *
 * Drives the hover "on disk" breakdown so developers can see when a tarball's
 * mass lives outside `lib/` (e.g. `example/` demos, `test/` suites). `other`
 * collects everything not in the named buckets (root files, `android/`,
 * `ios/`, `web/`, etc.) so totals stay reconciled with `archiveSizeBytes`.
 */
export interface FolderBreakdown {
    readonly lib: number;
    readonly example: number;
    readonly test: number;
    readonly tool: number;
    readonly doc: number;
    readonly other: number;
}

/**
 * Presence of maintainer-quality folders inside the package tarball.
 *
 * These are positive health signals — a package that ships a runnable demo,
 * a test suite, maintainer tooling, or extended docs is generally healthier
 * than one that strips them. Each flag feeds an independent positive
 * component on the vibrancy score (see calcMaintainerQualityBonus).
 *
 * The earlier model conflated tarball size with bloat, which inverted the
 * sign on all four signals (packages that shipped demos/tests scored worse).
 * Surfacing them as explicit positive flags fixes that inversion.
 */
export interface MaintainerQualityFlags {
    /** `example/` contains at least one `.dart` file (runnable demo / onboarding). */
    readonly hasExample: boolean;
    /** `test/` contains at least one `_test.dart` file (regression coverage). */
    readonly hasTests: boolean;
    /** `tool/` contains at least one `.dart` or shell script (maintainer automation). */
    readonly hasTools: boolean;
    /** `doc/` contains at least one `.md` beyond the auto-`api/` dump (extended docs). */
    readonly hasDocs: boolean;
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

/** Live metrics from pub.dev /metrics and /score endpoints. Null wasmReady = API failed. */
export interface PubDevMetrics {
    readonly pubPoints: number;
    /** Number of likes from pub.dev. Null when score API failed. */
    readonly likes: number | null;
    /**
     * Downloads on pub.dev in the trailing 30 days (from score API's
     * `downloadCount30Days` field). Null when the score API failed or did
     * not include the field (e.g. older registry mirrors).
     */
    readonly downloadCount30Days: number | null;
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

/** Transitive dependency info for one direct dependency. */
export interface TransitiveInfo {
    readonly directDep: string;
    readonly transitiveCount: number;
    readonly flaggedCount: number;
    readonly transitives: readonly string[];
    readonly sharedDeps: readonly string[];
    /**
     * Sum of archive sizes (bytes) of transitives used ONLY by this dep.
     * Removing this direct dep would eliminate this many bytes.
     * Null when no size data was available for any transitive; undefined
     * in older fixtures and tests that predate this field.
     */
    readonly uniqueTransitiveSizeBytes?: number | null;
    /**
     * Sum of archive sizes (bytes) of transitives this dep shares with at least
     * one other direct dep. Removing this dep would NOT eliminate these bytes.
     * Null when no size data was available for any shared transitive;
     * undefined in older fixtures and tests that predate this field.
     */
    readonly sharedTransitiveSizeBytes?: number | null;
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

/**
 * A documented intent to NOT upgrade a dependency, parsed from its pubspec
 * comment. Distinguishes an intentional hold (build break, do-not-use, frozen)
 * from neglect, so the scanner stops nagging to bump a deliberately-pinned dep.
 */
export interface PinIntent {
    /** The extracted reason line (e.g. "DO NOT BUMP home_widget to 0.9.2"). */
    readonly reason: string;
    /** Coarse classification driving wording and severity. */
    readonly kind: 'do-not-upgrade' | 'do-not-use';
}

/** One sibling repo's constraint on a package that diverges from this project's. */
export interface SiblingConstraint {
    /** Sibling repo label (its directory name). */
    readonly repo: string;
    /** The constraint that sibling declares for the package (e.g. "^13.12.7"). */
    readonly constraint: string;
}

/**
 * Cross-project version drift: the same package pinned at a different major in a
 * configured sibling repo. Surfaces an implicit, uncommented upgrade blocker —
 * a lagging consumer (e.g. saropa_lints `^9.7.0` here vs `^13.12.7` elsewhere)
 * whose newer major may need a floor this project's other pins forbid.
 */
export interface CrossProjectDrift {
    /** This project's constraint for the package. */
    readonly ownConstraint: string;
    /** Sibling repos whose major for this package differs from ours. */
    readonly siblings: readonly SiblingConstraint[];
    /** True when at least one sibling is on a higher major (this project lags). */
    readonly behind: boolean;
}

/** Why a `constrained` upgrade is capped by the user's own pubspec constraint. */
export interface ConstrainedReason {
    /** The constraint declared in the workspace pubspec (e.g. "^1.9.0"). */
    readonly constraint: string;
    /** The version pub could resolve to if the constraint were relaxed. */
    readonly resolvable: string;
    /** The latest published version. */
    readonly latest: string;
}

/** Information about what blocks a package upgrade. */
export interface BlockerInfo {
    readonly blockedPackage: string;
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly blockerPackage: string;
    readonly blockerVibrancyScore: number | null;
    readonly blockerCategory: VibrancyCategory | null;
    /**
     * Diamond / shared-transitive-dependency conflict detail.
     *
     * Set only when the block is NOT a direct reverse-dependency chain but a
     * sibling conflict over a shared transitive dependency: `blockedPackage`
     * and `blockerPackage` both depend on `sharedDependency`, and
     * `blockerPackage` caps it to a range (`blockerConstraint`) that excludes
     * the version `blockedPackage` needs at its latest. This is the class the
     * reverse-dependency walk cannot see — e.g. `dart_style` held back because
     * `saropa_lints` caps `analyzer <13`. Undefined for ordinary blockers.
     */
    readonly sharedDependency?: string | null;
    /** Highest version of the shared dep pub can resolve under current constraints. */
    readonly sharedDependencyResolvable?: string | null;
    /** Latest published version of the shared dep. */
    readonly sharedDependencyLatest?: string | null;
    /** The constraint `blockerPackage` places on the shared dep (e.g. ">=9.0.0 <13.0.0"); empty when SDK-inferred. */
    readonly blockerConstraint?: string | null;
    /**
     * True when `blockerPackage` is a Flutter/Dart SDK package whose pin on the
     * shared dep is opaque (inferred, not read). Drives the display wording —
     * "pinned by the Flutter SDK" rather than "caps <range>" — because there is
     * no readable constraint string to show.
     */
    readonly blockerIsSdkPin?: boolean;
    /**
     * Dependency path from a user-actionable direct dep down to `blockerPackage`
     * (`[directDep, …, blockerPackage]`), set only when the constrainer is a
     * deep transitive dep reached through 2+ hops. Lets the UI point at a line
     * the user can edit — e.g. `dart_style → build_runner → analyzer` — instead
     * of naming a constrainer absent from pubspec.yaml. Undefined/length-1 when
     * the constrainer is itself direct.
     */
    readonly blockerChain?: readonly string[] | null;
}

/** README content parsed for display: logo and inline images. */
export interface ReadmeData {
    /** First non-badge image before the first ## heading (likely the project logo). */
    readonly logoUrl: string | null;
    /** All non-badge image URLs found in the README, deduplicated, max 5. */
    readonly imageUrls: readonly string[];
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
    readonly archiveSizeBytes: number | null;
    /**
     * Bytes the package contributes to a compiled Flutter app — `lib/**` plus
     * assets declared in the package's own `pubspec.yaml` under
     * `flutter.assets:`. Excludes `example/`, `test/`, `tool/`, `doc/`, and
     * other tarball-only folders that never reach the APK/IPA/web bundle.
     *
     * This is the field that should drive bloat ratings, per-app size budgets,
     * and "is this package costly to ship" decisions. `archiveSizeBytes`
     * (gzipped tarball) is kept for the hover "on disk" line but no longer
     * drives scoring — it over-reports for packages that ship demos or
     * fixture media. Null when the tarball analysis could not run (offline,
     * fetch error, or tar parse failure).
     */
    readonly codeSizeBytes: number | null;
    /**
     * Per-top-level-folder byte breakdown of the package tarball. Drives the
     * hover "on disk" detail line so developers can see when a package's
     * tarball mass lives outside `lib/` (a 21 MB tarball that is 99%
     * `example/` is healthy; a 21 MB tarball that is 99% `lib/` is bloat).
     * Null when the tarball analysis could not run.
     */
    readonly folderBreakdown: FolderBreakdown | null;
    /**
     * Maintainer-quality presence flags derived from the package tarball.
     * Each true flag earns an independent positive component on the vibrancy
     * score via calcMaintainerQualityBonus. Null when the tarball analysis
     * could not run, in which case no bonus is awarded (rather than a
     * silently-zero penalty).
     */
    readonly maintainerQuality: MaintainerQualityFlags | null;
    /**
     * Vibrancy score component from `maintainerQuality` flags (0–10). Stored
     * separately from the score breakdown components (resolutionVelocity,
     * engagement, popularity) because it is a derived bonus, not a weighted
     * input. Surfaced in the hover so developers see why the score moved.
     */
    readonly maintainerQualityBonus: number;
    readonly bloatRating: number | null;
    readonly isUnused: boolean;
    /** Files that import this package (active + commented-out). Empty array if unused. */
    readonly fileUsages: readonly PackageUsage[];
    /**
     * Adoptable features mined from the package's FULL changelog history (not
     * just the upgrade delta), so up-to-date packages with unadopted features
     * still surface. Null when no changelog or nothing adoptable. Optional for
     * source compatibility with result literals that predate the field.
     */
    readonly opportunities?: PackageOpportunities | null;
    /**
     * API names from `opportunities` that do NOT appear anywhere in project
     * source — the genuinely unused features. Computed in the post-scan pass
     * where both opportunities and the project symbol scan are available.
     */
    readonly unadoptedApiNames?: readonly string[];
    /**
     * Relevance score (0–100) ranking this package as an adoption needle:
     * unadopted-feature count weighted by how heavily the project imports the
     * package. Drives the dashboard "Upgrade Opportunities" sort. 0 / absent
     * when nothing to adopt.
     */
    readonly opportunityScore?: number;
    readonly platforms: readonly string[] | null;
    readonly verifiedPublisher: boolean;
    readonly wasmReady: boolean | null;
    readonly blocker: BlockerInfo | null;
    readonly upgradeBlockStatus: UpgradeBlockStatus;
    /**
     * For `constrained` rows: the user's OWN pubspec constraint that caps the
     * upgrade, plus the version pub could otherwise resolve to. A `constrained`
     * status is purely arithmetic (upgradable < resolvable) and previously
     * surfaced no reason; this names the line the user must edit. Null for any
     * other status.
     */
    readonly constrainedReason?: ConstrainedReason | null;
    /**
     * Documented do-not-upgrade / do-not-use intent parsed from the pubspec
     * comment, or null when the pin (if any) is undocumented. Lets the UI mark
     * a deliberate hold instead of reporting it as a missed upgrade.
     */
    readonly pinIntent?: PinIntent | null;
    /**
     * Cross-project version drift vs configured sibling repos, or null when no
     * sibling diverges (or none configured). Surfaces a lagging consumer that
     * pub-outdated alone cannot see.
     */
    readonly crossProjectDrift?: CrossProjectDrift | null;
    readonly transitiveInfo: TransitiveInfo | null;
    readonly alternatives: readonly AlternativeSuggestion[];
    /** Latest prerelease version if newer than stable (e.g., '2.0.0-dev.1'). */
    readonly latestPrerelease: string | null;
    /** Prerelease tag extracted from version (e.g., 'dev', 'beta', 'rc'). */
    readonly prereleaseTag: string | null;
    /** Security vulnerabilities affecting this package version. */
    readonly vulnerabilities: readonly Vulnerability[];
    /** ISO date when the installed version was published. */
    readonly installedVersionDate?: string | null;
    /** PRs/issues between current and latest versions. Fetched on demand. */
    readonly versionGap: VersionGapResult | null;
    /** For overridden packages: PRs/issues from override version to latest. */
    readonly overrideGap: VersionGapResult | null;
    /** Replacement complexity based on local source analysis. Null when not yet analyzed. */
    readonly replacementComplexity: ReplacementComplexity | null;
    /** Number of likes on pub.dev. Null until fetched. */
    readonly likes: number | null;
    /**
     * Downloads on pub.dev in the trailing 30 days. Null when the score API
     * failed or did not include the field. A strong trust signal because
     * unlike stars (which count the whole repo) it is tied to this specific
     * package.
     */
    readonly downloadCount30Days: number | null;
    /** Number of published packages on pub.dev that depend on this package. Null when not yet fetched or fetch failed. */
    readonly reverseDependencyCount: number | null;
    /** README logo and images. Null until lazy-fetched when detail panel opens. */
    readonly readme: ReadmeData | null;
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
    /** Code size (lib + declared assets). Null when tarball analysis is
        unavailable; ranking falls back to archiveSizeBytes in that case. */
    readonly codeSizeBytes: number | null;
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
export type { ReplacementComplexity, ReplacementLevel, PackageCodeMetrics } from './services/package-code-analyzer';
export type { PackageUsage, PackageUsageMap } from './services/import-scanner';
export { activeFileUsages, hasActiveReExport } from './services/import-scanner';

import { VibrancyCategory } from '../types';

/** Severity levels for problems. */
export type ProblemSeverity = 'high' | 'medium' | 'low';

/** Base interface for all problem types. */
interface BaseProblem {
    readonly id: string;
    readonly package: string;
    readonly severity: ProblemSeverity;
    readonly line: number;
}

/** Package is unhealthy (EOL or legacy-locked). */
export interface UnhealthyPackageProblem extends BaseProblem {
    readonly type: 'unhealthy';
    readonly score: number;
    readonly category: VibrancyCategory;
}

/** Override is stale and can be removed. */
export interface StaleOverrideProblem extends BaseProblem {
    readonly type: 'stale-override';
    readonly overrideName: string;
    readonly ageDays: number | null;
}

/** Family packages on different major versions. */
export interface FamilyConflictProblem extends BaseProblem {
    readonly type: 'family-conflict';
    readonly familyId: string;
    readonly familyLabel: string;
    readonly currentMajor: number;
    readonly conflictingPackages: readonly string[];
}

/** Direct dependency has risky transitives. */
export interface RiskyTransitiveProblem extends BaseProblem {
    readonly type: 'risky-transitive';
    readonly flaggedCount: number;
    readonly flaggedTransitives: readonly string[];
}

/** Package upgrade is blocked by another package. */
export interface BlockedUpgradeProblem extends BaseProblem {
    readonly type: 'blocked-upgrade';
    readonly currentVersion: string;
    readonly latestVersion: string;
    readonly blockerPackage: string;
    readonly blockerScore: number | null;
}

/** Package appears unused (no imports found). */
export interface UnusedProblem extends BaseProblem {
    readonly type: 'unused';
}

/** Package has a risky or incompatible license. */
export interface LicenseRiskProblem extends BaseProblem {
    readonly type: 'license-risk';
    readonly license: string;
    readonly riskLevel: 'copyleft' | 'restrictive' | 'unknown';
}

/** Package has known security vulnerabilities. */
export interface VulnerabilityProblem extends BaseProblem {
    readonly type: 'vulnerability';
    readonly vulnId: string;
    readonly vulnSeverity: 'critical' | 'high' | 'medium' | 'low';
    readonly summary: string;
    readonly fixedVersion: string | null;
}

/** Union of all problem types. */
export type Problem =
    | UnhealthyPackageProblem
    | StaleOverrideProblem
    | FamilyConflictProblem
    | RiskyTransitiveProblem
    | BlockedUpgradeProblem
    | UnusedProblem
    | LicenseRiskProblem
    | VulnerabilityProblem;

/** Type discriminator for problems. */
export type ProblemType = Problem['type'];

/** Link between two problems (cause → effect). */
export interface ProblemLink {
    readonly causeId: string;
    readonly effectId: string;
    readonly relationship: 'blocks' | 'causes' | 'related';
}

/** Generate a unique ID for a problem. */
export function generateProblemId(pkg: string, type: ProblemType, suffix?: string): string {
    const base = `${pkg}:${type}`;
    return suffix ? `${base}:${suffix}` : base;
}

/** Get a human-readable message for a problem. */
export function problemMessage(problem: Problem): string {
    switch (problem.type) {
        case 'unhealthy':
            return problem.category === 'end-of-life'
                ? 'Package is end-of-life'
                : `Score ${problem.score}/100 — ${problem.category}`;
        case 'stale-override':
            return 'No version conflict detected — review this override';
        case 'family-conflict':
            return `${problem.familyLabel} v${problem.currentMajor} conflicts with ${problem.conflictingPackages.join(', ')}`;
        case 'risky-transitive':
            return problem.flaggedTransitives.length > 0
                ? `${problem.flaggedCount} risky transitive(s), e.g. ${problem.flaggedTransitives.join(', ')}`
                : `${problem.flaggedCount} risky transitive dep(s)`;
        case 'blocked-upgrade':
            return `Update ${problem.currentVersion} → ${problem.latestVersion} blocked by ${problem.blockerPackage}`;
        case 'unused':
            return 'No imports found in lib/, bin/, or test/';
        case 'license-risk':
            return `License ${problem.license} is ${problem.riskLevel}`;
        case 'vulnerability':
            return `${problem.vulnId}: ${problem.summary}`;
    }
}

/** Get a short label for a problem type. */
export function problemTypeLabel(type: ProblemType): string {
    switch (type) {
        case 'unhealthy': return 'Unhealthy';
        case 'stale-override': return 'Stale Override';
        case 'family-conflict': return 'Family Conflict';
        case 'risky-transitive': return 'Risky Transitive';
        case 'blocked-upgrade': return 'Blocked Upgrade';
        case 'unused': return 'Unused';
        case 'license-risk': return 'License Risk';
        case 'vulnerability': return 'Vulnerability';
    }
}

/** Get the emoji icon for a problem severity. */
export function severityIcon(severity: ProblemSeverity): string {
    switch (severity) {
        case 'high': return '🔴';
        case 'medium': return '🟡';
        case 'low': return '🔵';
    }
}

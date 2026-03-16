/**
 * Legacy problem conversion utilities.
 *
 * Converts the old Problem format (plain objects with string type/severity)
 * into the new discriminated-union Problem type. This is used during
 * migration from the previous diagnostic system to the typed problem registry.
 */

import {
    Problem, ProblemSeverity, ProblemType,
    generateProblemId,
} from './problem-types';

/**
 * Convert the old Problem format from types.ts to the new format.
 * Used during migration.
 *
 * Takes a legacy problem object with string-typed fields and produces
 * the correct discriminated-union Problem variant. Each case populates
 * the variant-specific fields with sensible defaults since the legacy
 * format didn't carry that information.
 *
 * @param legacy  - The old-format problem with string type and severity.
 * @param packageName - The package this problem belongs to.
 * @param line - The line number in pubspec.yaml where the package is declared.
 * @returns A typed Problem, or null if the legacy type is unrecognised.
 */
export function convertLegacyProblem(
    legacy: { type: string; severity: string; message: string; relatedPackage?: string },
    packageName: string,
    line: number,
): Problem | null {
    // Cast the string severity to the enum — legacy data is trusted here
    const severity = legacy.severity as ProblemSeverity;

    // Generate a deterministic ID from the package + type pair
    const id = generateProblemId(packageName, legacy.type as ProblemType);

    switch (legacy.type) {
        case 'unhealthy':
            return {
                id,
                type: 'unhealthy',
                package: packageName,
                severity,
                line,
                score: 0,
                category: 'legacy-locked',
            };
        case 'stale-override':
            return {
                id,
                type: 'stale-override',
                package: packageName,
                severity,
                line,
                overrideName: packageName,
                ageDays: null,
            };
        case 'family-conflict':
            return {
                id,
                type: 'family-conflict',
                package: packageName,
                severity,
                line,
                familyId: 'unknown',
                familyLabel: 'Unknown',
                currentMajor: 0,
                conflictingPackages: [],
            };
        case 'risky-transitive':
            return {
                id,
                type: 'risky-transitive',
                package: packageName,
                severity,
                line,
                flaggedCount: 0,
                flaggedTransitives: [],
            };
        case 'blocked-upgrade':
            return {
                id,
                type: 'blocked-upgrade',
                package: packageName,
                severity,
                line,
                currentVersion: '',
                latestVersion: '',
                blockerPackage: legacy.relatedPackage ?? 'unknown',
                blockerScore: null,
            };
        case 'unused':
            return {
                id,
                type: 'unused',
                package: packageName,
                severity,
                line,
            };
        case 'license-risk':
            return {
                id,
                type: 'license-risk',
                package: packageName,
                severity,
                line,
                license: 'unknown',
                riskLevel: 'unknown',
            };
        default:
            // Unrecognised legacy type — caller should handle null
            return null;
    }
}

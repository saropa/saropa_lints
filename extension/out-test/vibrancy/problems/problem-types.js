"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateProblemId = generateProblemId;
exports.problemMessage = problemMessage;
exports.problemTypeLabel = problemTypeLabel;
exports.severityIcon = severityIcon;
/** Generate a unique ID for a problem. */
function generateProblemId(pkg, type, suffix) {
    const base = `${pkg}:${type}`;
    return suffix ? `${base}:${suffix}` : base;
}
/** Get a human-readable message for a problem. */
function problemMessage(problem) {
    switch (problem.type) {
        case 'unhealthy':
            if (problem.category === 'end-of-life') {
                return 'Package is end-of-life';
            }
            if (problem.category === 'stale') {
                return 'Package is stale — low maintenance activity';
            }
            return `Score ${problem.score}/100 — ${problem.category}`;
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
function problemTypeLabel(type) {
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
function severityIcon(severity) {
    switch (severity) {
        case 'high': return '🔴';
        case 'medium': return '🟡';
        case 'low': return '🔵';
    }
}
//# sourceMappingURL=problem-types.js.map
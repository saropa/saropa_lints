"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifyAdoption = classifyAdoption;
/** Classify a candidate package for the adoption gate. */
function classifyAdoption(input) {
    if (!input.exists) {
        return {
            tier: 'unknown',
            badgeText: 'Not found on pub.dev',
            detail: 'This package was not found on pub.dev — check for typos or private packages',
        };
    }
    if (input.isDiscontinued) {
        return {
            tier: 'warning',
            badgeText: 'Discontinued',
            detail: 'This package is marked as discontinued on pub.dev',
        };
    }
    if (input.knownIssueStatus === 'end-of-life') {
        const reason = input.knownIssueReason ?? 'end of life';
        return {
            tier: 'warning',
            badgeText: `Known issue: ${reason}`,
            detail: `This package has a known issue: ${reason}`,
        };
    }
    if (input.pubPoints >= 100 && input.verifiedPublisher) {
        return {
            tier: 'healthy',
            badgeText: `✓ ${input.pubPoints} pts · verified`,
            detail: `${input.pubPoints} pub points, verified publisher`,
        };
    }
    const publisher = input.verifiedPublisher ? 'verified' : 'unverified';
    return {
        tier: 'caution',
        badgeText: `${input.pubPoints} pts · ${publisher}`,
        detail: `${input.pubPoints} pub points, ${publisher} publisher — proceed with caution`,
    };
}
//# sourceMappingURL=adoption-classifier.js.map
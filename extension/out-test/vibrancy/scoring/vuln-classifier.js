"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.classifySeverity = classifySeverity;
exports.worstSeverity = worstSeverity;
exports.severityEmoji = severityEmoji;
exports.severityLabel = severityLabel;
exports.countBySeverity = countBySeverity;
exports.filterBySeverity = filterBySeverity;
exports.calcVulnPenalty = calcVulnPenalty;
/**
 * Classify CVSS score to severity tier.
 * Based on CVSS v3.0 standard thresholds.
 */
function classifySeverity(cvssScore) {
    if (cvssScore === null) {
        return 'medium';
    }
    if (cvssScore >= 9.0) {
        return 'critical';
    }
    if (cvssScore >= 7.0) {
        return 'high';
    }
    if (cvssScore >= 4.0) {
        return 'medium';
    }
    return 'low';
}
/** Severity priority for sorting (higher = worse). */
const SEVERITY_PRIORITY = {
    'critical': 4,
    'high': 3,
    'medium': 2,
    'low': 1,
};
/**
 * Get the worst (highest) severity across all vulnerabilities.
 * Returns null if no vulnerabilities.
 */
function worstSeverity(vulns) {
    if (vulns.length === 0) {
        return null;
    }
    let worst = 'low';
    for (const vuln of vulns) {
        if (SEVERITY_PRIORITY[vuln.severity] > SEVERITY_PRIORITY[worst]) {
            worst = vuln.severity;
        }
    }
    return worst;
}
/** Get emoji icon for severity tier. */
function severityEmoji(severity) {
    switch (severity) {
        case 'critical': return '🔴';
        case 'high': return '🟠';
        case 'medium': return '🟡';
        case 'low': return '🔵';
    }
}
/** Get label for severity tier. */
function severityLabel(severity) {
    return severity.charAt(0).toUpperCase() + severity.slice(1);
}
/** Count vulnerabilities by severity tier. */
function countBySeverity(vulns) {
    const counts = {
        critical: 0,
        high: 0,
        medium: 0,
        low: 0,
    };
    for (const vuln of vulns) {
        counts[vuln.severity]++;
    }
    return counts;
}
/**
 * Check if vulnerabilities meet minimum severity threshold.
 * Returns vulns at or above the threshold.
 */
function filterBySeverity(vulns, minSeverity) {
    const minPriority = SEVERITY_PRIORITY[minSeverity];
    return vulns.filter(v => SEVERITY_PRIORITY[v.severity] >= minPriority);
}
/** Get total vulnerability score penalty (0-30 scale). */
function calcVulnPenalty(vulns) {
    if (vulns.length === 0) {
        return 0;
    }
    let penalty = 0;
    for (const vuln of vulns) {
        switch (vuln.severity) {
            case 'critical':
                penalty += 15;
                break;
            case 'high':
                penalty += 10;
                break;
            case 'medium':
                penalty += 5;
                break;
            case 'low':
                penalty += 2;
                break;
        }
    }
    return Math.min(30, penalty);
}
//# sourceMappingURL=vuln-classifier.js.map
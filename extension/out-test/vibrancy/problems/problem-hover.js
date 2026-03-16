"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatProblemsForHover = formatProblemsForHover;
exports.formatProblemsSummary = formatProblemsSummary;
exports.formatProblemTableRow = formatProblemTableRow;
exports.formatProblemsTable = formatProblemsTable;
exports.formatProblemDiagnostic = formatProblemDiagnostic;
const problem_types_1 = require("./problem-types");
const problem_actions_1 = require("./problem-actions");
/**
 * Build a markdown string for displaying problems in a hover tooltip.
 */
function formatProblemsForHover(packageName, registry, action) {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }
    const lines = [];
    lines.push(`### ⚠️ Problems (${problems.length})`);
    lines.push('');
    for (const problem of problems) {
        const icon = (0, problem_types_1.severityIcon)(problem.severity);
        const typeLabel = (0, problem_types_1.problemTypeLabel)(problem.type);
        lines.push(`${icon} **${typeLabel}:** ${(0, problem_types_1.problemMessage)(problem)}`);
        lines.push('');
    }
    if (action && action.type !== 'none') {
        lines.push('---');
        lines.push('');
        lines.push(`### 💡 Suggested Action`);
        lines.push('');
        lines.push((0, problem_actions_1.formatAction)(action));
        lines.push('');
        if (action.resolvesProblemIds.length > 1) {
            lines.push(`*Resolves ${action.resolvesProblemIds.length} problems*`);
            lines.push('');
        }
    }
    const chain = collectResolutionChain(packageName, registry);
    if (chain.length > 0) {
        lines.push(`*Unlocks: ${chain.join(', ')}*`);
        lines.push('');
    }
    return lines.join('\n');
}
/**
 * Build a concise summary line for problems.
 */
function formatProblemsSummary(packageName, registry) {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }
    const highCount = problems.filter(p => p.severity === 'high').length;
    const mediumCount = problems.filter(p => p.severity === 'medium').length;
    const lowCount = problems.filter(p => p.severity === 'low').length;
    const parts = [];
    if (highCount > 0) {
        parts.push(`🔴 ${highCount}`);
    }
    if (mediumCount > 0) {
        parts.push(`🟡 ${mediumCount}`);
    }
    if (lowCount > 0) {
        parts.push(`🔵 ${lowCount}`);
    }
    return parts.join(' ');
}
/**
 * Build a table row for problem details.
 */
function formatProblemTableRow(problem) {
    const icon = (0, problem_types_1.severityIcon)(problem.severity);
    return `| ${icon} ${(0, problem_types_1.problemTypeLabel)(problem.type)} | ${(0, problem_types_1.problemMessage)(problem)} |`;
}
/**
 * Build a full problems table for markdown display.
 */
function formatProblemsTable(packageName, registry) {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }
    const lines = [];
    lines.push('| Type | Details |');
    lines.push('|------|---------|');
    for (const problem of problems) {
        lines.push(formatProblemTableRow(problem));
    }
    return lines.join('\n');
}
/**
 * Collect packages that would be unlocked if this package is fixed.
 */
function collectResolutionChain(packageName, registry) {
    const unlocked = new Set();
    const problems = registry.getForPackage(packageName);
    for (const problem of problems) {
        const chain = registry.getResolutionChain(problem.id);
        for (const resolved of chain) {
            if (resolved.package !== packageName) {
                unlocked.add(resolved.package);
            }
        }
    }
    return Array.from(unlocked);
}
/**
 * Format a diagnostic message for a problem.
 */
function formatProblemDiagnostic(problem) {
    const typeLabel = (0, problem_types_1.problemTypeLabel)(problem.type);
    const message = (0, problem_types_1.problemMessage)(problem);
    return `[Saropa] ${typeLabel}: ${message} (${problem.package})`;
}
//# sourceMappingURL=problem-hover.js.map
import { Problem, problemMessage, severityIcon, problemTypeLabel } from './problem-types';
import { SuggestedAction, formatAction } from './problem-actions';
import { ProblemRegistry } from './problem-registry';

/**
 * Build a markdown string for displaying problems in a hover tooltip.
 */
export function formatProblemsForHover(
    packageName: string,
    registry: ProblemRegistry,
    action: SuggestedAction | null,
): string {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }

    const lines: string[] = [];
    lines.push(`### ⚠️ Problems (${problems.length})`);
    lines.push('');

    for (const problem of problems) {
        const icon = severityIcon(problem.severity);
        const typeLabel = problemTypeLabel(problem.type);
        lines.push(`${icon} **${typeLabel}:** ${problemMessage(problem)}`);
        lines.push('');
    }

    if (action && action.type !== 'none') {
        lines.push('---');
        lines.push('');
        lines.push(`### 💡 Suggested Action`);
        lines.push('');
        lines.push(formatAction(action));
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
export function formatProblemsSummary(
    packageName: string,
    registry: ProblemRegistry,
): string {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }

    const highCount = problems.filter(p => p.severity === 'high').length;
    const mediumCount = problems.filter(p => p.severity === 'medium').length;
    const lowCount = problems.filter(p => p.severity === 'low').length;

    const parts: string[] = [];
    if (highCount > 0) { parts.push(`🔴 ${highCount}`); }
    if (mediumCount > 0) { parts.push(`🟡 ${mediumCount}`); }
    if (lowCount > 0) { parts.push(`🔵 ${lowCount}`); }

    return parts.join(' ');
}

/**
 * Build a table row for problem details.
 */
export function formatProblemTableRow(problem: Problem): string {
    const icon = severityIcon(problem.severity);
    return `| ${icon} ${problemTypeLabel(problem.type)} | ${problemMessage(problem)} |`;
}

/**
 * Build a full problems table for markdown display.
 */
export function formatProblemsTable(
    packageName: string,
    registry: ProblemRegistry,
): string {
    const problems = registry.getForPackage(packageName);
    if (problems.length === 0) {
        return '';
    }

    const lines: string[] = [];
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
function collectResolutionChain(
    packageName: string,
    registry: ProblemRegistry,
): string[] {
    const unlocked = new Set<string>();
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
export function formatProblemDiagnostic(problem: Problem): string {
    const typeLabel = problemTypeLabel(problem.type);
    const message = problemMessage(problem);
    return `[Saropa] ${typeLabel}: ${message} (${problem.package})`;
}

import { VibrancyResult, BudgetConfig, BudgetResult, BudgetStatus } from '../types';
import { formatSizeMB } from './bloat-calculator';

/** Read budget configuration from workspace settings. */
export function readBudgetConfig(
    get: <T>(key: string) => T | undefined,
): BudgetConfig {
    return {
        maxDependencies: get<number>('budget.maxDependencies') ?? null,
        maxTotalSizeMB: get<number>('budget.maxTotalSizeMB') ?? null,
        minAverageVibrancy: get<number>('budget.minAverageVibrancy') ?? null,
        maxEndOfLife: get<number>('budget.maxEndOfLife') ?? null,
        maxLegacyLocked: get<number>('budget.maxLegacyLocked') ?? null,
        maxUnused: get<number>('budget.maxUnused') ?? null,
    };
}

/** Check if any budget is configured. */
export function hasBudgets(config: BudgetConfig): boolean {
    return config.maxDependencies !== null
        || config.maxTotalSizeMB !== null
        || config.minAverageVibrancy !== null
        || config.maxEndOfLife !== null
        || config.maxLegacyLocked !== null
        || config.maxUnused !== null;
}

/** Compute actual values for each budget dimension from scan results. */
export function computeActuals(results: readonly VibrancyResult[]): {
    totalCount: number;
    totalSizeMB: number;
    averageVibrancy: number;
    endOfLifeCount: number;
    legacyLockedCount: number;
    unusedCount: number;
} {
    const totalCount = results.length;

    let totalSizeBytes = 0;
    let totalScore = 0;
    let endOfLifeCount = 0;
    let legacyLockedCount = 0;
    let unusedCount = 0;

    for (const r of results) {
        totalScore += r.score;
        if (r.archiveSizeBytes !== null) {
            totalSizeBytes += r.archiveSizeBytes;
        }
        if (r.category === 'end-of-life') {
            endOfLifeCount++;
        }
        if (r.category === 'legacy-locked') {
            legacyLockedCount++;
        }
        if (r.isUnused) {
            unusedCount++;
        }
    }

    const totalSizeMB = totalSizeBytes / (1024 * 1024);
    const averageVibrancy = totalCount > 0
        ? Math.round(totalScore / totalCount) : 0;

    return {
        totalCount,
        totalSizeMB,
        averageVibrancy,
        endOfLifeCount,
        legacyLockedCount,
        unusedCount,
    };
}

/** Classify status based on actual vs limit. Handles zero limit as exceeded. */
function classifyStatus(actual: number, limit: number, isMinimum: boolean): BudgetStatus {
    if (limit <= 0) { return actual === 0 ? 'under' : 'exceeded'; }
    if (isMinimum) {
        return actual >= limit ? 'under' : actual >= limit * 0.8 ? 'warning' : 'exceeded';
    }
    return actual < limit * 0.8 ? 'under' : actual < limit ? 'warning' : 'exceeded';
}

interface BuildResultOpts {
    dimension: string;
    actual: number;
    limit: number | null;
    isMinimum: boolean;
    formatActual: (v: number) => string;
    formatLimit: (v: number) => string;
}

/** Build a single budget result. */
function buildResult(opts: BuildResultOpts): BudgetResult {
    const { dimension, actual, limit, isMinimum, formatActual, formatLimit } = opts;
    if (limit === null) {
        return {
            dimension,
            actual,
            limit: null,
            percentage: null,
            status: 'unconfigured',
            details: formatActual(actual),
        };
    }

    const status = classifyStatus(actual, limit, isMinimum);
    const percentage = limit > 0 ? Math.round((actual / limit) * 100) : 0;

    let details: string;
    if (isMinimum) {
        details = `${formatActual(actual)}/${formatLimit(limit)} min (${percentage}%)`;
    } else {
        details = `${formatActual(actual)}/${formatLimit(limit)} (${percentage}%)`;
    }

    return {
        dimension,
        actual,
        limit,
        percentage,
        status,
        details,
    };
}

/** Check all budget dimensions against configured limits. */
export function checkBudgets(
    results: readonly VibrancyResult[],
    config: BudgetConfig,
): BudgetResult[] {
    const actuals = computeActuals(results);
    const budgetResults: BudgetResult[] = [];

    budgetResults.push(buildResult({
        dimension: 'Dependencies',
        actual: actuals.totalCount,
        limit: config.maxDependencies,
        isMinimum: false,
        formatActual: v => `${v}`,
        formatLimit: v => `${v}`,
    }));

    budgetResults.push(buildResult({
        dimension: 'Total Size',
        actual: actuals.totalSizeMB,
        limit: config.maxTotalSizeMB,
        isMinimum: false,
        formatActual: v => formatSizeMB(v * 1024 * 1024),
        formatLimit: v => `${v.toFixed(1)} MB`,
    }));

    budgetResults.push(buildResult({
        dimension: 'Avg Vibrancy',
        actual: actuals.averageVibrancy,
        limit: config.minAverageVibrancy,
        isMinimum: true,
        formatActual: v => `${Math.round(v / 10)}/10`,
        formatLimit: v => `${Math.round(v / 10)}/10`,
    }));

    budgetResults.push(buildResult({
        dimension: 'End of Life',
        actual: actuals.endOfLifeCount,
        limit: config.maxEndOfLife,
        isMinimum: false,
        formatActual: v => `${v}`,
        formatLimit: v => `${v} max`,
    }));

    budgetResults.push(buildResult({
        dimension: 'Legacy-Locked',
        actual: actuals.legacyLockedCount,
        limit: config.maxLegacyLocked,
        isMinimum: false,
        formatActual: v => `${v}`,
        formatLimit: v => `${v} max`,
    }));

    budgetResults.push(buildResult({
        dimension: 'Unused',
        actual: actuals.unusedCount,
        limit: config.maxUnused,
        isMinimum: false,
        formatActual: v => `${v}`,
        formatLimit: v => `${v} max`,
    }));

    return budgetResults;
}

/** Summarize budget check results. */
export function summarizeBudgets(results: readonly BudgetResult[]): {
    configured: number;
    ok: number;
    warning: number;
    exceeded: number;
} {
    let configured = 0;
    let ok = 0;
    let warning = 0;
    let exceeded = 0;

    for (const r of results) {
        if (r.status === 'unconfigured') { continue; }
        configured++;
        switch (r.status) {
            case 'under': ok++; break;
            case 'warning': warning++; break;
            case 'exceeded': exceeded++; break;
        }
    }

    return { configured, ok, warning, exceeded };
}

/** Format a summary message for the budget status. */
export function formatBudgetSummary(results: readonly BudgetResult[]): string {
    const { configured, ok, warning, exceeded } = summarizeBudgets(results);

    if (configured === 0) {
        return 'No budgets configured';
    }

    if (exceeded === 0 && warning === 0) {
        return `All ${configured} limit(s) OK ✓`;
    }

    const parts: string[] = [];
    if (ok > 0) { parts.push(`${ok} OK`); }
    if (warning > 0) { parts.push(`${warning} warning`); }
    if (exceeded > 0) { parts.push(`${exceeded} exceeded`); }

    return parts.join(', ');
}

/** Get packages by category for diagnostic details. */
export function getPackagesByCategory(
    results: readonly VibrancyResult[],
    category: 'end-of-life' | 'legacy-locked' | 'unused',
): string[] {
    if (category === 'unused') {
        return results.filter(r => r.isUnused).map(r => r.package.name);
    }
    return results
        .filter(r => r.category === category)
        .map(r => r.package.name);
}

/** Build exceeded budget diagnostic messages. */
export function buildExceededDiagnostics(
    results: readonly VibrancyResult[],
    budgetResults: readonly BudgetResult[],
): string[] {
    const messages: string[] = [];

    for (const br of budgetResults) {
        if (br.status !== 'exceeded' || br.limit === null) { continue; }

        let packageNames: string[] = [];
        let message: string;

        switch (br.dimension) {
            case 'End of Life':
                packageNames = getPackagesByCategory(results, 'end-of-life');
                message = `Budget exceeded: ${br.actual} End-of-Life packages (limit: ${br.limit}). Remove or replace: ${packageNames.join(', ')}`;
                break;
            case 'Legacy-Locked':
                packageNames = getPackagesByCategory(results, 'legacy-locked');
                message = `Budget exceeded: ${br.actual} Legacy-Locked packages (limit: ${br.limit}). Review: ${packageNames.join(', ')}`;
                break;
            case 'Unused':
                packageNames = getPackagesByCategory(results, 'unused');
                message = `Budget exceeded: ${br.actual} unused packages (limit: ${br.limit}). Consider removing: ${packageNames.join(', ')}`;
                break;
            case 'Dependencies':
                message = `Budget exceeded: ${br.actual} dependencies (limit: ${br.limit}). Consider removing unused or consolidating packages.`;
                break;
            case 'Total Size':
                message = `Budget exceeded: Total archive size ${formatSizeMB(br.actual * 1024 * 1024)} (limit: ${br.limit?.toFixed(1)} MB). Review large dependencies.`;
                break;
            case 'Avg Vibrancy':
                message = `Budget exceeded: Average vibrancy ${Math.round(br.actual / 10)}/10 is below minimum ${Math.round(br.limit / 10)}/10. Improve dependency health.`;
                break;
            default:
                continue;
        }

        messages.push(message);
    }

    return messages;
}

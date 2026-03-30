import * as assert from 'assert';
import {
    checkBudgets, computeActuals, summarizeBudgets, formatBudgetSummary,
    hasBudgets, readBudgetConfig, buildExceededDiagnostics, getPackagesByCategory,
} from '../../../vibrancy/scoring/budget-checker';
import { VibrancyResult, BudgetConfig, VibrancyCategory, BudgetResult } from '../../../vibrancy/types';

const NO_BUDGET: BudgetConfig = {
    maxDependencies: null, maxTotalSizeMB: null, minAverageVibrancy: null,
    maxStale: null, maxEndOfLife: null, maxLegacyLocked: null, maxUnused: null,
};

function makeResult(
    name: string, score: number, category: VibrancyCategory,
    opts: { archiveSizeBytes?: number | null; isUnused?: boolean } = {},
): VibrancyResult {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null, github: null, knownIssue: null, score, category,
        resolutionVelocity: 0, engagementLevel: 0, popularity: 0, publisherTrust: 0,
        archiveSizeBytes: opts.archiveSizeBytes ?? null, isUnused: opts.isUnused ?? false,
        platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null,
        upgradeBlockStatus: 'up-to-date', transitiveInfo: null, alternatives: [],
        latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
    };
}

describe('budget-checker', () => {
    describe('readBudgetConfig', () => {
        it('should return nulls when no config set', () => {
            const config = readBudgetConfig(() => undefined);
            assert.strictEqual(config.maxDependencies, null);
            assert.strictEqual(config.maxTotalSizeMB, null);
            assert.strictEqual(config.minAverageVibrancy, null);
            assert.strictEqual(config.maxStale, null);
            assert.strictEqual(config.maxEndOfLife, null);
            assert.strictEqual(config.maxLegacyLocked, null);
            assert.strictEqual(config.maxUnused, null);
        });

        it('should read configured values', () => {
            const values: Record<string, number> = {
                'budget.maxDependencies': 50,
                'budget.maxTotalSizeMB': 100,
                'budget.minAverageVibrancy': 60,
                'budget.maxStale': 2,
                'budget.maxEndOfLife': 0,
                'budget.maxLegacyLocked': 5,
                'budget.maxUnused': 3,
            };
            const config = readBudgetConfig(<T>(key: string) => values[key] as T | undefined);
            assert.strictEqual(config.maxDependencies, 50);
            assert.strictEqual(config.maxTotalSizeMB, 100);
            assert.strictEqual(config.minAverageVibrancy, 60);
            assert.strictEqual(config.maxStale, 2);
            assert.strictEqual(config.maxEndOfLife, 0);
            assert.strictEqual(config.maxLegacyLocked, 5);
            assert.strictEqual(config.maxUnused, 3);
        });
    });

    describe('hasBudgets', () => {
        it('should return false when all nulls', () => {
            assert.strictEqual(hasBudgets(NO_BUDGET), false);
        });

        it('should return true when any value set', () => {
            assert.strictEqual(hasBudgets({ ...NO_BUDGET, maxDependencies: 50 }), true);
        });
    });

    describe('computeActuals', () => {
        it('should compute totals from results', () => {
            const results: VibrancyResult[] = [
                makeResult('a', 80, 'vibrant', { archiveSizeBytes: 1024 * 1024 }),
                makeResult('b', 50, 'quiet', { archiveSizeBytes: 2 * 1024 * 1024 }),
                makeResult('c', 20, 'legacy-locked', { isUnused: true }),
                makeResult('d', 5, 'stale'),
                makeResult('e', 0, 'end-of-life'),
            ];

            const actuals = computeActuals(results);

            assert.strictEqual(actuals.totalCount, 5);
            assert.strictEqual(actuals.totalSizeMB, 3);
            assert.strictEqual(actuals.averageVibrancy, 31);
            assert.strictEqual(actuals.staleCount, 1);
            assert.strictEqual(actuals.endOfLifeCount, 1);
            assert.strictEqual(actuals.legacyLockedCount, 1);
            assert.strictEqual(actuals.unusedCount, 1);
        });

        it('should handle empty results', () => {
            const actuals = computeActuals([]);

            assert.strictEqual(actuals.totalCount, 0);
            assert.strictEqual(actuals.totalSizeMB, 0);
            assert.strictEqual(actuals.averageVibrancy, 0);
            assert.strictEqual(actuals.staleCount, 0);
            assert.strictEqual(actuals.endOfLifeCount, 0);
            assert.strictEqual(actuals.legacyLockedCount, 0);
            assert.strictEqual(actuals.unusedCount, 0);
        });
    });

    describe('checkBudgets', () => {
        // EOL category is set directly — these represent discontinued packages, not score-based classification
        const results: VibrancyResult[] = [
            makeResult('a', 80, 'vibrant', { archiveSizeBytes: 10 * 1024 * 1024 }),
            makeResult('b', 60, 'quiet', { archiveSizeBytes: 5 * 1024 * 1024 }),
            makeResult('c', 20, 'legacy-locked', { isUnused: true }),
            makeResult('d', 5, 'end-of-life'),
            makeResult('e', 5, 'end-of-life'),
        ];

        it('should return unconfigured when no limits set', () => {
            const budgetResults = checkBudgets(results, NO_BUDGET);
            for (const br of budgetResults) {
                assert.strictEqual(br.status, 'unconfigured');
            }
        });

        it('should mark as under when well within limits', () => {
            const config = { ...NO_BUDGET, maxDependencies: 100, maxEndOfLife: 10 };
            const budgetResults = checkBudgets(results, config);
            const deps = budgetResults.find(r => r.dimension === 'Dependencies')!;
            assert.strictEqual(deps.status, 'under');
            assert.strictEqual(deps.percentage, 5);
        });

        it('should mark as warning when approaching limit', () => {
            const config = { ...NO_BUDGET, maxDependencies: 6 };
            const budgetResults = checkBudgets(results, config);
            const deps = budgetResults.find(r => r.dimension === 'Dependencies')!;
            assert.strictEqual(deps.status, 'warning');
            assert.strictEqual(deps.percentage, 83);
        });

        it('should mark as exceeded when over limit', () => {
            const config = { ...NO_BUDGET, maxDependencies: 3, maxTotalSizeMB: 10, maxEndOfLife: 1 };
            const budgetResults = checkBudgets(results, config);
            assert.strictEqual(budgetResults.find(r => r.dimension === 'Dependencies')!.status, 'exceeded');
            assert.strictEqual(budgetResults.find(r => r.dimension === 'Total Size')!.status, 'exceeded');
            assert.strictEqual(budgetResults.find(r => r.dimension === 'End of Life')!.status, 'exceeded');
        });

        it('should handle minAverageVibrancy as minimum threshold', () => {
            const config = { ...NO_BUDGET, minAverageVibrancy: 50 };
            const budgetResults = checkBudgets(results, config);
            assert.strictEqual(budgetResults.find(r => r.dimension === 'Avg Vibrancy')!.status, 'exceeded');
        });

        it('should pass minAverageVibrancy when above threshold', () => {
            const highResults = [makeResult('a', 80, 'vibrant'), makeResult('b', 70, 'vibrant')];
            const config = { ...NO_BUDGET, minAverageVibrancy: 50 };
            const budgetResults = checkBudgets(highResults, config);
            assert.strictEqual(budgetResults.find(r => r.dimension === 'Avg Vibrancy')!.status, 'under');
        });
    });

    describe('summarizeBudgets', () => {
        it('should count configured results', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'A', actual: 1, limit: 10, percentage: 10, status: 'under', details: '' },
                { dimension: 'B', actual: 8, limit: 10, percentage: 80, status: 'warning', details: '' },
                { dimension: 'C', actual: 15, limit: 10, percentage: 150, status: 'exceeded', details: '' },
                { dimension: 'D', actual: 5, limit: null, percentage: null, status: 'unconfigured', details: '' },
            ];
            const summary = summarizeBudgets(budgetResults);
            assert.deepStrictEqual(summary, { configured: 3, ok: 1, warning: 1, exceeded: 1 });
        });

        it('should handle all unconfigured', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'A', actual: 1, limit: null, percentage: null, status: 'unconfigured', details: '' },
            ];
            const summary = summarizeBudgets(budgetResults);
            assert.deepStrictEqual(summary, { configured: 0, ok: 0, warning: 0, exceeded: 0 });
        });
    });

    describe('formatBudgetSummary', () => {
        it('should format all ok', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'A', actual: 1, limit: 10, percentage: 10, status: 'under', details: '' },
                { dimension: 'B', actual: 2, limit: 10, percentage: 20, status: 'under', details: '' },
            ];
            assert.strictEqual(formatBudgetSummary(budgetResults), 'All 2 limit(s) OK ✓');
        });

        it('should format mixed status', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'A', actual: 1, limit: 10, percentage: 10, status: 'under', details: '' },
                { dimension: 'B', actual: 8, limit: 10, percentage: 80, status: 'warning', details: '' },
                { dimension: 'C', actual: 15, limit: 10, percentage: 150, status: 'exceeded', details: '' },
            ];
            assert.strictEqual(formatBudgetSummary(budgetResults), '1 OK, 1 warning, 1 exceeded');
        });

        it('should format none configured', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'A', actual: 1, limit: null, percentage: null, status: 'unconfigured', details: '' },
            ];
            assert.strictEqual(formatBudgetSummary(budgetResults), 'No budgets configured');
        });
    });

    describe('getPackagesByCategory', () => {
        const results: VibrancyResult[] = [
            makeResult('a', 80, 'vibrant'), makeResult('b', 5, 'end-of-life'),
            makeResult('c', 5, 'end-of-life'), makeResult('d', 20, 'legacy-locked', { isUnused: true }),
            makeResult('e', 60, 'quiet', { isUnused: true }),
            makeResult('f', 5, 'stale'),
        ];

        it('should return end-of-life packages', () => {
            assert.deepStrictEqual(getPackagesByCategory(results, 'end-of-life'), ['b', 'c']);
        });

        it('should return stale packages', () => {
            assert.deepStrictEqual(getPackagesByCategory(results, 'stale'), ['f']);
        });

        it('should return unused packages', () => {
            assert.deepStrictEqual(getPackagesByCategory(results, 'unused'), ['d', 'e']);
        });
    });

    describe('buildExceededDiagnostics', () => {
        // EOL category is set directly — these represent discontinued packages, not score-based classification
        const results: VibrancyResult[] = [
            makeResult('a', 5, 'end-of-life'), makeResult('b', 5, 'end-of-life'),
            makeResult('c', 20, 'legacy-locked'),
        ];

        it('should build messages for exceeded budgets', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'End of Life', actual: 2, limit: 1, percentage: 200, status: 'exceeded', details: '' },
                { dimension: 'Dependencies', actual: 3, limit: 2, percentage: 150, status: 'exceeded', details: '' },
            ];
            const messages = buildExceededDiagnostics(results, budgetResults);
            assert.strictEqual(messages.length, 2);
            assert.ok(messages[0].includes('End-of-Life') && messages[0].includes('a, b'));
        });

        it('should skip non-exceeded and unconfigured budgets', () => {
            const budgetResults: BudgetResult[] = [
                { dimension: 'End of Life', actual: 0, limit: 1, percentage: 0, status: 'under', details: '' },
                { dimension: 'Unused', actual: 2, limit: null, percentage: null, status: 'unconfigured', details: '' },
            ];
            assert.strictEqual(buildExceededDiagnostics(results, budgetResults).length, 0);
        });
    });
});

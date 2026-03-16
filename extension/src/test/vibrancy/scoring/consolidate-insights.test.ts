import * as assert from 'assert';
import {
    consolidateInsights, collectProblems, computeCombinedRisk,
    determineSuggestedAction, findUnlockedPackages,
} from '../../../vibrancy/scoring/consolidate-insights';
import { VibrancyResult, OverrideAnalysis, FamilySplit } from '../../../vibrancy/types';

const makeResult = (
    name: string,
    score: number,
    opts?: Partial<VibrancyResult>,
): VibrancyResult => ({
    package: {
        name,
        version: '1.0.0',
        constraint: '^1.0.0',
        source: 'hosted',
        isDirect: true,
        section: 'dependencies',
    },
    pubDev: null,
    github: null,
    knownIssue: null,
    score,
    // Score < 10 is 'stale' (low maintenance), not 'end-of-life' (truly dead)
    category: score >= 70 ? 'vibrant' : score >= 40 ? 'quiet' : score >= 10 ? 'legacy-locked' : 'stale',
    resolutionVelocity: 0,
    engagementLevel: 0,
    popularity: 0,
    publisherTrust: 0,
    updateInfo: null,
    license: null,
    drift: null,
    archiveSizeBytes: null,
    bloatRating: null,
    isUnused: false,
    platforms: null,
    verifiedPublisher: false,
    wasmReady: null,
    blocker: null,
    upgradeBlockStatus: 'up-to-date',
    transitiveInfo: null,
    alternatives: [],
    latestPrerelease: null,
    prereleaseTag: null,
    vulnerabilities: [],
    ...opts,
});

const makeOverride = (
    name: string,
    status: 'active' | 'stale',
    blocker?: string,
): OverrideAnalysis => ({
    entry: { name, version: '1.0.0', line: 10, isPathDep: false, isGitDep: false },
    status,
    blocker: blocker ?? null,
    addedDate: null,
    ageDays: null,
});

const makeSplit = (familyId: string, packages: string[][]): FamilySplit => ({
    familyId,
    familyLabel: familyId.charAt(0).toUpperCase() + familyId.slice(1),
    versionGroups: packages.map((pkgs, i) => ({
        majorVersion: i + 1,
        packages: pkgs,
    })),
    suggestion: `Upgrade all ${familyId} packages`,
});

describe('consolidate-insights', () => {
    describe('collectProblems', () => {
        it('should collect unhealthy problem for EOL package', () => {
            const result = makeResult('dead', 5, { category: 'end-of-life' });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'unhealthy');
            assert.strictEqual(problems[0].severity, 'high');
        });

        it('should collect unhealthy problem for stale package with medium severity', () => {
            const result = makeResult('quiet_pkg', 5, { category: 'stale' });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'unhealthy');
            assert.strictEqual(problems[0].severity, 'medium');
        });

        it('should collect unhealthy problem for legacy package', () => {
            const result = makeResult('old', 25, { category: 'legacy-locked' });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'unhealthy');
            assert.strictEqual(problems[0].severity, 'medium');
        });

        it('should collect unused problem', () => {
            const result = makeResult('unused', 80, { isUnused: true });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'unused');
        });

        it('should collect blocked-upgrade problem', () => {
            const result = makeResult('blocked', 60, {
                upgradeBlockStatus: 'blocked',
                blocker: {
                    blockedPackage: 'blocked',
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    blockerPackage: 'meta',
                    blockerVibrancyScore: 50,
                    blockerCategory: 'quiet',
                },
            });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'blocked-upgrade');
            assert.ok(problems[0].message.includes('meta'));
        });

        it('should collect risky-transitive problem', () => {
            const result = makeResult('risky', 70, {
                transitiveInfo: {
                    directDep: 'risky',
                    transitiveCount: 5,
                    flaggedCount: 2,
                    transitives: ['a', 'b'],
                    sharedDeps: [],
                },
            });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'risky-transitive');
        });

        it('should collect stale-override problem', () => {
            const result = makeResult('intl', 80);
            const overrideMap = new Map([['intl', makeOverride('intl', 'stale')]]);
            const problems = collectProblems(result, overrideMap, new Map());

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'stale-override');
        });

        it('should skip path overrides (intentional setup, not a problem)', () => {
            const result = makeResult('font_awesome_flutter', 80);
            const pathOverride: OverrideAnalysis = {
                entry: { name: 'font_awesome_flutter', version: '1.0.0', line: 10, isPathDep: true, isGitDep: false },
                status: 'active',
                blocker: 'local path override',
                addedDate: null,
                ageDays: null,
            };
            const overrideMap = new Map([['font_awesome_flutter', pathOverride]]);
            const problems = collectProblems(result, overrideMap, new Map());

            assert.strictEqual(problems.length, 0);
        });

        it('should skip git overrides (intentional setup, not a problem)', () => {
            const result = makeResult('custom_pkg', 80);
            const gitOverride: OverrideAnalysis = {
                entry: { name: 'custom_pkg', version: '1.0.0', line: 10, isPathDep: false, isGitDep: true },
                status: 'active',
                blocker: 'git override',
                addedDate: null,
                ageDays: null,
            };
            const overrideMap = new Map([['custom_pkg', gitOverride]]);
            const problems = collectProblems(result, overrideMap, new Map());

            assert.strictEqual(problems.length, 0);
        });

        it('should skip active version overrides (not a problem)', () => {
            const result = makeResult('intl', 80);
            const overrideMap = new Map([['intl', makeOverride('intl', 'active', 'some_pkg')]]);
            const problems = collectProblems(result, overrideMap, new Map());

            assert.strictEqual(problems.length, 0);
        });

        it('should collect family-conflict problem', () => {
            const result = makeResult('firebase_core', 70);
            const split = makeSplit('firebase', [['firebase_core'], ['cloud_firestore']]);
            const splitMap = new Map([['firebase_core', split]]);
            const problems = collectProblems(result, new Map(), splitMap);

            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'family-conflict');
        });

        it('should collect multiple problems for same package', () => {
            const result = makeResult('bad', 20, {
                category: 'legacy-locked',
                isUnused: true,
            });
            const problems = collectProblems(result, new Map(), new Map());

            assert.strictEqual(problems.length, 2);
            const types = problems.map(p => p.type);
            assert.ok(types.includes('unhealthy'));
            assert.ok(types.includes('unused'));
        });
    });

    describe('computeCombinedRisk', () => {
        it('should sum problem weights', () => {
            const result = makeResult('pkg', 20, { category: 'legacy-locked' });
            const problems = [
                { type: 'unhealthy' as const, severity: 'medium' as const, message: '' },
                { type: 'unused' as const, severity: 'low' as const, message: '' },
            ];
            const risk = computeCombinedRisk(problems, result);

            assert.strictEqual(risk, 25);
        });

        it('should use higher weight for EOL', () => {
            const result = makeResult('dead', 5, { category: 'end-of-life' });
            const problems = [
                { type: 'unhealthy' as const, severity: 'high' as const, message: '' },
            ];
            const risk = computeCombinedRisk(problems, result);

            assert.strictEqual(risk, 30);
        });

        it('should use medium weight for stale (between EOL and legacy)', () => {
            const result = makeResult('quiet_pkg', 5, { category: 'stale' });
            const problems = [
                { type: 'unhealthy' as const, severity: 'medium' as const, message: '' },
            ];
            const risk = computeCombinedRisk(problems, result);

            // Stale weight (25) sits between EOL (30) and legacy-locked (20)
            assert.strictEqual(risk, 25);
        });
    });

    describe('determineSuggestedAction', () => {
        it('should suggest removal for unused + unhealthy', () => {
            const result = makeResult('bad', 20, { category: 'legacy-locked' });
            const problems = [
                { type: 'unhealthy' as const, severity: 'medium' as const, message: '' },
                { type: 'unused' as const, severity: 'low' as const, message: '' },
            ];
            const { action, actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'remove');
            assert.ok(action?.includes('unused'));
        });

        it('should suggest upgrade-blocker for blocked upgrade', () => {
            const result = makeResult('blocked', 60);
            const problems = [
                {
                    type: 'blocked-upgrade' as const,
                    severity: 'medium' as const,
                    message: 'blocked by meta',
                    relatedPackage: 'meta',
                },
            ];
            const { actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'upgrade-blocker');
        });

        it('should suggest upgrade-family for family conflict', () => {
            const result = makeResult('firebase_core', 70);
            const problems = [
                {
                    type: 'family-conflict' as const,
                    severity: 'high' as const,
                    message: 'Firebase split',
                },
            ];
            const { actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'upgrade-family');
        });

        it('should suggest remove-override for stale override', () => {
            const result = makeResult('intl', 80);
            const problems = [
                { type: 'stale-override' as const, severity: 'low' as const, message: '' },
            ];
            const { actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'remove-override');
        });

        it('should suggest upgrade for risky transitive', () => {
            const result = makeResult('http', 70);
            const problems = [
                { type: 'risky-transitive' as const, severity: 'medium' as const, message: '2 risky' },
            ];
            const { action, actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'upgrade');
            assert.ok(action?.includes('safer transitive'));
        });

        it('should return none for no actionable problems', () => {
            const result = makeResult('pkg', 80);
            const problems: never[] = [];
            const { actionType } = determineSuggestedAction(problems, result);

            assert.strictEqual(actionType, 'none');
        });
    });

    describe('findUnlockedPackages', () => {
        it('should find packages blocked by this one', () => {
            const results = [
                makeResult('blocker', 50),
                makeResult('blocked', 60, {
                    blocker: {
                        blockedPackage: 'blocked',
                        currentVersion: '1.0.0',
                        latestVersion: '2.0.0',
                        blockerPackage: 'blocker',
                        blockerVibrancyScore: 50,
                        blockerCategory: 'quiet',
                    },
                }),
            ];
            const unlocked = findUnlockedPackages('blocker', results, []);

            assert.strictEqual(unlocked.length, 1);
            assert.strictEqual(unlocked[0], 'blocked');
        });

        it('should find overrides blocked by this package', () => {
            const results = [makeResult('http', 70)];
            const overrides = [makeOverride('intl', 'active', 'http')];
            const unlocked = findUnlockedPackages('http', results, overrides);

            assert.strictEqual(unlocked.length, 1);
            assert.ok(unlocked[0].includes('intl'));
        });
    });

    describe('consolidateInsights', () => {
        it('should return empty for healthy packages', () => {
            const results = [
                makeResult('good1', 85),
                makeResult('good2', 90),
            ];
            const insights = consolidateInsights(results, [], []);

            assert.strictEqual(insights.length, 0);
        });

        it('should return insights sorted by risk (highest first)', () => {
            const results = [
                makeResult('low', 35, { category: 'legacy-locked' }),
                makeResult('high', 5, { category: 'end-of-life', isUnused: true }),
                makeResult('medium', 25, { category: 'legacy-locked' }),
            ];
            const insights = consolidateInsights(results, [], []);

            assert.strictEqual(insights.length, 3);
            assert.strictEqual(insights[0].name, 'high');
            assert.ok(insights[0].combinedRiskScore > insights[1].combinedRiskScore);
        });

        it('should include override and split info', () => {
            const results = [makeResult('firebase_core', 70)];
            const overrides = [makeOverride('firebase_core', 'stale')];
            const splits = [makeSplit('firebase', [['firebase_core'], ['firebase_auth']])];

            const insights = consolidateInsights(results, overrides, splits);

            assert.strictEqual(insights.length, 1);
            const types = insights[0].problems.map(p => p.type);
            assert.ok(types.includes('stale-override'));
            assert.ok(types.includes('family-conflict'));
        });
    });
});

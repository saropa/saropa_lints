import * as assert from 'assert';
import { rankPackages, resultToComparisonData, isWinnerForDimension } from '../../../vibrancy/scoring/comparison-ranker';
import { ComparisonData, VibrancyCategory, DimensionWinner } from '../../../vibrancy/types';

function makePackage(overrides: Partial<ComparisonData>): ComparisonData {
    return {
        name: 'test-pkg',
        vibrancyScore: 75,
        category: 'vibrant',
        latestVersion: '1.0.0',
        publishedDate: '2026-01-15',
        publisher: null,
        pubPoints: 100,
        stars: 500,
        openIssues: 10,
        archiveSizeBytes: 100_000,
        bloatRating: 3,
        license: 'MIT',
        platforms: ['android', 'ios', 'web'],
        inProject: false,
        ...overrides,
    };
}

describe('comparison-ranker', () => {
    describe('rankPackages', () => {
        it('should return empty result for empty array', () => {
            const result = rankPackages([]);
            assert.strictEqual(result.packages.length, 0);
            assert.strictEqual(result.winners.length, 0);
            assert.ok(result.recommendation.includes('No packages'));
        });

        it('should identify clear winner for vibrancy score', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'http', vibrancyScore: 92 }),
                makePackage({ name: 'dio', vibrancyScore: 88 }),
                makePackage({ name: 'chopper', vibrancyScore: 54 }),
            ];

            const result = rankPackages(packages);

            const vibrancyWinner = result.winners.find(
                w => w.dimension === 'Vibrancy Score',
            );
            assert.ok(vibrancyWinner, 'Should have vibrancy winner');
            assert.strictEqual(vibrancyWinner.winnerName, 'http');
        });

        it('should identify smallest archive size as winner', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'small', archiveSizeBytes: 50_000 }),
                makePackage({ name: 'medium', archiveSizeBytes: 500_000 }),
                makePackage({ name: 'large', archiveSizeBytes: 5_000_000 }),
            ];

            const result = rankPackages(packages);

            const sizeWinner = result.winners.find(
                w => w.dimension === 'Archive Size',
            );
            assert.ok(sizeWinner, 'Should have size winner');
            assert.strictEqual(sizeWinner.winnerName, 'small');
        });

        it('should identify most stars as winner', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'popular', stars: 12000 }),
                makePackage({ name: 'normal', stars: 500 }),
            ];

            const result = rankPackages(packages);

            const starsWinner = result.winners.find(
                w => w.dimension === 'GitHub Stars',
            );
            assert.ok(starsWinner, 'Should have stars winner');
            assert.strictEqual(starsWinner.winnerName, 'popular');
        });

        it('should identify fewest open issues as winner', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'clean', openIssues: 5 }),
                makePackage({ name: 'messy', openIssues: 100 }),
            ];

            const result = rankPackages(packages);

            const issuesWinner = result.winners.find(
                w => w.dimension === 'Open Issues',
            );
            assert.ok(issuesWinner, 'Should have issues winner');
            assert.strictEqual(issuesWinner.winnerName, 'clean');
        });

        it('should handle null values gracefully', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'has-data', vibrancyScore: 80, stars: 1000 }),
                makePackage({ name: 'no-data', vibrancyScore: null, stars: null }),
            ];

            const result = rankPackages(packages);

            const vibrancyWinner = result.winners.find(
                w => w.dimension === 'Vibrancy Score',
            );
            assert.ok(vibrancyWinner === undefined || vibrancyWinner.winnerName === 'has-data');
        });

        it('should not declare winner when all values are equal', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'pkg1', vibrancyScore: 80 }),
                makePackage({ name: 'pkg2', vibrancyScore: 80 }),
            ];

            const result = rankPackages(packages);

            const vibrancyWinner = result.winners.find(
                w => w.dimension === 'Vibrancy Score',
            );
            assert.strictEqual(vibrancyWinner, undefined);
        });

        it('should generate recommendation mentioning top winner', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'best', vibrancyScore: 95, stars: 5000, pubPoints: 140 }),
                makePackage({ name: 'worst', vibrancyScore: 40, stars: 100, pubPoints: 80 }),
            ];

            const result = rankPackages(packages);

            assert.ok(result.recommendation.includes('best'));
            assert.ok(result.recommendation.includes('leads'));
        });

        it('should mention verified publisher in recommendation', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'official', publisher: 'dart.dev', vibrancyScore: 90 }),
                makePackage({ name: 'community', publisher: null, vibrancyScore: 85 }),
            ];

            const result = rankPackages(packages);

            assert.ok(result.recommendation.includes('dart.dev'));
        });

        it('should handle ties by listing first winner', () => {
            const packages: ComparisonData[] = [
                makePackage({ name: 'alpha', vibrancyScore: 90 }),
                makePackage({ name: 'beta', vibrancyScore: 90 }),
                makePackage({ name: 'gamma', vibrancyScore: 60 }),
            ];

            const result = rankPackages(packages);

            const vibrancyWinner = result.winners.find(
                w => w.dimension === 'Vibrancy Score',
            );
            assert.ok(vibrancyWinner);
            assert.ok(
                vibrancyWinner.winnerName.includes('alpha') ||
                vibrancyWinner.winnerName.includes('beta'),
            );
        });
    });

    describe('resultToComparisonData', () => {
        it('should convert VibrancyResult to ComparisonData', () => {
            const mockResult = {
                package: { name: 'test-package' },
                score: 85,
                category: 'vibrant' as VibrancyCategory,
                pubDev: {
                    publishedDate: '2026-01-15T10:00:00Z',
                    publisher: 'example.com',
                },
                github: { stars: 1500, openIssues: 25 },
                archiveSizeBytes: 250_000,
                bloatRating: 4,
                license: 'BSD-3-Clause',
                platforms: ['android', 'ios'],
                updateInfo: { latestVersion: '2.0.0' },
            };

            const data = resultToComparisonData(mockResult, true);

            assert.strictEqual(data.name, 'test-package');
            assert.strictEqual(data.vibrancyScore, 85);
            assert.strictEqual(data.category, 'vibrant');
            assert.strictEqual(data.stars, 1500);
            assert.strictEqual(data.openIssues, 25);
            assert.strictEqual(data.archiveSizeBytes, 250_000);
            assert.strictEqual(data.bloatRating, 4);
            assert.strictEqual(data.license, 'BSD-3-Clause');
            assert.strictEqual(data.inProject, true);
            assert.deepStrictEqual(data.platforms, ['android', 'ios']);
        });

        it('should handle null values in result', () => {
            const mockResult = {
                package: { name: 'minimal' },
                score: 50,
                category: 'stable' as VibrancyCategory,
                pubDev: null,
                github: null,
                archiveSizeBytes: null,
                bloatRating: null,
                license: null,
                platforms: null,
                updateInfo: null,
            };

            const data = resultToComparisonData(mockResult, false);

            assert.strictEqual(data.name, 'minimal');
            assert.strictEqual(data.vibrancyScore, 50);
            assert.strictEqual(data.stars, null);
            assert.strictEqual(data.openIssues, null);
            assert.strictEqual(data.archiveSizeBytes, null);
            assert.strictEqual(data.inProject, false);
            assert.deepStrictEqual(data.platforms, []);
        });

        it('should prefer trueOpenIssues over openIssues when available', () => {
            // trueOpenIssues excludes PRs from the count
            const mockResult = {
                package: { name: 'with-prs' },
                score: 80,
                category: 'vibrant' as VibrancyCategory,
                pubDev: null,
                github: { stars: 100, openIssues: 50, trueOpenIssues: 35 },
                archiveSizeBytes: null,
                bloatRating: null,
                license: null,
                platforms: null,
                updateInfo: null,
            };

            const data = resultToComparisonData(mockResult, false);

            // Should use trueOpenIssues (35) not openIssues (50)
            assert.strictEqual(data.openIssues, 35);
        });

        it('should fall back to openIssues when trueOpenIssues unavailable', () => {
            // When PR fetch fails, trueOpenIssues is undefined
            const mockResult = {
                package: { name: 'no-prs-data' },
                score: 80,
                category: 'vibrant' as VibrancyCategory,
                pubDev: null,
                github: { stars: 100, openIssues: 50 },
                archiveSizeBytes: null,
                bloatRating: null,
                license: null,
                platforms: null,
                updateInfo: null,
            };

            const data = resultToComparisonData(mockResult, false);

            // Should fall back to openIssues (50)
            assert.strictEqual(data.openIssues, 50);
        });

        it('should extract pubPoints from result', () => {
            const mockResult = {
                package: { name: 'with-points' },
                score: 80,
                category: 'vibrant' as VibrancyCategory,
                pubDev: {
                    publishedDate: '2026-01-15T10:00:00Z',
                    publisher: null,
                    pubPoints: 130,
                },
                github: null,
                archiveSizeBytes: null,
                bloatRating: null,
                license: null,
                platforms: null,
                updateInfo: null,
            };

            const data = resultToComparisonData(mockResult, true);

            assert.strictEqual(data.pubPoints, 130);
        });
    });

    describe('isWinnerForDimension', () => {
        it('should return true when package is the winner', () => {
            const winners: DimensionWinner[] = [
                {
                    dimension: 'Vibrancy Score',
                    winnerName: 'http',
                    value: '92/100',
                    allValues: [],
                },
            ];

            assert.strictEqual(isWinnerForDimension('http', 'Vibrancy Score', winners), true);
            assert.strictEqual(isWinnerForDimension('dio', 'Vibrancy Score', winners), false);
        });

        it('should return false for non-existent dimension', () => {
            const winners: DimensionWinner[] = [];

            assert.strictEqual(isWinnerForDimension('http', 'Vibrancy Score', winners), false);
        });

        it('should handle tied winners', () => {
            const winners: DimensionWinner[] = [
                {
                    dimension: 'Vibrancy Score',
                    winnerName: 'http, dio',
                    value: '90/100',
                    allValues: [],
                },
            ];

            assert.strictEqual(isWinnerForDimension('http', 'Vibrancy Score', winners), true);
            assert.strictEqual(isWinnerForDimension('dio', 'Vibrancy Score', winners), true);
            assert.strictEqual(isWinnerForDimension('chopper', 'Vibrancy Score', winners), false);
        });
    });
});

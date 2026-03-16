import * as assert from 'assert';
import {
    classifyStatus,
    categoryIcon,
    categoryToSeverity,
    categoryLabel,
} from '../../../vibrancy/scoring/status-classifier';

describe('status-classifier', () => {
    describe('classifyStatus', () => {
        it('should classify high scores as vibrant', () => {
            const cat = classifyStatus({ score: 75, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'vibrant');
        });

        it('should classify 40-69 as quiet', () => {
            const cat = classifyStatus({ score: 50, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'quiet');
        });

        it('should classify 10-39 as legacy-locked', () => {
            const cat = classifyStatus({ score: 25, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'legacy-locked');
        });

        // Score < 10 is now 'stale' (low maintenance), not 'end-of-life'
        it('should classify <10 as stale', () => {
            const cat = classifyStatus({ score: 5, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'stale');
        });

        it('should override with known issue', () => {
            const cat = classifyStatus({
                score: 90,
                knownIssue: {
                    name: 'pkg', status: 'end_of_life',
                    reason: 'bad', as_of: '2024-01-01',
                    replacement: undefined, migrationNotes: undefined,
                },
                pubDev: null,
            });
            assert.strictEqual(cat, 'end-of-life');
        });

        it('should override when discontinued', () => {
            const cat = classifyStatus({
                score: 90,
                knownIssue: null,
                pubDev: {
                    name: 'pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: true, isUnlisted: false,
                    pubPoints: 100,
                    publisher: null,
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'end-of-life');
        });

        it('should handle boundary at 70', () => {
            assert.strictEqual(
                classifyStatus({ score: 70, knownIssue: null, pubDev: null }),
                'vibrant',
            );
            assert.strictEqual(
                classifyStatus({ score: 69.9, knownIssue: null, pubDev: null }),
                'quiet',
            );
        });

        it('should handle boundary at 10 (legacy-locked vs stale)', () => {
            assert.strictEqual(
                classifyStatus({ score: 10, knownIssue: null, pubDev: null }),
                'legacy-locked',
            );
            assert.strictEqual(
                classifyStatus({ score: 9.9, knownIssue: null, pubDev: null }),
                'stale',
            );
        });

        it('should classify archived repos as end-of-life', () => {
            // Archived repos are end-of-life regardless of score
            const cat = classifyStatus({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: true,
            });
            assert.strictEqual(cat, 'end-of-life');
        });

        it('should not override when isArchived is false', () => {
            const cat = classifyStatus({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: false,
            });
            assert.strictEqual(cat, 'vibrant');
        });

        it('should not override when isArchived is undefined', () => {
            // When GitHub data is unavailable, isArchived is undefined
            const cat = classifyStatus({
                score: 90, knownIssue: null, pubDev: null,
                isArchived: undefined,
            });
            assert.strictEqual(cat, 'vibrant');
        });
    });

    describe('categoryIcon', () => {
        it('should map categories to icon ids', () => {
            assert.strictEqual(categoryIcon('vibrant'), 'pass');
            assert.strictEqual(categoryIcon('stale'), 'warning');
            assert.strictEqual(categoryIcon('end-of-life'), 'error');
        });
    });

    describe('categoryToSeverity', () => {
        it('should map end-of-life to Warning (1)', () => {
            assert.strictEqual(categoryToSeverity('end-of-life'), 1);
        });

        it('should map stale to Information (2)', () => {
            assert.strictEqual(categoryToSeverity('stale'), 2);
        });

        it('should map vibrant to Hint (3)', () => {
            assert.strictEqual(categoryToSeverity('vibrant'), 3);
        });
    });

    describe('categoryLabel', () => {
        it('should return human-readable labels', () => {
            assert.strictEqual(categoryLabel('legacy-locked'), 'Legacy-Locked');
            assert.strictEqual(categoryLabel('stale'), 'Stale');
        });
    });
});

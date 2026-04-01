import * as assert from 'assert';
import {
    classifyStatus,
    categoryIcon,
    categoryToSeverity,
    categoryLabel,
    categoryToGrade,
} from '../../../vibrancy/scoring/status-classifier';

describe('status-classifier', () => {
    describe('classifyStatus', () => {
        it('should classify high scores as vibrant', () => {
            const cat = classifyStatus({ score: 75, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'vibrant');
        });

        it('should classify 40-69 as stable', () => {
            const cat = classifyStatus({ score: 50, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'stable');
        });

        it('should classify 20-39 as outdated', () => {
            const cat = classifyStatus({ score: 25, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'outdated');
        });

        // Score < 20 is now 'abandoned' (low maintenance), not 'end-of-life'
        it('should classify <20 as abandoned', () => {
            const cat = classifyStatus({ score: 5, knownIssue: null, pubDev: null });
            assert.strictEqual(cat, 'abandoned');
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
                'stable',
            );
        });

        it('should handle boundary at 20 (outdated vs abandoned)', () => {
            assert.strictEqual(
                classifyStatus({ score: 20, knownIssue: null, pubDev: null }),
                'outdated',
            );
            assert.strictEqual(
                classifyStatus({ score: 19.9, knownIssue: null, pubDev: null }),
                'abandoned',
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

        it('should upgrade stable to vibrant for firebase.google.com (trusted publisher)', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: null,
                pubDev: {
                    name: 'firebase_core', latestVersion: '3.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 140,
                    publisher: 'firebase.google.com',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'vibrant');
        });

        it('should upgrade stable to vibrant for dart.dev (trusted publisher)', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: null,
                pubDev: {
                    name: 'test', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 140,
                    publisher: 'dart.dev',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'vibrant');
        });

        it('should keep stable when publisher is not trusted', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: null,
                pubDev: {
                    name: 'foo', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 80,
                    publisher: 'example.com',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'stable');
        });

        it('should not upgrade stable when publisher id casing does not match (false positive guard)', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: null,
                pubDev: {
                    name: 'test', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 140,
                    publisher: 'Dart.dev',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'stable');
        });

        it('should not upgrade trusted publisher when package is discontinued (EOL wins)', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: null,
                pubDev: {
                    name: 'legacy_pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: true, isUnlisted: false,
                    pubPoints: 140,
                    publisher: 'dart.dev',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'end-of-life');
        });

        it('should not override when known issue status is caution', () => {
            // 'caution' is informational — it should not force end-of-life
            const cat = classifyStatus({
                score: 50,
                knownIssue: {
                    name: 'pkg', status: 'caution',
                    reason: 'has issues', as_of: '2024-01-01',
                    replacement: undefined, migrationNotes: undefined,
                },
                pubDev: null,
            });
            assert.strictEqual(cat, 'stable');
        });

        it('should not override when known issue status is active', () => {
            // 'active' means the package has a known note but is still maintained
            const cat = classifyStatus({
                score: 50,
                knownIssue: {
                    name: 'pkg', status: 'active',
                    reason: 'maintained', as_of: '2024-01-01',
                    replacement: undefined, migrationNotes: undefined,
                },
                pubDev: null,
            });
            assert.strictEqual(cat, 'stable');
        });

        it('should apply pub points floor: abandoned with high points becomes outdated', () => {
            // A package with 150/160 pub points should not classify as 'abandoned'
            // even if its vibrancy score is very low (stable GitHub repo)
            const cat = classifyStatus({
                score: 5,
                knownIssue: null,
                pubDev: {
                    name: 'mature_pkg', latestVersion: '2.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 150,
                    publisher: null,
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'outdated');
        });

        it('should not apply pub points floor below 140 threshold', () => {
            // 130 pub points is below the 140 floor threshold
            const cat = classifyStatus({
                score: 5,
                knownIssue: null,
                pubDev: {
                    name: 'mediocre_pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 130,
                    publisher: null,
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'abandoned');
        });

        it('should not apply pub points floor when discontinued (EOL overrides)', () => {
            // Hard EOL override (discontinued) takes precedence over pub points floor
            const cat = classifyStatus({
                score: 5,
                knownIssue: null,
                pubDev: {
                    name: 'disc_pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: true, isUnlisted: false,
                    pubPoints: 160,
                    publisher: null,
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'end-of-life');
        });

        it('should not upgrade trusted publisher when known issue is end_of_life', () => {
            const cat = classifyStatus({
                score: 55,
                knownIssue: {
                    name: 'dead_pkg', status: 'end_of_life',
                    reason: 'replaced', as_of: '2024-01-01',
                    replacement: undefined, migrationNotes: undefined,
                },
                pubDev: {
                    name: 'dead_pkg', latestVersion: '1.0.0', publishedDate: '',
                    repositoryUrl: null, isDiscontinued: false, isUnlisted: false,
                    pubPoints: 140,
                    publisher: 'google.dev',
                    license: null,
                    description: null,
                    topics: [],
                },
            });
            assert.strictEqual(cat, 'end-of-life');
        });
    });

    describe('categoryIcon', () => {
        it('should map categories to icon ids', () => {
            assert.strictEqual(categoryIcon('vibrant'), 'pass');
            assert.strictEqual(categoryIcon('abandoned'), 'warning');
            assert.strictEqual(categoryIcon('end-of-life'), 'error');
        });
    });

    describe('categoryToSeverity', () => {
        it('should map end-of-life to Warning (1)', () => {
            assert.strictEqual(categoryToSeverity('end-of-life'), 1);
        });

        it('should map abandoned to Information (2)', () => {
            assert.strictEqual(categoryToSeverity('abandoned'), 2);
        });

        it('should map vibrant to Hint (3)', () => {
            assert.strictEqual(categoryToSeverity('vibrant'), 3);
        });
    });

    describe('categoryLabel', () => {
        it('should return human-readable labels', () => {
            assert.strictEqual(categoryLabel('outdated'), 'Outdated');
            assert.strictEqual(categoryLabel('abandoned'), 'Abandoned');
        });
    });

    describe('categoryToGrade', () => {
        it('should map categories to A (best) … E (abandoned) … F (dangerous)', () => {
            assert.strictEqual(categoryToGrade('vibrant'), 'A');
            assert.strictEqual(categoryToGrade('stable'), 'B');
            assert.strictEqual(categoryToGrade('outdated'), 'C');
            assert.strictEqual(categoryToGrade('abandoned'), 'E');
            assert.strictEqual(categoryToGrade('end-of-life'), 'F');
        });
    });
});

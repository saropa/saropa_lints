import * as assert from 'assert';
import {
    detectIssueSignals,
    flagHighSignalIssues,
    RawOpenIssue,
} from '../../../vibrancy/scoring/issue-signals';

describe('issue-signals', () => {
    describe('detectIssueSignals', () => {
        it('should detect deprecated keyword', () => {
            const signals = detectIssueSignals('This API is deprecated', []);
            assert.ok(signals.includes('deprecated'));
        });

        it('should detect obsolete keyword', () => {
            const signals = detectIssueSignals(
                'Warning about obsolete java version (8)', [],
            );
            assert.ok(signals.includes('obsolete'));
            assert.ok(signals.includes('java version'));
        });

        it('should detect multiple signals in one title', () => {
            const signals = detectIssueSignals(
                'Build fails with Dart 3.5 - breaking change', [],
            );
            assert.ok(signals.includes('build failure'));
            assert.ok(signals.includes('dart version'));
            assert.ok(signals.includes('breaking change'));
        });

        it('should be case insensitive', () => {
            const signals = detectIssueSignals('DEPRECATED API', []);
            assert.ok(signals.includes('deprecated'));
        });

        it('should return empty array for non-signal titles', () => {
            const signals = detectIssueSignals(
                'Add dark mode support', [],
            );
            assert.deepStrictEqual(signals, []);
        });

        it('should detect signal labels', () => {
            const signals = detectIssueSignals('Some issue', ['breaking-change']);
            assert.ok(signals.includes('label:breaking-change'));
        });

        it('should detect labels case-insensitively', () => {
            const signals = detectIssueSignals('Some issue', ['Critical']);
            assert.ok(signals.includes('label:critical'));
        });

        it('should deduplicate signals', () => {
            const signals = detectIssueSignals(
                'deprecated deprecated deprecated', [],
            );
            const count = signals.filter(s => s === 'deprecated').length;
            assert.strictEqual(count, 1);
        });

        it('should detect crash signal', () => {
            const signals = detectIssueSignals(
                'App crashes on startup', [],
            );
            assert.ok(signals.includes('crash'));
        });

        it('should detect memory leak signal', () => {
            const signals = detectIssueSignals(
                'Memory leak in background service', [],
            );
            assert.ok(signals.includes('memory leak'));
        });

        it('should detect null safety signal', () => {
            const signals = detectIssueSignals(
                'Package lacks null-safety support', [],
            );
            assert.ok(signals.includes('null safety'));
        });

        it('should detect gradle signal', () => {
            const signals = detectIssueSignals(
                'Incompatible with gradle 8.5', [],
            );
            assert.ok(signals.includes('gradle'));
            assert.ok(signals.includes('incompatible'));
        });

        it('should detect impeller signal', () => {
            const signals = detectIssueSignals(
                'Rendering broken on Impeller', [],
            );
            assert.ok(signals.includes('impeller'));
        });
    });

    describe('flagHighSignalIssues', () => {
        const repoUrl = 'https://github.com/test/repo';

        it('should flag issues with signal keywords', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 60,
                    title: 'Warning about obsolete java version (8)',
                    labels: [{ name: 'bug' }],
                    comments: 12,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(flagged.length, 1);
            assert.strictEqual(flagged[0].number, 60);
            assert.ok(flagged[0].matchedSignals.includes('obsolete'));
            assert.ok(flagged[0].matchedSignals.includes('java version'));
        });

        it('should skip non-signal issues', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 61,
                    title: 'Add dark mode support',
                    labels: [{ name: 'enhancement' }],
                    comments: 8,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(flagged.length, 0);
        });

        it('should construct correct URL', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 42,
                    title: 'App crashes on load',
                    labels: [],
                    comments: 3,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(
                flagged[0].url,
                'https://github.com/test/repo/issues/42',
            );
        });

        it('should return empty array for empty input', () => {
            const flagged = flagHighSignalIssues([], repoUrl);
            assert.deepStrictEqual(flagged, []);
        });

        it('should handle mixed label formats', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 70,
                    title: 'Minor issue',
                    labels: ['breaking-change'],
                    comments: 2,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(flagged.length, 1);
            assert.ok(
                flagged[0].matchedSignals.includes('label:breaking-change'),
            );
        });

        it('should preserve comment count', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 99,
                    title: 'deprecated method',
                    labels: [],
                    comments: 42,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(flagged[0].commentCount, 42);
        });

        it('should filter from mixed set correctly', () => {
            const issues: RawOpenIssue[] = [
                {
                    number: 1, title: 'deprecated API',
                    labels: [], comments: 5,
                },
                {
                    number: 2, title: 'Add feature X',
                    labels: [], comments: 10,
                },
                {
                    number: 3, title: 'Build fails on Dart 3',
                    labels: [], comments: 20,
                },
                {
                    number: 4, title: 'Update readme',
                    labels: [], comments: 1,
                },
            ];
            const flagged = flagHighSignalIssues(issues, repoUrl);
            assert.strictEqual(flagged.length, 2);
            assert.strictEqual(flagged[0].number, 1);
            assert.strictEqual(flagged[1].number, 3);
        });
    });
});

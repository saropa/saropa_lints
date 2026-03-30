import * as assert from 'assert';
import {
    formatCodeLensTitle, categoryEmoji,
} from '../../../vibrancy/scoring/codelens-formatter';
import { VibrancyResult } from '../../../vibrancy/types';

function makeResult(overrides: Partial<VibrancyResult> = {}): VibrancyResult {
    return {
        package: { name: 'http', version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score: 85,
        category: 'vibrant',
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 60,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        isUnused: false, platforms: null, verifiedPublisher: false, wasmReady: null, blocker: null, upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null, alternatives: [], latestPrerelease: null, prereleaseTag: null,
        vulnerabilities: [],
        ...overrides,
    };
}

describe('categoryEmoji', () => {
    it('should return green for vibrant', () => {
        assert.strictEqual(categoryEmoji('vibrant'), '🟢');
    });

    it('should return yellow for quiet', () => {
        assert.strictEqual(categoryEmoji('quiet'), '🟡');
    });

    it('should return orange for legacy-locked', () => {
        assert.strictEqual(categoryEmoji('legacy-locked'), '🟠');
    });

    it('should return orange for stale', () => {
        assert.strictEqual(categoryEmoji('stale'), '🟠');
    });

    it('should return red for end-of-life', () => {
        assert.strictEqual(categoryEmoji('end-of-life'), '🔴');
    });
});

describe('formatCodeLensTitle', () => {
    describe('minimal detail', () => {
        it('should show only score and category', () => {
            const result = makeResult({ score: 85 });
            const title = formatCodeLensTitle(result, 'minimal');
            assert.strictEqual(title, '🟢 9/10 Vibrant');
        });

        it('should not include update info', () => {
            const result = makeResult({
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    updateStatus: 'major',
                    changelog: null,
                },
            });
            const title = formatCodeLensTitle(result, 'minimal');
            assert.ok(!title.includes('⬆'));
        });
    });

    describe('standard detail', () => {
        it('should include up-to-date when no update', () => {
            const title = formatCodeLensTitle(makeResult(), 'standard');
            assert.ok(title.includes('✓ Up to date'));
        });

        it('should include update info when available', () => {
            const result = makeResult({
                updateInfo: {
                    currentVersion: '1.0.0',
                    latestVersion: '2.0.0',
                    updateStatus: 'major',
                    changelog: null,
                },
            });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(title.includes('⬆ 1.0.0 → 2.0.0 (major)'));
        });

        it('should not include archive size', () => {
            const result = makeResult({ archiveSizeBytes: 1_048_576 });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(!title.includes('MB'));
        });

        it('should include known issue replacement alert', () => {
            const result = makeResult({
                knownIssue: {
                    name: 'old_pkg', status: 'end_of_life',
                    replacement: 'new_pkg',
                },
            });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(title.includes('⚠ Replace with new_pkg'));
        });

        it('should include generic known issue alert', () => {
            const result = makeResult({
                knownIssue: {
                    name: 'old_pkg', status: 'deprecated',
                    reason: 'No longer maintained',
                },
            });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(title.includes('⚠ Known issue'));
        });

        it('should show Consider for instruction-style replacement', () => {
            const result = makeResult({
                knownIssue: {
                    name: 'old_pkg', status: 'end_of_life',
                    replacement: 'Update to v9+',
                },
            });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(title.includes('Consider: Update to v9+'));
        });

        it('should include unused warning', () => {
            const result = makeResult({ isUnused: true });
            const title = formatCodeLensTitle(result, 'standard');
            assert.ok(title.includes('Unused'));
        });
    });

    describe('full detail', () => {
        it('should include archive size when available', () => {
            const result = makeResult({ archiveSizeBytes: 1_048_576 });
            const title = formatCodeLensTitle(result, 'full');
            assert.ok(title.includes('1.0 MB'));
        });

        it('should skip archive size when null', () => {
            const result = makeResult({ archiveSizeBytes: null });
            const title = formatCodeLensTitle(result, 'full');
            assert.ok(!title.includes('MB'));
        });
    });

    describe('score rounding', () => {
        it('should round score to nearest integer', () => {
            const result = makeResult({ score: 45 });
            const title = formatCodeLensTitle(result, 'minimal');
            assert.ok(title.includes('5/10'));
        });

        it('should show 0 for very low scores', () => {
            const result = makeResult({ score: 3, category: 'end-of-life' });
            const title = formatCodeLensTitle(result, 'minimal');
            assert.ok(title.includes('0/10'));
        });

        it('should show 10 for perfect scores', () => {
            const result = makeResult({ score: 100 });
            const title = formatCodeLensTitle(result, 'minimal');
            assert.ok(title.includes('10/10'));
        });
    });

    describe('segment ordering', () => {
        it('should join segments with middle dot', () => {
            const result = makeResult({ isUnused: true });
            const title = formatCodeLensTitle(result, 'standard');
            const segments = title.split(' · ');
            assert.ok(segments.length >= 3);
            assert.ok(segments[0].includes('Vibrant'));
            assert.ok(segments.some(s => s.includes('Up to date')));
            assert.ok(segments.some(s => s.includes('Unused')));
        });
    });
});

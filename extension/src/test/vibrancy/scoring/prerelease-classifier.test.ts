import * as assert from 'assert';
import {
    isPrerelease,
    getPrereleaseTag,
    findLatestPrerelease,
    findLatestStable,
    filterByTags,
    isPrereleaseNewerThanStable,
    getPrereleaseTier,
    formatPrereleaseTag,
    extractPrereleaseInfo,
} from '../../../vibrancy/scoring/prerelease-classifier';

describe('prerelease-classifier', () => {
    describe('isPrerelease', () => {
        it('should detect dev prereleases', () => {
            assert.strictEqual(isPrerelease('2.0.0-dev.1'), true);
        });

        it('should detect beta prereleases', () => {
            assert.strictEqual(isPrerelease('2.0.0-beta.1'), true);
        });

        it('should detect rc prereleases', () => {
            assert.strictEqual(isPrerelease('2.0.0-rc.1'), true);
        });

        it('should detect alpha prereleases', () => {
            assert.strictEqual(isPrerelease('2.0.0-alpha'), true);
        });

        it('should detect nullsafety prereleases', () => {
            assert.strictEqual(isPrerelease('2.0.0-nullsafety.0'), true);
        });

        it('should return false for stable versions', () => {
            assert.strictEqual(isPrerelease('2.0.0'), false);
            assert.strictEqual(isPrerelease('1.0.0'), false);
            assert.strictEqual(isPrerelease('0.1.0'), false);
        });

        it('should handle invalid versions', () => {
            assert.strictEqual(isPrerelease('not-a-version'), false);
        });
    });

    describe('getPrereleaseTag', () => {
        it('should extract dev tag', () => {
            assert.strictEqual(getPrereleaseTag('2.0.0-dev.1'), 'dev');
        });

        it('should extract beta tag', () => {
            assert.strictEqual(getPrereleaseTag('2.0.0-beta.2'), 'beta');
        });

        it('should extract rc tag', () => {
            assert.strictEqual(getPrereleaseTag('2.0.0-rc.1'), 'rc');
        });

        it('should extract alpha tag', () => {
            assert.strictEqual(getPrereleaseTag('2.0.0-alpha'), 'alpha');
        });

        it('should return null for stable versions', () => {
            assert.strictEqual(getPrereleaseTag('2.0.0'), null);
        });
    });

    describe('findLatestPrerelease', () => {
        it('should find the latest prerelease', () => {
            const versions = [
                '1.0.0',
                '2.0.0-dev.1',
                '2.0.0-dev.2',
                '2.0.0-beta.1',
            ];
            // semver sorts alphabetically: dev > beta because d > b
            assert.strictEqual(findLatestPrerelease(versions), '2.0.0-dev.2');
        });

        it('should return null if no prereleases', () => {
            const versions = ['1.0.0', '2.0.0'];
            assert.strictEqual(findLatestPrerelease(versions), null);
        });

        it('should handle empty list', () => {
            assert.strictEqual(findLatestPrerelease([]), null);
        });
    });

    describe('findLatestStable', () => {
        it('should find the latest stable version', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '2.1.0-dev.1',
            ];
            assert.strictEqual(findLatestStable(versions), '2.0.0');
        });

        it('should return null if only prereleases', () => {
            const versions = ['1.0.0-dev.1', '2.0.0-beta.1'];
            assert.strictEqual(findLatestStable(versions), null);
        });
    });

    describe('filterByTags', () => {
        const versions = [
            '2.0.0-dev.1',
            '2.0.0-beta.1',
            '2.0.0-rc.1',
            '2.0.0-alpha.1',
        ];

        it('should filter by single tag', () => {
            const filtered = filterByTags(versions, ['beta']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1']);
        });

        it('should filter by multiple tags', () => {
            const filtered = filterByTags(versions, ['beta', 'rc']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1', '2.0.0-rc.1']);
        });

        it('should return all prereleases if tags empty', () => {
            const filtered = filterByTags(versions, []);
            assert.deepStrictEqual(filtered, versions);
        });

        it('should be case-insensitive', () => {
            const filtered = filterByTags(versions, ['BETA', 'RC']);
            assert.deepStrictEqual(filtered, ['2.0.0-beta.1', '2.0.0-rc.1']);
        });
    });

    describe('isPrereleaseNewerThanStable', () => {
        it('should return true when prerelease is newer', () => {
            assert.strictEqual(
                isPrereleaseNewerThanStable('2.1.0-dev.1', '2.0.0'),
                true,
            );
        });

        it('should return false when prerelease is older', () => {
            assert.strictEqual(
                isPrereleaseNewerThanStable('2.0.0-dev.1', '2.0.0'),
                false,
            );
        });

        it('should return true for prerelease of same base version', () => {
            assert.strictEqual(
                isPrereleaseNewerThanStable('3.0.0-rc.1', '2.0.0'),
                true,
            );
        });
    });

    describe('getPrereleaseTier', () => {
        it('should classify alpha', () => {
            assert.strictEqual(getPrereleaseTier('alpha'), 'alpha');
        });

        it('should classify dev', () => {
            assert.strictEqual(getPrereleaseTier('dev'), 'dev');
        });

        it('should classify beta', () => {
            assert.strictEqual(getPrereleaseTier('beta'), 'beta');
        });

        it('should classify rc', () => {
            assert.strictEqual(getPrereleaseTier('rc'), 'rc');
        });

        it('should classify rc variants', () => {
            assert.strictEqual(getPrereleaseTier('rc1'), 'rc');
        });

        it('should classify nullsafety as beta', () => {
            assert.strictEqual(getPrereleaseTier('nullsafety'), 'beta');
        });

        it('should classify unknown as other', () => {
            assert.strictEqual(getPrereleaseTier('custom'), 'other');
        });

        it('should handle null', () => {
            assert.strictEqual(getPrereleaseTier(null), 'other');
        });
    });

    describe('formatPrereleaseTag', () => {
        it('should format alpha', () => {
            assert.strictEqual(formatPrereleaseTag('alpha'), 'Alpha');
        });

        it('should format dev', () => {
            assert.strictEqual(formatPrereleaseTag('dev'), 'Dev');
        });

        it('should format beta', () => {
            assert.strictEqual(formatPrereleaseTag('beta'), 'Beta');
        });

        it('should format rc', () => {
            assert.strictEqual(formatPrereleaseTag('rc'), 'RC');
        });

        it('should return original for unknown tags', () => {
            assert.strictEqual(formatPrereleaseTag('custom'), 'custom');
        });

        it('should handle null', () => {
            assert.strictEqual(formatPrereleaseTag(null), 'prerelease');
        });
    });

    describe('extractPrereleaseInfo', () => {
        it('should extract prerelease info when newer than stable', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '2.1.0-dev.1',
            ];
            const info = extractPrereleaseInfo(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, '2.1.0-dev.1');
            assert.strictEqual(info.prereleaseTag, 'dev');
            assert.strictEqual(info.hasNewerPrerelease, true);
        });

        it('should return null prerelease when stable is newer', () => {
            const versions = [
                '1.0.0',
                '2.0.0',
                '1.5.0-dev.1',
            ];
            const info = extractPrereleaseInfo(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, null);
            assert.strictEqual(info.prereleaseTag, null);
            assert.strictEqual(info.hasNewerPrerelease, false);
        });

        it('should handle only prereleases', () => {
            const versions = [
                '1.0.0-dev.1',
                '1.0.0-beta.1',
            ];
            const info = extractPrereleaseInfo(versions);
            assert.strictEqual(info.latestStable, null);
            // semver sorts alphabetically: dev > beta because d > b
            assert.strictEqual(info.latestPrerelease, '1.0.0-dev.1');
            assert.strictEqual(info.prereleaseTag, 'dev');
            assert.strictEqual(info.hasNewerPrerelease, true);
        });

        it('should handle empty list', () => {
            const info = extractPrereleaseInfo([]);
            assert.strictEqual(info.latestStable, null);
            assert.strictEqual(info.latestPrerelease, null);
            assert.strictEqual(info.prereleaseTag, null);
            assert.strictEqual(info.hasNewerPrerelease, false);
        });

        it('should filter invalid versions', () => {
            const versions = [
                '2.0.0',
                'not-a-version',
                '3.0.0-dev.1',
            ];
            const info = extractPrereleaseInfo(versions);
            assert.strictEqual(info.latestStable, '2.0.0');
            assert.strictEqual(info.latestPrerelease, '3.0.0-dev.1');
        });
    });
});

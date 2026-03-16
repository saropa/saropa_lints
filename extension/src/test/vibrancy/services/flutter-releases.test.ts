import * as assert from 'assert';
import { parseStableReleases } from '../../../vibrancy/services/flutter-releases';

describe('flutter-releases', () => {
    describe('parseStableReleases', () => {
        it('should filter to stable channel only', () => {
            const json = {
                releases: [
                    { version: '3.24.0', release_date: '2024-08-01', channel: 'stable' },
                    { version: '3.25.0-dev', release_date: '2024-09-01', channel: 'dev' },
                    { version: '3.24.1', release_date: '2024-08-15', channel: 'stable' },
                    { version: '3.25.0-beta', release_date: '2024-09-10', channel: 'beta' },
                ],
            };
            const releases = parseStableReleases(json);
            assert.strictEqual(releases.length, 2);
            assert.ok(releases.every(r => !r.version.includes('dev')));
            assert.ok(releases.every(r => !r.version.includes('beta')));
        });

        it('should sort newest first', () => {
            const json = {
                releases: [
                    { version: '3.22.0', release_date: '2024-06-01', channel: 'stable' },
                    { version: '3.24.0', release_date: '2024-08-01', channel: 'stable' },
                    { version: '3.19.0', release_date: '2024-03-01', channel: 'stable' },
                ],
            };
            const releases = parseStableReleases(json);
            assert.strictEqual(releases[0].version, '3.24.0');
            assert.strictEqual(releases[2].version, '3.19.0');
        });

        it('should return empty for missing releases array', () => {
            assert.deepStrictEqual(parseStableReleases({}), []);
        });

        it('should return empty for null input', () => {
            assert.deepStrictEqual(parseStableReleases(null), []);
        });

        it('should extract version and releaseDate', () => {
            const json = {
                releases: [
                    { version: '3.24.0', release_date: '2024-08-01T00:00:00Z', channel: 'stable' },
                ],
            };
            const releases = parseStableReleases(json);
            assert.strictEqual(releases[0].version, '3.24.0');
            assert.strictEqual(releases[0].releaseDate, '2024-08-01T00:00:00Z');
        });
    });
});

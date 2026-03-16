import * as assert from 'assert';
import { calcDrift, driftLabel } from '../../../vibrancy/scoring/drift-calculator';
import { FlutterRelease } from '../../../vibrancy/services/flutter-releases';

const RELEASES: FlutterRelease[] = [
    { version: '3.27.0', releaseDate: '2025-02-01' },
    { version: '3.24.0', releaseDate: '2024-08-01' },
    { version: '3.22.0', releaseDate: '2024-05-01' },
    { version: '3.19.0', releaseDate: '2024-02-01' },
    { version: '3.16.0', releaseDate: '2023-11-01' },
    { version: '3.13.0', releaseDate: '2023-08-01' },
    { version: '3.10.0', releaseDate: '2023-05-01' },
    { version: '3.7.0', releaseDate: '2023-02-01' },
];

describe('drift-calculator', () => {
    describe('calcDrift', () => {
        it('should return 0 behind for recent publish', () => {
            const result = calcDrift('2025-03-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 0);
            assert.strictEqual(result?.label, 'current');
            assert.strictEqual(result?.driftScore, 10);
        });

        it('should count releases after publish date', () => {
            const result = calcDrift('2024-06-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 2);
            assert.strictEqual(result?.label, 'recent');
        });

        it('should return drifting for 3-5 releases behind', () => {
            const result = calcDrift('2024-01-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 4);
            assert.strictEqual(result?.label, 'drifting');
            assert.strictEqual(result?.driftScore, 4);
        });

        it('should return stale for 6 releases behind', () => {
            const result = calcDrift('2023-07-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 6);
            assert.strictEqual(result?.label, 'stale');
            assert.strictEqual(result?.driftScore, 2);
        });

        it('should return abandoned for 7+ releases behind', () => {
            const result = calcDrift('2022-01-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 8);
            assert.strictEqual(result?.label, 'abandoned');
            assert.strictEqual(result?.driftScore, 0);
        });

        it('should return null for null publish date', () => {
            assert.strictEqual(calcDrift(null, RELEASES), null);
        });

        it('should return null for empty releases', () => {
            assert.strictEqual(calcDrift('2025-01-01', []), null);
        });

        it('should return null for invalid date', () => {
            assert.strictEqual(calcDrift('not-a-date', RELEASES), null);
        });

        it('should include latest flutter version', () => {
            const result = calcDrift('2025-03-01', RELEASES);
            assert.strictEqual(result?.latestFlutterVersion, '3.27.0');
        });

        it('should handle publish on same day as release', () => {
            const result = calcDrift('2025-02-01', RELEASES);
            assert.strictEqual(result?.releasesBehind, 0);
        });
    });

    describe('driftLabel', () => {
        it('should return current for 0', () => {
            assert.strictEqual(driftLabel(0), 'current');
        });

        it('should return recent for 1-2', () => {
            assert.strictEqual(driftLabel(1), 'recent');
            assert.strictEqual(driftLabel(2), 'recent');
        });

        it('should return drifting for 3-5', () => {
            assert.strictEqual(driftLabel(3), 'drifting');
            assert.strictEqual(driftLabel(5), 'drifting');
        });

        it('should return stale for 6', () => {
            assert.strictEqual(driftLabel(6), 'stale');
        });

        it('should return abandoned for 7+', () => {
            assert.strictEqual(driftLabel(7), 'abandoned');
            assert.strictEqual(driftLabel(10), 'abandoned');
        });
    });
});

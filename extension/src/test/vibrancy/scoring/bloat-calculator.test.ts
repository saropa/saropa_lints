import * as assert from 'assert';
import { calcBloatRating, formatSizeMB } from '../../../vibrancy/scoring/bloat-calculator';

describe('bloat-calculator', () => {
    describe('calcBloatRating', () => {
        it('should return 0 for zero bytes', () => {
            assert.strictEqual(calcBloatRating(0), 0);
        });

        it('should return 0 for negative bytes', () => {
            assert.strictEqual(calcBloatRating(-100), 0);
        });

        it('should return 0 for tiny packages under 50 KB', () => {
            assert.strictEqual(calcBloatRating(10_000), 0);
        });

        it('should return low rating for small packages around 100 KB', () => {
            const rating = calcBloatRating(100_000);
            assert.ok(rating >= 1 && rating <= 2, `expected 1-2, got ${rating}`);
        });

        it('should return medium rating for ~1 MB packages', () => {
            const rating = calcBloatRating(1_048_576);
            assert.ok(rating >= 4 && rating <= 5, `expected 4-5, got ${rating}`);
        });

        it('should return high rating for ~10 MB packages', () => {
            const rating = calcBloatRating(10_485_760);
            assert.ok(rating >= 7 && rating <= 8, `expected 7-8, got ${rating}`);
        });

        it('should return 10 for very large packages over 50 MB', () => {
            assert.strictEqual(calcBloatRating(52_428_800), 10);
        });

        it('should clamp at 10 for extremely large packages', () => {
            assert.strictEqual(calcBloatRating(500_000_000), 10);
        });

        it('should return 0 for a 1-byte archive', () => {
            assert.strictEqual(calcBloatRating(1), 0);
        });
    });

    describe('formatSizeMB', () => {
        it('should show <0.01 MB for very small sizes', () => {
            assert.strictEqual(formatSizeMB(5_000), '<0.01 MB');
        });

        it('should show one decimal place at exactly 1 MB', () => {
            assert.strictEqual(formatSizeMB(1_048_576), '1.0 MB');
        });

        it('should show two decimal places for sub-MB sizes', () => {
            assert.strictEqual(formatSizeMB(317_440), '0.30 MB');
        });

        it('should show one decimal place for MB+ sizes', () => {
            assert.strictEqual(formatSizeMB(2_621_440), '2.5 MB');
        });

        it('should show one decimal place for large sizes', () => {
            assert.strictEqual(formatSizeMB(52_428_800), '50.0 MB');
        });
    });
});

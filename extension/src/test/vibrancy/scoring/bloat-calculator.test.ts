/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import { calcBloatRating, formatSizeMB, formatSizeKB } from '../../../vibrancy/scoring/bloat-calculator';

describe('bloat-calculator', () => {
    describe('calcBloatRating (code-size scale)', () => {
        /* Anchors: 0 = tiny (<10 KB), 4 ≈ 250 KB, 10 = huge (>10 MB).
           These are tighter than the old tarball-size thresholds because
           example/, test/, tool/, doc/ no longer count — a 1 MB of pure
           lib/ code really is high bloat for a Flutter package. */
        it('returns 0 for zero bytes', () => {
            assert.strictEqual(calcBloatRating(0), 0);
        });

        it('returns 0 for negative bytes', () => {
            assert.strictEqual(calcBloatRating(-100), 0);
        });

        it('returns 0 for tiny code (≤10 KB)', () => {
            assert.strictEqual(calcBloatRating(10_000), 0);
        });

        it('rates 100 KB of code as 3 (low-medium)', () => {
            /* log10(100000)=5.0 → (5.0-4.0)/0.3 = 3.33 → 3 */
            assert.strictEqual(calcBloatRating(100_000), 3);
        });

        it('rates 250 KB of code around the medium anchor (~4)', () => {
            const rating = calcBloatRating(250_000);
            assert.ok(rating >= 4 && rating <= 5, `expected 4-5, got ${rating}`);
        });

        it('rates 1 MB of code as high (~7)', () => {
            const rating = calcBloatRating(1_048_576);
            assert.ok(rating >= 6 && rating <= 7, `expected 6-7, got ${rating}`);
        });

        it('returns 10 for 10 MB+ of code', () => {
            assert.strictEqual(calcBloatRating(10_485_760), 10);
        });

        it('returns 10 for very large code sizes', () => {
            assert.strictEqual(calcBloatRating(50_000_000), 10);
        });

        it('returns 0 for a 1-byte input', () => {
            assert.strictEqual(calcBloatRating(1), 0);
        });
    });

    describe('audioplayers shape — the bug that drove the rescaling', () => {
        /* The bug report case: audioplayers ships 21.7 MB on disk but only
           ~40 KB of lib/ reaches the user's app. Old model rated it 9/10
           bloat; new model on codeSizeBytes rates it under 2. */
        it('rates ~40 KB of code as low (≤2), not the old archive-size 9', () => {
            const lib40kb = 40 * 1024;
            const rating = calcBloatRating(lib40kb);
            assert.ok(rating <= 2, `expected ≤2 for 40 KB of code, got ${rating}`);
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

    describe('formatSizeKB', () => {
        it('should format bytes as KB with rounding', () => {
            /* 276480 / 1024 = 270 */
            assert.strictEqual(formatSizeKB(276_480), '270 KB');
        });

        it('should use comma grouping for large values', () => {
            /* 3,670,016 / 1024 = 3,584 */
            assert.strictEqual(formatSizeKB(3_670_016), '3,584 KB');
        });

        it('should round to nearest KB', () => {
            /* 1500 / 1024 ≈ 1.46 → rounds to 1 */
            assert.strictEqual(formatSizeKB(1_500), '1 KB');
        });

        it('should return 0 KB for zero bytes', () => {
            assert.strictEqual(formatSizeKB(0), '0 KB');
        });
    });
});

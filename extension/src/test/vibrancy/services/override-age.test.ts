import * as assert from 'assert';
import { calculateAgeDays, formatAge } from '../../../vibrancy/services/override-age';

describe('override-age', () => {
    describe('calculateAgeDays', () => {
        it('should return null for null date', () => {
            assert.strictEqual(calculateAgeDays(null), null);
        });

        it('should calculate days since a past date', () => {
            const oneWeekAgo = new Date();
            oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
            const days = calculateAgeDays(oneWeekAgo);
            assert.ok(days !== null);
            assert.ok(days >= 6 && days <= 8);
        });

        it('should return 0 for today', () => {
            const today = new Date();
            const days = calculateAgeDays(today);
            assert.ok(days !== null);
            assert.ok(days >= 0 && days <= 1);
        });
    });

    describe('formatAge', () => {
        it('should return "unknown age" for null', () => {
            assert.strictEqual(formatAge(null), 'unknown age');
        });

        it('should format days for less than a week', () => {
            assert.strictEqual(formatAge(1), '1 day');
            assert.strictEqual(formatAge(3), '3 days');
            assert.strictEqual(formatAge(6), '6 days');
        });

        it('should format weeks for 7-29 days', () => {
            assert.strictEqual(formatAge(7), '1 week');
            assert.strictEqual(formatAge(14), '2 weeks');
            assert.strictEqual(formatAge(21), '3 weeks');
        });

        it('should format months for 30-364 days', () => {
            assert.strictEqual(formatAge(30), '1 month');
            assert.strictEqual(formatAge(60), '2 months');
            assert.strictEqual(formatAge(180), '6 months');
        });

        it('should format years for 365+ days', () => {
            assert.strictEqual(formatAge(365), '1 year');
            assert.strictEqual(formatAge(730), '2 years');
        });
    });
});

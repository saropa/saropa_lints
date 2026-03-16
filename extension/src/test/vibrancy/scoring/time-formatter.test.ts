import * as assert from 'assert';
import { formatRelativeTime } from '../../../vibrancy/scoring/time-formatter';

describe('time-formatter', () => {
    describe('formatRelativeTime', () => {
        it('should return "today" for 0 days', () => {
            assert.strictEqual(formatRelativeTime(0), 'today');
        });

        it('should return "yesterday" for 1 day', () => {
            assert.strictEqual(formatRelativeTime(1), 'yesterday');
        });

        it('should return days for 2-29', () => {
            assert.strictEqual(formatRelativeTime(2), '2 days ago');
            assert.strictEqual(formatRelativeTime(15), '15 days ago');
            assert.strictEqual(formatRelativeTime(29), '29 days ago');
        });

        it('should return "1 month ago" for 30-59 days', () => {
            assert.strictEqual(formatRelativeTime(30), '1 month ago');
            assert.strictEqual(formatRelativeTime(59), '1 month ago');
        });

        it('should return months for 60-364 days', () => {
            assert.strictEqual(formatRelativeTime(60), '2 months ago');
            assert.strictEqual(formatRelativeTime(150), '5 months ago');
            assert.strictEqual(formatRelativeTime(364), '12 months ago');
        });

        it('should return "1 year ago" for 365-729 days', () => {
            assert.strictEqual(formatRelativeTime(365), '1 year ago');
            assert.strictEqual(formatRelativeTime(729), '1 year ago');
        });

        it('should return years for 730+ days', () => {
            assert.strictEqual(formatRelativeTime(730), '2 years ago');
            assert.strictEqual(formatRelativeTime(1095), '3 years ago');
        });

        it('should clamp negative days to "today"', () => {
            // Negative days can occur from clock skew or bad data
            assert.strictEqual(formatRelativeTime(-1), 'today');
            assert.strictEqual(formatRelativeTime(-100), 'today');
        });

        it('should floor fractional days', () => {
            // 1.9 days → floor to 1 → "yesterday"
            assert.strictEqual(formatRelativeTime(1.9), 'yesterday');
            assert.strictEqual(formatRelativeTime(0.5), 'today');
            assert.strictEqual(formatRelativeTime(29.99), '29 days ago');
        });
    });
});

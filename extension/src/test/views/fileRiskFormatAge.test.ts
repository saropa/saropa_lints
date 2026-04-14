import * as assert from 'node:assert';
import { formatAge } from '../../views/fileRiskTree';

describe('formatAge', () => {
  it('returns "just now" for timestamps less than 60 seconds old', () => {
    const recent = new Date(Date.now() - 30_000).toISOString();
    const { label, isStale } = formatAge(recent);
    assert.strictEqual(label, 'just now');
    assert.strictEqual(isStale, false);
  });

  it('returns minutes for timestamps 1-59 minutes old', () => {
    const fiveMinAgo = new Date(Date.now() - 5 * 60_000).toISOString();
    const { label, isStale } = formatAge(fiveMinAgo);
    assert.strictEqual(label, '5m ago');
    assert.strictEqual(isStale, false);
  });

  it('returns hours for timestamps 1-23 hours old', () => {
    const threeHoursAgo = new Date(Date.now() - 3 * 3600_000).toISOString();
    const { label, isStale } = formatAge(threeHoursAgo);
    assert.strictEqual(label, '3h ago');
    assert.strictEqual(isStale, false);
  });

  it('returns days for timestamps 24+ hours old', () => {
    const twoDaysAgo = new Date(Date.now() - 2 * 86400_000).toISOString();
    const { label, isStale } = formatAge(twoDaysAgo);
    assert.strictEqual(label, '2d ago');
    assert.strictEqual(isStale, true);
  });

  it('marks timestamps older than 24 hours as stale', () => {
    const twentyFiveHoursAgo = new Date(Date.now() - 25 * 3600_000).toISOString();
    const { isStale } = formatAge(twentyFiveHoursAgo);
    assert.strictEqual(isStale, true);
  });

  it('marks timestamps under 24 hours as not stale', () => {
    const twentyThreeHoursAgo = new Date(Date.now() - 23 * 3600_000).toISOString();
    const { isStale } = formatAge(twentyThreeHoursAgo);
    assert.strictEqual(isStale, false);
  });

  it('handles invalid ISO timestamp gracefully', () => {
    const { label, isStale } = formatAge('not-a-date');
    assert.strictEqual(label, 'unknown');
    assert.strictEqual(isStale, false);
  });

  it('handles empty string', () => {
    const { label, isStale } = formatAge('');
    assert.strictEqual(label, 'unknown');
    assert.strictEqual(isStale, false);
  });
});

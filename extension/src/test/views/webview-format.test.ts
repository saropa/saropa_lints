/**
 * Unit tests for the shared webview formatting helpers (§18 of the UX
 * guidelines). Pin the en-US output so a future locale switch surfaces as
 * deliberate test updates rather than silent drift.
 */
import * as assert from 'node:assert';

import {
  pluralize,
  formatNumber,
  formatCompact,
  formatPercent,
  formatRelativeTimestamp,
  formatAbsoluteTimestamp,
} from '../../views/webview-format';

describe('webview-format — pluralize', () => {
  const forms = { one: '{count} finding', other: '{count} findings' };

  it('returns the "one" form for 1', () => {
    assert.strictEqual(pluralize(1, forms), '1 finding');
  });

  it('returns the "other" form for 0', () => {
    assert.strictEqual(pluralize(0, forms), '0 findings');
  });

  it('returns the "other" form for 2+', () => {
    assert.strictEqual(pluralize(2, forms), '2 findings');
    assert.strictEqual(pluralize(47, forms), '47 findings');
  });

  it('inserts thousands separators on large counts', () => {
    assert.strictEqual(pluralize(12345, forms), '12,345 findings');
  });

  it('omits the count when the template has no placeholder', () => {
    const f = { one: 'one item', other: 'multiple items' };
    assert.strictEqual(pluralize(1, f), 'one item');
    assert.strictEqual(pluralize(5, f), 'multiple items');
  });
});

describe('webview-format — formatNumber', () => {
  it('formats integers with thousands separators', () => {
    assert.strictEqual(formatNumber(1234), '1,234');
    assert.strictEqual(formatNumber(1234567), '1,234,567');
  });

  it('returns em dash for non-finite input', () => {
    assert.strictEqual(formatNumber(Number.NaN), '—');
    assert.strictEqual(formatNumber(Number.POSITIVE_INFINITY), '—');
  });
});

describe('webview-format — formatCompact', () => {
  it('keeps small numbers as-is with separators', () => {
    assert.strictEqual(formatCompact(840), '840');
    assert.strictEqual(formatCompact(999), '999');
  });

  it('compacts at thousand and above', () => {
    assert.strictEqual(formatCompact(1200), '1.2K');
    assert.strictEqual(formatCompact(1234567), '1.2M');
  });

  it('returns em dash for non-finite input', () => {
    assert.strictEqual(formatCompact(Number.NaN), '—');
  });
});

describe('webview-format — formatPercent', () => {
  it('formats a 0..1 ratio with the percent sign', () => {
    assert.strictEqual(formatPercent(0.123), '12.3%');
    assert.strictEqual(formatPercent(0.5), '50%');
    assert.strictEqual(formatPercent(1), '100%');
  });

  it('returns em dash for non-finite input', () => {
    assert.strictEqual(formatPercent(Number.NaN), '—');
  });
});

describe('webview-format — formatRelativeTimestamp', () => {
  it('returns "just now" for recent timestamps', () => {
    const now = new Date().toISOString();
    assert.strictEqual(formatRelativeTimestamp(now), 'just now');
  });

  it('returns "Nm ago" for minute-aged timestamps', () => {
    const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    assert.strictEqual(formatRelativeTimestamp(fiveMinAgo), '5m ago');
  });

  it('returns "Nh ago" for hour-aged timestamps', () => {
    const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();
    assert.strictEqual(formatRelativeTimestamp(threeHoursAgo), '3h ago');
  });

  it('returns undefined for falsy or unparseable input', () => {
    assert.strictEqual(formatRelativeTimestamp(undefined), undefined);
    assert.strictEqual(formatRelativeTimestamp('not a date'), undefined);
    assert.strictEqual(formatRelativeTimestamp(''), undefined);
  });

  it('returns "just now" for future-dated timestamps (clock skew)', () => {
    const inFuture = new Date(Date.now() + 60_000).toISOString();
    assert.strictEqual(formatRelativeTimestamp(inFuture), 'just now');
  });
});

describe('webview-format — formatAbsoluteTimestamp', () => {
  it('formats an ISO timestamp', () => {
    const formatted = formatAbsoluteTimestamp('2026-04-12T14:23:00Z');
    // Don't pin the exact format because Intl output can vary slightly across
    // ICU versions; assert structural shape instead.
    assert.ok(formatted, 'must return a string');
    assert.match(formatted!, /\d{4}/, 'must include the year');
    assert.match(formatted!, /\d{2}/, 'must include 2-digit components');
  });

  it('returns undefined for falsy or unparseable input', () => {
    assert.strictEqual(formatAbsoluteTimestamp(undefined), undefined);
    assert.strictEqual(formatAbsoluteTimestamp('not a date'), undefined);
  });
});

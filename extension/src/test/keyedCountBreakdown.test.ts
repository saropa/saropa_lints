/**
 * Unit tests for {@link formatKeyedCountBreakdown} and {@link sortedNumericCountEntries}.
 */

import * as assert from 'node:assert';
import {
  countNormalizedNumericEntries,
  formatKeyedCountBreakdown,
  normalizeNonNegativeInteger,
  sortedNumericCountEntries,
} from '../keyedCountBreakdown';

describe('normalizeNonNegativeInteger', () => {
  it('accepts non-negative integers', () => {
    assert.strictEqual(normalizeNonNegativeInteger(0), 0);
    assert.strictEqual(normalizeNonNegativeInteger(42), 42);
  });
  it('rejects negative, non-finite, and non-integer numbers', () => {
    assert.strictEqual(normalizeNonNegativeInteger(-1), null);
    assert.strictEqual(normalizeNonNegativeInteger(1.5), null);
    assert.strictEqual(normalizeNonNegativeInteger(NaN), null);
    assert.strictEqual(normalizeNonNegativeInteger(Infinity), null);
  });
  it('accepts integer-like numeric strings', () => {
    assert.strictEqual(normalizeNonNegativeInteger(' 7 '), 7);
  });
  it('rejects empty or non-numeric strings', () => {
    assert.strictEqual(normalizeNonNegativeInteger(''), null);
    assert.strictEqual(normalizeNonNegativeInteger('   '), null);
    assert.strictEqual(normalizeNonNegativeInteger('x'), null);
    assert.strictEqual(normalizeNonNegativeInteger('1.2'), null);
  });
});

describe('sortedNumericCountEntries', () => {
  it('returns empty for null, arrays, and primitives', () => {
    assert.deepStrictEqual(sortedNumericCountEntries(null), []);
    assert.deepStrictEqual(sortedNumericCountEntries([]), []);
    assert.deepStrictEqual(sortedNumericCountEntries('x'), []);
    assert.deepStrictEqual(sortedNumericCountEntries(3), []);
  });
  it('drops invalid keys and sorts by count desc', () => {
    assert.deepStrictEqual(
      sortedNumericCountEntries({
        a: 1,
        b: 10,
        bad: 'nope',
        c: -1,
        d: 3.14,
        e: NaN,
      }),
      [
        ['b', 10],
        ['a', 1],
      ],
    );
  });
});

describe('countNormalizedNumericEntries', () => {
  it('counts only keys with valid integers', () => {
    assert.strictEqual(
      countNormalizedNumericEntries({ a: 1, b: 'x', c: 2 }),
      2,
    );
  });
});

describe('formatKeyedCountBreakdown', () => {
  it('returns em dash when nothing valid remains', () => {
    assert.strictEqual(formatKeyedCountBreakdown(undefined), '—');
    assert.strictEqual(formatKeyedCountBreakdown({ a: 'bad' }), '—');
  });
  it('formats sorted pairs', () => {
    assert.strictEqual(
      formatKeyedCountBreakdown({ z: 1, y: 2 }),
      'y 2, z 1',
    );
  });
});

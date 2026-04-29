/**
 * Normalizes summary maps from violations.json (by rule type, suppressions by kind, etc.).
 * Export data can be incomplete or malformed; UIs must not throw and should skip bad values.
 */

/** Accepts analyzer-style counts: non-negative integers, optional string forms from loose JSON. */
export function normalizeNonNegativeInteger(value: unknown): number | null {
  if (typeof value === 'number') {
    if (!Number.isFinite(value) || value < 0 || !Number.isInteger(value)) return null;
    return value;
  }
  if (typeof value === 'string') {
    const s = value.trim();
    if (s === '') return null;
    const n = Number(s);
    if (!Number.isFinite(n) || n < 0 || !Number.isInteger(n)) return null;
    return n;
  }
  return null;
}

function isPlainKeyedObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * Reads string-keyed counts from an unknown value (typically a JSON object).
 * Drops non-integer, negative, NaN, or non-numeric entries. Sorts by count descending, then key.
 */
export function sortedNumericCountEntries(source: unknown): [string, number][] {
  if (!isPlainKeyedObject(source)) return [];
  const out: [string, number][] = [];
  for (const [k, v] of Object.entries(source)) {
    const n = normalizeNonNegativeInteger(v);
    if (n === null) continue;
    out.push([k, n]);
  }
  out.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  return out;
}

/** Keys with a valid non-negative integer count (ignores corrupt JSON values). */
export function countNormalizedNumericEntries(source: unknown): number {
  return sortedNumericCountEntries(source).length;
}

/** Comma-separated `key count` pairs for tree descriptions, or em dash when empty / invalid. */
export function formatKeyedCountBreakdown(source: unknown): string {
  const sorted = sortedNumericCountEntries(source);
  if (sorted.length === 0) return '—';
  return sorted.map(([k, v]) => `${k} ${v}`).join(', ');
}

/**
 * Shared formatting helpers for editor-area webview surfaces (UX guidelines §18).
 *
 * Consolidates pluralization, number formatting, and timestamp formatting so
 * every dashboard renders the same shape for the same value. Routing all
 * count / number / date strings through this module makes a future
 * internationalization pass tractable — every user-facing format in the
 * webview HTML / script reaches one of these helpers.
 *
 * **Banned patterns elsewhere:**
 *   - `${n} item${n === 1 ? '' : 's'}` — use [pluralize] (§18.2).
 *   - `${value.toFixed(2)}%` — use [formatPercent] (§18.3).
 *   - `${(n / 1000).toFixed(1)}k` — use [formatCompact] (§18.3).
 *
 * **Why English-first still routes through Intl.\*:** swapping a literal helper
 * for a locale-aware helper later becomes a refactor across N call sites; the
 * abstraction point is the cheap part. Adopt the helpers now even when every
 * locale resolves identically to en-US.
 */

const DEFAULT_LOCALE = 'en-US';

/* ──────────────────────────────────────────────────────────────────────
 * Pluralization (§18.2)
 * ──────────────────────────────────────────────────────────────────── */

const pluralRules = new Intl.PluralRules(DEFAULT_LOCALE);

/** Plural-forms map. English uses `one` (1) and `other` (everything else). */
export interface PluralForms {
    /** Form for `count === 1`. */
    readonly one: string;
    /** Form for every other count, including 0 and N > 1. */
    readonly other: string;
}

/**
 * Pick the correct plural form for `count`. Replaces inline ternaries
 * (`count === 1 ? 'item' : 'items'`) so a future locale switch with three or
 * more plural forms (Russian, Arabic, Polish) is a one-line config change.
 *
 * The forms may carry a `{count}` placeholder which is substituted via
 * [formatNumber] (locale-aware thousands separators). If the form has no
 * placeholder, the count is not rendered — caller is responsible for
 * displaying it separately.
 *
 * @example
 * pluralize(1, { one: '{count} finding', other: '{count} findings' })
 *   // → '1 finding'
 * pluralize(1234, { one: '{count} finding', other: '{count} findings' })
 *   // → '1,234 findings'
 * pluralize(0, { one: 'no findings', other: 'no findings' })
 *   // → 'no findings'  (forms can be identical when grammar permits)
 */
export function pluralize(count: number, forms: PluralForms): string {
    const key = pluralRules.select(count);
    const template = key === 'one' ? forms.one : forms.other;
    return template.replace('{count}', formatNumber(count));
}

/* ──────────────────────────────────────────────────────────────────────
 * Number formatting (§18.3)
 * ──────────────────────────────────────────────────────────────────── */

const integerFormatter = new Intl.NumberFormat(DEFAULT_LOCALE);
const compactFormatter = new Intl.NumberFormat(DEFAULT_LOCALE, {
    notation: 'compact',
    maximumFractionDigits: 1,
});
const percentFormatter = new Intl.NumberFormat(DEFAULT_LOCALE, {
    style: 'percent',
    maximumFractionDigits: 1,
});

/**
 * Format an integer with locale-correct thousands separators (e.g.
 * `1,234,567` in en-US, `1.234.567` in de-DE).
 *
 * Use this helper for every count rendered in a table cell, KPI card, or
 * status pill. Bare `n.toLocaleString()` works but spreading the call across
 * surfaces makes locale changes harder; route through here for consistency.
 */
export function formatNumber(value: number): string {
    if (!Number.isFinite(value)) { return '—'; }
    return integerFormatter.format(value);
}

/**
 * Compact display for wide integers (e.g. `1.2M`, `840K`). Pair with
 * [formatNumber] in the cell's `title` so the user gets precision on hover.
 *
 * @example
 * formatCompact(1234567)  // → '1.2M'
 * formatCompact(840)      // → '840'
 */
export function formatCompact(value: number): string {
    if (!Number.isFinite(value)) { return '—'; }
    if (value < 1000) { return integerFormatter.format(value); }
    return compactFormatter.format(value);
}

/**
 * Format a 0..1 ratio as a locale-correct percentage (e.g. `12.3%`).
 *
 * Never write `${n * 100}%` — the decimal separator is locale-specific
 * (`12.3%` in en-US, `12,3 %` in de-DE) and `Intl.NumberFormat` handles it.
 */
export function formatPercent(ratio: number): string {
    if (!Number.isFinite(ratio)) { return '—'; }
    return percentFormatter.format(ratio);
}

/* ──────────────────────────────────────────────────────────────────────
 * Timestamp formatting (§18.4)
 * ──────────────────────────────────────────────────────────────────── */

/**
 * Format a UTC ISO 8601 timestamp as a relative duration ("just now", "2m ago",
 * "3d ago"). Mirrors the helper currently in [dashboardHero.ts] so dashboards
 * that already imported from there stay working; future surfaces can import
 * either.
 *
 * Returns `undefined` for unparseable input so the caller can choose its
 * fallback (em-dash, "Never", "Unknown").
 */
export function formatRelativeTimestamp(iso: string | undefined): string | undefined {
    if (!iso) { return undefined; }
    const t = Date.parse(iso);
    if (!Number.isFinite(t)) { return undefined; }
    const diffMs = Date.now() - t;
    if (diffMs < 0) { return 'just now'; }
    const sec = Math.floor(diffMs / 1000);
    if (sec < 45) { return 'just now'; }
    const min = Math.floor(sec / 60);
    if (min < 60) { return `${min}m ago`; }
    const hr = Math.floor(min / 60);
    if (hr < 24) { return `${hr}h ago`; }
    const day = Math.floor(hr / 24);
    if (day < 7) { return `${day}d ago`; }
    const week = Math.floor(day / 7);
    if (week < 5) { return `${week}w ago`; }
    const month = Math.floor(day / 30);
    if (month < 12) { return `${month}mo ago`; }
    const year = Math.floor(day / 365);
    return `${year}y ago`;
}

const absoluteFormatter = new Intl.DateTimeFormat(DEFAULT_LOCALE, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
});

/**
 * Format a UTC ISO 8601 timestamp as a locale-formatted absolute string
 * (e.g. `2026/04/12, 14:23` in en-US). Pair with [formatRelativeTimestamp]
 * in `title` tooltips so the user gets quick context plus precision.
 *
 * Returns `undefined` for unparseable input.
 */
export function formatAbsoluteTimestamp(iso: string | undefined): string | undefined {
    if (!iso) { return undefined; }
    const t = Date.parse(iso);
    if (!Number.isFinite(t)) { return undefined; }
    return absoluteFormatter.format(new Date(t));
}

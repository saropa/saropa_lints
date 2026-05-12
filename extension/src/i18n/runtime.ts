/**
 * Runtime internationalization for the extension (Node + webview contexts).
 *
 * Loads bundled JSON catalogs, normalizes BCP-47-ish locale strings to a
 * supported catalog key, resolves dotted message keys with English fallback,
 * and performs simple `{token}` substitution. Does not load additional locales
 * from disk at runtime; catalogs are static imports above.
 */
import ar from './locales/ar.json';
import bn from './locales/bn.json';
import de from './locales/de.json';
import en from './locales/en.json';
import es from './locales/es.json';
import fa from './locales/fa.json';
import fil from './locales/fil.json';
import fr from './locales/fr.json';
import he from './locales/he.json';
import hi from './locales/hi.json';
import id from './locales/id.json';
import it from './locales/it.json';
import ja from './locales/ja.json';
import ko from './locales/ko.json';
import nl from './locales/nl.json';
import pl from './locales/pl.json';
import pt from './locales/pt.json';
import ru from './locales/ru.json';
import sw from './locales/sw.json';
import th from './locales/th.json';
import tr from './locales/tr.json';
import uk from './locales/uk.json';
import ur from './locales/ur.json';
import vi from './locales/vi.json';
import zh from './locales/zh.json';

/** Values allowed inside `{name}` interpolation payloads. */
type Primitive = string | number;
/** Immutable bag of named parameters for `t` / `format`. */
type Params = Readonly<Record<string, Primitive>>;
/** JSON catalog shape: leaves are translated strings; objects nest namespaces. */
interface NestedRecord {
    readonly [key: string]: string | NestedRecord;
}

/** Canonical fallback when the requested locale is unknown or catalogs miss a key. */
const DEFAULT_LOCALE = 'en';
/** Static locale → nested JSON map; keys must match `normalizeLocale` outputs. */
const catalogs: Readonly<Record<string, NestedRecord>> = {
    ar: ar as NestedRecord,
    bn: bn as NestedRecord,
    de: de as NestedRecord,
    en: en as NestedRecord,
    es: es as NestedRecord,
    fa: fa as NestedRecord,
    fil: fil as NestedRecord,
    fr: fr as NestedRecord,
    he: he as NestedRecord,
    hi: hi as NestedRecord,
    id: id as NestedRecord,
    it: it as NestedRecord,
    ja: ja as NestedRecord,
    ko: ko as NestedRecord,
    nl: nl as NestedRecord,
    pl: pl as NestedRecord,
    pt: pt as NestedRecord,
    ru: ru as NestedRecord,
    sw: sw as NestedRecord,
    th: th as NestedRecord,
    tr: tr as NestedRecord,
    uk: uk as NestedRecord,
    ur: ur as NestedRecord,
    vi: vi as NestedRecord,
    zh: zh as NestedRecord,
};
/** Process-wide active locale for `t` when `options.locale` is omitted. */
let activeLocale = DEFAULT_LOCALE;

/**
 * Maps free-form locale input to a catalog key present in `catalogs`.
 * Lowercases, prefers exact keys, then primary language subtag before `en`.
 * Aliases cover legacy OS tags (`iw`→Hebrew, `tl`→Filipino).
 */
const LOCALE_ALIASES: Readonly<Record<string, string>> = {
    iw: 'he',
    tl: 'fil',
};

function normalizeLocale(input: string | undefined): string {
    if (!input) return DEFAULT_LOCALE;
    const raw = input.toLowerCase();
    if (catalogs[raw]) return raw;
    const [base] = raw.split('-');
    const mapped = LOCALE_ALIASES[base] ?? base;
    return catalogs[mapped] ? mapped : DEFAULT_LOCALE;
}

/** Walks `a.b.c` segments; returns a string leaf or undefined if missing/non-leaf. */
function lookupKey(catalog: NestedRecord, key: string): string | undefined {
    const parts = key.split('.');
    let current: string | NestedRecord | undefined = catalog;
    for (const part of parts) {
        if (typeof current !== 'object' || current === null) return undefined;
        current = current[part];
    }
    return typeof current === 'string' ? current : undefined;
}

/** Replaces `{word}` tokens; unknown keys leave the placeholder unchanged. */
function interpolate(template: string, params?: Params): string {
    if (!params) return template;
    return template.replace(/\{(\w+)\}/g, (match, key) => {
        const value = params[key];
        return value === undefined ? match : String(value);
    });
}

/** Read-only: returns the catalog key that would be used for `requested`. */
export function resolveLocale(requested: string | undefined): string {
    return normalizeLocale(requested);
}

/** Updates the module-level active locale used by `t` without an explicit locale. */
export function setCurrentLocale(requested: string | undefined): string {
    activeLocale = normalizeLocale(requested);
    return activeLocale;
}

/** Current module-level locale after `setCurrentLocale` (defaults start at `en`). */
export function getCurrentLocale(): string {
    return activeLocale;
}

/** Full nested JSON catalog for UI that needs bulk lookups beyond single keys. */
export function getCatalog(locale: string | undefined): NestedRecord {
    return catalogs[normalizeLocale(locale ?? activeLocale)];
}

/**
 * Resolves a dotted message key with optional `{param}` interpolation.
 * Order: requested/active locale → English → `options.fallback` → raw `key`.
 */
export function l10n(
    key: string,
    params?: Params,
    options?: Readonly<{ locale?: string; fallback?: string }>,
): string {
    const locale = normalizeLocale(options?.locale ?? activeLocale);
    const fromLocale = lookupKey(catalogs[locale], key);
    if (fromLocale) return interpolate(fromLocale, params);

    const fromDefault = lookupKey(catalogs[DEFAULT_LOCALE], key);
    if (fromDefault) return interpolate(fromDefault, params);

    return options?.fallback ?? key;
}

/** Interpolates an already-resolved template string (no catalog lookup). */
export function format(template: string, params: Params): string {
    return interpolate(template, params);
}

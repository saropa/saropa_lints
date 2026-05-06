import en from './locales/en.json';
import ar from './locales/ar.json';
import de from './locales/de.json';
import es from './locales/es.json';
import fr from './locales/fr.json';
import hi from './locales/hi.json';
import it from './locales/it.json';
import ja from './locales/ja.json';
import ko from './locales/ko.json';
import nl from './locales/nl.json';
import pt from './locales/pt.json';
import ru from './locales/ru.json';
import ur from './locales/ur.json';
import zh from './locales/zh.json';

type Primitive = string | number;
type Params = Readonly<Record<string, Primitive>>;
interface NestedRecord {
    readonly [key: string]: string | NestedRecord;
}

const DEFAULT_LOCALE = 'en';
const catalogs: Readonly<Record<string, NestedRecord>> = {
    ar: ar as NestedRecord,
    de: de as NestedRecord,
    en: en as NestedRecord,
    es: es as NestedRecord,
    fr: fr as NestedRecord,
    hi: hi as NestedRecord,
    it: it as NestedRecord,
    ja: ja as NestedRecord,
    ko: ko as NestedRecord,
    nl: nl as NestedRecord,
    pt: pt as NestedRecord,
    ru: ru as NestedRecord,
    ur: ur as NestedRecord,
    zh: zh as NestedRecord,
};
let activeLocale = DEFAULT_LOCALE;

function normalizeLocale(input: string | undefined): string {
    if (!input) return DEFAULT_LOCALE;
    const raw = input.toLowerCase();
    if (catalogs[raw]) return raw;
    const [base] = raw.split('-');
    return catalogs[base] ? base : DEFAULT_LOCALE;
}

function lookupKey(catalog: NestedRecord, key: string): string | undefined {
    const parts = key.split('.');
    let current: string | NestedRecord | undefined = catalog;
    for (const part of parts) {
        if (typeof current !== 'object' || current === null) return undefined;
        current = current[part];
    }
    return typeof current === 'string' ? current : undefined;
}

function interpolate(template: string, params?: Params): string {
    if (!params) return template;
    return template.replace(/\{(\w+)\}/g, (match, key) => {
        const value = params[key];
        return value === undefined ? match : String(value);
    });
}

export function resolveLocale(requested: string | undefined): string {
    return normalizeLocale(requested);
}

export function setCurrentLocale(requested: string | undefined): string {
    activeLocale = normalizeLocale(requested);
    return activeLocale;
}

export function getCurrentLocale(): string {
    return activeLocale;
}

export function getCatalog(locale: string | undefined): NestedRecord {
    return catalogs[normalizeLocale(locale ?? activeLocale)];
}

export function t(
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

export function format(template: string, params: Params): string {
    return interpolate(template, params);
}


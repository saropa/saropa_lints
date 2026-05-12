/**
 * Labels for the UI language quick pick and settings row.
 *
 * Endonyms (native script) plus English in parentheses for non-English codes
 * so palette text stays discoverable for maintainers and mixed-language teams.
 */
import * as vscode from 'vscode';

import { l10n } from './runtime';

/** Values accepted for `saropaLints.uiLanguage` (matches package.json enum). */
export type UiLanguageCode =
  | 'auto'
  | 'ar'
  | 'bn'
  | 'de'
  | 'en'
  | 'es'
  | 'fa'
  | 'fil'
  | 'fr'
  | 'he'
  | 'hi'
  | 'id'
  | 'it'
  | 'ja'
  | 'ko'
  | 'nl'
  | 'pl'
  | 'pt'
  | 'ru'
  | 'sw'
  | 'th'
  | 'tr'
  | 'uk'
  | 'ur'
  | 'vi'
  | 'zh';

const ENGLISH_ENDONYM: Record<Exclude<UiLanguageCode, 'auto'>, string> = {
  ar: 'Arabic',
  bn: 'Bengali',
  de: 'German',
  en: 'English',
  es: 'Spanish',
  fa: 'Persian',
  fil: 'Filipino',
  fr: 'French',
  he: 'Hebrew',
  hi: 'Hindi',
  id: 'Indonesian',
  it: 'Italian',
  ja: 'Japanese',
  ko: 'Korean',
  nl: 'Dutch',
  pl: 'Polish',
  pt: 'Portuguese',
  ru: 'Russian',
  sw: 'Swahili',
  th: 'Thai',
  tr: 'Turkish',
  uk: 'Ukrainian',
  ur: 'Urdu',
  vi: 'Vietnamese',
  zh: 'Chinese',
};

const NATIVE_ENDONYM: Record<Exclude<UiLanguageCode, 'auto' | 'en'>, string> = {
  ar: 'العربية',
  bn: 'বাংলা',
  de: 'Deutsch',
  es: 'Español',
  fa: 'فارسی',
  fil: 'Filipino',
  fr: 'Français',
  he: 'עברית',
  hi: 'हिन्दी',
  id: 'Bahasa Indonesia',
  it: 'Italiano',
  ja: '日本語',
  ko: '한국어',
  nl: 'Nederlands',
  pl: 'Polski',
  pt: 'Português',
  ru: 'Русский',
  sw: 'Kiswahili',
  th: 'ไทย',
  tr: 'Türkçe',
  uk: 'Українська',
  ur: 'اردو',
  vi: 'Tiếng Việt',
  zh: '中文',
};

export interface LanguagePickItem extends vscode.QuickPickItem {
  readonly value: UiLanguageCode;
}

/** One-line label for the current value in the Settings tree row. */
export function formatLanguageChoiceLabel(code: string): string {
  if (code === 'auto') {
    return l10n('uiLanguage.pick.auto');
  }
  if (code === 'en') {
    return ENGLISH_ENDONYM.en;
  }
  if (Object.prototype.hasOwnProperty.call(NATIVE_ENDONYM, code)) {
    const k = code as keyof typeof NATIVE_ENDONYM;
    return `${NATIVE_ENDONYM[k]} (${ENGLISH_ENDONYM[k]})`;
  }
  return code;
}

function sortedLocaleCodes(): Exclude<UiLanguageCode, 'auto'>[] {
  const codes = Object.keys(ENGLISH_ENDONYM) as Exclude<UiLanguageCode, 'auto'>[];
  return codes.sort((a, b) =>
    ENGLISH_ENDONYM[a].localeCompare(ENGLISH_ENDONYM[b], 'en', { sensitivity: 'base' }),
  );
}

/** Rows for `showQuickPick`: `auto` first, then English language names A–Z. */
export function buildUiLanguageQuickPickItems(): LanguagePickItem[] {
  const order: UiLanguageCode[] = ['auto', ...sortedLocaleCodes()];
  const resolvedAuto = vscode.env.language;
  return order.map((value) => {
    const item: LanguagePickItem = {
      label: formatLanguageChoiceLabel(value),
      value,
    };
    // Show the resolved language for "auto" so users know what they're getting.
    if (value === 'auto') {
      return { ...item, description: `→ ${resolvedAuto}` };
    }
    return item;
  });
}

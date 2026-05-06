/**
 * Labels for the UI language quick pick and settings row.
 *
 * Endonyms (native script) plus English in parentheses for non-English codes
 * so palette text stays discoverable for maintainers and mixed-language teams.
 */
import * as vscode from 'vscode';

import { t } from './runtime';

/** Values accepted for `saropaLints.uiLanguage` (matches package.json enum). */
export type UiLanguageCode =
  | 'auto'
  | 'ar'
  | 'de'
  | 'en'
  | 'es'
  | 'fr'
  | 'hi'
  | 'it'
  | 'ja'
  | 'ko'
  | 'nl'
  | 'pt'
  | 'ru'
  | 'ur'
  | 'zh';

const ENGLISH_ENDONYM: Record<Exclude<UiLanguageCode, 'auto'>, string> = {
  ar: 'Arabic',
  de: 'German',
  en: 'English',
  es: 'Spanish',
  fr: 'French',
  hi: 'Hindi',
  it: 'Italian',
  ja: 'Japanese',
  ko: 'Korean',
  nl: 'Dutch',
  pt: 'Portuguese',
  ru: 'Russian',
  ur: 'Urdu',
  zh: 'Chinese',
};

const NATIVE_ENDONYM: Record<Exclude<UiLanguageCode, 'auto' | 'en'>, string> = {
  ar: 'العربية',
  de: 'Deutsch',
  es: 'Español',
  fr: 'Français',
  hi: 'हिन्दी',
  it: 'Italiano',
  ja: '日本語',
  ko: '한국어',
  nl: 'Nederlands',
  pt: 'Português',
  ru: 'Русский',
  ur: 'اردو',
  zh: '中文',
};

export interface LanguagePickItem extends vscode.QuickPickItem {
  readonly value: UiLanguageCode;
}

/** One-line label for the current value in the Settings tree row. */
export function formatLanguageChoiceLabel(code: string): string {
  if (code === 'auto') {
    return t('uiLanguage.pick.auto');
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

/** Rows for `showQuickPick`; order matches prior UX (auto first, then alphabetical by code). */
export function buildUiLanguageQuickPickItems(): LanguagePickItem[] {
  const order: UiLanguageCode[] = [
    'auto',
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'it',
    'ja',
    'ko',
    'nl',
    'pt',
    'ru',
    'ur',
    'zh',
  ];
  return order.map((value) => ({
    label: formatLanguageChoiceLabel(value),
    value,
  }));
}

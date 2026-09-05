/**
 * UI language quick pick: stable ordering for discoverability (auto first, then A–Z by English name).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

import { buildUiLanguageQuickPickItems } from '../../i18n/languagePick';

/**
 * Reads the generated locale_coverage.json so assertions track actual
 * coverage rather than hardcoding percentages that go stale on every
 * catalog regeneration.
 */
function readCoverageData(): Record<string, { coveragePct: number }> {
  const coveragePath = path.resolve(
    __dirname, '..', '..', '..', 'src', 'i18n', 'locale_coverage.json',
  );
  const raw = JSON.parse(fs.readFileSync(coveragePath, 'utf-8'));
  return raw.locales;
}

describe('languagePick', () => {
  it('lists auto first, then locales sorted by English language name', () => {
    const items = buildUiLanguageQuickPickItems();
    assert.strictEqual(items.length, 26);
    assert.strictEqual(items[0]!.value, 'auto');

    // Order must match `saropaLints.uiLanguage` enum in package.json (English endonyms A–Z).
    const expected: string[] = [
      'ar',
      'bn',
      'zh',
      'nl',
      'en',
      'fil',
      'fr',
      'de',
      'he',
      'hi',
      'id',
      'it',
      'ja',
      'ko',
      'fa',
      'pl',
      'pt',
      'ru',
      'es',
      'sw',
      'th',
      'tr',
      'uk',
      'ur',
      'vi',
    ];
    assert.deepStrictEqual(
      items.slice(1).map((i) => i.value),
      expected,
    );
  });

  it('badges incomplete locales with their coverage percent and leaves complete ones clean', () => {
    const items = buildUiLanguageQuickPickItems();
    const byValue = new Map(items.map((i) => [i.value, i]));
    const coverage = readCoverageData();

    // Dynamically check every locale: if coverage < 100%, the badge must
    // contain the percentage; if >= 100% or absent, no badge.
    for (const [code, entry] of Object.entries(coverage)) {
      // Cast needed: Object.entries returns string but the map is keyed by UiLanguageCode
      const item = byValue.get(code as any);
      if (!item) continue; // locale in coverage but not in the picker enum
      if (entry.coveragePct < 100) {
        assert.ok(item.description, `${code} at ${entry.coveragePct}% should carry a coverage badge`);
        assert.match(
          item.description!,
          new RegExp(String(entry.coveragePct)),
          `${code} badge should state its ${entry.coveragePct}% coverage`,
        );
      } else {
        assert.strictEqual(item.description, undefined, `${code} at 100% should have no badge`);
      }
    }

    // English is the source (100%) and always carries no badge.
    assert.strictEqual(byValue.get('en')!.description, undefined);

    // `auto` keeps its resolved-language hint, not a coverage badge.
    assert.ok(byValue.get('auto')!.description?.startsWith('→'));
  });
});

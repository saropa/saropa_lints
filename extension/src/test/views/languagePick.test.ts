/**
 * UI language quick pick: stable ordering for discoverability (auto first, then A–Z by English name).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildUiLanguageQuickPickItems } from '../../i18n/languagePick';

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

    // zh ships at 4% per the generated coverage file — must carry a badge so the
    // user is not silently dropped onto a near-English UI under a Chinese label.
    const zh = byValue.get('zh');
    assert.ok(zh, 'zh item present');
    assert.ok(zh!.description, 'zh has a coverage badge');
    assert.match(zh!.description!, /4/, 'zh badge states its 4% coverage');

    // A fully-translated locale gets no description, keeping the list uncluttered.
    const de = byValue.get('de');
    assert.ok(de, 'de item present');
    assert.strictEqual(de!.description, undefined, 'complete locale has no badge');

    // English is the source (100%) and likewise carries no badge.
    assert.strictEqual(byValue.get('en')!.description, undefined);

    // `auto` keeps its resolved-language hint, not a coverage badge.
    assert.ok(byValue.get('auto')!.description?.startsWith('→'));
  });
});

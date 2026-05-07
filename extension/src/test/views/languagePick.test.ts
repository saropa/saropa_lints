/**
 * UI language quick pick: stable ordering for discoverability (auto first, then A–Z by English name).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildUiLanguageQuickPickItems } from '../../i18n/languagePick';

describe('languagePick', () => {
  it('lists auto first, then locales sorted by English language name', () => {
    const items = buildUiLanguageQuickPickItems();
    assert.strictEqual(items.length, 15);
    assert.strictEqual(items[0]!.value, 'auto');

    // Order must match `saropaLints.uiLanguage` enum in package.json (English endonyms A–Z).
    const expected: string[] = ['ar', 'zh', 'nl', 'en', 'fr', 'de', 'hi', 'it', 'ja', 'ko', 'pt', 'ru', 'es', 'ur'];
    assert.deepStrictEqual(
      items.slice(1).map((i) => i.value),
      expected,
    );
  });
});

/**
 * Tests for the bundled rule-catalog loader.
 *
 * The catalog supplies per-rule metadata (type / status / security-review flag)
 * the live diagnostics path cannot get from a `Diagnostic`. These tests pin: a
 * well-formed `media/rules_catalog.json` loads into the rule map, the result is
 * cached (one read), a missing or malformed file degrades to an empty catalog
 * instead of throwing (so activation survives a corrupt asset), and `getRuleCatalog`
 * returns empty before init.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

import {
  getRuleCatalog,
  initRuleCatalog,
  resetRuleCatalogForTest,
} from '../ruleCatalog';

// Writes a `media/rules_catalog.json` under a fresh temp "extension root" and
// returns that root, matching how `initRuleCatalog(extensionPath)` resolves it.
function makeExtensionRoot(contents: string): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-catalog-'));
  const mediaDir = path.join(root, 'media');
  fs.mkdirSync(mediaDir, { recursive: true });
  fs.writeFileSync(path.join(mediaDir, 'rules_catalog.json'), contents);
  return root;
}

describe('ruleCatalog', () => {
  beforeEach(() => resetRuleCatalogForTest());
  afterEach(() => resetRuleCatalogForTest());

  it('returns an empty catalog before init', () => {
    assert.deepStrictEqual(getRuleCatalog(), {});
  });

  it('loads the rule map from a well-formed catalog file', () => {
    const root = makeExtensionRoot(
      JSON.stringify({
        schemaVersion: '1.0',
        ruleCount: 1,
        rules: { avoid_print: { ruleType: 'codeSmell', ruleStatus: 'ready' } },
      }),
    );
    const catalog = initRuleCatalog(root);
    assert.strictEqual(catalog.avoid_print?.ruleType, 'codeSmell');
    // getRuleCatalog reflects the same cached instance.
    assert.strictEqual(getRuleCatalog().avoid_print?.ruleStatus, 'ready');
  });

  it('caches after first load — a second init with a different path is ignored', () => {
    const first = makeExtensionRoot(
      JSON.stringify({ rules: { rule_a: { ruleType: 'bug' } } }),
    );
    const second = makeExtensionRoot(
      JSON.stringify({ rules: { rule_b: { ruleType: 'codeSmell' } } }),
    );
    initRuleCatalog(first);
    const catalog = initRuleCatalog(second);
    assert.ok(catalog.rule_a, 'first load is retained');
    assert.strictEqual(catalog.rule_b, undefined, 'second path is not re-read');
  });

  it('degrades to an empty catalog when the file is missing', () => {
    const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-no-catalog-'));
    const catalog = initRuleCatalog(emptyRoot);
    assert.deepStrictEqual(catalog, {});
  });

  it('degrades to an empty catalog when the file is malformed JSON', () => {
    const root = makeExtensionRoot('{ this is not json');
    const catalog = initRuleCatalog(root);
    assert.deepStrictEqual(catalog, {});
  });

  it('treats a catalog with no rules key as empty', () => {
    const root = makeExtensionRoot(JSON.stringify({ schemaVersion: '1.0' }));
    const catalog = initRuleCatalog(root);
    assert.deepStrictEqual(catalog, {});
  });
});

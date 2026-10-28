import * as assert from 'node:assert';
import { readConfiguredPluginVersion } from '../analysisOptionsVersion';

describe('readConfiguredPluginVersion', () => {
  it('returns null for missing/empty content', () => {
    assert.strictEqual(readConfiguredPluginVersion(undefined), null);
    assert.strictEqual(readConfiguredPluginVersion(null), null);
    assert.strictEqual(readConfiguredPluginVersion(''), null);
  });

  it('returns null when there is no plugins block', () => {
    assert.strictEqual(readConfiguredPluginVersion('linter:\n  rules:\n    - foo\n'), null);
  });

  it('returns null when plugins has no saropa_lints', () => {
    assert.strictEqual(
      readConfiguredPluginVersion('plugins:\n  other:\n    version: 1.0.0\n'),
      null,
    );
  });

  it('reads an unquoted exact version', () => {
    assert.deepStrictEqual(
      readConfiguredPluginVersion('plugins:\n  saropa_lints:\n    version: 16.10.0\n'),
      { raw: '16.10.0', isRange: false },
    );
  });

  it('reads double- and single-quoted versions', () => {
    for (const q of ['"', "'"]) {
      assert.deepStrictEqual(
        readConfiguredPluginVersion(`plugins:\n  saropa_lints:\n    version: ${q}16.10.0${q}\n`),
        { raw: '16.10.0', isRange: false },
      );
    }
  });

  it('flags a range', () => {
    assert.deepStrictEqual(
      readConfiguredPluginVersion('plugins:\n  saropa_lints:\n    version: ^16.0.0\n'),
      { raw: '^16.0.0', isRange: true },
    );
    assert.deepStrictEqual(
      readConfiguredPluginVersion('plugins:\n  saropa_lints:\n    version: ">=16.0.0 <17.0.0"\n'),
      { raw: '>=16.0.0 <17.0.0', isRange: true },
    );
  });

  it('strips trailing comments and handles CRLF', () => {
    assert.deepStrictEqual(
      readConfiguredPluginVersion('plugins:\r\n  saropa_lints:\r\n    version: 1.2.3 # pinned\r\n'),
      { raw: '1.2.3', isRange: false },
    );
  });

  it('accepts the inline shorthand', () => {
    assert.deepStrictEqual(
      readConfiguredPluginVersion('plugins:\n  saropa_lints: ^1.2.3\n'),
      { raw: '^1.2.3', isRange: true },
    );
  });

  it('ignores version of other plugins and later top-level keys', () => {
    const yaml = 'plugins:\n  other:\n    version: 9.9.9\n  saropa_lints:\n    diagnostics:\n      a: true\n    version: 2.0.0\nanalyzer:\n  version: 3.0.0\n';
    assert.deepStrictEqual(readConfiguredPluginVersion(yaml), { raw: '2.0.0', isRange: false });
  });

  it('returns null when saropa_lints has no version', () => {
    assert.strictEqual(
      readConfiguredPluginVersion('plugins:\n  saropa_lints:\n    diagnostics:\n      a: true\nanalyzer:\n  version: 3.0.0\n'),
      null,
    );
  });
});

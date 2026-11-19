import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import { applyRecommendation } from '../../compat/configEdits';

const PUB = ['name: app', 'dev_dependencies:', '  saropa_lints: ^16.7.0', '  test: ^1.0.0', ''].join('\n');
const AO = [
  'analyzer:',
  '  exclude: []',
  '',
  'plugins:',
  '  saropa_lints:',
  '    version: "16.7.0"',
  '    diagnostics:',
  '      foo: true',
  '',
  'linter:',
  '  rules: {}',
  '',
].join('\n');

describe('applyRecommendation', () => {
  it('writes pubspec constraint as ^version', () => {
    const r = applyRecommendation({ pubspec: PUB }, { constraint: '16.10.0' });
    assert.strictEqual(r.pubspec, PUB.replace('^16.7.0', '^16.10.0'));
    assert.strictEqual(r.analysisOptions, undefined);
  });

  it('does not double the caret', () => {
    const r = applyRecommendation({ pubspec: PUB }, { constraint: '^16.10.0' });
    assert.ok(r.pubspec!.includes('saropa_lints: ^16.10.0\n'));
  });

  it('writes plugin version exact, never a range', () => {
    const r = applyRecommendation({ analysisOptions: AO }, { pluginVersion: '^16.10.0' });
    assert.strictEqual(r.analysisOptions, AO.replace('"16.7.0"', '"16.10.0"'));
  });

  it('keeps CRLF in both files', () => {
    const pub = PUB.replace(/\n/g, '\r\n');
    const ao = AO.replace(/\n/g, '\r\n');
    const r = applyRecommendation({ pubspec: pub, analysisOptions: ao }, { constraint: '17.0.0', pluginVersion: '17.0.0' });
    assert.strictEqual(r.pubspec, pub.replace('^16.7.0', '^17.0.0'));
    assert.strictEqual(r.analysisOptions, ao.replace('16.7.0', '17.0.0'));
    assert.ok(!/[^\r]\n/.test(r.pubspec!) && !/[^\r]\n/.test(r.analysisOptions!));
  });

  it('keeps untouched lines byte-identical (mixed EOL, no trailing newline)', () => {
    const ao = 'a: 1\r\nplugins:\n  saropa_lints:\n    version: 1.0.0\r\nb: 2';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '2.0.0' });
    assert.strictEqual(r.analysisOptions, 'a: 1\r\nplugins:\n  saropa_lints:\n    version: 2.0.0\r\nb: 2');
  });

  it('leaves a commented-out plugins block alone', () => {
    const ao = '# plugins:\n#   saropa_lints:\n#     version: "16.7.0"\n';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '17.0.0' });
    assert.strictEqual(r.analysisOptions, ao);
  });

  it('leaves the extension-disabled block alone', () => {
    const ao = '# >>> saropa_lints integration turned OFF >>>\n# plugins:\n#   saropa_lints:\n#     version: "1"\n# <<< end <<<\n';
    assert.strictEqual(applyRecommendation({ analysisOptions: ao }, { pluginVersion: '2.0.0' }).analysisOptions, ao);
  });

  it('adds the version line when the block lacks one', () => {
    const ao = 'plugins:\n  saropa_lints:\n    diagnostics:\n      foo: true\nlinter:\n';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '17.0.0' });
    assert.strictEqual(r.analysisOptions, 'plugins:\n  saropa_lints:\n    version: "17.0.0"\n    diagnostics:\n      foo: true\nlinter:\n');
  });

  it('adds the version line with CRLF', () => {
    const ao = 'plugins:\r\n  saropa_lints:\r\n    diagnostics:\r\n';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '17.0.0' });
    assert.strictEqual(r.analysisOptions, 'plugins:\r\n  saropa_lints:\r\n    version: "17.0.0"\r\n    diagnostics:\r\n');
  });

  it('ignores a version line belonging to another plugin', () => {
    const ao = 'plugins:\n  other:\n    version: "1.0.0"\n  saropa_lints:\n    diagnostics:\n';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '2.0.0' });
    assert.ok(r.analysisOptions!.includes('other:\n    version: "1.0.0"'));
    assert.ok(r.analysisOptions!.includes('saropa_lints:\n    version: "2.0.0"\n'));
  });

  it('is a no-op without a recommendation or without the file', () => {
    assert.deepStrictEqual(applyRecommendation({ pubspec: PUB, analysisOptions: AO }, {}), { pubspec: PUB, analysisOptions: AO });
    assert.deepStrictEqual(applyRecommendation({}, { constraint: '1.0.0', pluginVersion: '1.0.0' }), {});
  });
});

describe('applyRecommendation plugin entry forms', () => {
  const wrap = (entry: string[]): string => ['plugins:', ...entry, 'linter:', '  rules: {}', ''].join('\n');

  it('edits shorthand `saropa_lints: ^x`', () => {
    const ao = wrap(['  saropa_lints: ^16.7.0']);
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '16.10.0' });
    assert.strictEqual(r.analysisOptions, wrap(['  saropa_lints: 16.10.0']));
  });

  it('edits shorthand with quotes and trailing comment', () => {
    const ao = wrap(['  saropa_lints: "^16.7.0"  # pinned']);
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '16.10.0' });
    assert.strictEqual(r.analysisOptions, wrap(['  saropa_lints: "16.10.0"  # pinned']));
  });

  it('edits block form with trailing comment on the key and CRLF', () => {
    const ao = wrap(['  saropa_lints: # main', '    version: 16.7.0 # keep']).replace(/\n/g, '\r\n');
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '16.10.0' });
    assert.strictEqual(r.analysisOptions, ao.replace('16.7.0', '16.10.0'));
  });

  it('leaves a commented-out plugins block alone', () => {
    const ao = '# plugins:\n#   saropa_lints: ^16.7.0\n';
    const r = applyRecommendation({ analysisOptions: ao }, { pluginVersion: '16.10.0' });
    assert.strictEqual(r.analysisOptions, ao);
  });
});

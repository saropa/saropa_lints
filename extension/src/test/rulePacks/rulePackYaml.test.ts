/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as assert from 'assert';
import {
  parseRulePacksEnabled,
  writeRulePacksEnabled,
} from '../../rulePacks/rulePackYaml';

/** analysis_options rule_packs enabled list read/write round-trips. */

describe('rulePackYaml', () => {
  it('parseRulePacksEnabled reads enabled list', () => {
    const yaml = `
plugins:
  saropa_lints:
    version: "9.0.0"
    rule_packs:
      enabled:
        - riverpod
        - drift
    diagnostics:
      foo: true
`;
    const ids = parseRulePacksEnabled(yaml);
    assert.deepStrictEqual(ids, ['riverpod', 'drift']);
  });

  it('parseRulePacksEnabled returns empty when absent', () => {
    assert.deepStrictEqual(parseRulePacksEnabled('plugins:\n  saropa_lints:\n'), []);
  });

  it('parseRulePacksEnabled handles CRLF line endings', () => {
    const yaml =
      'plugins:\r\n  saropa_lints:\r\n    rule_packs:\r\n      enabled:\r\n        - riverpod\r\n';
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['riverpod']);
  });

  it('parseRulePacksEnabled supports legacy migration_packs alias', () => {
    const yaml = `
plugins:
  saropa_lints:
    migration_packs:
      enabled:
        - drift
`;
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['drift']);
  });

  it('parseRulePacksEnabled prefers rule_packs when both keys exist', () => {
    const yaml = `
plugins:
  saropa_lints:
    migration_packs:
      enabled:
        - drift
    rule_packs:
      enabled:
        - riverpod
`;
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['riverpod']);
  });

  it('parseRulePacksEnabled handles quoted ids and inline comments', () => {
    const yaml = `
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        - "riverpod" # app state
        - 'drift'    # database
`;
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['riverpod', 'drift']);
  });

  it('parseRulePacksEnabled ignores blank lines and comments in enabled block', () => {
    const yaml = `
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        # key packs
        - riverpod

        - drift
`;
    assert.deepStrictEqual(parseRulePacksEnabled(yaml), ['riverpod', 'drift']);
  });

  // rule_packs now lives in analysis_options_custom.yaml (canonical); the
  // writer also strips any legacy block from analysis_options.yaml.
  function withRoot(fn: (root: string, mainPath: string, customPath: string) => void): void {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      fn(root, path.join(root, 'analysis_options.yaml'), path.join(root, 'analysis_options_custom.yaml'));
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }

  it('writeRulePacksEnabled writes rule_packs to the custom file and removes legacy migration_packs from the main file', () => {
    withRoot((root, mainPath, customPath) => {
      fs.writeFileSync(
        mainPath,
        `
plugins:
  saropa_lints:
    version: "9.0.0"
    migration_packs:
      enabled:
        - drift
    diagnostics:
      foo: true
`,
        'utf-8',
      );

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod']), true);
      const custom = fs.readFileSync(customPath, 'utf-8');
      assert.strictEqual(custom.includes('rule_packs:'), true);
      assert.deepStrictEqual(parseRulePacksEnabled(custom), ['riverpod']);
      const main = fs.readFileSync(mainPath, 'utf-8');
      assert.strictEqual(main.includes('migration_packs:'), false);
      assert.strictEqual(main.includes('diagnostics:'), true, 'other content preserved');
    });
  });

  it('writeRulePacksEnabled creates the custom file and leaves an unrelated main file untouched', () => {
    withRoot((root, mainPath, customPath) => {
      const original = `analyzer:\n  errors:\n    todo: ignore\nlinter:\n  rules:\n    - curly_braces_in_flow_control_structures\n`;
      fs.writeFileSync(mainPath, original, 'utf-8');

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(customPath, 'utf-8')), ['riverpod']);
      assert.strictEqual(fs.readFileSync(mainPath, 'utf-8'), original);
    });
  });

  it('writeRulePacksEnabled does not touch an existing plugins block without saropa_lints', () => {
    withRoot((root, mainPath, customPath) => {
      const original = `plugins:\n  other_plugin:\n    enabled: true\n`;
      fs.writeFileSync(mainPath, original, 'utf-8');

      assert.strictEqual(writeRulePacksEnabled(root, ['drift']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(customPath, 'utf-8')), ['drift']);
      assert.strictEqual(fs.readFileSync(mainPath, 'utf-8'), original, 'other plugin preserved');
    });
  });

  it('round-trip: create -> toggle OFF -> toggle ON via the custom file', () => {
    withRoot((root, mainPath, customPath) => {
      fs.writeFileSync(mainPath, 'analyzer:\n  errors:\n    todo: ignore\n', 'utf-8');
      fs.writeFileSync(customPath, '# custom overrides\nplatforms:\n  ios: true\n', 'utf-8');
      const read = (): string => fs.readFileSync(customPath, 'utf-8');

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(read()), ['riverpod']);

      assert.strictEqual(writeRulePacksEnabled(root, []), true);
      assert.deepStrictEqual(parseRulePacksEnabled(read()), []);
      assert.strictEqual(read().includes('rule_packs:'), false);

      assert.strictEqual(writeRulePacksEnabled(root, ['drift']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(read()), ['drift']);
      assert.strictEqual(read().includes('platforms:'), true, 'other custom content preserved');
      assert.strictEqual(fs.readFileSync(mainPath, 'utf-8').includes('analyzer:'), true);
    });
  });

  // Regression: the saropa_lints package's own dev config omits the version
  // pin. Writing must succeed without needing any anchor in the main file.
  it('writeRulePacksEnabled succeeds when the main file has no version pin', () => {
    withRoot((root, mainPath, customPath) => {
      fs.writeFileSync(
        mainPath,
        `
plugins:
  saropa_lints:
    # No version: pin — plugin loads from workspace source.
    diagnostics:
      foo: true
`,
        'utf-8',
      );

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod', 'drift']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(customPath, 'utf-8')), ['riverpod', 'drift']);
      assert.strictEqual(fs.readFileSync(mainPath, 'utf-8').includes('diagnostics:'), true);
    });
  });
});

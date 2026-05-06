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

  it('writeRulePacksEnabled normalizes legacy migration_packs to rule_packs', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      const analysisPath = path.join(root, 'analysis_options.yaml');
      fs.writeFileSync(
        analysisPath,
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
      const content = fs.readFileSync(analysisPath, 'utf-8');
      assert.strictEqual(content.includes('migration_packs:'), false);
      assert.strictEqual(content.includes('rule_packs:'), true);
      assert.deepStrictEqual(parseRulePacksEnabled(content), ['riverpod']);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});

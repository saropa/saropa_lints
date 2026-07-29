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

  it('writeRulePacksEnabled creates plugins block when no saropa_lints key exists', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      const analysisPath = path.join(root, 'analysis_options.yaml');
      fs.writeFileSync(
        analysisPath,
        `analyzer:\n  errors:\n    todo: ignore\nlinter:\n  rules:\n    - curly_braces_in_flow_control_structures\n`,
        'utf-8',
      );

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod']), true);
      const content = fs.readFileSync(analysisPath, 'utf-8');
      assert.strictEqual(content.includes('plugins:'), true);
      assert.strictEqual(content.includes('saropa_lints:'), true);
      assert.strictEqual(content.includes('rule_packs:'), true);
      assert.deepStrictEqual(parseRulePacksEnabled(content), ['riverpod']);
      assert.strictEqual(content.includes('analyzer:'), true, 'original content preserved');
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('writeRulePacksEnabled inserts under existing plugins key without saropa_lints', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      const analysisPath = path.join(root, 'analysis_options.yaml');
      fs.writeFileSync(
        analysisPath,
        `plugins:\n  other_plugin:\n    enabled: true\n`,
        'utf-8',
      );

      assert.strictEqual(writeRulePacksEnabled(root, ['drift']), true);
      const content = fs.readFileSync(analysisPath, 'utf-8');
      assert.strictEqual(content.includes('saropa_lints:'), true);
      assert.strictEqual(content.includes('other_plugin:'), true, 'other plugin preserved');
      assert.deepStrictEqual(parseRulePacksEnabled(content), ['drift']);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  it('round-trip: fallback create → toggle OFF → toggle ON', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      const analysisPath = path.join(root, 'analysis_options.yaml');
      fs.writeFileSync(analysisPath, 'analyzer:\n  errors:\n    todo: ignore\n', 'utf-8');

      // ON: creates plugins block via final fallback.
      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(analysisPath, 'utf-8')), ['riverpod']);

      // OFF: RULE_PACK_BLOCK regex must match the fallback-created block.
      assert.strictEqual(writeRulePacksEnabled(root, []), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(analysisPath, 'utf-8')), []);

      // ON again: bare saropa_lints: key remains; pluginKey regex re-anchors.
      assert.strictEqual(writeRulePacksEnabled(root, ['drift']), true);
      assert.deepStrictEqual(parseRulePacksEnabled(fs.readFileSync(analysisPath, 'utf-8')), ['drift']);

      const final = fs.readFileSync(analysisPath, 'utf-8');
      assert.strictEqual(final.includes('analyzer:'), true, 'original content preserved');
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });

  // Regression: the saropa_lints package's own dev config omits the version
  // pin (plugin loads from workspace source). The writer must still find an
  // anchor; previously it returned false and surfaced "could not write
  // analysis_options.yaml (rule_packs)" on the upgrade nudge.
  it('writeRulePacksEnabled inserts block when version pin is absent', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-rule-packs-'));
    try {
      const analysisPath = path.join(root, 'analysis_options.yaml');
      fs.writeFileSync(
        analysisPath,
        `
plugins:
  saropa_lints:
    # No version: pin — plugin loads from workspace source.
    # Regenerate with: dart run saropa_lints:init --tier recommended
    diagnostics:
      foo: true
`,
        'utf-8',
      );

      assert.strictEqual(writeRulePacksEnabled(root, ['riverpod', 'drift']), true);
      const content = fs.readFileSync(analysisPath, 'utf-8');
      assert.strictEqual(content.includes('rule_packs:'), true);
      assert.strictEqual(content.includes('diagnostics:'), true);
      assert.deepStrictEqual(parseRulePacksEnabled(content), ['riverpod', 'drift']);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});

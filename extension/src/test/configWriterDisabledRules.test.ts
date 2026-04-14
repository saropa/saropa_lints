import * as assert from 'node:assert';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { readDisabledRules, invalidateDisabledRulesCache } from '../configWriter';

describe('readDisabledRules', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cw-'));
    // Clear the module-level cache so each test starts fresh.
    invalidateDisabledRulesCache();
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('returns empty set when no config files exist', () => {
    const result = readDisabledRules(tmpDir);
    assert.strictEqual(result.size, 0);
  });

  it('reads disabled rules from analysis_options.yaml diagnostics section', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: true',
      '      rule_b: false',
      '      rule_c: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const result = readDisabledRules(tmpDir);
    // rule_a is true (enabled), so only rule_b and rule_c should be disabled.
    assert.strictEqual(result.has('rule_a'), false);
    assert.strictEqual(result.has('rule_b'), true);
    assert.strictEqual(result.has('rule_c'), true);
    assert.strictEqual(result.size, 2);
  });

  it('skips comment lines in diagnostics section', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false  # some comment',
      '      # this is a comment',
      '      rule_b: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const result = readDisabledRules(tmpDir);
    assert.strictEqual(result.has('rule_a'), true);
    assert.strictEqual(result.has('rule_b'), true);
  });

  it('stops reading at less-indented lines', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '  other_section:',
      '      rule_b: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const result = readDisabledRules(tmpDir);
    // rule_b is under other_section, should not be picked up.
    assert.strictEqual(result.has('rule_a'), true);
    assert.strictEqual(result.has('rule_b'), false);
  });

  it('reads disabled rules from analysis_options_custom.yaml', () => {
    const customYaml = [
      '# RULE OVERRIDES',
      'rule_x: false',
      'rule_y: true',
      '',
    ].join('\n');
    fs.writeFileSync(
      path.join(tmpDir, 'analysis_options_custom.yaml'),
      customYaml,
    );

    const result = readDisabledRules(tmpDir);
    assert.strictEqual(result.has('rule_x'), true);
    // rule_y is explicitly true, should not be in disabled set.
    assert.strictEqual(result.has('rule_y'), false);
  });

  it('custom overrides take precedence over diagnostics', () => {
    // rule_a is disabled in diagnostics but re-enabled in custom overrides.
    const mainYaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '      rule_b: false',
      '',
    ].join('\n');
    const customYaml = [
      '# RULE OVERRIDES',
      'rule_a: true',
      '',
    ].join('\n');

    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), mainYaml);
    fs.writeFileSync(
      path.join(tmpDir, 'analysis_options_custom.yaml'),
      customYaml,
    );

    const result = readDisabledRules(tmpDir);
    // rule_a should NOT be disabled — custom override re-enabled it.
    assert.strictEqual(result.has('rule_a'), false);
    // rule_b remains disabled from diagnostics.
    assert.strictEqual(result.has('rule_b'), true);
  });

  it('returns empty set when diagnostics section is absent', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    tier: recommended',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const result = readDisabledRules(tmpDir);
    assert.strictEqual(result.size, 0);
  });

  it('returns cached result on second call for the same root', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const first = readDisabledRules(tmpDir);
    const second = readDisabledRules(tmpDir);
    // Same reference — cached, not re-read.
    assert.strictEqual(first, second);
  });

  it('returns fresh result after invalidateDisabledRulesCache', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const first = readDisabledRules(tmpDir);
    assert.strictEqual(first.size, 1);

    // Modify the file and invalidate cache.
    const yaml2 = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '      rule_b: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml2);
    invalidateDisabledRulesCache();

    const second = readDisabledRules(tmpDir);
    // Different reference — re-read after invalidation.
    assert.notStrictEqual(first, second);
    assert.strictEqual(second.size, 2);
  });

  it('invalidates cache when root changes', () => {
    const yaml = [
      'plugins:',
      '  saropa_lints:',
      '    diagnostics:',
      '      rule_a: false',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(tmpDir, 'analysis_options.yaml'), yaml);

    const first = readDisabledRules(tmpDir);
    // Call with a different root — should not return the cached set.
    const otherDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cw2-'));
    try {
      const second = readDisabledRules(otherDir);
      assert.notStrictEqual(first, second);
      // No config in otherDir, so empty.
      assert.strictEqual(second.size, 0);
    } finally {
      fs.rmSync(otherDir, { recursive: true, force: true });
    }
  });
});

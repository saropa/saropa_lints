import * as assert from 'node:assert';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { readViolations } from '../violationsReader';

describe('readViolations', () => {
  let tmpDir: string;

  /** Write a violations.json under the expected path and return the workspace root. */
  function writeJson(data: unknown): string {
    const reportDir = path.join(tmpDir, 'reports', '.saropa_lints');
    fs.mkdirSync(reportDir, { recursive: true });
    fs.writeFileSync(path.join(reportDir, 'violations.json'), JSON.stringify(data));
    return tmpDir;
  }

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-vr-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('returns null when violations.json does not exist', () => {
    assert.strictEqual(readViolations(tmpDir), null);
  });

  it('extracts rulesWithFixes when present as an array', () => {
    const root = writeJson({
      violations: [],
      config: { rulesWithFixes: ['rule_a', 'rule_b'] },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.config?.rulesWithFixes, ['rule_a', 'rule_b']);
  });

  it('returns undefined rulesWithFixes when field is absent (backward compat)', () => {
    const root = writeJson({
      violations: [],
      config: { tier: 'recommended' },
    });
    const data = readViolations(root);
    // Field absent → undefined, so downstream treats all violations as fixable.
    assert.strictEqual(data?.config?.rulesWithFixes, undefined);
  });

  it('returns undefined rulesWithFixes when field is not an array', () => {
    const root = writeJson({
      violations: [],
      config: { rulesWithFixes: 'not-an-array' },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.config?.rulesWithFixes, undefined);
  });

  it('returns undefined config when config block is absent', () => {
    const root = writeJson({ violations: [] });
    const data = readViolations(root);
    assert.strictEqual(data?.config, undefined);
  });

  it('handles empty rulesWithFixes array', () => {
    const root = writeJson({
      violations: [],
      config: { rulesWithFixes: [] },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.config?.rulesWithFixes, []);
  });

  // ── Suppression parsing ─────────────────────────────────────────────

  it('parses suppressions summary with total and byKind', () => {
    const root = writeJson({
      violations: [],
      summary: {
        totalViolations: 0,
        suppressions: {
          total: 14,
          byKind: { ignore: 8, ignoreForFile: 4, baseline: 2 },
        },
      },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.summary?.suppressions?.total, 14);
    assert.deepStrictEqual(data?.summary?.suppressions?.byKind, {
      ignore: 8,
      ignoreForFile: 4,
      baseline: 2,
    });
  });

  it('returns undefined suppressions when field is absent (backward compat)', () => {
    const root = writeJson({
      violations: [],
      summary: { totalViolations: 0 },
    });
    const data = readViolations(root);
    // Older violations.json files won't have the suppressions field.
    assert.strictEqual(data?.summary?.suppressions, undefined);
  });

  it('returns undefined suppressions when field is not an object', () => {
    const root = writeJson({
      violations: [],
      summary: { totalViolations: 0, suppressions: 'not-an-object' },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.summary?.suppressions, undefined);
  });

  it('handles suppressions with total only (no byKind)', () => {
    const root = writeJson({
      violations: [],
      summary: { suppressions: { total: 5 } },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.summary?.suppressions?.total, 5);
    assert.strictEqual(data?.summary?.suppressions?.byKind, undefined);
  });

  it('handles suppressions with non-numeric total gracefully', () => {
    const root = writeJson({
      violations: [],
      summary: { suppressions: { total: 'bad' } },
    });
    const data = readViolations(root);
    // Non-numeric total is dropped to undefined rather than propagated.
    assert.strictEqual(data?.summary?.suppressions?.total, undefined);
  });

  it('handles suppressions with zero total', () => {
    const root = writeJson({
      violations: [],
      summary: {
        suppressions: { total: 0, byKind: { ignore: 0, ignoreForFile: 0, baseline: 0 } },
      },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.summary?.suppressions?.total, 0);
  });

  it('parses suppressions byRule and byFile breakdowns', () => {
    const root = writeJson({
      violations: [],
      summary: {
        suppressions: {
          total: 7,
          byKind: { ignore: 5, ignoreForFile: 2 },
          byRule: { avoid_print: 4, require_https: 3 },
          byFile: { 'lib/app.dart': 5, 'lib/api.dart': 2 },
        },
      },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.summary?.suppressions?.byRule, {
      avoid_print: 4,
      require_https: 3,
    });
    assert.deepStrictEqual(data?.summary?.suppressions?.byFile, {
      'lib/app.dart': 5,
      'lib/api.dart': 2,
    });
  });

  it('returns undefined byRule/byFile when absent (backward compat)', () => {
    const root = writeJson({
      violations: [],
      summary: {
        suppressions: { total: 3, byKind: { ignore: 3 } },
      },
    });
    const data = readViolations(root);
    assert.strictEqual(data?.summary?.suppressions?.byRule, undefined);
    assert.strictEqual(data?.summary?.suppressions?.byFile, undefined);
  });
});

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
});

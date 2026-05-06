/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'node:assert';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import {
  getViolationsTriageState,
  normalizeLegacyImpact,
  readViolations,
  VIOLATIONS_EXPORT_STALE_MS,
} from '../violationsReader';

// Resolves .saropa_lints/reports/violations.json paths and normalizes issues.

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

  it('parses summary metadata breakdowns when present', () => {
    const root = writeJson({
      violations: [],
      summary: {
        byRuleType: { vulnerability: 5, codeSmell: 3 },
        byRuleStatus: { ready: 7, beta: 1 },
      },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.summary?.byRuleType, {
      vulnerability: 5,
      codeSmell: 3,
    });
    assert.deepStrictEqual(data?.summary?.byRuleStatus, {
      ready: 7,
      beta: 1,
    });
  });

  it('parses config.ruleMetadataByRule when present', () => {
    const root = writeJson({
      violations: [],
      config: {
        ruleMetadataByRule: {
          avoid_hardcoded_credentials: {
            ruleType: 'vulnerability',
            ruleStatus: 'ready',
            cweIds: [798],
            certIds: [],
            tags: ['security'],
            accuracyTarget: { minTruePositiveRate: 0.8 },
          },
        },
      },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(
      data?.config?.ruleMetadataByRule?.avoid_hardcoded_credentials?.cweIds,
      [798],
    );
  });

  it('parses config.conflictingRulesByRule when present', () => {
    const root = writeJson({
      violations: [],
      config: {
        conflictingRulesByRule: {
          prefer_type_over_var: ['prefer_var_over_explicit_type'],
        },
      },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.config?.conflictingRulesByRule, {
      prefer_type_over_var: ['prefer_var_over_explicit_type'],
    });
  });

  it('parses config.supersedesRulesByRule when present', () => {
    const root = writeJson({
      violations: [],
      config: {
        supersedesRulesByRule: {
          prefer_cubit_for_simple_state: ['prefer_cubit_for_simple'],
        },
      },
    });
    const data = readViolations(root);
    assert.deepStrictEqual(data?.config?.supersedesRulesByRule, {
      prefer_cubit_for_simple_state: ['prefer_cubit_for_simple'],
    });
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

  // Issue #208 follow-up: pre-13.4.x violations.json has 5-bucket impacts
  // (critical/high/medium/low/opinionated). The dashboard's filter only
  // accepts {error, warning, info}, so without normalization every legacy
  // finding gets filtered out — symptom: status pill shows "401 findings",
  // findings table shows "No violations match the current filters".
  describe('legacy impact normalization (issue #208 regression)', () => {
    it('rewrites violation.impact from 5-bucket to 3-bucket vocabulary', () => {
      const root = writeJson({
        violations: [
          { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', impact: 'critical' },
          { file: 'lib/a.dart', line: 2, rule: 'r2', message: 'm', impact: 'high' },
          { file: 'lib/a.dart', line: 3, rule: 'r3', message: 'm', impact: 'medium' },
          { file: 'lib/a.dart', line: 4, rule: 'r4', message: 'm', impact: 'low' },
          { file: 'lib/a.dart', line: 5, rule: 'r5', message: 'm', impact: 'opinionated' },
        ],
      });
      const data = readViolations(root);
      assert.deepStrictEqual(
        data?.violations.map((v) => v.impact),
        ['error', 'warning', 'warning', 'info', 'info'],
      );
    });

    it('leaves already-normalized impacts untouched (post-13.4.x happy path)', () => {
      const root = writeJson({
        violations: [
          { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', impact: 'error' },
          { file: 'lib/a.dart', line: 2, rule: 'r2', message: 'm', impact: 'warning' },
          { file: 'lib/a.dart', line: 3, rule: 'r3', message: 'm', impact: 'info' },
        ],
      });
      const data = readViolations(root);
      assert.deepStrictEqual(
        data?.violations.map((v) => v.impact),
        ['error', 'warning', 'info'],
      );
    });

    it('merges summary.byImpact counts where two legacy keys collapse onto one', () => {
      // critical → error (1)
      // high (3) + medium (4) → warning (7)
      // low (5) + opinionated (2) → info (7)
      const root = writeJson({
        violations: [],
        summary: {
          byImpact: { critical: 1, high: 3, medium: 4, low: 5, opinionated: 2 },
        },
      });
      const data = readViolations(root);
      assert.deepStrictEqual(data?.summary?.byImpact, {
        error: 1,
        warning: 7,
        info: 7,
      });
    });

    it('returns empty byImpact when summary.byImpact is absent', () => {
      const root = writeJson({ violations: [], summary: { totalViolations: 0 } });
      const data = readViolations(root);
      assert.strictEqual(data?.summary?.byImpact, undefined);
    });

    it('passes unknown impact strings through (lowercased) without dropping', () => {
      // Forward-compat: a future LintImpact value should not be silently
      // erased by this layer; downstream filters can decide how to render it.
      const root = writeJson({
        violations: [
          { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', impact: 'CRITICAL' },
          { file: 'lib/a.dart', line: 2, rule: 'r2', message: 'm', impact: 'novel' },
        ],
      });
      const data = readViolations(root);
      assert.strictEqual(data?.violations[0].impact, 'error');
      assert.strictEqual(data?.violations[1].impact, 'novel');
    });
  });
});

describe('normalizeLegacyImpact', () => {
  it('maps each 5-bucket value to its 3-bucket replacement', () => {
    assert.strictEqual(normalizeLegacyImpact('critical'), 'error');
    assert.strictEqual(normalizeLegacyImpact('high'), 'warning');
    assert.strictEqual(normalizeLegacyImpact('medium'), 'warning');
    assert.strictEqual(normalizeLegacyImpact('low'), 'info');
    assert.strictEqual(normalizeLegacyImpact('opinionated'), 'info');
  });

  it('passes the post-collapse vocabulary through unchanged', () => {
    assert.strictEqual(normalizeLegacyImpact('error'), 'error');
    assert.strictEqual(normalizeLegacyImpact('warning'), 'warning');
    assert.strictEqual(normalizeLegacyImpact('info'), 'info');
  });

  it('returns undefined for null/undefined input', () => {
    assert.strictEqual(normalizeLegacyImpact(undefined), undefined);
    assert.strictEqual(normalizeLegacyImpact(null), undefined);
  });

  it('lowercases mixed-case input', () => {
    assert.strictEqual(normalizeLegacyImpact('Critical'), 'error');
    assert.strictEqual(normalizeLegacyImpact('HIGH'), 'warning');
  });
});

describe('getViolationsTriageState', () => {
  let tmpDir: string;

  function writeAtPath(root: string, data: unknown): string {
    const reportDir = path.join(root, 'reports', '.saropa_lints');
    fs.mkdirSync(reportDir, { recursive: true });
    const p = path.join(reportDir, 'violations.json');
    fs.writeFileSync(p, JSON.stringify(data));
    return p;
  }

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-vr-triage-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('is ok for a fresh file with issuesByRule', () => {
    writeAtPath(tmpDir, {
      violations: [],
      summary: { issuesByRule: {}, totalViolations: 0 },
    });
    const data = readViolations(tmpDir);
    const s = getViolationsTriageState(tmpDir, data);
    assert.strictEqual(s.triage.kind, 'ok');
  });

  it('is stale when mtime is older than the export window', () => {
    const p = writeAtPath(tmpDir, {
      violations: [],
      summary: { issuesByRule: { a: 1 } },
    });
    const old = new Date(Date.now() - VIOLATIONS_EXPORT_STALE_MS - 60_000);
    fs.utimesSync(p, old, old);
    const data = readViolations(tmpDir);
    const s = getViolationsTriageState(tmpDir, data);
    assert.strictEqual(s.triage.kind, 'stale');
    if (s.triage.kind === 'stale') {
      assert.ok(s.triage.ageMs > VIOLATIONS_EXPORT_STALE_MS);
    }
  });

  it('is incomplete when summary.issuesByRule is absent', () => {
    writeAtPath(tmpDir, { violations: [], summary: { totalViolations: 0 } });
    const data = readViolations(tmpDir);
    const s = getViolationsTriageState(tmpDir, data);
    assert.deepStrictEqual(s.triage, { kind: 'incomplete', reason: 'no_per_rule' });
  });
});

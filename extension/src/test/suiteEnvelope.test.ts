/**
 * Tests for the Saropa Diagnostic Envelope producer (plan requirement R1).
 *
 * Pins the contract the two sibling extensions depend on: the `source: "lints"`
 * shape, the category derivation (Drift wins over a security/perf tag because the
 * flagship Drift Health loop joins on it), the finding-id round-trip that
 * `saropaLints.openFinding` relies on (including a Windows path with an interior
 * colon), severity coercion, the deep-link fix targeting the public
 * `saropaLints.explainRule` id, and that the writer lands the file at
 * `.saropa/diagnostics/lints.json`.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

import {
  buildFindingId,
  buildLintsEnvelope,
  deriveCategory,
  lintsMirrorPath,
  parseFindingId,
  writeLintsEnvelope,
  type BuildEnvelopeOptions,
} from '../suite/envelope';
import type { RuleMetadataData, ViolationsData } from '../violationsReader';

const baseOpts: BuildEnvelopeOptions = {
  producerVersion: '13.12.7',
  generatedAt: '2026-06-13T00:00:00.000Z',
  fixTitle: 'Explain this rule',
};

describe('suite/envelope deriveCategory', () => {
  it('classifies any drift rule as drift, even when it also carries a security tag', () => {
    const meta: RuleMetadataData = { tags: ['security'], cweIds: [89] };
    assert.strictEqual(deriveCategory('avoid_drift_raw_sql_interpolation', meta), 'drift');
  });

  it('classifies a vulnerability rule-type as security', () => {
    assert.strictEqual(deriveCategory('avoid_hardcoded_secret', { ruleType: 'vulnerability' }), 'security');
  });

  it('classifies a rule with a CWE mapping as security', () => {
    assert.strictEqual(deriveCategory('some_rule', { cweIds: [79] }), 'security');
  });

  it('classifies a performance-tagged rule as performance', () => {
    assert.strictEqual(deriveCategory('avoid_expensive_build', { tags: ['performance'] }), 'performance');
  });

  it('classifies an accessibility-tagged rule as a11y', () => {
    assert.strictEqual(deriveCategory('require_semantic_label', { tags: ['accessibility'] }), 'a11y');
  });

  it('falls back to other when no domain signal exists', () => {
    assert.strictEqual(deriveCategory('prefer_final_locals', { tags: ['readability'] }), 'other');
    assert.strictEqual(deriveCategory('prefer_final_locals', undefined), 'other');
  });
});

describe('suite/envelope finding id round-trip', () => {
  it('builds and parses a finding id', () => {
    const id = buildFindingId({ file: 'lib/a.dart', line: 42, rule: 'my_rule', message: 'x' });
    assert.strictEqual(id, 'lints:my_rule:lib/a.dart:42');
    assert.deepStrictEqual(parseFindingId(id), { rule: 'my_rule', file: 'lib/a.dart', line: 42 });
  });

  it('preserves a file path containing an interior colon', () => {
    const id = 'lints:my_rule:C:/src/app/lib/a.dart:7';
    assert.deepStrictEqual(parseFindingId(id), { rule: 'my_rule', file: 'C:/src/app/lib/a.dart', line: 7 });
  });

  it('rejects non-lints and malformed ids', () => {
    assert.strictEqual(parseFindingId('advisor:foo:bar:1'), null);
    assert.strictEqual(parseFindingId('lints:onlyrule'), null);
    assert.strictEqual(parseFindingId('lints:rule:file:notanumber'), null);
  });
});

describe('suite/envelope buildLintsEnvelope', () => {
  const data: ViolationsData = {
    violations: [
      { file: 'lib/db.dart', line: 10, rule: 'avoid_drift_update_without_where', message: 'No WHERE clause', severity: 'error' },
      { file: 'lib/a.dart', line: 3, rule: 'prefer_final_locals', message: 'Prefer final', severity: 'info' },
    ],
  };

  it('produces a schema-conformant envelope with source lints', () => {
    const env = buildLintsEnvelope(data, baseOpts);
    assert.strictEqual(env.schemaVersion, 1);
    assert.strictEqual(env.producer.name, 'saropa_lints');
    assert.strictEqual(env.producer.version, '13.12.7');
    assert.strictEqual(env.generatedAt, '2026-06-13T00:00:00.000Z');
    assert.strictEqual(env.diagnostics.length, 2);
  });

  it('maps a finding to a diagnostic with a deep-link fix to explainRule', () => {
    const env = buildLintsEnvelope(data, baseOpts);
    const drift = env.diagnostics[0];
    assert.strictEqual(drift.source, 'lints');
    assert.strictEqual(drift.severity, 'error');
    assert.strictEqual(drift.category, 'drift');
    assert.strictEqual(drift.ruleId, 'avoid_drift_update_without_where');
    assert.strictEqual(drift.location.file, 'lib/db.dart');
    assert.strictEqual(drift.location.line, 10);
    assert.strictEqual(drift.fix?.command, 'saropaLints.explainRule');
    assert.deepStrictEqual(drift.fix?.args, [{ ruleId: 'avoid_drift_update_without_where' }]);
    assert.strictEqual(drift.id, 'lints:avoid_drift_update_without_where:lib/db.dart:10');
  });

  it('coerces an unknown severity to info', () => {
    const env = buildLintsEnvelope(
      { violations: [{ file: 'lib/a.dart', line: 1, rule: 'r', message: 'm', severity: 'critical' }] },
      baseOpts,
    );
    assert.strictEqual(env.diagnostics[0].severity, 'info');
  });

  it('stamps commitSha only when supplied', () => {
    const withSha = buildLintsEnvelope(data, { ...baseOpts, commitSha: 'abc123' });
    assert.strictEqual(withSha.diagnostics[0].commitSha, 'abc123');
    const without = buildLintsEnvelope(data, baseOpts);
    assert.strictEqual(without.diagnostics[0].commitSha, undefined);
  });
});

describe('suite/envelope writeLintsEnvelope', () => {
  it('writes the mirror at .saropa/diagnostics/lints.json', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-envelope-'));
    const env = buildLintsEnvelope({ violations: [] }, baseOpts);
    const written = writeLintsEnvelope(root, env);
    assert.strictEqual(written, lintsMirrorPath(root));
    assert.strictEqual(written, path.join(root, '.saropa', 'diagnostics', 'lints.json'));
    const parsed = JSON.parse(fs.readFileSync(written, 'utf-8'));
    assert.strictEqual(parsed.schemaVersion, 1);
    assert.strictEqual(parsed.producer.name, 'saropa_lints');
  });
});

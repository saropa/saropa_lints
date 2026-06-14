/**
 * Tests for the sibling-envelope consumer (plan requirement R2).
 *
 * Pins the correlation contract the dashboard badges depend on: evidence is
 * counted ONLY from the explicit protocol signal — a sibling diagnostic whose
 * `fix.command` is a Lints deep-link id carrying a `{ ruleId }` arg — and bucketed
 * by which mirror (advisor vs log-capture) it came from. A diagnostic without that
 * cross-reference contributes nothing, and a missing or malformed mirror yields no
 * evidence rather than throwing (a sibling mid-write must not break the dashboard).
 */

import * as assert from 'node:assert';
import * as path from 'node:path';

import {
  buildSuiteEvidence,
  hasEvidence,
  type ReadFileFn,
} from '../suite/siblingEnvelopes';

const ROOT = '/workspace';
const ADVISOR = path.join(ROOT, '.saropa', 'diagnostics', 'advisor.json');
const LOG_CAPTURE = path.join(ROOT, '.saropa', 'diagnostics', 'log-capture.json');

/** A reader backed by an in-memory map; any unlisted path reads as missing (null). */
function reader(files: Record<string, string>): ReadFileFn {
  return (absPath: string) => files[absPath] ?? null;
}

function envelope(diagnostics: unknown[]): string {
  return JSON.stringify({ schemaVersion: 1, diagnostics });
}

function deepLink(command: string, ruleId: string): unknown {
  return { fix: { command, args: [{ ruleId }] } };
}

describe('suite/siblingEnvelopes buildSuiteEvidence', () => {
  it('counts an Advisor diagnostic that deep-links a Lints rule', () => {
    const ev = buildSuiteEvidence(
      ROOT,
      reader({ [ADVISOR]: envelope([deepLink('saropaLints.explainRule', 'require_database_index')]) }),
    );
    assert.deepStrictEqual(ev.get('require_database_index'), { advisorCount: 1, logCaptureCount: 0 });
  });

  it('buckets advisor and log-capture references to the same rule separately', () => {
    const ev = buildSuiteEvidence(
      ROOT,
      reader({
        [ADVISOR]: envelope([deepLink('saropaLints.explainRule', 'avoid_drift_update_without_where')]),
        [LOG_CAPTURE]: envelope([
          deepLink('saropaLints.enableRule', 'avoid_drift_update_without_where'),
          deepLink('saropaLints.openFinding', 'avoid_drift_update_without_where'),
        ]),
      }),
    );
    assert.deepStrictEqual(ev.get('avoid_drift_update_without_where'), {
      advisorCount: 1,
      logCaptureCount: 2,
    });
  });

  it('ignores diagnostics with no Lints deep-link cross-reference', () => {
    const ev = buildSuiteEvidence(
      ROOT,
      reader({
        [ADVISOR]: envelope([
          { fix: { command: 'driftViewer.openTable', args: [{ table: 'users' }] } },
          { ruleId: 'some_advisor_check', severity: 'warning' },
          deepLink('saropaLints.explainRule', ''),
        ]),
      }),
    );
    assert.strictEqual(ev.size, 0);
  });

  it('returns an empty map when no mirror files exist', () => {
    const ev = buildSuiteEvidence(ROOT, reader({}));
    assert.strictEqual(ev.size, 0);
  });

  it('tolerates a malformed mirror without throwing', () => {
    const ev = buildSuiteEvidence(ROOT, reader({ [ADVISOR]: '{ not valid json' }));
    assert.strictEqual(ev.size, 0);
  });

  it('tolerates an envelope with no diagnostics array', () => {
    const ev = buildSuiteEvidence(ROOT, reader({ [ADVISOR]: JSON.stringify({ schemaVersion: 1 }) }));
    assert.strictEqual(ev.size, 0);
  });
});

describe('suite/siblingEnvelopes hasEvidence', () => {
  it('is true only when some count is positive', () => {
    assert.strictEqual(hasEvidence(undefined), false);
    assert.strictEqual(hasEvidence({ advisorCount: 0, logCaptureCount: 0 }), false);
    assert.strictEqual(hasEvidence({ advisorCount: 1, logCaptureCount: 0 }), true);
    assert.strictEqual(hasEvidence({ advisorCount: 0, logCaptureCount: 3 }), true);
  });
});

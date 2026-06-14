/**
 * Tests for crash-to-rule attribution (plan requirement R3).
 *
 * Pins three contracts:
 *  1. The frozen crash-signature set matches Log Capture's exactly (renaming a
 *     signature on either side silently breaks the loop, so the set is asserted
 *     member-for-member here).
 *  2. Every rule id the map points at is a REAL rule (cross-checked against the
 *     bundled `media/rules_catalog.json`) — a typo'd id would silently never fire
 *     the "enable rule X" nudge.
 *  3. The reader is tolerant: a missing / malformed / non-crash / unknown-signature
 *     mirror yields no suggestions rather than throwing, and only DISABLED mapped
 *     rules surface as suggestions.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  CRASH_PREFIX,
  CRASH_SIGNATURE_TO_RULES,
  findCrashCoveredDisabledRules,
  readCrashCounts,
  type CrashSignature,
  type ReadFileFn,
} from '../suite/crashToRule';

const ROOT = '/workspace';
const LOG_CAPTURE = path.join(ROOT, '.saropa', 'diagnostics', 'log-capture.json');

/** A reader backed by an in-memory map; any unlisted path reads as missing (null). */
function reader(files: Record<string, string>): ReadFileFn {
  return (absPath: string) => files[absPath] ?? null;
}

/** Build a log-capture envelope from raw diagnostic objects. */
function envelope(diagnostics: unknown[]): string {
  return JSON.stringify({ schemaVersion: 1, diagnostics });
}

/** One crash diagnostic as Log Capture emits it: category "crash", `crash:`-prefixed ruleId. */
function crash(signature: string): unknown {
  return { category: 'crash', ruleId: `${CRASH_PREFIX}${signature}` };
}

/** Locate the real bundled catalog regardless of compiled test layout. */
function catalogPath(): string {
  const candidates = [
    path.resolve(__dirname, '..', '..', 'media', 'rules_catalog.json'),
    path.resolve(__dirname, '..', '..', '..', 'media', 'rules_catalog.json'),
    path.resolve(process.cwd(), 'media', 'rules_catalog.json'),
  ];
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) {
    throw new Error(`rules_catalog.json not found; looked in:\n${candidates.join('\n')}`);
  }
  return found;
}

/** The 12 frozen signatures, mirrored from Log Capture's crash-signature.ts. */
const FROZEN_SIGNATURES: CrashSignature[] = [
  'state-error-no-element',
  'range-error-index',
  'null-check-operator',
  'late-init',
  'concurrent-modification',
  'type-error-cast',
  'format-exception',
  'no-such-method',
  'assertion-failed',
  'stack-overflow',
  'out-of-memory',
  'anr',
];

describe('suite/crashToRule frozen signature set', () => {
  it('maps exactly the frozen signature set, no more no less', () => {
    assert.deepStrictEqual(
      Object.keys(CRASH_SIGNATURE_TO_RULES).sort(),
      [...FROZEN_SIGNATURES].sort(),
    );
  });

  it('every mapped rule id is a real rule in the bundled catalog', () => {
    const parsed = JSON.parse(fs.readFileSync(catalogPath(), 'utf-8')) as {
      rules?: Record<string, unknown>;
    };
    const known = new Set(Object.keys(parsed.rules ?? {}));
    const unknownIds: string[] = [];
    for (const rules of Object.values(CRASH_SIGNATURE_TO_RULES)) {
      for (const ruleId of rules) {
        if (!known.has(ruleId)) unknownIds.push(ruleId);
      }
    }
    assert.deepStrictEqual(unknownIds, [], `mapped rule ids absent from catalog: ${unknownIds}`);
  });

  it('lists no duplicate rule id within a single signature', () => {
    for (const [sig, rules] of Object.entries(CRASH_SIGNATURE_TO_RULES)) {
      assert.strictEqual(new Set(rules).size, rules.length, `duplicate rule in ${sig}`);
    }
  });
});

describe('suite/crashToRule readCrashCounts', () => {
  it('counts crash diagnostics per signature, repeats included', () => {
    const counts = readCrashCounts(
      ROOT,
      reader({
        [LOG_CAPTURE]: envelope([
          crash('null-check-operator'),
          crash('null-check-operator'),
          crash('range-error-index'),
        ]),
      }),
    );
    assert.strictEqual(counts.get('null-check-operator'), 2);
    assert.strictEqual(counts.get('range-error-index'), 1);
  });

  it('ignores non-crash diagnostics and unknown signatures', () => {
    const counts = readCrashCounts(
      ROOT,
      reader({
        [LOG_CAPTURE]: envelope([
          { category: 'performance', ruleId: 'crash:null-check-operator' },
          { category: 'crash', ruleId: 'crash:some-future-family-lints-does-not-know' },
          { category: 'crash', ruleId: 'null-check-operator' }, // missing crash: prefix
          crash('anr'),
        ]),
      }),
    );
    assert.strictEqual(counts.size, 1);
    assert.strictEqual(counts.get('anr'), 1);
  });

  it('yields an empty map for a missing or malformed mirror', () => {
    assert.strictEqual(readCrashCounts(ROOT, reader({})).size, 0);
    assert.strictEqual(readCrashCounts(ROOT, reader({ [LOG_CAPTURE]: '{ not json' })).size, 0);
    assert.strictEqual(
      readCrashCounts(ROOT, reader({ [LOG_CAPTURE]: JSON.stringify({ diagnostics: 'nope' }) })).size,
      0,
    );
  });
});

describe('suite/crashToRule findCrashCoveredDisabledRules', () => {
  const mirror = reader({
    [LOG_CAPTURE]: envelope([crash('null-check-operator'), crash('null-check-operator')]),
  });

  it('suggests only mapped rules that are currently disabled', () => {
    // avoid_null_assertion disabled, avoid_non_null_assertion enabled.
    const suggestions = findCrashCoveredDisabledRules(
      ROOT,
      new Set(['avoid_null_assertion']),
      mirror,
    );
    assert.deepStrictEqual(
      suggestions.map((s) => s.ruleId),
      ['avoid_null_assertion'],
    );
    assert.strictEqual(suggestions[0].occurrences, 2);
    assert.strictEqual(suggestions[0].signature, 'null-check-operator');
  });

  it('produces nothing when every mapped rule is enabled', () => {
    assert.deepStrictEqual(findCrashCoveredDisabledRules(ROOT, new Set(), mirror), []);
  });

  it('produces nothing when the crash family was not observed', () => {
    const other = reader({ [LOG_CAPTURE]: envelope([crash('anr')]) });
    const suggestions = findCrashCoveredDisabledRules(
      ROOT,
      new Set(['avoid_null_assertion']),
      other,
    );
    assert.deepStrictEqual(suggestions, []);
  });
});

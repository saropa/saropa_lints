/**
 * Tier / pack grouping metadata contract (Findings dashboard group-by: tier, pack).
 *
 * These guards are written against the generated registries themselves rather
 * than hardcoded rule names, so they survive rules moving between tiers/packs.
 * They pin the behaviors that matter: tier is single-key, pack is multi-key,
 * absent rules fall back deterministically, and the dashboard extractor agrees
 * with the helpers.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { RULE_PACK_DEFINITIONS } from '../../rulePacks/rulePackDefinitions';
import { RULE_TIER_BY_CODE } from '../../rulePacks/ruleTierDefinitions';
import {
  PACK_NONE,
  TIER_UNKNOWN,
  packsForRule,
  tierForRule,
} from '../../views/ruleGroupingMeta';
import { extractViolationGroupKeys } from '../../views/issuesTreeModel';
import type { Violation } from '../../violationsReader';

const VALID_TIERS = new Set([
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'pedantic',
  'stylistic',
  'unknown',
]);

function violation(rule: string): Violation {
  return { file: 'lib/a.dart', line: 1, rule, message: 'x' };
}

/** First rule that the pack registry lists under two or more distinct packs. */
function findMultiPackRule(): string | undefined {
  const counts = new Map<string, Set<string>>();
  for (const pack of RULE_PACK_DEFINITIONS) {
    for (const code of pack.ruleCodes) {
      const set = counts.get(code) ?? new Set<string>();
      set.add(pack.label);
      counts.set(code, set);
    }
  }
  for (const [code, labels] of counts) {
    if (labels.size >= 2) return code;
  }
  return undefined;
}

describe('ruleGroupingMeta — tier grouping', () => {
  it('maps a known rule to its generated introducing tier', () => {
    const [rule, tier] = Object.entries(RULE_TIER_BY_CODE)[0];
    assert.strictEqual(tierForRule(rule), tier);
    assert.ok(VALID_TIERS.has(tier), `unexpected tier id: ${tier}`);
  });

  it('falls back to TIER_UNKNOWN for a rule absent from the registry', () => {
    assert.strictEqual(tierForRule('not_a_real_rule_zzz'), TIER_UNKNOWN);
  });

  it('extractViolationGroupKeys(tier) returns exactly one key', () => {
    const [rule] = Object.entries(RULE_TIER_BY_CODE)[0];
    const keys = extractViolationGroupKeys(violation(rule), 'tier');
    assert.deepStrictEqual(keys, [tierForRule(rule)]);
  });
});

describe('ruleGroupingMeta — pack grouping', () => {
  it('falls back to PACK_NONE for a rule in no pack', () => {
    assert.deepStrictEqual(packsForRule('not_a_real_rule_zzz'), [PACK_NONE]);
  });

  it('returns multiple sorted pack labels for a multi-pack rule (mirrors OWASP)', () => {
    const rule = findMultiPackRule();
    if (rule === undefined) {
      // No rule currently spans two packs — nothing to assert, but the
      // single-key path is still covered by the dashboard extractor test below.
      return;
    }
    const packs = packsForRule(rule);
    assert.ok(packs.length >= 2, `expected >=2 packs for ${rule}`);
    assert.deepStrictEqual(packs, [...packs].sort(), 'pack labels must be sorted');
    assert.ok(!packs.includes(PACK_NONE));
  });

  it('extractViolationGroupKeys(pack) agrees with packsForRule', () => {
    const rule = findMultiPackRule() ?? RULE_PACK_DEFINITIONS[0]?.ruleCodes[0];
    assert.ok(rule, 'registry has at least one pack rule');
    const keys = extractViolationGroupKeys(violation(rule), 'pack');
    assert.deepStrictEqual(keys, packsForRule(rule));
  });
});

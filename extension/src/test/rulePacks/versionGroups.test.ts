/**
 * Unit tests for version-group derivation and single-version enforcement
 * ({@link computeVersionGroups}, {@link versionGroupIndex},
 * {@link enforceSingleVersion}).
 *
 * Covers grouping against the live registry (so a new version companion is caught
 * by the count assertions) plus the exclusivity contract on a synthetic registry
 * (so the edge cases — base pack that is itself gated, lone gated pack — are
 * pinned independent of the real data drifting over time).
 */

import * as assert from 'node:assert';
import type { RulePackDefinition } from '../../rulePacks/rulePackDefinitions';
import { RULE_PACK_DEFINITIONS } from '../../rulePacks/rulePackDefinitions';
import {
  computeVersionGroups,
  versionGroupIndex,
  enforceSingleVersion,
} from '../../rulePacks/versionGroups';

/** Minimal synthetic registry exercising every grouping shape. */
const SYNTHETIC: RulePackDefinition[] = [
  // Base + one companion → a 2-member group.
  { id: 'dio', label: 'Dio', matchPubNames: ['dio'], ruleCodes: ['a'] },
  {
    id: 'dio_5',
    label: 'Dio 5',
    matchPubNames: ['dio'],
    ruleCodes: ['b'],
    dependencyGate: { package: 'dio', constraint: '>=5.0.0' },
  },
  // Base + two companions → a 3-member group.
  { id: 'riverpod', label: 'Riverpod', matchPubNames: ['riverpod'], ruleCodes: ['c'] },
  {
    id: 'riverpod_2',
    label: 'Riverpod 2',
    matchPubNames: ['riverpod'],
    ruleCodes: ['d'],
    dependencyGate: { package: 'riverpod', constraint: '>=2.0.0' },
  },
  {
    id: 'riverpod_3',
    label: 'Riverpod 3',
    matchPubNames: ['riverpod'],
    ruleCodes: ['e'],
    dependencyGate: { package: 'riverpod', constraint: '>=3.0.0' },
  },
  // Base pack that is ITSELF gated, plus a companion → still a 2-member group,
  // counted once (not twice for matching both the id and the gate branch).
  {
    id: 'google_sign_in',
    label: 'google_sign_in',
    matchPubNames: ['google_sign_in'],
    ruleCodes: ['f'],
    dependencyGate: { package: 'google_sign_in', constraint: '>=6.0.0' },
  },
  {
    id: 'google_sign_in_7',
    label: 'google_sign_in 7',
    matchPubNames: ['google_sign_in'],
    ruleCodes: ['g'],
    dependencyGate: { package: 'google_sign_in', constraint: '>=7.0.0' },
  },
  // Lone gated pack with no sibling → NOT a group.
  {
    id: 'collection_compat',
    label: 'collection compat',
    matchPubNames: ['collection'],
    ruleCodes: ['h'],
    dependencyGate: { package: 'collection', constraint: '<1.19.0' },
  },
  // An unrelated ungated pack → never grouped.
  { id: 'accessibility', label: 'Accessibility', matchPubNames: ['flutter'], ruleCodes: ['i'] },
];

describe('computeVersionGroups (synthetic)', () => {
  const groups = computeVersionGroups(SYNTHETIC);

  it('returns one group per multi-member dependency, sorted by dependency', () => {
    assert.deepStrictEqual(
      groups.map((g) => g.dependency),
      ['dio', 'google_sign_in', 'riverpod'],
    );
  });

  it('orders the base pack (id === dependency) first, then companions', () => {
    const riverpod = groups.find((g) => g.dependency === 'riverpod');
    assert.deepStrictEqual(riverpod?.packIds, ['riverpod', 'riverpod_2', 'riverpod_3']);
  });

  it('counts a self-gated base pack exactly once', () => {
    const gsi = groups.find((g) => g.dependency === 'google_sign_in');
    assert.deepStrictEqual(gsi?.packIds, ['google_sign_in', 'google_sign_in_7']);
  });

  it('excludes a lone gated pack with no sibling', () => {
    assert.ok(!groups.some((g) => g.dependency === 'collection'));
  });
});

describe('versionGroupIndex (synthetic)', () => {
  const index = versionGroupIndex(SYNTHETIC);

  it('maps every grouped member to its dependency', () => {
    assert.strictEqual(index.get('dio'), 'dio');
    assert.strictEqual(index.get('dio_5'), 'dio');
    assert.strictEqual(index.get('riverpod_3'), 'riverpod');
    assert.strictEqual(index.get('google_sign_in_7'), 'google_sign_in');
  });

  it('omits ungrouped packs', () => {
    assert.strictEqual(index.get('collection_compat'), undefined);
    assert.strictEqual(index.get('accessibility'), undefined);
  });
});

describe('enforceSingleVersion (synthetic)', () => {
  it('drops sibling versions when one is enabled', () => {
    const next = enforceSingleVersion(SYNTHETIC, ['dio', 'dio_5', 'accessibility'], 'dio_5');
    assert.deepStrictEqual(next.sort(), ['accessibility', 'dio_5']);
  });

  it('keeps the just-enabled pack and unrelated packs', () => {
    const next = enforceSingleVersion(
      SYNTHETIC,
      ['riverpod', 'riverpod_2', 'riverpod_3', 'collection_compat'],
      'riverpod_2',
    );
    assert.deepStrictEqual(next.sort(), ['collection_compat', 'riverpod_2']);
  });

  it('is a no-op for a pack outside any version group', () => {
    const cur = ['accessibility', 'collection_compat'];
    assert.deepStrictEqual(enforceSingleVersion(SYNTHETIC, cur, 'collection_compat'), cur);
  });

  it('does not touch other dependencies sharing the enabled set', () => {
    const next = enforceSingleVersion(SYNTHETIC, ['dio', 'riverpod', 'riverpod_2'], 'dio');
    assert.deepStrictEqual(next.sort(), ['dio', 'riverpod', 'riverpod_2']);
  });
});

describe('computeVersionGroups (live registry)', () => {
  const groups = computeVersionGroups(RULE_PACK_DEFINITIONS);
  const byDep = new Map(groups.map((g) => [g.dependency, g]));

  it('groups the known multi-version packages', () => {
    for (const dep of ['app_links', 'dio', 'riverpod', 'file_picker', 'google_sign_in']) {
      assert.ok(byDep.has(dep), `expected a version group for ${dep}`);
    }
  });

  it('groups dio as base + dio_5', () => {
    assert.deepStrictEqual(byDep.get('dio')?.packIds, ['dio', 'dio_5']);
  });

  it('groups riverpod as base + 2 + 3', () => {
    assert.deepStrictEqual(byDep.get('riverpod')?.packIds, ['riverpod', 'riverpod_2', 'riverpod_3']);
  });

  it('never lists a single-member group', () => {
    for (const g of groups) {
      assert.ok(g.packIds.length >= 2, `${g.dependency} has only ${g.packIds.length} member`);
    }
  });

  it('every member id refers to a real pack', () => {
    const ids = new Set(RULE_PACK_DEFINITIONS.map((d) => d.id));
    for (const g of groups) {
      for (const id of g.packIds) {
        assert.ok(ids.has(id), `group ${g.dependency} references unknown pack ${id}`);
      }
    }
  });
});

import * as assert from 'assert';
import {
  buildTierChips,
  compareSdkPackRowsByRisk,
  computePackDashboardStats,
  sdkPackMatchesSelection,
  sdkPackRiskKind,
} from '../../rulePacks/rulePacksWebviewProvider';

describe('rulePacksWebviewProvider dashboard helpers', () => {
  it('computes enabled and detected pack/rule totals', () => {
    const stats = computePackDashboardStats([
      { id: 'a', label: 'A', rules: 3, enabled: true, detected: false },
      { id: 'b', label: 'B', rules: 5, enabled: false, detected: true },
      { id: 'c', label: 'C', rules: 2, enabled: true, detected: true },
    ]);

    assert.deepStrictEqual(stats, {
      totalPacks: 3,
      enabledPacks: 2,
      detectedPacks: 2,
      enabledRules: 5,
      detectedRules: 7,
    });
  });

  it('marks the current tier chip', () => {
    const html = buildTierChips('recommended');
    assert.ok(html.includes('recommended (current)'));
    assert.ok(html.includes('tier-chip active'));
    assert.ok(html.includes('pedantic'));
  });

  it('classifies sdk pack risk kind from rule codes', () => {
    assert.strictEqual(
      sdkPackRiskKind({ id: 'flutter_sdk_3_19', ruleCodes: ['avoid_removed_foo'] }),
      'breaking',
    );
    assert.strictEqual(
      sdkPackRiskKind({ id: 'dart_sdk_3_4', ruleCodes: ['prefer_bar'] }),
      'deprecation',
    );
    assert.strictEqual(
      sdkPackRiskKind({ id: 'riverpod', ruleCodes: ['avoid_baz'] }),
      'none',
    );
  });

  it('sorts sdk packs breaking first then label', () => {
    const rows = [
      { label: 'Flutter SDK 3.22+', risk: 'deprecation' as const },
      { label: 'Dart SDK 3.4+', risk: 'breaking' as const },
      { label: 'Flutter SDK 3.10+', risk: 'breaking' as const },
    ];
    rows.sort(compareSdkPackRowsByRisk);
    assert.deepStrictEqual(rows.map((r) => r.label), [
      'Dart SDK 3.4+',
      'Flutter SDK 3.10+',
      'Flutter SDK 3.22+',
    ]);
  });

  it('matches sdk packs by rollout selection', () => {
    const breakingPack = { id: 'flutter_sdk_3_19', ruleCodes: ['avoid_removed_x'] };
    const deprecationPack = { id: 'dart_sdk_3_4', ruleCodes: ['prefer_y'] };
    const packagePack = { id: 'riverpod', ruleCodes: ['avoid_z'] };

    assert.strictEqual(sdkPackMatchesSelection(breakingPack, 'all'), true);
    assert.strictEqual(sdkPackMatchesSelection(breakingPack, 'breaking'), true);
    assert.strictEqual(sdkPackMatchesSelection(breakingPack, 'deprecation'), false);

    assert.strictEqual(sdkPackMatchesSelection(deprecationPack, 'all'), true);
    assert.strictEqual(sdkPackMatchesSelection(deprecationPack, 'breaking'), false);
    assert.strictEqual(sdkPackMatchesSelection(deprecationPack, 'deprecation'), true);

    assert.strictEqual(sdkPackMatchesSelection(packagePack, 'all'), false);
  });
});


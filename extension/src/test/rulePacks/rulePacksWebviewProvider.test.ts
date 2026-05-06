/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import {
  buildConfigSnippetYaml,
  buildTierControl,
  compareSdkPackRowsByRisk,
  computeDonutSegments,
  computePackCoverageScore,
  computePackDashboardStats,
  formatRelativeFreshness,
  hslForCoverageScore,
  sdkPackMatchesSelection,
  sdkPackRiskKind,
  shouldRenderPackCoverageChart,
} from '../../rulePacks/rulePacksWebviewProvider';

/** Rule pack webview helpers: stats, tier control, sort order, freshness, chart visibility. */

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

  it('renders the tier control as real radio buttons with active state', () => {
    const html = buildTierControl('recommended');
    assert.ok(html.includes('role="radiogroup"'));
    assert.ok(html.includes('role="radio"'));
    assert.ok(html.includes('aria-checked="true"'));
    assert.ok(html.includes('data-tier="recommended"'));
    assert.ok(html.includes('recommended (current)'));
    assert.ok(html.includes('data-tier="pedantic"'));
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

  it('formats relative freshness across the granularity ladder', () => {
    const now = Date.parse('2026-05-01T12:00:00Z');
    assert.strictEqual(formatRelativeFreshness(undefined, now), 'never run');
    assert.strictEqual(formatRelativeFreshness('not-a-date', now), 'never run');
    assert.strictEqual(formatRelativeFreshness('2026-05-01T11:59:30Z', now), 'just now');
    assert.strictEqual(formatRelativeFreshness('2026-05-01T11:55:00Z', now), '5m ago');
    assert.strictEqual(formatRelativeFreshness('2026-05-01T09:00:00Z', now), '3h ago');
    assert.strictEqual(formatRelativeFreshness('2026-04-29T12:00:00Z', now), '2d ago');
    assert.strictEqual(formatRelativeFreshness('2026-04-15T12:00:00Z', now), '2w ago');
  });

  it('scores pack coverage as enabled-over-detected, falling back to enabled-over-total', () => {
    // Detected > 0: coverage is the overlap (enabled ∩ detected) divided by detected.
    assert.strictEqual(
      computePackCoverageScore({ totalPacks: 40, enabledPacks: 3, detectedPacks: 5, enabledRules: 0, detectedRules: 0 }),
      60,
    );
    // Detected = 0 but catalogue not empty: fall back to enabled-over-total.
    assert.strictEqual(
      computePackCoverageScore({ totalPacks: 40, enabledPacks: 10, detectedPacks: 0, enabledRules: 0, detectedRules: 0 }),
      25,
    );
    // Empty catalogue: defensive zero.
    assert.strictEqual(
      computePackCoverageScore({ totalPacks: 0, enabledPacks: 0, detectedPacks: 0, enabledRules: 0, detectedRules: 0 }),
      0,
    );
  });

  it('maps coverage score to an HSL hue along red → green', () => {
    assert.strictEqual(hslForCoverageScore(0), 'hsl(0, 70%, 50%)');
    assert.strictEqual(hslForCoverageScore(50), 'hsl(65, 70%, 50%)');
    assert.strictEqual(hslForCoverageScore(100), 'hsl(130, 70%, 50%)');
    // Defensive clamping: out-of-range scores stay within the ladder ends.
    assert.strictEqual(hslForCoverageScore(-10), 'hsl(0, 70%, 50%)');
    assert.strictEqual(hslForCoverageScore(150), 'hsl(130, 70%, 50%)');
  });

  it('computes donut segments with cumulative offsets summing to 100', () => {
    const segs = computeDonutSegments([
      { id: 'a', label: 'A', rules: 25, enabled: false, detected: false },
      { id: 'b', label: 'B', rules: 50, enabled: false, detected: false },
      { id: 'c', label: 'C', rules: 25, enabled: false, detected: false },
    ]);
    assert.strictEqual(segs.length, 3);
    assert.strictEqual(segs[0].length, 25);
    assert.strictEqual(segs[0].offset, 0);
    assert.strictEqual(segs[1].length, 50);
    assert.strictEqual(segs[1].offset, 25);
    assert.strictEqual(segs[2].offset, 75);
    const lastEnd = segs[2].offset + segs[2].length;
    assert.strictEqual(lastEnd, 100);
  });

  it('returns no donut segments when the dataset is empty', () => {
    assert.deepStrictEqual(computeDonutSegments([]), []);
    assert.deepStrictEqual(
      computeDonutSegments([{ id: 'a', label: 'A', rules: 0, enabled: false, detected: false }]),
      [],
    );
  });

  it('builds a paste-ready YAML snippet of the current config', () => {
    const snippet = buildConfigSnippetYaml('professional', ['riverpod', 'bloc']);
    assert.ok(snippet.includes('tier: professional'));
    assert.ok(snippet.includes('rule_packs:'));
    // Pack ids are sorted alphabetically before serialization.
    const bIdx = snippet.indexOf('- bloc');
    const rIdx = snippet.indexOf('- riverpod');
    assert.ok(bIdx > 0 && rIdx > 0 && bIdx < rIdx, 'expected packs to be sorted: ' + snippet);
  });

  it('falls back to the recommended tier when an unknown tier is passed in', () => {
    // Defensive guard so a stale or hand-edited config setting cannot poison the snippet.
    const snippet = buildConfigSnippetYaml('not-a-tier', []);
    assert.ok(snippet.includes('tier: recommended'));
    assert.ok(snippet.includes('enabled: []'));
  });

  it('skips the pack coverage chart when no pack is enabled or detected', () => {
    const allOff = [
      { id: 'a', label: 'A', rules: 3, enabled: false, detected: false },
      { id: 'b', label: 'B', rules: 1, enabled: false, detected: false },
    ];
    const oneDetected = [
      { id: 'a', label: 'A', rules: 3, enabled: false, detected: false },
      { id: 'b', label: 'B', rules: 1, enabled: false, detected: true },
    ];
    const oneEnabled = [
      { id: 'a', label: 'A', rules: 3, enabled: true, detected: false },
    ];
    assert.strictEqual(shouldRenderPackCoverageChart(allOff), false);
    assert.strictEqual(shouldRenderPackCoverageChart(oneDetected), true);
    assert.strictEqual(shouldRenderPackCoverageChart(oneEnabled), true);
  });
});

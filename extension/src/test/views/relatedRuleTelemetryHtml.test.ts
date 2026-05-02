/**
 * HTML-render coverage for the Related Rule Telemetry panel's adherence to
 * the editor-dashboard UX guidelines (§7.1 / §8.3, §8.10, §8.16). Pins:
 *
 *   - Count column is right-aligned with nowrap (numeric columns must not
 *     wrap mid-number on narrow panes).
 *   - Refresh is no longer marked tier-1; on a counter table no action
 *     dominates strongly enough to deserve primary emphasis.
 *   - Reset is rendered with `disabled` + a tooltip explaining why when
 *     totalEvents === 0 — clicking a no-op button is a silent-failure trap.
 *   - When totalEvents === 0 the table is replaced by an empty-state CTA
 *     (tier-1 *Open Findings Dashboard* button) so the panel is not just a
 *     blank header row.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildRelatedRuleTelemetryHtml } from '../../views/relatedRuleTelemetryView';
import type { TelemetryStore } from '../../relatedRuleTelemetry';

function snapshot(overrides: Partial<TelemetryStore> = {}): TelemetryStore {
  return {
    counters: {},
    ...overrides,
  };
}

describe('Related Rule Telemetry HTML', () => {
  it('renders count cells with class="num" for right-align + nowrap (§7.1, §8.3)', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot({
      counters: { 'ruleExplain.open': 12 },
      lastEventAt: new Date().toISOString(),
    }));
    assert.ok(html.includes('class="num">12</td>'));
    assert.ok(html.includes('text-align: right'));
    assert.ok(html.includes('white-space: nowrap'));
  });

  it('demotes Refresh out of tier-1 (§8.10)', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot({
      counters: { 'ruleExplain.open': 1 },
      lastEventAt: new Date().toISOString(),
    }));
    assert.ok(html.includes('class="btn" id="refresh"'));
    assert.ok(!html.includes('class="btn tier-1" id="refresh"'));
  });

  it('disables Reset when totalEvents === 0 with an explanatory title (§8.10)', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot());
    assert.ok(html.includes('id="reset"'));
    assert.ok(html.includes('disabled'));
    assert.ok(html.includes('No counters to reset.'));
  });

  it('renders Reset as enabled when at least one event has fired (§8.10)', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot({
      counters: { 'ruleExplain.open': 1 },
      lastEventAt: new Date().toISOString(),
    }));
    // No disabled attribute on the reset button when counters exist.
    assert.ok(!/<button[^>]*id="reset"[^>]*disabled/.test(html));
  });

  it('replaces the empty counter table with a tier-1 CTA empty-state (§8.16)', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot());
    assert.ok(html.includes('class="empty-cta"'));
    assert.ok(html.includes('id="openFindings"'));
    assert.ok(html.includes('class="btn tier-1"'));
    assert.ok(html.includes('Open Findings Dashboard'));
    // Counter table should NOT render when there are no events.
    assert.ok(!html.includes('<table class="tel-table">'));
  });

  it('renders the counter table when at least one event has fired', () => {
    const html = buildRelatedRuleTelemetryHtml(snapshot({
      counters: { 'ruleExplain.open': 3 },
      lastEventAt: new Date().toISOString(),
    }));
    assert.ok(html.includes('<table class="tel-table">'));
    assert.ok(!html.includes('id="openFindings"'));
  });
});

/**
 * End-to-end coverage that the Rule Explain fold (plan §B) actually reaches
 * the rendered Top-Rules row, not just the isolated extras builder tested in
 * violationsDashboardRuleDetail.test.ts — i.e. `buildTopRuleRow` widens its
 * `expandable` check for fold-in-only content and `buildTopRuleDetailRow`
 * actually appends the extras block inside `.trd-body`.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildTopRuleRow, type TopRule } from '../../views/violations-dashboard-tables';
import { setSupersedesRulesMetadata } from '../../ruleMetadata';

function row(overrides: Partial<TopRule> = {}): TopRule {
  return {
    name: 'avoid_print',
    count: 3,
    severity: 'warning',
    ...overrides,
  };
}

describe('Top-Rules row — Rule Explain fold reaches the DOM', () => {
  afterEach(() => {
    setSupersedesRulesMetadata(undefined);
  });

  it('stays a flat, non-expandable row when there is no message, files, or fold-in content', () => {
    const html = buildTopRuleRow(row(), 0);
    assert.ok(!html.includes('data-expandable="true"'));
    assert.ok(!html.includes('trow-detail'));
  });

  it('becomes expandable for fold-in-only content (a correction) even with no message/files', () => {
    const html = buildTopRuleRow(row({ correction: 'Use a Logger instead.' }), 0);
    assert.ok(html.includes('data-expandable="true"'));
    assert.ok(html.includes('trow-detail'));
    assert.ok(html.includes('Use a Logger instead.'));
  });

  it('appends the extras block after the message/files content inside .trd-body', () => {
    setSupersedesRulesMetadata({ avoid_print: ['legacy_print_rule'] });
    const html = buildTopRuleRow(
      row({ message: 'Avoid print() in production code.' }),
      0,
    );
    const bodyStart = html.indexOf('trd-body');
    const msgIdx = html.indexOf('Avoid print() in production code.');
    const extrasIdx = html.indexOf('trd-extra');
    assert.ok(bodyStart > -1 && msgIdx > bodyStart && extrasIdx > msgIdx);
    assert.ok(html.includes('data-rule="legacy_print_rule"'));
  });
});

/**
 * Coverage for the Rule Explain fold onto the Findings dashboard's Top-Rules
 * expander (`violations-dashboard-rule-detail.ts` — plan §B,
 * `PLAN_ext_ui_dashboard_consolidation.md`).
 *
 * Pins:
 *   - How-to-fix and OWASP render only when the rule carries that data
 *     (§8.16/§14.3 "earned by data" pattern, matching ruleExplainView.ts).
 *   - Related / same-tag / supersedes render as clickable rule chips reusing
 *     the `.owasp-dl` definition-list vocabulary from ruleExplainPanelStyles.
 *   - "View in ROADMAP" is NEVER rendered here — ROADMAP.md is a dead
 *     redirect stub (see ruleExplainHtml.test.ts's matching assertion for
 *     the standalone panel) and must not be resurrected on the fold.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import {
  buildRuleDetailExtras,
  ruleDetailExtrasAvailable,
  type TopRuleForDetail,
} from '../../views/violations-dashboard-rule-detail';
import {
  setRelatedRulesMetadata,
  setSupersedesRulesMetadata,
  setRuleTagsMetadata,
} from '../../ruleMetadata';

function rule(overrides: Partial<TopRuleForDetail> = {}): TopRuleForDetail {
  return {
    name: 'avoid_print',
    count: 1,
    severity: 'warning',
    ...overrides,
  };
}

describe('Rule Explain fold onto the Top-Rules expander', () => {
  afterEach(() => {
    // Module-level metadata state (populated from the batch export in
    // production) must not leak between tests.
    setRelatedRulesMetadata(undefined);
    setSupersedesRulesMetadata(undefined);
    setRuleTagsMetadata(undefined);
  });

  it('renders nothing and reports unavailable for a rule with no fold-in content', () => {
    assert.strictEqual(ruleDetailExtrasAvailable(rule()), false);
    assert.strictEqual(buildRuleDetailExtras(rule()), '');
  });

  it('renders How to fix only when a correction is present', () => {
    const html = buildRuleDetailExtras(rule({ correction: 'Use a Logger instead.' }));
    assert.ok(html.includes('How to fix'));
    assert.ok(html.includes('Use a Logger instead.'));
    assert.strictEqual(ruleDetailExtrasAvailable(rule({ correction: 'x' })), true);
  });

  it('renders OWASP mobile/web mapping as a definition list', () => {
    const html = buildRuleDetailExtras(rule({ owasp: { mobile: ['M1'], web: ['A03'] } }));
    assert.ok(html.includes('class="owasp-dl"'));
    assert.ok(html.includes('<dt>Mobile</dt><dd>M1</dd>'));
    assert.ok(html.includes('<dt>Web</dt><dd>A03</dd>'));
  });

  it('renders related-rule links from the catalog, excluding self-references', () => {
    setRelatedRulesMetadata({ avoid_print: ['avoid_print', 'avoid_web_libraries_in_flutter'] });
    const html = buildRuleDetailExtras(rule());
    assert.ok(html.includes('Related rules'));
    assert.ok(html.includes('data-rule="avoid_web_libraries_in_flutter"'));
    // Self-reference must be filtered out, not just deduped visually.
    assert.ok(!html.includes('data-rule="avoid_print"'));
  });

  it('renders same-tag discovery links from shared tags', () => {
    setRuleTagsMetadata({
      avoid_print: { tags: ['debug'] },
      no_debug_prints: { tags: ['debug'] },
    });
    const html = buildRuleDetailExtras(rule());
    assert.ok(html.includes('Same-tag discovery'));
    assert.ok(html.includes('data-rule="no_debug_prints"'));
  });

  it('renders supersedes/migration links with a label preceding the chips', () => {
    setSupersedesRulesMetadata({ avoid_print: ['legacy_print_rule'] });
    const html = buildRuleDetailExtras(rule());
    assert.ok(html.includes('Migration'));
    assert.ok(html.includes('Supersedes:'));
    assert.ok(html.includes('data-rule="legacy_print_rule"'));
  });

  it('never renders a "View in ROADMAP" link — ROADMAP.md is a dead redirect stub', () => {
    const html = buildRuleDetailExtras(
      rule({ correction: 'x', owasp: { mobile: ['M1'] } }),
    );
    assert.ok(!html.includes('ROADMAP'));
    assert.ok(!html.includes('roadmap'));
  });
});

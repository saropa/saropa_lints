/**
 * HTML-render coverage for the Rule Explain panel's adherence to the editor-
 * dashboard UX guidelines (§8.1, §7.2, §8.10, §8.16). Pins behavior:
 *
 *   - Subsection headings use <h4> per the *Expander detail headings* rule;
 *     <h2> is reserved for major page bands.
 *   - OWASP entries render as a <dl> definition list, not as paragraphs.
 *   - The Documentation link renders as a .btn-styled action so the panel
 *     has one tier-2 CTA (the "view documentation" affordance).
 *   - Empty Problem section is omitted entirely; previously rendered a
 *     *No message* placeholder card.
 *   - The <h1> stays Saropa-prefixed via the shared hero builder.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';

import { buildRuleExplainHtml, withCatalogDetails, type RuleExplainInput } from '../../views/ruleExplainView';

function input(overrides: Partial<RuleExplainInput> = {}): RuleExplainInput {
  return {
    ruleName: 'avoid_print',
    message: 'Avoid using print() in production code.',
    ...overrides,
  };
}

describe('Rule Explain panel HTML', () => {
  it('keeps the Saropa-prefixed h1 from the shared hero builder (§8.1)', () => {
    const html = buildRuleExplainHtml(input());
    assert.ok(html.includes('Saropa Rule: avoid_print'));
  });

  it('renders subsection headings as <h4>, not <h2> (§8.1)', () => {
    const html = buildRuleExplainHtml(input({
      relatedRules: ['avoid_dynamic'],
    }));
    assert.ok(html.includes('<h4>Problem</h4>'));
    assert.ok(html.includes('<h4>Related rules</h4>'));
    // No subsection should still be rendered as <h2> after the demotion.
    assert.ok(!html.match(/<h2>(Problem|How to fix|Related rules|Same-tag|Migration|OWASP)<\/h2>/));
  });

  it('omits the Problem section when no message is present (§8.16, §14.3)', () => {
    const html = buildRuleExplainHtml(input({ message: undefined }));
    assert.ok(!html.includes('<h4>Problem</h4>'));
    assert.ok(!html.includes('No message'));
  });

  it('renders OWASP entries as a <dl> definition list (§7.2)', () => {
    const html = buildRuleExplainHtml(input({
      owasp: { mobile: ['M1'], web: ['A03'] },
    }));
    assert.ok(html.includes('class="owasp-dl"'));
    assert.ok(html.includes('<dt>Mobile</dt><dd>M1</dd>'));
    assert.ok(html.includes('<dt>Web</dt><dd>A03</dd>'));
    // No <p>...</p><p>...</p> fallback should remain.
    assert.ok(!html.includes('<p>Mobile:'));
  });

  it('omits the dead "View in ROADMAP" documentation link', () => {
    // ROADMAP.md is now a redirect stub with no per-rule content, so the link
    // led nowhere useful. The panel must not render the button or its handler.
    const html = buildRuleExplainHtml(input());
    assert.ok(!html.includes('doc-link'));
    assert.ok(!html.includes('View in ROADMAP'));
  });
});

// Most entry points (Rule Packs finder, pack rule lists, related-rule links) pass only the rule
// name. Before the catalog backfill the panel rendered its header and no body at all.
describe('Rule Explain catalog backfill', () => {
  const catalog = {
    avoid_cached_isar_stream: {
      problemMessage: '[avoid_cached_isar_stream] Caching Isar streams causes runtime errors.',
      correction: 'Create Isar streams inline.',
      impact: 'warning',
      ruleType: 'codeSmell',
      owasp: { mobile: [], web: [] },
    },
  };

  it('fills problem, fix, impact and type for a name-only open', () => {
    const html = buildRuleExplainHtml(withCatalogDetails({ ruleName: 'avoid_cached_isar_stream' }, catalog));
    assert.ok(html.includes('<h4>Problem</h4>'));
    assert.ok(html.includes('Caching Isar streams causes runtime errors.'));
    // The [rule_name] prefix is dropped — the name already heads the panel.
    assert.ok(!html.includes('<p>[avoid_cached_isar_stream]'));
    assert.ok(html.includes('<h4>How to fix</h4>'));
    assert.ok(html.includes('impact: warning'));
    assert.ok(html.includes('type: code smell'));
  });

  it('keeps caller-supplied violation details over catalog defaults', () => {
    const merged = withCatalogDetails(
      { ruleName: 'avoid_cached_isar_stream', message: 'Live message', impact: 'error' },
      catalog,
    );
    assert.strictEqual(merged.message, 'Live message');
    assert.strictEqual(merged.impact, 'error');
    assert.strictEqual(merged.correction, 'Create Isar streams inline.');
  });

  it('returns the input unchanged for a rule missing from the catalog', () => {
    const input = { ruleName: 'not_a_rule' };
    assert.strictEqual(withCatalogDetails(input, catalog), input);
  });
});

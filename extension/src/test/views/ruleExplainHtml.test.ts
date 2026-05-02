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

import { buildRuleExplainHtml, type RuleExplainInput } from '../../views/ruleExplainView';

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
    assert.ok(html.includes('<h4>Documentation</h4>'));
    // No subsection should still be rendered as <h2> after the demotion.
    assert.ok(!html.match(/<h2>(Problem|How to fix|Related rules|Same-tag|Migration|Documentation|OWASP)<\/h2>/));
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

  it('renders the Documentation link as a tier-2 .btn affordance (§8.10)', () => {
    const html = buildRuleExplainHtml(input());
    assert.ok(html.includes('class="doc-link btn"'));
    assert.ok(html.includes('View in ROADMAP'));
  });
});

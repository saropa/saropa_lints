/**
 * PLAN_ext_ui_report_styles.md Phase 1 pin: `chromeBaseLayout()` and
 * `chromeMicroAndMotion()` used to be single monolithic template-literal
 * functions that bundled several unrelated CSS concerns together (the body
 * reset alongside the `.full-width-toggle` button; the `code, .mono`
 * monospace rule alongside `@keyframes hero-in`). That bundling is WHY two
 * earlier passes at PLAN_ext_ui_report_styles.md could not let
 * report-styles-parts.ts adopt just the keyframe without also repainting
 * unrelated elements (opportunities-html.ts's `.opp-chip`) in monospace.
 *
 * Phase 1 split each bundle into single-concern exports and re-composes the
 * original public function from them. This test pins that composition so a
 * future edit cannot silently re-bundle two concerns back together (or
 * silently change the byte-identical output the composer promises) without
 * a assert failure. It also pins each new fine-grained export's presence so
 * report-styles-parts.ts (Phase 2) can safely import `chromeKeyframeHeroIn`
 * without `chromeMonospace` coming along for the ride.
 */
import * as assert from 'node:assert';
import {
  chromeBaseLayout,
  chromeBoxSizingReset,
  chromeBodyReset,
  chromeFullWidthMaxWidthOverride,
  chromeMutedUtility,
  chromeFullWidthToggleButton,
} from '../../views/dashboardChromeStylesTokens';
import { chromeAccessibility } from '../../views/dashboardChromeStylesSystem';
import {
  chromeMicroAndMotion,
  chromeLinks,
  chromeMonospace,
  chromeSectionHeadings,
  chromeKeyframeHeroIn,
  chromeKeyframesSecondary,
} from '../../views/dashboardChromeStylesSystem';

describe('dashboardChromeStyles Phase 1 seams (PLAN_ext_ui_report_styles.md)', () => {
  it('chromeBaseLayout() equals the concatenation of its fine-grained pieces, in order', () => {
    const composed =
      chromeBoxSizingReset() +
      chromeBodyReset() +
      chromeFullWidthMaxWidthOverride() +
      chromeMutedUtility() +
      chromeFullWidthToggleButton();
    assert.strictEqual(chromeBaseLayout(), composed);
  });

  it('chromeBaseLayout() no longer duplicates .sr-only (Phase 2 dedup) -- exactly one definition ' +
    'when composed with chromeAccessibility(), which every current consumer already pairs it with', () => {
    // Phase 1 kept a byte-identical legacy duplicate of .sr-only inside chromeBaseLayout() (it had
    // to, to satisfy that phase's byte-identical gate). Phase 2 removed it once both real
    // consumers of chromeBaseLayout() (getDashboardChromeStyles() and report-styles.ts) were
    // confirmed to always also load chromeAccessibility(), which already defines the same rule.
    const combined = chromeAccessibility() + chromeBaseLayout();
    const occurrences = combined.split('.sr-only {').length - 1;
    assert.strictEqual(occurrences, 1, '.sr-only must be defined exactly once, not duplicated');
  });

  it('chromeMicroAndMotion() equals the concatenation of its fine-grained pieces, in order', () => {
    const composed =
      chromeLinks() +
      chromeMonospace() +
      chromeSectionHeadings() +
      chromeKeyframeHeroIn() +
      chromeKeyframesSecondary();
    assert.strictEqual(chromeMicroAndMotion(), composed);
  });

  it('chromeKeyframeHeroIn() carries the hero-in keyframe and NOTHING else -- no monospace, no other keyframes', () => {
    const css = chromeKeyframeHeroIn();
    assert.ok(css.includes('@keyframes hero-in'), 'must define hero-in');
    assert.ok(!css.includes('.mono'), 'must not bundle the code/.mono monospace rule');
    assert.ok(!css.includes('@keyframes card-in'), 'must not bundle the other keyframes');
    assert.ok(!css.includes('@keyframes chip-in'), 'must not bundle the other keyframes');
    assert.ok(!css.includes('@keyframes menu-in'), 'must not bundle the other keyframes');
    assert.ok(!css.includes('@keyframes grow-x'), 'must not bundle the other keyframes');
  });

  it('chromeMonospace() carries ONLY the code/.mono rule -- no keyframes, no link/section rules', () => {
    const css = chromeMonospace();
    assert.ok(css.includes('code, .mono'), 'must define the monospace rule');
    assert.ok(!css.includes('@keyframes'), 'must not bundle any keyframe');
    assert.ok(!css.includes('.section'), 'must not bundle section-heading rules');
  });

  it('chromeBodyReset() carries the plain body reset -- no .full-width-toggle CSS', () => {
    const css = chromeBodyReset();
    assert.ok(css.includes('font-family: var(--vscode-font-family)'), 'must define the body reset');
    assert.ok(!css.includes('.full-width-toggle'), 'must not bundle the full-width-toggle button');
  });

  it('chromeFullWidthToggleButton() carries the toggle button -- no plain body reset', () => {
    const css = chromeFullWidthToggleButton();
    assert.ok(css.includes('.full-width-toggle {'), 'must define the toggle button');
    assert.ok(!css.includes('font-family: var(--vscode-font-family)'), 'must not bundle the body reset');
  });
});

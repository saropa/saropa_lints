# Config Dashboard: rule search dead ends, no disable action, broken CSP

The Rules & Tiers Config Dashboard's rule-finder search results led nowhere (the "in
&lt;pack&gt;" link appeared to do nothing, a matched rule's "Explain rule" panel rendered with
no content, and the search box cleared itself after two clicks), and neither the search
results nor the standalone "Explain rule" panel offered any way to disable a rule. All four
symptoms traced back to a webview CSP defect plus two missing/broken code paths.

## Root causes

1. **CSP nonce silently dropping inline style writes.** Six webviews (Config Dashboard,
   Analysis Optimizer, Findings Dashboard, Code Health Dashboard, package-vibrancy report)
   set `style-src 'nonce-X' 'unsafe-inline'` as one directive. Per the CSP3 spec, a directive
   containing a nonce-source makes the browser ignore `'unsafe-inline'` for the *whole*
   directive — including inline `style="..."` attributes and JS `element.style.x = ...` /
   `.style.setProperty()` (CSSOM) writes, which cannot carry a nonce. This silently broke
   `focusPack()`'s `detail.style.display = ''` (the reason "in &lt;pack&gt;" links looked
   inert), `applyFilters()`'s row show/hide toggles, the hero coverage gauge's
   `--gauge-target` CSS var, chart bar widths, and score-pill colors — and produced the
   repeated "'unsafe-inline' is ignored if either a hash or nonce value is present" DevTools
   warnings reported alongside the other symptoms. Fixed by splitting the directive into
   `style-src-elem 'nonce-X'` (for `&lt;style&gt;` blocks) and `style-src-attr 'unsafe-inline'`
   (for attribute/CSSOM writes, no nonce present so `'unsafe-inline'` is honored there),
   consolidated into a single `buildWebviewCsp()` helper in `html-utils.ts` used by all six
   call sites (a prior interim fix had inlined the corrected CSP string at each site with a
   duplicated multi-paragraph rationale comment).

2. **Rule search opened an empty "Explain rule" panel.** The `saropaLints.explainRule`
   command's bare-string-argument branch (what a rule-finder click posts) opened the panel
   with only the rule name — no lookup into `violations.json` for message/correction/
   severity, unlike the quickpick fallback path a few lines below it. Fixed by adding the
   same lookup-and-enrich-if-found step to the string-argument branch. A rule that has never
   fired in the current workspace still renders name-only: the extension ships no static
   per-rule description catalog (`getRuleDescription()` in `ruleMetadata.ts` is a permanent
   stub returning `undefined`), which is a real content gap left out of scope for this fix.

3. **No disable/enable action anywhere.** The override-write plumbing
   (`writeRuleOverrides`/`removeRuleOverrides`) already existed and was used by the Overrides
   tab, but neither the rule-finder search results nor the standalone rule-explain panel
   exposed it. Added a toggle to both surfaces. Reusing the Overrides tab's existing
   `toggleRule` handler verbatim would have been wrong: that handler's write convention
   (`enabled:true` writes an override; `enabled:false` *removes* one) is only correct for
   opt-in stylistic rules — applying it to an arbitrary on-by-default tier/pack rule would
   make "Disable" a silent no-op whenever no override already existed. Added a distinct
   `disableRule` message + `_handleDisableRule` (Config Dashboard) that branches on whether
   the rule is stylistic, matching the semantics `saropaLints.disableRules`/`enableRules`
   already use for on-by-default rules; the standalone rule-explain panel (which has no
   access to `RulePacksWebviewProvider`) does the same branch inline via a new shared
   `isStylisticRule()` helper.

4. **Search box lost its text after two result clicks.** A rule-finder link click steals
   focus from the search `&lt;input&gt;`, firing a `uiBlur` message; if a background refresh had
   already been queued while the user was typing, `uiBlur` immediately replays it, which
   reassigns `webview.html` wholesale and re-executes the client script from scratch —
   silently resetting the in-memory `state.search` object and the fresh `&lt;input&gt;`'s empty
   value. Fixed by persisting the filter state (`search`, `type`, `detectedOnly`,
   `enabledOnly`, `barPack`, `kpi`) through `vscode.setState()` (the same mechanism already
   used for `state.activeTab`) and restoring it before the first `applyFilters()` call on
   script init.

5. **"Isar" rule pack looked missing.** Not a data defect — `rulePackDefinitions.ts` and
   `packDomains.ts` both have it correctly (23 rules, "Storage & persistence" domain). It
   sits two collapsed `&lt;details&gt;` deep (All packages → Storage & persistence), which read
   as "missing" until the CSP fix (item 1) restored `focusPack()`'s ability to actually
   expand it from a search-result click.

## Post-implementation review fix

A code-review pass on the initial fix found the standalone rule-explain panel's
`onDidReceiveMessage` handler is registered once, at first panel creation, and closed over
that call's `input` parameter. Because navigating to a related rule inside the same panel
(`activePanel` reused) only reassigns `webview.html` without re-registering the handler, a
subsequent disable/enable click re-rendered using the *original* rule's stale `input` —
the panel body would snap back to the first-opened rule while only the toggle's disabled
state reflected the currently-viewed rule. Fixed by tracking the currently-rendered input in
a module-level `currentInput` variable, updated on every render, and used by the message
handler instead of the closured parameter. The duplicated stylistic-rule predicate (copied
inline in `ruleExplainView.ts` instead of reusing `RulePacksWebviewProvider`'s private
method) was also extracted to a shared `isStylisticRule()` export in `packDomains.ts` so
both disable/enable surfaces cannot drift out of sync on which override-write convention a
rule needs.

## Files changed

`extension/src/rulePacks/rulePacksWebviewProvider.ts`,
`extension/src/rulePacks/configDashboardScript.ts`,
`extension/src/rulePacks/packDomains.ts`, `extension/src/views/ruleExplainView.ts`,
`extension/src/extension.ts`, `extension/src/analysisOptimizer/analysisOptimizerWebviewProvider.ts`,
`extension/src/views/projectVibrancyReportView.ts`, `extension/src/views/violationsDashboardHtml.ts`,
`extension/src/vibrancy/views/report-html-top.ts`, `extension/src/vibrancy/views/html-utils.ts`,
`extension/src/i18n/locales/en.json`, `CHANGELOG.md`.

## Finish Report (2026-09-08)

A code-review pass (`/code-review medium`) on the CSP/search/disable fix found one
correctness bug and two duplication/reuse defects, all fixed:

- **Stale closure in the rule-explain panel's message handler.** `openRuleExplainPanel`'s
  `onDidReceiveMessage` handler is registered once, at first panel creation, and closed over
  that call's `input` parameter. Because navigating to a related rule inside the same panel
  only reassigns `webview.html` without re-registering the handler, clicking the
  disable/enable toggle after such a navigation re-rendered using the *original* rule's
  stale `input` — the panel body snapped back to the first-opened rule while only the
  toggle's disabled state reflected the currently-viewed rule. Fixed by tracking the
  currently-rendered input in a module-level `currentInput` variable, updated on every
  render and used by the message handler instead of the closured parameter.
- **Duplicated stylistic-rule predicate.** `STYLISTIC_PACK_DEFINITIONS.some(...)` was
  copy-pasted in `ruleExplainView.ts` instead of reusing `RulePacksWebviewProvider`'s private
  method of the same logic. Extracted to a shared `isStylisticRule()` export in
  `packDomains.ts` (the hand-maintained sibling of the generated `rulePackDefinitions.ts`/
  `stylisticPackDefinitions.ts`) so both disable/enable surfaces cannot drift on which
  override-write convention a rule needs.
- **Duplicated CSP construction.** The corrected `style-src-elem`/`style-src-attr` CSP string
  plus a multi-paragraph rationale comment had been copy-pasted verbatim across all six fixed
  webviews. Consolidated into one `buildWebviewCsp()` helper in the existing shared
  `html-utils.ts`.

Two items raised in the initial handoff's reflection were hardened further:

- **CSP split-directive browser support.** `style-src-elem`/`style-src-attr` are only
  recognized from Chrome/Chromium 111 onward; a browser that doesn't recognize them drops
  them as unknown tokens and, with no plain `style-src` present, would fall back to
  `default-src 'none'` for *all* style checks — a worse regression (blocking `<style>` blocks
  too) than the bug being fixed. `buildWebviewCsp()` now also emits a legacy
  `style-src 'nonce-X' 'unsafe-inline'` fallback alongside the split pair; CSP directive
  precedence means a modern browser ignores it entirely (no behavior change there), while an
  old one that doesn't understand the split directives falls back to it.
- **"Explain rule" panel showing nothing for a rule that has never fired.** Rather than
  leaving this fully out of scope, added a minimal fallback: when no violation match exists,
  the panel now shows the rule's introducing tier (`RULE_TIER_BY_CODE`, already-generated
  data with full rule coverage) and the rule pack(s) that own it (`packsForRule()`, new
  helper in `packDomains.ts` scanning the existing generated `RULE_PACK_DEFINITIONS`/
  `STYLISTIC_PACK_DEFINITIONS`), instead of literally nothing but the rule name. This uses
  only data already shipped in the extension — no new codegen pipeline. A full per-rule
  prose description catalog (what the rule checks, why, example) remains a separate,
  larger effort not attempted here.

The CHANGELOG entry was also restructured per explicit feedback: the fixes and the new
disable-action/tier-fallback features had been run together in one paragraph under
`### Fixed`; split into separate `### Added` and `### Fixed` bullets, one sentence each.

Verification: `npx tsc --noEmit -p .`, `npx tsc -p tsconfig.test.json`, and `npm run compile`
clean after every edit in this pass. Two new unit tests added to `ruleExplainHtml.test.ts`
pin the tier/pack fallback's actual before/after behavior (a known rule renders "Included
from tier: professional" / "Rule pack: Isar"; an unknown rule name renders the fallback
heading with no tier/pack lines). Full scoped run across every touched test file: 280
passing, 0 failing.

## Verification

`npm run compile`, `npx tsc --noEmit -p .`, `npx tsc -p tsconfig.test.json`, and
`npm run verify-nls-keys` all clean. Scoped mocha across every touched test file
(`ruleExplainHtml`, `violationsDashboardRuleDetail`, `rulePacksWebviewProvider`,
`configFileCardCoverage`, `overviewTreeFlat`, `violationsDashboardHtml`,
`projectVibrancyReportHtml`): 130 passing, 0 failing. Broader `analysisOptimizer` suite run
alongside: 211 passing, 1 pre-existing failure (`scanner.test.js` "detects widgets and async
code") confirmed unrelated via `git stash`/`pop` against the unmodified baseline.
`generate_locales.py --mode audit --fail-on-missing` reports 168 translation gaps (7 new
English strings × 24 locales) — expected immediately after adding new `en.json` keys;
regenerating translated catalogs is an operator-only step, not run here.

No visual verification was performed — this is TypeScript/webview code with no access to an
Extension Development Host from this session. Every claim above is "should render correctly
per the code change," not a confirmed rendered result.

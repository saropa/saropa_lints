/**
 * Rule Explain content, folded onto the Findings dashboard's Top Rules
 * expander row instead of requiring a jump to the standalone `ruleExplainView`
 * screen (plan §B, `plans/PLAN_ext_ui_dashboard_consolidation.md` — "Fold list
 * B (rule-detail items) into the rule-group expander").
 *
 * Renders: How-to-fix text, OWASP mobile/web mapping, related rules, same-tag
 * discovery links, and supersedes/migration links. Each block is EARNED by
 * having data (§8.16 / §14.3 pattern already used by `ruleExplainView.ts`) —
 * an empty section is omitted rather than rendered as a placeholder card, so
 * a rule with no OWASP mapping does not advertise an empty "OWASP" heading.
 *
 * Deliberately NOT folded: "View in ROADMAP" (list item 18). `ROADMAP.md` was
 * turned into a redirect stub with no per-rule content (commit `28c2fedb`,
 * see `extension/src/test/views/ruleExplainHtml.test.ts` — "omits the dead
 * 'View in ROADMAP' documentation link"). Re-adding that link here would
 * resurrect a UX regression the standalone panel deliberately removed; the
 * Issues-tree tooltip's "More" link (`getRuleDocUrl`) is unaffected by this
 * decision and is out of scope for this change.
 *
 * `ruleExplainView.ts` is left standing as a working standalone surface —
 * this module only ADDS an inline summary; it does not replace or delete it.
 */

import { l10n } from '../i18n/runtime';
import type { OwaspData } from '../violationsReader';
import {
  getRelatedRules,
  getSameTagRules,
  getSupersedesRules,
} from '../ruleMetadata';
import { escapeHtml, type ViolationsDashboardHtmlInput } from './violations-dashboard-shared';

/** One Top-Rules row's expandable data — the subset `buildRuleDetailExtras` reads. */
export type TopRuleForDetail = NonNullable<ViolationsDashboardHtmlInput['topRules']>[number];

/**
 * Render a comma-joined list of clickable rule chips. Each chip posts
 * `{ type: 'openRuleExplain', rule }` (wired in `violations-dashboard-script.ts`)
 * so clicking a related/same-tag/superseded rule not present in the current
 * Top Rules table still opens full detail via the standalone panel — the
 * fold-in summarizes, it does not have room to show every rule's full detail
 * inline, so cross-navigation still routes through the kept-standalone screen.
 */
function ruleChips(names: readonly string[]): string {
  return names
    .map(
      (r) =>
        `<a href="#" class="related-rule-link" data-rule="${escapeHtml(r)}"><code>${escapeHtml(r)}</code></a>`,
    )
    .join(', ');
}

/**
 * Builds the "extras" block appended inside a Top-Rules detail row: how-to-fix,
 * OWASP mapping, related rules, same-tag discovery, and supersedes/migration.
 * Returns '' when the rule has none of this content, so callers can decide
 * whether the row is expandable without duplicating the presence checks.
 */
export function buildRuleDetailExtras(rule: TopRuleForDetail): string {
  const correction = rule.correction ? escapeHtml(rule.correction) : '';
  const owasp = buildOwaspBlock(rule.owasp);
  // Cross-rule links are metadata-catalog-driven (not violation-driven), so
  // they are available even when the dashboard's own data source is the
  // live-diagnostics model (which carries no correction/OWASP fields) —
  // see extension.ts `syncRuleMetadataFromViolations`, populated from the
  // batch export independently of how the dashboard itself sources findings.
  const related = getRelatedRules(rule.name).filter((r) => r !== rule.name);
  const sameTag = getSameTagRules(rule.name).filter((r) => r !== rule.name);
  const supersedes = getSupersedesRules(rule.name).filter((r) => r !== rule.name);

  const correctionHtml = correction
    ? `<section class="trd-sub"><h4>${escapeHtml(l10n('findingsDash.topRules.howToFixHeading'))}</h4><p>${correction}</p></section>`
    : '';
  const relatedHtml = related.length
    ? `<section class="trd-sub"><h4>${escapeHtml(l10n('findingsDash.topRules.relatedRulesHeading'))}</h4><p>${ruleChips(related)}</p></section>`
    : '';
  const sameTagHtml = sameTag.length
    ? `<section class="trd-sub"><h4>${escapeHtml(l10n('findingsDash.topRules.sameTagHeading'))}</h4><p>${ruleChips(sameTag)}</p></section>`
    : '';
  const supersedesHtml = supersedes.length
    ? `<section class="trd-sub"><h4>${escapeHtml(l10n('findingsDash.topRules.migrationHeading'))}</h4><p>${escapeHtml(l10n('findingsDash.topRules.supersedesLabel'))} ${ruleChips(supersedes)}</p></section>`
    : '';

  const body = `${correctionHtml}${owasp}${relatedHtml}${sameTagHtml}${supersedesHtml}`;
  return body.length ? `<div class="trd-extra">${body}</div>` : '';
}

/** True when the rule carries any fold-in content — decides row expandability. */
export function ruleDetailExtrasAvailable(rule: TopRuleForDetail): boolean {
  return Boolean(
    rule.correction ||
      rule.owasp?.mobile?.length ||
      rule.owasp?.web?.length ||
      getRelatedRules(rule.name).some((r) => r !== rule.name) ||
      getSameTagRules(rule.name).some((r) => r !== rule.name) ||
      getSupersedesRules(rule.name).some((r) => r !== rule.name),
  );
}

/** OWASP mobile/web mapping as a definition list — matches `ruleExplainView.ts`'s §7.2 pattern. */
function buildOwaspBlock(owasp: OwaspData | undefined): string {
  const entries: Array<{ label: string; value: string }> = [];
  if (owasp?.mobile?.length) {
    entries.push({ label: l10n('findingsDash.topRules.owaspMobileLabel'), value: owasp.mobile.join(', ') });
  }
  if (owasp?.web?.length) {
    entries.push({ label: l10n('findingsDash.topRules.owaspWebLabel'), value: owasp.web.join(', ') });
  }
  if (entries.length === 0) return '';
  const heading = l10n('findingsDash.groupBy.owasp'); // reuse the existing "OWASP" string (single source of truth)
  const dl = entries
    .map((e) => `<dt>${escapeHtml(e.label)}</dt><dd>${escapeHtml(e.value)}</dd>`)
    .join('');
  return `<section class="trd-sub"><h4>${escapeHtml(heading)}</h4><dl class="owasp-dl">${dl}</dl></section>`;
}

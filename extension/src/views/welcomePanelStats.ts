import { getSupportedLocaleCount } from '../i18n/runtime';
import type { RuleCountSummary } from './ruleCountCliRunner';

/** One number tile in the welcome panel's stats strip. */
export interface WelcomeStat {
  value: string;
  label: string;
  /** Chrome accent token (without `var()`) — gives each tile a distinct hue. */
  tone: string;
}

/**
 * Builds the 5-stat showcase. Two figures are live and can never drift: `total` comes
 * from the same `dart run saropa_lints:rule_count` call the About panel already uses
 * (patched in once it resolves — see WelcomePanel.refreshWithRuleCounts), and
 * `languages` reads the actual bundled locale catalog count via getSupportedLocaleCount().
 * The other three (quick fixes, package integrations, tiers) have no live CLI source yet
 * — see plans/PLAN_welcome_flow.md — so they carry the same figures already published in
 * the top-of-CHANGELOG overview line and README package-coverage table rather than
 * inventing new ones.
 */
export function buildWelcomeStats(ruleCounts: RuleCountSummary | null): WelcomeStat[] {
  const totalRules = ruleCounts ? ruleCounts.total.toLocaleString() : '2,300+';
  return [
    { value: totalRules, label: 'lint rules', tone: 'brand' },
    { value: '250+', label: 'quick fixes', tone: 'status-good' },
    { value: String(getSupportedLocaleCount()), label: 'languages', tone: 'accent-info' },
    { value: '57+', label: 'package integrations', tone: 'accent-medium' },
    { value: '5', label: 'severity tiers', tone: 'accent-critical' },
  ];
}

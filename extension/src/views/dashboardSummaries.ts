/**
 * Live summary cards for the "Saropa Dashboards" launchpad.
 *
 * The launchpad fully embeds the two heavy dashboards (Project Map, Code Health) because they run a
 * `dart run` scan and need their real interactive markup. The four FAST dashboards — Lints Config,
 * Package, Findings, Command Catalog — read only local files / in-memory caches, so the launchpad
 * shows a compact live summary (a few key metrics) plus an "Open full screen" deep-link instead of
 * embedding each full interactive document. That avoids the id/CSS/`acquireVsCodeApi` collisions
 * that composing six full webviews into one document would create, and keeps the shell instant.
 *
 * Each builder is pure (data in → HTML string out) so the launchpad can drop the result straight
 * into a pane body and unit tests can assert the markup without a webview. The "Open full screen"
 * button carries the target command in a `data-command` attribute; the launchpad client delegates
 * clicks on `[data-command]` to the host, which executes the (allowlisted) command.
 */
import type * as vscode from 'vscode';
import { readViolations } from '../violationsReader';
import { readPubspec } from '../pubspecReader';
import { readRulePacksEnabled } from '../rulePacks/rulePackYaml';
import { getLatestResults } from '../vibrancy/extension-activation';
import { catalogEntries } from './commandCatalogRegistry';
import { readCommandHistory } from './commandCatalogHistory';
import { l10n } from '../i18n/runtime';

/** Commands the launchpad summary cards may deep-link to (host enforces this allowlist). */
export const SUMMARY_OPEN_COMMANDS = {
  lintsConfig: 'saropaLints.openConfigDashboard',
  package: 'saropaLints.packageVibrancy.showReport',
  findings: 'saropaLints.openViolationsWideReport',
  commandCatalog: 'saropaLints.showCommandCatalog',
} as const;

/** One labeled metric cell; tone shades the value (warn/bad) so triage signal is visible at a glance. */
interface Metric {
  label: string;
  value: string;
  tone?: 'warn' | 'bad';
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** A responsive grid of metric cells. */
function metricGrid(metrics: readonly Metric[]): string {
  const cells = metrics
    .map((m) => {
      const toneClass = m.tone ? ` metric-${m.tone}` : '';
      return `<div class="metric${toneClass}">
        <span class="metric-value">${escapeHtml(m.value)}</span>
        <span class="metric-label">${escapeHtml(m.label)}</span>
      </div>`;
    })
    .join('');
  return `<div class="summary-grid">${cells}</div>`;
}

/**
 * Assemble a summary card body: either the metric grid or an empty-state line. The "Open full
 * screen" deep-link is rendered by the launchpad in the pane head (uniform with the heavy panes),
 * not here, so this returns only the card content.
 */
function summaryCard(opts: { metrics: readonly Metric[]; emptyMessage?: string }): string {
  return opts.emptyMessage
    ? `<p class="summary-empty">${escapeHtml(opts.emptyMessage)}</p>`
    : metricGrid(opts.metrics);
}

/** Lints Config summary: tier, enabled-rule count, rule-pack count, detected packages. */
export function buildConfigSummary(root: string): string {
  const violations = readViolations(root);
  const pubspec = readPubspec(root);
  const rulePacks = readRulePacksEnabled(root);
  const tier = violations?.config?.tier;
  const enabledRules = violations?.config?.enabledRuleCount;
  const metrics: Metric[] = [
    { label: l10n('dashboards.config.tier'), value: tier ?? '—' },
    {
      label: l10n('dashboards.config.enabledRules'),
      value: typeof enabledRules === 'number' ? String(enabledRules) : '—',
    },
    { label: l10n('dashboards.config.rulePacks'), value: String(rulePacks.length) },
    { label: l10n('dashboards.config.packages'), value: String(pubspec.packages.length) },
  ];
  return summaryCard({ metrics });
}

/** Package summary: total scanned, count needing attention, count blocked from upgrading. */
export function buildPackageSummary(): string {
  const results = getLatestResults();
  if (results.length === 0) {
    return summaryCard({ metrics: [], emptyMessage: l10n('dashboards.package.empty') });
  }
  // "Needs attention" = packages the scorer flagged as no longer actively maintained.
  const attention = results.filter(
    (r) => r.category === 'outdated' || r.category === 'abandoned' || r.category === 'end-of-life',
  ).length;
  const blocked = results.filter((r) => r.blocker != null).length;
  const metrics: Metric[] = [
    { label: l10n('dashboards.package.total'), value: String(results.length) },
    {
      label: l10n('dashboards.package.attention'),
      value: String(attention),
      tone: attention > 0 ? 'warn' : undefined,
    },
    {
      label: l10n('dashboards.package.blocked'),
      value: String(blocked),
      tone: blocked > 0 ? 'bad' : undefined,
    },
  ];
  return summaryCard({ metrics });
}

/** Findings summary: total violations split by severity. */
export function buildFindingsSummary(root: string): string {
  const data = readViolations(root);
  if (!data) {
    return summaryCard({ metrics: [], emptyMessage: l10n('dashboards.findings.empty') });
  }
  const total = data.summary?.totalViolations ?? data.violations.length;
  const sev = data.summary?.bySeverity ?? {};
  const errors = sev.error ?? 0;
  const warnings = sev.warning ?? 0;
  const info = sev.info ?? 0;
  const metrics: Metric[] = [
    { label: l10n('dashboards.findings.total'), value: String(total) },
    {
      label: l10n('dashboards.findings.errors'),
      value: String(errors),
      tone: errors > 0 ? 'bad' : undefined,
    },
    {
      label: l10n('dashboards.findings.warnings'),
      value: String(warnings),
      tone: warnings > 0 ? 'warn' : undefined,
    },
    { label: l10n('dashboards.findings.info'), value: String(info) },
  ];
  return summaryCard({ metrics });
}

/** Command Catalog summary: user-facing command count and how many have a recent run record. */
export function buildCatalogSummary(context: vscode.ExtensionContext): string {
  // Internal commands are hidden from the catalog UI, so count only what users can see.
  const commandCount = catalogEntries.filter((e) => !e.internal).length;
  const recentCount = readCommandHistory(context).length;
  const metrics: Metric[] = [
    { label: l10n('dashboards.catalog.commands'), value: String(commandCount) },
    { label: l10n('dashboards.catalog.recent'), value: String(recentCount) },
  ];
  return summaryCard({ metrics });
}

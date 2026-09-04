/**
 * Live summary cards for the "Saropa Dashboards" Home hub (`saropaDashboardsView.ts`, plan
 * `PLAN_extension_ui_redesign.md` Phase 3).
 *
 * Every builder here reads only local files / in-memory caches — never spawns a `dart run` scan —
 * so the Home hub always renders instantly. Project Map and Code Health are heavy (`dart run`)
 * dashboards; rather than embed their full interactive markup (the pre-Phase-3 launchpad did, and
 * paid for it with a sequential-scan-on-every-open cost), their cards show only what is already
 * cheaply known: Code Health's last in-session scan result, Project Map's last-generated report's
 * file timestamp. Both fall back to an honest "not scanned" empty state rather than lying with a
 * stale or fabricated number.
 *
 * Each builder is pure (data in → HTML string out) so callers can drop the result straight into a
 * card body and unit tests can assert the markup without a webview. The "Open" button carries the
 * target command in a `data-command` attribute; the host's client script delegates clicks on
 * `[data-command]` to the extension host, which executes the (allowlisted) command.
 */
import type * as vscode from 'vscode';
import * as nodePath from 'node:path';
import * as nodeFs from 'node:fs';
import { readViolations } from '../violationsReader';
import { readVisibleLiveViolations, computeLiveHealthScore } from '../liveViolationsData';
import { readPubspec } from '../pubspecReader';
import { readRulePacksEnabled } from '../rulePacks/rulePackYaml';
import { getLatestResults } from '../vibrancy/extension-activation';
import { catalogEntries } from './commandCatalogRegistry';
import { readCommandHistory } from './commandCatalogHistory';
import { getLastProjectVibrancyPayload } from './projectVibrancyReportView';
import { formatRelativeTimestamp } from './dashboardHero';
import { saropaLintsDataPath } from '../reportsPaths';
import { HealthPanel } from '../systemHealth/healthPanel';
import { l10n } from '../i18n/runtime';

/** Commands the launchpad summary cards may deep-link to (host enforces this allowlist). */
export const SUMMARY_OPEN_COMMANDS = {
  lintsConfig: 'saropaLints.openConfigDashboard',
  package: 'saropaLints.packageVibrancy.showReport',
  findings: 'saropaLints.openViolationsWideReport',
  commandCatalog: 'saropaLints.showCommandCatalog',
  codeHealth: 'saropaLints.openProjectVibrancyReport',
  projectMap: 'saropaLints.openProjectHealthDashboard',
  fullAudit: 'saropaLints.fullAudit',
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
 *
 * `limit` truncates the metric list (used by the Home hub's "top-3 signals" cards) without
 * duplicating the underlying data read — the full-detail callers (the light panes that used to
 * live in the "Saropa Dashboards" launchpad, still used by other summary consumers) pass no limit
 * and get every metric this builder computed.
 */
function summaryCard(opts: { metrics: readonly Metric[]; emptyMessage?: string; limit?: number }): string {
  if (opts.emptyMessage) return `<p class="summary-empty">${escapeHtml(opts.emptyMessage)}</p>`;
  const metrics = opts.limit !== undefined ? opts.metrics.slice(0, opts.limit) : opts.metrics;
  return metricGrid(metrics);
}

/**
 * Lints Config / "Rules & Tiers" summary: tier, enabled-rule count, rule-pack count, detected
 * packages. `limit` trims to the Home hub's top-N-signal card; the full-launchpad pane omits it.
 */
export function buildConfigSummary(root: string, limit?: number): string {
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
  return summaryCard({ metrics, limit });
}

/**
 * Shared package-health tally read by both [buildPackageSummary] (the dashboard card) and the Home
 * hub's KPI band ([saropaDashboardsView.ts]) — one computation so the two surfaces cannot disagree
 * on what "needs attention" means.
 */
export interface PackagesKpi {
  total: number;
  attention: number;
  blocked: number;
}

/** Total scanned, count needing attention (outdated/abandoned/end-of-life), count upgrade-blocked. */
export function getPackagesKpi(): PackagesKpi {
  const results = getLatestResults();
  const attention = results.filter(
    (r) => r.category === 'outdated' || r.category === 'abandoned' || r.category === 'end-of-life',
  ).length;
  const blocked = results.filter((r) => r.blocker != null).length;
  return { total: results.length, attention, blocked };
}

/**
 * Package summary: total scanned, count needing attention, count blocked from upgrading. `limit`
 * trims to the Home hub's top-N-signal card; the full-launchpad pane omits it.
 */
export function buildPackageSummary(limit?: number): string {
  const { total, attention, blocked } = getPackagesKpi();
  if (total === 0) {
    return summaryCard({ metrics: [], emptyMessage: l10n('dashboards.package.empty') });
  }
  const metrics: Metric[] = [
    { label: l10n('dashboards.package.total'), value: String(total) },
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
  return summaryCard({ metrics, limit });
}

/**
 * Findings summary: total violations split by severity. `limit` trims to the Home hub's
 * top-N-signal card; the full-launchpad pane omits it.
 */
export function buildFindingsSummary(root: string, limit?: number): string {
  // Live diagnostics, not the cached violations.json export — mirrors the
  // status-bar/Issues-tree/sidebar-Status live-diagnostics migration so this
  // card cannot show "no findings" while the Problems panel has real ones.
  // Never null: an empty result means the project is clean, which renders as
  // 0/0/0/0 below rather than a separate "not scanned" empty state.
  const data = readVisibleLiveViolations(root);
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
  return summaryCard({ metrics, limit });
}

/**
 * Code Health summary: average grade, average score, function count scanned. Reads the in-memory
 * cache from the last completed Code Health scan ([getLastProjectVibrancyPayload]) — never spawns
 * its own `dart run`, so the Home hub stays instant. Empty state until Code Health has been opened
 * at least once this session.
 */
export function buildCodeHealthSummary(limit?: number): string {
  const payload = getLastProjectVibrancyPayload();
  const summary = payload?.summary;
  if (!summary) {
    return summaryCard({ metrics: [], emptyMessage: l10n('dashboards.codeHealth.empty') });
  }
  const metrics: Metric[] = [
    { label: l10n('dashboards.codeHealth.grade'), value: summary.averageGrade ?? '—' },
    {
      label: l10n('dashboards.codeHealth.score'),
      value: typeof summary.averageScore === 'number' ? String(Math.round(summary.averageScore)) : '—',
    },
    {
      label: l10n('dashboards.codeHealth.functions'),
      value: typeof summary.functionCount === 'number' ? String(summary.functionCount) : '—',
    },
  ];
  return summaryCard({ metrics, limit });
}

/**
 * mtime of the last generated Project Map report, or `undefined` if none exists yet. Shared by
 * [buildProjectMapSummary] and the Home hub's project-size KPI tile ([readHomeKpis]) — the CLI
 * emits an HTML-only artifact (no structured JSON with size/hotspot totals), so a real number is
 * not cheaply available; presence + freshness of the last report is the honest signal both
 * surfaces can show without scraping generated markup.
 */
export function getLastProjectMapMtime(root: string): Date | undefined {
  const indexPath = nodePath.join(saropaLintsDataPath(root), 'health', 'index.html');
  try {
    return nodeFs.statSync(indexPath).mtime;
  } catch {
    return undefined;
  }
}

/**
 * Project Map summary: presence + freshness of the last generated report only (see
 * [getLastProjectMapMtime] for why there is no size/hotspot number). Never spawns its own
 * `dart run` scan.
 */
export function buildProjectMapSummary(root: string, limit?: number): string {
  const mtime = getLastProjectMapMtime(root);
  if (!mtime) {
    return summaryCard({ metrics: [], emptyMessage: l10n('dashboards.projectMap.empty') });
  }
  const metrics: Metric[] = [
    { label: l10n('dashboards.projectMap.lastMapped'), value: formatRelativeTimestamp(mtime.toISOString()) ?? '—' },
  ];
  return summaryCard({ metrics, limit });
}

/** Full Audit summary: static description — the audit is a one-shot report, not a live model. */
export function buildFullAuditSummary(): string {
  return `<p class="summary-empty">${escapeHtml(l10n('dashboards.fullAudit.description'))}</p>`;
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

// ── Home hub KPI band (plan §3 "Phase 3") ──────────────────────────────

/**
 * The six headline numbers the Home hub's KPI band shows. Every field is nullable/optional in the
 * "no data yet" sense rather than defaulting to 0 — a 0 is a real fact (no issues!) that must not
 * be confused with "never scanned" (unknown). [buildKpiBand] renders the distinction.
 */
export interface HomeKpis {
  /** 0-100, or `null` when no analysis has run yet / the report is too partial to score. */
  healthScore: number | null;
  /** Total open findings, or `null` when no analysis has run yet. */
  issueCount: number | null;
  /** How many of the three diagnostic engines (analyzer/scanDaemon/LSP) are up, or `null` if the
   *  Engines section is disabled (`saropaLints.debug.enabled`) / not wired yet. */
  enginesRunning: number | null;
  /** Always 3 today — kept as a field (not a literal) so a future 4th engine needs no call-site changes. */
  enginesTotal: number;
  packagesTotal: number;
  packagesAttention: number;
  /** Average Code Health letter grade from the last in-session scan, or `null` if never scanned. */
  codeHealthGrade: string | null;
  /** Whether a Project Map report has ever been generated for this project (see [getLastProjectMapMtime]). */
  projectMapScanned: boolean;
}

/** An engine counts as "running" unless its status is one of these explicitly-down states. */
function isEngineDown(status: string): boolean {
  return status === 'stopped' || status === 'suspended';
}

/**
 * Reads the six KPIs from whatever is already cheaply available — the last analysis export, the
 * vibrancy package scan, the Health Panel's engine snapshot, and the in-memory/on-disk traces of
 * the two heavy dashboards. Never triggers a scan; a value that needs one shows `null`/`false`
 * instead, which [buildKpiBand] renders as an honest "not scanned" tile.
 */
export function readHomeKpis(root: string): HomeKpis {
  // Live diagnostics, not the cached violations.json export — same fix as
  // buildFindingsSummary above and the sidebar's Status section, so the KPI
  // band's issue count cannot disagree with the Problems panel.
  // computeLiveHealthScore still borrows the cached export's file-count
  // denominator (see its doc comment), preserving the 0-vs-never-scanned
  // distinction this interface documents.
  const violations = readVisibleLiveViolations(root);
  const health = computeLiveHealthScore(root, violations);
  const engines = HealthPanel.getEngineStatuses();
  const { total: packagesTotal, attention: packagesAttention } = getPackagesKpi();
  const codeHealth = getLastProjectVibrancyPayload()?.summary;
  return {
    healthScore: health?.score ?? null,
    issueCount: violations.summary?.totalViolations ?? null,
    enginesRunning: engines ? engines.filter((e) => !isEngineDown(e.status)).length : null,
    enginesTotal: 3,
    packagesTotal,
    packagesAttention,
    codeHealthGrade: codeHealth?.averageGrade ?? null,
    projectMapScanned: getLastProjectMapMtime(root) !== undefined,
  };
}

/** One KPI tile: a big value plus a label, matching the `.metric` cell visual language. */
function kpiTile(label: string, value: string, tone?: 'warn' | 'bad'): string {
  const toneClass = tone ? ` metric-${tone}` : '';
  return `<div class="metric kpi-tile${toneClass}">
    <span class="metric-value">${escapeHtml(value)}</span>
    <span class="metric-label">${escapeHtml(label)}</span>
  </div>`;
}

/**
 * Renders the Home hub's KPI band: 6 tiles (health score, issue count, engines, packages,
 * code-health grade, project size). Replaces the former "Saropa Dashboards" launchpad's
 * grade-gauge-only hero (plan Phase 3) with a wider at-a-glance strip.
 */
export function buildKpiBand(kpis: HomeKpis): string {
  const notScanned = l10n('dashboards.kpi.notScanned');
  const health =
    kpis.healthScore === null
      ? kpiTile(l10n('dashboards.kpi.health'), l10n('dashboards.kpi.healthPending'))
      : kpiTile(
          l10n('dashboards.kpi.health'),
          `${kpis.healthScore}%`,
          kpis.healthScore < 70 ? 'bad' : kpis.healthScore < 90 ? 'warn' : undefined,
        );
  const issues =
    kpis.issueCount === null
      ? kpiTile(l10n('dashboards.kpi.issues'), notScanned)
      : kpiTile(l10n('dashboards.kpi.issues'), String(kpis.issueCount), kpis.issueCount > 0 ? 'warn' : undefined);
  const engines =
    kpis.enginesRunning === null
      ? kpiTile(l10n('dashboards.kpi.engines'), l10n('dashboards.kpi.enginesOff'))
      : kpiTile(
          l10n('dashboards.kpi.engines'),
          l10n('dashboards.kpi.enginesValue', { running: String(kpis.enginesRunning), total: String(kpis.enginesTotal) }),
          kpis.enginesRunning < kpis.enginesTotal ? 'warn' : undefined,
        );
  const packages =
    kpis.packagesTotal === 0
      ? kpiTile(l10n('dashboards.kpi.packages'), notScanned)
      : kpiTile(
          l10n('dashboards.kpi.packages'),
          kpis.packagesAttention > 0
            ? l10n('dashboards.kpi.packagesAttention', { count: String(kpis.packagesAttention) })
            : l10n('dashboards.kpi.packagesValue', { count: String(kpis.packagesTotal) }),
          kpis.packagesAttention > 0 ? 'warn' : undefined,
        );
  const codeHealth = kpiTile(
    l10n('dashboards.kpi.codeHealthGrade'),
    kpis.codeHealthGrade ?? notScanned,
  );
  const projectSize = kpiTile(
    l10n('dashboards.kpi.projectSize'),
    kpis.projectMapScanned ? l10n('dashboards.kpi.projectSizeMapped') : notScanned,
  );
  return `<div class="kpi-band">${health}${issues}${engines}${packages}${codeHealth}${projectSize}</div>`;
}

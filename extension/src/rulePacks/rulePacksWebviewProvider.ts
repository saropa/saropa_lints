// Implements the Rule Packs / Config Dashboard UI: load pubspec, toggles, and `rule_packs` config.
/**
 * **Config Dashboard** editor webview: rule packs table, tier chips, SDK rollout actions,
 * a read-only export suppressions snapshot strip (totals from `violations.json`), and Flutter
 * embedder rows from {@link readPubspec}.
 *
 * Opens as a {@link vscode.WebviewPanel} (full editor column), not a sidebar webview, so the
 * layout stays usable. Writes `plugins.saropa_lints.rule_packs.enabled` (see `rulePackYaml.ts`).
 * Refreshes when the user saves `analysis_options.yaml` or when the extension calls {@link refresh}.
 *
 * **Concurrency:** toggle handler is async; YAML is written synchronously then
 * analysis may run — no recursive refresh loop (refresh after write is intentional).
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { getProjectRoot } from '../projectRoot';
import { readDisabledRules } from '../configWriter';
import { readPubspec, FLUTTER_EMBEDDER_PLATFORMS } from '../pubspecReader';
import { readViolations, filterDisabledFromData } from '../violationsReader';
import { buildSuppressionsExportSnapshotStripHtml } from '../views/configDashboardSuppressionsStrip';
import { RULE_PACK_DEFINITIONS, isPackDetected } from './rulePackDefinitions';
import { createWebviewCspNonce } from '../vibrancy/views/html-utils';
import { getConfigDashboardScript } from './configDashboardScript';
import { getConfigDashboardStyles } from './configDashboardStyles';
import { readRulePacksEnabled, writeRulePacksEnabled } from './rulePackYaml';

const CONFIG_DASHBOARD_PANEL_TYPE = 'saropaLints.configDashboard';
const TIERS = ['essential', 'recommended', 'professional', 'comprehensive', 'pedantic'] as const;

type TierName = (typeof TIERS)[number];

interface PackDashboardStats {
  totalPacks: number;
  enabledPacks: number;
  detectedPacks: number;
  enabledRules: number;
  detectedRules: number;
}

interface PackChartRow {
  id: string;
  label: string;
  rules: number;
  enabled: boolean;
  detected: boolean;
}

/**
 * Bundled dashboard inputs collected once per render. Computing this in one place keeps the
 * builder methods free of repeated I/O and gives every section a consistent view of the data.
 */
interface DashboardContext {
  pubspecInfo: ReturnType<typeof readPubspec>;
  currentTier: string;
  packRows: readonly PackChartRow[];
  stats: PackDashboardStats;
  detectedSdkPacks: ReadonlyArray<(typeof RULE_PACK_DEFINITIONS)[number]>;
  detectedBreakingSdkCount: number;
  detectedDeprecationSdkCount: number;
  /** ISO timestamp from violations.json — drives the status-line freshness label. */
  analysisTimestamp: string | undefined;
  suppressionsStripHtml: string;
  /**
   * Rules currently disabled via `analysis_options_custom.yaml` overrides.
   * Surfacing them here is the user's only graphical way to see and re-enable
   * what they previously turned off; the file itself carries a "do not edit"
   * banner directing readers back to the extension.
   */
  disabledRules: readonly string[];
}

export function isSdkPackId(id: string): boolean {
  return id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_');
}

export function sdkPackRiskKind(def: { id: string; ruleCodes: readonly string[] }): 'breaking' | 'deprecation' | 'none' {
  if (!isSdkPackId(def.id)) return 'none';
  return def.ruleCodes.some((code) => code.startsWith('avoid_removed_')) ? 'breaking' : 'deprecation';
}

export function compareSdkPackRowsByRisk(
  a: { label: string; risk: 'breaking' | 'deprecation' | 'none' },
  b: { label: string; risk: 'breaking' | 'deprecation' | 'none' },
): number {
  const rank = (risk: 'breaking' | 'deprecation' | 'none'): number => {
    if (risk === 'breaking') return 0;
    if (risk === 'deprecation') return 1;
    return 2;
  };
  const byRisk = rank(a.risk) - rank(b.risk);
  if (byRisk !== 0) return byRisk;
  return a.label.localeCompare(b.label);
}

type SdkRiskSelection = 'all' | 'breaking' | 'deprecation';

export function sdkPackMatchesSelection(
  def: { id: string; ruleCodes: readonly string[] },
  selection: SdkRiskSelection,
): boolean {
  if (!isSdkPackId(def.id)) return false;
  if (selection === 'all') return true;
  return sdkPackRiskKind(def) === selection;
}

function isBreakingSdkPack(def: { id: string; ruleCodes: readonly string[] }): boolean {
  return sdkPackRiskKind(def) === 'breaking';
}

export function computePackDashboardStats(rows: readonly PackChartRow[]): PackDashboardStats {
  let enabledPacks = 0;
  let detectedPacks = 0;
  let enabledRules = 0;
  let detectedRules = 0;
  for (const row of rows) {
    if (row.enabled) {
      enabledPacks++;
      enabledRules += row.rules;
    }
    if (row.detected) {
      detectedPacks++;
      detectedRules += row.rules;
    }
  }
  return {
    totalPacks: rows.length,
    enabledPacks,
    detectedPacks,
    enabledRules,
    detectedRules,
  };
}

/**
 * Renders the tier segmented control as real `<button role="radio">` elements.
 *
 * UX_UI_GUIDELINES §14.1 fix: previously rendered as inert `<span class="tier-chip">` that looked
 * interactive but did nothing — the user had to click a separate "Set tier" toolbar button. The
 * new control posts `setTier` messages on click, removing the bait-and-switch pattern.
 */
export function buildTierControl(currentTier: string): string {
  const buttons = TIERS.map((tier) => {
    const active = tier === currentTier;
    const label = active ? `${escapeHtml(tier)} (current)` : escapeHtml(tier);
    return [
      '<button type="button" class="tier-btn"',
      ` role="radio" aria-checked="${active ? 'true' : 'false'}"`,
      ` data-tier="${escapeHtml(tier)}"`,
      ` tabindex="${active ? '0' : '-1'}">`,
      label,
      '</button>',
    ].join('');
  }).join('');
  return `<div class="tier-control" role="radiogroup" aria-label="Lint tier">${buttons}</div>`;
}

/**
 * Formats an ISO timestamp into a short relative-time label for the status line.
 * Returns 'never run' for null input. Granularity drops as time passes so the line stays compact.
 */
export function formatRelativeFreshness(iso: string | undefined, now: number = Date.now()): string {
  if (!iso) return 'never run';
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return 'never run';
  const sec = Math.max(0, Math.floor((now - t) / 1000));
  if (sec < 60) return 'just now';
  if (sec < 3600) return `${Math.floor(sec / 60)}m ago`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`;
  const days = Math.floor(sec / 86400);
  if (days < 7) return `${days}d ago`;
  return `${Math.floor(days / 7)}w ago`;
}

/**
 * Decides whether the pack coverage chart should render. Per UX_UI_GUIDELINES §14.3/§14.5/§8.16:
 * the chart is omitted when no pack is enabled or detected — an all-grey chart is decoration.
 */
export function shouldRenderPackCoverageChart(rows: readonly PackChartRow[]): boolean {
  return rows.some((row) => row.enabled || row.detected);
}

/**
 * Score the workspace's lint configuration coverage on a 0–100 scale for the header gauge.
 *
 * Definition: of the packs whose pubspec gate is satisfied (detected), what fraction has the
 * user actually enabled? This is the actionable metric — *"are you taking advantage of the
 * tooling that applies to your code?"*. If nothing is detected, fall back to enabled/total so
 * the gauge still rewards a configured tier-only workspace; if the catalogue itself is empty
 * (defensive), return 0.
 */
export function computePackCoverageScore(stats: PackDashboardStats): number {
  if (stats.detectedPacks > 0) {
    const overlap = Math.min(stats.enabledPacks, stats.detectedPacks);
    return Math.round((overlap / stats.detectedPacks) * 100);
  }
  if (stats.totalPacks === 0) return 0;
  return Math.round((stats.enabledPacks / stats.totalPacks) * 100);
}

/**
 * Map a 0–100 coverage score to an HSL hue along red → amber → green per §2.3 (ordinal
 * spectrum). The result is consumed inline as a CSS string, so the helper returns the full
 * `hsl(...)` form, not just the hue number.
 */
export function hslForCoverageScore(score: number): string {
  const clamped = Math.max(0, Math.min(100, score));
  // 0 → red (0deg), 50 → amber (~60deg), 100 → green (~130deg). Linear interpolation is
  // fine for a small range and avoids the perceptual dead zones of HSV.
  const hue = Math.round((clamped / 100) * 130);
  return `hsl(${hue}, 70%, 50%)`;
}

/**
 * Compute donut segment offsets for the pack coverage donut companion (§6.1).
 *
 * Returns one segment per row in input order with `length` (stroke-dasharray) and `offset`
 * (cumulative starting offset around the circle), both expressed as a fraction of 100 so the
 * SVG can use `pathLength="100"` and skip arithmetic at render time.
 */
export interface DonutSegment {
  id: string;
  label: string;
  length: number;
  offset: number;
}

export function computeDonutSegments(rows: readonly PackChartRow[]): DonutSegment[] {
  const total = rows.reduce((acc, r) => acc + r.rules, 0);
  if (total <= 0) return [];
  let acc = 0;
  return rows.map((row) => {
    const length = (row.rules / total) * 100;
    const seg: DonutSegment = { id: row.id, label: row.label, length, offset: acc };
    acc += length;
    return seg;
  });
}

/**
 * Build a paste-ready YAML snippet of the current Lints Config (tier + enabled rule packs) for
 * the *Copy config* toolbar action. The snippet matches the analyzer's expected `analysis_options`
 * layout so the user can paste it under their existing `analyzer:` / `plugins:` block in another
 * project. Inputs are sanitized: tier is whitelisted; pack ids are sorted and pre-filtered to the
 * known catalogue by callers, so this helper just formats — it does not validate.
 */
export function buildConfigSnippetYaml(tier: string, enabledPackIds: readonly string[]): string {
  const safeTier = (TIERS as readonly string[]).includes(tier) ? tier : 'recommended';
  const sortedIds = [...enabledPackIds].sort((a, b) => a.localeCompare(b));
  const packsBlock =
    sortedIds.length === 0
      ? '      enabled: []'
      : ['      enabled:', ...sortedIds.map((id) => `        - ${id}`)].join('\n');
  return [
    '# Saropa Lints — copy into your analysis_options.yaml under saropa_lints / plugins.',
    'saropa_lints:',
    `  tier: ${safeTier}`,
    '  rule_packs:',
    packsBlock,
    '',
  ].join('\n');
}

export class RulePacksWebviewProvider {
  private _panel?: vscode.WebviewPanel;

  constructor(private readonly _extensionUri: vscode.Uri) {}

  /** Opens or focuses the Config Dashboard in the editor area and rebuilds HTML. */
  openEditorPanel(): void {
    if (this._panel) {
      // preserveFocus=false: reclicking the sidebar entry must move focus into
      // the dashboard so keyboard users can immediately interact with it. The
      // previous `true` left focus on the sidebar tree row, which made the
      // reclick feel like a no-op.
      this._panel.reveal(vscode.ViewColumn.One, false);
      this.refresh();
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      CONFIG_DASHBOARD_PANEL_TYPE,
      // Editor-tab title keeps the "Saropa" prefix even though the sidebar row drops it —
      // the prefix is the only signal that lets users find this tab in Quick Open / Recent
      // Files / the editor tab dropdown when many unrelated tabs are open.
      'Saropa Lints Config',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        localResourceRoots: [this._extensionUri],
        retainContextWhenHidden: true,
      },
    );
    this._panel = panel;

    panel.webview.onDidReceiveMessage(
      (msg: { type: string; packId?: string; enabled?: boolean; id?: string; tier?: string }) => {
        if (msg.type === 'toggle' && msg.packId !== undefined && msg.enabled !== undefined) {
          void this._handleToggle(msg.packId, msg.enabled);
        }
        if (msg.type === 'showRules' && msg.packId !== undefined) {
          void this._showRulesList(msg.packId);
        }
        if (msg.type === 'command' && typeof msg.id === 'string') {
          void this._runDashboardCommand(msg.id);
        }
        // setTier is fired by the in-page tier radio control — replaces the old "Set tier"
        // toolbar button + quickpick round-trip with a single click on the active tier.
        if (msg.type === 'setTier' && typeof msg.tier === 'string') {
          void this._handleSetTier(msg.tier);
        }
        if (msg.type === 'refresh') {
          this.refresh();
        }
      },
    );

    panel.onDidDispose(() => {
      this._panel = undefined;
    });

    this.refresh();
  }

  refresh(): void {
    const webview = this._panel?.webview;
    if (!webview) {
      return;
    }
    webview.html = this._buildHtml();
  }

  /**
   * Build the Lints Config webview body.
   *
   * Layout per UX_UI_GUIDELINES §14.7 (density-first ordering): header → KPIs → tier → toolbar →
   * filter strip → primary table → conditional chart → diagnostics. Suppressions, target platforms,
   * and docs are bottom-band reference content (§14.14 fix), not above-the-fold.
   */
  private _buildHtml(): string {
    const root = getProjectRoot();
    if (!root) {
      return this._wrapHtml('<p>Open a workspace folder.</p>', false);
    }

    const pubspecPath = path.join(root, 'pubspec.yaml');
    let pubspecContent = '';
    try {
      pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
    } catch {
      return this._wrapHtml('<p>No pubspec.yaml in workspace.</p>', false);
    }

    const ctx = this._collectDashboardContext(root, pubspecContent);
    const body = [
      this._buildHeader(ctx),
      this._buildKpiStrip(ctx),
      this._buildTierSection(ctx),
      this._buildToolbar(ctx),
      // Empty placeholder; the script populates it whenever filter state diverges from defaults.
      // Per §8.5 / §14.10 the strip must exist in the DOM so it can render synchronously.
      '<div class="chip-strip" id="filter-strip" hidden></div>',
      this._buildPackTable(ctx),
      // Disabled-rules section sits directly under the pack table because both
      // edit the same effective rule set: packs + tier set the baseline, and
      // these overrides remove individual rules from it. Users coming from
      // the sidebar's "X rules disabled by override" row land here.
      this._buildDisabledRulesSection(ctx),
      this._buildChartSection(ctx),
      this._buildDiagnostics(ctx),
    ].join('\n');

    return this._wrapHtml(body, true);
  }

  /** Resolve the pubspec, tier, violations snapshot, and pack rows in one pass. */
  private _collectDashboardContext(root: string, pubspecContent: string): DashboardContext {
    const info = readPubspec(root);
    const enabledIds = new Set(readRulePacksEnabled(root));
    const currentTier =
      vscode.workspace.getConfiguration('saropaLints').get<string>('tier', 'recommended') ??
      'recommended';
    const packRows: PackChartRow[] = RULE_PACK_DEFINITIONS.map((def) => ({
      id: def.id,
      label: def.label,
      detected: isPackDetected(def, pubspecContent),
      enabled: enabledIds.has(def.id),
      rules: def.ruleCodes.length,
    }));
    const detectedSdkPacks = RULE_PACK_DEFINITIONS.filter(
      (def) => isSdkPackId(def.id) && isPackDetected(def, pubspecContent),
    );
    const stats = computePackDashboardStats(packRows);
    const violationsRaw = readViolations(root);
    const violationsForStrip = violationsRaw
      ? filterDisabledFromData(violationsRaw, readDisabledRules(root))
      : null;
    // Rules currently disabled via overrides. Rendered as a dashboard
    // section so users have a graphical way to review and re-enable —
    // the underlying file (`analysis_options_custom.yaml`) carries a
    // "do not edit manually" banner pointing back to this extension.
    const disabledRules = [...readDisabledRules(root)].sort();
    return {
      pubspecInfo: info,
      currentTier,
      packRows,
      stats,
      detectedSdkPacks,
      detectedBreakingSdkCount: detectedSdkPacks.filter((d) => isBreakingSdkPack(d)).length,
      detectedDeprecationSdkCount: detectedSdkPacks.filter((d) => sdkPackRiskKind(d) === 'deprecation')
        .length,
      analysisTimestamp: violationsRaw?.timestamp,
      suppressionsStripHtml: buildSuppressionsExportSnapshotStripHtml(violationsForStrip),
      disabledRules,
    };
  }

  /**
   * Header band with status line and hero coverage gauge.
   *
   * §4.1 / §14.9: replaces the marketing subtitle with one muted sentence carrying tier, pack
   * coverage, applicable SDK migrations, and analysis freshness. The methodology copy that used
   * to be the subtitle moves into a help-icon `title` so it stays reachable but doesn't compete
   * with the data the user came for.
   *
   * §6.3: a partial-arc gauge anchors the right side of the header — score-derived HSL fill,
   * centered numeric grade, neutral track. Animates from empty on first render so the
   * orientation is unambiguous. The arc fills from CSS variables to keep the initial keyframe
   * from fighting inline geometry (per §5).
   */
  private _buildHeader(ctx: DashboardContext): string {
    const sdkApplicable = ctx.detectedSdkPacks.length;
    const freshness = formatRelativeFreshness(ctx.analysisTimestamp);
    const parts = [
      `Tier: <strong>${escapeHtml(ctx.currentTier)}</strong>`,
      `${ctx.stats.enabledPacks}/${ctx.stats.totalPacks} packs enabled`,
      `${ctx.stats.detectedPacks}/${ctx.stats.totalPacks} detected`,
      `${sdkApplicable} applicable SDK migration${sdkApplicable === 1 ? '' : 's'}`,
      `last analysis ${freshness}`,
    ];
    const statusLine = parts
      .map((p, i) => (i === 0 ? `<span>${p}</span>` : `<span class="dot">·</span><span>${p}</span>`))
      .join('');
    const helpTitle =
      'Pack-owned rules are off unless that pack is enabled. Tiers control broad baselines; ' +
      'packs control package- and SDK-migration domains.';
    return `<header class="dash-hero">
  <div class="hero-text">
    <h1>Saropa Lints Config <button type="button" class="help-icon" title="${escapeHtml(helpTitle)}" aria-label="About this dashboard">?</button></h1>
    <p class="status-line">${statusLine}</p>
  </div>
  ${this._buildCoverageGauge(ctx)}
</header>`;
  }

  /**
   * Hero coverage gauge: enabled / detected as a percentage. Uses the shared `.hero-gauge`
   * chrome from `dashboardChromeStyles.ts` so this gauge looks identical to the Findings and
   * Code Health gauges. Hidden if the catalogue is empty (defensive) — otherwise always
   * rendered, including at 0%, because the user needs to see the gauge in its zero state to
   * understand what the page is measuring.
   */
  private _buildCoverageGauge(ctx: DashboardContext): string {
    if (ctx.stats.totalPacks === 0) return '';
    const score = computePackCoverageScore(ctx.stats);
    const hsl = hslForCoverageScore(score);
    const denom = ctx.stats.detectedPacks > 0 ? ctx.stats.detectedPacks : ctx.stats.totalPacks;
    const numerator = Math.min(ctx.stats.enabledPacks, denom);
    const tooltipBase =
      ctx.stats.detectedPacks > 0
        ? `${numerator} of ${denom} detected packs are enabled.`
        : `${numerator} of ${denom} packs in the catalogue are enabled (no packs detected in this pubspec).`;
    const tooltip = `Pack coverage ${score}%. ${tooltipBase}`;
    // pathLength="100" + `--gauge-target` / `--gauge-arc` follows the shared-chrome contract
    // used by all three dashboards' hero gauges. `--gauge-color` carries the score-derived hue.
    return `<div class="hero-gauge" role="img"
    aria-label="${escapeHtml(`Pack coverage ${score} percent`)}"
    title="${escapeHtml(tooltip)}"
    style="--gauge-target:${score};--gauge-arc:100;--gauge-color:${hsl};">
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <path class="gauge-track" d="M 15 80 A 45 45 0 1 1 85 80" pathLength="100"></path>
      <path class="gauge-fill" d="M 15 80 A 45 45 0 1 1 85 80" pathLength="100"></path>
    </svg>
    <div class="gauge-label">
      <span class="lg">${score}<span class="muted" style="font-size:0.55em;">%</span></span>
      <span class="sm">coverage</span>
    </div>
  </div>`;
  }

  /**
   * KPI strip with collapsed identical twins (§14.11) and preset-filter affordance (§14.8).
   *
   * Cards are real `<button>`s so they're keyboard-reachable; the script wires `data-filter-*`
   * to the table filter state. Numbers use the hero scale (1.8em) per §4.2.
   */
  private _buildKpiStrip(ctx: DashboardContext): string {
    const cards = [
      this._buildCoverageCard(ctx),
      this._buildSdkApplicableCard(ctx),
      this._buildEnabledRulesCard(ctx),
    ].join('');
    return `<section class="kpi-row" aria-label="Overview">${cards}</section>`;
  }

  /** Coverage card collapses the old "enabled vs detected" twins into one (§14.11). */
  private _buildCoverageCard(ctx: DashboardContext): string {
    const { enabledPacks, detectedPacks, totalPacks } = ctx.stats;
    const ratio = totalPacks > 0 ? Math.round((enabledPacks / totalPacks) * 100) : 0;
    const detail =
      enabledPacks === detectedPacks
        ? `${detectedPacks} detected in pubspec`
        : `${detectedPacks} detected · ${enabledPacks} active`;
    const title =
      'Packs you have enabled in analysis_options.yaml versus the total pack catalogue. ' +
      'Click to filter the table to enabled packs.';
    return [
      '<button type="button" class="kpi-card interactive" data-kpi-filter="enabled"',
      ` title="${escapeHtml(title)}">`,
      '<span class="kpi-k">Packs enabled</span>',
      `<span class="kpi-v">${enabledPacks}<span class="muted" style="font-size:0.6em;">/${totalPacks}</span></span>`,
      `<span class="kpi-sub">${escapeHtml(detail)}</span>`,
      `<span class="kpi-progress" aria-hidden="true"><span style="width:${ratio}%"></span></span>`,
      '</button>',
    ].join('');
  }

  /** SDK-applicable card: collapses {all, breaking, deprecation} when they all match (§14.11). */
  private _buildSdkApplicableCard(ctx: DashboardContext): string {
    const total = ctx.detectedSdkPacks.length;
    const breaking = ctx.detectedBreakingSdkCount;
    const deprecation = ctx.detectedDeprecationSdkCount;
    const detail =
      total === 0
        ? 'no SDK migrations in this pubspec'
        : breaking === total && deprecation === 0
          ? 'all are breaking changes'
          : `${breaking} breaking · ${deprecation} deprecation`;
    const title =
      'SDK migration packs whose constraint matches this workspace\'s pubspec environment. ' +
      'Click to filter the table to applicable SDK packs.';
    return [
      '<button type="button" class="kpi-card interactive" data-kpi-filter="applicable-sdk"',
      ` title="${escapeHtml(title)}">`,
      '<span class="kpi-k">Applicable SDK migrations</span>',
      `<span class="kpi-v">${total}</span>`,
      `<span class="kpi-sub">${escapeHtml(detail)}</span>`,
      '</button>',
    ].join('');
  }

  /** Enabled rules card. Independent number; no twin. Static (no preset filter). */
  private _buildEnabledRulesCard(ctx: DashboardContext): string {
    const title =
      'Total rules contributed by enabled packs. Tier rules are not counted here — packs are an ' +
      'overlay on top of the tier baseline.';
    return [
      '<div class="kpi-card"',
      ` title="${escapeHtml(title)}">`,
      '<span class="kpi-k">Pack rules enabled</span>',
      `<span class="kpi-v">${ctx.stats.enabledRules}</span>`,
      `<span class="kpi-sub">${ctx.stats.detectedRules} would activate if all detected packs were enabled</span>`,
      '</div>',
    ].join('');
  }

  /** Tier control section: real radio buttons replace the inert chips. */
  private _buildTierSection(ctx: DashboardContext): string {
    return `<section aria-label="Tier">
  <h2>Tier</h2>
  ${buildTierControl(ctx.currentTier)}
  <p class="hint">Tier sets broad defaults. Pack-owned migration rules require pack enablement.</p>
</section>`;
  }

  /**
   * Toolbar band with density tiers (§4.3, §14.4).
   *
   * Tier 1 primary: Run analysis. Tier 2 secondary: Open config YAML, Copy config, Package
   * Vibrancy, Refresh. Tier 3 overflow `details.more`: Enable applicable SDK packs (all /
   * breaking / deprecation) — items disabled with `title` when zero detected (§8.10). Search /
   * filter inputs share the band on a second row.
   */
  private _buildToolbar(ctx: DashboardContext): string {
    return `<section class="toolbar-band" role="toolbar" aria-label="Lints config actions">
  <div class="toolbar-row spread">
    ${this._buildPrimaryActions()}
    ${this._buildEnableOverflow(ctx)}
  </div>
  <div class="toolbar-row">
    ${this._buildToolbarFilters()}
  </div>
</section>`;
  }

  private _buildPrimaryActions(): string {
    return `<div class="toolbar-row" style="gap:6px;">
    <button class="btn tier-1" data-command="runAnalysis"
      title="Run dart analyze and refresh the dashboard.">Run analysis</button>
    <button class="btn" data-command="openConfig"
      title="Open analysis_options.yaml in the editor.">Open config YAML</button>
    <button class="btn" data-command="copyConfigSnippet"
      title="Copy a paste-ready YAML snippet of the current tier + enabled packs to the clipboard.">Copy config</button>
    <button class="btn" data-command="openVibrancy"
      title="Open the Package Vibrancy report.">Package Vibrancy</button>
    <button class="btn icon-only" data-command="refresh"
      title="Reload the dashboard from disk." aria-label="Refresh">⟳</button>
  </div>`;
  }

  /**
   * Overflow trigger for the SDK enable variants. Uses the shared chrome's `details.more`
   * pattern (also used by the Findings dashboard) so the menu visual + open/close behavior
   * matches across all three dashboards. The trigger is disabled when nothing is applicable
   * (§8.10) — disabled state communicates "no work to do here" before the user has to click.
   */
  private _buildEnableOverflow(ctx: DashboardContext): string {
    const total = ctx.detectedSdkPacks.length;
    const breaking = ctx.detectedBreakingSdkCount;
    const deprecation = ctx.detectedDeprecationSdkCount;
    const noneDetected = total === 0;
    const noneTitle = 'No applicable SDK packs detected in this pubspec.';
    const buildItem = (id: string, label: string, count: number): string => {
      const disabled = count === 0;
      const itemTitle = disabled ? noneTitle : `${count} pack${count === 1 ? '' : 's'} match`;
      return `<button type="button" class="menu-item" data-command="${id}"${disabled ? ' disabled' : ''} title="${escapeHtml(itemTitle)}">${escapeHtml(label)} <span class="kbd">${count}</span></button>`;
    };
    if (noneDetected) {
      return `<button type="button" class="btn" disabled title="${escapeHtml(noneTitle)}">Enable applicable packs ▾</button>`;
    }
    return `<details class="more">
    <summary class="btn" title="Choose all applicable, breaking-only, or deprecation-only.">
      Enable applicable packs <span class="chev">▾</span>
    </summary>
    <div class="menu" role="menu">
      ${buildItem('enableDetectedSdkPacks', 'All applicable', total)}
      ${buildItem('enableDetectedBreakingSdkPacks', 'Breaking only', breaking)}
      ${buildItem('enableDetectedDeprecationSdkPacks', 'Deprecation only', deprecation)}
    </div>
  </details>`;
  }

  /** Toolbar filter cluster: search field, type select, detected/enabled-only segmented control. */
  private _buildToolbarFilters(): string {
    return `<label class="field" title="Filter packs by name.">
    <span class="glyph">🔎</span>
    <label class="sr-only" for="pack-search">Search packs</label>
    <input id="pack-search" type="search" placeholder="Search packs…" autocomplete="off" />
  </label>
  <label class="field">
    <label class="sr-only" for="type-filter">Filter by type</label>
    <select id="type-filter" title="Filter by pack type (SDK migration vs package rule).">
      <option value="all">All types</option>
      <option value="sdk">SDK migration</option>
      <option value="package">Package</option>
    </select>
  </label>
  <div class="seg additive" role="group" aria-label="Pack visibility">
    <span class="seg-label">Show</span>
    <button type="button" class="seg-btn" data-toggle-filter="detected" aria-pressed="false"
      title="Show only packs whose pubspec gate is satisfied.">Detected</button>
    <button type="button" class="seg-btn" data-toggle-filter="enabled" aria-pressed="false"
      title="Show only packs already enabled in analysis_options.yaml.">Enabled</button>
  </div>`;
  }

  /** Combined packs table — one schema, Type column, sortable headers, sticky header (§14.13).
   *
   * Wrapped in `<details open>` so the user can collapse the (long) packs table when they want
   * to focus on the Disabled rules block below. Defaulted open because the packs table is the
   * primary content of the dashboard.
   */
  private _buildPackTable(ctx: DashboardContext): string {
    const rows = [...ctx.packRows]
      .sort((a, b) => b.rules - a.rules || a.label.localeCompare(b.label))
      .map((row) => this._buildPackRow(row))
      .join('\n');
    return `<details class="section expander" aria-label="Rule packs" open>
  <summary><span class="expander-title">Rule packs</span> <span class="muted">(${ctx.packRows.length})</span></summary>
  <div class="dash-table-wrap">
    <table class="dash-table packs" id="packs-table">
      <thead>
        <tr>
          <th class="sortable" data-sort="label" aria-sort="none">Pack <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="type" aria-sort="none">Type <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="risk" aria-sort="none">Risk <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="detected" aria-sort="none" title="Pack gate is satisfied by this workspace's pubspec.">In pubspec <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="enabled" aria-sort="none">Enabled <span class="arrow">▲</span></th>
          <th class="sortable num" data-sort="rules" aria-sort="descending">Rules <span class="arrow">▼</span></th>
          <th></th>
        </tr>
      </thead>
      <tbody id="packs-tbody">${rows}</tbody>
    </table>
  </div>
</details>`;
  }

  /**
   * One table row.
   *
   * §14.12 fix: each "is this applicable?" signal lives in exactly one column. The methodology
   * (gate package + version constraint) goes into the `title` of the *In pubspec* cell, not as a
   * second visible footnote on the row.
   */
  private _buildPackRow(row: PackChartRow): string {
    const def = RULE_PACK_DEFINITIONS.find((d) => d.id === row.id)!;
    const isSdk = isSdkPackId(def.id);
    const riskKind = sdkPackRiskKind(def);
    const typeBadge = `<span class="type-badge">${isSdk ? 'SDK' : 'Package'}</span>`;
    const riskBadge =
      riskKind === 'none'
        ? '<span class="risk-badge none" title="Not applicable to this pack type.">—</span>'
        : `<span class="risk-badge ${riskKind}">${riskKind === 'breaking' ? 'breaking' : 'deprecation'}</span>`;
    const gateText = this._gateMethodologyText(def);
    const detectedCell = `<td class="${row.detected ? 'ok' : 'muted'}" title="${escapeHtml(gateText)}" data-detected="${row.detected ? '1' : '0'}">${row.detected ? 'Yes' : 'No'}</td>`;
    const id = escapeHtml(row.id);
    return `<tr data-pack="${id}" data-type="${isSdk ? 'sdk' : 'package'}" data-risk="${riskKind}" data-detected="${row.detected ? '1' : '0'}" data-enabled="${row.enabled ? '1' : '0'}" data-rules="${row.rules}" data-label="${escapeHtml(def.label.toLowerCase())}">
  <td class="pack-name">${escapeHtml(def.label)}</td>
  <td>${typeBadge}</td>
  <td>${riskBadge}</td>
  ${detectedCell}
  <td><label class="switch"><input type="checkbox" data-pack="${id}" ${row.enabled ? 'checked' : ''} aria-label="Enable ${escapeHtml(def.label)}" /><span class="slider"></span></label></td>
  <td class="num">${row.rules}</td>
  <td><a href="#" class="rules-link" data-pack="${id}" title="View the ${row.rules} rule${row.rules === 1 ? '' : 's'} in this pack.">View</a></td>
</tr>`;
  }

  /** One-line methodology text used as a tooltip on the "In pubspec" cell (§14.12). */
  private _gateMethodologyText(def: { dependencyGate?: { package: string; constraint: string }; sdkGate?: { sdkKey: string; constraint: string } }): string {
    if (def.dependencyGate) {
      return `Gate: ${def.dependencyGate.package} ${def.dependencyGate.constraint} in pubspec.lock`;
    }
    if (def.sdkGate) {
      return `Gate: ${def.sdkGate.sdkKey} ${def.sdkGate.constraint} in pubspec environment`;
    }
    return 'No applicability gate; this pack is always available.';
  }

  /**
   * Pack coverage chart — only when at least one pack is enabled or detected (§14.3/§14.5/§8.16).
   *
   * Bar chart + donut companion side-by-side per §6.1: bars communicate rank by rule count,
   * donut communicates proportion. Both share the same dataset and the same click contract —
   * clicking a bar OR a donut segment filters the table to that pack (§6.2, §14.8). Legend
   * explains the three visual states so color is paired with non-color cues (§2.3).
   */
  private _buildChartSection(ctx: DashboardContext): string {
    if (!shouldRenderPackCoverageChart(ctx.packRows)) return '';
    const top = [...ctx.packRows]
      .sort((a, b) => b.rules - a.rules || a.label.localeCompare(b.label))
      .slice(0, 8);
    const bars = this._buildChartBars(top);
    const donut = this._buildChartDonut(top);
    return `<section class="section chart-card" aria-label="Pack coverage">
  <h3>Pack coverage <span class="meta">
    <span class="chart-legend">
      <span class="chart-legend-item"><span class="legend-swatch" aria-hidden="true"></span>available</span>
      <span class="chart-legend-item"><span class="legend-swatch detected" aria-hidden="true"></span>detected</span>
      <span class="chart-legend-item"><span class="legend-swatch enabled" aria-hidden="true"></span>enabled</span>
    </span>
  </span></h3>
  <div class="body">
    <div>${bars}</div>
    ${donut}
  </div>
  <p class="hint">Top 8 packs by rule count. Click a bar or donut segment to filter the table.</p>
</section>`;
  }

  /**
   * Render the horizontal-bar list (one row per pack) using the shared `.bar-row` grid layout
   * (label / track / value). Width is set via `--bar-width` CSS variable so the shared keyframe
   * animation in dashboardChromeStyles takes effect on first render.
   */
  private _buildChartBars(top: readonly PackChartRow[]): string {
    const maxRules = Math.max(1, ...top.map((r) => r.rules));
    return top
      .map((row) => {
        const width = Math.round((row.rules / maxRules) * 100);
        const cls = `${row.enabled ? 'enabled' : ''} ${row.detected ? 'detected' : ''}`.trim();
        const tip = `${row.rules} rule${row.rules === 1 ? '' : 's'}; ${row.detected ? 'detected' : 'not detected'}; ${row.enabled ? 'enabled' : 'not enabled'}`;
        return `<div class="bar-row" role="button" tabindex="0" data-bar-pack="${escapeHtml(row.id)}" title="${escapeHtml(tip)}" style="--bar-width:${width}%;">
    <span class="bar-label">${escapeHtml(row.label)}</span>
    <div class="bar-track"><div class="bar-fill ${cls}"></div></div>
    <span class="bar-value">${row.rules}</span>
  </div>`;
      })
      .join('\n');
  }

  /**
   * Render the donut companion. Each `<circle>` segment carries the same `data-bar-pack`
   * attribute as the bars so the script's chart-bar handler picks them up uniformly — one
   * filter contract for both visualizations.
   *
   * pathLength="100" lets each segment's stroke-dasharray be expressed as a percent without
   * arithmetic at render time. The `--seg-color` CSS variable rotates through the categorical
   * hue slots defined in the chart styles (§2.3).
   */
  private _buildChartDonut(top: readonly PackChartRow[]): string {
    const segments = computeDonutSegments(top);
    if (segments.length === 0) return '';
    const total = top.reduce((acc, r) => acc + r.rules, 0);
    const circles = segments
      .map((seg, i) => {
        const tip = `${escapeHtml(seg.label)}: ${seg.length.toFixed(1)}% of top ${segments.length} pack rules`;
        return `<circle class="seg" cx="50" cy="50" r="35" pathLength="100"
      stroke-dasharray="${seg.length} ${100 - seg.length}"
      stroke-dashoffset="${(100 - seg.offset) % 100}"
      style="--seg-color: var(--chart-hue-${i % 10});"
      data-bar-pack="${escapeHtml(seg.id)}"
      tabindex="0" role="button"
      aria-label="${escapeHtml(seg.label)}"
      title="${tip}"></circle>`;
      })
      .join('\n      ');
    return `<div class="donut-wrap" aria-label="Pack rule proportions">
    <svg class="donut" viewBox="0 0 100 100">
      <circle class="donut-track" cx="50" cy="50" r="35" pathLength="100"></circle>
      ${circles}
    </svg>
    <div class="donut-legend">
      <span class="total">${total}</span>
      <span class="lbl">rules</span>
    </div>
  </div>`;
  }

  /**
   * Disabled rules section — graphical review and re-enable for everything
   * the user previously turned off via `analysis_options_custom.yaml`.
   *
   * The buttons post `command` messages with `id="enableRule:<ruleName>"`;
   * `_runDashboardCommand` parses the prefix, validates the rule name shape,
   * and forwards to `saropaLints.enableRules`. Unknown / unsafe shapes are
   * dropped because the message arrives over postMessage and the rule name
   * flows into a config write.
   *
   * Empty state shows an explanatory blurb instead of an empty list so the
   * section explains what it would normally show.
   */
  private _buildDisabledRulesSection(ctx: DashboardContext): string {
    const count = ctx.disabledRules.length;
    const summary = `<summary><span class="expander-title">Disabled rules</span> <span class="muted">(${count})</span></summary>`;
    if (count === 0) {
      // Collapsed by default even when empty: empty state rarely needs immediate attention,
      // and keeping the same `<details>` shell avoids a visual jump if a rule is later disabled.
      return `<details class="section expander disabled-rules" aria-label="Disabled rules">
  ${summary}
  <p class="hint">No rules are currently disabled by override. When you disable a rule (right-click in Issues, or the Triage panel), it appears here with a one-click re-enable.</p>
</details>`;
    }
    // Build rule → owning pack labels map. A rule may belong to multiple packs; the first
    // pack (alphabetical by RULE_PACK_DEFINITIONS order) wins for grouping so each rule
    // appears exactly once in the UI. Rules not in any pack land in a "Tier-only" bucket.
    const ruleToPack = new Map<string, string>();
    for (const def of RULE_PACK_DEFINITIONS) {
      for (const code of def.ruleCodes) {
        if (!ruleToPack.has(code)) ruleToPack.set(code, def.label);
      }
    }
    const TIER_ONLY = 'Tier-only (no pack)';
    const groups = new Map<string, string[]>();
    for (const rule of ctx.disabledRules) {
      const groupName = ruleToPack.get(rule) ?? TIER_ONLY;
      const list = groups.get(groupName);
      if (list) {
        list.push(rule);
      } else {
        groups.set(groupName, [rule]);
      }
    }
    // Sort: real packs alphabetically first, then "Tier-only" bucket last so the catch-all
    // doesn't outrank named packs in the visual hierarchy.
    const sortedGroupNames = [...groups.keys()].sort((a, b) => {
      if (a === TIER_ONLY) return 1;
      if (b === TIER_ONLY) return -1;
      return a.localeCompare(b);
    });
    const groupHtml = sortedGroupNames.map((groupName) => {
      const rules = groups.get(groupName)!;
      const rows = rules.map((rule) => {
        const id = `enableRule:${rule}`;
        const ruleEsc = escapeHtml(rule);
        return `<li class="disabled-rule-row" data-rule="${ruleEsc}">
    <code>${ruleEsc}</code>
    <button type="button" class="btn tier-3" data-command="${escapeHtml(id)}" title="Re-enable ${ruleEsc}">Re-enable</button>
  </li>`;
      }).join('\n');
      const groupEsc = escapeHtml(groupName);
      return `<div class="disabled-rules-group" data-group="${groupEsc}">
  <h4 class="disabled-rules-group-heading">${groupEsc} <span class="muted">(${rules.length})</span></h4>
  <ul class="disabled-rules-list">${rows}</ul>
</div>`;
    }).join('\n');
    return `<details class="section expander disabled-rules" aria-label="Disabled rules">
  ${summary}
  <p class="hint">These rules are turned off via overrides in <code>analysis_options_custom.yaml</code>. Re-enable a rule below; the file is managed by the extension — no manual editing required.</p>
  <div class="disabled-rules-toolbar">
    <input type="search" id="disabled-rules-search" class="disabled-rules-search" placeholder="Search disabled rules…" aria-label="Search disabled rules" autocomplete="off" spellcheck="false" />
    <span class="muted disabled-rules-empty-hint" id="disabled-rules-empty-hint" hidden>No disabled rules match.</span>
  </div>
  <div class="disabled-rules-groups">
    ${groupHtml}
  </div>
</details>`;
  }

  /** Diagnostics band: suppressions, target platforms, docs (§14.7 step 6, §14.14). */
  private _buildDiagnostics(ctx: DashboardContext): string {
    return `<section class="diagnostics" aria-label="Diagnostics and references">
  <div>
    <h3>Suppressions snapshot</h3>
    ${ctx.suppressionsStripHtml}
  </div>
  ${this._buildPlatformsBlock(ctx)}
  <div>
    <h3>Docs</h3>
    <ul class="docs">
      <li><a href="https://pub.dev/packages/saropa_lints">Package on pub.dev</a></li>
      <li><a href="https://github.com/saropa/saropa_lints/blob/main/doc/guides/rule_packs.md">Rule pack guide</a></li>
      <li><a href="https://github.com/saropa/saropa_lints#rule-configuration-cheatsheet">Tier and pack cheatsheet</a></li>
    </ul>
  </div>
</section>`;
  }

  private _buildPlatformsBlock(ctx: DashboardContext): string {
    if (!ctx.pubspecInfo.isFlutter) {
      return `<div>
    <h3>Target platforms</h3>
    <p class="hint">Pure Dart package — no Flutter embedder targets.</p>
  </div>`;
    }
    const platRows = FLUTTER_EMBEDDER_PLATFORMS.map((p) => {
      const present = ctx.pubspecInfo.platforms.includes(p);
      return `<tr><td>${escapeHtml(p)}</td><td class="${present ? 'ok' : 'muted'}">${present ? 'Yes' : 'No'}</td></tr>`;
    }).join('');
    return `<div>
    <h3>Target platforms</h3>
    <table class="plat"><thead><tr><th>Platform</th><th>Present</th></tr></thead><tbody>${platRows}</tbody></table>
    <p class="hint">Detected from embedder folders (android/, ios/, …).</p>
  </div>`;
  }

  private _wrapHtml(body: string, scripts: boolean): string {
    const nonce = createWebviewCspNonce();
    // 'unsafe-inline' on style-src: hero coverage gauge sets dynamic CSS vars
    // (--gauge-target, --gauge-arc, --gauge-color) via inline style="..." attributes.
    // CSP nonces only authorize <style> blocks, not style attributes — without
    // 'unsafe-inline' the vars are dropped, the dasharray falls back to 0, and the
    // gauge renders as a tiny dot.
    const csp = [
      "default-src 'none'",
      `style-src 'nonce-${nonce}' 'unsafe-inline'`,
      scripts ? `script-src 'nonce-${nonce}'` : '',
    ]
      .filter(Boolean)
      .join('; ');
    const script = scripts
      ? `<script nonce="${nonce}">${getConfigDashboardScript()}</script>`
      : '';
    return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Saropa Lints Config</title><meta http-equiv="Content-Security-Policy" content="${csp}">
<style nonce="${nonce}">${getConfigDashboardStyles()}</style></head><body>${body}${script}</body></html>`;
  }

  private async _handleToggle(packId: string, enabled: boolean): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const cur = readRulePacksEnabled(root);
    const next = new Set(cur);
    if (enabled) {
      next.add(packId);
    } else {
      next.delete(packId);
    }
    const ok = writeRulePacksEnabled(
      root,
      [...next].sort((a, b) => a.localeCompare(b)),
    );
    if (!ok) {
      void vscode.window.showErrorMessage('Saropa Lints: could not write analysis_options.yaml (rule_packs).');
      return;
    }
    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    this.refresh();
  }

  private async _showRulesList(packId: string): Promise<void> {
    const def = RULE_PACK_DEFINITIONS.find((d) => d.id === packId);
    if (!def) return;
    const items = def.ruleCodes.map((code) => ({ label: code, description: '' }));
    await vscode.window.showQuickPick(items, {
      title: `${def.label} — ${def.ruleCodes.length} rules`,
      placeHolder: 'Rule codes in this pack',
    });
  }

  private async _runDashboardCommand(id: string): Promise<void> {
    // The legacy 'setTier' id is preserved for any toolbar entry points that still post it (e.g.
    // command palette callers); the in-page tier radio control posts a typed `setTier` message
    // instead, handled by `_handleSetTier`.
    if (id === 'setTier') {
      await vscode.commands.executeCommand('saropaLints.setTier');
      return;
    }
    if (id === 'openConfig') {
      await vscode.commands.executeCommand('saropaLints.openConfig');
      return;
    }
    if (id === 'runAnalysis') {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
      return;
    }
    if (id === 'refresh') {
      this.refresh();
      return;
    }
    if (id === 'copyConfigSnippet') {
      await this._copyConfigSnippet();
      return;
    }
    if (id === 'openVibrancy') {
      await vscode.commands.executeCommand('saropaLints.openPackageVibrancy');
      return;
    }
    if (id === 'openFindingsDashboard') {
      await vscode.commands.executeCommand('saropaLints.openViolationsWideReport');
      return;
    }
    if (id === 'enableDetectedSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'all' });
      return;
    }
    if (id === 'enableDetectedBreakingSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'breaking' });
      return;
    }
    if (id === 'enableDetectedDeprecationSdkPacks') {
      await this._enableDetectedSdkPacks({ selection: 'deprecation' });
      return;
    }
    // Per-rule re-enable from the Disabled rules section. The id arrives as
    // `enableRule:<ruleName>`; validate the shape before forwarding because
    // postMessage is untrusted and the rule name reaches a config write.
    if (id.startsWith('enableRule:')) {
      const ruleName = id.slice('enableRule:'.length);
      // Lint rule names are conventionally snake_case identifiers; reject
      // anything that does not match so we never write garbage to the
      // overrides file.
      if (!/^[a-z][a-z0-9_]*$/.test(ruleName)) return;
      await vscode.commands.executeCommand('saropaLints.enableRules', [ruleName]);
      this.refresh();
      return;
    }
  }

  /**
   * Copy the current Lints Config (tier + enabled packs) to the clipboard as a paste-ready
   * YAML snippet. Falls back to a notification if clipboard access fails (rare in webview hosts
   * but possible behind certain remote-extension configurations).
   */
  private async _copyConfigSnippet(): Promise<void> {
    const root = getProjectRoot();
    if (!root) {
      void vscode.window.showWarningMessage('Saropa Lints: open a workspace folder before copying the config.');
      return;
    }
    const tier =
      vscode.workspace.getConfiguration('saropaLints').get<string>('tier', 'recommended') ??
      'recommended';
    const enabled = readRulePacksEnabled(root);
    const snippet = buildConfigSnippetYaml(tier, enabled);
    try {
      await vscode.env.clipboard.writeText(snippet);
      const packsLine =
        enabled.length === 0 ? 'no packs enabled' : `${enabled.length} pack${enabled.length === 1 ? '' : 's'}`;
      void vscode.window.showInformationMessage(
        `Saropa Lints: copied config snippet (tier: ${tier}, ${packsLine}).`,
      );
    } catch (err) {
      void vscode.window.showErrorMessage(
        `Saropa Lints: could not copy to clipboard — ${err instanceof Error ? err.message : String(err)}.`,
      );
    }
  }

  /**
   * Persist a tier change posted by the in-page radio control.
   *
   * Validates against the {@link TIERS} whitelist before writing — the message arrives over
   * postMessage and must not be trusted with arbitrary configuration writes. Refresh after the
   * write so the new active tier renders without waiting for the analyzer to complete.
   */
  private async _handleSetTier(tier: string): Promise<void> {
    if (!(TIERS as readonly string[]).includes(tier)) return;
    const config = vscode.workspace.getConfiguration('saropaLints');
    const current = config.get<string>('tier', 'recommended');
    if (current === tier) return;
    await config.update('tier', tier, vscode.ConfigurationTarget.Workspace);
    this.refresh();
    const run = config.get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
  }

  private async _enableDetectedSdkPacks(options: { selection: SdkRiskSelection }): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const pubspecPath = path.join(root, 'pubspec.yaml');
    let pubspecContent = '';
    try {
      pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
    } catch {
      void vscode.window.showErrorMessage('Saropa Lints: could not read pubspec.yaml.');
      return;
    }

    const currentEnabled = new Set(readRulePacksEnabled(root));
    const detectedSdkDefs = RULE_PACK_DEFINITIONS.filter((def) => {
      if (!sdkPackMatchesSelection(def, options.selection)) return false;
      if (!isPackDetected(def, pubspecContent)) return false;
      return true;
    });
    const toEnable = detectedSdkDefs.filter((def) => !currentEnabled.has(def.id));
    if (toEnable.length === 0) {
      void vscode.window.showInformationMessage('Saropa Lints: no additional applicable SDK packs to enable.');
      return;
    }
    const confirmed = await this._confirmSdkBulkEnable(options.selection, toEnable.map((def) => def.label));
    if (!confirmed) return;

    let added = 0;
    for (const def of detectedSdkDefs) {
      if (!currentEnabled.has(def.id)) {
        currentEnabled.add(def.id);
        added += 1;
      }
    }
    const ok = writeRulePacksEnabled(root, [...currentEnabled].sort((a, b) => a.localeCompare(b)));
    if (!ok) {
      void vscode.window.showErrorMessage('Saropa Lints: could not write analysis_options.yaml (rule_packs).');
      return;
    }

    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    const modeLabel =
      options.selection === 'breaking'
        ? 'breaking SDK'
        : options.selection === 'deprecation'
          ? 'deprecation SDK'
          : 'SDK';
    void vscode.window.showInformationMessage(
      `Saropa Lints: enabled ${added} applicable ${modeLabel} pack(s).`,
    );
    this.refresh();
  }

  private async _confirmSdkBulkEnable(
    selection: SdkRiskSelection,
    packLabels: readonly string[],
  ): Promise<boolean> {
    const modeLabel =
      selection === 'breaking'
        ? 'breaking SDK'
        : selection === 'deprecation'
          ? 'deprecation SDK'
          : 'SDK';
    const preview = packLabels.slice(0, 5).join(', ');
    const suffix = packLabels.length > 5 ? `, +${packLabels.length - 5} more` : '';
    const choice = await vscode.window.showWarningMessage(
      `Enable ${packLabels.length} ${modeLabel} pack(s)?`,
      {
        modal: true,
        detail: `This updates rule_packs.enabled in analysis_options.yaml. ${preview}${suffix}`,
      },
      'Enable',
    );
    return choice === 'Enable';
  }
}

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** Panel `viewType` for the Config Dashboard webview panel (editor area). */
export const CONFIG_DASHBOARD_PANEL_ID = CONFIG_DASHBOARD_PANEL_TYPE;

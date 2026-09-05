/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * VS Code extension host code (activation, services, readers).
 */

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
import {
  readDisabledRules,
  readRuleOverrides,
  writeRuleOverrides,
  removeRuleOverrides,
} from '../configWriter';
import { readPubspec, FLUTTER_EMBEDDER_PLATFORMS } from '../pubspecReader';
import { readViolations, filterDisabledFromData } from '../violationsReader';
import { buildSuppressionsExportSnapshotStripHtml } from '../views/configDashboardSuppressionsStrip';
import { RULE_PACK_DEFINITIONS, isPackDetected } from './rulePackDefinitions';
import { enforceSingleVersion, versionGroupIndex } from './versionGroups';
import { STYLISTIC_PACK_DEFINITIONS } from './stylisticPackDefinitions';
import { packDomainForId, PACK_DOMAIN_ORDER } from './packDomains';
import { l10n } from '../i18n/runtime';
import { createWebviewCspNonce } from '../vibrancy/views/html-utils';
import { getConfigDashboardScript } from './configDashboardScript';
import { getConfigDashboardStyles } from './configDashboardStyles';
// Phase 7 leftover (deferred): Rules & Tiers already ships working digit shortcuts (1-7, see
// _buildTabBar) but never surfaced the shared '?' overlay that Findings/Packages use, so those
// shortcuts were undiscoverable. Wires the same button + overlay + script + styles pattern.
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from '../views/keyboard-shortcuts';
import type { MemoryPressureState } from '../systemHealth/memoryPressureWatcher';
import { readRulePacksEnabled, writeRulePacksEnabled } from './rulePackYaml';
import { computeConfigSuggestions } from '../config/configSuggestions';
import { fetchRuleCounts, type RuleCountSummary } from '../views/ruleCountCliRunner';
import type { AnalysisOptimizerWebviewProvider } from '../analysisOptimizer/analysisOptimizerWebviewProvider';
import {
  readScalarKey,
  writeScalarKey,
  readPlatforms,
  writePlatforms,
  readSeverities,
  writeSeverityEntry,
  removeSeverityEntry,
  readBannedUsage,
  writeBannedUsage,
  readDiagnosticThresholds,
  writeDiagnosticThresholds,
  OUTPUT_MODES,
  CUSTOM_YAML_TIERS,
  CUSTOM_YAML_TOP_LEVEL_KEYS,
  type SeverityLevel,
  type BannedUsageEntry,
  type DiagnosticThreshold,
  type CustomYamlTopLevelKey,
} from './customConfigYaml';
import { readBaselineSummary, baselineFilePath, computeBaselineDiff, type BaselineDiff } from './baselineReader';
// Bare diagnostic-to-violation builder (not the enriched `readLiveViolations` wrapper) — the
// diff only needs file/rule/line, so skipping rule-catalog enrichment and tier resolution keeps
// this read as cheap as the handover's "must not trigger a scan" constraint requires.
import { buildViolationsDataFromDiagnostics } from '../liveDiagnosticsModel';
// `lane:` is a top-level `analysis_options_custom.yaml` key like the ones in
// `customConfigYaml.ts`, but it has deprecation-fallback read semantics (an
// old `plugins > saropa_lints:` location is still honored) the generic
// `readScalarKey`/`writeScalarKey` helpers there do not implement — its
// reader/writer lives in `laneConfig.ts` instead. See
// `CUSTOM_YAML_TOP_LEVEL_KEYS`'s `lane` entry comment in `customConfigYaml.ts`.
import { readRawLaneFromCustomConfig, writeLaneToCustomConfig, type RuleLaneValue } from '../config/laneConfig';
import { buildSettingsCatalog, findSettingEntry, flatSettingKey, type SettingCatalogEntry } from './settingsCatalog';

const CONFIG_DASHBOARD_PANEL_TYPE = 'saropaLints.configDashboard';
const TIERS = ['essential', 'recommended', 'professional', 'comprehensive', 'pedantic'] as const;

/**
 * The 7 tabs the Config Dashboard renders (Phase 4, PLAN_extension_ui_redesign.md §2.2 Rules &
 * Tiers row). Order here fixes both the tab bar's left-to-right order and each tab's `1`-`7`
 * keyboard shortcut (UX_UI_GUIDELINES keyboard-shortcuts convention: tabs reachable by digit).
 */
const TAB_IDS = ['tier', 'packs', 'overrides', 'sdk', 'configFile', 'automation', 'extension'] as const;
type TabId = (typeof TAB_IDS)[number];
const DEFAULT_TAB: TabId = 'tier';

/** Type guard validating an untrusted postMessage `tab` string against {@link TAB_IDS}. */
function isTabId(value: string): value is TabId {
  return (TAB_IDS as readonly string[]).includes(value);
}

/**
 * The Config file tab's card ids. Exported so
 * `extension/src/test/rulePacks/configFileCardCoverage.test.ts` can assert every
 * {@link CUSTOM_YAML_TOP_LEVEL_KEYS} entry maps (via {@link CONFIG_FILE_KEY_TO_CARD}) to one of
 * these — the guard against a 9th custom-yaml key shipping with no UI (Phase 4 design requirement,
 * PLAN_extension_ui_redesign.md §1 principle 4).
 */
export const CONFIG_FILE_CARD_IDS = [
  'analysisSettings',
  'tierCap',
  'lane',
  'platforms',
  'severities',
  'bannedUsage',
  'diagnosticStatistics',
] as const;
export type ConfigFileCardId = (typeof CONFIG_FILE_CARD_IDS)[number];

/**
 * Maps each of the 9 `analysis_options_custom.yaml` top-level keys to the Config file tab card
 * that renders its control. Two keys share a card where they are naturally one concern
 * (`max_issues`+`output` are both "analysis settings"; `saropa_tier`+`runtime_tier` are both
 * "tier caps") — the coverage test checks every KEY maps somewhere, not a strict 1:1 key:card
 * ratio, since that pairing is a deliberate UI grouping decision, not an oversight. `lane` gets
 * its OWN card (not folded into `tierCap`) because it round-trips through `laneConfig.ts`'s
 * dedicated reader/writer, not the generic scalar helpers the other cards share (WP2, sidebar row
 * collapse plan) — sharing a card would blur that distinction for the next person editing it.
 */
export const CONFIG_FILE_KEY_TO_CARD: Record<CustomYamlTopLevelKey, ConfigFileCardId> = {
  max_issues: 'analysisSettings',
  output: 'analysisSettings',
  saropa_tier: 'tierCap',
  runtime_tier: 'tierCap',
  lane: 'lane',
  platforms: 'platforms',
  severities: 'severities',
  banned_usage: 'bannedUsage',
  diagnostic_statistics: 'diagnosticStatistics',
};

// Pack id → version-group dependency, computed once from the static registry.
// Packs in a multi-version group (dio+dio_5, riverpod+riverpod_2+riverpod_3, …)
// render an exclusive control so only one version of a package can be enabled.
const VERSION_GROUP_INDEX = versionGroupIndex(RULE_PACK_DEFINITIONS);

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
  /**
   * Stylistic rule codes currently turned ON via overrides (`rule: true`).
   * Stylistic rules are off in every tier, so an explicit `true` override is
   * the only way one is active. Drives the checked/selected state of the
   * Style & opinions section's toggles and radios.
   */
  enabledStylistic: ReadonlySet<string>;
  /**
   * Rule names currently shed under memory pressure, keyed by shed category.
   * Empty when no rules are shed (shedLevel === 0 or no pressure state).
   */
  shedByCategory: ReadonlyMap<string, readonly string[]>;
  /** Total count per category (may exceed the listed array, which caps at 20). */
  shedCategoryTotals: ReadonlyMap<string, number>;
  /** Total count of rules currently shed across all categories. */
  shedRuleCount: number;
  /** Flat set of all shed rule names for O(1) lookup when marking individual rules. */
  shedRuleNames: ReadonlySet<string>;
}

export function isSdkPackId(id: string): boolean {
  return id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_');
}

/**
 * "12 packs · 340 rules" count label for a section or domain accordion header, so a
 * user can see where rules concentrate before opening the group. Both halves are
 * pluralized; the `·` separates them.
 */
export function packsAndRulesLabel(packCount: number, ruleCount: number): string {
  const packs = `${packCount} pack${packCount === 1 ? '' : 's'}`;
  const rules = `${ruleCount} rule${ruleCount === 1 ? '' : 's'}`;
  return `${packs} · ${rules}`;
}

/** Sum the rule counts of a set of pack rows (for header count badges). */
export function sumPackRules(rows: readonly PackChartRow[]): number {
  return rows.reduce((acc, r) => acc + r.rules, 0);
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
export function buildTierControl(
  currentTier: string,
  ruleCounts: RuleCountSummary | null = null,
): string {
  const buttons = TIERS.map((tier) => {
    const active = tier === currentTier;
    const count = ruleCounts?.[tier];
    // Live count, not a static "≈2000 rules" string that drifts stale as
    // rules are added — see plans/history/2026.08/2026.08.19/rule_count_correction.md
    // for why hardcoded counts caused a real user-facing accuracy bug.
    const countLabel = typeof count === 'number' ? ` <span class="tier-btn-count">${escapeHtml(l10n('tierPicker.ruleCount', { count: String(count) }))}</span>` : '';
    const label = active
      ? `${escapeHtml(tier)} (current)${countLabel}`
      : `${escapeHtml(tier)}${countLabel}`;
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
  // Cached across refresh() calls (fired on every toggle/edit) so the tier
  // picker's live counts don't re-spawn `dart run` dozens of times per
  // session — fetched once per panel open, then reused until the panel closes.
  private _ruleCounts: RuleCountSummary | null = null;
  private _ruleCountsRequested = false;
  // Latest memory pressure snapshot pushed from MemoryPressureWatcher via
  // extension.ts — drives the "Shed rules" section and per-rule shed badges.
  private _memoryPressureState: MemoryPressureState | null = null;
  // Set post-construction via {@link setAnalysisOptimizerProvider} once extension.ts has
  // constructed both providers — injecting it at construction time would force an ordering
  // dependency between the two activation call sites. Optional because the Config file tab's
  // Analysis Optimizer subsection degrades to a "not available" note if never wired (defensive;
  // extension.ts always wires it today).
  private _analysisOptimizerProvider?: AnalysisOptimizerWebviewProvider;
  // Tracks which tab the client last reported active (via `setActiveTab`) so a host-triggered
  // refresh (config file watcher, memory pressure update, locale change) re-renders with the
  // SAME tab open instead of resetting to the Tier tab every time — satisfies Phase 4's "wire the
  // config file watcher to re-render whichever tab is active" without needing the host to track
  // DOM state itself; the client script is still the source of truth for the CSS visibility toggle
  // (see `SCRIPT_TABS` in configDashboardScript.ts), this only decides which tab's data-heavy
  // subsections (e.g. re-reading the baseline file) get rebuilt into the fresh HTML string.
  private _activeTab: TabId = DEFAULT_TAB;

  constructor(private readonly _extensionUri: vscode.Uri) {}

  /** Receive a memory pressure update from the watcher; refreshes the panel if open. */
  setMemoryPressureState(state: MemoryPressureState | null): void {
    this._memoryPressureState = state;
    this.refresh();
  }

  /**
   * Wires the Analysis Optimizer provider so the Config file tab can embed its live body HTML
   * and forward its button clicks (Phase 4 "Analysis Optimizer moves in as a tab"). Called once
   * from `extension.ts` right after both providers are constructed.
   */
  setAnalysisOptimizerProvider(provider: AnalysisOptimizerWebviewProvider): void {
    this._analysisOptimizerProvider = provider;
  }

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
      // Files / the editor tab dropdown when many unrelated tabs are open. "Manage Rule
      // Packs" names the powerful, easily-missed package packs that are the panel's point.
      'Saropa Lints: Manage Rule Packs',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        localResourceRoots: [this._extensionUri],
        retainContextWhenHidden: true,
      },
    );
    this._panel = panel;

    panel.webview.onDidReceiveMessage(
      (msg: {
        type: string;
        packId?: string;
        enabled?: boolean;
        id?: string;
        tier?: string;
        rule?: string;
        // --- Phase 4 additions: tab persistence, generic settings grid, Config file tab writers,
        // and Analysis Optimizer message forwarding. See each handler for the shape it expects.
        tab?: string;
        key?: string;
        value?: unknown;
        scalarKey?: string;
        platforms?: Record<string, boolean>;
        level?: string;
        identifier?: string;
        reason?: string;
        entries?: BannedUsageEntry[];
        warn?: number | null;
        fail?: number | null;
        optimizer?: { type: string; pattern?: string; patterns?: string[] };
      }) => {
        if (msg.type === 'toggle' && msg.packId !== undefined && msg.enabled !== undefined) {
          void this._handleToggle(msg.packId, msg.enabled);
        }
        // A single stylistic rule toggled on/off (multi-select groups). Enabling
        // writes `rule: true`; disabling removes the override (back to off default).
        if (msg.type === 'toggleRule' && typeof msg.rule === 'string' && msg.enabled !== undefined) {
          void this._handleToggleRule(msg.rule, msg.enabled);
        }
        // A pick-one stylistic group choice. `packId` is the group id; `rule` is
        // the chosen rule code, or '' to clear the whole group.
        if (msg.type === 'selectStylistic' && typeof msg.packId === 'string' && typeof msg.rule === 'string') {
          void this._handleSelectStylistic(msg.packId, msg.rule);
        }
        // Enable-all / disable-all for a multi-select stylistic group.
        if (msg.type === 'stylisticBulk' && typeof msg.packId === 'string' && msg.enabled !== undefined) {
          void this._handleStylisticBulk(msg.packId, msg.enabled);
        }
        // A rule code clicked inside an expanded pack row opens its explanation.
        // The name arrives over untrusted postMessage and reaches a command, so
        // validate it as a snake_case lint id before forwarding.
        if (msg.type === 'explainRule' && typeof msg.rule === 'string') {
          if (/^[a-z][a-z0-9_]*$/.test(msg.rule)) {
            void vscode.commands.executeCommand('saropaLints.explainRule', msg.rule);
          }
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
        // Client-side tab switches persist via vscode.setState, but the host still needs to
        // know the active tab so a config-file-watcher-triggered refresh (see extension.ts) can
        // re-render without the client needing to re-post its remembered tab on every refresh.
        if (msg.type === 'setActiveTab' && typeof msg.tab === 'string' && isTabId(msg.tab)) {
          this._activeTab = msg.tab;
        }
        // Generic `saropaLints.*` settings grid (Automation / Extension tabs). `key` is
        // validated against the static catalog below — never trust a postMessage key directly
        // into `workspace.getConfiguration().update()`.
        if (msg.type === 'updateSetting' && typeof msg.key === 'string') {
          void this._handleUpdateSetting(msg.key, msg.value);
        }
        // Config file tab: the previously-UI-less analysis_options_custom.yaml keys.
        if (msg.type === 'writeScalar' && typeof msg.scalarKey === 'string') {
          void this._handleWriteScalar(msg.scalarKey, typeof msg.value === 'string' ? msg.value : undefined);
        }
        // `lane` gets its own message type (not `writeScalar`) so it never routes through the
        // generic scalar allow-list in `_handleWriteScalar` — see `_buildLaneCard`'s doc comment
        // for why `lane`'s read/write must stay on `laneConfig.ts`'s dedicated functions.
        if (msg.type === 'writeLane' && typeof msg.value === 'string') {
          void this._handleWriteLane(msg.value);
        }
        if (msg.type === 'writePlatforms' && msg.platforms) {
          void this._handleWritePlatforms(msg.platforms);
        }
        if (msg.type === 'writeSeverity' && typeof msg.rule === 'string' && typeof msg.level === 'string') {
          void this._handleWriteSeverity(msg.rule, msg.level);
        }
        if (msg.type === 'removeSeverity' && typeof msg.rule === 'string') {
          void this._handleRemoveSeverity(msg.rule);
        }
        if (msg.type === 'addBannedUsage' && typeof msg.identifier === 'string') {
          void this._handleAddBannedUsage(msg.identifier, msg.reason ?? '');
        }
        if (msg.type === 'removeBannedUsage' && typeof msg.identifier === 'string') {
          void this._handleRemoveBannedUsage(msg.identifier);
        }
        if (msg.type === 'setDiagnosticThreshold' && typeof msg.rule === 'string') {
          void this._handleSetDiagnosticThreshold(msg.rule, msg.warn ?? undefined, msg.fail ?? undefined);
        }
        if (msg.type === 'removeDiagnosticThreshold' && typeof msg.rule === 'string') {
          void this._handleRemoveDiagnosticThreshold(msg.rule);
        }
        // Analysis Optimizer embed: forward the exact message shape its own standalone panel
        // script would have sent, then re-render this tab from the updated embedded body.
        if (msg.type === 'optimizerCommand' && msg.optimizer) {
          void this._handleOptimizerCommand(msg.optimizer);
        }
      },
    );

    panel.onDidDispose(() => {
      this._panel = undefined;
      // Re-fetch on next open rather than serving a session-stale count —
      // rules can change between opens (e.g. the user updates the package).
      this._ruleCounts = null;
      this._ruleCountsRequested = false;
    });

    this._loadRuleCounts();
    this.refresh();
  }

  /**
   * Fires the rule-count CLI once per panel lifetime and redraws when it
   * resolves. Best-effort: `fetchRuleCounts` already degrades to `null` on
   * any failure (no workspace, CLI missing, timeout), so the tier picker
   * simply renders without counts rather than erroring.
   */
  private _loadRuleCounts(): void {
    if (this._ruleCountsRequested) return;
    this._ruleCountsRequested = true;
    const root = getProjectRoot();
    if (!root) return;
    void fetchRuleCounts(root).then((counts) => {
      if (counts) {
        this._ruleCounts = counts;
        this.refresh();
      }
    });
  }

  refresh(): void {
    const webview = this._panel?.webview;
    if (!webview) {
      return;
    }
    webview.html = this._buildHtml();
  }

  /**
   * Build the Rules & Tiers webview body.
   *
   * Phase 4 (PLAN_extension_ui_redesign.md §2.2) turned this dashboard from one long scrolling
   * page into 7 tabs: Tier · Rule packs · Overrides · SDK rollout · Config file · Automation ·
   * Extension. The header + KPI strip stay OUTSIDE the tab body (persistent context — tier,
   * coverage, and freshness matter no matter which tab is open); everything else moved into
   * exactly one tab per the mapping documented on each `_build*Tab` method.
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
      this._buildTabBar(),
      this._buildTierTab(ctx),
      this._buildPacksTab(ctx),
      this._buildOverridesTab(ctx),
      this._buildSdkRolloutTab(ctx),
      this._buildConfigFileTab(root),
      this._buildAutomationTab(),
      this._buildExtensionTab(ctx),
      // Phase 7 leftover: pairs the '?' button placed in the header status-line with its overlay
      // markup — without this the button had nothing to toggle open.
      buildKeyboardShortcutsOverlay([
        { key: '1-7', label: l10n('rulesTiers.shortcuts.jumpToTab') },
        { key: '← / →', label: l10n('rulesTiers.shortcuts.prevNextTab') },
        { key: '?', label: l10n('rulesTiers.shortcuts.showOverlay') },
      ]),
    ].join('\n');

    return this._wrapHtml(body, true);
  }

  /**
   * Renders the tab bar as `<button role="tab">` elements — same real-control convention
   * `buildTierControl` established for the tier segmented control, so keyboard users can Tab to
   * the strip and arrow between tabs (wired in `configDashboardScript.ts` `SCRIPT_TABS`).
   * `data-active-tab` on the wrapping element (set from {@link _activeTab}) is what a full HTML
   * rebuild (e.g. the config-file-watcher-triggered refresh) uses to reopen on the same tab
   * instead of resetting to Tier — the client script reads this attribute once on load and then
   * owns visibility from there via its own click handlers.
   */
  private _buildTabBar(): string {
    const labelKeys: Record<TabId, string> = {
      tier: 'rulesTiers.tab.tier',
      packs: 'rulesTiers.tab.packs',
      overrides: 'rulesTiers.tab.overrides',
      sdk: 'rulesTiers.tab.sdk',
      configFile: 'rulesTiers.tab.configFile',
      automation: 'rulesTiers.tab.automation',
      extension: 'rulesTiers.tab.extension',
    };
    const buttons = TAB_IDS.map((id, index) => {
      const active = id === this._activeTab;
      return [
        '<button type="button" class="rt-tab-btn"',
        ' role="tab"',
        ` id="rt-tab-${id}"`,
        ` aria-controls="rt-panel-${id}"`,
        ` aria-selected="${active ? 'true' : 'false'}"`,
        ` tabindex="${active ? '0' : '-1'}"`,
        ` data-tab="${id}">`,
        // Digit shortcut hint (1-7) — matches UX_UI_GUIDELINES "every dashboard tab reachable by
        // 1-9" convention already used elsewhere (Findings, Code Health).
        `<span class="rt-tab-kbd">${index + 1}</span> ${escapeHtml(l10n(labelKeys[id]))}`,
        '</button>',
      ].join('');
    }).join('');
    return `<div class="rt-tabbar" role="tablist" aria-label="${escapeHtml(l10n('rulesTiers.tabBar.ariaLabel'))}" data-active-tab="${this._activeTab}">${buttons}</div>`;
  }

  /** Wraps one tab's content in the shared `role="tabpanel"` shell the client script shows/hides. */
  private _tabPanel(id: TabId, contentHtml: string): string {
    const hidden = id === this._activeTab ? '' : ' hidden';
    return `<div class="rt-tab-panel" id="rt-panel-${id}" role="tabpanel" aria-labelledby="rt-tab-${id}"${hidden}>${contentHtml}</div>`;
  }

  /** Tier tab: the segmented tier control only — coverage/freshness context lives in the persistent header above the tabs. */
  private _buildTierTab(ctx: DashboardContext): string {
    return this._tabPanel('tier', this._buildTierSection(ctx));
  }

  /**
   * Rule packs tab: toolbar (search/filter/enable-all), the detected/all pack tables, and the
   * coverage chart. This is the dashboard's original primary content, unchanged in substance —
   * only the SDK-specific bulk-enable overflow moved out to the new SDK rollout tab so this tab
   * stays about "which packs are on", not "which migrations are pending".
   */
  private _buildPacksTab(ctx: DashboardContext): string {
    const content = [
      this._buildToolbar(ctx),
      '<div class="chip-strip" id="filter-strip" hidden></div>',
      '<div class="rule-finder" id="rule-finder" hidden></div>',
      this._buildPackTable(ctx),
      this._buildChartSection(ctx),
    ].join('\n');
    return this._tabPanel('packs', content);
  }

  /**
   * Overrides tab: absorbs the Style & opinions (stylistic) section AND the standalone Lints
   * Config dashboard's "Disabled rules" section (Phase 4 requirement #5) — both edit the same
   * concept, "deviate a specific rule from what the tier/packs would otherwise set", so they
   * belong together even though one is an opt-IN (stylistic) and the other an opt-OUT (disabled).
   */
  private _buildOverridesTab(ctx: DashboardContext): string {
    const content = [this._buildStylisticSection(ctx), this._buildDisabledRulesSection(ctx), this._buildShedRulesSection(ctx)].join('\n');
    return this._tabPanel('overrides', content);
  }

  /**
   * SDK rollout tab: the SDK-migration-specific bulk-enable actions (previously an overflow menu
   * buried in the packs toolbar) plus a table scoped to ONLY the SDK migration packs — pulling
   * these out of the general pack table means a user planning a Dart/Flutter version bump sees
   * just the packs relevant to that decision, not all ~86 rows.
   */
  private _buildSdkRolloutTab(ctx: DashboardContext): string {
    const sdkRows = ctx.packRows.filter((r) => isSdkPackId(r.id)).sort((a, b) => a.label.localeCompare(b.label));
    const total = ctx.detectedSdkPacks.length;
    const breaking = ctx.detectedBreakingSdkCount;
    const deprecation = ctx.detectedDeprecationSdkCount;
    const summary = `<p class="hint">${escapeHtml(l10n('rulesTiers.sdk.summary', { total: String(total), breaking: String(breaking), deprecation: String(deprecation) }))}</p>`;
    const actions = total === 0
      ? `<p class="hint">${escapeHtml(l10n('rulesTiers.sdk.noneApplicable'))}</p>`
      : `<div class="toolbar-row" style="gap:6px;">
    <button class="btn tier-1" data-command="enableDetectedSdkPacks" title="${escapeHtml(l10n('rulesTiers.sdk.enableAllTitle'))}">${escapeHtml(l10n('rulesTiers.sdk.enableAll', { count: String(total) }))}</button>
    <button class="btn" data-command="enableDetectedBreakingSdkPacks"${breaking === 0 ? ' disabled' : ''} title="${escapeHtml(l10n('rulesTiers.sdk.enableBreakingTitle'))}">${escapeHtml(l10n('rulesTiers.sdk.enableBreaking', { count: String(breaking) }))}</button>
    <button class="btn" data-command="enableDetectedDeprecationSdkPacks"${deprecation === 0 ? ' disabled' : ''} title="${escapeHtml(l10n('rulesTiers.sdk.enableDeprecationTitle'))}">${escapeHtml(l10n('rulesTiers.sdk.enableDeprecation', { count: String(deprecation) }))}</button>
  </div>`;
    const rows = sdkRows.map((row) => this._buildPackRow(row, false, ctx.shedRuleNames)).join('\n');
    const empty = `<tr><td colspan="6" class="hint">${escapeHtml(l10n('rulesTiers.sdk.noPacksInCatalogue'))}</td></tr>`;
    const table = `<div class="dash-table-wrap">
    <table class="dash-table packs" id="sdk-packs-table">
      ${this._packTableHead()}
      <tbody class="packs-tbody">${sdkRows.length > 0 ? rows : empty}</tbody>
    </table>
  </div>`;
    return this._tabPanel('sdk', `<section aria-label="${escapeHtml(l10n('rulesTiers.tab.sdk'))}"><h2>${escapeHtml(l10n('rulesTiers.tab.sdk'))}</h2>${summary}${actions}${table}</section>`);
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
    // Stylistic rules active = overrides explicitly set to true. Stylistic rules
    // sit in no tier, so this is the complete set of opt-ins the user has made.
    const enabledStylistic = new Set<string>();
    for (const [rule, on] of readRuleOverrides(root)) {
      if (on) enabledStylistic.add(rule);
    }
    // Build shed-by-category map from the memory pressure state. Each category
    // key maps to the rule names the analyzer shed for that reason (capped at 20
    // per category by getShedDetails — see handover gotcha).
    const shedByCategory = new Map<string, readonly string[]>();
    const shedCategoryTotals = new Map<string, number>();
    const details = this._memoryPressureState?.shedDetails;
    let shedRuleCount = this._memoryPressureState?.shedRuleCount ?? 0;
    if (details && shedRuleCount > 0) {
      // Populate both the rule-name arrays (capped at 20 by getShedDetails)
      // and the category totals (always accurate). The gap between the two
      // drives a "+N more" indicator in the shed section.
      if (details.typeResolvingRules?.length) {
        shedByCategory.set('typeResolving', details.typeResolvingRules);
      }
      if (details.typeResolving > 0) shedCategoryTotals.set('typeResolving', details.typeResolving);
      if (details.highCostRules?.length) {
        shedByCategory.set('highCost', details.highCostRules);
      }
      if (details.highCost > 0) shedCategoryTotals.set('highCost', details.highCost);
      if (details.infoSeverityRules?.length) {
        shedByCategory.set('infoSeverity', details.infoSeverityRules);
      }
      if (details.infoSeverity > 0) shedCategoryTotals.set('infoSeverity', details.infoSeverity);
      if (details.warningSeverityRules?.length) {
        shedByCategory.set('warningSeverity', details.warningSeverityRules);
      }
      if (details.warningSeverity > 0) shedCategoryTotals.set('warningSeverity', details.warningSeverity);
    }
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
      enabledStylistic,
      shedByCategory,
      shedCategoryTotals,
      shedRuleCount,
      // Flatten all category arrays into one set for O(1) per-rule lookup.
      shedRuleNames: new Set([...shedByCategory.values()].flat()),
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
    <p class="status-line">${statusLine}${buildKeyboardShortcutsButton()}</p>
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
    // The fill's stroke-dasharray is driven by `--gauge-target` / `--gauge-arc`.
    // Those vars are set by the client script (`setProperty`) from the data-*
    // attributes below, NOT from this inline style — a webview CSP that pairs a
    // style-src nonce with 'unsafe-inline' makes the browser ignore 'unsafe-inline'
    // for inline style ATTRIBUTES (they cannot carry a nonce), so `--gauge-target`
    // set here was dropped and the arc rendered empty while the numeric label still
    // showed the score. Seeding `--gauge-target:0` inline gives a definite empty
    // start state; the script raises it to the real score and the scoped transition
    // in configDashboardStyles animates the fill in.
    return `<div class="hero-gauge" role="img"
    aria-label="${escapeHtml(`Pack coverage ${score} percent`)}"
    title="${escapeHtml(tooltip)}"
    data-gauge-target="${score}" data-gauge-arc="100" data-gauge-color="${escapeHtml(hsl)}"
    style="--gauge-target:0;--gauge-arc:100;--gauge-color:${hsl};">
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
  ${buildTierControl(ctx.currentTier, this._ruleCounts)}
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
    <button class="btn tier-1" data-command="enableAllApplicablePacks"
      title="Turn on every rule pack whose dependency or SDK gate your project already satisfies — the packs marked Recommended.">Enable all recommended packs</button>
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
    <input id="pack-search" type="search" placeholder="Search packs and rules…" autocomplete="off" />
  </label>
  <span id="pack-match-count" class="match-count" role="status" aria-live="polite" hidden></span>
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
    // Relevance-first split: packs whose dependency/SDK gate matches this project
    // go in a "For your project" accordion that opens by default; everything else
    // lands in a collapsed "All packages" accordion. This keeps the screen to a
    // few rows on open instead of all ~86, while leaving every pack one click away.
    // Each accordion sorts A–Z by pack name (what users recognize) within itself.
    const byLabel = (a: PackChartRow, b: PackChartRow): number =>
      a.label.localeCompare(b.label);
    const detected = [...ctx.packRows].filter((r) => r.detected).sort(byLabel);
    const rest = [...ctx.packRows].filter((r) => !r.detected).sort(byLabel);
    const detectedRows = detected.map((row) => this._buildPackRow(row, true, ctx.shedRuleNames)).join('\n');
    const detectedEmpty = `<tr class="packs-none"><td colspan="6" class="hint">${escapeHtml(l10n('packs.noneDetected'))}</td></tr>`;
    const detectedCount = packsAndRulesLabel(detected.length, sumPackRules(detected));
    const restCount = packsAndRulesLabel(rest.length, sumPackRules(rest));
    return `<details class="section expander" aria-label="${escapeHtml(l10n('packs.forYourProject'))}" open>
  <summary><span class="expander-title">${escapeHtml(l10n('packs.forYourProject'))}</span> <span class="muted">(${detectedCount})</span></summary>
  <p class="hint">${escapeHtml(l10n('packs.forYourProjectHint'))}</p>
  <div class="dash-table-wrap">
    <table class="dash-table packs" id="packs-table-detected">
      ${this._packTableHead()}
      <tbody id="packs-tbody-detected" class="packs-tbody">${detected.length > 0 ? detectedRows : detectedEmpty}</tbody>
    </table>
  </div>
</details>
<details class="section expander" aria-label="${escapeHtml(l10n('packs.allPackages'))}">
  <summary><span class="expander-title">${escapeHtml(l10n('packs.allPackages'))}</span> <span class="muted">(${restCount})</span></summary>
  <p class="hint">${escapeHtml(l10n('packs.allPackagesHint'))}</p>
  ${this._buildPackDomainGroups(rest, ctx.shedRuleNames)}
</details>`;
  }

  /**
   * Render the non-detected packs grouped by editorial domain (State management,
   * Networking, Storage, …). Each domain is its own collapsed sub-accordion so a
   * user scanning by problem area (e.g. "what storage rules exist?") opens one
   * group instead of reading all ~80 rows. Domains follow {@link PACK_DOMAIN_ORDER};
   * empty domains are skipped. Each sub-table reuses the shared `.packs-tbody`
   * class so the existing filter/sort logic spans every group.
   */
  private _buildPackDomainGroups(rows: readonly PackChartRow[], shedRuleNames: ReadonlySet<string>): string {
    const byDomain = new Map<string, PackChartRow[]>();
    for (const row of rows) {
      const domain = packDomainForId(row.id);
      const list = byDomain.get(domain);
      if (list) {
        list.push(row);
      } else {
        byDomain.set(domain, [row]);
      }
    }
    // Render in the curated order; any domain not in the order list (defensive)
    // is appended alphabetically so a stray group is never silently dropped.
    const ordered = [...byDomain.keys()].sort((a, b) => {
      const ia = PACK_DOMAIN_ORDER.indexOf(a);
      const ib = PACK_DOMAIN_ORDER.indexOf(b);
      if (ia !== -1 && ib !== -1) return ia - ib;
      if (ia !== -1) return -1;
      if (ib !== -1) return 1;
      return a.localeCompare(b);
    });
    return ordered
      .map((domain) => this._buildPackDomainGroup(domain, byDomain.get(domain)!, shedRuleNames))
      .join('\n');
  }

  /** One domain sub-accordion: a collapsed table of that domain's packs. */
  private _buildPackDomainGroup(domain: string, rows: PackChartRow[], shedRuleNames: ReadonlySet<string>): string {
    const slug = domain.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    const body = rows.map((row) => this._buildPackRow(row, false, shedRuleNames)).join('\n');
    const rawDesc = l10n('packs.domainDesc.' + slug, undefined, { fallback: '' });
    const descHtml = rawDesc ? `<p class="hint domain-desc">${escapeHtml(rawDesc)}</p>` : '';
    return `<details class="domain-group">
  <summary><span class="domain-title">${escapeHtml(domain)}</span> <span class="muted">(${packsAndRulesLabel(rows.length, sumPackRules(rows))})</span></summary>
  ${descHtml}
  <div class="dash-table-wrap">
    <table class="dash-table packs" id="packs-table-${slug}">
      ${this._packTableHead()}
      <tbody id="packs-tbody-${slug}" class="packs-tbody">${body}</tbody>
    </table>
  </div>
</details>`;
  }

  /** Shared column header row for both pack tables (detected / all). */
  private _packTableHead(): string {
    return `<thead>
        <tr>
          <th class="sortable" data-sort="detected" aria-sort="none" title="Recommended for this project: the pack's dependency or SDK gate is satisfied by your pubspec, so its rules apply to code you actually ship. Sort to bring recommended packs together.">Recommended <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="label" aria-sort="ascending" title="The pub package or Dart/Flutter SDK version this rule pack targets. Default sort. Click to reverse.">Pack <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="type" aria-sort="none" title="SDK = Dart/Flutter version-migration rules; Package = rules for a pub dependency.">Type <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="risk" aria-sort="none" title="Breaking = the API was removed in that version; Deprecation = still works but scheduled for removal. Blank for non-migration packs.">Risk <span class="arrow">▲</span></th>
          <th class="sortable" data-sort="enabled" aria-sort="none" title="Whether this pack is currently switched on in analysis_options.yaml.">Enabled <span class="arrow">▲</span></th>
          <th class="sortable num" data-sort="rules" aria-sort="none" title="How many lint rules this pack adds when enabled. Click a count to list and open each rule.">Rules <span class="arrow">▲</span></th>
        </tr>
      </thead>`;
  }

  /**
   * One table row.
   *
   * §14.12 fix: each "is this applicable?" signal lives in exactly one column. The methodology
   * (gate package + version constraint) goes into the `title` of the *In pubspec* cell, not as a
   * second visible footnote on the row.
   */
  private _buildPackRow(row: PackChartRow, showDomain = false, shedRuleNames?: ReadonlySet<string>): string {
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
    const label = escapeHtml(def.label);
    // In the flat "For your project" table, append the domain so each detected
    // pack still shows its problem area (the domain accordions carry it in the
    // header instead, so it would be redundant there).
    const domainTag = showDomain
      ? ` <span class="pack-domain">${escapeHtml(packDomainForId(row.id))}</span>`
      : '';
    // Inline disclosure: clicking the toggle reveals the detail row below (built
    // from def.ruleCodes) instead of opening a separate quick-pick popup, so the
    // rule list stays in context and each rule is a clickable link to its doc.
    // Mark rules currently shed under memory pressure with a visual badge so the
    // user sees exactly which rules in this pack are temporarily inactive.
    const ruleLinks = def.ruleCodes
      .map((code) => {
        const esc = escapeHtml(code);
        const isShed = shedRuleNames?.has(code) ?? false;
        const shedClass = isShed ? ' shed' : '';
        const shedBadge = isShed
          ? ` <span class="shed-badge" title="${escapeHtml(l10n('memoryPressure.dashboard.shedBadgeTooltip'))}">${escapeHtml(l10n('memoryPressure.dashboard.shedBadge'))}</span>`
          : '';
        return `<a href="#" class="rule-link${shedClass}" data-rule="${esc}" title="Open the explanation for ${esc}.">${esc}${shedBadge}</a>`;
      })
      .join('');
    // Merged Rules column (§ feedback 2026-06-23): the count IS the disclosure
    // control — a single "N rules" link toggles the detail row, replacing the old
    // separate "Rules" number cell + "View" button. One column, one click target.
    const ruleWord = row.rules === 1 ? 'rule' : 'rules';
    const toggle = `<button type="button" class="rules-toggle" data-pack="${id}" aria-expanded="false" aria-label="Show the ${row.rules} ${ruleWord} in ${label}" title="List and open the ${row.rules} ${ruleWord} in this pack."><span class="rules-count">${row.rules}</span> ${ruleWord} <span class="chev">▸</span></button>`;
    const detailRow = `<tr class="rules-detail" data-detail-for="${id}" hidden><td colspan="6"><div class="rules-detail-body">${ruleLinks}</div></td></tr>`;
    // data-rules-text + data-domain make individual rule codes and the pack's
    // problem area searchable, so typing a rule name (e.g. "avoid_print") surfaces
    // the pack that owns it — packs were previously findable only by their label.
    const rulesText = escapeHtml(def.ruleCodes.join(' ').toLowerCase());
    const domainLower = escapeHtml(packDomainForId(row.id).toLowerCase());
    // Version-group membership: dio+dio_5, riverpod+riverpod_2+riverpod_3, …
    // share one dependency and are mutually exclusive — only one version of a
    // package's rules can apply. `data-vgroup` ties the row + its toggle to its
    // siblings so the client clears the others when this one is enabled, and a
    // "pick one version" tag tells the user the choice is exclusive. The written
    // config is also de-duplicated server-side (see _handleToggle), so the
    // single-version contract holds even if the UI is out of sync.
    const vgroup = VERSION_GROUP_INDEX.get(row.id);
    const vgroupAttr = vgroup ? ` data-vgroup="${escapeHtml(vgroup)}"` : '';
    const vgroupTag = vgroup
      ? ` <span class="pack-vgroup" title="${escapeHtml(l10n('packs.versionGroup.tooltip'))}">${escapeHtml(l10n('packs.versionGroup.tag'))}</span>`
      : '';
    return `<tr data-pack="${id}"${vgroupAttr} data-type="${isSdk ? 'sdk' : 'package'}" data-risk="${riskKind}" data-detected="${row.detected ? '1' : '0'}" data-enabled="${row.enabled ? '1' : '0'}" data-rules="${row.rules}" data-label="${escapeHtml(def.label.toLowerCase())}" data-pack-label="${label}" data-rules-text="${rulesText}" data-domain="${domainLower}">
  ${detectedCell}
  <td class="pack-name">${label}${domainTag}${vgroupTag}</td>
  <td>${typeBadge}</td>
  <td>${riskBadge}</td>
  <td><label class="switch"><input type="checkbox" data-pack="${id}"${vgroupAttr} ${row.enabled ? 'checked' : ''} aria-label="Enable ${label}" /><span class="slider"></span></label></td>
  <td class="num rules-cell">${toggle}</td>
</tr>
${detailRow}`;
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

  /**
   * Shed rules section: rules temporarily disabled by the memory pressure handler.
   * Grouped by shed category (type-resolving, high-cost, INFO severity, WARNING
   * severity) so the user understands why each rule was shed and at which pressure
   * level it returns. Hidden when no rules are shed (shedLevel === 0).
   */
  private _buildShedRulesSection(ctx: DashboardContext): string {
    if (ctx.shedRuleCount === 0) return '';
    const summary = `<summary><span class="expander-title">${escapeHtml(l10n('memoryPressure.dashboard.shedSectionTitle'))}</span> <span class="muted">(${ctx.shedRuleCount})</span></summary>`;
    // Category display order matches escalation: expensive first, then severity.
    const categoryOrder: Array<{ key: string; labelKey: string }> = [
      { key: 'typeResolving', labelKey: 'memoryPressure.dashboard.categoryTypeResolving' },
      { key: 'highCost', labelKey: 'memoryPressure.dashboard.categoryHighCost' },
      { key: 'infoSeverity', labelKey: 'memoryPressure.dashboard.categoryInfoSeverity' },
      { key: 'warningSeverity', labelKey: 'memoryPressure.dashboard.categoryWarningSeverity' },
    ];
    const groupHtml = categoryOrder
      .filter(({ key }) => ctx.shedByCategory.has(key) || (ctx.shedCategoryTotals.get(key) ?? 0) > 0)
      .map(({ key, labelKey }) => {
        const rules = ctx.shedByCategory.get(key) ?? [];
        const total = ctx.shedCategoryTotals.get(key) ?? rules.length;
        const rows = rules
          .map((rule) => {
            const esc = escapeHtml(rule);
            return `<li class="shed-rule-row"><a href="#" class="rule-link" data-rule="${esc}" title="Open the explanation for ${esc}.">${esc}</a></li>`;
          })
          .join('\n');
        // When the rule name array is capped (getShedDetails caps at 20
        // per category) but the total is higher, show a "+N more" hint
        // so the count stays accurate and the user isn't misled.
        const overflow = total - rules.length;
        const overflowHint = overflow > 0
          ? `\n<li class="shed-rule-row muted">+${overflow} ${escapeHtml(l10n('memoryPressure.dashboard.moreRules'))}</li>`
          : '';
        return `<div class="shed-rules-group">
  <h4 class="shed-rules-group-heading">${escapeHtml(l10n(labelKey))} <span class="muted">(${total})</span></h4>
  <ul class="shed-rules-list">${rows}${overflowHint}</ul>
</div>`;
      })
      .join('\n');
    // Restart button lets the user clear shedding by restarting the analyzer —
    // RSS resets on restart, so shedding de-escalates to level 0 if the project
    // fits in memory on a fresh start. Uses the existing 'command' message type.
    const restartBtn = `<button type="button" class="btn tier-2" data-command="restartAnalyzer" title="${escapeHtml(l10n('memoryPressure.dashboard.restartTooltip'))}">${escapeHtml(l10n('memoryPressure.dashboard.restartButton'))}</button>`;
    return `<details class="section expander shed-rules" aria-label="${escapeHtml(l10n('memoryPressure.dashboard.shedSectionTitle'))}" open>
  ${summary}
  <p class="hint">${escapeHtml(l10n('memoryPressure.dashboard.shedHint'))} ${restartBtn}</p>
  ${groupHtml}
</details>`;
  }

  /**
   * Style & opinions section: the opt-in stylistic rules grouped by concept.
   *
   * Collapsed by default and placed below the ecosystem packs because these are
   * pure preferences, not correctness or migration rules — they should never be
   * the first thing a user reorganizes. Conflicting groups render as pick-one
   * radios so two contradictory rules can never be enabled at once; the rest are
   * independent toggles.
   */
  private _buildStylisticSection(ctx: DashboardContext): string {
    const total = STYLISTIC_PACK_DEFINITIONS.reduce((n, p) => n + p.ruleCodes.length, 0);
    let enabledCount = 0;
    for (const pack of STYLISTIC_PACK_DEFINITIONS) {
      for (const code of pack.ruleCodes) {
        if (ctx.enabledStylistic.has(code)) enabledCount++;
      }
    }
    const summary = `<summary><span class="expander-title">${escapeHtml(l10n('stylistic.title'))}</span> <span class="muted">(${enabledCount}/${total})</span></summary>`;
    const groups = STYLISTIC_PACK_DEFINITIONS.map((pack) =>
      this._buildStylisticGroup(pack, ctx.enabledStylistic),
    ).join('\n');
    return `<details class="section expander stylistic" aria-label="${escapeHtml(l10n('stylistic.title'))}">
  ${summary}
  <p class="hint">${escapeHtml(l10n('stylistic.intro'))}</p>
  <div class="stylistic-toolbar">
    <input type="search" id="stylistic-search" class="stylistic-search" placeholder="${escapeHtml(l10n('stylistic.searchPlaceholder'))}" aria-label="${escapeHtml(l10n('stylistic.searchPlaceholder'))}" autocomplete="off" spellcheck="false" />
    <span class="muted stylistic-empty-hint" id="stylistic-empty-hint" hidden>${escapeHtml(l10n('stylistic.noMatch'))}</span>
  </div>
  <div class="stylistic-groups">
    ${groups}
  </div>
</details>`;
  }

  /**
   * One stylistic group. `pickOne` groups use a radio set (with a "None" option
   * to clear the choice) so the mutually-exclusive contract is enforced in the
   * UI, not just documented. `multi` groups use independent checkbox toggles
   * plus enable-all / disable-all bulk actions on the group header.
   */
  private _buildStylisticGroup(
    pack: (typeof STYLISTIC_PACK_DEFINITIONS)[number],
    enabled: ReadonlySet<string>,
  ): string {
    const onCount = pack.ruleCodes.filter((c) => enabled.has(c)).length;
    const id = escapeHtml(pack.id);
    const label = escapeHtml(pack.label);
    const countBadge = `<span class="muted">(${onCount}/${pack.ruleCodes.length})</span>`;
    // Description is optional and lives in en.json (translatable); conflicting
    // pick-one pairs are self-evident from their two rule names and have none.
    const rawDesc = l10n('stylistic.desc.' + pack.id, undefined, { fallback: '' });
    const descHtml = rawDesc ? `<p class="stylistic-group-desc">${escapeHtml(rawDesc)}</p>` : '';
    if (pack.selectionMode === 'pickOne') {
      const noneChecked = onCount === 0 ? 'checked' : '';
      const noneRow = `<label class="stylistic-radio-row" data-rule="">
        <input type="radio" name="stylistic-${id}" value="" data-pack="${id}" ${noneChecked} />
        <span class="stylistic-none">${escapeHtml(l10n('stylistic.none'))}</span>
      </label>`;
      const radios = pack.ruleCodes
        .map((code) => {
          const codeEsc = escapeHtml(code);
          const checked = enabled.has(code) ? 'checked' : '';
          return `<label class="stylistic-radio-row" data-rule="${codeEsc}">
        <input type="radio" name="stylistic-${id}" value="${codeEsc}" data-pack="${id}" ${checked} />
        <a href="#" class="rule-link" data-rule="${codeEsc}" title="Open the explanation for ${codeEsc}.">${codeEsc}</a>
      </label>`;
        })
        .join('\n');
      return `<fieldset class="stylistic-group pick-one" data-group="${id}">
    <legend class="stylistic-group-heading">${label} ${countBadge} <span class="pick-one-tag">${escapeHtml(l10n('stylistic.pickOne'))}</span></legend>
    ${descHtml}
    ${noneRow}
    ${radios}
  </fieldset>`;
    }
    const rows = pack.ruleCodes
      .map((code) => {
        const codeEsc = escapeHtml(code);
        const checked = enabled.has(code) ? 'checked' : '';
        return `<li class="stylistic-rule-row" data-rule="${codeEsc}">
      <label class="switch"><input type="checkbox" data-stylistic-rule="${codeEsc}" ${checked} aria-label="Enable ${codeEsc}" /><span class="slider"></span></label>
      <a href="#" class="rule-link" data-rule="${codeEsc}" title="Open the explanation for ${codeEsc}.">${codeEsc}</a>
    </li>`;
      })
      .join('\n');
    return `<div class="stylistic-group multi" data-group="${id}">
    <div class="stylistic-group-heading">${label} ${countBadge}
      <span class="stylistic-bulk">
        <button type="button" class="btn tier-3" data-stylistic-bulk="enable" data-pack="${id}">${escapeHtml(l10n('stylistic.enableAll'))}</button>
        <button type="button" class="btn tier-3" data-stylistic-bulk="disable" data-pack="${id}">${escapeHtml(l10n('stylistic.disableAll'))}</button>
      </span>
    </div>
    ${descHtml}
    <ul class="stylistic-rules-list">${rows}</ul>
  </div>`;
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

  // ---------------------------------------------------------------------------------------------
  // Config file tab — the 8 previously-UI-less `analysis_options_custom.yaml` top-level keys
  // (Phase 4 requirement #1) plus Baseline (create/view) and the embedded Analysis Optimizer
  // (requirement #4). Every control here round-trips through `customConfigYaml.ts`, which edits
  // only the byte range of the one key it owns — see that module's header comment for why a
  // generic YAML library was rejected in favor of this scoped-block approach.
  // ---------------------------------------------------------------------------------------------

  private _buildConfigFileTab(root: string): string {
    // Render strictly from CONFIG_FILE_CARD_IDS (not a hand-ordered literal array of builder
    // calls) so the coverage test's assumption — every CUSTOM_YAML_TOP_LEVEL_KEYS entry maps to
    // an id in this list — is checked against the SAME list that actually renders, not a second
    // copy that could silently drift from it.
    const builders = this._configFileCardBuilders();
    const yamlKeyCards = CONFIG_FILE_CARD_IDS.map((id) => builders[id](root));
    const content = [...yamlKeyCards, this._buildBaselineCard(root), this._buildOptimizerCard()].join('\n');
    return this._tabPanel('configFile', content);
  }

  /** Maps each {@link CONFIG_FILE_CARD_IDS} entry to the instance method that renders it, bound to `this` — see {@link _buildConfigFileTab}'s doc comment for why this indirection exists (coverage-test guarantee) instead of a literal call list. */
  private _configFileCardBuilders(): Record<ConfigFileCardId, (root: string) => string> {
    return {
      analysisSettings: (root) => this._buildAnalysisSettingsCard(root),
      tierCap: (root) => this._buildTierCapCard(root),
      lane: (root) => this._buildLaneCard(root),
      platforms: (root) => this._buildPlatformsCard(root),
      severities: (root) => this._buildSeveritiesCard(root),
      bannedUsage: (root) => this._buildBannedUsageCard(root),
      diagnosticStatistics: (root) => this._buildDiagnosticStatisticsCard(root),
    };
  }

  /** `max_issues:` and `output:` — the two ProgressTracker scalars. */
  private _buildAnalysisSettingsCard(root: string): string {
    const maxIssues = readScalarKey(root, 'max_issues') ?? '500';
    const output = readScalarKey(root, 'output') ?? 'terminal';
    const outputOptions = OUTPUT_MODES.map(
      (mode) => `<option value="${mode}"${mode === output ? ' selected' : ''}>${escapeHtml(mode)}</option>`,
    ).join('');
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.analysisSettings.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.analysisSettings.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.analysisSettings.hint'))}</p>
  <div class="cf-field-row">
    <label class="cf-field">
      <span>${escapeHtml(l10n('rulesTiers.configFile.maxIssues.label'))}</span>
      <input type="number" min="0" step="1" id="cf-max-issues" data-scalar-key="max_issues" value="${escapeHtml(maxIssues)}" title="${escapeHtml(l10n('rulesTiers.configFile.maxIssues.desc'))}" />
    </label>
    <label class="cf-field">
      <span>${escapeHtml(l10n('rulesTiers.configFile.output.label'))}</span>
      <select id="cf-output" data-scalar-key="output" title="${escapeHtml(l10n('rulesTiers.configFile.output.desc'))}">${outputOptions}</select>
    </label>
  </div>
</section>`;
  }

  /** `saropa_tier:` and `runtime_tier:` — the custom.yaml-level tier caps (distinct from the `saropaLints.tier` setting the Tier tab's segmented control writes). */
  private _buildTierCapCard(root: string): string {
    const saropaTier = readScalarKey(root, 'saropa_tier');
    const runtimeTier = readScalarKey(root, 'runtime_tier');
    const buildSelect = (id: string, scalarKey: string, current: string | undefined): string => {
      const noneSelected = current === undefined ? ' selected' : '';
      const options = [
        `<option value=""${noneSelected}>${escapeHtml(l10n('rulesTiers.configFile.tierCap.none'))}</option>`,
        ...CUSTOM_YAML_TIERS.map(
          (t) => `<option value="${t}"${t === current ? ' selected' : ''}>${escapeHtml(t)}</option>`,
        ),
      ].join('');
      return `<select id="${id}" data-scalar-key="${scalarKey}">${options}</select>`;
    };
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.tierCap.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.tierCap.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.tierCap.hint'))}</p>
  <div class="cf-field-row">
    <label class="cf-field"><span>${escapeHtml(l10n('rulesTiers.configFile.saropaTier.label'))}</span>${buildSelect('cf-saropa-tier', 'saropa_tier', saropaTier)}</label>
    <label class="cf-field"><span>${escapeHtml(l10n('rulesTiers.configFile.runtimeTier.label'))}</span>${buildSelect('cf-runtime-tier', 'runtime_tier', runtimeTier)}</label>
  </div>
</section>`;
  }

  /**
   * `lane:` — the in-process analyzer plugin's light/full split
   * (`rule_lane.dart`'s `RuleLane`). This was the sidebar's Lane row before
   * the 2026-09-04 row collapse (plans/PLAN_sidebar_row_collapse.md WP2); it
   * moved here because `lane` is a `analysis_options_custom.yaml` top-level
   * key with no Config file tab card before this change, and the row's click
   * target (`saropaLints.setLane`'s QuickPick) is a worse UI than a persistent
   * select next to every other custom-yaml key.
   *
   * Deliberately reads/writes through `laneConfig.ts`
   * (`readRawLaneFromCustomConfig` / `writeLaneToCustomConfig`), NOT the
   * generic `readScalarKey`/`writeScalarKey` helpers the other scalar cards
   * use — `lane` has a deprecation-fallback read path (the old
   * `plugins > saropa_lints:` block in `analysis_options.yaml`) that the
   * generic helpers do not implement, so routing it through them would silently
   * disagree with what the in-process plugin is actually honoring.
   */
  private _buildLaneCard(root: string): string {
    const raw = readRawLaneFromCustomConfig(root);
    // Absent/unrecognized reads as 'light' — matches the Dart-side default
    // (RuleLane.light), the same fallback the removed sidebar Lane row and
    // the `setLane` QuickPick both use, so this card never disagrees with them.
    const lane: RuleLaneValue = raw === 'full' ? 'full' : 'light';
    const buildOption = (value: RuleLaneValue, label: string): string =>
      `<option value="${value}"${value === lane ? ' selected' : ''}>${escapeHtml(label)}</option>`;
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.lane.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.lane.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.lane.hint'))}</p>
  <div class="cf-field-row">
    <label class="cf-field">
      <select id="cf-lane" data-lane-select>
        ${buildOption('light', l10n('dashboards.controls.laneLight'))}
        ${buildOption('full', l10n('dashboards.controls.laneFull'))}
      </select>
    </label>
  </div>
</section>`;
  }

  /** `platforms:` — one checkbox per Flutter embedder platform. Always saves the full map (see `writePlatforms`'s doc comment for why a partial update is never needed here). */
  private _buildPlatformsCard(root: string): string {
    const platforms = readPlatforms(root);
    const rows = FLUTTER_EMBEDDER_PLATFORMS.map((p) => {
      const on = platforms.get(p) ?? false;
      return `<label class="cf-platform-row"><input type="checkbox" data-platform="${escapeHtml(p)}" ${on ? 'checked' : ''} /> ${escapeHtml(p)}</label>`;
    }).join('');
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.platforms.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.platforms.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.platforms.hint'))}</p>
  <div class="cf-platform-grid">${rows}</div>
</section>`;
  }

  /** `severities:` — a table of rule → override level, add/remove per row (mirrors the Disabled rules table's row shape). */
  private _buildSeveritiesCard(root: string): string {
    const entries = readSeverities(root);
    const rows = entries
      .map((e) => {
        const ruleEsc = escapeHtml(e.rule);
        const levelOptions = ['ERROR', 'WARNING', 'INFO', 'false']
          .map((lvl) => `<option value="${lvl}"${lvl === e.level ? ' selected' : ''}>${escapeHtml(lvl)}</option>`)
          .join('');
        return `<tr data-severity-row="${ruleEsc}">
    <td><code>${ruleEsc}</code></td>
    <td><select class="cf-severity-level" data-rule="${ruleEsc}">${levelOptions}</select></td>
    <td><button type="button" class="btn tier-3" data-remove-severity="${ruleEsc}">${escapeHtml(l10n('rulesTiers.common.remove'))}</button></td>
  </tr>`;
      })
      .join('\n');
    const empty = `<tr><td colspan="3" class="hint">${escapeHtml(l10n('rulesTiers.configFile.severities.empty'))}</td></tr>`;
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.severities.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.severities.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.severities.hint'))}</p>
  <table class="dash-table"><thead><tr><th>${escapeHtml(l10n('rulesTiers.common.rule'))}</th><th>${escapeHtml(l10n('rulesTiers.configFile.severities.level'))}</th><th></th></tr></thead>
    <tbody id="cf-severities-tbody">${entries.length > 0 ? rows : empty}</tbody>
  </table>
  <div class="cf-add-row">
    <input type="text" id="cf-severity-rule" placeholder="${escapeHtml(l10n('rulesTiers.configFile.severities.rulePlaceholder'))}" />
    <select id="cf-severity-new-level" aria-label="${escapeHtml(l10n('rulesTiers.configFile.severities.newLevelAria'))}"><option value="ERROR">ERROR</option><option value="WARNING">WARNING</option><option value="INFO">INFO</option><option value="false">false</option></select>
    <button type="button" class="btn tier-2" id="cf-severity-add">${escapeHtml(l10n('rulesTiers.common.add'))}</button>
  </div>
</section>`;
  }

  /** `banned_usage.entries:` — identifier + reason pairs (e.g. banning `print` in favor of a logger). */
  private _buildBannedUsageCard(root: string): string {
    const entries = readBannedUsage(root);
    const rows = entries
      .map(
        (e) => `<tr data-banned-row="${escapeHtml(e.identifier)}">
    <td><code>${escapeHtml(e.identifier)}</code></td>
    <td>${escapeHtml(e.reason)}</td>
    <td><button type="button" class="btn tier-3" data-remove-banned="${escapeHtml(e.identifier)}">${escapeHtml(l10n('rulesTiers.common.remove'))}</button></td>
  </tr>`,
      )
      .join('\n');
    const empty = `<tr><td colspan="3" class="hint">${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.empty'))}</td></tr>`;
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.hint'))}</p>
  <table class="dash-table"><thead><tr><th>${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.identifier'))}</th><th>${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.reason'))}</th><th></th></tr></thead>
    <tbody id="cf-banned-tbody">${entries.length > 0 ? rows : empty}</tbody>
  </table>
  <div class="cf-add-row">
    <input type="text" id="cf-banned-identifier" placeholder="${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.identifierPlaceholder'))}" />
    <input type="text" id="cf-banned-reason" placeholder="${escapeHtml(l10n('rulesTiers.configFile.bannedUsage.reasonPlaceholder'))}" />
    <button type="button" class="btn tier-2" id="cf-banned-add">${escapeHtml(l10n('rulesTiers.common.add'))}</button>
  </div>
</section>`;
  }

  /** `diagnostic_statistics.thresholds:` — per-rule warn/fail counts (CI-style budget gates). */
  private _buildDiagnosticStatisticsCard(root: string): string {
    const thresholds = readDiagnosticThresholds(root);
    const rows = thresholds
      .map((t) => {
        const ruleEsc = escapeHtml(t.rule);
        return `<tr data-threshold-row="${ruleEsc}">
    <td><code>${ruleEsc}</code></td>
    <td>${t.warn ?? ''}</td>
    <td>${t.fail ?? ''}</td>
    <td><button type="button" class="btn tier-3" data-remove-threshold="${ruleEsc}">${escapeHtml(l10n('rulesTiers.common.remove'))}</button></td>
  </tr>`;
      })
      .join('\n');
    const empty = `<tr><td colspan="4" class="hint">${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.empty'))}</td></tr>`;
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.hint'))}</p>
  <table class="dash-table"><thead><tr><th>${escapeHtml(l10n('rulesTiers.common.rule'))}</th><th>${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.warn'))}</th><th>${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.fail'))}</th><th></th></tr></thead>
    <tbody id="cf-thresholds-tbody">${thresholds.length > 0 ? rows : empty}</tbody>
  </table>
  <div class="cf-add-row">
    <input type="text" id="cf-threshold-rule" placeholder="${escapeHtml(l10n('rulesTiers.configFile.severities.rulePlaceholder'))}" />
    <input type="number" min="0" id="cf-threshold-warn" placeholder="${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.warn'))}" />
    <input type="number" min="0" id="cf-threshold-fail" placeholder="${escapeHtml(l10n('rulesTiers.configFile.diagnosticStats.fail'))}" />
    <button type="button" class="btn tier-2" id="cf-threshold-add">${escapeHtml(l10n('rulesTiers.common.add'))}</button>
  </div>
</section>`;
  }

  /**
   * Baseline: create/refresh (delegates to the existing `saropaLints.createBaseline` command,
   * which both writes `saropa_baseline.json` AND the config block that activates it — see
   * `baselineReader.ts`'s header comment for why there is no separate "apply" step) and a summary
   * table of the current file's contents.
   */
  private _buildBaselineCard(root: string): string {
    const summary = readBaselineSummary(root);
    const actions = `<div class="toolbar-row" style="gap:6px;">
    <button class="btn tier-1" data-command="createBaseline" title="${escapeHtml(l10n('rulesTiers.configFile.baseline.createTitle'))}">${escapeHtml(l10n('rulesTiers.configFile.baseline.createButton'))}</button>
    ${summary ? `<button class="btn" data-command="openBaselineFile" title="${escapeHtml(l10n('rulesTiers.configFile.baseline.openTitle'))}">${escapeHtml(l10n('rulesTiers.configFile.baseline.openButton'))}</button>` : ''}
  </div>`;
    if (!summary) {
      return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.baseline.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.baseline.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.baseline.emptyHint'))}</p>
  ${actions}
</section>`;
    }
    const generated = summary.generated ? formatRelativeFreshness(summary.generated) : l10n('rulesTiers.configFile.baseline.unknownDate');
    const ruleRows = summary.topRules
      .map((r) => `<tr><td><code>${escapeHtml(r.rule)}</code></td><td class="num">${r.count}</td></tr>`)
      .join('');
    return `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.configFile.baseline.title'))}">
  <h3>${escapeHtml(l10n('rulesTiers.configFile.baseline.title'))}</h3>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.baseline.hint'))}</p>
  <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.baseline.summary', {
    files: String(summary.fileCount),
    violations: String(summary.totalViolations),
    generated,
  }))}</p>
  ${actions}
  <table class="dash-table"><thead><tr><th>${escapeHtml(l10n('rulesTiers.common.rule'))}</th><th>${escapeHtml(l10n('rulesTiers.configFile.baseline.count'))}</th></tr></thead>
    <tbody>${ruleRows}</tbody>
  </table>
  ${this._buildBaselineDiffHtml(root)}
</section>`;
  }

  /**
   * Deferred Phase 4 item: diffs the baseline file against the CURRENT live violation set
   * (read from `vscode.languages.getDiagnostics()` — the same in-memory source the Findings
   * dashboard already uses, so this never triggers a scan) and renders the result as its own
   * subsection under the Baseline card's summary table.
   *
   * Only called from the `summary` (non-empty) branch of {@link _buildBaselineCard} — with no
   * baseline file there is nothing to diff against, and that branch already shows the
   * "no baseline yet" empty hint, so a second empty state here would be redundant noise.
   */
  private _buildBaselineDiffHtml(root: string): string {
    // Bare diagnostic read — deliberately skips `readLiveViolations`'s rule-catalog enrichment
    // and tier resolution, which the diff (file/rule/line only) does not need.
    const live = buildViolationsDataFromDiagnostics(root);
    const diff = computeBaselineDiff(root, live.violations);
    if (!diff) return '';

    const countsLine = `<p class="hint">${escapeHtml(
      l10n('rulesTiers.configFile.baseline.diff.counts', {
        resolved: String(diff.resolvedCount),
        new: String(diff.newCount),
      }),
    )}</p>`;

    if (diff.resolvedCount === 0 && diff.newCount === 0) {
      return `<div class="baseline-diff">
    <h4>${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.title'))}</h4>
    <p class="hint">${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.empty'))}</p>
  </div>`;
    }

    return `<div class="baseline-diff">
    <h4>${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.title'))}</h4>
    ${countsLine}
    ${this._buildBaselineDiffTable('resolved', diff.resolved, diff.resolvedCount)}
    ${this._buildBaselineDiffTable('new', diff.newSince, diff.newCount)}
  </div>`;
  }

  /**
   * One diff bucket's table (resolved OR new-since). `kind` picks the section header/empty-state
   * copy; the row shape (file/line/rule) is identical for both buckets, so the table markup
   * itself is shared rather than duplicated per kind.
   */
  private _buildBaselineDiffTable(
    kind: 'resolved' | 'new',
    entries: readonly { file: string; rule: string; line: number }[],
    trueCount: number,
  ): string {
    const titleKey = kind === 'resolved' ? 'rulesTiers.configFile.baseline.diff.resolvedSection' : 'rulesTiers.configFile.baseline.diff.newSection';
    // Zero-count bucket: a flat line, not a collapsible `<details>` with an empty table —
    // there is nothing to expand into.
    if (trueCount === 0) {
      return `<p class="hint">${escapeHtml(l10n(titleKey, { count: '0' }))}</p>`;
    }
    const rows = entries
      .map(
        (e) => `<tr><td><code>${escapeHtml(e.file)}</code></td><td class="num">${e.line}</td><td><code>${escapeHtml(e.rule)}</code></td></tr>`,
      )
      .join('');
    // The reader caps each bucket at MAX_DIFF_ROWS (baselineReader.ts) — when the true count
    // exceeds what's rendered, say so rather than silently truncating.
    const moreNote =
      trueCount > entries.length
        ? `<p class="hint">${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.moreRows', { count: String(trueCount - entries.length) }))}</p>`
        : '';
    return `<details class="section expander">
    <summary><span class="expander-title">${escapeHtml(l10n(titleKey, { count: String(trueCount) }))}</span></summary>
    <table class="dash-table"><thead><tr>
      <th>${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.fileCol'))}</th>
      <th>${escapeHtml(l10n('rulesTiers.configFile.baseline.diff.lineCol'))}</th>
      <th>${escapeHtml(l10n('rulesTiers.common.rule'))}</th>
    </tr></thead>
      <tbody>${rows}</tbody>
    </table>
    ${moreNote}
  </details>`;
  }

  /** Embeds the Analysis Optimizer's live body (Phase 4 requirement #4 — its standalone command remains a working deep link; this is the SAME render logic, not a copy). */
  private _buildOptimizerCard(): string {
    const inner = this._analysisOptimizerProvider
      ? this._analysisOptimizerProvider.getEmbeddedBodyHtml()
      : `<p class="hint">${escapeHtml(l10n('rulesTiers.configFile.optimizer.unavailable'))}</p>`;
    return `<section class="section optimizer-embed" aria-label="${escapeHtml(l10n('analysisOptimizer.title'))}">
  <h3>${escapeHtml(l10n('analysisOptimizer.title'))} <button type="button" class="btn tier-3" data-command="openOptimizerPanel" title="${escapeHtml(l10n('rulesTiers.configFile.optimizer.openStandaloneTitle'))}">${escapeHtml(l10n('rulesTiers.configFile.optimizer.openStandalone'))}</button></h3>
  <div class="optimizer-embed-body">${inner}</div>
</section>`;
  }

  // ---------------------------------------------------------------------------------------------
  // Automation + Extension tabs — the generic `saropaLints.*` settings grid (Phase 4 requirement
  // #2). Schema-driven from `buildSettingsCatalog()` (reads the manifest directly — see
  // `settingsCatalog.ts`'s header comment) so a setting added to `package.json` appears here with
  // ZERO changes to this file; only the manifest-key EXCLUSION list is hand-maintained.
  // ---------------------------------------------------------------------------------------------

  private _buildAutomationTab(): string {
    const rows = buildSettingsCatalog().filter((e) => e.tab === 'automation').map((e) => this._buildSettingRow(e)).join('\n');
    const content = `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.tab.automation'))}">
  <p class="hint">${escapeHtml(l10n('rulesTiers.automation.hint'))}</p>
  <table class="dash-table settings-table"><tbody>${rows}</tbody></table>
</section>`;
    return this._tabPanel('automation', content);
  }

  private _buildExtensionTab(ctx?: DashboardContext): string {
    const rows = buildSettingsCatalog().filter((e) => e.tab === 'extension').map((e) => this._buildSettingRow(e)).join('\n');
    const parts = [
      `<section class="section" aria-label="${escapeHtml(l10n('rulesTiers.tab.extension'))}">
  <p class="hint">${escapeHtml(l10n('rulesTiers.extension.hint'))}</p>
  <table class="dash-table settings-table"><tbody>${rows}</tbody></table>
  <p class="hint">${escapeHtml(l10n('rulesTiers.extension.linkNote'))}</p>
</section>`,
    ];
    // The pubspec-detected platform reference table + suppressions snapshot + doc links used to
    // sit in a catch-all "Diagnostics" band at the bottom of the single-page dashboard; the
    // Extension tab is their new home as general reference content about this installation.
    if (ctx) parts.push(this._buildDiagnostics(ctx));
    return this._tabPanel('extension', parts.join('\n'));
  }

  /**
   * One settings-grid row for a single catalog entry. Reads the CURRENT value from VS Code
   * configuration on every render, so the grid never drifts from a change made elsewhere
   * (Settings UI, settings.json, another dashboard). Label and description come straight from
   * the manifest entry (see `settingsCatalog.ts`) rather than `l10n()` — see that module's header
   * comment for why: they are derived from `package.json`/`package.nls.json`, which is already
   * the single authored copy of that text.
   */
  private _buildSettingRow(entry: SettingCatalogEntry): string {
    const cfg = vscode.workspace.getConfiguration('saropaLints');
    const flat = flatSettingKey(entry.key);
    const label = escapeHtml(entry.label);
    const desc = escapeHtml(entry.description);
    let control: string;
    if (entry.kind === 'boolean') {
      const value = cfg.get<boolean>(entry.key) ?? false;
      control = `<label class="switch"><input type="checkbox" data-setting-key="${escapeHtml(entry.key)}" ${value ? 'checked' : ''} aria-label="${label}" /><span class="slider"></span></label>`;
    } else if (entry.kind === 'number') {
      const value = cfg.get<number>(entry.key) ?? 0;
      control = `<input type="number" data-setting-key="${escapeHtml(entry.key)}" value="${value}" class="cf-number-input" />`;
    } else if (entry.kind === 'select') {
      const value = cfg.get<string>(entry.key) ?? '';
      const options = (entry.options ?? [])
        .map((o) => `<option value="${escapeHtml(o)}"${o === value ? ' selected' : ''}>${escapeHtml(o)}</option>`)
        .join('');
      control = `<select data-setting-key="${escapeHtml(entry.key)}">${options}</select>`;
    } else if (entry.kind === 'stringArray') {
      // Rendered as a comma-separated text field — simplest control that round-trips an array
      // setting without a bespoke multi-value widget.
      const value = (cfg.get<string[]>(entry.key) ?? []).join(', ');
      control = `<input type="text" data-setting-key="${escapeHtml(entry.key)}" data-setting-array="1" value="${escapeHtml(value)}" class="cf-array-input" />`;
    } else {
      // 'text': a free-form string setting with no enum — none of today's in-scope settings hit
      // this branch, but a future one (e.g. a new free-text preference) renders correctly without
      // needing this file touched, per the schema-driven design.
      const value = cfg.get<string>(entry.key) ?? '';
      control = `<input type="text" data-setting-key="${escapeHtml(entry.key)}" value="${escapeHtml(value)}" class="cf-array-input" />`;
    }
    return `<tr id="setting-row-${escapeHtml(flat)}"><td class="settings-label" title="${desc}">${label}</td><td class="settings-control">${control}</td></tr>`;
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
    // Append the overlay's own script so the '?' button/keydown wiring runs alongside the rest
    // of the dashboard's client script under the SAME nonce (a second <script> tag would need its
    // own nonce authorization and CSP only lists one).
    const script = scripts
      ? `<script nonce="${nonce}">${getConfigDashboardScript()}${getKeyboardShortcutsScript()}</script>`
      : '';
    // lang="en": the Phase 7 UX-harness sweep flagged the missing attribute as a serious a11y
    // violation (html-has-lang) — screen readers fall back to the OS locale's pronunciation rules
    // without it. All of this dashboard's static chrome/labels are English; per-string translation
    // happens through l10n() but the document's declared language is unaffected by that (matches
    // the convention already used by the other dashboard shells in this codebase).
    return `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Saropa Lints Config</title><meta http-equiv="Content-Security-Policy" content="${csp}">
<style nonce="${nonce}">${getConfigDashboardStyles()}${getKeyboardShortcutsStyles()}</style></head><body>${body}${script}</body></html>`;
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
    // Version groups are mutually exclusive: enabling one variant (e.g. dio_5)
    // drops the package's other variants so rule_packs.enabled never carries two
    // versions of the same dependency. Enforced here, not only in the UI, so a
    // stale config or an out-of-sync client cannot leave both enabled.
    const deduped = enabled
      ? enforceSingleVersion(RULE_PACK_DEFINITIONS, [...next], packId)
      : [...next];
    const ok = writeRulePacksEnabled(
      root,
      deduped.sort((a, b) => a.localeCompare(b)),
    );
    if (!ok) {
      void vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotWriteRulePacks'));
      return;
    }
    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
    this.refresh();
  }

  /** Snake_case lint-id guard for rule names arriving over untrusted postMessage. */
  private _isValidRuleName(rule: string): boolean {
    return /^[a-z][a-z0-9_]*$/.test(rule);
  }

  /** Re-run analysis after a config write unless the user opted out. */
  private async _runAnalysisIfEnabled(): Promise<void> {
    const run = vscode.workspace.getConfiguration('saropaLints').get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
  }

  /**
   * Toggle one stylistic rule. Enabling writes an explicit `rule: true` override;
   * disabling removes the override so the rule returns to its off-by-default state
   * rather than being pinned to `false` (which would clutter the overrides file).
   */
  private async _handleToggleRule(rule: string, enabled: boolean): Promise<void> {
    const root = getProjectRoot();
    if (!root || !this._isValidRuleName(rule)) return;
    if (enabled) {
      writeRuleOverrides(root, [{ rule, enabled: true }]);
    } else {
      removeRuleOverrides(root, [rule]);
    }
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /**
   * Apply a pick-one stylistic group choice. The chosen rule (if any) is enabled
   * and every other rule in the same group is cleared, so the mutually-exclusive
   * contract holds in the written config and not only in the radio UI. An empty
   * `rule` clears the whole group.
   */
  private async _handleSelectStylistic(packId: string, rule: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const pack = STYLISTIC_PACK_DEFINITIONS.find((p) => p.id === packId);
    if (!pack) return;
    if (rule !== '' && !this._isValidRuleName(rule)) return;
    // Reject a rule that does not belong to this group — the id pair arrives over
    // untrusted postMessage and must not let one group write another's rules.
    if (rule !== '' && !pack.ruleCodes.includes(rule)) return;
    const toClear = pack.ruleCodes.filter((c) => c !== rule);
    removeRuleOverrides(root, toClear);
    if (rule !== '') {
      writeRuleOverrides(root, [{ rule, enabled: true }]);
    }
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /**
   * Enable-all / disable-all for a multi-select stylistic group. Enabling pins
   * every rule in the group to `true`; disabling removes the overrides so they
   * fall back to off. Only the named group's own rules are written.
   */
  private async _handleStylisticBulk(packId: string, enabled: boolean): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const pack = STYLISTIC_PACK_DEFINITIONS.find((p) => p.id === packId && p.selectionMode === 'multi');
    if (!pack) return;
    if (enabled) {
      writeRuleOverrides(root, pack.ruleCodes.map((rule) => ({ rule, enabled: true })));
    } else {
      removeRuleOverrides(root, [...pack.ruleCodes]);
    }
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /**
   * Writes one `saropaLints.*` setting from the Automation/Extension tabs' generic grid. `key` is
   * validated against the LIVE manifest-derived catalog (not a cached list) before the write —
   * `findSettingEntry` rebuilds the catalog on every call (see `settingsCatalog.ts`), so a key
   * that has been removed from the manifest (or was never a real setting) is rejected even if a
   * stale webview somehow still has it in its DOM.
   *
   * `ConfigurationTarget.Workspace`: matches `_handleSetTier`'s choice elsewhere in this file — a
   * lint configuration preference is a project decision, not a personal one, so it belongs in
   * `.vscode/settings.json` (committed) rather than the user's global settings.
   */
  private async _handleUpdateSetting(key: string, value: unknown): Promise<void> {
    const entry = findSettingEntry(key);
    if (!entry) return;
    let coerced: unknown = value;
    if (entry.kind === 'stringArray' && typeof value === 'string') {
      // The grid posts the comma-separated text field's raw string; split/trim/drop-empty here so
      // "lib, bin,  test" and "lib,bin,test" both round-trip to the same array.
      coerced = value
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    } else if (entry.kind === 'number' && typeof value === 'string') {
      const n = Number(value);
      if (Number.isNaN(n)) return;
      coerced = n;
    }
    await vscode.workspace.getConfiguration('saropaLints').update(key, coerced, vscode.ConfigurationTarget.Workspace);
    this.refresh();
  }

  /** Config file tab: `max_issues` / `output` / `saropa_tier` / `runtime_tier` scalars. `scalarKey` is checked against the fixed key set the UI can post — it is never taken from arbitrary postMessage text. */
  private async _handleWriteScalar(scalarKey: string, value: string | undefined): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const allowed = new Set(['max_issues', 'output', 'saropa_tier', 'runtime_tier']);
    if (!allowed.has(scalarKey)) return;
    // An empty string from a "None" select option means "remove the key", matching the tier-cap
    // selects' `<option value="">` sentinel built in `_buildTierCapCard`.
    writeScalarKey(root, scalarKey, value === '' ? undefined : value);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /**
   * Config file tab: `lane` scalar. Routes through `writeLaneToCustomConfig`
   * (not `writeScalarKey`) because `lane` has deprecation-fallback read
   * semantics the generic helper does not implement — see `_buildLaneCard`'s
   * doc comment. Only `'light'`/`'full'` are accepted; anything else arriving
   * from the untrusted postMessage channel is silently dropped rather than
   * written, same defensive posture as `_handleWritePlatforms`'s known-name check.
   */
  private async _handleWriteLane(value: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    if (value !== 'light' && value !== 'full') return;
    writeLaneToCustomConfig(root, value);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: rewrites the whole `platforms:` map from the checkbox grid's current state. */
  private async _handleWritePlatforms(platforms: Record<string, boolean>): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    // Only accept known platform names — postMessage is untrusted and this writes a YAML block.
    const known = new Set<string>(FLUTTER_EMBEDDER_PLATFORMS);
    const map = new Map<string, boolean>();
    for (const [name, on] of Object.entries(platforms)) {
      if (known.has(name)) map.set(name, Boolean(on));
    }
    writePlatforms(root, map);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: sets one `severities:` override. `level` is validated against the fixed enum before reaching the yaml writer. */
  private async _handleWriteSeverity(rule: string, level: string): Promise<void> {
    const root = getProjectRoot();
    if (!root || !this._isValidRuleName(rule)) return;
    if (level !== 'ERROR' && level !== 'WARNING' && level !== 'INFO' && level !== 'false') return;
    writeSeverityEntry(root, rule, level as SeverityLevel);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: removes one `severities:` override. */
  private async _handleRemoveSeverity(rule: string): Promise<void> {
    const root = getProjectRoot();
    if (!root || !this._isValidRuleName(rule)) return;
    removeSeverityEntry(root, rule);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: appends one `banned_usage.entries` item. Identifier shape mirrors the Dart parser's expectation (`^\S+$`, matched loosely as "no whitespace") rather than the stricter lint-id pattern, since a banned identifier can be a class or member name, not only a rule name. */
  private async _handleAddBannedUsage(identifier: string, reason: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const trimmedId = identifier.trim();
    if (trimmedId.length === 0 || /\s/.test(trimmedId)) return;
    const current = readBannedUsage(root);
    const next = [...current.filter((e) => e.identifier !== trimmedId), { identifier: trimmedId, reason: reason.trim() }];
    writeBannedUsage(root, next);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: removes one `banned_usage.entries` item by identifier. */
  private async _handleRemoveBannedUsage(identifier: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const current = readBannedUsage(root).filter((e) => e.identifier !== identifier);
    writeBannedUsage(root, current);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: sets one `diagnostic_statistics.thresholds` entry's warn/fail counts. */
  private async _handleSetDiagnosticThreshold(rule: string, warn: number | undefined, fail: number | undefined): Promise<void> {
    const root = getProjectRoot();
    if (!root || !this._isValidRuleName(rule)) return;
    const current = readDiagnosticThresholds(root).filter((t) => t.rule !== rule);
    const entry: DiagnosticThreshold = { rule };
    if (typeof warn === 'number' && Number.isFinite(warn)) entry.warn = warn;
    if (typeof fail === 'number' && Number.isFinite(fail)) entry.fail = fail;
    writeDiagnosticThresholds(root, [...current, entry]);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /** Config file tab: removes one `diagnostic_statistics.thresholds` entry. */
  private async _handleRemoveDiagnosticThreshold(rule: string): Promise<void> {
    const root = getProjectRoot();
    if (!root) return;
    const current = readDiagnosticThresholds(root).filter((t) => t.rule !== rule);
    writeDiagnosticThresholds(root, current);
    await this._runAnalysisIfEnabled();
    this.refresh();
  }

  /**
   * Forwards a click from the embedded Analysis Optimizer card to the optimizer provider's own
   * message handler (`handleEmbeddedMessage`), then re-renders this tab so the embedded body
   * reflects whatever changed (a new scan result, an applied exclusion, …). See
   * `analysisOptimizerWebviewProvider.ts`'s `handleEmbeddedMessage` doc comment for why this
   * mirrors the standalone panel's own message switch exactly.
   */
  private async _handleOptimizerCommand(msg: { type: string; pattern?: string; patterns?: string[] }): Promise<void> {
    if (!this._analysisOptimizerProvider) return;
    await this._analysisOptimizerProvider.handleEmbeddedMessage(msg);
    this.refresh();
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
    if (id === 'enableAllApplicablePacks') {
      await this._enableAllApplicablePacks();
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
    // Restart the Dart analysis server to clear memory pressure — RSS resets
    // on restart, so shedding de-escalates to level 0 if the project fits in
    // memory on a fresh start.
    if (id === 'restartAnalyzer') {
      await vscode.commands.executeCommand('dart.restartAnalysisServer');
      return;
    }
    // Config file tab — Baseline card. `saropaLints.createBaseline` already writes both
    // saropa_baseline.json AND the config block that activates it (see baselineReader.ts's header
    // comment), so this is create+apply in one command.
    if (id === 'createBaseline') {
      await vscode.commands.executeCommand('saropaLints.createBaseline');
      this.refresh();
      return;
    }
    if (id === 'openBaselineFile') {
      const root = getProjectRoot();
      if (!root) return;
      const uri = vscode.Uri.file(baselineFilePath(root));
      await vscode.commands.executeCommand('vscode.open', uri);
      return;
    }
    // Config file tab — Analysis Optimizer card's "open standalone" deep link. The tab embed
    // stays live in this panel; this just also opens the optimizer's own editor tab, matching
    // "its existing standalone panel command still opens it directly" (Phase 4 requirement #4).
    if (id === 'openOptimizerPanel') {
      this._analysisOptimizerProvider?.openEditorPanel();
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
      void vscode.window.showWarningMessage(l10n('notify.vibrancy.openFolderBeforeCopyConfig'));
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
        l10n('notify.vibrancy.copiedConfigSnippet', { tier, packsLine }),
      );
    } catch (err) {
      void vscode.window.showErrorMessage(
        l10n('notify.vibrancy.couldNotCopyClipboard', { message: err instanceof Error ? err.message : String(err) }),
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
      void vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotReadPubspec'));
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
      void vscode.window.showInformationMessage(l10n('notify.vibrancy.noAdditionalSdkPacks'));
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
      void vscode.window.showErrorMessage(l10n('notify.vibrancy.couldNotWriteRulePacks'));
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
      l10n('notify.vibrancy.enabledApplicableSdkPacks', { added, modeLabel }),
    );
    this.refresh();
  }

  /**
   * Enable every pack that is "recommended" for this project in one click:
   * package packs whose marker is in pubspec, SDK packs whose environment gate
   * passes, and lockfile-resolved upgrade packs. {@link computeConfigSuggestions}
   * is the single source of "what applies", so this button and the proactive
   * detection agree on the set instead of drifting apart.
   */
  private async _enableAllApplicablePacks(): Promise<void> {
    const root = getProjectRoot();
    if (!root) {
      void vscode.window.showWarningMessage(
        l10n('notify.vibrancy.openFolderBeforeEnablePacks'),
      );
      return;
    }
    const applicableIds = computeConfigSuggestions(root)
      .filter((s) => s.kind === 'pack-available' && s.packId)
      .map((s) => s.packId!);
    if (applicableIds.length === 0) {
      void vscode.window.showInformationMessage(
        l10n('notify.vibrancy.noApplicablePacksDetected'),
      );
      return;
    }
    const currentEnabled = new Set(readRulePacksEnabled(root));
    const toAdd = applicableIds.filter((packId) => !currentEnabled.has(packId));
    if (toAdd.length === 0) {
      void vscode.window.showInformationMessage(
        l10n('notify.vibrancy.allApplicablePacksEnabled'),
      );
      return;
    }
    const labelFor = (packId: string): string =>
      RULE_PACK_DEFINITIONS.find((d) => d.id === packId)?.label ?? packId;
    const preview = toAdd.slice(0, 5).map(labelFor).join(', ');
    const suffix = toAdd.length > 5 ? `, +${toAdd.length - 5} more` : '';
    // Action-button label is localized; capture it in a const so the equality
    // check below compares against the exact string the user clicked.
    const enableLabel = l10n('notify.vibrancy.actionEnable');
    const choice = await vscode.window.showWarningMessage(
      l10n('notify.vibrancy.enableRecommendedPacksPrompt', { count: toAdd.length }),
      {
        modal: true,
        detail: l10n('notify.vibrancy.enablePacksDetail', { preview: `${preview}${suffix}` }),
      },
      enableLabel,
    );
    if (choice !== enableLabel) return;

    for (const packId of toAdd) currentEnabled.add(packId);
    const ok = writeRulePacksEnabled(
      root,
      [...currentEnabled].sort((a, b) => a.localeCompare(b)),
    );
    if (!ok) {
      void vscode.window.showErrorMessage(
        l10n('notify.vibrancy.couldNotWriteRulePacks'),
      );
      return;
    }
    void vscode.window.showInformationMessage(
      l10n('notify.vibrancy.enabledRecommendedPacks', { count: toAdd.length }),
    );
    this.refresh();
    const run = vscode.workspace
      .getConfiguration('saropaLints')
      .get<boolean>('runAnalysisAfterConfigChange');
    if (run !== false) {
      await vscode.commands.executeCommand('saropaLints.runAnalysis');
    }
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
    // Action-button label is localized; capture it so the equality check below
    // compares against the exact string the user clicked.
    const enableLabel = l10n('notify.vibrancy.actionEnable');
    const choice = await vscode.window.showWarningMessage(
      l10n('notify.vibrancy.enableModePacksPrompt', { count: packLabels.length, modeLabel }),
      {
        modal: true,
        detail: l10n('notify.vibrancy.enablePacksDetail', { preview: `${preview}${suffix}` }),
      },
      enableLabel,
    );
    return choice === enableLabel;
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

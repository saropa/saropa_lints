/**
 * HTML for the editor-area Saropa Violations Dashboard (grouped, filterable).
 *
 * Implements the gold-standard editor dashboard hierarchy from
 * `plan/guides/UX_UI_GUIDELINES.md`:
 *   §4.1 Hero with status line + version stamp.
 *   §4.2 KPI cards as preset filters with hero-sized numbers.
 *   §4.3 Toolbar band with density tiers (one primary, ≤4 secondary,
 *        rest behind "More actions ▾").
 *   §6   Bars + donut chart side by side.
 *   §7   Sortable, sticky-header findings table.
 *   §8.5 Active-filters chip strip.
 *   §14.7 Density-first content ordering — actionable data above empties.
 */

import { createWebviewCspNonce } from '../vibrancy/views/html-utils';
import type { Violation } from '../violationsReader';
import { getFindingsEmptyStateStyles, getViolationsDashboardStyles } from './violationsDashboardStyles';
import type { DashboardSection } from './issuesTreeModel';
import { VIOLATIONS_GROUP_BY_MODES, type GroupByMode } from './issuesTreeGrouping';
import {
  buildAnnouncer,
  buildFullWidthToggle,
  buildSkipLink,
  getAnnouncerScript,
  getFullWidthToggleScript,
} from './dashboardHero';
import {
  buildKeyboardShortcutsButton,
  buildKeyboardShortcutsOverlay,
  getKeyboardShortcutsScript,
  getKeyboardShortcutsStyles,
} from './keyboard-shortcuts';
import { pluralize } from './webview-format';
import { l10n } from '../i18n/runtime';

/** Client-script strings (embedded webview JS); resolved at host HTML build time. */
function findingsDashScriptStrings(): Record<string, string> {
    return {
        analysisRunning: l10n('loading.runningAnalysis'),
        analysisComplete: l10n('loading.analysisComplete'),
        metaRunning: l10n('findingsDash.progress.runningMeta'),
        metaDone: l10n('loading.refreshingDashboard'),
        metaFailed: l10n('loading.analysisFailedDetail'),
        metaStartedDetail: l10n('loading.analysisStartedDetail'),
        announceSearchVerb: l10n('findingsDash.script.announceSearchVerb'),
        severitiesNoun: l10n('findingsDash.script.severitiesNoun'),
        impactsNoun: l10n('findingsDash.script.impactsNoun'),
        announceCleared: l10n('findingsDash.script.announceCleared'),
        filtersPrefix: l10n('findingsDash.script.announceFiltersPrefix'),
        announceStarted: l10n('findingsDash.script.announceStarted'),
        announceComplete: l10n('findingsDash.script.announceComplete'),
        announceFailed: l10n('findingsDash.script.announceFailed'),
        removeRecentTitle: l10n('findingsDash.script.removeRecentTitle'),
        removeRecentAriaPrefix: l10n('findingsDash.script.removeRecentAria'),
        bulkSelectedTpl: l10n('findingsDash.script.bulkSelectedTpl'),
    };
}

/** Analyzer-side suppression counts from `violations.json` (same source as the Suppressions tree). */
export interface AnalyzerSuppressionsSlice {
  total: number;
  byKind: readonly [string, number][];
  byRule: readonly [string, number][];
  byFile: readonly [string, number][];
}

/** Workspace-stored hides applied to the Issues / Findings list (not analyzer ignores). */
export interface ViewSuppressionsSlice {
  active: boolean;
  folderCount: number;
  fileCount: number;
  ruleCount: number;
  ruleInFileEntryCount: number;
  severityCount: number;
  impactCount: number;
  sampleFolders: readonly string[];
  sampleFiles: readonly string[];
  sampleRules: readonly string[];
  /** Short lines like `lib/a.dart: rule_x, rule_y` for per-file rule hides. */
  sampleRuleInFileLines: readonly string[];
}

export interface ViolationsDashboardHtmlInput {
  /** Violations matching current filters (deduped), for JSON copy. */
  exportViolations: Violation[];
  totalRawAfterDisable: number;
  filteredCount: number;
  truncatedSource: boolean;
  maxSourceViolations: number;
  pageSize: number;
  groupBy: GroupByMode;
  textFilter: string;
  severities: readonly string[];
  impacts: readonly string[];
  sections: DashboardSection[];
  todoHackSnapshot: {
    enabled: boolean;
    capped: boolean;
    todos: Array<{ file: string; line: number; snippet: string }>;
    hacks: Array<{ file: string; line: number; snippet: string }>;
  };
  driftAdvisorSnapshot: {
    integrationEnabled: boolean;
    connected: boolean;
    serverLabel?: string;
    issues: Array<{ source: string; severity: string; message: string; file?: string; line?: number }>;
  };
  severityCounts: Record<string, number>;
  impactCounts: Record<string, number>;
  analyzerSuppressions: AnalyzerSuppressionsSlice;
  viewSuppressions: ViewSuppressionsSlice;
  /** ISO 8601 timestamp from `violations.json`; powers the "Last run …" status pill. */
  reportTimestamp?: string;
  /** Extension semver (e.g. "1.4.2") shown next to the title as a muted build stamp. */
  extensionVersion?: string;
  /** Highest-volume rule across the export (post-disable, pre-filter), for KPI subtitle. */
  topRule?: { name: string; count: number };
  /** Distinct files contributing at least one finding, for KPI subtitle. */
  filesAffected?: number;
  /** Count of enabled rules in the current tier; powers status-line breadth pill. */
  enabledRuleCount?: number;
  /**
   * Top-N rules by violation count for the noisy-rule triage table.
   * Sourced from `exportViolations` so the ranking reflects what the user
   * is currently seeing in the findings table (post-disable, post-suppress,
   * post-filter). Each row carries severity so the user can decide whether
   * the noise is from an INFO-level stylistic rule or a real WARNING.
   */
  topRules?: ReadonlyArray<{
    name: string;
    count: number;
    severity: string;
    /**
     * Representative finding message for the rule (first occurrence). Shown
     * when the row is expanded so the user can read what the rule flags
     * without scrolling down to the findings table. Optional: callers (and
     * tests) that only need the count ranking may omit it — the row then
     * renders as a plain, non-expandable row.
     */
    message?: string;
    /**
     * Files contributing this rule's findings, highest-count first and capped
     * host-side, each with a representative (lowest) line so the expander can
     * deep-link into the source. Optional for the same reason as `message`.
     */
    files?: ReadonlyArray<{ file: string; count: number; line: number }>;
  }>;
  /**
   * Live supplementary diagnostic state powering the status-line toggle pills
   * (gap-closing affordance for issue #224). Each source is a three-state
   * pill on the dashboard: hidden / promo (off, gap present) / count (on).
   *
   * Counts come from `vscode.languages.getDiagnostics()` and reflect the
   * Problems panel; saropa's own findings are subtracted out so the residual
   * is the *additional* context the user would see in Problems but not on
   * this dashboard. Display-only — never feeds health score, KPI cards, or
   * the violations list itself.
   */
  supplementary?: {
    /** Workspace setting `saropaLints.includeOtherAnalyzerFindingsInDashboard`. */
    otherAnalyzerEnabled: boolean;
    /** Workspace setting `saropaLints.includeAnalyzerTodosInDashboard`. */
    analyzerTodosEnabled: boolean;
    /** Workspace setting `saropaLints.todosAndHacks.workspaceScanEnabled` (existing). */
    scannerEnabled: boolean;
    /** Non-saropa analyzer findings on `.dart` files (excludes TODO diagnostics). */
    otherAnalyzerCount: number;
    /** Analyzer-side `code: "todo"` diagnostics on `.dart` files. */
    analyzerTodosCount: number;
    /**
     * Whether the workspace has any `.dart` files. Drives the scanner-promo
     * pill — surfacing it in a workspace with no Dart code is just noise.
     */
    hasDartFiles: boolean;
  };
}

const DEFAULT_SEVERITIES: readonly string[] = ['error', 'warning', 'info'];
// Three-bucket severity model — collapsed from the prior 5-bucket
// (critical/high/medium/low/opinionated) impact taxonomy on 2026-05-03;
// see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md. DEFAULT_IMPACTS mirrors
// DEFAULT_SEVERITIES exactly and is only embedded in the webview JS state
// payload for back-compat with stored panel state; no UI surface solicits
// impact toggles anymore.
const DEFAULT_IMPACTS: readonly string[] = ['error', 'warning', 'info'];
const SEVERITY_ORDER: readonly string[] = ['error', 'warning', 'info'];

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function groupBySelectOptions(current: GroupByMode): string {
  const labels: Record<GroupByMode, string> = {
    severity: l10n('findingsDash.groupBy.severity'),
    file: l10n('findingsDash.groupBy.file'),
    impact: l10n('findingsDash.groupBy.impact'),
    rule: l10n('findingsDash.groupBy.rule'),
    owasp: l10n('findingsDash.groupBy.owasp'),
    ruleType: l10n('findingsDash.groupBy.ruleType'),
    ruleStatus: l10n('findingsDash.groupBy.ruleStatus'),
  };
  // 'impact' is filtered out: post-collapse it groups identically to 'severity'
  // so offering both is a trap. The mode value stays in the GroupByMode union
  // (issuesTreeGrouping / triage views still understand it for stored state
  // back-compat) — the dashboard select simply doesn't expose it.
  return VIOLATIONS_GROUP_BY_MODES.filter((m) => m !== 'impact').map((m) => {
    const sel = m === current ? ' selected' : '';
    return `<option value="${escapeHtml(m)}"${sel}>${escapeHtml(labels[m])}</option>`;
  }).join('');
}

function severitySegmented(active: readonly string[]): string {
  return SEVERITY_ORDER.map((v) => {
    const pressed = active.includes(v);
    return `<button type="button" class="seg-btn" aria-pressed="${pressed}" data-sev="${v}" title="${escapeHtml(l10n('findingsDash.seg.toggleSeverityTitle', { v }))}">
      <span class="swatch sev-${v}"></span>${escapeHtml(v.charAt(0).toUpperCase() + v.slice(1))}
    </button>`;
  }).join('');
}

/* ============================================================================
 * Hero / status / gauge
 * ========================================================================= */

/** Relative time (e.g. "2m ago"). Resilient to clock drift / future stamps. */
function formatRelative(iso: string | undefined): string | undefined {
  if (!iso) return undefined;
  const parsed = Date.parse(iso);
  if (!Number.isFinite(parsed)) return undefined;
  const diffMs = Date.now() - parsed;
  if (diffMs < 0) return l10n('findingsDash.time.justNow');
  const sec = Math.floor(diffMs / 1000);
  if (sec < 45) return l10n('findingsDash.time.justNow');
  const min = Math.floor(sec / 60);
  if (min < 60) return l10n('findingsDash.time.minutesAgo', { min: String(min) });
  const hr = Math.floor(min / 60);
  if (hr < 24) return l10n('findingsDash.time.hoursAgo', { hr: String(hr) });
  const day = Math.floor(hr / 24);
  return l10n('findingsDash.time.daysAgo', { day: String(day) });
}

/**
 * 0-100 health score derived from severity mix.
 * Errors weigh heaviest; warnings moderate; info marginal. Clamped.
 * The intent is "is this codebase quiet?" not a precise quality metric —
 * paired with the per-severity KPIs that carry the absolute counts.
 */
function computeHealthScore(severityCounts: Record<string, number>): number {
  const e = severityCounts.error ?? 0;
  const w = severityCounts.warning ?? 0;
  const i = severityCounts.info ?? 0;
  const penalty = e * 5 + w * 2 + i * 0.5;
  return Math.max(0, Math.min(100, Math.round(100 - penalty)));
}

function scoreToGrade(score: number): string {
  if (score >= 90) return 'A';
  if (score >= 75) return 'B';
  if (score >= 60) return 'C';
  if (score >= 40) return 'D';
  return 'E';
}

/**
 * Hero radial gauge — same SVG geometry as the package dashboard's gauge.
 *
 * The fill arc is a static SVG `stroke-dasharray` presentation attribute, NOT a
 * CSS keyframe. The dashboard re-renders its whole HTML on every diagnostics
 * tick; an entrance animation restarts from the 0% frame on each rebuild, and
 * when rebuilds arrive faster than the animation duration the ring is forever
 * caught near empty — it reads as a lone round-cap dot. A static dasharray
 * paints the true fill instantly on every rebuild, so the ring is always right.
 *
 * `data-pending` (toggled client-side while analysis is in flight) dims the ring
 * and swaps the grade for a "computing" glyph, so a transient not-yet-settled
 * score never flashes a misleading grade (the A→E whiplash the user reported).
 */
function buildGauge(score: number): string {
  const r = 36;
  const circumference = 2 * Math.PI * r;
  const arcLength = circumference * 0.75;
  const filled = arcLength * (score / 100);
  const color = score >= 50
    ? `hsl(${Math.round(60 + (score - 50) * 1.2)}, 70%, 48%)`
    : `hsl(${Math.round(score * 1.2)}, 75%, 48%)`;
  const grade = scoreToGrade(score);
  return `<div class="hero-gauge" data-pending="false" title="${escapeHtml(l10n('findingsDash.hero.gaugeTitle', { score: String(score), grade }))}">
    <svg viewBox="0 0 88 88">
      <circle class="gauge-track" cx="44" cy="44" r="${r}" fill="none"
        stroke-width="7"
        stroke-dasharray="${arcLength} ${circumference}"
        stroke-linecap="round" transform="rotate(135 44 44)" />
      <circle class="gauge-fill" cx="44" cy="44" r="${r}" fill="none"
        stroke="${color}" stroke-width="7"
        stroke-dasharray="${filled} ${circumference}"
        stroke-linecap="round" transform="rotate(135 44 44)" />
    </svg>
    <div class="gauge-label">
      <span class="lg">${grade}</span>
      <span class="sm">${score}</span>
    </div>
    <div class="gauge-pending" aria-hidden="true">${escapeHtml(l10n('findingsDash.hero.gaugePending'))}</div>
  </div>`;
}

/**
 * Build the three-state toggle pills for the supplementary-counts feature
 * (#224). Each source (other analyzer findings / analyzer TODOs / scanner)
 * renders as zero or one pill depending on its setting state and whether
 * there is anything worth surfacing.
 *
 * - OFF + gap present  → muted "promo" pill inviting the user to enable.
 * - OFF + no gap       → hidden (no need to advertise an empty bucket).
 * - ON  + count > 0    → solid count pill, clickable to disable.
 * - ON  + count == 0   → hidden (avoids a useless "+0 ..." pill).
 *
 * The scanner pill is rendered ELSEWHERE in `buildStatusLine` when ON (to
 * preserve the existing "{N} TODO · {N} HACK" pill shape and tests). This
 * helper only returns the scanner *promo* — never the scanner ON state.
 */
function buildSupplementaryPills(input: ViolationsDashboardHtmlInput): string[] {
  const s = input.supplementary;
  if (!s) return [];
  const out: string[] = [];

  // Other analyzer findings — bucket includes built-in Dart SDK lints AND any
  // third-party custom_lint plugins (riverpod_lint, etc.). Label is honest
  // about that (NOT "Dart lints" alone).
  if (s.otherAnalyzerEnabled && s.otherAnalyzerCount > 0) {
    out.push(
      `<span class="pill toggle on" data-toggle="other" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipLive'))}">${escapeHtml(l10n('findingsDash.supplementary.otherAnalyzerOn', { count: String(s.otherAnalyzerCount) }))}</span>`,
    );
  } else if (!s.otherAnalyzerEnabled && s.otherAnalyzerCount > 0) {
    out.push(
      `<span class="pill toggle promo" data-toggle="other" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipPromoClickToOn'))}">${escapeHtml(l10n('findingsDash.supplementary.otherAnalyzerPromo'))}</span>`,
    );
  }

  // Analyzer-side TODO diagnostics (`code: "todo"`) — independent of the
  // file-system scanner; matches what Problems panel shows for #224's "20
  // TODOs" complaint.
  if (s.analyzerTodosEnabled && s.analyzerTodosCount > 0) {
    out.push(
      `<span class="pill toggle on" data-toggle="todos" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipLive'))}">${escapeHtml(l10n('findingsDash.supplementary.analyzerTodosOn', { count: String(s.analyzerTodosCount) }))}</span>`,
    );
  } else if (!s.analyzerTodosEnabled && s.analyzerTodosCount > 0) {
    out.push(
      `<span class="pill toggle promo" data-toggle="todos" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipPromoClickToOn'))}">${escapeHtml(l10n('findingsDash.supplementary.analyzerTodosPromo'))}</span>`,
    );
  }

  // Scanner promo only — the ON state pill is rendered in buildStatusLine
  // alongside the existing todoHackSnapshot logic. Only suggest enabling the
  // scanner if there are .dart files to scan; promoting it in a non-Dart
  // workspace is just noise.
  if (!s.scannerEnabled && s.hasDartFiles) {
    out.push(
      `<span class="pill toggle promo" data-toggle="scanner" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipPromoClickToOn'))}">${escapeHtml(l10n('findingsDash.supplementary.scannerPromo'))}</span>`,
    );
  }

  return out;
}

/** Status line under the title — freshness + highest-signal facts (§4.1). */
function buildStatusLine(input: ViolationsDashboardHtmlInput): string {
  const parts: string[] = [];
  const rel = formatRelative(input.reportTimestamp);
  if (rel) {
    const iso = escapeHtml(input.reportTimestamp ?? '');
    parts.push(`<span class="pill" title="${iso}">⟳ ${l10n('findingsDash.status.lastRunPrefix')} ${escapeHtml(rel)}</span>`);
  } else {
    parts.push(`<span class="pill warn" title="${escapeHtml(l10n('findingsDash.status.noTimestampTitle'))}">⟳ ${escapeHtml(l10n('findingsDash.status.lastRunUnknown'))}</span>`);
  }
  const findings = input.totalRawAfterDisable;
  const findingsClass = findings === 0 ? 'good' : findings > 100 ? 'bad' : 'warn';
  parts.push(`<span class="pill ${findingsClass}" title="${escapeHtml(l10n('findingsDash.status.findingsAfterFilterTitle'))}">${pluralize(findings, { one: l10n('findingsDash.status.findingOne'), other: l10n('findingsDash.status.findingOther') })}</span>`);
  const todos = input.todoHackSnapshot.todos.length;
  const hacks = input.todoHackSnapshot.hacks.length;
  if (input.todoHackSnapshot.enabled) {
    // ON state — count pill matches the existing pre-supplementary-pills
    // behavior, but is now clickable so users can dismiss the scanner the same
    // way they enabled it (#224). The data-toggle attribute drives the click
    // handler at the bottom of this file.
    parts.push(
      `<span class="pill toggle on" data-toggle="scanner" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.status.todoHackTitle'))} — ${escapeHtml(l10n('findingsDash.supplementary.tooltipScanner'))}">${todos} TODO · ${hacks} HACK</span>`,
    );
  }
  // Supplementary toggle pills (#224) — live next to the saropa pills so the
  // discoverability gap is closed on the surface that has it. Each source has
  // three render states: hidden / promo (off, gap present) / count (on).
  // Promo pills only render when there is actually a gap to surface, so a
  // clean workspace never sees them.
  parts.push(...buildSupplementaryPills(input));
  const drift = input.driftAdvisorSnapshot;
  if (drift.integrationEnabled) {
    if (drift.connected) {
      parts.push(`<span class="pill good" title="${escapeHtml(l10n('findingsDash.status.driftOnTitle', { label: drift.serverLabel ?? '' }))}">${l10n('findingsDash.status.driftOnPill', { count: String(drift.issues.length) })}</span>`);
    } else {
      parts.push(`<span class="pill warn" title="${escapeHtml(l10n('findingsDash.status.driftOfflineTitle'))}">${escapeHtml(l10n('findingsDash.status.driftOfflinePill'))}</span>`);
    }
  }
  if (typeof input.enabledRuleCount === 'number' && input.enabledRuleCount > 0) {
    parts.push(`<span class="pill" title="${escapeHtml(l10n('findingsDash.status.enabledRulesTitle'))}">${l10n('findingsDash.status.rulesCount', { count: String(input.enabledRuleCount) })}</span>`);
  }
  // Full-width toggle is appended after the pills so it right-aligns via margin-inline-start:auto
  // (see .status-line .full-width-toggle in dashboardChromeStyles.ts / violationsDashboardStyles.ts).
  // The keyboard-shortcut overlay trigger sits left of the toggle so the toggle
  // remains the rightmost action across all dashboards (sticky muscle memory).
  const trailing = `${buildKeyboardShortcutsButton()}${buildFullWidthToggle()}`;
  return `<p class="status-line">${parts.join('<span class="dot">·</span>')}${trailing}</p>`;
}

function buildHero(input: ViolationsDashboardHtmlInput): string {
  const score = computeHealthScore(input.severityCounts);
  const stamp = input.extensionVersion
    ? `<span class="stamp">v${escapeHtml(input.extensionVersion)}</span>`
    : '';
  return `<header class="dash-hero">
    <div class="hero-text">
      <h1>${escapeHtml(l10n('findingsDash.pageTitle'))}${stamp}</h1>
      ${buildStatusLine(input)}
    </div>
    ${buildGauge(score)}
  </header>`;
}

/* ============================================================================
 * KPI row — interactive cards that double as preset filters (§14.8).
 * ========================================================================= */

interface KpiSpec {
  key: string;
  label: string;
  value: string;
  sub: string;
  classes: string;
  filter?: { kind: 'sev' | 'reset' | 'top-rule'; value?: string };
  title?: string;
}

function buildKpiCards(input: ViolationsDashboardHtmlInput): string {
  const cards = collectKpiCards(input);
  return `<div class="kpi-row">${cards.map(renderKpiCard).join('')}</div>`;
}

/**
 * KPI card order is **importance-descending** and now matches the
 * analyzer's three-level severity model. The previous five-card layout
 * (Errors / Critical / High / Warnings / Info) was driven by the
 * 5-bucket LintImpact taxonomy that collapsed on 2026-05-03 — see
 * plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md. Critical/High/Medium have
 * folded into Errors/Warnings; Low/Opinionated into Info.
 *
 * Order: Visible (anchor) → Errors → Warnings → Info → Files → Top rule.
 */
function collectKpiCards(input: ViolationsDashboardHtmlInput): KpiSpec[] {
  // Severity axis is the only axis now — `impactCounts` is the same data
  // re-keyed for back-compat (see ByImpact in violationsReader.ts).
  const errorCount = input.severityCounts.error ?? input.impactCounts.error ?? 0;
  const warningCount = input.severityCounts.warning ?? input.impactCounts.warning ?? 0;
  const infoCount = input.severityCounts.info ?? input.impactCounts.info ?? 0;
  const cards: KpiSpec[] = [];
  cards.push({
    key: 'visible',
    label: l10n('findingsDash.kpi.visibleLabel'),
    value: String(input.filteredCount),
    sub: input.totalRawAfterDisable === input.filteredCount
      ? l10n('findingsDash.kpi.allMatched')
      : l10n('findingsDash.kpi.ofTotal', { total: String(input.totalRawAfterDisable) }),
    classes: '',
    filter: { kind: 'reset' },
    title: l10n('findingsDash.kpi.clearFiltersTitle'),
  });
  cards.push({
    key: 'errors',
    label: l10n('findingsDash.kpi.errorsLabel'),
    value: String(errorCount),
    sub: errorCount > 0 ? l10n('findingsDash.kpi.errorsSubFix') : l10n('findingsDash.kpi.errorsSubClear'),
    classes: 'errors',
    filter: { kind: 'sev', value: 'error' },
    title: l10n('findingsDash.kpi.errorsTitle'),
  });
  cards.push({
    key: 'warnings',
    label: l10n('findingsDash.kpi.warningsLabel'),
    value: String(warningCount),
    sub: warningCount > 0 ? l10n('findingsDash.kpi.warningsSubBad') : l10n('findingsDash.kpi.warningsSubClear'),
    classes: 'warnings',
    filter: { kind: 'sev', value: 'warning' },
    title: l10n('findingsDash.kpi.warningsTitle'),
  });
  cards.push({
    key: 'info',
    label: l10n('findingsDash.kpi.infoLabel'),
    value: String(infoCount),
    sub: infoCount > 0 ? l10n('findingsDash.kpi.infoSub') : l10n('findingsDash.kpi.infoSubNone'),
    classes: 'info',
    filter: { kind: 'sev', value: 'info' },
    title: l10n('findingsDash.kpi.infoTitle'),
  });
  if (typeof input.filesAffected === 'number') {
    cards.push({
      key: 'files',
      label: l10n('findingsDash.kpi.filesLabel'),
      value: String(input.filesAffected),
      sub: input.filesAffected > 0 ? l10n('findingsDash.kpi.filesSubAcross') : l10n('findingsDash.kpi.filesSubNone'),
      classes: '',
      title: l10n('findingsDash.kpi.filesTitle'),
    });
  }
  if (input.topRule && input.topRule.count > 0) {
    cards.push({
      key: 'top-rule',
      label: l10n('findingsDash.kpi.topRuleLabel'),
      value: String(input.topRule.count),
      sub: input.topRule.name,
      classes: '',
      filter: { kind: 'top-rule', value: input.topRule.name },
      title: l10n('findingsDash.kpi.topRuleTitle', { name: input.topRule.name }),
    });
  }
  return cards;
}

function renderKpiCard(c: KpiSpec): string {
  /* `data-kpi` is the card identifier (always emitted so DOM tests and
     analytics can find a card by key), independent of whether the card
     is interactive. Filter-specific attrs only render when the card
     has an associated filter behavior. */
  const interactive = c.filter ? ' interactive' : '';
  const role = c.filter ? ' role="button" tabindex="0"' : '';
  const filterAttrs = c.filter
    ? ` data-kpi-kind="${escapeHtml(c.filter.kind)}"${
        c.filter.value !== undefined ? ` data-kpi-value="${escapeHtml(c.filter.value)}"` : ''
      }`
    : '';
  const title = c.title ? ` title="${escapeHtml(c.title)}"` : '';
  return `<div class="kpi-card ${escapeHtml(c.classes)}${interactive}"${role} data-kpi="${escapeHtml(c.key)}"${filterAttrs}${title}>
    <div class="kpi-k">${escapeHtml(c.label)}</div>
    <div class="kpi-v">${escapeHtml(c.value)}</div>
    <div class="kpi-sub">${escapeHtml(c.sub)}</div>
  </div>`;
}

/* ============================================================================
 * Toolbar — sticky band with density tiers (§4.3, §8.10).
 * ========================================================================= */

function buildToolbar(input: ViolationsDashboardHtmlInput): string {
  const tf = escapeHtml(input.textFilter);
  const exportCount = input.exportViolations.length;
  const gbLabel = l10n('findingsDash.toolbar.groupByLabel');
  return `<section class="toolbar-band" aria-label="${escapeHtml(l10n('findingsDash.toolbar.ariaFiltersActions'))}">
    <div class="toolbar-row">
      <span class="field" title="${escapeHtml(l10n('findingsDash.toolbar.groupByFieldTitle'))}">
        <span class="glyph">⌘</span>
        <label for="groupBy">${escapeHtml(gbLabel)}</label>
        <select id="groupBy" aria-label="${escapeHtml(gbLabel)}">${groupBySelectOptions(input.groupBy)}</select>
      </span>
      <span class="field text-filter-field" title="${escapeHtml(l10n('findingsDash.toolbar.textFilterTitle'))}">
        <span class="glyph">⌕</span>
        <input type="text" id="textFilter" placeholder="${escapeHtml(l10n('findingsDash.toolbar.textFilterPlaceholder'))}" value="${tf}" aria-label="${escapeHtml(l10n('findingsDash.toolbar.textFilterAria'))}" />
        <button type="button" class="clear-btn" id="textFilterClear" title="${escapeHtml(l10n('findingsDash.toolbar.clearTextFilterTitle'))}" aria-label="${escapeHtml(l10n('findingsDash.toolbar.clearTextFilterAria'))}">×</button>
        <!-- §8.5.2 — recent-searches popover for the Findings filter.
             Persistence: sessionStorage. Cross-session persistence via
             workspaceState is tracked in plan/UX_GUIDELINES.md (Part B). -->
        <div id="findings-recent" class="findings-recent" hidden>
          <div class="findings-recent-head">
            <span class="findings-recent-title">${escapeHtml(l10n('findingsDash.toolbar.recentFiltersTitle'))}</span>
            <button type="button" id="findings-recent-clear"
              class="findings-recent-clear"
              title="${escapeHtml(l10n('findingsDash.toolbar.clearRecentTitle'))}">${escapeHtml(l10n('findingsDash.toolbar.clearRecentButton'))}</button>
          </div>
          <ul id="findings-recent-list" class="findings-recent-list"
            role="listbox" aria-label="${escapeHtml(l10n('findingsDash.toolbar.recentFiltersListAria'))}"></ul>
        </div>
      </span>
      <button type="button" class="btn tier-1" id="btn-run" data-run-analysis title="${escapeHtml(l10n('findingsDash.toolbar.runAnalysisTitle'))}">
        <span class="glyph">▶</span>${escapeHtml(l10n('toolbar.runAnalysis'))}
      </button>
      ${buildMoreActionsMenu(exportCount)}
      <!-- Refresh moved into the More menu as "Reload from disk".
           The visible toolbar button was indistinguishable from Run analysis
           and never re-ran the analyzer — it only re-rendered from the
           existing violations.json. Hidden stub kept so existing tests and
           keybindings that reference #btn-refresh still resolve to a node;
           the actual click handler is bound to the in-menu replacement. -->
      <button type="button" id="btn-refresh" hidden aria-hidden="true" tabindex="-1"></button>
    </div>
    <div class="toolbar-row">
      <!-- The Impact filter pill row was removed: since the LintImpact 5→3
           collapse on 2026-05-03 (plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md),
           every Impact bucket mirrors the same-named Severity bucket. Two
           pill rows with identical semantics were confusing — users could
           not tell which one to use. Severity is the single axis now;
           input.impacts is still accepted for back-compat with stored
           webview state but no longer surfaced or solicited. -->
      <span class="seg" role="group" aria-label="${escapeHtml(l10n('findingsDash.toolbar.severityGroupAria'))}">
        <span class="seg-label">${escapeHtml(l10n('findingsDash.toolbar.severityLabel'))}</span>
        ${severitySegmented(input.severities)}
      </span>
    </div>
    ${buildChipStrip(input)}
  </section>`;
}

function buildAnalysisProgress(): string {
  return `<div id="analysis-progress" class="analysis-progress" role="status" aria-live="polite" hidden>
    <div class="analysis-progress-head">
      <strong id="analysis-progress-label">${escapeHtml(l10n('findingsDash.progress.runningLabel'))}</strong>
      <span id="analysis-progress-meta">${escapeHtml(l10n('findingsDash.progress.runningMeta'))}</span>
    </div>
    <div class="analysis-progress-track" aria-hidden="true">
      <div class="analysis-progress-bar"></div>
    </div>
  </div>`;
}

/**
 * One menu item: either a palette command (`cmd` invokes the VS Code command
 * via paletteCommand message) or a local action (`localId` is the button id,
 * wired in the webview script directly). Mutually exclusive.
 */
type MenuItem = {
  readonly cmd?: string;
  readonly localId?: string;
  readonly glyph: string;
  readonly label: string;
  readonly kbd?: string;
  readonly title?: string;
};

/**
 * Build the More menu HTML, grouped into four labeled sections with separators:
 *   Export   — Copy JSON, Save report, Copy tree JSON
 *   Filter   — Group by, Text filter, Severity & impact, Hide rules, Rule
 *              metadata, Match active editor, Clear filters, Clear
 *              suppressions, Clear file focus, Re-enable disabled rules
 *   Open     — Package dashboard, Code Health, Lints Config
 *   System   — Help, Reload from disk, Refresh extension
 *
 * Why grouped: a flat 17-item list (previous shape) is visually inscrutable —
 * users scan label-by-label instead of jumping to a category. Section heads
 * + <hr class="menu-sep"> between sections make the menu glanceable.
 *
 * Every item carries a glyph so the icon column is uniform (previously only
 * Copy JSON / Save report had glyphs, the rest were text-only — labels did
 * not line up). The glyph slot is fixed-width via .menu-item .glyph in
 * violationsDashboardStyles.ts.
 *
 * Hidden id="btn-refresh-extension" preserves the existing test contract
 * and keyboard binding (Cmd/Ctrl-R) without polluting the visible menu.
 */
function buildMoreActionsMenu(exportCount: number): string {
  const exportItems: readonly MenuItem[] = [
    { localId: 'btn-copy', glyph: '⎘', label: l10n('toolbar.copyJson'), title: l10n('findingsDash.toolbar.copyJsonTitle', { count: String(exportCount) }) },
    { localId: 'btn-save', glyph: '⤓', label: l10n('toolbar.saveReport'), title: l10n('findingsDash.toolbar.saveReportTitle') },
    { cmd: 'saropaLints.issues.copyAsJson', glyph: '❏', label: l10n('findingsDash.menuPalette.copyTreeJson') },
  ];
  const filterItems: readonly MenuItem[] = [
    { cmd: 'saropaLints.setGroupBy', glyph: '▦', label: l10n('findingsDash.menuPalette.groupBy') },
    { cmd: 'saropaLints.setIssuesFilter', glyph: '⌕', label: l10n('findingsDash.menuPalette.textFilter') },
    { cmd: 'saropaLints.setIssuesFilterByType', glyph: '◉', label: l10n('findingsDash.menuPalette.severityImpact') },
    { cmd: 'saropaLints.setIssuesFilterByRule', glyph: '⊘', label: l10n('findingsDash.menuPalette.hideRules') },
    { cmd: 'saropaLints.setIssuesFilterByMetadata', glyph: 'ℹ', label: l10n('findingsDash.menuPalette.ruleMetadata') },
    { cmd: 'saropaLints.focusIssuesForActiveFile', glyph: '⊙', label: l10n('findingsDash.menuPalette.matchActiveEditor') },
    { cmd: 'saropaLints.clearIssuesFilters', glyph: '⌫', label: l10n('findingsDash.menuPalette.clearFilters') },
    { cmd: 'saropaLints.clearSuppressions', glyph: '⌫', label: l10n('findingsDash.menuPalette.clearSuppressions') },
    { cmd: 'saropaLints.clearFocusFile', glyph: '⌫', label: l10n('findingsDash.menuPalette.clearFileFocus') },
    { cmd: 'saropaLints.reEnableDisabledRules', glyph: '⟲', label: l10n('findingsDash.menuPalette.reEnableDisabledRules'), title: l10n('findingsDash.menuPalette.reEnableDisabledRulesTitle') },
  ];
  const openItems: readonly MenuItem[] = [
    { cmd: 'saropaLints.openPackageVibrancy', glyph: '❒', label: l10n('findingsDash.menuPalette.openPackageDashboard') },
    { cmd: 'saropaLints.openProjectVibrancyReport', glyph: '♥', label: l10n('findingsDash.menuPalette.openCodeHealth') },
    { cmd: 'saropaLints.openConfigDashboard', glyph: '⚙', label: l10n('findingsDash.menuPalette.openLintsConfig') },
  ];
  const systemItems: readonly MenuItem[] = [
    { cmd: 'saropaLints.openHelpHub', glyph: '?', label: l10n('findingsDash.menuPalette.help'), kbd: 'F1' },
    { localId: 'btn-reload-disk', glyph: '↺', label: l10n('findingsDash.menuPalette.reloadFromDisk'), title: l10n('findingsDash.menuPalette.reloadFromDiskTitle') },
    { cmd: 'saropaLints.refresh', glyph: '⟳', label: l10n('findingsDash.menuPalette.refreshExtension') },
  ];

  const sections: ReadonlyArray<{ key: string; title: string; items: readonly MenuItem[] }> = [
    { key: 'export', title: l10n('findingsDash.menuPalette.menuGroupExport'), items: exportItems },
    { key: 'filter', title: l10n('findingsDash.menuPalette.menuGroupFilter'), items: filterItems },
    { key: 'open', title: l10n('findingsDash.menuPalette.menuGroupOpen'), items: openItems },
    { key: 'system', title: l10n('findingsDash.menuPalette.menuGroupSystem'), items: systemItems },
  ];

  const renderItem = (item: MenuItem): string => {
    const idAttr = item.localId ? ` id="${escapeHtml(item.localId)}"` : '';
    const cmdAttr = item.cmd ? ` data-palette-cmd="${escapeHtml(item.cmd)}"` : '';
    const titleAttr = item.title ? ` title="${escapeHtml(item.title)}"` : '';
    return `<button type="button" class="menu-item"${idAttr}${cmdAttr}${titleAttr}>
      <span class="menu-item-label"><span class="glyph">${escapeHtml(item.glyph)}</span>${escapeHtml(item.label)}</span>
      <span class="kbd">${escapeHtml(item.kbd ?? '')}</span>
    </button>`;
  };

  const sectionsHtml = sections
    .map((section, index) => {
      const sep = index > 0 ? `<hr class="menu-sep" role="separator" />` : '';
      const head = `<div class="menu-section-title" role="presentation">${escapeHtml(section.title)}</div>`;
      const body = section.items.map(renderItem).join('');
      return `${sep}${head}${body}`;
    })
    .join('');

  return `<details class="more">
    <summary class="btn" title="${escapeHtml(l10n('toolbar.moreActions'))}" aria-label="${escapeHtml(l10n('toolbar.moreActions'))}">
      <span class="glyph">⋯</span>${escapeHtml(l10n('findingsDash.toolbar.moreSummary'))} <span class="chev">${escapeHtml(l10n('findingsDash.toolbar.moreChevron'))}</span>
    </summary>
    <div class="menu" role="menu">
      ${sectionsHtml}
    </div>
  </details>
  <button type="button" id="btn-refresh-extension" hidden aria-hidden="true" tabindex="-1"></button>`;
}

/* ============================================================================
 * Active filter chip strip (§8.5, §14.10).
 * ========================================================================= */

function buildChipStrip(input: ViolationsDashboardHtmlInput): string {
  const chips: string[] = [];
  if (input.textFilter.trim().length > 0) {
    chips.push(buildChip('contains', l10n('findingsDash.chip.contains', { q: input.textFilter }), 'text'));
  }
  for (const v of SEVERITY_ORDER) {
    if (!input.severities.includes(v)) {
      chips.push(buildChip('sev-off', l10n('findingsDash.chip.severityOff', { v }), `sev:${v}`));
    }
  }
  // Impact chips intentionally not emitted — see the comment on the toolbar
  // row above buildToolbar's seg group. Impact mirrors severity since the
  // 2026-05-03 collapse; the chip would always duplicate the corresponding
  // severity chip.
  if (chips.length === 0) return '';
  return `<div class="chip-strip" id="chipStrip">
    <span class="lbl">${escapeHtml(l10n('filter.activeLabel'))}</span>
    ${chips.join('')}
    <button type="button" class="clear-all" id="chipsClearAll" title="${escapeHtml(l10n('findingsDash.chip.resetAllTitle'))}">${escapeHtml(l10n('toolbar.clearAll'))}</button>
  </div>`;
}

function buildChip(kind: string, label: string, dropToken: string): string {
  return `<span class="chip" data-chip-kind="${escapeHtml(kind)}" data-chip-token="${escapeHtml(dropToken)}">
    ${escapeHtml(label)}
    <button type="button" class="x" aria-label="${escapeHtml(l10n('filter.chipRemove'))}">×</button>
  </span>`;
}

/* ============================================================================
 * Top Rules table — noisy-rule triage with two suppression flavors per row:
 *   • Hide    — workspace-only, per-user, reversible via Clear Suppressions
 *               (same path as the Issues tree's "Hide rule").
 *   • Disable — project-wide, writes to analysis_options_custom.yaml and
 *               re-runs analysis (team-shared, persistent).
 * Sits above the Findings table so users can clean dominant noise before
 * scrolling. Two buttons over a split menu: scannable at a glance, and the
 * commitment difference (personal triage vs. team config) is encoded in the
 * label, not buried behind a chevron.
 * ========================================================================= */

type TopRule = NonNullable<ViolationsDashboardHtmlInput['topRules']>[number];

function buildTopRulesTable(input: ViolationsDashboardHtmlInput): string {
  const rows = input.topRules ?? [];
  // Hide the section entirely when there are no findings — avoids an empty
  // shell next to the "no findings" empty state in the findings block.
  if (rows.length === 0 || input.filteredCount === 0) return '';
  const totalShown = rows.reduce((n, r) => n + r.count, 0);
  const share = input.filteredCount > 0
    ? Math.round((totalShown / input.filteredCount) * 100)
    : 0;
  // Body is built once on render; suppressing a rule reloads the panel via
  // the issuesProvider tree-data event, so client-side row removal is not
  // needed (and would diverge from the rebuilt findings table below).
  // Rank is a stable position attribute reflecting the original count order;
  // it is intentionally NOT sortable, so it keeps reading as "the Nth noisiest
  // rule" even after the user re-sorts by name or severity.
  const body = rows.map((r, i) => buildTopRuleRow(r, i)).join('');
  const topPhrase = pluralize(rows.length, {
    one: l10n('findingsDash.topRules.topRulesOne'),
    other: l10n('findingsDash.topRules.topRulesOther'),
  });
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.topRules.sectionAria'))}">
    <div class="findings-wrap">
      <div class="findings-toolbar">
        <span class="meta-line" style="margin:0">
          ${topPhrase} · ${totalShown} of ${input.filteredCount} findings (${share}%) ·
          <strong>${escapeHtml(l10n('findingsDash.topRules.hideButton'))}</strong> = ${escapeHtml(l10n('findingsDash.topRules.workspaceOnlyShort'))} ·
          <strong>${escapeHtml(l10n('findingsDash.topRules.disableButton'))}</strong> = ${escapeHtml(l10n('findingsDash.topRules.projectConfigShort'))}
        </span>
      </div>
      <table class="top-rules-table" role="grid">
        <thead>
          <tr>
            <th class="col-rank" scope="col">${escapeHtml(l10n('findingsDash.topRules.colRank'))}</th>
            <th class="col-rule" data-sort="rule" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.topRules.colRule'))}<span class="arrow">⇅</span></th>
            <th class="col-count" data-sort="count" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.topRules.colCount'))}<span class="arrow">⇅</span></th>
            <th class="col-sev" data-sort="sev" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.topRules.colSeverity'))}<span class="arrow">⇅</span></th>
            <th class="col-actions" aria-label="${escapeHtml(l10n('findingsDash.topRules.colActionsAria'))}" scope="col"></th>
          </tr>
        </thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  </section>`;
}

/**
 * One Top-Rules row. When the rule carries a message or file breakdown the row
 * becomes an expander: a chevron + `data-expandable` main row, followed by a
 * `trow-detail` row (hidden) holding the full message and the affected-file
 * list. Rows without that detail (count-only fixtures) render flat so the
 * chevron never advertises content that is not there.
 */
function buildTopRuleRow(r: TopRule, i: number): string {
  const sev = (r.severity || 'info').toLowerCase();
  const ruleAttr = encodeURIComponent(r.name);
  const files = r.files ?? [];
  const message = r.message ?? '';
  const expandable = message.length > 0 || files.length > 0;
  const chevron = expandable
    ? '<span class="trow-chev" aria-hidden="true">▸</span>'
    : '<span class="trow-chev placeholder" aria-hidden="true"></span>';
  const expandAttrs = expandable
    ? ` role="button" tabindex="0" aria-expanded="false" data-expandable="true" aria-controls="trd-${ruleAttr}"`
    : '';
  const mainRow = `<tr class="trow" data-rule="${escapeHtml(r.name)}" data-rule-enc="${ruleAttr}" data-count="${r.count}" data-sev="${escapeHtml(sev)}"${expandAttrs}>
      <td class="col-rank">${i + 1}</td>
      <td class="col-rule">${chevron}<span class="rule-tag">${escapeHtml(r.name)}</span></td>
      <td class="col-count">${r.count}</td>
      <td class="col-sev"><span class="sev-pill sev-${escapeHtml(sev)}">${escapeHtml(sev)}</span></td>
      <td class="col-actions">
        <button type="button" class="row-action neutral" data-row-action="hide-rule"
                title="${escapeHtml(l10n('findingsDash.topRules.hideTitle'))}">
          ${escapeHtml(l10n('findingsDash.topRules.hideButton'))}
        </button>
        <button type="button" class="row-action danger" data-row-action="disable-rule"
                title="${escapeHtml(l10n('findingsDash.topRules.disableTitle'))}">
          ${escapeHtml(l10n('findingsDash.topRules.disableButton'))}
        </button>
      </td>
    </tr>`;
  if (!expandable) return mainRow;
  return `${mainRow}${buildTopRuleDetailRow(ruleAttr, message, files)}`;
}

function buildTopRuleDetailRow(
  ruleAttr: string,
  message: string,
  files: ReadonlyArray<{ file: string; count: number; line: number }>,
): string {
  const msgHtml = message.length > 0
    ? `<p class="trd-msg">${escapeHtml(message)}</p>`
    : '';
  const fileItems = files
    .map((f) => {
      const enc = encodeURIComponent(f.file);
      return `<li class="trd-file" role="button" tabindex="0" data-file="${enc}" data-line="${Math.max(1, f.line)}" title="${escapeHtml(f.file)}">
            <span class="trd-file-path">${escapeHtml(f.file)}</span>
            <span class="trd-file-count">${f.count}</span>
          </li>`;
    })
    .join('');
  const filesHtml = files.length > 0
    ? `<div class="trd-files-head">${escapeHtml(l10n('findingsDash.topRules.filesAffected', { count: String(files.length) }))}</div>
         <ul class="trd-files">${fileItems}</ul>`
    : '';
  return `<tr class="trow-detail" id="trd-${ruleAttr}" data-rule-enc="${ruleAttr}" hidden>
      <td colspan="5"><div class="trd-body">${msgHtml}${filesHtml}</div></td>
    </tr>`;
}

/* ============================================================================
 * Findings table — sortable, sticky header, group rows (§7).
 * Replaces the legacy `<details > <details> > <vrow>` tree.
 * ========================================================================= */

function buildFindingsBlock(input: ViolationsDashboardHtmlInput): string {
  if (input.filteredCount === 0) {
    return buildFindingsEmpty(input);
  }
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.findings.sectionAria'))}">
    <div class="findings-wrap">
      <div class="findings-toolbar">
        <span class="meta-line" style="margin:0">${escapeHtml(buildFindingsMeta(input))}</span>
        <div class="actions">
          <button type="button" class="mini-btn" id="expand-all">${escapeHtml(l10n('findingsDash.findings.expandAll'))}</button>
          <button type="button" class="mini-btn" id="collapse-all">${escapeHtml(l10n('findingsDash.findings.collapseAll'))}</button>
        </div>
      </div>
      <div id="findings-bulk-bar" class="findings-bulk-bar" hidden>
        <span class="findings-bulk-label" id="findings-bulk-count">${escapeHtml(l10n('findingsDash.findings.bulkSelected', { count: '0' }))}</span>
        <button type="button" class="mini-btn tier-1" id="btn-bulk-copy">${escapeHtml(l10n('findingsDash.findings.bulkCopy'))}</button>
      </div>
      <table class="findings-table" role="grid" aria-rowcount="${input.filteredCount}">
        <thead>
          <tr>
            <th class="col-sel-bulk" scope="col"><input type="checkbox" id="bulk-select-all" title="${escapeHtml(l10n('findingsDash.findings.selectAllTitle'))}" aria-label="${escapeHtml(l10n('findingsDash.findings.selectAllAria'))}"></th>
            <th data-sort="sev" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.findings.colSeverity'))}<span class="arrow">⇅</span><span class="sort-idx" aria-hidden="true"></span></th>
            <th data-sort="rule" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.findings.colRule'))}<span class="arrow">⇅</span><span class="sort-idx" aria-hidden="true"></span></th>
            <th data-sort="msg" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.findings.colMessage'))}<span class="arrow">⇅</span><span class="sort-idx" aria-hidden="true"></span></th>
            <th data-sort="line" aria-sort="none" scope="col">${escapeHtml(l10n('findingsDash.findings.colLine'))}<span class="arrow">⇅</span><span class="sort-idx" aria-hidden="true"></span></th>
            <th aria-label="${escapeHtml(l10n('findingsDash.findings.colActionsAria'))}" scope="col"></th>
          </tr>
        </thead>
        <tbody>${buildTableBody(input.sections, input.pageSize)}</tbody>
      </table>
      ${buildOverflowNote(input)}
    </div>
  </section>`;
}

function buildFindingsMeta(input: ViolationsDashboardHtmlInput): string {
  const parts: string[] = [l10n('findingsDash.findings.metaShown', { filtered: String(input.filteredCount) })];
  if (input.totalRawAfterDisable !== input.filteredCount) {
    parts.push(l10n('findingsDash.findings.metaAfterDisable', { total: String(input.totalRawAfterDisable) }));
  }
  if (input.truncatedSource) {
    parts.push(l10n('findingsDash.findings.metaSourceCap', { max: String(input.maxSourceViolations) }));
  }
  parts.push(l10n('findingsDash.findings.metaGroupedBy', { mode: input.groupBy }));
  return parts.join(' · ');
}

function buildOverflowNote(input: ViolationsDashboardHtmlInput): string {
  if (!input.truncatedSource) return '';
  return `<p class="overflow-note">
    <span>${escapeHtml(l10n('findingsDash.findings.overflowNote', { max: String(input.maxSourceViolations) }))}</span>
    <button type="button" class="link" id="run-again" data-run-analysis>${escapeHtml(l10n('findingsDash.findings.runAgain'))}</button>
  </p>`;
}

function buildTableBody(sections: DashboardSection[], pageSize: number): string {
  return sections.map((sec, idx) => buildSectionRows(sec, pageSize, idx === 0)).join('');
}

function buildSectionRows(sec: DashboardSection, pageSize: number, openByDefault: boolean): string {
  const title = escapeHtml(sectionTitle(sec));
  const total = sectionCount(sec);
  const groupId = `grp-${escapeHtml(sec.kind === 'severity' ? sec.severity : sec.label)}`;
  const expanded = openByDefault ? 'true' : 'true';
  const rows = sec.files
    .flatMap((fb) => fb.violations.slice(0, pageSize).map((v) => renderFindingRow(v, fb.filePath)))
    .join('');
  return `<tr class="group-row" data-group="${groupId}" aria-expanded="${expanded}" tabindex="0">
    <td colspan="6">
      <span class="gtitle"><span class="chev">▾</span><span>${title}</span></span>
      <span class="gcount">${total}</span>
    </td>
  </tr>
  ${rows}`;
}

function renderFindingRow(v: Violation, filePath: string): string {
  const fileAttr = encodeURIComponent(v.file ?? filePath);
  const line = v.line ?? 1;
  const sev = (v.severity ?? 'info').toLowerCase();
  const rule = escapeHtml(v.rule);
  const msg = escapeHtml(v.message ?? '');
  const fileLabel = escapeHtml(filePath);
  return `<tr class="frow" data-sev="${escapeHtml(sev)}" data-rule="${escapeHtml(v.rule)}" data-line="${line}" data-file="${fileAttr}" tabindex="0">
    <td class="col-sel-bulk"><input type="checkbox" class="bulk-row-cb" data-file="${fileAttr}" data-line="${line}" data-rule="${escapeHtml(v.rule)}" aria-label="${escapeHtml(l10n('findingsDash.findings.selectRowAria'))}"></td>
    <td class="col-sev"><span class="sev-pill sev-${escapeHtml(sev)}">${escapeHtml(sev)}</span></td>
    <td class="col-rule"><span class="rule-tag">${rule}</span></td>
    <td class="col-msg"><div class="vmsg">${msg}</div><div class="kpi-sub" title="${fileLabel}">${fileLabel}</div></td>
    <td class="col-line">${escapeHtml(l10n('findingsDash.findings.linePrefix', { line: String(line) }))}</td>
    <td class="col-actions"><button type="button" class="row-action" data-row-action="copy" title="${escapeHtml(l10n('findingsDash.findings.copyRowTitle'))}">⎘</button></td>
  </tr>`;
}

function buildFindingsEmpty(input: ViolationsDashboardHtmlInput): string {
  const reason = input.totalRawAfterDisable === 0
    ? l10n('findingsDash.findings.emptyNoViolations')
    : l10n('findingsDash.findings.emptyNoMatch');
  const cta = input.totalRawAfterDisable === 0
    ? `<button type="button" class="btn tier-1" id="btn-run-empty" data-run-analysis><span class="glyph">▶</span>${escapeHtml(l10n('toolbar.runAnalysis'))}</button>
       <button type="button" class="btn" id="btn-refresh-empty"><span class="glyph">⟳</span>${escapeHtml(l10n('toolbar.refresh'))}</button>`
    : `<button type="button" class="btn tier-1" id="btn-reset-empty"><span class="glyph">⊘</span>${escapeHtml(l10n('findingsDash.findings.resetFilters'))}</button>
       <button type="button" class="btn" id="btn-run-empty2" data-run-analysis><span class="glyph">▶</span>${escapeHtml(l10n('findingsDash.findings.reRunAnalysis'))}</button>`;
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.findings.sectionAria'))}">
    <div class="findings-wrap">
      <div class="empty-cta">
        <h3>${escapeHtml(reason)}</h3>
        <p>${input.totalRawAfterDisable === 0
          ? escapeHtml(l10n('findingsDash.findings.emptyHintNoData'))
          : escapeHtml(l10n('findingsDash.findings.emptyHintFilters'))}</p>
        <div class="btns">${cta}</div>
      </div>
    </div>
  </section>`;
}

function sectionTitle(sec: DashboardSection): string {
  if (sec.kind === 'severity') {
    return sec.severity.charAt(0).toUpperCase() + sec.severity.slice(1);
  }
  return sec.label;
}

function sectionCount(sec: DashboardSection): number {
  return sec.files.reduce((n, f) => n + f.violations.length, 0);
}

/* ============================================================================
 * Charts — bars + donut (§6.1). Skeleton-on-zero for individual rows;
 * card omitted entirely if every slot is zero (§8.16, §14.6).
 * ========================================================================= */

function buildChartsBlock(input: ViolationsDashboardHtmlInput): string {
  const sevTotal = SEVERITY_ORDER.reduce((n, k) => n + (input.severityCounts[k] ?? 0), 0);
  if (sevTotal === 0) return '';
  // The Impact mix donut was removed: post-collapse it rendered an identical
  // chart to Severity mix on the same row. impactCounts is still populated
  // on input for stored snapshot back-compat but no longer displayed.
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.charts.sectionAria'))}">
    <h2>${escapeHtml(l10n('findingsDash.charts.heading'))} <span class="meta">${escapeHtml(l10n('findingsDash.charts.metaClickSlice'))}</span></h2>
    <div class="charts-grid">
      ${buildMixCard(l10n('findingsDash.charts.severityMix'), SEVERITY_ORDER, input.severityCounts, 'sev')}
    </div>
  </section>`;
}

function buildMixCard(
  title: string,
  order: readonly string[],
  counts: Record<string, number>,
  axis: 'sev' | 'imp',
): string {
  const total = order.reduce((n, k) => n + (counts[k] ?? 0), 0);
  const max = Math.max(1, ...order.map((k) => counts[k] ?? 0));
  const bars = order.map((k) => buildBarRow(axis, k, counts[k] ?? 0, max)).join('');
  const donut = buildDonut(order, counts, axis, total);
  return `<div class="chart-card">
    <h3>${escapeHtml(title)}<span class="count">${total}</span></h3>
    <div class="body">
      <div class="bars">${bars}</div>
      ${donut}
    </div>
  </div>`;
}

function buildBarRow(axis: 'sev' | 'imp', key: string, count: number, max: number): string {
  const width = max > 0 ? Math.round((count / max) * 100) : 0;
  const zero = count === 0 ? ' zero' : '';
  const role = count === 0 ? '' : ' role="button" tabindex="0"';
  return `<div class="bar-row${zero}"${role} data-filter-kind="${axis}" data-filter-value="${escapeHtml(key)}" title="${escapeHtml(l10n('findingsDash.charts.filterBarTitle', { key }))}">
    <span class="bar-label">${escapeHtml(key)}</span>
    <div class="bar-track"><div class="bar-fill ${axis === 'sev' ? `sev-${escapeHtml(key)}` : `imp-${escapeHtml(key)}`}" style="--bar-width:${width}%"></div></div>
    <span class="bar-value">${count}</span>
  </div>`;
}

/** Donut SVG built from arc-length stroke segments. Same dataset as the bars. */
function buildDonut(
  order: readonly string[],
  counts: Record<string, number>,
  axis: 'sev' | 'imp',
  total: number,
): string {
  if (total <= 0) return '';
  const r = 30;
  const circ = 2 * Math.PI * r;
  let offset = 0;
  const segs = order.map((k) => {
    const v = counts[k] ?? 0;
    if (v <= 0) return '';
    const len = (v / total) * circ;
    const seg = `<circle class="seg ${axis}-${escapeHtml(k)}" cx="48" cy="48" r="${r}"
      stroke="var(--accent-${escapeHtml(k)})"
      stroke-dasharray="${len.toFixed(2)} ${(circ - len).toFixed(2)}"
      stroke-dashoffset="${(-offset).toFixed(2)}"
      data-axis="${axis}" data-key="${escapeHtml(k)}">
      <title>${escapeHtml(k)}: ${v}</title>
    </circle>`;
    offset += len;
    return seg;
  }).join('');
  return `<div class="donut-wrap"><div class="donut">
    <svg viewBox="0 0 96 96">${segs}</svg>
    <div class="donut-legend"><div class="total">${total}</div><div class="lbl">${escapeHtml(l10n('findingsDash.charts.donutTotal'))}</div></div>
  </div></div>`;
}

/* ============================================================================
 * Secondary actionable lists — TODOs, HACKS (§14.7).
 * ========================================================================= */

function buildTodoHackBlock(input: ViolationsDashboardHtmlInput): string {
  const snap = input.todoHackSnapshot;
  if (!snap.enabled) {
    return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.todoHack.sectionAria'))}">
      <h2>${escapeHtml(l10n('findingsDash.todoHack.headingDisabled'))} <span class="meta">${escapeHtml(l10n('findingsDash.todoHack.metaDisabled'))}</span></h2>
      <p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.scanOff'))}
        <button type="button" class="link" id="btn-enable-todos-scan">${escapeHtml(l10n('findingsDash.todoHack.enableScan'))}</button></p>
    </section>`;
  }
  const todoBody = renderTodoSubsection(l10n('findingsDash.todoHack.todosLabel'), snap.todos, snap.capped);
  const hackBody = renderTodoSubsection(l10n('findingsDash.todoHack.hacksLabel'), snap.hacks, snap.capped);
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.todoHack.sectionAria'))}">
    <h2>${escapeHtml(l10n('findingsDash.todoHack.heading'))} <span class="count">${snap.todos.length + snap.hacks.length}</span></h2>
    ${todoBody}
    ${hackBody}
  </section>`;
}

function renderTodoSubsection(
  title: string,
  items: Array<{ file: string; line: number; snippet: string }>,
  capped: boolean,
): string {
  if (items.length === 0) {
    return `<p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.subsectionNone', { title }))}</p>`;
  }
  const rows = items.map(renderCompactRow).join('');
  const cap = capped
    ? `<p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.capNote'))}</p>`
    : '';
  return `<div style="margin-bottom:8px">
    <h3 style="margin:6px 0;font-size:.95em;font-weight:600">${escapeHtml(title)} <span class="meta">${items.length}</span></h3>
    <div class="compact-list">${rows}</div>
    ${cap}
  </div>`;
}

function renderCompactRow(item: { file: string; line: number; snippet: string }): string {
  const fileAttr = encodeURIComponent(item.file);
  const line = Math.max(1, item.line);
  const snippet = escapeHtml(item.snippet);
  const file = escapeHtml(item.file);
  return `<div class="crow" role="button" tabindex="0" data-file="${fileAttr}" data-line="${line}">
    <span class="sev-pill sev-note">${escapeHtml(l10n('findingsDash.todoHack.notePill'))}</span>
    <span class="floc" title="${file}">${file}</span>
    <span class="fmsg">${snippet}</span>
    <span class="fline">L${line}</span>
  </div>`;
}

/* ============================================================================
 * Drift Advisor (§14.7) — single section, footer-line when offline.
 * ========================================================================= */

function buildDriftBlock(input: ViolationsDashboardHtmlInput['driftAdvisorSnapshot']): string {
  if (!input.integrationEnabled) {
    return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.drift.sectionAria'))}">
      <h2>${escapeHtml(l10n('findingsDash.drift.headingOff'))} <span class="meta">${escapeHtml(l10n('findingsDash.drift.metaOff'))}</span></h2>
      <p class="footer-line">${escapeHtml(l10n('findingsDash.drift.enableBlurb'))}
        <button type="button" class="link" id="btn-drift-enable">${escapeHtml(l10n('findingsDash.drift.enable'))}</button></p>
    </section>`;
  }
  if (!input.connected) {
    return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.drift.sectionAria'))}">
      <h2>${escapeHtml(l10n('findingsDash.drift.headingNoServer'))} <span class="meta">${escapeHtml(l10n('findingsDash.drift.metaNoServer'))}</span></h2>
      <p class="footer-line">${escapeHtml(l10n('findingsDash.drift.noServerBlurb'))}
        <button type="button" class="link" id="btn-drift-refresh">${escapeHtml(l10n('findingsDash.drift.retry'))}</button>
      </p>
    </section>`;
  }
  if (input.issues.length === 0) {
    return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.drift.sectionAria'))}">
      <h2>${escapeHtml(l10n('findingsDash.drift.headingConnected'))} <span class="meta">${escapeHtml(l10n('findingsDash.drift.metaConnected'))}</span></h2>
      <p class="footer-line">${escapeHtml(l10n('findingsDash.drift.noIssues', { label: input.serverLabel ?? '' }))}
        <button type="button" class="link" id="btn-drift-refresh">${escapeHtml(l10n('findingsDash.drift.refresh'))}</button>
        <button type="button" class="link" id="btn-drift-browser">${escapeHtml(l10n('findingsDash.drift.openBrowser'))}</button>
      </p>
    </section>`;
  }
  const rows = input.issues.map((issue) => {
    const file = issue.file ? escapeHtml(issue.file) : escapeHtml(issue.source);
    const line = issue.line ?? 1;
    const snippet = escapeHtml(issue.message);
    const sev = escapeHtml(issue.severity);
    if (issue.file) {
      return `<div class="crow" role="button" tabindex="0" data-file="${encodeURIComponent(issue.file)}" data-line="${line}">
        <span class="sev-pill sev-${sev}">${sev}</span>
        <span class="floc" title="${file}">${file}</span>
        <span class="fmsg">${snippet}</span>
        <span class="fline">L${line}</span>
      </div>`;
    }
    return `<div class="crow inert">
      <span class="sev-pill sev-${sev}">${sev}</span>
      <span class="floc" title="${file}">${file}</span>
      <span class="fmsg">${snippet}</span>
      <span class="fline">—</span>
    </div>`;
  }).join('');
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.drift.sectionAria'))}">
    <h2>${escapeHtml(l10n('findingsDash.drift.headingIssues'))} <span class="count">${input.issues.length}</span> <span class="meta">${escapeHtml(input.serverLabel ?? '')}</span></h2>
    <div class="compact-list">${rows}</div>
    <p class="footer-line">
      <button type="button" class="link" id="btn-drift-refresh">${escapeHtml(l10n('findingsDash.drift.refresh'))}</button>
      <button type="button" class="link" id="btn-drift-browser">${escapeHtml(l10n('findingsDash.drift.openBrowser'))}</button>
      <button type="button" class="link" id="btn-drift-disable">${escapeHtml(l10n('findingsDash.drift.disable'))}</button>
    </p>
  </section>`;
}

/* ============================================================================
 * Suppressions & view hides — single bordered band (§14.1, §14.3).
 * Kind counts inline in the meta; only rule + file render as drillable rows.
 * ========================================================================= */

function buildSuppressionsBlock(input: ViolationsDashboardHtmlInput): string {
  const a = input.analyzerSuppressions;
  const v = input.viewSuppressions;
  const kindBreakdown = buildKindBreakdown(a.byKind);
  /* "(export)" qualifier is part of the section title — it tells the user this
     section reflects what is in violations.json, not the live workspace state.
     The kind breakdown sits in the meta span when populated; otherwise the meta
     span stays empty so the header doesn't render an awkward trailing dot. */
  return `<section class="section" id="suppressions-block" aria-label="${escapeHtml(l10n('findingsDash.suppressions.sectionAria'))}">
    <h2>${escapeHtml(l10n('findingsDash.suppressions.headingExport'))} <span class="count">${a.total}</span>${kindBreakdown ? ` <span class="meta">${kindBreakdown}</span>` : ''}</h2>
    <div class="sup-band">${buildAnalyzerBody(a)}</div>
    <h3 style="margin:14px 0 6px;font-size:.98em;font-weight:600">${escapeHtml(l10n('findingsDash.suppressions.viewHidesHeading'))} <span class="meta" style="margin-inline-start:8px;color:var(--vscode-descriptionForeground)">${v.active ? escapeHtml(l10n('findingsDash.suppressions.viewHidesMetaActive')) : escapeHtml(l10n('findingsDash.suppressions.viewHidesMetaNone'))}</span></h3>
    <div class="sup-band">${buildViewBody(v)}</div>
  </section>`;
}

function buildKindBreakdown(byKind: readonly [string, number][]): string {
  if (byKind.length === 0) return '';
  return byKind
    .map(([k, n]) => `${escapeHtml(prettifyAnalyzerKindToken(k))} ${n}`)
    .join(' · ');
}

function buildAnalyzerBody(a: AnalyzerSuppressionsSlice): string {
  if (a.total <= 0) {
    return `<p class="footer-line">${escapeHtml(l10n('findingsDash.suppressions.noneInExport'))}</p>`;
  }
  const totalRow = `<div class="sup-row sup-act" role="button" tabindex="0" data-sup="focus-issues">
    <span class="sup-k plain">${escapeHtml(l10n('findingsDash.suppressions.totalRow'))}</span>
    <span class="sup-n">${a.total}</span>
  </div>`;
  const ruleBody = renderSupRows(a.byRule, 'rule');
  const fileBody = renderSupRows(a.byFile, 'file');
  return `${totalRow}
    <details class="sup-disclosure" open><summary>${escapeHtml(l10n('findingsDash.suppressions.byRule', { count: String(a.byRule.length) }))}</summary>${ruleBody}</details>
    <details class="sup-disclosure"><summary>${escapeHtml(l10n('findingsDash.suppressions.byFile', { count: String(a.byFile.length) }))}</summary>${fileBody}</details>`;
}

function renderSupRows(entries: readonly [string, number][], kind: 'rule' | 'file'): string {
  if (entries.length === 0) {
    return `<p class="footer-line">${escapeHtml(l10n('findingsDash.suppressions.noEntries'))}</p>`;
  }
  return entries
    .map(([key, count]) => {
      const enc = encodeURIComponent(key);
      const label = escapeHtml(key);
      const dataAttr = kind === 'rule' ? `data-rule="${enc}"` : `data-file="${enc}"`;
      return `<div class="sup-row sup-act" role="button" tabindex="0" data-sup="${kind}" ${dataAttr}>
        <span class="sup-k">${label}</span>
        <span class="sup-n">${count}</span>
      </div>`;
    })
    .join('');
}

function buildViewBody(v: ViewSuppressionsSlice): string {
  if (!v.active) {
    return `<p class="footer-line">${escapeHtml(l10n('findingsDash.suppressions.nothingHidden'))}</p>`;
  }
  const counts = [
    v.folderCount ? l10n('findingsDash.suppressions.folderPattern', { count: String(v.folderCount) }) : '',
    v.fileCount ? l10n('findingsDash.suppressions.filePattern', { count: String(v.fileCount) }) : '',
    v.ruleCount ? l10n('findingsDash.suppressions.ruleGlobal', { count: String(v.ruleCount) }) : '',
    v.ruleInFileEntryCount ? l10n('findingsDash.suppressions.perFileRules', { count: String(v.ruleInFileEntryCount) }) : '',
    v.severityCount ? l10n('findingsDash.suppressions.severityHides', { count: String(v.severityCount) }) : '',
    v.impactCount ? l10n('findingsDash.suppressions.impactHides', { count: String(v.impactCount) }) : '',
  ]
    .filter(Boolean)
    .join(' · ');
  const parts: string[] = [];
  parts.push(`<p class="footer-line">${escapeHtml(l10n('findingsDash.suppressions.activeHides', { counts }))}</p>`);
  parts.push(`<p class="footer-line">${escapeHtml(l10n('findingsDash.suppressions.viewHidesFooter'))}
    <button type="button" class="link" id="btn-clear-view-sup">${escapeHtml(l10n('findingsDash.suppressions.clearViewHides'))}</button></p>`);
  parts.push(renderListBlock(l10n('findingsDash.suppressions.foldersSample'), v.sampleFolders));
  parts.push(renderListBlock(l10n('findingsDash.suppressions.filesSample'), v.sampleFiles));
  parts.push(renderListBlock(l10n('findingsDash.suppressions.rulesSample'), v.sampleRules));
  if (v.sampleRuleInFileLines.length > 0) {
    parts.push(renderListBlock(l10n('findingsDash.suppressions.perFileRulesSample'), v.sampleRuleInFileLines));
  }
  return parts.filter(Boolean).join('\n');
}

function renderListBlock(title: string, items: readonly string[]): string {
  if (items.length === 0) return '';
  // §7.1 — Same data type (rule names / file paths) must use the same element
  // across rows. The findings table renders rule names as <span class="rule-tag">,
  // so the suppressions list must too. <code> carries a default monospace +
  // background tint that made suppression rows look pre-highlighted compared
  // to findings rows of the same shape.
  const lis = items.map((s) => `<li><span class="rule-tag">${escapeHtml(s)}</span></li>`).join('');
  return `<p class="footer-line"><strong>${escapeHtml(title)}</strong></p><ul class="sup-ul">${lis}</ul>`;
}

function prettifyAnalyzerKindToken(token: string): string {
  if (!token) return l10n('findingsDash.unknownAnalyzerKind');
  return token
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/* ============================================================================
 * Inline client script — debounced filters, sortable table, KPI clicks,
 * chip removal, group-row collapse, save/copy, drift, suppressions.
 * ========================================================================= */

function buildScript(): string {
  const FD = findingsDashScriptStrings();
  return `(function () {
  var vscode = acquireVsCodeApi();
  var FD = ${JSON.stringify(FD)};
  var filterDebounce = null;
  var isAnalyzing = false;

  // §15.3 — polite live-region announcer for filter / sort state changes.
  ${getAnnouncerScript()}

  function readState() {
    var gb = document.getElementById('groupBy');
    var tf = document.getElementById('textFilter');
    var sev = [];
    document.querySelectorAll('.seg-btn[data-sev][aria-pressed="true"]').forEach(function (el) {
      sev.push(el.getAttribute('data-sev'));
    });
    // Impact pills were removed (post-collapse impact mirrors severity).
    // Send the default all-impacts-on list so the host-side merge that
    // still accepts an impacts field treats it as "no filter applied".
    return {
      type: 'dashboardUpdate',
      groupBy: gb ? gb.value : undefined,
      textFilter: tf ? tf.value : '',
      severities: sev.length ? sev : ${JSON.stringify(DEFAULT_SEVERITIES)},
      impacts: ${JSON.stringify(DEFAULT_IMPACTS)}
    };
  }

  function pushState(immediate) {
    if (filterDebounce) { clearTimeout(filterDebounce); filterDebounce = null; }
    if (immediate) { vscode.postMessage(readState()); announceFilterState(); return; }
    filterDebounce = setTimeout(function () {
      vscode.postMessage(readState());
      announceFilterState();
    }, 220);
  }

  /* Gauge "pending" state — dims the ring and hides the grade while analysis
     is in flight, so a transient not-yet-settled health score never flashes a
     misleading grade (the A→E whiplash). No explicit clear is needed for the
     normal path: every host rebuild ships a fresh gauge with data-pending
     already "false", so the settled grade reveals itself on the next paint. */
  function setGaugePending(on) {
    var g = document.querySelector('.hero-gauge');
    if (g) g.setAttribute('data-pending', on ? 'true' : 'false');
  }

  function setAnalysisProgress(running, metaText) {
    isAnalyzing = running;
    setGaugePending(running);
    var box = document.getElementById('analysis-progress');
    var label = document.getElementById('analysis-progress-label');
    var meta = document.getElementById('analysis-progress-meta');
    if (box) box.hidden = !running;
    if (label) label.textContent = running ? FD.analysisRunning : FD.analysisComplete;
    if (meta) {
      meta.textContent = metaText || (running ? FD.metaRunning : FD.metaDone);
    }
    document.querySelectorAll('[data-run-analysis]').forEach(function (el) {
      if ('disabled' in el) {
        el.disabled = running;
      }
      if (running) {
        el.setAttribute('aria-disabled', 'true');
      } else {
        el.removeAttribute('aria-disabled');
      }
    });
  }

  function triggerRunAnalysis() {
    if (isAnalyzing) return;
    setAnalysisProgress(true);
    vscode.postMessage({ type: 'runAnalysis' });
  }

  // §15.3 — describe the current filter state to screen readers so users
  // navigating without a mouse know which constraints are active.
  function announceFilterState() {
    var s = readState();
    var parts = [];
    if (s.textFilter) { parts.push(FD.announceSearchVerb + ' ' + s.textFilter); }
    var sevDefaults = ${JSON.stringify(DEFAULT_SEVERITIES)}.length;
    if (s.severities.length !== sevDefaults) {
      parts.push(s.severities.length + ' ' + FD.severitiesNoun);
    }
    // Impact divergence-announcement was removed alongside the impact
    // pill UI; readState always emits the default all-impacts-on list,
    // so the branch would be permanently dead.
    if (parts.length === 0) {
      announce(FD.announceCleared);
    } else {
      announce(FD.filtersPrefix + ' ' + parts.join(', '));
    }
  }

  /* Filter inputs */
  var gb = document.getElementById('groupBy');
  if (gb) gb.addEventListener('change', function () { pushState(true); });
  var tf = document.getElementById('textFilter');

  /* §8.5.2 — recent-filters popover. Stored in sessionStorage so the list
     survives within the current panel session; cross-session persistence
     is tracked in plan/UX_GUIDELINES.md (Part B). */
  var recentEl = document.getElementById('findings-recent');
  var recentListEl = document.getElementById('findings-recent-list');
  var recentClearAllEl = document.getElementById('findings-recent-clear');
  var RECENT_KEY = 'saropa.findings.recentFilters';
  var RECENT_CAP = 10;
  var RECENT_DEBOUNCE_MS = 800;
  var recentTimer = null;

  function findingsRecentPersist() {
    try { vscode.postMessage({ type: 'saveFindingsRecent', queries: recentLoad() }); } catch (_) {}
  }

  window.addEventListener('message', function (event) {
    var m = event.data;
    if (m && m.type === 'hydrateRecentSearches' && Array.isArray(m.queries) && m.queries.length > 0) {
      recentSave(m.queries.slice(0, RECENT_CAP), true);
      recentRender();
    }
  });

  function recentLoad() {
    try {
      var raw = sessionStorage.getItem(RECENT_KEY);
      if (!raw) return [];
      var parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.filter(function (s) { return typeof s === 'string'; }) : [];
    } catch (e) { return []; }
  }
  function recentSave(list, skipHost) {
    try { sessionStorage.setItem(RECENT_KEY, JSON.stringify(list)); } catch (e) { /* best-effort */ }
    if (!skipHost) { findingsRecentPersist(); }
  }
  function recentRecord(q) {
    var t = (q || '').trim();
    if (!t) return;
    var existing = recentLoad().filter(function (s) { return s.toLowerCase() !== t.toLowerCase(); });
    existing.unshift(t);
    recentSave(existing.slice(0, RECENT_CAP));
  }
  function recentRemove(q) {
    recentSave(recentLoad().filter(function (s) { return s !== q; }));
    recentRender();
  }
  function recentClearAll() { recentSave([]); recentRender(); recentHide(); }
  function recentEsc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function recentRender() {
    if (!recentListEl) return;
    var list = recentLoad();
    if (list.length === 0) { recentListEl.innerHTML = ''; return; }
    recentListEl.innerHTML = list.map(function (q) {
      var s = recentEsc(q);
      return '<li>' +
        '<button type="button" class="recent-pick" data-query="' + s + '">' + s + '</button>' +
        '<button type="button" class="recent-remove" data-query="' + s +
        '" aria-label="' + FD.removeRecentAriaPrefix + ' ' + s + '" title="' + FD.removeRecentTitle + '">&times;</button>' +
        '</li>';
    }).join('');
  }
  function recentShow() {
    if (!recentEl) return;
    var list = recentLoad();
    if (list.length === 0) { recentEl.hidden = true; return; }
    recentRender();
    recentEl.hidden = false;
  }
  function recentHide() { if (recentEl) recentEl.hidden = true; }
  function recentMaybeShow() {
    if (!tf) return;
    if (document.activeElement === tf && !tf.value.trim()) recentShow();
    else recentHide();
  }

  if (tf) {
    tf.addEventListener('input', function () {
      pushState(false);
      recentMaybeShow();
      // Debounced commit so transient keystrokes don't spam the recent list.
      if (recentTimer) clearTimeout(recentTimer);
      var snapshot = tf.value;
      recentTimer = setTimeout(function () {
        recentTimer = null;
        if (snapshot && tf.value === snapshot) recentRecord(snapshot);
      }, RECENT_DEBOUNCE_MS);
    });
    tf.addEventListener('focus', recentMaybeShow);
    tf.addEventListener('blur', function () { setTimeout(recentHide, 120); });
    tf.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && tf.value.trim()) { recentRecord(tf.value); recentHide(); }
      else if (e.key === 'Escape' && recentEl && !recentEl.hidden) { e.preventDefault(); recentHide(); }
    });
  }
  if (recentListEl) {
    recentListEl.addEventListener('click', function (e) {
      var t = e.target;
      if (!t || !t.dataset || !t.dataset.query) return;
      var q = t.dataset.query;
      if (t.classList.contains('recent-pick')) {
        if (tf) { tf.value = q; pushState(true); recentRecord(q); recentHide(); tf.focus(); }
      } else if (t.classList.contains('recent-remove')) {
        e.stopPropagation();
        recentRemove(q);
        if (tf) tf.focus();
      }
    });
  }
  if (recentClearAllEl) recentClearAllEl.addEventListener('click', recentClearAll);
  document.addEventListener('click', function (e) {
    if (!recentEl || recentEl.hidden) return;
    var wrapper = tf && tf.closest ? tf.closest('.text-filter-field') : null;
    if (wrapper && !wrapper.contains(e.target)) recentHide();
  });

  var tfClear = document.getElementById('textFilterClear');
  if (tfClear) tfClear.addEventListener('click', function () {
    if (tf) { tf.value = ''; pushState(true); recentMaybeShow(); }
  });
  // Impact-pill click branch was removed alongside the impact toolbar row.
  // The selector is now severity-only.
  document.querySelectorAll('.seg-btn[data-sev]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var pressed = btn.getAttribute('aria-pressed') === 'true';
      btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
      pushState(true);
    });
  });

  /* Toolbar primary actions */
  bindClick('btn-run', triggerRunAnalysis);
  // Refresh was promoted out of the toolbar (it was indistinguishable from
  // Run analysis but only re-rendered from disk). The hidden #btn-refresh
  // stub keeps test selectors / keybindings resolvable; the user-clickable
  // replacement is the "Reload from disk" item in the More menu's System
  // section. Both fire the same {type:'refresh'} message so any existing
  // host-side handler keeps working unchanged.
  bindClick('btn-refresh', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-reload-disk', function () {
    vscode.postMessage({ type: 'refresh' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  // Copy JSON / Save report now live inside the More-actions overflow menu
  // (§14.4 toolbar budget). Auto-close the menu after click so the user is
  // not left with an open dropdown obscuring the table.
  bindClick('btn-copy', function () {
    vscode.postMessage({ type: 'copyFilteredJson' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  bindClick('btn-save', function () {
    vscode.postMessage({ type: 'saveFilteredJson' });
    var det = document.querySelector('details.more');
    if (det) det.removeAttribute('open');
  });
  bindClick('btn-refresh-extension', function () {
    vscode.postMessage({ type: 'paletteCommand', commandId: 'saropaLints.refresh' });
  });
  bindClick('btn-run-empty', triggerRunAnalysis);
  bindClick('btn-run-empty2', triggerRunAnalysis);
  bindClick('btn-refresh-empty', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-reset-empty', function () { vscode.postMessage({ type: 'resetFilters' }); });
  bindClick('run-again', triggerRunAnalysis);

  /* Supplementary-counts toggle pills (#224). Single delegated click handler
     for all three sources (other / todos / scanner) so we do not need to
     re-bind after every dashboard rebuild — the pills come and go as their
     state changes. Activate on Enter/Space too so the role="button" pills
     are keyboard-operable.  */
  function handleToggleEvent(target) {
    if (!target || typeof target.closest !== 'function') return;
    var pill = target.closest('.pill.toggle');
    if (!pill) return;
    var source = pill.getAttribute('data-toggle');
    if (!source) return;
    vscode.postMessage({ type: 'toggleSupplementary', source: source });
  }
  document.addEventListener('click', function (e) { handleToggleEvent(e.target); });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    var t = e.target;
    if (!t || typeof t.closest !== 'function') return;
    if (!t.closest('.pill.toggle')) return;
    e.preventDefault();
    handleToggleEvent(t);
  });

  /* More actions menu */
  document.querySelectorAll('.menu-item[data-palette-cmd]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var id = btn.getAttribute('data-palette-cmd');
      if (id) vscode.postMessage({ type: 'paletteCommand', commandId: id });
      var det = btn.closest('details.more');
      if (det) det.removeAttribute('open');
    });
  });
  /* Close menu on outside click */
  document.addEventListener('click', function (e) {
    document.querySelectorAll('details.more[open]').forEach(function (det) {
      if (!det.contains(e.target)) det.removeAttribute('open');
    });
  });

  /* KPI cards as preset filters */
  document.querySelectorAll('.kpi-card.interactive').forEach(function (card) {
    function fire() {
      var kind = card.getAttribute('data-kpi-kind');
      var v = card.getAttribute('data-kpi-value') || '';
      if (kind === 'reset') {
        vscode.postMessage({ type: 'resetFilters' });
        return;
      }
      if (kind === 'sev') {
        document.querySelectorAll('.seg-btn[data-sev]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-sev') === v ? 'true' : 'false');
        });
        pushState(true);
        return;
      }
      // KpiSpec.filter.kind === 'imp' branch was removed: collectKpiCards()
      // never emits an 'imp' KPI card since the Impact axis was retired.
      if (kind === 'top-rule') {
        var input = document.getElementById('textFilter');
        if (input) { input.value = v; pushState(true); }
      }
    }
    card.addEventListener('click', fire);
    card.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
    });
  });

  /* Chart bar clicks */
  document.querySelectorAll('.bar-row[role="button"]').forEach(function (row) {
    function fire() {
      var kind = row.getAttribute('data-filter-kind');
      var v = row.getAttribute('data-filter-value');
      // Only severity bars emit clickable rows now — the Impact-mix donut /
      // bars are gone.
      if (kind === 'sev') {
        document.querySelectorAll('.seg-btn[data-sev]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-sev') === v ? 'true' : 'false');
        });
      }
      pushState(true);
    }
    row.addEventListener('click', fire);
    row.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
    });
  });

  /* Active-filter chip removal */
  document.querySelectorAll('.chip').forEach(function (chip) {
    var x = chip.querySelector('.x');
    if (!x) return;
    x.addEventListener('click', function (e) {
      e.stopPropagation();
      var token = chip.getAttribute('data-chip-token') || '';
      if (token === 'text') {
        if (tf) { tf.value = ''; pushState(true); }
      } else if (token.indexOf('sev:') === 0) {
        var sv = token.slice(4);
        var btn = document.querySelector('.seg-btn[data-sev="' + sv + '"]');
        if (btn) { btn.setAttribute('aria-pressed', 'true'); pushState(true); }
      }
      // No 'imp:' branch — impact chips are no longer emitted from
      // buildChipStrip, so any imp: token in stored state is stale and
      // a no-op is the right behavior.
    });
  });
  bindClick('chipsClearAll', function () { vscode.postMessage({ type: 'resetFilters' }); });

  /* Group-row collapse / expand */
  document.querySelectorAll('tr.group-row').forEach(function (gr) {
    function toggle() {
      var open = gr.getAttribute('aria-expanded') !== 'false';
      gr.setAttribute('aria-expanded', open ? 'false' : 'true');
      var sib = gr.nextElementSibling;
      while (sib && !sib.classList.contains('group-row')) {
        sib.style.display = open ? 'none' : '';
        sib = sib.nextElementSibling;
      }
    }
    gr.addEventListener('click', toggle);
    gr.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggle(); }
    });
  });
  bindClick('expand-all', function () {
    document.querySelectorAll('tr.group-row[aria-expanded="false"]').forEach(function (gr) { gr.click(); });
  });
  bindClick('collapse-all', function () {
    document.querySelectorAll('tr.group-row[aria-expanded="true"]').forEach(function (gr) { gr.click(); });
  });

  /* Sortable table headers — primary click sets key; Shift+click stacks a
     secondary tie-breaker (shows ① / ② badges). */
  var sortLevels = [];
  function rowSortVal(tr, sk) {
    var sevOrder = { error: 0, warning: 1, info: 2, note: 3 };
    if (sk === 'sev') return sevOrder[tr.getAttribute('data-sev')] || 99;
    if (sk === 'rule') return tr.getAttribute('data-rule') || '';
    if (sk === 'line') return parseInt(tr.getAttribute('data-line') || '0', 10);
    return (tr.querySelector('.vmsg') || {}).textContent || '';
  }
  function cmpRows(a, b, sk, asc) {
    var av = rowSortVal(a, sk);
    var bv = rowSortVal(b, sk);
    if (av < bv) return asc ? -1 : 1;
    if (av > bv) return asc ? 1 : -1;
    return 0;
  }
  function updateSortHeaderUi() {
    document.querySelectorAll('.findings-table thead th[data-sort]').forEach(function (h) {
      h.setAttribute('aria-sort', 'none');
      var idx = h.querySelector('.sort-idx');
      if (idx) idx.textContent = '';
    });
    for (var i = 0; i < sortLevels.length && i < 2; i++) {
      var lk = sortLevels[i].key;
      var th = document.querySelector('.findings-table thead th[data-sort="' + lk + '"]');
      if (th) {
        th.setAttribute('aria-sort', sortLevels[i].asc ? 'ascending' : 'descending');
        var idx = th.querySelector('.sort-idx');
        if (idx) idx.textContent = i === 0 ? '①' : '②';
      }
    }
  }
  function sortRowsWithinGroupsMulti() {
    var tbody = document.querySelector('.findings-table tbody');
    if (!tbody || sortLevels.length === 0) return;
    var groups = [];
    var current = null;
    Array.prototype.forEach.call(tbody.children, function (tr) {
      if (tr.classList.contains('group-row')) {
        current = { header: tr, rows: [] };
        groups.push(current);
      } else if (current) {
        current.rows.push(tr);
      }
    });
    groups.forEach(function (g) {
      g.rows.sort(function (a, b) {
        for (var si = 0; si < sortLevels.length; si++) {
          var lv = sortLevels[si];
          var c = cmpRows(a, b, lv.key, lv.asc);
          if (c !== 0) return c;
        }
        return 0;
      });
    });
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    groups.forEach(function (g) {
      tbody.appendChild(g.header);
      g.rows.forEach(function (r) { tbody.appendChild(r); });
    });
    updateBulkUi();
  }

  document.querySelectorAll('.findings-table thead th[data-sort]').forEach(function (th) {
    th.addEventListener('click', function (ev) {
      var sk = th.getAttribute('data-sort');
      if (!sk) return;
      if (ev.shiftKey) {
        if (sortLevels.length === 0) {
          sortLevels = [{ key: sk, asc: true }];
        } else if (sortLevels[0].key === sk) {
          sortLevels[0].asc = !sortLevels[0].asc;
        } else if (sortLevels.length >= 2 && sortLevels[1].key === sk) {
          sortLevels[1].asc = !sortLevels[1].asc;
        } else if (sortLevels.length === 1) {
          sortLevels.push({ key: sk, asc: true });
        } else {
          sortLevels = [sortLevels[0], { key: sk, asc: true }];
        }
      } else {
        if (sortLevels.length && sortLevels[0].key === sk) {
          sortLevels[0].asc = !sortLevels[0].asc;
        } else {
          sortLevels = [{ key: sk, asc: true }];
        }
      }
      updateSortHeaderUi();
      sortRowsWithinGroupsMulti();
    });
  });

  /* Bulk row selection — copy selected violations as JSON without opening each file. */
  var bulkBar = document.getElementById('findings-bulk-bar');
  var bulkCount = document.getElementById('findings-bulk-count');
  var bulkAll = document.getElementById('bulk-select-all');

  function decodeFileAttr(enc) {
    try { return decodeURIComponent(enc || ''); } catch (e2) { return enc || ''; }
  }
  function updateBulkUi() {
    var cbs = document.querySelectorAll('.bulk-row-cb:checked');
    if (!bulkBar || !bulkCount) return;
    var n = cbs.length;
    bulkBar.hidden = n === 0;
    bulkCount.textContent = FD.bulkSelectedTpl.replace(/\{n\}/g, String(n));
    var vis = Array.prototype.filter.call(
      document.querySelectorAll('.bulk-row-cb'),
      function (cb) {
        var row = cb.closest('tr');
        return row && row.style.display !== 'none';
      },
    );
    if (bulkAll) {
      bulkAll.indeterminate = n > 0 && n < vis.length;
      bulkAll.checked = vis.length > 0 && n === vis.length;
    }
  }
  function collectBulkPayload() {
    var out = [];
    document.querySelectorAll('.bulk-row-cb:checked').forEach(function (cb) {
      out.push({
        file: decodeFileAttr(cb.getAttribute('data-file')),
        line: parseInt(cb.getAttribute('data-line') || '1', 10),
        rule: cb.getAttribute('data-rule') || ''
      });
    });
    return out;
  }
  if (bulkAll) {
    bulkAll.addEventListener('change', function () {
      Array.prototype.forEach.call(document.querySelectorAll('.bulk-row-cb'), function (cb) {
        var tr = cb.closest('tr');
        if (tr && tr.style.display === 'none') return;
        cb.checked = bulkAll.checked;
      });
      updateBulkUi();
    });
  }
  bindClick('btn-bulk-copy', function () {
    var pay = collectBulkPayload();
    if (pay.length) {
      vscode.postMessage({ type: 'copyBulkFindings', violations: pay });
    }
  });

  /* Finding-row clicks open the file. Per-row copy posts JSON. */
  bindFRows();
  function bindFRows() {
    document.querySelectorAll('tr.frow').forEach(function (row) {
      row.addEventListener('click', function (e) {
        var t = e.target;
        if (t && t.closest && t.closest('.bulk-row-cb')) return;
        if (t && t.closest && t.closest('.col-sel-bulk')) return;
        if (t && t.getAttribute && t.getAttribute('data-row-action') === 'copy') {
          e.stopPropagation();
          vscode.postMessage({
            type: 'copySingleFinding',
            file: decodeURIComponent(row.getAttribute('data-file') || ''),
            line: parseInt(row.getAttribute('data-line') || '1', 10),
            rule: row.getAttribute('data-rule') || '',
          });
          return;
        }
        openRow(row);
      });
      row.addEventListener('keydown', function (e) {
        var tgt = e.target;
        if (tgt && tgt.closest && tgt.closest('.bulk-row-cb')) return;
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openRow(row); }
      });
    });
    document.querySelectorAll('.crow').forEach(function (row) {
      if (row.classList.contains('inert')) return;
      row.addEventListener('click', function () { openRow(row); });
      row.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openRow(row); }
      });
    });
    document.querySelectorAll('.bulk-row-cb').forEach(function (cb) {
      cb.addEventListener('click', function (e) {
        e.stopPropagation();
        updateBulkUi();
      });
    });
    updateBulkUi();
  }
  function openRow(row) {
    var enc = row.getAttribute('data-file');
    var ln = parseInt(row.getAttribute('data-line') || '1', 10);
    if (!enc) return;
    try {
      vscode.postMessage({ type: 'openFile', file: decodeURIComponent(enc), line: ln });
    } catch (e) { /* ignore */ }
  }

  /* Top Rules table — Hide and Disable buttons post different message types.
     Both rely on the dashboard rebuilding via the issuesProvider tree-data
     event (Hide) or the post-disable analysis re-run (Disable), so we don't
     manipulate the DOM directly here. */
  document.querySelectorAll('.top-rules-table tr.trow').forEach(function (row) {
    var enc = row.getAttribute('data-rule-enc') || '';
    var rule = '';
    try { rule = decodeURIComponent(enc); } catch (err) { rule = ''; }
    if (!rule) return;
    var hideBtn = row.querySelector('button[data-row-action="hide-rule"]');
    if (hideBtn) {
      hideBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        vscode.postMessage({ type: 'suppressRule', rule: rule });
      });
    }
    var disableBtn = row.querySelector('button[data-row-action="disable-rule"]');
    if (disableBtn) {
      disableBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        vscode.postMessage({ type: 'disableRule', rule: rule });
      });
    }
  });

  /* Top Rules table — click a header to sort; click a row to expand its full
     message + affected-file breakdown. Sorting moves each detail row with its
     parent so the disclosure stays glued to the right rule. Rank is left
     unsortable on purpose (it is a stable noise-rank position label). */
  (function () {
    var tbl = document.querySelector('.top-rules-table');
    if (!tbl) return;
    var tbody = tbl.querySelector('tbody');
    if (!tbody) return;
    var sevOrder = { error: 0, warning: 1, info: 2, note: 3 };
    var sortState = { key: null, asc: true };

    function sortVal(tr, key) {
      if (key === 'count') return parseInt(tr.getAttribute('data-count') || '0', 10);
      if (key === 'sev') {
        var s = sevOrder[tr.getAttribute('data-sev')];
        return s == null ? 99 : s;
      }
      return (tr.getAttribute('data-rule') || '').toLowerCase();
    }
    function detailFor(tr) {
      var n = tr.nextElementSibling;
      return (n && n.classList.contains('trow-detail')) ? n : null;
    }
    function applySort(key) {
      if (sortState.key === key) { sortState.asc = !sortState.asc; }
      else { sortState.key = key; sortState.asc = true; }
      var asc = sortState.asc;
      var pairs = [];
      Array.prototype.forEach.call(tbody.querySelectorAll('tr.trow'), function (tr) {
        pairs.push({ row: tr, detail: detailFor(tr) });
      });
      pairs.sort(function (a, b) {
        var av = sortVal(a.row, key), bv = sortVal(b.row, key);
        if (av < bv) return asc ? -1 : 1;
        if (av > bv) return asc ? 1 : -1;
        return 0;
      });
      while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
      pairs.forEach(function (p) {
        tbody.appendChild(p.row);
        if (p.detail) tbody.appendChild(p.detail);
      });
      tbl.querySelectorAll('thead th[data-sort]').forEach(function (h) {
        var hk = h.getAttribute('data-sort');
        h.setAttribute('aria-sort', hk === key ? (asc ? 'ascending' : 'descending') : 'none');
      });
    }
    tbl.querySelectorAll('thead th[data-sort]').forEach(function (th) {
      th.addEventListener('click', function () {
        var k = th.getAttribute('data-sort');
        if (k) applySort(k);
      });
    });

    function toggleRow(tr) {
      var detail = detailFor(tr);
      if (!detail) return;
      var open = tr.getAttribute('aria-expanded') === 'true';
      tr.setAttribute('aria-expanded', open ? 'false' : 'true');
      detail.hidden = open;
      var chev = tr.querySelector('.trow-chev');
      if (chev) chev.textContent = open ? '▸' : '▾';
    }
    Array.prototype.forEach.call(
      tbody.querySelectorAll('tr.trow[data-expandable="true"]'),
      function (tr) {
        tr.addEventListener('click', function (e) {
          // Hide / Disable buttons own their own clicks — never toggle on them.
          if (e.target && e.target.closest && e.target.closest('.row-action')) return;
          toggleRow(tr);
        });
        tr.addEventListener('keydown', function (e) {
          if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleRow(tr); }
        });
      },
    );

    /* Affected-file rows in the expander deep-link into the source file. */
    Array.prototype.forEach.call(tbl.querySelectorAll('.trd-file[data-file]'), function (li) {
      function open() {
        try {
          vscode.postMessage({
            type: 'openFile',
            file: decodeURIComponent(li.getAttribute('data-file') || ''),
            line: parseInt(li.getAttribute('data-line') || '1', 10),
          });
        } catch (e) { /* ignore */ }
      }
      li.addEventListener('click', open);
      li.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
      });
    });
  })();

  /* TODOs / Drift section action bindings */
  bindClick('btn-enable-todos-scan', function () { vscode.postMessage({ type: 'enableTodosScan' }); });
  bindClick('btn-drift-refresh', function () { vscode.postMessage({ type: 'driftRefresh' }); });
  bindClick('btn-drift-enable', function () { vscode.postMessage({ type: 'driftEnable' }); });
  bindClick('btn-drift-disable', function () { vscode.postMessage({ type: 'driftDisable' }); });
  bindClick('btn-drift-browser', function () { vscode.postMessage({ type: 'driftOpenBrowser' }); });

  /* Suppressions block bindings */
  var supRoot = document.getElementById('suppressions-block');
  if (supRoot) {
    supRoot.querySelectorAll('.sup-row.sup-act').forEach(function (row) {
      function fire() {
        var sup = row.getAttribute('data-sup');
        if (sup === 'focus-issues') { vscode.postMessage({ type: 'focusIssues' }); return; }
        if (sup === 'rule') {
          var r = row.getAttribute('data-rule');
          if (!r) return;
          try { vscode.postMessage({ type: 'focusIssuesForRules', rules: [decodeURIComponent(r)] }); } catch (e) { /* ignore */ }
          return;
        }
        if (sup === 'file') {
          var f = row.getAttribute('data-file');
          if (!f) return;
          try { vscode.postMessage({ type: 'openFileAndFocusIssues', filePath: decodeURIComponent(f) }); } catch (e) { /* ignore */ }
        }
      }
      row.addEventListener('click', fire);
      row.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); fire(); }
      });
    });
    bindClick('btn-clear-view-sup', function () {
      vscode.postMessage({ type: 'clearWorkspaceSuppressions' });
    });
  }

  function bindClick(id, fn) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('click', fn);
  }

  window.addEventListener('message', function (event) {
    var msg = event && event.data ? event.data : null;
    if (!msg) return;
    // Host posts this on the first diagnostics change of a burst (analysis is
    // streaming results in); the subsequent debounced rebuild reveals the
    // settled grade. Keeps the gauge honest even for runs the dashboard did
    // not initiate (e.g. analyze-on-save).
    if (msg.type === 'gaugePending') { setGaugePending(!!msg.pending); return; }
    if (msg.type !== 'analysisProgress') return;
    if (msg.status === 'started') {
      setAnalysisProgress(true, FD.metaStartedDetail);
      announce(FD.announceStarted);
      return;
    }
    if (msg.status === 'completed') {
      setAnalysisProgress(false, FD.metaDone);
      announce(FD.announceComplete);
      return;
    }
    if (msg.status === 'failed') {
      setAnalysisProgress(false, FD.metaFailed);
      announce(FD.announceFailed);
    }
  });

  /* Full-width toggle (guideline §4) — flips body[data-full-width] so users on ultrawide
     monitors can opt out of the readability max-width set in the stylesheet. */
  ${getFullWidthToggleScript()}

  /* §15.2 — page-level keyboard shortcuts advertised in the overlay.
     '/' focuses the text filter from anywhere; 'Esc' on a focused, non-empty
     filter clears it. Skip when the user is already typing in another input
     so the global handler doesn't steal the slash key from a search box on a
     popover or future modal. */
  document.addEventListener('keydown', function (e) {
    var tag = e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '';
    var isEditable = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === '/' && !isEditable) {
      e.preventDefault();
      var input = document.getElementById('textFilter');
      if (input) { input.focus(); input.select && input.select(); }
    } else if (e.key === 'Escape' && e.target === tf && tf && tf.value) {
      e.preventDefault();
      tf.value = '';
      pushState(true);
    }
  });
  ${getKeyboardShortcutsScript()}
})();`;
}

/* ============================================================================
 * Composer — density-first DOM order (§14.7).
 * ========================================================================= */

export function renderViolationsDashboardHtml(input: ViolationsDashboardHtmlInput): string {
  const nonce = createWebviewCspNonce();
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8" />
  <title>${escapeHtml(l10n('findingsDash.documentTitle'))}</title>
  <!-- 'unsafe-inline' on style-src: the severity-mix chart bars set their width
       via an inline style="--bar-width:N%" attribute. CSP nonces authorize
       <style> blocks, not style attributes — without 'unsafe-inline' the var is
       dropped and every bar renders at zero width. (The hero gauge no longer
       needs this: its fill is now a static SVG stroke-dasharray attribute.) -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';" />
  <style nonce="${nonce}">${getViolationsDashboardStyles()}${getKeyboardShortcutsStyles()}</style>
</head><body>
  ${buildSkipLink('findings-table', l10n('findingsDash.skipToFindings'))}
  ${buildAnnouncer()}
  <header>${buildHero(input)}</header>
  ${buildKpiCards(input)}
  ${buildToolbar(input)}
  ${buildAnalysisProgress()}
  <main id="findings-table" tabindex="-1">
    ${buildTopRulesTable(input)}
    ${buildFindingsBlock(input)}
  </main>
  <aside aria-label="${escapeHtml(l10n('findingsDash.secondaryAsideLabel'))}">
    ${buildTodoHackBlock(input)}
    ${buildDriftBlock(input.driftAdvisorSnapshot)}
    ${buildChartsBlock(input)}
    ${buildSuppressionsBlock(input)}
  </aside>
  ${buildKeyboardShortcutsOverlay([
    { key: '/', label: l10n('findingsDash.shortcuts.focusTextFilter') },
    { key: 'Esc', label: l10n('findingsDash.shortcuts.clearTextFilter') },
    { key: 'Enter', label: l10n('findingsDash.shortcuts.activateKpi') },
    { key: 'Space', label: l10n('findingsDash.shortcuts.activateKpiSpace') },
    { key: '?', label: l10n('findingsDash.shortcuts.showOverlay') },
  ])}
  <script nonce="${nonce}">${buildScript()}</script>
</body></html>`;
}

/** Editor-area empty state when no `violations.json` exists yet (nonce CSP + primary actions). */
export function buildFindingsEmptyStateHtml(message: string): string {
  const nonce = createWebviewCspNonce();
  const esc = escapeHtml(message);
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8"/>
  <!-- 'unsafe-inline' on style-src: kept consistent with the populated dashboard CSP
       so future inline-style additions (e.g. gauges, sparklines) work without a CSP
       regression that re-creates the gauge-renders-as-a-dot bug. -->
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}' 'unsafe-inline'; script-src 'nonce-${nonce}';"/>
  <style nonce="${nonce}">${getFindingsEmptyStateStyles()}</style>
</head><body>
  <div class="empty-hero">
    <h1>${escapeHtml(l10n('findingsDash.pageTitle'))}</h1>
    <p>${esc}</p>
    <p>${escapeHtml(l10n('findingsDash.emptyState.hintAfterMessage'))}</p>
    <div class="btns">
      <button type="button" class="primary" id="btn-run" data-run-analysis>${escapeHtml(l10n('toolbar.runAnalysis'))}</button>
      <button type="button" id="btn-refresh">${escapeHtml(l10n('findingsDash.emptyState.refreshDisk'))}</button>
    </div>
    ${buildAnalysisProgress()}
  </div>
  <script nonce="${nonce}">
    (function () {
      var vscode = acquireVsCodeApi();
      var running = false;
      function setRunning(on) {
        running = on;
        var box = document.getElementById('analysis-progress');
        if (box) box.hidden = !on;
        var btn = document.getElementById('btn-run');
        if (btn) btn.disabled = on;
      }
      document.getElementById('btn-run').addEventListener('click', function () {
        if (running) return;
        setRunning(true);
        vscode.postMessage({ type: 'runAnalysis' });
      });
      document.getElementById('btn-refresh').addEventListener('click', function () {
        vscode.postMessage({ type: 'refresh' });
      });
      window.addEventListener('message', function (event) {
        var msg = event && event.data ? event.data : null;
        if (!msg || msg.type !== 'analysisProgress') return;
        if (msg.status === 'started') {
          setRunning(true);
          return;
        }
        if (msg.status === 'completed' || msg.status === 'failed') {
          setRunning(false);
        }
      });
    })();
  </script>
</body></html>`;
}

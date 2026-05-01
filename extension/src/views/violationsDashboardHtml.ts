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
}

const DEFAULT_SEVERITIES: readonly string[] = ['error', 'warning', 'info'];
const DEFAULT_IMPACTS: readonly string[] = ['critical', 'high', 'medium', 'low', 'opinionated'];
const SEVERITY_ORDER: readonly string[] = ['error', 'warning', 'info'];
const IMPACT_ORDER: readonly string[] = ['critical', 'high', 'medium', 'low', 'opinionated'];

function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function groupBySelectOptions(current: GroupByMode): string {
  const labels: Record<GroupByMode, string> = {
    severity: 'Severity',
    file: 'File',
    impact: 'Impact',
    rule: 'Rule',
    owasp: 'OWASP',
    ruleType: 'Rule type',
    ruleStatus: 'Rule status',
  };
  return VIOLATIONS_GROUP_BY_MODES.map((m) => {
    const sel = m === current ? ' selected' : '';
    return `<option value="${escapeHtml(m)}"${sel}>${escapeHtml(labels[m])}</option>`;
  }).join('');
}

function severitySegmented(active: readonly string[]): string {
  return SEVERITY_ORDER.map((v) => {
    const pressed = active.includes(v);
    return `<button type="button" class="seg-btn" aria-pressed="${pressed}" data-sev="${v}" title="Toggle ${v} severity">
      <span class="swatch sev-${v}"></span>${escapeHtml(v.charAt(0).toUpperCase() + v.slice(1))}
    </button>`;
  }).join('');
}

function impactSegmented(active: readonly string[]): string {
  return IMPACT_ORDER.map((v) => {
    const pressed = active.includes(v);
    return `<button type="button" class="seg-btn" aria-pressed="${pressed}" data-imp="${v}" title="Toggle ${v} impact">
      <span class="swatch imp-${v}"></span>${escapeHtml(v.charAt(0).toUpperCase() + v.slice(1))}
    </button>`;
  }).join('');
}

/* ============================================================================
 * Hero / status / gauge
 * ========================================================================= */

/** Relative time (e.g. "2m ago"). Resilient to clock drift / future stamps. */
function formatRelative(iso: string | undefined): string | undefined {
  if (!iso) return undefined;
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return undefined;
  const diffMs = Date.now() - t;
  if (diffMs < 0) return 'just now';
  const sec = Math.floor(diffMs / 1000);
  if (sec < 45) return 'just now';
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}h ago`;
  const day = Math.floor(hr / 24);
  return `${day}d ago`;
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

/** Hero radial gauge — same SVG geometry as the package dashboard's gauge. */
function buildGauge(score: number): string {
  const r = 36;
  const circumference = 2 * Math.PI * r;
  const arcLength = circumference * 0.75;
  const filled = arcLength * (score / 100);
  const color = score >= 50
    ? `hsl(${Math.round(60 + (score - 50) * 1.2)}, 70%, 48%)`
    : `hsl(${Math.round(score * 1.2)}, 75%, 48%)`;
  const grade = scoreToGrade(score);
  return `<div class="hero-gauge" title="Health score ${score}/100 (grade ${grade}). Errors weigh heaviest.">
    <svg viewBox="0 0 88 88">
      <circle class="gauge-track" cx="44" cy="44" r="${r}" fill="none"
        stroke-width="7"
        stroke-dasharray="${arcLength} ${circumference}"
        stroke-linecap="round" transform="rotate(135 44 44)" />
      <circle class="gauge-fill" cx="44" cy="44" r="${r}" fill="none"
        stroke="${color}" stroke-width="7"
        stroke-dasharray="${filled} ${circumference}"
        stroke-linecap="round" transform="rotate(135 44 44)"
        style="--gauge-target: ${filled}; --gauge-arc: ${arcLength};" />
    </svg>
    <div class="gauge-label"><span class="lg">${grade}</span><span class="sm">${score}/100</span></div>
  </div>`;
}

/** Status line under the title — freshness + highest-signal facts (§4.1). */
function buildStatusLine(input: ViolationsDashboardHtmlInput): string {
  const parts: string[] = [];
  const rel = formatRelative(input.reportTimestamp);
  if (rel) {
    const iso = escapeHtml(input.reportTimestamp ?? '');
    parts.push(`<span class="pill" title="${iso}">⟳ Last run ${escapeHtml(rel)}</span>`);
  } else {
    parts.push(`<span class="pill warn" title="No timestamp on violations.json">⟳ Last run unknown</span>`);
  }
  const findings = input.totalRawAfterDisable;
  const findingsClass = findings === 0 ? 'good' : findings > 100 ? 'bad' : 'warn';
  parts.push(`<span class="pill ${findingsClass}" title="Total findings after disabled-rule filter">${findings} finding${findings === 1 ? '' : 's'}</span>`);
  const todos = input.todoHackSnapshot.todos.length;
  const hacks = input.todoHackSnapshot.hacks.length;
  if (input.todoHackSnapshot.enabled) {
    parts.push(`<span class="pill" title="TODO and HACK markers found in workspace">${todos} TODO · ${hacks} HACK</span>`);
  }
  const drift = input.driftAdvisorSnapshot;
  if (drift.integrationEnabled) {
    if (drift.connected) {
      parts.push(`<span class="pill good" title="Drift Advisor connected: ${escapeHtml(drift.serverLabel ?? '')}">Drift on · ${drift.issues.length}</span>`);
    } else {
      parts.push(`<span class="pill warn" title="Drift Advisor enabled but no server found">Drift offline</span>`);
    }
  }
  if (typeof input.enabledRuleCount === 'number' && input.enabledRuleCount > 0) {
    parts.push(`<span class="pill" title="Enabled rules in current tier">${input.enabledRuleCount} rules</span>`);
  }
  return `<p class="status-line">${parts.join('<span class="dot">·</span>')}</p>`;
}

function buildHero(input: ViolationsDashboardHtmlInput): string {
  const score = computeHealthScore(input.severityCounts);
  const stamp = input.extensionVersion
    ? `<span class="stamp">v${escapeHtml(input.extensionVersion)}</span>`
    : '';
  return `<header class="dash-hero">
    <div class="hero-text">
      <h1>Findings Dashboard${stamp}</h1>
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
  filter?: { kind: 'sev' | 'imp' | 'reset' | 'top-rule'; value?: string };
  title?: string;
}

function buildKpiCards(input: ViolationsDashboardHtmlInput): string {
  const cards = collectKpiCards(input);
  return `<div class="kpi-row">${cards.map(renderKpiCard).join('')}</div>`;
}

function collectKpiCards(input: ViolationsDashboardHtmlInput): KpiSpec[] {
  const errors = input.severityCounts.error ?? 0;
  const warnings = input.severityCounts.warning ?? 0;
  const critHigh = (input.impactCounts.critical ?? 0) + (input.impactCounts.high ?? 0);
  const cards: KpiSpec[] = [];
  cards.push({
    key: 'visible',
    label: 'Visible findings',
    value: String(input.filteredCount),
    sub: input.totalRawAfterDisable === input.filteredCount
      ? 'all matched'
      : `of ${input.totalRawAfterDisable} total`,
    classes: '',
    filter: { kind: 'reset' },
    title: 'Click to clear all filters',
  });
  cards.push({
    key: 'errors',
    label: 'Errors',
    value: String(errors),
    sub: errors > 0 ? 'click to focus on errors' : 'no errors',
    classes: 'errors',
    filter: { kind: 'sev', value: 'error' },
    title: 'Filter findings to errors only',
  });
  cards.push({
    key: 'warnings',
    label: 'Warnings',
    value: String(warnings),
    sub: warnings > 0 ? 'click to focus on warnings' : 'no warnings',
    classes: 'warnings',
    filter: { kind: 'sev', value: 'warning' },
    title: 'Filter findings to warnings only',
  });
  cards.push({
    key: 'crit',
    label: 'Critical + High',
    value: String(critHigh),
    sub: critHigh > 0 ? 'click to focus on highest impact' : 'none at top impact',
    classes: 'crit',
    filter: { kind: 'imp', value: 'critical,high' },
    title: 'Filter findings to critical or high impact',
  });
  if (typeof input.filesAffected === 'number') {
    cards.push({
      key: 'files',
      label: 'Files affected',
      value: String(input.filesAffected),
      sub: input.filesAffected > 0 ? 'across the export' : 'no files affected',
      classes: '',
      title: 'Distinct files contributing at least one finding',
    });
  }
  if (input.topRule && input.topRule.count > 0) {
    cards.push({
      key: 'top-rule',
      label: 'Top rule',
      value: String(input.topRule.count),
      sub: input.topRule.name,
      classes: '',
      filter: { kind: 'top-rule', value: input.topRule.name },
      title: `Filter findings to rule ${input.topRule.name}`,
    });
  }
  return cards;
}

function renderKpiCard(c: KpiSpec): string {
  const interactive = c.filter ? ' interactive' : '';
  const role = c.filter ? ' role="button" tabindex="0"' : '';
  const dataAttrs = c.filter
    ? ` data-kpi="${escapeHtml(c.key)}" data-kpi-kind="${escapeHtml(c.filter.kind)}"${
        c.filter.value !== undefined ? ` data-kpi-value="${escapeHtml(c.filter.value)}"` : ''
      }`
    : '';
  const title = c.title ? ` title="${escapeHtml(c.title)}"` : '';
  return `<div class="kpi-card ${escapeHtml(c.classes)}${interactive}"${role}${dataAttrs}${title}>
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
  return `<section class="toolbar-band" aria-label="Filters and actions">
    <div class="toolbar-row">
      <span class="field" title="Group findings by selected dimension">
        <span class="glyph">⌘</span>
        <label for="groupBy">Group by</label>
        <select id="groupBy" aria-label="Group by">${groupBySelectOptions(input.groupBy)}</select>
      </span>
      <span class="field" title="Filter findings by file path, rule, or message text">
        <span class="glyph">⌕</span>
        <input type="text" id="textFilter" placeholder="Filter by file, rule, or message…" value="${tf}" aria-label="Text filter" />
        <button type="button" class="clear-btn" id="textFilterClear" title="Clear text filter" aria-label="Clear text filter">×</button>
      </span>
      <button type="button" class="btn tier-1" id="btn-run" title="Run Saropa Lints analysis">
        <span class="glyph">▶</span>Run analysis
      </button>
      <button type="button" class="btn" id="btn-refresh" title="Reload violations.json from disk">
        <span class="glyph">⟳</span>Refresh
      </button>
      <button type="button" class="btn" id="btn-copy" title="Copy filtered violations as JSON (${exportCount})">
        <span class="glyph">⎘</span>Copy JSON
      </button>
      <button type="button" class="btn" id="btn-save" title="Save filtered violations as JSON to reports/YYYYMMDD/">
        <span class="glyph">⤓</span>Save report
      </button>
      ${buildMoreActionsMenu()}
    </div>
    <div class="toolbar-row">
      <span class="seg" role="group" aria-label="Severity filter">
        <span class="seg-label">Severity</span>
        ${severitySegmented(input.severities)}
      </span>
      <span class="seg" role="group" aria-label="Impact filter">
        <span class="seg-label">Impact</span>
        ${impactSegmented(input.impacts)}
      </span>
    </div>
    ${buildChipStrip(input)}
  </section>`;
}

function buildMoreActionsMenu(): string {
  const items: Array<[string, string, string]> = [
    ['saropaLints.openHelpHub', 'Help', 'F1'],
    ['saropaLints.setGroupBy', 'Group by…', ''],
    ['saropaLints.setIssuesFilter', 'Text filter…', ''],
    ['saropaLints.setIssuesFilterByType', 'Severity & impact', ''],
    ['saropaLints.setIssuesFilterByRule', 'Hide rules…', ''],
    ['saropaLints.setIssuesFilterByMetadata', 'Rule metadata', ''],
    ['saropaLints.clearIssuesFilters', 'Clear filters', ''],
    ['saropaLints.clearSuppressions', 'Clear suppressions', ''],
    ['saropaLints.clearFocusFile', 'Clear file focus', ''],
    ['saropaLints.focusIssuesForActiveFile', 'Match active editor', ''],
    ['saropaLints.issues.copyAsJson', 'Copy tree JSON', ''],
    ['saropaLints.refresh', 'Refresh extension', ''],
    ['saropaLints.openPackageVibrancy', 'Open Package dashboard', ''],
    ['saropaLints.openProjectVibrancyReport', 'Open Code Health', ''],
    ['saropaLints.openConfigDashboard', 'Open Lints Config', ''],
  ];
  const itemsHtml = items
    .map(([cmd, label, kbd]) =>
      `<button type="button" class="menu-item" data-palette-cmd="${escapeHtml(cmd)}">
        <span>${escapeHtml(label)}</span>
        <span class="kbd">${escapeHtml(kbd)}</span>
      </button>`,
    )
    .join('');
  // Hidden id="btn-refresh-extension" preserves the existing test contract
  // and keyboard binding without polluting the visible toolbar.
  return `<details class="more">
    <summary class="btn" title="More actions" aria-label="More actions">
      <span class="glyph">⋯</span>More <span class="chev">▾</span>
    </summary>
    <div class="menu" role="menu">${itemsHtml}</div>
  </details>
  <button type="button" id="btn-refresh-extension" hidden aria-hidden="true" tabindex="-1"></button>`;
}

/* ============================================================================
 * Active filter chip strip (§8.5, §14.10).
 * ========================================================================= */

function buildChipStrip(input: ViolationsDashboardHtmlInput): string {
  const chips: string[] = [];
  if (input.textFilter.trim().length > 0) {
    chips.push(buildChip('contains', `contains "${input.textFilter}"`, 'text'));
  }
  for (const v of SEVERITY_ORDER) {
    if (!input.severities.includes(v)) {
      chips.push(buildChip('sev-off', `severity ≠ ${v}`, `sev:${v}`));
    }
  }
  for (const v of IMPACT_ORDER) {
    if (!input.impacts.includes(v)) {
      chips.push(buildChip('imp-off', `impact ≠ ${v}`, `imp:${v}`));
    }
  }
  if (chips.length === 0) return '';
  return `<div class="chip-strip" id="chipStrip">
    <span class="lbl">Active filters:</span>
    ${chips.join('')}
    <button type="button" class="clear-all" id="chipsClearAll" title="Reset all filters">Clear all</button>
  </div>`;
}

function buildChip(kind: string, label: string, dropToken: string): string {
  return `<span class="chip" data-chip-kind="${escapeHtml(kind)}" data-chip-token="${escapeHtml(dropToken)}">
    ${escapeHtml(label)}
    <button type="button" class="x" aria-label="Remove filter">×</button>
  </span>`;
}

/* ============================================================================
 * Findings table — sortable, sticky header, group rows (§7).
 * Replaces the legacy `<details > <details> > <vrow>` tree.
 * ========================================================================= */

function buildFindingsBlock(input: ViolationsDashboardHtmlInput): string {
  if (input.filteredCount === 0) {
    return buildFindingsEmpty(input);
  }
  return `<section class="section" aria-label="Findings">
    <div class="findings-wrap">
      <div class="findings-toolbar">
        <span class="meta-line" style="margin:0">${escapeHtml(buildFindingsMeta(input))}</span>
        <div class="actions">
          <button type="button" class="mini-btn" id="expand-all">Expand all</button>
          <button type="button" class="mini-btn" id="collapse-all">Collapse all</button>
        </div>
      </div>
      <table class="findings-table" role="grid" aria-rowcount="${input.filteredCount}">
        <thead>
          <tr>
            <th data-sort="sev" aria-sort="none" scope="col">Severity<span class="arrow">⇅</span></th>
            <th data-sort="rule" aria-sort="none" scope="col">Rule<span class="arrow">⇅</span></th>
            <th data-sort="msg" aria-sort="none" scope="col">Message<span class="arrow">⇅</span></th>
            <th data-sort="line" aria-sort="none" scope="col">Line<span class="arrow">⇅</span></th>
            <th aria-label="Row actions" scope="col"></th>
          </tr>
        </thead>
        <tbody>${buildTableBody(input.sections, input.pageSize)}</tbody>
      </table>
      ${buildOverflowNote(input)}
    </div>
  </section>`;
}

function buildFindingsMeta(input: ViolationsDashboardHtmlInput): string {
  const parts: string[] = [`${input.filteredCount} shown`];
  if (input.totalRawAfterDisable !== input.filteredCount) {
    parts.push(`${input.totalRawAfterDisable} after disabled-rule filter`);
  }
  if (input.truncatedSource) {
    parts.push(`source capped at ${input.maxSourceViolations} for performance`);
  }
  parts.push(`grouped by ${input.groupBy}`);
  return parts.join(' · ');
}

function buildOverflowNote(input: ViolationsDashboardHtmlInput): string {
  if (!input.truncatedSource) return '';
  return `<p class="overflow-note">
    <span>Source list truncated at ${input.maxSourceViolations} for render performance.</span>
    <button type="button" class="link" id="run-again">Run analysis again</button>
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
    <td colspan="5">
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
    <td class="col-sev"><span class="sev-pill sev-${escapeHtml(sev)}">${escapeHtml(sev)}</span></td>
    <td class="col-rule"><span class="rule-tag">${rule}</span></td>
    <td class="col-msg"><div class="vmsg">${msg}</div><div class="kpi-sub" title="${fileLabel}">${fileLabel}</div></td>
    <td class="col-line">L${line}</td>
    <td class="col-actions"><button type="button" class="row-action" data-row-action="copy" title="Copy this finding as JSON">⎘</button></td>
  </tr>`;
}

function buildFindingsEmpty(input: ViolationsDashboardHtmlInput): string {
  const reason = input.totalRawAfterDisable === 0
    ? 'No violations in the last analysis run.'
    : 'No violations match the current filters.';
  const cta = input.totalRawAfterDisable === 0
    ? `<button type="button" class="btn tier-1" id="btn-run-empty"><span class="glyph">▶</span>Run analysis</button>
       <button type="button" class="btn" id="btn-refresh-empty"><span class="glyph">⟳</span>Refresh</button>`
    : `<button type="button" class="btn tier-1" id="btn-reset-empty"><span class="glyph">⊘</span>Reset filters</button>
       <button type="button" class="btn" id="btn-run-empty2"><span class="glyph">▶</span>Re-run analysis</button>`;
  return `<section class="section" aria-label="Findings">
    <div class="findings-wrap">
      <div class="empty-cta">
        <h3>${escapeHtml(reason)}</h3>
        <p>${input.totalRawAfterDisable === 0
          ? 'Run analysis to populate <code>reports/.saropa_lints/violations.json</code>, then refresh.'
          : 'Adjust filters or run analysis again to see findings.'}</p>
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
  const impTotal = IMPACT_ORDER.reduce((n, k) => n + (input.impactCounts[k] ?? 0), 0);
  if (sevTotal === 0 && impTotal === 0) return '';
  return `<section class="section" aria-label="Mix charts">
    <h2>Mix <span class="meta">click a slice to filter</span></h2>
    <div class="charts-grid">
      ${sevTotal === 0 ? '' : buildMixCard('Severity mix', SEVERITY_ORDER, input.severityCounts, 'sev')}
      ${impTotal === 0 ? '' : buildMixCard('Impact mix',   IMPACT_ORDER,   input.impactCounts,   'imp')}
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
  return `<div class="bar-row${zero}"${role} data-filter-kind="${axis}" data-filter-value="${escapeHtml(key)}" title="Filter to ${escapeHtml(key)} only">
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
    <div class="donut-legend"><div class="total">${total}</div><div class="lbl">total</div></div>
  </div></div>`;
}

/* ============================================================================
 * Secondary actionable lists — TODOs, HACKS (§14.7).
 * ========================================================================= */

function buildTodoHackBlock(input: ViolationsDashboardHtmlInput): string {
  const snap = input.todoHackSnapshot;
  if (!snap.enabled) {
    return `<section class="section" aria-label="TODOs and HACKS">
      <h2>TODOs &amp; HACKS <span class="meta">scan disabled</span></h2>
      <p class="footer-line">Workspace scan is off — enable to surface markers from project files.
        <button type="button" class="link" id="btn-enable-todos-scan">Enable scan</button></p>
    </section>`;
  }
  const todoBody = renderTodoSubsection('TODOs', snap.todos, snap.capped);
  const hackBody = renderTodoSubsection('HACKS', snap.hacks, snap.capped);
  return `<section class="section" aria-label="TODOs and HACKS">
    <h2>TODOs &amp; HACKS <span class="count">${snap.todos.length + snap.hacks.length}</span></h2>
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
    return `<p class="footer-line"><strong>${escapeHtml(title)}:</strong> none in scan range.</p>`;
  }
  const rows = items.map(renderCompactRow).join('');
  const cap = capped
    ? `<p class="footer-line">Scan hit max-file cap; raise <code>saropaLints.todosAndHacks.maxFilesToScan</code> for full coverage.</p>`
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
    <span class="sev-pill sev-note">note</span>
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
    return `<section class="section" aria-label="Drift Advisor">
      <h2>Drift Advisor <span class="meta">integration off</span></h2>
      <p class="footer-line">Enable Drift Advisor integration to surface database suggestions here.
        <button type="button" class="link" id="btn-drift-enable">Enable</button></p>
    </section>`;
  }
  if (!input.connected) {
    return `<section class="section" aria-label="Drift Advisor">
      <h2>Drift Advisor <span class="meta">no server</span></h2>
      <p class="footer-line">No Drift Advisor server found on configured ports.
        <button type="button" class="link" id="btn-drift-refresh">Retry</button>
      </p>
    </section>`;
  }
  if (input.issues.length === 0) {
    return `<section class="section" aria-label="Drift Advisor">
      <h2>Drift Advisor <span class="meta">connected</span></h2>
      <p class="footer-line">Connected to ${escapeHtml(input.serverLabel ?? '')} — no current issues.
        <button type="button" class="link" id="btn-drift-refresh">Refresh</button>
        <button type="button" class="link" id="btn-drift-browser">Open in browser</button>
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
  return `<section class="section" aria-label="Drift Advisor">
    <h2>Drift Advisor <span class="count">${input.issues.length}</span> <span class="meta">${escapeHtml(input.serverLabel ?? '')}</span></h2>
    <div class="compact-list">${rows}</div>
    <p class="footer-line">
      <button type="button" class="link" id="btn-drift-refresh">Refresh</button>
      <button type="button" class="link" id="btn-drift-browser">Open in browser</button>
      <button type="button" class="link" id="btn-drift-disable">Disable Drift Advisor</button>
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
  return `<section class="section" id="suppressions-block" aria-label="Suppressions">
    <h2>Suppressions (export) <span class="count">${a.total}</span>${kindBreakdown ? ` <span class="meta">${kindBreakdown}</span>` : ''}</h2>
    <div class="sup-band">${buildAnalyzerBody(a)}</div>
    <h3 style="margin:14px 0 6px;font-size:.98em;font-weight:600">Issues view hides <span class="meta" style="margin-left:8px;color:var(--vscode-descriptionForeground)">${v.active ? 'active' : 'none'}</span></h3>
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
    return `<p class="footer-line">No analyzer suppressions in the current <code>violations.json</code> export. Run analysis after editing ignores or baselines to populate.</p>`;
  }
  const totalRow = `<div class="sup-row sup-act" role="button" tabindex="0" data-sup="focus-issues">
    <span class="sup-k plain">Total — clear filters and open Findings</span>
    <span class="sup-n">${a.total}</span>
  </div>`;
  const ruleBody = renderSupRows(a.byRule, 'rule');
  const fileBody = renderSupRows(a.byFile, 'file');
  return `${totalRow}
    <details class="sup-disclosure" open><summary>By rule (${a.byRule.length})</summary>${ruleBody}</details>
    <details class="sup-disclosure"><summary>By file (${a.byFile.length})</summary>${fileBody}</details>`;
}

function renderSupRows(entries: readonly [string, number][], kind: 'rule' | 'file'): string {
  if (entries.length === 0) {
    return `<p class="footer-line">No entries.</p>`;
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
    return `<p class="footer-line">Nothing hidden from the Issues list in this workspace. Use tree context actions to hide folders, files, or rules; they persist in workspace state.</p>`;
  }
  const counts = [
    v.folderCount ? `${v.folderCount} folder(s)` : '',
    v.fileCount ? `${v.fileCount} file pattern(s)` : '',
    v.ruleCount ? `${v.ruleCount} rule(s) globally` : '',
    v.ruleInFileEntryCount ? `${v.ruleInFileEntryCount} file(s) with per-file rule hides` : '',
    v.severityCount ? `${v.severityCount} severity hide(s)` : '',
    v.impactCount ? `${v.impactCount} impact hide(s)` : '',
  ]
    .filter(Boolean)
    .join(' · ');
  const parts: string[] = [];
  parts.push(`<p class="footer-line"><strong>Active hides:</strong> ${escapeHtml(counts)}.</p>`);
  parts.push(`<p class="footer-line">These hides shrink the Issues / dashboard list only; they are not written to <code>violations.json</code>.
    <button type="button" class="link" id="btn-clear-view-sup">Clear all view hides</button></p>`);
  parts.push(renderListBlock('Folders (sample)', v.sampleFolders));
  parts.push(renderListBlock('Files / globs (sample)', v.sampleFiles));
  parts.push(renderListBlock('Rules (sample)', v.sampleRules));
  if (v.sampleRuleInFileLines.length > 0) {
    parts.push(renderListBlock('Per-file rules (sample)', v.sampleRuleInFileLines));
  }
  return parts.filter(Boolean).join('\n');
}

function renderListBlock(title: string, items: readonly string[]): string {
  if (items.length === 0) return '';
  const lis = items.map((s) => `<li><code>${escapeHtml(s)}</code></li>`).join('');
  return `<p class="footer-line"><strong>${escapeHtml(title)}</strong></p><ul class="sup-ul">${lis}</ul>`;
}

function prettifyAnalyzerKindToken(token: string): string {
  if (!token) return 'Unknown';
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
  return `(function () {
  var vscode = acquireVsCodeApi();
  var filterDebounce = null;

  function readState() {
    var gb = document.getElementById('groupBy');
    var tf = document.getElementById('textFilter');
    var sev = [];
    document.querySelectorAll('.seg-btn[data-sev][aria-pressed="true"]').forEach(function (el) {
      sev.push(el.getAttribute('data-sev'));
    });
    var imp = [];
    document.querySelectorAll('.seg-btn[data-imp][aria-pressed="true"]').forEach(function (el) {
      imp.push(el.getAttribute('data-imp'));
    });
    return {
      type: 'dashboardUpdate',
      groupBy: gb ? gb.value : undefined,
      textFilter: tf ? tf.value : '',
      severities: sev.length ? sev : ${JSON.stringify(DEFAULT_SEVERITIES)},
      impacts: imp.length ? imp : ${JSON.stringify(DEFAULT_IMPACTS)}
    };
  }

  function pushState(immediate) {
    if (filterDebounce) { clearTimeout(filterDebounce); filterDebounce = null; }
    if (immediate) { vscode.postMessage(readState()); return; }
    filterDebounce = setTimeout(function () { vscode.postMessage(readState()); }, 220);
  }

  /* Filter inputs */
  var gb = document.getElementById('groupBy');
  if (gb) gb.addEventListener('change', function () { pushState(true); });
  var tf = document.getElementById('textFilter');
  if (tf) tf.addEventListener('input', function () { pushState(false); });
  var tfClear = document.getElementById('textFilterClear');
  if (tfClear) tfClear.addEventListener('click', function () {
    if (tf) { tf.value = ''; pushState(true); }
  });
  document.querySelectorAll('.seg-btn[data-sev], .seg-btn[data-imp]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var pressed = btn.getAttribute('aria-pressed') === 'true';
      btn.setAttribute('aria-pressed', pressed ? 'false' : 'true');
      pushState(true);
    });
  });

  /* Toolbar primary actions */
  bindClick('btn-run', function () { vscode.postMessage({ type: 'runAnalysis' }); });
  bindClick('btn-refresh', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-copy', function () { vscode.postMessage({ type: 'copyFilteredJson' }); });
  bindClick('btn-save', function () { vscode.postMessage({ type: 'saveFilteredJson' }); });
  bindClick('btn-refresh-extension', function () {
    vscode.postMessage({ type: 'paletteCommand', commandId: 'saropaLints.refresh' });
  });
  bindClick('btn-run-empty', function () { vscode.postMessage({ type: 'runAnalysis' }); });
  bindClick('btn-run-empty2', function () { vscode.postMessage({ type: 'runAnalysis' }); });
  bindClick('btn-refresh-empty', function () { vscode.postMessage({ type: 'refresh' }); });
  bindClick('btn-reset-empty', function () { vscode.postMessage({ type: 'resetFilters' }); });
  bindClick('run-again', function () { vscode.postMessage({ type: 'runAnalysis' }); });

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
      if (kind === 'imp') {
        var keep = v.split(',');
        document.querySelectorAll('.seg-btn[data-imp]').forEach(function (b) {
          b.setAttribute('aria-pressed', keep.indexOf(b.getAttribute('data-imp')) >= 0 ? 'true' : 'false');
        });
        pushState(true);
        return;
      }
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
      if (kind === 'sev') {
        document.querySelectorAll('.seg-btn[data-sev]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-sev') === v ? 'true' : 'false');
        });
      } else if (kind === 'imp') {
        document.querySelectorAll('.seg-btn[data-imp]').forEach(function (b) {
          b.setAttribute('aria-pressed', b.getAttribute('data-imp') === v ? 'true' : 'false');
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
      } else if (token.indexOf('imp:') === 0) {
        var iv = token.slice(4);
        var ibtn = document.querySelector('.seg-btn[data-imp="' + iv + '"]');
        if (ibtn) { ibtn.setAttribute('aria-pressed', 'true'); pushState(true); }
      }
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

  /* Sortable table headers — sorts within each group, stable. */
  document.querySelectorAll('.findings-table thead th[data-sort]').forEach(function (th) {
    th.addEventListener('click', function () {
      var sortKey = th.getAttribute('data-sort');
      var current = th.getAttribute('aria-sort') || 'none';
      var next = current === 'ascending' ? 'descending' : 'ascending';
      document.querySelectorAll('.findings-table thead th').forEach(function (other) {
        other.setAttribute('aria-sort', 'none');
      });
      th.setAttribute('aria-sort', next);
      sortRowsWithinGroups(sortKey, next === 'ascending');
    });
  });

  function sortRowsWithinGroups(key, asc) {
    var tbody = document.querySelector('.findings-table tbody');
    if (!tbody) return;
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
    var sevOrder = { error: 0, warning: 1, info: 2, note: 3 };
    groups.forEach(function (g) {
      g.rows.sort(function (a, b) {
        var av, bv;
        if (key === 'sev') {
          av = sevOrder[a.getAttribute('data-sev')] || 99;
          bv = sevOrder[b.getAttribute('data-sev')] || 99;
        } else if (key === 'rule') {
          av = a.getAttribute('data-rule') || '';
          bv = b.getAttribute('data-rule') || '';
        } else if (key === 'line') {
          av = parseInt(a.getAttribute('data-line') || '0', 10);
          bv = parseInt(b.getAttribute('data-line') || '0', 10);
        } else {
          av = (a.querySelector('.vmsg') || {}).textContent || '';
          bv = (b.querySelector('.vmsg') || {}).textContent || '';
        }
        if (av < bv) return asc ? -1 : 1;
        if (av > bv) return asc ? 1 : -1;
        return 0;
      });
    });
    /* Wipe the tbody, then re-append in (header, sorted rows) order so
       group sequence stays stable while rows within each group reflect
       the new sort. Single-pass — earlier drafts double-rebuilt. */
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    groups.forEach(function (g) {
      tbody.appendChild(g.header);
      g.rows.forEach(function (r) { tbody.appendChild(r); });
    });
  }

  /* Finding-row clicks open the file. Per-row copy posts JSON. */
  bindFRows();
  function bindFRows() {
    document.querySelectorAll('tr.frow').forEach(function (row) {
      row.addEventListener('click', function (e) {
        var t = e.target;
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
  }
  function openRow(row) {
    var enc = row.getAttribute('data-file');
    var ln = parseInt(row.getAttribute('data-line') || '1', 10);
    if (!enc) return;
    try {
      vscode.postMessage({ type: 'openFile', file: decodeURIComponent(enc), line: ln });
    } catch (e) { /* ignore */ }
  }

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
  <title>Saropa Findings Dashboard</title>
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';" />
  <style nonce="${nonce}">${getViolationsDashboardStyles()}</style>
</head><body>
  ${buildHero(input)}
  ${buildKpiCards(input)}
  ${buildToolbar(input)}
  ${buildFindingsBlock(input)}
  ${buildTodoHackBlock(input)}
  ${buildDriftBlock(input.driftAdvisorSnapshot)}
  ${buildChartsBlock(input)}
  ${buildSuppressionsBlock(input)}
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
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}';"/>
  <style nonce="${nonce}">${getFindingsEmptyStateStyles()}</style>
</head><body>
  <div class="empty-hero">
    <h1>Saropa Findings Dashboard</h1>
    <p>${esc}</p>
    <p>Run a Saropa Lints analysis to generate <code>violations.json</code>, then use <strong>Refresh</strong> here or reopen this dashboard.</p>
    <div class="btns">
      <button type="button" class="primary" id="btn-run">Run analysis</button>
      <button type="button" id="btn-refresh">Refresh from disk</button>
    </div>
  </div>
  <script nonce="${nonce}">
    (function () {
      var vscode = acquireVsCodeApi();
      document.getElementById('btn-run').addEventListener('click', function () {
        vscode.postMessage({ type: 'runAnalysis' });
      });
      document.getElementById('btn-refresh').addEventListener('click', function () {
        vscode.postMessage({ type: 'refresh' });
      });
    })();
  </script>
</body></html>`;
}

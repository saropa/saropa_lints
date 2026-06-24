/**
 * Findings dashboard — top chrome section builders (hero gauge, status line, KPI filter cards, toolbar, more-actions menu, active-filter chips). Extracted from violationsDashboardHtml.ts; the composer imports the section entry points.
 */

import { gradeColor, scoreToGrade, severityScore } from '../healthGrade';
import { l10n } from '../i18n/runtime';
import { buildFullWidthToggle } from './dashboardHero';
import { VIOLATIONS_GROUP_BY_MODES, type GroupByMode } from './issuesTreeGrouping';
import { buildKeyboardShortcutsButton } from './keyboard-shortcuts';
import { SEVERITY_ORDER, escapeHtml, formatRelative, type ViolationsDashboardHtmlInput } from './violations-dashboard-shared';
import { pluralize } from './webview-format';




export function groupBySelectOptions(current: GroupByMode): string {
  const labels: Record<GroupByMode, string> = {
    severity: l10n('findingsDash.groupBy.severity'),
    file: l10n('findingsDash.groupBy.file'),
    impact: l10n('findingsDash.groupBy.impact'),
    rule: l10n('findingsDash.groupBy.rule'),
    owasp: l10n('findingsDash.groupBy.owasp'),
    ruleType: l10n('findingsDash.groupBy.ruleType'),
    ruleStatus: l10n('findingsDash.groupBy.ruleStatus'),
    tier: l10n('findingsDash.groupBy.tier'),
    pack: l10n('findingsDash.groupBy.pack'),
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


export function severitySegmented(active: readonly string[]): string {
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
export function buildGauge(score: number): string {
  const r = 36;
  const circumference = 2 * Math.PI * r;
  const arcLength = circumference * 0.75;
  const filled = arcLength * (score / 100);
  const color = gradeColor(score);
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
 * Build the file-system TODO/HACK scanner *promo* pill — the muted invite
 * shown when the scanner is off and there are Dart files to scan. Returns
 * nothing once the scanner is on (its "{N} TODO · {N} HACK" pill is rendered in
 * buildStatusLine from todoHackSnapshot) or in a workspace with no Dart code.
 */
export function buildScannerPromoPill(input: ViolationsDashboardHtmlInput): string[] {
  const s = input.scanner;
  if (!s || s.enabled || !s.hasDartFiles) return [];
  return [
    `<span class="pill toggle promo" data-toggle="scanner" role="button" tabindex="0" title="${escapeHtml(l10n('findingsDash.supplementary.tooltipPromoClickToOn'))}">${escapeHtml(l10n('findingsDash.supplementary.scannerPromo'))}</span>`,
  ];
}


/** Status line under the title — freshness + highest-signal facts (§4.1). */
export function buildStatusLine(input: ViolationsDashboardHtmlInput): string {
  const parts: string[] = [];
  const rel = formatRelative(input.reportTimestamp);
  if (rel) {
    const iso = escapeHtml(input.reportTimestamp ?? '');
    // The timestamp is the moment this dashboard last repainted from live
    // diagnostics (liveDiagnosticsModel stamps it at build), so "Updated" is
    // accurate where "Last run" implied a separate analysis pass. The pill is
    // clickable (data-action="refresh") because a backgrounded panel does not
    // auto-repaint — the user can pull the analyzer's current state on demand.
    //
    // The relative label re-ticks client-side: we ship the localized time
    // templates as data attributes with a literal {n} placeholder (mirroring
    // formatRelative's buckets exactly) so the webview can recompute "5m ago"
    // every 30s without another host rebuild. Without this the label would
    // freeze at "just now" until the next diagnostics change.
    const tJustNow = escapeHtml(l10n('findingsDash.time.justNow'));
    const tMin = escapeHtml(l10n('findingsDash.time.minutesAgo', { min: '{n}' }));
    const tHr = escapeHtml(l10n('findingsDash.time.hoursAgo', { hr: '{n}' }));
    const tDay = escapeHtml(l10n('findingsDash.time.daysAgo', { day: '{n}' }));
    const hint = escapeHtml(l10n('findingsDash.status.refreshHint'));
    parts.push(
      `<span class="pill freshness" role="button" tabindex="0" data-action="refresh" title="${hint} · ${iso}">` +
        `⟳ ${escapeHtml(l10n('findingsDash.status.updatedPrefix'))} ` +
        `<span class="freshness-rel" data-updated-at="${iso}"` +
        ` data-t-justnow="${tJustNow}" data-t-min="${tMin}" data-t-hr="${tHr}" data-t-day="${tDay}">` +
        `${escapeHtml(rel)}</span>` +
        `</span>`,
    );
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
  // Scanner promo pill — invites enabling the file-system TODO/HACK scanner
  // when it is off and there are Dart files to scan. Renders nothing once the
  // scanner is on (the ON pill above) or in a non-Dart workspace.
  parts.push(...buildScannerPromoPill(input));
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


export function buildHero(input: ViolationsDashboardHtmlInput): string {
  const score = severityScore(input.severityCounts);
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

export interface KpiSpec {
  key: string;
  label: string;
  value: string;
  sub: string;
  classes: string;
  filter?: { kind: 'sev' | 'reset' | 'top-rule'; value?: string };
  title?: string;
}


export function buildKpiCards(input: ViolationsDashboardHtmlInput): string {
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
export function collectKpiCards(input: ViolationsDashboardHtmlInput): KpiSpec[] {
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


export function renderKpiCard(c: KpiSpec): string {
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

export function buildToolbar(input: ViolationsDashboardHtmlInput): string {
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


export function buildAnalysisProgress(): string {
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
export type MenuItem = {
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
export function buildMoreActionsMenu(exportCount: number): string {
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

export function buildChipStrip(input: ViolationsDashboardHtmlInput): string {
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


export function buildChip(kind: string, label: string, dropToken: string): string {
  return `<span class="chip" data-chip-kind="${escapeHtml(kind)}" data-chip-token="${escapeHtml(dropToken)}">
    ${escapeHtml(label)}
    <button type="button" class="x" aria-label="${escapeHtml(l10n('filter.chipRemove'))}">×</button>
  </span>`;
}

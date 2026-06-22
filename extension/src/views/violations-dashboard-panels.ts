/**
 * Findings dashboard — aside panel section builders (severity-mix chart, TODO/HACK block, Drift Advisor block, suppressions / view-hides block). Extracted from violationsDashboardHtml.ts.
 */

import { l10n } from '../i18n/runtime';
import { SEVERITY_ORDER, escapeHtml, type AnalyzerSuppressionsSlice, type ViewSuppressionsSlice, type ViolationsDashboardHtmlInput } from './violations-dashboard-shared';


/* ============================================================================
 * Charts — bars + donut (§6.1). Skeleton-on-zero for individual rows;
 * card omitted entirely if every slot is zero (§8.16, §14.6).
 * ========================================================================= */

export function buildChartsBlock(input: ViolationsDashboardHtmlInput): string {
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


export function buildMixCard(
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


export function buildBarRow(axis: 'sev' | 'imp', key: string, count: number, max: number): string {
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
export function buildDonut(
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

export function buildTodoHackBlock(input: ViolationsDashboardHtmlInput): string {
  const snap = input.todoHackSnapshot;
  if (!snap.enabled) {
    return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.todoHack.sectionAria'))}">
      <h2>${escapeHtml(l10n('findingsDash.todoHack.headingDisabled'))} <span class="meta">${escapeHtml(l10n('findingsDash.todoHack.metaDisabled'))}</span></h2>
      <p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.scanOff'))}
        <button type="button" class="link" id="btn-enable-todos-scan">${escapeHtml(l10n('findingsDash.todoHack.enableScan'))}</button></p>
    </section>`;
  }
  const todoBody = renderTodoSubsection(l10n('findingsDash.todoHack.todosLabel'), snap.todos);
  const hackBody = renderTodoSubsection(l10n('findingsDash.todoHack.hacksLabel'), snap.hacks);
  // Cap note is rendered once at block level (not per subsection) so the limit
  // warning + its action appear a single time, and it carries a clickable button
  // that opens the relevant setting — naming the setting key in prose alone left
  // the user with no way to act on it (user-reported dead-end).
  const capNote = snap.capped ? buildScanCapNote() : '';
  return `<section class="section" aria-label="${escapeHtml(l10n('findingsDash.todoHack.sectionAria'))}">
    <h2>${escapeHtml(l10n('findingsDash.todoHack.heading'))} <span class="count">${snap.todos.length + snap.hacks.length}</span></h2>
    ${todoBody}
    ${hackBody}
    ${capNote}
  </section>`;
}


/** Actionable "scan hit its file limit" note: plain explanation + a button that
 * opens the maxFilesToScan setting. Wired by btn-raise-scan-cap in the script. */
export function buildScanCapNote(): string {
  return `<p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.capNote'))}
    <button type="button" class="link" id="btn-raise-scan-cap">${escapeHtml(l10n('findingsDash.todoHack.raiseCap'))}</button></p>`;
}


export function renderTodoSubsection(
  title: string,
  items: Array<{ file: string; line: number; snippet: string }>,
): string {
  if (items.length === 0) {
    return `<p class="footer-line">${escapeHtml(l10n('findingsDash.todoHack.subsectionNone', { title }))}</p>`;
  }
  const rows = items.map(renderCompactRow).join('');
  return `<div style="margin-bottom:8px">
    <h3 style="margin:6px 0;font-size:.95em;font-weight:600">${escapeHtml(title)} <span class="meta">${items.length}</span></h3>
    <div class="compact-list">${rows}</div>
  </div>`;
}


export function renderCompactRow(item: { file: string; line: number; snippet: string }): string {
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

export function buildDriftBlock(input: ViolationsDashboardHtmlInput['driftAdvisorSnapshot']): string {
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

export function buildSuppressionsBlock(input: ViolationsDashboardHtmlInput): string {
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


export function buildKindBreakdown(byKind: readonly [string, number][]): string {
  if (byKind.length === 0) return '';
  return byKind
    .map(([k, n]) => `${escapeHtml(prettifyAnalyzerKindToken(k))} ${n}`)
    .join(' · ');
}


export function buildAnalyzerBody(a: AnalyzerSuppressionsSlice): string {
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


export function renderSupRows(entries: readonly [string, number][], kind: 'rule' | 'file'): string {
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


export function buildViewBody(v: ViewSuppressionsSlice): string {
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


export function renderListBlock(title: string, items: readonly string[]): string {
  if (items.length === 0) return '';
  // §7.1 — Same data type (rule names / file paths) must use the same element
  // across rows. The findings table renders rule names as <span class="rule-tag">,
  // so the suppressions list must too. <code> carries a default monospace +
  // background tint that made suppression rows look pre-highlighted compared
  // to findings rows of the same shape.
  const lis = items.map((s) => `<li><span class="rule-tag">${escapeHtml(s)}</span></li>`).join('');
  return `<p class="footer-line"><strong>${escapeHtml(title)}</strong></p><ul class="sup-ul">${lis}</ul>`;
}


export function prettifyAnalyzerKindToken(token: string): string {
  if (!token) return l10n('findingsDash.unknownAnalyzerKind');
  return token
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

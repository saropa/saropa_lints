/**
 * Findings dashboard — table section builders (Top Rules triage table and the grouped, sortable findings table with its rows, meta line, overflow note, and empty state). Extracted from violationsDashboardHtml.ts.
 */

import { l10n } from '../i18n/runtime';
import { type Violation } from '../violationsReader';
import { type DashboardSection } from './issuesTreeModel';
import { escapeHtml, type ViolationsDashboardHtmlInput } from './violations-dashboard-shared';
import { pluralize } from './webview-format';


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

export type TopRule = NonNullable<ViolationsDashboardHtmlInput['topRules']>[number];


export function buildTopRulesTable(input: ViolationsDashboardHtmlInput): string {
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
export function buildTopRuleRow(r: TopRule, i: number): string {
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


export function buildTopRuleDetailRow(
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

export function buildFindingsBlock(input: ViolationsDashboardHtmlInput): string {
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


export function buildFindingsMeta(input: ViolationsDashboardHtmlInput): string {
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


export function buildOverflowNote(input: ViolationsDashboardHtmlInput): string {
  if (!input.truncatedSource) return '';
  return `<p class="overflow-note">
    <span>${escapeHtml(l10n('findingsDash.findings.overflowNote', { max: String(input.maxSourceViolations) }))}</span>
    <button type="button" class="link" id="run-again" data-run-analysis>${escapeHtml(l10n('findingsDash.findings.runAgain'))}</button>
  </p>`;
}


export function buildTableBody(sections: DashboardSection[], pageSize: number): string {
  return sections.map((sec, idx) => buildSectionRows(sec, pageSize, idx === 0)).join('');
}


export function buildSectionRows(sec: DashboardSection, pageSize: number, openByDefault: boolean): string {
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


export function renderFindingRow(v: Violation, filePath: string): string {
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


export function buildFindingsEmpty(input: ViolationsDashboardHtmlInput): string {
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


export function sectionTitle(sec: DashboardSection): string {
  if (sec.kind === 'severity') {
    return sec.severity.charAt(0).toUpperCase() + sec.severity.slice(1);
  }
  return sec.label;
}


export function sectionCount(sec: DashboardSection): number {
  return sec.files.reduce((n, f) => n + f.violations.length, 0);
}

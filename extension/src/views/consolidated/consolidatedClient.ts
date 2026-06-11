/**
 * Client script for the consolidated dashboard (runs inside the webview).
 *
 * Async-first / shell-once: the HTML skeleton is set ONCE by the host. This
 * never rebuilds the page — it patches the DOM in place from `model` messages,
 * keyed by rule, so scroll position, focus, and expansion survive every live
 * update. Occurrences are fetched lazily, one rule at a time, on expand.
 *
 * No hardcoded user-facing copy: every string arrives already localized from
 * the host (the `SL` bundle for the two client-only literals; pre-formatted
 * `summaryLine` / chip labels / `more` in the messages).
 */

export function getConsolidatedClient(): string {
  return `
const vscode = acquireVsCodeApi();
const SL = window.SL || {};
const $ = (id) => document.getElementById(id);
const groupsEl = $('groups');
const emptyEl = $('empty');
const searchEl = $('search');
const summaryEl = $('summary');
const gaugeEl = $('gauge');
const gaugeGrade = $('gaugeGrade');
const gaugeScore = $('gaugeScore');
const gradeLabelEl = $('gradeLabel');
const chipsEl = $('chips');

const SEV = { error: 'error', warning: 'warning', info: 'info' };

// rule -> { el, count, open, loaded }
const rows = new Map();
let filter = '';

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function applyGauge(m) {
  gaugeEl.style.setProperty('--gauge-val', String(m.score));
  gaugeEl.style.setProperty('--gauge-col', m.color);
  gaugeGrade.textContent = m.grade;
  gaugeScore.textContent = m.score;
  gradeLabelEl.textContent = m.label;
}

function applyChips(chips) {
  let html = '';
  for (const c of chips) {
    const dot = c.kind ? '<span class="dot"></span>' : '';
    const cls = c.kind ? ' ' + c.kind : '';
    html += '<span class="chip' + cls + '">' + dot +
      '<span class="n">' + c.n + '</span><span class="lbl">' + esc(c.label) + '</span></span>';
  }
  chipsEl.innerHTML = html;
}

function makeRow(g) {
  const group = document.createElement('div');
  group.dataset.rule = g.rule;
  group.innerHTML =
    '<div class="row" role="button" tabindex="0" aria-expanded="false">' +
      '<svg class="chev" viewBox="0 0 16 16" width="12" height="12" aria-hidden="true"><path fill="currentColor" d="M6 4l4 4-4 4z"/></svg>' +
      '<span class="rule-name"></span><span class="spacer"></span>' +
      '<span class="sev-tag"></span><span class="count-badge"></span>' +
    '</div><div class="occ"></div>';
  return group;
}

function paintRow(group, g, open) {
  group.className = 'group ' + SEV[g.worst] + (open ? ' open' : '');
  group.querySelector('.rule-name').textContent = g.rule;
  group.querySelector('.sev-tag').textContent = g.worst;
  group.querySelector('.count-badge').textContent = String(g.count);
  group.querySelector('.row').setAttribute('aria-expanded', String(open));
}

function applyFilterTo(entry, rule) {
  const show = !filter || rule.toLowerCase().indexOf(filter) !== -1;
  entry.el.classList.toggle('hidden', !show);
}

function requestOcc(rule, entry) {
  entry.el.querySelector('.occ').innerHTML = '<div class="occ-loading">' + esc(SL.fetching || '') + '</div>';
  vscode.postMessage({ type: 'expand', rule: rule });
}

function reconcile(groups) {
  const seen = new Set();
  for (const g of groups) {
    seen.add(g.rule);
    let entry = rows.get(g.rule);
    if (!entry) {
      entry = { el: makeRow(g), count: g.count, open: false, loaded: false };
      rows.set(g.rule, entry);
      paintRow(entry.el, g, false);
    } else {
      // Count changed while open -> cached occurrences are stale; refetch.
      if (entry.count !== g.count) {
        entry.loaded = false;
        if (entry.open) requestOcc(g.rule, entry);
      }
      entry.count = g.count;
      paintRow(entry.el, g, entry.open);
    }
    // appendChild MOVES an existing node, so reordering preserves expansion.
    groupsEl.appendChild(entry.el);
    applyFilterTo(entry, g.rule);
  }
  for (const [rule, entry] of rows) {
    if (!seen.has(rule)) { entry.el.remove(); rows.delete(rule); }
  }
  emptyEl.classList.toggle('hidden', groups.length > 0);
  groupsEl.classList.toggle('hidden', groups.length === 0);
}

function toggle(group) {
  const entry = rows.get(group.dataset.rule);
  if (!entry) return;
  entry.open = !entry.open;
  group.classList.toggle('open', entry.open);
  group.querySelector('.row').setAttribute('aria-expanded', String(entry.open));
  if (entry.open && !entry.loaded) requestOcc(group.dataset.rule, entry);
}

function renderOcc(rule, items, more) {
  const entry = rows.get(rule);
  if (!entry) return;
  entry.loaded = true;
  let html = '';
  for (const it of items) {
    html += '<div class="occ-row" data-file="' + esc(it.file) + '" data-line="' + it.line + '">' +
      '<span class="occ-loc">' + esc(it.file) + ':' + it.line + '</span>' +
      '<span class="occ-msg">' + esc(it.message) + '</span></div>';
  }
  if (more) html += '<div class="occ-more">' + esc(more) + '</div>';
  entry.el.querySelector('.occ').innerHTML = html || '<div class="occ-more">' + esc(SL.noOccurrences || '') + '</div>';
}

groupsEl.addEventListener('click', (e) => {
  const occRow = e.target.closest('.occ-row');
  if (occRow) {
    vscode.postMessage({ type: 'open', file: occRow.dataset.file, line: Number(occRow.dataset.line) });
    return;
  }
  const row = e.target.closest('.row');
  if (row) toggle(row.parentElement);
});

groupsEl.addEventListener('keydown', (e) => {
  if (e.key !== 'Enter' && e.key !== ' ') return;
  const row = e.target.closest('.row');
  if (row) { e.preventDefault(); toggle(row.parentElement); }
});

searchEl.addEventListener('input', () => {
  filter = searchEl.value.trim().toLowerCase();
  for (const [rule, entry] of rows) applyFilterTo(entry, rule);
});

window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.type === 'model') {
    applyGauge(m);
    applyChips(m.chips);
    summaryEl.textContent = m.summaryLine;
    reconcile(m.groups);
  } else if (m.type === 'occurrences') {
    renderOcc(m.rule, m.items, m.more);
  }
});

vscode.postMessage({ type: 'ready' });
`;
}

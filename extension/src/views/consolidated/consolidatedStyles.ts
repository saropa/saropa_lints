/**
 * Styles for the consolidated dashboard.
 *
 * Beauty rules (per the spec): VS Code theme tokens only — never an off-theme
 * palette that fights the user's theme; one focal element (the gauge); calm
 * rows not cards (so it stays readable at 60+ groups); motion is rare and
 * meaningful (gauge fill, chevron, a one-shot entrance fade). No framework, no
 * charting lib — the gauge is a pure conic-gradient.
 */

export function getConsolidatedStyles(): string {
  return `
/* Animatable gauge fill: registering the custom property lets the conic-gradient
   stop transition smoothly instead of snapping on each live update. */
@property --gauge-val { syntax: '<number>'; initial-value: 0; inherits: false; }

:root {
  --sev-error: var(--vscode-editorError-foreground, #f14c4c);
  --sev-warning: var(--vscode-editorWarning-foreground, #cca700);
  --sev-info: var(--vscode-editorInfo-foreground, var(--vscode-editorInformation-foreground, #3794ff));
  --hairline: var(--vscode-panel-border, var(--vscode-editorWidget-border, rgba(128,128,128,.25)));
  --row-gap: 2px;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  padding: 0;
  font-family: var(--vscode-font-family);
  font-size: var(--vscode-font-size, 13px);
  color: var(--vscode-foreground);
  background: var(--vscode-editor-background);
}

.app {
  max-width: 1080px;
  margin: 0 auto;
  padding: 22px 26px 60px;
  animation: rise .28s ease both;
}
@keyframes rise { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }

/* ── Hero ───────────────────────────────────────────────────────────────── */
.hero {
  display: flex;
  align-items: center;
  gap: 26px;
  padding: 8px 4px 22px;
}
.gauge {
  --gauge-val: 0;
  --gauge-col: var(--sev-info);
  position: relative;
  flex: 0 0 auto;
  width: 104px;
  height: 104px;
  border-radius: 50%;
  background: conic-gradient(var(--gauge-col) calc(var(--gauge-val) * 1%), var(--hairline) 0);
  transition: --gauge-val .55s cubic-bezier(.22,.61,.36,1), --gauge-col .4s ease;
}
.gauge-inner {
  position: absolute;
  inset: 9px;
  border-radius: 50%;
  background: var(--vscode-editor-background);
  display: grid;
  place-items: center;
  text-align: center;
  line-height: 1;
}
.gauge-grade { font-size: 38px; font-weight: 700; letter-spacing: -1px; }
.gauge-score { font-size: 11px; opacity: .6; margin-top: 3px; font-variant-numeric: tabular-nums; }

.hero-meta { flex: 1 1 auto; min-width: 0; }
.hero-kicker {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: .14em;
  opacity: .55;
  margin-bottom: 4px;
}
.hero-title { font-size: 22px; font-weight: 650; margin: 0 0 12px; letter-spacing: -.2px; }
.grade-label { font-size: 13px; opacity: .7; margin: 0 0 11px; min-height: 16px; }
.hero-title .live {
  display: inline-block;
  width: 7px; height: 7px;
  border-radius: 50%;
  background: var(--sev-info);
  margin-left: 10px;
  vertical-align: middle;
  animation: pulse 2.4s ease-in-out infinite;
}
@keyframes pulse { 0%,100% { opacity: .35; } 50% { opacity: 1; } }

/* Totals chips — passive aggregates; they reflect total state, never animate. */
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chip {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 5px 11px;
  border: 1px solid var(--hairline);
  border-radius: 999px;
  font-size: 12px;
  font-variant-numeric: tabular-nums;
  background: var(--vscode-editorWidget-background, transparent);
}
.chip .dot { width: 8px; height: 8px; border-radius: 50%; }
.chip.error .dot { background: var(--sev-error); }
.chip.warning .dot { background: var(--sev-warning); }
.chip.info .dot { background: var(--sev-info); }
.chip .n { font-weight: 650; }
.chip .lbl { opacity: .7; }

/* ── Toolbar ────────────────────────────────────────────────────────────── */
.toolbar { display: flex; align-items: center; gap: 10px; margin: 4px 0 14px; }
.search {
  flex: 1 1 auto;
  background: var(--vscode-input-background);
  color: var(--vscode-input-foreground);
  border: 1px solid var(--vscode-input-border, var(--hairline));
  border-radius: 6px;
  padding: 7px 11px;
  font-size: 13px;
  outline: none;
}
.search:focus { border-color: var(--vscode-focusBorder); }
.count-note { font-size: 12px; opacity: .6; white-space: nowrap; }

/* ── Rule rows ──────────────────────────────────────────────────────────── */
.groups { display: flex; flex-direction: column; gap: var(--row-gap); }
.group { border-radius: 7px; overflow: hidden; }
.row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 11px 13px;
  border: 1px solid transparent;
  border-left: 3px solid var(--hairline);
  border-radius: 7px;
  cursor: pointer;
  user-select: none;
  transition: background .12s ease, border-color .12s ease;
}
.row:hover { background: var(--vscode-list-hoverBackground); }
.row:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px; }
.group.error  .row { border-left-color: var(--sev-error); }
.group.warning .row { border-left-color: var(--sev-warning); }
.group.info   .row { border-left-color: var(--sev-info); }

.chev { flex: 0 0 auto; width: 12px; opacity: .5; transition: transform .15s ease; }
.group.open .chev { transform: rotate(90deg); }
.rule-name {
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: 12.5px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.spacer { flex: 1 1 auto; }
.sev-tag {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: .08em;
  opacity: .6;
}
.group.error  .sev-tag { color: var(--sev-error); opacity: .85; }
.group.warning .sev-tag { color: var(--sev-warning); opacity: .85; }
.count-badge {
  flex: 0 0 auto;
  min-width: 22px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  text-align: center;
  background: var(--vscode-badge-background);
  color: var(--vscode-badge-foreground);
}

/* ── Occurrences (lazy) ─────────────────────────────────────────────────── */
.occ {
  display: none;
  padding: 2px 8px 10px 30px;
  animation: fade .18s ease both;
}
.group.open .occ { display: block; }
@keyframes fade { from { opacity: 0; } to { opacity: 1; } }
.occ-row {
  display: flex;
  gap: 12px;
  align-items: baseline;
  padding: 5px 9px;
  border-radius: 5px;
  cursor: pointer;
}
.occ-row:hover { background: var(--vscode-list-hoverBackground); }
.occ-loc {
  flex: 0 0 auto;
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: 11.5px;
  color: var(--vscode-textLink-foreground);
  white-space: nowrap;
}
.occ-msg {
  flex: 1 1 auto;
  font-size: 12px;
  opacity: .72;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.occ-more { padding: 6px 9px; font-size: 11px; opacity: .55; }
.occ-loading { padding: 6px 9px; font-size: 11px; opacity: .55; }

/* ── Empty / clear state ────────────────────────────────────────────────── */
.empty {
  text-align: center;
  padding: 40px 0 20px;
  opacity: .7;
  font-size: 13px;
}
.hidden { display: none !important; }
`;
}

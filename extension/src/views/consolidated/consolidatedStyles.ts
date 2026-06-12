/**
 * Styles for the consolidated dashboard.
 *
 * Design principles (verifiable from this source, independent of rendering):
 *  - Theme-token-first: every color is a `--vscode-*` token with a layered
 *    fallback, so the dashboard inherits the user's theme instead of fighting
 *    it. No off-theme palette.
 *  - Token scales, not eyeballed values: spacing (`--s-*`, 4px rhythm), type
 *    (`--t-*`), and radii are tokens; rules consume them, never raw pixels.
 *  - Secondary text uses the semantic `--vscode-descriptionForeground` token,
 *    NOT opacity — opacity muting is not contrast-safe and washes out on
 *    textured backgrounds.
 *  - One focal element (the gauge); calm rows, not cards, so it stays readable
 *    at 60+ groups; severity is one consistent color language.
 *  - Motion is rare, one-shot, and meaningful (entrance, chevron, gauge fill).
 *    Nothing idles or pulses.
 *  - No framework, no charting lib — the gauge is a pure conic-gradient.
 */

export function getConsolidatedStyles(): string {
  return `
/* Registering the custom property lets the conic-gradient stop transition
   smoothly (numeric interpolation) instead of snapping on each live update. */
@property --gauge-val { syntax: '<number>'; initial-value: 0; inherits: false; }

:root {
  /* Spacing — 4px rhythm. */
  --s-1: 4px; --s-2: 8px; --s-3: 12px; --s-4: 16px; --s-5: 24px; --s-6: 32px; --s-8: 48px;
  /* Type scale. */
  --t-hero: 40px; --t-title: 21px; --t-body: 13px; --t-sm: 12px; --t-xs: 11px; --t-micro: 10px;
  /* Radii. */
  --r-sm: 6px; --r-md: 8px; --r-pill: 999px;

  /* Severity — one color language, reused for accent, dot, and tag. */
  --sev-error: var(--vscode-editorError-foreground, #f14c4c);
  --sev-warning: var(--vscode-editorWarning-foreground, #cca700);
  --sev-info: var(--vscode-editorInfo-foreground, var(--vscode-editorInformation-foreground, #3794ff));

  /* Secondary text — semantic token, contrast-managed by the theme. */
  --text-2: var(--vscode-descriptionForeground, var(--vscode-foreground));
  --hairline: var(--vscode-panel-border, var(--vscode-editorWidget-border, rgba(128,128,128,.22)));
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: var(--vscode-font-family);
  font-size: var(--t-body);
  color: var(--vscode-foreground);
  background: var(--vscode-editor-background);
}

.app {
  max-width: 1080px;
  margin: 0 auto;
  padding: var(--s-5) var(--s-6) var(--s-8);
  animation: rise .28s ease both;
}
@keyframes rise { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }

/* ── Hero ───────────────────────────────────────────────────────────────── */
.hero {
  display: flex;
  align-items: center;
  gap: var(--s-6);
  padding: var(--s-2) var(--s-1) var(--s-5);
}
.gauge {
  --gauge-val: 0;
  --gauge-col: var(--sev-info);
  position: relative;
  flex: 0 0 auto;
  width: 108px;
  height: 108px;
  border-radius: 50%;
  /* Track is a faint tint of the grade color so the ring reads as one object,
     not a colored arc on a gray gap. The first declaration is the safe
     fallback (neutral hairline track) for VS Code < 1.85 / Chromium < 111
     where color-mix is unsupported; the second upgrades it where available. */
  background: conic-gradient(var(--gauge-col) calc(var(--gauge-val) * 1%), var(--hairline) 0);
  background: conic-gradient(
    var(--gauge-col) calc(var(--gauge-val) * 1%),
    color-mix(in srgb, var(--gauge-col) 15%, transparent) 0
  );
  transition: --gauge-val .55s cubic-bezier(.22,.61,.36,1), --gauge-col .4s ease;
}
.gauge-inner {
  position: absolute;
  inset: 10px;
  border-radius: 50%;
  background: var(--vscode-editor-background);
  box-shadow: inset 0 0 0 1px var(--hairline);
  display: grid;
  place-items: center;
  text-align: center;
  line-height: 1;
}
.gauge-grade { font-size: var(--t-hero); font-weight: 700; letter-spacing: -1.5px; }
.gauge-score { font-size: var(--t-xs); color: var(--text-2); margin-top: var(--s-1); font-variant-numeric: tabular-nums; }

.hero-meta { flex: 1 1 auto; min-width: 0; }
.hero-kicker {
  font-size: var(--t-xs);
  text-transform: uppercase;
  letter-spacing: .14em;
  color: var(--text-2);
  margin-bottom: var(--s-1);
}
.hero-title { font-size: var(--t-title); font-weight: 650; margin: 0 0 var(--s-3); letter-spacing: -.2px; }
.grade-label { font-size: var(--t-body); color: var(--text-2); margin: 0 0 var(--s-3); min-height: 16px; }
/* "Live" indicator — a steady accent dot with a soft ring. No idle animation:
   liveness is communicated by the data updating, not by a blinking dot. */
.hero-title .live {
  display: inline-block;
  width: 7px; height: 7px;
  border-radius: 50%;
  background: var(--sev-info);
  box-shadow: 0 0 0 3px var(--hairline);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--sev-info) 22%, transparent);
  margin-left: var(--s-3);
  vertical-align: middle;
}

/* Totals chips — passive aggregates; they reflect total state, never animate. */
.chips { display: flex; flex-wrap: wrap; gap: var(--s-2); }
.chip {
  display: inline-flex; align-items: center; gap: 7px;
  padding: 5px var(--s-3);
  border: 1px solid var(--hairline);
  border-radius: var(--r-pill);
  font-size: var(--t-sm);
  font-variant-numeric: tabular-nums;
  background: var(--vscode-editorWidget-background, transparent);
}
.chip .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--text-2); }
.chip.error .dot { background: var(--sev-error); }
.chip.warning .dot { background: var(--sev-warning); }
.chip.info .dot { background: var(--sev-info); }
.chip .n { font-weight: 650; }
.chip .lbl { color: var(--text-2); }

/* ── Toolbar ────────────────────────────────────────────────────────────── */
.toolbar { display: flex; align-items: center; gap: var(--s-3); margin: var(--s-1) 0 var(--s-4); }
.search {
  flex: 1 1 auto;
  background: var(--vscode-input-background);
  color: var(--vscode-input-foreground);
  border: 1px solid var(--vscode-input-border, var(--hairline));
  border-radius: var(--r-sm);
  padding: 7px var(--s-3);
  font-size: var(--t-body);
  outline: none;
}
.search::placeholder { color: var(--vscode-input-placeholderForeground, var(--text-2)); }
.search:focus { border-color: var(--vscode-focusBorder); }
.count-note { font-size: var(--t-sm); color: var(--text-2); white-space: nowrap; }

/* ── Rule rows ──────────────────────────────────────────────────────────── */
.groups { display: flex; flex-direction: column; gap: 3px; }
.row {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  padding: var(--s-3) var(--s-3);
  border: 1px solid transparent;
  border-left: 3px solid var(--hairline);
  border-radius: var(--r-md);
  cursor: pointer;
  user-select: none;
  transition: background .12s ease, border-color .12s ease;
}
.row:hover { background: var(--vscode-list-hoverBackground); }
.row:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px; }
.group.error  .row { border-left-color: var(--sev-error); }
.group.warning .row { border-left-color: var(--sev-warning); }
.group.info   .row { border-left-color: var(--sev-info); }

.chev { flex: 0 0 auto; width: 12px; color: var(--text-2); transition: transform .15s ease; }
.group.open .chev { transform: rotate(90deg); }
.rule-name {
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: var(--t-sm);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.spacer { flex: 1 1 auto; }
.sev-tag {
  font-size: var(--t-micro);
  text-transform: uppercase;
  letter-spacing: .08em;
  color: var(--text-2);
}
.group.error  .sev-tag { color: var(--sev-error); }
.group.warning .sev-tag { color: var(--sev-warning); }
.count-badge {
  flex: 0 0 auto;
  min-width: 22px;
  padding: 2px var(--s-2);
  border-radius: var(--r-pill);
  font-size: var(--t-xs);
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  text-align: center;
  background: var(--vscode-badge-background);
  color: var(--vscode-badge-foreground);
}

/* ── Occurrences (lazy) ─────────────────────────────────────────────────── */
.occ {
  display: none;
  padding: 2px var(--s-2) var(--s-3) 30px;
  animation: fade .18s ease both;
}
.group.open .occ { display: block; }
@keyframes fade { from { opacity: 0; } to { opacity: 1; } }
.occ-row {
  display: flex;
  gap: var(--s-3);
  align-items: baseline;
  padding: 5px 9px;
  border-radius: 5px;
  cursor: pointer;
}
.occ-row:hover { background: var(--vscode-list-hoverBackground); }
.occ-loc {
  flex: 0 0 auto;
  font-family: var(--vscode-editor-font-family, monospace);
  font-size: var(--t-xs);
  color: var(--vscode-textLink-foreground);
  white-space: nowrap;
}
.occ-msg {
  flex: 1 1 auto;
  font-size: var(--t-sm);
  color: var(--text-2);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.occ-more, .occ-loading { padding: 6px 9px; font-size: var(--t-xs); color: var(--text-2); }

/* ── Empty / clear state ────────────────────────────────────────────────── */
.empty {
  text-align: center;
  padding: var(--s-8) 0 var(--s-5);
  color: var(--text-2);
  font-size: var(--t-body);
}
.hidden { display: none !important; }
`;
}

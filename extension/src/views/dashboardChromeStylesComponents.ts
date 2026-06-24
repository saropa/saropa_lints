/**
 * Component bands for the shared dashboard chrome: hero/gauge, KPI cards, toolbar/buttons, chip strip, chart/donut, and the table base.
 *
 * Part of the shared dashboard chrome stylesheet, split out of
 * dashboardChromeStyles.ts. Each function returns a static CSS string;
 * the composer there joins them with the other bands. No interpolation.
 */

/** Header band + radial gauge — title gets a subtle tint, gauge sits to the right (§4.1, §6.3). */
export function chromeHeroAndGauge(): string {
  return `
.dash-hero {
  position: relative;
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 18px;
  align-items: center;
  padding: 18px 20px;
  margin-bottom: 14px;
  border: 1px solid var(--border-strong);
  border-radius: 12px;
  background:
    radial-gradient(900px 220px at 0% 0%, var(--hero-tint), transparent 60%),
    var(--surface-2);
  animation: hero-in 360ms ease-out;
}
.hero-text { min-width: 0; }
.hero-text h1 {
  margin: 0 0 4px;
  font-size: 1.55em;
  font-weight: 600;
  letter-spacing: 0.2px;
}
.hero-text h1 .stamp {
  margin-inline-start: 10px;
  font-size: 0.55em;
  font-weight: 400;
  opacity: 0.55;
  vertical-align: middle;
  letter-spacing: 0.4px;
}
.status-line {
  margin: 0;
  color: var(--muted);
  font-size: 0.95em;
  display: flex;
  flex-wrap: wrap;
  gap: 4px 10px;
  align-items: center;
}
.status-line .dot { opacity: 0.55; }
.status-line .pill {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--surface-3);
  color: var(--vscode-foreground);
  font-size: 0.92em;
}
/* Small status-pill text mixes the semantic hue toward foreground for WCAG AA
 * on the tinted pill background. The --status/--accent tokens stay vivid for the
 * large KPI hero numbers (which meet the 3:1 large-text threshold as-is). */
.status-line .pill.good { color: color-mix(in srgb, var(--status-good) 58%, var(--vscode-foreground)); }
.status-line .pill.bad  { color: color-mix(in srgb, var(--status-bad) 44%, var(--vscode-foreground)); }
.status-line .pill.warn { color: color-mix(in srgb, var(--accent-warning) 55%, var(--vscode-foreground)); }
/* Interactive pill (e.g. "Scanned X ago" -> rescan). Reset the button chrome so
 * it reads as a pill, but keep the affordances a button needs: pointer cursor,
 * a hover lift, and a visible focus ring for keyboard users. */
.status-line .pill.pill-action {
  cursor: pointer;
  font: inherit;
  border: 1px solid transparent;
}
.status-line .pill.pill-action:hover {
  background: color-mix(in srgb, var(--vscode-focusBorder) 22%, var(--surface-3));
}
.status-line .pill.pill-action:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
.help-icon {
  flex: 0 0 auto;
  width: 24px; height: 24px;
  display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid var(--border);
  border-radius: 50%;
  background: var(--surface-3);
  color: var(--vscode-foreground);
  font-size: 11px; font-weight: 700;
  cursor: help;
  user-select: none;
}
.help-icon:focus-visible {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
.hero-gauge {
  position: relative;
  width: 96px; height: 96px;
  flex: 0 0 auto;
}
.hero-gauge svg { width: 96px; height: 96px; display: block; }
.hero-gauge .gauge-track {
  fill: none;
  stroke: var(--border);
  stroke-width: 10;
  stroke-linecap: round;
}
.hero-gauge .gauge-fill {
  fill: none;
  stroke: var(--gauge-color, var(--vscode-progressBar-background));
  stroke-width: 10;
  stroke-linecap: round;
  stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 100);
  /* Keyframe (not transition) so the arc fills on first paint. CSS transitions
     only fire on value change — on initial render the dasharray is already at
     its target, so a transition produces no animation. */
  animation: gauge-fill-in 1.1s ease-out;
  transition: stroke 0.3s;
}
@keyframes gauge-fill-in {
  from { stroke-dasharray: 0 var(--gauge-arc, 100); }
  to   { stroke-dasharray: var(--gauge-target, 0) var(--gauge-arc, 100); }
}
.gauge-label {
  position: absolute; inset: 0;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  pointer-events: none;
  text-align: center;
}
.gauge-label .lg { font-size: 1.55em; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; }
.gauge-label .sm { font-size: 0.7em; opacity: 0.7; margin-top: 2px; }
@media (prefers-reduced-motion: reduce) {
  .dash-hero { animation: none; }
  /* Disable the fill-in keyframe but keep the resting dasharray so the arc
     still renders at its target value (without 'animation: none' the resting
     rule above already drives the static state). */
  .hero-gauge .gauge-fill { animation: none; transition: none; }
}
`;
}

/** KPI strip with hero numbers (~1.85em) and preset-filter affordance (§4.2, §14.8). */
export function chromeKpiCards(): string {
  return `
.kpi-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 10px;
  margin-bottom: 14px;
}
.kpi-card {
  position: relative;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface-2);
  text-align: left;
  font: inherit;
  color: inherit;
  transition: background 0.15s, border-color 0.15s, transform 0.15s;
  display: flex; flex-direction: column; gap: 2px;
  min-width: 0;
}
.kpi-card.interactive { cursor: pointer; }
.kpi-card.interactive:hover {
  background: var(--vscode-list-hoverBackground);
  border-color: var(--border-strong);
}
.kpi-card.interactive:focus-visible {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: 1px;
}
.kpi-card.active {
  background: var(--vscode-list-activeSelectionBackground);
  color: var(--vscode-list-activeSelectionForeground);
  border-color: var(--vscode-focusBorder);
}
.kpi-k {
  text-transform: uppercase;
  font-size: 0.7em;
  letter-spacing: 0.8px;
  color: var(--muted);
  font-weight: 600;
}
.kpi-v {
  margin-top: 4px;
  font-size: 1.85em;
  font-weight: 700;
  line-height: 1.05;
  font-variant-numeric: tabular-nums;
}
.kpi-sub {
  margin-top: 4px;
  font-size: 0.82em;
  color: var(--muted);
  min-height: 1em;
}
.kpi-progress {
  height: 4px; border-radius: 2px;
  background: var(--inset);
  overflow: hidden;
  margin-top: 6px;
}
.kpi-progress > span {
  display: block; height: 100%;
  background: var(--vscode-progressBar-background);
}
.kpi-card.errors    .kpi-v { color: var(--accent-error); }
.kpi-card.warnings  .kpi-v { color: var(--accent-warning); }
.kpi-card.crit      .kpi-v { color: var(--accent-critical); }
.kpi-card.todos     .kpi-v { color: var(--accent-info); }
@media (prefers-reduced-motion: reduce) {
  .kpi-card { transition: none; }
}
`;
}

/** Toolbar band, density-tier buttons, fields, segmented controls, overflow menu. */
export function chromeToolbarAndButtons(): string {
  return `
.toolbar-band {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px 12px;
  margin-bottom: 12px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface-2);
}
.toolbar-row {
  display: flex; flex-wrap: wrap; align-items: center;
  gap: 8px 10px;
}
.toolbar-row.spread { justify-content: space-between; }
.toolbar-row label {
  color: var(--muted);
  font-size: 0.92em;
  display: inline-flex; align-items: center; gap: 6px;
}
.field {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 8px;
  border: 1px solid var(--vscode-input-border, var(--border));
  border-radius: 6px;
  background: var(--vscode-input-background);
}
.field:focus-within { border-color: var(--vscode-focusBorder); }
.field input, .field select {
  border: 0; outline: 0; background: transparent;
  color: var(--vscode-input-foreground);
  font: inherit;
  min-width: 160px;
}
.field input { flex: 1; min-width: 200px; }
.field .glyph { color: var(--muted); }
.field .clear-btn {
  border: 0; background: transparent; color: var(--muted);
  cursor: pointer; padding: 0 2px; font: inherit;
}
.field .clear-btn:hover { color: var(--vscode-foreground); }
/* Inverted toggle visual model (guideline §14.15): pressed = quiet (the default state),
   unpressed = ghosted (the diverged state). The track band is the only persistent chrome;
   pressed buttons render as plain text + swatch + the track. The primary-button background
   is **never** used here — it is reserved for tier-1 actions in the same toolbar. */
.seg {
  display: inline-flex; flex-wrap: wrap; align-items: center;
  gap: 2px;
  padding: 3px 4px;
  border: 1px solid var(--border);
  border-radius: 999px;
  background: var(--surface-3);
}
.seg .seg-label {
  padding: 0 8px 0 6px;
  /* Lift off plain --muted (which dips under AA on the seg band) toward
     foreground; uppercase + letter-spacing keep it reading as a label. */
  color: color-mix(in srgb, var(--vscode-foreground) 72%, var(--muted));
  font-size: 0.85em;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  font-weight: 600;
}
.seg .seg-btn {
  border: 1px solid transparent;
  border-radius: 999px;
  padding: 3px 10px;
  font: inherit; font-size: 0.9em;
  color: var(--vscode-foreground);
  background: transparent;
  cursor: pointer;
  display: inline-flex; align-items: center; gap: 6px;
  transition: opacity 0.12s, color 0.12s, border-color 0.12s;
}
.seg .seg-btn .swatch {
  width: 9px; height: 9px;
  border-radius: 50%;
  display: inline-block;
  background: var(--vscode-foreground);
  flex: 0 0 auto;
  transition: opacity 0.12s, transform 0.12s;
}
/* Pressed = INCLUDED — the default, quiet state. Plain text + colored swatch.
   No primary-button background; the swatch carries the on-state signal and the track
   band carries the toggle-group signal. */
.seg .seg-btn[aria-pressed="true"],
.seg .seg-btn[aria-checked="true"] {
  color: var(--vscode-foreground);
  font-weight: 500;
  opacity: 1;
}
/* Unpressed = EXCLUDED — the diverged state. Ghosted, strike-through, desaturated swatch.
   This is the loud signal: "you have actively removed this category from the view." */
.seg .seg-btn[aria-pressed="false"],
.seg .seg-btn[aria-checked="false"] {
  color: var(--muted);
  opacity: 0.5;
  text-decoration: line-through;
  text-decoration-color: color-mix(in srgb, var(--muted) 60%, transparent);
}
.seg .seg-btn[aria-pressed="false"] .swatch,
.seg .seg-btn[aria-checked="false"] .swatch {
  opacity: 0.4;
  transform: scale(0.85);
}
.seg .seg-btn:hover {
  opacity: 1;
  background: color-mix(in srgb, var(--vscode-list-hoverBackground) 60%, transparent);
}
.seg .seg-btn:focus-visible {
  outline: 1px solid var(--vscode-focusBorder); outline-offset: 1px;
}
/* .seg.additive variant — for filters where the resting state is "no constraint applied"
   and pressing a button ADDS a constraint (e.g. "Show only detected", "Show only enabled").
   The diverged state here is *pressed*, not *unpressed*, so the inversion above doesn't
   apply: pressed = active filter, soft tinted background; unpressed = inactive, quiet text.
   Primary-button colors stay off-limits per §14.15. */
.seg.additive .seg-btn[aria-pressed="false"] {
  color: var(--vscode-foreground);
  opacity: 0.85;
  text-decoration: none;
  font-weight: 400;
}
.seg.additive .seg-btn[aria-pressed="false"] .swatch { opacity: 1; transform: none; }
.seg.additive .seg-btn[aria-pressed="true"] {
  background: var(--vscode-list-activeSelectionBackground);
  color: var(--vscode-list-activeSelectionForeground);
  font-weight: 600;
  opacity: 1;
  text-decoration: none;
}
.btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 12px;
  border-radius: 999px;
  /* Guide §5.4: a secondary button MUST keep a visible edge and a fallback fill. Several host
     themes leave button-border / button-secondaryBackground undefined or near-equal to the
     surface behind it; without both fallbacks the control renders as bare text and reads as a
     link, not a button. */
  border: 1px solid var(--vscode-button-border, var(--border));
  background: var(--vscode-button-secondaryBackground, var(--surface-3));
  color: var(--vscode-button-secondaryForeground);
  cursor: pointer;
  font: inherit; font-size: 0.95em;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
}
.btn .glyph { font-size: 1em; line-height: 1; }
.btn:hover:not(:disabled) {
  background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
  border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, transparent);
}
.btn:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
.btn:disabled { opacity: 0.45; cursor: not-allowed; }
.btn.tier-1 {
  background: var(--vscode-button-background);
  color: var(--vscode-button-foreground);
  font-weight: 600;
}
.btn.tier-1:hover:not(:disabled) {
  background: var(--vscode-button-hoverBackground, var(--vscode-button-background));
}
.btn.tier-3 {
  padding: 4px 10px;
  font-size: 0.88em;
  background: var(--surface-3);
  color: var(--vscode-foreground);
  border-color: var(--border);
  border-radius: 6px;
}
.btn.tier-3:hover:not(:disabled) { background: var(--vscode-list-hoverBackground); }
.btn.danger {
  color: var(--accent-error);
  border-color: color-mix(in srgb, var(--accent-error) 50%, transparent);
}
.btn.icon-only { padding: 6px 10px; }
details.more { position: relative; }
details.more > summary { list-style: none; cursor: pointer; }
details.more > summary::-webkit-details-marker { display: none; }
details.more[open] > summary .chev { transform: rotate(180deg); }
details.more > summary .chev { display: inline-block; transition: transform 0.15s linear; }
details.more .menu {
  position: absolute;
  top: calc(100% + 6px);
  /* §23.1 — anchor to the inline-end edge of the trigger so the dropdown
     opens leftward in LTR (its natural direction) and rightward in RTL.
     inset-inline-end:0 flips automatically with the dir attribute. */
  inset-inline-end: 0;
  min-width: 220px;
  max-width: 320px;
  padding: 6px;
  display: grid; gap: 4px;
  background: var(--vscode-editorWidget-background);
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.18);
  z-index: 20;
  animation: menu-in 0.14s ease-out;
}
details.more .menu .menu-item {
  display: flex; align-items: center; justify-content: space-between;
  gap: 8px;
  padding: 6px 10px;
  border-radius: 5px;
  cursor: pointer;
  background: transparent;
  color: var(--vscode-foreground);
  border: 0;
  font: inherit; font-size: 0.92em;
  text-align: left;
  width: 100%;
}
details.more .menu .menu-item:hover:not(:disabled) {
  background: var(--vscode-list-hoverBackground);
}
details.more .menu .menu-item:disabled {
  opacity: 0.45; cursor: not-allowed;
}
details.more .menu .menu-item:focus-visible {
  outline: 1px solid var(--vscode-focusBorder); outline-offset: -1px;
}
`;
}

/** Active-filter chip strip (§8.5, §14.10). */
export function chromeChipStrip(): string {
  return `
.chip-strip {
  display: flex; flex-wrap: wrap; align-items: center;
  gap: 6px;
  padding: 6px 8px;
  margin-bottom: 12px;
  border: 1px dashed var(--border-strong);
  border-radius: 8px;
  background: color-mix(in srgb, var(--surface-3) 65%, transparent);
}
.chip-strip[hidden] { display: none; }
.chip-strip .lbl { color: var(--muted); font-size: 0.9em; margin-inline-end: 2px; }
.chip {
  display: inline-flex; align-items: center;
  gap: 4px;
  padding: 2px 4px 2px 10px;
  border-radius: 999px;
  background: var(--vscode-badge-background);
  color: var(--vscode-badge-foreground);
  font-size: 0.88em;
  animation: chip-in 0.14s ease-out;
}
.chip .x {
  cursor: pointer;
  border: 0; background: transparent; color: inherit;
  font: inherit;
  padding: 0 5px;
  border-radius: 999px;
  opacity: 0.8;
}
.chip .x:hover {
  opacity: 1;
  background: rgba(0, 0, 0, 0.18);
}
.chip-strip .clear-all {
  margin-inline-start: auto;
  color: var(--link);
  background: transparent;
  border: 0;
  cursor: pointer;
  padding: 2px 4px;
  font: inherit; font-size: 0.9em;
}
.chip-strip .clear-all:hover { text-decoration: underline; }
`;
}

/** Bar+donut companion charts and the chart card frame (§6.1). */
export function chromeChartAndDonut(): string {
  // Categorical hue palette for donut companions (§2.3) — 10 distinct slots; consumers use
  // var(--chart-hue-N) where N is the segment index modulo 10.
  return `
.chart-card {
  --chart-hue-0: hsl(210, 70%, 55%);
  --chart-hue-1: hsl(150, 55%, 50%);
  --chart-hue-2: hsl( 35, 80%, 55%);
  --chart-hue-3: hsl(280, 55%, 60%);
  --chart-hue-4: hsl(  5, 70%, 60%);
  --chart-hue-5: hsl(190, 60%, 50%);
  --chart-hue-6: hsl(110, 50%, 45%);
  --chart-hue-7: hsl(325, 55%, 60%);
  --chart-hue-8: hsl( 60, 60%, 50%);
  --chart-hue-9: hsl(245, 55%, 60%);
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--surface-2);
}
.chart-card h3 {
  margin: 0 0 10px;
  font-size: 0.98em;
  font-weight: 600;
  display: flex; align-items: baseline; gap: 8px;
}
.chart-card h3 .count {
  font-size: 0.82em;
  color: var(--muted);
  font-weight: 500;
}
.chart-card .body {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
}
@media (max-width: 720px) {
  .chart-card .body { grid-template-columns: 1fr; }
}
.bar-row {
  display: grid;
  grid-template-columns: minmax(120px, 30%) 1fr 48px;
  align-items: center;
  gap: 8px;
  padding: 4px 6px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.92em;
  transition: background 0.15s;
}
.bar-row:hover { background: var(--vscode-list-hoverBackground); }
.bar-row:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: -1px;
}
.bar-row.zero { opacity: 0.45; cursor: default; }
.bar-row.zero:hover { background: transparent; }
.bar-row.active {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: -1px;
}
.bar-label {
  text-transform: capitalize;
  color: var(--vscode-foreground);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.bar-track {
  height: 8px;
  border-radius: 999px;
  background: var(--border);
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  border-radius: 999px;
  width: var(--bar-width, 0%);
  background: var(--vscode-progressBar-background);
  animation: grow-x 520ms ease-out;
  transform-origin: left center;
}
.bar-fill.enabled { background: var(--vscode-button-background); }
.bar-fill.detected {
  box-shadow: inset 0 0 0 1px var(--status-good);
}
.bar-fill.sev-error      { background: var(--accent-error); }
.bar-fill.sev-warning    { background: var(--accent-warning); }
.bar-fill.sev-info       { background: var(--accent-info); }
.bar-fill.imp-critical   { background: var(--accent-critical); }
.bar-fill.imp-high       { background: var(--accent-high); }
.bar-fill.imp-medium     { background: var(--accent-medium); }
.bar-fill.imp-low        { background: var(--accent-low); }
.bar-fill.imp-opinionated { background: var(--accent-opinionated); }
.bar-value {
  text-align: right;
  font-variant-numeric: tabular-nums;
  color: var(--muted);
}
.donut-wrap {
  width: 120px; height: 120px;
  position: relative;
  display: flex; align-items: center; justify-content: center;
}
.donut svg {
  width: 100%; height: 100%;
  transform: rotate(-90deg);
  display: block;
}
.donut .seg, .donut .donut-seg {
  fill: transparent;
  stroke-width: 16;
  stroke: var(--seg-color, var(--vscode-progressBar-background));
  cursor: pointer;
  transition: stroke-width 0.15s, opacity 0.15s;
}
.donut .seg:hover, .donut .donut-seg:hover { stroke-width: 18; }
.donut .seg:focus-visible, .donut .donut-seg:focus-visible {
  outline: 2px solid var(--vscode-focusBorder); outline-offset: 2px;
}
.donut .donut-track {
  fill: transparent;
  stroke: var(--inset);
  stroke-width: 14;
  opacity: 0.7;
}
.donut[data-has-active="1"] .seg:not(.active),
.donut[data-has-active="1"] .donut-seg:not(.active) {
  opacity: 0.35;
}
.donut .seg.active, .donut .donut-seg.active {
  stroke-width: 20;
  filter: brightness(1.1);
}
.donut-legend {
  position: absolute; inset: 0;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  pointer-events: none;
}
.donut-legend .total {
  font-size: 1.25em;
  font-weight: 700;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.donut-legend .lbl {
  font-size: 0.68em;
  color: var(--muted);
  margin-top: 2px;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}
.chart-legend {
  display: inline-flex; gap: 12px;
  font-size: 0.78em;
  color: var(--muted);
}
.chart-legend-item {
  display: inline-flex; align-items: center; gap: 4px;
}
.legend-swatch {
  display: inline-block; width: 10px; height: 10px;
  border-radius: 2px;
  background: var(--vscode-progressBar-background);
}
.legend-swatch.detected {
  background: transparent;
  box-shadow: inset 0 0 0 2px var(--status-good);
}
.legend-swatch.enabled { background: var(--vscode-button-background); }
@media (prefers-reduced-motion: reduce) {
  .bar-fill { animation: none; transform: scaleX(1); }
}
`;
}

/** Sortable, sticky-header table base (§7). Dashboard-specific column rules layer on top. */
export function chromeTableBase(): string {
  return `
.dash-table-wrap {
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
  background: var(--surface-2);
}
.dash-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.92em;
}
.dash-table thead th {
  position: sticky;
  top: 0;
  background: var(--surface-3);
  text-align: left;
  font-weight: 600;
  font-size: 0.82em;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: var(--muted);
  padding: 6px 10px;
  border-bottom: 1px solid var(--border);
  user-select: none;
  white-space: nowrap;
}
.dash-table thead th.sortable { cursor: pointer; }
.dash-table thead th .arrow { opacity: 0.4; margin-inline-start: 4px; }
.dash-table thead th[aria-sort="ascending"]  .arrow { opacity: 1; }
.dash-table thead th[aria-sort="descending"] .arrow { opacity: 1; }
.dash-table tbody tr { border-bottom: 1px solid var(--border); }
.dash-table tbody tr:last-child { border-bottom: 0; }
.dash-table tbody tr:hover { background: var(--vscode-list-hoverBackground); }
.dash-table tbody tr:focus-within {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: -1px;
}
.dash-table td { padding: 6px 10px; vertical-align: middle; }
.dash-table td.num {
  text-align: right;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.empty-row td {
  text-align: center; padding: 18px 12px;
  color: var(--muted);
}
.empty-row .reset-link {
  background: transparent; border: 0; color: var(--link);
  cursor: pointer; font: inherit; padding: 0;
}
.empty-row .reset-link:hover { text-decoration: underline; }
`;
}

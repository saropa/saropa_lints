/**
 * Cross-cutting chrome styles: micro-interactions/motion, empty & error states, accessibility, print, and reduced-motion overrides.
 *
 * Part of the shared dashboard chrome stylesheet, split out of
 * dashboardChromeStyles.ts. Each function returns a static CSS string;
 * the composer there joins them with the other bands. No interpolation.
 */

/**
 * §8 — Plain anchor + `.link`-as-button styling. Split out of the former
 * `chromeMicroAndMotion` bundle (see that function's doc comment below) so a
 * consumer that wants only link styling never also pulls in the monospace
 * font rule, section-heading rules, or keyframes.
 */
export function chromeLinks(): string {
  return `
a { color: var(--link); cursor: pointer; text-decoration: none; }
a:hover { text-decoration: underline; }
.link {
  color: var(--link);
  cursor: pointer;
  background: transparent;
  border: 0;
  padding: 0;
  font: inherit;
}
.link:hover { text-decoration: underline; }
`;
}

/**
 * `code, .mono` monospace font-family rule — its own concern.
 *
 * THIS is the exact rule PLAN_ext_ui_report_styles.md's audit named as the reason
 * `report-styles-parts.ts` could not adopt the old bundled `chromeMicroAndMotion()`
 * just to get `@keyframes hero-in`: opportunities-html.ts' `.opp-chip` elements are
 * tagged with `code`, so importing this rule alongside the keyframe would silently
 * repaint them in the editor monospace font. Keeping it as its own export means a
 * consumer can now take `chromeKeyframeHeroIn()` without this side effect.
 */
export function chromeMonospace(): string {
  // NOTE: no leading newline -- chromeMicroAndMotion() concatenates these pieces
  // with `+`, no separator, and the preceding chromeLinks() piece already ends in
  // "\n". Adding one here would insert a blank line the pre-split output never had
  // and break the Phase 1 byte-identical gate.
  return `code, .mono {
  font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
}
`;
}

/**
 * `.section` heading band (count/meta annotations) — its own concern.
 *
 * Task A (Findings dashboard only): `buildCollapsibleSection` in
 * violations-dashboard-shared.ts now renders `.section` as a native
 * `<details>` with its heading wrapped in `<summary>`. Several OTHER
 * consumers of this shared chrome (rulePacksWebviewProvider's Lints Config
 * tab, relatedRuleTelemetryView, projectVibrancyReportView's Code Health
 * table) still render `.section` as a plain `<section>` with `<h2>` as a
 * DIRECT child and are NOT part of this task — so the original `> h2`
 * selector stays, unmodified, and the new `> summary > h2` selector is
 * ADDED alongside it rather than replacing it. Removing the original would
 * silently unstyle every heading in those other dashboards. The rest of
 * this function hides the native disclosure triangle and replaces it with a
 * rotating chevron, matching the existing `.sup-disclosure` / `details.more`
 * pattern elsewhere in this stylesheet rather than inventing a third
 * disclosure look.
 */
export function chromeSectionHeadings(): string {
  // NOTE: no leading newline -- see chromeMonospace's comment.
  return `.section { margin-bottom: 14px; }
.section > h2, .section > summary > h2 {
  margin: 0 0 8px;
  font-size: 1.05em;
  font-weight: 600;
  letter-spacing: 0.2px;
  display: flex; align-items: baseline; gap: 8px;
}
.section > h2 .count, .section > h2 .meta,
.section > summary > h2 .count, .section > summary > h2 .pill, .section > summary > h2 .meta {
  font-size: 0.82em;
  color: var(--muted);
  font-weight: 500;
}
.section > h2 .meta, .section > summary > h2 .meta { margin-inline-start: auto; font-weight: 400; }
/* Native-<details> variant only (Findings dashboard) — hide the default
   disclosure triangle and draw a rotating chevron instead, matching the
   existing .sup-disclosure / details.more pattern rather than inventing a
   third disclosure look. */
.section > summary {
  cursor: pointer;
  list-style: none;
}
.section > summary::-webkit-details-marker { display: none; }
.section > summary::before {
  content: '▸';
  display: inline-block;
  margin-inline-end: 6px;
  color: var(--muted);
  transition: transform 0.12s linear;
}
.section[open] > summary::before { transform: rotate(90deg); }
.section > summary:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
/* > h2 above sets display:flex (a block-level box) which is right for the
   original direct-child-of-section usage but would force the heading onto
   its own line under the chevron inside <summary> (an inline-context
   parent) — override back to inline-flex for the <summary> variant only. */
.section > summary > h2 { display: inline-flex; margin-bottom: 0; }
.section > .section-body { margin-top: 8px; }
`;
}

/**
 * `@keyframes hero-in` ONLY — isolated from every other keyframe and from the
 * unrelated link/monospace/section rules above so a consumer (report-styles-parts.ts)
 * can adopt exactly this animation for its own `.dash-hero` without also emitting
 * `code, .mono` or the other four keyframes below. This is the single rule
 * PLAN_ext_ui_report_styles.md Phase 2 needed unblocked.
 */
export function chromeKeyframeHeroIn(): string {
  // NOTE: no leading newline -- see chromeMonospace's comment.
  return `@keyframes hero-in { from { opacity: 0; transform: translateY(-4px); } to { opacity: 1; transform: translateY(0); } }
`;
}

/**
 * The remaining four chrome keyframes (card/chip/menu-in, grow-x), grouped
 * together since they are all "supplementary chrome keyframes" used by the
 * KPI card / chip-strip / overflow-menu / bar-chart components — a single
 * concern distinct from `chromeKeyframeHeroIn` only because Phase 2 needs
 * hero-in in isolation, not because these four are unrelated to each other.
 */
export function chromeKeyframesSecondary(): string {
  // NOTE: no leading newline -- see chromeMonospace's comment.
  return `@keyframes card-in { from { opacity: 0; transform: translateY(4px); }  to { opacity: 1; transform: translateY(0); } }
@keyframes chip-in { from { opacity: 0; transform: scale(0.92); }       to { opacity: 1; transform: scale(1); } }
@keyframes menu-in { from { opacity: 0; transform: translateY(-4px); }  to { opacity: 1; transform: translateY(0); } }
@keyframes grow-x  { from { transform: scaleX(0); }                     to { transform: scaleX(1); } }
`;
}

/**
 * Links, animations, reduced-motion fallbacks — COMPOSED from the fine-grained
 * exports above in their original textual order. Kept as the public entry point
 * so every existing consumer (`dashboardChromeStyles.ts`'s `getDashboardChromeStyles()`)
 * keeps calling exactly what it calls today; output is byte-identical to what the
 * single monolithic function emitted before the Phase 1 split (verified via a
 * captured-baseline diff — see PLAN_ext_ui_report_styles.md and
 * dashboardChromeStylesSeams.test.ts).
 */
export function chromeMicroAndMotion(): string {
  return (
    chromeLinks() +
    chromeMonospace() +
    chromeSectionHeadings() +
    chromeKeyframeHeroIn() +
    chromeKeyframesSecondary()
  );
}

/**
 * §8.16 — Empty / loading / error / partial / offline / stale state primitives.
 *
 * Lifted out of the per-surface stylesheets because four dashboards were
 * shipping their own copies (Findings, Code Health, Telemetry, Known Issues).
 * Per-surface stylesheets can still override individual rules; this module
 * provides the baseline so a new dashboard inherits the gold-standard look
 * without copy-pasting CSS.
 *
 * Tier-1 button inside `.empty-cta` reuses `.btn.tier-1` from the toolbar
 * section so the empty-state CTA matches the toolbar's primary action.
 */
export function chromeEmptyAndError(): string {
  return `
.empty-cta {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 24px 16px;
  margin: 12px 0;
  border: 1px dashed var(--border);
  border-radius: 6px;
  background: var(--surface-2);
}
.empty-cta .empty-msg {
  margin: 0;
  color: var(--muted);
  font-size: 0.95em;
  text-align: center;
}
.empty-cta .empty-title {
  margin: 0;
  font-size: 1.05em;
  font-weight: 600;
}

/* Generic error banner — input-validation tokens, border-left accent. */
.error-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 12px;
  padding: 8px 12px;
  border-radius: 6px;
  border-inline-start: 3px solid var(--vscode-inputValidation-errorBorder);
  background: var(--vscode-inputValidation-errorBackground);
  color: var(--vscode-inputValidation-errorForeground);
  font-size: 0.92em;
}
.error-banner .error-msg { flex: 1 1 auto; }
.error-banner .btn { flex: 0 0 auto; }

/* Per-section error-boundary fallback (§8.16.8) — single component failed
 * but the rest of the page is still useful, so render a small inline band. */
.error-fallback {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px;
  margin: 8px 0;
  border: 1px dashed var(--vscode-inputValidation-warningBorder, var(--border));
  border-radius: 6px;
  background: var(--surface-2);
  color: var(--muted);
  font-size: 0.9em;
}

/* Stale-data warning pill that replaces the freshness pill in the status line
 * when the most recent refresh failed (§8.16.6). */
.status-line .pill.stale {
  color: var(--accent-warning);
  border-bottom: 1px dashed var(--accent-warning);
}

/* Partial-failure banner for multi-source loads (§8.16.3). */
.partial-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 0 12px;
  padding: 6px 10px;
  border-radius: 4px;
  background: color-mix(in srgb, var(--accent-warning) 14%, transparent);
  color: var(--accent-warning);
  font-size: 0.9em;
}
.partial-banner .partial-msg { flex: 1 1 auto; color: var(--vscode-foreground); }
`;
}

/**
 * §15 — Accessibility primitives shared across all editor-area dashboards.
 *
 * Exposes:
 *   - `.sr-only` — visually-hidden but screen-reader-readable text used for
 *     icon-only buttons and contextual hints.
 *   - `.skip-link` — keyboard-only "Skip to table" affordance per §15.2;
 *     surfaces with long hero+toolbar regions wire it up so keyboard users
 *     can bypass navigation.
 *   - `#announcer` — single polite live region every dashboard injects
 *     filter / sort / count change messages into (§15.3).
 *   - Focus ring — restated for elements that opt out of the default
 *     browser outline; surfaces must NOT set `outline: none` without an
 *     immediate replacement that uses --vscode-focusBorder.
 */
export function chromeAccessibility(): string {
  return `
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* Skip link — visible only on focus so keyboard users can bypass the
 * hero / toolbar block and jump straight to the data table. */
.skip-link {
  position: absolute;
  top: -100px;
  /* §23.1 — anchor at the inline-start edge so the focused skip link
     pops in from the natural reading-direction corner (top-left in LTR,
     top-right in RTL). */
  inset-inline-start: 8px;
  z-index: 1000;
  padding: 6px 12px;
  background: var(--vscode-button-background);
  color: var(--vscode-button-foreground);
  border-radius: 4px;
  font-size: 0.9em;
  text-decoration: none;
}
.skip-link:focus {
  top: 8px;
}

/* Polite live region — sits hidden in the DOM; surfaces inject filter
 * / sort / count change messages here. Screen readers announce updates
 * without interrupting the user's current task. */
#announcer {
  /* Re-uses .sr-only positioning but with a known id so script can find it. */
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* High-contrast focus ring for elements that strip the browser default. */
.focus-ring:focus-visible,
[tabindex]:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
`;
}

/**
 * §22.1 — Print stylesheet.
 *
 * Editor-area dashboards are occasionally printed or exported as PDF for
 * share-out. Strip the chrome that doesn't make sense on paper (sticky
 * headers, hover affordances, full-width toggle), preserve the data with
 * visible borders, and respect the user's intent for colored badges
 * (`print-color-adjust: exact`).
 */
export function chromePrintStyles(): string {
  return `
@media print {
  /* Strip chrome that doesn't translate to paper. */
  .toolbar-band,
  .full-width-toggle,
  .row-action,
  details.more,
  .skip-link,
  .chip-strip {
    display: none !important;
  }

  /* Disable sticky positioning so headers don't duplicate per page. */
  .dash-table thead,
  .toolbar-band {
    position: static !important;
  }

  /* Preserve KPI / pill / badge colors so severity reads on paper. */
  .kpi-card,
  .pill,
  .badge,
  .grade-badge,
  .sev-pill,
  .flag-pill {
    print-color-adjust: exact;
    -webkit-print-color-adjust: exact;
  }

  /* Plain background, dark text — keeps ink usage reasonable. */
  body {
    background: white !important;
    color: black !important;
    max-width: none !important;
  }

  /* Cells visible on plain paper — even if the screen used very subtle borders. */
  .dash-table th,
  .dash-table td {
    border: 1px solid #999 !important;
  }

  /* Keep table rows from splitting across pages. */
  .dash-table tr {
    break-inside: avoid;
    page-break-inside: avoid;
  }

  /* Suppress hover affordances in case they leak through. */
  .dash-table tr:hover,
  .kpi-card:hover {
    background: transparent !important;
  }
}
`;
}

/**
 * §5.2 — Reduced-motion overrides for every named keyframe in the chrome.
 *
 * Per-surface stylesheets that define their own animations must add their
 * own \`@media (prefers-reduced-motion: reduce)\` override; this block
 * covers the chrome's keyframes so a surface that uses only chrome
 * animations is automatically reduced-motion-compliant.
 *
 * The end-state must still apply — never set \`animation: none\` and
 * leave the element in its starting position; that's a regression for
 * users who can't see the animation anyway.
 */
export function chromeReducedMotion(): string {
  return `
@media (prefers-reduced-motion: reduce) {
  .dash-hero,
  .kpi-card,
  .chip,
  details.more .menu,
  .bar-row .bar-fill {
    animation: none !important;
    transition: none !important;
  }
}
`;
}

/**
 * Design tokens (:root custom properties) and base page layout for the shared dashboard chrome.
 *
 * Part of the shared dashboard chrome stylesheet, split out of
 * dashboardChromeStyles.ts. Each function returns a static CSS string;
 * the composer there joins them with the other bands. No interpolation.
 */

/** Surface tokens, accent palette, motion-friendly tints. Shared across all three dashboards. */
export function chromeTokens(): string {
  return `
:root {
  --surface-1: var(--vscode-editor-background);
  --surface-2: var(--vscode-editorWidget-background);
  --surface-3: var(--vscode-editor-inactiveSelectionBackground);
  --inset: var(--vscode-input-background);
  --border: var(--vscode-widget-border);
  --border-strong: color-mix(in srgb, var(--vscode-focusBorder) 35%, var(--vscode-widget-border));
  --muted: var(--vscode-descriptionForeground);
  --link: var(--vscode-textLink-foreground);
  --accent-error: var(--vscode-editorError-foreground);
  --accent-warning: var(--vscode-editorWarning-foreground);
  --accent-info: var(--vscode-editorInfo-foreground);
  --accent-critical: var(--vscode-editorError-foreground);
  --accent-high: color-mix(in srgb, var(--vscode-editorError-foreground) 60%, var(--vscode-editorWarning-foreground));
  --accent-medium: var(--vscode-editorWarning-foreground);
  --accent-low: var(--vscode-editorInfo-foreground);
  --accent-opinionated: var(--vscode-descriptionForeground);
  --hero-tint: color-mix(in srgb, var(--vscode-textLink-foreground) 14%, transparent);
  --status-good: var(--vscode-testing-iconPassed, var(--vscode-editorInfo-foreground));
  --status-bad: var(--vscode-editorError-foreground);

  /* --- Scale tokens (SAROPA_DASHBOARD_STYLE_GUIDE §3.7–3.13) ---
     Added so every surface converges on ONE spacing/radius/type/motion system instead of
     each hardcoding its own. Additive only: existing components keep their literal values
     until migrated, so the established dashboards are visually unchanged. New/migrated
     surfaces reference these names. */

  /* Spacing — 4px base. */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px;  --space-4: 16px;
  --space-5: 24px; --space-6: 32px; --space-8: 48px;

  /* Radius. */
  --radius-sm: 3px; --radius: 8px; --radius-lg: 12px; --radius-pill: 999px;

  /* Type scale — anchored to the chrome's 13px VS Code density (host is denser than a
     standalone report); ratio ~1.2. Pair each with the line-height below at the call site. */
  --text-eyebrow: 11px; --text-caption: 11px; --text-body: 13px; --text-label: 13px;
  --text-h3: 15px; --text-h2: 18px; --text-h1: 22px; --text-kpi: 28px; --text-kpi-xl: 40px;

  /* Elevation. VS Code's language is flat — prefer border + surface step over shadow; these
     are reserved for true overlays (popovers, drill-downs). */
  --shadow: 0 1px 2px rgba(0,0,0,.12), 0 1px 3px rgba(0,0,0,.10);
  --shadow-lg: 0 4px 12px rgba(0,0,0,.18), 0 10px 30px -8px rgba(0,0,0,.28);

  /* Motion. */
  --ease: cubic-bezier(.2,.6,.2,1);
  --dur-fast: 80ms; --dur: 160ms; --dur-slow: 300ms;

  /* Z-index layers. */
  --z-base: 0; --z-sticky: 50; --z-overlay: 100; --z-modal: 200; --z-toast: 300;

  /* Letter-grade ramp (guide §5.8) — each grade reads the same hue as the matching severity
     so a grade and a severity never disagree on color. Derived from the semantic tokens; never
     a bespoke grade green/red. The guide ramp lists A/B/C/D/F; E sits between D and F for the
     surfaces whose data carries an E grade. */
  --grade-a: var(--status-good);
  --grade-b: color-mix(in srgb, var(--status-good) 55%, var(--accent-warning));
  --grade-c: var(--accent-warning);
  --grade-d: var(--accent-high);
  --grade-e: color-mix(in srgb, var(--accent-high) 50%, var(--status-bad));
  --grade-f: var(--status-bad);

  /* Saropa brand accent — the ONLY fixed colors in the system. Available for surfaces that
     opt into the brand mark (eyebrow, top strip, focus ring); NOT applied to chrome
     components by default, so adopting the chrome never repaints a host-themed dashboard. */
  --brand: #f97316;
  --brand-2: #ea580c;
  --brand-glow: rgba(249,115,22,.20);
  --ring: 0 0 0 3px rgba(249,115,22,.32);
}
`;
}

/** Body fonts, page padding, helper utilities. */
export function chromeBaseLayout(): string {
  // Padding matches Findings (18px top/bottom, 18px sides) so the three dashboards line up
  // when the user toggles between them.
  //
  // Content max-width: editor panes can be 4000+px wide on ultrawide monitors; long-line text
  // and dense KPI strips become unreadable past ~1300px. We constrain to a readable width by
  // default and offer a `body[data-full-width="true"]` override that dashboards toggle via the
  // `.full-width-toggle` button. Persistence is ephemeral (per webview session) — VS Code retains
  // body markup across hidden/shown via `retainContextWhenHidden`, so the toggle survives focus
  // changes within a session even without `vscode.setState()`. See guideline §4.
  return `
* { box-sizing: border-box; }
body {
  margin: 0 auto;
  padding: 18px 18px 28px;
  max-width: 1280px;
  font-family: var(--vscode-font-family);
  font-size: 13px;
  line-height: 1.45;
  color: var(--vscode-foreground);
  background: var(--surface-1);
}
body[data-full-width="true"] { max-width: none; }
.sr-only {
  position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
  overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
.muted { color: var(--muted); }
.full-width-toggle {
  /* Square icon button anchored in the hero corner; size matches the help-icon for visual rhyme. */
  flex: 0 0 auto;
  width: 28px; height: 28px;
  display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: var(--surface-3);
  color: var(--vscode-foreground);
  font-size: 13px; font-weight: 500;
  cursor: pointer;
  user-select: none;
  transition: background 0.12s, border-color 0.12s;
}
.full-width-toggle:hover { background: var(--vscode-list-hoverBackground); border-color: var(--border-strong); }
.full-width-toggle:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px; }
body[data-full-width="true"] .full-width-toggle { background: var(--vscode-list-activeSelectionBackground); border-color: var(--vscode-focusBorder); }
.status-line .full-width-toggle { margin-inline-start: auto; }
`;
}

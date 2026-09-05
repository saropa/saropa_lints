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

/**
 * §1 — Universal box-sizing reset. Split out on its own (was bundled into
 * `chromeBaseLayout` alongside the body reset and the full-width-toggle button)
 * so a consumer that wants ONLY this reset — with no opinion on body padding/
 * max-width or the toggle button — can take it without inheriting either.
 */
export function chromeBoxSizingReset(): string {
  return `
* { box-sizing: border-box; }
`;
}

/**
 * §4 — Body fonts, page padding, max-width. Split out from the former
 * `chromeBaseLayout` bundle: this is the "plain body reset" concern only —
 * it does NOT include the `.full-width-toggle` button or the
 * `body[data-full-width="true"]` override that un-does its own max-width,
 * because a consumer of the plain reset should not silently also get an
 * unused toggle button's CSS. See `chromeFullWidthMaxWidthOverride` and
 * `chromeFullWidthToggleButton` for that half of the concern.
 *
 * Padding matches Findings (18px top/bottom, 18px sides) so the three dashboards line up
 * when the user toggles between them.
 */
export function chromeBodyReset(): string {
  // NOTE: no leading newline in this template literal (unlike the other exports in this
  // file) -- chromeBaseLayout() concatenates these pieces with `+`, no separator, and the
  // preceding chromeBoxSizingReset() piece already supplies the newline between the two
  // rules. Adding one here would insert a blank line not present in the pre-split output
  // and break the Phase 1 byte-identical gate.
  return `body {
  margin: 0 auto;
  padding: 18px 18px 28px;
  max-width: 1280px;
  font-family: var(--vscode-font-family);
  font-size: 13px;
  line-height: 1.45;
  color: var(--vscode-foreground);
  background: var(--surface-1);
}
`;
}

/**
 * §4 — The `body[data-full-width="true"]` max-width override that undoes
 * `chromeBodyReset`'s 1280px cap. Kept separate from `chromeFullWidthToggleButton`
 * (below) only because of its original position in the legacy bundled string,
 * between the body reset and the `.sr-only` rule — both belong to the SAME
 * "full-width toggle" feature and are documented together; a consumer that
 * wants the toggle feature should call both.
 *
 * Content max-width: editor panes can be 4000+px wide on ultrawide monitors; long-line text
 * and dense KPI strips become unreadable past ~1300px. We constrain to a readable width by
 * default and offer this override that dashboards toggle via the `.full-width-toggle` button.
 * Persistence is ephemeral (per webview session) — VS Code retains body markup across
 * hidden/shown via `retainContextWhenHidden`, so the toggle survives focus changes within a
 * session even without `vscode.setState()`. See guideline §4.
 */
export function chromeFullWidthMaxWidthOverride(): string {
  // NOTE: no leading newline -- see chromeBodyReset's comment; the preceding piece already
  // ends in "\n".
  return `body[data-full-width="true"] { max-width: none; }
`;
}

/**
 * §15 — REMOVED (PLAN_ext_ui_report_styles.md Phase 2, 2026-09-05): this used to be a
 * byte-identical duplicate of `chromeAccessibility()`'s `.sr-only` rule, kept only during
 * the Phase 1 split so `chromeBaseLayout()`'s output stayed byte-identical to the pre-split
 * monolithic function (a hard gate for that phase — no rendered-CSS change permitted).
 *
 * Verified before deletion: `chromeBaseLayout()` has exactly two consumers today —
 * `getDashboardChromeStyles()` (dashboardChromeStyles.ts) and `report-styles.ts` — and BOTH
 * already compose `chromeAccessibility()` alongside `chromeBaseLayout()` in every code path,
 * so the real `.sr-only` rule was always present regardless of this duplicate. Deleting it
 * changes zero rendered CSS for any current consumer. If a future consumer calls
 * `chromeBaseLayout()` WITHOUT also calling `chromeAccessibility()`, that consumer will not
 * get `.sr-only` from this function anymore — grep for `chromeBaseLayout(` before assuming
 * that is still safe.
 */

/** `.muted` text-color utility — its own one-line concern. */
export function chromeMutedUtility(): string {
  // NOTE: no leading newline -- see chromeBodyReset's comment.
  return `.muted { color: var(--muted); }
`;
}

/**
 * §4 — The `.full-width-toggle` button itself (icon button + hover/focus/active
 * states + its placement helper inside `.status-line`). Split out from the
 * former `chromeBaseLayout` bundle so a consumer that only wants the plain body
 * reset (`chromeBodyReset`) is never forced to also ship this button's CSS —
 * that was the exact bundling problem PLAN_ext_ui_report_styles.md's audit
 * flagged as blocking piecemeal adoption.
 */
export function chromeFullWidthToggleButton(): string {
  // NOTE: no leading newline -- see chromeBodyReset's comment.
  return `.full-width-toggle {
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

/**
 * Body fonts, page padding, helper utilities — COMPOSED from the fine-grained
 * exports above in their original textual order. Kept as the public entry
 * point so every existing consumer (`report-styles.ts`, `dashboardChromeStyles.ts`,
 * etc.) keeps calling exactly what it calls today.
 *
 * Phase 1 (split into fine-grained pieces) kept this byte-identical to the pre-split
 * monolithic function — verified via a captured-baseline diff, see
 * PLAN_ext_ui_report_styles.md and dashboardChromeStylesSeams.test.ts. Phase 2 then
 * removed one dead duplicate call (the legacy `.sr-only` copy, see the removal note
 * above) since both current consumers always pair this with `chromeAccessibility()`
 * anyway — a deliberate, documented change, not a silent regression.
 */
export function chromeBaseLayout(): string {
  return (
    chromeBoxSizingReset() +
    chromeBodyReset() +
    chromeFullWidthMaxWidthOverride() +
    chromeMutedUtility() +
    chromeFullWidthToggleButton()
  );
}

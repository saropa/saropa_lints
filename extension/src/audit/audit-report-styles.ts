/**
 * CSS for the audit report webview.
 *
 * Migrated onto the canonical dashboard chrome (`views/dashboardChromeStyles.ts`)
 * per design principle 5 ("one design system",
 * plans/PLAN_extension_ui_redesign.md §1.5). The caller (`audit-report-html.ts`)
 * now emits `getDashboardChromeStyles()` first, so `.dash-hero`, `.chip-strip`
 * / `.chip`, `.toolbar-band` / `.field`, `.btn`, `.dash-table`, and
 * `.empty-cta` all come from the shared system. This file holds only what has
 * no canonical equivalent: severity-tinted pills/rows, the filter-chip
 * on/off toggle look, baseline "new"/"unchanged" badges, and the
 * deferred-load / error-state banners.
 */

/** Returns the raw CSS body (no wrapping <style> tag — the caller adds the nonce). */
export function buildAuditStyles(): string {
  return `
:root {
  /* Severity hues alias the canonical accent tokens (from getDashboardChromeStyles'
     :root) so audit's severity coloring always agrees with every other dashboard's
     severity coloring instead of carrying its own hardcoded hex fallbacks. */
  --audit-sev-error: var(--accent-error);
  --audit-sev-warning: var(--accent-warning);
  --audit-sev-info: var(--accent-info);
}

/* KPI strip reuses .chip-strip/.chip from the chrome; only the per-severity tint is bespoke.
   A first pass filled the chip solid with the raw accent color and white/black text — the UX
   harness's axe-core sweep measured that at 3.59:1 (info, white-on-blue) and worse, all under
   the 4.5:1 AA floor. Fixed the same way the chrome's own .status-line pills do it: keep the
   neutral chip surface and color-mix the accent toward the theme foreground for the text, which
   is guaranteed-readable in every shipped theme instead of gambling on a raw accent's contrast
   against a raw white/black fill. */
.audit-kpi-error   { background: var(--surface-3); color: color-mix(in srgb, var(--audit-sev-error) 40%, var(--vscode-foreground)); }
.audit-kpi-warning { background: var(--surface-3); color: color-mix(in srgb, var(--audit-sev-warning) 40%, var(--vscode-foreground)); }
.audit-kpi-info    { background: var(--surface-3); color: color-mix(in srgb, var(--audit-sev-info) 40%, var(--vscode-foreground)); }

/* Filter chips reuse .chip as their base but also act as toggles (click
   removes/re-adds the dimension value from the active filter set — see
   audit-report-script.ts). The canonical .chip has no "inactive" visual since
   it's normally a read-only active-filter summary, so this adds one: greyed +
   line-through, matching the inverted-toggle language .seg.additive already
   uses elsewhere in the chrome for "this value is excluded". */
.audit-chip { cursor: pointer; border: 1px solid transparent; }
.audit-chip:not(.audit-chip-active) {
  background: transparent;
  border-color: var(--border);
  color: var(--muted);
  opacity: 0.6;
  text-decoration: line-through;
}
.audit-chip-count { opacity: 0.85; font-size: 0.92em; }

.audit-sev-pill {
  display: inline-block;
  padding: 1px 6px;
  border-radius: var(--radius-pill);
  font-size: 0.85em;
  font-weight: 500;
}
/* Same color-mix-toward-foreground fix as the KPI chips above: raw accent-on-table-background
   measured as low as 2.93:1 (warning) in the harness sweep, since the table row background is
   themed and the small pill font is under the large-text AA exemption. */
.audit-sev-pill.audit-sev-error   { color: color-mix(in srgb, var(--audit-sev-error) 40%, var(--vscode-foreground)); }
.audit-sev-pill.audit-sev-warning { color: color-mix(in srgb, var(--audit-sev-warning) 40%, var(--vscode-foreground)); }
.audit-sev-pill.audit-sev-info    { color: color-mix(in srgb, var(--audit-sev-info) 40%, var(--vscode-foreground)); }

.audit-col-file { max-width: 300px; overflow: hidden; text-overflow: ellipsis; }
.audit-col-line { white-space: nowrap; min-width: 60px; }
.audit-col-rule { white-space: nowrap; }
.audit-col-message { max-width: 500px; }

/* Active row highlight for keyboard navigation (arrow keys in audit-report-script.ts). */
.audit-row-active {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: -2px;
  background: var(--vscode-list-hoverBackground) !important;
}
.audit-keyboard-hint {
  text-align: center;
  padding: var(--space-2);
  color: var(--muted);
  font-size: 0.8em;
  margin: 0;
}

/* Baseline diffing: "new" rows get a left accent border. */
.audit-baseline-new-row { border-left: 3px solid var(--audit-sev-error); }
.audit-baseline-tag { font-size: 0.85em; color: var(--muted); font-style: italic; }

/* Status badges next to rule names when baseline data is present. */
.audit-status-badge {
  display: inline-block;
  padding: 0 4px;
  border-radius: var(--radius-sm);
  font-size: 0.7em;
  font-weight: 600;
  vertical-align: middle;
  margin-left: 4px;
}
/* Same solid-accent-fill pattern the KPI/sev-pill fixes above replaced — not caught by the UX
   harness fixture (this badge only appears after a client-side re-render, which the static
   harness never triggers) but fixed proactively rather than shipping a known-risky pairing. */
.audit-status-new { background: var(--surface-3); color: color-mix(in srgb, var(--audit-sev-error) 40%, var(--vscode-foreground)); font-weight: 700; }
.audit-status-unchanged { opacity: 0.4; }

.audit-pagination {
  padding: var(--space-3) var(--space-5);
  text-align: center;
  display: flex;
  gap: var(--space-3);
  justify-content: center;
  align-items: center;
}

/* Shown while the deferred (>10MB) diagnostics payload is still loading
   from the temp file — see audit-report-panel.ts MAX_INLINE_BYTES. */
.audit-loading-banner {
  padding: var(--space-2) var(--space-5);
  color: var(--muted);
  font-size: 0.85em;
  text-align: center;
}

/* Empty-state icon (big glyph above the .empty-cta message) — the chrome's
   .empty-cta has no icon slot of its own since most consumers use text only. */
.audit-empty-icon {
  display: block;
  font-size: 2.5em;
  margin-bottom: var(--space-2);
  opacity: 0.6;
}
.audit-error-failed .audit-empty-icon { color: var(--audit-sev-error); opacity: 0.9; }
.audit-error-canceled .audit-empty-icon { opacity: 0.5; }
`;
}

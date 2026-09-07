/**
 * Styles for the "What's New" welcome panel — layered over the shared dashboard chrome
 * (getDashboardChromeStyles) the same way About and Health Panel do. Only adds the
 * card-grid layout the welcome content needs; everything else (hero, tokens, buttons)
 * comes from the chrome.
 */
export function getWelcomePanelStyles(): string {
  return `
/* Explicit margin: 0 auto — restated rather than relying on chromeBodyReset's own
   margin declaration to still win the cascade, so this page's centering can never
   silently break if the chrome's base layout rule changes shape later. */
body { max-width: 900px; margin: 0 auto; }
.welcome-subtitle {
  color: var(--muted);
  margin: 0 0 var(--space-4);
  font-size: var(--text-body);
}
/* Colorful 5-tile number showcase directly under the hero — each tile's accent
   comes from the --stat-tone custom property set inline per tile (see
   buildStatsStripHtml), so the palette stays theme-safe chrome tokens rather than
   hardcoded hex. */
.welcome-stats-strip {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: var(--space-3);
  margin: 0 0 var(--space-5);
}
.welcome-stat-tile {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: var(--space-3) var(--space-2);
  border-radius: var(--radius-md);
  border: 1px solid var(--border);
  border-top: 3px solid var(--stat-tone);
  background: color-mix(in srgb, var(--stat-tone) 8%, var(--surface-2));
}
.welcome-stat-value {
  font-size: var(--text-kpi);
  font-weight: 700;
  color: var(--stat-tone);
  line-height: 1.1;
}
.welcome-stat-label {
  font-size: var(--text-caption);
  color: var(--muted);
  margin-top: var(--space-1);
}
.welcome-card {
  border: 1px solid var(--border);
  border-left-width: 4px;
  border-radius: var(--radius-md);
  background: var(--surface-2);
  padding: var(--space-4);
  margin: 0 0 var(--space-4);
}
.welcome-card h2 {
  font-size: var(--text-h3);
  margin: 0 0 var(--space-2);
  display: flex;
  align-items: center;
  gap: var(--space-2);
}
.welcome-card p {
  margin: 0 0 var(--space-2);
  line-height: 1.5;
}
.welcome-card .welcome-why {
  color: var(--muted);
  font-style: italic;
  margin: 0 0 var(--space-3);
}
.welcome-card .welcome-actions {
  display: flex;
  gap: var(--space-2);
  flex-wrap: wrap;
}
/* Elevated treatment for the engine-swap card — a default diagnostic engine change,
   not a routine feature note. Left border + tinted background keep it identifiable
   at a glance even before the header text is read. */
.welcome-card-critical {
  border-color: var(--accent-critical);
  border-left-width: 4px;
  background: color-mix(in srgb, var(--accent-critical) 6%, var(--surface-2));
}
.welcome-card-critical h2 {
  color: var(--accent-critical);
}
.welcome-checkbox-row {
  margin: var(--space-5) 0 0;
  padding: var(--space-3);
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface-2);
}
.welcome-checkbox-row label {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-weight: 600;
}
.welcome-checkbox-row input[type="checkbox"]:disabled {
  cursor: not-allowed;
}
.welcome-checkbox-hint {
  margin: var(--space-1) 0 0 26px;
  color: var(--muted);
  font-size: var(--text-caption);
}
.welcome-discover {
  margin: var(--space-5) 0;
}
.welcome-discover h2 {
  font-size: var(--text-h3);
  margin: 0 0 var(--space-3);
}
.welcome-discover-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-3);
}
.welcome-discover-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  text-align: left;
  gap: var(--space-1);
  padding: var(--space-3);
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface-2);
  cursor: pointer;
  color: inherit;
  font-family: inherit;
}
.welcome-discover-tile:hover {
  border-color: var(--border-strong);
  background: var(--surface-3);
}
.welcome-discover-tile:focus-visible {
  outline: 1px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
.welcome-discover-icon {
  font-size: 20px;
}
.welcome-discover-label {
  font-weight: 600;
}
.welcome-discover-description {
  color: var(--muted);
  font-size: var(--text-caption);
}
/* Narrow viewports (guideline: no horizontal scroll below ~380px) collapse both
   grids to a single column instead of squeezing 5 stat tiles or 2 discovery tiles. */
@media (max-width: 480px) {
  .welcome-stats-strip { grid-template-columns: repeat(2, 1fr); }
  .welcome-discover-grid { grid-template-columns: 1fr; }
}
`;
}

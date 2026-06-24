/**
 * Stylesheet for the command-catalog webview. Split out of
 * commandCatalogWebviewHtml.ts (which kept the markup builders) so the ~820-line
 * CSS string is its own module. Interpolates only the shared dashboard tokens
 * and pill-button styles; otherwise static.
 */

import { getDashboardTokens } from './dashboardChromeStyles';
import { getPillButtonStyles } from '../vibrancy/views/pill-button-styles';

export function getStyles(): string {
  return `
    ${getDashboardTokens()}
    ${getPillButtonStyles()}

    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: var(--vscode-font-family);
      font-size: var(--vscode-font-size);
      color: var(--vscode-foreground);
      background: var(--vscode-editor-background);
      line-height: 1.55;
      min-height: 100vh;
    }

    /* ── Header (§4.1) ─────────────────────────────────────────────────── */

    /* Hero panel matches the Findings dashboard (the gold standard): a contained,
     * rounded, bordered surface with a focus-tinted border and a soft radial gradient,
     * mounted with a short fade-in. Was a full-bleed gradient band; converted to a
     * centered panel so the catalog reads with the same hero visual as the rest of
     * the editor dashboards (§4.1 + §14.6 zoning). */
    /* Values now come from the shared dashboard tokens (border-strong, hero-tint,
     * surface-2, radius-lg) so this hero tracks the one gold-standard source instead
     * of re-deriving the same color-mix inline. (SAROPA_DASHBOARD_STYLE_GUIDE §4.1.) */
    .hero {
      position: relative;
      max-width: 880px;
      margin: 18px auto var(--space-4);
      padding: 18px 20px;
      border: 1px solid var(--border-strong);
      border-radius: var(--radius-lg);
      background:
        radial-gradient(900px 220px at 0% 0%, var(--hero-tint), transparent 60%),
        var(--surface-2);
      animation: hero-in 360ms ease-out;
    }

    /* .hero-inner is now a transparent flow container — the .hero panel itself
     * carries the framing. Kept so existing markup ("hero-inner" wrapper div in the
     * page template) doesn't have to be edited and so future content (e.g. a gauge
     * cell) can be added to a 2-column grid here without touching .hero. */
    .hero-inner {
      display: block;
    }

    .hero-title {
      font-size: 1.55em;
      font-weight: 600;
      letter-spacing: 0.2px;
      margin: 0 0 4px;
    }

    @keyframes hero-in {
      from { opacity: 0; transform: translateY(-4px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @media (prefers-reduced-motion: reduce) {
      .hero { animation: none; }
    }

    .status-line {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      font-size: 0.88em;
      color: var(--vscode-descriptionForeground);
    }

    .status-line strong {
      font-weight: 600;
      color: var(--vscode-foreground);
    }

    .status-line .status-sep {
      opacity: 0.5;
    }

    .status-line .status-dim {
      opacity: 0.78;
    }

    body.show-internal .status-line #statInternal {
      opacity: 1;
    }

    /* ── Toolbar band (§4.3) ───────────────────────────────────────────── */

    .toolbar-wrap {
      position: sticky;
      top: 0;
      z-index: 5;
      background: var(--vscode-editor-background);
      border-bottom: 1px solid color-mix(in srgb, var(--vscode-widget-border) 60%, transparent);
      padding: 12px 20px 8px;
    }

    .toolbar-inner {
      max-width: 880px;
      margin: 0 auto;
    }

    .toolbar-band {
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 8px 12px;
      background: var(--vscode-editorWidget-background, var(--vscode-sideBar-background));
      border: 1px solid var(--vscode-widget-border);
      border-radius: 8px;
    }

    .search-row {
      display: flex;
      align-items: center;
      gap: 8px;
      background: var(--vscode-input-background);
      border: 1px solid var(--vscode-input-border, transparent);
      border-radius: 6px;
      padding: 6px 10px;
    }

    .search-row:focus-within {
      border-color: var(--vscode-focusBorder);
    }

    .search-icon {
      opacity: 0.7;
      flex-shrink: 0;
    }

    .search-input {
      flex: 1;
      min-width: 0;
      border: none;
      outline: none;
      background: transparent;
      color: var(--vscode-input-foreground);
      font: inherit;
    }

    .search-input::placeholder {
      color: var(--vscode-input-placeholderForeground);
    }

    /* Inline (×) clear control surfaces only when the field has content
     * (§4.3 "Inline clear control when non-empty"). */
    .search-clear {
      flex-shrink: 0;
      width: 20px;
      height: 20px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: none;
      border-radius: 50%;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
    }

    .search-clear:hover {
      background: var(--vscode-toolbar-hoverBackground);
      color: var(--vscode-foreground);
    }

    .search-clear .codicon {
      font-size: 13px;
    }

    .search-count {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      white-space: nowrap;
    }

    .toolbar-controls {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
    }

    .checkbox-control {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.86em;
      color: var(--vscode-foreground);
      cursor: pointer;
      user-select: none;
    }

    .checkbox-control input { cursor: pointer; }

    .search-hint {
      font-size: 0.82em;
      color: var(--vscode-descriptionForeground);
      margin-top: 8px;
      line-height: 1.45;
    }

    /* §4.3 — single-line variant rendered BELOW the toolbar band so the
       toolbar reads as a pure control surface. Centered to mirror the
       toolbar's max-width and indented to read as supporting copy. */
    .search-hint-below {
      max-width: 880px;
      margin: 6px auto 0;
      padding: 0 14px;
      font-size: 0.78em;
    }

    .search-hint kbd {
      font-family: var(--vscode-editor-font-family);
      font-size: 0.92em;
      padding: 1px 5px;
      border-radius: 4px;
      border: 1px solid var(--vscode-widget-border);
      background: var(--vscode-editor-inactiveSelectionBackground);
    }

    .search-hint strong {
      font-weight: 600;
      color: var(--vscode-foreground);
    }

    /* ── Active filter chip strip (§8.5 / §14.10) ──────────────────────── */

    .filter-chip-strip {
      max-width: 880px;
      margin: 8px auto 0;
      padding: 8px 14px;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      border: 1px dashed var(--vscode-widget-border);
      border-radius: 6px;
      background: color-mix(in srgb, var(--vscode-editor-inactiveSelectionBackground) 60%, transparent);
      font-size: 0.84em;
    }

    .filter-chip-label {
      color: var(--vscode-descriptionForeground);
      font-weight: 600;
    }

    .filter-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 2px 6px 2px 10px;
      border-radius: 999px;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
    }

    .filter-chip-remove {
      width: 18px;
      height: 18px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: none;
      border-radius: 50%;
      cursor: pointer;
      color: inherit;
      opacity: 0.85;
    }

    .filter-chip-remove:hover {
      background: color-mix(in srgb, var(--vscode-foreground) 15%, transparent);
      opacity: 1;
    }

    .filter-chip-remove .codicon {
      font-size: 11px;
    }

    /* ── Bands: Frequent + Recent ──────────────────────────────────────── */

    .band {
      max-width: 880px;
      margin: 16px auto 0;
      padding: 0 20px;
    }

    .band-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .section-title {
      font-size: 0.78em;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--vscode-descriptionForeground);
    }

    .band-hint {
      font-size: 0.82em;
      color: var(--vscode-descriptionForeground);
      margin: 4px 0 10px;
    }

    .text-btn {
      font: inherit;
      font-size: 0.85em;
      color: var(--vscode-textLink-foreground);
      background: none;
      border: none;
      cursor: pointer;
      padding: 2px 6px;
      border-radius: 4px;
    }

    .text-btn:hover {
      background: var(--vscode-toolbar-hoverBackground);
    }

    .text-btn:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    /* Frequent: larger pinned tiles with primary-feeling weight (§14.7 tier-1). */
    .frequent-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 10px;
    }

    /* §8.10 — frequent tiles previously used a 12% --vscode-button-background
       tint that visually outweighed the actual tier-1/tier-2 toolbar buttons.
       The action-button color vocabulary belongs to actions, not to content
       cards; tiles drop to the editor's inactive-selection tone so the user's
       eye lands on the search input and toolbar buttons first. The hover
       state still lifts the tile via a subtle button-color brush so the
       affordance reads as interactive without competing for emphasis. */
    .frequent-tile {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border-radius: 8px;
      border: 1px solid var(--vscode-widget-border);
      background: var(--vscode-editor-inactiveSelectionBackground);
      cursor: pointer;
      text-align: left;
      color: inherit;
      font: inherit;
    }

    .frequent-tile:hover {
      background: color-mix(in srgb, var(--vscode-button-background) 8%, var(--vscode-editor-inactiveSelectionBackground));
      border-color: color-mix(in srgb, var(--vscode-focusBorder) 50%, var(--vscode-widget-border));
    }

    .frequent-tile:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .frequent-tile .codicon {
      font-size: 18px;
      opacity: 0.95;
      flex-shrink: 0;
    }

    .frequent-tile .frequent-title {
      font-weight: 600;
      font-size: 0.95em;
      flex: 1;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .frequent-tile .frequent-count {
      font-size: 0.74em;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 2px 7px;
      border-radius: 999px;
      flex-shrink: 0;
    }

    /* Recent strip (existing pill chips, capped). */
    .history-chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }

    .history-chip { /* layout-only; visual tokens come from .saropa-pill-button */ }
    .history-chip.history-overflow { display: none; }
    .band-recent.show-all .history-chip.history-overflow { display: inline-flex; }

    .history-more {
      margin-top: 6px;
    }

    /* ── Catalog (flat list with sticky section headers) ─────────────── */

    .catalog {
      max-width: 880px;
      margin: 0 auto;
      padding: 12px 20px 48px;
    }

    .category {
      margin-bottom: 14px;
      /* No surrounding card border (§14.6). Sticky header below carries the
       * grouping signal; relying on borders for every section flattens the
       * page into uniform tiles. */
    }

    .category-header {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 8px;
      cursor: pointer;
      user-select: none;
      font: inherit;
      color: var(--vscode-descriptionForeground);
      background: var(--vscode-editor-background);
      border: none;
      border-bottom: 1px solid color-mix(in srgb, var(--vscode-widget-border) 70%, transparent);
      text-align: left;
      /* Sticky just below the toolbar band so the user always knows which
       * category they are scrolling through. --toolbar-h is measured at
       * runtime (the toolbar wraps, so its height is not constant); the 0px
       * fallback degrades to top-of-pane if the script has not run yet.
       * Without the offset the header pinned at top:0 and slid behind the
       * higher-z-index toolbar, hiding the very label it exists to show. */
      position: sticky;
      top: var(--toolbar-h, 0px);
      z-index: 2;
      /* Microlabel typography per §8.1: small, uppercase, letter-spaced —
       * structural depth, not a competing headline. */
      font-size: 0.72em;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
    }

    /* Flash overlay — color is set in a static rule (var() resolves reliably
       outside keyframes) and the keyframe animates only opacity, so the
       flash still appears when var() in @keyframes fails to resolve in the
       VS Code webview (the same Chromium quirk that left chart bars all at
       100% width). The pseudo sits over the header content; pointer-events:
       none keeps clicks flowing through to the underlying button. */
    .category-header::after {
      content: '';
      position: absolute;
      inset: 0;
      background: color-mix(in srgb, var(--vscode-focusBorder) 35%, transparent);
      opacity: 0;
      pointer-events: none;
    }

    .category.flash .category-header::after {
      animation: badge-flash 0.9s ease-out;
    }

    @keyframes badge-flash {
      from { opacity: 1; }
      to   { opacity: 0; }
    }

    .collapse-icon {
      transition: transform 0.18s ease;
      opacity: 0.85;
      font-size: 12px;
    }

    .category.collapsed .collapse-icon {
      transform: rotate(-90deg);
    }

    .category.collapsed .category-body {
      display: none;
    }

    .category-label { flex: 1; }

    .category-count {
      font-size: 0.95em;
      font-weight: 600;
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      padding: 1px 8px;
      border-radius: 999px;
      cursor: pointer;
      letter-spacing: 0;
      /* Click target — smooth-scrolls the category into view (§14.8 makes
       * count badges first-class actions, not inert decoration). */
    }

    /* §14.1 — count badges had cursor:pointer but no visible focus/hover
       outline, so they read as semi-static decoration at first glance.
       The outline announces "this is a click target" before the user
       commits, matching the chrome's affordance-discovery pattern. */
    .category-count:hover {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }
    .category-count:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: 2px;
    }

    .category-body { padding: 4px 0 8px; }

    /* ── Slim entry rows (§3 compact typography, §14.6 weight depth) ─── */

    .entry {
      position: relative;
      display: grid;
      grid-template-columns: 22px 1fr auto;
      align-items: start;
      gap: 10px;
      padding: 6px 8px;
      border-radius: 6px;
      cursor: pointer;
      border: 1px solid transparent;
    }

    .entry:hover, .entry:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
      border-color: color-mix(in srgb, var(--vscode-widget-border) 60%, transparent);
    }

    .entry:focus-visible {
      outline: 1px solid var(--vscode-focusBorder);
      outline-offset: -1px;
    }

    .entry.kbd-active {
      background: var(--vscode-list-activeSelectionBackground);
      color: var(--vscode-list-activeSelectionForeground);
    }

    .entry.internal { display: none; }

    body.show-internal .entry.internal {
      display: grid;
      opacity: 0.7;
    }

    /* Flat icon — no boxed wrap (§8.7). The boxed 36×36 icon competed
     * with the title for the eye and made every row read like a button-
     * within-a-button. A bare codicon at title size keeps the title as
     * the row's primary identifier. */
    .entry-icon {
      font-size: 16px;
      line-height: 22px;
      opacity: 0.85;
      color: var(--vscode-foreground);
    }

    .entry-text {
      min-width: 0;
      display: flex;
      flex-direction: column;
      gap: 1px;
    }

    .entry-title-row {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 6px 8px;
    }

    .entry-title {
      font-weight: 600;
      font-size: 0.95em;
    }

    .entry-desc {
      color: var(--vscode-descriptionForeground);
      font-size: 0.82em;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    /* §8.5.2 — search hit highlights inside title and description text.
       Uses the host find-match token so the highlight is visible across
       all four default themes; the foreground inherits so contrast against
       the row text stays bound to the host theme. */
    .entry mark.search-hit {
      background: var(--vscode-editor-findMatchHighlightBackground,
          var(--vscode-editor-selectionBackground));
      color: inherit;
      padding: 0 1px;
      border-radius: 2px;
    }

    /* §8.5.2 — recent-searches popover anchored under the catalog search field. */
    .search-row { position: relative; }
    .catalog-recent {
      position: absolute;
      top: calc(100% + 4px);
      inset-inline-start: 0;
      inset-inline-end: 0;
      z-index: 50;
      max-height: 220px;
      overflow-y: auto;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-widget-border);
      border-radius: 4px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    }
    .catalog-recent-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 4px 8px;
      border-bottom: 1px solid var(--vscode-widget-border);
    }
    .catalog-recent-title {
      font-size: 0.8em;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
      letter-spacing: 0.4px;
    }
    .catalog-recent-clear {
      background: none;
      border: 0;
      padding: 0;
      cursor: pointer;
      color: var(--vscode-textLink-foreground);
      font-size: 0.85em;
    }
    .catalog-recent-clear:hover { text-decoration: underline; }
    .catalog-recent-list {
      list-style: none;
      margin: 0;
      padding: 4px 0;
    }
    .catalog-recent-list li {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 0;
    }
    .catalog-recent-list .recent-pick {
      flex: 1;
      text-align: start;
      background: none;
      border: 0;
      padding: 4px 10px;
      color: var(--vscode-foreground);
      cursor: pointer;
      font: inherit;
    }
    .catalog-recent-list .recent-pick:hover,
    .catalog-recent-list .recent-pick:focus-visible {
      background: var(--vscode-list-hoverBackground);
      outline: none;
    }
    .catalog-recent-list .recent-remove {
      width: 22px;
      height: 22px;
      margin-inline-end: 6px;
      border: 0;
      background: transparent;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      opacity: 0.6;
      border-radius: 2px;
      font-size: 14px;
    }
    .catalog-recent-list .recent-remove:hover,
    .catalog-recent-list .recent-remove:focus-visible {
      opacity: 1;
      background: var(--vscode-toolbar-hoverBackground, var(--vscode-list-hoverBackground));
    }

    /* Copy-id button only fades in on row hover/focus (§8.14). The id
     * itself is not in the row body anymore — that was the single biggest
     * source of visual noise across 156 rows. The full id remains in the
     * button's title attribute and the row's tooltip. */
    .entry-copy {
      width: 24px;
      height: 24px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      border: 1px solid transparent;
      border-radius: 4px;
      cursor: pointer;
      color: var(--vscode-descriptionForeground);
      opacity: 0;
      transition: opacity 0.12s ease;
    }

    .entry:hover .entry-copy,
    .entry:focus-within .entry-copy,
    .entry-copy:focus-visible,
    .entry.kbd-active .entry-copy {
      opacity: 1;
    }

    .entry-copy:hover {
      background: var(--vscode-toolbar-hoverBackground);
      color: var(--vscode-foreground);
    }

    .entry-copy.copied {
      color: var(--vscode-testing-iconPassed, var(--vscode-charts-green, var(--vscode-foreground)));
      opacity: 1;
    }

    .entry-copy .codicon {
      font-size: 13px;
    }

    .badge {
      font-size: 0.7em;
      padding: 1px 6px;
      border-radius: 999px;
      white-space: nowrap;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      font-weight: 600;
    }

    .internal-badge {
      background: var(--vscode-badge-background);
      color: var(--vscode-badge-foreground);
      opacity: 0.85;
    }

    .entry.search-hidden { display: none !important; }
    .category.search-hidden { display: none !important; }

    .no-results {
      text-align: center;
      padding: 48px 24px;
      color: var(--vscode-descriptionForeground);
    }

    .no-results-icon {
      font-size: 2.2em;
      opacity: 0.45;
      display: block;
      margin-bottom: 12px;
    }

    .no-results p { font-size: 1.05em; margin-bottom: 12px; }

    /* ── Responsive (narrow editor columns / split panes) ──────────────── */

    @media (max-width: 720px) {
      .hero { padding: 14px 12px; }
      .toolbar-wrap { padding: 10px 12px 6px; }
      .hero-inner,
      .toolbar-inner,
      .filter-chip-strip,
      .band,
      .catalog {
        max-width: none;
      }
      .band,
      .catalog {
        padding-inline-start: 12px;
        padding-inline-end: 12px;
      }
      .hero-title { font-size: 1.22em; }
      .frequent-grid {
        grid-template-columns: 1fr;
      }
    }

    @media (max-width: 420px) {
      .entry {
        grid-template-columns: 22px 1fr;
      }
      .entry-copy {
        grid-column: 2;
        justify-self: end;
        margin-top: 4px;
      }
      .history-chip {
        max-width: 100%;
        width: 100%;
        justify-content: flex-start;
      }
      .history-chip .saropa-pill-button-title {
        white-space: normal;
        text-overflow: unset;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      .collapse-icon,
      .entry-copy { transition: none; }
      .category.flash .category-header::after { animation: none; }
    }
  `;
}

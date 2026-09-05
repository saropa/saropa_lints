/**
 * Per-section slices of the package-vibrancy report stylesheet, split out of
 * report-styles.ts so the ~1100-line CSS string is not one function. Each
 * returns a static CSS fragment; the composer there concatenates them in
 * order. No interpolation — output is byte-identical.
 */

export function reportStylesPart1(): string {
    return `
        /* PLAN_ext_ui_report_styles.md Pass 1: the local body reset (16px all-round padding,
           default browser font-size/line-height, no box-sizing normalization) was dropped in
           favor of dashboardChromeStylesTokens.ts' chromeBaseLayout(), now composed into
           report-styles.ts. This is a deliberate, describable visual change, not a silent
           regression: chromeBaseLayout sets padding 18px/18px/28px (was 16px all round),
           font-size 13px + line-height 1.45 (was the browser default, ~14px/normal), and adds
           a global box-sizing:border-box reset. known-issues-html.ts already renders with this
           exact body (it loads getDashboardChromeStyles() alongside getReportStyles()), so this
           change makes the Package Dashboard and Upgrades tab match a body treatment already
           shipping elsewhere rather than introducing an unproven one. body[data-full-width=true]
           and .full-width-toggle moved the same way (chromeBaseLayout defines both; the only
           difference is the toggle grows from 26x26 to 28x28 and gains a border-color hover/
           focus tell -- verify at F5 in both themes, see the report footer for the checklist).
           NOTE: this comment must never contain a backtick -- this whole file is one JS template
           literal per function, and a stray backtick here would silently close the CSS string
           early (that bug shipped once already in this same edit and was caught by tsc). */
        h1 { font-size: 1.4em; margin-bottom: 8px; }

        /* PLAN_ext_ui_report_styles.md Pass 1: .report-header, .hero-text, h1 and
           .header-version were a byte-for-byte-equivalent duplicate of
           dashboardChromeStylesComponents.ts' chromeHeroAndGauge() (.dash-hero, .hero-text,
           .hero-text h1, .stamp -- identical once resolved through chromeTokens(), confirmed
           by comparing every property). Deleted here; report-html.ts and opportunities-html.ts
           now emit dash-hero / stamp class markup and rely on the chrome import in
           report-styles.ts. The one real difference is .stamp's opacity (chrome: 0.55, this
           report used 0.5) -- a difference too small to be worth a scoped override for.
           PLAN_ext_ui_report_styles.md Phase 1 (2026-09-05): @keyframes hero-in used to stay
           local here because chromeMicroAndMotion() bundled it with an unrelated code/.mono
           font-family:monospace rule that would have repainted opportunities-html.ts' code-tagged
           opp-chip elements. That bundle has since been split (dashboardChromeStylesSystem.ts) into
           single-concern exports, including chromeKeyframeHeroIn() with ONLY this keyframe -- no
           monospace rule attached. report-styles.ts now composes chromeKeyframeHeroIn() (plus
           chromeReducedMotion() for the .dash-hero reduced-motion override, which used to be a
           local 3-line media query here), so the local copies are deleted. */
        /* PLAN_ext_ui_report_styles.md Pass 1/2: .status-line/.pill were a
           byte-for-byte-equivalent duplicate of
           dashboardChromeStylesComponents.ts' chromeHeroAndGauge() (same
           colors once resolved through the --vscode-* aliases in
           chromeTokens(), which report-styles.ts now also composes in).
           Deleted here and left to the chrome import in report-styles.ts.
           The single real difference (chrome's .status-line has margin:0,
           this report kept a 12px trailing gap) is restored below as a
           scoped 1-line override instead of re-duplicating the whole
           block, per the plan's "adapt with <=10 lines of override"
           guidance. */
        /* Chrome's shared .status-line resets margin to 0 (other dashboards
           nest it directly against following content); the Package
           Dashboard's hero keeps its original 12px gap so the status row
           doesn't crowd its own bottom padding. Every hero consumer of
           this stylesheet now shares the identical .dash-hero class (see
           the .report-header removal note above), so the override can no
           longer be scoped by that selector alone -- known-issues-html.ts's
           buildDashboardHero() ALSO emits .dash-hero and must keep the
           chrome's zero-margin default. report-html.ts/opportunities-html.ts
           therefore keep an extra report-header marker class purely as a
           CSS scoping hook (no styling of its own) so this 1-line override
           targets only the Package Dashboard / Upgrades hero. */
        .dash-hero.report-header .status-line { margin-bottom: 12px; }

        /* ---- Radial gauge ---- */
        .radial-gauge {
            position: relative; width: 72px; height: 72px;
            flex-shrink: 0;
        }
        .gauge-svg { width: 72px; height: 72px; }
        /* Arc fill: stroke-dasharray is set as a direct SVG presentation
           attribute on the <circle class="gauge-fill"> (see buildRadialGauge
           in report-html.ts) and the load animation is driven by a SMIL
           <animate> child. Both survive the strict CSP — an earlier CSS-vars
           approach using inline style="..." attributes collapsed under CSP3
           and left the gauge as a single dot. Do NOT reintroduce a
           stroke-dasharray rule here: it would override the attribute. */
        /* Named .radial-gauge-label, NOT .gauge-label: report-styles.ts now composes
           dashboardChromeStylesComponents.ts' chromeHeroAndGauge(), which defines an
           UNSCOPED .gauge-label rule (position:absolute; inset:0) for its own
           .hero-gauge widget. This report's 72px SMIL-driven gauge is deliberately
           distinct from chrome's 96px CSS-keyframe .hero-gauge (plan §7: "do NOT
           conflate them"), so the label class was renamed to avoid the collision
           rather than adopting chrome's gauge markup. See report-html-top.ts. */
        .radial-gauge-label {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -55%);
            font-size: 1.3em; font-weight: bold;
        }
        .gauge-sub {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, 40%);
            font-size: 0.65em; opacity: 0.5;
        }
        /* Gauge doubles as the trigger for the "Why this grade?" breakdown
           panel (see buildGradeBreakdown). Visual affordance: cursor change +
           subtle focus ring; the SVG itself is unchanged so the animation
           reads the same. */
        .radial-gauge[role="button"] { cursor: pointer; }
        .radial-gauge[role="button"]:hover { filter: brightness(1.08); }
        .radial-gauge[role="button"]:focus-visible {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 4px;
            border-radius: 50%;
        }
`;
}

export function reportStylesPart2(): string {
    return `
        /* ---- "Why this grade?" breakdown panel ---- */
        .grade-breakdown {
            margin: 0 0 14px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 10px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .grade-breakdown-summary {
            cursor: pointer;
            padding: 10px 14px;
            list-style: none;
            display: flex; align-items: center; justify-content: space-between;
            gap: 12px;
            font-size: 0.95em;
        }
        /* Override the default disclosure-triangle marker so the chevron sits
           where we expect across Chromium and WebKit. */
        .grade-breakdown-summary::-webkit-details-marker { display: none; }
        .grade-breakdown-summary::marker { content: ''; }
        .grade-breakdown-summary::before {
            content: '\\25B8'; /* right-pointing triangle, rotates on open */
            display: inline-block;
            margin-inline-end: 8px;
            transition: transform 0.15s ease-out;
            opacity: 0.6;
        }
        .grade-breakdown[open] > .grade-breakdown-summary::before {
            transform: rotate(90deg);
        }
        .grade-breakdown-title { font-weight: 600; flex: 1; min-width: 0; }
        .grade-breakdown-hint {
            font-size: 0.85em;
            /* The 0.7 opacity on muted text dropped this to ~2.5:1 — well under
             * AA. Drop the opacity and lift the color toward foreground; the
             * smaller size still reads as a secondary hint. */
            color: color-mix(in srgb, var(--vscode-foreground) 70%, var(--vscode-descriptionForeground));
        }
        .grade-breakdown[open] > .grade-breakdown-summary .grade-breakdown-hint {
            visibility: hidden;
        }
        .grade-breakdown-body {
            padding: 0 14px 14px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            border-top: 1px solid var(--vscode-widget-border);
            padding-top: 12px;
        }
        .grade-breakdown-body h3 {
            margin: 0 0 6px;
            font-size: 0.82em;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--vscode-descriptionForeground);
        }
        .grade-breakdown-body ul,
        .grade-breakdown-body ol {
            list-style: none;
            margin: 0; padding: 0;
        }
        .breakdown-section li {
            display: flex; align-items: center; gap: 8px;
            padding: 3px 0;
            font-size: 0.92em;
        }
        .breakdown-dist-row,
        .breakdown-bottom-row {
            justify-content: space-between;
        }
        .breakdown-dist-count,
        .breakdown-pkg-score {
            font-variant-numeric: tabular-nums;
            color: var(--vscode-foreground);
        }
        .breakdown-dist-pct {
            font-variant-numeric: tabular-nums;
            /* descriptionForeground alone clears AA on the body background; the
               0.7 opacity that previously dimmed it pushed it under. */
            color: var(--vscode-descriptionForeground);
            min-width: 38px;
            text-align: end;
        }
        /* Filter / jump buttons inside the breakdown panel — visually plain
           so the panel reads as a report, not a toolbar; styled like links
           with a hover affordance to confirm they're actionable. */
        .breakdown-filter-btn,
        .breakdown-jump-btn {
            background: none; border: none; cursor: pointer; padding: 0;
            color: var(--vscode-foreground);
            font: inherit;
            display: inline-flex; align-items: center; gap: 6px;
            flex: 1; min-width: 0;
            text-align: start;
        }
        .breakdown-filter-btn:hover,
        .breakdown-jump-btn:hover {
            color: var(--vscode-textLink-foreground);
            text-decoration: underline;
        }
        .breakdown-filter-btn:focus-visible,
        .breakdown-jump-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
            border-radius: 3px;
        }
        .breakdown-filter-btn[disabled] {
            cursor: default;
            opacity: 0.45;
            text-decoration: none;
        }
        .breakdown-filter-btn[disabled]:hover {
            color: var(--vscode-foreground);
            text-decoration: none;
        }
        .breakdown-pkg-name {
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .breakdown-thresholds li { font-size: 0.88em; }

        /* ---- Letter grade badges ---- */
        .grade-badge {
            display: inline-block;
            width: 20px; height: 20px; line-height: 20px;
            text-align: center; border-radius: 4px;
            font-size: 0.75em; font-weight: bold;
            margin-inline-end: 4px; vertical-align: middle;
        }
        .grade-A { background: var(--vscode-testing-iconPassed); color: var(--vscode-editor-background); }
        .grade-B { background: var(--vscode-editorInfo-foreground); color: var(--vscode-editor-background); }
        .grade-C { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); }
        .grade-D { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); opacity: 0.8; }
        .grade-E { background: var(--vscode-editorWarning-foreground); color: var(--vscode-editor-background); }
        .grade-F { background: var(--vscode-editorError-foreground); color: var(--vscode-editor-background); }
        .category-cell {
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .sparkline {
            opacity: 0.9;
        }

        /* ---- Row expansion ---- */
        .col-expand { width: 24px; padding: 6px 2px; }
        .expand-cell { text-align: center; padding: 6px 2px; width: 24px; cursor: pointer; }
        .expand-chevron {
            display: inline-block; font-size: 0.7em;
            transition: transform 0.2s;
            opacity: 0.5; user-select: none;
        }
        .expand-cell:hover .expand-chevron { opacity: 1; }
        .pkg-row.expanded .expand-chevron { transform: rotate(90deg); opacity: 1; }
        .detail-row td { padding: 0; border-bottom: none; }
        .detail-card {
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 6px; padding: 12px 16px;
            margin: 4px 8px 8px;
            display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 12px;
        }
        /* Detail-card content was at 0.85em with opacity 0.6 on labels — too small
         * and too dim to read in many themes (the value-side numbers stayed full
         * opacity, so the label/value contrast inside the same row was harsh).
         * Now: 0.95em body for readability, descriptionForeground token for muted
         * labels (theme-aware, WCAG-correct), and h4 at full opacity since opacity
         * stacks against the card background instead of pairing cleanly. */
        .detail-section h3 {
            margin: 0 0 6px; font-size: 0.95em; font-weight: 600;
            color: var(--vscode-foreground);
            border-bottom: 1px solid var(--vscode-widget-border);
            padding-bottom: 4px;
        }
        .detail-grid {
            display: grid; grid-template-columns: auto 1fr;
            gap: 4px 14px; font-size: 0.95em;
        }
        .detail-label { color: var(--vscode-descriptionForeground); }
        .vuln-row { font-size: 0.95em; margin: 2px 0; }
        .file-row {
            font-size: 0.9em; font-family: var(--vscode-editor-font-family, monospace);
            color: var(--vscode-descriptionForeground);
        }
        .detail-links .link-list { font-size: 0.95em; }
        .detail-search-link { cursor: pointer; font-size: 0.95em; }
`;
}

export function reportStylesPart3(): string {
    return `
        /* ---- Deps column ---- */
        .deps-icon { font-size: 0.85em; margin-inline-end: 2px; }
        .badge-shared {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 1px 4px; border-radius: 3px;
            font-size: 0.7em; margin-inline-start: 4px;
            vertical-align: middle;
        }
        .badge-shared-sm {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 0 3px; border-radius: 2px;
            font-size: 0.65em; margin-inline-start: 3px;
        }
        .dep-cloud { font-size: 0.8em; line-height: 1.8; }
        .dep-cloud span { margin-inline-end: 6px; }
        .dep-shared { font-weight: bold; color: var(--vscode-editorInfo-foreground); }

        /* ---- Summary cards ----
           PLAN_ext_ui_report_styles.md Phase 2 (2026-09-05): evaluated against
           dashboardChromeStylesComponents.ts' chromeKpiCards() (.kpi-row/.kpi-card) and KEPT
           local -- this is not an oversight, it is a genuine visual-model mismatch, not a
           small-override case:
             1. Layout is inverted. .summary-card renders .count (large number) ABOVE .label
                (small caption), centered, on a flat --vscode-editor-inactiveSelectionBackground
                tile with no border. .kpi-card renders .kpi-k (small caption) ABOVE .kpi-v
                (large number), left-aligned, on a bordered var(--surface-2) card with its own
                border-radius/padding scale. Applying both classes to the same element (as
                known-issues-html.ts does for its 4 simple cards) would let .kpi-card's later
                cascade rules silently override .summary-card's centering/flat-background --
                not a merge, a redesign of the strip's look with no way to verify it at F5 in
                this pass.
             2. Nine bespoke semantic categories (.vibrant/.stable/.outdated/.abandoned/.eol/
                .updates/.unused/.vulns/.overrides below) map package-health LETTER GRADES to
                color -- a different domain from chromeKpiCards' four hardcoded categories
                (.errors/.warnings/.crit/.todos, a lint-severity vocabulary). chromeTokens()
                does define --grade-a..--grade-f, so the color RAMP could theoretically be
                reused, but chromeKpiCards() has no .kpi-card.vibrant/.stable/etc. selectors to
                hang them on -- adding nine new selectors to the shared chrome file to serve
                one consumer is a blast-radius change to shared infrastructure (CLAUDE.md
                Scope & Safety gate), not something this pass does without asking.
           Net: migrating would mean either accepting an unreviewed layout change or extending
           the shared chrome component for a single caller. Both are out of proportion to the
           ~20 lines of CSS this local block costs. Kept, not forgotten. */
        .summary {
            display: flex; gap: 16px; margin-bottom: 16px;
            flex-wrap: wrap;
        }
        .summary-card {
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 6px; padding: 12px 16px;
            min-width: 100px; text-align: center;
        }
        .summary-card .count { font-size: 1.8em; font-weight: bold; }
        /* Summary-card label: was 0.85em + opacity 0.8 — small and washed-out.
         * descriptionForeground gives proper muted contrast in any theme. */
        /* Card labels sit on a tinted card, where plain descriptionForeground
         * dips just under WCAG AA (~4.0:1). Mix toward foreground so the small
         * label clears AA while staying lighter than the hero number above it. */
        .summary-card .label { font-size: 0.9em; color: color-mix(in srgb, var(--vscode-foreground) 72%, var(--vscode-descriptionForeground)); min-height: 18px; }
        .summary-card[data-filter],
        .summary-card[data-breakdown-trigger] {
            cursor: pointer; transition: box-shadow 0.2s, background 0.2s;
        }
        .summary-card[data-filter]:hover,
        .summary-card[data-breakdown-trigger]:hover {
            box-shadow: 0 0 0 2px var(--vscode-focusBorder);
        }
        .summary-card[data-filter]:focus-visible,
        .summary-card[data-breakdown-trigger]:focus-visible {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        .summary-card.card-active {
            box-shadow: 0 0 0 2px var(--vscode-focusBorder);
            background: var(--vscode-list-activeSelectionBackground);
        }
        .vibrant .count { color: var(--vscode-testing-iconPassed); }
        .stable .count { color: var(--vscode-editorInfo-foreground); }
        .outdated .count { color: var(--vscode-editorWarning-foreground); }
        .abandoned .count { color: var(--vscode-editorWarning-foreground); }
        .eol .count { color: var(--vscode-editorError-foreground); }
        .updates .count { color: var(--vscode-textLink-foreground); }
        .unused .count { color: var(--vscode-editorWarning-foreground); }
        .vulns .count { color: var(--vscode-editorError-foreground); }
        .overrides .count { color: var(--vscode-descriptionForeground); }

        /* ---- Toolbar (search + pubspec button) ----
           PLAN_ext_ui_report_styles.md Phase 2 (2026-09-05): evaluated against
           dashboardChromeStylesComponents.ts' chromeToolbarAndButtons() (.toolbar-band/.field/
           .btn) and KEPT local:
             1. .toolbar-band is 'position: sticky; top: 0; z-index: 10'. The Package Dashboard
                is the most interaction-heavy surface in the extension (detail pane, network
                diagram, dependency popovers -- see the plan's own Risks section). Making its
                filter row sticky is a real functional/UX change to scroll behavior around
                those overlays, not a CSS-only swap, and this pass has no Extension Dev Host or
                Playwright run to verify it doesn't clip a popover under the newly-fixed band.
                Not something to ship unverified.
             2. .toolbar-btn's shape was a DELIBERATE prior decision, already documented a few
                lines below (see the "Rounded-rect toolbar buttons" comment on .toolbar-btn):
                6px radius + 0.85em font, chosen specifically so these buttons read as one
                family with the .table-toolbar container's own 6px radius. Chrome's '.btn' is a
                999px PILL at 0.95em with a 0.45 disabled-opacity floor (vs this file's 0.65).
                Reusing '.btn' here would mean either (a) accepting the pill shape, undoing the
                earlier deliberate decision, or (b) re-overriding radius + font-size +
                disabled-opacity back to this file's values on every one of the 8 toolbar
                buttons -- which is not deduplication, it's carrying the same three
                overrides eight times instead of once.
           Net: adopting either half of this family costs more than it saves without a visual
           verification pass this session cannot run. Kept, not forgotten. */
        .table-toolbar {
            display: flex; gap: 12px; align-items: center;
            margin: 12px 0 8px;
            flex-wrap: wrap;
            padding: 8px 10px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        /* PLAN_ext_ui_report_styles.md Pass 1: .sr-only used to be duplicated here
           (see git history) because this webview didn't load any dashboardChromeStyles
           module. report-styles.ts now composes chromeAccessibility() (byte-identical
           rule) alongside the report parts, so the local copy was deleted — single
           source of truth for the visually-hidden-but-readable-by-screen-readers
           helper used by the search-field <label> below and report-html-table.ts'
           column header. */
        /* Relative wrapper anchors the absolutely-positioned clear (X)
           button inside the search field. inline-flex keeps the wrapper
           sized to the input so the toolbar layout is unchanged. */
        .search-wrapper {
            position: relative;
            display: inline-flex;
            align-items: center;
        }
        .search-input {
            padding: 4px 24px 4px 8px; /* right padding leaves room for clear (X) */
            border: 1px solid var(--vscode-input-border);
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            border-radius: 3px;
            font-size: 0.9em;
            min-width: 200px;
        }
        .search-input:focus {
            outline: none;
            border-color: var(--vscode-focusBorder);
        }
        /* Clear (X) button lives inside the input via absolute positioning.
           Hidden by default via [hidden]; report-script.ts toggles it when
           the input value is non-empty after trim. */
        .search-clear {
            position: absolute;
            /* §23.1 — clear-X anchors to the trailing edge of the input so
               it stays at end-of-line whether the writing direction is LTR
               or RTL. */
            inset-inline-end: 4px;
            top: 50%;
            transform: translateY(-50%);
            width: 16px;
            height: 16px;
            padding: 0;
            line-height: 14px;
            font-size: 14px;
            border: none;
            background: transparent;
            color: var(--vscode-input-foreground);
            opacity: 0.6;
            cursor: pointer;
            border-radius: 2px;
        }
        .search-clear:hover {
            opacity: 1;
            background: var(--vscode-toolbar-hoverBackground);
        }
        /* Rounded-rect toolbar buttons. Tokens stay on the secondary-button
         * pair. Two notes on the shape and border:
         *   - border-radius 6px: a full-pill 999px read as "too round" next
         *     to the rectangular search input and Preset select; 6px matches
         *     the table-toolbar container radius and reads as one family.
         *   - border fallback: --vscode-button-border is undefined in most
         *     themes (only Dark+ and a few HC themes set it), so the prior
         *     transparent fallback rendered as no border at all. Falling
         *     back to --vscode-widget-border keeps a visible edge in every
         *     theme without competing with focusBorder. */
        .toolbar-btn {
            background: var(--vscode-button-secondaryBackground);
            color: var(--vscode-button-secondaryForeground);
            border: 1px solid var(--vscode-button-border, var(--vscode-widget-border));
            padding: 6px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.85em;
            transition: background 0.12s ease, border-color 0.12s ease;
        }
        .toolbar-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground, var(--vscode-button-secondaryBackground));
            border-color: color-mix(in srgb, var(--vscode-focusBorder) 55%, var(--vscode-button-border, var(--vscode-widget-border)));
        }
        .toolbar-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 2px;
        }
        .toolbar-btn:disabled {
            opacity: 0.65;
            cursor: not-allowed;
        }
        #pkg-nav-back { min-width: 82px; }
        /* Age slider sits immediately before the Preset dropdown. Without
           a strong visual break, the slider's max-value label ("All")
           reads as the value of the adjacent "Preset" field. We use a
           wider trailing margin AND a higher-contrast divider built from
           focusBorder + widget-border so it survives both light and dark
           themes — widget-border on its own is too subtle. */
        .age-filter {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.8em;
            padding-inline-end: 14px;
            margin-inline-end: 6px;
            border-inline-end: 1px solid
                color-mix(in srgb, var(--vscode-focusBorder) 30%, var(--vscode-widget-border));
        }
        .age-filter input[type="range"] { width: 120px; }
        /* The slider's max-value readout sits at the end of the age group,
           directly before the divider. A muted chip-style background and
           a min-width keep "All" from blending into the neighboring
           "Preset" label. */
        #age-max-label {
            display: inline-block;
            min-width: 32px;
            padding: 1px 6px;
            border-radius: 4px;
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            text-align: center;
            font-size: 0.95em;
        }
        .preset-filter {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.82em;
        }
        .preset-filter select {
            border: 1px solid var(--vscode-input-border);
            background: var(--vscode-input-background);
            color: var(--vscode-input-foreground);
            border-radius: 3px;
            padding: 2px 6px;
            font-size: 0.95em;
        }
        .dev-toggle {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 0.85em;
            white-space: nowrap;
        }
        .active-filters {
            display: flex;
            align-items: center;
            gap: 8px;
            margin: 6px 0 2px;
            padding: 6px 10px;
            border: 1px dashed var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        /* The HTML5 [hidden] attribute is set by JS when chips.length === 0; without
           this rule the .active-filters display:flex above wins and the strip
           re-appears empty (label + Clear all with no chips). */
        .active-filters[hidden] {
            display: none !important;
        }
        .active-filters-label {
            font-size: 0.82em;
            opacity: 0.8;
            white-space: nowrap;
        }
        .active-filters-list {
            display: flex;
            align-items: center;
            gap: 6px;
            flex-wrap: wrap;
            flex: 1;
        }
        .active-filter-chip {
            background: var(--vscode-badge-background);
            color: var(--vscode-badge-foreground);
            border: 1px solid var(--vscode-widget-border);
            border-radius: 999px;
            padding: 2px 8px;
            font-size: 0.78em;
            cursor: pointer;
        }
        .active-filter-chip:hover {
            filter: brightness(1.08);
        }
`;
}

export function reportStylesPart4(): string {
    return `
        /* ---- Footprint mode toggle (radio-style segmented control) ----
           Three buttons that swap the Size column between own / +unique / +all transitive
           footprint. Per guideline §14.15 the active button does NOT borrow primary-button
           colors — primary-button vocabulary is reserved for tier-1 actions (Rescan, Run).
           For a radio toggle (exactly one active), the active option gets an inactive-selection
           backdrop tint; inactive options stay transparent. The user picks out the active
           option by its subtle tinted backdrop, not by a shouting blue pill. */
        /* Segmented control sits beside the rounded-rect toolbar buttons,
           so its radius is matched (6px container + 4px segments) instead
           of the prior full-pill 999px. */
        /* PLAN_ext_ui_report_styles.md Phase 2 (2026-09-05): evaluated against
           dashboardChromeStylesComponents.ts' chromeToolbarAndButtons() '.seg' segmented
           control and KEPT local -- the two controls solve DIFFERENT interaction problems,
           not the same one with different CSS:
             '.seg' is an ADDITIVE multi-select whose state lives entirely in 'aria-pressed':
             [aria-pressed="true"] renders plain/included, [aria-pressed="false"] renders
             ghosted+strike-through/excluded (see the inversion comment on '.seg' in
             dashboardChromeStylesComponents.ts). '.footprint-toggle' is a single-select RADIO
             group -- report-html-top.ts (footprintToggle markup, 'role="group"', one
             '.active' class on the current button, no 'aria-pressed' attribute anywhere) and
             report-script-parts.ts' setFootprintMode() (toggles '.active' via
             'data-footprint', never touches 'aria-pressed') both encode "exactly one of
             own/unique/total is selected," never "each option independently included or
             excluded." Adopting '.seg' would mean rewriting the markup to add
             'aria-pressed' to all three buttons AND rewriting setFootprintMode() to flip
             'aria-pressed' instead of '.active' -- a script + markup + a11y-semantics rewrite
             to save roughly 35 lines of CSS, disproportionate per the plan's own guidance.
           Kept, not forgotten. */
        .footprint-toggle {
            display: inline-flex; align-items: center; gap: 2px;
            padding: 2px 4px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .footprint-toggle .toggle-label {
            /* Was foreground @0.7 opacity (~4.2:1). A muted color mixed toward
               foreground reads as a label and clears AA on the toggle band. */
            font-size: 0.75em;
            color: color-mix(in srgb, var(--vscode-foreground) 72%, var(--vscode-descriptionForeground));
            margin-inline-end: 4px;
            padding-inline-start: 4px;
            text-transform: uppercase;
            letter-spacing: 0.4px;
        }
        .toggle-btn {
            background: transparent;
            color: var(--vscode-foreground);
            border: 1px solid transparent;
            padding: 2px 10px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.85em;
            white-space: nowrap;
            /* Inactive footprint options read as dimmed but must still clear AA;
               0.6 left them at ~3.3:1. 0.8 keeps the dim look above the bar. */
            opacity: 0.8;
            transition: opacity 0.12s, background 0.12s;
        }
        .toggle-btn:hover { opacity: 1; }
        .toggle-btn:focus-visible {
            outline: 1px solid var(--vscode-focusBorder);
            outline-offset: 1px;
            opacity: 1;
        }
        .toggle-btn.active {
            background: var(--vscode-list-activeSelectionBackground);
            color: var(--vscode-list-activeSelectionForeground);
            opacity: 1;
        }

        /* Size column: only the span matching the active footprint mode
           is visible. Default class is set in JS on table load. */
        .size-cell .size-own,
        .size-cell .size-unique,
        .size-cell .size-total { display: none; }
        table.fp-own .size-cell .size-own { display: inline; }
        table.fp-unique .size-cell .size-unique { display: inline; }
        table.fp-total .size-cell .size-total { display: inline; }

        /* ---- Table ---- */
        /* §4 — the wide multi-column tables cannot fit a narrow (docked) webview;
         * a scroll wrapper lets the table scroll horizontally inside its own
         * bounds instead of pushing the whole page sideways. At wide widths the
         * table fits so no scrollbar appears. These tables have no sticky thead,
         * so the overflow container does not regress a pinned header. */
        .table-scroll { max-width: 100%; overflow-x: auto; }

        /* §7 master-detail: the packages table (left, flex-grow) sits beside the
         * docked detail pane (right, fixed). The pane is hidden until a row is
         * selected, so the default view is the full-width table. min-width:0 on
         * the table column lets .table-scroll shrink inside the flex row instead
         * of forcing overflow. On a narrow webview the pane stacks below. */
        .dash-split { display: flex; gap: 16px; align-items: flex-start; }
        .dash-split > details,
        .dash-split > .packages-section { flex: 1 1 auto; min-width: 0; }
        .detail-pane {
            box-sizing: border-box;
            flex: 0 0 380px; max-width: 380px;
            position: sticky; top: 8px;
            max-height: calc(100vh - 24px); overflow: auto;
            border: 1px solid var(--vscode-widget-border); border-radius: 8px;
            padding: 12px 14px;
            background: var(--vscode-editorWidget-background);
        }
        .detail-pane[hidden] { display: none; }
        /* The row whose detail is open in the pane stays highlighted so the
         * master-detail relationship is visible while scrolling the table. */
        .pkg-row.row-selected > td {
            background: var(--vscode-list-inactiveSelectionBackground, var(--vscode-list-hoverBackground));
        }
        .detail-pane-head {
            display: flex; align-items: center; justify-content: space-between;
            margin-bottom: 10px;
        }
        .detail-pane-kicker {
            font-size: 0.72em; text-transform: uppercase; letter-spacing: 0.08em;
            color: var(--vscode-descriptionForeground);
        }
        .detail-pane-close {
            background: none; border: none; cursor: pointer; font-size: 1.2em;
            line-height: 1; color: var(--vscode-descriptionForeground);
            padding: 2px 6px; border-radius: 4px;
        }
        .detail-pane-close:hover {
            color: var(--vscode-foreground);
            background: var(--vscode-list-hoverBackground);
        }
        .detail-pane-close:focus-visible {
            outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px;
        }
        .detail-pane .pane-header {
            display: flex; gap: 12px; align-items: flex-start; margin-bottom: 12px;
        }
        .detail-pane .pane-logo {
            width: 40px; height: 40px; border-radius: 6px; object-fit: contain;
            flex-shrink: 0;
        }
        .detail-pane .pane-title { font-size: 1.15em; font-weight: 600; margin-bottom: 4px; }
        @media (max-width: 900px) {
            /* Stack on narrow webviews. align-items:stretch (not flex-start) so
             * the table column fills the viewport width and .table-scroll keeps
             * the wide table contained — flex-start would let it take its
             * content width and overflow the page. */
            .dash-split { flex-direction: column; align-items: stretch; }
            .dash-split > details,
            .dash-split > .packages-section { width: 100%; }
            .detail-pane {
                flex-basis: auto; max-width: 100%; width: 100%;
                position: static; max-height: none;
            }
        }
        table {
            width: 100%; border-collapse: collapse; margin-top: 8px;
        }
        th, td {
            text-align: left; padding: 4px 6px;
            border-bottom: 1px solid var(--vscode-widget-border);
        }
        th {
            background: var(--vscode-editor-inactiveSelectionBackground);
            /* Prevent header text wrapping when many columns are visible.
               Long labels like "Transitives" / "References" / "Published"
               otherwise stack to two lines and inflate row height. */
            white-space: nowrap;
        }
        /* Only sortable headers (with data-col) get pointer cursor. */
        th[data-col] {
            cursor: pointer; user-select: none;
        }
        th[data-col]:hover { background: var(--vscode-list-hoverBackground); }
        tr:hover { background: var(--vscode-list-hoverBackground); }
        .row-focused {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: -2px;
        }
        .sort-arrow { margin-inline-start: 4px; opacity: 0.6; }
        a {
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        a:hover { text-decoration: underline; }

        /* ---- Right-aligned numeric cells ---- */
        /* nowrap so size/count values stay on one line in narrow viewports. */
        .cell-right { text-align: right; white-space: nowrap; }
        .deps-cell, .transitives-cell, .refs-cell { text-align: right; }
`;
}

export function reportStylesPart5(): string {
    return `
        /* ---- File usage count styling ---- */
        .file-single { color: var(--vscode-descriptionForeground); }
        .file-deep { font-weight: bold; }
        /* Tiny badge next to the References count when at least one usage
           is a re-export. Subtle — the cell is already crowded and the
           tooltip carries the explanation. */
        .ref-reexport-badge {
            color: var(--vscode-editorInfo-foreground);
            font-weight: bold;
            margin-inline-start: 2px;
        }

        /* ---- Version age suffix ---- */
        .version-age {
            color: var(--vscode-descriptionForeground);
            font-size: 0.85em;
            margin-inline-start: 2px;
        }

        /* ---- Update status colors ---- */
        .update-major { color: var(--vscode-editorError-foreground); font-weight: bold; }
        .update-minor { color: var(--vscode-editorWarning-foreground); }
        .update-patch { color: var(--vscode-editorInfo-foreground); }
`;
}

export function reportStylesPart6(): string {
    return `
        /* ---- Badges ---- */
        .badge-unused {
            background: var(--vscode-editorWarning-foreground);
            /* Amber is a light color in every theme, so editor-background text
               (white on light themes) failed AA. Fixed dark text reads on amber
               in both themes — the same rationale as the score pill. */
            color: #1f1f1f;
            padding: 2px 6px; border-radius: 3px; font-size: 0.85em;
        }
        .badge-dev {
            background: var(--vscode-editorInfo-foreground);
            color: var(--vscode-editor-background);
            padding: 1px 5px; border-radius: 3px; font-size: 0.75em;
            margin-inline-start: 6px; vertical-align: middle;
        }
        .badge-transitive {
            background: var(--vscode-descriptionForeground);
            color: var(--vscode-editor-background);
            padding: 1px 5px; border-radius: 3px; font-size: 0.75em;
            margin-inline-start: 6px; vertical-align: middle;
        }
        /* Opportunities-column count: a filled pill so a high under-adoption
           count reads as an actionable call-to-action, not a warning. Reuses
           the dashboard's existing accent/link foreground for consistency. */
        .badge-opportunity {
            background: var(--vscode-charts-blue, var(--vscode-textLink-foreground));
            color: var(--vscode-editor-background);
            padding: 1px 6px; border-radius: 10px; font-size: 0.8em;
            font-weight: 600; vertical-align: middle;
        }

        /* ---- Dimmed placeholder text (dashes, hyphens) ---- */
        .dimmed { opacity: 0.35; }

        /* ---- Description text column ---- */
        .desc-text {
            max-width: 300px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
        }
`;
}

export function reportStylesPart7(): string {
    return `
        /* ---- Clickable package name (links to pubspec.yaml entry) ---- */
        .pkg-name-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .pkg-name-link:hover { text-decoration: underline; }

        /* ---- Clickable reference count (links to import search) ---- */
        .ref-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .ref-link:hover { text-decoration: underline; }
        .size-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .size-link:hover { text-decoration: underline; }
        .file-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .file-link:hover { text-decoration: underline; }
        .dep-list-link {
            cursor: pointer;
            color: var(--vscode-textLink-foreground);
        }
        .dep-list-link:hover { text-decoration: underline; }
        .pkg-row.pkg-nav-focus {
            outline: 2px solid var(--vscode-focusBorder);
            outline-offset: -2px;
        }
        .dep-popover {
            position: fixed;
            z-index: 1000;
            min-width: 220px;
            max-width: 420px;
            max-height: 280px;
            overflow: auto;
            padding: 8px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            background: var(--vscode-editorWidget-background);
            box-shadow: 0 2px 10px rgba(0,0,0,0.35);
        }
        .dep-popover-title {
            font-size: 0.8em;
            opacity: 0.75;
            margin-bottom: 6px;
            position: sticky;
            top: 0;
            background: var(--vscode-editorWidget-background);
            padding-bottom: 4px;
        }
        .dep-popover .dep-nav-link {
            display: block;
            margin: 2px 0;
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
        }
        .dep-popover .dep-nav-link:hover { text-decoration: underline; }
        .dep-popover .ref-nav-link {
            display: block;
            margin: 2px 0;
            color: var(--vscode-textLink-foreground);
            text-decoration: none;
            font-family: monospace;
            font-size: 0.9em;
        }
        .dep-popover .ref-nav-link:hover { text-decoration: underline; }
        .network-wrap {
            margin-top: 10px;
            margin-bottom: 6px;
            border: 1px solid var(--vscode-widget-border);
            border-radius: 6px;
            padding: 6px 10px;
            background: var(--vscode-editor-inactiveSelectionBackground);
        }
        .network-wrap summary {
            cursor: pointer;
            font-weight: 600;
        }
        /* Collapsible dashboard sections — used by Size Distribution,
           Filters, and the Packages table. <details>/<summary> primitive
           gives the disclosure triangle and toggle behavior for free; we
           only style the summary affordance and ensure the inner <h2>
           sits inline with the marker. Marker stays default-colored so
           it tracks the active theme. */
        .dashboard-collapsible {
            margin: 16px 0;
        }
        .dashboard-collapsible > summary {
            cursor: pointer;
            user-select: none;
            list-style: revert;
            padding: 4px 0;
        }
        .dashboard-collapsible > summary > h2 {
            display: inline-block;
            margin: 0;
            font-size: 1.1em;
            opacity: 0.9;
            vertical-align: middle;
        }
        .dashboard-collapsible[open] > summary {
            margin-bottom: 8px;
        }
        .network-canvas {
            /* Fixed-height viewport. Zoom/pan is driven by the SVG viewBox, not
             * container scroll, so overflow is hidden — preserveAspectRatio
             * "meet" scales the content uniformly inside, which is what avoids
             * the label-squash the old natural-pixel + width:100% layout hit. */
            margin-top: 8px;
            overflow: hidden;
            border-top: 1px solid var(--vscode-widget-border);
            padding-top: 8px;
        }
        .network-toolbar {
            display: flex;
            gap: 6px;
            align-items: center;
            margin-bottom: 6px;
            flex-wrap: wrap;
        }
        .network-btn {
            cursor: pointer;
            font: inherit;
            font-size: 0.85em;
            min-width: 26px;
            padding: 2px 8px;
            color: var(--vscode-button-secondaryForeground, var(--vscode-foreground));
            background: var(--vscode-button-secondaryBackground, var(--vscode-editor-inactiveSelectionBackground));
            border: 1px solid var(--vscode-widget-border);
            border-radius: 4px;
        }
        .network-btn:hover {
            background: var(--vscode-button-secondaryHoverBackground, var(--vscode-toolbar-hoverBackground));
        }
        .network-btn-toggle { margin-left: auto; }
        .network-svg {
            display: block;
            width: 100%;
            height: 380px;
            /* touch-action:none lets a pointer drag pan without the browser
             * hijacking the gesture for page scroll/zoom. grab/grabbing cursor
             * signals the canvas is draggable. */
            touch-action: none;
            cursor: grab;
        }
        .network-svg.network-panning { cursor: grabbing; }
        .network-edge {
            stroke: var(--vscode-widget-border);
            stroke-width: 1;
            opacity: 0.6;
            fill: none;
        }
        .network-edge-link { cursor: pointer; }
        .network-node {
            fill: var(--vscode-foreground);
            /* 12px (was 10px): the panel sat in a scrollable container at
             * natural size, so tiny labels were unnecessary — readability
             * matters more than fitting more in the viewport. */
            font-size: 12px;
            font-family: var(--vscode-font-family);
        }
        .network-node-link {
            cursor: pointer;
        }
        .network-node-link:hover,
        .network-node-link:focus {
            fill: var(--vscode-textLink-foreground);
            text-decoration: underline;
            outline: none;
        }
        .network-node-link.network-selected,
        .network-edge-link.network-selected {
            stroke: var(--vscode-textLink-foreground);
            fill: var(--vscode-textLink-foreground);
            opacity: 1;
            stroke-width: 1.6;
        }
        .network-node.direct { font-weight: 700; }
        .network-node.transitive { opacity: 0.85; }

        /* ---- Detail-pane copy-as-JSON button ---- */
        /* Sits beside the close button in the detail-pane header; styled to
         * match .detail-pane-close so the two header actions read as a pair. */
        .detail-pane-actions { display: flex; align-items: center; gap: 2px; }
        .detail-pane-copy {
            background: none; border: none; cursor: pointer; font-size: 1em;
            line-height: 1; color: var(--vscode-descriptionForeground);
            padding: 2px 6px; border-radius: 4px; user-select: none;
            transition: color 0.15s;
        }
        .detail-pane-copy:hover {
            color: var(--vscode-foreground);
            background: var(--vscode-list-hoverBackground);
        }
        .detail-pane-copy:focus-visible {
            outline: 1px solid var(--vscode-focusBorder); outline-offset: 2px;
        }
        .detail-pane-copy.copied { color: var(--vscode-testing-iconPassed); }
`;
}

export function reportStylesPart8(): string {
    return `
        /* ---- Chart filter indicator ---- */
        .chart-filter-indicator {
            padding: 4px 12px;
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 4px;
            font-size: 0.85em;
            display: flex; align-items: center; gap: 8px;
            margin-top: 8px;
        }
        .clear-filter-btn {
            background: none; border: none; cursor: pointer;
            color: var(--vscode-textLink-foreground);
            font-size: 0.85em;
        }
        .clear-filter-btn:hover { text-decoration: underline; }

        @media (prefers-reduced-motion: reduce) {
            /* gauge-fill SMIL <animate> is removed at runtime by
               report-script.ts when this query matches — CSS can't disable
               SMIL, so the JS path is the only reliable kill-switch. */
            .expand-chevron { transition: none; }
            .detail-pane-copy { transition: none; }
            .summary-card[data-filter] { transition: none; }
            .active-filter-chip { transition: none; }
            .bar-row { transition: none; }
            .search-clear { transition: none; }
            .footprint-toggle .toggle-btn { transition: none; }
            /* Hold the indeterminate sweep still so reduced-motion users get a
               static partial bar instead of a continuously sliding stripe. */
            .scan-progress-fill.indeterminate { animation: none; }
            /* Busy-button spinner stops spinning; the relabel still signals work. */
            .action-btn.btn-busy::before, .btn.btn-busy::before { animation: none; }
        }

        /* ---- Live scan-progress bar ----
           Sits directly under the header; the host drives it via postMessage
           during a rescan so the dashboard shows determinate progress instead
           of looking frozen behind a lone VS Code toast. Determinate fill width
           is set from JS (CSSOM, allowed under the strict nonce CSP); the
           indeterminate sweep covers the brief window before the first percent
           arrives. */
        .scan-progress {
            margin: 0 0 12px;
            padding: 8px 12px;
            border-radius: 6px;
            background: var(--vscode-editorWidget-background, var(--vscode-editor-background));
            border: 1px solid var(--vscode-widget-border, transparent);
        }
        .scan-progress-track {
            position: relative;
            height: 6px;
            border-radius: 3px;
            overflow: hidden;
            background: var(--vscode-progressBar-background, var(--vscode-editorWidget-border));
            opacity: 0.85;
        }
        .scan-progress-fill {
            height: 100%;
            width: 0%;
            border-radius: 3px;
            background: var(--vscode-progressBar-background, var(--vscode-button-background));
            transition: width 0.25s ease;
        }
        /* Before the first percent: a moving stripe so the bar reads as "working"
           rather than stuck at 0%. JS swaps this class off once a real percent
           arrives. */
        .scan-progress-fill.indeterminate {
            width: 35% !important;
            animation: scanSweep 1.1s ease-in-out infinite;
        }
        @keyframes scanSweep {
            0%   { margin-left: -35%; }
            100% { margin-left: 100%; }
        }
        .scan-progress-meta {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            gap: 12px;
            margin-top: 6px;
            font-size: 0.85em;
            color: var(--vscode-descriptionForeground);
        }
        .scan-progress-label {
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .scan-progress-pct {
            font-variant-numeric: tabular-nums;
            flex: 0 0 auto;
        }

        /* ---- Busy state for pane action buttons (Upgrade / Retry) ----
           A slow host op (pub get + test, or network re-fetches) disables the
           button and prefixes a spinner so the pane shows it is working rather
           than sitting idle behind a toast. */
        .action-btn.btn-busy, .btn.btn-busy {
            opacity: 0.85;
            cursor: progress;
        }
        .action-btn.btn-busy::before, .btn.btn-busy::before {
            content: '';
            display: inline-block;
            width: 0.85em;
            height: 0.85em;
            margin-right: 6px;
            vertical-align: -0.12em;
            border: 2px solid currentColor;
            border-right-color: transparent;
            border-radius: 50%;
            animation: btnSpin 0.7s linear infinite;
        }
        @keyframes btnSpin { to { transform: rotate(360deg); } }
    `;
}

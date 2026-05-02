<!-- markdownlint-disable-file MD024 MD033 -->
# Changelog

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTEANCE NOTES -- IMPORTANT --

    All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

    Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

    Each release (and [Unreleased]) opens with a short plain-language **overview** for humans — user-facing only, casual wording, 2–4 sentences max. Summarize what changed from the user's point of view; do NOT restate implementation details from the `### Added/Changed/Fixed` sections below. Hard bans in the overview: line numbers, file paths, regex snippets, internal flag names (`multiLine: true`, `requiredPatterns`, etc.), specific counts/percentages from particular projects ("22,695 issues on project X", "96.8% of the backlog"), AST/visitor terminology. If a reader would have to open the code to understand a phrase, it belongs in the detailed section — not the overview. End the overview (no linebreak) with: [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md) substituting X.Y.Z.

    **Bullet density (HARD RULE — applies to every entry under `### Added` / `### Changed` / `### Fixed` / `### Removed`, including `### Added (Extension)` / `### Fixed (Extension)` / `### Changed (Extension)` and similar)** — One sentence per bullet. That sentence answers, in order: *what changed* → *why the user cares* → *what the user must do* (say "No action required" explicitly when true). A second sentence is allowed ONLY when a concrete user action (migration step, config line to remove) cannot fit in the first. Three-sentence bullets are forbidden — split into multiple bullets, or move the detail to the commit message, PR description, bug report, or inline code comment. When a bullet genuinely needs more context, LINK OUT to those places; do not inline the explanation. Concision edits may touch historical sections on purpose.

    Hard bans inside bullets (send any of these to the commit message / PR / code comments instead):
    - **PR archaeology** — narrative of prior failed attempts, rename history, "after X didn't hold…". The changelog describes the landed state.
    - **File-by-file inventories** — `Removed from config_rules.dart, saropa_lints.dart, tiers.dart, …`. That's the git diff.
    - **Test counts** — `8,585 Dart tests pass` / `817 passing, 1 failing (unrelated)`. That's CI output.
    - **Code-internal names** — AST visitor classes, regex flags (`multiLine: true`), function signatures (`flushReport(root, options?)`), field names, type names, private identifiers. If a reader would need the source to understand the phrase, it does not belong here.
    - **Bug-report / fixture / test file paths** — those belong in the commit message footer.
    - **How-the-decision-was-made paragraphs** — one-clause reasoning is fine; a paragraph is not.

    **Maintenance** `<details>` bullets: keep them short and free of the same bans (no test counts, no file inventories); the strict what → why → must-do template is optional there when the change is infra-only.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

    **CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

    **Score** — [pub.dev/packages/saropa_lints/score](https://pub.dev/packages/saropa_lints/score)

    **Maintenance entries** — Anything with **no end-user impact** (publish/CI tooling, internal refactors, test harness tweaks, plan-folder housekeeping, developer-only scripts) goes INSIDE a collapsed `<details><summary>Maintenance</summary>...</details>` block at the *bottom* of its version section — NOT in `### Added` / `### Changed` / `### Fixed`, which are reserved for user-visible changes that ship in the `.dart` / `.vsix` artifacts. Rule of thumb: if a pub.dev / Marketplace user running the published package would notice the difference, it belongs in a top-level section; otherwise it belongs in the Maintenance expander.

-->

---

## [Unreleased]

### Changed (Extension)

- The **Findings Dashboard** title now reads *Saropa Findings Dashboard* in the page heading (previously only the editor tab carried the *Saropa* prefix), and the toolbar's Copy JSON / Save report buttons have moved into the **More actions ▾** overflow menu so the visible action row stays scannable. No action required — both exports remain reachable from the same overflow menu that already housed the rest of the palette.
- The **Findings Dashboard** suppressions list now renders rule names with the same monospace tag style used in the findings table; previously the two surfaces used different elements (`<code>` vs. `<span class="rule-tag">`) which made suppression rows look pre-highlighted. No action required.
- The **Code Health Dashboard** KPI strip now suppresses zero-count categories and collapses to a single muted *all clear* line when every category is zero, instead of greeting healthy projects with a row of identical zeros. No action required — categories reappear as their counts grow.
- The **Code Health Dashboard** filtered table now shows an empty-state banner with a *Reset filters* button when search or a flag-card filter narrows it to zero rows, instead of leaving the user staring at an empty table with no cue. No action required — the banner appears and disappears with the filter state.
- The **Code Health Dashboard** gate-failure banner now carries an *Open Code Health settings* button so the user can act on a failing quality gate from inside the banner; previously it offered only explanatory text. No action required.
- The **Rule Explain panel** now renders each section as an inset card with consistent `<h4>` subsection headings, OWASP labels as a definition list, and the *Documentation* link as a tier-2 button — so the panel inherits the same visual depth and CTA emphasis as the Findings and Code Health dashboards. The panel also drops its private body styles so it picks up the shared `max-width` and full-width toggle. No action required.
- The **Rule Explain panel** now omits the *Problem* section entirely when a rule carries no message, instead of advertising a *No message* placeholder card. No action required.
- The **Command Catalog** panel cleans up its toolbar surface: the search-tokenization hint moves below the toolbar band as a one-line muted note (it previously lived inside the toolbar and ate vertical space), the *Frequent* tiles drop their primary-button tint in favor of the editor's inactive-selection tone (so toolbar buttons keep visual primacy), and category-count badges now show a focus/hover outline so the click target is visible before commit. No action required.
- The **Related Rule Telemetry** panel now right-aligns the count column with nowrap so wide integers do not wrap mid-number, demotes the *Refresh* button out of tier-1 (no action on this read-only counter table dominates strongly enough to deserve primary emphasis), disables the *Reset counters* button when no events have fired, and replaces the blank counter table with an empty-state *Open Findings Dashboard* CTA when telemetry is empty. No action required.
- The **Single-package detail** panel cleans up several rendering gaps: the page heading no longer reads *Saropa Package: foo* (it now reads *Saropa foo*, dropping the redundant noun), the external-link strip renders only once at the bottom of the page (it previously appeared both below the hero and again at the foot), the gap-summary number jumps from `1.5em` to `1.8em` so KPIs read as KPIs, the version-gap filter row becomes a quiet segmented radio control (no longer a row of primary-button-colored pills), section blocks pick up a secondary background tone for inset-card depth, external vs. in-panel links pick up distinct hover patterns, and the body inherits a `max-width` with the chrome's full-width toggle override. All hard-coded dark-only hex fallbacks (`#252526`, `#2a2d2e`, `#333`, etc.) are dropped so light and high-contrast themes render correctly. No action required.
- The **Package comparison** panel grows a KPI summary row (Leading package / Packages compared / Dimensions ranked), a toolbar band with a *Package Dashboard* button, and a tier-1 *Open Package Dashboard* CTA in its empty state — so the page no longer jumps from hero straight to a bare table. Per-row *Add to Project* buttons drop their primary-button color in favor of secondary tokens so multiple inline Adds stop competing with the toolbar for emphasis. No action required.
- The **Known Issues Library** panel now lights up the matching KPI card when you pick *Has replacement* / *No replacement* (the cards previously had click handlers but never reflected the active filter), renders an active-filter chip strip when search or category filters diverge from defaults so you can see and remove individual constraints, and shows an empty-state *Reset filters* tier-1 button when search or filter narrows the table to zero rows. No action required.

### Fixed (Extension)

- The **Size Distribution** chart in the Package Vibrancy report now draws each bar at a length proportional to its percentage — previously every bar rendered at the full track width regardless of the package's share, making the visualization unreadable. No action required — reopen the report after updating.
- The **Command Catalog** category-jump flash (the brief tint that highlights a section after you click its count badge) now reliably appears in webview environments where CSS `var()` references inside `@keyframes` fail to resolve — the highlight previously did nothing on those builds. No action required.

---

## [13.0.2]

The Top Rules table in the Findings Dashboard now lets you choose between hiding a noisy rule just for yourself or disabling it across the whole project — two buttons per row, side by side, so the commitment is obvious before you click. Hide stays personal and reversible; Disable writes the rule into your project config and re-runs analysis on the spot. [log](https://github.com/saropa/saropa_lints/blob/v13.0.2/CHANGELOG.md)

### Added (Extension)

- Each row in the **Findings Dashboard** Top Rules table now has a **Disable** button next to the existing **Hide** button — Hide is workspace-only (per-user, reversible via Clear Suppressions) while Disable writes the rule to `analysis_options_custom.yaml` so the whole project stops running it (team-shared, persistent, re-runs analysis automatically). No action required — open the Findings Dashboard to use it.

---

## [13.0.1]

The Findings Dashboard gets a Top Rules table that ranks the noisiest rules by count and gives you a one-click Hide button per row, so a screen full of repeated INFO lints stops drowning out the warnings you actually need to see. Behind the scenes the Code Health Dashboard scan no longer stacks parallel processes when you click rescan in quick succession, and every visible label, toast, and Command Catalog entry now uses the on-screen "Code Health" name instead of the older "Project Vibrancy" wording. [log](https://github.com/saropa/saropa_lints/blob/v13.0.1/CHANGELOG.md)

### Added (Extension)

- The **Findings Dashboard** now shows a **Top Rules** triage table above the findings list, ranking the noisiest rules by count with severity and a per-row Hide button so a single click suppresses a rule across the workspace findings (same hide as the Issues tree's "Hide rule", reversible via Clear Suppressions). No action required — open the Findings Dashboard to use it.

### Fixed (Extension)

- The **Code Health Dashboard** scan no longer stacks parallel `dart run` processes when the command fires repeatedly (sidebar item, rescan button, command palette) — concurrent invocations now share one in-flight scan, and the progress notification is cancellable so a runaway scan can be stopped from the toast. No action required.
- Renamed every user-facing **Project Vibrancy** label to **Code Health** so toasts, banners, tooltips, the toolbar settings button, the Settings group title, the README section, and the Command Catalog all match the dashboard panel name. The setting keys (`saropaLints.projectVibrancy.*`) and the underlying CLI executable (`saropa_lints:project_vibrancy`) are unchanged so existing `settings.json` files keep working. The old name still appears once in the LCOV-path setting description as a migration breadcrumb so users searching for "Project Vibrancy" still find it. No action required.
- Moved the **Open Code Health Dashboard** and **Open Code Health Settings** entries in the Command Catalog from the **Package Vibrancy** category to a new **Code Health** category — Code Health scores your own source, Package Vibrancy scores your dependencies, and they should not appear under the same heading.
- Removed two factually wrong claims from the README's Code Health section: the dashboard is an editor tab (not a sidebar webview, which was removed in v13.0.0), and the **Refresh Project Vibrancy Sidebar** command no longer exists. The section now describes the editor-tab dashboard, the KPI-card filters, and the actual ways to launch a scan.

---

## [13.0.0]

This release rebuilds the VS Code extension around a single dashboard look so the **Findings**, **Lints Config**, **Code Health Dashboard**, **Package Dashboard**, **Known Issues**, and **Package Comparison** editor tabs all share the same hero band, status line, KPI cards that double as filters, sticky toolbars, and sortable tables. The Saropa activity bar collapses into one flat **Saropa Lints** sidebar — many duplicate tree views are gone in favor of the editor tabs they were always pointing at, so there is one obvious place to land for each task. A common nullable build-context guard pattern no longer trips the after-await context lints, and a handful of webview, path-resolution, and cache fixes round things out. [log](https://github.com/saropa/saropa_lints/blob/v13.0.0/CHANGELOG.md)

### Added (Extension)

- The **Lints Config** header now carries a coverage gauge (red→amber→green) showing what fraction of the packs detected in your pubspec are actually enabled, so you can tell at a glance whether your config is taking advantage of the available tooling. No action required.
- The **Pack coverage** chart now renders a donut companion next to the existing horizontal-bar list — segments are clickable filters on the same pack contract as the bars, and they cross-highlight when a bar or segment is selected. No action required.
- A **Copy config** toolbar action copies a paste-ready `analysis_options.yaml` snippet (tier + enabled rule packs, sorted) to the clipboard so you can replicate the configuration in another project. No action required.
- The **Code Health Dashboard** now opens with a status line (generated, function count, average score, gate state), an average-score gauge in the header, and KPI cards (Unused, Uncovered, Stub-tested, Suspicious coverage, Test drift) that double as click-to-filter presets on the table. No action required — open *Saropa Lints: Open Code Health Dashboard* to see the new layout.

### Changed (Extension)

- The **Lints Config** editor tab is rebuilt around the gold-standard dashboard pattern: a status line under the title now shows tier, pack coverage, applicable SDK migrations, and analysis freshness instead of marketing copy; KPI cards are clickable preset filters with hero-sized numbers; the tier selector is a real radio segmented control (replacing the read-only chips and the separate *Set tier* toolbar button); the toolbar is a banded sticky strip with one primary *Run analysis* action and a *Enable applicable packs ▾* split-button for the breaking / deprecation variants. No action required — open the **Lints Config** tab to see the new layout.
- The two pack tables (*SDK migration packs* and *Package rule packs*) are merged into one searchable, sortable table with **Type** and **Risk** columns; the table now supports text search, type filter, *Detected only* / *Enabled only* checkboxes, and an active-filter chip strip with per-chip removal and *Clear all*. The *Pack coverage* chart is hidden when no pack is enabled or detected, and its bars now click through to filter the table. The suppressions snapshot, target platforms, and docs links move to a diagnostics band below the table. No action required.
- **Findings**, **Lints Config**, and **Code Health** dashboards now share one visual chrome (header band with status line and gauge, KPI cards as preset filters, banded sticky toolbar with density tiers, segmented filter controls, active-filter chip strip, sortable sticky-header table, bar+donut chart pair). Class names and tokens are unified so a user moving between the three sees the same buttons, fields, and layout grid. No action required.
- Every editor-area dashboard now adopts the gold-standard hero band — **Saropa Package Dashboard**, **Saropa Package Comparison**, **Saropa Known Issues**, **Saropa Package Detail**, **Saropa Rule Explain**, **Saropa Related Rule Telemetry**, and **Saropa Lints — About** all carry a Saropa-prefixed title, version stamp, and a status-line strip of facts (last run, counts, freshness) so each tab telegraphs *what it knows right now* without scrolling. Sidebar webviews and tree views keep their unprefixed labels because the activity bar already supplies the product context. No action required.
- Every editor-area dashboard now constrains content to a readable max-width (~1280px) with a **↔ full-width toggle** in the status line, so panels stay legible on ultrawide monitors but can stretch on demand for wide tables and side-by-side comparisons. The toggle persists per webview session. No action required.
- Severity, impact, and replacement filter toggles render with an inverted visual model: included values stay quiet (the resting state) while excluded values are struck through and faded, so the dashboard greets you with calm chrome at defaults instead of a wall of blue pills, and only shouts when you have actively narrowed the view. The pressed-state vocabulary no longer collides with the **Run analysis** primary button. No action required.
- Tier and footprint mode toggles (radio-style, exactly one active) drop the primary-button background in favor of a soft inactive-selection backdrop, so the active option reads as selected without competing with the toolbar's tier-1 actions. The **Lints Config** *Show detected / Show enabled* filter uses a third *additive* variant where pressing a button narrows the result and the active state stays muted. No action required.
- The **Saropa Known Issues** library now treats its summary cards as click-to-filter presets (Showing / Total / Has replacement / No replacement) and replaces the binary checkbox with a multi-toggle segmented control, so each card maps to a distinct filter state instead of acting as decoration. No action required.
- The **Saropa Package Comparison** panel moves the recommendation summary below the comparison table — the user's reason for opening the panel is the data, not the synthesis — and the empty-state still leads with the Saropa-prefixed hero so the page identity is visible before content arrives. No action required.
- The **Saropa Related Rule Telemetry** panel adopts the shared toolbar band, KPI-style empty state, and `Refresh / Copy JSON / Reset counters` density tiers (one primary, two secondary, destructive last) so it stops looking like a one-off debug page and matches the rest of the editor surfaces. No action required.
- The **Saropa Package Dashboard** and **Saropa Command Catalog** hero bands now match the Findings dashboard's contained, rounded panel with focus-tinted border, soft radial gradient over the editor-widget surface, and a short fade-in on mount — replacing the bare flex container and the full-bleed gradient stripe respectively, so all four editor dashboards open with the same visual signature. No action required.
- The **Command Catalog** editor tab is redesigned around the editor-dashboard guidelines so the 156-command list no longer reads as one uniform wall: the marketing subtitle is replaced with a real status line (commands, categories, recent count, internal-hidden), search and the context-menu toggle live in one sticky toolbar band with an inline (×) clear and an active-filter chip strip, the **Recent** strip caps at six chips behind **+N more** above a new usage-ranked **Frequent** band, rows are slimmed to icon + title + one-line description with the command id revealed via a hover-only **copy** affordance and tooltip, category cards lose their borders for sticky uppercase microlabel headers, count badges become click-to-jump anchors that flash the target section, and Up/Down/Home/End navigate visible rows for keyboard-first browsing. No action required.
- The Saropa activity bar now hosts a **single flat sidebar** named **Saropa Lints** instead of the previous **Dashboards** + **Overview & options** split, with no in-panel group headers; editor-tab dashboards, run/discover actions, project status rows, settings toggles, triage groups, and help links all sit at the top level so duplicate copies of **Run analysis**, **Getting Started**, **About**, and **pub.dev** are gone. No action required; if you set `saropaLints.sidebar.showOverview` to `false` it now hides the unified view.
- The **Dashboards** activity-bar hub drops the **Violations tools** row group; the same filter, grouping, suppression, and navigation commands remain on the **Findings Dashboard** tab (toolbar + **More commands**) and in the Command Palette. No config change.
- The **Findings Dashboard** adds **Refresh extension** (full `saropaLints.refresh`: trees, annotations, report-backed views) next to **Refresh from disk**. No config change.
- The Saropa activity bar keeps **Dashboards** and **Overview & options** only; per-section `saropaLints.sidebar.show*` toggles under Overview were removed with the migrated views. **`saropaLints.exportOwaspReport`** is available from the Command Palette when the workspace has violations.
- The five dashboard hub labels drop the **Saropa** prefix (now **Lints Config**, **Package Dashboard**, **Code Health Dashboard**, **Findings Dashboard**, **Command Catalog**) so the activity-bar tree stops reading as "Saropa Saropa Lints …"; editor-tab titles and primary headings keep the **Saropa** prefix so the tabs stay findable in Quick Open, Recent Files, and the editor tab dropdown. No action required.
- Package Vibrancy timestamped JSON, Markdown, and SBOM exports now save under **`<workspace>/reports/`** instead of **`report/`**, matching cross_file CLI defaults and other Saropa on-disk report paths. No action required if you only use extension commands and webviews.
- Automation that consumed **`report/*_saropa_vibrancy.*`** must use **`reports/`**; first-time vibrancy history backfill still scans legacy **`report/`** when importing old timestamped JSON into `.saropa/vibrancy-history.json`.
- The **Dashboards** hub lists editor dashboards only (the extra “Violations sidebar” jump row is removed because that tree no longer exists). No action required.
- The **Findings Dashboard** adds a compact **More commands** row (palette actions for filters, help, vibrancy, config, and **Copy tree JSON**) so shortcuts that lived on the old Violations title bar stay one click away in the editor tab. No action required.
- **Help & resources** includes **Create project instructions** so that command stays visible after the hub trim. No action required.
- The **Findings Dashboard** editor tab now includes **Suppressions (export)** (same breakdown as the violations export summary) and **Issues view hides** (workspace list filters) with actions to clear filters, drill by rule or file, and clear view hides, so you can review suppressions without a separate Violations tree. No action required.
- The **Findings Dashboard** is redesigned around a hero strip (title, version stamp, last-run pill, severity-weighted health gauge), interactive KPI cards that double as preset filters (Errors, Warnings, Critical+High, Files affected, Top rule), an active-filters chip strip with one-click removal, a sortable sticky-header findings table with per-row Copy and group expand/collapse, a Save-report button that writes timestamped JSON under `reports/YYYYMMDD/`, and an overflow **More ▾** menu replacing the flat 14-button palette row; severity/impact mix renders as bars + donut and the card hides entirely when every slot is zero. No action required—filters and existing actions remain in place.
- The **Findings Dashboard** suppressions block drops the inert **By kind** sub-list (clicks did nothing) and inlines the kind breakdown next to the section title, so every visible row is now actionable—rule and file rows still drill into Findings; analyzer / view-hide sections collapse to a one-line muted footer when there is nothing to show. No action required.
- The **Findings Dashboard** TODOs, HACKS, and Drift Advisor sections render in density-first order above empty placeholders so actionable markers stay above the fold; sections with no data collapse to a single muted footer rather than reserving full bordered bands. No action required.
- The **Config Dashboard** shows a read-only **Suppressions (export)** strip (totals and by-kind snapshot from the current report, after the disabled-rule filter) plus **Open Findings Dashboard** for the full breakdown; browse, clear view hides, and drill-down stay on Findings. No action required.
- Package Vibrancy user-facing text now refers to the **activity-bar list**, **Package Dashboard** (editor tab), and **CodeLens** instead of generic “tree view” wording; **Saropa Lints: Open Package Dashboard** is the palette label for `saropaLints.packageVibrancy.showReport` (same command id). No config change.
- **Open Package Vibrancy**, **Open Code Health Dashboard**, and **Open Project Vibrancy Settings** now have toolbar icons, and the **Dashboards** hub title bar includes **Open Package Vibrancy** and **Open Code Health Dashboard** in Dart workspaces so the main vibrancy webviews stay one click away from the activity bar. No config change.
- **Config Dashboard** (rule packs, tiers, charts) opens as an **editor tab** instead of a Saropa sidebar webview so the layout matches a real dashboard width. No action required.
- **Open Config Dashboard** has a toolbar icon on the **Dashboards** hub in Dart workspaces (Overview title unchanged); the `saropaLints.sidebar.showRulePacks` setting is removed because that sidebar section no longer exists—delete the key from settings JSON if you set it explicitly. No other migration.
- **Composite analyzer plugin scaffold** shows an explanatory notification with **Continue** and **Open guide** before the folder prompt so the flow is obvious; **Open guide** opens the composite-plugin documentation in the browser without writing files. No action required.
- Editor-area dashboards (**Package Vibrancy**, **Package Details**, **Telemetry**, **Command Catalog**) now use a consistent pill-shaped button style with secondary-button theme tokens, so the toolbar / action buttons read the same across these dashboards and contrast correctly in light, dark, and high-contrast themes. No action required.
- Improved readability of detail and summary panels in the **Package Vibrancy** report and **Package Details** view: bumped tiny 0.8–0.85em text to 0.9–0.95em and replaced low `opacity: 0.6` muting on labels with the theme-aware `descriptionForeground` token, so panels like **Health Score**, summary cards, and gap-table cards stay legible (and WCAG-compliant) in light, dark, and high-contrast themes. No action required.
- The **Findings Dashboard** **Severity mix** and **Impact mix** charts hide rows whose count is zero (and show a single muted **No findings.** line when every bucket is empty) so empty tracks no longer pad the chart cards. No action required.
- The **Lints Config** *Rule packs* table and *Disabled rules* block are now collapsible expanders — packs open by default, the (previously wall-of-text) disabled-rules block starts collapsed — so the dashboard reads as two intentional sections instead of one long scroll. No action required.
- The **Lints Config** *Disabled rules* block now ships with a search input and groups rules by their owning rule pack (with a *Tier-only (no pack)* bucket last), so triaging large override lists is one search box instead of an alphabetical scroll. No action required.

### Removed (Extension)

- The **Composite analyzer plugin (scaffold)** row is removed from the Saropa Lints sidebar (both the **Config** tree and the sectioned sidebar) because the action only applies to teams that ship their own custom analyzer rules alongside Saropa, and the term was jargon for the typical user. The action stays available via the command palette (`Saropa Lints: Create Composite Analyzer Plugin (scaffold)`), `Saropa Lints: Show All Commands`, the CLI flag `dart run saropa_lints:init --emit-composite-plugin-scaffold`, and `doc/guides/composite_analyzer_plugin.md`. No action required.
- The palette entry **Saropa Lints: Focus Violations View** (`saropaLints.focusView`) is removed because it did not focus a violations tree and duplicated **Open Overview** behavior; the main Saropa status bar still opens the Overview view via the same underlying focus command. No action unless you referenced `saropaLints.focusView` in keybindings or tasks—use `saropaLints.overview.focus` instead.
- The **Violations** activity-bar tree (`saropaLints.issues`) is **removed from the extension manifest** so lint findings are not hosted in a duplicate sidebar; use the **Findings Dashboard** editor tab and the `$(warning)` status item. The **`saropaLints.sidebar.showIssues`** setting is removed—delete it from JSON if present.
- The **Commands** sidebar webview (`saropaLints.commandCatalogSidebar`) and **`saropaLints.sidebar.showCommandCatalog`** are removed; **Browse All Commands** / **Command Catalog** open the **editor tab** only.
- The Project Vibrancy sidebar view and its refresh command are removed so function-level vibrancy lives only in the editor-area report, which removes duplicate UI and avoids cramped sidebar layouts. Use **Saropa Lints: Open Code Health Dashboard** (Command Palette or Saropa navigation where offered). No config change.
- **Summary**, **Suppressions**, **Suggestions**, **Security Posture**, **File Risk**, **TODOs & Hacks**, **Drift Advisor**, **Package Vibrancy** (dependency tree), and **Package Details** (sidebar webview) are **removed from the Saropa activity bar**; use the **Findings Dashboard**, **Lints Config**, **Package Dashboard**, and Command Palette instead. Delete **`saropaLints.sidebar.showSummary`** through **`saropaLints.sidebar.showDriftAdvisor`** from settings JSON if you set them explicitly—only **`saropaLints.sidebar.showOverview`** remains under Activity bar.

### Fixed

- **`avoid_context_across_async`** and **`avoid_context_after_await_in_static`** no longer report the idiomatic compound nullable guard `context != null && context.mounted ? context : null` (used by extension methods and static helpers that take a `BuildContext?` parameter); both the null-check `context` and the then-branch `context` are now recognized as part of the guard. Remove any temporary `// ignore` workarounds you added for that pattern.

### Fixed (Extension)

- The **Package Dashboard**'s *Active filters:* strip no longer renders as an empty "Active filters: Clear all" band when no filters are active. The strip now uses the HTML5 `hidden` attribute (paired with a `[hidden] { display: none !important }` rule) instead of an inline `style.display="none"` that any later style write could clear. No action required.
- Reclicking the **Lints Config** entry in the Saropa sidebar when the dashboard tab is already open now moves keyboard focus into the dashboard, instead of leaving focus on the sidebar tree row (which made the reclick feel like a no-op). No action required.
- Header gauges on the **Findings**, **Lints Config**, **Code Health**, and **Package** dashboards now render their arc at the correct level and animate on first paint instead of showing only a tiny green dot next to the grade letter. The webview Content-Security-Policy was blocking the inline `style` attribute that carries the gauge's score variable, and the chrome rule used a CSS transition (which only fires on value change) rather than a keyframe (which runs on initial render). No action required.
- The **Rescan** button in the Package Vibrancy report now clears the per-package pub.dev cache before scanning, so the report reflects current pub.dev versions instead of silently re-using cached entries within the 24-hour TTL. A new **Saropa: Rescan Packages (Fresh)** command exposes the same behavior from the Command Palette; the existing **Scan Packages** command stays cache-friendly for the file watcher and startup paths. No action required.
- **Dashboards** hub rows no longer show stale **Saropa**-prefixed labels after the quick-actions split (**Full-width tabs**, **Lints Config**, **Package Dashboard**, **Project Dashboard**, and quick-action descriptions without redundant **Saropa** wording); reload the window after upgrading the VSIX or dev build to pick up the tree provider. No config change.
- Opening a file from the Project Vibrancy report now resolves report paths against the workspace root on Windows and mixed path styles, so jump-to-file from a hit works reliably instead of failing on path shape. No action required.
- The **Code Health Dashboard** now invokes `dart run saropa_lints:project_vibrancy` (registered package executable) instead of the source path `bin/project_vibrancy.dart`, so the dashboard works in every consumer workspace instead of failing with *"Could not find file `bin/project_vibrancy.dart`"* outside the saropa_lints repo. No action required.
- Hardened three editor-area webview panels against script injection: the **Package Details** panel now uses a nonce-based Content-Security-Policy instead of `'unsafe-inline'`, the **About** panel rejects `javascript:` / `data:` / `vbscript:` / `file:` URIs in markdown links (rendered as plain text instead of an anchor), and the **Explain Rule** panel escapes `</script>` and U+2028/U+2029 in rule-name strings interpolated into its inline script. No action required.
- The **About Saropa Lints** panel now indents sub-bullets under their parent in sections like **VS Code Extensions** and **Smart Features**, restoring the parent/child hierarchy that previously collapsed into a flat sibling list and made product descriptions blur into the product names. No action required.

<details><summary>Maintenance</summary>

- VS Code Project Vibrancy scan startup now resolves the Dart executable per platform (`dart.bat` on Windows, `dart` elsewhere) and surfaces the underlying spawn error in the notification when startup fails, which prevents false “Dart SDK missing” messages on Windows PATH setups.
- Added `scripts/run_extension_local.py` to compile `extension/` and launch an Extension Development Host (shared `scripts/modules/_utils` branding, step progress, Node/npm/`dist` checks); see `scripts/README.md`. No action for pub.dev or Marketplace users.
- Recorded the native-plugin quick-fix migration as structurally complete in [`plan/TESTING_AND_RELEASE.md`](plan/TESTING_AND_RELEASE.md) §3 — `lib/` has 0 `extends DartFix` and 221 `extends SaropaFixProducer` files; remaining work is end-to-end verification, not migration.
- Added [`doc/troubleshooting.md`](doc/troubleshooting.md) covering the three IDE-specific failure modes (custom_lint not running, rules absent from Problems panel, missing lightbulb fix), separate from the broader README §Troubleshooting.
- Added a "Supported Versions" note to [`README.md`](README.md) describing the active 12.x line and security-only backport policy for earlier majors.
- `scripts/run_extension_local.py` auto-detect now prefers `code` (VS Code) over `code-insiders` and other VS Code-compatible CLIs, so devs with both editors installed get the VS Code Extension Development Host by default; override with `--editor <name>` or `SAROPA_VSCODE_CLI`.
- `scripts/run_extension_local.py` now starts a detached `npm run watch` after compile so `.ts` saves rebuild `dist/extension.js` automatically for the running EDH session — previously the bundle stayed frozen at launch and every code change required re-running the script. Disable with `--no-watch`; logs land in `extension/.watcher.log`.
- Expanded [`plan/guides/UX_UI_GUIDELINES.md`](plan/guides/UX_UI_GUIDELINES.md) with toolbar density tiers, mandatory active-filter chip strip, status-line under H1, button hierarchy beyond primary/secondary, "same row visual = same row contract" rule, and a new §14 anti-pattern catalog (bait-and-switch rows, doubled empty states, placeholder-as-content, flat-toolbar overflow, buried high-value sections, decorative weight without depth, density-first content ordering, inert KPI cards, status-line absence, identical-twin KPI cards) so future surfaces avoid the failure modes that prompted the Findings Dashboard redesign.
- `scripts/modules/_git_ops.py` `_push_with_retry` now prompts the developer to retry or abort on hard push failures (missing remote, auth error, network outage) instead of aborting the whole publish. Empty input defaults to retry so the dev can fix the underlying issue (e.g. re-add `origin`) and press Enter to continue from the same release commit.

</details>

---

## [12.8.3]

This patch release focuses on reducing noisy false positives so everyday Flutter and Dart code reads cleaner in the editor. Common animation flows, validated parsing paths, numeric loop accumulation, parent-data lifecycle field patterns, and guarded render-object parentData casts should now lint the way you expect. No config updates are needed; re-run analysis and you should see fewer distracting reports. [log](https://github.com/saropa/saropa_lints/blob/v12.8.3/CHANGELOG.md)

### Fixed

- **`avoid_redundant_await`** no longer flags `await` on `AnimationController.forward()` and `.reverse()` sequencing calls that return `TickerFuture`, so valid animation orchestration is not misreported as redundant. No action required.
- **`avoid_inert_animation_value_in_build`** no longer reports `Animation.value` reads inside child widget `build()` methods when that child is instantiated from a listening builder callback (for example `AnimatedBuilder`), so tick-driven subtrees are not misclassified as inert snapshots. No action required.
- **`prefer_try_parse_for_dynamic_data`** now skips `parse(...)` calls when the input is provably safe (valid numeric literals and digit-only regex-validated captures/substrings), so common validated parsing paths are no longer false positives. Remove any temporary local suppressions you added for those patterns.
- **`avoid_memory_intensive_operations`** now reports loop `+=` only when the operation is on strings, so numeric accumulation patterns no longer produce false positives. No action required.
- **`avoid_unassigned_late_fields`** no longer reports `late` fields declared on RenderObject parent-data classes (types in the `ParentData` inheritance chain), so lifecycle-initialized layout fields are not misclassified as unassigned. No action required.
- **`avoid_unsafe_cast`** no longer flags guarded `RenderObject.parentData` casts to `*ParentData` types when the enclosing class safely initializes that parent data shape in `setupParentData(...)`, so valid render-object parent-data workflows are not misclassified as unsafe casts. No action required.

---

## [12.8.2]

The VS Code extension now registers the **Suppressions** sidebar at startup, so you should see fewer “view not registered” glitches after an update or a full window reload. **avoid_redundant_await** also stops mis-flagging `await` on some third-party async builder-style APIs. No config change. [log](https://github.com/saropa/saropa_lints/blob/v12.8.2/CHANGELOG.md)

### Fixed

- **`avoid_redundant_await`** no longer flags `await` when the expression’s static type is a class that implements `Future` or `Stream` (e.g. Postgrest/Supabase builder APIs) instead of the plain `Future<…>` type, so legitimate awaits are not misreported as redundant. Remove any temporary `// ignore` workarounds you added for that pattern.
- **`avoid_inert_animation_value_in_build`** no longer reports `Animation.value` reads inside child widget `build()` methods when that child is instantiated from a listening builder callback (for example `AnimatedBuilder`), so tick-driven subtrees are not misclassified as inert snapshots. No action required.

### Fixed (Extension)

- The **Suppressions** tree binds at activation like other first-class sidebar trees, which avoids intermittent registration failures for that view. No action required; if a one-off error persists from an older session, use **Developer: Reload Window**.

<details><summary>Maintenance</summary>

- Tag-publish and CI analyze jobs run nested `dart pub get` (discovered under `packages/`, with the same retries as the root install) before `dart analyze` so nested packages resolve on fresh checkouts. No action for pub.dev or extension users.

</details>

---

## [12.8.0]

Cross-file and snapshot loading forgive bad JSON or YAML on disk, so one broken l10n file should not take down a whole run. Many rules now offer IDE quick fixes where a mechanical edit is safe, and you can cap which cumulative tier runs with an environment variable or plugin config if you do not want to hand-edit huge rule lists. A handful of rules were renamed for clarity, and exports plus the extension **Issues** view prioritize and label findings a bit more helpfully—re-run analysis if you rely on `violations.json`. [log](https://github.com/saropa/saropa_lints/blob/v12.8.0/CHANGELOG.md)

### Fixed

- Cross-file **unused-l10n** and snapshot loading from disk tolerate corrupt JSON and YAML so a broken ARB or snapshot file no longer aborts the whole run; if results look incomplete, fix or regenerate that file. No config change.

### Added

- Many **widget flex/scroll**, **GetX**, **iOS lifecycle**, **iOS capabilities**, and **security auth/storage** rules now register IDE quick fixes where a safe mechanical edit applies (layout unwraps, physics helpers, HTTPS in string URLs, GetX `super` lifecycle inserts, and similar). No config change; use the lightbulb when the offered fix matches your intent.

- Optional **runtime tier cap** lets you set `SAROPA_TIER` to `essential`, `recommended`, `professional`, `comprehensive`, or `pedantic` so analysis skips rules above that cumulative band without editing generated rule lists, or set the same value as `saropa_tier` in `analysis_options_custom.yaml` or as `runtime_tier` / `saropa_tier` under `plugins.saropa_lints` when you prefer file-based config; the environment variable wins if both are set. No action required until you want CI or local runs to enforce a lower band than your YAML enables.

### Changed

- **Lint identifiers:** `annotate_redeclares`, `document_ignores`, `duplicate_constructor`, and `package_names` were renamed to `annotate_inherited_member_redeclaration`, `document_analyzer_ignore_rationale`, `duplicate_constructor_declarations`, and `pubspec_package_name_convention` for clearer multi-word names; update `analysis_options.yaml` / Saropa config if you toggled those rules by id.
- **`prefer_schedule_microtask_over_window_postmessage`** is included in the **Professional** cumulative tier (alongside other web guidance). No change unless you rely on tier lists for automation.
- **VS Code:** the Triage tree no longer shows volume or critical groups when `violations.json` is missing, is older than four hours, or lacks `summary.issuesByRule`, because those states would mislead group-level rule actions; a single row with a **Run analysis** action explains the issue instead. Re-run analysis to refresh; no config change.
- **Plugin:** report import graph lookup now uses a path key index and caches the analyzed file set after `compute`, which cuts report-side overhead on large projects. No action required.
- **Plugin + VS Code:** each entry in `violations.json` now includes a numeric **`priority`** (same combined score as the report’s FIX PRIORITY section), and the Saropa **Issues** tree sorts findings by that score (then line) so the extension matches “fix what matters first” without opening the log. Re-run analysis to refresh the export; Problems tab behavior is unchanged.
- Cross-file `dart run saropa_lints:cross_file report` writes `feature-deps.html` and a shared `report.css` (light and dark via the browser) into the output folder, and the README explains that the CLI analyzes one package root at a time so monorepo users know to run it per package. Re-run `report` to refresh an existing output directory; no config changes.

<details><summary>Maintenance</summary>

- Release tooling: full publish builds `extension/saropa-lints-*.vsix` before the optional “re-run failed CI and watch” step so a long or interrupted watch does not leave the tree without a packaged extension when `npm`/`vsce` succeeded. No action for pub.dev or extension users.
- Stopping a CI run watch with Ctrl+C during publish is treated as “done watching” and the pipeline continues to tag, pub upload, and extension install or store publish; use **n** at the watch prompt to skip waiting. Maintainers only.
- `scripts/README.md` documents `python -m unittest discover` for the Python `scripts/tests/` suite (no pytest). Maintainers and CI already use the same command.

</details>

---

## [12.7.0]

Package Vibrancy and cross-file analysis get proper extension UI and several new CLI modes, metadata-rich exports make related rules and triage easier, and security hotspots plus suppressions are more workable end-to-end. This is a big extension-focused drop—update the VS Code side if you use those panels or vibrancy. Most Dart-only users still just upgrade the package and re-run analysis. [log](https://github.com/saropa/saropa_lints/blob/v12.7.0/CHANGELOG.md)

### Added

- Project Vibrancy now has primary extension UI surfaces: a dedicated sidebar webview (filters, quick unused/uncovered slices, persisted filter state, and `--since` git-ref scoped scans) plus a full report webview command with **clickable file links** per function row (opens the editor at the reported line range), so teams can use project-level code-health scoring directly in the IDE instead of CLI-only output. No action required beyond updating the extension and opening **Project Vibrancy** from the Saropa sidebar.
- Project Vibrancy now emits `stub_tested`, `suspicious_coverage`, and `test_drift` per function with summary counts in JSON, the sidebar, and the full report, plus optional `--max-stub-tested`, `--max-suspicious-coverage`, and `--max-test-drift` CI gates. No action required unless you adopt those gates in automation.
- Related-rule guidance is now available end-to-end via exported data (`config.relatedRulesByRule` / `config.ruleMetadataByRule` in `violations.json`, plus `consumer_contract.json`), extension surfaces (Violations/Issues tree hovers with **See also:** related rules, Rule Explain links, Suggestions), and init post-write hints so users can discover complementary rules faster without manual lookup. No action required.
- The VS Code extension now exposes cross-file analysis commands (unused files, circular dependencies, import stats, DOT graph export, and HTML report) with command-catalog and walkthrough discoverability, so CLI-only cross-file features are usable from the UI. No action required beyond updating the extension and running the new `Saropa Lints: Cross-File — ...` commands.
- Cross-file CLI now includes `feature-deps` output that reports feature-to-feature adjacency and concrete cross-feature import edges for `lib/features/<name>/...` projects, so architecture boundary drift is visible without custom scripts. No action required unless you want to consume the new `featureDependencies` / `crossFeatureImports` fields from JSON output.
- Cross-file CLI now includes a first-pass `unused-symbols` mode that reports likely unused top-level declarations across project files, so teams can identify dead public code quickly before deeper cleanup passes; use `--exclude-public-api` to skip exported lib files and `--include-private` to widen detection. No action required unless you want to run the new command and review candidates.
- The VS Code extension cross-file command set now includes feature dependency and unused symbol actions in addition to file/cycle/stats/graph/report, so new cross-file CLI capabilities stay discoverable in the command palette, walkthrough, and command catalog. No action required beyond updating the extension and running the added `Saropa Lints: Cross-File — ...` commands.
- Cross-file CLI now includes a first-pass `dead-imports` mode for likely dead relative imports, with extension command support, so teams can spot stale local imports during architecture cleanup without custom scripts; later bullets in this section add combinator imports, local re-export awareness, and deferred `loadLibrary()` handling on top of the first pass, while full analyzer-accurate symbol resolution remains future work. No action required unless you want to run the new command and review candidates.
- Cross-file `dead-imports` detection now understands aliased and combinator imports (`as` / `show` / `hide`) in its first-pass heuristic, so cleanup results are more accurate on common Dart import patterns without needing analyzer-level symbol resolution. No action required.
- Cross-file CLI now includes a first-pass `watch` mode that re-runs analysis on Dart file changes with configurable debounce and command targeting, so teams can iterate on architecture checks without manually re-running commands after each edit. No action required unless you want to use `watch` with `--command` and optional `--watch-debounce-ms`.
- Cross-file `watch` mode now prints per-rerun delta summaries (new vs resolved finding sets for `unused-files`, `circular-deps`, `feature-deps`, `dead-imports`, and `unused-symbols`, or per-rerun `import-stats` file/total-import count deltas), so ongoing edits are easier to track than re-reading full output each time. No action required.
- Cross-file text reporting now includes a feature dependency matrix view alongside adjacency listings, so boundary relationships are easier to scan visually in terminal and CI logs without post-processing. No action required.
- Added `tool/cross_file_benchmark.dart` to run repeatable cross-file performance benchmarks on synthetic 1000+-file projects, so maintainers can measure analysis throughput and compare optimization changes with a consistent harness. No action required unless you want to run benchmark checks locally or in CI.
- Cross-file `dead-imports` now understands local file re-exports when determining whether imported symbols are referenced, so barrel-file import patterns are less likely to be misreported as dead imports in the first-pass heuristic. No action required.
- Cross-file `dead-imports` now treats deferred imports as used when their prefix is used to call `loadLibrary()`, reducing false positives in lazy-loading patterns while semantic resolution work continues. No action required.
- Package Vibrancy now persists per-package score snapshots in workspace-local history and renders inline sparklines in the report so users can see score direction at a glance without external tracking. No action required.
- Package Vibrancy now auto-exports Markdown and JSON reports after each successful scan, so report files are always available without manual export clicks; set `saropaLints.packageVibrancy.autoExportReportsOnScan` to `false` if you prefer manual-only exports. No action required unless you want to disable auto-export.
- Package Vibrancy now runs a one-time historical backfill from existing vibrancy JSON report files with visible progress and completion messaging, so long-time users get trend sparklines without manually rebuilding history. No action required.
- Rule metadata now ships in analysis export output (`ruleMetadataByRule` in config and per-violation metadata) with summary breakdowns by `ruleType` and `ruleStatus`, so downstream tooling can build metadata-aware reports and gates without re-parsing rule classes. No action required unless you consume `violations.json`, in which case the new fields are available immediately.
- Violations view now supports metadata-driven workflows with Summary drill-down and direct toolbar filtering by rule metadata (`ruleType` / `ruleStatus`), so users can isolate vulnerability/hotspot/beta clusters in one click instead of hand-curating rule lists. No action required.
- Security hotspots now have a persisted review workflow (`open`, `reviewed-safe`, `reviewed-fixed`) with Issues actions and Summary/Overview progress counts, so teams can track triage completion across scans without external spreadsheets. No action required unless you want to start recording hotspot review state from the Violations context menu.
- Rule Packs now include SDK-gated packs (`dart_sdk_3_2`, `dart_sdk_3_4`, `flutter_sdk_3_0`, `flutter_sdk_3_7`, `flutter_sdk_3_10`, `flutter_sdk_3_16`, `flutter_sdk_3_18`, `flutter_sdk_3_19`, `flutter_sdk_3_22`, `flutter_sdk_3_24`, `flutter_sdk_3_28`, `flutter_sdk_3_29`, `flutter_sdk_3_32`, `flutter_sdk_3_35`, `flutter_sdk_3_38`) driven by pubspec `environment` constraints, so migration packs can be suggested/enabled by target SDK level instead of only dependency names. No action required unless you want these packs, in which case add them under `plugins.saropa_lints.rule_packs.enabled`.
- `dart run saropa_lints:init --emit-composite-plugin-scaffold [dir]` writes a minimal **composite** analyzer-plugin package (Saropa registrars + hook for your rules) so orgs can wire a single `plugins:` key without hand-authoring boilerplate from scratch; the VS Code extension exposes the same flow as a command (see **Added (Extension)**). No action required unless you are building a meta-plugin, in which case use the command or flag and follow `doc/guides/composite_analyzer_plugin.md`.
- The repo now includes **`saropa_lints_api`** (`packages/saropa_lints_api/`), a thin re-export of `registerSaropaLintRules` and the Saropa YAML loaders for composite plugins that prefer a small dependency surface. No action required unless you maintain a meta-plugin, in which case you may depend on `saropa_lints_api` instead of importing `saropa_lints` directly.

### Added (Extension)

- **Saropa Lints: Create Composite Analyzer Plugin (scaffold)** is available from the command palette and from **Saropa Lints → Config** (sidebar), prompting for a workspace-relative output folder and running the same scaffold as `dart run saropa_lints:init --emit-composite-plugin-scaffold`, so composite meta-plugins do not require CLI-only setup. No action required unless you are building a meta-plugin, in which case use the command and follow `doc/guides/composite_analyzer_plugin.md`.

### Changed

- Cross-file `unused-symbols` now uses the Dart analyzer to resolve references (with automatic fallback to the prior regex heuristic if resolution fails), so type annotations and constructor type names count as real uses instead of being misreported as unused. No action required unless you need the old behavior, in which case pass the heuristic-only flag shown in `dart run saropa_lints:cross_file --help`.
- Extension UX now promotes a dedicated **Config Dashboard** plus **Triage** naming, default-on Dashboard/Package Vibrancy sidebar sections, and direct open commands, so users can reach configuration and dependency-health surfaces without hunting through tree views. No action required.
- Config Dashboard rule-pack UX now includes staged SDK rollout controls (all, breaking-only, deprecation-only), risk-first SDK grouping/badges, and a confirmation prompt before bulk enablement, so teams can adopt migration packs incrementally with less accidental churn in `analysis_options.yaml`. No action required beyond using the new SDK rollout actions.
- Violations grouping now includes `Rule Type` and `Rule Status` in addition to Severity/File/Impact/Rule/OWASP, so teams can pivot directly by semantic class and lifecycle state during triage. No action required.
- Rule-pack config parsing now tolerates quoted ids, inline comments, and spacing variations while preserving legacy `migration_packs` read compatibility and normalizing writes to canonical `rule_packs`, so mixed/older configs keep working and converge automatically; if your config still uses `migration_packs`, run init or toggle any Rule Pack once to rewrite it. No action required for already-canonical `rule_packs` setups.
- Rule-pack ownership is now authoritative over tiers: **every** rule code assigned to any registered rule pack (library packs such as Bloc/Dio/Firebase, SDK-gated migration packs, and similar) is subtracted from tier-derived enables first, then only re-enabled when its pack is listed under `plugins.saropa_lints.rule_packs.enabled`, so pack toggles control those diagnostics instead of tier defaults alone. Action required if you relied on tier-only activation for any pack-listed rule—enable the corresponding packs to restore those lints.
- Package Vibrancy now surfaces a dedicated Activity grade (A-F) based on both recent commits and release cadence across table, hover, and detail surfaces, so users can distinguish "quiet but active" packages from genuinely dormant ones at a glance; review Activity badges and dormancy hints in the report when triaging dependencies. No action required.
- Suppression tracking now surfaces as a dedicated extension sidebar section with by-kind/by-rule/by-file drilldown, includes suppression-rate context in Overview, and is reflected in export/governance outputs so teams can audit ignored diagnostics without custom tooling. No action required unless you consume report exports, in which case `summary.suppressions` is now documented for CI use.

### Fixed

- `avoid_money_arithmetic_on_double` no longer treats standalone `rate` as a money word (so bare `*Rate` suffixes such as `frameRate`/`sampleRate`/`heartRate` are not financial intent by themselves), while expressions that pair a money-named operand with a `*Rate` factor—e.g. `amount * taxRate`—still trigger because identifiers like `amount`/`tax` match the financial heuristics. No action required.
- `prefer_skeleton_over_spinner` no longer reports determinate `CircularProgressIndicator`/`LinearProgressIndicator` usage (`value` named argument present and not `null`) inside conditional UI branches, so real progress meters are not mislabeled as loading placeholders; indeterminate indicators in `if` / ternary / collection-`if` branches continue to be reported (spinners not under those constructs are out of scope for this rule). No action required.
- `prefer_layout_builder_for_constraints` now skips `MediaQuery` size reads in non-build scopes (for example lifecycle/setup methods and callbacks without a `BuildContext` parameter), which removes false positives where `LayoutBuilder` cannot be applied while still reporting build-phase and builder-callback sizing misuse. No action required.
- `prefer_single_ticker_provider_state_mixin` now skips State classes that hand off `vsync: this` to external helpers, which prevents unsafe suggestions to downgrade to `SingleTickerProviderStateMixin` when multiple ticker consumers exist. No action required.
- Rule execution profiling now records actual callback timing and exposes a stable JSON contract (`ruleName`, `totalMs`, `callCount`, `avgMs`) through `RuleTimingTracker.summaryJson`, so CI can detect performance regressions without parsing human-formatted logs. No action required unless you are consuming timing data, in which case switch to the JSON payload.
- Diagnostic statistics now support per-rule threshold gates and baseline-diff reporting in both the analysis report and `violations.json`, so CI can fail on targeted rule regressions and track newly introduced violations without custom parsers. To adopt this workflow, generate a baseline with `dart run saropa_lints:diagnostic_baseline` and reference it under `diagnostic_statistics.baseline.file` in `analysis_options_custom.yaml`.
- Project Vibrancy scoring tolerates missing or unreadable LCOV (empty coverage), missing or non-object on-disk vibrancy cache JSON (with short **stderr** diagnostics instead of crashing), and git subprocess failures per path (`git log` timestamps, `git blame` ages, `git hash-object` blob keys degrade to null/empty data rather than aborting the scan). No action required.

<details>
<summary>Maintenance</summary>

- Discussion #59 (custom suppression prefixes) is now explicitly deferred as policy-blocked in its discussion document, so contributors do not accidentally implement plugin-side custom ignore parsing under current project policy. No action required for package users.
- Added a dedicated `diagnostic-baseline-strict` GitHub Actions workflow for maintainers to fail fast when `violations.json` is missing before baseline refresh, so strict baseline regeneration can be run independently without changing default CI behavior. No action required for package users.
- Added a dedicated Project Vibrancy GitHub Actions workflow that emits a JSON artifact on pull requests that touch Project Vibrancy sources (see workflow `paths:` filters) and on `workflow_dispatch` manual runs, so maintainers can inspect code-health snapshots from CI without running the CLI locally. No action required for package users.
- Added sidebar UI-state regression checks for Project Vibrancy scope badge/count and persisted filter wiring, so future extension refactors are less likely to silently break the primary filtering flow. No action required for package users.
- Removed many tautological `isNotNull` expectations on guaranteed-non-null rule metadata strings in package tests (CI already enforces stub integrity), preserving rule instantiation, fixture checks, and substantive assertions such as fix metadata and AST-backed tests. No action required for pub.dev or Marketplace users.

</details>

---

## [12.6.1]

More rules now ship IDE quick fixes for repetitive, low-risk edits (secure URL schemes, image and HTTP/Firestore/Drift call shapes), so you can apply the suggested remediation from the lightbulb menu instead of typing boilerplate by hand. Update the package and re-analyze to see new fix actions where diagnostics already appear. [log](https://github.com/saropa/saropa_lints/blob/v12.6.1/CHANGELOG.md)

### Added

- `require_image_error_builder`, `require_image_dimensions`, `require_placeholder_for_network`, `require_https_over_http`, and `require_wss_over_ws` gain quick fixes that insert a minimal `errorBuilder`, placeholder `width`/`height`, a loading/placeholder callback, or rewrite `http://` / `ws://` prefixes where the rule already fires, so common widget and URL hygiene fixes are one action in the IDE. No action required beyond updating and using the fix when offered; adjust inserted dimensions to your layout.
- `require_websocket_error_handling` gains a quick fix that appends a stub `onError` argument to flagged `listen` calls so you can fill in logging or reconnection logic without retyping the signature. No action required beyond updating and using the fix when offered.
- `incorrect_firebase_parameter_name` offers a quick fix that rewrites hyphenated Analytics parameter keys to underscores when that alone satisfies Firebase’s naming rules, so common `item-id` style keys become `item_id` in one step. No action required beyond updating and using the fix when offered; reserved-prefix violations still need a manual rename.
- `avoid_firestore_unbounded_query` offers a quick fix that inserts `limit(100).` before `.get` / `.snapshots` on flagged collection chains so you can cap reads without manually editing the method chain. Review the chosen limit for your product before shipping. No action required to adopt beyond the package update.
- `prefer_timeout_on_requests` and `require_request_timeout` offer quick fixes that append `.timeout(const Duration(seconds: 30))` after the flagged HTTP client call when the rule applies, matching the documented remediation pattern. Tune the duration in code if 30 seconds is not right for your endpoints. No action required beyond updating and using the fix when offered.
- `avoid_drift_enum_index_reorder` offers a quick fix that renames `intEnum` to `textEnum` on flagged Drift column builders so you can switch to name-backed enum storage in one step; you must still migrate existing stored ordinals and adjust related `TypeConverter` code the rule flags separately. No action required beyond updating and using the fix when offered.

---

## [12.6.0]

New recommended-tier migrations cover Flutter scrollbar theme lookup and several Dart 3.2 `dart:js_interop` signature changes. The interop rules only fire when the real SDK library is resolved, so local types or extensions that reuse the same names should stay quiet, and outdated `.toDart` chains are still caught when the bool result is cast through dynamic first. [log](https://github.com/saropa/saropa_lints/blob/v12.6.0/CHANGELOG.md)

### Added

- `prefer_scrollbar_theme_of` guides `ScrollbarTheme.of(context)` instead of `Theme.of(context).scrollbarTheme` so inherited scrollbar themes are not skipped. No action required until you enable or adopt the recommended tier.
- `avoid_legacy_jsboolean_return_assumptions`, `prefer_string_for_typeof_equals`, and `prefer_int_for_jsarray_with_length` target Dart 3.2 `dart:js_interop` changes around `typeofEquals`, `instanceof`, and `JSArray.withLength`. No action required until you enable or adopt the recommended tier.

### Fixed

- `avoid_legacy_jsboolean_return_assumptions`, `prefer_string_for_typeof_equals`, and `prefer_int_for_jsarray_with_length` no longer treat unresolved elements or same-named user declarations as `dart:js_interop`, which removes false positives in mock-heavy code while keeping real interop call sites covered. No action required.

---

## [12.5.4]

This release tightens a noisy repeated-map-lookup lint that could still report in code where extraction was not actually appropriate. The rule now stays out of assignment/update patterns and avoids conflating similarly named variables across different scopes when type resolution is ambiguous. If you were seeing stubborn false positives in loop-heavy or shadowed-variable code, those should now be gone. [log](https://github.com/saropa/saropa_lints/blob/v12.5.4/CHANGELOG.md)

### Fixed

- `prefer_extracting_repeated_map_lookup` now hard-skips write contexts (`[]=`, compound assignment, and increment/decrement), only buckets map-like targets with resolved elements, and refuses unresolved target bucketing, which prevents lingering false positives in shadowed/sibling scopes and mixed read+write loops that users could not safely "extract" anyway. No action required.
- Diagnostics from the same rule at the same file offset are now deduplicated in reporter emission paths, which reduces duplicate warnings when multiple AST callbacks converge on one location while preserving distinct reports at different offsets or from different rules. No action required.

---

## [12.5.3]

This release focuses on reducing high-noise false positives in common Flutter patterns so teams can keep strict lint settings enabled without fighting the tool. Several rules now better distinguish real risks from valid callback, const-context, lifecycle, and helper-ownership code. You should see cleaner results in existing codebases with fewer diagnostics that require no meaningful code change. [log](https://github.com/saropa/saropa_lints/blob/v12.5.3/CHANGELOG.md)

### Fixed

- `avoid_setstate_in_build` no longer fires on `setState` calls inside event-handler closures (`onTap:`, `onPressed:`, `onChanged:`, `Future.then`, etc.) passed during `build()`, since those closures are stored as callbacks and invoked later — not synchronously during the build pass. The visitor now skips `FunctionExpression` subtrees, eliminating the structural false positive while still catching genuine inline `setState` calls in `build()`. No action required.
- `avoid_opacity_animation` no longer fires on an `Opacity` widget whose `opacity:` argument is a constant numeric literal, even when it sits inside an `AnimatedBuilder` that drives a sibling property (icon swap, color, layout). A constant value cannot animate, so the rebuild cost the rule targets does not exist; replacing it with `FadeTransition` would introduce flicker. Genuine animation-driven opacity expressions still warn. No action required.
- `prefer_const_literals_to_create_immutables` no longer fires on collection literals whose enclosing constructor is already `const` (explicitly or via const context). The Dart language auto-promotes inner literals in that case, so adding an explicit `const` would be redundant and trigger the standard analyzer's `unnecessary_const` — leaving the user with no valid resolution. Genuine cases (non-const parent with all-const elements) still warn. No action required.
- `require_database_close` no longer fires on opener helpers whose lifetime is owned by their caller — methods named `init*` / `_init*` / `open*` / `_open*` / `setup*` / `_setup*` that return `Future<bool>` / `Future<void>` / `bool` / `void`. A success-flag return signals the helper hands control back to a caller that closes in `try { … } finally { close(); }`, the standard pattern for background-isolate / WorkManager / migration setup. Methods returning a connection (`Future<Database>` etc.) still warn because the return type transfers ownership. No action required.
- `prefer_extracting_repeated_map_lookup` no longer fires on assignment targets (`map[key] = value`, `map[k] += 1`) — those cannot be hoisted into a local since the `[]=` operation must remain on the map. The rule also stops conflating same-spelled variables in different scopes: `cache[uuid]` written inside three sequential `for` loops, each declaring its own `uuid`, is three independent lookups and is no longer flagged. Bucketing now uses the resolved `Element` for variable keys instead of source text. No action required.
- `require_clipboard_paste_validation` no longer fires on reusable paste helpers that hand the pasted string to a callback parameter (`callback.call(text)`, `onPaste?.call(text)`, `(callback)(text)`) — those helpers have no semantic context to validate against, so the security boundary lives at the caller, not the paste site. Genuine cases (clipboard text written directly into a field with no validation regex nearby and no callback dispatch) still warn. No action required.
- `use_setstate_synchronously` no longer fires on a `setState` that lexically precedes the first `await`, even when both calls live inside a single compound statement (`try`, `if`, `for`, `switch`). Previously the rule iterated only top-level statements, so any descendant `await` made every `setState` in the same enclosing block look post-await — which broke every codebase that wraps method bodies in mandatory `try { … } on Object catch (e, st) { … }` blocks. The walker now tracks await position and `if (!mounted) return;` guard scope in source order across nested blocks. No action required.

<details>
<summary>Maintenance</summary>

- Archived the resolved `avoid_opacity_animation` constant-opacity false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.

</details>

---

## [12.5.2]

This release is a quality pass aimed at precision: fewer accidental matches, fewer environment-related false alarms, and better handling of real-world project layouts. Notification, animation, platform-import, and permission checks now behave more predictably in production-style code. Most users only need to update and re-run analysis to get quieter, more actionable output. [log](https://github.com/saropa/saropa_lints/blob/v12.5.2/CHANGELOG.md)

### Fixed

- `require_intl_plural_rules` now treats comparisons to the integer literal **1** only when that digit is not part of a longer numeral, so helpers that branch on values like 12 or 100 (12-hour labels, build bands, and similar) are not misclassified as manual plural logic. No action required.
- Long-task name matching for the `dbProcessAll…` skip now uses bounded character checks instead of `substring`, so the package’s own `dart analyze --fatal-infos` run stays clean under `avoid_string_substring`. No action required.
- `avoid_excessive_rebuilds_animation` now only considers `AnimatedBuilder` and `ListenableBuilder` when the listenable resolves to an `Animation` subtype, so `FutureBuilder`, `StreamBuilder`, `ValueListenableBuilder`, and non-animation listenables no longer get a misleading “every frame” warning. No action required.
- `require_notification_for_long_tasks` now matches long-operation tokens on camelCase boundaries (so names like `ImportAllowed` no longer hit `importAll`), skips `dbProcessAll…` DB helpers, skips the whole file when common in-app progress or notification-plugin strings appear, and splits example fixtures so BAD cases are not suppressed by GOOD escape hatches in the same file. No action required.
- Rules that read `Info.plist` through the shared helper now re-read when the file’s size or modification time changes, match keys with whitespace-tolerant XML checks, and normalize analyzer `file:` URIs to OS paths, so `require_image_picker_permission_ios` no longer false-positives once `NSCameraUsageDescription` is present. No action required.
- `require_image_picker_permission_android` now reads `AndroidManifest.xml` like the iOS camera rule reads `Info.plist`, so it stays silent when `android.permission.CAMERA` is already declared; it also covers `pickVideo` as well as `pickImage` for `ImageSource.camera`. No action required.
- `avoid_platform_specific_imports` and sibling rules that consult `ProjectContext.hasWebSupport` now run that check while visiting each library, so Flutter projects without a root `web/` directory are correctly treated as non-web and `dart:io` imports stop false-alarming there; pure Dart packages still get web-portability warnings by default. No action required.
- `prefer_layout_builder_for_constraints` no longer double-reports on `MediaQuery.of(context).size.width` / `.height`, skips intentional screen fractions and numeric breakpoint comparisons, documents when `MediaQuery` sizing is appropriate, and treats `MediaQuery.sizeOf(context).width` / `.height` like the `.of().size.*` pattern. No action required.

<details>
<summary>Maintenance</summary>

- Archived the closed `require_notification_for_long_tasks` foreground false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.
- Archived the resolved `avoid_excessive_rebuilds_animation` false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.
- Archived the resolved `prefer_layout_builder_for_constraints` false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.

</details>

---

## [12.5.1]

This release cleans up disposal and accessibility false positives that were noisy in mature widget codebases and design-system wrapper layers. The fixes improve confidence that warnings point to real leaks or UX issues instead of valid cleanup and companion-indicator patterns. If these lints were previously too chatty in your project, this update should be noticeably calmer. [log](https://github.com/saropa/saropa_lints/blob/v12.5.1/CHANGELOG.md)

### Fixed

- **`require_change_notifier_dispose` false positive**: The rule no longer flags owned notifier fields when disposal runs on a local initialized from the field (for example capturing a nullable controller before `dispose()`). No action required.
- `require_scroll_controller_dispose` and `require_focus_node_dispose` now treat disposal through a local copy of the field, disposal only in `didUpdateWidget`, and disposal inside private helpers called from `dispose` or `didUpdateWidget` as valid cleanup, so the common nullable-controller pattern no longer reports a leak when the controller is actually released. No action required.
- `avoid_color_only_meaning` now treats `Checkbox`/`Switch`/`Radio` (including `*ListTile` variants) as companion state indicators, so selection rows with conditional background color are not incorrectly reported as color-only meaning. No action required.
- `avoid_color_only_meaning` now recognizes common design-system widget names built as a short prefix plus a known companion type (for example thin `Icon`/`Text` wrappers), so conditional surface color next to an icon swap or label in those widgets is not treated as color-only meaning when the remainder matches a real companion. No action required.

<details>
<summary>Maintenance</summary>

- Archived the closed `avoid_color_only_meaning` design-system wrapper companion false-positive report under `plan/history/2026.04/2026.04.25/` and removed it from `bugs/`. No action required for package users.
- The publish script’s combined coverage report now treats `repo_integrity` rules as using the shared `config` example fixtures, matching where those files already live. Additional validated example fixtures cover stylistic null-and-collection rules, stylistic whitespace and constructor preferences, and `prefer_semantics_sort`, with matching mock types for analysis. No action required for package users.

</details>

---

## [12.5.0]

New rules help you catch missing Android permissions, missing iOS privacy strings, desktop window setup, and gaps around background audio and location, notifications, Firestore rules, and secrets on disk before they bite at review or runtime. A couple of noisy false positives in internationalization and iOS camera permission checks are gone, and the cross-file CLI can warn when library code has no matching test file. [log](https://github.com/saropa/saropa_lints/blob/v12.5.0/CHANGELOG.md)

### Fixed

- `avoid_builder_index_out_of_bounds` now treats `idx`, `realIndex`, and `itemIndex` inside bracket lookups like the existing `index`/`i` handling, so Carousel-style and similar builder callbacks get the same bounds heuristics. No action required unless you relied on the blind spot; add guards where the rule now applies.
- The same rule’s DartDoc now states that each list subscripted with the builder index needs its own visible bound or matching item count when lengths are not provable from the source. No action required.
- `require_intl_plural_rules` no longer treats code between string literals (for example `(hour == …)` next to AM/PM labels) as if it were text inside a quoted string, so 12-hour clock helpers are not mistaken for manual noun pluralization. No action required.
- `require_image_picker_permission_ios` now reads `ios/Runner/Info.plist` through the shared plist checker so it does not warn when `NSCameraUsageDescription` is already present. No action required.

### Added

- Added `require_android_manifest_entries` to flag permission-gated Android API usage when the app manifest is missing required `android.permission.*` entries, so runtime-denied features are caught during analysis instead of on devices. Add the missing `<uses-permission>` rows in `android/app/src/main/AndroidManifest.xml` where reported.
- Added `require_ios_info_plist_entries` to report permission-gated iOS API usage when required `NS*UsageDescription` keys are absent from `Info.plist`, so App Store rejection and runtime permission crashes are caught during analysis. Add the missing key(s) to `ios/Runner/Info.plist` where reported.
- Added `require_desktop_window_setup` to report desktop window-manager API usage when desktop runner setup files are missing, so desktop-only configuration gaps are surfaced before runtime. Ensure the relevant `windows/`, `linux/`, or `macos/` runner files are present when using desktop window APIs.
- Added `avoid_audio_in_background_without_config` to flag background audio usage when iOS `UIBackgroundModes` audio or Android manifest foreground-service / audio declarations are missing, so store review and runtime failures are caught during analysis.
- Added `avoid_geolocator_background_without_config` to flag `Geolocator.getPositionStream` when iOS background location or Android background location permission is not reflected in platform config files.
- Added `require_notification_icon_kept` to warn when FCM or local notifications are used but ProGuard/R8 rules do not appear to keep notification icon resources.
- Added `require_firestore_security_rules` to report `FirebaseFirestore` usage when no `firestore.rules` file exists at the project root.
- Added `require_env_file_gitignore` to report `.env` / `.env.*` files at the project root that are not covered by `.gitignore` patterns.
- Extended `dart run saropa_lints:cross_file` with **missing mirror test** detection: each `lib/**/*.dart` (except `main.dart`, generated-style names, and `lib/generated/`) is checked for a matching `test/**/*_test.dart`; results appear in text/JSON output, HTML report, baselines (format version 2), and non-zero exit when present.

<details>
<summary>Maintenance</summary>

- Archived closed `avoid_builder_index_out_of_bounds` false-positive investigation under `plan/history/2026.04/2026.04.25/` (removed duplicate from `bugs/`). No action required for package users.
- Closed false-positive report for `require_image_picker_permission_ios` (existing `NSCameraUsageDescription`) under `plan/history/2026.04/2026.04.25/`. No action required for package users.

</details>

---

## [12.4.4]

`require_animation_controller_dispose` stops nagging when you really did tear down an `AnimationController` using a disposeSafe-style helper next to `dispose`, and the help text you read in the editor now matches what the linter reports. Rule counts and Marketplace-facing copy line up across the package and extension, publish and audit flows are a little sturdier, and you do not need new analysis_options toggles to pick any of this up. [log](https://github.com/saropa/saropa_lints/blob/v12.4.4/CHANGELOG.md)

### Fixed

- `require_animation_controller_dispose` now treats `disposeSafe(…)` like `dispose(…)` in your `State.dispose()` so custom safe-dispose extensions are not reported, and the rule message was refreshed so on-screen wording stays aligned with that behavior. No action required; remove suppression comments you added only for this false positive.

<details>
<summary>Maintenance</summary>

- Deferred SDK plan notes consolidated under `plan/deferred/`; publish audit spelling prompt now retry/ignore; publish menu shows logo first; Windows temp-dir teardown hardened in one integration test. No action required for package users.
- Rounded rule-count messaging is aligned to **2100+** / **~2100** everywhere (pub.dev description, extension listings, walkthrough, tier headers, and guides) so numbers match the current rule set. No action required.
- Extension publish still tries Open VSX after a failed VS Code Marketplace upload, so the Open VSX listing can move forward when Marketplace auth fails but your Open VSX token is fine. No action required for package users.
- Publish work-report “unsolved bug” count excludes the bug-filing guide at repo root so only real open bug files inflate that bar. No action required for package users.
- Clarified internal helper documentation for `isFieldCleanedUp` so extension method names are not implied by a generic `dispose` check. No action required for package users.
- Dropped placeholder-only example rule fixtures and matching fixture-existence test entries so the suite does not imply behavioral coverage for unfilled TODO stubs. No action required for package users.
- Follow-up removed additional stylistic and related stub fixtures, added migration and SDK-migration batch fixtures with shared mocks, and expanded unit tests for compile-time syntax and image filter tier metadata. No action required for package users.
- Internal doc comment reference style, plan notes, extension copy, script helpers, and archive indexing were updated. No action required for package users.

</details>

---

## [12.4.2]

`saropa_depend_on_referenced_packages` is removed because the Dart SDK already ships the same check via `lints` / `flutter_lints`, and saropa’s copy kept false-positiveing on legitimate imports. You still get the behavior from the SDK; nothing breaks if you leave old config in place. [log](https://github.com/saropa/saropa_lints/blob/v12.4.2/CHANGELOG.md)

### Removed

- Removed `saropa_depend_on_referenced_packages` so duplicate / noisy import checks go away while the SDK lint keeps the same coverage for you. No action required; delete any `saropa_depend_on_referenced_packages` entry from `analysis_options.yaml` when you tidy config.

<details><summary>Maintenance</summary>

- Publish script: extension-only and publish-existing-.vsix modes now run the same Marketplace + Open VSX verification as the full flow so a “successful” store publish cannot slip through undetected. No action required for package or rule users.

</details>

---

## [12.4.1]

Analysis reports and the Run Analysis popup now show which saropa_lints build ran, and the popup can copy or open the latest consolidated report without digging through folders. Theme- and platform-driven color branches no longer trip `avoid_color_only_meaning`, and `prefer_final_locals` stops suggesting `final` where the variable is reassigned inside nested blocks or closures. [log](https://github.com/saropa/saropa_lints/blob/v12.4.1/CHANGELOG.md)

### Added

- Run Analysis popup adds Copy Report and Open Report (plus palette commands) so you can share or open the latest `*_saropa_lint_report.log` in one step instead of browsing dated folders under `reports/`. No action required.

### Changed

- Extension Run Analysis stamps extension reports and the issue popup with the resolved saropa_lints version and source (hosted / path / git) when `pubspec.lock` allows, so you can confirm which build ran without opening files. No action required.

### Fixed

- `prefer_final_locals` no longer false-positives when a local is reassigned inside nested blocks, control flow, or closures, so the quick fix matches real code and you can rely on the rule again. No action required; details in [bugs/prefer_final_locals_false_positive_nested_assignments.md](bugs/prefer_final_locals_false_positive_nested_assignments.md).
- `avoid_color_only_meaning` skips ordinary theme, platform, and directionality-driven color branches so theming code stays clean without ignores. No action required; details in [bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md](bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md).
- Analyzer-plugin text reports now show a real `Version:` from your project root instead of `unknown`, so each report identifies the plugin build that produced it. No action required.

---

## [12.4.0] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 12.4.0.


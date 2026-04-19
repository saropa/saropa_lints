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

    Each release (and [Unreleased]) opens with one plain-language line for humans—user-facing only, casual wording—then end it with:
    [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)
    substituting X.Y.Z.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

    **CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

    **Score** — [pub.dev/packages/saropa_lints/score](https://pub.dev/packages/saropa_lints/score)

-->

---

## [Unreleased]

Letter-only grading for package vibrancy across the report and detail views, plus a new "true footprint" view that links shared dependency size into per-package cost.

### Added

- **Extension:** Footprint-mode toggle (Own / + Unique / + All) in the vibrancy report toolbar — switches what the Size column shows: the package's own archive (default), own + transitives used only by this dep (the size you'd save by removing it), or own + all transitives including ones shared with other direct deps. Sorting by Size respects the active mode.
- **Extension:** "True Footprint" row in the package detail panel — for any direct dep with transitives, surfaces the breakdown as `unique &middot; +shared = total` with a tooltip explaining how much disappears if you remove the dep vs. how much stays pulled in by other deps. Lets you spot cases like `crop_your_image` where the bulk of the size comes from a shared `image` transitive.
- **Extension:** `TransitiveInfo.uniqueTransitiveSizeBytes` and `sharedTransitiveSizeBytes` fields, computed in `enrichTransitiveInfo` from the per-package archive sizes already gathered during scan.
- **Extension:** Re-export awareness throughout the vibrancy report. Each `PackageUsage` now carries an `isExport: boolean` flag. The Single-use summary card excludes packages whose only reference is a `export 'package:...'` directive (they're public-API surface, not removable). The detail panel tags individual re-export lines with a "re-export" badge and a "public API surface" header note. The report row's References cell shows a "↪" badge after the count and prepends a warning to its tooltip when re-exported, and the muted single-use styling no longer applies to re-exports. `hasActiveReExport()` helper exposed alongside `activeFileUsages()`.

### Fixed

- **Extension:** Vibrancy report column headers no longer wrap to two lines when many optional columns are visible. Headers, right-aligned numeric cells, and the footprint-mode toggle buttons now use `white-space: nowrap` so each value stays on a single line.
- **Extension:** Vibrancy report version-age suffix no longer shows `(new)` for packages published within the last month. The label was misleading (a recently published version of a mature package isn't "new") and didn't carry useful information, so the suffix is now omitted entirely under one month.

### Changed

- **Extension:** Vibrancy report Category column now shows the letter grade badge only — the category label ("Vibrant", "Stable", etc.) and the dimmed `(n/10)` suffix were removed. Full label and score breakdown remain available via the hover tooltip.
- **Extension:** Report summary filter cards (Vibrant/Stable/Outdated/Abandoned/End-of-Life) now display the grade letter (A/B/C/E/F) as their label. The full category name moved to a `title` tooltip on each card.
- **Extension:** Report average-score summary card renamed to "Project Package Grade" and now shows a single letter derived from the average vibrancy score, replacing the old `n/10` value.
- **Extension:** Radial gauge in the report header now displays the project package grade letter instead of the `n` / `/10` stack. Tooltip label updated to "Project Package Grade".
- **Extension:** Sidebar detail view header replaced the `n/10` score pill plus standalone category-badge with a single letter pill. Category name is surfaced via the pill's `title` tooltip.
- **Extension:** Package detail panel header badge (top-right) now shows the letter grade only; the `n/10` score and inline category label were dropped (label moved to the title tooltip).
- **Extension:** Expanded row "Health Score" detail card dropped the redundant "Overall" numeric row — the aggregate is already shown as the letter badge in the card header; the factor rows (Resolution Velocity, Engagement Level, Popularity, Publisher Trust) remain.
- **Extension:** Health breakdown tooltip (shown on hover over a row's grade cell) now leads with "Grade: X" instead of "Vibrancy Score: n/10". Factor rows unchanged.
- **Extension:** CodeLens titles changed from "emoji n/10 Label" to "emoji X" (letter). The `indicatorStyle: text` variant now shows only the text indicator since a letter next to the text label was redundant; `indicatorStyle: none` shows the letter alone.
- **Extension:** pubspec hover tooltips show "**X** Category" (letter + label) in place of "**n/10** Category". Alternatives list shows "(X)" per alt (letter derived from the alt's score via `scoreToGrade`).
- **Extension:** Diagnostic messages trail with "(X)" (grade letter) instead of "(n/10)". Applies to Review/Monitor/Deprecated verbs and to blocker annotations.
- **Extension:** Vibrancy tree view blocker row switched from "score (category)" to a single letter grade. Alternatives group shows "(X)" per suggestion.
- **Extension:** Package comparison view row renamed "Vibrancy Score" → "Vibrancy Grade"; cell displays the letter derived from the 0-100 score (ranking still uses the numeric score so ordering stays precise).
- **Extension:** Markdown report export renamed the "Score" column to "Grade" and displays the letter. The JSON sibling preserves the numeric `health.score` field unchanged so downstream automation keeps working.
- **Extension:** Budget-exceeded message for the `minAverageVibrancy` rule now reads "Project Package Grade X is below minimum Y" instead of showing `n/10` actual vs limit.
- **Extension:** DetailLogger output channel prints "name — X (Category)" and "Blocker grade: X" instead of `n/10` forms.
- **Extension:** New `scoreToGrade(score)` helper in `category-dictionary.ts`, re-exported from `status-classifier`, providing a single source of truth for score-to-letter thresholds used by the gauge, summary card, alternatives, comparison view, and budget messages.

---

## [12.1.0]

### Added

- **Extension:** Report renamed from "Package Vibrancy Report" to "Saropa Package Vibrancy" with the extension version shown as dimmed text next to the title.
- **Extension:** Animated radial gauge in the report header (floating top-right) showing the overall project health score on a color-coded 270-degree arc that fills on load.
- **Extension:** Letter grade badges (A through F) in the Category column, synced with the extension's category dictionary (A=Vibrant, B=Stable, C=Outdated, E=Abandoned, F=End-of-Life). Displayed as color-coded pill badges alongside the category label.
- **Extension:** Expandable detail cards — click any row (or press Enter with keyboard focus) to reveal an inline card with score breakdown, vulnerability list, file references, transitive dependency cloud, and external links. Collapse with a second click or Escape.
- **Extension:** Keyboard navigation in the report table — arrow keys (or j/k) move a visible focus highlight between rows, Enter/Space toggles expansion, Escape collapses all.
- **Extension:** New "Deps" column showing transitive dependency count per package with a tree icon. Shared dependencies are highlighted with a badge, and a tooltip lists all transitives with shared ones marked.
- **Extension:** Detail card dependency cloud highlights shared transitive deps in bold with a "shared" badge, so blast-radius of package removal is immediately visible.

### Fixed

- **Extension:** Radial gauge grade thresholds now match the category classifier boundaries (>=70 Vibrant/A, >=40 Stable/B, >=20 Outdated/C, <20 Abandoned/E) instead of diverging display-score thresholds.
- **Extension:** Table sorting now keeps detail rows paired with their parent package row. Previously, sorting would break the pairing and cluster orphaned detail rows together.
- **Extension:** Table filtering now correctly hides detail rows when their parent row is filtered out, preventing orphaned expanded cards from remaining visible.

---

## [12.0.3]

### Fixed

- **Extension:** Upgrade plan no longer includes git, path, or SDK dependencies that cannot be upgraded via version constraint bump. Previously these would appear in the plan and immediately fail with an unhelpful "pub get failed" message.
- **Extension:** Upgrade report now shows the actual error reason (e.g. version conflict details) instead of just "pub get failed" or "flutter test failed".
- **Extension:** Upgrade plan continues to the next package after a step failure instead of halting the entire plan. Each failed step rolls back independently so subsequent packages still get attempted.

---

## [12.0.2]

### Added

- **Extension:** Size Distribution chart now separates transitive dependencies into distinct "Unique transitives" and "Shared transitives" segments instead of burying them in a single "Other" bucket. Unique transitives are the real cost of adding a package — shared transitives are already pulled in by other direct deps. A new "Exclude shared" checkbox hides shared transitive segments from both charts and the table, recalculating percentages for the remaining packages. This makes inflated size reports (e.g. a 63 MB package whose weight is entirely from a dep you already carry) immediately visible.
- **Extension:** Report renamed from "Package Vibrancy Report" to "Saropa Package Vibrancy" with the extension version shown as dimmed text next to the title.
- **Extension:** Animated radial gauge in the report header (floating top-right) showing the overall project health score on a color-coded 270-degree arc that fills on load.
- **Extension:** Letter grade badges (A through F) in the Category column, synced with the extension's category dictionary (A=Vibrant, B=Stable, C=Outdated, E=Abandoned, F=End-of-Life). Displayed as color-coded pill badges alongside the category label.
- **Extension:** Expandable detail cards — click any row (or press Enter with keyboard focus) to reveal an inline card with score breakdown, vulnerability list, file references, transitive dependency cloud, and external links. Collapse with a second click or Escape.
- **Extension:** Keyboard navigation in the report table — arrow keys (or j/k) move a visible focus highlight between rows, Enter/Space toggles expansion, Escape collapses all.
- **Extension:** New "Deps" column showing transitive dependency count per package with a tree icon. Shared dependencies are highlighted with a badge, and a tooltip lists all transitives with shared ones marked.
- **Extension:** Detail card dependency cloud highlights shared transitive deps in bold with a "shared" badge, so blast-radius of package removal is immediately visible.

---

## [12.0.1]

### Changed

- **Extension:** Prominent "Set Up Project" banner at the top of the Overview sidebar when `saropa_lints` is not yet in `pubspec.yaml` — new users no longer have to hunt for the setup action
- **Extension:** Auto-detect notification on activation when a Dart project lacks `saropa_lints`, offering one-click setup directly from the toast

---

## [12.0.0]

Rolled back from analyzer 12 to analyzer 11 — analyzer 12 requires `meta ^1.18.0` but Flutter stable (3.41.6 / Dart 3.11.4) pins `meta` to `1.17.0`, which made saropa_lints `>=10.3.0` unresolvable for every Flutter project on stable. The pub solver would reject the package outright with a `meta` version conflict. This downgrade restores compatibility with Flutter stable while keeping all 2134 rules and 254 quick fixes intact.  — [log](https://github.com/saropa/saropa_lints/blob/v12.0.0/CHANGELOG.md)

### Fixed

- **Critical:** Downgrade `analyzer` from `^12.0.0` to `>=9.0.0 <12.0.0` — analyzer 12 requires `meta ^1.18.0` which conflicts with Flutter stable's pinned `meta 1.17.0`, making saropa_lints unresolvable for all Flutter consumers (see `bugs/infra_meta_pin_flutter_incompatible.md`)
- Downgrade `analyzer_plugin` from `^0.14.7` to `>=0.11.0 <0.14.7` for analyzer 11 compatibility
- Add `ClassBodyMembersCompat` extension to bridge analyzer 11's sealed `ClassBody` (where `.members` is only on `BlockClassBody`, not the base type)


---

## [11.1.0]

Ten new quick fixes — click the lightbulb and let the IDE rewrite `late`, `abstract final`, `unawaited()`, `toString()`, and more for you. — [log](https://github.com/saropa/saropa_lints/blob/v11.1.0/CHANGELOG.md)

### Added

- **Quick fix:** `unnecessary_library_name` — remove the library name, leaving bare `library;`
- **Quick fix:** `avoid_late_for_nullable` — remove the `late` keyword from nullable field/variable declarations
- **Quick fix:** `prefer_late_final` — change `late` to `late final` for single-assignment variables
- **Quick fix:** `prefer_abstract_final_static_class` — add `abstract final` modifiers to static-only classes
- **Quick fix:** `avoid_async_call_in_sync_function` — wrap unhandled Future call with `unawaited()`
- **Quick fix:** `avoid_default_tostring` — generate a `toString()` override listing all instance fields
- **Quick fix:** `missing_use_result_annotation` — add `@useResult` annotation before builder/factory methods
- **Quick fix:** `avoid_unnecessary_local_late` — remove `late` from immediately-initialized local variables
- **Quick fix:** `avoid_unnecessary_late_fields` — remove `late` from constructor-assigned fields
- **Quick fix:** `avoid_positional_boolean_parameters` — convert positional bool parameter to required named

### Changed

- **Quick fix:** `RemoveLateKeywordFix` now handles `VariableDeclarationStatement` nodes (used by `avoid_unnecessary_local_late`)

<details>
<summary>Maintenance</summary>
- **Security:**  Fix CVE in transitive dependency `serialize-javascript` (RCE via RegExp.flags and Date.toISOString) by adding npm `overrides` to pin `>=7.0.5`
</details>

---

## [11.0.0]

A major extension UX upgrade featuring a new searchable command catalog sidebar, embedded health dashboards, rich package details with logos and README images, unique vs. shared dependency breakdowns, and workspace-wide diagnostic suppression tracking. — [log](https://github.com/saropa/saropa_lints/blob/v11.0.0/CHANGELOG.md)

### Added

- **Extension:** Commands sidebar section — a searchable, always-visible index of every extension command as the first sidebar section. Includes recent command history and one-click execution. The full editor-tab catalog remains available via the "Open full catalog" link.
- **Extension:** Overview now embeds Health Summary, Next Steps, and Riskiest Files groups directly — users see violation breakdowns, prioritized actions, and risky files without enabling standalone sidebar sections. Clicking items filters the Violations view. Standalone sections remain available for users who prefer dedicated views.
- **Extension:** Package Details sidebar section now defaults to visible — it only appears when a Vibrancy scan has results (gated by the existing `when` clause), so no clutter for users who haven't scanned.
- **Extension:** Vibrancy scoring now includes an ecosystem adoption bonus based on reverse dependency count — how many published packages on pub.dev depend on a given package. Packages with dependents get a score boost (up to +10 points on a logarithmic curve); packages with zero dependents are unaffected (bonus-only, no penalty). The count is displayed in the Community group of the tree view, sidebar detail, and full detail panel with a clickable link to the pub.dev search results.
- **Extension:** Package detail panel and sidebar now show package description (truncated with "read more" link), topic badges linking to pub.dev topic search, likes count in the Community section, direct dependencies as clickable chips, and a Documentation link to the pub.dev API reference.
- **Extension:** Package detail panel and sidebar now show the package logo (first non-badge image from README) in the header and a README Images gallery section. Both are lazy-loaded from the GitHub API when the detail panel opens. HTTP-only images are filtered out to prevent silent CSP failures.
- **Extension:** Package detail and sidebar CSP updated to allow HTTPS images for logo and README screenshots.
- **Plugin:** Suppression tracking — every diagnostic silenced by `// ignore:`, `// ignore_for_file:`, or baseline is now recorded as a full `SuppressionRecord` (rule, file, line, kind). Records are included in batch data for cross-isolate merging, deduplicated with normalized paths, and exported in `violations.json` with `byKind`, `byRule`, and `byFile` breakdowns. Counts appear in the console summary log and the extension Overview tree. Foundation for Discussion #56 suppression audit trail.

### Changed

- **Extension:** Size Distribution chart in the vibrancy report now has an "Include transitives" checkbox. Unchecking it hides transitive packages from both the bar chart and donut chart, recalculating percentages for direct dependencies only. Helps identify whether a package's apparent size is real or inflated by shared transitive weight.
- **Extension:** Package Vibrancy tree now shows unique vs shared transitive dependency breakdown in the Dependencies group. Shared transitives are already in the project via other direct deps — only unique transitives represent added weight. Package rows show a compact `N% shared` indicator so misleading size reports (e.g. a 63MB package whose weight is entirely from a dep you already carry) are immediately visible.
- **Extension:** Package detail sidebar webview now includes a Dependencies section with a visual unique/shared bar, counts, and shared dependency names.
- **Extension:** Package Vibrancy tree row inline icons replaced: removed redundant go-to-file icon (row click already navigates) and added Copy as JSON (`$(clippy)`) and Focus Details (`$(preview)`) inline actions.
- **Extension:** File Risk section moved above Violations in the sidebar so it acts as a natural file selector before the detail view.
- **Extension:** File Risk summary replaced the confusing "Top N files have X% of critical issues" label with a flat breakdown: file count, critical, high, and other counts.
- **Extension:** Clicking a file in the File Risk tree now opens the file in the editor (in addition to filtering the Violations view).
- **Extension:** File Risk tree now has a Copy All toolbar button (clipboard icon) for copying the full tree as JSON.
- **Extension:** File Risk file items now have right-click context menu actions: Show Violations for File, Hide File, Copy Path, and Copy as JSON.
- **Extension:** File Risk summary node is now clickable — opens all violations in the Violations view.
- **Extension:** File Risk tree now respects view-level suppressions from the Violations view (hidden folders, files, rules, severities, and impacts).
- **Extension:** File Risk tree shows a "Scanned Xd ago" timestamp node at the bottom. When scan data is older than 24 hours, the node shows a warning icon and clicking it runs analysis to refresh.
- **Extension:** All tree views (Violations, File Risk, Summary, Security Posture, Suggestions) now respect rules disabled in `analysis_options.yaml` (`diagnostics:` section) and `analysis_options_custom.yaml` (`RULE OVERRIDES` section). Violations for disabled rules are automatically hidden even when `violations.json` is stale.
- **Extension:** Right-clicking a violation in the Violations tree now offers "Disable rule(s)" to persistently disable the rule via `analysis_options_custom.yaml`, in addition to the existing view-level "Hide Rule" suppression.
- **Extension:** Package Vibrancy tree items now show the category label in parentheses (e.g. `(Stable)`, `(Outdated)`) instead of the verbose `3/10 — Outdated — 1 problem` format, consistent with the vibrancy report terminology. The full score remains in the hover tooltip and detail views.
- **Extension:** Group node counts now use brackets (e.g. `Dependencies [5]`) instead of parentheses for visual distinction from the grade.
- **Extension:** "Source" node renamed to "Source Code" with a shorter description (e.g. `2.5k lines, 18 files`). Full detail shown in tooltip. Double-clicking opens the package's local source folder.
- **Extension:** Hover tooltip in pubspec.yaml now includes all information from the detail panel — version, community stats, size, file usages, alerts, vulnerabilities, platforms, alternatives, and action items. Footer links include pub.dev, Changelog, Versions, Repository, Open Issues, and Report Issue.
- **Extension:** Links in the package detail panel and sidebar detail view now render as underlined hyperlinks for discoverability. Added direct links to Changelog, Versions, Open Issues, and Report Issue alongside existing pub.dev and Repository links.

### Fixed

- **Extension:** Violations tree file items no longer expand to empty. `getChildren()` re-read `violations.json` on every expansion — if the file was temporarily unavailable (write lock during scan, concurrent rewrite), the early-return guards returned `[]` before reaching the file-item handler. File and group nodes now resolve from their embedded data before any disk read, so already-loaded children survive a transient I/O hiccup.
- **Extension:** Pubspec validation no longer shows duplicate diagnostics on startup. `onDidOpenTextDocument` fires retroactively for already-loaded documents, and the `visibleTextEditors` loop covered them again — deduplicating the initial sync prevents `update()` from running twice for the same file.
- **Extension:** `stale-override` no longer false-positives on overrides that resolve SDK-pinned transitive conflicts (e.g. `meta: 1.18.0` when `flutter_test` pins `1.17.0` but `analyzer ^12` requires `^1.18.0`). The override analyzer now compares the overridden version against the dep-graph resolved version — if they differ, the override is classified as active.


<details>
<summary>Maintenance</summary>

- Consolidated 7 example fixture packages into 2 (`example/` and `example_packages/`). Merged `example_async`, `example_core`, `example_platforms`, `example_style`, and `example_widgets` into the main `example/` directory. Only `example_packages` remains separate (it requires the `bloc` dependency). Reduces pubspec/lockfile/analysis_options maintenance from 7 projects to 2.
</details>

---

## [10.12.2]

Pubspec inline suppression comments, l10n.yaml false-positive fix, and scan logger cleanup. — [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- **Extension:** Inline suppression for pubspec validation rules via `# saropa_lints:ignore <rule_code>[, ...]` comments. Place the directive on the line above (or inline after) a flagged entry to suppress specific diagnostics without disabling the rule globally. All 11 pubspec rules support suppression automatically.

### Fixed

- **Extension:** `prefer_l10n_yaml_config` no longer fires when `l10n.yaml` already exists alongside `pubspec.yaml`. Flutter tooling requires `generate: true` in pubspec even with a dedicated l10n config file — flagging it was a false positive.
- **Extension:** Package Vibrancy scan logger no longer creates a separate log file per scan. Scans are debounced (5 s after last `pubspec.lock` change), logs append to one file per day, and identical-result scans are skipped entirely.

---

## [10.12.1]

Publishing fix — removed stale publish_to field that blocked CI. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.1/CHANGELOG.md)

### Fixed

- **Publishing:** Removed `publish_to: "none"` from pubspec.yaml — the template placeholder blocked `dart pub publish` in CI. The field defaults to pub.dev when absent.

---

## [10.12.0]

False-positive fixes across hardcoded config, dependency ordering, adoption gate, and pubspec diagnostics; plus a help hub, comment-preserving sort, and command catalog refresh. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.0/CHANGELOG.md)

### Fixed

- **`avoid_hardcoded_config` (v5):** No longer reports URL/key-like string literals used as initializers for top-level `const` declarations or `static const` class fields. Those are the usual single-source-of-truth pattern; mutable `static final` / locals still warn.
- **`dependencies_ordering` (extension):** No longer flags SDK dependencies (`flutter`, `flutter_localizations`, `flutter_test`, `integration_test`) as out of alphabetical order when they appear before pub-hosted packages. SDK deps are now exempt from the alphabetical sort; only pub-hosted entries are checked.
- **Adoption Gate (extension):** No longer shows false "Discontinued" badge on SDK dependencies (`flutter`, `flutter_test`, `flutter_localizations`, `integration_test`, etc.). SDK packages are not hosted on pub.dev; looking them up produced misleading warnings because the pub.dev `flutter` placeholder is marked discontinued. Also fixed badge placement: `findPackageLine` now only matches within dependency sections, so badges no longer appear on `environment:` constraint lines.
- **`prefer_publish_to_none` (extension):** No longer flags packages that have `topics:`, `homepage:`, or `repository:` fields — these are pub.dev publication signals, so suggesting `publish_to: none` was a false positive on intentionally published packages.
- **Pubspec diagnostics (extension):** All 11 pubspec.yaml validation messages now include the `[saropa_lints]` prefix, matching the convention used by the Dart-side lint rules.
- **`isLintPluginSource` guard (infra):** The per-file guard that prevents rules from firing on their own source code was broken in the native analyzer model — it ran once at registration time, not per-file. Moved the check into `_shouldSkipCurrentFile()` so it evaluates per-file and removed the 43 dead per-rule guards across 12 rule files. Fixes 8 false positives from `avoid_ios_in_app_browser_for_auth` on its own OAuth URL pattern definitions, plus potential false positives in all other affected rule files.

### Added (Extension)

- **Help hub**: New “Saropa Lints: Help” command (`saropaLints.openHelpHub`) opens a quick pick for Getting Started, About, Browse All Commands, and pub.dev. **Overview** intro links are grouped under a permanent collapsible **Help & resources** tree section; the title bar shows only the Command Catalog icon (help is in the tree). **Violations** always shows a **Help & resources** row at the top when the tree has content, plus both Help and Command Catalog icons in the title bar.

### Fixed (Extension)

- **Pubspec sorter**: Comments that precede a dependency entry (description, changelog URL, version-pin notes) now travel with the entry during sorting instead of being stripped. Trailing decorative comment blocks (section dividers) at the end of a section are also preserved. Previously, running "Sort Dependencies" on a richly commented pubspec would silently delete all comments.

### Changed (Extension)

- **Command catalog**: Sidebar title actions on Overview and Violations open the catalog; Codicons load in the webview; recent command runs are stored for one-click replay with a clear control; UI refresh (hero header, cards, command IDs). **Toolbar trim**: fewer Package Vibrancy and Violations title-bar entries (secondary actions remain in the command palette and catalog). **Context menu**: removed “Log package details” from package rows. **Catalog UX**: categories ordered setup → analysis → violations → rules → security → reporting → vibrancy → …; entries sorted A–Z within each section; search indexes title, description, and command id (including spaced tokens); responsive layout for narrow panes.

<details>
<summary>Maintenance</summary>

- **SDK_PACKAGES (extension):** Consolidated three duplicate `SDK_PACKAGES` sets (annotate-command, unused-detector, pubspec-sorter) into a single shared constant at `sdk-packages.ts`. Added missing `integration_test` and `flutter_driver` entries to the pubspec-sorter set.
</details>

---

## [10.11.0]

New graph command for import visualization, a searchable command catalog in the extension, eleven pubspec validation diagnostics with quick fixes, and a batch of bug fixes. — [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- **cross_file graph command**: New `dart run saropa_lints:cross_file graph` command exports the import graph in DOT format for Graphviz visualization. Use `--output-dir` to control where `import_graph.dot` is written.

### Added (Extension)

- **Command catalog webview**: New "Saropa Lints: Browse All Commands" command opens a searchable, categorized catalog of every extension command (117 commands across 13 categories). Features instant text search, collapsible category sections, click-to-execute, and a toggle to reveal context-menu-only commands. Accessible from the command palette, welcome views, and the getting-started walkthrough.
- **Enablement audit**: Seven copy-as-JSON commands (`Copy Violations as JSON`, `Copy Config as JSON`, etc.) previously hidden from the command palette are now visible when a Dart project is open. Commands have unique titles so they are distinguishable in the palette.
- **Walkthrough expansion**: Three new getting-started walkthrough steps — Package Health (dependency scanning and SBOM), TODOs & Hacks (workspace-wide marker scanning), and Browse All Commands (command catalog).
- **Welcome view links**: Both welcome views (non-Dart project intro and no-analysis-yet prompt) now include a "Browse All Commands" link to the command catalog.
- **Pubspec validation diagnostics**: Eleven inline checks on `pubspec.yaml`, shown in the Problems panel and as editor squiggles:
  - `avoid_any_version` (Warning): Flags `any` version constraints in dependencies
  - `dependencies_ordering` (Info): Flags unsorted dependency lists
  - `prefer_caret_version_syntax` (Info): Flags bare version pins (`1.2.3`) — suggests caret syntax (`^1.2.3`)
  - `avoid_dependency_overrides` (Warning): Flags `dependency_overrides` entries without an explanatory comment
  - `prefer_publish_to_none` (Info): Flags pubspec files missing `publish_to: none` field
  - `prefer_pinned_version_syntax` (Info): Stylistic opposite of `prefer_caret_version_syntax` — flags caret ranges, prefers exact pins (opt-in)
  - `pubspec_ordering` (Info): Flags top-level fields not in recommended order (name, description, version, ...)
  - `newline_before_pubspec_entry` (Info): Flags top-level sections without a preceding blank line
  - `prefer_commenting_pubspec_ignores` (Info): Flags `ignored_advisories` entries without an explanatory comment
  - `add_resolution_workspace` (Info): Flags workspace roots missing `resolution: workspace` field
  - `prefer_l10n_yaml_config` (Info): Flags inline `generate: true` under flutter — suggests `l10n.yaml`
- `prefer_pinned_version_syntax` and `prefer_caret_version_syntax` are mutually exclusive stylistic rules — controlled via `saropaLints.pubspecValidation.preferPinnedVersions` setting (default: off = caret preferred). Changes take effect immediately on open pubspec files.
- **Quick-fix code actions** for 5 pubspec diagnostics: `prefer_caret_version_syntax` (add `^`), `prefer_pinned_version_syntax` (remove `^`), `prefer_publish_to_none` (insert field), `newline_before_pubspec_entry` (insert blank line), `add_resolution_workspace` (insert field). Available from the lightbulb menu and `Ctrl+.`.
- Diagnostics update live as you edit pubspec.yaml (300ms debounce). SDK/path/git dependencies and `dependency_overrides` are handled correctly.
- **Package vibrancy sort spacing**: Sort Dependencies now inserts blank lines between packages for readability. Related packages that share a common name prefix (e.g. `drift`, `drift_flutter`, `drift_dev`) are kept together without a separator. SDK packages are always separated from non-SDK packages.

### Fixed (Extension)

- **Duplicate annotation comments**: The annotate-packages feature could leave duplicate description comments above a dependency (e.g. two identical `# A composable, multi-platform...` lines) when re-run on a pubspec that already had annotations from a prior run. The scanner now removes all consecutive auto-description lines above a URL, not just the single closest one.

### Fixed

- **Sidebar section toggles not responding**: Clicking an "Off" sidebar toggle in Overview & options produced no feedback. Root cause: the `toggleSidebarSection` command was registered at runtime but not declared in `contributes.commands`, so VS Code silently ignored tree-item clicks. Added the command declaration and a `commandPalette` hide entry, and wrapped the handler in try/catch so config-update failures now surface as error notifications.
- **avoid_stream_subscription_in_field**: Fixed false positive when `.listen()` is inside a conditional block (`if`/`for`) and assigned to a properly-named subscription field. The parent-walk loop now stops at closure (`FunctionExpression`) boundaries to prevent escaping into outer scopes. **Note:** this also fixes false negatives where a bare `.listen()` inside a closure was incorrectly suppressed because an outer scope had a properly-named subscription assignment — those uncaptured subscriptions will now correctly fire the lint.
- **cross_file HTML reporter**: Fixed string interpolation bug in index page — file counts were rendered as list objects instead of numbers.
- **cross_file --exclude**: The `--exclude` glob flag is now applied to filter results. Previously it was parsed but silently ignored.

<details>
<summary>Maintenance</summary>

- **Unified pubspec.yaml listener**: Pubspec validation and SDK constraint diagnostics now share a single `registerPubspecDocListeners` helper with one debounce timer (300ms), eliminating duplicate event subscriptions. Includes error boundary — a pubspec validation failure does not block SDK diagnostics.
- **Internal**: `parseDependencySections()` now accepts a pre-split lines array, eliminating a duplicate `content.split('\n')` call per validation run.
- **Roadmap restructure**: Split deferred rules into focused documents in `plan/deferred/` by barrier type (cross-file, unreliable detection, external dependencies, framework limitations, compiler diagnostics, not viable). Trimmed ROADMAP.md to actionable content only. Moved cross-file CLI design to `plan/cross_file_cli_design.md`.
- **Bug Report Guide**: Added `bugs/BUG_REPORT_GUIDE.md` — structured template and investigation checklist for filing lint rule bugs (false positives, false negatives, crashes, wrong fixes, performance)
- **Changelog Archive**: Moved [9.9.0] and older logs to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)
- **Plan history restore**: Restored 21 active plan/discussion/bug documents plus `deferred/` and `implementable_only_in_plugin_extension/` directories back to `plan/` root — these were incorrectly swept into `plan/history/` by the consolidation commit. Added `plan/history/INDEX.md` as a searchable index for the 1,069 history files.

</details>

---

## [10.10.0]

Ten new rules targeting deprecated APIs, performance traps, and migration gotchas across Dart and Flutter. — [log](https://github.com/saropa/saropa_lints/blob/v10.10.0/CHANGELOG.md)

### Added

- **prefer_isnan_over_nan_equality**: Flags `x == double.nan` (always false) and `x != double.nan` (always true) — use `.isNaN` instead (IEEE 754). Includes quick fix.
- **prefer_code_unit_at**: Flags `string.codeUnits[i]` which allocates an entire List just to read one code unit — use `string.codeUnitAt(i)` instead (Flutter 3.10, PR #120234). Includes quick fix.
- **prefer_never_over_always_throws**: Flags the deprecated `@alwaysThrows` annotation from `package:meta` — use `Never` return type instead (Dart 2.12+).
- **prefer_visibility_over_opacity_zero**: Flags `Opacity(opacity: 0.0, ...)` which inserts an unnecessary compositing layer — use `Visibility(visible: false, ...)` instead (Flutter 3.7, PR #112191).
- **avoid_platform_constructor**: Flags `Platform()` constructor usage deprecated in Dart 3.1 — all useful Platform members are static.
- **prefer_keyboard_listener_over_raw**: Flags deprecated `RawKeyboardListener` — use `KeyboardListener` which handles IME and key composition correctly (Flutter 3.18). Includes quick fix.
- **avoid_extending_html_native_class**: Flags extending native `dart:html` classes (`HtmlElement`, `CanvasElement`, etc.) which can no longer be subclassed (Dart 3.8 breaking change).
- **avoid_extending_security_context**: Flags extending or implementing `SecurityContext` from `dart:io` which is now `final` (Dart 3.5, breaking change #55786).
- **avoid_deprecated_pointer_arithmetic**: Flags deprecated `Pointer.elementAt()` from `dart:ffi` — use the `+` operator instead (Dart 3.3). Includes quick fix.
- **prefer_extracting_repeated_map_lookup**: Flags 3+ identical `map[key]` accesses in the same function body — extract into a local variable for readability and type safety (Flutter 3.10, PR #122178).

---

## [10.9.0]

Four new rules catching deprecated media query params, codec shorthand, a removed AppBar field, and iterable cast cleanup. — [log](https://github.com/saropa/saropa_lints/blob/v10.9.0/CHANGELOG.md)

### Added

- **prefer_iterable_cast**: Flags `Iterable.castFrom(x)` (and `List.castFrom`, `Set.castFrom`, `Map.castFrom`) and suggests the more readable `.cast<T>()` instance method (Flutter 3.24, PR #150185). Includes quick fix.
- **avoid_deprecated_use_inherited_media_query**: Flags the deprecated `useInheritedMediaQuery` parameter on `MaterialApp`, `CupertinoApp`, and `WidgetsApp` (deprecated after Flutter 3.7). The setting is ignored. Includes quick fix to remove the argument.
- **prefer_utf8_encode**: Flags `Utf8Encoder().convert(x)` and suggests the shorter `utf8.encode(x)` from `dart:convert` (Dart 2.18 / Flutter 3.16, PR #130567). Includes quick fix.
- **avoid_removed_appbar_backwards_compatibility**: Flags the removed `AppBar.backwardsCompatibility` parameter (removed in Flutter 3.10, PR #120618). Includes quick fix to remove the argument.

### Fixed

- **avoid_global_state**: Report diagnostic at declaration level instead of individual variable nodes to prevent wrong line numbers when doc comments precede the declaration

---

## [10.8.1]

Vibrancy report polish — better empty-cell display, smarter column layouts, and clickable package names. — [log](https://github.com/saropa/saropa_lints/blob/v10.8.1/CHANGELOG.md)

### Changed

- **Vibrancy Report**: Empty cells now show an em-dash with an explanatory tooltip instead of blank space (stars, published date, issues, PRs, size, license, description, and other optional columns)
- **Vibrancy Report**: Merged Health column into Category as a dimmed suffix, e.g. "Abandoned (1/10)"
- **Vibrancy Report**: Package name now opens pubspec.yaml at the dependency entry (was: pub.dev link) and shows description as tooltip
- **Vibrancy Report**: Published date now links to the pub.dev package page and shows the version age suffix (moved from Version column)
- **Vibrancy Report**: "Files" column renamed to "References" — click the count to search your workspace for that package's imports
- **Vibrancy Report**: Update column shows a dimmed en-dash instead of a checkmark when no update is available; all placeholder dashes are now dimmed
- **Vibrancy Report**: License and Description columns are now hidden by default (Description changed from icon to plain-text column)

---

## [10.8.0]

Vibrancy report gets GitHub issue and PR counts, plus a toolbar toggle for Drift Advisor integration. — [log](https://github.com/saropa/saropa_lints/blob/v10.8.0/CHANGELOG.md)

### Added

- **Vibrancy Report**: New "Issues" and "PRs" columns show open GitHub issue and pull request counts, linking directly to the repository's issues and pulls pages
- **Drift Advisor**: Toolbar toggle button in the Drift Advisor view — `$(plug)` enables integration, `$(circle-slash)` disables it. No more hunting through Settings to find `saropaLints.driftAdvisor.integration`.

---

## [10.7.0]

Vibrancy health categories renamed for clarity, report gains copy-as-JSON, file usage tracking, and clickable summary cards. — [log](https://github.com/saropa/saropa_lints/blob/v10.7.0/CHANGELOG.md)

### Changed

- **Vibrancy**: Renamed health categories for clarity — "Quiet" → **Stable**, "Legacy-Locked" → **Outdated**, "Stale" → **Abandoned**. Vibrant and End of Life are unchanged.
- **Vibrancy**: Raised Abandoned threshold from score <10 to score <20 so packages untouched for 4+ years with only bonus points are correctly flagged instead of escaping into Outdated
- **Vibrancy Report**: Overrides summary card is now clickable — filters the table to show only overridden packages
- **Vibrancy Report**: All table column headings now have tooltips explaining what each column represents (e.g. Published = "Date the installed version was published to pub.dev")

### Added

- **Vibrancy Report**: Copy-as-JSON button appears on row hover — copies a detailed JSON of all package fields and links to clipboard
- **Vibrancy Report**: New "Files" column shows how many source files import each package, with clickable file paths in the detail view that open at the exact import line
- **Vibrancy Report**: "Single-use" summary card filters to packages imported from only one file
- **Vibrancy Report**: Exported JSON and Markdown reports now include per-package file-usage data (file paths and line numbers)

### Fixed

- **Vibrancy Report**: Commented-out imports (e.g. `// import 'package:foo/foo.dart'`) are no longer counted as active usage for unused-package detection

### Breaking

- **Vibrancy Settings**: `budget.maxStale` renamed to `budget.maxAbandoned`; `budget.maxLegacyLocked` renamed to `budget.maxOutdated`. Users who customized these settings will need to update their config.
- **Vibrancy Exports**: JSON/Markdown export schemas use new category keys (`stable`, `outdated`, `abandoned` instead of `quiet`, `legacy_locked`, `stale`)
- **Generated CI scripts**: Previously generated CI workflows reference old threshold variable names. Regenerate after updating.

---

## [10.6.1]

Updated README screenshots. — [log](https://github.com/saropa/saropa_lints/blob/v10.6.1/CHANGELOG.md)

### Changed

Updated screenshots in [README.md](./README.md).

---

## [10.6.0]

Extension UX refinements — split workspace options into Settings and Issues sections, hide "Apply fix" for unfixable violations, and auto-expand violations tree on programmatic navigation. — [log](https://github.com/saropa/saropa_lints/blob/v10.6.0/CHANGELOG.md)

### Changed

- **Extension:** Overview sidebar splits the former "Workspace options" section into two focused sections: **Settings** (lint integration, tier, detected packages, config actions) and **Issues** (triage groups by violation count); Issues hides when no analysis data exists
- **Extension:** "Apply fix" context menu item is now hidden for violations without a quick fix, instead of showing a dead-end "No quick fix available" message
- **Extension:** Violations tree now auto-expands all levels when navigated to from settings, dashboard links, summary counts, or triage groups

### Fixed

- **Extension:** `rulesWithFixes` from `violations.json` was not extracted, causing all violations to appear fixable regardless of actual fix availability

---

## [10.5.0]

Replacement complexity metric — analyzes local pub cache to estimate feasibility of inlining, forking, or replacing each dependency; removed inline vibrancy summary diagnostic. — [log](https://github.com/saropa/saropa_lints/blob/v10.5.0/CHANGELOG.md)

### Added

- **(Extension)** Package Vibrancy: replacement complexity metric — analyzes local pub cache to count source lines in each dependency's `lib/` directory and classifies how feasible it would be to inline, fork, or replace (trivial / small / moderate / large / native). Shown in Size tree group, detail sidebar, and CodeLens for stale/end-of-life packages with feasible migration

### Changed

- **(Extension)** Removed the `vibrancy-summary` inline diagnostic from `pubspec.yaml` — the Package Vibrancy sidebar and report already surface this information. The `inlineDiagnostics` setting no longer offers a `"summary"` mode; the default is now `"critical"` (end-of-life packages only)

---

## [10.4.1]

Fixed VS Code Marketplace publishing blocked by TypeScript 5.9 bug; modularized publish script into focused modules. — [log](https://github.com/saropa/saropa_lints/blob/v10.4.1/CHANGELOG.md)

### Fixed

- **(Extension)** Fixed VS Code Marketplace publishing blocked since v10.2.2 by TypeScript 5.9 bug — `tsc --noEmit` fails with "Unknown compiler option" because TS 5.9's `createOptionNameMap()` reads `option.lowerCaseName` (a property that doesn't exist on any option declaration), building an empty lookup map; pinned TypeScript to `~5.8.3` to restore extension compilation and Marketplace publishing

<details>
<summary>Maintenance</summary>

- Modularized `scripts/publish.py` (1,246 → 202 lines) into three focused modules: `_publish_workflow.py` (pipeline orchestration), version prompting/sync into `_version_changelog.py`, and store verification into `_extension_publish.py`.
- Added `scripts/README.md` with architecture diagram, module map, exit codes, and troubleshooting.
- Added pub.dev publication verification: polls the pub.dev API after publish to confirm the new version is live.
</details>

---

## [10.4.0]

Vibrancy Report overhaul — auto-hiding blank columns, clickable summary cards and chart segments for filtering, search box, richer version/health tooltips, and pub.dev deep links throughout. — [log](https://github.com/saropa/saropa_lints/blob/v10.4.0/CHANGELOG.md)

### Vibrancy Report

- **(Extension)** Auto-hide blank columns: Transitives, Vulns, and Status columns are hidden when all values are empty
- **(Extension)** Summary cards now toggle table filters on click (vibrant, quiet, stale, updates, unused, vulns)
- **(Extension)** Chart bars and donut segments toggle a package filter instead of scrolling
- **(Extension)** Search box added above the table for filtering packages by name
- **(Extension)** "Open pubspec.yaml" toolbar button sends message to open the file in the editor
- **(Extension)** Version column links to pub.dev/versions; shows compact age suffix (e.g. `(4mo)`, `(2y)`)
- **(Extension)** Version column tooltip shows installed version date, latest version, creation date, and constraint
- **(Extension)** Health column merged from separate Score/Drift; tooltip shows score breakdown (Resolution Velocity, Engagement Level, Popularity, Publisher Trust)
- **(Extension)** License column links to pub.dev/license; Update column links to pub.dev/changelog
- **(Extension)** Stars column right-aligned with comma formatting; Size column now shows KB
- **(Extension)** Section badges (`dev`, `transitive`) shown in Package column
- **(Extension)** Description info icon column with tooltip on hover
- **(Extension)** Override count shown in summary cards

<details>
<summary>Maintenance</summary>

- `createdDate` field added to pub.dev metadata model.
- `installedVersionDate` field added to vibrancy results model.
</details>

---

## [10.3.0]

Analyzer 12 migration — rewrites ~500 call sites across 70+ rule files to the new AST API, adds vibrancy scan cancel/supersede support. — [log](https://github.com/saropa/saropa_lints/blob/v10.3.0/CHANGELOG.md)

### Added

- **Vibrancy scan cancel button** — the progress notification now shows a Cancel button so users can abort a long-running scan
- **Scan supersede** — starting a new vibrancy scan automatically cancels any in-progress scan instead of silently dropping the request

<details>
<summary>Maintenance</summary>

- **Analyzer upgraded from ^9.0.0 to ^12.0.0** — migrated ~500 call sites across 70+ rule files to the new AST API (`ClassDeclaration.body.members`, `ClassNamePart.typeName`, `PrimaryConstructorDeclaration`, `DottedName`, etc.)
- **Removed analyzer-9 compatibility extensions** — `DiagnosticCodeLowerCase` and `LintCodeLowerCase` shims removed; `lowerCaseName` is now native in analyzer 12.
- **Updated `CapturingRuleVisitorRegistry`** — added 5 new visitor methods and removed 4 obsolete ones to match the analyzer 12 `RuleVisitorRegistry` interface.
- **Updated test registry** — `PluginRegistry` interface changes: `enabled()` method, `DiagnosticCode` parameter on `registerFixForRule`.
</details>

---

## [10.2.2]

Extension vibrancy scoring fix. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.2/CHANGELOG.md)

### Fixed

- **(Extension)** Vibrancy scores no longer bottom out near zero for packages with high pub.dev quality but low GitHub activity; a new pub quality bonus (0–10) scales linearly with pub.dev points so that well-vetted "finished" packages score fairly

## [10.2.1]

VS Code extension polish — clearer status bar when lint health and Package Vibrancy are both shown. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.1/CHANGELOG.md)

### Fixed

- **(Extension)** Unified status bar now uses compact disambiguation for mixed metrics when vibrancy is shown: `Saropa: 90% · V4/10` (prevents confusion between lint `%` and vibrancy `/10` without adding verbose labels)

## [10.2.0]

Stream subscription detection improvements — fixes false negatives on rxdart and custom Stream subclasses, and aligns rule description with actual behavior. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.0/CHANGELOG.md)

### Added

- New rule: `avoid_removed_null_thrown_error` — flags removed `NullThrownError` type (Dart 3.0); quick fix renames to `TypeError`
- New rule: `avoid_deprecated_file_system_delete_event_is_directory` — flags deprecated `FileSystemDeleteEvent.isDirectory` (Dart 3.4) which always returns false
- New rule: `avoid_removed_render_object_element_methods` — flags removed `insertChildRenderObject`, `moveChildRenderObject`, `removeChildRenderObject` (Flutter 3.0); quick fix renames to replacement methods
- New rule: `avoid_deprecated_animated_list_typedefs` — flags deprecated `AnimatedListItemBuilder` / `AnimatedListRemovedItemBuilder` (Flutter 3.7); quick fix renames to `AnimatedItemBuilder` / `AnimatedRemovedItemBuilder`
- New rule: `avoid_deprecated_use_material3_copy_with` — flags misleading `useMaterial3` parameter in `ThemeData.copyWith()` (Flutter 3.16); quick fix removes the parameter
- New rule: `avoid_deprecated_on_surface_destroyed` — flags deprecated `SurfaceProducer.onSurfaceDestroyed` (Flutter 3.29); quick fix renames to `onSurfaceCleanup`

### Fixed

- `avoid_stream_subscription_in_field` now detects uncaptured `.listen()` calls on Stream subclasses (e.g. rxdart `MergeStream`, `BehaviorSubject`) that were previously missed by string-based type checking
- `avoid_stream_subscription_in_field` problem message and correction message now accurately describe the rule's behavior (detecting uncaptured `.listen()` calls) instead of incorrectly claiming it checks `dispose()`
- **(Extension)** Violations sidebar no longer opens a "file not found" error when source files have been moved or renamed since the last analysis; affected items show a warning icon with "(file moved or deleted)" label
- **(Extension)** "Fix all in this file" command now shows a user-friendly warning instead of silently failing on moved/deleted files

<details>
<summary>Maintenance</summary>

- Test fixture for `avoid_stream_subscription_in_field` now uses properly-typed `Stream<int>` variables instead of undefined `dynamic` references that bypassed the type check.
</details>

## [10.1.1]

Package Vibrancy accuracy pass — removes false "End of Life" flags on healthy packages and adds a pub points quality floor so high-scoring packages are never labeled Stale. — [log](https://github.com/saropa/saropa_lints/blob/v10.1.1/CHANGELOG.md)

### Fixed

- **(Extension)** 8 packages falsely classified as **End of Life** in `known_issues.json` have been downgraded to `caution` or `active` — `local_auth`, `font_awesome_flutter`, `animations`, `flutter_email_sender`, `flutter_sticky_header`, `flutter_rating_bar`, `workmanager`, `flutter_phone_direct_caller` were contradicted by their own pub.dev scores (135-160/160 points).
- **(Extension)** Packages with **>= 140/160 pub points** can no longer classify as **Stale** — the pub points quality floor promotes them to **Legacy-Locked** at minimum, preventing high-quality quiet packages from appearing abandoned.
- **(Extension)** `calcPopularity` pub points normalization cap corrected from 150 to 160 (the actual pub.dev maximum).
- **(Extension)** Fixed dead-code status string mismatch in `adoption-classifier.ts` and `transitive-analyzer.ts` — checks for `'end-of-life'` (hyphenated) now correctly use `'end_of_life'` (underscored) to match `known_issues.json` format.

---

## [10.1.0]

This release focuses on Flutter SDK alignment (new migration lints and a shared identifier→element helper) and on the **VS Code extension**: Package Vibrancy now uses a single **trusted publishers** list so first-party and Google-published packages are not mislabeled **Quiet** when GitHub-activity scoring sits in the mid tier. — [log](https://github.com/saropa/saropa_lints/blob/v10.1.0/CHANGELOG.md)

### Added

- **`prefer_dropdown_menu_item_button_opacity_animation`** (Recommended, INFO) — Flutter 3.32 ([PR #164795](https://github.com/flutter/flutter/pull/164795)) types `opacityAnimation` on `DropdownMenuItemButton` state as non-null (`late CurvedAnimation`). The rule flags nullable `CurvedAnimation? opacityAnimation` fields and redundant `opacityAnimation!` when resolved types show `State<DropdownMenuItemButton<…>>` or a `DropdownMenuItemButton` receiver. Quick fixes: remove `!` ([RemoveNullAssertionFix](lib/src/fixes/type/remove_null_assertion_fix.dart)) and rewrite the field to `late CurvedAnimation` ([prefer_dropdown_menu_item_button_opacity_animation_field_fix.dart](lib/src/fixes/config/prefer_dropdown_menu_item_button_opacity_animation_field_fix.dart)). Fixture: `example/lib/migration/prefer_dropdown_menu_item_button_opacity_animation_fixture.dart`; mock: `DropdownMenuItemButton` in `example/lib/flutter_mocks.dart`.

- **`prefer_image_filter_quality_medium`** (Comprehensive, INFO) — Flags `filterQuality: FilterQuality.low` on Flutter SDK `Image` / `RawImage` / `FadeInImage` / `DecorationImage` so apps align with Flutter 3.24 image defaults ([PR #148799](https://github.com/flutter/flutter/pull/148799)). Quick fix rewrites `low` → `medium` (preserves enum prefix). Does not apply to `Texture`. Detection: `lib/src/rules/widget/image_filter_quality_detection.dart`; rule: `lib/src/rules/widget/image_filter_quality_migration_rules.dart`.

- **`avoid_deprecated_flutter_test_window`** (Recommended, WARNING) — Flags `package:flutter_test` [TestWindow](https://api.flutter.dev/flutter/flutter_test/TestWindow-class.html) and [TestWidgetsFlutterBinding.window](https://api.flutter.dev/flutter/flutter_test/TestWidgetsFlutterBinding/window.html), deprecated in Flutter 3.10 ([PR #122824](https://github.com/flutter/flutter/pull/122824)); migrate to `WidgetTester.platformDispatcher` and `WidgetTester.view` / `viewOf`. Detection uses resolved elements only. Shared predicates: `lib/src/rules/config/flutter_test_window_deprecation_utils.dart` (unit-tested URI boundary); `example/analysis_options_template.yaml` lists the override.

### Changed

- **Package Vibrancy (VS Code extension)** — Introduces [`extension/src/vibrancy/scoring/trusted-publishers.ts`](extension/src/vibrancy/scoring/trusted-publishers.ts): **`TRUSTED_PUBLISHERS`** (`dart.dev`, `google.dev`, `flutter.dev`, `firebase.google.com`) and **`isTrustedPublisher()`**. The same set controls (1) the **`publisherTrustBonus`** scoring bonus and (2) promoting **Quiet** → **Vibrant** when the raw score is in the mid band but the dependency is from a trusted publisher—so pubspec CodeLens and reports match maintainer intent. **EOL still wins:** discontinued packages, known end-of-life entries, and archived GitHub repos are unchanged; publisher IDs are matched case-sensitively (as on pub.dev). **`saropaLints.packageVibrancy.publisherTrustBonus`** setting description updated to describe the trusted list. **Tests:** `npm test` runs [`vibrancy-calculator.test.ts`](extension/src/test/vibrancy/scoring/vibrancy-calculator.test.ts) (trust bonus for every trusted ID) and extended [`status-classifier.test.ts`](extension/src/test/vibrancy/scoring/status-classifier.test.ts) (trusted upgrade, non-trusted quiet, wrong-case publisher, EOL overrides).


<details>
<summary>Maintenance</summary>

- **Analyzer identifier → element** — Shared `elementFromAstIdentifier` in `lib/src/element_identifier_utils.dart` tries `.element` then `.staticElement` with optional `logFailures`. Used by `image_filter_quality_detection` and deprecated-API checks in `code_quality_avoid_rules.dart`. Tests: `test/element_identifier_utils_test.dart`.
</details>

---

## [10.0.2]

This patch wires ten compile-time mirror rules into the public rule list and tiers, updates existing rules for Analyzer 9 element APIs, and fixes a `require_data_encryption` false positive and unsafe `file://` root parsing in project metadata. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.2/CHANGELOG.md)

### Fixed

- **Plan additional rules 31–40** — The ten compile-time / doc / style mirror rules (`abstract_field_initializer`, `abi_specific_integer_invalid`, `annotate_redeclares`, `deprecated_new_in_comment_reference`, `document_ignores`, `non_constant_map_element`, `return_in_generator`, `subtype_of_disallowed_type`, `undefined_enum_constructor`, `yield_in_non_generator`) were present in source but missing from [`saropa_lints.dart`](lib/saropa_lints.dart) `_allRuleFactories` and from [`essentialRules`](lib/src/tiers.dart); they are now registered so tiers and tooling load them.
- **`require_data_encryption`** — The `pin` keyword is matched only when not immediately preceded by an ASCII letter, so identifiers such as `OwaspMapping` (where `Mapping` embeds `…p-i-n…`) no longer false-positive on ordinary `write`/`writeAsString` calls. Regression coverage: `test/require_data_encryption_pin_pattern_test.dart`; fixture: `example_async/lib/security/require_data_encryption_fixture.dart`.

<details>
<summary>Maintenance</summary>

- **Analyzer 9 (migration / fixes)** — `prefer_dropdown_menu_item_button_opacity_animation` uses `declaredFragment?.element` on class and field declarations, `DartType.nullabilitySuffix` for nullable `CurvedAnimation?`, `SimpleIdentifier.element` for `!` operands, and `reporter.atToken` for field names. `image_filter_quality_detection` uses `SimpleIdentifier.element` only (removed `staticElement`).
- **`rootUriToPath`** — `file://` roots use `Uri.tryParse` so invalid URIs return null instead of throwing. Tests: `test/project_info_root_uri_test.dart`.
</details>

---

## [10.0.1]

Version bump only. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.1/CHANGELOG.md)

### Changed

- Version bump

---

## [10.0.0]

In this milestone update work centers on the composite analyzer plugin hook (`registerSaropaLintRules`), rule packs end-to-end (analyzer merge, CLI init, VS Code Rule Packs webview, generated registry), extension UX that defaults integration on with clearer commands and TODOs workspace scan as opt-in, and a wave of new lints—compile-time shape alignment, Dart 3.0 removed-API migration rules, and targeted Flutter fixes. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.0/CHANGELOG.md)

### Fixed

• **VS Code extension** — **Violations tree:** enable `canSelectMany` on `saropaLints.issues` so Ctrl/Cmd+click multi-select works with **Copy as JSON** (command already preferred the selection array; the UI could not select multiple rows before). Selection resolution moved to `extension/src/copyTreeAsJsonSelection.ts` for unit tests without the VS Code runtime. Tests: `extension/src/test/copyTreeAsJson.test.ts`.

### Changed

• **VS Code extension** — **Default-on UX:** `saropaLints.enabled` defaults **true**; Overview always shows workspace options and sidebar toggles for Dart projects (no empty tree + “off” welcome). Config and Rule Packs views depend on `saropaLints.isDartProject` + sidebar settings, not on `enabled`. **TODOs & Hacks** workspace scan is opt-in via new `saropaLints.todosAndHacks.workspaceScanEnabled` (default **false**) with command **TODOs & Hacks: Enable workspace scan**. Commands renamed for clarity (**Set Up Project** / **Turn Off Lint Integration**). Sidebar section counts still reflect `violations.json` even when integration is off; Vibrancy package count is supplied by the extension host (`getLatestResults().length`) so `sidebarSectionCounts` stays testable. New modules/tests: `suggestionCounts.ts`, `suggestionCounts.test.ts`, `sidebarSectionCounts.test.ts`.

### Added

• **Composite analyzer plugin API** — `registerSaropaLintRules(PluginRegistry)` on `package:saropa_lints/saropa_lints.dart` (used by `lib/main.dart`); skips rules via `SaropaLintRule.isDisabled` (canonical name or `configAliases`). Re-export `loadNativePluginConfig`, `loadOutputConfigFromProjectRoot`, `loadRulePacksConfigFromProjectRoot` for meta-plugins. Guide: `doc/guides/composite_analyzer_plugin.md`. Tests: `test/saropa_plugin_registration_test.dart`. Template note: `example/analysis_options_template.yaml`.

• **VS Code extension** — **Rule Packs** sidebar webview: per-pack row (label, detected in pubspec, enable toggle, rule count, “Rules” opens Quick Pick of rule codes), plus **target platforms** table (android/ios/web/windows/macos/linux) when embedder folders exist. Writes `plugins.saropa_lints.rule_packs.enabled` in `analysis_options.yaml`.

• **Analyzer plugin** — `rule_packs.enabled` under `plugins.saropa_lints` merges rule codes from `lib/src/config/rule_packs.dart` via `mergeRulePacksIntoEnabled` (skips codes in `diagnostics`/`severities` disables). Config load order documented in `config_loader.dart`.

• **Rule packs (Phase 3)** — `pubspec.lock` resolved versions (cached by mtime) gate optional packs via `kRulePackDependencyGates`; example `collection_compat` merges only when `collection` satisfies `>=1.19.0`. `loadRulePacksConfigFromProjectRoot` re-merges packs when the analyzer discovers the project root. Dependency: `pub_semver`.

• **Rule packs (Phase 4 / CLI)** — `dart run saropa_lints:init --list-packs` lists applicable packs from pubspec + lockfile; `--enable-pack <id>` (repeatable) merges into `rule_packs.enabled`. Init / `write_config` preserve existing `rule_packs` when regenerating the plugins section (unless `--reset`).

• **Rule packs (Phase 5 / registry codegen)** — `lib/src/config/rule_pack_codes_generated.dart` is produced from `lib/src/rules/packages/*_rules.dart` by `dart run tool/generate_rule_pack_registry.dart` (also refreshes `extension/src/rulePacks/rulePackDefinitions.ts`). `kRulePackRuleCodes` / `kRulePackPubspecMarkers` in `rule_packs.dart` spread the generated maps and add `collection_compat`. `dart run tool/rule_pack_audit.dart` checks file extraction vs the merged registry (shared composite map for cross-pack rules such as `avoid_isar_import_with_drift`).

• **Lint rules** — **compile-time Dart shape** (ERROR/WARNING, Essential): ten rules aligned with analyzer compile-time diagnostics — `duplicate_constructor`, `conflicting_constructor_and_static_member`, `duplicate_field_name`, `field_initializer_redirecting_constructor`, `invalid_super_formal_parameter_location`, `illegal_concrete_enum_member`, `invalid_extension_argument_count`, `invalid_field_name` (keyword-tokens on record labels when present in AST), `invalid_literal_annotation`, `invalid_non_virtual_annotation`. Implementation: `lib/src/rules/architecture/compile_time_syntax_rules.dart`, record/extension rules in `type_rules.dart`; fixture `example/lib/plan_additional_rules_21_30_fixture.dart`.

• **Lint rules** — **Dart SDK 3.0 removed APIs** (WARNING, Recommended): fifteen migration rules with targeted quick fixes where safe — `avoid_deprecated_list_constructor`, `avoid_removed_proxy_annotation`, `avoid_removed_provisional_annotation`, `avoid_deprecated_expires_getter`, `avoid_removed_cast_error`, `avoid_removed_fall_through_error`, `avoid_removed_abstract_class_instantiation_error`, `avoid_removed_cyclic_initialization_error`, `avoid_removed_nosuchmethoderror_default_constructor`, `avoid_removed_bidirectional_iterator`, `avoid_removed_deferred_library`, `avoid_deprecated_has_next_iterator`, `avoid_removed_max_user_tags_constant`, `avoid_removed_dart_developer_metrics`, `avoid_deprecated_network_interface_list_supported`. See `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

• **Lint rule** — **avoid_implicit_animation_dispose_cast** (WARNING, Professional, **high** impact): flags `(animation as CurvedAnimation).dispose()` in `ImplicitlyAnimatedWidgetState` subclasses; the framework disposes that animation in `super.dispose()` (Flutter 3.7 / [PR #111849](https://github.com/flutter/flutter/pull/111849)). Quick fix removes the redundant statement. Shared AST helper: `lib/src/implicit_animation_dispose_cast_ast.dart`. Tests: `test/avoid_implicit_animation_dispose_cast_rule_test.dart`.

• **Lint rule** — **prefer_overflow_bar_over_button_bar** (INFO, Recommended): flags `ButtonBar` usage; prefer `OverflowBar` for Material action layouts (Flutter 3.13 guidance, PR #128437).

### Changed

• **VS Code extension** — **Overview & options** sidebar: **Workspace options** embeds the same tree as the standalone Config view; section toggles show counts in the label (e.g. `Package Vibrancy (2)`) with **On**/**Off** in the description; intro links (pub.dev, About, Getting Started) remain visible whenever Saropa is enabled; standalone Config defaults off (`saropaLints.sidebar.showConfig`). Command **Saropa Lints: Open package on pub.dev** (`saropaLints.openPubDevSaropaLints`). Overview **Copy as JSON** recurses through nested children. Embedded config nodes are allowlisted by `kind` (`overviewEmbeddedConfigKinds.ts`); sidebar label formatting lives in `sidebarToggleLabel.ts` for Node tests. Unit tests: `sidebarToggleLabel`, `overviewEmbeddedConfigKinds`, `serializeOverviewNode`.

• **VS Code extension** — **TODOs & Hacks** default `includeGlobs` no longer scans `**/*.md` (Markdown READMEs/plans often match tag words in prose). Defaults remain Dart, YAML, TypeScript, and JavaScript; add `**/*.md` in settings if you want docs included. `package.json` defaults and `todosAndHacksDefaults.ts` stay in sync (unit test).

• **ListView extent hints** — `avoid_listview_without_item_extent`, `prefer_item_extent`, `prefer_prototype_item`, `prefer_itemextent_when_known`, and `require_item_extent_for_large_lists` now treat **`itemExtentBuilder`** (Flutter 3.16+, PR #131393) as a valid alternative to `itemExtent` / `prototypeItem` where applicable. `avoid_listview_without_item_extent` also applies to **`ListView.separated`**.

• **Lint rules** — Flutter migration / widget consistency (INFO; **prefer_super_key** in Comprehensive, **avoid_chip_delete_inkwell_circle_border** in stylistic + `flutterStylisticRules` only — mutually exclusive tier sets):

- **prefer_super_key**: flags `Key? key` with `super(key: key)` on `StatelessWidget` / `StatefulWidget` / `*Widget` subclasses; prefer `super.key` ([Flutter PR #147621](https://github.com/flutter/flutter/pull/147621)). Quick fix rewrites the constructor.
- **avoid_chip_delete_inkwell_circle_border**: flags chip `deleteIcon` subtrees that use `InkWell` with `customBorder: CircleBorder()`, which mismatches the square chip delete region fixed in Flutter 3.22 ([PR #144319](https://github.com/flutter/flutter/pull/144319)). Handles both `InstanceCreationExpression` and unqualified `MethodInvocation` chip calls, and nested `InkWell`/`CircleBorder` parse shapes.

<details>
<summary>Maintenance</summary>

- **Publish / tier integrity** — `scripts/modules/_tier_integrity.py` `get_registered_rule_names` now resolves rule classes when the `extends` clause starts on the line after the class name (valid Dart; previously produced a false **phantom** for `avoid_removed_nosuchmethoderror_default_constructor`). Python regression coverage added.
- **Code cleanup** — Batched `context.subscriptions.push` calls in `extension.ts`; refactored vibrancy "Copy as JSON" serialization into small matchers with documented dispatch order (`treeSerializers.ts`). Added unit tests for `serializeVibrancyNode`.
- **Rule packs** — Maintainer workflow documented in `doc/guides/rule_packs.md` (regenerate, composite map, audit). Added `test/rule_pack_registry_test.dart` and expanded pubspec-marker false-positive coverage. README badge rule count aligned with `pubspec.yaml` (2105).
- **Dart SDK** — `example*` and `self_check` `pubspec.yaml` floors aligned to `>=3.9.0` with the main package, replacing stale lower example constraints.
- **Dart SDK 3.0 migration rules** — `avoid_removed_max_user_tags_constant` and `avoid_removed_dart_developer_metrics` use **high** LintImpact (removed APIs are compile failures on Dart 3). File header and rule DartDocs expanded for reviewers and false-positive contracts.
</details>

---

## [9.10.0] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 9.10.0.

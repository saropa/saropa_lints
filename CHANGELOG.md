# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 8.0.11.

**Package** — [pub.dev / packages / saropa_lints](https://pub.dev/packages/saropa_lints)

**Score** — [pub.dev / packages / saropa_lints / score](https://pub.dev/packages/saropa_lints/score)

**CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

**Releases** — [github.com / saropa / saropa_lints / releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com / items ? itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org / extension / saropa / saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

Each version (and [Unreleased]) has a short commentary line in plain language — what this release is about for humans. Only discuss user-facing features; vary the phrasing.

---

## [Unreleased]

### Added

• **Headless config writer (write_config)** — New `write_config` executable and `lib/src/init/write_config_runner.dart` for writing `analysis_options.yaml` from tier + `analysis_options_custom.yaml` without interactive output. Extension now calls `dart run saropa_lints:write_config --tier <tier> --target <workspace>` instead of init for Enable, Initialize Config, and Set tier. Init remains for CI/scripting. Aligns with [003_INIT_REDESIGN](bugs/discussion/003_INIT_REDESIGN.md) (extension-driven config).

• **Cross-file analysis CLI** — New `cross_file` executable: `dart run saropa_lints:cross_file <command>` with commands `unused-files`, `circular-deps`, `import-stats`, and `report`. Builds the import graph from `lib/`, reports files with no importers, circular import chains, and graph statistics. Output: text (default), JSON, or HTML via `report --output-dir`. Baseline: `--baseline <file>` and `--update-baseline` to suppress known issues and fail only on new violations. Exit codes 0/1/2. README and [doc/cross_file_ci_example.md](doc/cross_file_ci_example.md) for CI. See [ROADMAP Part 3](ROADMAP.md).

• **Central cache stats** — `CacheStatsAggregator.getStats()` returns a single map aggregating statistics from all project caches (import graph, throttle, speculative, rule batch, baseline, semantic, etc.) for debugging and monitoring.

### Archive

• Rules 8.0.11 and earlier moved to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md)

---

## [9.6.1]

### Fixed

• **Package Vibrancy** — Do not show the main vibrancy diagnostic (Review/stale/legacy-locked/end-of-life/monitor) for dependencies resolved via path or git override; the resolved artifact is local or from git, so the upstream pub.dev score is not actionable and was causing false positives.

---

## [9.6.0]

_Clearer Package Vibrancy scoring and reliable filter-by-type behavior._

### Added

• **Package Vibrancy** — Action Items tree now shows a simple letter grade (A = best … E = stale … F = dangerous) and problem count instead of a numeric “risk” score; aligns with a single, clear scoring system and correct pluralization (“1 problem” / “2 problems”)

### Fixed

• **Package Vibrancy** — Filter by Problem Type now correctly applies the selected types; resolved QuickPick selections using a shared id+label fallback so filter state is set reliably across environments

---

## [9.5.2]

_Keeping your lints fresh — the extension now detects outdated saropa_lints versions and offers one-click upgrades, plus new SDK constraint diagnostics._

### Added

• **Extension** — background upgrade checker: on activation, the extension checks pub.dev for newer saropa_lints versions and shows a non-intrusive notification with Upgrade, View Changelog, and Dismiss actions; throttled to once per 24 hours, remembers dismissed versions, skips path/git dependencies, and respects the new `saropaLints.checkForUpdates` setting

• **Extension** — SDK constraint diagnostics: inspects the `environment` section of `pubspec.yaml` and reports when Dart SDK or Flutter version constraints are behind the latest stable release; shows Warning when the upper bound excludes latest, Information when behind by a minor version, and Hint for patch-level gaps; fires on file open, on edit (debounced), and after every vibrancy scan

• **Extension** — overview panel toolbar: added About (info icon) and Run Analysis (play icon) buttons to the overview panel title bar; removed redundant tree items (Run Analysis, Summary, Config, Suggestions) that duplicate existing sidebar views

• **Extension** — overview tree icons: each overview item now displays a contextual icon (pulse for health score, warning/pass for violations, graph-line for trends, arrow-down for regressions, star-full for celebrations, history for last run)

---

## [9.5.1]

_Streamlining the Package Vibrancy toolbar._

### Added

• **Package Vibrancy** — added interactive Size Distribution charts (horizontal bar + SVG donut) to the vibrancy report webview; bars animate in, donut segments draw in, hover shows tooltips with cross-highlighting between charts, click scrolls to the package row in the table; small packages are consolidated into "Other (N packages)"

• **Package Vibrancy** — added Expand All button to the tree toolbar; collapse all uses the built-in VS Code button (`showCollapseAll`)

### Changed

• **Package Vibrancy** — the "Unhealthy" problem label now shows the actual category ("End of Life", "Stale", "Legacy-Locked") instead of the generic "Unhealthy" label; the description shows the vibrancy score for additional context

• **Package Vibrancy** — the Version group now shows "(latest)" on the version constraint and collapses when the package is confirmed up-to-date; the redundant "Latest" child row is hidden in that case

### Fixed

• **Package Vibrancy** — fixed false positive "unused" detection for packages referenced only via `export` directives (e.g. `analyzer_plugin`); the import scanner now recognizes both `import` and `export` as package usage

• **Extension** — fixed "Annotate pubspec.yaml" command targeting the wrong file in workspaces with multiple `pubspec.yaml` files; now prefers the active editor's pubspec, then falls back to the workspace root; also checks the `applyEdit` return value and shows the target file name in the success message

• **Lint rules** — registered `prefer_debugPrint` rule that was implemented but never wired into `_allRuleFactories` or assigned a tier; now active in the Recommended tier

• **Examples** — removed stale `custom_lint` dev dependency from all 6 example projects; `custom_lint ^0.8.0` requires `analyzer ^8.0.0` which conflicts with the v5 native plugin's `analyzer ^9.0.0`

• **ROADMAP** — removed `prefer_semver_version` and `prefer_correct_package_name` from the "Deferred: Pubspec Rules" section; both are already implemented and registered

• **Plugin** — removed dead `PreferConstChildWidgetsRule` commented-out factory entry (class never existed)

### Removed

• **Extension:** removed the "About Package Vibrancy" info icon and webview panel from the Package Vibrancy sidebar toolbar

• **Package Vibrancy** — removed the cryptic problem-severity summary row (colored dots with bare numbers) from the top of the tree; the Action Items group already communicates problem counts and details

---

## [9.5.0]

_Smarter dependency health — stale vs end-of-life separation, GitHub archived-repo detection, a unified vibrancy panel with filters, and copy-as-JSON across all tree views._

### Added

• **Extension** — "Copy as JSON" context menu on all tree views (Issues, Config, Summary, Security Posture, File Risk, Overview, Suggestions, Package Vibrancy) with recursive child serialization and multi-select support

• **Package Vibrancy** — GitHub archived-repo detection: archived repositories are automatically classified as End of Life and shown with a 🗄️ badge in tree view, hover tooltip, and detail panel

• **Package Vibrancy** — richer GitHub metrics: true open issue count (separating issues from PRs), open PR count, last commit date, and GitHub license; displayed across hover tooltip, detail panel, and output log

### Changed

• **Extension** — consolidated 3 right-side status bar items (Saropa Lints, CodeLens toggle, Vibrancy score) into a single unified item; vibrancy score appears in the label when scan data is available, with full detail in the tooltip; new `showInStatusBar` setting lets users hide the vibrancy score without disabling the extension

• **Extension** — "Apply fix" context menu item in Issues tree is now greyed out for violations whose rule has no quick-fix generator; `rulesWithFixes` list in `violations.json` config section drives the enablement so the user knows upfront which violations are auto-fixable

• **Package Vibrancy** — merged Package Problems panel into Package Vibrancy; problems and suggested actions now appear as child nodes under each package instead of in a separate tree view

• **Package Vibrancy** — added filter toolbar: search by name, filter by severity, problem type, health category, and dependency section; toggle problems-only view mode; clear all filters

• **Package Vibrancy** — problem summary bar (severity counts) now appears at the top of the unified tree when problems exist

• **Package Vibrancy** — added algorithmic guardrail to prevent editorial `end_of_life` overrides from condemning actively-maintained packages; if live pub.dev data shows a package has ≥130 pub points and was published within 18 months, the classification is capped at Legacy-Locked instead of End of Life

• **Package Vibrancy** — `isDiscontinued` (objective pub.dev signal) now takes priority over known-issue overrides in the status classifier

• **Package Vibrancy** — reclassified 71 known-issue entries from `end_of_life` to `caution` for packages that are actively maintained with verified publishers and high pub points (e.g. `animations`, `google_fonts`, `flutter_local_notifications`, `camera`, `dio`); these packages are now scored by the vibrancy algorithm instead of being force-classified as dead

• **Package Vibrancy** — separated "Stale" from "End of Life": packages with score < 10 are now classified as `stale` (low maintenance activity) instead of `end-of-life`; the `end-of-life` label is reserved exclusively for packages that are discontinued on pub.dev, listed in known_issues as `end_of_life`, or archived on GitHub; new budget dimension `maxStale` and CI threshold `maxStale` added

• **Extension** — removed "Saropa:" prefix from all vibrancy command titles in context menus and command palette; commands now read "Scan Dependencies", "Update All Dependencies", etc. instead of "Saropa: Scan Dependencies"

### Fixed

• **Lint Rules** — `require_image_picker_permission_ios` no longer fires a false positive on gallery-only usage; the rule now checks for `ImageSource.camera` in `pickImage()`/`pickVideo()` calls instead of triggering on any `image_picker` import, matching the Android rule's approach

• **Package Vibrancy** — clicking a problem child node (e.g. "Unhealthy") now navigates to the correct pubspec.yaml from the last scan instead of opening a random pubspec in a multi-root workspace

• **Package Vibrancy** — added missing `stale` category handling in comparison view CSS, scan log output, CI threshold prompts, and CI generator templates

• **Analyzer** — `// ignore:` and `// ignore_for_file:` comments now suppress violations in the extension's Issues tree and `violations.json`, not just in the editor; centralized ignore handling in `SaropaDiagnosticReporter` so all rules benefit without per-rule opt-in

• **Package Vibrancy** — added missing `.warning` CSS class in detail-view styles; archived-repo row now renders with correct warning color instead of inheriting default text color

## [9.4.2]

_Quick polish: colored diagnostic icons in the Issues tree and clipboard support on vibrancy tooltips._

### Added

• **Extension** — copy-to-clipboard link on package vibrancy hover tooltip; copies full package info as markdown

### Changed

• **Extension** — Issues tree severity and folder nodes now display colored diagnostic icons (error/warning/info) instead of plain folder icons

### Fixed

• **Extension** — clicking a child node (problem, suggestion, or healthy package) in the Package Problems tree now shows the parent package's details instead of clearing the Package Details panel

---

## [9.4.1]

_Housekeeping: plugging minor gaps carried over from the Package Vibrancy merge._

### Fixed

• **Extension** — dispose the upgrade-plan output channel on deactivation (was never cleaned up, minor resource leak)

• **Extension** — declare `focusIssuesForOwasp` command in `package.json` so VS Code can validate it; hidden from Command Palette since it requires a structured argument

• **Extension** — set `showPrereleases` context key via `setContext` so the show/hide prerelease toggle buttons reflect the actual state; also wire `refresh()` into the config-change listener so direct settings.json edits stay in sync

---

## [9.4.0]

_Package Vibrancy is now built into Saropa Lints. One extension, one sidebar — lint analysis and dependency health together._

### Added

• **Package Vibrancy integration** — merged the standalone Saropa Package Vibrancy extension into Saropa Lints
  - Three new collapsible sidebar panels: Package Vibrancy, Package Problems, Package Details
  - Dependency vibrancy scoring, vulnerability scanning (OSV + GitHub Advisory), SBOM export (CycloneDX)
  - Upgrade planning with test gates, bulk updates (latest/major/minor/patch)
  - CodeLens badges on pubspec.yaml dependencies showing vibrancy scores
  - Unused dependency detection, pubspec annotation, dependency sorting
  - Background version watching with configurable polling intervals
  - Budget enforcement (max dependencies, total size, min average vibrancy)
  - Private registry support with secure token storage
  - CI pipeline generation for dependency health checks
  - Package comparison view for side-by-side evaluation

### Changed

• **Build system** migrated from raw tsc to esbuild (bundled single file, smaller .vsix, faster startup)

• Extension minimum VS Code version remains ^1.74.0

---

## [9.3.0]

### Added

• "About Saropa Lints" screen showing extension version and full company/product info from `ABOUT_SAROPA.md` — accessible from the Overview welcome buttons and command palette

• "Getting Started" walkthrough button in Overview welcome content

• Overview intro text describing the two components (pub.dev package + VS Code extension)

• Version number shown in status bar tooltip for deployment verification

• `precompile` script auto-copies root `ABOUT_SAROPA.md` into extension bundle so the About screen stays in sync with the source of truth

### Changed

• Consolidated three status bar items into one — shows score + tier (e.g. `Saropa: 72% · recommended`), version in tooltip only

• Score display uses `%` format instead of `/100`

• Sidebar views hidden when empty — Issues appears with a Dart project, Config when enabled, Summary/Suggestions/Security Posture/File Risk after analysis has data

• Removed 15 redundant welcome content entries for views now hidden by `when` clauses

• "Learn More" button renamed to "Learn more online" to clarify it opens a website

### Administration

• **CRITICAL** Fixed extension never reaching VS Code Marketplace after v9.0.2 — `run_extension_package()` used `next(glob("*.vsix"))` which returned the stale 9.0.2 `.vsix` (alphabetically before 9.1.0/9.2.0) instead of the newly created one; now deletes old `.vsix` files before packaging and looks for the expected filename first

• Changed extension Marketplace publish prompt default from No to Yes (`[Y/n]`) — previous default silently skipped publishing with no warning

• Replaced misleading "package already published" error messages with clear descriptions of what actually failed

---

## [9.2.0]

Extension reliability and subdirectory project support.

### Fixed

• **IMPORTANT** Fixed YAML corruption in `ensureSaropaLintsInPubspec()` — regex backtracking placed the dependency on the same line as `dev_dependencies:`, producing invalid YAML that caused `dart run saropa_lints:init` to fail on every project

• Fixed `DEFAULT_VERSION` from stale `^8.0.0` to `^9.1.0`

• Fixed `fs` import shadowing in OWASP export handler (dynamic `import('fs')` shadowed static `import * as fs`)

• Fixed `package_config.json` verification to match exact `"saropa_lints"` instead of substring

• Removed unreachable fallback branch in inline annotations path computation

### Added

• Subdirectory pubspec detection — projects with `pubspec.yaml` one level deep (e.g. `game/pubspec.yaml`) are now discovered automatically

• Centralized project root discovery (`projectRoot.ts`) with per-session caching

• Workspace folder change listener invalidates cached project root

• Added `workspaceContains:*/pubspec.yaml` activation event

### Changed

• All 13 source files now use `getProjectRoot()` instead of scattering `workspaceFolders[0]` references

• Line-based YAML insertion preserves original CRLF/LF line endings

---

## [9.1.0]

### Changed

• Welcome views and status bar now detect non-Dart workspaces and show appropriate guidance instead of a misleading "Enable" button

### Removed

• **Logs view:** Removed the Logs panel from the sidebar — it was a file browser for the `reports/` directory, which the built-in file explorer already provides.

---

## [9.0.2]

Sidebar icon refinement.

### Changed

• **Sidebar icon:** Changed activity bar icon from solid fill to wireframe (stroked outline) for consistency with VS Code's icon style.

### Administration

• **Open VSX publish:** The publish script now prompts for an OVSX_PAT when the environment variable is missing, with platform-specific setup instructions, instead of silently skipping.

• **Stale plugin-cache repair:** `dart analyze` failures caused by a stale analyzer plugin cache are now detected automatically. The script offers to update `analysis_options.yaml` and clear the cache in one step.

• **Post-publish version sync:** After publishing, `analysis_options.yaml` plugin version is updated to the just-published version so `dart analyze` resolves correctly.

---

## [9.0.1]

Sidebar polish — fixed the broken activity bar icon, removed repetitive enable buttons, and auto-enabled the extension for existing users.

### Added

• **Auto-enable for existing projects:** The extension now detects `saropa_lints` in pubspec.yaml and enables itself automatically — no manual "Enable" click needed for projects that already depend on the package. New projects still see the welcome prompt.

### Fixed

• **Sidebar icon:** Replaced oversized colorful PNG with monochrome SVG that renders correctly in the VS Code activity bar and respects theme colors.

• **Repetitive enable buttons:** Removed duplicate "Enable Saropa Lints" buttons from Config, Logs, Suggestions, Security Posture, File Risk, and Summary views. The enable button now appears only in Overview and Issues; other views show a text pointer instead.

---

## [9.0.0]

The VS Code extension is now the primary way to use saropa_lints. One-click setup, health scoring, rule triage, inline annotations, OWASP compliance reports, and file risk analysis — all from the sidebar. The CLI remains for CI and scripting but interactive setup has moved entirely to the extension. Run “Saropa Lints: Getting Started” from the command palette to get started.

### Added

• **Health Score & Trends:** 0–100 project quality score in the Overview view and status bar, computed from violation count and impact severity. Color bands (green/yellow/red), score delta from last run, trend tracking over last 20 snapshots, milestone celebrations (50/60/70/80/90), and regression alerts when score drops.

• **Issues & Inline Annotations:** Error Lens-style decorations showing violation messages at the end of affected lines. Issues tree grouped by severity and file with text/severity/impact/rule filters, persistent suppressions, focus mode, group-by presets (Severity/File/Impact/Rule/OWASP), and context-menu quick fixes. Code Lens per file with critical count. Bulk “Fix all in this file” with progress and score delta. “Show in Saropa Lints” from the Problems view.

• **Security Posture:** OWASP Top 10 coverage matrix (Mobile and Web) with violation and rule counts per category. Click to filter Issues. “Export OWASP Compliance Report” generates a markdown report for audits.

• **Triage & Config:** Rules grouped by priority (critical, volume bands A–D, stylistic) with estimated score impact per group. Right-click to disable/enable rules — writes overrides to YAML and re-runs analysis. Packages auto-detected from `pubspec.yaml`. Custom config reduced from ~420 to ~40 lines.

• **File Risk:** Files ranked by weighted violation density — riskiest first. Flame icon for critical, warning icon for high. Summary shows “Top N files have X% of critical issues”.

• **First-run & Welcome:** "Getting Started" walkthrough with guided tour of all features (Health Score, Issues, Security, Triage, Trends, and About Saropa). Score-aware notification after enabling with actionable buttons. Native welcome states on all views when disabled or no data. Analysis auto-focuses Overview to show score delta. Extension report writer logs actions for audit trail.

### Deprecated

• **CLI init interactive mode:** `dart run saropa_lints:init` is now headless-only — defaults to `recommended` tier. Use the VS Code extension for interactive setup. CLI remains for CI/scripting with `--tier`, `--target`, `--no-stylistic`. Removed `--stylistic` (interactive walkthrough) and `--reset-stylistic` flags; use `--stylistic-all` for bulk enable.

### Changed

• **Custom config notice:** `analysis_options_custom.yaml` now includes a prominent "DO NOT EDIT MANUALLY" banner directing users to the VS Code extension for rule overrides.

• **Smart Tier Transitions:** Upgrading to a higher tier auto-filters the Issues view to critical + high violations so users aren't overwhelmed. Notification shows violation delta and "Show All" escape hatch. Tier picker shows rule counts, descriptions, and current-tier marker; same-tier selection is a no-op.

• Progress indicators for Run Analysis, Initialize Config, and Set Tier.

• Debounced refresh (300 ms) on `violations.json` changes.

• Summary view uses stable node IDs for expansion state.

• Status bar update logic consolidated across all command handlers.

### Fixed

• Health Score NaN guard for non-numeric JSON values.

• Run history dedup compares severity breakdown and score, not just total.

• Celebration messages only fire on genuinely new snapshots.

• Snapshot recorded before tree refresh so Overview reads fresh history.

• Inline annotations cache violations data; re-read only on file-watcher change.

• Test runner hanging indefinitely: added global 2-minute timeout (`dart_test.yaml`) and per-test timeouts on integration tests that spawn `Process.run` without a cap.

• Security Posture caches OWASP counts; OWASP filter clears prior filters; ID normalization handles short and long forms; data validation for malformed JSON.

• Output channel uses singleton pattern.

• Tree view fixes: root folder path prefix, severity/impact suppression timing, tier status bar immediate update.

### Administration

• Unified publish script (`scripts/publish.py`) for package and extension; extension version synced with package version.

---

## [8.2.2]

### Changed

• Release version bump

---

## [8.2.0]

### Added

• **Init `--target` flag:** `dart run saropa_lints init --target /path/to/project` generates configuration for any project directory, not just the current working directory.

• **Standalone scan command:** `dart run saropa_lints scan [path]` runs lint rules directly against any Dart project without requiring saropa_lints as a dependency. Reads the project's `analysis_options.yaml` (generated by `init`) to determine which rules to run. Results are written to a report file with a compact summary on terminal.

### Changed

• **Init tool modularization:** Extracted `bin/init.dart` (4,819 lines) into 21 focused modules under `lib/src/init/`, reducing the entry point to 15 lines. No behavior changes.
  - `cli_args.dart` — CLI argument parsing and `CliArgs` class
  - `config_reader.dart` — user customization extraction
  - `config_writer.dart` — YAML generation for `analysis_options.yaml`
  - `custom_overrides_core.dart` — override file creation and settings
  - `display.dart` — ANSI color support and `InitColors` class
  - `init_runner.dart` — main orchestrator (`runInit`)
  - `init_post_write.dart` — post-write phase (ignore conversion, walkthrough, analysis)
  - `log_writer.dart` — `LogWriter` class, report file management
  - `migration.dart` — V4/V7 migration detection and conversion
  - `platforms_packages.dart` — platform and package settings
  - `preflight.dart` — pre-flight environment checks
  - `project_info.dart` — project and package detection
  - `rule_metadata.dart` — rule metadata cache and lookups
  - `stylistic_rulesets.dart` — stylistic rule category data
  - `stylistic_section.dart` — stylistic section builder
  - `stylistic_section_parser.dart` — stylistic section parsing
  - `stylistic_walkthrough.dart` — interactive walkthrough orchestrator
  - `stylistic_walkthrough_prompts.dart` — walkthrough UI prompts
  - `tier_ui.dart` — tier selection UI
  - `validation.dart` — post-write config validation
  - `whats_new.dart` — release notes display (moved from `bin/`)

### Fixed

• **19 false positive bugs fixed across scan rules:**
  - **Self-referential false positives (8 rules):** `avoid_asset_manifest_json`, `avoid_ios_in_app_browser_for_auth`, `avoid_mixed_environments`, `avoid_purchase_in_sandbox_production`, `require_database_migration`, `require_https_only`, `require_unique_iv_per_encryption`, `require_websocket_reconnection` — rules no longer flag their own detection pattern strings in `lib/src/rules/` and `lib/src/fixes/` directories
  - **Flutter-only rules skip non-Flutter projects (5 rules):** `avoid_blocking_main_thread` (-170 FPs), `avoid_print_in_release` (-197 FPs), `avoid_long_running_isolates`, `prefer_platform_io_conditional`, `require_android_permission_request` — rules now check `ProjectContext.isFlutterProject` and skip CLI tools, servers, and analysis plugins
  - **Detection logic improvements (6 rules):** `avoid_api_key_in_code` skips regex patterns; `avoid_catch_all` allows `developer.log(error:, stackTrace:)` defensive catches; `avoid_hardcoded_config` whitelists `pub.dev`/`github.com` URLs; `avoid_parameter_mutation` no longer flags collection accumulator methods (`.add()`, `.addAll()`, etc.); `require_catch_logging` recognizes `developer.log` and `stderr`; `require_data_encryption` checks argument text only (not receiver names)

---

## [8.0.11] and Earlier

For details on the initial release and versions 0.1.0 through 8.0.11, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).

# Changelog

```text
                                    ....
                             -+shdmNMMMMNmdhs+-
                          -odMMMNyo/-..``.++:+o+/-
                       /dMMMMMM/               `````
                      dMMMMMMMMNdhhhdddmmmNmmddhs+-
                      /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/
                    . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+
                    o     ..~~~::~+==+~:/+sdNMMMMMMMMMMMo
                    m                        .+NMMMMMMMMMN
                    m+                         :MMMMMMMMMm
                    /N:                        :MMMMMMMMM/
                     oNs.                    +NMMMMMMMMo
                      :dNy/.              ./smMMMMMMMMm:
                       /dMNmhyso+++oosydNNMMMMMMMMMd/
                          .odMMMMMMMMMMMMMMMMMMMMdo-
                             -+shdNNMMMMNNdhs+-
                                     ``

Made by Saropa. All rights reserved.

Learn more at https://saropa.com, or mailto://dev.tools@saropa.com
```

2300+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTENANCE NOTES -- IMPORTANT --

   Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html). Omit dates from headers; [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays them.

   **Overview** — Every release (and [Unreleased]) opens with a 2–4 sentence user-facing summary. Do not restate the detailed bullets. Banned in the overview: file paths, line numbers, regex snippets, internal flag names, project-specific counts or percentages, and AST or visitor terminology. End with `[log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)` (no preceding line break), substituting the version.

   **Bullet density (HARD RULE)** — Applies to every bullet under `### Added`, `### Changed`, `### Fixed`, `### Removed`, and their `(Extension)` variants. One sentence per bullet, ordered: *what changed → why the user cares → what the user must do* (write "No action required" when true). A second sentence is permitted only when a required user action does not fit in the first. Three-sentence bullets are forbidden — split, or move detail to the commit message, PR, bug report, or code comment, and link out. Concision edits may touch historical sections.

   **Banned inside bullets** (move to commit message, PR, or code comment):
   - **PR archaeology** — prior attempts, rename history, "after X didn't hold". Describe the landed state only.
   - **File-by-file inventories** — that is the git diff.
   - **Test counts** — that is CI output.
   - **Code-internal names** — AST classes, regex flags, function signatures, field or type names, private identifiers.
   - **Bug-report, fixture, or test paths** — commit message footer only.
   - **Decision-making narrative** — one clause of reasoning is fine; a paragraph is not.

   **Maintenance `<details>` bullets** — Same bans apply (no test counts, no file inventories). The what→why→must-do template is optional for infra-only entries.

   **Maintenance section** — Changes with no end-user impact (publish/CI tooling, internal refactors, test harness, plan housekeeping, developer scripts) belong in a collapsed `<details><summary>Maintenance</summary>...</details>` block at the bottom of the version section, never in `### Added` / `### Changed` / `### Fixed`. Test: if a pub.dev or Marketplace user would notice, it is top-level; otherwise Maintenance.

   **Unreleased convention** — The top changelog section MUST use the heading `## [X.Y.Z] — Unreleased` (with ` — Unreleased` suffix) while work is in progress. All new entries go into this ONE section — never create a second unreleased section or bump the version number. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) at publish time via `_strip_unreleased_suffix()`. The version numbers in `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle.

   **Tagged changelog** — Published versions use git tag `vx.y.z`. Each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [16.0.0-beta.3] — Unreleased

Streamlines the extension sidebar, cutting it roughly in half by removing rows that duplicated richer controls already available on the dashboards. The Findings dashboard status line now surfaces trend, regression, and security-hotspot information directly instead of hiding it in a collapsible panel, and the Rules & Tiers config tab adds a Lane switch and a live baseline diff. Also fixes a false positive in the case-sensitive path comparison rule. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.3/CHANGELOG.md)

### Changed

- Sidebar collapsed from 25–39 rows to 13 steady-state (15 worst case). Severity toggles, setting-value rows (run-after-config/dependency, UI language, detected packages), and triage rows removed from the Settings panel — each was a duplicate of a richer control on the Rules & Tiers Automation/Extension tabs, Package Dashboard, or Findings Dashboard's top-rules table. No action required.
- Sidebar Tier and Lane rows folded into the Dashboards "Lints Config" row description (`Tier: recommended · Lane: light`), replacing two click-only rows with always-visible state. No action required.
- Sidebar "Migrate config keys" row now appears only while legacy plugin-block keys remain to clean up, instead of rendering unconditionally. No action required.
- Findings dashboard status line gains trend, regression, and security-hotspot pills — the same data the sidebar Status rows showed, now persistent and clickable instead of buried in a collapsible panel. No action required.
- Sidebar Status section: Hotspots, Trends, Score regression, Suppression count, and Last-run rows removed — all now live on the Findings dashboard's status line or are straight duplicates of Findings data. Health row gains a "Last analysis: {ago}" tooltip. No action required.
- Sidebar Status panel now visible on all Dart projects, not just those with violations — Lint integration status was hidden exactly when it mattered most (integration off = no violations = panel gone). No action required.

### Added

- Rules & Tiers Config file tab: Lane card. Switch between Light (~200 rules in-editor) and Full (all enabled rules) from the same dashboard that already shows every other `analysis_options_custom.yaml` key. No action required.
- Config file tab: the Baseline card now shows a "Diff vs current" subsection listing violations resolved since the baseline and new since the baseline, each with a file/line/rule table. Reads live diagnostics — never triggers a scan and stays current as you edit. No action required.
- Live sidebar badges: the Status view's Activity Bar icon now carries a numeric badge (critical count when any exist, else total violations), and the Dashboards view carries a badge for packages with unadopted features. No action required.
- Rules & Tiers and Project Map dashboards now show a "?" button that opens a list of the tab-jump shortcuts already available (`1`-`7` on Rules & Tiers, `1`/`2` on Project Map) — previously these shortcuts worked but had no in-app way to discover them.

### Fixed

- Fixed `avoid_case_sensitive_path_comparison` false positive on non-string comparisons — null checks, boolean/integer/double/enum guards on path-named variables no longer fire. No action required.
- Sidebar Status panel no longer silently drops the Health row before any analysis has ever run — it now shows a "Health: —" row explaining why, with a one-click link to run analysis. No action required.
- Fixed LSP server crash on startup in large projects — the Dart VM exhausted its OS thread pool when the workspace scan called `lastModifiedSync` / `listSync` on hundreds of files. Replaced sync I/O with batched async equivalents (capped at 20 concurrent file operations) and added error handlers so failures exit cleanly instead of triggering an infinite restart loop. No action required.

<details><summary>Maintenance</summary>

- Fixed 15 pre-existing extension test failures: added missing `onDidChangeConfiguration` mock (13 issuesTree tests), updated stale locale coverage assertions (languagePick), and updated sidebar panel count from 5 to 4 after Help view removal (uxLabels). No action required.
- Updated stale path reference in the UI redesign plan after archiving completed sub-plans. No action required.
- Package Dashboard (Overview and Upgrades tabs): now pulls its color/spacing/radius design tokens from the same canonical token layer already used by the Settings and tab-bar surfaces, instead of only the legacy report stylesheet. No visible change — additive groundwork for retiring the older parallel styling system.
- l10n diagnostics now recognize `// l10n:passthrough` on the same line as a suppress directive for calls whose `{placeholders}` are substituted by caller code (e.g. `pluralize()`) rather than by `l10n()` itself. Annotated all existing `pluralize()`+`l10n()` call sites. No action required.
- Removed `transformProjectMapHtml()` and `webviewThemeOverride()` from `projectMapView.ts` — dead since the standalone Project Map panel switched to the composed `projectMapShell.ts` document in Phase 6; their only remaining reference was a historical code comment.
- Added unit test coverage for `projectMapShell.ts` (shell tab structure, scanning-state pane, done-state pane) and `projectMapReports.ts` (report-card catalog, Reports tab HTML, quality-gate config read/write, panel-message routing) — both had zero tests before this pass.

</details>

---

## [16.0.0-beta.2]

Fixes the VS Code pre-release install button and removes a publish-time blocker that stalled builds. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.2/CHANGELOG.md)

### Changed

- Sidebar: "Lint integration" is now one row in the Status section that toggles on a single click, instead of two separate copies of the same state in different panels. No action required.
- Sidebar: "Find stale ignores" and "Fix stale ignores" merged into one row that detects, shows the count, then asks to confirm before removing anything. No action required.
- Sidebar: Analysis Optimizer, Upgrade Opportunities, and the Feature Inventory export are no longer separate Dashboards rows — each is reachable as a tab inside Rules & Tiers or the Package Dashboard. Command Catalog moved next to Run analysis and Fix stale ignores. No action required.
- Sidebar: "Engines (LSP / Analyzer)" and "Process health" rows — announced in beta.1 — removed from the Settings panel. Engine toggles remain accessible from the Status section's Engines row (visible when debug mode is on), Health Panel, and Command Catalog. No action required.

### Fixed

- Fixed VS Code "Switch to Pre-Release Version" button failing with `net::ERR_FAILED` — pre-release extension versions now use an odd minor number as VS Code requires.
- Fixed status-bar click behavior: beta.1 stated clicking while lint integration is off opens the Dashboards view — it actually opens Findings in every state (`extension.ts:1310`). The click target is intentionally Findings regardless of integration state. No action required.
- Fixed CI watch blocking publish by defaulting to skip (press `y` to opt in).
- Fixed the status bar cramming memory/system-health warnings into the same text as the lint score, with no way to click through to the details — split into a second status bar item that only appears when there's something to report and opens the Process Health panel on click. No action required.
- Fixed the status bar's hover tooltip being read-only text with no way to act on it — it's now a clickable menu (toggle analysis on/off, jump to the Violations Report, Package Dashboard, Process Health, Command Catalog, or About). No action required.

<details><summary>Maintenance</summary>

- Fixed publish script writing raw pub.dev version to `package.json` instead of the converted extension version — caused preflight version check to fail on every pre-release publish.
- Hardened publish version verification: `_is_head_pushed()` now handles detached HEAD and unreachable remote, `_verify_versions_in_commit` docstring documents that it runs after HEAD is pushed (step 13 after step 12), and `extension_version_for()` idempotency contract is explicit.
- Added `--dry-run` mode to `set_extension_version()` — returns the converted extension version without touching the file, useful for preflight checks that need the expected version without side effects.
- Extracted the status bar tooltip's action-menu rows (`buildStatusBarMenuItems`) and its command allow-list (`STATUS_BAR_TRUSTED_COMMANDS`) into `statusBarLabel.ts`, with a unit test asserting every row's command id is covered by the allow-list — a renamed or added command that falls out of sync would previously break the tooltip link with no test failure.

</details>

## [16.0.0-beta.1]

*--- IMPORTANT NOTE ---*

**Major release — LSP server (BETA).** The new standalone LSP server replaces the in-process analyzer plugin as the default diagnostic engine. It runs in its own process, consuming a fraction of the RAM the plugin needed, and delivers diagnostics, quick fixes (lightbulb menu), and per-rule config overrides without loading the full analyzer into the IDE's analysis server. The LSP server is now **ON by default** — review its status in the Health Panel (Command Palette → "Saropa Lints: Process Health"). This is a BETA feature: if you encounter issues, toggle "LSP Server" OFF in the Health Panel and re-enable the Analyzer Plugin. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.1/CHANGELOG.md)

### Fixed

- **Auto-migrate legacy plugin-block config keys.** Projects with `log_level`, `lane`, `memory_mode`, or `rule_packs` under `plugins > saropa_lints:` in `analysis_options.yaml` triggered `unsupported_option` warnings that were fatal under `--fatal-warnings`, breaking CI. The plugin now auto-migrates these keys to `analysis_options_custom.yaml` at load time — no manual action required.
- **LSP server: fix 0 diagnostics on opened files.** The CLI scanner's built-in path exclusions (which drop `example/`, `bin/`, generated files) were silently filtering out files the user opened in the editor, producing 0 diagnostics. The LSP server now bypasses scan exclusions since the user explicitly requested analysis by opening the file, and falls back to the `recommended` tier when the project has no `saropa_lints: tier:` shorthand.
- **LSP server: fix didOpen flood.** VS Code sends `textDocument/didOpen` for every Dart file in the workspace on activation (~200+ for real projects), each triggering a full rule scan. The server now debounces didOpen — only the last file opened within a 1.5-second window gets analyzed. The extension also filters didOpen to only forward files in visible editors. Save still triggers immediate analysis.
- **LSP server: message queue resilience.** A malformed or unexpected JSON-RPC message could crash the async queue processor, silently dropping all subsequent messages. Each message is now handled in its own try-catch so one bad message doesn't stall the server.
- **LSP server: Windows CRLF config parsing.** The tier config reader failed to match `tier:` when `analysis_options.yaml` had Windows `\r\n` line endings with lines between `saropa_lints:` and `tier:`. Line endings are now normalized before parsing.
- **Debug panel: analyzer toggle restores extension setting.** Toggling the Analyzer Plugin OFF correctly set `saropaLints.enabled = false`, but toggling it back ON never restored the setting — the extension stayed disabled until manually re-enabled in VS Code settings. No action required.
- **`avoid_platform_channel_on_web`: false positive with early-return guards.** The rule fired on `MethodChannel(...)` even when preceded by `if (kIsWeb) return;` or `if (kIsWeb) throw ...;`, because it only recognized platform checks that *wrapped* the node as an ancestor, not preceding sibling guard statements. No action required.
- **`no_direct_iterable_access`: fixed off-by-one false negative and hardened guard detection.** `index <= list.length` was wrongly accepted as a sufficient bounds guard even though `index == list.length` still throws; only `<` is now accepted. The rule also now recognizes the early-return guard-clause idiom (`if (index >= list.length) return;`), `else`-branch guards, reversed comparisons (`list.length > index`), `RangeError.checkValidIndex(index, list)`, collection-`for` elements, and typed-data lists (`Uint8List` and friends), closing several false-positive/false-negative gaps in the initial implementation. No action required.
- **Dashboard contrast and a11y fixes.** A new visual-regression pass (rendering Home, Rules & Tiers, and Project Map through the extension's Playwright a11y harness for the first time) found and fixed real WCAG AA contrast failures: the red "Cancel" button, table column headers, the Rules & Tiers tier picker, and the Home hub's "needs attention" KPI tiles all read below the 4.5:1 contrast floor in at least one theme. Also fixed a missing accessible name on the Config file tab's severity-level dropdown, a missing document language attribute on the Rules & Tiers dashboard, and a narrow-window layout bug where the tier picker's pill buttons could push the whole dashboard into horizontal scroll. No action required.
- **Full Audit report contrast fixes.** Migrating the Full Audit report onto the shared dashboard chrome (below) gave it its first-ever visual-regression pass, which caught severity badges and KPI chips rendering colored text/fills as low as 2.93:1 contrast — now fixed to clear the 4.5:1 AA floor in every theme. No action required.
- **Sidebar Status and Home hub KPIs could show "All clear" while the Problems panel had real findings.** The sidebar's Status section and Home hub's issue count/health tiles read `reports/.saropa_lints/violations.json`, a file only written by an explicit scan — so a project with the LSP server running (default since this release) and real diagnostics visible in the Problems panel could still show "No violations" if no scan had ever been run. Both now read the same live diagnostics the status bar and Issues tree already use, so they can no longer disagree with the Problems panel. The health score keeps using the last scan's file-count denominator (there's no equivalent from live diagnostics alone) so its coverage caveat is unchanged — only the violation counts and the score's numerator are now always current.
- **Sidebar Settings rows had no icons.** Every row in the Settings panel (Lint integration, Analyzer plugin, Tier, Lane, Run-analysis toggles, UI language, Detected, config actions, dashboard shortcuts) rendered with no icon at all, unlike every other panel — a wall of unlabeled text. Every row now has a distinct icon. Also adds an "Engines (LSP / Analyzer)" row so the Analyzer Plugin/LSP Server/Scan Daemon toggles (Health Panel) are reachable from the sidebar instead of Command Palette only.

### Changed

- **LSP server is now ON by default (BETA).** New installations start with `saropaLints.lspServer.enabled: true`. The analyzer plugin is automatically disabled when the LSP server is on — it's no longer needed and its ~10GB RAM footprint is eliminated. Turning the LSP server off re-enables the analyzer plugin. To revert: toggle "LSP Server" OFF in the Health Panel, or set the setting to `false` in VS Code workspace settings.
- **Sidebar: severity toggles are single-click; Diagnostics and Help panels folded away.** The Show errors/warnings/infos/hints rows previously required an undiscoverable double-click; they now toggle on a single click. The standalone Diagnostics panel (severity toggles, Lint integration, Analyzer plugin, Tier) merged into the Settings panel, and the standalone Help panel (Getting Started, About, pub.dev, AI agent instructions) moved into the Dashboards panel's "..." menu. Clicking the status bar while lint integration is off now opens the Dashboards view instead of doing nothing.
- **Debug Panel merged into the Health Panel.** The sidebar's standalone Debug Panel (engine toggles, PID/RSS, Kill All / Restart All, log) is gone — that content now lives inside "Saropa Lints: Show Process Health" alongside the Dart process table, so engine controls and process diagnostics are in one place instead of two. The engine log is now a collapsed-by-default expander. The sidebar container is down to 4 panels total (from 7).
- **"Saropa Dashboards" home hub removed.** It duplicated the sidebar and each dashboard's own settings without adding anything a dashboard couldn't already show — the status bar and every former "Saropa Dashboards" link now open Findings instead.
- **Package dashboard command palette decluttered.** 38 of the 63 `Saropa Lints: Package...` commands (row-argument actions like "go to package", "suppress package", bulk major/minor/patch updaters, and niche registry-auth setup) no longer show in the Command Palette — they still work exactly as before from the dashboard's buttons, CodeLens, and context menus, which is how they were actually used. The palette now shows 25 general-purpose package commands instead of 56.

### Added

- **Sidebar Status section: Engines row.** Shows "Engines: N running" with a one-line summary of the Analyzer Plugin, Scan Daemon, and LSP Server's live status, right below Health — click to open the Health Panel. Turns amber when zero engines are running, so a fully-off diagnostics setup is visible without opening the panel. Previously this state was only visible by opening the panel itself. No action required.
- **Package dashboard: tabs and an in-dashboard Settings form.** The Package Dashboard now has a tab bar (Overview · Upgrades · Full report · Known issues · Compare · Settings). Upgrades, Full report, Known issues, and Compare open their existing panel with one click from inside the dashboard instead of only being reachable as separate sidebar rows. The new Settings tab renders every `packageVibrancy.*` setting as a grouped form (Access, Scan, Display, Score Weights, Upgrade, Watch, Budget, Vulnerabilities) that writes straight to your workspace settings — the 7 dependency-budget limits are one "Budget" card instead of 7 separate settings.
- **LSP server: quick fixes (lightbulb menu).** `textDocument/codeAction` now returns real quick fixes for rules that have fix generators. The server resolves the file, instantiates the rule's `SaropaFixProducer`, and returns workspace edits — same fixes the native plugin offers, without the in-process memory cost. No action required.
- **LSP server: per-rule config overrides.** The server now reads per-rule enable/disable from both `analysis_options.yaml` (`diagnostics:` section) and `analysis_options_custom.yaml` (`severities:` section), layered on top of the tier. Rules the user disabled stay off; rules they enabled run even if the tier wouldn't include them.
- **Health Panel: every engine and action now has a description.** The Analyzer Plugin, Scan Daemon, and LSP Server cards each show a one-line "what this does" subtitle. Kill All and Restart All show what they actually affect — both currently control the LSP Server only; the Analyzer Plugin and Scan Daemon each have their own ON/OFF toggle.
- **Debug panel: all three engine toggles now work.** The "Analyzer Plugin" card's ON/OFF buttons previously did nothing — only the LSP Server card was wired up. Toggling the analyzer card now runs the same enable/disable mechanism as the "Lint integration" sidebar toggle, and the card reflects the real on-disk state instead of always showing "active". The Scan Daemon toggle now suspends/resumes the daemon process. The LSP Server toggle persists to `saropaLints.lspServer.enabled` in settings. All toggles log their action to the debug panel's LOG section for immediate user feedback.
- **LSP server: live config reload.** `workspace/didChangeConfiguration` now re-reads the tier from `analysis_options.yaml` and re-analyzes every file with published diagnostics, so editing per-rule overrides or the tier takes effect immediately instead of requiring a server restart.
- **LSP server: full workspace scan on startup with incremental re-scan.** After the analyzer warms up, the server scans all Dart files project-wide so diagnostics appear in the Problems panel without opening every file. Subsequent re-scans (e.g. after a config change) are incremental — only files modified since the last scan are re-analyzed. Which directories are scanned and whether the scan runs at all are configurable via `saropaLints.lspServer.scanDirectories` and `saropaLints.lspServer.workspaceScan` in VS Code settings.
- **Project Map dashboard: live scan + a Reports tab for 7 CLI tools.** The Project Map panel now opens immediately with a live activity log and a working Cancel/Restart, instead of freezing until the whole scan finishes. A new Reports tab adds a Run button for every `saropa_lints` report CLI that previously had no UI at all — Severity Report, Impact Report, Quality Gate (with an inline editor for `saropa_quality_gate.yaml`), Stub Test Report, Accuracy Report, Memory Report, and Doctor — each streaming its output live and saving a copy under `reports/.saropa_lints/reports-tab/`.
- **Rules & Tiers dashboard is now the full config surface, with 7 tabs.** The dashboard (formerly "Lints Config") is now organized as Tier · Rule packs · Overrides · SDK rollout · Config file · Automation · Extension. The new **Config file** tab adds a control for every `analysis_options_custom.yaml` key that previously had no UI — `max_issues`, `output`, `platforms`, `severities`, `banned_usage`, `saropa_tier`, `runtime_tier`, and `diagnostic_statistics` thresholds — plus a Baseline card (create/refresh, with the current baseline rendered as a table) and the Analysis Optimizer embedded as a live tab (its standalone command still opens it in its own editor tab). The new **Automation** and **Extension** tabs render every remaining `saropaLints.*` setting (outside the Package/Code Health/TODO/Drift groups, which keep their own settings surfaces) as a live control, read directly from the extension's manifest so a setting added later appears automatically. The Disabled rules section moved from the old dashboard into this one's Overrides tab. Editing `analysis_options_custom.yaml` in another editor now refreshes this dashboard automatically if it is open.
- **Packages and Project Map dashboards: number-key tab shortcuts.** Pressing `1`-`6` on the Package Dashboard, or `1`/`2` on Project Map, jumps straight to that tab — matching the shortcut Rules & Tiers already had. Ignored while typing in a search box or form field.
- **19 new tier-1 quick-win lint rules.** No action required.
  - `avoid_disposing_late_fields` flags `.dispose()` on conditionally-initialized `late` fields (Recommended).
  - `avoid_dynamic_calls_extended` catches method/property/index access through resolved `dynamic` (Recommended). Named `_extended` — `avoid_dynamic_calls` is a core Dart analyzer lint name.
  - `avoid_equals_and_hash_code_on_mutable_classes_extended` prevents `==`/`hashCode` overrides on classes with non-final fields (Essential). Named `_extended` — the base name is a core Dart analyzer lint name.
  - `avoid_futureor_return_type` flags `FutureOr<T>` as a declared return type (Recommended).
  - `avoid_implementing_value_types_extended` catches classes that `implements` a known value-equality type (Comprehensive). Named `_extended` — the base name is a core Dart analyzer lint name.
  - `avoid_mounted_check_in_finally` flags `mounted` guards inside `finally` blocks (Recommended).
  - `document_enum` requires doc comments on public enums and enum values (Pedantic).
  - `duplicate_value` detects repeated sub-expressions in boolean chains (Recommended).
  - `getters_in_member_list` flags getters declared after behavior members (Pedantic).
  - `initializers_ordering` enforces field-declaration order in constructor initializer lists (Pedantic).
  - `is_future` catches runtime `x is Future` type checks (Recommended).
  - `mutable_tearoff` flags method tear-offs from non-final fields (Professional).
  - `named_parameters_ordering` enforces declaration-order named arguments at call sites (Pedantic).
  - `never_discard_build_context` catches unused `BuildContext` params in builder callbacks (Recommended).
  - `new_instance_cascade` suggests cascades for consecutive statements on a freshly-created instance (Pedantic).
  - `no_direct_iterable_access` flags `list[i]` index access without a bounds guard (Professional).
  - `prefer_typed_exceptions` catches `throw` of raw String/non-Exception values (Comprehensive).
  - `specify_unknown_enum_value` requires `unknownEnumValue` on `@JsonSerializable` enum fields (Comprehensive).
  - `use_compare_without_case` flags `toLowerCase() ==` patterns that should use `compareTo` (Pedantic).

<details>
<summary>Maintenance</summary>

- Extended the extension's Playwright visual-regression harness (`test/ux/generate-pages.ts`) to render the Home hub, two Rules & Tiers tabs, and both Project Map states, which previously had no rendered-HTML coverage at all. Added a `vscode.extensions.getExtension` stub to the shared test mock so the Rules & Tiers dashboard's manifest-driven settings tab can render outside a real VS Code host.
- **Style-system migration: Full Audit report.** `audit/audit-report-styles.ts` now builds on `getDashboardChromeStyles()` (`.dash-hero`, `.chip-strip`/`.chip`, `.toolbar-band`/`.field`, `.btn`, `.dash-table`, `.empty-cta`) instead of a fully bespoke stylesheet — one of the three remaining parallel CSS systems the redesign plan re-deferred at Phases 5 and 7 (`plans/PLAN_extension_ui_redesign.md` §1.5). Only severity-tinted pills, baseline badges, and the deferred-load banner remain bespoke. Added the first-ever `audit-report` fixture to the Playwright UX harness. No markup IDs or client-script selectors changed, so `audit-report-script.ts` needed no edits.
- **Style-system migration: Findings dashboard.** `violationsDashboardStylesParts.ts` now builds on `getDashboardChromeStyles()` instead of a fully bespoke stylesheet — the second of the three parallel CSS systems the redesign plan re-deferred (`plans/PLAN_extension_ui_redesign.md` §1.5). The file shrank from 1337 to a much smaller "extras" sheet carrying only what the shared chrome doesn't cover (severity-tinted pills, the hero gauge's `animation: none !important` override so the chrome's shared entrance keyframe doesn't play on this dashboard's rebuilds). One remaining parallel system (`vibrancy/views/report-styles-parts.ts`, the Package Dashboard) is still deferred.
- Added a `vscode.languages.getDiagnostics` stub to the shared test mock (`test/vibrancy/vscode-mock.ts`) — the sidebar's live-diagnostics fix (above) calls it by default, and the mock's absence was silently breaking sidebar unit tests that don't care about diagnostic content.
- **New `scripts/check_rule_name.py`.** Checks a proposed rule name against the core Dart/Flutter analyzer lint namespace in one second, before any implementation work begins. The same collision gate (`_tier_integrity.py` Check 8) caught 3 rules that needed renaming at publish time three days running (2026-09-02, 2026-09-03, 2026-09-04) — each time meaning a rename across `lib/`, `test/`, and `example/` after the fact. Wired into the rule-authoring checklist (`.claude/skills/lint-rules/SKILL.md`, `CLAUDE.md`) as step 0.
- Extended `scripts/fix_ignores.py`'s rename map with the 3 rules renamed 2026-09-04 (`avoid_dynamic_calls`, `avoid_equals_and_hash_code_on_mutable_classes`, `avoid_implementing_value_types`, all now `_extended`), and fixed the corresponding stale "N/A (stock analyzer rule)" rows in `doc/guides/migration_guides/migration_from_vga.md` to `ENHANCED`.
- `scripts/publish.py` now routes a prerelease version (e.g. `16.0.0-beta.1`, the version this release ships as) to each store's prerelease channel automatically — `vsce package`/`publish`, `ovsx publish`, and `gh release create` all get their prerelease flag derived from the version string, no separate flag or prompt needed. `extension/package.json`'s `version` field, which the Marketplace requires to be a plain `MAJOR.MINOR.PATCH` (no hyphen, even with `--pre-release`), is instead derived via `extension_version_for()`: the stripped core PATCH offset by a channel- and iteration-specific band, so successive beta/rc builds of the same base version get distinct extension versions instead of colliding at the Marketplace/Open VSX level. The `.vsix` filename and store-verification poll stay consistent with whichever version was actually published.

</details>

---

## [15.2.12]

Hardens the LSP server against normal editor traffic and adds a `doctor` command to catch misconfigured project settings before they cause confusing warnings. [log](https://github.com/saropa/saropa_lints/blob/v15.2.12/CHANGELOG.md)

### Fixed

- **LSP server handles all standard notifications without crashing.** Added explicit no-op cases for `textDocument/didChange`, `$/cancelRequest`, `$/setTrace`, and `workspace/didChangeConfiguration` so the inert server stays alive under normal VS Code traffic. Two-level logging surfaces server activity in the Output channel: lifecycle events always log, high-frequency messages (didChange, codeAction) are suppressed unless `$/setTrace` is set to `verbose`. No action required.

### Added

- **New `doctor` command** scans consumer project configuration for misplaced keys, missing custom file, and other issues that produce SDK warnings. Run `dart run saropa_lints doctor [directory]`.
- **`--trace` flag for LSP server** enables verbose logging from startup without waiting for the editor to send `$/setTrace`. Useful for standalone debugging: `dart run saropa_lints:lsp_server --trace`.

<details>
<summary>Maintenance</summary>

- Pre-commit hook now auto-regenerates category map and migration pack codes when rule files, tier definitions, or migration guides change — eliminates the recurring CI failures from stale generated indexes.
- Closed `unsupported_option` bug for `rule_packs` and `log_level` — investigation confirmed the fix was already implemented; consumer projects just need to run `dart run saropa_lints migrate-config`.
- `migrate-config` now removes orphan `rule_packs:` keys that have no `enabled:` child, and handles trailing comments on the key line.
- Config parser (`_leadingSpaces`) now counts tabs as indentation, matching the scalar parser — fixes silent parse failures on tab-indented YAML.
- `doctor` command now scopes key detection to the `saropa_lints:` plugin block — no longer false-positives on identically named top-level keys.
- Publish script supports `--log-file`, `--log-append`, `--mode`, `--auto-retry`, and `--output-level` flags for non-interactive/CI execution. Auto-detects non-TTY stdin. Mode definitions are unified in a single table driving both CLI and interactive menu.

</details>

---

## [15.2.11]

Removed Phase 0 fake LSP test diagnostics that shipped in 15.2.10. The standalone LSP server infrastructure remains (off by default) but no longer emits test squiggles. [log](https://github.com/saropa/saropa_lints/blob/v15.2.11/CHANGELOG.md)

### Fixed

- **LSP server no longer emits fake test diagnostics.** Phase 0 proof-of-concept diagnostics were being published to every open `.dart` file when the LSP server was enabled. No action required — the setting now defaults to off.

### Changed

- **`saropaLints.lspServer.enabled` now defaults to `false`.** Previously defaulted to `true`, which activated the fake LSP server for all users. No action required.

<details>
<summary>Maintenance</summary>

- Regenerated category map and migration pack codes for 18 new rules added in 15.2.10 that were missing from the generated indexes.

</details>

---

## [15.2.10]

> **Known issue:** This release shipped `saropaLints.lspServer.enabled` defaulting to `true`, causing fake test diagnostics to appear in every open `.dart` file. Update to 15.2.11 immediately.

Seventeen new lint rules across testing, equality, control flow, constructor style, widget lifecycle, formatting, code quality, documentation, and architecture. Cross-platform SARIF output fix, dead-link hardening for published docs, and orphan-publish recovery for the publish script. [log](https://github.com/saropa/saropa_lints/blob/v15.2.10/CHANGELOG.md)

### Fixed

- Fixed SARIF writer emitting `../C:/project/...` URIs on Linux CI — switched from `p.relative()` to prefix stripping after forward-slash normalization so Windows-style paths resolve correctly cross-platform.
- Fixed broken links in `README.md` and `doc/README.md` to removed guide files (`upgrading_to_v7.md`, `migration_v4_to_v5.md`).
- Fixed wrong relative path in `using_with_flutter_lints.md` link to VGA migration guide.
- Fixed `always_put_doc_comments_before_annotations` false-negative — the old token-walking detection assumed `documentationComment == null` for misplaced comments, but the analyzer populates it regardless of position. Replaced with offset comparison against the first annotation.

### Added

- New rule `avoid_focused_tests` (Essential) — flags `test()`/`group()` calls with `solo: true` left in committed code, which silently skips the rest of the suite in CI.
- New rule `avoid_exit_outside_entrypoint` (Recommended) — flags `exit()` calls outside the top-level `main()` function, which kill the process bypassing cleanup and `finally` blocks.
- New rule `avoid_labeled_statements` (Comprehensive) — flags labeled statements (`label: for/while/switch`) that force readers to track names across nested blocks instead of reasoning locally.
- New rule `avoid_null_checks_in_equality_operators_extended` (Recommended) — flags dead `other == null` checks inside `operator ==` overrides under sound null safety. Named with `_extended` suffix to avoid collision with the core Dart lint.
- New rule `avoid_unnecessary_else_after_control_flow` (Recommended) — flags `else` blocks after `if` bodies that end with `return`, `throw`, `break`, or `continue`.
- New rule `prefer_initializing_formals_extended` (Comprehensive) — flags constructor body assignments that could be `this.param` initializing formals. Named with `_extended` suffix to avoid collision with the core Dart lint.
- New rule `avoid_skipped_tests` (Recommended) — flags `test()`/`group()` calls with `skip: true` or a skip message left in committed code.
- New rule `no_optional_operators_in_tests` (Comprehensive) — flags `?.` and `??` operators in test files that silently swallow failures.
- New rule `avoid_public_members_in_states` (Recommended) — flags public fields and methods in `State` subclasses that leak internal state as public API.
- New rule `prefer_blank_line_before_break` (Stylistic) — requires a blank line before `break` in multi-statement blocks for visual separation.
- New rule `prefer_blank_line_before_continue` (Stylistic) — requires a blank line before `continue` in multi-statement blocks.
- New rule `prefer_blank_line_before_throw` (Stylistic) — requires a blank line before `throw` statements in multi-statement blocks.
- New rule `avoid_unnecessary_parentheses` (Comprehensive) — flags redundant parentheses that don't change evaluation order or precedence.
- New rule `always_put_doc_comments_before_annotations` (Recommended) — flags `///` doc comments placed after annotations instead of before, which breaks dartdoc association.
- New rule `start_comments_with_space` (Pedantic) — flags `//comment` missing a space after the slashes.
- New rule `constructor_parameters_and_fields_should_have_the_same_order` (Comprehensive) — flags constructors where parameter order doesn't match field declaration order.
- New rule `todo_with_story_links` (Professional) — flags TODO/FIXME comments lacking an issue tracker reference.
- New quick fix for `always_put_doc_comments_before_annotations` — auto-moves misplaced `///` doc comments above all annotations with correct indentation. Supports bulk "Fix All" application across files.
- New rule `prefer_doc_comment_after_annotations` (Stylistic) — inverse of `always_put_doc_comments_before_annotations`, for teams that prefer `///` doc comments adjacent to the declaration keyword rather than above annotations. Registered as a conflicting pair. Includes quick fix with bulk "Fix All" support.

<details>
<summary>Maintenance</summary>

- Added doc-link validation to `.githooks/pre-commit` — broken or excluded-path links in shipped docs are now caught before commit, not just in CI.
- Publish script now detects orphaned version bumps from aborted publishes at startup and offers to reset versions, preventing cascading state corruption.
- New publish mode **9) Pub.dev only** — runs the full publish pipeline (audit, format, analyze, tests, version, commit, tag, pub.dev publish, GitHub release) but skips all extension packaging and Marketplace/Open VSX publishing. Use when the VSIX was already published separately or when only the Dart package needs a release.
- Fixed `--fail-on error` scan test failing when error-level diagnostics exist in the fixture — test now uses `--fail-on-count 9999` to decouple exit-code assertion from project error count.
- Fixed CI failure: `.pubignore` now excludes `doc/guides/migration_guides/` so shipped docs no longer contain dead links to `.pubignore`-excluded `plans/` proposals.
- Fixed `check_doc_links_excluded_paths.py` not filtering out source docs that are themselves `.pubignore`-excluded — the script now skips docs under excluded prefixes instead of scanning them for link targets.
- New `scripts/fix_ignores.py` migration tool rewrites stale `// ignore:` comments and `analysis_options.yaml` rule names from pre-rename saropa_lints rule names to their current `_extended`/`_strict`/`_with_fix` equivalents. Run `python scripts/fix_ignores.py <dir>` (dry run) or `--apply` to rewrite.
- Publish audit now checks `CORE_DART_LINT_NAMES` freshness against the live Dart SDK linter — warns (non-blocking) if the reference set is stale.
- New `test/integrity/core_lint_collision_test.dart` catches rule name collisions with core Dart lints during `dart test`, not only at publish time.

</details>

---

## [15.2.9]

The system health monitor now separates memory used by Saropa Lints from the total across all Dart processes, so users can see the real footprint instead of being blamed for the entire analysis server. The scan daemon auto-suspends under heavy memory pressure to reclaim its analyzer cache, and orphaned scan daemons are now detected and cleaned up alongside Flutter daemons. A new Full Audit command scans a project against every rule regardless of its configured tier and opens the results in a filterable report panel. [log](https://github.com/saropa/saropa_lints/blob/v15.2.9/CHANGELOG.md)

### Added

- New Full Audit command scans a project against every lint rule regardless of the configured tier — choose the whole project, only changed files versus a branch, or a comparison against a saved baseline. Results open in a dedicated report panel with tier/severity/category filters, search, file grouping, and a "Copy JSON" export. Run it from the Explorer context menu ("Saropa: Audit Folder...") or the audit icon in the dashboards sidebar.
- Full Audit supports `--format sarif` for SARIF 2.1.0 output, so results can feed GitHub code-scanning annotations directly on a PR diff — particularly useful combined with `--since <ref>`.
- Status bar tooltip now shows Saropa Lints process count and memory separately from the system-wide Dart total — no more blaming the extension for the entire analysis server. No action required.
- Scan daemon auto-suspends when memory-pressure shedding reaches level 2+ (most rules shed), reclaiming the daemon's warm analyzer cache; resumes automatically when pressure drops. No action required.
- Orphaned scan daemon detection — scan daemons left running after a VS Code crash are now identified and included in the Clean Up command alongside Flutter daemons. No action required.
- Health panel marks Saropa Lints processes with a "Saropa" type pill so they are visually distinct from analysis servers and other Dart processes. No action required.
- Standalone LSP server infrastructure (Phase 0) — proves two LSP servers coexist in the same VS Code Problems panel. **Bug:** `saropaLints.lspServer.enabled` shipped defaulting to `true`, causing fake test diagnostics to appear in every open `.dart` file. Fixed in 15.2.11 — setting now defaults to `false` and test diagnostics have been removed.
- Debug Panel sidebar — shows status and toggle controls for all three diagnostic engines (Analyzer Plugin, Scan Daemon, LSP Server) with PID, rule count, RSS, and a live log tail. **Bug:** Debug panel was enabled by default, which also activated the LSP server toggle. Disable via `saropaLints.debug.enabled` if not needed.
- Migration packs for 24 alternative lint packages — when a project still depends on an alternative (e.g. `pyramid_lint`, `solid_lints`, `dcm`), the extension surfaces a "Migrate from …" pack in the Rule Packs dashboard that enables all equivalent saropa rules in one click. No action required.

### Fixed

- Fixed double-unescape vulnerability in pub.dev changelog entity decoder — `&amp;lt;` was incorrectly decoded to `<` instead of the literal `&lt;` (CodeQL #19, CWE-116).
- Fixed case-insensitive script-tag matching in snapshot harness so upper-case `<SCRIPT>` tags are normalized correctly (CodeQL #20).
- Status bar warning/critical suffix now shows Saropa Lints RSS when available instead of the misleading system-wide total. No action required.
- Fixed 12 rule files (28 rule classes) that accessed `.constructorName.type.element` without declaring `usesTypeResolution => true` — these rules silently produced zero findings in the light analysis lane. The integrity test now detects this access pattern.
- Fixed Full Audit showing a confusing second "output could not be read" error after canceling an audit — the forced process-tree kill on cancel could still fire a late completion event with truncated output.
- Fixed Full Audit cancellation silently failing to stop the underlying `dart` process on macOS/Linux — the audit CLI kept running in the background after the "Audit canceled" toast, because killing the shell process alone (with `shell: true`) doesn't reach its `dart` child on POSIX.
- Fixed Full Audit accumulating a temp file per run for large (>10MB) result sets with no cleanup, and silently swallowing a temp-file write failure instead of warning the user.
- Fixed accuracy report and audit CLI showing most rules as silent — the Problems-tab issue cap (500) was silently dropping diagnostics before they reached the listener. Added `disableIssueCap` parameter to `ScanRunner` so batch CLI tools opt out of the IDE cap at construction, rather than each caller needing to know about `ProgressTracker`.
- Fixed LSP server failing to spawn on Windows — `dart.bat` requires `shell: true` for PATHEXT resolution, matching the convention used by every other dart spawn in the extension.
- Fixed fake LSP test diagnostics inflating the real score — changed the diagnostic source to `saropa_lsp_test` and added a source filter in `liveDiagnosticsModel` so status bar, Issues tree, and dashboard ignore them.
- Fixed stop/dispose race when toggling the LSP server setting — `dispose()` was called before `stop()` completed, causing a double-stop. Now awaits stop before dispose.
- Wired Kill All / Restart All buttons in the Debug Panel — previously they were rendered but nothing subscribed to the click events.
- Replaced hardcoded English engine names and status words in the Debug Panel with `l10n()` calls — added explicit `key` field to `EngineStatus` so toggle messages don't depend on locale-sensitive substring matching.
- Removed hand-typed rule counts (203, 2140) from the Debug Panel engine status — these drifted as rules were added. The LSP server retains its fixed count of 4 (the actual test diagnostic count).
- Fixed 4 migration packs that had drifted from their source guides: `migrate_dcm` was missing 9 documented rules and carried one typo'd rule name that never matched anything; `migrate_dart_code_metrics_presets` was missing 1 rule; `migrate_dart_code_linter` and `migrate_awesome_lints` each carried rules not backed by any guide row. Enabling these packs previously gave less (or, for the typo, slightly wrong) coverage than the migration guide promised.
- Fixed 5 migration guides (`dcm`, `dart_code_linter`, `pyramid_lint`, `mad_lint`, `solid_lints`) that mapped a source rule to a saropa Dart *class* name (`NewlineBeforeReturnRule`) or a rule that never existed (`avoid_magic_numbers`) instead of the real rule codes (`prefer_blank_line_before_return`, `no_magic_number`). Every affected migration pack was silently missing that rule's coverage — the phantom code matched nothing.
- Fixed `many_lints` migration pack referencing the removed rule `prefer_returning_shorthands` instead of its replacement `prefer_arrow_functions` — the pack was silently missing coverage for that rule.

<details>
<summary>Maintenance</summary>

- Compiled alternative landscape gap analysis (`plans/GAP_ANALYSIS.md`) — rule-by-rule audit of 48 Dart/Flutter lint packages against saropa_lints' catalog, with gap themes and per-package detail sections for planning future rule additions.
- Hardened dead-package language in migration guides for `accessibility_lint` (archived), `design_system_lints` (defunct since 2022), and `flutter_refactor_plugin` (source repo 404) — migration is mandatory, not optional.
- Added migration packs plan (`plans/MIGRATION_PACKS_PLAN.md`) — rule packs that surface saropa equivalents for each alternative package in the extension's Config dashboard.
- Added `// LINT_MESSAGE:`, `// LINT_NOT:`, and `// LINT_COUNT:` fixture marker infrastructure — declarative message validation, false-positive guards, and whole-fixture count assertions for resolved harness tests.
- `audit` CLI: fixed `RuntimeTierCap` silently capping the rule set — added `bypassTierCap` flag on `ScanRunner` so audit runs every rule regardless of the project's configured tier.
- `audit` CLI: fixed tier enrichment bug — was looking up `entry['rule']` instead of `entry['ruleName']`, so tier field was never populated in JSON output.
- `audit` CLI: added per-diagnostic `category` field to JSON output (derived from rule source file directory), with generated category map and drift-catching unit tests.
- Fixed l10n diagnostic param-extraction by replacing the regex with a state-machine parser that handles nested expressions, spread syntax, template literal interpolations, regex literals, and value-expression skipping after explicit keys. Also added comment-aware scanning to prevent false positives from code comments.
- Moved `PACKAGE_VIBRANCY.md` from `plans/guides/` to the repo root to match the path the extension's SDK vibrancy table expects; excluded `plans/` from the pub.dev package (already public on GitHub, this only trims the published tarball); added CI check `scripts/check_doc_links_excluded_paths.py` to catch shipped docs linking into `.pubignore`-excluded paths (resolves link targets relative to the linking file, reads exclusion prefixes directly from `.pubignore`, and checks both inline and reference-style Markdown links). Fixed 6 dead links it found across `README.md`, `doc/troubleshooting.md`, and `doc/guides/`.
- Added GitHub issue form templates (`.github/ISSUE_TEMPLATE/`) for bug reports and feature requests, enforcing the structure from `bugs/ISSUE_REPORT_GUIDE.md` at filing time. Blank issues disabled.
- Moved `rule_packs` config from `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level key in `analysis_options_custom.yaml`, eliminating the false `unsupported_option` warning from the Dart SDK's plugin-block validator. Existing configs are read with deprecation fallback; run `dart run saropa_lints migrate-config` to migrate automatically.
- Added `--dry-run` flag to `migrate-config` CLI — previews what would change without writing files.
- Fixed CRLF line-ending handling in `rule_packs` write/migrate paths (Windows files with `\r\n` could silently corrupt regex matches).
- Filed 336 new-rule and extension proposals (`bugs/proposal_*.md`) covering every DCM gap, partial-coverage rule, and all 46 alternative-package migration-guide gaps, each traceable back to `plans/GAP_ANALYSIS.md` via a "Closes gap" line. All migration-guide TODO rows now link to their proposal.
- Created 46 migration guides (`doc/guides/migration_guides/`) — one per alternative lint package audited in the gap analysis — with rule-mapping tables (HAVE / PARTIAL / TODO) and migration steps.
- Added cross-referencing requirement to `bugs/ISSUE_REPORT_GUIDE.md`: implementing a proposal that closes a migration-guide gap must flip the corresponding table row from TODO/PARTIAL to HAVE/ENHANCED.
- Corrected stale `prefer-container` false-gap entry in `plans/GAP_ANALYSIS.md` — saropa already covers this via `PreferContainerRule`.
- Closed 11 i18n translation gaps across 8 locales (de, fil, id, it, nl, pl, pt, sw) via curated dictionary entries — cognate passthroughs (`Status:`, `Debug`), manual translations (`Panel ng Debug`, `tulivu`), and fixed Swahili `active` MT garbage.
- Added dictionary locale-integrity validator (`_check_dictionary_locale_integrity`) — AST-based check that detects entries misrouted to the wrong locale section, with duplicate-key detection and cross-locale diagnostic hints. Runs as a hard gate before translation.
- Added unit tests for the Full Audit POSIX process-group kill path (5 cases covering Linux, macOS, fallback, Windows, and no-pid edge cases) and the >10MB deferred-payload temp-file lifecycle (write, cleanup, and fallback behavior) — 11 new tests total.
- Documented the circular-fallback risk when `globalStorageUri` temp-file write fails for large audit payloads — the fallback inlines a payload that was too large for inlining, which may stall the webview for 50MB+ results.
- Documented GitHub code-scanning CI recipe in `doc/guides/cli.md` — example workflow using `--since` and `--format sarif` with `upload-sarif@v3` for inline PR annotations.
- Confirmed SARIF `properties` bag carrying `tier`/`category`/`baselineStatus` is compatible with GitHub code-scanning and VS Code SARIF Viewer per SARIF 2.1.0 §3.8 — added spec-reference comment.
- Eliminated redundant JSON.stringify of the full diagnostics array in the audit report render path — the array is now serialized once in `openAuditReport` and the same string feeds both the size check and the inline embed.
- Added `test/config/rule_packs_migration_guide_sync_test.dart` — re-derives each migration pack's expected rule set from its guide's HAVE/ENHANCED table and fails if the pack file drifts from the guide (caught the 4 packs fixed above).
- `rule_pack_migration_codes.dart` is now generated, not hand-maintained: `tool/generate_migration_pack_codes.dart` parses the HAVE/ENHANCED rows out of every migration guide, validates each referenced saropa rule against `tiers.dart`, and rewrites the pack file — run it after editing any migration guide instead of hand-syncing the pack's `Set<String>`. Shared parsing lives in `tool/migration_pack_guide_sync.dart` so the generator and the drift test can't disagree.
- Hardened the migration pack generator's tiers.dart validation to skip comment lines (commented-out rule names were false-passing), added validation for the carried-forward `flutter_skill_lints` code set, and extracted a shared dedup constant so the generator and drift test can't silently disagree on the count.
- Hardened migration pack generator further: `extractBlock`/`extractPackCodes` now use balanced brace counting instead of fragile `\n};`/`\n  },` string markers; `activeQuotedIdentifiers` strips `/* */` block comments in addition to `//` lines; `.dart_tool/` temp directory is created before use; diff output shows per-pack `+ added`/`- removed` codes in both normal and `--check` modes.
- l10n diagnostic provider: excluded `l10nParsers.test.ts` from validation (false positives from dummy keys in test fixtures), added extra-params detection (Hint when code passes params the template doesn't use), added `// l10n-ignore-next-line` comment directive for per-call suppression, and added dead-key detection with single and bulk quick-fixes to remove unreferenced en.json keys from all 25 locale files at once.

</details>

---

## [15.2.8]

Rule shedding under memory pressure is now cost-aware — expensive rules that drive the most memory consumption are shed first, keeping cheap syntactic rules running longer. The Config Dashboard surfaces which rules are currently shed and why, and the status bar tooltip shows shed category breakdowns. [log](https://github.com/saropa/saropa_lints/blob/v15.2.8/CHANGELOG.md)

### Added

- Config Dashboard now shows a "Shed rules" section when memory pressure is active — lists every temporarily disabled rule grouped by shed category (type-resolving, high-cost, INFO, WARNING) with clickable links to each rule's explanation.
- Shed rules are marked with a "shed" badge inside expanded pack rows so you can see at a glance which rules in a pack are temporarily inactive.
- "Restart analyzer" button in the shed section clears memory pressure by restarting the analysis server — shed rules restore automatically when RSS resets. No action required.

### Changed

- Cost-aware rule shedding: memory pressure now sheds type-resolving and high-cost rules first (level 1), then INFO-severity (level 2), then WARNING-severity (level 3). No action required.
- Status bar tooltip shows shed rule breakdown by category (type-resolving, high-cost, INFO, WARNING) when shedding is active. No action required.

---

## [15.2.7]

Adds graduated rule shedding under memory pressure — the analyzer plugin now progressively disables low-severity rules when RSS approaches its cap, keeping essential rules running. The VS Code extension surfaces shedding state in the status bar and tooltip. Also includes publish script hardening. [log](https://github.com/saropa/saropa_lints/blob/v15.2.7/CHANGELOG.md)

### Added

- Graduated memory-pressure rule shedding (opt-in via `shed_rules: true` in `analysis_options_custom.yaml`): shed level 1 disables INFO-severity rules, level 2 adds WARNING-severity rules, essential-tier rules are always protected. Without opt-in, soft-limit warnings still log but no rules are shed.
- Memory pressure indicator in the VS Code status bar and tooltip, fed by `memory_state.json` written on shed-level transitions — no polling.
- VS Code warning notification when the analyzer hits memory pressure but rule shedding is not enabled — "Enable" writes `shed_rules: true` directly into `analysis_options_custom.yaml`, "Learn More" opens the docs. Shows once per workspace root per session, with a persistent status-bar indicator so pressure stays visible after dismissing the toast.
- `memory_mode: aggressive` option in `analysis_options_custom.yaml` — applies balanced-mode unchanged-file skipping to the scan daemon and CLI too, reducing daemon RSS on incremental scans at the cost of potentially missing violations in unchanged files whose dependencies changed.

<details>
<summary>Maintenance</summary>

- **Publish script: preflight version verification** — a visible "PREFLIGHT: VERSION VERIFICATION" step now runs early in the publish pipeline (before badge validation, CI gate, and extension packaging), checking that `pubspec.yaml` and `extension/package.json` carry the correct version. Two additional safety-net gates run later (after staging and before tagging) as a last resort. No action required.
- Severity registration at plugin startup maps each rule to a 0-based shed index for the graduated shedding mechanism.
- `memory_state.json` state file written alongside `plugin.log` on shed-level transitions for extension consumption.
- Periodic memory log line now includes soft limit and shed level.
- `PluginLogger.logFilePath` public getter for the memory-state writer.
- `getStats()` now includes `softLimitMb`, `softLimitTripped`, `shedLevel`, and `shedRuleCount`.
- Fixed negative recovery thresholds when the hard RSS limit is below ~366 MB — soft-limit recovery and de-escalation checks now clamp to zero instead of going negative, which would lock shedding on permanently.
- Shed level updates skip the full rule-set rebuild when the level hasn't actually changed.
- Shedding opt-in moved from the env-var-only `SAROPA_LINTS_SHED_RULES=true` to a `shed_rules: true` key in `analysis_options_custom.yaml` (the env var still works, but is no longer the only way in — `dart run saropa_lints:init` now writes a commented `shed_rules` line so the setting is discoverable). `_refreshSoftLimit` split into `_tripSoftLimit`/`_recoverSoftLimit`/`_refreshEscalation` helpers. Status-bar and tooltip memory-pressure text now share one priority-order function (`memoryPressureTooltipLine`) instead of two independently maintained decision trees.
- **`usesTypeResolution` audit complete** — 180 false claims flipped to `false` across 9 rule files, freeing those rules from unnecessary scan-daemon routing. Integrity test unskipped and now guards both directions (missing flag + false claim). Test regex extended with `formalParameters` to catch modern element-model resolution APIs.
- **Full Audit i18n** — added all 50 missing `audit.*` keys to `en.json` (scope picker, progress, errors, and report webview) plus 3 missing `findingsDash.script.*` accessibility keys, and localized the inline progress-bar message. No action required.
- **`check_l10n_keys.py`** — new CI script cross-references every `l10n()` call in `extension/src/` against `en.json`, with `--check-params` to validate interpolation tokens match between call sites and catalog values. Handles template-literal `${}` interpolations, spread properties, and dynamic-key prefixes. No action required.
- **Live l10n diagnostics** — new `saropa-l10n` diagnostic provider shows inline warnings for missing `en.json` keys and param mismatches on save. Re-validates when `en.json` changes. No action required.
- **`check_l10n_keys.py` param checker hardened** — fixed false positives: consecutive shorthand properties (`{ a, b }`) were missed due to trailing-delimiter consumption; template-literal interpolations (`${suffix}`) were misidentified as extra params; plural keys (`*One`/`*Other`) with `{count}` are now skipped since `pluralize()` handles substitution. No action required.
- **`usesTypeResolution` false flips fixed** — 8 rules across 4 files (`stylistic_rules.dart`, `ui_ux_rules.dart`, `widget_lifecycle_rules.dart`, `widget_patterns_ux_rules.dart`) were incorrectly set to `usesTypeResolution: false` despite using `NamedType.element` for superclass resolution; integrity test regex now catches `.superclass.element`. No action required.
- **Reports-dir single source of truth** — extracted `REPORTS_DIR` and `SAROPA_LINTS_DATA_DIR` constants plus path-builder helpers into `reportsPaths.ts`, replacing 27 hardcoded `'reports'`/`'.saropa_lints'` string literals across 18 production files. No action required.
- **Config loader deduplication** — extracted `_resolveEnvThenYaml` shared helper in `config_loader.dart`, replacing duplicated env-var-then-yaml lookup logic in `_loadShedRulesConfig` and `_loadMemoryMode`. No action required.
- **Scan-loop RSS guard** — the scan CLI now samples RSS between files and stops early (returning partial results) when memory exceeds the configured hard limit, preventing OOM on very large codebases. No action required.
- **CodeQL security fixes (13 alerts)** — added `permissions: contents: read` to 2 workflow YAMLs; fixed incomplete Markdown escaping in issue-tree tooltips; replaced substring URL check with parsed-hostname `isGitHubUrl()`; hardened pub.dev changelog HTML-to-markdown against tag-stripping bypasses and double-unescaping. No action required.
- **Shared `markdownUtils.ts`** — extracted `escapeMarkdown()` and added `buildMarkdownString()` structured builder for safe MarkdownString construction with mixed trusted/untrusted segments. Applied defense-in-depth escaping to hover-provider for external metadata (package names, vulnerability advisories, issue titles, file paths). No action required.

</details>

---

## [15.2.6]

Restores the Full Audit sidebar button and fixes `require_ignore_comment_plugin_prefix` showing the wrong diagnostic message when an ignore comment uses `saropa_lints/` prefix with an unregistered rule name. No new rules or breaking changes. [log](https://github.com/saropa/saropa_lints/blob/v15.2.6/CHANGELOG.md)

### Fixed

- **Full Audit sidebar button** — the "Full Audit" entry was missing from the extension sidebar despite being documented in 15.2.5. Now appears between Findings Dashboard and Command Catalog with a shield icon, plus a title-bar shortcut icon in the Editor Dashboards view header (visible only in Dart projects).
- **`require_ignore_comment_plugin_prefix` wrong message for unknown prefixed rule** — `// ignore: saropa_lints/nonexistent_rule` showed the "add prefix" message instead of the "not a registered rule" message. The reporter always reads `diagnosticCode` and ignores per-diagnostic `LintCode` overrides; fixed by temporarily swapping `diagnosticCode` during the unknown-prefix report.
- **Tier-change toast count mismatch with Findings Dashboard** — changing tier showed a toast with a violation count from the stale `violations.json` file while the dashboard read live diagnostics (often empty during re-analysis), producing "toast says N, dashboard shows 0". The toast now defers until the first diagnostics refresh settles, so both surfaces show the same count. The dashboard shows a "Re-analyzing..." progress indicator during the gap. A 15-second safety fallback fires if the analysis server never produces results.

<details><summary>Maintenance</summary>

- **`generate_translations.py` auto-commits** — the translation wrapper script now auto-detects every file the pipeline touches (no hardcoded path list) and commits them after a successful run. Pre-staged files are left untouched. Null-delimited git output handles unusual filenames. SIGINT is restored before git calls so Ctrl+C can abort a stuck commit. Pass `--no-commit` to skip the auto-commit for CI or review workflows.

</details>

---

## [15.2.5]

This patch moves `log_level`, `lane`, and `memory_mode` configuration from the `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level keys in `analysis_options_custom.yaml`, eliminating false `unsupported_option` warnings from the Dart SDK's plugin-block validator. Projects using the old location get a deprecation warning and automatic fallback — the keys still work from the plugin block, but moving them to the custom file silences the warnings. [log](https://github.com/saropa/saropa_lints/blob/v15.2.5/CHANGELOG.md)

### Added

- **Full Audit CLI** — `dart run saropa_lints audit <dir>` runs every rule (pedantic + stylistic) against a codebase regardless of the project's configured tier. Produces enriched JSON with per-diagnostic `tier` and `category` fields. Supports `--since <ref>` to audit only changed files, `--min-severity`/`--min-impact` post-filters, `--profile` timing, and `--exclude-globs`/`--include-globs`.
- **Full Audit sidebar button** — new "Full Audit" entry in the extension sidebar launches the audit with a scope quick-pick (full project, changed vs main, or pick a branch) and opens a filterable report webview with search, tier/severity/impact filter chips, sortable columns, and JSON export. The progress notification shows real-time percentage, file count, issue count, and current filename.
- **Audit report keyboard navigation** — use ↑/↓ arrow keys to move between rows and Enter to open the file at that diagnostic. A "no matches" state now appears when filters exclude all results.
- **Audit baseline diffing** — `--save-baseline` saves the current audit as a project baseline at `.saropa/audit_baseline.json`; `--baseline` compares against the saved baseline and tags each diagnostic as new or unchanged. The sidebar quick-pick shows a "Compare to baseline" option when a baseline exists, and the report webview has a "Save as baseline" button and new/unchanged filter chips.
- **Migrate Config** — `dart run saropa_lints migrate-config` and a sidebar button ("Migrate config keys") automatically move `log_level`, `lane`, and `memory_mode` from the old plugin block to `analysis_options_custom.yaml`. Safe to run multiple times; already-migrated keys are skipped.
- **Configurable `max_declarations_per_file`** — set `max_declarations_per_file: N` in `analysis_options_custom.yaml` to allow up to N top-level declarations before `prefer_single_declaration_per_file` fires (default 1). No action required — existing behavior is unchanged.
- **Sealed hierarchy size nudge** — set `max_sealed_hierarchy_lines: N` in `analysis_options_custom.yaml` to get a lint when a sealed class file exceeds N lines, suggesting `part`/`part of` to split subtypes while keeping them in the same library (default 0 = disabled).

### Fixed

- `log_level`, `lane`, and `memory_mode` plugin configuration keys no longer trigger `unsupported_option` warnings from the Dart SDK analyzer. These keys now live as top-level entries in `analysis_options_custom.yaml` instead of under `plugins > saropa_lints:`. Projects still using the old location get a deprecation warning with the key's value honored as a fallback; `dart run saropa_lints init` generates the updated layout automatically.
- `prefer_sorted_parameters` no longer conflicts with `dart format`. The rule now respects `always_put_required_named_parameters_first`: required named parameters come first, then optional named parameters, each group sorted alphabetically. Includes a quick fix that reorders parameters automatically. ([#321](https://github.com/saropa/saropa_lints/issues/321))
- `require_text_overflow_handling` and `require_text_overflow_in_row` correction messages no longer default to `TextOverflow.ellipsis`. The guidance now recommends wrapping in `Expanded`/`Flexible` first — ellipsis is a last resort when truncation is intentional. Both rules offer context-aware quick fixes: "Wrap in Expanded" inside Row/Column/Flex, or "Add maxLines" elsewhere. ([#320](https://github.com/saropa/saropa_lints/issues/320))
- `prefer_single_declaration_per_file` no longer fires on sealed class hierarchies. Dart requires sealed subtypes in the same library, so co-locating them is mandatory, not a style violation. ([#322](https://github.com/saropa/saropa_lints/issues/322))
- `avoid_unused_parameters` no longer fires on abstract, external, or native method declarations. These methods have no implementation body, so their parameters define the interface contract and cannot be "used." ([#319](https://github.com/saropa/saropa_lints/issues/319))

### Changed (Extension)

- The lane picker now reads and writes `lane:` from `analysis_options_custom.yaml` instead of `analysis_options.yaml`. No action required — the extension handles the new location transparently.

---

## [15.2.4]

This patch release focuses on refining the avoid_unguarded_debug rule to eliminate several false positives. The rule now correctly recognizes early-exit returns and safely resolves variable-indirection chains for debug mode checks. Behind the scenes, early-exit and guard-evaluation utilities were unified across multiple core rules to ensure consistent behavior moving forward. [log](https://github.com/saropa/saropa_lints/blob/v15.2.4/CHANGELOG.md)

### Fixed

- `avoid_unguarded_debug` no longer false-positives when `debugPrint()` is dominated by an early-return guard (`if (!kDebugMode) return;`) at the top of the enclosing block. Also recognizes `kDebugMode == false`, `kDebugMode != true`, reversed operand order (`false == kDebugMode`), and multi-statement then-blocks ending in `return`. No action required.

### Added

- `avoid_unguarded_debug` now recognizes variable-indirection guards: `final isDebug = kDebugMode; if (!isDebug) return;` is accepted, including chained assignments up to 3 levels deep and top-level/static `const` fields in the same file. Only `final` and `const` are trusted — mutable assignments are correctly rejected. No action required.

<details><summary>Maintenance</summary>

- Extracted shared `early_exit_guard_utils.dart` — `containsEarlyExit`, `endsWithEarlyExit`, `findPrecedingGuardInBlock`, and `hasDominatingEarlyExitGuard` replace five independent reimplementations across `debug_rules.dart`, `collection_rules.dart`, `async_rules.dart`, `type_rules.dart`, and `code_quality_avoid_rules.dart`.
- `hasDominatingEarlyExitGuard` now supports a `stopAtClosureBoundary` parameter — runtime-mutable guards (collection emptiness) stop at closure/function boundaries; compile-time constants (`kDebugMode`) opt out since closures in the guarded zone are safe.
- `endsWithEarlyExit` now recognizes `break` and `continue` statements, matching the coverage of `containsEarlyExit`.
- Variable-indirection resolver follows chained `final`/`const` assignments up to 3 levels with cycle detection, and resolves top-level/static class fields via pure AST walk (no type resolution — rule stays in the light analysis lane).
- `_findLocalInitializer` now only considers declarations preceding the usage site (offset-based guard prevents forward-reference resolution).

</details>

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.

# VS Code Extension Guide

<!--
  This is the DETAILED reference for the Saropa Lints VS Code extension: settings, commands,
  view behavior, and the extension API. The root README keeps only the quick-start steps
  (install -> open sidebar -> Set Up Project) and the comparison/"why" sections; everything
  below is the deep-dive material that used to live inline in the "VS Code Extension
  (Recommended)" section.
-->

Install the [Saropa Lints VS Code extension](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints) for the full experience. Also on [Open VSX](https://open-vsx.org/extension/saropa/saropa-lints) (Cursor, VSCodium).

The package and the extension are **one product** — published together and versioned in sync. The Dart package provides the rules; the extension is the primary setup, configuration, and triage surface.

Lint integration defaults **on** for Dart workspaces (`saropaLints.enabled`). Overview and setup stay available even when integration is off; turn it off with **Saropa Lints: Turn Off Lint Integration** if you only want the sidebar without analyzer runs.

For install steps and the first "Set Up Project" run, see the [README quick start](../../README.md#quick-start). This page assumes the extension is already installed and covers what each view, setting, and command does.

## Features

<!-- One-line summary of every feature area; each gets its own section below with full detail. -->

- **Health Score** — 0-100 score in the status bar; green/yellow/red bands in the Overview
- **Violations view** — Violations grouped by severity and file, with Error Lens-style inline annotations; multi-select works with **Copy as JSON**
- **Security Posture** — OWASP Mobile and Web Top 10 coverage matrix, compliance export
- **File Risk** — Files ranked by violation density; focus on the riskiest first
- **Triage** — Disable noisy rules from the UI; see estimated score impact before acting
- **Rule packs / Manage Rule Packs** — Enable stack bundles (Riverpod, Drift, …) and per-package packs from **Saropa Lints: Manage Rule Packs** (editor tab: per-pack toggles, inline rule lists, an "Enable all recommended packs" action, target platforms when embedder folders exist); see [Rule Packs Guide](rule_packs.md)
- **Package Vibrancy** — Dependency health, alerts, and optional **version-gap** PR/issue triage (enable with `saropaLints.packageVibrancy.enableVersionGap`; a GitHub token improves results)
- **Full Opportunities Report** — **Saropa Lints: Export Full Opportunities Report** writes every dependency and every changelog feature to `reports/` as HTML, Markdown, and JSON, with each feature's usage counted from zero upward and every call site named; built to hand to an AI for a dependency-usage review
- **Project Vibrancy / Code Health Dashboard** — Project code-health scoring for your own Dart source via **Open Code Health Dashboard** (editor-area webview; same scan as the CLI JSON output); use the graph icon on **Violations**, **Overview**, **Config**, or **Package Vibrancy** view titles, or the Command Palette
- **TODOs & Hacks** — Sidebar scan for TODO/FIXME/HACK-style markers; full-workspace scan is **opt-in** (`saropaLints.todosAndHacks.workspaceScanEnabled`; leave `false` until you need it) via **TODOs & Hacks: Enable workspace scan**
- **Trends** — Score progression over time with milestone celebrations

Problems panel empty, analyzer plugin stuck, or no lightbulb fixes? See the [Troubleshooting guide](../troubleshooting.md).

## Extension Settings

<!-- Full settings reference, copied verbatim from the README so nothing is lost on extraction. -->

| Setting | Default | Description |
|--------|--------|-------------|
| `saropaLints.enabled` | `true` | Lint integration for this workspace (upgrade checks, status-bar treatment). Overview stays usable when off; use **Set Up Project** to add the package and config. |
| `saropaLints.tier` | `recommended` | Tier used when enabling or re-initializing (essential, recommended, professional, comprehensive, pedantic). |
| `saropaLints.runAnalysisAfterConfigChange` | `true` | Run `dart analyze` after init when enabling. |
| `saropaLints.runAnalysisOpenEditorsOnly` | `false` | When true, `Run Analysis` runs `dart/flutter analyze` only for Dart files currently open in VS Code (workspace text documents) under the detected project root (pubspec.yaml directory). |
| `saropaLints.issuesPageSize` | `100` | Max violations shown per file in the Violations tree (1-1000). Remaining appear as "and N more…". |
| `saropaLints.violationsGroupBy` | `impact` | Default tree grouping: `impact`, `severity`, `file`, `rule`, `owasp`, `ruleType`, or `ruleStatus`. `impact` lists Critical / High first. Change anytime from the Violations toolbar. |

**Sidebar defaults:** **Commands** (searchable index of every command), **Overview & options**, **Violations**, **Config Dashboard**, and **Package Vibrancy** show in the activity bar by default. Use **Saropa: Open Package Dashboard** for the full dependency report in an editor tab. Overview includes embedded Health Summary, Next Steps, and Riskiest Files groups when violations exist. **Package Details** appears automatically after a Vibrancy scan. Turn on standalone **Triage**, Summary, Security, File Risk, TODOs, etc. from **Overview & options -> Activity bar sections** (default path) or Settings (`saropaLints.sidebar.show*` advanced mirror).

### TODOs & Hacks settings

| Setting | Default | Description |
|--------|--------|-------------|
| `saropaLints.todosAndHacks.workspaceScanEnabled` | `false` | When **true**, the view scans the workspace for comment markers (resource-intensive). |
| `saropaLints.todosAndHacks.tags` | `["TODO", "FIXME", "HACK", "XXX", "BUG"]` | Tags to search for in comments (case-sensitive). |
| `saropaLints.todosAndHacks.includeGlobs` | `["**/*.dart", "**/*.yaml", "**/*.ts", "**/*.js"]` | Glob patterns for files to scan. |
| `saropaLints.todosAndHacks.excludeGlobs` | `["**/node_modules/**", "**/.dart_tool/**", "**/build/**", "**/.git/**"]` | Extra exclude patterns (merged with search.exclude). |
| `saropaLints.todosAndHacks.maxFilesToScan` | `2000` | Maximum number of files to scan; view shows a message when capped. |
| `saropaLints.todosAndHacks.autoRefresh` | `true` | Refresh the TODOs & Hacks view when a file is saved (debounced). |
| `saropaLints.todosAndHacks.groupByTag` | `false` | When true, group tree by tag (TODO, FIXME, …) then by file; when false, by folder then file. |
| `saropaLints.todosAndHacks.customRegex` | `""` | Optional regex override for comment markers. Use capture group 1 for tag, optional group 2 for snippet. Empty = default (//, #, <!-- + tags). Invalid regex falls back to default. |

## Commands

<!-- Full command list, copied verbatim from the README. -->

- **Saropa Lints: Getting Started** — Open the walkthrough with a guided tour of all features.
- **Saropa Lints: Set Up Project (pubspec + config)** — Add `saropa_lints` to the project and run init (and optionally analyze).
- **Saropa Lints: Turn Off Lint Integration** — Disable integration for this workspace (does not remove files).
- **Saropa Lints: Run Analysis** — Run `dart analyze` / `flutter analyze`.
- **Saropa Lints: Initialize / Update Analysis Options** — Write analysis_options.yaml with the current tier (uses write_config).
- **Saropa Lints: Open Analysis Options** — Open `analysis_options_custom.yaml` or `analysis_options.yaml`.
- **Filter by text…** / **Filter by severity and impact…** / **Filter by rule name…** / **Filter by rule metadata…** — Filter the Violations tree (view toolbar).
- **Clear filters** / **Clear suppressions** — Reset filters or hidden items (view toolbar when active).
- **Saropa Lints: Show All Violations** — Open the Violations view and show all findings (clears filters). Used when clicking "Total violations" in Summary.
- **Saropa Lints: Show in Saropa Lints** — Focus the Violations view filtered to the active editor's file (e.g. from Problems view context menu or command palette).
- **Group by…** — Change how the Violations tree is organized: Severity, File, Impact, Rule, OWASP Category, Rule Type, or Rule Status (view toolbar).
- **Explain rule** — On a violation in the Violations tree (context menu) or from the command palette (pick a rule): open a side tab with full rule details (message, fix, severity, impact, OWASP, ROADMAP link).
- **Apply fix** — On a violation in the Violations tree (context menu): run the Dart analyzer's quick fix for that location without opening the file.
- **Fix all in this file** — On a file in the Violations tree (context menu): run all available quick fixes for that file bottom-up.
- **TODOs & Hacks: Refresh** — Refresh the TODOs & Hacks view (full rescan only when workspace scan is enabled).
- **TODOs & Hacks: Enable workspace scan** — Turn on `workspaceScanEnabled` so marker search can run.
- **Create Saropa Lints Instructions for AI Agents** — Create `.cursor/rules/saropa_lints_instructions.mdc` in the workspace from the bundled template (**Overview & options -> Help & resources** or Command Palette). Gives AI agents project guidelines for working on saropa_lints.
- **TODOs & Hacks: Toggle group by tag / folder** — Switch between grouping by folder->file->line and by tag->file->line (view toolbar).
- **Export OWASP Compliance Report** — Generate a markdown report with Mobile/Web Top 10 coverage tables and gap analysis.

## Violations View

<!-- Tree structure, toolbar actions, and every context menu on the Violations view. -->

The **Violations** view lists lint findings from your analysis report in a **tree**: first by **severity** (Error, Warning, Info), then by **project structure** (folders and files). Each file lists violations (capped per file; excess shown as "and N more…").

- **Group by (toolbar):** Change how the tree is organized — by Severity (default), File, Impact, Rule, OWASP Category, Rule Type, or Rule Status. Click the tree icon in the toolbar to switch.
- **Filters (toolbar):** Filter by text (file path, rule, or message), Filter by type (severity and impact), Filter by rule (multi-select), or Filter by rule metadata (`ruleType` / `ruleStatus`). When active, the view shows "Showing X of Y".
- **Suppressions:** Right-click a folder, file, violation, or severity node to hide it from the tree (e.g. "Hide folder", "Hide rule"). Suppressions are persisted; use **Clear suppressions** in the toolbar to restore all.
- **Code Lens:** In Dart files that have violations, a lens at the top shows e.g. "Saropa: 3 violations — Show in Saropa". Click to open the Violations view filtered to that file.
- **Multi-select + JSON:** Ctrl+click (Windows/Linux) or Cmd+click (macOS) multiple tree rows, then **Copy as JSON** (context menu or toolbar) to export those subtrees. For all violations at once, use `reports/.saropa_lints/violations.json` (see [VIOLATION_EXPORT_API.md](https://github.com/saropa/saropa_lints/blob/main/VIOLATION_EXPORT_API.md)).
- **Context menus:** **Explain rule** (book icon) opens a side tab with full rule details; Apply fix (wrench icon) and Copy message (clipboard icon), then a separator, then hide options: Hide rule from view, Hide rule in this file. On folders/files: Hide folder, Hide file, Copy path; on files: Fix all in file, Show only this file. On severity nodes: Hide this severity.
- **Explain rule:** Right-click a violation and choose **Explain rule** (or run **Saropa Lints: Explain rule** from the command palette and pick a rule) to open a tab beside your code with the rule's problem message, how to fix, severity, impact, OWASP mapping (if any), and a link to the ROADMAP.
- **Violation tooltips:** Show rule name and a "More" link to rule documentation (ROADMAP).
- **Summary -> Violations:** Click **Total violations** in the Summary view to open the Violations view with all findings (clears any active filters). By severity / By impact rows open Violations with the matching filter, and **By rule type / By rule status** rows open Violations filtered to matching metadata groups.
- **Problems view:** Right-click a problem and choose **Saropa Lints: Show in Saropa Lints** to focus the Violations view filtered to the active file.

## Health Score

<!-- Scoring bands and status bar rendering detail. -->

A single 0-100 number in the **Overview** and **status bar**, computed from violation count and impact severity. Higher is better:

- **80-100** (green): Good shape — few issues, none critical.
- **50-79** (yellow): Needs work — some high-impact issues.
- **Below 50** (red): Serious problems — many critical/high-impact violations.

The status bar shows the score with a delta from the last run, plus the finding count, in a single item (e.g. "Saropa: 78 ▲4 · ⚠ 12"); its background stays neutral rather than turning red, and the score is held back until a full analysis has covered enough of the project. When violations decrease, a celebration message includes the score change.

## Security Posture

<!-- Kept brief per the requested outline; full detail lives in the Violations View / OWASP sections. -->

The **Security Posture** view shows OWASP Mobile and Web Top 10 coverage based on the active rules and violations. Right-click a category to export an OWASP compliance report. See the [README OWASP Compliance Mapping](../../README.md#owasp-compliance-mapping) section for the underlying coverage table.

## File Risk

<!-- Kept brief per the requested outline. -->

The **File Risk** view ranks files by weighted violation density (same weights as the Health Score). Files with critical violations appear first with a flame icon. Click a file to filter the Violations view to that file.

The **Triage** view focuses on rule groups by impact/volume and quick enable/disable actions, while full config controls live in **Config Dashboard**.

The **Logs** view lists analysis reports from `reports/`. Each log shows a parsed hint (e.g. violation counts, init tier). A "Run Analysis" action appears when the latest report is over 1 hour old.

## Package Vibrancy

<!-- Detail on the Activity grade signal specifically; the general Package Vibrancy feature is summarized above under Features. -->

The Package Vibrancy report includes an **Activity** grade column (**A-F**) that reflects maintenance activity separately from overall vibrancy.

- Uses both **code activity** (last commit from GitHub `pushed_at`) and **release activity** (latest pub.dev publish date).
- Activity score uses a 90-day decay for both timelines and takes the weaker side.
- Report surfaces dormancy hints:
  - **90+ days** with no commits and no releases: stale
  - **180+ days** with no commits and no releases: dormant

This helps distinguish "not recently released but still actively maintained" from "no recent release and no recent code changes."

**TODOs & Hacks** is a Todo-Tree-style marker view (TODO, FIXME, …) that appears **after you opt in** to workspace scanning (`saropaLints.todosAndHacks.workspaceScanEnabled`, default **off** to avoid heavy full-repo I/O). Until then, the view shows **Enable workspace scan…** (or use **TODOs & Hacks: Enable workspace scan**). No `violations.json` required. Default globs: Dart, YAML, TypeScript, JavaScript; add `**/*.md` to `includeGlobs` if you want Markdown. Toolbar: Refresh, Toggle group by tag / folder. Auto-refresh on save respects the same gate. Custom regex: `saropaLints.todosAndHacks.customRegex`.

## Code Health Dashboard

<!-- Project Vibrancy scoring of the user's OWN source, distinct from Package Vibrancy which scores dependencies. -->

The **Code Health Dashboard** scores the functions in your own Dart code (separate from Package Vibrancy, which scores dependencies).

- Scans your project with `dart run saropa_lints:project_vibrancy` and shows the worst function hotspots in an editor-tab dashboard.
- KPI cards double as one-click filters for `unused`, `uncovered`, `stub_tested`, `suspicious_coverage`, and `test_drift`.
- Free-text search filter, sortable table, and active-filter chip strip.
- Quality gates (min grade, max-unused, max-uncovered, etc.) configured under **Code Health** settings — failures show a banner and are surfaced as a warning toast.
- Run from the Command Palette via **Saropa Lints: Open Code Health Dashboard**, from the Saropa Lints sidebar entry **Code Health Dashboard**, or from the in-dashboard **Rescan** button.

## TODOs & Hacks

<!-- Consolidated TODOs & Hacks detail (view behavior above under Violations/Package Vibrancy sections plus settings). -->

Sidebar scan for TODO/FIXME/HACK-style markers, styled like Todo-Tree. Full-workspace scan is **opt-in** — leave `saropaLints.todosAndHacks.workspaceScanEnabled` at its default `false` until you need it, then either toggle the setting or run **TODOs & Hacks: Enable workspace scan**. No `violations.json` is required for this view; it scans source files directly.

- Default globs cover Dart, YAML, TypeScript, and JavaScript; add `**/*.md` to `includeGlobs` for Markdown files.
- Toolbar actions: Refresh, and Toggle group by tag / folder (folder->file->line vs tag->file->line).
- Auto-refresh on save is gated by the same workspace-scan opt-in.
- `saropaLints.todosAndHacks.customRegex` overrides the default marker regex; an invalid regex falls back to the built-in default.

See [Extension Settings](#extension-settings) above for the full `saropaLints.todosAndHacks.*` settings table.

## Triage & Config Dashboard

<!-- Kept brief per the requested outline. -->

The **Triage** view focuses on rule groups by impact/volume with quick enable/disable actions and an estimated score impact before you act. Full config controls — tier, rule packs, platforms, and packages — live in the **Config Dashboard**. Use **Saropa Lints: Manage Rule Packs** for the dedicated rule-pack editor (per-pack toggles, inline rule lists, "Enable all recommended packs"); see the [Rule Packs Guide](rule_packs.md).

## API for Other Extensions

<!-- Public API surface exposed by the extension's exports, for other extensions to consume without parsing violations.json themselves. -->

When the extension is activated, it exposes a **public API** so other extensions (e.g. [Saropa Log Capture](https://pub.dev/packages/saropa_log_capture)) can read violations and run analysis without parsing `violations.json` from disk.

Usage:

```ts
const ext = vscode.extensions.getExtension<import('./api').SaropaLintsApi>('saropa.saropa-lints');
if (ext?.exports) {
  const data = ext.exports.getViolationsData();
  const path = ext.exports.getViolationsPath();
  const params = ext.exports.getHealthScoreParams();
  const version = ext.exports.getVersion();
  await ext.exports.runAnalysis();
  await ext.exports.runAnalysisForFiles(['lib/main.dart', 'lib/auth.dart']);
}
```

| Method | Description |
|--------|-------------|
| `getViolationsData()` | Same shape as `violations.json`; `null` if no project root or read fails. |
| `getViolationsPath()` | Absolute path to `reports/.saropa_lints/violations.json`; `null` if no project root. |
| `getHealthScoreParams()` | `{ impactWeights, decayRate }` used by the health score formula. |
| `runAnalysis()` | Runs full `dart analyze` / `flutter analyze` in the workspace. Returns `true` if exit code 0. |
| `runAnalysisForFiles(files)` | Runs analyze for the given file paths only (e.g. stack-trace files). Capped at 50 files. Returns `true` if exit code 0. |
| `getVersion()` | Extension version string (e.g. from package.json). |

The file contract `reports/.saropa_lints/violations.json` remains the primary integration point; the API is optional and allows Log Capture to avoid disk reads and to refresh analysis for specific files. For the violation export schema, see [VIOLATION_EXPORT_API.md](https://github.com/saropa/saropa_lints/blob/main/VIOLATION_EXPORT_API.md). The same `violations.json` file is used by [Saropa Log Capture](https://pub.dev/packages/saropa_log_capture) for bug report correlation — crash reports include the project's health score and OWASP violations affecting the crash file.

## Violation Context Menu

<!-- The two "Hide" options are easy to confuse; this table plus the notes below disambiguate them. -->

On a violation, the two "Hide" options mean:

| Option | Effect |
|--------|--------|
| **Hide rule from view** | Hides that rule **everywhere** in the Violations tree (all files). |
| **Hide rule in this file** | Hides that rule **only in this file**; the same rule still appears in other files. |

("Hide this impact" is not shown on violations: it would hide all violations with that impact level, which is confusing from a single violation. Severity nodes still have "Hide this severity".)

These are **view-only** suppressions: they do not change `analysis_options.yaml` or source code. They are stored in workspace state and only affect what the Violations tree shows.

**To undo or manage:** Use **Clear suppressions** in the Violations view toolbar (it appears when any suppressions are active). That clears all hidden folders, files, rules, rule-in-file, severities, and impacts at once. There is no per-item "unhide"; clearing restores everything. To see or edit raw suppressions you would need to inspect workspace state (e.g. extension storage); the UI only offers Clear suppressions.

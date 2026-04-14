# Saropa Lints — VS Code Extension

Enable and configure [Saropa Lints](https://pub.dev/packages/saropa_lints) from the IDE. The extension is **on by default** for Dart workspaces: Overview shows settings, issues, and sidebar toggles immediately. Use **Set Up Project** when you need to add `saropa_lints` to `pubspec.yaml` and write `analysis_options` (no terminal init required).

After installing, run **"Saropa Lints: Getting Started"** from the Command Palette for a guided tour of all features.

## Requirements

- Dart SDK (or Flutter SDK) on PATH
- A Dart/Flutter project (workspace with `pubspec.yaml`)

## Usage

1. Open a Dart/Flutter project.
2. Open the **Saropa Lints** view (checklist icon in the activity bar). **Overview & options** lists workspace settings, sidebar section toggles, and links (About, Getting Started).
3. When you are ready to wire the package in, run **Saropa Lints: Set Up Project (pubspec + config)** (or click **Lint integration: Off** if you disabled integration). That will add `saropa_lints` to `dev_dependencies`, run pub get, run `write_config` for your tier, and optionally analyze.
4. Run **"Saropa Lints: Getting Started"** from the Command Palette for a guided tour of all features.
5. Use **Run Analysis** and **Open Config** as needed. Violations appear in the **Violations** view when `reports/.saropa_lints/violations.json` exists (written by the analyzer).

## Health Score

A single 0–100 number in the **Overview** and **status bar**, computed from violation count and impact severity. Higher is better:

- **80–100** (green): Good shape — few issues, none critical.
- **50–79** (yellow): Needs work — some high-impact issues.
- **Below 50** (red): Serious problems — many critical/high-impact violations.

The status bar shows the score with a delta from the last run (e.g. "Saropa: 78 ▲4"). When violations decrease, a celebration message includes the score change.

## Violations view

The **Violations** view lists lint findings from your analysis report in a **tree**: first by **severity** (Error, Warning, Info), then by **project structure** (folders and files). Each file lists violations (capped per file; excess shown as “and N more…”).

- **Group by (toolbar):** Change how the tree is organized — by Severity (default), File, Impact, Rule, or OWASP Category. Click the tree icon in the toolbar to switch.
- **Filters (toolbar):** Filter by text (file path, rule, or message), Filter by type (severity and impact), Filter by rule (multi-select). When active, the view shows “Showing X of Y”.
- **Suppressions:** Right-click a folder, file, violation, or severity node to hide it from the tree (e.g. “Hide folder”, “Hide rule”). Suppressions are persisted; use **Clear suppressions** in the toolbar to restore all.
- **Code Lens:** In Dart files that have violations, a lens at the top shows e.g. “Saropa: 3 violations — Show in Saropa”. Click to open the Violations view filtered to that file.
- **Multi-select + JSON:** Ctrl+click (Windows/Linux) or Cmd+click (macOS) multiple tree rows, then **Copy as JSON** (context menu or toolbar) to export those subtrees. For all violations at once, use `reports/.saropa_lints/violations.json` (see [VIOLATION_EXPORT_API.md](../VIOLATION_EXPORT_API.md)).
- **Context menus:** **Explain rule** (book icon) opens a side tab with full rule details; Apply fix (wrench icon) and Copy message (clipboard icon), then a separator, then hide options: Hide rule from view, Hide rule in this file. On folders/files: Hide folder, Hide file, Copy path; on files: Fix all in file, Show only this file. On severity nodes: Hide this severity.
- **Explain rule:** Right-click a violation and choose **Explain rule** (or run **Saropa Lints: Explain rule** from the command palette and pick a rule) to open a tab beside your code with the rule’s problem message, how to fix, severity, impact, OWASP mapping (if any), and a link to the ROADMAP.
- **Violation tooltips:** Show rule name and a “More” link to rule documentation (ROADMAP).
- **Summary → Violations:** Click **Total violations** in the Summary view to open the Violations view with all findings (clears any active filters). By severity / By impact rows open Violations with the matching filter.
- **Problems view:** Right-click a problem and choose **Saropa Lints: Show in Saropa Lints** to focus the Violations view filtered to the active file.

The **File Risk** view ranks files by weighted violation density (same weights as the Health Score). Files with critical violations appear first with a flame icon. Click a file to filter the Violations view to that file.

The **Security Posture** view shows OWASP Mobile and Web Top 10 coverage based on the active rules and violations. Right-click a category to export an OWASP compliance report.

The **Config** view shows Enabled, Tier, Run analysis after config change, **Detected** (Flutter and packages from `pubspec.yaml`), and actions (Open config, Initialize config, Run analysis).

**TODOs & Hacks** — Todo-Tree-style markers (TODO, FIXME, …) **after you opt in** to workspace scanning (`saropaLints.todosAndHacks.workspaceScanEnabled`, default **off** to avoid heavy full-repo I/O). Until then, the view shows **Enable workspace scan…** (or use **TODOs & Hacks: Enable workspace scan**). No `violations.json` required. Default globs: Dart, YAML, TypeScript, JavaScript; add `**/*.md` to `includeGlobs` if you want Markdown. Toolbar: Refresh, Toggle group by tag / folder. Auto-refresh on save respects the same gate. Custom regex: `saropaLints.todosAndHacks.customRegex`.

The **Logs** view lists analysis reports from `reports/`. Each log shows a parsed hint (e.g. violation counts, init tier). A "Run Analysis" action appears when the latest report is over 1 hour old.

## Settings

| Setting | Default | Description |
|--------|--------|-------------|
| `saropaLints.enabled` | `true` | Lint integration for this workspace (upgrade checks, status-bar treatment). Overview stays usable when off; use **Set Up Project** to add the package and config. |
| `saropaLints.tier` | `recommended` | Tier used when enabling or re-initializing (essential, recommended, professional, comprehensive, pedantic). |
| `saropaLints.runAnalysisAfterConfigChange` | `true` | Run `dart analyze` after init when enabling. |
| `saropaLints.runAnalysisOpenEditorsOnly` | `false` | When true, `Run Analysis` runs `dart/flutter analyze` only for Dart files currently open in VS Code (workspace text documents) under the detected project root (pubspec.yaml directory). |
| `saropaLints.issuesPageSize` | `100` | Max violations shown per file in the Violations tree (1–1000). Remaining appear as “and N more…”. |
| `saropaLints.violationsGroupBy` | `impact` | Default tree grouping: **impact** lists Critical / High first; use **severity** for Error / Warning / Info. Change anytime from the Violations toolbar. |

**Sidebar defaults:** **Commands** (searchable index of every command), **Overview & options**, and **Violations** show in the activity bar by default. Overview includes embedded Health Summary, Next Steps, and Riskiest Files groups when violations exist. **Package Details** appears automatically after a Vibrancy scan. Turn on standalone **Config**, Summary, Security, File Risk, Package Vibrancy, TODOs, etc. from **Overview & options → Sidebar** or Settings (`saropaLints.sidebar.show*`).

| **TODOs & Hacks** | | |
| `saropaLints.todosAndHacks.workspaceScanEnabled` | `false` | When **true**, the view scans the workspace for comment markers (resource-intensive). |
| `saropaLints.todosAndHacks.tags` | `["TODO", "FIXME", "HACK", "XXX", "BUG"]` | Tags to search for in comments (case-sensitive). |
| `saropaLints.todosAndHacks.includeGlobs` | `["**/*.dart", "**/*.yaml", "**/*.ts", "**/*.js"]` | Glob patterns for files to scan. |
| `saropaLints.todosAndHacks.excludeGlobs` | `["**/node_modules/**", "**/.dart_tool/**", "**/build/**", "**/.git/**"]` | Extra exclude patterns (merged with search.exclude). |
| `saropaLints.todosAndHacks.maxFilesToScan` | `2000` | Maximum number of files to scan; view shows a message when capped. |
| `saropaLints.todosAndHacks.autoRefresh` | `true` | Refresh the TODOs & Hacks view when a file is saved (debounced). |
| `saropaLints.todosAndHacks.groupByTag` | `false` | When true, group tree by tag (TODO, FIXME, …) then by file; when false, by folder then file. |
| `saropaLints.todosAndHacks.customRegex` | `""` | Optional regex override for comment markers. Use capture group 1 for tag, optional group 2 for snippet. Empty = default (//, #, <!-- + tags). Invalid regex falls back to default. |

## Commands

- **Saropa Lints: Getting Started** — Open the walkthrough with a guided tour of all features.
- **Saropa Lints: Set Up Project (pubspec + config)** — Add `saropa_lints` to the project and run init (and optionally analyze).
- **Saropa Lints: Turn Off Lint Integration** — Disable integration for this workspace (does not remove files).
- **Saropa Lints: Run Analysis** — Run `dart analyze` / `flutter analyze`.
- **Saropa Lints: Initialize / Update Config** — Write analysis_options.yaml with the current tier (uses write_config).
- **Saropa Lints: Open Config** — Open `analysis_options_custom.yaml` or `analysis_options.yaml`.
- **Filter by text…** / **Filter by type…** / **Filter by rule…** — Filter the Violations tree (view toolbar).
- **Clear filters** / **Clear suppressions** — Reset filters or hidden items (view toolbar when active).
- **Saropa Lints: Show All Violations** — Open the Violations view and show all findings (clears filters). Used when clicking "Total violations" in Summary.
- **Saropa Lints: Show in Saropa Lints** — Focus the Violations view filtered to the active editor's file (e.g. from Problems view context menu or command palette).
- **Group by…** — Change how the Violations tree is organized: Severity, File, Impact, Rule, or OWASP Category (view toolbar).
- **Explain rule** — On a violation in the Violations tree (context menu) or from the command palette (pick a rule): open a side tab with full rule details (message, fix, severity, impact, OWASP, ROADMAP link).
- **Apply fix** — On a violation in the Violations tree (context menu): run the Dart analyzer's quick fix for that location without opening the file.
- **Fix all in this file** — On a file in the Violations tree (context menu): run all available quick fixes for that file bottom-up.
- **TODOs & Hacks: Refresh** — Refresh the TODOs & Hacks view (full rescan only when workspace scan is enabled).
- **TODOs & Hacks: Enable workspace scan** — Turn on `workspaceScanEnabled` so marker search can run.
- **Create Saropa Lints Instructions for AI Agents** — Create `.cursor/rules/saropa_lints_instructions.mdc` in the workspace from the bundled template (Overview title bar or Command Palette). Gives AI agents project guidelines for working on saropa_lints.
- **TODOs & Hacks: Toggle group by tag / folder** — Switch between grouping by folder→file→line and by tag→file→line (view toolbar).

### Violation context menu: Hide options

On a violation, the two “Hide” options mean:

| Option | Effect |
|--------|--------|
| **Hide rule from view** | Hides that rule **everywhere** in the Violations tree (all files). |
| **Hide rule in this file** | Hides that rule **only in this file**; the same rule still appears in other files. |

(“Hide this impact” is not shown on violations: it would hide all violations with that impact level, which is confusing from a single violation. Severity nodes still have “Hide this severity”.)

These are **view-only** suppressions: they do not change `analysis_options.yaml` or source code. They are stored in workspace state and only affect what the Violations tree shows.

**To undo or manage:** Use **Clear suppressions** in the Violations view toolbar (it appears when any suppressions are active). That clears all hidden folders, files, rules, rule-in-file, severities, and impacts at once. There is no per-item “unhide”;
 clearing restores everything. To see or edit raw suppressions you would need to inspect workspace state (e.g. extension storage); the UI only offers Clear suppressions.
- **Export OWASP Compliance Report** — Generate a markdown report with Mobile/Web Top 10 coverage tables and gap analysis.

## API for other extensions

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

The file contract `reports/.saropa_lints/violations.json` remains the primary integration point; the API is optional and allows Log Capture to avoid disk reads and to refresh analysis for specific files. For the violation export schema, see the root [VIOLATION_EXPORT_API.md](../VIOLATION_EXPORT_API.md).

## Integration

The `reports/.saropa_lints/violations.json` file is also used by [Saropa Log Capture](https://pub.dev/packages/saropa_log_capture) for bug report correlation — crash reports include the project's health score and OWASP violations affecting the crash file.

## Links

- [Saropa Lints on pub.dev](https://pub.dev/packages/saropa_lints)
- [GitHub](https://github.com/saropa/saropa_lints)

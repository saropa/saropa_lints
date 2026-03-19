# Saropa Lints — VS Code Extension

Enable and configure [Saropa Lints](https://pub.dev/packages/saropa_lints) from the IDE. No terminal init command: turn the extension **on** and it sets up `pubspec.yaml` and `analysis_options` for you.

After installing, run **"Saropa Lints: Getting Started"** from the Command Palette for a guided tour of all features.

## Requirements

- Dart SDK (or Flutter SDK) on PATH
- A Dart/Flutter project (workspace with `pubspec.yaml`)

## Usage

1. Open a Dart/Flutter project.
2. Open the **Saropa Lints** view (checklist icon in the activity bar).
3. Click **Enable Saropa Lints**. The extension will:
   - Add `saropa_lints` to `dev_dependencies`
   - Run `dart pub get` (or `flutter pub get`)
   - Run `dart run saropa_lints:write_config --tier recommended --target <workspace>` (headless)
   - Optionally run `dart analyze`
4. Run **"Saropa Lints: Getting Started"** from the Command Palette for a guided tour of all features.
5. Use **Run Analysis** and **Open Config** as needed. Issues appear in the **Issues** view when `reports/.saropa_lints/violations.json` exists (written by the analyzer).

## Health Score

A single 0–100 number in the **Overview** and **status bar**, computed from violation count and impact severity. Higher is better:

- **80–100** (green): Good shape — few issues, none critical.
- **50–79** (yellow): Needs work — some high-impact issues.
- **Below 50** (red): Serious problems — many critical/high-impact violations.

The status bar shows the score with a delta from the last run (e.g. "Saropa: 78 ▲4"). When violations decrease, a celebration message includes the score change.

## Issues view

The Issues view shows violations in a **tree**: first by **severity** (Error, Warning, Info), then by **project structure** (folders and files). Each file lists violations (capped per file; excess shown as “and N more…”).

- **Group by (toolbar):** Change how the tree is organized — by Severity (default), File, Impact, Rule, or OWASP Category. Click the tree icon in the toolbar to switch.
- **Filters (toolbar):** Filter by text (file path, rule, or message), Filter by type (severity and impact), Filter by rule (multi-select). When active, the view shows “Showing X of Y”.
- **Suppressions:** Right-click a folder, file, violation, or severity node to hide it from the tree (e.g. “Hide folder”, “Hide rule”). Suppressions are persisted; use **Clear suppressions** in the toolbar to restore all.
- **Code Lens:** In Dart files that have violations, a lens at the top shows e.g. “Saropa Lints: 3 issues — Show in Saropa”. Click to open the Issues view filtered to that file.
- **Context menus:** **Explain rule** (book icon) opens a side tab with full rule details; Apply fix (wrench icon) and Copy message (clipboard icon), then a separator, then hide options: Hide rule from view, Hide rule in this file. On folders/files: Hide folder, Hide file, Copy path; on files: Fix all in file, Show only this file. On severity nodes: Hide this severity.
- **Explain rule:** Right-click a violation and choose **Explain rule** (or run **Saropa Lints: Explain rule** from the command palette and pick a rule) to open a tab beside your code with the rule’s problem message, how to fix, severity, impact, OWASP mapping (if any), and a link to the ROADMAP.
- **Violation tooltips:** Show rule name and a “More” link to rule documentation (ROADMAP).
- **Summary → Issues:** Click **Total violations** in the Summary view to open the Issues view with all issues (clears any active filters). By severity / By impact rows open Issues with the matching filter.
- **Problems view:** Right-click a problem and choose **Saropa Lints: Show in Saropa Lints** to focus the Issues view filtered to the active file.

The **File Risk** view ranks files by weighted violation density (same weights as the Health Score). Files with critical violations appear first with a flame icon. Click a file to filter the Issues view to that file.

The **Security Posture** view shows OWASP Mobile and Web Top 10 coverage based on the active rules and violations. Right-click a category to export an OWASP compliance report.

The **Config** view shows Enabled, Tier, Run analysis after config change, **Detected** (Flutter and packages from `pubspec.yaml`), and actions (Open config, Initialize config, Run analysis).

**TODOs & Hacks** — A Todo-Tree-style sidebar view that lists TODO, FIXME, HACK, XXX, and BUG comment markers by scanning workspace files. No Dart analyzer or violations.json; works in any workspace with supported file types (Dart, YAML, Markdown, TypeScript, JavaScript by default). Tree shows by folder → file → line (or by tag → file → line when "Group by tag" is on). Click a line to open the file at that line. Use the **Refresh** or **Toggle group by tag / folder** buttons in the view toolbar, or **TODOs & Hacks: Refresh** from the command palette. Auto-refresh on save is optional (see settings). Optional custom regex override is supported (see `saropaLints.todosAndHacks.customRegex`).

The **Logs** view lists analysis reports from `reports/`. Each log shows a parsed hint (e.g. violation counts, init tier). A "Run Analysis" action appears when the latest report is over 1 hour old.

## Settings

| Setting | Default | Description |
|--------|--------|-------------|
| `saropaLints.enabled` | `false` | Master switch. When on, the extension has set up the project and you can run analysis from the UI. |
| `saropaLints.tier` | `recommended` | Tier used when enabling or re-initializing (essential, recommended, professional, comprehensive, pedantic). |
| `saropaLints.runAnalysisAfterConfigChange` | `true` | Run `dart analyze` after init when enabling. |
| `saropaLints.issuesPageSize` | `100` | Max violations shown per file in the Issues tree (1–1000). Remaining appear as “and N more…”. |

| **TODOs & Hacks** | | |
| `saropaLints.todosAndHacks.tags` | `["TODO", "FIXME", "HACK", "XXX", "BUG"]` | Tags to search for in comments (case-sensitive). |
| `saropaLints.todosAndHacks.includeGlobs` | `["**/*.dart", "**/*.yaml", "**/*.md", "**/*.ts", "**/*.js"]` | Glob patterns for files to scan. |
| `saropaLints.todosAndHacks.excludeGlobs` | `["**/node_modules/**", "**/.dart_tool/**", "**/build/**", "**/.git/**"]` | Extra exclude patterns (merged with search.exclude). |
| `saropaLints.todosAndHacks.maxFilesToScan` | `2000` | Maximum number of files to scan; view shows a message when capped. |
| `saropaLints.todosAndHacks.autoRefresh` | `true` | Refresh the TODOs & Hacks view when a file is saved (debounced). |
| `saropaLints.todosAndHacks.groupByTag` | `false` | When true, group tree by tag (TODO, FIXME, …) then by file; when false, by folder then file. |
| `saropaLints.todosAndHacks.customRegex` | `""` | Optional regex override for comment markers. Use capture group 1 for tag, optional group 2 for snippet. Empty = default (//, #, <!-- + tags). Invalid regex falls back to default. |

## Commands

- **Saropa Lints: Getting Started** — Open the walkthrough with a guided tour of all features.
- **Saropa Lints: Enable** — Add saropa_lints to the project and run init (and optionally analyze).
- **Saropa Lints: Disable** — Turn the extension off for this workspace (does not remove files).
- **Saropa Lints: Run Analysis** — Run `dart analyze` / `flutter analyze`.
- **Saropa Lints: Initialize / Update Config** — Write analysis_options.yaml with the current tier (uses write_config).
- **Saropa Lints: Open Config** — Open `analysis_options_custom.yaml` or `analysis_options.yaml`.
- **Filter by text…** / **Filter by type…** / **Filter by rule…** — Filter the Issues tree (view toolbar).
- **Clear filters** / **Clear suppressions** — Reset filters or hidden items (view toolbar when active).
- **Saropa Lints: Show All Issues** — Open Issues view and show all issues (clears filters). Used when clicking "Total violations" in Summary.
- **Saropa Lints: Show in Saropa Lints** — Focus Issues view filtered to the active editor's file (e.g. from Problems view context menu or command palette).
- **Group by…** — Change how the Issues tree is organized: Severity, File, Impact, Rule, or OWASP Category (view toolbar).
- **Explain rule** — On a violation in the Issues tree (context menu) or from the command palette (pick a rule): open a side tab with full rule details (message, fix, severity, impact, OWASP, ROADMAP link).
- **Apply fix** — On a violation in the Issues tree (context menu): run the Dart analyzer's quick fix for that location without opening the file.
- **Fix all in this file** — On a file in the Issues tree (context menu): run all available quick fixes for that file bottom-up.
- **TODOs & Hacks: Refresh** — Rescan the workspace for TODO/FIXME/HACK/XXX/BUG markers and refresh the TODOs & Hacks view.
- **Create Saropa Lints Instructions for AI Agents** — Create `.cursor/rules/saropa_lints_instructions.mdc` in the workspace from the bundled template (Overview title bar or Command Palette). Gives AI agents project guidelines for working on saropa_lints.
- **TODOs & Hacks: Toggle group by tag / folder** — Switch between grouping by folder→file→line and by tag→file→line (view toolbar).

### Violation context menu: Hide options

On a violation, the two “Hide” options mean:

| Option | Effect |
|--------|--------|
| **Hide rule from view** | Hides that rule **everywhere** in the Issues tree (all files). |
| **Hide rule in this file** | Hides that rule **only in this file**; the same rule still appears in other files. |

(“Hide this impact” is not shown on violations: it would hide all violations with that impact level, which is confusing from a single violation. Severity nodes still have “Hide this severity”.)

These are **view-only** suppressions: they do not change `analysis_options.yaml` or source code. They are stored in workspace state and only affect what the Issues tree shows.

**To undo or manage:** Use **Clear suppressions** in the Issues view toolbar (it appears when any suppressions are active). That clears all hidden folders, files, rules, rule-in-file, severities, and impacts at once. There is no per-item “unhide”;
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

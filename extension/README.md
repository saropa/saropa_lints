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
- **Context menus:** Apply fix (run quick fix without opening the file), Fix all in file, Hide folder/file/rule/rule-in-file/severity/impact, Copy path, Copy message.
- **Violation tooltips:** Show rule name and a “More” link to rule documentation (ROADMAP).
- **Summary → Issues:** Click **Total violations** in the Summary view to open the Issues view with all issues (clears any active filters). By severity / By impact rows open Issues with the matching filter.
- **Problems view:** Right-click a problem and choose **Saropa Lints: Show in Saropa Lints** to focus the Issues view filtered to the active file.

The **File Risk** view ranks files by weighted violation density (same weights as the Health Score). Files with critical violations appear first with a flame icon. Click a file to filter the Issues view to that file.

The **Security Posture** view shows OWASP Mobile and Web Top 10 coverage based on the active rules and violations. Right-click a category to export an OWASP compliance report.

The **Config** view shows Enabled, Tier, Run analysis after config change, **Detected** (Flutter and packages from `pubspec.yaml`), and actions (Open config, Initialize config, Run analysis).

The **Logs** view lists analysis reports from `reports/`. Each log shows a parsed hint (e.g. violation counts, init tier). A "Run Analysis" action appears when the latest report is over 1 hour old.

## Settings

| Setting | Default | Description |
|--------|--------|-------------|
| `saropaLints.enabled` | `false` | Master switch. When on, the extension has set up the project and you can run analysis from the UI. |
| `saropaLints.tier` | `recommended` | Tier used when enabling or re-initializing (essential, recommended, professional, comprehensive, pedantic). |
| `saropaLints.runAnalysisAfterConfigChange` | `true` | Run `dart analyze` after init when enabling. |
| `saropaLints.issuesPageSize` | `100` | Max violations shown per file in the Issues tree (1–1000). Remaining appear as “and N more…”. |

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
- **Apply fix** — On a violation in the Issues tree (context menu): run the Dart analyzer's quick fix for that location without opening the file.
- **Fix all in this file** — On a file in the Issues tree (context menu): run all available quick fixes for that file bottom-up.
- **Export OWASP Compliance Report** — Generate a markdown report with Mobile/Web Top 10 coverage tables and gap analysis.

## Integration

The `reports/.saropa_lints/violations.json` file is also used by [Saropa Log Capture](https://pub.dev/packages/saropa_log_capture) for bug report correlation — crash reports include the project's health score and OWASP violations affecting the crash file.

## Links

- [Saropa Lints on pub.dev](https://pub.dev/packages/saropa_lints)
- [GitHub](https://github.com/saropa/saropa_lints)

# Saropa Lints VS Code Extension — Design

**Status:** Draft for review  
**Goal:** The extension is the **primary way** to use saropa_lints.

**Issues view (tree):** Implemented 2026-03-14 — severity → path tree, filters, suppressions; see `bugs/history/20260314/ISSUES_TREE_IMPLEMENTATION_SUMMARY.md`. It has a **master on/off switch**; when **on**, it sets up the project (pubspec + analysis_options), runs init and analysis, and provides all views and controls. **If the extension doesn't replace the init process from the user's perspective, we have failed.** The Dart analyzer + saropa_lints plugin remain the execution plane for linting; the extension owns setup, config, and UX.

---

## 0. Success criteria

- **Master on/off switch:** One setting to enable/disable the extension's behavior. When **on**, the extension has set up the project (pubspec + analysis_options) and the user never has to run `dart run saropa_lints:init` manually.
- **Setup when turned on:** Turning **on** adds `saropa_lints` to `pubspec.yaml` (dev_dependency) and creates/updates `analysis_options.yaml` (and `analysis_options_custom.yaml` as needed). No separate "add package then run init" step.
- **Init and analysis from the extension:** Extension can run the init process and the analysis process (commands and/or automatic). User runs these from the extension, not from the terminal.
- **Package promotes the extension:** The saropa_lints package (README, pub.dev) explicitly tells users to install the VS Code extension for the best experience.
- **Cursor compatible:** Extension targets a slightly older VS Code engine so it runs in Cursor and VS Code.
- **Dual publishing:** Extension is published to both **Open VSX** (Cursor, VSCodium) and **VS Code Marketplace**.

---

## 1. Why an extension (vs. dev dependency only)

| Pain | Extension addresses |
|------|----------------------|
| **Issue groups hard to see** | Dedicated views: by tier, category, impact, file, rule; filters and grouping in one place. |
| **No trends** | Persist summaries over time; charts for “issues by rule/file over last N runs”. |
| **Toggling rules = editing YAML** | UI to enable/disable rule groups (tier, category, single rule); extension writes `analysis_options.yaml` / custom file. |
| **Flaky analysis_options** | Single source of truth in extension state; generate/repair config from extension; optional “lock” to avoid manual edits overwriting. |
| **Logs scattered** | Single place to open analysis/test/publish logs, with parsing and “next step” hints. |
| **What to do next** | Suggestions: “Fix 3 critical in this file”, “Enable these 12 zero-issue rules”, “Run baseline for new violations”. |

The extension does **not** run the lint engine inside the IDE—`dart analyze` and the native plugin do that. The extension sets up the project, runs init/analyze, reads outputs, drives config, and provides all views and actions.

---

## 2. Data sources

- **Primary:** `reports/.saropa_lints/violations.json` (existing [Violation Export API](https://github.com/saropa/saropa_lints/blob/main/VIOLATION_EXPORT_API.md)).
  - Gives: config (tier, enabled rules, platforms, packages, userExclusions, maxIssues), summary (bySeverity, byImpact, issuesByFile, issuesByRule), and full violations list.
- **Config:** `analysis_options.yaml` and `analysis_options_custom.yaml` in workspace root.
  - Extension can read/write (or “suggest” edits) for rule toggles and tier.
- **Logs (optional):**
  - `reports/YYYYMMDD/*_analysis_violations_*.log`
  - `reports/YYYYMMDD/*_dart_test*.log`
  - Publish script output (when run from integrated terminal or captured path).
- **Rule metadata:** Extension can ship (or fetch from package) a static map: rule → tier, category, impact, so “issue groups” can be by category/tier even when not in the JSON.

Schema 1.0 already has `issuesByRule`, `issuesByFile`, `bySeverity`, `byImpact`, `config.tier`, `config.userExclusions`. Gaps to consider:
- **Category:** Not in violations.json. Options: (a) add `ruleCategory` to export, or (b) bundle rule→category in extension (e.g. from `lib/src/rules/` layout or a generated JSON).
- **Trends:** Extension-only: append-only local store (e.g. `reports/.saropa_lints/history.json` or SQLite) keyed by sessionId/timestamp, storing summary + optional issuesByRule/issuesByFile counts.

---

## 3. Architecture (high level)

```
┌─────────────────────────────────────────────────────────────────┐
│  VS Code Extension (Saropa Lints)                               │
│  - Views: Issues by group, Trends, Config, Logs, Suggestions    │
│  - Commands: Apply config, Run analyze, Open log, Suggest next  │
│  - State: last violations.json path, history DB, user prefs      │
└──────────────────────────┬─────────────────────────────────────┘
                           │ read / write
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Workspace                                                        │
│  - reports/.saropa_lints/violations.json  (read)                 │
│  - analysis_options.yaml + analysis_options_custom.yaml (r/w)     │
│  - reports/YYYYMMDD/*.log (read)                                 │
└──────────────────────────┬─────────────────────────────────────┘
                           │ produced by
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Dart Analyzer + saropa_lints plugin (unchanged)                  │
│  - Still added as dev_dependency + analysis_options              │
│  - Extension does not replace the plugin                         │
└─────────────────────────────────────────────────────────────────┘
```

- **Activation:** When workspace has Dart (e.g. `pubspec.yaml`). If master switch is **on**, extension also ensures pubspec and analysis_options are set up.
- **Refreshing:** File watcher on `violations.json`; manual “Refresh” and “Saropa: Run analysis” commands.

---

## 3a. Master on/off switch

- **Single setting:** e.g. `saropaLints.enabled` (workspace or user). When **off**, the extension does nothing (no setup, no views, no commands that modify the project). When **on**, the extension is fully active.
- **Turn on (first time):**
  1. Add `saropa_lints` to `pubspec.yaml` under `dev_dependencies` (version: latest compatible, or a range like `^8.0.0`).
  2. Run `dart pub get` (or prompt user to run it).
  3. Create or update `analysis_options.yaml` and `analysis_options_custom.yaml` so that saropa_lints is configured (tier + plugin block). This **is** the init process—either the extension invokes `dart run saropa_lints:init --tier <default>` or the extension generates the same config that init would produce. **User never runs init manually.**
  4. Optionally run analysis once to populate violations.json and show the Issues view.
- **Turn off (optional behavior):** Leave files as-is (user keeps the dependency and config but extension stops acting), or offer a command "Remove Saropa Lints from project" that removes the dev_dependency and restores analysis_options. Default: leave as-is.
- **UI:** Status bar item or sidebar: "Saropa Lints: On" / "Off" with click to toggle, or "Enable" / "Disable" in a Saropa Lints view.

---

## 3b. Setup when turned on (replacing init)

- **Extension owns setup.** When the user turns the extension **on**, the extension:
  - Ensures `saropa_lints` is in `pubspec.yaml` (dev_dependency). If not, add it and run `dart pub get`.
  - Ensures `analysis_options.yaml` includes the saropa_lints plugin and diagnostics (tier-based rule set). Either call `dart run saropa_lints:init` internally (user never types it) or implement the same config output in the extension.
  - Ensures `analysis_options_custom.yaml` exists with sensible defaults (platforms, packages, max_issues, output).
- **Tier selection:** On first setup, prompt for tier (essential / recommended / professional / comprehensive / pedantic) or default to `recommended`. Stored in workspace state or analysis_options_custom.
- **Success criterion:** From the user's point of view, **there is no init process**. Only "Turn on Saropa Lints" → project is configured. All config changes (tier, rule toggles) happen through the extension UI.

---

## 3c. Running init and analysis from the extension

- **Saropa: Initialize / Update config:** Command that (re)generates analysis_options from current tier and overrides. Implementation: call `dart run saropa_lints:init --tier <tier>` or write config directly. Used when user changes tier or after "Repair config".
- **Saropa: Run analysis:** Command that runs `dart analyze`. Output and diagnostics appear in the IDE and in violations.json; extension refreshes views from violations.json.
- **Automatic analysis:** Optional setting to run analysis after init or config change.
- **Progress/feedback:** Show "Initializing Saropa Lints...", "Running analysis..." while running.

---

## 3d. Package tells users to install the extension

- **README (saropa_lints package):** Prominent section near the top: "**Recommended:** Install the Saropa Lints VS Code extension—one-click setup, no init command, issue views, config from the UI." Links to VS Code Marketplace and Open VSX (for Cursor, VSCodium).
- **pub.dev:** Description and/or Installing section can repeat the recommendation and links.
- **Optional:** Short note in generated analysis_options_custom.yaml or a comment: "Get the VS Code extension: [link]."

---

## 3e. Cursor compatibility

- **Engine:** In the extension's `package.json`, set `engines.vscode` to a **conservative** value so it runs on Cursor's slightly older VS Code engine. Example: `"vscode": "^1.74.0"` or `"^1.80.0"`. Avoid requiring the latest VS Code APIs.
- **Testing:** Validate in Cursor (install from Open VSX or side-load) and in VS Code.
- **Open VSX:** Cursor often uses Open VSX; publishing there is required for Cursor users to discover the extension.

---

## 3f. Publishing (Open VSX + VS Code Marketplace)

- **Both registries:**
  - **VS Code Marketplace:** `@vscode/vsce` (`vsce publish`). Publisher account and PAT from marketplace.visualstudio.com.
  - **Open VSX:** `ovsx` CLI (e.g. `npx ovsx publish`). Eclipse Foundation account and token from open-vsx.org. Used by Cursor, VSCodium.
- **CI:** One workflow that builds the VSIX and publishes to both (e.g. `vsce publish` then `ovsx publish` with same VSIX, or an action like `HaaLeo/publish-vscode-extension`).
- **package.json:** Include `repository`, `license`, `displayName`, `publisher`, `icon`, `CHANGELOG.md`; use `.vscodeignore` to keep package small.

---

## 3g. Extension package.json config (aligned with Drift Advisor)

**Reference:** Saropa Drift Advisor (`D:\src\saropa_drift_advisor\extension\package.json`). This section reviews its config pattern and defines the same for the proposed saropa_lints extension so setup is concrete.

### What Drift Advisor does

- **Activation:** `activationEvents: ["onLanguage:dart"]` — activates when a Dart file is opened. No master on/off; extension is always “on” once activated.
- **Settings prefix:** All settings under one prefix: `driftViewer.*` (e.g. `driftViewer.port`, `driftViewer.discovery.enabled`, `driftViewer.linter.enabled`). Grouped with dots: `driftViewer.performance.slowThresholdMs`, `driftViewer.fileBadges.enabled`.
- **Configuration block:** `contributes.configuration` with `"title": "Saropa Drift Advisor"` and `properties` for each setting (type, default, description; enum/min/max where needed). No master switch; they use per-feature toggles (e.g. `driftViewer.linter.enabled`).
- **Views container:** Custom activity bar icon via `viewsContainers.activitybar` with id `driftViewer`, title, icon `$(database)`.
- **Views:** Under that container (`driftViewer.schemaSearch`, `driftViewer.databaseExplorer`, `driftViewer.pendingChanges`) and under `debug` with `when` clauses: `driftViewer.serverConnected`, `driftViewer.hasEdits`, `inDebugMode && driftViewer.serverConnected`. Context keys are set in code.
- **viewsWelcome:** When `!driftViewer.serverConnected`, show troubleshooting + commands (Retry, Forward Port, Select Server). Empty state drives “what to do next.”
- **Commands:** All under a namespace: `driftViewer.refreshTree`, `driftViewer.viewTableData`, etc. Titles often “Saropa Drift Advisor: …” for discoverability. Menus use `when`: `view == driftViewer.databaseExplorer`, `viewItem == driftTable`, etc.
- **Engines:** `"vscode": "^1.85.0"` (newer than Cursor-friendly 1.74–1.80).

### What saropa_lints extension must add (proposed setup)

- **Master switch (Drift has none):** Add a single setting that gates the whole extension:
  - `saropaLints.enabled` (boolean, default `false` for “opt-in”). Workspace-scoped so “on” applies to the current project. When `false`, extension does not modify project, does not run init/analyze, and views show the “Turn on” welcome.
- **Activation:** Same as Drift: `activationEvents: ["onLanguage:dart"]` (or `workspaceContains:pubspec.yaml` if we want to activate on Dart projects even before opening a .dart file). On activate, if `saropaLints.enabled` is false, register views and commands but no setup/analysis; when user turns on, then run setup (pubspec + analysis_options) and init/analyze.
- **Settings prefix and schema:** Use one prefix `saropaLints.*` and a single `contributes.configuration` block, e.g.:

```json
"configuration": {
  "title": "Saropa Lints",
  "properties": {
    "saropaLints.enabled": {
      "type": "boolean",
      "default": false,
      "description": "Enable Saropa Lints for this workspace. When on, the extension sets up pubspec and analysis_options and runs analysis; when off, it does nothing."
    },
    "saropaLints.tier": {
      "type": "string",
      "enum": ["essential", "recommended", "professional", "comprehensive", "pedantic"],
      "default": "recommended",
      "description": "Default tier when enabling or re-initializing."
    },
    "saropaLints.runAnalysisAfterConfigChange": {
      "type": "boolean",
      "default": true,
      "description": "Run dart analyze after init or config change when enabled."
    }
  }
}
```

- **Views container:** Like Drift, own activity bar icon: `viewsContainers.activitybar` id `saropaLints`, title “Saropa Lints”, icon e.g. `$(checklist)` or `$(shield)`.
- **Views:** Under that container: e.g. `saropaLints.issues`, `saropaLints.summary`, `saropaLints.config`, `saropaLints.logs`, `saropaLints.suggestions`. Use `when` so they only make sense when enabled and (where applicable) when violations/data exist, e.g. `when == saropaLints.enabled` (if we expose that as a context key) or always show but content shows “Turn on” when disabled.
- **viewsWelcome:** When extension is disabled or no analysis yet: “Saropa Lints is off” or “No analysis yet” with **[Enable Saropa Lints]** and optionally **[Run analysis]** once enabled. Mirrors Drift’s “No server connected” welcome.
- **Commands:** Namespace `saropaLints.*`: e.g. `saropaLints.enable`, `saropaLints.disable`, `saropaLints.runAnalysis`, `saropaLints.initializeConfig`, `saropaLints.repairConfig`, `saropaLints.openConfig`. Titles “Saropa Lints: …” for search. Menus: view/title and view/item with `when` including `saropaLints.enabled` where relevant.
- **Context key:** Set in code e.g. `setContext('saropaLints.enabled', true/false)` so `when` clauses can show/hide views or menu items. Optionally `saropaLints.hasViolations` for badge/visibility.
- **Engines:** Use a conservative `"vscode": "^1.74.0"` (or `^1.80.0`) for Cursor compatibility; Drift’s ^1.85.0 is too new for Cursor.

### Summary: config vs Drift

| Aspect | Drift Advisor | Saropa Lints (proposed) |
|--------|----------------|-------------------------|
| Master switch | None (always on when Dart) | `saropaLints.enabled` (default false), workspace |
| Activation | onLanguage:dart | onLanguage:dart (or workspaceContains:pubspec.yaml) |
| Settings prefix | driftViewer.* | saropaLints.* |
| Views container | activitybar driftViewer | activitybar saropaLints |
| Empty state | viewsWelcome when !serverConnected | viewsWelcome when !enabled or no analysis |
| Context keys | driftViewer.serverConnected, hasEdits, etc. | saropaLints.enabled, (optional) hasViolations |
| Engines | ^1.85.0 | ^1.74.0 or ^1.80.0 (Cursor-safe) |

---

## 4. Views (issue groups and more)

- **Saropa: Issues**
  - Tree or flat list of violations; group by: **Impact** | **Rule** | **File** | **Tier** | **Category** (if available).
  - Filters: severity, impact, rule name, file path.
  - Click → reveal in editor at line.
  - Badge: total count (and optionally critical count).

- **Saropa: Summary**
  - One pane: tier, enabled rule count, total violations, by severity, by impact.
  - Optional: “Zero-issue rules” count (from config.enabledRuleNames vs. issuesByRule).

- **Saropa: Trends** (if history is stored)
  - Simple charts: total violations over time; top N rules by count over last K runs; “new” vs “fixed” if we store deltas.
  - Helps spot regressions and progress.

- **Saropa: Config**
  - Read-only display of effective tier, platforms, packages, maxIssues, outputMode (from last violations.json config).
  - Actions: “Open analysis_options_custom.yaml”, “Set tier to …”, “Enable/disable rule group” (writes YAML then prompts “Re-run init?”).

- **Saropa: Logs**
  - List of recent report logs (analysis, test, publish) under `reports/`.
  - Open in editor or in a parsed “Log viewer” with sections (e.g. “Failed step”, “Errors”, “Warnings”). Parsing can be heuristic at first (e.g. “Install dependencies” failed).

- **Saropa: Suggestions**
  - “What to do next”: e.g. “3 critical in lib/auth.dart — fix first”, “12 rules have 0 issues — enable them”, “Run baseline to suppress known violations”, “Upgrade tier to professional for security rules”.
  - Driven by rules: critical count, zero-issue rules, presence of baseline file, current tier.

---

## 5. Turning groups on/off (and taming analysis_options)

- **Tier:** Command “Saropa: Set tier to &lt;essential|recommended|…&gt;” → set in custom config or call `dart run saropa_lints:init --tier &lt;tier&gt;` (if init is the source of truth).
- **Rule groups:** “Enable/disable by category” (e.g. “async”, “security”, “stylistic”) or “by impact” (e.g. enable all “opinionated”).
  - Implementation: extension keeps a rule→category/impact map; applies bulk true/false to diagnostics section of analysis_options (or to analysis_options_custom if that’s where overrides live). Then either run `init` to merge, or extension writes the merged result (if we define a clear contract).
- **Single rule:** Toggle in “Saropa: Config” or from context menu on a rule in “Saropa: Issues”.
- **Flaky analysis_options:** 
  - **Option A:** Extension “owns” the diagnostics section: user edits only analysis_options_custom (or extension UI); extension (or init when invoked by extension) always regenerates analysis_options from tier + overrides. Reduces drift.
  - **Option B:** “Repair config” command: read current YAML, validate against known rules/tiers, fix or offer to reset to a tier preset.
  - **Option C:** “Lock” mode: extension warns when analysis_options.yaml is changed on disk and offers to revert to last extension-generated state.

Recommendation: start with **Option B** (“Repair / validate config”) and “Set tier” + “Toggle rule/group” that call `dart run saropa_lints:init` with the right args (if init supports it) or write only analysis_options_custom and re-run init. That avoids reimplementing full config generation in the extension.

---

## 6. Log analysis

- **Discovery:** Scan `reports/` for `*_analysis_violations_*.log`, `*_dart_test*.log`, and optionally a known publish log path/pattern.
- **Display:** List by date; open raw file; optional “parsed” view with:
  - Analysis: “No issues” vs “N errors, M warnings” (from existing report format).
  - Test: failed test names and first line of stack trace.
  - Publish: failed step name (e.g. “Install dependencies”) and last few lines.
- **Suggestions:** “Last analysis had 3 errors — open log”, “Tests failed — open test log”.

No need to parse every log format in v1; start with “open this log” and one or two key patterns (e.g. “FAILED”, “Error”, “Failed step”).

---

## 7. Suggest what to do next

- **Inputs:** Last violations.json (summary + config), optional history, presence of baseline file, current tier.
- **Examples:**
  - If `bySeverity.error > 0`: “Fix N errors first” + link to Issues view filtered by error.
  - If `byImpact.critical > 0`: “Address critical issues in &lt;files&gt;.”
  - If many rules enabled and `issuesByRule` has many zeros: “Consider enabling these zero-issue rules: …” (from config.enabledRuleNames minus rules in issuesByRule).
  - If no baseline and high count: “Run Saropa: Create baseline to suppress existing violations.”
  - If tier is “recommended” and project has security-related packages: “Consider professional tier for security rules.”
- **Surface:** “Saropa: Suggestions” view + optional status bar item (“Saropa: N critical”) that opens the view.

---

## 8. Scope and phasing

- **In scope:** Views (Issues by group, Summary, Config, Logs, Suggestions), config toggles (tier + rule/group), log discovery and open/parsed view, “what to do next” suggestions, optional trend storage and charts. Optionally “repair/validate” analysis_options to reduce flakiness.
- **Out of scope (v1):** Running the Dart analyzer inside the extension (still invoke `dart analyze`); replacing the dev dependency (plugin is still required for linting).

**Phasing suggestion:**
- **Phase 1 (MVP):** Master switch; turn on → add saropa_lints to pubspec, run pub get, run init (or generate config), optionally run analysis. "Saropa: Run analysis" and "Saropa: Initialize config" commands. Read violations.json + analysis_options; “Saropa: Issues” view with grouping by impact/rule/file; “Saropa: Summary”; open file at line; “Saropa: Open config”.
- **Phase 2:** “Saropa: Config” view and tier/rule toggles (via init or YAML write); “Repair config” command.
- **Phase 3:** Log discovery and open/parsed logs; “Saropa: Suggestions” view and status bar.
- **Phase 4:** History storage and “Saropa: Trends” view.

---

## 9. Dependencies and constraints

- **VS Code:** Use standard extension API; no dependency on Dart/Flutter extension except for “Dart project” detection (e.g. pubspec.yaml).
- **saropa_lints:** violations.json and analysis_options already exist. Extension invokes init when needed or replicates its output. Optional later: add `ruleCategory` to violation export or ship rule→category JSON in the extension.
- **analysis_options:** Behavior must stay compatible with `dart run saropa_lints:init` so that users who don’t use the extension still get the same result when they run init.

---

## 10. Open decisions

1. **Category in export vs. in extension:** Add `ruleCategory` (and maybe `ruleTier`) to violations.json for consistency, or keep export minimal and bundle category map in the extension?
2. **Config ownership:** Should the extension ever write analysis_options.yaml directly, or always go through `saropa_lints:init`?
3. **History location:** `reports/.saropa_lints/history.json` (or SQLite) vs. extension global state (workspace-agnostic). Workspace-local is better for “trends in this project”.
4. **Naming:** “Saropa Lints” vs. “Saropa Lints Companion” to make clear it’s an add-on to the package.

---

## Summary

The extension adds **views** (issues by group, summary, config, logs, suggestions, trends), **controls** (tier and rule/group toggles, repair config), and **guidance** (suggestions, log parsing) on top of the existing saropa_lints dev dependency and violation export. The extension is the primary way to use saropa_lints (master switch, setup when on, init/analysis from UI). The package tells users to install the extension; it is Cursor compatible and published to Open VSX and Marketplace. If the extension doesn't replace init for the user, we have failed. It makes configuration less flaky and usage more visible and actionable. Phasing from “read-only views + open config” to “config toggles → repair → logs → suggestions → trends” keeps the first deliverable small and builds on the existing VIOLATION_EXPORT_API and init workflow.

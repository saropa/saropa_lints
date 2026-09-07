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

   **Internal bullets** — Same bans apply (no test counts, no file inventories). The what→why→must-do template is optional for infra-only entries.

   **Internal section** — Changes with no end-user impact (publish/CI tooling, internal refactors, test harness, plan housekeeping, developer scripts) belong under a `### Internal` heading at the bottom of the version section, never in `### Added` / `### Changed` / `### Fixed`. NEVER use `<details><summary>Maintenance</summary>`. Test: if a pub.dev or Marketplace user would notice, it is top-level; otherwise Internal.

   **Unreleased convention** — The top changelog section MUST use the heading `## [X.Y.Z] — Unreleased` (with ` — Unreleased` suffix) while work is in progress. All new entries go into this ONE section — never create a second unreleased section or bump the version number. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) at publish time via `_strip_unreleased_suffix()`. The version numbers in `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle.

   **Tagged changelog** — Published versions use git tag `vx.y.z`. Each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [16.0.0-beta.9] — Unreleased

Activation is now resilient — commands register and the sidebar warns on failure instead of going blank. The Findings Dashboard absorbs the full-project audit as a scope selector and gains severity coloring, clickable file paths and rule names, a filter-aware page limit, and JSON export. Sidebar rows show live counts, and per-file analysis no longer blocks the extension host. Publish-pipeline fixes stop the i18n audit from launching Ollama and the local pub.dev fallback from flooding the terminal.

### Fixed (Extension)

- Fixed "command not found" errors for dashboard and config commands when unrelated activation setup threw an error. The 80-command registration block now always executes regardless of whether earlier setup (providers, watchers, LSP) succeeded or failed. No action required.
- When activation setup fails, the sidebar now shows a warning banner ("Activation Error — Check Extension Host log for details") instead of empty panels. No action required.
- Fixed "Prune ignores" crashing the Flutter daemon on Windows by spawning `dart` directly instead of via a `cmd.exe` wrapper, eliminating process-tree complexity that competed for SDK resources. All `dart` CLI invocations now use direct spawn; `flutter` (a `.bat` wrapper) retains the shell path, and an ENOENT fallback retries with a shell for legacy SDK installs. No action required.
- Fixed per-file analysis (`runAnalysisForFiles`) blocking the extension host with a synchronous `spawnSync` call for the entire `dart analyze` duration. Converted to the async `runInWorkspaceAsync` variant that the full-workspace analysis already uses, keeping the event loop responsive and adding a Cancel button to the progress notification. No action required.
- Sidebar dashboard rows now show live counts instead of static labels — Findings Dashboard shows violation count and health score, Package Dashboard shows how many packages have features to adopt, and the activity bar badge now reflects only lint violations. No action required.

### Improved (Extension)

- Full Audit is now a "Source" scope selector inside the Findings Dashboard toolbar (Live diagnostics / Full project / Changed vs main / Changed vs branch) instead of a separate sidebar entry that opened a VS Code quick-pick menu and a second report panel. Progress and results render in the same dashboard you already have open, the chosen scope is remembered across sessions, and a legacy `saropa_lints` version's audit output normalizes to the current severity vocabulary the same way the batch report already did.
- Audit report: severity is now color-coded — error rows get a red left border, warning rows amber, and severity pills/chips use tinted text for quick scanning.
- Audit report: all counts use thousands separators (e.g. 151,919 instead of 151919) for readability.
- Audit report: filter chip counts use a consistent badge style instead of bare parenthesized numbers.
- Audit report: removed the duplicate read-only KPI chip strip — the interactive filter chips already show the same counts.
- Audit report: the 500-row page limit now applies after filtering, not before. The pagination note clarifies this.
- Audit report: added "Export JSON" button that saves the full diagnostics to a user-chosen file.
- Audit report: file paths are visually clickable (link color + underline on hover) and now jump to the diagnostic line instead of just opening the file.
- Audit report: rule names are clickable — clicking one filters the table to show only findings for that rule, with a dismissible banner.
- Audit report: when errors or warnings exist, INFO findings are hidden by default so actionable findings are immediately visible. Click the INFO chip to show them.
- Audit report: a severity summary bar below the header shows the error/warning/info ratio as colored segments with tooltips. No action required.
- Audit report: clicking a file path now jumps to the exact column, not just the line. No action required.

### Internal

- Sidebar data is now computed once per refresh cycle (`prepareRefreshCycle`) instead of being cleared and rebuilt by each provider independently. Eliminates redundant `readVisibleLiveViolations` + `computeLiveHealthScore` calls when multiple sidebar sections refresh together.
- Fixed i18n audit (`--mode audit`) probing Ollama engine availability via `low_quality_entries()`, which self-provisioned the daemon and pulled the model — an expensive, risky side effect during a read-only coverage check. Audit now uses `audit_only=True` to scan cache provenance tags without any subprocess calls. No action required.
- Fixed `dart pub publish --force` (local fallback) printing its full file-tree listing to stdout, flooding the terminal and pushing prior publish-step output out of the scrollback buffer. Output is now captured; only the pub.dev confirmation line is surfaced. No action required.
- Added manual translations to `dictionaries.py` for 5 gaps across 4 locales (ar, de, fil, pt) that MT engines did not translate: RSS warning description, "Dev Tool Budget", "Set Cap", "Translation Engine (Ollama)". No action required.
- Added `COGNATES` approval list to `dictionaries.py` for words that are spelled identically in specific target languages (e.g. "Source" in French). Previously each cognate needed a per-locale `"X": "X"` passthrough scattered across the file; the centralized list merges them at import time, with locale-code validation (typos raise `ValueError`), empty/duplicate-locale guards, drift detection (`--fail-on-drift`), and a `--check-cognates` flag (now in the publish pipeline) that catches conflicts and DO_NOT_TRANSLATE redundancies. No action required.

---

## [16.0.0-beta.8]

🌍 **Milestone: 25 languages, 2,319 translated fields** — extension ships in 25 locales (Arabic, Bengali, Chinese, Dutch, English, Farsi, Filipino, French, German, Hebrew, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Swahili, Thai, Turkish, Ukrainian, Urdu, Vietnamese).

Fixed a sidebar action that could crash on a project's first scan or run twice on rapid clicks, and shortened several sidebar labels. System Health now monitors the whole machine — not just saropa_lints' own processes — with proactive warnings and one-click fixes. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.8/CHANGELOG.md)

### Added (Extension)

- Machine-wide health monitoring: system RAM, every Dart analysis server, Flutter daemon, and Ollama/llama-server process grouped by category with contextual recommendations and one-click actions (restart server, set heap cap, reclaim orphans, unload model). Accessible from the sidebar and command palette. No action required.
- Dev Tool Budget indicator: a single percentage showing how much of the machine's RAM dev tools consume versus a configurable target (`saropaLints.systemHealth.devToolBudgetPercent`, default 60%). Warns when dev tools exceed the budget. No action required.
- Proactive warnings when free RAM drops below a configurable threshold (`saropaLints.systemHealth.systemMemoryWarningPercent`, default 15%) or any single analysis server exceeds a configurable size (`saropaLints.systemHealth.analysisServerWarningGB`, default 4 GB), plus a one-time session-start check. System-wide free RAM now appears in the status bar tooltip. No action required.

### Fixed (Extension)

- Fixed "Fix stale ignores" sidebar action crashing with ENOENT when the `reports/.saropa_lints/` directory does not yet exist (e.g. first run on a project). The directory is now created before the scan CLI writes its JSON output. No action required.
- Fixed all stale-ignore commands allowing concurrent execution when double-clicked or triggered in rapid succession, which could launch duplicate CLI processes. A busy guard now shows a brief status-bar message and drops the duplicate click. No action required.

### Changed (Extension)

- Shortened sidebar action labels: "Fix stale ignores" → "Prune ignores", "Initialize / Update config" → "Update config". Descriptions now carry the detail the labels shed. No action required.

### Internal

- Extracted `createBusyGuard` to `commandGuards.ts` as a reusable concurrency guard with visible status-bar feedback, replacing four identical inline busy-flag patterns in the stale-ignore commands. No action required.
- Routed the three sidebar Actions labels ("Run analysis", "Prune ignores", "Update config") through `l10n()` with new `sidebar.actions.*` keys in `en.json`, closing an i18n gap where two of the three labels were hardcoded English. No action required.
- Hardened Machine Health dashboard: Windows-only platform guard with localized message, narrow viewport wrapping/scrolling, two-tier query/notification throttle (2 min / 10 min) to reduce unnecessary PowerShell shell-outs, undefined-arg guard on Unload Ollama Model command. No action required.
- System memory warning now honors the user's configured threshold directly instead of silently clamping to a 20% minimum at session start. No action required.

---

## [16.0.0-beta.7]

Process Health now tracks only saropa-owned memory, so other VS Code windows no longer trigger false alerts. The tooltip adds a trend arrow, sparkline chart, and early leak detection. Also fixes the dashboard's "Enable all recommended packs" button showing stale results. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.7/CHANGELOG.md)

### Added

- New rule `add_resolution_workspace` (recommended tier, WARNING): flags a package listed in a Dart pub workspace that is missing `resolution: workspace` in its pubspec.yaml, catching version drift before `pub get` fails. Quick fix inserts the key after the `environment:` block. No action required.
- New rule `flag_missing_workspace_member` (recommended tier, INFO): flags a workspace root whose subdirectories contain pubspec.yaml files not listed in the `workspace:` list, catching packages that silently resolve independently instead of joining the shared lockfile. Scans up to 3 levels deep, skips listed members' children (no example/ false positives). No action required.
- New rule `workspace_dependency_version_sync` (recommended tier, INFO): flags a workspace whose member packages declare different version constraints for the same dependency, catching version drift that produces misleading pubspecs since all members share one lockfile. No action required.
- New rule `workspace_member_order` (recommended tier, INFO): flags a workspace root whose `workspace:` list entries are not in alphabetical order, making large workspaces easier to scan and reducing merge conflicts from unordered insertions. No action required.
- New rule `prefer_publish_to_none` (recommended tier, INFO): flags a pubspec.yaml that has no `publish_to` field and appears to be an application (missing homepage/repository metadata), guarding against accidental `dart pub publish` to pub.dev. Quick fix inserts `publish_to: none` after `description:` (or after `name:` if there is no description). No action required.
- New rule `avoid_dependency_overrides` (recommended tier, WARNING): flags any non-empty `dependency_overrides:` section in pubspec.yaml, which silently diverges the resolved dependency graph from declared constraints and masks real conflicts. No action required.
- New rule `prefer_pinned_version_syntax` (stylistic tier, INFO): flags caret-range version constraints (`^X.Y.Z`) in app pubspecs (`publish_to: none`), suggesting exact pins for reproducible builds. Conflicting pair with `prefer_caret_constraint_in_app` — opt-in only. No action required.
- Process Health tooltip now shows an RSS trend arrow (↑ rising / → stable / ↓ falling) next to the saropa section header. A rising trend is an early memory-leak warning before the red threshold trips. Based on a 5-sample split-mean with a 10% change threshold. No action required.
- Process Health tooltip includes a Unicode sparkline chart (▁▂▃▄▅▆▇█) showing saropa RSS over the last ~30 minutes. Gives a visual memory profile at a glance without opening a panel. No action required.
- Process Health now detects monotonically rising RSS and shows a one-time "possible memory leak" notification before the red threshold trips. Based on 8/10 consecutive non-decreasing comparisons, tolerating brief GC dips. No action required.

### Fixed

- Fixed Process Health status bar falsely attributing system-wide Dart memory to saropa_lints. The red/yellow thresholds now evaluate saropa-owned process RSS only (scan daemon, CLI scans), not the aggregate of all Dart processes. A 12GB analysis server from another VS Code window no longer makes the saropa_lints indicator go red.
- Process Health tooltip now shows a per-process breakdown: saropa-owned processes first (with health check), Flutter daemons, then other Dart processes as informational. Top 3 processes per category listed by RSS. Hints when multiple analysis servers are detected.
- Fixed "Enable all recommended packs" button showing "no applicable rule packs detected" while the dashboard table correctly showed 87 detected packs. The button now uses `getDetectedPackIds`, a shared helper that both the table and the button call, so the two surfaces can never diverge. No action required.

### Internal

- Hardened `add_resolution_workspace` quick fix: re-verifies `resolution: workspace` absence before inserting (guards against stale diagnostics and batch "fix all" duplicates), added trailing-newline guard when inserting after the environment block, and tolerates blank lines inside the environment block. The detection regex now also accepts quoted forms (`"workspace"` / `'workspace'`).
- Hardened `flag_missing_workspace_member` scan: deduplicated path-normalization logic into a shared public helper, extended case-insensitive path comparison to macOS (default APFS), and made the `build/` directory skip case-insensitive.
- Extracted `findDivergentDependencyConstraints` from `workspace_dependency_version_sync` into the pubspec constraint parser, creating a pure-function seam for unit testing and removing an unreachable block-dep guard that the parser already handles.
- Hardened Process Health tooltip: process labels truncated at 30 chars for width safety, analysis server detection broadened with `--protocol=lsp` for future binary rename resilience, ✓/↑ conflict resolved (rising trend suppresses the healthy checkmark to avoid mixed signals), and partition assertion added to catch filter coupling drift.
- Expanded RSS history ring buffer from 5 to 30 samples for sparkline rendering while preserving trend computation on the most recent 5.
- Added monotonic growth detector as a pure function with 8/10 threshold — fires a one-time informational toast directing the user to the health panel.
- Hardened sparkline renderer to use reduce loops instead of spread for stack safety, and ProcessMonitor returns a defensive copy of the RSS history buffer.
- Added `classifyProcess()` as a discriminated union (`ProcessCategory` + label) replacing the duplicated predicate chains across tooltip, snapshot, and label functions. Boolean predicates (`isSaropaProcess`, `isDaemonProcess`, `isAnalysisServerProcess`) now delegate to it, and the tooltip builder uses a single-pass partition instead of three independent filter passes with a runtime assertion.
- Fixed leak detection "Open Health Panel" button silently no-oping because it called unregistered command `showHealthPanel` instead of the registered `showProcessHealth`.
- Added 45 tests total in the systemHealth suite (90 passing): `classifyProcess` discriminated union (8), process partition mutual exclusivity (3), marker substring containment invariant (1), plus the existing `processLabel` (9), `isAnalysisServerProcess` (4), `truncateLabel` (5), RSS trend boundary (2), `renderSparkline` (6), `detectMonotonicGrowth` (7).
- Extracted `getDetectedPackIds` in `rulePackDefinitions.ts` as the single source of truth for pack applicability. The dashboard table and "Enable all" button both call it instead of inlining `isPackDetected` filters independently.
- Replaced the collapsed HTML Maintenance expander changelog convention with a `### Internal` heading, enforced by a pre-commit hook and a publish-time gate. No action required.

---

## [16.0.0-beta.6]

Fixes a false positive in the l10n diagnostic provider and catches more CI-only test failures locally before publishing. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.6/CHANGELOG.md)

### Fixed

- Fixed the l10n diagnostic provider (`saropa-l10n`) reporting false-positive "expects params but none passed" warnings when `l10n()` receives its params via a variable or expression instead of an inline object literal. The parser now recognizes non-literal second arguments and skips static key extraction for them. No action required.
- Fixed the l10n diagnostic silently accepting `l10n('key', undefined)` and `l10n('key', null)` without warning when the template expects params. These keyword arguments are now correctly treated as "no params passed." No action required.

### Internal

- Introduced a branded `OpaqueParams` type for the l10n parser sentinel, preventing accidental use of the sentinel string in key-extraction functions at compile time.
- Extracted `extractBalancedBrace` as a shared export from `l10nParsers.ts`, deduplicating the brace-matching loop previously inlined in `extractParamsBlock`.
- Added missing `usesTypeResolution` override to `AvoidCaseSensitivePathComparisonRule` (uses `staticType`).
- Added 4 missing codes to the `flutter_skill_lints` migration pack that moved from TODO/PARTIAL to HAVE.
- Publish script: `create_git_tag` now prompts before moving a stale remote tag to HEAD on retry instead of hard-failing.
- Publish script: `_find_workflow_run` skips already-failed runs so retry doesn't re-attach to old workflows.
- Publish script: delta test pass now includes integrity and config test suites when rule/config files change, catching cross-cutting failures locally instead of deferring to CI.

---

## [16.0.0-beta.5]

Hardens memory safety and scan reliability across the extension and CLI. Memory pressure detection now attributes usage correctly, preventing false pauses on large projects, and a stalled scan on save can no longer disable the feature for the session. Also fixes false positives in timer-lifecycle and manifest rules, and adds orphaned-process detection at startup. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.5/CHANGELOG.md)

### Added

- Memory debug mode: set `SAROPA_LINTS_DEBUG_MEMORY=1` to log per-cache size breakdowns on every periodic memory trend line. Helps diagnose which plugin caches are growing when investigating memory pressure. No action required.
- Orphaned process check: finds model host and Dart processes left behind by earlier sessions, reports how much memory they hold, and offers to reclaim them after you confirm. Runs once shortly after startup and is also available from the Process Health panel and the command palette. No action required.
- New `saropaLints.scanOnSave.timeoutSeconds` setting (default 180, range 30 to 1800) caps how long a single scan on save may run before it is abandoned. Raise it on very large projects if scans are cut short. No action required.
- Diagnostic triage script: `python scripts/triage_scan.py` post-processes `--format json` scan output into five priority buckets (errors → bulk fixes → individual triage → dev code → forked code), replacing manual categorization of bulk lint sweeps. Supports `--suppress-dirs`, `--dev-dirs`, `--bulk-threshold`, and `--format json` for machine-readable output. No action required.

### Fixed

- Fixed stale diagnostics persisting in the Problems panel after adding `// ignore:` directives or fixing code. The scan CLI now honors `// ignore:` and `// ignore_for_file:` directives, and "Restart Analysis Server" now also clears scan-on-save diagnostics and rescans open editors. No action required.
- Fixed hard RSS valve pausing all rules based on the analysis server's total process memory instead of the plugin's own contribution. On large projects the server's AST caches and resolved element model consume 70–90% of RSS, tripping the valve even when the plugin's estimated footprint is under 100 MB. The valve now checks plugin attribution: it only pauses rules when the plugin's estimated memory exceeds 100 MB or 5% of process RSS. A separate unconditional panic threshold at 90% of system RAM provides last-resort OOM protection. No action required.
- Fixed the Drift Advisor integration opening every Dart file in the workspace on each 30-second poll, which could cascade into repeated whole-project scans and exhaust system memory until VS Code crashed. Table lookups now read files directly without creating editor documents, and results are cached until Dart sources change. No action required; the integration is off by default, so only users who enabled it were affected.
- Fixed scan on save treating a file opened by other extension code as a file the user opened, which let any extension's background file access trigger lint scans. Scans now run only for files you actually have open or have saved. No action required.
- Fixed a stalled scan permanently disabling scan on save for the rest of the session. Scans now time out, are canceled when a newer save supersedes them, and release their slot on every failure path. No action required.
- Fixed the memory status bar showing a red critical badge next to a healthy memory figure when the real trigger was orphaned background processes. The badge now names whichever condition actually tripped, and a memory reading shows the same total the warning threshold is compared against. No action required.
- Fixed every level of memory pressure painting the status bar error red, including informational ones such as a light rule shed. Only genuinely severe states are red now, with moderate states amber and informational states left uncolored. No action required.
- Fixed a Dart file open only as one side of a diff or merge view never receiving scan on save diagnostics, because only ordinary tabs were recognized. No action required.
- Fixed a canceled scan leaving an orphaned Dart process on macOS and Linux, and a failure to launch the process cleanup command being able to crash the extension host. No action required.
- Fixed the memory status bar showing plugin state that was no longer live, so a project with the analyzer plugin switched off could still display paused rules and a large memory figure from an earlier session. Nothing is shown now unless the plugin is enrolled and the reading is from the current session. No action required.
- Fixed the memory safety valve never resuming rules after it paused them. Clearing the plugin's own caches made it a minor memory contributor, but release was tested against total process memory, which the analysis server keeps high, so rules stayed paused indefinitely. No action required.
- Fixed the memory valve repeatedly re-measuring every cache while the analysis server sat above the memory cap, which made the common case the most expensive one. No action required.
- Fixed the translation tooling abandoning multi-gigabyte model host processes on every run, by terminating whole process trees rather than a parent alone, sweeping for survivors, and refusing to start when abandoned processes are already present. No action required.
- Fixed `require_copy_with_null_handling` firing on `copyWith` methods where all fields using `??` are non-nullable types. The sentinel/wrapper pattern adds no value when a field cannot be null, so `??` is the correct pattern. The rule now checks class field nullability before emitting. No action required.
- Fixed `require_permission_manifest_android` asserting a missing manifest entry when it cannot read AndroidManifest.xml. Downgraded to INFO severity since the rule is advisory only. No action required.
- Fixed `require_url_launcher_queries_android` asserting missing `<queries>` blocks when it cannot read AndroidManifest.xml. Downgraded to INFO severity since the rule is advisory only. No action required.
- Fixed `require_workmanager_for_background` firing on `Timer.periodic` inside `State` subclasses with proper `cancel()` in `dispose()`. UI-lifecycle timers are not background tasks. No action required.
- Extended `require_workmanager_for_background` to also detect `Stream.periodic` — the same background-polling anti-pattern using the stream API. No action required.
- Fixed `avoid_ios_battery_drain_patterns` firing on `Timer.periodic` inside `State` subclasses with proper `cancel()` in `dispose()`. Widget-bound timers cannot drain battery in the background. No action required.

### Internal

- Triage script (`scripts/triage_scan.py`): added diagnostic-key validation (warns when `filePath`/`severity`/`ruleName` are missing), and a 29-test unit-test suite covering path classification, bucket assignment, and output formatting. No action required.
- Changelog guard hook (`scripts/hooks/changelog_guard.py`): removed the `package.json` version-drift check that false-alarmed every beta cycle because VS Code uses a different version scheme. Guard 1 (multiple unreleased sections) still triggers on `package.json` edits. No action required.
- Extracted shared `isTimerLifecycleBoundToDisposableState()` helper to eliminate duplicate private implementations across timer lifecycle rules. No action required.

---

## [16.0.0-beta.4]

Adds five new lint rules covering unsafe late-final fields, constructor and widget ordering, and Equatable prop sorting. Extends the dashboards with inline rule guidance, embedded Package Dashboard tabs, live sidebar data, and scan progress in Health Panel and Project Map. Also fixes several false-positive and over-suppression bugs in existing rules. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.4/CHANGELOG.md)

### Added

- New rule `avoid_public_late_final_without_initializer`: flags public `late final` fields with no initializer — a runtime crash waiting to happen if any caller reads the field before it is assigned. No action required.
- New rule `avoid_unnecessary_factory_constructor`: flags `factory` constructors whose body just returns `ClassName(...)` — a factory keyword adds indirection with no benefit when the constructor could be a regular named or unnamed constructor. No action required.
- New rule `no_internal_method_docs`: flags DartDoc comments on private methods in non-library code — internal-only methods rarely benefit from doc comments and the noise makes public API docs harder to find. No action required.
- New rule `prefer_state_class_below_widget`: flags a `State<X>` class declared above its `StatefulWidget X` — the conventional Flutter ordering places the widget's public API first. Closes the DCM `keep-state-below-its-widget` gap. No action required.
- New rule `prefer_sorted_equatable_props`: flags an Equatable `props` getter whose field order doesn't match the class's field declaration order — props that drift out of declaration order are harder to audit for missing fields. Closes the DCM `sort-equatable-props` gap. No action required.
- Findings dashboard: the top-rules expander now shows each rule's how-to-fix guidance, OWASP mapping, related rules, and supersedes/migration notes inline, instead of requiring a jump to the separate Rule Explain screen. This detail is now also available during live analysis, not only after a batch export. No action required.
- Package Dashboard: the Upgrades, Full report, and Known issues tabs now render their content inline instead of opening a separate editor tab. Compare still opens as its own panel. No action required.
- Analysis Optimizer (embedded in the Lints Config dashboard): sortable columns and a working select-all, matching the standalone panel. Sort choice is remembered per dashboard. No action required.
- Project Map: a live percentage progress bar with a file count during scanning, plus pause and cancel, and a Files / Lines / Size summary in the header. Older engines without progress support fall back to the previous elapsed-time view. No action required.
- Project Map reports: the severity and doctor reports now render as sortable typed tables rather than preformatted text, via a new `--format json` mode on both command-line tools. No action required.
- Health Panel: engine cards now show live scan progress ("Scan: N/M files") while the language server is scanning a workspace. No action required.
- Lints Config, Config file tab: a "Migrate config keys" action now appears there when legacy plugin-block keys remain, replacing the sidebar row that previously carried it. No action required.
- Findings dashboard status line and the sidebar's Code Health row now show quality-gate state. A failing gate previously appeared only inside the Code Health screen, so it was invisible unless you went looking for it. No action required.
- Sidebar Code Health and Project Map rows now show live data — health grade and score, and how long ago the project was last scanned — instead of fixed descriptive text. Both read already-computed results and never start a scan. No action required.
- Scan CLI: `--no-exclude` flag disables all hardcoded path exclusions (`example/`, `build/`, `.dart_tool/`, etc.) so the scan covers every `.dart` file it finds. User-supplied `--exclude-globs` still apply. No action required.
- LSP Server: new `saropaLints.lspServer.workspaceScanDelay` setting (default 5 seconds) defers the workspace scan after the analyzer is ready, letting VS Code's startup burst settle first. Set to 0 for immediate scan. No action required.

### Changed

- `require_test_description_convention` now recognizes 23 additional action verbs as good description indicators and uses word-boundary matching to prevent false negatives on substring matches (e.g. "maps" no longer matches inside "hashmaps"). No action required.
- `require_test_description_convention` quick fix now handles interpolated test descriptions — previously it silently skipped them because the full string value was null. No action required.
- `prefer_state_class_below_widget` now detects third-party widget/state pairs — Riverpod's `ConsumerStatefulWidget`/`ConsumerState` and flutter_hooks' `HookStatefulWidget`/`HookState` — in addition to core Flutter's `StatefulWidget`/`State`. No action required.
- Renamed engine names throughout the extension: "Analyzer Plugin" → "Live Analysis", "Scan Daemon" → "Scan on Save" in the Health Panel; "Turn Off Lint Integration" → "Disable Saropa Lints" and "Re-enable In-Process Plugin" → "Re-enable Live Analysis" in the command catalog. Updated notification strings that referenced "Lint integration" to say "Scan on save". No action required.

- Sidebar restructured into three sections totalling 14 rows: Dashboards, Status, and Actions. Rows that open a screen, rows that report state, and rows that run something are now separated, so a row's section tells you what clicking it will do. No setting is flipped from the sidebar any more. No action required.
- Package Dashboard now uses the shared dashboard chrome for page spacing and typography. Body padding, base font size, and line height change slightly as a result; layout is otherwise unchanged.
- The bundled rule catalog now carries correction text and OWASP mappings for every rule, so live analysis can show them without a batch export. This grows the packaged catalog by roughly 0.5 MB. No action required.

### Fixed

- Fixed LSP Server flooding the output channel with `didClose` messages on startup — VS Code sends a burst of didClose notifications for files from the previous session; these are now trace-level and only visible with verbose logging. No action required.
- Fixed `avoid_string_substring` false positives where the index was already guaranteed in bounds by a regex `hasMatch()` guard, an `indexOf()`/`lastIndexOf()` result, or a `RegExpMatch`'s `.start`/`.end`/`.group()`. No action required.
- Fixed `avoid_case_sensitive_path_comparison` false positives on non-path string comparisons: CLI flag literals, Dart import URI comparisons, filesystem root-detection idioms (`dir.path != dir.parent.path`), and identifiers where "path" was embedded in an unrelated word (e.g. "pathology"). Also fixed import-URI suppression failing to detect camelCase `Uri` segments (e.g. `namedUri`) because the boundary check ran on the lowercased name. No action required.
- Fixed `avoid_unsafe_cast` false positives on `ProcessResult.stdout`/`.stderr` cast to `String` — the SDK default encoding always decodes to `String`, so the cast is only unsafe when the call explicitly passes a `null` encoding to request raw bytes. Also fixed a false positive when a cast is preceded by an exact-type `is` check on the same expression in an enclosing `if` condition (e.g. `if (v is List) { v as List }`); only `&&` compounds are recognized as guards — an `is` check inside `||` does not guarantee the type. No action required.
- Fixed `avoid_nullable_interpolation` false positive when a `!= null` guard for the interpolated expression is buried inside a compound `&&` condition (e.g. `if (isChurning(f) && f.churn != null)`), not just a bare `if (expr != null)`. No action required.
- Fixed `avoid_stack_trace_in_production` false positives in developer-tool code: `dart:developer`'s `log()` is now recognized as a diagnostics API (never user-visible output) regardless of package type, and files under a `bin/`/`tool/` directory are skipped even in mixed packages that aren't wholly CLI tools. No action required.
- Fixed `require_url_validation` false positive on local `file://` path validation — the scheme-guard heuristic now also recognizes `.isScheme('file')` checks and the `file` scheme, not just `.scheme` reads against `https`/`http`. No action required.

- Fixed `runtime_tier` being silently ignored when set in `analysis_options_custom.yaml`. The Config file tab writes this key, but the parser only ever recognized `saropa_tier`, so the chosen value was written to disk and then dropped with no warning. It is now recognized as a deprecated alias and reports a migration warning. Set the tier in the `plugins: saropa_lints:` block to have it take effect.
- Fixed the Health Panel reporting scan-on-save as "idle" while it was actually disabled — the status only tracked memory-pressure suspension and never read the master switch, so a disabled scanner looked healthy. No action required.
- Fixed `--format` being swallowed as the target path by the severity report and doctor command-line tools, so the flag had no effect and the positional path was lost. No action required.
- Fixed selecting a package from the embedded Upgrades tab opening the detail pane behind a hidden tab; the dashboard now switches back to Overview first. No action required.
- Fixed Package Dashboard's Full report and Upgrades embedded tabs showing "Generating…" forever on first open, and rendering stale data from the previous scan on subsequent opens. The async builders now read the current scan results instead of the not-yet-assigned options object. No action required.
- Fixed Full report tab's "Expand/Collapse all" button toggling every `<details>` element in the Package Dashboard (charts, package filters, grade breakdown in Overview), not just the Feature Inventory's own disclosures. The script is now IIFE-wrapped and scoped to its own tab container. No action required.
- Fixed the Health Panel engine card showing "scanning N/M files" indefinitely after a canceled workspace scan. The LSP server's scan progress notification now carries an explicit `done` flag on terminal ticks (cancel or completion), so the client no longer relies solely on the filesScanned/totalFiles ratio. No action required.
- Fixed severity report and doctor typed tables falling back to raw text on the first run after install or `pub get`, because Dart's "Building package executable…" stderr banner was mixed into the JSON parse buffer. Only stdout is now accumulated for JSON parsing. No action required.
- Fixed Project Map progress bar never reaching 100% when the CLI's final progress event arrived without a trailing newline. The partial-line flush on process exit now routes through the progress parser instead of bypassing it. No action required.
- Fixed `avoid_nullable_interpolation` false positive on `Match[n]` and `Match.group(n)` in string interpolations — when the regex pattern literal is visible, a group-count parser now verifies the accessed index refers to a required capture group; the parser now also traces through variable assignments (`final re = RegExp(r'...'); re.firstMatch(...)`) and correctly handles groups containing alternation (e.g. `(a|b)` is always required). No action required.
- Fixed `avoid_dynamic_calls_extended` over-suppression: dynamic calls inside catch clauses and finally blocks are no longer wrongly exempted by the try/catch guard (only the try body is exempted). Bare `catch(e)` and `on Object` no longer suppress dynamic-call warnings — only `on NoSuchMethodError` and `on TypeError` indicate intentional duck-typing. No action required.
- Fixed `require_catch_logging` over-suppression: `catch (e) { return null; }` with an unused exception variable was falsely exempt — the return/continue/break exemption now fires only when the exception variable is actually referenced. No action required.
- Fixed `require_url_validation` over-suppression: substring `'file'` no longer matches inside identifiers like `profileId`; `startsWith` guards are now checked against the actual URL variable; CLI exemption is scoped to the file's directory rather than disabling the rule project-wide. No action required.
- Fixed `avoid_global_state` over-suppression: `_hasClearOrResetFunction` now matches exact identifier tokens instead of substrings; `??=` lazy-init detection uses a word-boundary regex instead of raw source text; multi-variable declarations no longer fire duplicate diagnostics. No action required.
- Fixed `require_cache_expiration` over-suppression: `.clear()` detection is now scoped to the flagged cache class's own Map fields rather than matching any `.clear()` in the file; `HashMap`/`hashCode` are no longer treated as crypto-hash indicators. No action required.
- Fixed `avoid_string_substring` over-suppression: `indexOf` results are recognized as safe index sources alongside `RegExpMatch.start`/`.end`/`.group()`; a regex `hasMatch()` guard on the receiver is now accepted in `if`-condition and ternary branches. No action required.
- Fixed `avoid_case_sensitive_path_comparison` over-suppression: the root-detection idiom check now verifies both sides of a `||` share the same base expression. No action required.
- Fixed `require_test_description_convention` false positives on data-driven test descriptions built with string interpolation (e.g. `test('${'$'}{c.rule} should ...', ...)`) — the rule read `stringValue`, which is always null for a non-constant string, so every interpolated description was flagged regardless of its actual wording. It now reads the literal text segments instead. No action required.

### Internal

- Archived 36 tier-1 quick-win proposals already covered by existing rules — 19 implemented under the same name, 8 under a different name or alias, and 9 identified as functional duplicates of rules shipped in prior versions. Updated 15 migration guides to reflect the closures (TODO → HAVE with correct saropa rule name). No action required.
- Added fixture coverage for `require_ios_deployment_target_consistency`'s collection-literal guard — GOOD cases with a rule-name string inside a `Set` and as a `Map` value, confirming `isDataLiteralElement()` (shipped in beta.3) already prevents the false positive reported in a duplicate bug report. No action required.
- Added GOOD fixture cases for `require_catch_logging` and `avoid_swallowing_exceptions` covering fallback-return, loop-continue, and loop-break catch bodies, confirming the return/continue/break handling guard closes the intentional-fallback false positive reported against both rules. No action required.
- Fixed 12 false-positive rule implementations: `avoid_unsafe_reduce` now skips non-empty list/set literals; `avoid_accessing_collections_by_constant_index` now skips write targets (DP row init); `require_catch_logging` and `avoid_swallowing_exceptions` now accept return/continue/break as valid handling; `avoid_dynamic_calls_extended` now exempts Object methods and try/catch-guarded duck-typing; `avoid_unsafe_cast` now recognizes preceding `is` checks; `avoid_global_state` now exempts lazy-init (`??=`) and managed-lifecycle globals; `avoid_case_sensitive_path_comparison` now skips root-detection idioms and CLI flag literals; `avoid_platform_specific_imports`, `avoid_stack_trace_in_production`, `require_cache_expiration`, `avoid_unbounded_cache_growth`, and `require_url_validation` now skip CLI tool and analyzer plugin packages via new `ProjectContext.isCliOrToolPackage()`. No action required.
- Extended `avoid_global_state`'s managed-lifecycle exemption to also recognize a same-file `dispose*` function (previously only `clear*`/`reset*`), and confirmed `late final` globals were already exempt via the existing const/final skip. No action required.
- Fixed `avoid_unnecessary_factory_constructor` compile error against analyzer 12.x — used removed `ClassDeclaration.name` getter instead of `nameToken`, causing the LSP server to crash on startup (exit 255).
- Fixed unsafe `as Map<String, dynamic>` cast in `audit_baseline.dart` — `jsonDecode` on a valid-but-non-object baseline file (e.g. `[]`) threw `TypeError` instead of returning `null` per the documented contract. Replaced with `is!` type check.
- Fixed 6 broken `// ignore:` comments missing the `saropa_lints/` prefix — suppressions in `project_context.dart`, `pubspec_constraint_parser.dart` (3), `project_context_parallel_batch.dart`, and `project_vibrancy_resolved_usage.dart` were silently ineffective.
- Fixed case-sensitive path comparison in `project_vibrancy.dart` — `--file` CLI argument now compared with `p.equals()` for Windows/macOS compatibility.
- Fixed nullable interpolation in `health_export_markdown.dart` — `churn` field interpolated without null guard, producing "null commits" in markdown export.
- Fixed forward-slash path construction in `log_writer.dart` (2 sites) and `init_runner.dart` — replaced string interpolation with `p.join()`/`p.basename()` for cross-platform correctness.
- Filed 13 false-positive bug reports across 13 rules against own-dogfood scan findings (305 total, 295 confirmed FP). See `bugs/` for details.
- Fixed `commandCatalogRegistry.test.ts` failures: added 17 missing catalog entries for commands that existed in `package.json` but had no catalog registration, and marked 15 palette-hidden commands as `internal`. All 17 catalog sync tests now pass.
- Fixed remaining `require_cache_expiration` / `avoid_unbounded_cache_growth` false positives on content-addressed caches: both rules now skip classes keyed by hash/sha/fingerprint/digest (a stale entry under an unchanged key is structurally impossible), skip files under a `bin/`/`tool/` directory in addition to the existing whole-package check, and skip caches with an explicit `.clear()` call anywhere in the same file. No action required.

- Partially migrated the Package Dashboard's parallel stylesheet onto the shared dashboard chrome: the accessibility helper, hero header, status line, and page layout families now come from the shared layer. The remaining duplicated families cannot be adopted piecemeal because the shared chrome's exported functions bundle unrelated rules — adopting the motion helper would also restyle inline code, and adopting the layout helper drags a full body reset with it. Splitting the chrome into single-concern exports is a prerequisite for finishing this.
- Reworked the embedded Known issues tab to prefix element ids and scope its script, preventing collisions with the host dashboard's own search and table when both render in one document.
- Added regression coverage for the areas above: the scan progress event schema and cancel path, the language server's progress notification shape, the rule-catalog correction/OWASP backfill, the report totals parser, the optimizer sort and bulk-select, the rule-detail expander, and the embedded tab contracts.
- Added CI compile-check gate (`dart compile kernel`) for all `bin/` entry points — catches build-breaking analyzer API changes that `dart analyze` misses because rule files are loaded at runtime.
- Added CI `check_analyzer_api_compat.py` script that greps rule files for known-removed analyzer package APIs (e.g. `ClassDeclaration.name.lexeme`) before they reach users as a crash.

- Extracted shared `catchHandlesViaControlFlow()` and `catchBodyUsesException()` utilities into `catch_body_logging_utils.dart` — eliminates duplicated return/continue/break and exception-usage checks between `require_catch_logging` and `avoid_swallowing_exceptions`. No action required.

- Split the shared dashboard chrome stylesheet into single-concern exports, with the existing public functions preserved as compositions so every consumer renders identically. The previous bundling made the layer un-adoptable piecemeal: taking the hero animation also took an unrelated monospace rule, and taking the full-width toggle dragged a whole body reset with it. A unit test now pins each composition.
- Removed a duplicate `.sr-only` accessibility rule from the token layer after confirming every consumer already pairs it with the accessibility helper; the test suite now pins that rule as defined exactly once.
- Fixed 9 self-dogfood lint warnings in test files: 3 `avoid_misused_test_matchers` (raw `true`/`false` → `isTrue`/`isFalse`), 5 `require_test_description_convention` (added "should" keyword to interpolated test descriptions), and 1 `prefer_setup_teardown` (hoisted repeated `_violationsForExample()` call into `setUpAll`).
- Adopted the shared hero animation and reduced-motion rules in the Package Dashboard stylesheet. The summary cards, table toolbar, and footprint toggle stay local by decision, not omission — each differs from its chrome counterpart in layout semantics, domain color vocabulary, or ARIA interaction model, and the reasons are documented in the code. See `plans/PLAN_ext_ui_report_styles.md` for the full disposition.
- Fixed 2 stale curated dictionary keys in `dictionaries.py`: removed the `de` entry whose English source text was rewritten (daemon label, LSP/plugin separation), and capitalized the `fil` "Analyzer Plugin" key to match the current source strings. Patched 48 missing translations across 21 locales — 4 format/loanword strings added to `DO_NOT_TRANSLATE`, 15 locale-specific entries hand-translated. Added `--strict-dnt` flag to `generate_locales.py` — treats `DO_NOT_TRANSLATE` collision warnings as errors for CI gating.
- Added "Make member public (remove underscore)" quick fix for `no_internal_method_docs` — strips the leading `_` from the declaration name as an alternative to the existing "Convert to a regular comment" fix.
- Added fixture files for `no_internal_method_docs`, `prefer_state_class_below_widget`, and `prefer_sorted_equatable_props`. Extended `avoid_public_late_final_without_initializer` fixture with static and multi-variable edge cases.
- Added `DeprecatedNewInCommentReferenceRule` instantiation test to the documentation rules test suite.
- Fixed scan CLI silently excluding `example_packages/` fixtures: the hardcoded `/example` substring in `scan_runner.dart` matched `example_packages/`, the `--files` flag applied exclusions to explicitly named files, and `shouldSkipFile`'s fixture-skip exemption missed relative paths and `example_packages/`. Three-part fix: tightened the substring to `/example/`, bypassed exclusions when `--files` is explicitly provided, and added `startsWith` checks for relative paths.
- Fixed three CodeQL `js/bad-tag-filter` alerts (two reported, one preemptive) in test infrastructure — closing-tag regexes now tolerate attributes and case variants. No action required.
- Added `check_html_tag_regex.py` CI script that detects HTML tag regexes missing case-insensitive flags or attribute-tolerant closing tags before CodeQL reports them on push. No action required.
- Moved `require_test_description_convention` fixture from `example/lib/testing_best_practices/` (where `isTestPath` never matched, so the `FileType.test`-gated rule silently never ran) to `example/lib/test/` with real BAD/GOOD examples covering simple strings and interpolated descriptions. Added to `expectedFromFixtures` in the integration test.
- Added `check_fixture_filetype_match.py` CI script that audits all rules with `applicableFileTypes => {FileType.test}` and verifies their fixture files live at paths matching `isTestPath()` — wired into the publish pipeline as a blocking check via `run_pre_publish_audits()`, and supports `--fix` to bulk-relocate misplaced fixtures via `git mv`. No action required.

---

## [16.0.0-beta.3]

Streamlines the extension sidebar by moving rows that duplicated dashboard controls onto the Findings and Rules & Tiers dashboards instead. Fixes path traversal vulnerabilities in the HTML reporter and package detection, plus false positives in the path-comparison rule and several iOS rules. Also fixes a startup crash on large workspaces and makes the in-editor scan progressive and cancelable. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.3/CHANGELOG.md)

### Changed

- Sidebar collapsed from 25–39 rows to 13 steady-state (15 worst case). Severity toggles, setting-value rows (run-after-config/dependency, UI language, detected packages), and triage rows removed from the Settings panel — each was a duplicate of a richer control on the Rules & Tiers Automation/Extension tabs, Package Dashboard, or Findings Dashboard's top-rules table. No action required.
- Sidebar Tier and Lane rows folded into the Dashboards "Lints Config" row description (`Tier: recommended · Lane: light`), replacing two click-only rows with always-visible state. No action required.
- Sidebar "Migrate config keys" row now appears only while legacy plugin-block keys remain to clean up, instead of rendering unconditionally. No action required.
- Findings dashboard status line gains trend, regression, and security-hotspot pills — the same data the sidebar Status rows showed, now persistent and clickable instead of buried in a collapsible panel. No action required.
- Sidebar Status section: Hotspots, Trends, Score regression, Suppression count, and Last-run rows removed — all now live on the Findings dashboard's status line or are straight duplicates of Findings data. Health row gains a "Last analysis: {ago}" tooltip. No action required.
- Sidebar Status panel now visible on all Dart projects, not just those with violations — Lint integration status was hidden exactly when it mattered most (integration off = no violations = panel gone). No action required.

### Added

- Quick fix for `avoid_misused_test_matchers` — auto-rewrites `expect(x, true)` → `expect(x, isTrue)`, `expect(x, false)` → `expect(x, isFalse)`, `expect(x, null)` → `expect(x, isNull)`, and `expect(x.length, N)` → `expect(x, hasLength(N))`. No action required.
- Rules & Tiers Config file tab: Lane card. Switch between Light (~200 rules in-editor) and Full (all enabled rules) from the same dashboard that already shows every other `analysis_options_custom.yaml` key. No action required.
- Config file tab: the Baseline card now shows a "Diff vs current" subsection listing violations resolved since the baseline and new since the baseline, each with a file/line/rule table. Reads live diagnostics — never triggers a scan and stays current as you edit. No action required.
- Live sidebar badges: the Status view's Activity Bar icon now carries a numeric badge (critical count when any exist, else total violations), and the Dashboards view carries a badge for packages with unadopted features. No action required.
- Rules & Tiers and Project Map dashboards now show a "?" button that opens a list of the tab-jump shortcuts already available (`1`-`7` on Rules & Tiers, `1`/`2` on Project Map) — previously these shortcuts worked but had no in-app way to discover them.

### Fixed

- Fixed path traversal vulnerability in `cross_file report` HTML output — `outputDir` from `--output-dir` is now normalized and rejected if it contains `..` segments. No action required.
- Fixed `avoid_path_traversal` in `detectProjectPackages` — `targetDir` parameter is now canonicalized before reaching `File()`. No action required.
- Fixed `avoid_case_sensitive_path_comparison` false positive on non-string comparisons — null checks, boolean/integer/double/enum guards on path-named variables no longer fire. No action required.
- Fixed `require_ios_deployment_target_consistency` false positive on any string literal containing "async" — the rule's `_ios15PlusApis` map included a bare `'async'` entry intended to detect Swift concurrency, but it substring-matched every Dart string containing "async" (rule names, identifiers, comments). Removed the entry. No action required.
- Hardened 6 iOS rules against false positives on collection-literal data tables — string literals inside list, set, or map literals (rule-name registries, route catalogs, path inventories) are now skipped by `AvoidIos13DeprecationsRule`, `AvoidIosSimulatorOnlyCodeRule`, `RequireIosMinimumVersionCheckRule`, `AvoidIosDeprecatedUikitRule`, `RequireIosDeploymentTargetConsistencyRule`, and `RequireIosCertificatePinningRule`. No action required.
- Sidebar Status panel no longer silently drops the Health row before any analysis has ever run — it now shows a "Health: —" row explaining why, with a one-click link to run analysis. No action required.
- Fixed LSP server crash on startup in large projects — the Dart VM exhausted its OS thread pool when the workspace scan called `lastModifiedSync` / `listSync` on hundreds of files. Replaced sync I/O with batched async equivalents (capped at 20 concurrent file operations) and added error handlers so failures exit cleanly instead of triggering an infinite restart loop. No action required.
- LSP workspace scan is now progressive and cancelable — diagnostics publish incrementally as each file is analyzed, and the scan aborts cleanly on shutdown or config reload instead of racing to completion. Progress is logged every 50 files. No action required.

### Internal

- Fixed 15 pre-existing extension test failures: added missing `onDidChangeConfiguration` mock (13 issuesTree tests), updated stale locale coverage assertions (languagePick), and updated sidebar panel count from 5 to 4 after Help view removal (uxLabels). No action required.
- Updated stale path reference in the UI redesign plan after archiving completed sub-plans. No action required.
- Package Dashboard (Overview and Upgrades tabs): now pulls its color/spacing/radius design tokens from the same canonical token layer already used by the Settings and tab-bar surfaces, instead of only the legacy report stylesheet. No visible change — additive groundwork for retiring the older parallel styling system.
- l10n diagnostics now recognize `// l10n:passthrough` on the same line as a suppress directive for calls whose `{placeholders}` are substituted by caller code (e.g. `pluralize()`) rather than by `l10n()` itself. Annotated all existing `pluralize()`+`l10n()` call sites. No action required.
- Removed `transformProjectMapHtml()` and `webviewThemeOverride()` from `projectMapView.ts` — dead since the standalone Project Map panel switched to the composed `projectMapShell.ts` document in Phase 6; their only remaining reference was a historical code comment.
- Added unit test coverage for `projectMapShell.ts` (shell tab structure, scanning-state pane, done-state pane) and `projectMapReports.ts` (report-card catalog, Reports tab HTML, quality-gate config read/write, panel-message routing) — both had zero tests before this pass.
- Fixed null-unsafe map access and direct `as` casts in `asset_scanner.dart`, `health_cache.dart`, and `saropa_lint_rule.dart` — own-dogfood violations from `require_null_safe_json_access` and `avoid_unsafe_cast`. No action required.
- Fixed 5 own-dogfood `avoid_misused_test_matchers` violations across 4 test files — replaced `expect(x.length, N)` with `expect(x, hasLength(N))`. No action required.
- Extracted shared `sanitizePath()` utility to `path_guard.dart` — centralizes the normalize-and-reject-traversal pattern so future CLI entry points get path safety automatically. No action required.
- README rewritten for readability — cut from 1,598 lines to ~430. Extension detail moved to `doc/guides/extension.md`, configuration reference to `doc/guides/configuration.md`, troubleshooting merged into `doc/troubleshooting.md`, FAQ to `doc/faq.md`. Added alternative package coverage table (46 packages audited, ~75% rule coverage). Deleted redundant `plans/GAP_ANALYSIS.md` — per-package data lives in migration guides.
- Suppressed own-dogfood false positives in `analyzer_compat.dart` (dynamic dispatch, bare catches, swallowed exceptions are intentional version-probing shims) and `scan_runner.dart` (safe-by-construction cast). Fixed nullable interpolation in `DiagnosticCodeLowerCaseCompat.lowerCaseName`.

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

### Internal

- Fixed publish script writing raw pub.dev version to `package.json` instead of the converted extension version — caused preflight version check to fail on every pre-release publish.
- Hardened publish version verification: `_is_head_pushed()` now handles detached HEAD and unreachable remote, `_verify_versions_in_commit` docstring documents that it runs after HEAD is pushed (step 13 after step 12), and `extension_version_for()` idempotency contract is explicit.
- Added `--dry-run` mode to `set_extension_version()` — returns the converted extension version without touching the file, useful for preflight checks that need the expected version without side effects.
- Extracted the status bar tooltip's action-menu rows (`buildStatusBarMenuItems`) and its command allow-list (`STATUS_BAR_TRUSTED_COMMANDS`) into `statusBarLabel.ts`, with a unit test asserting every row's command id is covered by the allow-list — a renamed or added command that falls out of sync would previously break the tooltip link with no test failure.


## [16.0.0-beta.1]

*--- IMPORTANT NOTE ---*

**Major release — LSP server (BETA).** A new standalone LSP server replaces the in-process analyzer plugin as the default diagnostic engine, using far less memory while still providing diagnostics, quick fixes, and per-rule overrides. It's **ON by default** — check its status in the Health Panel. If you hit issues, toggle it off there to fall back to the Analyzer Plugin. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.1/CHANGELOG.md)

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

### Internal

- Extended the extension's Playwright visual-regression harness (`test/ux/generate-pages.ts`) to render the Home hub, two Rules & Tiers tabs, and both Project Map states, which previously had no rendered-HTML coverage at all. Added a `vscode.extensions.getExtension` stub to the shared test mock so the Rules & Tiers dashboard's manifest-driven settings tab can render outside a real VS Code host.
- **Style-system migration: Full Audit report.** `audit/audit-report-styles.ts` now builds on `getDashboardChromeStyles()` (`.dash-hero`, `.chip-strip`/`.chip`, `.toolbar-band`/`.field`, `.btn`, `.dash-table`, `.empty-cta`) instead of a fully bespoke stylesheet — one of the three remaining parallel CSS systems the redesign plan re-deferred at Phases 5 and 7 (`plans/PLAN_extension_ui_redesign.md` §1.5). Only severity-tinted pills, baseline badges, and the deferred-load banner remain bespoke. Added the first-ever `audit-report` fixture to the Playwright UX harness. No markup IDs or client-script selectors changed, so `audit-report-script.ts` needed no edits.
- **Style-system migration: Findings dashboard.** `violationsDashboardStylesParts.ts` now builds on `getDashboardChromeStyles()` instead of a fully bespoke stylesheet — the second of the three parallel CSS systems the redesign plan re-deferred (`plans/PLAN_extension_ui_redesign.md` §1.5). The file shrank from 1337 to a much smaller "extras" sheet carrying only what the shared chrome doesn't cover (severity-tinted pills, the hero gauge's `animation: none !important` override so the chrome's shared entrance keyframe doesn't play on this dashboard's rebuilds). One remaining parallel system (`vibrancy/views/report-styles-parts.ts`, the Package Dashboard) is still deferred.
- Added a `vscode.languages.getDiagnostics` stub to the shared test mock (`test/vibrancy/vscode-mock.ts`) — the sidebar's live-diagnostics fix (above) calls it by default, and the mock's absence was silently breaking sidebar unit tests that don't care about diagnostic content.
- **New `scripts/check_rule_name.py`.** Checks a proposed rule name against the core Dart/Flutter analyzer lint namespace in one second, before any implementation work begins. The same collision gate (`_tier_integrity.py` Check 8) caught 3 rules that needed renaming at publish time three days running (2026-09-02, 2026-09-03, 2026-09-04) — each time meaning a rename across `lib/`, `test/`, and `example/` after the fact. Wired into the rule-authoring checklist (`.claude/skills/lint-rules/SKILL.md`, `CLAUDE.md`) as step 0.
- Extended `scripts/fix_ignores.py`'s rename map with the 3 rules renamed 2026-09-04 (`avoid_dynamic_calls`, `avoid_equals_and_hash_code_on_mutable_classes`, `avoid_implementing_value_types`, all now `_extended`), and fixed the corresponding stale "N/A (stock analyzer rule)" rows in `doc/guides/migration_guides/migration_from_vga.md` to `ENHANCED`.
- `scripts/publish.py` now routes a prerelease version (e.g. `16.0.0-beta.1`, the version this release ships as) to each store's prerelease channel automatically — `vsce package`/`publish`, `ovsx publish`, and `gh release create` all get their prerelease flag derived from the version string, no separate flag or prompt needed. `extension/package.json`'s `version` field, which the Marketplace requires to be a plain `MAJOR.MINOR.PATCH` (no hyphen, even with `--pre-release`), is instead derived via `extension_version_for()`: the stripped core PATCH offset by a channel- and iteration-specific band, so successive beta/rc builds of the same base version get distinct extension versions instead of colliding at the Marketplace/Open VSX level. The `.vsix` filename and store-verification poll stay consistent with whichever version was actually published.

---

## [15.2.12]

Hardens the LSP server against normal editor traffic and adds a `doctor` command to catch misconfigured project settings before they cause confusing warnings. [log](https://github.com/saropa/saropa_lints/blob/v15.2.12/CHANGELOG.md)

### Fixed

- **LSP server handles all standard notifications without crashing.** Added explicit no-op cases for `textDocument/didChange`, `$/cancelRequest`, `$/setTrace`, and `workspace/didChangeConfiguration` so the inert server stays alive under normal VS Code traffic. Two-level logging surfaces server activity in the Output channel: lifecycle events always log, high-frequency messages (didChange, codeAction) are suppressed unless `$/setTrace` is set to `verbose`. No action required.

### Added

- **New `doctor` command** scans consumer project configuration for misplaced keys, missing custom file, and other issues that produce SDK warnings. Run `dart run saropa_lints doctor [directory]`.
- **`--trace` flag for LSP server** enables verbose logging from startup without waiting for the editor to send `$/setTrace`. Useful for standalone debugging: `dart run saropa_lints:lsp_server --trace`.

### Internal

- Pre-commit hook now auto-regenerates category map and migration pack codes when rule files, tier definitions, or migration guides change — eliminates the recurring CI failures from stale generated indexes.
- Closed `unsupported_option` bug for `rule_packs` and `log_level` — investigation confirmed the fix was already implemented; consumer projects just need to run `dart run saropa_lints migrate-config`.
- `migrate-config` now removes orphan `rule_packs:` keys that have no `enabled:` child, and handles trailing comments on the key line.
- Config parser (`_leadingSpaces`) now counts tabs as indentation, matching the scalar parser — fixes silent parse failures on tab-indented YAML.
- `doctor` command now scopes key detection to the `saropa_lints:` plugin block — no longer false-positives on identically named top-level keys.
- Publish script supports `--log-file`, `--log-append`, `--mode`, `--auto-retry`, and `--output-level` flags for non-interactive/CI execution. Auto-detects non-TTY stdin. Mode definitions are unified in a single table driving both CLI and interactive menu.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.

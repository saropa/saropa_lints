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

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

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

    **Tagged changelog** — Published versions use git tag `vx.y.z`. Each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

    **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [15.0.3]

The scan CLI now lets users filter diagnostics by severity, so AI agents and CI pipelines can suppress info-level noise and focus on warnings and errors. The extension also stops losing the in-editor analyzer plugin when Lint integration is switched off and back on, and now reports that plugin's real state instead of implying it from a setting that does not control it. [log](https://github.com/saropa/saropa_lints/blob/v15.0.3/CHANGELOG.md)

### Added

- `--min-severity` flag for the `scan` command filters diagnostics by severity threshold — `--min-severity warning` excludes info-level output from both stdout and the report file, reducing noise for AI agents and CI pipelines. No action required.
- `--max-severity` flag for the `scan` command caps output at a severity ceiling — `--max-severity warning` hides errors so you can triage lower-priority noise in isolation. No action required.

### Added (Extension)

- When Lint integration and the analyzer plugin disagree in a way you probably did not intend — scan-on-save on with in-editor diagnostics silently off, or the multi-gigabyte plugin still loading while lints read as off — the extension now offers once to reconcile it either way. Answer or dismiss it and it does not ask again for that project.

### Fixed (Extension)

- Turning Lint integration off and then on again left the in-editor analyzer plugin switched off — the off step comments out the `plugins:` block in `analysis_options.yaml`, and the on step never put it back, so a project silently lost live diagnostics with no indication of why. Enable now restores the block when it was this extension's own Off that commented it out, leaving new projects (which default to the lighter scan-on-save delivery) untouched. This has proven to be tricky!
- The sidebar now reports the analyzer plugin's actual on-disk state as its own row, so "Lint integration: On" can no longer sit above a project whose `plugins:` block is commented out — clicking that row while it reads Off restores the plugin. No action required.
- The record of which side switched the analyzer plugin off is now stored twice, so a VS Code profile switch or extension-storage reset can no longer make Enable silently stop restoring the plugin. No action required.
- The analyzer plugin row and its restore logic now track every folder in a multi-root window and start working in a window that had no folder open at startup, instead of only the one folder present when the extension activated. No action required.

<details><summary>Maintenance</summary>

- (Extension) Added explicit `"types"` field to both `tsconfig.json` and `tsconfig.test.json` so the TypeScript compiler reliably resolves Node.js globals and test framework types instead of relying on auto-discovery. No action required.
- (Extension) Added `verify-tsconfig-types` build gate that validates both tsconfig files during `precompile` — fails when an imported `@types/*` package is missing from either config's `"types"` array. No action required.

</details>

---

## [15.0.2]

This release focuses on improving the reliability and user experience of the extension's setup workflows. Progress notifications now provide real-time feedback during lengthy operations to clearly communicate the current status. Safeguards have also been introduced to prevent duplicate, conflicting tasks from executing concurrently if a command is triggered multiple times. [log](https://github.com/saropa/saropa_lints/blob/v15.0.2/CHANGELOG.md)

### Fixed (Extension)

- The "Enabling Saropa Lints" progress notification stayed on a single static title for the entire `pub get` step, which can take over a minute on projects with many plugins — with nothing on screen to distinguish "still working" from "stuck," clicking Cancel (or clicking "Enable" again) mid-run was a reasonable reaction. The notification now shows which step is running and a live elapsed-time counter (e.g. "Running pub get… (45s)"). No action required.
- Clicking "Enable" again while an enable flow was already running started a second, fully concurrent flow — both writing `pubspec.yaml`/`analysis_options.yaml` and shelling out to `pub get`/`write_config` at the same time — instead of joining the one already in progress, which could stack duplicate progress notifications and race on the same files. A second call now joins the in-flight run instead of starting a new one. The same fix applies to "Create Baseline" (`saropa_baseline.json`), which had the same gap. No action required.

---

## [15.0.1]

Version 15.0.1 improves the editor extension's responsiveness and resolves a file-parsing bug that prevented the plugin from re-enabling. The setup flow now executes asynchronously to prevent UI freezes, while deactivated lint configurations generate significantly smaller files by omitting unused inline documentation. [log](https://github.com/saropa/saropa_lints/blob/v15.0.1/CHANGELOG.md)

### Fixed (Extension)

- A project whose `plugins:` block is written commented-out (new projects, or one where "Turn Off Lint Integration" was used) no longer gets the full per-rule description dump on every regenerate — the disabled block now keeps only the `rule_name: true/false` lines needed to restore the exact configured tier, dropping the multi-hundred-line prose and box-drawing headers that served no purpose while inert. A live (uncommented) block is unaffected and keeps its full inline documentation. No action required; re-run `dart run saropa_lints:init` or trigger a config write to see the smaller file.
- "Enabling Saropa Lints" could appear to hang forever on larger projects — the enable flow ran `pub get`, config write, and analysis synchronously, freezing the whole editor for as long as those took instead of just showing progress. The flow now runs them without blocking the UI and can be canceled from the progress notification. Canceling during the final analysis step also no longer silently reports "Enable" as successful — it now stops and logs the cancellation instead of turning the plugin on as if the flow had completed. No action required.
- "Re-enable Plugin" could report "nothing to restore" on a project whose `analysis_options.yaml` mixed CRLF and plain-LF line endings, even though the disabled `plugins:` block was plainly present — line detection now tolerates mixed endings instead of assuming one for the whole file. No action required.

---

## [15.0.0]

Version 15.0.0 adds new quick fixes for error logging and variable placement while introducing a persistent background daemon for significantly faster IDE save-scans. This release resolves false positives across exception handling, lifecycle timers, static method detection, and platform target checks. Project tier management is now unified directly through project configuration, reducing default editor memory overhead. [log](https://github.com/saropa/saropa_lints/blob/v15.0.0/CHANGELOG.md)

### Added

- `require_error_logging` now offers a quick fix: applying it inserts a `debugPrint` call logging the caught error (interpolating the captured exception variable when one exists, or naming the statically-known exception type when it does not) instead of only reporting the missing log call.
- `move_variable_closer_to_its_usage` now offers a quick fix: applying it moves the flagged declaration down to just before its first use. The fix only activates when doing so is provably safe (a single-variable declaration whose initializer shares no identifier with any statement it would move past) and otherwise leaves the diagnostic for manual review, so no action is required beyond reviewing the proposed edit before applying it.

### Fixed

- `avoid_catching_generic_exception` no longer flags `on Object`/`on Exception`/`dynamic` catch clauses whose body forwards the caught error to a logging or crash-reporting call (or rethrows it) before falling back — this is a deliberate pattern for also catching `Error` subtypes and reporting them, not a swallowed exception. Untyped `catch (e)` is unaffected. ([plans/history/2026.08/2026.08.15/avoid_catching_generic_exception_false_positive_logged_broad_catch.md](plans/history/2026.08/2026.08.15/avoid_catching_generic_exception_false_positive_logged_broad_catch.md))
- `require_error_boundary` no longer flags a `MaterialApp`/`CupertinoApp` built inside `main()`'s own `catch` clause when that clause already logged the caught error and its `try` body attempted `runApp(...)` — that's the app's crash-recovery fallback screen, not its normal entry point, and demanding it also carry an error-boundary `builder:` is recursive. The same shape outside `main()`, without logging, or without an `runApp` attempt in the `try` body still requires a `builder:` as before. ([plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md](plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md))
- `require_error_logging` no longer flags a `catch`/`on Type` clause with no captured exception variable if its body still calls a recognized logging function — a static message like `on TimeoutException { debug('timed out'); }` is a complete log entry even without touching the exception object. A clause with no captured variable and no logging call is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_error_logging_false_positive_unparamed_catch_with_logged_body.md](plans/history/2026.08/2026.08.15/require_error_logging_false_positive_unparamed_catch_with_logged_body.md))
- `require_app_lifecycle_handling`, `avoid_work_in_paused_state`, and `require_lifecycle_observer` no longer flag a `Timer`/`Stream.periodic`/`.listen()` subscription that is created and canceled/closed within the same `State` class's own `initState`/`dispose()` pair — that's Flutter's standard cleanup contract for a foreground-only ticker that doesn't need to pause on backgrounding, since it stops existing when the widget is disposed. A class whose `dispose()` does not cancel the field it created, or that assigns the Timer/subscription somewhere dispose() can't prove cleanup for, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_app_lifecycle_handling_false_positive_dispose_cancels_timer.md](plans/history/2026.08/2026.08.15/require_app_lifecycle_handling_false_positive_dispose_cancels_timer.md))
- `require_ios_deployment_target_consistency` no longer flags `import 'dart:async'` (or any other import/export URI) as Swift `async`/`await` usage — the rule now skips string literals inside import/export directives before checking them against its tracked iOS 15+ API names. A genuine API name appearing elsewhere in the file is still flagged, as before. The same import/export-URI substring-match false positive was also fixed in `require_ios_live_activities_setup` (triggered by `import 'package:live_activities/...'`) and `require_ios_certificate_pinning` (triggered by package import paths containing segments like `/auth`). ([plans/history/2026.08/2026.08.15/require_ios_deployment_target_consistency_false_positive_import_uri_misattribution.md](plans/history/2026.08/2026.08.15/require_ios_deployment_target_consistency_false_positive_import_uri_misattribution.md))
- `prefer_static_method` no longer flags methods that read instance fields or call instance methods via bare (unprefixed) identifiers — the idiomatic Dart style used throughout most codebases. Previously the rule only recognized an explicit `this.` prefix, so any method touching instance state through a bare identifier (including inside a nested closure) was misdiagnosed as "could be static." A method that truly uses no instance state anywhere is still flagged, as before. ([plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md](plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md))
- `move_variable_closer_to_its_usage` no longer flags a deliberate "load N values, then consume all N in the same order" batch shape (e.g. five sequential `await`-loads followed by five field assignments) — a sibling declaration in the same contiguous run that is itself genuinely used elsewhere, or the first-use site of another such sibling, no longer counts toward the "unrelated intervening statements" distance. A genuinely far-apart single declaration, declarations used out of matching order, or unused padding declarations sitting next to a real one, are all still flagged, as before. ([plans/history/2026.08/2026.08.15/move_variable_closer_to_its_usage_false_positive_batch_declaration_grouping.md](plans/history/2026.08/2026.08.15/move_variable_closer_to_its_usage_false_positive_batch_declaration_grouping.md))
- `require_firebase_app_check_production` and `require_firebase_app_check` no longer flag `Firebase.initializeApp()` when `FirebaseAppCheck`/`AppCheck` activation is deferred to a separate, actually-called function elsewhere in the same file — a common pattern for keeping a slow/flaky Play Integrity check off the startup path. A file where App Check is only mentioned in a comment, or where the activating function exists but is never called from anywhere, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_firebase_app_check_production_false_positive_activation_in_separate_function.md](plans/history/2026.08/2026.08.15/require_firebase_app_check_production_false_positive_activation_in_separate_function.md))
- `require_log_level_for_production` no longer flags a bare verbose-log call (e.g. `debug(...)`) when the called function's own log-level parameter (`level`, `logLevel`, `severity`, or `verbosity`) already defaults to a safe value — demanding an explicit `level:` argument in that case would be a no-op. A callee whose default is itself verbose, unrecognized (numeric or constructor-call), or unresolvable, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_log_level_for_production_false_positive_default_level_param.md](plans/history/2026.08/2026.08.15/require_log_level_for_production_false_positive_default_level_param.md))

### Changed (Extension)

- Saving a Dart file now scans it in an external process and shows findings as squiggles and Problems panel entries — no separate setting to find or enable, this is what `saropaLints.enabled` now does. Turning that toggle off stops save scans and shuts the scanner down immediately, rather than leaving stale findings in the Problems panel. `saropaLints.scanOnSave.resolveTypes` (default on) controls whether scans fully resolve types so type-based rules fire; turn it off only if save latency matters more than catching those rules.
- Type-resolved save scans run through a persistent `scan_daemon` process that builds the analyzer's project context once and keeps it warm, so a save is checked in a few seconds instead of re-paying a roughly one-minute analyzer warmup on every save. The status bar shows a warming message while the first scan after opening is still resolving; the daemon restarts automatically (with backoff) if it stops. Measured memory is comparable to the in-process analyzer plugin — the daemon's advantage is living outside the editor's own process, not a smaller footprint.
- New projects (`dart run saropa_lints:init` or the extension's Enable) no longer get a live in-process analyzer plugin — the `plugins:` block is written commented out by default, since it can hold several GB of resolved analysis state on large projects for no benefit over the scan-on-save daemon above. A project that already had the plugin running, or had it explicitly turned off, keeps that state through tier changes and re-enabling; uncomment the block in `analysis_options.yaml` to opt back in to live in-editor squiggles, or run the new "Saropa Lints: Re-enable In-Process Plugin" command to do it in one step (it also restarts the Dart analysis server so the plugin reloads immediately).
- New command "Saropa Lints: Scan Whole Project for Issues" runs a cancelable whole-project scan so files you haven't saved this session still show up in the Problems panel — save-triggered scanning alone only checks a file once you save it. It streams results in chunks as it goes and can be canceled mid-scan from the progress notification; run it from the Command Palette when you want full coverage, not automatically on open (a full pass on a large project can take tens of minutes).
- A save-triggered scan of a single file no longer prints a misleading progress bar estimating its position against the whole project (e.g. "Files: 1/4477, ETA: 2h"). That estimate now only appears during the long-lived in-editor plugin session it was designed for; one-shot scans (save-triggered daemon, `scan` CLI) show a plain file count instead.
- `analysis_options.yaml` is now the single source of truth for a project's lint tier. Save-triggered scans, the whole-project baseline scan, and the tier picker's "current tier" display now read the tier straight from `analysis_options.yaml` instead of trusting the (possibly stale) `saropaLints.tier` setting, so a hand-edited or regenerated config file can no longer silently disagree with what the extension shows or scans with. `SAROPA_TIER` remains available as a dev-only override but now logs a warning when it disagrees with the project's own config; `saropa_tier:` in `analysis_options_custom.yaml` is deprecated in favor of `analysis_options.yaml`.

<details>
<summary>Maintenance</summary>

- Investigated a `no_magic_string` false-positive report (string literal inside a `//`-commented-out `debugPrint` call) and confirmed by code inspection it cannot occur — the rule and all its gating helpers are AST-callback-only, with no raw-text scanning. Added a resolved-analyzer regression test pinning this behavior. ([bugs/no_magic_string_false_positive_commented_out_code.md](bugs/no_magic_string_false_positive_commented_out_code.md))
- Manually corrected seven German and Swahili extension strings that had shipped corrupted machine-translation output — a mangled literal `--resolve` CLI flag, two entries collapsed into a repetition loop (one leaking a fragment resembling a stray prompt artifact), and grammatically broken fallback text — and added each as a curated `dictionaries.py` override so a future translation run can never regenerate the same corruption from cache.

</details>

---

## [14.5.9]

This release adds a rule catching a common button-labeling mistake: cramming extra detail into a button's main text using parentheses instead of the dedicated subtitle line. It also closes the last gap in the "Lint integration off" toggle: the analyzer plugin itself now refuses to enable any rules while the integration is disabled, so no fallback configuration can silently re-enable analysis and its multi-gigabyte memory footprint. [log](https://github.com/saropa/saropa_lints/blob/v14.5.9/CHANGELOG.md)

### Added

- New rule `avoid_parenthesized_button_caption` (Comprehensive tier): flags `CommonButton` / `CommonButtonWait` calls where the `text:` parameter contains parenthesized text that belongs in `subtitleText:` instead. No action required.

### Fixed

- The analyzer plugin now enables zero rules whenever "Lint integration" is toggled off, even if it gets loaded anyway — previously fallback configuration could re-enable over a thousand rules and hold several GB of analysis-server memory on a project the user had disabled. No action required.

---

## [14.5.8]

Fixed the extension running lint analysis in the background while "Lint integration" was turned off. Disabling the integration now stops every automatic analysis trigger and background suggestion, not just the editor diagnostics. [log](https://github.com/saropa/saropa_lints/blob/v14.5.8/CHANGELOG.md)

### Fixed (Extension)

- Turning off "Lint integration" now also stops analysis triggered by saving files, changing dependencies, changing tier, changing config, and enabling a rule pack, along with the crash-coverage rule suggestion. Previously only in-editor diagnostics were suppressed. No action required.
- Turning off "Lint integration" now restarts the Dart analysis server immediately, so the plugin's background process actually exits instead of continuing to run (and hold onto several GB of memory) until the next manual reload. No action required.

### Changed (Extension)

- The "Run Analysis" toolbar button is hidden while "Lint integration" is off, instead of appearing clickable and doing nothing useful. No action required.

---

## [14.5.7]

Dependency maintenance release — no rule or extension changes. [log](https://github.com/saropa/saropa_lints/blob/v14.5.7/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- Bumped `js-yaml` (extension dev dependency, via `mocha`) from 4.3.0 to 4.3.1, resolving GHSA-5p4m-2wfm-xmqj.

</details>

---

## [14.5.6]

This release introduces a new rule to ensure lint suppression comments work correctly in your IDE. The `require_ignore_comment_plugin_prefix` rule flags ignore comments referencing saropa_lints rules that lack the required package prefix, preventing suppressions from failing silently. An automated quick fix is included to instantly apply the missing prefix. [log](https://github.com/saropa/saropa_lints/blob/v14.5.6/CHANGELOG.md)

### Added

- **New rule `require_ignore_comment_plugin_prefix`** (Essential tier, WARNING) — flags `// ignore: rule_name` and `// ignore_for_file: rule_name` comments that reference a saropa_lints rule without the required `saropa_lints/` prefix, which causes the suppression to silently fail in the IDE. A quick fix inserts the prefix. No action required.
- **`dart run saropa_lints scan --fix-ignores`** — bulk-converts bare `// ignore: rule_name` to `// ignore: saropa_lints/rule_name` for all known saropa_lints rules across `lib/`, `test/`, and `bin/`.

### Fixed

- **`require_ignore_comment_plugin_prefix`'s quick fix could insert the prefix into the wrong `// ignore:` comment** when another ignore comment sat nearby in the file. It now targets the exact flagged comment. No action required.
- **`--fix-ignores` skipped hyphenated rule names** (e.g. `avoid-null-assertion`), leaving them unprefixed. It now converts them correctly. No action required.

---

## [14.5.5]

The Analysis Optimizer now makes changes safely: it surgically updates only the patterns you're modifying while preserving your file structure, comments, and ordering, and backs up your configuration before every write for easy manual recovery. The dashboard excludes redundant recommendations when patterns are already covered and automatically rescans to keep the status current. [log](https://github.com/saropa/saropa_lints/blob/v14.5.5/CHANGELOG.md)

### Fixed (Extension)

- **Analysis Optimizer could silently destroy hand-curated `analysis_options.yaml` structure** — every Apply/Remove/Fix Syntax action rebuilt the entire `exclude:` block from scratch, discarding section-header comments and blank-line grouping (which aren't attached to any single pattern) and re-sorting every entry alphabetically. Writes are now surgical: only the lines for patterns actually being added or removed are touched, and every other line — comments, spacing, order — is left exactly as it was. No action required.
- **Folder exclusion recommendations kept showing as "Recommended" even when already covered by a broader applied pattern** (e.g. individual `dependency_overrides/<package>/**` entries never matched as "Applied" despite a `dependency_overrides/**` already excluding them). These redundant recommendations no longer appear. No action required.
- The dashboard now automatically scans on open and rescans after every Apply/Remove/Fix Syntax, instead of requiring a manual "Scan Workspace" click to see current status. No action required.

### Added (Extension)

- Every Analysis Optimizer write now saves a one-step-back copy of `analysis_options.yaml` to `analysis_options.yaml.bak` first, so a change can always be manually reverted. No action required.

---

## [14.5.4]

This release fixes the Analysis Optimizer's exclusion detection, which previously missed patterns already present in analysis_options.yaml and duplicated them on apply. The dashboard's two separate exclusion lists are now one sortable table with clearer status and impact indicators, plus a quick line preview before applying. [log](https://github.com/saropa/saropa_lints/blob/v14.5.4/CHANGELOG.md)

### Fixed (Extension)

- **Analysis Optimizer could write invalid YAML that broke Dart analysis entirely** — an unquoted exclude pattern starting with `**` (routine for Dart globs) is YAML alias syntax, not a literal string, and caused a real `Undefined alias` parse error the moment the analyzer read the file. Every written pattern is now quoted, and previously-malformed unquoted entries are automatically re-quoted the next time any change is applied through the dashboard. No action required.
- **Analysis Optimizer failed to detect existing exclusions** — patterns with an inline `# comment` or a stray trailing quote (`- **/*.g.dart" # ...`) were never recognized as already excluded, so the dashboard kept recommending them and applying created a duplicate line. The reader now strips comments and malformed quoting before comparing, and the writer preserves each pattern's original comment on write. No action required.
- **Analysis Optimizer's "Current exclusions" and "Recommended exclusions" are now one deduplicated "Exclusions" table**, with an Applied/Recommended status column, sortable columns, and the chosen sort order preserved across Apply/Remove actions. No action required.
- An already-applied Analysis Optimizer exclusion that matches zero scanned Dart files (e.g. a non-Dart tool reference) now shows a dash and an explanatory reason instead of a misleading "0". No action required.

### Added (Extension)

- Each Analysis Optimizer recommendation now has a "Preview" toggle showing the approximate line that would be added to `analysis_options.yaml`, without leaving the table. No action required.
- Analysis Optimizer now proactively warns when `analysis_options.yaml` already has invalid exclude syntax and offers a one-click "Fix Syntax" that re-quotes every entry, so a broken file can be repaired without needing to apply or remove a specific pattern first. No action required.

---

## [14.5.3]

This release fixes a test-suite timeout in the health-history archival path and completes Filipino and Dutch translation coverage across the extension UI. No action required. [log](https://github.com/saropa/saropa_lints/blob/v14.5.3/CHANGELOG.md)

### Fixed

- `loadHealthHistory` test timeout — complexity parsing every Dart file across archived tags exceeded the 2-minute test budget. The function now accepts an optional `withComplexity` parameter (defaults `true`; test passes `false`).

<details>
<summary>Maintenance</summary>

- `loadHealthHistory` now caches each tag's computed `HistoryPoint` on disk (`.dart_tool/saropa_lints/health_history_cache.json`), keyed by the tag's resolved commit SHA. Repeat calls against unchanged tags skip re-archiving and re-scanning entirely.
- Fill `fil`/`nl` extension i18n coverage gaps for `Default`, `Pattern`, `Medium`, and `Open analysis_options.yaml`. `Pattern` is kept as the English loanword already used in the sibling `{count} file pattern(s)` string; `Open analysis_options.yaml` uses verb-final Dutch order to match the existing `pubspec.yaml openen` sibling.

</details>

---

## [14.5.2]

This release introduces the Analysis Optimizer to help developers proactively manage their Dart analyzer's resource footprint. The extension now identifies memory-intensive files and provides an interactive dashboard for safely previewing and applying workspace exclusion patterns. By intelligently filtering out generated code and high-cost directories, users can easily maintain editor performance and swiftly resolve critical memory warnings. [log](https://github.com/saropa/saropa_lints/blob/v14.5.2/CHANGELOG.md)


### Added (Extension)

- **Analysis Optimizer** — new dashboard (sidebar, command palette, or memory warning toast) that scans the workspace, identifies high-cost files and folders, and recommends `analyzer: exclude:` patterns to reduce Dart analyzer memory usage. Applying a pattern opens a diff preview of the resulting `analysis_options.yaml` before writing; multi-pattern applies require confirmation. Generated code patterns (`*.g.dart`, `*.freezed.dart`, etc.) are recommended by default. No action required.
- The critical-memory toast now includes an "Optimize Analysis" button alongside "Clean Up" to surface the optimizer when the analyzer is consuming excessive memory.

---

## [14.5.1]

This release introduces a new balanced memory mode to drastically reduce RAM consumption during incremental analysis, alongside a Full Opportunities Report designed specifically for AI-driven dependency reviews. It also refines localization workflows by eliminating false-positive translation warnings on placeholder-only templates. Developers will experience a significantly lighter background footprint on large projects and gain deeper, exportable insights into their codebase's dependency utilization. [log](https://github.com/saropa/saropa_lints/blob/v14.5.1/CHANGELOG.md)

### Added

- **Full Opportunities Report** — a new export (sidebar, or `Saropa Lints: Export Full Opportunities Report`) that consolidates every dependency and every changelog feature into one HTML, Markdown, and JSON report under `reports/`. Unlike the Upgrade Opportunities panel, it keeps fully-adopted packages and every changelog category, and counts each feature's usage from zero upward with the exact project file and line of every reference. Built to hand to an AI for a dependency-usage review.
- **Balanced memory mode** — new `memory_mode: balanced` setting (default) that skips type-heavy rules on unchanged files during incremental analysis, reducing CPU work on re-analysis passes. When a dependency changes, all transitive importers are automatically re-analyzed via import-graph invalidation. Set `memory_mode: full` in `analysis_options_custom.yaml` or `SAROPA_MEMORY_MODE=full` to restore previous behavior. No action required.

<details>
<summary>Maintenance</summary>

- Moved `.vsix` output from `extension/` to the project root for easier access after packaging.
- Translation skip logic now recognizes placeholder-only templates (`{category} ({count})`) as untranslatable, eliminating 48 false-positive missing-translation reports.
- Pinned the opportunities report's symbol matcher against the implementation it replaced with a differential test, which found that the previous matcher silently never counted `$`-prefixed identifiers.
- Added a headless-DOM test harness (`jsdom`) that executes the opportunities report's inline script, so its filter, mode toggles, expand/collapse, and column sort are verified to work rather than merely to be present.
- Marked 68 rule files as type-resolution-heavy (`usesTypeResolution`) to support balanced memory mode filtering.

</details>

---

## [14.5.0]

This release introduces comprehensive system health monitoring to track memory usage and safely terminate orphaned background processes. It also resolves severe memory retention issues during analysis of large codebases and refines localization workflows by preventing false-positive translation warnings. Developers will experience a significantly more stable and responsive environment with highly accurate diagnostic results during extended coding sessions. [log](https://github.com/saropa/saropa_lints/blob/v14.5.0/CHANGELOG.md)

### Added

- System health monitor in the VS Code extension: polls Dart/Flutter process memory and orphaned daemon count every 60 seconds (Windows). Status bar shows a warning or critical suffix when memory exceeds configurable thresholds or orphaned daemons accumulate. One-click "Kill Orphaned Flutter Daemons" command re-queries live processes before killing, avoiding stale-PID risks. All thresholds configurable via extension settings under "System Health".
- Process Health panel (Command Palette → "Process Health"): live table of all Dart/Flutter processes with PID, parent, RSS, type classification (process/daemon/orphan), and per-process kill buttons for orphaned daemons.

### Fixed

- Register 25+ internal caches for eviction under memory pressure — previously only 10 of ~70 were managed, causing unbounded memory growth on large projects (7.8 GB observed on a 3,900-file codebase). No action required.
- Fix memory estimator to measure actual per-file cache sizes instead of flat approximations that understated real usage by ~25×. No action required.
- Cap the per-file passed-rules cache with LRU eviction (default 500 files) — the single largest memory consumer at O(files × rules), previously unbounded. No action required.
- Cap the per-file diff cache with LRU eviction (default 250 files) — retained full source text of every analyzed file (~19.5 MB on a 3,900-file project), now bounded. No action required.
- Release per-file tracking maps after the analysis summary is reported — previously retained indefinitely, wasting memory for the rest of the session. No action required.
- Fix VS Code integrated terminal color detection on Windows — ANSI escape sequences now render correctly when `TERM_PROGRAM` is set. No action required.

<details>
<summary>Maintenance</summary>

- Add infrastructure bug report for orphaned `flutter daemon` processes accumulating on Windows and exhausting system RAM. Includes hardened cleanup scripts with PID-reuse detection, a scheduled task to break the OOM feedback loop, and a Win32 Job Object permanent fix concept.
- Add `PID`, `RSS`, `Daemon` to MT do-not-translate list and expand skip logic for emoji+placeholder patterns (`⚠ {size}`, `🔴 {size}`), resolving 71 false-positive missing-translation entries across 24 locales. No action required.

</details>

---

## [14.4.3]

Resolves a runtime error in the lint diagnostic reporter that could prevent ignore-comments and deduplication checks from functioning correctly. This release also hardens internal code quality with broad static analysis improvements and introduces new automated CI gates to prevent future regressions. [log](https://github.com/saropa/saropa_lints/blob/v14.4.3/CHANGELOG.md)

### Fixed

- Fix undefined `ruleContext` reference in `SaropaLintRule.registerNodeProcessors` — the diagnostic reporter was receiving an unresolved identifier instead of the method's `RuleContext` parameter, which could cause ignore-comment and dedup checks to fail at runtime. No action required.

<details>
<summary>Maintenance</summary>

- Resolve `unnecessary_string_interpolations`, `unnecessary_string_escapes`, and `prefer_adjacent_string_concatenation` lint issues across lib/ to future-proof against pana baseline upgrades to `package:lints/recommended.yaml`. No action required.
- Resolve 209 dart analyzer lint issues across lib/ and test/: nullable final variables, string interpolation style, dangling library doc comments, unnecessary `this`/`late`, missing `@override`, `prefer_contains`, `use_super_parameters`, `prefer_collection_literals`, and parameter naming alignment with base class signatures.
- Remove dead field `_isProjectRootInitialized` from `SaropaLintRule`.
- Add `scripts/check_dart_fix.py` — CI gate that fails if fixable dart issues exist; hardened with multiple regex patterns and error handling for missing `dart` or timeout.
- Integrate `dart fix --dry-run` / `--apply` into the publish pipeline as an auto-fix step before blocking checks.
- Add `// ignore:` suppressions for 5 unfixable recommended.yaml issues (implementation_imports, library_private_types_in_public_api, prefer_interpolation_to_compose_strings) with verified rationale comments.
- Add `scripts/check_recommended_yaml.py` — CI gate that temporarily enables recommended.yaml analysis and asserts zero unsuppressed issues; preserves original file bytes on restore, handles YAML document markers and missing `dart`.
- Add `dart fix` and recommended.yaml checks to pre-commit hook — regressions are now caught before push; dart availability is checked by each Python script (exit 2 = skip), not the shell.

</details>

---

## [14.4.2]

Static analysis fixes. [log](https://github.com/saropa/saropa_lints/blob/v14.4.2/CHANGELOG.md)

### Fixed

- Fix 41 static analysis issues flagged by pub.dev pana scoring (unnecessary null checks, unused imports, missing curly braces, dead code, redundant ignores, invalid overrides)

---

## [14.4.1]

**Ignore**: Published build error - mixed code/versions. Ignore.

---

## [14.4.0]

Introduces a new lint rule to catch invalid date initializations that would otherwise silently roll over into incorrect dates. Developers are now guided toward strict parsing methods to make date handling safer across Dart and Flutter projects. [log](https://github.com/saropa/saropa_lints/blob/v14.4.0/CHANGELOG.md)

### Added

- `avoid_datetime_constructor` — flags `DateTime()` and `DateTime.utc()` constructors, which silently roll over out-of-range values (e.g. month 13 becomes January of the next year). All-literal in-range calls are allowed. Quick fix available: replace with `DateTime.tryParse()`. No action required.
- `avoid_datetime_constructor_unvalidated` — flags `DateTime()` calls whose result is consumed directly (returned, passed as argument, used in field initializer) without being assigned to a local variable where components can be validated. No action required.

---

## [14.3.13]

Fix false positive in `avoid_bluetooth_scan_without_timeout` — the rule no longer fires on non-Bluetooth `scan()` calls. [log](https://github.com/saropa/saropa_lints/blob/v14.3.13/CHANGELOG.md)

### Fixed

- `avoid_bluetooth_scan_without_timeout` no longer flags `scan().listen()` on non-Bluetooth receivers (e.g. dedup scanners, port scanners). No action required.
- `require_bluetooth_state_check` now recognizes additional Bluetooth package types (`flutter_reactive_ble`, `bluetooth_low_energy`, `quick_blue`, `universal_ble`). No action required.
- `avoid_bluetooth_scan_without_timeout` skips files without scan-related strings via `requiredPatterns` pre-filter, reducing unnecessary AST traversal. No action required.

---

## [14.3.12]

Re-release of v14.3.10 with a build fix — no rule or extension changes. [log](https://github.com/saropa/saropa_lints/blob/v14.3.12/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- Fix test compilation error that blocked the v14.3.10 publish pipeline. No action required.
- Extract shared `parseMethodBody` test helper and add CI guard against `childEntities` usage on class-like declarations. No action required.

</details>

---

## [14.3.11]

**Skipped**: Internal build only.

---

## [14.3.10]

Resolves false positives across matrix scaling operations and resource disposal lints. Uniform scaling factors in matrix transformations are no longer incorrectly flagged as duplicate arguments, and cleanup rules now properly recognize cascade syntax when disposing of controllers, streams, and timers. [log](https://github.com/saropa/saropa_lints/blob/v14.3.10/CHANGELOG.md)

### Fixed

- **Fix: `no_equal_arguments` false positive on Matrix4 uniform scaling** — `scaleByDouble(s, s, 1, 1)`, `scale(s, s, 1)`, and `diagonal3Values(s, s, 1)` no longer flag the repeated factor as a copy-paste error. The `scale` exemption is receiver-type-guarded to Matrix4 only, so `myWidget.scale(x, x)` still fires.
- **Fix: disposal rules false positive on cascade syntax** — all disposal/cleanup rules (`require_text_editing_controller_dispose`, `require_page_controller_dispose`, stream/timer cancel rules, etc.) now recognize `_field..dispose()` and `_field..close()` cascade expressions as valid cleanup. Previously only `_field.dispose()` and `_field?.dispose()` were matched.

<details>
<summary>Maintenance</summary>

- Fix cascade cleanup test helper to use `ClassDeclaration.body.members` instead of `childEntities`, which stopped exposing `MethodDeclaration` in analyzer 12.1.0.

</details>

---

## [14.3.9]

Two new comprehensive rules help monitor native bridge performance by requiring the `@MethodChannelInstrumented` annotation on channel classes and ensuring those calls are wrapped in timing helpers like `noteIfSlow`. [log](https://github.com/saropa/saropa_lints/blob/v14.3.9/CHANGELOG.md)

### Added

- **New rule: `require_method_channel_instrumented`** — flags classes that call `MethodChannel.invokeMethod` / `invokeListMethod` / `invokeMapMethod` without a `@MethodChannelInstrumented` annotation, one diagnostic per class. Quick fix inserts the annotation. Comprehensive tier.
- **New rule: `prefer_method_channel_note_if_slow`** — flags bare invoke-method calls inside `@MethodChannelInstrumented` classes that are not wrapped in `noteIfSlow` or an equivalent timing helper. Comprehensive tier.

<details><summary>Maintenance</summary>

- **Fix: rule packs UI in self-package** — the Config Dashboard's "Enable all" and individual pack toggles produced misleading toasts ("already enabled" / "could not write") when the workspace is the saropa_lints package itself. The extension now detects the self-package via `name: saropa_lints` in pubspec, treats the implicit plugin load as configured, and creates a `plugins: saropa_lints:` block when no anchor exists for `rule_packs` writes.
- **CI: full clone for test job** — the `health_history_test` needs git tags; shallow CI clones lacked them. Changed to `fetch-depth: 0` (full clone) so tags and history are always available.
- **Security: fix 3 Dependabot alerts** — upgraded `shell-quote` 1.8.4 → 1.10.0 (quadratic DoS in `parse()`), replaced abandoned `npm-run-all` with maintained `npm-run-all2@8`, and overrode `brace-expansion` to patched versions (exponential DoS). All dev-only dependencies.
- **Dependabot: grouped weekly schedule** — added `.github/dependabot.yml` to batch all extension npm security updates into a single weekly PR (Mondays) instead of one PR per alert.
- **i18n engine: NLLB → Qwen** — the extension's machine-translation pipeline now uses Qwen 3 via local Ollama as the primary engine, with Google Translate as the per-string fallback. NLLB is deprecated; existing NLLB-provenance translations are treated as low-quality and re-translated on the next `--mode upgrade` run. No user action required.
- **i18n: LLM control-token rejection** — the translation cache validator now rejects cached strings containing leaked LLM control tokens (`/no_think`, `<|endoftext|>`, `[INST]`, etc.). Contaminated entries auto-heal on the next translation run. GPU detection is deferred to first use so importing the engine no longer runs `nvidia-smi`.

</details>

## [14.3.8]

Fixes an issue where the analysis server repeatedly restarted the plugin isolate, causing IDE diagnostic results to clear continuously. Automatically excludes common non-Dart output directories during initialization to prevent file-watcher feedback loops. Adds restart-rate telemetry, log rotation, and a configurable `log_level` setting to control plugin log verbosity. [log](https://github.com/saropa/saropa_lints/blob/v14.3.8/CHANGELOG.md)

### Fixed

- **Plugin isolate restart storm** — the analysis server respawned the plugin isolate hundreds of times per day (13,660 over 91 days on the `contacts` project), clearing all diagnostics from the Problems tab each time. Two causes addressed: (1) `Plugin.start()` now skips config loading when the working directory is not a Dart project (e.g. the VS Code install directory), eliminating the 0-rules phase and noisy log entries; (2) `PluginLogger.setProjectRoot()` now validates that the root contains `pubspec.yaml` before writing log files, preventing log writes into non-project directories that could trigger file-watcher restarts.
- **Init command: non-Dart directories now excluded from analyzer** — `dart run saropa_lints:init` and the headless config writer now ensure common non-Dart directories (`reports/**`, `docs/**`, `bugs/**`, `plans/**`, `doc/**`, `output/**`, `tmp/**`) are in the `analyzer > exclude` list. Without this, plugin log writes to `reports/.saropa_lints/` could trigger the analysis server's file watcher and restart the plugin isolate in a feedback loop.
- **Plugin logger: restart-rate telemetry** — after each isolate spawn, `PluginLogger` counts recent "session started" entries in the log file. When the rate exceeds 10 restarts in 10 minutes, a `WARNING` line is emitted with remediation advice. The log file itself is the durable counter since statics reset per isolate.
- **Init command: flow-style YAML guard** — `ensureNonDartExcludes` now detects flow-style `exclude: [...]` under the `analyzer:` section and leaves it unchanged instead of inserting a duplicate `exclude:` key. Trailing comments after `exclude:` are also handled correctly.
- **Plugin logger: log rotation** — `plugin.log` is now capped at 512 KB; oldest content is discarded at each isolate start, bounding the cost of the restart-rate telemetry read and preventing unbounded disk growth. No action required.

### Added

- **Plugin logger: configurable log level** — new `log_level:` key under `plugins > saropa_lints` in `analysis_options.yaml` controls which messages are written to `plugin.log`. Valid values: `off`, `error`, `warning`, `info` (default), `debug`. Messages below the configured level are still sent to the analysis server's developer log but skip the user-visible file. The init command writes `log_level: info` by default.
- **Plugin logger: convenience API** — `PluginLogger.debug()`, `.warning()`, and `.error()` replace the `level:` named parameter pattern, making log call sites more concise. Unrecognized `log_level` values now emit a warning instead of silently falling back to `info`. Tab-indented configs are now parsed correctly.

---

## [14.3.7]

Updates the Dio linting behavior to favor dependency injection and factory patterns over static singletons. The updated rule flags top-level and static `Dio` declarations while permitting instantiation inside methods, constructors, and callbacks, resolving an architectural contradiction with anti-singleton guidelines. [log](https://github.com/saropa/saropa_lints/blob/v14.3.7/CHANGELOG.md)

### Changed

- **Breaking:** Renamed `require_dio_singleton` to `require_dio_factory` — the rule now flags `Dio()` in static fields and top-level variables (the singleton anti-pattern) instead of recommending them. `Dio()` inside methods, constructors, closures, and DI callbacks is allowed. Resolves the architectural contradiction with `avoid_singleton_pattern` ([#274](https://github.com/saropa/saropa_lints/issues/274)). No action required if already using factory/DI patterns.
- **`require_dio_factory` config alias:** Projects using `require_dio_singleton` in `analysis_options.yaml` continue working via `configAliases` — no config migration required on upgrade.

### Added

- **Hardened `require_dio_factory` detection:** Added coverage for `late static final Dio` fields, static getters, nested closures, and mixin method bodies. No action required.

<details><summary>Maintenance</summary>

- Closed Dependabot PR #271 bug (js-yaml 4.1.1 → 4.3.0): lock file already resolves to 4.3.0 via mocha; archived as fixed.
- Publish audit now detects dangling `bugs/*.md` references in active documents (skips frozen `plans/history/`).

</details>

---

## [14.3.6]

Removes the `avoid_debug_print` rule, which contradicted the existing `prefer_debug_print` and left no valid console output path. Also fixes false positives in `avoid_redundant_null_check` and `avoid_redundant_await` when types are nullable or resolve across package boundaries. A new `--debug-rule` flag on the scan CLI traces type resolution for any named rule, making it easier to diagnose false positives.
[log](https://github.com/saropa/saropa_lints/blob/v14.3.6/CHANGELOG.md)

### Removed

- **`avoid_debug_print` rule deleted.** The rule contradicted `prefer_debug_print` — one said "use debugPrint," the other said "don't" — leaving no valid console output function for projects without a custom logging wrapper. `prefer_debug_print` remains and covers the `print()` → `debugPrint()` upgrade path. No action required unless your config explicitly enabled `avoid_debug_print`; if so, remove the entry.
- **`CommentOutDebugPrintFix` quick fix deleted** (was the only fix for the removed rule). No action required.

### Added

- **`--debug-rule <name>` flag for the scan CLI.** Emits per-node type-resolution trace output (staticType, staticInvokeType, returnType) for the named rule during a scan. Use with `--resolve` for full type information. Designed for diagnosing false positives caused by type-resolution divergence in the analyzer plugin context. No action required.

### Fixed

- `avoid_redundant_null_check` no longer fires on variables, parameters, fields, or getters declared with a nullable type (`Type?`). The rule cross-checks the element's declared type against the resolved `staticType` and guards against `InvalidType` from failed type resolution, preventing false positives in cross-package contexts.
- `avoid_redundant_await` no longer fires on `await` of static methods returning `Future<T>`. The rule now guards against `InvalidType` (unresolvable types) and falls back to checking the invoked method signature's return type via `staticInvokeType` when `staticType` fails to resolve for cross-file static invocations.

---

## [14.3.5]

This update improves the precision of our accessibility lints by isolating Flutter UI components from lower-level graphics classes. Projects utilizing external image processing libraries alongside Flutter will no longer experience irrelevant warnings. [log](https://github.com/saropa/saropa_lints/blob/v14.3.5/CHANGELOG.md)

### Added

- `isFlutterWidgetNamed(Element?, String)` shared utility for verifying a resolved element is a Flutter SDK widget by name and library origin, with `TypeAliasElement` unwrapping.

### Fixed

- `require_image_semantics`, `require_image_description`, `require_accessible_images` no longer fire on non-Flutter classes named `Image` (e.g. `package:image`'s pixel-buffer `Image` or `dart:ui`'s `Image`). All three rules now verify the declaring library is `package:flutter/` before reporting, with `TypeAliasElement` unwrapping for typedef'd widget references.

---

## [14.3.4]

Adds a cross-tool data channel so sibling Saropa Suite tools can pull this project's daily health snapshot, adds a validated `fresh_code` risk flag to the Code Health report, and revives a batch of lint rules that never fired for anyone: seven that were missing their most common bad-code shape, and fourteen whole-file rules (desktop, BLoC, Riverpod, iOS, testing, navigation, i18n, and animation checks) that reported through an end-of-file step the analysis engine ignored. Also fixes a broken age signal that scored every function as maximally stale. No action required — the API is opt-in and the new flag and fixes take effect automatically. [log](https://github.com/saropa/saropa_lints/blob/v14.3.4/CHANGELOG.md)

### Added

- **`fresh_code` flag in the Code Health (vibrancy) report.** Functions with cyclomatic complexity above 10 whose body was written or rewritten within the last 90 days are now flagged, because validation against real bug-fix history showed recently rewritten complex code causes incidents far more often than old code. No action required — the flag appears in the CLI report and as a filterable pill in the extension's Code Health view.
- **(Extension) `getDailySummary(date)` on the extension's public API.** Sibling Saropa Suite tools can now read this project's current health score, violation counts, and error-level trouble items for a given day via `getExtension('saropa.saropa-lints').exports.getDailySummary('YYYY-MM-DD')`, which resolves to a documented `DailySummary` (or `undefined` before any analysis has run). No action required — the summary is built lazily on call, reads only local analysis output, and transmits nothing.

### Fixed

- **`prefer_notifier_over_state` false positives eliminated.** The rule matched `StateProvider` by scanning serialized source text, which could match unrelated identifiers containing that substring; it now checks the constructor/invocation name directly via the AST. The `MethodInvocation` branch is restricted to the known Riverpod factory methods (`autoDispose`, `family`) to prevent false positives from unrelated static methods. A fixture pins all three detection branches and a false-positive decoy. No action required.
- **Code Health age scores were stuck at zero.** A broken decay formula scored every function with git history as maximally stale, so the age component contributed nothing to health rankings; ages now decay correctly from 100 (touched today) toward 0 over years. Overall scores rise slightly on recently maintained code — no action required.
- **`prefer_list_contains` now flags `indexOf(x) != -1`.** The rule only recognized a bare `0` or `-1` on the right of the comparison, but `-1` is written as a negation, not a plain number, so the most common presence check — `list.indexOf(x) != -1` — was never flagged. It now is. No action required.
- **`avoid_map_keys_contains` now flags `map.keys.contains(k)` on a plain variable.** The rule previously matched only chained receivers (like `this.map.keys.contains(k)`) and missed the ordinary `map.keys.contains(k)` on a simple map variable — the usual shape. Its quick fix (`map.containsKey(k)`) now applies to those cases too. No action required.
- **`avoid_unnecessary_collections` now flags `List.of([...])`/`Set.of(...)`/`Map.of(...)`.** The rule missed these wrapped-literal constructors during full analysis because they are constructor calls, which analysis represents differently from the method-call shape the rule looked for. Both shapes are now flagged. No action required.
- **`prefer_asmap_over_indexed_iteration` now flags `for (i = 0; i < list.length; i++)`.** The rule required the loop bound to be a chained property read and missed the ordinary `list.length` on a plain list variable — the usual shape — so it effectively never fired. It now does. No action required.
- **`require_key_for_collection` now flags `ListView.builder`/`GridView.builder` during full analysis.** These are constructor calls, which full analysis represents differently from the method-call shape the rule looked for, so keyless items in the most common list builders went unflagged; only a few less-common widgets were caught. All shapes are now flagged. No action required.
- **`prefer_commenting_future_delayed` now works during full analysis and stops flagging already-commented delays.** `Future.delayed` is a constructor call (represented differently from a method call during full analysis), so the rule never fired for anyone; and it looked for the explanatory comment on the wrong token, so an `await Future.delayed(...)` with a comment above it was treated as uncommented. Both are fixed: the rule fires on uncommented delays and stays quiet when a comment precedes the statement. No action required.
- **`avoid_sequential_awaits` now fires.** The rule registered for a callback the analysis engine silently ignores, so three or more independent sequential awaits (which could run together with `Future.wait`) were never flagged for anyone. It now registers correctly and reports. No action required.
- **Four more rules that never fired now work: `prefer_single_exit_point`, `prefer_guard_clauses`, `require_getit_registration_order`, and `require_hive_adapter_registration_order`.** All registered through the same ignored callback as `avoid_sequential_awaits`, so none produced a diagnostic for anyone. All four now register correctly and report. No action required.
- **`pass_correct_accepted_type` now fires, and `prefer_correct_identifier_length` now checks parameter names.** Both registered for a parameter callback the engine ignores: `pass_correct_accepted_type` never fired at all, and `prefer_correct_identifier_length` only checked variable names, silently skipping parameters. Both now register correctly. No action required.
- **Fourteen more whole-file rules that never fired now work.** Each aggregated information across the whole file and then reported through an end-of-file callback the analysis engine silently ignores, so none produced a diagnostic for anyone. The revived rules are `require_menu_bar_for_desktop`, `require_window_close_confirmation`, `require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state`, `require_apple_sign_in`, `require_error_case_tests`, `avoid_test_coupling`, `require_test_cleanup`, `prefer_test_variant`, `require_route_transition_consistency`, `prefer_shell_route_for_persistent_ui`, `require_intl_locale_initialization`, and `prefer_implicit_animations`. All now scan the file in a single pass and report correctly; `require_intl_locale_initialization` also stops missing usages that a duplicate registration had been discarding, and `require_apple_sign_in` now recognizes the standard `GoogleSignIn().signIn()` call shape (a constructor-call receiver) that its detection had been skipping. No action required.

<details>
<summary>Maintenance</summary>

- Fixed the rule-liveness report (`accuracy_report`) so it exercises stylistic rules. No tier — not even pedantic — contains the stylistic rules, so the previous tier-scoped scan never enabled them and falsely reported stylistic rules with fixtures as silent; correcting it flipped 80 previously-false-silent rules to firing (the silent worklist dropped from 744 to 664). The report now defaults to all defined rules (`--tier <name>` narrows it), via a new optional explicit rule-set on the scan runner.
- Repaired the collection and async rule fixtures so the liveness instrument exercises the rules that were correct but sitting on inadequate fixtures. Collection reached full coverage (all 27 rules fire). Async went from 13 silent to 4: eight fixtures made realistic (typed streams/futures, class-method context, matching heuristic identifiers, a real `WebSocketChannel`). The four remaining are two rules whose fixtures resolve to zero diagnostics under the full-corpus scan (cause not yet isolated with per-file tooling) and two `expect_lint` markers naming rules that were never implemented.
- Added an integrity test that fails the build if any rule calls one of the three no-op registration stubs (`addPostRunCallback`, `addFunctionBody`, `addFormalParameter`), which silently discard their callback and were the root cause of the fourteen dead whole-file rules revived this release. The guard forces authors to the real registrations instead.
- Repaired the liveness fixtures for the revived whole-file rules and added fixtures for three that had none (`require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state`). Because these rules judge the whole file, a fixture that placed a BAD and a GOOD example together let the GOOD example mask the BAD; the compliant examples were moved to sibling `*_good.dart` files, path-gated fixtures were relocated, and mock classes (`GoogleSignIn`, `CupertinoPageRoute`, `FadeTransitionRoute`) were added so constructor-based rules resolve. All fourteen are confirmed firing (six in the full corpus scan, eight in isolated scans — the eight hit the pre-existing full-corpus-scan measurement limitation with the crowded test-fixture directory, already noted for the async cluster).
- Fixed the Code Health `unused` flag producing ~50% false positives on multi-package repos. Nested `pubspec.yaml` files fragmented the analysis context, the resolved-usage pass silently degraded, and every `@override` method and `bin/`-only-called function was flagged dead. The fix scopes the analysis context to `lib/`, `test/`, `bin/` (preventing fragmentation), includes `bin/` files in the usage set (so CLI delegates get real caller counts), and adds a syntactic `@override` safety net that protects polymorphic methods even if resolution degrades. No action required.
- Split the Issues tree provider's ~220-line tree-item renderer into a sibling module so the provider class carries only its stateful filter/index logic. Behavior-identical; the tree-item tests pin the render output.
- Closed the oversized view-file breakdown plan and archived it to plan history — all ten tracked files are decomposed, and the two residual stateful controllers are accepted as cohesive final-state modules.
- Ran the flight-risk scoring research gate (predictive-score validation) and recorded a negative result: on a 16-incident corpus mined from this repo's fix history, the candidate composite formula lost to the complexity-alone baseline, so the feature stays unbuilt and its plan stays open with the findings and re-attempt conditions documented.
- Closed the sidebar-and-affordance inventory snapshot and archived it to plan history — every count had drifted from the manifest, and the one durable decision (the palette-only JSON-export tree providers are intentionally never registered as views) now lives as a comment at their construction site.
- Fixed the `loadHealthHistory` test so it asserts real behavior instead of silently passing on empty results. The test had `if (points.isEmpty) return`, which meant a completely broken function still produced a green test. It now requires non-empty results (this repo has tags), asserts `codeLoc > 0`, the `codeLoc <= loc` invariant, and distinct tags when two points are returned.
- Added `HistoryPoint.toMarkdownRow()`, `HistoryPoint.markdownHeader`, and `HistoryPoint.toMarkdownTable()` for rendering health trajectory as markdown tables.
- Fixed the performance-rules fixture verification test: renamed `require_window_close_confirmation_desktop_fixture.dart` to match the rule-name convention, and added 8 fixture files that existed on disk but were missing from the verification list.
- Replaced the hardcoded fixture list in the performance test with a directory scan, so new fixture files are verified automatically without manual list maintenance. Also renamed the stale `require_window_close_confirmation_desktop_good.dart` to drop the `_desktop` suffix.
- Converted all 126 remaining test files from hardcoded fixture lists to the same `Directory.listSync()` auto-discovery pattern. Every fixture verification group now scans its directory on disk, so adding a fixture file is automatically tested — no manual list to maintain or drift out of sync. The `android_rules_test` retains one explicit test for a cross-directory fixture (`require_android_manifest_entries` in `example/lib/platform/`). Two files (`roadmap_15_rules_test`, `migration_rules_test`) were excluded because their fixture groups contain content-validation tests beyond simple existence checks.
- Extracted fixture auto-discovery into a shared `discoverFixtures()` helper (`test/helpers/fixture_discovery.dart`) and migrated all 127 fixture-verification test files to use it. The helper returns an empty list when the directory is missing, so the guard test fails with a clear assertion instead of a `FileSystemException` aborting the group. Removes ~7 lines of duplicated `listSync` chain per file.
- Added a fixture-vs-tiers integrity test (`test/integrity/fixture_integrity_test.dart`) that cross-references every `*_fixture.dart` on disk against `getAllDefinedRules()`. Catches stale or misspelled fixture files whose names don't match any registered rule. Group/category fixtures (covering multiple rules) are logged but not failed. Includes a regression floor at >2300 exact-match fixtures.

</details>

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.

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

   Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/); versioning: [SemVer](https://semver.org/spec/v2.0.0.html). Omit dates from headers, because [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays them.

   **Overview** — Every release (and [Unreleased]) opens with a 2–4 sentence user-facing summary that doesn't restate the bullets. Banned: file paths, line numbers, regex snippets, internal flag names, project-specific counts or percentages, and AST or visitor terminology. End with `[log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)` (no preceding line break), substituting the version.

   **Bullet density (HARD RULE)** — Applies to every bullet under `### Added`, `### Changed`, `### Fixed`, `### Removed`, and their `(Extension)` variants. Write one sentence per bullet, in the order *what changed → why the user cares → what the user must do* ("No action required" when true). A second sentence is allowed only when a required user action doesn't fit in the first. Never write three; split the bullet, or move the detail to the commit message, PR, bug report, or code comment and link out. Concision edits may touch historical sections.

   **Banned inside bullets** (move to commit message, PR, or code comment):
   - **PR archaeology** — prior attempts, rename history, "after X didn't hold". Describe the landed state only.
   - **File-by-file inventories** — that is the git diff.
   - **Test counts** — that is CI output.
   - **Code-internal names** — AST classes, regex flags, function signatures, field or type names, private identifiers.
   - **Bug-report, fixture, or test paths** — commit message footer only.
   - **Decision-making narrative** — one clause of reasoning is fine, not a paragraph.

   **Internal bullets** — Same bans apply (no test counts, no file inventories). The what→why→must-do template is optional for infra-only entries.

   **Internal section** — Changes with no end-user impact (publish/CI tooling, internal refactors, test harness, plan housekeeping, developer scripts) go under `### Internal` at the bottom of the version section, never in `### Added` / `### Changed` / `### Fixed`. NEVER use `<details><summary>Maintenance</summary>`. Test: if a pub.dev or Marketplace user would notice, it's top-level; otherwise Internal.

   **Unreleased convention** — While work is in progress, the top section MUST be headed `## [X.Y.Z] — Unreleased`. Put all new entries in this ONE section: never create a second unreleased section or bump the version. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) via `_strip_unreleased_suffix()`. `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle.

   **Tagged changelog** — Published versions use git tag `vx.y.z`, and each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [17.0.1-beta.6]

The "large files not excluded from the file watcher" warning no longer appears in workspaces that are not Dart projects, and no longer lists tool-managed folders. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.6/CHANGELOG.md)

### Changed

- **Lints switch (extension):** a single click on the sidebar switch row, or on the status bar tooltip link and menu, no longer turns lints on or off. They open Process Health, which holds the toggles. The `Saropa Lints: Toggle` command and the Lints Config dashboard button are unchanged.
- **Lints switch (extension):** the status bar and sidebar showed "Partly off" when every engine was off but the Scan on Save toggle in Process Health had only suspended the scan daemon. A suspended daemon now counts as the setting being off, so the switch shows "Off".
- **Large-file watcher warning (extension):** the message now names the open folder, says the listed paths are relative to it, shows at most 3 files with sizes or file counts plus "and N more", and explains that VS Code watches every file in the folder for changes and large files can slow it down or crash it. The "Exclude from Watcher" button is unchanged.
- **Status bar hover (extension):** the tooltip is now laid out in sections (Status, Project, Problems, Memory, Actions) with tables, colored pills with hover text, and one link per action. Findings read "18,368 findings (all errors)" or "N errors · M warnings", long numbers have thousands separators, each problem names itself with its own link, and the memory detail is unchanged but tabulated. The toggle label follows the real state, and the two conflicting "not set up" messages are now one.
- **Status bar click (extension):** clicking the status bar item no longer flips Lints on or off. It opens a menu (new command `Saropa Lints: Status Menu`) with the status, problems and actions; the toggle is one row.

### Fixed

- **Large-file watcher warning (extension):** the scan now runs only in Dart/Flutter workspaces, and skips `.claude/worktrees` and `.venv` folders, so web or Python workspaces no longer get warnings about virtual-environment files and media assets. The 5 MB default size bar (`saropaLints.watcherExclude.maxFileKb`) is unchanged.

---

## [17.0.1-beta.5]

The VS Code status bar now shows one Saropa item instead of four, the Lints On/Off state now matches what a click does, and 6 rules and the `init` command no longer report problems that are not there. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.5/CHANGELOG.md)

### Changed

- **Status bar (extension):** the four Saropa status bar items (switch, score, "Saropa: ready/disabled", route and memory/workspace issues) are now one item, e.g. `Saropa Lints: On · 90% · V9/10`, `Saropa Lints: Off`, or `Saropa Lints: Partly off`. It turns to the warning color when lints are Off or Partly off, or when memory or workspace issues need attention. The route (`saropa_lints: pubspec 17.0.1`), memory, health and workspace-issue details moved into its tooltip. Click still flips the Lints On/Off switch; the tooltip links open the report. The scan-on-save item now appears only while a scan is running or has just finished.

### Fixed

- **Lints On/Off switch (extension):** the status bar, sidebar and dashboards now read the saved ownership record, so the displayed state matches what a click does (e.g. after `flutter clean` deletes `.dart_tool`).
- **`init`:** a re-run on a project with the default commented-out plugin block no longer exits 1, no longer claims the extension turned lints off, and no longer warns "0 rules found"; it exits 1 only when the extension recorded turning lints off.
- **`avoid_return_await_db`:** no longer treats `db*` reads such as `dbContactLoadDBListByStatus` as writes (the name `LoadDB` contains `add`). Method names are now matched by camel-case word; `compute`, `calculate` and `check` are now read verbs (`dbContactComputeTotals` no longer lints). `dbContactSave` and `dbContactAddToGroup` still lint.
- **`prefer_freezed_for_data_classes`:** no longer flags data classes in projects that do not depend on `freezed` or `freezed_annotation`, where the suggestion could not be acted on. No action required.
- **`require_catch_logging`:** no longer flags a catch whose only statement returns a constructed typed result (e.g. `return const DecryptResult(DecryptStatus.authFailed)`). `return null;`, `return false;` and empty catches still lint.
- **`avoid_memory_intensive_operations`, `avoid_string_concatenation_loop`:** no longer flag `line += buffer.toString()` where `buffer` is a `StringBuffer` (flushing a buffer into a string).
- **`avoid_platform_channel_on_web`:** no longer flags channel calls after `if (!isSupported) return;` when `isSupported` reads a private flag that is only ever set true after a `kIsWeb`-guarded early exit. A flag assigned with no web guard still lints. The guard flag must be false on web (for example `!kIsWeb && ...`); a flag such as `kIsWeb || ...` and writes through `this._flag = ...` are now handled correctly. An early exit `if (!_canUse) return;` on a getter such as `kIsWeb || ...` no longer counts as a web guard; only a getter that is false on web (`!kIsWeb && ...`) does.

---

## [17.0.1-beta.4]

This update removes false positives from 19 rules, mostly the mounted-check and context rules that flagged code that was already safe. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.4/CHANGELOG.md)

### Fixed

- **`check_mounted_after_async`:** no longer treats an `await` inside an always-returning `if` branch as an await before a later `setState`.
- **`require_mounted_check_after_await`, `require_mounted_check`:** an `await` confined to an always-exiting `if` branch no longer triggers `setState` reports after the `if`.
- **`use_setstate_synchronously`:** await and guard state are now restored after an `if` whose awaits all sit in exiting branches.
- **`avoid_platform_channel_on_web`:** no longer flags calls after `if (field == null) return` (field null on web) or after a negated `Platform.isX` early exit, and is skipped in Flutter projects with no `web/` target.
- **`avoid_inert_animation_value_in_build`:** no longer flags an `animation.value` read in a branch whose sibling branch uses an `AnimatedBuilder` or `ListenableBuilder` on the same animation.
- **`avoid_datetime_constructor`:** no longer flags a `DateTime(...)` assigned to a local and then round-trip validated by an `if` on its `month` or `day` that exits.
- **`avoid_retaining_disposed_widgets`:** no longer flags immutable `const` descriptor classes, render-time delegates (`FlowDelegate`, `CustomPainter` and similar), or widgets that reach `Widget` or `State` through a non-listed Flutter base class.
- **`avoid_storing_context`:** no longer flags a `BuildContext` field on render-time delegates, or a `final` field whose every use follows a `.mounted` check.
- **`avoid_parameter_mutation`:** no longer flags `void`/`bool` functions documented as in-place ("in place"/"mutates") or named with a mutator verb (`apply`, `restore`, `rollback`, `inherit`, `carry`, `merge`, `stamp`, `mark`).
- **`move_variable_closer_to_its_usage`:** no longer flags a state snapshot (call or member-read initializer) taken before intervening `await`s.
- **`prefer_asmap_over_indexed_iteration`:** no longer flags pairwise loops (inner start not 0, or index feeding a nested loop bound).
- **`prefer_static_method`:** no longer flags instance methods of singleton classes (private/factory constructors plus a static self-typed instance).
- **`prefer_try_parse_for_dynamic_data`:** `Uri.parse` of an interpolation made only of `const` references and `Uri.encode*` calls is no longer flagged.
- **`require_apple_signin_nonce`:** no longer reports `getAppleIDCredential(scopes: [])`, which only fetches an authorization code for token revocation.
- **`require_data_encryption`:** no longer reports calls that only clear credential fields with `null` or `Value(null)`.
- **`require_drift_equals_value`:** now resolves the argument type and reports only enums, so `static const String` or int arguments pass.
- **`require_qr_permission_check`:** no longer reports `MobileScanner`, which handles camera permission itself.
- **`require_speech_stop_on_dispose`:** follows same-class and externally declared private helpers called from `dispose()`.

---

## [17.0.1-beta.3]

This update makes the command-line setup report problems honestly instead of finishing as if everything worked. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.3/CHANGELOG.md)

### Added

- **VS Code extension:** one On / Off / Partly off switch for Saropa Lints, in the status bar and at the top of the sidebar. One click turns it on or off. "On" means the setting is on and the analyzer plugin block is live or was never turned off by the extension (a new project's default daemon-only block counts as On, and turning On from there does not load the heavy plugin). "Partly off" shows only when the extension itself turned the block off or the setting and block otherwise disagree; it says which part is off and the same click fixes it.
- **VS Code extension:** a version-sync row in the sidebar that, in one click, syncs the plugin version in `analysis_options.yaml` to the version pinned in `pubspec.lock` when they differ.

### Fixed

- **`dart run saropa_lints:init`:** exits with a failure code when the resulting configuration has no active `plugins:` block or lists no rules, and says so plainly when the VS Code extension turned Lint integration OFF.
- **`dart run saropa_lints:init`:** the stale-version warning now reads the version of the `saropa_lints` plugin entry only (it previously could report an unrelated `version:` such as `true`) and names the command that updates it.
- **`dart run saropa_lints:init`:** the deprecation note no longer implies the extension will undo an OFF state that init cannot undo.
- **VS Code extension:** the Lints Config dashboard shows "Lints are off" with a Turn on (or Fix) button instead of coverage numbers while lints are off or partly off.
- **VS Code extension:** Re-enable In-Process Plugin now also turns the `saropaLints.enabled` setting back on, so the two can no longer disagree.
- **`avoid_async_call_in_sync_function`, `avoid_unawaited_future`, `avoid_uncaught_future_errors`:** no longer report `Map<K, Future<V>>.remove(key)` statements.
- **`avoid_context_across_async`, `avoid_context_after_await_in_static`:** no longer treat an `if` as an await when the await sits only in branches that always return or throw.
- **`avoid_drift_value_null_vs_absent`:** no longer reports `Value<T?>(null)` on a nullable column.
- **`avoid_ignoring_return_values`:** no longer reports `Never`-returning calls, or extension methods whose name contains a mutate verb word (for example `dbActivityAdd`).
- **`avoid_implicitly_nullable_extension_types`:** no longer reports an extension type that implements a non-nullable interface.
- **`avoid_memory_intensive_operations`, `avoid_string_concatenation_loop`:** no longer report `+=` on a String declared inside the same loop.
- **`avoid_nullable_interpolation`:** no longer reports interpolation inside a lazy debug-log closure.
- **`avoid_nullable_parameters_with_default_values`:** no longer reports a parameter the body compares to `null`.
- **`avoid_only_rethrow`:** no longer reports a rethrow-only clause when a later clause in the same `try` also catches the exception.
- **`avoid_parameter_mutation`:** no longer reports `Draft`, `Builder`, `Accumulator`, `Collector` and `Buffer` parameters in `void` functions.
- **`avoid_string_substring`:** recognizes a length guard in a collection-for loop condition.
- **`avoid_unbounded_cache_growth`, `require_cache_expiration`:** treat `field = null` on a Map field as invalidation (wholesale-replaced snapshot caches).
- **`avoid_unsafe_collection_methods`:** recognizes `isNotEmpty && ....first` and `isEmpty || ....first` short-circuit guards.
- **`move_variable_closer_to_its_usage`:** no longer reports a declaration whose initializer contains `await`.
- **`prefer_drift_batch_operations`:** no longer reports `batch.insert` inside a batch callback or `update(...).write`.
- **`prefer_transaction_for_batch`:** counts writes per execution path (exclusive branches) and ignores `StreamController.add` and other sinks.
- **`require_data_encryption`:** no longer matches `card` inside `vcard`.
- **`require_dispose_pattern`:** no longer reports abstract classes with only static members.
- **`require_file_close_in_finally`:** no longer reports `File.openRead` (the stream closes itself).

---

## [17.0.1-beta.2]

The latest release, `17.0.1-beta.2`, focuses entirely on refining existing rules to eliminate false positives in specific code contexts.  Key fixes include recognizing `!context.mounted` guards in static methods, allowing constant or literal interpolations in Drift SQL strings, and properly handling RegExp group matches for dynamic data parsing. It also improves checks for hooks outside build methods, platform channel declarations, and null-safe JSON accesses by better analyzing the surrounding code logic and type guards.[log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.2/CHANGELOG.md)

### Fixed

- **`avoid_context_after_await_in_static`:** no longer reports after a `!context.mounted || ...` guard.
- **`avoid_drift_raw_sql_interpolation`:** no longer reports SQL built only from constant or literal interpolations, including loop variables over a literal list of strings.
- **`avoid_drift_raw_sql_interpolation`:** no longer reports SQL built from a private method's parameter when every caller passes a literal.
- **`avoid_hardcoded_credentials`:** no longer reports a short plain word assigned to a bare `token` name (for example `_unitToken = 'unit'`).
- **`avoid_hooks_outside_build`:** no longer reports static `ClassName.useX(...)` helper calls, and only applies to files that import a hooks package.
- **`avoid_platform_channel_on_web`:** no longer reports channel declarations in field or top-level variable initializers; calls inside closures or methods still report.
- **`avoid_platform_channel_on_web`:** unguarded `invokeMethod`, `invokeListMethod` and `invokeMapMethod` calls on field channels are now reported; calls guarded by `kIsWeb` are skipped.
- **`prefer_try_parse_for_dynamic_data`:** digit group lookups on a RegExp match (`match.group(1)`) are recognized, and inline `RegExp(...).firstMatch(...)` matches are checked.
- **`require_ios_face_id_usage_description`:** no longer reports when the project root cannot be found or when Info.plist is missing, and the plist lookup now works for relative file paths.
- **`require_null_safe_json_access`:** no longer reports casts guarded by an `is` test in a conditional, or after the key was assigned earlier in the same block.
- **`require_unique_iv_per_encryption`:** no longer reports IV size constants (`ivLength`, `ivSize`, and similar) or whose initializer is an integer literal.

---

## [17.0.1-beta.1]

This beta focuses heavily on optimizing the VS Code extension's performance and improving the reliability of its Language Server Protocol (LSP) controls. Key updates include a smarter workspace hazard scan that automatically flags massive files or crowded directories for `watcherExclude`—now with built-in coverage for heavy Android and iOS build outputs—to protect extension host memory. It also overhauls the Health Panel's LSP management so server toggles work predictably without infinite spawn loops, and ensures critical upgrade prompts and detailed status tooltips remain visible even when lint integration is temporarily disabled. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.1/CHANGELOG.md)

### Added

- **Extension:** the Health Panel "Diagnostic Engines" section now states the recommended setup (LSP Server ON, Scan on Save ON, Live Analysis OFF, CI ON only if you want PRs gated, and the fallback if a rule stops firing under LSP) above the cards and as a short note on each card.
- **Extension:** new settings `saropaLints.watcherExclude.maxFileKb` (default 5120) and `saropaLints.watcherExclude.maxFolderFiles` (default 1000). The workspace hazard scan now flags any file above the size bar and any folder with more direct files than the limit, and offers to add them to `files.watcherExclude`. Rules & Tiers > Automation has a new "Watcher excludes" block with both settings, the count of files, folders and missing recommended excludes affected, and a List control for each.
- **Extension:** the recommended watcher excludes now cover Android/iOS build output (`.gradle`, `android/build`, `android/app/build`, `ios/build`, `ios/Pods`, `ios/.symlinks`, `DerivedData`); the hazard scan no longer descends into `.gradle`, `Pods` and `DerivedData`, and files under `.gradle` are excluded with `**/.gradle/**`.

### Changed

- **Extension:** dev dependencies `serialize-javascript` 7.1.0 → 7.1.4 and `undici` bumped (Dependabot, PR #360). No action required.

### Fixed

- **Extension:** the start-up upgrade offer (for example `^16.x` to 17.0.0) now also runs when Lint integration is Off (`saropaLints.enabled` false); it was skipped exactly in the projects that most needed it. The status bar item and upgrade prompt now also appear when Lint integration is Off.
- **Extension:** the status bar "N workspace issue(s)" item now lists each issue in its tooltip (large unexcluded files, missing watcher exclusions, extension host memory). Before, the tooltip showed only process stats, so the red dot gave no hint of the cause.
- **Extension:** the Health Panel "LSP Server" ON toggle no longer does nothing. The setting defaults to true, so clicking ON while the server was stopped (failed start, or after Kill All) rewrote the same value, fired no change event, and started nothing. The toggle now starts or stops the server directly, and the Health Panel refreshes. A failed start now shows an error message with the reason instead of only logging to the output channel.
- **Extension:** Health Panel "Kill All" and "Restart All" buttons now name their target ("Kill All LSP Server", "Restart LSP Server").
- **Extension:** the `saropaLints.lspServer.start` command and Health Panel "Restart All" no longer start the LSP server when `saropaLints.lspServer.enabled` is off; the start command now offers an Enable button. No action required.
- **Extension:** the LSP client no longer spawns `dart run saropa_lints:lsp_server` when `saropa_lints` is missing from `.dart_tool/package_config.json`; it shows one warning ("run `dart pub get`") instead of restarting 5 times with stacked error toasts.
- **Extension:** the "zero rules enabled" modal no longer reopens in a loop after clicking "Set Up Project". If setup does not fix the config, a single non-modal warning is shown instead.
- **Extension:** the "zero rules enabled" modal no longer appears after Enable when `violations.json` was written by the extension itself (live-diagnostics snapshot with no `enabledRuleCount`), e.g. while Lint integration is Off. A missing count is now treated as unknown, not zero.
- **Tests:** the unwritable-location test in `init_emit_ci_test.dart` no longer uses `skip:` (flagged by `avoid_skipped_tests`). It returns early on Windows instead.

---

## [17.0.0] - retracted

Retracted on pub.dev: this was meant to be a beta. Use 17.0.1-beta.1 or later.

Moves saropa_lints to the analyzer 13 and 14 lines and keeps analyzer 12 projects on the frozen 16.x line. [log](https://github.com/saropa/saropa_lints/blob/v17.0.0/CHANGELOG.md)

### Changed

- **Breaking:** saropa_lints now requires Dart `>=3.11.0` (analyzer 13.0.0 depends on `_fe_analyzer_shared` 100, which needs 3.11) and `analyzer >=13.0.0 <15.0.0`, and pub picks the newest allowed by your Dart version (3.11 and 3.12 up to 14.5.0, 3.13 14.6.0); projects held on analyzer 12 stay on `saropa_lints: ^16.7.0`, which is frozen with no back-ports.
- `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended`; update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name.
- Reports on named arguments now highlight only the argument name instead of the whole `name: value` text, so editor squiggles and `// ignore:` placement for those reports shift to the name; no action required.
- Widget rules that match by name no longer match record fields that share a widget's name, which removes false positives; no action required.
- The extension now detects at start-up whether a project uses the pubspec route, the plugin route or both, and shows one prompt offering Migrate when a newer saropa_lints works with the project's Dart. Plugin-only projects (saropa_lints only in `analysis_options.yaml`) get the same offer as pubspec projects.

### Internal

- Extension version now keeps the package's major.minor and maps only the patch (10 x package patch + slot; stable uses slot 9, prerelease N uses slot N-1), so every publish is strictly higher; a 10th prerelease of one patch is refused.

---

## [16.10.0]

Restores installation on Flutter 3.44 and older, and renames one rule whose name matched a core analyzer diagnostic. [log](https://github.com/saropa/saropa_lints/blob/v16.10.0/CHANGELOG.md)

### Fixed

- Projects on Flutter 3.44 and older could not add saropa_lints as a dev dependency from 14.0.3 onward: the `meta ^1.18.3` floor conflicted with the `meta 1.18.0` that those Flutter versions pin. The floor is back to `meta ^1.18.0`. No other dependency changed.

### Changed

- `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended` because the old name matched a core analyzer diagnostic that the analyzer is removing; update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name.

---

## [16.9.0]

A false-positive fix for `avoid_async_in_build`. [log](https://github.com/saropa/saropa_lints/blob/v16.9.0/CHANGELOG.md)

### Fixed

- `avoid_async_in_build` no longer flags an async `build` method in a class that is not a Flutter widget or State (for example a Serverpod `WidgetRoute`). Fixes [#359](https://github.com/saropa/saropa_lints/issues/359).

---

## [16.8.0]

Test-suite repair, dependency security updates, and a linting fix. No change to rule behavior or shipped output. [log](https://github.com/saropa/saropa_lints/blob/v16.8.0/CHANGELOG.md)

### Security (Extension)

- Dependency bumps: undici 8.10.0 → 8.11.2 (clears 8 Dependabot alerts); brace-expansion 5.0.9 → 5.0.12 and source-map-js 1.2.1 → 1.2.2 (clears 4 alerts).
- Dependency bump: shell-quote 1.10.0 → 1.12.0 (clears critical command-injection Dependabot alert 33, fixed in 1.11.0; dev-tooling only via npm-run-all2).

### Fixed

- `audit --baseline` now exits 1 only when a finding is new. It used to exit 1 for every finding, baselined or not, so the action's `baseline` input could never let a gate accept a known backlog. Same contract as `cross_file --baseline` and `project_health --baseline`. With no baseline file, every finding still counts.
- `audit --since` works for a project in a subdirectory of its repository (a monorepo package). The changed-file paths were joined onto the project path twice and matched nothing, so the audit covered no files. An unknown ref now also returns an empty list on git versions that report it as a "bad revision", instead of crashing.
- `init --emit-ci` writes the workflow at the repository root, where GitHub runs workflows from, and adds `working-directory` when the project is in a subdirectory. It honors an explicit `--tier`, and reports a write failure instead of printing a stack trace.
- The composite action trims glob patterns (`lib/gen/**, test/**` no longer yields a pattern with a leading space that matches nothing), accepts one pattern per line, and no longer aborts on an empty pattern. It fetches `since` given as a bare branch name, a branch with slashes or a commit SHA, and names the problem when it is on a remote other than origin. It removes a stale SARIF file before the run, creates the SARIF directory, handles an absolute `sarif-file`, and rejects `resolve` values other than true/false and a `fail-on-count` without its `fail-on`.
- Releases no longer start a second publish run for the moving `v16` tag, which matched the publish workflow's `v*` trigger. Pre-releases leave `v16` on the last stable release, the tag points at the release commit rather than whatever is checked out, and re-running the tag step repairs a `v16` push that failed.
- `extension/scripts/check_l10n_keys.py` key-union regex rewritten to eliminate exponential backtracking (ReDoS vulnerability, code-scanning alert 23).
- `avoid_string_substring` now documents that it cannot prove bounds established inside a helper function it would have to inline; suppress with `// ignore:` at the call site when the helper is bounds-safe.

### Fixed (Extension)

- The CI card writes the workflow at the repository root with `working-directory` for a project in a subdirectory. It was written under the project, where GitHub never runs it.
- Publishing the CI change no longer freezes VS Code while git pushes, and pressing the button again after a failure resumes on the same branch instead of failing at `git checkout -b`. It refuses to publish when `pubspec.yaml` already had uncommitted edits of yours (a commit takes whole files, so they would have been pushed too), when there is nothing to publish, and when a branch of the same name already exists on the remote. Opening the pull request gives up after 15 seconds on a connection that never answers and offers the compare page.
- Adding `saropa_lints` to `pubspec.yaml` keeps valid YAML for a `dev_dependencies:` with a trailing comment, four-space indentation, an existing entry at any indentation, and an empty `{}`. It also adds `^16.2.1` instead of the long-stale `^9.1.0`.
- Turning CI off a second time also suspends a job added since the first time, and toggling to the state the file is already in no longer offers an empty pull request.
- Package Vibrancy's "Generate CI Pipeline" counts only direct and dev dependencies that have a newer version, the same measure its suggested threshold now uses. Transitive packages the project cannot upgrade no longer fail a fresh pipeline. `failOnVulnerability` is enforced from the security advisories `pub outdated` reports, where it used to claim there was no data and pass. The pull request comment shows pass or fail against the threshold, the shell script uses a private temporary directory, and the GitLab job uses the maintained Flutter image.

### Internal

- Restored the scripts package markers and the cross-file, structure and example fixture sources that an earlier bulk commit deleted, which had made the CI `test` job fail.
- Health history no longer labels a point with the wrong tag when two tags (such as `v16` and `v16.6.0`) share a commit.

---

## [16.7.0]

**Published 2026-10-06 - superseded by 16.8.0**

---

## [16.6.0]

Minor release adding a new essential-tier rule that catches an unguarded `dart:developer`
`debugger()` call before it can hang a test run. It also fixes the extension's CI switch for
workflows whose jobs already carry their own conditions. [log](https://github.com/saropa/saropa_lints/blob/v16.6.0/CHANGELOG.md)

### Version Note

The pub.dev package and the VS Code extension now share one version number and will match from here on; previously the extension's minor was shifted up by two, so package `16.2.1` reached the Marketplace as extension `16.4.1`. Stable releases now use even minors only, since VS Code reserves odd ones for pre-release builds — hence the jump from `16.2.2`.

### Added

`guard_debugger_against_test_environment` flags any `debugger()` call not lexically guarded against the test environment. A VM service attaches during `flutter test` too, so an unguarded call pauses the isolate and hangs the run with no verdict — `kDebugMode` does not help, since `flutter test` itself runs in debug mode. Guard it with a condition mentioning an `isTestEnvironment`-shaped check or `FLUTTER_TEST`, anywhere up the enclosing `if` chain. The negated `if` (`if (!isTestEnvironment) { … }`), the inverted branch (`if (isTestEnvironment) { } else { … }`) and the early-return guard clause (`if (isTestEnvironment) return;`) all count. `&&` and `||` are not interchangeable: one guarded term guards an `&&`, but every term of an `||` must guarantee non-test, so `if (isBreak || !isTestEnvironment)` is still reported. No action required unless the rule fires.

### Fixed

- `prefer_utc_for_storage` no longer flags `.toIso8601String()`/epoch calls on a `final` local variable whose initializer is already UTC — directly, through a `.add()`/`.subtract()` call on a UTC value, or when the variable is read inside a nested closure — even though the receiver's own source at the call site has no `.toUtc()`/`.utc` text. `.toUtc().toLocal()` is now correctly still reported, on the receiver itself or through a local variable, since `.toLocal()` undoes the UTC conversion.
- `always_specify_parameter_names` no longer flags calls to Dart SDK (`dart:*`) methods such as `String.substring` — their positional-only parameter lists can never be changed by any caller, so the rule's own suggestion was always inapplicable there.
- `avoid_case_sensitive_path_comparison` no longer flags:
  - a path comparison on `.uri`, `.requestedUri`, or `.url` of a `dart:io` `HttpRequest` or package:shelf `Request` — an HTTP route path, not a filesystem path
  - the root-walk idiom when the `.parent` hop is held in a `final` local before the comparison

  Filesystem URIs, plain `Uri` parameters, and reassigned locals are still reported.
- `avoid_duplicate_string_literals` and `avoid_duplicate_string_literals_pair` no longer flag a URI repeated across `import`/`export`/`part` directives — Dart requires a directive URI to be a string literal, so there is no legal way to deduplicate it.
- `avoid_misused_set_literals` now flags an empty `{}` only when nothing gives it a type. It is no longer flagged when its position already supplies a `Map`/`Set` type, or when it initializes a declaration with an explicit `Map` annotation. `var x = {}` — genuinely ambiguous — is still reported.
- `avoid_stack_trace_in_production`:
  - It now recognizes a debug guard reached through a `final` local or a zero-argument helper, `!bool.fromEnvironment('dart.vm.product')`, and `kDebugMode == true`-style comparisons.
  - Behavior change: `&&`/`||`/`!` are now evaluated soundly, so a condition such as `if (verbose || kDebugMode)`, which the old text match silenced, is now reported. No action required unless a condition like this was previously silent for you, in which case it was never soundly guarded.
- `avoid_throw_in_catch_block` no longer flags `throw Error.throwWithStackTrace(...)`, including a `core.`-prefixed call and in the unresolved CLI scan pass.
- `avoid_unused_assignment` no longer flags a closure-captured variable's reset that the closure's own next invocation reads back.
- `function_always_returns_null` no longer flags null-only members in the web-side stub of a `dart.library.io`/`.ffi` conditional import — a null-only body there is the documented contract, mirrored by the native sibling file.
- `move_variable_closer_to_its_usage` no longer suggests moving an `await`-initialized declaration inside a `try` block that has a `catch`/`finally` — moving it could let an intervening statement's side effects run before the possible throw instead of after.
- `prefer_cached_getter` no longer flags repeated `.length`/`.isEmpty`/`.isNotEmpty`/`.first`/`.last` reads on a `List`, `String`, `Set`, or `Map`, or an unoverridden `.hashCode`. A lazy `Iterable` (for example a `.where(...)` result) is still reported, since those accessors are not O(1) there.
- `prefer_typed_route_params` no longer flags a parameter passed into a call whose resolved return type is `int`, `double`, or `num` (for example `parseLimit(...)`), regardless of the call's own name.
- `require_data_encryption` no longer flags auth-status metadata (`authStatusFields`, `authConfigured`, `authScheme`, `authRequired`/`authRequiredMessage`) as a credential. A real credential in the same call is still reported.
- `require_error_logging` no longer flags a catch block that propagates the error via `return Error.throwWithStackTrace(...)` or a bare call to it.
- `require_permission_plist_ios` now reads your `ios/Runner/Info.plist` and reports a permission request only when a usage-description key that permission needs is actually missing, so notification, critical-alert and Android-only permissions (which need no key on iOS) and permissions whose keys are already declared are no longer flagged. No action required, though you can remove any `// ignore:` comments you added for this rule.
- `require_yield_after_db_write` and `suggest_yield_after_db_read` no longer fire in packages that do not depend on Flutter — their premise, protecting a UI thread, does not apply there.

`google_sign_in_auth_token_from_authenticate` no longer flags `.accessToken` reads on a nullable authorization result — the exact shape v7's scope-authorization call returns — so correctly migrated code is left alone.

`prefer_late_final` no longer flags a `late` field whose assigning method is captured as a tear-off in a field initializer; the 16.2.1 fix covered only tear-offs written inside a method or constructor body, so taking the suggestion could still produce a late-initialization error at run time.

`avoid_ignoring_return_values` now reads `safe_to_ignore:` only from its own section of `analysis_options_custom.yaml` instead of silently adopting a same-named list from an unrelated section further down the file. No action required unless a stray allowlist was being picked up, in which case move those names into the rule's own section.

`banned_usage` now reads its banned-identifier list only from its own section of `analysis_options_custom.yaml`, instead of adopting a same-named list from an unrelated section further down the file or appending that section's items to its own. No action required unless stray bans were being picked up, in which case move those identifiers into the rule's own section.

`always_specify_parameter_names` now reads its allowlist only from its own section of `analysis_options_custom.yaml`, with the same fix for adopted and appended entries. No action required unless a stray allowlist was being picked up, in which case move those entries into the rule's own section.

### Added (Extension)

- The extension now checks the Dart analysis server's memory cap against this machine's RAM at startup and, when there is no cap or it leaves less than half the RAM for everything else, explains the trade-off and offers a recommended value in one click. Click Apply, or choose Don't ask again to keep your setting.
- Package Vibrancy now shows a separate "Upgrade Required" status for packages that are alive but where your installed old major version is known to be broken, instead of labeling them "End of Life"; "End of Life" now means only that the package itself is dead.
- Package Vibrancy now checks what an upgrade would break before recommending it, and replaces the upgrade nudge with the reason when dependents cap the package below the new version or the new version needs a newer dependency than your Flutter SDK pins (for example `analyzer` 13, which needs a newer `meta` than Flutter stable ships) or needs a dependency that another package in your project caps (for example a `drift_dev` release that requires `analyzer` 13 while a dependency caps it below 13), naming the package responsible. Blocked packages are also skipped by "upgrade all", and the newest version you can still take is suggested.

### Fixed (Extension)

- Manage Rule Packs no longer resets itself while the Dart analyzer is running. Your pack search, the Matching rules list, filters, sort order, opened rule lists and scroll position now stay put, and the page redraws only when something on it actually changed.
- Clicking a pack name in Manage Rule Packs' Matching rules list now scrolls to that pack, highlights it, opens its rule list and puts focus on its on/off switch. If another filter (type, Detected, Enabled) was hiding the pack, that filter is cleared and your search is kept.
- The rule detail panel now shows the rule's problem, how to fix it, impact, type and OWASP mapping when opened from Manage Rule Packs, a related-rule link or the Explain Rule command. Before, it showed only the rule name.
- Turning a rule pack off in `analysis_options_custom.yaml` no longer deletes the blank line and the next top-level section (such as `platforms:`) after it.
- Machine Health, Workspace Readiness, Set Analysis Server Heap Cap and Unload Ollama Model now appear in the command catalog.
- The saropa_lints update prompt now appears at every startup while your project is behind, instead of only once per release even when the notification was missed. Choose Don't ask for this version to silence a release.
- Setting the analysis server heap cap from System Health now changes the settings file that actually controls it, instead of reporting success while a workspace setting kept the old value.
- Package Vibrancy no longer marks healthy packages such as `flutter_map`, `camera` and `location` as end of life when checking for new adoption or offering quick fixes, because a problem recorded for an old version was being applied to every version.
- Package Vibrancy now notes when a package is unlisted, in maintenance mode or under a caution, warns when an end-of-life record may be out of date, and never offers a retracted release as the latest version.
- The known-issues data was cleaned up: about a dozen dead entries removed, wrong version limits on `hive`, `flutter_hooks`, `camera` and `responsive_builder` corrected, and long-quiet packages such as `beamer` and `camerawesome` moved to maintenance mode.
- Every translated language now has complete, correct translations: missing strings were added, broken placeholders and code snippets repaired, and hundreds of nonsensical machine translations replaced.
- The "Dismiss" button in every translated language now reads correctly; several languages previously showed unrelated machine-translated phrases.
- Package Vibrancy's known-issues data now marks `cubit`, `shared_preferences_ios`, `url_strategy` and `integration_test` as end of life, no longer flags eight revived packages (such as `alice` and `rubber`), and stops flagging current `flutter_secure_storage` versions for a pre-5.0 problem.
- The Analysis Optimizer's git-based scan now also covers Dart code inside git submodules and nested repositories.
- The nested-package warning is now translated into all supported languages.
- The Analysis Optimizer now lists Dart files through git in one pass when the project is a git repository, so scans are faster, ignored files never count, and the 50,000-file cap no longer applies there. Projects without git keep the previous scan.
- The System Health panel warns when a Dart project contains git-ignored nested package roots, which the analysis server treats as separate contexts, and offers a one-click exclude or a per-folder dismiss.
- The Analysis Optimizer now lists nested Dart package contexts as a high-priority exclusion row, and its scan honors `files.exclude` and `.gitignore`.
- The Analysis Optimizer's scan now detects `StatelessWidget` and `StatefulWidget` classes as widgets.
- The Package Dashboard no longer shows a white page with unreadable dark text under dark themes; the Feature Inventory tab's browser-only colors were overriding the editor theme.
- The System Health panel now tracks Dart processes and memory on macOS and Linux instead of only Windows, whatever the system language.
- The Analysis Optimizer now skips dot-folders such as agent worktree copies, which the Dart analyzer never analyzes, so they no longer inflate costs or crowd out real files, and a scan that hits its file cap now says the results are partial.
- The file-watcher exclude audit now suggests excluding agent worktree copies when a workspace has any, and dismissing the audit hides only the patterns shown, so a new suggestion can still appear once. Accept the prompt to add the exclusion.
- Turning CI off in the System Health panel no longer breaks a workflow whose job already has its own `if:` condition. It used to add a second `if:`, which GitHub rejects as an invalid workflow. The existing condition is now swapped for `if: false` and put back exactly when CI is turned on again. A workflow with a job it cannot safely switch off is left untouched, and the panel reports that CI is still running.
- Turning CI off no longer misses a job's own `if:` when a comment sits above it at 0-2 spaces of indent. The body scan stopped at the comment, so the `if:` further down was never found, and a second `if: false` was inserted before it — the same duplicate-key failure the previous fix was meant to prevent.
- `buildCiWorkflow`'s dartdoc had been merged into `ciNeedsExplicitTier`'s by a missing blank line, so `--emit-ci`'s workflow-generating function carried no documentation. Restored to the function it describes; no behavior change.
- The CI card and `init --emit-ci` write identical workflow files again. Their header and comments had drifted apart.

- The Config Dashboard now redraws as soon as you toggle a rule pack, enable a rule, or pick a dropdown value, instead of showing "Update pending" until you click somewhere else — only in-progress text entry defers a refresh now.

### Internal

- The extension compiles again with `vscode-languageclient` 10: the LSP client's output channel is now a log channel, which that version requires.
- The bundled rule catalog (`extension/media/rules_catalog.json`) and each rule's metadata in the `violations.json` export now include the rule's `problemMessage` and `impact`, taken from the same `LintCode` a live diagnostic uses. The catalog was regenerated.
- Restored the state and problems index modules of Package Vibrancy, which an earlier cleanup deleted and which stopped the extension from compiling.
- Added `scripts/pubdev_snapshot.py`, which downloads the latest pub.dev data for every tracked package into a reusable snapshot and refreshes the Package Vibrancy known-issues data from it; the analyzer entries now record why analyzer 13 and later is held back. It also flags packages that look revived or stale, and seven long-quiet packages moved to maintenance mode.
- The localization key checker no longer crashes, ignores its test fixture, and recognizes keys referenced through key-type unions.
- Test descriptions for the shared CI workflow fixture checks now state the expected behavior, satisfying `require_test_description_convention`.
- `CHANGELOG_ARCHIVE.md` (11k+ lines) split into one file per major.minor line under `changelog/archive/` (e.g. `15.2.x.md`); the old file is now a short index. Every release entry is preserved (plus 10.12.0–12.2.1, recovered from git history where an earlier trim had deleted them without archiving) and stays greppable with `grep -r <term> changelog/archive/`. `scripts/split_changelog_archive.py` regenerates the split and index; `compact_changelog_archive.py` and the rule-version-history scan now read the directory, and `changelog/` is excluded from the pub.dev package.

- Section bounding for the line-based config readers is now a single directly tested helper, adopted by all three readers.
- The Flutter SDK contract lookup behind `avoid_public_members_in_states` is computed on demand, so a `State` class with no public overridden members no longer pays for element resolution and a supertype walk.
- `avoid_string_substring` now documents that it cannot prove bounds established inside a helper function it would have to inline; suppress with `// ignore:` at the call site when the helper is bounds-safe.

---

## [16.3.0]

Minor release adding a GitHub Actions integration: a composite action, a CLI flag that writes the workflow for you, and a switch in the extension that turns it on and off. [log](https://github.com/saropa/saropa_lints/blob/v16.3.0/CHANGELOG.md)

### Added

A composite GitHub Action at the repository root runs saropa_lints against a project's pull requests. Reference it as `saropa/saropa_lints@v16`, which now tracks the latest 16.x. `mode` decides what a finding does — `annotate` posts SARIF to the pull request diff, `gate` fails the build, `both` does each. `command` decides which rules produce one — `scan` honors the project's own `analysis_options.yaml`, `audit` runs every rule regardless of configured tier, and `auto` picks per mode. An analysis that could not run fails the job in every mode, so a green check always means it actually ran.

`dart run saropa_lints:init --emit-ci` writes `.github/workflows/saropa-lints.yml` into a project, pinned to the saropa_lints version doing the generating. It refuses to overwrite an existing file, so a re-run cannot discard workflow edits a team has made.

### Added (Extension)

- A **GitHub Actions CI** card in the System Health panel turns CI on and off for the project. ON adds the dependency if missing and writes the workflow; OFF adds one `if: false` line per job rather than deleting the file, so the change is reversible and any customization survives. Neither direction commits anything on its own — the file governs every contributor's pull requests, so it goes through normal review.
- The generated workflow runs the `scan` command, which honors the project's configured tier and per-rule choices rather than reporting all 2332 rules, and carries `continue-on-error` so it reports without failing pull requests. Removing that line makes it enforce.
- Both directions of that switch offer to open a pull request for the change, since nothing reaches CI until it is on the default branch. It is a deliberate step, never automatic: the panel shows the exact git commands it would run, beside a copy button, and cuts no branch until the button is pressed. Only the workflow file is ever staged, the branch is always new and the push is never forced, and a failure names the step that failed and leaves the commands valid to finish by hand.

### Fixed (Extension)

- The Diagnostic Engines section of the System Health panel is no longer hidden when `saropaLints.debug.enabled` is off. These controls decide whether analysis runs at all, and one of them turns off a project's CI.
- Package Vibrancy's "Generate CI Pipeline" produced workflows that always passed: thresholds were printed but never compared, and the generated checker was invoked in a way that never executed it. The generated workflow now compares against `maxOutdated` and fails the job when it is breached. Thresholds that `pub outdated` carries no data for are now stated as unenforceable rather than silently ignored.

---

## [16.2.1]

Patch release fixing false positives in two lint rules, adding a project-level allowlist for `avoid_ignoring_return_values`, and resolving unwanted reload behavior in the Config and Findings Dashboards when editing text fields. [log](https://github.com/saropa/saropa_lints/blob/v16.2.1/CHANGELOG.md)

### Added

`avoid_ignoring_return_values` now supports a project-level allowlist via `analysis_options_custom.yaml` — add method names under `avoid_ignoring_return_values: safe_to_ignore:` to exempt project-specific methods whose return values are safely ignored. No action required unless you have project-specific methods you want to allowlist.

### Fixed

`google_sign_in_auth_token_from_authenticate` no longer flags `.accessToken` reads on already-migrated `GoogleSignInClientAuthorization` results or unrelated model classes with a same-named field.

`avoid_public_members_in_states` no longer flags `WidgetsBindingObserver`/`RouteAware`/`AutomaticKeepAliveClientMixin` callback methods (e.g. `didChangeAppLifecycleState`, `didPushNext`, `wantKeepAlive`) on a `State` class that carries the interface via `with` or `implements` — their public spelling is mandated by the framework, so the rule's own suggested private-rename fix would have silently broken dispatch.

`prefer_late_final` no longer flags a `late` field whose assigning method is passed elsewhere as a bare tear-off (e.g. `setState(_initFutures)`) — the tear-off's runtime call count can't be bounded from the declaration site, so the field may genuinely be reassigned even though only one direct call site is visible in the AST.

`avoid_ignoring_return_values` no longer flags a project-local `extension` method whose name follows a mutate-verb convention (`add*`, `append*`, `insert*`, `remove*`, `update*`, `set*`) and returns `bool` — the same structural shape as allowlisted stdlib mutators like `List.add`, where the bool is a "did it happen" convenience the caller is not required to consult.

`require_ios_accessibility_large_text` no longer flags `TextStyle(fontSize:)` when the value comes from a non-const getter, method call, or property access — only bare numeric literals and const identifiers are flagged. Previously the rule pattern-matched source text for `textScaleFactor`/`textScaler`/`MediaQuery` substrings and missed any design-system token that applies Dynamic Type scaling through a helper.

### Fixed (Extension)

- The Config Dashboard and Findings Dashboard no longer constantly reload while you type into a search box or text field — a background refresh (triggered by the analyzer's live diagnostics, config-file saves, or workspace tree updates) was rebuilding the whole panel on every tick regardless of whether you were mid-edit, which also made the Config Dashboard's "Matching rules" → "in `<package>`" links appear dead since the panel they lived in kept getting torn down. Both dashboards now wait until you leave the field before redrawing.
- The Config Dashboard's collapsible sections (packs, disabled rules, shed rules, style & opinions) now remember whether you left them open or closed, the same way the Findings Dashboard's sections already did.

---

## [16.2.0]

The audit command now gives you complete visibility into suppressed warnings across your codebase, revealing exactly what is being silenced in your project. A new diagnostic flags unbounded images that waste memory, while the extension introduces robust workspace hazard scans and a fully collapsible Findings Dashboard. [log](https://github.com/saropa/saropa_lints/blob/v16.2.0/CHANGELOG.md)

### Added

The audit command now gives you complete visibility into suppressed warnings across your codebase. You can optionally expose findings previously hidden by ignore directives or baseline files to understand exactly what is being silenced in your project. [log](https://github.com/saropa/saropa_lints/blob/v16.2.0/CHANGELOG.md)

New rule `avoid_unbounded_image_in_full_bleed_container`: flags an `Image`/`Image.asset`/`Image.network`/`Image.memory`/`Image.file` with no `width`/`height`/`cacheWidth`/`cacheHeight` sitting inside a full-bleed ancestor (`Positioned.fill`, `SizedBox.expand`, or a `Stack` with `fit: StackFit.expand`) — the image decodes at native resolution and is then stretched to fill an arbitrarily large parent, wasting decode memory. Skips false positives where a nearer `SizedBox`/`Container`/`ConstrainedBox`/`AspectRatio` already constrains the image's own size.

### Added (Extension)

- New file-watcher exclusion audit checks the workspace's `files.watcherExclude` setting on activation and recommends missing patterns for heap dumps, build output, and tooling caches that can crash VS Code when tracked. "Add All" writes them into workspace settings in one click; "Dismiss" suppresses the prompt permanently for that workspace.
- Extension host process memory monitoring: the ProcessMonitor now samples the Node.js extension host RSS and heap on each poll, with trend tracking and a configurable warning threshold (`extensionHostWarningGB`, default 1 GB) that surfaces in the status bar — the blind spot behind the 2026-09-05 crash.
- Workspace hazard scan: on activation, scans for dangerously large files (heap dumps, oversized logs, any file >100 MB) not excluded from the file watcher. Warns with a one-click action to add `files.watcherExclude` patterns. Disable via `saropaLints.systemHealth.workspaceHazardScan`.
- Workspace readiness indicator: combines hazard scan, watcher exclude audit, and extension host memory into a single status bar signal with a `saropaLints.showWorkspaceReadiness` command that opens an actionable quick-pick listing each issue.
- Every top-level section of the Findings Dashboard (Overview KPIs, Charts, TODO/HACK, Drift Advisor, Suppressions, Top Rules, Findings) is now individually collapsible via a native disclosure triangle. Each section remembers its open/closed state per workspace, and a collapsed section still shows its counter so you know how many items are inside without expanding it.
- Unified every counter on the Findings Dashboard (chart totals, section headers, TODO/HACK counts, and the big KPI stat-card numbers) onto the same pill component already used by the status-line pills, for one consistent counter look across the page. Severity colors are unchanged.
- "Include suppressed" checkbox in the Findings Dashboard toolbar (visible only in audit mode) passes the new `--include-suppressed` CLI flag through the UI — check it, run audit, and suppressed violations appear in the findings table with an orange "Suppressed" pill badge. No config files are touched.
- New "Copy everything as JSON" and "Save everything report" items in the More-actions menu (audit mode only) export the raw, unfiltered audit result — bypassing all dashboard filters and including suppressed findings — so you can get a true everything-export without manually clearing filters first.
- New "Suppressed Findings" collapsible section appears in the dashboard when audit mode has `--include-suppressed` active and there are suppressed violations. Groups findings by suppression kind (ignore, ignore_for_file, baseline) with a mini table and per-row "Unsuppress" button (currently shows a hint — full comment-removal is planned).
- New "Suppress all visible" bulk action in the Findings Dashboard's More-actions menu inserts `// ignore: <rule>` above every finding currently shown in the table, in one confirmed, all-or-nothing edit across every affected file. Disabled when there are no findings to suppress.
- New extension-native check flags a `bugs/*.md` report marked Fixed, Closed, or Declined that is still sitting in `bugs/` instead of being archived to `plans/history/`, as a Problems-panel hint on the report's `Status:` line. No action required — this only surfaces reports that were left un-archived.
- New extension-native check (mirror image of the above) flags a markdown file filed under the configured archive directory (default `plans/history/`) that still reads as open work — an open `Status:`/`Severity:` field or an unaddressed action-items heading — as a Problems-panel hint suggesting it be moved to the open-issues directory instead. Archive glob, open-issues directory, and the open/closed signal patterns are all configurable via `saropaLints.docPlacement.*` settings; disable with `saropaLints.docPlacement.enabled`.

### Fixed (Extension)

- Drift Advisor integration now supports authenticated servers via a new `saropaLints.driftAdvisor.authToken` setting, with matching guidance states in both the tree view (linking to Settings) and the Findings Dashboard status pill when a token is missing or was rejected by the server.

- Fixed Code Health dashboard KPI tiles silently losing their semantic color coding (red/amber/info) after the pill-unification refactor — `kpiCard()` was missing the `.pill` class that the updated CSS selectors require.

- Fixed silent status bar disappearance when `updateAllStatusBars` throws (e.g. corrupted `workspaceState` after a VS Code hard crash). The bar now catches errors, shows a visible `$(error) Saropa Lints: Error` state with an error-themed background, and logs to the output channel so the failure is discoverable.

### Internal

- Converted the workspace hazard scan's recursive directory walk from synchronous `fs.readdirSync`/`fs.statSync` to async `fs.promises.readdir`/`fs.promises.stat`, preventing the extension host thread from blocking on large workspaces. Subdirectory walks and file stat calls now fan out concurrently via `Promise.all`.
- Extracted duplicate watcher-exclude merge logic (read config, spread, set keys, write at workspace level) from both `workspaceHazardScan.ts` and `watcherExcludeAudit.ts` into a shared `mergeWatcherExcludes` helper in `watcherExcludeHelpers.ts`.
- Added a guard around the watcher-exclude audit's `workspaceState.get` call so a corrupted workspace state after a VS Code crash does not prevent the audit from running.
- Fixed extension version scheme so stable releases supersede their betas on Marketplace and Open VSX. Stable versions now bump minor to the next even above the prerelease odd minor (e.g. `16.2.x` > `16.1.x`).
- Documented the split between Dart AST rules (`lib/src/rules/`, scoped to resolved `.dart` files) and ad hoc extension-native checks (`extension/src/`, full workspace file access, own `DiagnosticCollection` each, not yet surfaced in the web report) in `bugs/ISSUE_REPORT_GUIDE.md`, so non-Dart-file issues are routed correctly instead of being misfiled as out of scope.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.

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

2350+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTENANCE NOTES -- IMPORTANT --

   Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/spec/v2.0.0.html). Omit dates from headers, because [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays them.

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

   **Unreleased convention** — While work is in progress, the top section MUST be headed `## [X.Y.Z] — Unreleased`. Put all new entries in this ONE section: never create a second unreleased section or bump the version. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) via `_strip_unreleased_suffix()`. `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle. A section is published only when its git tag `vX.Y.Z` exists (`git tag -l vX.Y.Z`). If the top section has no tag, it is the unreleased section even when the ` — Unreleased` suffix is missing, so add entries there.

   **Tagged changelog** — Published versions use git tag `vx.y.z`, and each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [17.10.1] — Unreleased

`require_error_widget` stops asking for an error branch that can never run, and the VS Code extension can now explain which baseline settings hide findings in a file. Accepted findings are now counted wherever suppressions are broken down by kind. [log](https://github.com/saropa/saropa_lints/blob/v17.10.1/CHANGELOG.md)

### Fixed

- `require_error_widget` no longer reports a `FutureBuilder` whose future comes from a same-file async method that catches every error and only logs and returns a fallback, since its error state is unreachable; futures from other files, overridable methods and handlers that can still throw are still reported. No action required.
- The scan CLI, scan daemon and language server now apply each package's own baseline when one run covers a folder with several packages; before, only the first analyzed package's baseline was used for every file. No action required.

### Added (Extension)

- New "Explain Baseline for This File" command in the editor and Explorer context menus for Dart files shows which baseline settings hide findings in that file, in the Output panel. On Windows, if the file path holds a character the shell cannot pass safely, the error message says so. No action required.

### Changed (Extension)

- The Rule Packs "Suppressions (export)" strip and the exported OWASP report now list findings hidden by `saropa_accepted.yaml` next to the ignore and baseline counts, so the kinds add up to the total. No action required.

### Fixed (Extension)

- Urdu text that had been written with Sindhi-only letters is corrected. No action required.

### Internal

- A translation guard and the locale parity test now fail when an Urdu value contains a Sindhi-only letter.
- New process-level tests run the scan daemon and the language server on a temporary package to check that `max:` in `saropa_accepted.yaml` hides only the first findings and that ignored findings do not count toward it.
- Diagnosed why `dart analyze` on a folder holding two packages reports plugin findings for only one: the analysis server tracks one shared "plugin analyzing" flag for all plugin isolates, so it reports idle once the first isolate finishes, before a slower second isolate starts. Upstream; the limit is documented in the configuration guide.

---

## [17.10.0]

> **Upgrade note:** A plain `dart run saropa_lints scan` no longer skips when the plugin block in `analysis_options.yaml` is commented out, which the language server does by default and `init` can leave behind, so git hooks and CI that passed by skipping can now report findings and fail. To keep skipping, set `"saropaLints.enabled": false` in `.vscode/settings.json` and commit that file; a switch in user settings or a `.code-workspace` file is not seen by the scan.

Many lint rules report fewer false positives, covering paths, caches, async guards, parsing, secrets, long tasks, HTTP responses, and Firebase calls. The adaptive widget rule now targets different code than before. [log](https://github.com/saropa/saropa_lints/blob/v17.10.0/CHANGELOG.md)

### Added

- A `saropa_accepted.yaml` beside a package's `pubspec.yaml` (rule, file and reason, no line numbers) hides reviewed findings from Problems, scan, audit and violations exports; each file uses the list of its nearest `pubspec.yaml`. An optional `max:` count hides only the first findings by source position and reports the rest. `scan --check-accepted` checks every list under the target and fails on stale or invalid entries. The VS Code extension adds "Accept {rule} in this file" and "Check Accepted Findings".

### Changed

- `prefer_platform_widget_adaptive` no longer reports `MaterialApp`; it now reports Material controls that leave an available `.adaptive` constructor unused and are not already branched by platform, in resolved analysis such as the editor. Review any new reports.
- The homepage link of the package and the VS Code extension now opens the product page at [saropa.com/developers/saropa-lints](https://saropa.com/developers/saropa-lints/). No action required.

### Fixed

- `avoid_case_sensitive_path_comparison` no longer flags a comparison against a MIME type, so content type checks are not treated as file path checks (a named constant is recognized only in resolved analysis such as the editor). No action required.
- `require_file_path_sanitization` now reports only when the path actually uses a parameter, not when a property or literal text merely shares its name. No action required.
- `avoid_path_traversal` now reports only when the path actually uses a parameter, not when a property or literal text merely shares its name. It also no longer stays silent when a literal-only parameter precedes a user-supplied one in the same path. No action required.
- `avoid_unbounded_cache_growth` no longer flags a private cache map that is only ever replaced whole by a freshly built map, since old entries cannot accumulate. No action required.
- `require_cache_expiration` no longer asks for expiration on a private cache map that is only ever replaced whole, since each replacement already refreshes it. No action required.
- `no_equal_nested_conditions` no longer flags a condition checked again after `await` or `yield` when its value can change during the suspension, such as a getter, mutable field, or method call. The same applies to a check repeated inside a closure that may run later, and to a check after a call when a closure in the same declaration writes the condition's variable or field. No action required.
- `prefer_try_parse_for_dynamic_data` no longer flags, in the unresolved scan, `Uri.parse` of an interpolation of constants declared in the same file, including static class fields. No action required.
- `prefer_try_parse_for_dynamic_data` now recognizes digit-only regex checks declared in an outer block or seen by the unresolved scan, and reports guarded parses that can still receive empty or non-digit text (such as an unanchored pattern or an open-ended `substring`). A pattern variable or local function that reuses a checked name no longer counts as checked. Review any new reports.
- `require_envied_obfuscation` no longer reports `bool` fields, which cannot hold a secret and lose `static const` when obfuscated. No action required.
- `require_notification_for_long_tasks` no longer reports a `syncAll`, `processAll`, `exportAll`, or `importAll` call whose same-file function provably does only short work, in resolved analysis such as the editor. No action required.
- `require_http_status_check` no longer reports a private send helper that returns the HTTP response unread when all its callers in the file are methods, which now carry the status check requirement (assigning to a local before returning is still reported). Add a status check to any newly reported caller.
- `require_refresh_indicator` and `require_refresh_indicator_on_lists` no longer report a list in a private widget that its file only shows in a dialog, popup, menu or bottom sheet (including `show...Dialog` wrappers), or a list whose `itemCount` is the length of a constant list. A screen pushed from a dialog button, and a list name shadowed by a local or by a member of the same class, are still reported. No action required.
- `require_firebase_error_handling` no longer reports a Firebase call in a private async helper when every reference in the library is an awaited call inside try-catch, directly or through a private or `@visibleForTesting` function field. No action required.
- `dart run saropa_lints:baseline` now activates the baseline as a top-level `baseline:` section in `analysis_options_custom.yaml`, where it is read; it previously wrote it into `analysis_options.yaml`, where it never took effect. The baseline file now resolves against the project root instead of the analysis server's working directory. Re-run the command once if you created a baseline before; an old nested `baseline:` entry in `analysis_options.yaml` can be removed.
- `dart run saropa_lints:baseline` (including `--update`) no longer drops entries that are still present when a baseline is already active, because its analysis run now ignores the current baseline JSON (`date:` and `paths:` still apply). A relative output path now lands in the analyzed project when a project path is given. No action required.
- `dart run saropa_lints:baseline ./my_project` now analyzes the named project instead of the current directory. When a `baseline:` section already exists, the command adds or updates its `file:` line (keeping the other keys) and prints the change. No action required.
- The `baseline:` section now accepts trailing `# comments` and inline lists such as `only_impacts: [info]`, which were previously misread; legacy impact names (`low`, `medium`, `high`, `critical`) map to the current severities. Check that the filtered baseline hides what you expect.
- In the editor, each project in a multi-root workspace now uses its own `baseline:` section, so one project's entries and paths no longer hide findings in another. No action required.
- `baseline: date:` now hides findings on lines committed before the date in the editor, `dart analyze`, the language server and `scan`; it previously hid nothing. Uncommitted, unsaved and untracked code still reports. It runs `git blame` once for each file with findings (about 0.1 to 0.3 seconds each), so expect a slower first analysis on large projects and fewer reported findings.
- `dart run saropa_lints:baseline --explain <file>` shows which baseline settings (`paths:`, JSON entries, `date:`, `only_impacts:`) hide findings in that file, without running analysis. No action required.
- "Check Accepted Findings" in the VS Code extension now also checks a workspace folder whose `pubspec.yaml` sits one folder down, and a folder that uses saropa_lints without listing it in `pubspec.yaml`. A package nested inside a folder that is not checked is no longer skipped. No action required.
- "Migrate Renamed Rules" in the VS Code extension now also renames rules in `saropa_accepted.yaml`, so renamed rules keep their reviewed entries. Entries for removed rules are kept and reported by `--check-accepted` for you to delete.
- The Hebrew VS Code extension no longer shows Arabic or Japanese characters and garbled words in six accepted-findings and stale-override messages, and the language picker title no longer carries extra trailing words. No action required.
- Translated VS Code extension text no longer falls back to English in the status bar's install-route labels and a few other strings, keeps the command links and code samples that several walkthrough steps and settings had lost, and shows a clean language picker title in 17 languages. The Hebrew accepted-findings messages use consistent wording. No action required.
- Translated VS Code extension text no longer shows the translator's own instructions ("Strict rules: 1. Return only the translated string…"), labels repeated three or four times ("Linea Linea Linea Linea"), or sentences that run on far past the English, in walkthrough steps, settings, column headers and messages across all 24 languages. No action required.
- Translated VS Code extension text no longer contains sentences the translator invented (such as "Es el nombre de la persona que tiene…" after "Saropa Lints:") or nonsense labels such as "El mensaje es el mensaje." for "Message", and buttons and column headers no longer end in a stray full stop, in all 24 languages. No action required.
- `scan` and other command-line scans given a relative folder such as `.` now apply that project's baselines, configuration and `// ignore:` matching as they do for a full path. No action required.
- "Check Accepted Findings" and `scan --check-accepted` now run when the VS Code extension has commented out the plugin block (its default with the language server on) instead of skipping without a result. No action required.
- Scans run by the language server, scan-on-save and `--tier` now keep the rule settings in a plugin block the extension commented out, so rules turned off there stay off. No action required.
- A plain `scan` now runs with the commented-out rule settings, instead of printing "scan skipped", when the plugin block is commented out because the language server is on or `init` left it that way, so hooks and CI that passed this way can now report findings. To keep skipping, set `"saropaLints.enabled": false` in `.vscode/settings.json` and commit it; a switch set only in a `.code-workspace` file or user settings is not seen.
- `scan --find-stale-ignores` no longer reports a live `// ignore:` as stale, and `--fix-stale-ignores` no longer deletes it. A comment is reported only when its rule ran on a fully scanned file and did not fire there; comments for rules that did not run, files that could not be scanned, and comments the check cannot place are kept. Both modes now use a resolved, single-process scan (slower on large projects) and also run when the VS Code extension has commented out the plugin block. Re-check any ignore an earlier `--fix-stale-ignores` run removed.

### Internal

- The locale parity test and `bad_translations.py` now fail on a leaked numbered translator prompt, a word or phrase repeated three times in a row, or a long value more than 2.5 times the English length; flagged entries are also pruned from the translation cache.
- The same guards now also fail on 85 known invented phrases (`extension/scripts/i18n/invented_phrases.json`, each excused when the English justifies it) and on Chinese, Japanese or Korean text repeated back to back; the hand repairs live in `extension/scripts/i18n/invented_repairs/`.
- Added behavioral tests for `require_copy_with_null_handling` and documented that it judges the `copyWith` declaration only, not callers or clear-by-empty conventions; detection is unchanged.

---

## [17.9.1]

Package Vibrancy is more accurate about which `dependency_overrides` entries are still needed, and now records in its log why a check was skipped instead of failing silently. [log](https://github.com/saropa/saropa_lints/blob/v17.9.1/CHANGELOG.md)

### Fixed (Extension)

- Package Vibrancy no longer flags a needed override as stale when the parent package's constraint line carries a trailing comment; skipped constraint reads are now logged. No action required.
- The Package Vibrancy stale-override warning can now be dismissed for a deliberate override with a quick fix, "Suppress (override is intentional)", which adds `# saropa_lints:ignore stale-override` to the line. No action required.
- Overrides whose check could not complete (dependency graph failed, or a parent package's pubspec was unreadable) now show as "Unverified" instead of "Stale", so they are never presented as safe to remove. Re-run the scan once the cause (named in the tooltip and log) is fixed.

---

## [17.9.0]

Package Vibrancy no longer rewrites `pubspec.lock` in FVM-pinned projects, now uses the project's pinned SDK and respects `saropaLints.enabled`; `avoid_screenshot_sensitive` reports fewer false positives and catches more real authentication and verification screens; and `prefer_test_find_by_key` is now opt-in. [log](https://github.com/saropa/saropa_lints/blob/v17.9.0/CHANGELOG.md)

### Added

- **Explain Last Vibrancy Skip**: when Package Vibrancy skips a pub query to protect `pubspec.lock`, a status-bar item now appears; clicking it (or running the command) shows which SDK was selected, where it came from, the project SDK version, and the rule that caused the skip, with a button to run `pub get` using the project SDK (`dart pub get` for pure-Dart projects, `flutter pub get` for Flutter projects, with an extra confirmation when the SDK would come from PATH). Multi-root workspaces list each skipped folder.

### Fixed

- Package Vibrancy no longer rewrites `pubspec.lock` with the wrong SDK. Its `dart pub outdated` / `dart pub deps` / `flutter` calls now use the workspace SDK (`dart.sdkPath`, `dart.flutterSdkPath`, or the FVM pin) instead of whatever is first on PATH, and a pub query is skipped when the SDK differs from the one that last resolved the project. The startup scan and the new-version watcher also respect `saropaLints.enabled: false`.
- `avoid_screenshot_sensitive` matched sensitive words as substrings of class names (`pin` inside "mapping" or "shipping"); it now matches whole camelCase words, so only classes that name a screen, page, view or widget for payment, login, PIN and similar flows are reported. The debug/tooling exclusion is also whole-word now, so `viewer` no longer hides `ReviewerPaymentScreen`. State, ViewModel and controller classes are skipped, and a StatefulWidget is cleared when its `State` class applies `FLAG_SECURE`. It also now catches authentication, authorization, verification and passcode screens (for example `AuthenticationScreen`, `VerificationScreen`), which were missed before; no action required.

### Changed

- **`prefer_test_find_by_key` is now opt-in**: it moved from the Recommended tier to the stylistic (opt-in) set and left the `testing` rule pack, because it flagged every `find.byType()` and fixing it meant adding Keys to production widgets. Enable it explicitly in `diagnostics:` if the project wants key-based finders.

### Internal

- Vibrancy pub-guard strings are hand-translated in all 24 locales, and the stale `pubGuard.skipped` key (leaked machine-translation prompt text) is removed. No action required.
- The locale audit (`generate_locales.py --fail-on-missing`, the publish gate) now reads the shipped catalogs: keys absent from a locale, leaked MT prompt text, repeat loops and wrong-script characters fail the gate, and coverage badges count them. About 340 corrupted catalog values across 20+ locales were hand-retranslated so the gate passes; new standalone `extension/scripts/i18n/check_locale_garbage.py`.

---

## [17.8.0]

Fewer false positives: over 20 rules no longer flag code that was already correct (cached notifiers, loop-disposed controllers, `InkWell` hover/focus, button busy spinners, projects without an `ios/` folder and more), the VS Code LSP server stops rewriting `pubspec.lock` in FVM-pinned projects, and published rule counts and the Vietnamese comparison label are fixed. [log](https://github.com/saropa/saropa_lints/blob/v17.8.0/CHANGELOG.md)

### Changed

- Rule-count claims in the README, extension README, extension manifest strings, translated catalogs, welcome panel fallback, About pages, Professional Services page and every migration guide now say "2350+" instead of a mix of 1400+, 1500+, 2100+ and 2300+; no action required.

### Internal

- New `scripts/checks/check_report_attribution.py` proves a reported diagnostic is a saropa_lints rule before a bug is filed or fixed; `bugs/ISSUE_REPORT_GUIDE.md` now routes Dart SDK diagnostics upstream and asks reporters to retest on the latest release.

### Added

- New rule `prefer_generated_data_classes` (Professional, INFO): in projects that depend on dart_mappable, freezed or json_serializable, flags a class that hand-writes `copyWith`, `==` together with `hashCode`, or `toJson`/`fromJson` using two or more string keys. Classes annotated `@MappableClass`, `@freezed`, `@unfreezed` or `@JsonSerializable`, classes using a generated mixin, and abstract classes are skipped; `toString` alone does not trigger it. Reported in #415.
- VS Code: **Saropa Lints: Scan with Latest Engine (Older Dart Projects)** runs the newest scan engine under a newer Dart SDK (PATH `dart`, or `saropaLints.externalEngine.dartSdkPath`) against a project pinned below Dart 3.11, and lists the findings in the Problems panel. It also appears as a **Scan with latest engine** row in the sidebar Actions list, shown only when the project's Dart SDK is below 3.11. The first run asks before installing the engine globally; the project's `pubspec.yaml` and SDK pin are untouched. New guide: `doc/guides/older_dart_sdks.md`.

### Fixed

- VS Code: the LSP server never started because the extension passed `--no-pub` to `dart run`, an option Dart 3.8 and 3.14 both reject. It now launches `bin/lsp_server.dart` directly against the project's `package_config.json`, which also avoids any implicit `pub get`.
- VS Code: the LSP server no longer crash-loops five times when the project's locked `saropa_lints` is older than 15.2.10 (no `bin/lsp_server.dart`, e.g. 4.15.1); the extension skips the spawn and shows one warning naming the installed version, the minimum, the exact `pubspec.yaml` edit (or the Dart SDK upgrade needed first when the project is below Dart 3.9), and an **Open pubspec.yaml** button.
- `avoid_skipped_tests` no longer flags a `skip:` driven by `bool.fromEnvironment` / `String.fromEnvironment` / `Platform.environment` (directly or via a variable initialized from one), since that is an opt-in gate; `skip: true` and string reasons are still reported; no action required.
- VS Code: **Run analysis** in the sidebar now restarts the Dart analysis server, shows scan progress with a Cancel button, and refreshes the views and status bar with the issue count; previously it only re-copied existing diagnostics and showed nothing when issues were found.
- VS Code: the LSP server now launches with the workspace's pinned Dart SDK (`dart.sdkPath`, `dart.flutterSdkPath`, or `.fvm/flutter_sdk`, falling back to PATH) and runs with `--no-pub`, so it no longer rewrites `pubspec.lock` or `package_config.json` in FVM-pinned projects.
- VS Code: the Package Vibrancy `sdk-constraint` warning on `pubspec.yaml` can now be silenced with `# saropa_lints:ignore sdk-constraint` on the `sdk:`/`flutter:` line or the line above, or via the new "Suppress (intentional old SDK)" quick fix, for projects that deliberately pin an old SDK. A `# saropa_lints:ignore-file` comment (optionally followed by codes) now silences those codes for a whole `pubspec.yaml`.
- `avoid_change_notifier_in_widget` no longer flags a notifier created with `_field ??= Notifier()` inside `build()`, since it is cached in a State field; no action required.
- `avoid_ios_hardcoded_status_bar` no longer flags `SizedBox(height: 20/44/47/59)` used as spacing or a fixed row height inside a `children` list; no action required.
- `avoid_keyboard_overlap` no longer flags a TextField inside a widget that returns a bare Column/Row with no Scaffold of its own, because the scroll view is owned by the hosting page; no action required.
- `avoid_undisposed_instances` no longer flags controllers disposed by a `for (final c in [_a, _b]) c.dispose();` loop in `dispose()`; no action required.
- Hover, focus, cursor, refresh-indicator, scroll-controller, intrinsic-dimensions and gesture-behavior lints no longer fire on map-marker or `Semantics(button: true)` tap targets, non-scrolling or dialog/popup lists, or stretch Columns whose width is already bounded; no action required.
- `prefer_abstraction_injection` no longer flags factory-function parameters such as `Dio Function()? dioFactory`, since the closure is the injection seam; no action required.
- `prefer_number_format` no longer flags `DateTime` day/hour/minute/month/weekday values in text, since they never need locale grouping; no action required.
- `prefer_positioned_directional` no longer flags `Positioned` whose `left`/`right` derive from Offset `.dx`/`.dy` geometry (absolute canvas layouts); no action required.
- `prefer_scalable_text` no longer flags a literal `TextStyle(fontSize:)`, since Flutter scales it by default; it now reports only `Text` or `RichText` that disables scaling (`TextScaler.noScaling` or `textScaleFactor: 1`); no action required.
- `prefer_skeleton_over_spinner` no longer flags a progress indicator used as a button's busy icon (`icon:`, `child:` or `label:` of a `*Button` widget); spinners outside buttons are still reported; no action required.
- `prefer_static_method` no longer flags instance methods that read only bare `final` instance fields (for example immutable value classes); no action required.
- `require_copy_with_null_handling` no longer flags a `copyWith` that clears a nullable field through a boolean flag such as `noExtra` or `clearExtra`; no action required.
- `require_hover_states`, `prefer_cursor_for_buttons` and `require_focus_indicator` no longer flag `InkWell`/`InkResponse`, which already provide hover, focus and click cursor; only `GestureDetector` is reported; no action required.
- `require_ios_multitasking_support` no longer fires in projects with no `ios/` directory (for example Android/Windows-only apps); no action required.
- `require_semantic_label_icons` no longer flags decorative icons passed as `icon:`, `prefixIcon:`, `suffixIcon:` or `leading:` to a widget that already has a text label (`ButtonSegment`, `FilledButton.icon`, `InputDecoration.labelText`); no action required.
- `require_text_overflow_handling` no longer flags dynamic `Text` used as the `title`/`subtitle` of ListTile-family widgets or as the direct child of `Expanded`/`Flexible`, since those slots already wrap and bound width; no action required.
- The Vietnamese label under the package count in the comparison view no longer reads "so sánh trong khi so sánh." and now reads "đang so sánh"; no action required.

---

## [17.7.0]

Scanning now uses your computer's cores while staying careful with its memory: large projects scan several times faster, the VS Code whole-project scan finishes in about a minute instead of tens of minutes, and a scan that would strain your machine slows itself down — and tells you how to fix it — instead of freezing it. [log](https://github.com/saropa/saropa_lints/blob/v17.7.0/CHANGELOG.md)

### Added

- `scan` runs in parallel by default (`--jobs <n|auto|off>`), sized from your CPUs, free memory and container limits, so large scans finish sooner on CI and desktops alike — use `--jobs 1` for the old serial behavior.
- `scan` watches its own memory (`--max-memory-mb`), sheds workers under pressure, and stops early with exit code 3 rather than risk the machine — a gate can no longer pass on a partial scan.
- `scan` recovers from a file that hangs a worker (`--chunk-timeout`), skips and names it, and reports slow files (`--slow-file-ms`) so you can see what makes a scan slow.
- `scan --progress plain` prints a status line every 15 seconds, which is readable in CI logs; the GitHub Action gained `jobs` and `max-memory-mb` inputs.
- VS Code: **Scan Whole Project for Issues** now defaults to a fast parallel scan (`saropaLints.scanOnSave.baselineMode`) and offers the type-aware deep scan afterwards with a time and memory estimate; no action required.
- VS Code: **Saropa Lints: Scan Performance and Memory Settings…** shows what each profile (`gentle`, `balanced`, `fast`) would do on your machine and recommends one; fine-tune with `saropaLints.scan.maxWorkers` and `saropaLints.scan.maxMemoryMb`.
- `scan --max-issues <n>` (also `SAROPA_LINTS_MAX`) sets how many non-error issues are reported; the default is now unlimited so reports and `--fail-on-count` thresholds are complete, and errors are never capped — pass `--max-issues 500` to restore the old cutoff.
- A new `max_rss_mb` key in `analysis_options_custom.yaml` sets the live analyzer plugin's hard memory cap without needing an environment variable; `SAROPA_LINTS_MAX_RSS_MB` still overrides it.
- VS Code: choosing the gentle profile (or opening a project on a small computer with no limits set) offers a one-click, machine-sized memory limit and graceful rule shedding for live analysis, then offers to restart the analysis server.
- VS Code: `saropaLints.scan.maxIssues` controls the issue cap for whole-project and on-save scans (default unlimited).
- VS Code: when free memory is low, the multi-GB type-aware scan is skipped or paused with a notification offering one-click fixes (use the fast scan, turn off type resolution, resume, or open settings) instead of starting on a struggling computer.

### Changed

- The scan CLI and VS Code scan daemon no longer silently drop non-error issues beyond 500, which previously made reports and count-based CI thresholds incomplete; the analyzer plugin keeps its 500-issue Problems-tab default.
- VS Code scan processes now run at reduced CPU priority (`saropaLints.scan.lowPriority`, on by default) so typing stays smooth during a scan; no action required.
- A fast whole-project scan no longer overwrites findings from files that were already scanned with type resolution; no action required.

### Internal

- New locale strings (`scanResources.*`) ship in English in every locale until the translation pipeline is run; they are allowlisted in `english_allowed.json`.

---

## [17.6.0]

The extension's rating prompts, welcome panel, scan progress message and several other strings now read natively in all 24 supported languages instead of falling back to English. Eleven false positives are also fixed. [log](https://github.com/saropa/saropa_lints/blob/v17.6.0/CHANGELOG.md)

### Fixed

- `avoid_context_after_navigation` no longer reports the awaited navigator call itself (e.g. `await Navigator.maybePop(context)`). The `context` argument is evaluated before the await, so only uses after the await are checked.
- `avoid_gesture_only_interactions` no longer flags a GestureDetector when an ancestor `Semantics` supplies `onTap`/`onLongPress`, or when it is an opaque `SizedBox`/`ColoredBox` hit region with nothing to focus.
- `avoid_variable_shadowing` no longer reports Dart 3 wildcard `_` locals, loop variables or parameters.
- `require_ios_accessibility_large_text` no longer flags a literal `TextStyle(fontSize:)` consumed by `Text`/`RichText` (ambient `TextScaler`) or a `TextPainter` with a `textScaler:`. It still reports bare styles and consumers that pin scaling off (`TextScaler.noScaling`, `textScaleFactor: 1`).
- `invalid_field_name` no longer reports contextual keywords (e.g. `when`) used as record field names; only reserved words are flagged.
- `prefer_static_method` no longer flags a state-free method that other code in the library calls through an instance receiver (`widget.button.buildTile()`). Making it static would break those callers.
- `avoid_motion_without_reduce` no longer reports animated widgets whose duration (or enclosing class) is gated through a project reduce-motion helper such as `isMotionReduced`, or that use `Duration.zero`.
- `avoid_public_members_in_states` no longer flags `@override` members that implement a user-defined mixin or base-class contract.
- `prefer_stream_distinct` no longer fires when the `listen` callback ignores its event parameter (`(_) => ...` or an unused parameter).
- `require_permission_manifest_android` now reads the project's AndroidManifest.xml. It no longer reports `permission_handler` imports when the manifest already declares permissions or when there is no manifest to check.
- `avoid_implicitly_nullable_extension_types` now reports only extension types with a nullable or bare-type-parameter representation. Non-nullable representations (`int`, `List<T>`) are no longer flagged.
- `avoid_public_members_in_states` now exempts an `@override` only when it comes from a mixin or an SDK/Flutter type, and again reports overrides of app-defined State base classes. It also now checks transitive State subclasses.
- `avoid_gesture_only_interactions` ignores `Semantics(onTap: null)` and no longer accepts a distant page-level `Semantics`; only a near ancestor counts.
- `avoid_motion_without_reduce` matches reduce-motion helper names on identifier boundaries, so `unreducedMotionDuration` no longer counts as a guard.
- `require_ios_accessibility_large_text` treats `TextScaler.linear(1)` and `textScaleFactor: 1.0` as pinned scaling.
- `avoid_implicitly_nullable_extension_types` also flags `dynamic` and `Null` representation types.
- `require_permission_manifest_android` also reads debug/profile manifests, ignores commented-out `<uses-permission>` entries, and looks up the manifest only once a `permission_handler` import is seen. Flutter's default debug manifest declares INTERNET, so the reminder is now silent for default projects.
- `prefer_static_method` now also treats cascade calls, tear-offs and `this.m()` as instance use, with one pass per file instead of one per method.

### Changed

- Added hand-written translations for the rate-and-feedback prompts, "What's New" panel, workspace scan progress and roughly 100 smaller strings across the translated locales. They have not had native-speaker review.

### Internal

- Scan tests (`git_changed_files_test`, `scan_analyzer_exclude_test`) now compare separator-neutral paths on Windows; the anti-pattern `.contains()` guard is satisfied by the iOS large-text rule.
- Fixed `ScanRunner.runResolved` silently skipping explicitly requested files that the project's `analyzer: exclude:` removes, which broke the resolved-superset-of-syntactic invariant. Also normalized the path in `_createContextUnit` so mixed-separator targets no longer throw "Path must be normalized" on Windows, and made the git-changed-files and analyzer-exclude tests separator-neutral.
- i18n dictionaries: technical labels (pubspec/plugin-route version sources, RSS/heap readout, `WASM`, `GitHub Actions CI`, `N/A`, `UPDATE`) are now passthroughs in every locale, and `dev` is a cognate in the nine locales that kept it. Hand translations live in `extension/scripts/i18n/manual_translations.py` and `manual_translations_gaps.py`.

---

## [17.5.0]

Polish translations in the extension are refreshed, and the release tooling no longer stalls on a stale version number. [log](https://github.com/saropa/saropa_lints/blob/v17.5.0/CHANGELOG.md)

### Changed

- Refreshed the Polish extension translations. No action required.

### Internal

- Publish script: a stale `pubspec.yaml` version found at the pre-commit check is now auto-corrected (and re-staged along with `extension/package.json`) instead of dead-ending at the Retry/Abort menu.

---

## [17.4.9]

Scan notifications are quieter: one progress notification replaces the stack of "N issues found" toasts while the workspace scan runs. The What's New panel no longer shows the red engine-change warning to fresh installs or unconfirmed upgrades, and it gains a "Rate Us" card, a rating nudge after your 5th successful scan, and Help Hub entries for the Marketplace and Open VSX review pages. [log](https://github.com/saropa/saropa_lints/blob/v17.4.9/CHANGELOG.md)

### Changed

- The "N issues found" warning no longer stacks a new toast for every auto-triggered analysis while the workspace scan is still running; a single progress notification shows the scan percentage and the running issue count, and the final toast appears once when the scan completes.
- The What's New panel now shows the red "Default Diagnostic Engine Changed" card and its warning subtitle only when upgrading from a version before v16; fresh installs and upgrades the extension cannot confirm no longer see it. No action required.

### Added

- Added a "Rate Us" call-to-action on the What's New welcome panel with links to the VS Code Marketplace, Open VSX review pages, and GitHub Issues — a gradient-accented card with animated stars, centered between the discovery grid and the show-next-time checkbox.
- Added a scan-gated rating nudge toast that appears after the user's 5th successful scan, linking to both extension stores and the GitHub issues page. Respects the proactive-nudge opt-out and defers gracefully on "Not now".
- Added "Rate on VS Code Marketplace" and "Rate on Open VSX" entries to the Help Hub quick pick, so users can reach the review pages at any time.
- Added `saropaLints.rateOnMarketplace` and `saropaLints.rateOnOpenVsx` commands (Command Palette + Command Catalog).

---

## [17.3.0]

Rules & Tiers results and the "Explain rule" panel can now turn a rule off without a trip to the Overrides tab, and several Health Panel dashboards render correctly again after a CSP directive was silently dropping their inline style updates. The scan CLI is more reliable on large or unusual project layouts: it no longer runs out of memory with `--resolve`, and `--exclude-globs` no longer crashes when the excluded path contains a directory the scan can't read. [log](https://github.com/saropa/saropa_lints/blob/v17.3.0/CHANGELOG.md)

### Added

- Added a disable/enable action directly on Rules & Tiers rule-search results and on the standalone "Explain rule" panel, so a rule can be turned off without switching to the Overrides tab.
- Added `--strict-files` flag to the scan CLI: exits 2 when ANY `--files` entry is skipped (outside the analysis root), not just when all are skipped. Use in CI pipelines that must guarantee every named file was analyzed.

### Changed

- Removed the duplicate rule `prefer_named_boolean_parameters`; `avoid_positional_boolean_parameters_with_fix` reports the same positional `bool` parameters and adds a quick fix. Existing `analysis_options.yaml` entries naming the old rule (disable or severity override) still apply to the surviving rule; a `// ignore: prefer_named_boolean_parameters` comment no longer suppresses it, so rename it to `avoid_positional_boolean_parameters_with_fix`.

### Fixed

- `require_data_encryption` no longer reports writes to network or stream sinks (`HttpResponse`, `IOSink`, `Socket`, `WebSocket`); sending a response body is transport, not storage. `File.writeAsString` and similar persistence calls still report.
- Fixed a webview CSP directive that combined a nonce with `unsafe-inline` for `style-src`, which per spec silently dropped inline style writes across several dashboards (the Rules & Tiers coverage gauge, chart bars, and score pills now render correctly again). No action required.
- The removed `saropaLints.scanOnSave.enabled` setting is now detected and flagged (output channel plus a one-time notification) instead of silently doing nothing; remove it from `settings.json`.
- Fixed the "Explain rule" panel showing "Run analysis to see it in context" for a disabled rule that has never fired; it now explains the rule is disabled and suggests re-enabling it. No action required.
- Fixed the "Explain rule" fallback panel showing an unbounded pack-label list; it now caps at 3 labels with a "(+N more)" indicator. No action required.
- Fixed `scan --resolve` exceeding its memory limit after a single file on most projects by sharing one analysis context across all files instead of creating one per file ([#402](https://github.com/saropa/saropa_lints/issues/402)). No action required.
- Fixed `scan --exclude-globs` crashing with a permission error when the excluded path contained an unreadable directory, because the scan listed every subdirectory before applying exclusions ([#408](https://github.com/saropa/saropa_lints/issues/408)). No action required.
- Fixed `scan --files --resolve` silently exiting 0 when requested files fell outside the analysis context root, letting CI pass having scanned nothing. The scan now exits non-zero and prints which files were skipped. No action required.
- Fixed `avoid_case_sensitive_path_comparison` false positive on route handler methods where `path` is a `String` parameter alongside an `HttpRequest` parameter. The rule now recognizes the route-handler signature and exempts comparisons in that context. No action required.
- Added regression coverage for `avoid_case_sensitive_path_comparison` confirming that the upward directory-walk root check (`parent.path == dir.path` with `dir = parent;` afterwards, on a real `dart:io` `Directory`) and `!=` route comparisons against a local from `req.uri.path` are not flagged, while `File(a).path == File(b).path` still lints. No action required.
- Fixed `require_isolate_for_heavy` false positive on `jsonEncode`/`jsonDecode` of a map or list literal (e.g. a small error-response body in a server handler); literal payloads have fixed small size so no isolate is needed. Non-literal arguments still lint.
- Fixed `avoid_unnecessary_nullable_fields` false positive when a constructor initializer can yield null (e.g. `cond ? Value() : null`, or a `??` chain ending in a nullable expression); only literal `null` was recognized before. No action required.
- Fixed `prefer_cached_getter` false positive on repeated reads of plain `dart:` SDK accessors such as `HttpRequest.method`; lazy `Iterable` and `Stream` getters and user-declared getters are still flagged.
- Fixed `prefer_utc_for_storage` false positive on a `final` field that is UTC by construction (`Entry(DateTime now) : at = now.toUtc();` or `final at = x.toUtc();`); fields set through `this.at` or from non-UTC values still lint.
- Fixed `avoid_platform_specific_imports` false positive on files reachable only through the `dart.library.io` branch of a conditional import or export; the whole io-only subtree is now skipped, while files that the stub/web path can also reach are still reported.

### Internal

- Added "Dart SDK", "Flutter SDK", "Flutter daemons", and "Vibrancy" to `DO_NOT_TRANSLATE` in `extension/scripts/i18n/dictionaries.py`; these proper nouns no longer show as missing translations in every locale.
- Added `extension/scripts/i18n/bad_translations.py`: detects mechanically defective machine translations (leaked shield sentinels and `⁇`, prompt echo, wrong script, hallucinated length, placeholder drift, blocklisted domain-term renderings from `bad_translations_blocklist.json`). `generate_locales.py` now auto-prunes flagged cache entries on every run so they are re-translated; `--check` exits 1 on any flagged shipped string and `--purge` clears the cache on demand.
- Fixed `mt_fallback._SHIELD_RESIDUE_RE` missing bare `ZZ`, `_PH<n>_`, and `ПХ<n>` shield leaks, so such translations were accepted and cached at write time; they are now rejected before caching, matching `bad_translations.py`. `bad_translations.py --purge` now backs the cache up to `mt_strings.json.bak` first.
- Fixed `generate_locales.py` aborting a locale (and discarding its translations) when Qwen failed on a few pruned short labels: the cache is now saved before the english-regression guard, and a string that falls back to English keeps its existing shipped translation instead of regressing.
- Fixed `generate_locales.py` appearing to hang for minutes after a locale's "engines ->" line: the mapping pass re-ran every string the engines had just failed on through Qwen and Google (28 s timeout plus backoff each). The pass is now cache-only (`HybridTranslator(cache_only=True)`), so failed strings fall straight back to English or their shipped translation.
- Qwen translation now runs 2 requests at once (`SAROPA_QWEN_PARALLEL`, 1-4, default 2; sets the daemon's `OLLAMA_NUM_PARALLEL` to match) because a single stream left the GPU 10-30% busy. Each result is keyed to its own source string; progress, checkpoints and Ctrl-C stay on the main thread. Set `SAROPA_QWEN_PARALLEL=1` for the old serial behavior. Speedup unmeasured.
- `generate_locales.py` now prints a VRAM report before a Qwen run (`vram_report.py`): used/free MB, the apps holding GPU memory (Windows counter, allocation not residency), and a per-app tip for turning off hardware acceleration in VS Code, Firefox, Chrome, Edge, Discord, Slack and Teams. Report only; best-effort and silent without `nvidia-smi`.
- Added `extension/scripts/i18n/coverage_report.py`: prints a per-locale translation coverage table and rewrites the marked "Extension language coverage" block in `README.md`. `generate_locales.py` refreshes the block on every coverage write, from the same `locale_coverage.json` the language picker uses.
- Added `extension/scripts/i18n/semantic_check.py`: ranks shipped translations by cross-lingual embedding similarity (local Ollama, default `bge-m3`) to surface meaning drift the mechanical detector cannot see. Report only, no translation performed; precision unmeasured.
- CI now runs `extension/scripts/check_l10n_keys.py --check-params`, failing when a literal `l10n()` key is missing from `en.json` or its call-site params do not match the catalog placeholders. Five checker false positives (variable, spread and webview-substituted params) are marked `l10n:passthrough`.
- Added a GitHub Actions workflow that runs saropa_lints on pull requests.
- Added a master switch card (`saropaLints.enabled`) to the Health Panel's Diagnostic Engines section; the Scan on Save card dims when it is off, since that is the only engine the setting gates. A folder-level override of the setting is flagged on the card and in a warning after a click.
- Eliminated redundant `contextFor` lookups in the resolved scan path: the analysis context is resolved once per file and passed through, removing 1-2 extra hash-map probes per file in `_scanFilesResolved` and `runResolvedWithCollection`.
- The publish script now writes the known-issues review list to the ignored `reports/` folder and prints the queued packages, instead of committing a file to `bugs/`.
- The Qwen translation prompt now includes a short glossary of domain terms (audit, suppress, gate, transitive, hotspot, tier, …) when a string contains them, fixing word-sense mistranslations found in a side-by-side review.

---

## [17.2.0]

Adds a rule that suggests the narrower width and height lookups on `MediaQuery`, so widgets rebuild only when the dimension they read changes. [log](https://github.com/saropa/saropa_lints/blob/v17.2.0/CHANGELOG.md)

### Added

- **`prefer_media_query_width_height_of`:** new rule (comprehensive tier, INFO, quick fix) that flags `MediaQuery.sizeOf(context).width` and `.height`, the `maybeSizeOf` form, and `MediaQuery.of(context).size.width`, because the whole screen size is watched when only one dimension is read; it stays silent on Flutter older than 3.35, where `widthOf` and `heightOf` do not exist, so no action is required there ([#406](https://github.com/saropa/saropa_lints/issues/406)).

### Changed

- **Bug report form is shorter ([#404](https://github.com/saropa/saropa_lints/issues/404)):** only the rule name, a summary, a code sample that shows the problem, expected versus actual behavior, and the saropa_lints version are required. Severity, frequency, the rule's source file and the attribution check are optional. The form says that reports without a code sample, or without replies to follow-up questions, may be closed.
- **Rule pack lists regenerated:** the VS Code extension's pack and tier lists now include every rule. `avoid_reexports` is no longer in the "Migrate from awesome_lints" and "Migrate from DCM" packs, because neither tool has a matching rule; it stays in the architecture pack.

### Fixed

- **`scan --exclude-globs` and `--include-globs` match relative to the scanned folder ([#405](https://github.com/saropa/saropa_lints/issues/405)):** a pattern such as `packages/**` now matches `packages/mypackage/lib/src/x.dart` under the folder being scanned. Before, only `**/packages/**` worked. Every pattern that worked before still works.
- **`scan` honors `analyzer: exclude:` ([#403](https://github.com/saropa/saropa_lints/issues/403)):** `dart run saropa_lints scan` now skips the paths listed under `analyzer: exclude:`. It uses the nearest `analysis_options.yaml` at or above the scanned folder, with patterns relative to that file's folder, which matches how `dart analyze` picks the options file. `--find-stale-ignores` and `--fix-stale-ignores` skip the same files. Explicit `--files` lists are not filtered, same as `--exclude-globs`. No action required.

## [17.1.0]

The 17 line is out of beta: this is the first stable release since the 17.0.1 betas, and it includes all of their changes. It also removes false positives from `avoid_hardcoded_colors` where colors define the theme rather than bypass it. [log](https://github.com/saropa/saropa_lints/blob/v17.1.0/CHANGELOG.md)

### Upgrading from 16.x

- **Requirements:** the 17 line needs Dart 3.11 or newer and analyzer 13 or 14. Projects held on analyzer 12 stay on `^16.7.0`.
- **Rule renamed:** `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended`. Update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name. The extension's compatibility card offers to rewrite them for you.

### Fixed

- **New-project setup picks a current version (extension):** enabling Saropa Lints in a project that does not depend on it yet now writes the newest `saropa_lints` its Dart SDK supports (the same choice the compatibility card makes) instead of the frozen `^16.2.1`. If the Dart version or the pub.dev list cannot be read, it writes `^16.7.0`, and it does the same when the pub.dev lookup takes longer than 8 seconds. `^16.7.0` needs Dart 3.9 or newer.
- **`avoid_hardcoded_colors`:** no longer flags colors written inside `ColorScheme`, `TextTheme`, `*ThemeData` constructors or `ThemeExtension` classes, or a private constant used only there (such as a seed passed to `ColorScheme.fromSeed`), so theme definitions stay clean. No action required.
- **`avoid_hardcoded_colors`:** no longer flags fully transparent colors (`Colors.transparent`, alpha 0), which look the same in every theme. No action required.

### Changed

- **Package Vibrancy known issues:** the pricing notes for 11 hosted-service packages (AppsFlyer, CometChat, Datadog, UXCam, Mapbox, RevenueCat, Scanbot, Stream, Superwall, Syncfusion, ZEGOCLOUD) were re-checked against vendor pricing pages and reworded to plain facts. AppsFlyer and CometChat now show as freemium, as both offer a free tier. The AppsFlyer migration notes no longer recommend Firebase Dynamic Links, which Google shut down in 2025. A new optional `reasonVerified` field in the known-issues schema records the date a person last checked an entry's reason text; those 11 entries carry it. No action required.
- **Package Vibrancy known issues:** the warnings for flutter_sticky_header, google_api_availability and blinkid_flutter were re-checked and reworded to match their changelogs and repositories (blinkid_flutter's wrapper is open source and only the Microblink SDK needs a license key), with statuses unchanged. No action required.

### Internal

- **Known-issues review queue is now a tracked dated file:** the publish-time report is written to `bugs/YYYY-MM-DD_known_issues_review_queue.md` on every run (even with zero entries) instead of the gitignored `plans/known_issues_review.md`; older dated files are kept.
- **CI tests the newest analyzer:** the analyzer matrix now pins analyzer 14.7.0 (with `analysis_server_plugin` 0.3.26) for its Dart 3.13 row instead of 14.6.0, so the range users actually get on Dart 3.13 is the one tested.
- **Known-issues review report skips recently verified paid-package warnings:** the publish-time review no longer re-lists business-model (paid/commercial) entries whose human-set `reasonVerified` date is within the last 183 days, so a warning a person just checked is not flagged again on every release. Tooling-refreshed `as_of` dates do not count.
- **Known-issues review report skips entries verified since the latest release:** any entry (every tier) whose human-set `reasonVerified` date is on or after the package's latest pub.dev release date is no longer re-listed; a newer release brings it back. The publish step and generator write no review file when nothing needs review.
- **CI never changes dependency versions:** jobs now run on the Dart SDK the lockfile requires, fail if installing dependencies would change the lockfile, and the formatting bot can only commit source and test files, so it can no longer push a downgraded analyzer to a pull request.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.

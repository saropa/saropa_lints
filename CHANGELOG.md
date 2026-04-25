<!-- markdownlint-disable-file MD024 MD033 -->
# Changelog

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTEANCE NOTES -- IMPORTANT --

    All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

    Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

    Each release (and [Unreleased]) opens with a short plain-language **overview** for humans — user-facing only, casual wording, 2–4 sentences max. Summarize what changed from the user's point of view; do NOT restate implementation details from the `### Added/Changed/Fixed` sections below. Hard bans in the overview: line numbers, file paths, regex snippets, internal flag names (`multiLine: true`, `requiredPatterns`, etc.), specific counts/percentages from particular projects ("22,695 issues on project X", "96.8% of the backlog"), AST/visitor terminology. If a reader would have to open the code to understand a phrase, it belongs in the detailed section — not the overview. End the overview with:
    [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)
    substituting X.Y.Z.

    **Bullet density (HARD RULE — applies to every entry under `### Added` / `### Changed` / `### Fixed` / `### Removed`, including `### Added (Extension)` / `### Fixed (Extension)` / `### Changed (Extension)` and similar)** — One sentence per bullet. That sentence answers, in order: *what changed* → *why the user cares* → *what the user must do* (say "No action required" explicitly when true). A second sentence is allowed ONLY when a concrete user action (migration step, config line to remove) cannot fit in the first. Three-sentence bullets are forbidden — split into multiple bullets, or move the detail to the commit message, PR description, bug report, or inline code comment. When a bullet genuinely needs more context, LINK OUT to those places; do not inline the explanation. Concision edits may touch historical sections on purpose.

    Hard bans inside bullets (send any of these to the commit message / PR / code comments instead):
    - **PR archaeology** — narrative of prior failed attempts, rename history, "after X didn't hold…". The changelog describes the landed state.
    - **File-by-file inventories** — `Removed from config_rules.dart, saropa_lints.dart, tiers.dart, …`. That's the git diff.
    - **Test counts** — `8,585 Dart tests pass` / `817 passing, 1 failing (unrelated)`. That's CI output.
    - **Code-internal names** — AST visitor classes, regex flags (`multiLine: true`), function signatures (`flushReport(root, options?)`), field names, type names, private identifiers. If a reader would need the source to understand the phrase, it does not belong here.
    - **Bug-report / fixture / test file paths** — those belong in the commit message footer.
    - **How-the-decision-was-made paragraphs** — one-clause reasoning is fine; a paragraph is not.

    **Maintenance** `<details>` bullets: keep them short and free of the same bans (no test counts, no file inventories); the strict what → why → must-do template is optional there when the change is infra-only.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

    **CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

    **Score** — [pub.dev/packages/saropa_lints/score](https://pub.dev/packages/saropa_lints/score)

    **Maintenance entries** — Anything with **no end-user impact** (publish/CI tooling, internal refactors, test harness tweaks, plan-folder housekeeping, developer-only scripts) goes INSIDE a collapsed `<details><summary>Maintenance</summary>...</details>` block at the *bottom* of its version section — NOT in `### Added` / `### Changed` / `### Fixed`, which are reserved for user-visible changes that ship in the `.dart` / `.vsix` artifacts. Rule of thumb: if a pub.dev / Marketplace user running the published package would notice the difference, it belongs in a top-level section; otherwise it belongs in the Maintenance expander.

-->

---

## [12.5.0] - Unreleased

### Fixed

- `require_intl_plural_rules` no longer treats code between string literals (for example `(hour == …)` next to AM/PM labels) as if it were text inside a quoted string, so 12-hour clock helpers are not mistaken for manual noun pluralization. No action required.

### Added

- Added `require_android_manifest_entries` to flag permission-gated Android API usage when the app manifest is missing required `android.permission.*` entries, so runtime-denied features are caught during analysis instead of on devices. Add the missing `<uses-permission>` rows in `android/app/src/main/AndroidManifest.xml` where reported.
- Added `require_ios_info_plist_entries` to report permission-gated iOS API usage when required `NS*UsageDescription` keys are absent from `Info.plist`, so App Store rejection and runtime permission crashes are caught during analysis. Add the missing key(s) to `ios/Runner/Info.plist` where reported.
- Added `require_desktop_window_setup` to report desktop window-manager API usage when desktop runner setup files are missing, so desktop-only configuration gaps are surfaced before runtime. Ensure the relevant `windows/`, `linux/`, or `macos/` runner files are present when using desktop window APIs.
- Added `avoid_audio_in_background_without_config` to flag background audio usage when iOS `UIBackgroundModes` audio or Android manifest foreground-service / audio declarations are missing, so store review and runtime failures are caught during analysis.
- Added `avoid_geolocator_background_without_config` to flag `Geolocator.getPositionStream` when iOS background location or Android background location permission is not reflected in platform config files.
- Added `require_notification_icon_kept` to warn when FCM or local notifications are used but ProGuard/R8 rules do not appear to keep notification icon resources.
- Added `require_firestore_security_rules` to report `FirebaseFirestore` usage when no `firestore.rules` file exists at the project root.
- Added `require_env_file_gitignore` to report `.env` / `.env.*` files at the project root that are not covered by `.gitignore` patterns.

<details>
<summary>Maintenance</summary>

- Updated the open bug note for `avoid_builder_index_out_of_bounds` (itemCount and guard false positives) so it matches current rule behavior and documented detection limits instead of stale assumptions. No action required for package users.

</details>

---

## [12.4.4]

`require_animation_controller_dispose` stops nagging when you really did tear down an `AnimationController` using a disposeSafe-style helper next to `dispose`, and the help text you read in the editor now matches what the linter reports. Rule counts and Marketplace-facing copy line up across the package and extension, publish and audit flows are a little sturdier, and you do not need new analysis_options toggles to pick any of this up. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.4/CHANGELOG.md)

### Fixed

- `require_animation_controller_dispose` now treats `disposeSafe(…)` like `dispose(…)` in your `State.dispose()` so custom safe-dispose extensions are not reported, and the rule message was refreshed so on-screen wording stays aligned with that behavior. No action required; remove suppression comments you added only for this false positive.

<details>
<summary>Maintenance</summary>

- Deferred SDK plan notes consolidated under `plan/deferred/`; publish audit spelling prompt now retry/ignore; publish menu shows logo first; Windows temp-dir teardown hardened in one integration test. No action required for package users.
- Rounded rule-count messaging is aligned to **2100+** / **~2100** everywhere (pub.dev description, extension listings, walkthrough, tier headers, and guides) so numbers match the current rule set. No action required.
- Extension publish still tries Open VSX after a failed VS Code Marketplace upload, so the Open VSX listing can move forward when Marketplace auth fails but your Open VSX token is fine. No action required for package users.
- Publish work-report “unsolved bug” count excludes the bug-filing guide at repo root so only real open bug files inflate that bar. No action required for package users.
- Clarified internal helper documentation for `isFieldCleanedUp` so extension method names are not implied by a generic `dispose` check. No action required for package users.
- Dropped placeholder-only example rule fixtures and matching fixture-existence test entries so the suite does not imply behavioral coverage for unfilled TODO stubs. No action required for package users.
- Follow-up removed additional stylistic and related stub fixtures, added migration and SDK-migration batch fixtures with shared mocks, and expanded unit tests for compile-time syntax and image filter tier metadata. No action required for package users.
- Internal doc comment reference style, plan notes, extension copy, script helpers, and archive indexing were updated. No action required for package users.

</details>

---

## [12.4.2]

`saropa_depend_on_referenced_packages` is removed because the Dart SDK already ships the same check via `lints` / `flutter_lints`, and saropa’s copy kept false-positiveing on legitimate imports. You still get the behavior from the SDK; nothing breaks if you leave old config in place. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.2/CHANGELOG.md)

### Removed

- Removed `saropa_depend_on_referenced_packages` so duplicate / noisy import checks go away while the SDK lint keeps the same coverage for you. No action required; delete any `saropa_depend_on_referenced_packages` entry from `analysis_options.yaml` when you tidy config.

<details><summary>Maintenance</summary>

- Publish script: extension-only and publish-existing-.vsix modes now run the same Marketplace + Open VSX verification as the full flow so a “successful” store publish cannot slip through undetected. No action required for package or rule users.

</details>

---

## [12.4.1]

Analysis reports and the Run Analysis popup now show which saropa_lints build ran, and the popup can copy or open the latest consolidated report without digging through folders. Theme- and platform-driven color branches no longer trip `avoid_color_only_meaning`, and `prefer_final_locals` stops suggesting `final` where the variable is reassigned inside nested blocks or closures. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.1/CHANGELOG.md)

### Added

- Run Analysis popup adds Copy Report and Open Report (plus palette commands) so you can share or open the latest `*_saropa_lint_report.log` in one step instead of browsing dated folders under `reports/`. No action required.

### Changed

- Extension Run Analysis stamps extension reports and the issue popup with the resolved saropa_lints version and source (hosted / path / git) when `pubspec.lock` allows, so you can confirm which build ran without opening files. No action required.

### Fixed

- `prefer_final_locals` no longer false-positives when a local is reassigned inside nested blocks, control flow, or closures, so the quick fix matches real code and you can rely on the rule again. No action required; details in [bugs/prefer_final_locals_false_positive_nested_assignments.md](bugs/prefer_final_locals_false_positive_nested_assignments.md).
- `avoid_color_only_meaning` skips ordinary theme, platform, and directionality-driven color branches so theming code stays clean without ignores. No action required; details in [bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md](bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md).
- Analyzer-plugin text reports now show a real `Version:` from your project root instead of `unknown`, so each report identifies the plugin build that produced it. No action required.

---

## [12.4.0]

Three animation-focused rules catch inert `Animation.value` reads in `build`, mis-matched ticker mixins, and press-and-bounce `forward()` without `from: 0.0`. Several platform rules and `avoid_platform_specific_imports` quiet down when the project cannot hit the failure mode (for example mobile-only apps without `web/`). Pubspec dependency discovery works again, saropa’s import rule is renamed to `saropa_depend_on_referenced_packages` so it no longer doubles the SDK lint, large reports open with triage-oriented sections, and Run Analysis popups show real issue counts. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.0/CHANGELOG.md)

### Added

- Added `avoid_inert_animation_value_in_build` (recommended, error) so you catch opacity and other reads that never refresh because `build` does not rerun on ticks, without noise on listening builders. No action required; see [bugs/infra_propose_avoid_inert_animation_value_in_build.md](bugs/infra_propose_avoid_inert_animation_value_in_build.md).
- Added `prefer_single_ticker_provider_state_mixin` (recommended, info) so single-controller states use the lighter mixin and intent is obvious. No action required; see [bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md](bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md).
- Added `prefer_animation_controller_forward_from_zero` (recommended, warning) with a quick fix so press-and-bounce gestures always restart from zero and feel consistent on rapid taps. No action required.

### Changed

- Consolidated analysis logs now lead with concentration, delta-since-last-run, and triage hints on large backlogs, and the top-rules table adds share, source, and fixable columns so you can prioritize work. No action required; see [bugs/infra_analysis_report_insufficient_for_large_backlogs.md](bugs/infra_analysis_report_insufficient_for_large_backlogs.md).

### Fixed

- Several “wrong platform” rules now bail when the repo cannot build the platform they warn about, so mobile-only and similar setups stop getting irrelevant noise. No action required; see [bugs/platform_gate_missing_from_sibling_rules.md](bugs/platform_gate_missing_from_sibling_rules.md).
- `avoid_platform_specific_imports` stays silent when the Flutter app has no `web/` tree, since `dart:io` web breakage is not applicable there. No action required; see [bugs/avoid_platform_specific_imports_false_positive_non_web_project.md](bugs/avoid_platform_specific_imports_false_positive_non_web_project.md).
- Pubspec dependency names parse correctly again so `hasDependency`-gated rules and import checks behave; this removes the flood of bogus “not in pubspec” findings. No action required; see [bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md](bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md).
- Renamed saropa’s duplicate lint to `saropa_depend_on_referenced_packages` so counts and ignores align with the SDK’s `depend_on_referenced_packages`. Use `// ignore: saropa_depend_on_referenced_packages` or disable that code in `plugins: saropa_lints` if you only want to silence saropa’s copy; `// ignore: depend_on_referenced_packages` still targets the SDK lint only.
- Analyzer-plugin reports populate the configuration block instead of showing “not captured,” so reports stay self-describing. No action required.
- Extension Run Analysis warning popups show the real issue count from `violations.json` instead of a slice of progress stderr. No action required; see [bugs/infra_run_analysis_popup_dumps_progress_stderr.md](bugs/infra_run_analysis_popup_dumps_progress_stderr.md).

<details>
<summary>Maintenance</summary>

- Internal tweak to `prefer_animation_controller_forward_from_zero` detection so publish CI anti-pattern gates stay satisfied; rule behavior unchanged. No action required for consumers.

</details>

---

## [12.3.4]

New `avoid_drift_insert_missing_conflict_target` flags Drift inserts that omit the right `onConflict` target on tables with a non-primary unique index, matching the class of SQLite `UNIQUE` failures you otherwise hit at runtime. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.4/CHANGELOG.md)

### Added

- Added `avoid_drift_insert_missing_conflict_target` (essential, error) so Drift inserts declare the correct conflict target when a non-PK unique index exists and you avoid silent `SqliteException` failures. No action required; see [bugs/infra_new_rule_drift_insert_missing_conflict_target.md](bugs/infra_new_rule_drift_insert_missing_conflict_target.md).

---

## [12.3.3]

Path-safety rules ignore clearly safe literal-only helpers and common Dart SDK path sources, `avoid_null_assertion` skips typical `RegExpMatch.group(n)!` after a match, and `prefer_debug_print` stops recommending Flutter-only APIs in pure Dart packages. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.3/CHANGELOG.md)

### Fixed

- `avoid_path_traversal` and `require_file_path_sanitization` no longer flag private helpers fed only literals or paths resolved via trusted SDK entry points, so asset helpers and similar code stay clean while real taint stays covered. No action required; see [bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md](bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md) and [bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md](bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md).
- `prefer_debug_print` is skipped for non-Flutter packages so you are not told to import Flutter just to silence `print` guidance. No action required; see [bugs/prefer_debug_print_false_positive_pure_dart_package.md](bugs/prefer_debug_print_false_positive_pure_dart_package.md).
- `avoid_null_assertion` allows `RegExpMatch.group(n)!` on matched regex results so you are not pushed into dead null-fallbacks for common parsing loops. No action required; see [bugs/avoid_null_assertion_false_positive_regex_match_group.md](bugs/avoid_null_assertion_false_positive_regex_match_group.md).

---

## [12.3.2]

`saropa_lints` itself passes `dart analyze --fatal-infos` again thanks to dogfood-only disables and small plugin fixes; publish script gains a publish-existing-.vsix mode. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.2/CHANGELOG.md)

### Fixed

- `dart analyze --fatal-infos` is clean on saropa_lints itself via targeted code fixes plus dogfood-only disables in this repo’s `analysis_options.yaml`, so maintainers can ship without thousands of self-applied rule hits while published consumer behavior is unchanged. No action required for package users.

<details>
<summary>Maintenance</summary>

- Publish script adds mode 7 to publish the newest packaged `.vsix` without repackaging after `pubspec`/`package.json` post-publish bumps, avoiding version skew when finishing a partial extension release. No action required for package users.

</details>

---

## [12.3.1]

Hotfix: tier-based `scan` and similar flows no longer crash on the second file when rule packs merge into an unmodifiable tier set. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.1/CHANGELOG.md)

### Fixed

- Rule-pack reload now copies enabled-rule sets before mutating them, so `scan` with `essential`/`recommended` tiers and pack merges no longer throws on the second analyzed file. No action required.

---

## [12.3.0]

Windows vibrancy scans run again, footprint sizes reflect transitive packages, the analyzer plugin logs to `reports/.saropa_lints/plugin.log` and no longer goes silent when the server cwd differs from your project, the vibrancy report toolbar adds rescan / open-project / copy-all-json, and `prefer_listenable_builder` nudges `AnimatedBuilder` uses that should be `ListenableBuilder`. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.0/CHANGELOG.md)

### Added

- Plugin log file at `reports/.saropa_lints/plugin.log` surfaces startup and config-load issues without digging in Dart server logs. No action required.
- `prefer_listenable_builder` (recommended, info) with quick fix for `Listenable` sources that are not `Animation`, gated below Flutter 3.13. No action required; see [plan/054-prefer_listenable_builder_over_animated_builder.md](plan/054-prefer_listenable_builder_over_animated_builder.md).
- `ProjectContext.flutterSdkAtLeast` lets future rules respect declared Flutter lower bounds. No action required.
- Vibrancy report toolbar adds Copy All JSON, Rescan, and Open Another Project for side-by-side scans. No action required.

### Changed

- Vibrancy commands are grouped under the Saropa palette with shorter titles; command IDs unchanged. No action required.
- Stars column becomes Likes + Downloads (per-package signals) with JSON fields updated accordingly. No action required.
- Update column right-aligns with other numeric columns. No action required.

### Fixed

- Extension vibrancy CLI on Windows now resolves `dart.bat` via the shell so pub graph and outdated data load instead of failing quietly. No action required.
- Footprint modes now include sizes for transitives pulled from pub cache so Own / +Unique / +All differ when deps exist. No action required.
- Analyzer plugin registers all rules then honors `diagnostics:` from the real project root, so IDE sessions no longer show zero saropa diagnostics when config was read from the wrong cwd. No action required.
- Import+export on the same file counts once in References, with both line locations preserved in tooltips and exports. No action required.
- Report and Known Issues search trims whitespace and adds a clear control so pasted names match rows. No action required.
- Header gauge fill renders correctly after CSS fix. No action required.
- Violations tree filenames open the editor on click when the file exists. No action required.

---

## [12.2.1]

Publish script now verifies Marketplace and Open VSX separately, so an expired Marketplace token surfaces a concrete ACTION REQUIRED warning and auto-opens the manage page instead of a silent 0-exit. — [log](https://github.com/saropa/saropa_lints/blob/v12.2.1/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- Publish script verifies Marketplace and Open VSX separately with actionable warnings when a store never shows the new version. No action required for package users.

</details>

---

## [12.2.0]

Letter grades replace fractional scores across the vibrancy report, tree, exports, and related UI, and footprint views clarify unique versus shared transitive size. Ten new quick fixes land for common style rules, plus two new Dart rules for symlink checks and JS interop migration. — [log](https://github.com/saropa/saropa_lints/blob/v12.2.0/CHANGELOG.md)

### Added

- Ten new quick fixes cover record wildcards, `const`/`final` tweaks, `unawaited`, doc `new` cleanup, and related style nags so lightbulb workflows cover more rules. No action required.
- `prefer_type_sync_over_is_link_sync` (recommended, warning) steers you off Windows-broken `isLinkSync` toward `typeSync` link detection. No action required.
- `avoid_removed_js_number_to_dart` (recommended, warning) flags removed `JSNumber.toDart` and points to typed `toDartDouble` / `toDartInt`. No action required.
- Vibrancy report adds footprint toggles, true-footprint detail, re-export-aware single-use logic, optional startup-scan skip with settings, wired cache TTL, and clear-cache resets the skip fingerprint. No action required.

### Changed

- Vibrancy surfaces grades (A–F) instead of `n/10` in reports, cards, gauge, tooltips, CodeLens, diagnostics, exports (JSON still carries numeric score), and logger output for consistent scanning. No action required.

### Fixed

- Dense report headers stay on one line with nowrap layout, and the “(new)” age suffix under one month is dropped as misleading. No action required.

---

## [12.1.0]

The vibrancy report adds a radial gauge, letter-grade badges, expandable per-package detail, keyboard navigation, and a Deps column that highlights shared transitives. — [log](https://github.com/saropa/saropa_lints/blob/v12.1.0/CHANGELOG.md)

### Added

- Saropa Package Vibrancy report shows version, gauge, A–F badges, expandable rows with full package context, keyboard navigation, and a Deps column with shared-transitive emphasis so dependency risk is obvious at a glance. No action required.

### Fixed

- Gauge thresholds match category cutoffs; sorting and filtering keep detail rows attached to their parent so expanded cards never orphan. No action required.

---

## [12.0.3]

Package upgrade plans skip constraints you cannot bump via semver, show real resolver errors, and keep iterating after a single package fails. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.3/CHANGELOG.md)

### Fixed

- Upgrade planner omits git/path/SDK entries that cannot be semver-bumped, prints concrete pub errors instead of generic “pub get failed,” and advances to the next package after each rollback. No action required.

---

## [12.0.2]

Size Distribution splits unique versus shared transitives and adds “Exclude shared” so apparent package weight reflects deps you do not already carry. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.2/CHANGELOG.md)

### Added

- Size Distribution chart separates unique and shared transitive weight with an optional hide-shared toggle so bar, donut, and table percentages reflect removable cost. No action required.

---

## [12.0.1]

Overview shows a Set Up Project banner and activation toast when `saropa_lints` is missing from `pubspec.yaml`, so onboarding is one click. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.1/CHANGELOG.md)

### Changed

- Extension surfaces setup banner plus activation toast for Dart workspaces without saropa_lints so install/configure is obvious. No action required.

---

## [12.0.0]

Analyzer 11 compatibility is restored so saropa_lints resolves on current Flutter stable (analyzer 12 required `meta` versions Flutter does not ship yet). Rule and quick-fix counts are unchanged from the prior release line. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.0/CHANGELOG.md)

### Fixed

- Dependency stack pins `analyzer` and `analyzer_plugin` to ranges compatible with Flutter stable’s pinned `meta`, fixing pub resolution failures. No action required; see [bugs/infra_meta_pin_flutter_incompatible.md](bugs/infra_meta_pin_flutter_incompatible.md).
- Small compatibility shim keeps class-body iteration working on analyzer 11. No action required.


---

## [11.1.0]

Ten new quick fixes cover library names, `late` patterns, `unawaited`, `toString`, `@useResult`, and positional booleans so more saropa rules are one-click fixable in the IDE. — [log](https://github.com/saropa/saropa_lints/blob/v11.1.0/CHANGELOG.md)

### Added

- Quick fixes ship for `unnecessary_library_name`, `avoid_late_for_nullable`, `prefer_late_final`, `prefer_abstract_final_static_class`, `avoid_async_call_in_sync_function`, `avoid_default_tostring`, `missing_use_result_annotation`, `avoid_unnecessary_local_late`, `avoid_unnecessary_late_fields`, and `avoid_positional_boolean_parameters`, reducing manual cleanup. No action required.

### Changed

- `RemoveLateKeywordFix` also covers local variable statements used by `avoid_unnecessary_local_late`. No action required.

<details>
<summary>Maintenance</summary>

- Extension npm overrides pin `serialize-javascript` to a patched release for a transitive CVE. No action required for Dart-only consumers.

</details>

---

## [11.0.0]

Extension Overview gains command search, embedded health and risk summaries, richer vibrancy package detail (logos, README shots, adoption bonus), unique-vs-shared dependency insight, File Risk workflow polish, and suppression records exported with violations for auditing. — [log](https://github.com/saropa/saropa_lints/blob/v11.0.0/CHANGELOG.md)

### Added

- Command catalog sidebar, embedded health/risk cards, richer vibrancy detail (topics, likes, docs, README imagery with CSP updates), reverse-dependency scoring bonus, and plugin suppression tracking in `violations.json` so ignored diagnostics are measurable. No action required.

### Changed

- Vibrancy charts and trees highlight unique vs shared transitives; File Risk moves up with JSON export, click-to-open, diagnostics-aware hiding, persistent disable actions, cleaner labels, and richer pubspec hovers with outbound links. No action required.

### Fixed

- Violations tree survives transient `violations.json` read gaps; pubspec diagnostics dedupe on startup; stale-override detection respects active SDK-pin overrides. No action required.

<details>
<summary>Maintenance</summary>

- Example fixture packages consolidated from seven layouts to two to reduce repo maintenance. No action required for package users.

</details>

---

## [10.12.2]

Pubspec lines can opt out of specific saropa pubspec checks with inline comments, `prefer_l10n_yaml_config` stops false-positiveing split l10n setups, and vibrancy scan logging is calmer. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.2/CHANGELOG.md)

### Added

- `# saropa_lints:ignore <codes>` on pubspec lines suppresses individual pubspec validation hits without turning rules off globally. No action required.

### Fixed

- `prefer_l10n_yaml_config` ignores the normal `generate: true` + `l10n.yaml` combo. No action required.
- Vibrancy scan logs debounce, append per day, and skip duplicate runs instead of spawning endless log files. No action required.

---

## [10.12.1]

CI publish unblocked by removing a stray `publish_to: "none"` placeholder from the package manifest. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.1/CHANGELOG.md)

### Fixed

- Repository `pubspec.yaml` no longer carries a template `publish_to: "none"` so automated pub publish succeeds. No action required for consumers.

---

## [10.12.0]

Pubspec and adoption tooling see fewer false positives, diagnostics pick up a consistent `[saropa_lints]` prefix, plugin self-fire guards work per-file, Help hub and command catalog UX improve, and dependency sort preserves comments. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.0/CHANGELOG.md)

### Fixed

- `avoid_hardcoded_config`, pubspec ordering, adoption badges, `prefer_publish_to_none`, and prefixed pubspec diagnostics trim false positives on normal Flutter/SDK layouts. No action required.
- Plugin self-source checks run per-file so rules no longer fire on their own fixture literals. No action required.

### Added (Extension)

- Help hub command plus Overview/Violations entry points surface onboarding, catalog, and pub.dev links without hunting the palette. No action required.

### Fixed (Extension)

- Sort Dependencies keeps per-entry comments and trailing section banners instead of deleting them. No action required.

### Changed (Extension)

- Command catalog gains refreshed layout, codicons, recent-command replay, tighter toolbars, and better search ordering for narrow layouts. No action required.

<details>
<summary>Maintenance</summary>

- Shared SDK package name list deduped for annotate/unused/sort paths with missing SDK entries restored. No action required for package users.

</details>

---

## [10.11.0] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 10.11.0.


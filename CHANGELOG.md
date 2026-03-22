# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 8.0.11.

**Package** — [pub.dev / packages / saropa_lints](https://pub.dev/packages/saropa_lints)

**Score** — [pub.dev / packages / saropa_lints / score](https://pub.dev/packages/saropa_lints/score)

**CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

**Releases** — [github.com / saropa / saropa_lints / releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com / items ? itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org / extension / saropa / saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

Each version (and [Unreleased]) has a short commentary line in plain language — what this release is about for humans. Only discuss user-facing features; vary the phrasing.

---

## [10.0.1]

### Changed

- Version bump

---

## [10.0.0]

In this milestone update work centers on the composite analyzer plugin hook (`registerSaropaLintRules`), rule packs end-to-end (analyzer merge, CLI init, VS Code Rule Packs webview, generated registry), extension UX that defaults integration on with clearer commands and TODOs workspace scan as opt-in, and a wave of new lints—compile-time shape alignment, Dart 3.0 removed-API migration rules, and targeted Flutter fixes.

### Fixed

• **Publish / tier integrity** — `scripts/modules/_tier_integrity.py` `get_registered_rule_names` now resolves rule classes when the `extends` clause starts on the line after the class name (valid Dart; previously produced a false **phantom** for `avoid_removed_nosuchmethoderror_default_constructor`). `AvoidRemovedNoSuchMethodErrorDefaultConstructorRule` header documented to stay single-line for consistency with adjacent migration rules. Python regression coverage: `scripts/tests/test_tier_integrity_registered_names.py`.

• **VS Code extension** — **Violations tree:** enable `canSelectMany` on `saropaLints.issues` so Ctrl/Cmd+click multi-select works with **Copy as JSON** (command already preferred the selection array; the UI could not select multiple rows before). Selection resolution moved to `extension/src/copyTreeAsJsonSelection.ts` for unit tests without the VS Code runtime. Tests: `extension/src/test/copyTreeAsJson.test.ts`.

• **VS Code extension** — Code cleanup: batch `context.subscriptions.push` where it was split unnecessarily (`extension.ts`), and refactor vibrancy “Copy as JSON” serialization into small matchers with documented dispatch order (`treeSerializers.ts`). Adds unit tests for `serializeVibrancyNode` (including false-positive guards for partial package/problem/suggestion payloads).

### Changed

• **VS Code extension** — **Default-on UX:** `saropaLints.enabled` defaults **true**; Overview always shows workspace options and sidebar toggles for Dart projects (no empty tree + “off” welcome). Config and Rule Packs views depend on `saropaLints.isDartProject` + sidebar settings, not on `enabled`. **TODOs & Hacks** workspace scan is opt-in via new `saropaLints.todosAndHacks.workspaceScanEnabled` (default **false**) with command **TODOs & Hacks: Enable workspace scan**. Commands renamed for clarity (**Set Up Project** / **Turn Off Lint Integration**). Sidebar section counts still reflect `violations.json` even when integration is off; Vibrancy package count is supplied by the extension host (`getLatestResults().length`) so `sidebarSectionCounts` stays testable. New modules/tests: `suggestionCounts.ts`, `suggestionCounts.test.ts`, `sidebarSectionCounts.test.ts`.

### Added

• **Composite analyzer plugin API** — `registerSaropaLintRules(PluginRegistry)` on `package:saropa_lints/saropa_lints.dart` (used by `lib/main.dart`); skips rules via `SaropaLintRule.isDisabled` (canonical name or `configAliases`). Re-export `loadNativePluginConfig`, `loadOutputConfigFromProjectRoot`, `loadRulePacksConfigFromProjectRoot` for meta-plugins. Guide: `doc/guides/composite_analyzer_plugin.md`. Tests: `test/saropa_plugin_registration_test.dart`. Template note: `example/analysis_options_template.yaml`.

• **VS Code extension** — **Rule Packs** sidebar webview: per-pack row (label, detected in pubspec, enable toggle, rule count, “Rules” opens Quick Pick of rule codes), plus **target platforms** table (android/ios/web/windows/macos/linux) when embedder folders exist. Writes `plugins.saropa_lints.rule_packs.enabled` in `analysis_options.yaml`.

• **Analyzer plugin** — `rule_packs.enabled` under `plugins.saropa_lints` merges rule codes from `lib/src/config/rule_packs.dart` via `mergeRulePacksIntoEnabled` (skips codes in `diagnostics`/`severities` disables). Config load order documented in `config_loader.dart`.

• **Rule packs (Phase 3)** — `pubspec.lock` resolved versions (cached by mtime) gate optional packs via `kRulePackDependencyGates`; example `collection_compat` merges only when `collection` satisfies `>=1.19.0`. `loadRulePacksConfigFromProjectRoot` re-merges packs when the analyzer discovers the project root. Dependency: `pub_semver`.

• **Rule packs (Phase 4 / CLI)** — `dart run saropa_lints:init --list-packs` lists applicable packs from pubspec + lockfile; `--enable-pack <id>` (repeatable) merges into `rule_packs.enabled`. Init / `write_config` preserve existing `rule_packs` when regenerating the plugins section (unless `--reset`).

• **Rule packs (Phase 5 / registry codegen)** — `lib/src/config/rule_pack_codes_generated.dart` is produced from `lib/src/rules/packages/*_rules.dart` by `dart run tool/generate_rule_pack_registry.dart` (also refreshes `extension/src/rulePacks/rulePackDefinitions.ts`). `kRulePackRuleCodes` / `kRulePackPubspecMarkers` in `rule_packs.dart` spread the generated maps and add `collection_compat`. `dart run tool/rule_pack_audit.dart` checks file extraction vs the merged registry (shared composite map for cross-pack rules such as `avoid_isar_import_with_drift`).

• **Lint rules** — **compile-time Dart shape** (ERROR/WARNING, Essential): ten rules aligned with analyzer compile-time diagnostics — `duplicate_constructor`, `conflicting_constructor_and_static_member`, `duplicate_field_name`, `field_initializer_redirecting_constructor`, `invalid_super_formal_parameter_location`, `illegal_concrete_enum_member`, `invalid_extension_argument_count`, `invalid_field_name` (keyword-tokens on record labels when present in AST), `invalid_literal_annotation`, `invalid_non_virtual_annotation`. Implementation: `lib/src/rules/architecture/compile_time_syntax_rules.dart`, record/extension rules in `type_rules.dart`; fixture `example/lib/plan_additional_rules_21_30_fixture.dart`.

• **Lint rules** — **Dart SDK 3.0 removed APIs** (WARNING, Recommended): fifteen migration rules with targeted quick fixes where safe — `avoid_deprecated_list_constructor`, `avoid_removed_proxy_annotation`, `avoid_removed_provisional_annotation`, `avoid_deprecated_expires_getter`, `avoid_removed_cast_error`, `avoid_removed_fall_through_error`, `avoid_removed_abstract_class_instantiation_error`, `avoid_removed_cyclic_initialization_error`, `avoid_removed_nosuchmethoderror_default_constructor`, `avoid_removed_bidirectional_iterator`, `avoid_removed_deferred_library`, `avoid_deprecated_has_next_iterator`, `avoid_removed_max_user_tags_constant`, `avoid_removed_dart_developer_metrics`, `avoid_deprecated_network_interface_list_supported`. See `lib/src/rules/config/dart_sdk_3_removal_rules.dart`.

• **Lint rule** — **avoid_implicit_animation_dispose_cast** (WARNING, Professional, **high** impact): flags `(animation as CurvedAnimation).dispose()` in `ImplicitlyAnimatedWidgetState` subclasses; the framework disposes that animation in `super.dispose()` (Flutter 3.7 / [PR #111849](https://github.com/flutter/flutter/pull/111849)). Quick fix removes the redundant statement. Shared AST helper: `lib/src/implicit_animation_dispose_cast_ast.dart`. Tests: `test/avoid_implicit_animation_dispose_cast_rule_test.dart`.

• **Lint rule** — **prefer_overflow_bar_over_button_bar** (INFO, Recommended): flags `ButtonBar` usage; prefer `OverflowBar` for Material action layouts (Flutter 3.13 guidance, PR #128437).

### Changed

• **VS Code extension** — **Overview & options** sidebar: **Workspace options** embeds the same tree as the standalone Config view; section toggles show counts in the label (e.g. `Package Vibrancy (2)`) with **On**/**Off** in the description; intro links (pub.dev, About, Getting Started) remain visible whenever Saropa is enabled; standalone Config defaults off (`saropaLints.sidebar.showConfig`). Command **Saropa Lints: Open package on pub.dev** (`saropaLints.openPubDevSaropaLints`). Overview **Copy as JSON** recurses through nested children. Embedded config nodes are allowlisted by `kind` (`overviewEmbeddedConfigKinds.ts`); sidebar label formatting lives in `sidebarToggleLabel.ts` for Node tests. Unit tests: `sidebarToggleLabel`, `overviewEmbeddedConfigKinds`, `serializeOverviewNode`.

• **Rule packs** — Maintainer workflow documented in `doc/guides/rule_packs.md` (regenerate, composite map, audit). Added `test/rule_pack_registry_test.dart` (composite `avoid_isar_import_with_drift` on drift + isar; `collection_compat` merge) and expanded pubspec-marker false-positive coverage. README badge rule count aligned with `pubspec.yaml` (2105).

• **VS Code extension** — **TODOs & Hacks** default `includeGlobs` no longer scans `**/*.md` (Markdown READMEs/plans often match tag words in prose). Defaults remain Dart, YAML, TypeScript, and JavaScript; add `**/*.md` in settings if you want docs included. `package.json` defaults and `todosAndHacksDefaults.ts` stay in sync (unit test).

• **Dart SDK** — `example*` and `self_check` `pubspec.yaml` floors aligned to `>=3.9.0` with the main package ([PACKAGE_VIBRANCY.md](https://github.com/saropa/saropa_lints/blob/main/PACKAGE_VIBRANCY.md) legacy-support baseline), replacing stale lower example constraints.

• **Dart SDK 3.0 migration rules** — `avoid_removed_max_user_tags_constant` and `avoid_removed_dart_developer_metrics` use **high** [LintImpact] (removed APIs are compile failures on Dart 3). File header and rule DartDocs in `dart_sdk_3_removal_rules.dart` expanded for reviewers and false-positive contracts.

• **ListView extent hints** — `avoid_listview_without_item_extent`, `prefer_item_extent`, `prefer_prototype_item`, `prefer_itemextent_when_known`, and `require_item_extent_for_large_lists` now treat **`itemExtentBuilder`** (Flutter 3.16+, PR #131393) as a valid alternative to `itemExtent` / `prototypeItem` where applicable. `avoid_listview_without_item_extent` also applies to **`ListView.separated`**.

• **Lint rules** — Flutter migration / widget consistency (INFO; **prefer_super_key** in Comprehensive, **avoid_chip_delete_inkwell_circle_border** in stylistic + `flutterStylisticRules` only — mutually exclusive tier sets):

- **prefer_super_key**: flags `Key? key` with `super(key: key)` on `StatelessWidget` / `StatefulWidget` / `*Widget` subclasses; prefer `super.key` ([Flutter PR #147621](https://github.com/flutter/flutter/pull/147621)). Quick fix rewrites the constructor.
- **avoid_chip_delete_inkwell_circle_border**: flags chip `deleteIcon` subtrees that use `InkWell` with `customBorder: CircleBorder()`, which mismatches the square chip delete region fixed in Flutter 3.22 ([PR #144319](https://github.com/flutter/flutter/pull/144319)). Handles both `InstanceCreationExpression` and unqualified `MethodInvocation` chip calls, and nested `InkWell`/`CircleBorder` parse shapes.

---

## [9.10.0]

This release adds version-gap awareness: see which PRs and issues landed between your pinned version and latest, triage them with a persistent review checklist, and focus your pubspec tooltip on must-know stats with a "View Full Details" link to a full-detail panel.

### Added

• **Version-gap PR/issue viewer** — new "Package Details" webview panel shows merged PRs and closed issues between your current package version and latest, fetched from GitHub on demand. Includes searchable/filterable/sortable table with per-item review controls.

• **Review checklist** — persistent triage state for version-gap items. Mark each PR/issue as reviewed, applicable, or not-applicable. State persists across sessions and auto-prunes when package versions change.

• **Full-detail package panel** — new command `Show Package Details` opens a comprehensive editor-area panel with version info, community metrics, alerts, vulnerabilities, version-gap table, platforms, and suggestions.

• **"View Full Details" links** — compact hover tooltip and sidebar detail view now include a "View Full Details" button that opens the full panel.

• **Version-gap configuration** — new setting `saropaLints.packageVibrancy.enableVersionGap` (default: off) to enable GitHub version-gap fetching. Recommended with a GitHub token for best results.

### Changed

• **Compact hover tooltip** — pubspec dependency hover reduced from 60-100+ lines to ~10 lines of must-know stats (score, update, license, vulnerabilities, critical alerts, action item count).

---

## [9.9.1]

### Added

• **Lint rules** — 7 new Flutter deprecation migration rules (WARNING, Recommended tier):

- **prefer_m3_text_theme**: flags deprecated 2018-era TextTheme member names (headline1–6, subtitle1–2, bodyText1–2, caption, button, overline) removed in Flutter 3.22. Quick fix renames to M3 equivalents.
- **prefer_keepalive_dispose**: flags `KeepAliveHandle.release()` removed after Flutter 3.19; use `dispose()` instead. Quick fix renames the method call.
- **prefer_pan_axis**: flags `InteractiveViewer.alignPanAxis` removed after Flutter 3.19; use `panAxis` enum parameter instead.
- **prefer_context_menu_builder**: flags `CupertinoContextMenu.previewBuilder` removed after Flutter 3.19; use `builder` (callback signature changed, manual migration required).
- **prefer_button_style_icon_alignment**: flags `iconAlignment` parameter on button constructors deprecated in Flutter 3.28; move to `ButtonStyle.iconAlignment`.
- **prefer_key_event**: flags deprecated `RawKeyEvent`/`RawKeyboard` system deprecated in Flutter 3.18; migrate to `KeyEvent`/`HardwareKeyboard`.
- **prefer_platform_menu_bar_child**: flags `PlatformMenuBar.body` removed after Flutter 3.16; use `child` instead. Quick fix renames the parameter.

• **Lint rules** — **prefer_tabbar_theme_indicator_color**: flags `ThemeData.indicatorColor` usage deprecated in Flutter 3.32.0; migrate to `TabBarThemeData.indicatorColor` (WARNING, Recommended tier). Quick fix removes the deprecated argument.

• **Lint rules** — 10 new rules from ROADMAP additional rules 11–20:

- **uri_does_not_exist** (ERROR, Essential): import/export/part URI refers to a non-existent file.
- **depend_on_referenced_packages** (WARNING, Essential): imported package not listed in pubspec.yaml dependencies.
- **secure_pubspec_urls** (WARNING, Recommended): flags insecure http:// or git:// URLs in pubspec dependency sources.
- **package_names** (WARNING, Recommended): package name in pubspec must be lowercase_with_underscores.
- **prefer_for_elements_to_map_from_iterable** (WARNING, Professional): prefer for-element map literal over Map.fromIterable with key/value closures.
- **missing_code_block_language_in_doc_comment** (INFO, Comprehensive): fenced code block in doc comment missing language identifier.
- **unintended_html_in_doc_comment** (INFO, Comprehensive): angle brackets in doc comment prose interpreted as HTML.
- **uri_does_not_exist_in_doc_import** (INFO, Comprehensive): @docImport URI refers to a non-existent file.
- **invalid_visible_outside_template_annotation** (WARNING, Comprehensive): @visibleOutsideTemplate used on wrong declaration type.
- **sort_pub_dependencies** (INFO, Comprehensive): pubspec dependencies not sorted alphabetically.

## [9.9.0]

### Fixed

• **Package** — Analysis log report sections **FILE IMPORTANCE**, **FIX PRIORITY**, and **PROJECT STRUCTURE** now receive import graph data: `ImportGraphTracker.collectImports` runs from `SaropaContext` on each analyzed file (right after the file is recorded for progress), and `ImportGraphTracker.setProjectInfo` runs from `AnalysisReporter.initialize` so `package:` self-imports resolve. If the reporter is never initialized (e.g. progress reporting off), `collectImports` infers project root and package name from the file path once. Windows path keys (`\` vs `/`) are aligned when resolving edges so the graph matches analyzer file paths.

• **Package** — **Cross-isolate import graph:** each batch file (`.batches/*.json`) now includes optional `ig` (raw import/export URIs per file). `ReportConsolidator` merges `ig` across isolates into `ConsolidatedData.mergedRawImports`; the combined report hydrates `ImportGraphTracker` from that merge so FILE IMPORTANCE / PROJECT STRUCTURE reflect the whole session. Legacy batches without `ig` still use in-memory graph data from the writing isolate. **Path alignment:** consolidated violations use project-relative paths; `ImportGraphTracker` resolves scores and FILE IMPORTANCE issue counts against graph keys via canonical path matching.

• **Package** — Priority report correctness: progress/report counts are now deduplicated by `ruleName:offset` (offset-based) instead of `ruleName:line`, preventing inflated FIX PRIORITY / FILE IMPORTANCE counts when the same rule emits multiple diagnostics at the same location. The combined report also omits the legacy flat `ALL VIOLATIONS` section so developers work from the prioritized view.

### Added

• **Package** — Performance benchmark: added `test/import_graph_tracker_perf_test.dart` to measure ordering overhead for FILE IMPORTANCE / FIX PRIORITY / PROJECT STRUCTURE sections. Synthetic “200-file chain + 500 violations” took ~60-80ms in unit test (the “<20ms” target still needs optimization).
• **Extension** — Added setting `saropaLints.runAnalysisOpenEditorsOnly` to run `dart/flutter analyze` only for Dart files currently open in VS Code (faster turnaround during focused work).

• **Extension** — **Drift Advisor integration (optional):** When using a Dart/Drift project and a running Saropa Drift Advisor server, enable `saropaLints.driftAdvisor.integration` in settings. The extension discovers the server (ports 8642–8649 by default via GET /api/health), fetches index suggestions and anomalies (GET /api/issues when supported, else legacy endpoints), maps table/column to Dart file/line via PascalCase/camelCase heuristics, and shows issues in the **Drift Advisor** sidebar view and optionally in the Problems list (source "Saropa Drift Advisor"). Settings: integration, portRange, pollIntervalMs, showInProblems. Commands: Refresh, Open in Browser. No dependency on the Drift Advisor extension at install time. See About Saropa Lints and plan in bugs/history.

• **Extension** — **Log Capture integration**: Public API for other extensions (e.g. Saropa Log Capture). When the extension is activated, `exports` provides: `getViolationsData()`, `getViolationsPath()`, `getHealthScoreParams()`, `runAnalysis()`, `runAnalysisForFiles(files)`, `getVersion()`. Consumers use `vscode.extensions.getExtension('saropa.saropa-lints')?.exports`. No progress UI when `runAnalysisForFiles` is invoked via API unless `showProgress: true`; file list is normalized, deduplicated, sorted, and capped at 50. See extension README “API for other extensions” and `bugs/plan/plan_log_capture_integration.md`.

• **Package** — **Consumer manifest**: `reports/.saropa_lints/consumer_contract.json` is written after every violation export with `schemaVersion`, `healthScore` (impactWeights, decayRate), and `tierRuleSets` (rule names per tier: essential, recommended, professional, comprehensive, pedantic, stylistic). Single source for health score constants: `lib/src/report/health_score_constants.dart`; extension’s `healthScore.ts` and the manifest stay in sync. Documented in VIOLATION_EXPORT_API.md “Consumer manifest” section.

• **Package** — **Rule metadata API:** `RuleType`, `RuleStatus`, and `AccuracyTarget` (`lib/src/rule_metadata.dart`); optional getters on `SaropaLintRule` (`ruleType`, `accuracyTarget`, `ruleStatus`, `cweIds`, `certIds`, `tags`). Exported from `package:saropa_lints/saropa_lints.dart`. Bulk `ruleType`/`tags` by category: `scripts/bulk_rule_metadata.py`. Security follow-up: populated `cweIds` and added `securityHotspot` + `review-required` (WebView/redirects) via `scripts/apply_security_metadata_cwe_hotspots.py` where human review is expected. See `bugs/discussion/RULE_METADATA_BULK_STATUS.md`.

• **Scan** — Public programmatic API and CLI extensions: (1) **Public API**: `package:saropa_lints/scan.dart` exports `ScanRunner`, `ScanConfig`, `ScanDiagnostic`, `loadScanConfig`, `scanDiagnosticsToJson`, `scanDiagnosticsToJsonString`, and `ScanMessageSink` for running scans from code without the CLI. (2) **File-list support**: `ScanRunner(dartFiles: [...])` and CLI `--files <path>...` and `--files-from-stdin` (one path per line) to scan only specified files; relative paths resolved against project root; optional exclusions applied. (3) **Tier override**: `ScanRunner(tier: 'essential'|...)` and CLI `--tier <name>` to use a tier’s rule set for that run without changing `analysis_options.yaml`. (4) **Message sink**: optional `messageSink` callback to redirect or suppress progress/error output. (5) **JSON output**: `--format json` writes machine-readable JSON to stdout; same schema via `scanDiagnosticsToJson` / `scanDiagnosticsToJsonString`. (6) **CLI parser**: `parseScanArgs` in `lib/src/scan/scan_cli_args.dart` (testable); `--tier` with no value now exits 2 with clear message. (7) **Tests**: `test/scan_cli_args_test.dart` (parseScanArgs + process test), `test/scan_runner_test.dart` (ScanRunner with tier, dartFiles). Backward-compatible; existing `dart run saropa_lints scan [path]` unchanged when options omitted. See README “Standalone Scanner” and “Programmatic scan”.

### Changed

• **Package Vibrancy** — Unused-package detection no longer flags federated platform plugins with non-standard suffixes (e.g. `google_maps_flutter_ios_sdk10`) when the parent package is in `dependencies` or `dev_dependencies`; uses a parent-package heuristic in addition to the existing hard-coded suffix list.

• **Package Vibrancy** — Report and webview titles use "Package Vibrancy Report" consistently (removed leftover "Saropa " from markdown export and HTML/webview panel).

### Added

• **Extension** — **TODOs & Hacks** view: Todo-Tree-style sidebar that lists TODO, FIXME, HACK, XXX, and BUG comment markers by scanning workspace files (no Dart analyzer or violations.json). Tree shows by folder → file → line, or by tag → file → line when "Group by tag" is enabled. Click a line to open the file at that line. Settings: tags, include/exclude globs, maxFilesToScan, autoRefresh (debounced refresh on save), groupByTag, and optional customRegex override. View toolbar: **Refresh** and **Toggle group by tag / folder**. "Scanning…" message shown briefly on refresh/toggle. When the scan hits the file cap, a placeholder node explains how to increase the limit. Unit tests for regex and exclude-pattern logic (run `npm run test` in extension directory). Implementation: core uses `regex.exec()` with `lastIndex` reset when global; concurrency guard prevents duplicate full scans when expanding multiple tag nodes.

• **Lint rules** — **no_runtimeType_toString**: flags `runtimeType.toString()` and suggests type checks or direct `Type` comparison (performance, MAJOR, Recommended tier).

• **Lint rules** — **use_truncating_division**: flags `(a / b).toInt()` and suggests `a ~/ b` (MAJOR, Recommended tier).

• **Lint rules** — Eight additional rules from ROADMAP (comprehensive tier): **external_with_initializer** (external field/variable must not have initializer), **illegal_enum_values** (enum must not declare instance member named `values`), **wrong_number_of_parameters_for_setter** (setter must have exactly one required positional parameter), **duplicate_ignore** (same diagnostic listed twice in one ignore comment), **type_check_with_null** (prefer `== null` / `!= null` over `is Null` / `is! Null`), **unnecessary_library_name** (library directive with only a name and no URI), **invalid_runtime_check_with_js_interop_types** (is/is! with JS interop type at runtime), **argument_must_be_native** (Native.addressOf argument must be @Native or native type).

• **Extension** — **Explain rule**: right-click any violation in the Issues view (or run **Saropa Lints: Explain rule** from the command palette) to open a side tab with full rule details: problem message, how to fix, severity, impact, OWASP mapping (when present), and a link to the ROADMAP. The panel reuses a single tab; the documentation link opens in the default browser.

• **Extension** — **Create Saropa Lints Instructions for AI Agents**: Command (Overview title bar and Command Palette) creates `.cursor/rules/saropa_lints_instructions.mdc` in the workspace from a bundled template, so AI agents get project guidelines (essential files, workflow, prohibitions, principles). Uses async file I/O and a short progress notification.

### Administration

• **Scripts** — `publish.py` main workflow refactored into smaller helpers (`_PublishContext`, `_run_audit_step`, `_run_pre_publish_pipeline`, `_run_badge_validation_docs_dryrun`, etc.) to reduce cognitive complexity; behavior unchanged. Extension install/publish prompts centralized in `_prompt_extension_install_and_publish`. Main docstring documents flow for reviewers. `SystemExit` from `exit_with_error()` is caught so `finally` (timer summary) runs and the intended exit code is returned.

• **Scripts** — Version prompt in `publish.py` refactored into smaller helpers (`_handle_win_key`, `_prompt_version_windows`, `_prompt_version_unix`) to satisfy cognitive complexity limits; behavior unchanged.

• **Scripts** — Gap analysis export: `scripts/export_saropa_rules_for_gap.py` exports rule names and categories to JSON for comparison with external Dart rule sets. Procedure and inputs/outputs are documented in `bugs/discussion/GAP_ANALYSIS_EXTERNAL_DART.md`. Rule metadata plan (rule types, accuracy targets, tags, quality gates, etc.) is in `bugs/discussion/PLAN_RULE_METADATA_AND_QUALITY.md`.

• **Extension** — First-run notification: score qualifier uses an if/else chain instead of a nested ternary (lint compliance, readability).

• **Extension** — Prefer `.at(-n)` for from-end array access in celebration/snapshot logic (lint compliance).

• **Extension** — Code quality: resolve SonarQube/TypeScript findings (node: imports, reduced cognitive complexity, batched subscriptions, replaceAll, positive conditions, extracted celebration/status-bar helpers); behavior unchanged.

---

## [9.8.1]

_Smarter SDK guidance in pubspec and less noise when already on 3.9+._

### Added

• **Package Vibrancy** — SDK constraint diagnostic now includes actionable guidance: "Aim for >=3.10.0; use >=3.9.0 only if you need to support more legacy setups." Quick fixes: **Set Dart SDK to >=3.10.0** (preferred) and **Set Dart SDK to >=3.9.0 (legacy support)**; both preserve the existing upper bound (e.g. <4.0.0). Hover on the `sdk:` or `flutter:` line in `pubspec.yaml` shows the Dart/Flutter version history table; diagnostic code links to [PACKAGE_VIBRANCY.md](https://github.com/saropa/saropa_lints/blob/main/PACKAGE_VIBRANCY.md).

### Changed

• **Package Vibrancy** — "Behind latest stable" is no longer shown when the Dart SDK minimum is already >=3.9.0, to avoid nagging projects that have adopted the recommended legacy floor.

---

## [9.8.0]

_One-line vibrancy summary in pubspec by default and consistent "Package Vibrancy" naming._

### Changed

• **Package Vibrancy** — Inline diagnostics in `pubspec.yaml` are now simplified by default: a single summary line (e.g. "Package Vibrancy: 12 stale, 8 legacy-locked — Open Package Vibrancy view for details.") instead of one warning per package. New setting `saropaLints.packageVibrancy.inlineDiagnostics`: **summary** (default), **critical** (only end-of-life/vulnerabilities/family conflicts per-line), **all** (one diagnostic per package, previous behavior), or **none** (sidebar only). Reduces noise in large projects while keeping the Package Vibrancy view as the place for full details.

• **Package Vibrancy** — All user-facing text and diagnostic sources now use "Package Vibrancy" only; the former "Saropa Package Vibrancy" label has been removed from the extension (settings title, report headers, CI-generated comments, and diagnostics).

---

## [9.7.0]

_Headless config writer, cross-file analysis CLI, and a polished Issues view._

### Added

• **Headless config writer (write_config)** — New `write_config` executable and `lib/src/init/write_config_runner.dart` for writing `analysis_options.yaml` from tier + `analysis_options_custom.yaml` without interactive output. Extension now calls `dart run saropa_lints:write_config --tier <tier> --target <workspace>` instead of init for Enable, Initialize Config, and Set tier. Init remains for CI/scripting. Aligns with [003_INIT_REDESIGN](bugs/discussion/003_INIT_REDESIGN.md) (extension-driven config).

• **Cross-file analysis CLI** — New `cross_file` executable: `dart run saropa_lints:cross_file <command>` with commands `unused-files`, `circular-deps`, `import-stats`, and `report`. Builds the import graph from `lib/`, reports files with no importers, circular import chains, and graph statistics. Output: text (default), JSON, or HTML via `report --output-dir`. Baseline: `--baseline <file>` and `--update-baseline` to suppress known issues and fail only on new violations. Exit codes 0/1/2. README and [doc/cross_file_ci_example.md](doc/cross_file_ci_example.md) for CI. See [ROADMAP Part 3](ROADMAP.md).

• **Central cache stats** — `CacheStatsAggregator.getStats()` returns a single map aggregating statistics from all project caches (import graph, throttle, speculative, rule batch, baseline, semantic, etc.) for debugging and monitoring.

### Changed

• **Extension** — Polished Issues view violation context menu with icons for Apply fix / Copy message, a separator between action and hide groups, and clearer suppression behavior (rule vs rule-in-file); extension README documents how to clear and manage suppressions from the toolbar.

### Archive

• Rules 8.0.11 and earlier moved to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md)

---

## [9.6.1]

_No more vibrancy warnings for path or git-resolved dependencies._

### Fixed

• **Package Vibrancy** — Do not show the main vibrancy diagnostic (Review/stale/legacy-locked/end-of-life/monitor) for dependencies resolved via path or git override; the resolved artifact is local or from git, so the upstream pub.dev score is not actionable and was causing false positives.

---

## [9.6.0]

_Clearer Package Vibrancy scoring and reliable filter-by-type behavior._

### Added

• **Package Vibrancy** — Action Items tree now shows a simple letter grade (A = best … E = stale … F = dangerous) and problem count instead of a numeric “risk” score; aligns with a single, clear scoring system and correct pluralization (“1 problem” / “2 problems”)

### Fixed

• **Package Vibrancy** — Filter by Problem Type now correctly applies the selected types; resolved QuickPick selections using a shared id+label fallback so filter state is set reliably across environments

---

## [9.5.2]

_Keeping your lints fresh — the extension now detects outdated saropa_lints versions and offers one-click upgrades, plus new SDK constraint diagnostics._

### Added

• **Extension** — background upgrade checker: on activation, the extension checks pub.dev for newer saropa_lints versions and shows a non-intrusive notification with Upgrade, View Changelog, and Dismiss actions; throttled to once per 24 hours, remembers dismissed versions, skips path/git dependencies, and respects the new `saropaLints.checkForUpdates` setting

• **Extension** — SDK constraint diagnostics: inspects the `environment` section of `pubspec.yaml` and reports when Dart SDK or Flutter version constraints are behind the latest stable release; shows Warning when the upper bound excludes latest, Information when behind by a minor version, and Hint for patch-level gaps; fires on file open, on edit (debounced), and after every vibrancy scan

• **Extension** — overview panel toolbar: added About (info icon) and Run Analysis (play icon) buttons to the overview panel title bar; removed redundant tree items (Run Analysis, Summary, Config, Suggestions) that duplicate existing sidebar views

• **Extension** — overview tree icons: each overview item now displays a contextual icon (pulse for health score, warning/pass for violations, graph-line for trends, arrow-down for regressions, star-full for celebrations, history for last run)

---

## [9.5.1]

_Streamlining the Package Vibrancy toolbar._

### Added

• **Package Vibrancy** — added interactive Size Distribution charts (horizontal bar + SVG donut) to the vibrancy report webview; bars animate in, donut segments draw in, hover shows tooltips with cross-highlighting between charts, click scrolls to the package row in the table; small packages are consolidated into "Other (N packages)"

• **Package Vibrancy** — added Expand All button to the tree toolbar; collapse all uses the built-in VS Code button (`showCollapseAll`)

### Changed

• **Package Vibrancy** — the "Unhealthy" problem label now shows the actual category ("End of Life", "Stale", "Legacy-Locked") instead of the generic "Unhealthy" label; the description shows the vibrancy score for additional context

• **Package Vibrancy** — the Version group now shows "(latest)" on the version constraint and collapses when the package is confirmed up-to-date; the redundant "Latest" child row is hidden in that case

### Fixed

• **Package Vibrancy** — fixed false positive "unused" detection for packages referenced only via `export` directives (e.g. `analyzer_plugin`); the import scanner now recognizes both `import` and `export` as package usage

• **Extension** — fixed "Annotate pubspec.yaml" command targeting the wrong file in workspaces with multiple `pubspec.yaml` files; now prefers the active editor's pubspec, then falls back to the workspace root; also checks the `applyEdit` return value and shows the target file name in the success message

• **Lint rules** — registered `prefer_debugPrint` rule that was implemented but never wired into `_allRuleFactories` or assigned a tier; now active in the Recommended tier

• **Examples** — removed stale `custom_lint` dev dependency from all 6 example projects; `custom_lint ^0.8.0` requires `analyzer ^8.0.0` which conflicts with the v5 native plugin's `analyzer ^9.0.0`

• **ROADMAP** — removed `prefer_semver_version` and `prefer_correct_package_name` from the "Deferred: Pubspec Rules" section; both are already implemented and registered

• **Plugin** — removed dead `PreferConstChildWidgetsRule` commented-out factory entry (class never existed)

### Removed

• **Extension:** removed the "About Package Vibrancy" info icon and webview panel from the Package Vibrancy sidebar toolbar

• **Package Vibrancy** — removed the cryptic problem-severity summary row (colored dots with bare numbers) from the top of the tree; the Action Items group already communicates problem counts and details

---

## [9.5.0]

_Smarter dependency health — stale vs end-of-life separation, GitHub archived-repo detection, a unified vibrancy panel with filters, and copy-as-JSON across all tree views._

### Added

• **Extension** — "Copy as JSON" context menu on all tree views (Issues, Config, Summary, Security Posture, File Risk, Overview, Suggestions, Package Vibrancy) with recursive child serialization and multi-select support

• **Package Vibrancy** — GitHub archived-repo detection: archived repositories are automatically classified as End of Life and shown with a 🗄️ badge in tree view, hover tooltip, and detail panel

• **Package Vibrancy** — richer GitHub metrics: true open issue count (separating issues from PRs), open PR count, last commit date, and GitHub license; displayed across hover tooltip, detail panel, and output log

### Changed

• **Extension** — consolidated 3 right-side status bar items (Saropa Lints, CodeLens toggle, Vibrancy score) into a single unified item; vibrancy score appears in the label when scan data is available, with full detail in the tooltip; new `showInStatusBar` setting lets users hide the vibrancy score without disabling the extension

• **Extension** — "Apply fix" context menu item in Issues tree is now greyed out for violations whose rule has no quick-fix generator; `rulesWithFixes` list in `violations.json` config section drives the enablement so the user knows upfront which violations are auto-fixable

• **Package Vibrancy** — merged Package Problems panel into Package Vibrancy; problems and suggested actions now appear as child nodes under each package instead of in a separate tree view

• **Package Vibrancy** — added filter toolbar: search by name, filter by severity, problem type, health category, and dependency section; toggle problems-only view mode; clear all filters

• **Package Vibrancy** — problem summary bar (severity counts) now appears at the top of the unified tree when problems exist

• **Package Vibrancy** — added algorithmic guardrail to prevent editorial `end_of_life` overrides from condemning actively-maintained packages; if live pub.dev data shows a package has ≥130 pub points and was published within 18 months, the classification is capped at Legacy-Locked instead of End of Life

• **Package Vibrancy** — `isDiscontinued` (objective pub.dev signal) now takes priority over known-issue overrides in the status classifier

• **Package Vibrancy** — reclassified 71 known-issue entries from `end_of_life` to `caution` for packages that are actively maintained with verified publishers and high pub points (e.g. `animations`, `google_fonts`, `flutter_local_notifications`, `camera`, `dio`); these packages are now scored by the vibrancy algorithm instead of being force-classified as dead

• **Package Vibrancy** — separated "Stale" from "End of Life": packages with score < 10 are now classified as `stale` (low maintenance activity) instead of `end-of-life`; the `end-of-life` label is reserved exclusively for packages that are discontinued on pub.dev, listed in known_issues as `end_of_life`, or archived on GitHub; new budget dimension `maxStale` and CI threshold `maxStale` added

• **Extension** — removed "Saropa:" prefix from all vibrancy command titles in context menus and command palette; commands now read "Scan Dependencies", "Update All Dependencies", etc. instead of "Saropa: Scan Dependencies"

### Fixed

• **Lint Rules** — `require_image_picker_permission_ios` no longer fires a false positive on gallery-only usage; the rule now checks for `ImageSource.camera` in `pickImage()`/`pickVideo()` calls instead of triggering on any `image_picker` import, matching the Android rule's approach

• **Package Vibrancy** — clicking a problem child node (e.g. "Unhealthy") now navigates to the correct pubspec.yaml from the last scan instead of opening a random pubspec in a multi-root workspace

• **Package Vibrancy** — added missing `stale` category handling in comparison view CSS, scan log output, CI threshold prompts, and CI generator templates

• **Analyzer** — `// ignore:` and `// ignore_for_file:` comments now suppress violations in the extension's Issues tree and `violations.json`, not just in the editor; centralized ignore handling in `SaropaDiagnosticReporter` so all rules benefit without per-rule opt-in

• **Package Vibrancy** — added missing `.warning` CSS class in detail-view styles; archived-repo row now renders with correct warning color instead of inheriting default text color

## [9.4.2]

_Quick polish: colored diagnostic icons in the Issues tree and clipboard support on vibrancy tooltips._

### Added

• **Extension** — copy-to-clipboard link on package vibrancy hover tooltip; copies full package info as markdown

### Changed

• **Extension** — Issues tree severity and folder nodes now display colored diagnostic icons (error/warning/info) instead of plain folder icons

### Fixed

• **Extension** — clicking a child node (problem, suggestion, or healthy package) in the Package Problems tree now shows the parent package's details instead of clearing the Package Details panel

---

## [9.4.1]

_Housekeeping: plugging minor gaps carried over from the Package Vibrancy merge._

### Fixed

• **Extension** — dispose the upgrade-plan output channel on deactivation (was never cleaned up, minor resource leak)

• **Extension** — declare `focusIssuesForOwasp` command in `package.json` so VS Code can validate it; hidden from Command Palette since it requires a structured argument

• **Extension** — set `showPrereleases` context key via `setContext` so the show/hide prerelease toggle buttons reflect the actual state; also wire `refresh()` into the config-change listener so direct settings.json edits stay in sync

---

## [9.4.0]

_Package Vibrancy is now built into Saropa Lints. One extension, one sidebar — lint analysis and dependency health together._

### Added

• **Package Vibrancy integration** — merged the standalone Package Vibrancy extension into Saropa Lints

- Three new collapsible sidebar panels: Package Vibrancy, Package Problems, Package Details
- Dependency vibrancy scoring, vulnerability scanning (OSV + GitHub Advisory), SBOM export (CycloneDX)
- Upgrade planning with test gates, bulk updates (latest/major/minor/patch)
- CodeLens badges on pubspec.yaml dependencies showing vibrancy scores
- Unused dependency detection, pubspec annotation, dependency sorting
- Background version watching with configurable polling intervals
- Budget enforcement (max dependencies, total size, min average vibrancy)
- Private registry support with secure token storage
- CI pipeline generation for dependency health checks
- Package comparison view for side-by-side evaluation

### Changed

• **Build system** migrated from raw tsc to esbuild (bundled single file, smaller .vsix, faster startup)

• Extension minimum VS Code version remains ^1.74.0

---

## [9.3.0]

### Added

• "About Saropa Lints" screen showing extension version and full company/product info from `ABOUT_SAROPA.md` — accessible from the Overview welcome buttons and command palette

• "Getting Started" walkthrough button in Overview welcome content

• Overview intro text describing the two components (pub.dev package + VS Code extension)

• Version number shown in status bar tooltip for deployment verification

• `precompile` script auto-copies root `ABOUT_SAROPA.md` into extension bundle so the About screen stays in sync with the source of truth

### Changed

• Consolidated three status bar items into one — shows score + tier (e.g. `Saropa: 72% · recommended`), version in tooltip only

• Score display uses `%` format instead of `/100`

• Sidebar views hidden when empty — Issues appears with a Dart project, Config when enabled, Summary/Suggestions/Security Posture/File Risk after analysis has data

• Removed 15 redundant welcome content entries for views now hidden by `when` clauses

• "Learn More" button renamed to "Learn more online" to clarify it opens a website

### Administration

• **CRITICAL** Fixed extension never reaching VS Code Marketplace after v9.0.2 — `run_extension_package()` used `next(glob("*.vsix"))` which returned the stale 9.0.2 `.vsix` (alphabetically before 9.1.0/9.2.0) instead of the newly created one; now deletes old `.vsix` files before packaging and looks for the expected filename first

• Changed extension Marketplace publish prompt default from No to Yes (`[Y/n]`) — previous default silently skipped publishing with no warning

• Replaced misleading "package already published" error messages with clear descriptions of what actually failed

---

## [9.2.0]

Extension reliability and subdirectory project support.

### Fixed

• **IMPORTANT** Fixed YAML corruption in `ensureSaropaLintsInPubspec()` — regex backtracking placed the dependency on the same line as `dev_dependencies:`, producing invalid YAML that caused `dart run saropa_lints:init` to fail on every project

• Fixed `DEFAULT_VERSION` from stale `^8.0.0` to `^9.1.0`

• Fixed `fs` import shadowing in OWASP export handler (dynamic `import('fs')` shadowed static `import * as fs`)

• Fixed `package_config.json` verification to match exact `"saropa_lints"` instead of substring

• Removed unreachable fallback branch in inline annotations path computation

### Added

• Subdirectory pubspec detection — projects with `pubspec.yaml` one level deep (e.g. `game/pubspec.yaml`) are now discovered automatically

• Centralized project root discovery (`projectRoot.ts`) with per-session caching

• Workspace folder change listener invalidates cached project root

• Added `workspaceContains:*/pubspec.yaml` activation event

### Changed

• All 13 source files now use `getProjectRoot()` instead of scattering `workspaceFolders[0]` references

• Line-based YAML insertion preserves original CRLF/LF line endings

---

## [9.1.0]

### Changed

• Welcome views and status bar now detect non-Dart workspaces and show appropriate guidance instead of a misleading "Enable" button

### Removed

• **Logs view:** Removed the Logs panel from the sidebar — it was a file browser for the `reports/` directory, which the built-in file explorer already provides.

---

## [9.0.2]

Sidebar icon refinement.

### Changed

• **Sidebar icon:** Changed activity bar icon from solid fill to wireframe (stroked outline) for consistency with VS Code's icon style.

### Administration

• **Open VSX publish:** The publish script now prompts for an OVSX_PAT when the environment variable is missing, with platform-specific setup instructions, instead of silently skipping.

• **Stale plugin-cache repair:** `dart analyze` failures caused by a stale analyzer plugin cache are now detected automatically. The script offers to update `analysis_options.yaml` and clear the cache in one step.

• **Post-publish version sync:** After publishing, `analysis_options.yaml` plugin version is updated to the just-published version so `dart analyze` resolves correctly.

---

## [9.0.1]

Sidebar polish — fixed the broken activity bar icon, removed repetitive enable buttons, and auto-enabled the extension for existing users.

### Added

• **Auto-enable for existing projects:** The extension now detects `saropa_lints` in pubspec.yaml and enables itself automatically — no manual "Enable" click needed for projects that already depend on the package. New projects still see the welcome prompt.

### Fixed

• **Sidebar icon:** Replaced oversized colorful PNG with monochrome SVG that renders correctly in the VS Code activity bar and respects theme colors.

• **Repetitive enable buttons:** Removed duplicate "Enable Saropa Lints" buttons from Config, Logs, Suggestions, Security Posture, File Risk, and Summary views. The enable button now appears only in Overview and Issues; other views show a text pointer instead.

---

## [9.0.0]

The VS Code extension is now the primary way to use saropa_lints. One-click setup, health scoring, rule triage, inline annotations, OWASP compliance reports, and file risk analysis — all from the sidebar. The CLI remains for CI and scripting but interactive setup has moved entirely to the extension. Run “Saropa Lints: Getting Started” from the command palette to get started.

### Added

• **Health Score & Trends:** 0–100 project quality score in the Overview view and status bar, computed from violation count and impact severity. Color bands (green/yellow/red), score delta from last run, trend tracking over last 20 snapshots, milestone celebrations (50/60/70/80/90), and regression alerts when score drops.

• **Issues & Inline Annotations:** Error Lens-style decorations showing violation messages at the end of affected lines. Issues tree grouped by severity and file with text/severity/impact/rule filters, persistent suppressions, focus mode, group-by presets (Severity/File/Impact/Rule/OWASP), and context-menu quick fixes. Code Lens per file with critical count. Bulk “Fix all in this file” with progress and score delta. “Show in Saropa Lints” from the Problems view.

• **Security Posture:** OWASP Top 10 coverage matrix (Mobile and Web) with violation and rule counts per category. Click to filter Issues. “Export OWASP Compliance Report” generates a markdown report for audits.

• **Triage & Config:** Rules grouped by priority (critical, volume bands A–D, stylistic) with estimated score impact per group. Right-click to disable/enable rules — writes overrides to YAML and re-runs analysis. Packages auto-detected from `pubspec.yaml`. Custom config reduced from ~420 to ~40 lines.

• **File Risk:** Files ranked by weighted violation density — riskiest first. Flame icon for critical, warning icon for high. Summary shows “Top N files have X% of critical issues”.

• **First-run & Welcome:** "Getting Started" walkthrough with guided tour of all features (Health Score, Issues, Security, Triage, Trends, and About Saropa). Score-aware notification after enabling with actionable buttons. Native welcome states on all views when disabled or no data. Analysis auto-focuses Overview to show score delta. Extension report writer logs actions for audit trail.

### Deprecated

• **CLI init interactive mode:** `dart run saropa_lints:init` is now headless-only — defaults to `recommended` tier. Use the VS Code extension for interactive setup. CLI remains for CI/scripting with `--tier`, `--target`, `--no-stylistic`. Removed `--stylistic` (interactive walkthrough) and `--reset-stylistic` flags; use `--stylistic-all` for bulk enable.

### Changed

• **Custom config notice:** `analysis_options_custom.yaml` now includes a prominent "DO NOT EDIT MANUALLY" banner directing users to the VS Code extension for rule overrides.

• **Smart Tier Transitions:** Upgrading to a higher tier auto-filters the Issues view to critical + high violations so users aren't overwhelmed. Notification shows violation delta and "Show All" escape hatch. Tier picker shows rule counts, descriptions, and current-tier marker; same-tier selection is a no-op.

• Progress indicators for Run Analysis, Initialize Config, and Set Tier.

• Debounced refresh (300 ms) on `violations.json` changes.

• Summary view uses stable node IDs for expansion state.

• Status bar update logic consolidated across all command handlers.

### Fixed

• Health Score NaN guard for non-numeric JSON values.

• Run history dedup compares severity breakdown and score, not just total.

• Celebration messages only fire on genuinely new snapshots.

• Snapshot recorded before tree refresh so Overview reads fresh history.

• Inline annotations cache violations data; re-read only on file-watcher change.

• Test runner hanging indefinitely: added global 2-minute timeout (`dart_test.yaml`) and per-test timeouts on integration tests that spawn `Process.run` without a cap.

• Security Posture caches OWASP counts; OWASP filter clears prior filters; ID normalization handles short and long forms; data validation for malformed JSON.

• Output channel uses singleton pattern.

• Tree view fixes: root folder path prefix, severity/impact suppression timing, tier status bar immediate update.

### Administration

• Unified publish script (`scripts/publish.py`) for package and extension; extension version synced with package version.

---

## [8.2.2]

### Changed

• Release version bump

---

## [8.2.0]

### Added

• **Init `--target` flag:** `dart run saropa_lints init --target /path/to/project` generates configuration for any project directory, not just the current working directory.

• **Standalone scan command:** `dart run saropa_lints scan [path]` runs lint rules directly against any Dart project without requiring saropa_lints as a dependency. Reads the project's `analysis_options.yaml` (generated by `init`) to determine which rules to run. Results are written to a report file with a compact summary on terminal.

### Changed

• **Init tool modularization:** Extracted `bin/init.dart` (4,819 lines) into 21 focused modules under `lib/src/init/`, reducing the entry point to 15 lines. No behavior changes.

- `cli_args.dart` — CLI argument parsing and `CliArgs` class
- `config_reader.dart` — user customization extraction
- `config_writer.dart` — YAML generation for `analysis_options.yaml`
- `custom_overrides_core.dart` — override file creation and settings
- `display.dart` — ANSI color support and `InitColors` class
- `init_runner.dart` — main orchestrator (`runInit`)
- `init_post_write.dart` — post-write phase (ignore conversion, walkthrough, analysis)
- `log_writer.dart` — `LogWriter` class, report file management
- `migration.dart` — V4/V7 migration detection and conversion
- `platforms_packages.dart` — platform and package settings
- `preflight.dart` — pre-flight environment checks
- `project_info.dart` — project and package detection
- `rule_metadata.dart` — rule metadata cache and lookups
- `stylistic_rulesets.dart` — stylistic rule category data
- `stylistic_section.dart` — stylistic section builder
- `stylistic_section_parser.dart` — stylistic section parsing
- `stylistic_walkthrough.dart` — interactive walkthrough orchestrator
- `stylistic_walkthrough_prompts.dart` — walkthrough UI prompts
- `tier_ui.dart` — tier selection UI
- `validation.dart` — post-write config validation
- `whats_new.dart` — release notes display (moved from `bin/`)

### Fixed

• **19 false positive bugs fixed across scan rules:**

- **Self-referential false positives (8 rules):** `avoid_asset_manifest_json`, `avoid_ios_in_app_browser_for_auth`, `avoid_mixed_environments`, `avoid_purchase_in_sandbox_production`, `require_database_migration`, `require_https_only`, `require_unique_iv_per_encryption`, `require_websocket_reconnection` — rules no longer flag their own detection pattern strings in `lib/src/rules/` and `lib/src/fixes/` directories
- **Flutter-only rules skip non-Flutter projects (5 rules):** `avoid_blocking_main_thread` (-170 FPs), `avoid_print_in_release` (-197 FPs), `avoid_long_running_isolates`, `prefer_platform_io_conditional`, `require_android_permission_request` — rules now check `ProjectContext.isFlutterProject` and skip CLI tools, servers, and analysis plugins
- **Detection logic improvements (6 rules):** `avoid_api_key_in_code` skips regex patterns; `avoid_catch_all` allows `developer.log(error:, stackTrace:)` defensive catches; `avoid_hardcoded_config` whitelists `pub.dev`/`github.com` URLs; `avoid_parameter_mutation` no longer flags collection accumulator methods (`.add()`, `.addAll()`, etc.); `require_catch_logging` recognizes `developer.log` and `stderr`; `require_data_encryption` checks argument text only (not receiver names)

---

## [8.0.11] and Earlier

For details on the initial release and versions 0.1.0 through 8.0.11, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).

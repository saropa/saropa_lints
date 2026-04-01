# Changelog

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 9.5.1.

**Package** — [pub.dev / packages / saropa_lints](https://pub.dev/packages/saropa_lints)

**Score** — [pub.dev / packages / saropa_lints / score](https://pub.dev/packages/saropa_lints/score)

**CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

**Releases** — [github.com / saropa / saropa_lints / releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com / items ? itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org / extension / saropa / saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTEANCE NOTES -- IMPORTANT --

    All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

    Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

    Each version (and [Unreleased]) should open with a short human summary when it helps; only discuss user-facing features.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

-->

---

## [Unreleased]

### Changed

- **Extension:** "Apply fix" context menu item is now hidden for violations without a quick fix, instead of showing a dead-end "No quick fix available" message

### Fixed

- **Extension:** `rulesWithFixes` from `violations.json` was not extracted, causing all violations to appear fixable regardless of actual fix availability

---

## [10.5.0]

### Added

- **(Extension)** Package Vibrancy: replacement complexity metric — analyzes local pub cache to count source lines in each dependency's `lib/` directory and classifies how feasible it would be to inline, fork, or replace (trivial / small / moderate / large / native). Shown in Size tree group, detail sidebar, and CodeLens for stale/end-of-life packages with feasible migration

### Changed

- **(Extension)** Removed the `vibrancy-summary` inline diagnostic from `pubspec.yaml` — the Package Vibrancy sidebar and report already surface this information. The `inlineDiagnostics` setting no longer offers a `"summary"` mode; the default is now `"critical"` (end-of-life packages only)

---

## [10.4.1]

### Fixed

- **(Extension)** Fixed VS Code Marketplace publishing blocked since v10.2.2 by TypeScript 5.9 bug — `tsc --noEmit` fails with "Unknown compiler option" because TS 5.9's `createOptionNameMap()` reads `option.lowerCaseName` (a property that doesn't exist on any option declaration), building an empty lookup map; pinned TypeScript to `~5.8.3` to restore extension compilation and Marketplace publishing

### Changed

- Modularized `scripts/publish.py` (1,246 → 202 lines) into three focused modules: `_publish_workflow.py` (pipeline orchestration), version prompting/sync into `_version_changelog.py`, and store verification into `_extension_publish.py`
- Added `scripts/README.md` with architecture diagram, module map, exit codes, and troubleshooting
- Added pub.dev publication verification: polls the pub.dev API after publish to confirm the new version is live

---

## [10.4.0]

Vibrancy Report overhaul — auto-hiding blank columns, clickable summary cards and chart segments for filtering, search box, richer version/health tooltips, and pub.dev deep links throughout. — [log](https://github.com/saropa/saropa_lints/blob/v10.4.0/CHANGELOG.md)

### Vibrancy Report

- **(Extension)** Auto-hide blank columns: Transitives, Vulns, and Status columns are hidden when all values are empty
- **(Extension)** Summary cards now toggle table filters on click (vibrant, quiet, stale, updates, unused, vulns)
- **(Extension)** Chart bars and donut segments toggle a package filter instead of scrolling
- **(Extension)** Search box added above the table for filtering packages by name
- **(Extension)** "Open pubspec.yaml" toolbar button sends message to open the file in the editor
- **(Extension)** Version column links to pub.dev/versions; shows compact age suffix (e.g. `(4mo)`, `(2y)`)
- **(Extension)** Version column tooltip shows installed version date, latest version, creation date, and constraint
- **(Extension)** Health column merged from separate Score/Drift; tooltip shows score breakdown (Resolution Velocity, Engagement Level, Popularity, Publisher Trust)
- **(Extension)** License column links to pub.dev/license; Update column links to pub.dev/changelog
- **(Extension)** Stars column right-aligned with comma formatting; Size column now shows KB
- **(Extension)** Section badges (`dev`, `transitive`) shown in Package column
- **(Extension)** Description info icon column with tooltip on hover
- **(Extension)** Override count shown in summary cards
- **(Extension)** `createdDate` field added to pub.dev metadata
- **(Extension)** `installedVersionDate` field added to vibrancy results

---

## [10.3.0]

Analyzer 12 migration — rewrites ~500 call sites across 70+ rule files to the new AST API, adds vibrancy scan cancel/supersede support. — [log](https://github.com/saropa/saropa_lints/blob/v10.3.0/CHANGELOG.md)

### Changed

- **Analyzer upgraded from ^9.0.0 to ^12.0.0** — migrated ~500 call sites across 70+ rule files to the new AST API (`ClassDeclaration.body.members`, `ClassNamePart.typeName`, `PrimaryConstructorDeclaration`, `DottedName`, etc.)
- **Removed analyzer-9 compatibility extensions** — `DiagnosticCodeLowerCase` and `LintCodeLowerCase` shims removed; `lowerCaseName` is now native in analyzer 12
- **Updated `CapturingRuleVisitorRegistry`** — added 5 new visitor methods and removed 4 obsolete ones to match the analyzer 12 `RuleVisitorRegistry` interface
- **Updated test registry** — `PluginRegistry` interface changes: `enabled()` method, `DiagnosticCode` parameter on `registerFixForRule`

### Added

- **Vibrancy scan cancel button** — the progress notification now shows a Cancel button so users can abort a long-running scan
- **Scan supersede** — starting a new vibrancy scan automatically cancels any in-progress scan instead of silently dropping the request

---

## [10.2.2]

Extension vibrancy scoring fix. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.2/CHANGELOG.md)

### Fixed

- **(Extension)** Vibrancy scores no longer bottom out near zero for packages with high pub.dev quality but low GitHub activity; a new pub quality bonus (0–10) scales linearly with pub.dev points so that well-vetted "finished" packages score fairly

## [10.2.1]

VS Code extension polish — clearer status bar when lint health and Package Vibrancy are both shown. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.1/CHANGELOG.md)

### Fixed

- **(Extension)** Unified status bar now uses compact disambiguation for mixed metrics when vibrancy is shown: `Saropa: 90% · V4/10` (prevents confusion between lint `%` and vibrancy `/10` without adding verbose labels)

## [10.2.0]

Stream subscription detection improvements — fixes false negatives on rxdart and custom Stream subclasses, and aligns rule description with actual behavior. — [log](https://github.com/saropa/saropa_lints/blob/v10.2.0/CHANGELOG.md)

### Added

- New rule: `avoid_removed_null_thrown_error` — flags removed `NullThrownError` type (Dart 3.0); quick fix renames to `TypeError`
- New rule: `avoid_deprecated_file_system_delete_event_is_directory` — flags deprecated `FileSystemDeleteEvent.isDirectory` (Dart 3.4) which always returns false
- New rule: `avoid_removed_render_object_element_methods` — flags removed `insertChildRenderObject`, `moveChildRenderObject`, `removeChildRenderObject` (Flutter 3.0); quick fix renames to replacement methods
- New rule: `avoid_deprecated_animated_list_typedefs` — flags deprecated `AnimatedListItemBuilder` / `AnimatedListRemovedItemBuilder` (Flutter 3.7); quick fix renames to `AnimatedItemBuilder` / `AnimatedRemovedItemBuilder`
- New rule: `avoid_deprecated_use_material3_copy_with` — flags misleading `useMaterial3` parameter in `ThemeData.copyWith()` (Flutter 3.16); quick fix removes the parameter
- New rule: `avoid_deprecated_on_surface_destroyed` — flags deprecated `SurfaceProducer.onSurfaceDestroyed` (Flutter 3.29); quick fix renames to `onSurfaceCleanup`

### Fixed

- `avoid_stream_subscription_in_field` now detects uncaptured `.listen()` calls on Stream subclasses (e.g. rxdart `MergeStream`, `BehaviorSubject`) that were previously missed by string-based type checking
- `avoid_stream_subscription_in_field` problem message and correction message now accurately describe the rule's behavior (detecting uncaptured `.listen()` calls) instead of incorrectly claiming it checks `dispose()`
- Test fixture for `avoid_stream_subscription_in_field` now uses properly-typed `Stream<int>` variables instead of undefined `dynamic` references that bypassed the type check
- **(Extension)** Violations sidebar no longer opens a "file not found" error when source files have been moved or renamed since the last analysis; affected items show a warning icon with "(file moved or deleted)" label
- **(Extension)** "Fix all in this file" command now shows a user-friendly warning instead of silently failing on moved/deleted files

## [10.1.1]

Package Vibrancy accuracy pass — removes false "End of Life" flags on healthy packages and adds a pub points quality floor so high-scoring packages are never labeled Stale. — [log](https://github.com/saropa/saropa_lints/blob/v10.1.1/CHANGELOG.md)

### Fixed

- **(Extension)** 8 packages falsely classified as **End of Life** in `known_issues.json` have been downgraded to `caution` or `active` — `local_auth`, `font_awesome_flutter`, `animations`, `flutter_email_sender`, `flutter_sticky_header`, `flutter_rating_bar`, `workmanager`, `flutter_phone_direct_caller` were contradicted by their own pub.dev scores (135-160/160 points).
- **(Extension)** Packages with **>= 140/160 pub points** can no longer classify as **Stale** — the pub points quality floor promotes them to **Legacy-Locked** at minimum, preventing high-quality quiet packages from appearing abandoned.
- **(Extension)** `calcPopularity` pub points normalization cap corrected from 150 to 160 (the actual pub.dev maximum).
- **(Extension)** Fixed dead-code status string mismatch in `adoption-classifier.ts` and `transitive-analyzer.ts` — checks for `'end-of-life'` (hyphenated) now correctly use `'end_of_life'` (underscored) to match `known_issues.json` format.

---

## [10.1.0]

This release focuses on Flutter SDK alignment (new migration lints and a shared identifier→element helper) and on the **VS Code extension**: Package Vibrancy now uses a single **trusted publishers** list so first-party and Google-published packages are not mislabeled **Quiet** when GitHub-activity scoring sits in the mid tier. — [log](https://github.com/saropa/saropa_lints/blob/v10.1.0/CHANGELOG.md)

### Added

- **`prefer_dropdown_menu_item_button_opacity_animation`** (Recommended, INFO) — Flutter 3.32 ([PR #164795](https://github.com/flutter/flutter/pull/164795)) types `opacityAnimation` on `DropdownMenuItemButton` state as non-null (`late CurvedAnimation`). The rule flags nullable `CurvedAnimation? opacityAnimation` fields and redundant `opacityAnimation!` when resolved types show `State<DropdownMenuItemButton<…>>` or a `DropdownMenuItemButton` receiver. Quick fixes: remove `!` ([RemoveNullAssertionFix](lib/src/fixes/type/remove_null_assertion_fix.dart)) and rewrite the field to `late CurvedAnimation` ([prefer_dropdown_menu_item_button_opacity_animation_field_fix.dart](lib/src/fixes/config/prefer_dropdown_menu_item_button_opacity_animation_field_fix.dart)). Fixture: `example/lib/migration/prefer_dropdown_menu_item_button_opacity_animation_fixture.dart`; mock: `DropdownMenuItemButton` in `example/lib/flutter_mocks.dart`.

- **`prefer_image_filter_quality_medium`** (Comprehensive, INFO) — Flags `filterQuality: FilterQuality.low` on Flutter SDK `Image` / `RawImage` / `FadeInImage` / `DecorationImage` so apps align with Flutter 3.24 image defaults ([PR #148799](https://github.com/flutter/flutter/pull/148799)). Quick fix rewrites `low` → `medium` (preserves enum prefix). Does not apply to `Texture`. Detection: `lib/src/rules/widget/image_filter_quality_detection.dart`; rule: `lib/src/rules/widget/image_filter_quality_migration_rules.dart`.

- **`avoid_deprecated_flutter_test_window`** (Recommended, WARNING) — Flags `package:flutter_test` [TestWindow](https://api.flutter.dev/flutter/flutter_test/TestWindow-class.html) and [TestWidgetsFlutterBinding.window](https://api.flutter.dev/flutter/flutter_test/TestWidgetsFlutterBinding/window.html), deprecated in Flutter 3.10 ([PR #122824](https://github.com/flutter/flutter/pull/122824)); migrate to `WidgetTester.platformDispatcher` and `WidgetTester.view` / `viewOf`. Detection uses resolved elements only. Shared predicates: `lib/src/rules/config/flutter_test_window_deprecation_utils.dart` (unit-tested URI boundary); `example/analysis_options_template.yaml` lists the override.

### Changed

- **Package Vibrancy (VS Code extension)** — Introduces [`extension/src/vibrancy/scoring/trusted-publishers.ts`](extension/src/vibrancy/scoring/trusted-publishers.ts): **`TRUSTED_PUBLISHERS`** (`dart.dev`, `google.dev`, `flutter.dev`, `firebase.google.com`) and **`isTrustedPublisher()`**. The same set controls (1) the **`publisherTrustBonus`** scoring bonus and (2) promoting **Quiet** → **Vibrant** when the raw score is in the mid band but the dependency is from a trusted publisher—so pubspec CodeLens and reports match maintainer intent. **EOL still wins:** discontinued packages, known end-of-life entries, and archived GitHub repos are unchanged; publisher IDs are matched case-sensitively (as on pub.dev). **`saropaLints.packageVibrancy.publisherTrustBonus`** setting description updated to describe the trusted list. **Tests:** `npm test` runs [`vibrancy-calculator.test.ts`](extension/src/test/vibrancy/scoring/vibrancy-calculator.test.ts) (trust bonus for every trusted ID) and extended [`status-classifier.test.ts`](extension/src/test/vibrancy/scoring/status-classifier.test.ts) (trusted upgrade, non-trusted quiet, wrong-case publisher, EOL overrides).

- **Analyzer identifier → element** — Shared `elementFromAstIdentifier` in [`lib/src/element_identifier_utils.dart`](lib/src/element_identifier_utils.dart) tries `.element` then `.staticElement` with optional `logFailures`. Used by `image_filter_quality_detection` and deprecated-API checks in `code_quality_avoid_rules.dart`. Documented in [CODE_INDEX.md](CODE_INDEX.md). Tests: [`test/element_identifier_utils_test.dart`](test/element_identifier_utils_test.dart).

---

## [10.0.2]

This patch wires ten compile-time mirror rules into the public rule list and tiers, updates existing rules for Analyzer 9 element APIs, and fixes a `require_data_encryption` false positive and unsafe `file://` root parsing in project metadata. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.2/CHANGELOG.md)

### Fixed

- **Plan additional rules 31–40** — The ten compile-time / doc / style mirror rules (`abstract_field_initializer`, `abi_specific_integer_invalid`, `annotate_redeclares`, `deprecated_new_in_comment_reference`, `document_ignores`, `non_constant_map_element`, `return_in_generator`, `subtype_of_disallowed_type`, `undefined_enum_constructor`, `yield_in_non_generator`) were present in source but missing from [`saropa_lints.dart`](lib/saropa_lints.dart) `_allRuleFactories` and from [`essentialRules`](lib/src/tiers.dart); they are now registered so tiers and tooling load them.
- **Analyzer 9 (migration / fixes)** — `prefer_dropdown_menu_item_button_opacity_animation` uses `declaredFragment?.element` on class and field declarations, `DartType.nullabilitySuffix` for nullable `CurvedAnimation?`, [SimpleIdentifier.element] for `!` operands, and `reporter.atToken` for field names. `PreferDropdownMenuItemButtonOpacityAnimationFieldFix` uses `NamedType.name.lexeme` and `VariableDeclarationList.lateKeyword` / `keyword` for insertion offsets. `image_filter_quality_detection` uses `SimpleIdentifier.element` only (removed `staticElement`).
- **`require_data_encryption`** — The `pin` keyword is matched only when not immediately preceded by an ASCII letter, so identifiers such as `OwaspMapping` (where `Mapping` embeds `…p-i-n…`) no longer false-positive on ordinary `write`/`writeAsString` calls. Regression coverage: `test/require_data_encryption_pin_pattern_test.dart`; fixture: `example_async/lib/security/require_data_encryption_fixture.dart`.
- **`rootUriToPath`** — `file://` roots use `Uri.tryParse` so invalid URIs return null instead of throwing; satisfies `prefer_try_parse_for_dynamic_data` for package_config paths. Tests: `test/project_info_root_uri_test.dart`.

---

## [10.0.1]

Version bump only. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.1/CHANGELOG.md)

### Changed

- Version bump

---

## [10.0.0]

In this milestone update work centers on the composite analyzer plugin hook (`registerSaropaLintRules`), rule packs end-to-end (analyzer merge, CLI init, VS Code Rule Packs webview, generated registry), extension UX that defaults integration on with clearer commands and TODOs workspace scan as opt-in, and a wave of new lints—compile-time shape alignment, Dart 3.0 removed-API migration rules, and targeted Flutter fixes. — [log](https://github.com/saropa/saropa_lints/blob/v10.0.0/CHANGELOG.md)

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

This release adds version-gap awareness: see which PRs and issues landed between your pinned version and latest, triage them with a persistent review checklist, and focus your pubspec tooltip on must-know stats with a "View Full Details" link to a full-detail panel. — [log](https://github.com/saropa/saropa_lints/blob/v9.10.0/CHANGELOG.md)

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

Flutter deprecation migration rules and ROADMAP additional rules 11–20. — [log](https://github.com/saropa/saropa_lints/blob/v9.9.1/CHANGELOG.md)

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

Import graph tracking, scan API, TODOs & Hacks view, and new lint rules. — [log](https://github.com/saropa/saropa_lints/blob/v9.9.0/CHANGELOG.md)

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

_Smarter SDK guidance in pubspec and less noise when already on 3.9+._ — [log](https://github.com/saropa/saropa_lints/blob/v9.8.1/CHANGELOG.md)

### Added

• **Package Vibrancy** — SDK constraint diagnostic now includes actionable guidance: "Aim for >=3.10.0; use >=3.9.0 only if you need to support more legacy setups." Quick fixes: **Set Dart SDK to >=3.10.0** (preferred) and **Set Dart SDK to >=3.9.0 (legacy support)**; both preserve the existing upper bound (e.g. <4.0.0). Hover on the `sdk:` or `flutter:` line in `pubspec.yaml` shows the Dart/Flutter version history table; diagnostic code links to [PACKAGE_VIBRANCY.md](https://github.com/saropa/saropa_lints/blob/main/PACKAGE_VIBRANCY.md).

### Changed

• **Package Vibrancy** — "Behind latest stable" is no longer shown when the Dart SDK minimum is already >=3.9.0, to avoid nagging projects that have adopted the recommended legacy floor.

---

## [9.8.0]

_One-line vibrancy summary in pubspec by default and consistent "Package Vibrancy" naming._ — [log](https://github.com/saropa/saropa_lints/blob/v9.8.0/CHANGELOG.md)

### Changed

• **Package Vibrancy** — Inline diagnostics in `pubspec.yaml` are now simplified by default: a single summary line (e.g. "Package Vibrancy: 12 stale, 8 legacy-locked — Open Package Vibrancy view for details.") instead of one warning per package. New setting `saropaLints.packageVibrancy.inlineDiagnostics`: **summary** (default), **critical** (only end-of-life/vulnerabilities/family conflicts per-line), **all** (one diagnostic per package, previous behavior), or **none** (sidebar only). Reduces noise in large projects while keeping the Package Vibrancy view as the place for full details.

• **Package Vibrancy** — All user-facing text and diagnostic sources now use "Package Vibrancy" only; the former "Saropa Package Vibrancy" label has been removed from the extension (settings title, report headers, CI-generated comments, and diagnostics).

---

## [9.7.0]

_Headless config writer, cross-file analysis CLI, and a polished Issues view._ — [log](https://github.com/saropa/saropa_lints/blob/v9.7.0/CHANGELOG.md)

### Added

• **Headless config writer (write_config)** — New `write_config` executable and `lib/src/init/write_config_runner.dart` for writing `analysis_options.yaml` from tier + `analysis_options_custom.yaml` without interactive output. Extension now calls `dart run saropa_lints:write_config --tier <tier> --target <workspace>` instead of init for Enable, Initialize Config, and Set tier. Init remains for CI/scripting. Aligns with [003_INIT_REDESIGN](bugs/discussion/003_INIT_REDESIGN.md) (extension-driven config).

• **Cross-file analysis CLI** — New `cross_file` executable: `dart run saropa_lints:cross_file <command>` with commands `unused-files`, `circular-deps`, `import-stats`, and `report`. Builds the import graph from `lib/`, reports files with no importers, circular import chains, and graph statistics. Output: text (default), JSON, or HTML via `report --output-dir`. Baseline: `--baseline <file>` and `--update-baseline` to suppress known issues and fail only on new violations. Exit codes 0/1/2. README and [doc/cross_file_ci_example.md](doc/cross_file_ci_example.md) for CI. See [ROADMAP Part 3](ROADMAP.md).

• **Central cache stats** — `CacheStatsAggregator.getStats()` returns a single map aggregating statistics from all project caches (import graph, throttle, speculative, rule batch, baseline, semantic, etc.) for debugging and monitoring.

### Changed

• **Extension** — Polished Issues view violation context menu with icons for Apply fix / Copy message, a separator between action and hide groups, and clearer suppression behavior (rule vs rule-in-file); extension README documents how to clear and manage suppressions from the toolbar.

---

## [9.6.1]

_No more vibrancy warnings for path or git-resolved dependencies._ — [log](https://github.com/saropa/saropa_lints/blob/v9.6.1/CHANGELOG.md)

### Fixed

• **Package Vibrancy** — Do not show the main vibrancy diagnostic (Review/stale/legacy-locked/end-of-life/monitor) for dependencies resolved via path or git override; the resolved artifact is local or from git, so the upstream pub.dev score is not actionable and was causing false positives.

---

## [9.6.0]

_Clearer Package Vibrancy scoring and reliable filter-by-type behavior._ — [log](https://github.com/saropa/saropa_lints/blob/v9.6.0/CHANGELOG.md)

### Added

• **Package Vibrancy** — Action Items tree now shows a simple letter grade (A = best … E = stale … F = dangerous) and problem count instead of a numeric “risk” score; aligns with a single, clear scoring system and correct pluralization (“1 problem” / “2 problems”)

### Fixed

• **Package Vibrancy** — Filter by Problem Type now correctly applies the selected types; resolved QuickPick selections using a shared id+label fallback so filter state is set reliably across environments

---

## [9.5.2]

_Keeping your lints fresh — the extension now detects outdated saropa_lints versions and offers one-click upgrades, plus new SDK constraint diagnostics._ — [log](https://github.com/saropa/saropa_lints/blob/v9.5.2/CHANGELOG.md)

### Added

• **Extension** — background upgrade checker: on activation, the extension checks pub.dev for newer saropa_lints versions and shows a non-intrusive notification with Upgrade, View Changelog, and Dismiss actions; throttled to once per 24 hours, remembers dismissed versions, skips path/git dependencies, and respects the new `saropaLints.checkForUpdates` setting

• **Extension** — SDK constraint diagnostics: inspects the `environment` section of `pubspec.yaml` and reports when Dart SDK or Flutter version constraints are behind the latest stable release; shows Warning when the upper bound excludes latest, Information when behind by a minor version, and Hint for patch-level gaps; fires on file open, on edit (debounced), and after every vibrancy scan

• **Extension** — overview panel toolbar: added About (info icon) and Run Analysis (play icon) buttons to the overview panel title bar; removed redundant tree items (Run Analysis, Summary, Config, Suggestions) that duplicate existing sidebar views

• **Extension** — overview tree icons: each overview item now displays a contextual icon (pulse for health score, warning/pass for violations, graph-line for trends, arrow-down for regressions, star-full for celebrations, history for last run)

---

## [9.5.1] and Earlier

For versions 0.1.0 through 9.5.1, see [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).

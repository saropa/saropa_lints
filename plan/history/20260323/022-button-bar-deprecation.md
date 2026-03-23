# Plan #022 (ButtonBar deprecation) — done

**Source plan:** `plan/implementable_only_in_plugin_extension/022-deprecate_buttonbar_buttonbarthemedata_and_themedata_buttonb.md` (removed when complete; this file is the history note).

**Summary:** Extended existing rule **`prefer_overflow_bar_over_button_bar`** to v2 for Flutter [PR #145523](https://github.com/flutter/flutter/pull/145523): `ButtonBarThemeData`, `ThemeData.buttonBarTheme` (constructor, `copyWith`, property reads), plus `MethodInvocation` shapes when the analyzer leaves the callee element unresolved. Quick fix removes `buttonBarTheme:` from `ThemeData` constructors/`copyWith` (Flutter data-driven fix parity).

**Shared code:** `lib/src/rules/config/migration_rule_source_utils.dart` — `isMaterialMigrationInstanceCreationTarget`, `compilationUnitDeclaresClassLikeName`, `sourceRangeForDeletingNamedArgument` (middle-arg comma fix). Also refactors `prefer_tabbar_theme_indicator_color` fix to use the shared deletion helper.

**Tests:** `test/prefer_overflow_bar_over_button_bar_rule_test.dart`; updated `test/listview_extent_metadata_rules_test.dart` (ButtonBar visitor parity).

**Docs / packaging:** `CHANGELOG.md` ([Unreleased]), `CODE_INDEX.md`, `pubspec.yaml` quick-fix count 140, `example/analysis_options_template.yaml`, `lib/src/tiers.dart` comment.

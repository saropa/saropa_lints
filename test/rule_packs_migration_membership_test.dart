// Consistency: SDK pack rule lists vs generated codes in kRulePacks* sources.
import 'dart:io';

import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

Set<String> _sdkPackRuleCodes() {
  final sdkPackIds = kRulePackRuleCodes.keys.where(
    (id) => id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_'),
  );
  final sdkRuleCodes = <String>{};
  for (final id in sdkPackIds) {
    sdkRuleCodes.addAll(kRulePackRuleCodes[id] ?? const <String>{});
  }

  return sdkRuleCodes;
}

Set<String> _lintCodesFromFile(String relativePath) {
  final content = File(relativePath).readAsStringSync();
  final matches = RegExp(
    r"static const LintCode _code = LintCode\(\s*'([a-z0-9_]+)'",
    multiLine: true,
  ).allMatches(content);
  return {
    for (final m in matches)
      if (m.group(1) != null) m.group(1)!,
  };
}

void main() {
  test('sdk migration rules are assigned to sdk packs', () {
    final sdkRuleCodes = _sdkPackRuleCodes();

    // Guardrail list for all migration rules currently owned by SDK packs.
    // If a migration rule is added/renamed in sdk packs, update this list.
    const expected = <String>{
      'avoid_removed_js_number_to_dart',
      'avoid_legacy_jsboolean_return_assumptions',
      'prefer_string_for_typeof_equals',
      'prefer_int_for_jsarray_with_length',
      'avoid_deprecated_file_system_delete_event_is_directory',
      'avoid_removed_null_thrown_error',
      'avoid_removed_render_object_element_methods',
      'avoid_deprecated_use_inherited_media_query',
      'prefer_scrollbar_theme_of',
      'avoid_deprecated_animated_list_typedefs',
      'avoid_removed_appbar_backwards_compatibility',
      'avoid_deprecated_flutter_test_window',
      'avoid_deprecated_use_material3_copy_with',
      'prefer_utf8_encode',
      'prefer_key_event',
      'prefer_platform_menu_bar_child',
      'prefer_keepalive_dispose',
      'prefer_context_menu_builder',
      'prefer_pan_axis',
      'prefer_m3_text_theme',
      'prefer_overflow_bar_over_button_bar',
      'prefer_iterable_cast',
      'prefer_button_style_icon_alignment',
      'avoid_deprecated_on_surface_destroyed',
      'prefer_tabbar_theme_indicator_color',
      'prefer_dropdown_menu_item_button_opacity_animation',
      'prefer_dropdown_initial_value',
      'prefer_on_pop_with_result',
      'avoid_asset_manifest_json',
    };

    expect(sdkRuleCodes, containsAll(expected));
  });

  test('sdk-pack migration codes exist in migration source files', () {
    final sdkRuleCodes = _sdkPackRuleCodes();
    final migrationSources = <String>{
      'lib/src/rules/config/migration_rules.dart',
      'lib/src/rules/config/flutter_sdk_migration_rules.dart',
      'lib/src/rules/config/sdk_migration_batch2_rules.dart',
      'lib/src/rules/config/dart_sdk_3_removal_rules.dart',
      'lib/src/rules/config/dart_sdk_34_deprecation_rules.dart',
    };
    final migrationCodes = <String>{};
    for (final file in migrationSources) {
      migrationCodes.addAll(_lintCodesFromFile(file));
    }

    final missingFromMigrationSources = sdkRuleCodes.difference(migrationCodes);
    expect(
      missingFromMigrationSources,
      isEmpty,
      reason:
          'Every SDK-pack migration code should map to a real migration lint.',
    );
  });
}

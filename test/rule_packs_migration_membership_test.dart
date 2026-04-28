import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

void main() {
  test('key migration rules are assigned to sdk packs', () {
    final sdkPackIds = kRulePackRuleCodes.keys.where(
      (id) => id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_'),
    );

    final sdkRuleCodes = <String>{};
    for (final id in sdkPackIds) {
      sdkRuleCodes.addAll(kRulePackRuleCodes[id] ?? const <String>{});
    }

    // Representative guardrail list across multiple Flutter/Dart releases.
    const expected = <String>{
      'avoid_removed_js_number_to_dart',
      'prefer_int_for_jsarray_with_length',
      'avoid_removed_render_object_element_methods',
      'avoid_deprecated_use_inherited_media_query',
      'avoid_deprecated_animated_list_typedefs',
      'avoid_removed_appbar_backwards_compatibility',
      'avoid_deprecated_flutter_test_window',
      'avoid_deprecated_use_material3_copy_with',
      'prefer_utf8_encode',
      'prefer_key_event',
      'prefer_m3_text_theme',
      'prefer_overflow_bar_over_button_bar',
      'avoid_deprecated_on_surface_destroyed',
      'prefer_tabbar_theme_indicator_color',
      'prefer_dropdown_initial_value',
      'avoid_asset_manifest_json',
    };

    expect(sdkRuleCodes, containsAll(expected));
  });
}

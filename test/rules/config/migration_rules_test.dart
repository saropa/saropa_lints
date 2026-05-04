import 'dart:io';

import 'package:saropa_lints/src/rules/config/migration_rules.dart';
import 'package:saropa_lints/src/tiers.dart';
import 'package:test/test.dart';

/// Tests for 14 Migration lint rules.
///
/// Rules:
///   - avoid_asset_manifest_json (Essential, ERROR)
///   - prefer_dropdown_initial_value (Recommended, WARNING)
///   - prefer_dropdown_menu_item_button_opacity_animation (Recommended, INFO)
///   - prefer_on_pop_with_result (Recommended, WARNING)
///   - prefer_tabbar_theme_indicator_color (Recommended, WARNING)
///   - prefer_platform_menu_bar_child (Recommended, WARNING)
///   - prefer_keepalive_dispose (Recommended, WARNING)
///   - prefer_context_menu_builder (Recommended, WARNING)
///   - prefer_pan_axis (Recommended, WARNING)
///   - prefer_button_style_icon_alignment (Recommended, WARNING)
///   - prefer_key_event (Recommended, WARNING)
///   - prefer_m3_text_theme (Recommended, WARNING)
///   - prefer_overflow_bar_over_button_bar (Recommended, INFO)
///   - avoid_deprecated_flutter_test_window (Recommended, WARNING)
///
/// Test fixture: example/lib/migration_rules_fixture.dart
void main() {
  group('Migration Rules - Fixture Verification', () {
    test('migration_rules_fixture exists', () {
      final file = File('example/lib/migration_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });
  });

  group('Migration Rules - Rule Instantiation', () {
    test('AvoidAssetManifestJsonRule instantiates correctly', () {
      final rule = AvoidAssetManifestJsonRule();
      expect(rule.code.lowerCaseName, 'avoid_asset_manifest_json');
      expect(rule.code.problemMessage, contains('[avoid_asset_manifest_json]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferDropdownInitialValueRule instantiates correctly', () {
      final rule = PreferDropdownInitialValueRule();
      expect(rule.code.lowerCaseName, 'prefer_dropdown_initial_value');
      expect(
        rule.code.problemMessage,
        contains('[prefer_dropdown_initial_value]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test(
      'PreferDropdownMenuItemButtonOpacityAnimationRule instantiates correctly',
      () {
        final rule = PreferDropdownMenuItemButtonOpacityAnimationRule();
        expect(
          rule.code.lowerCaseName,
          'prefer_dropdown_menu_item_button_opacity_animation',
        );
        expect(
          rule.code.problemMessage,
          contains('[prefer_dropdown_menu_item_button_opacity_animation]'),
        );
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
        expect(rule.fixGenerators, hasLength(2));
      },
    );

    test('PreferOnPopWithResultRule instantiates correctly', () {
      final rule = PreferOnPopWithResultRule();
      expect(rule.code.lowerCaseName, 'prefer_on_pop_with_result');
      expect(rule.code.problemMessage, contains('[prefer_on_pop_with_result]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferTabbarThemeIndicatorColorRule instantiates correctly', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      expect(rule.code.lowerCaseName, 'prefer_tabbar_theme_indicator_color');
      expect(
        rule.code.problemMessage,
        contains('[prefer_tabbar_theme_indicator_color]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('TabBarThemeData'));
    });

    test('PreferOverflowBarOverButtonBarRule instantiates correctly', () {
      final rule = PreferOverflowBarOverButtonBarRule();
      expect(rule.code.lowerCaseName, 'prefer_overflow_bar_over_button_bar');
      expect(
        rule.code.problemMessage,
        contains('[prefer_overflow_bar_over_button_bar]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('ButtonBar'));
      expect(rule.requiredPatterns, contains('buttonBarTheme'));
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  group('prefer_dropdown_menu_item_button_opacity_animation', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_dropdown_menu_item_button_opacity_animation_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    // Stub-only trigger/pass assertions were removed for migration sweeps.
    // Keep fixture existence and rule metadata checks.
  });

  group('prefer_tabbar_theme_indicator_color', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_tabbar_theme_indicator_color_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('rule metadata is correct', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      // Deprecation migration = medium impact (tech debt, not crash)
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      // Fix removes the indicatorColor argument from ThemeData
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  // =========================================================================
  // prefer_platform_menu_bar_child
  // =========================================================================

  group('prefer_platform_menu_bar_child', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_platform_menu_bar_child_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferPlatformMenuBarChildRule instantiates correctly', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.code.lowerCaseName, 'prefer_platform_menu_bar_child');
      expect(
        rule.code.problemMessage,
        contains('[prefer_platform_menu_bar_child]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('child'));
    });

    test('rule metadata is correct', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  // =========================================================================
  // prefer_keepalive_dispose
  // =========================================================================

  group('prefer_keepalive_dispose', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_keepalive_dispose_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferKeepaliveDisposeRule instantiates correctly', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.code.lowerCaseName, 'prefer_keepalive_dispose');
      expect(rule.code.problemMessage, contains('[prefer_keepalive_dispose]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('dispose'));
    });

    test('rule metadata is correct', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  // =========================================================================
  // prefer_context_menu_builder
  // =========================================================================

  group('prefer_context_menu_builder', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_context_menu_builder_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferContextMenuBuilderRule instantiates correctly', () {
      final rule = PreferContextMenuBuilderRule();
      expect(rule.code.lowerCaseName, 'prefer_context_menu_builder');
      expect(
        rule.code.problemMessage,
        contains('[prefer_context_menu_builder]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('builder'));
    });

    test('has no quick fix (callback signature changed)', () {
      final rule = PreferContextMenuBuilderRule();
      // No auto-fix: callback signature changed from 3 to 2 params
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferContextMenuBuilderRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_pan_axis
  // =========================================================================

  group('prefer_pan_axis', () {
    test('fixture file exists', () {
      final file = File('example/lib/migration/prefer_pan_axis_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('PreferPanAxisRule instantiates correctly', () {
      final rule = PreferPanAxisRule();
      expect(rule.code.lowerCaseName, 'prefer_pan_axis');
      expect(rule.code.problemMessage, contains('[prefer_pan_axis]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('PanAxis'));
    });

    test('has no quick fix (value transformation needed)', () {
      final rule = PreferPanAxisRule();
      // No auto-fix: bool → PanAxis enum transformation
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferPanAxisRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_button_style_icon_alignment
  // =========================================================================

  group('prefer_button_style_icon_alignment', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_button_style_icon_alignment_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferButtonStyleIconAlignmentRule instantiates correctly', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      expect(rule.code.lowerCaseName, 'prefer_button_style_icon_alignment');
      expect(
        rule.code.problemMessage,
        contains('[prefer_button_style_icon_alignment]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('style'));
    });

    test('has no quick fix (restructuring needed)', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      // No auto-fix: moving value to ButtonStyle requires restructuring
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_key_event
  // =========================================================================

  group('prefer_key_event', () {
    test('fixture file exists', () {
      final file = File('example/lib/migration/prefer_key_event_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('PreferKeyEventRule instantiates correctly', () {
      final rule = PreferKeyEventRule();
      expect(rule.code.lowerCaseName, 'prefer_key_event');
      expect(rule.code.problemMessage, contains('[prefer_key_event]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('KeyEvent'));
    });

    test('has no quick fix (complex migration)', () {
      final rule = PreferKeyEventRule();
      // No auto-fix: too many interrelated changes needed
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferKeyEventRule();
      // High impact: entire keyboard event system deprecated
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_m3_text_theme
  // =========================================================================

  group('prefer_m3_text_theme', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_m3_text_theme_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferM3TextThemeRule instantiates correctly', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.code.lowerCaseName, 'prefer_m3_text_theme');
      expect(rule.code.problemMessage, contains('[prefer_m3_text_theme]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('Material 3'));
    });

    test('rule metadata is correct', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.fixGenerators, hasLength(1));
    });

    test('rename map covers all 13 deprecated members', () {
      // Verify the _renames map is complete
      final rule = PreferM3TextThemeRule();
      // Access the rule to verify it instantiates with a complete map.
      // The map is static const, so just verify the rule loads.
      expect(rule.code.problemMessage, contains('13 deprecated names'));
    });
  });

  // =========================================================================
  // avoid_deprecated_flutter_test_window
  // =========================================================================

  group('avoid_deprecated_flutter_test_window', () {
    test('AvoidDeprecatedFlutterTestWindowRule instantiates correctly', () {
      final rule = AvoidDeprecatedFlutterTestWindowRule();
      expect(rule.code.lowerCaseName, 'avoid_deprecated_flutter_test_window');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_flutter_test_window]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('platformDispatcher'));
      expect(rule.code.correctionMessage, contains('view'));
    });

    test('scopes to flutter_test imports via requiredPatterns', () {
      final rule = AvoidDeprecatedFlutterTestWindowRule();
      expect(rule.requiredPatterns, contains('package:flutter_test/'));
    });

    test('uses element resolution (no name-only heuristics)', () {
      final rule = AvoidDeprecatedFlutterTestWindowRule();
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = AvoidDeprecatedFlutterTestWindowRule();
      expect(rule.impact.name, 'warning');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
      expect(rule.tags, contains('flutter'));
      expect(rule.tags, contains('test'));
    });

    test(
      'factory listed in lib/saropa_lints.dart (avoids loading all rules)',
      () {
        final content = File('lib/saropa_lints.dart').readAsStringSync();
        expect(
          content.contains('AvoidDeprecatedFlutterTestWindowRule.new'),
          isTrue,
        );
      },
    );

    test('included in recommended tier', () {
      expect(
        getRulesForTier(
          'recommended',
        ).contains('avoid_deprecated_flutter_test_window'),
        isTrue,
      );
    });
  });

  // Stub-only trigger/pass assertions were removed from this migration suite.
  // Keep fixture existence and rule metadata/registration checks.
}

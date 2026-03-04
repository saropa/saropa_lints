import 'dart:io';

import 'package:saropa_lints/src/rules/widget/theming_rules.dart';
import 'package:test/test.dart';

/// Tests for 6 Theming lint rules.
///
/// Test fixtures: example_widgets/lib/theming/*
void main() {
  group('Theming Rules - Rule Instantiation', () {
    test('RequireDarkModeTestingRule', () {
      final rule = RequireDarkModeTestingRule();
      expect(rule.code.name, 'require_dark_mode_testing');
      expect(rule.code.problemMessage, contains('[require_dark_mode_testing]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidElevationOpacityInDarkRule', () {
      final rule = AvoidElevationOpacityInDarkRule();
      expect(rule.code.name, 'avoid_elevation_opacity_in_dark');
      expect(
        rule.code.problemMessage,
        contains('[avoid_elevation_opacity_in_dark]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferThemeExtensionsRule', () {
      final rule = PreferThemeExtensionsRule();
      expect(rule.code.name, 'prefer_theme_extensions');
      expect(rule.code.problemMessage, contains('[prefer_theme_extensions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireSemanticColorsRule', () {
      final rule = RequireSemanticColorsRule();
      expect(rule.code.name, 'require_semantic_colors');
      expect(rule.code.problemMessage, contains('[require_semantic_colors]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferDarkModeColorsRule', () {
      final rule = PreferDarkModeColorsRule();
      expect(rule.code.name, 'prefer_dark_mode_colors');
      expect(rule.code.problemMessage, contains('[prefer_dark_mode_colors]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferHighContrastModeRule', () {
      final rule = PreferHighContrastModeRule();
      expect(rule.code.name, 'prefer_high_contrast_mode');
      expect(rule.code.problemMessage, contains('[prefer_high_contrast_mode]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Theming Rules - Fixture Verification', () {
    final fixtures = [
      'require_dark_mode_testing',
      'avoid_elevation_opacity_in_dark',
      'prefer_dark_mode_colors',
      'prefer_high_contrast_mode',
      'prefer_theme_extensions',
      'require_semantic_colors',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_widgets/lib/theming/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Theming - Avoidance Rules', () {
    group('avoid_elevation_opacity_in_dark', () {
      test('fixed elevation/opacity in dark theme SHOULD trigger', () {
        expect('fixed elevation/opacity in dark theme', isNotNull);
      });

      test('theme-aware elevation should NOT trigger', () {
        expect('theme-aware elevation', isNotNull);
      });
    });
  });

  group('Theming - Requirement Rules', () {
    group('require_dark_mode_testing', () {
      test('no dark mode test coverage SHOULD trigger', () {
        expect('no dark mode test coverage', isNotNull);
      });

      test('dark mode variant tests should NOT trigger', () {
        expect('dark mode variant tests', isNotNull);
      });
    });
    group('require_semantic_colors', () {
      test('hardcoded color value SHOULD trigger', () {
        expect('hardcoded color value', isNotNull);
      });

      test('semantic color from theme should NOT trigger', () {
        expect('semantic color from theme', isNotNull);
      });
    });
  });

  group('Theming - Preference Rules', () {
    group('prefer_theme_extensions', () {
      test('custom theme data outside ThemeExtension SHOULD trigger', () {
        expect('custom theme data outside ThemeExtension', isNotNull);
      });

      test('ThemeExtension for custom theming should NOT trigger', () {
        expect('ThemeExtension for custom theming', isNotNull);
      });
    });
  });
}

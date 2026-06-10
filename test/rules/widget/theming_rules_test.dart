import 'dart:io';

import 'package:saropa_lints/src/rules/widget/theming_rules.dart';
import 'package:test/test.dart';

/// Tests for 6 Theming lint rules.
///
/// Test fixtures: example/lib/theming/*
void main() {
  group('Theming Rules - Rule Instantiation', () {
    test('RequireDarkModeTestingRule', () {
      final rule = RequireDarkModeTestingRule();
      expect(rule.code.lowerCaseName, 'require_dark_mode_testing');
      expect(rule.code.problemMessage, contains('[require_dark_mode_testing]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidElevationOpacityInDarkRule', () {
      final rule = AvoidElevationOpacityInDarkRule();
      expect(rule.code.lowerCaseName, 'avoid_elevation_opacity_in_dark');
      expect(
        rule.code.problemMessage,
        contains('[avoid_elevation_opacity_in_dark]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferThemeExtensionsRule', () {
      final rule = PreferThemeExtensionsRule();
      expect(rule.code.lowerCaseName, 'prefer_theme_extensions');
      expect(rule.code.problemMessage, contains('[prefer_theme_extensions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireSemanticColorsRule', () {
      final rule = RequireSemanticColorsRule();
      expect(rule.code.lowerCaseName, 'require_semantic_colors');
      expect(rule.code.problemMessage, contains('[require_semantic_colors]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferDarkModeColorsRule', () {
      final rule = PreferDarkModeColorsRule();
      expect(rule.code.lowerCaseName, 'prefer_dark_mode_colors');
      expect(rule.code.problemMessage, contains('[prefer_dark_mode_colors]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferHighContrastModeRule', () {
      final rule = PreferHighContrastModeRule();
      expect(rule.code.lowerCaseName, 'prefer_high_contrast_mode');
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
        final file = File('example/lib/theming/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}

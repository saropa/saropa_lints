import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_widget_rules.dart';

/// Tests for 13 Stylistic Widget lint rules.
///
/// Test fixtures: example/lib/stylistic_widget/*
void main() {
  group('Stylistic Widget Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferSizedBoxOverContainerRule',
      'prefer_sizedbox_over_container',
      () => PreferSizedBoxOverContainerRule(),
    );

    testRule(
      'PreferContainerOverSizedBoxRule',
      'prefer_container_over_sizedbox',
      () => PreferContainerOverSizedBoxRule(),
    );

    testRule(
      'PreferTextRichOverRichTextRule',
      'prefer_text_rich_over_richtext',
      () => PreferTextRichOverRichTextRule(),
    );

    testRule(
      'PreferRichTextOverTextRichRule',
      'prefer_richtext_over_text_rich',
      () => PreferRichTextOverTextRichRule(),
    );

    testRule(
      'PreferEdgeInsetsSymmetricRule',
      'prefer_edgeinsets_symmetric',
      () => PreferEdgeInsetsSymmetricRule(),
    );

    testRule(
      'PreferEdgeInsetsOnlyRule',
      'prefer_edgeinsets_only',
      () => PreferEdgeInsetsOnlyRule(),
    );

    testRule(
      'PreferBorderRadiusCircularRule',
      'prefer_borderradius_circular',
      () => PreferBorderRadiusCircularRule(),
    );

    testRule(
      'PreferExpandedOverFlexibleRule',
      'prefer_expanded_over_flexible',
      () => PreferExpandedOverFlexibleRule(),
    );

    testRule(
      'PreferFlexibleOverExpandedRule',
      'prefer_flexible_over_expanded',
      () => PreferFlexibleOverExpandedRule(),
    );

    testRule(
      'PreferMaterialThemeColorsRule',
      'prefer_material_theme_colors',
      () => PreferMaterialThemeColorsRule(),
    );

    testRule(
      'PreferExplicitColorsRule',
      'prefer_explicit_colors',
      () => PreferExplicitColorsRule(),
    );

    testRule(
      'PreferClipRSuperellipseRule',
      'prefer_clip_r_superellipse',
      () => PreferClipRSuperellipseRule(),
    );

    testRule(
      'PreferClipRSuperellipseClipperRule',
      'prefer_clip_r_superellipse_clipper',
      () => PreferClipRSuperellipseClipperRule(),
    );
  });

  group('Stylistic Widget Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/stylistic_widget');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_widget/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}

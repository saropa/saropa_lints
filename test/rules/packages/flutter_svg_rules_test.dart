import 'dart:io';

import 'package:saropa_lints/src/rules/packages/flutter_svg_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for 5 flutter_svg lint rules.
///
/// Test fixtures: example_packages/lib/flutter_svg/flutter_svg_fixture.dart
void main() {
  group('FlutterSvg Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferSvgColorFilterRule',
      'prefer_svg_color_filter',
      () => PreferSvgColorFilterRule(),
    );

    testRule(
      'SvgNetworkMissingErrorBuilderRule',
      'svg_network_missing_error_builder',
      () => SvgNetworkMissingErrorBuilderRule(),
    );

    testRule(
      'SvgNetworkMissingPlaceholderRule',
      'svg_network_missing_placeholder',
      () => SvgNetworkMissingPlaceholderRule(),
    );

    testRule(
      'SvgMissingSemanticsLabelRule',
      'svg_missing_semantics_label',
      () => SvgMissingSemanticsLabelRule(),
    );

    testRule(
      'SvgStringMissingErrorBuilderRule',
      'svg_string_missing_error_builder',
      () => SvgStringMissingErrorBuilderRule(),
    );
  });

  group('FlutterSvg Rules - Fix Registration', () {
    test('PreferSvgColorFilterRule has fixGenerators', () {
      final rule = PreferSvgColorFilterRule();
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('SvgNetworkMissingErrorBuilderRule has no fix (report-only)', () {
      final rule = SvgNetworkMissingErrorBuilderRule();
      expect(rule.fixGenerators, isEmpty);
    });

    test('SvgNetworkMissingPlaceholderRule has no fix (report-only)', () {
      final rule = SvgNetworkMissingPlaceholderRule();
      expect(rule.fixGenerators, isEmpty);
    });

    test('SvgMissingSemanticsLabelRule has no fix (report-only)', () {
      final rule = SvgMissingSemanticsLabelRule();
      expect(rule.fixGenerators, isEmpty);
    });

    test('SvgStringMissingErrorBuilderRule has no fix (report-only)', () {
      final rule = SvgStringMissingErrorBuilderRule();
      expect(rule.fixGenerators, isEmpty);
    });
  });

  group('FlutterSvg Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/flutter_svg');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/flutter_svg/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('FlutterSvg Rules - Metadata', () {
    test('PreferSvgColorFilterRule has packages tag', () {
      final rule = PreferSvgColorFilterRule();
      expect(rule.tags, contains('packages'));
    });

    test('SvgNetworkMissingErrorBuilderRule has packages tag', () {
      final rule = SvgNetworkMissingErrorBuilderRule();
      expect(rule.tags, contains('packages'));
    });

    test('SvgNetworkMissingPlaceholderRule has packages tag', () {
      final rule = SvgNetworkMissingPlaceholderRule();
      expect(rule.tags, contains('packages'));
    });

    test('SvgMissingSemanticsLabelRule has packages tag', () {
      final rule = SvgMissingSemanticsLabelRule();
      expect(rule.tags, contains('packages'));
    });

    test('SvgStringMissingErrorBuilderRule has packages tag', () {
      final rule = SvgStringMissingErrorBuilderRule();
      expect(rule.tags, contains('packages'));
    });
  });
}

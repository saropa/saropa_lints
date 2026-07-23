import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/flutter_animate_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for the 6 flutter_animate lint rules.
///
/// Test fixtures: example_packages/lib/flutter_animate/flutter_animate_fixture.dart
void main() {
  group('FlutterAnimate Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason: 'Problem message must exceed 200 characters',
        );
        expect(rule.code.correctionMessage, isNotNull);
        expect(rule.tags, contains('packages'));
      });
    }

    testRule(
      'FlutterAnimateUnconditionalRepeatInOnPlayRule',
      'flutter_animate_unconditional_repeat_in_on_play',
      FlutterAnimateUnconditionalRepeatInOnPlayRule.new,
    );

    testRule(
      'FlutterAnimateRestartOnHotReloadInReleaseRule',
      'flutter_animate_restart_on_hot_reload_in_release',
      FlutterAnimateRestartOnHotReloadInReleaseRule.new,
    );

    testRule(
      'FlutterAnimateNoKeyInListRule',
      'flutter_animate_no_key_in_list',
      FlutterAnimateNoKeyInListRule.new,
    );

    testRule(
      'FlutterAnimateEmptyAnimateListRule',
      'flutter_animate_empty_animate_list',
      FlutterAnimateEmptyAnimateListRule.new,
    );

    testRule(
      'FlutterAnimateFixedTargetLiteralRule',
      'flutter_animate_fixed_target_literal',
      FlutterAnimateFixedTargetLiteralRule.new,
    );

    testRule(
      'FlutterAnimateAutoPlayFalseNoDriverRule',
      'flutter_animate_auto_play_false_no_driver',
      FlutterAnimateAutoPlayFalseNoDriverRule.new,
    );
  });

  group('FlutterAnimate Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/flutter_animate');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/flutter_animate/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

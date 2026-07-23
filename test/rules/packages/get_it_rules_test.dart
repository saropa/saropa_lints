import 'dart:io';

import 'package:saropa_lints/src/rules/packages/get_it_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 GetIt lint rules.
///
/// Test fixtures: example_packages/lib/get_it/*
void main() {
  group('GetIt Rules - Rule Instantiation', () {
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
      'AvoidGetItInBuildRule',
      'avoid_getit_in_build',
      () => AvoidGetItInBuildRule(),
    );
    testRule(
      'RequireGetItRegistrationOrderRule',
      'require_getit_registration_order',
      () => RequireGetItRegistrationOrderRule(),
    );
    testRule(
      'RequireGetItResetInTestsRule',
      'require_getit_reset_in_tests',
      () => RequireGetItResetInTestsRule(),
    );
  });
  group('GetIt Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/get_it');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/get_it/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}

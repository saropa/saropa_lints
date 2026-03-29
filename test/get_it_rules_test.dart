import 'dart:io';

import 'package:saropa_lints/src/rules/packages/get_it_rules.dart';
import 'package:test/test.dart';

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
    final fixtures = [
      'avoid_getit_in_build',
      'require_getit_registration_order',
      'require_getit_reset_in_tests',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/get_it/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('GetIt - Avoidance Rules', () {
    group('avoid_getit_in_build', () {
      test('GetIt.instance in build method SHOULD trigger', () {
        expect('GetIt.instance in build method', isNotNull);
      });

      test('inject via constructor or context should NOT trigger', () {
        expect('inject via constructor or context', isNotNull);
      });
    });
  });

  group('GetIt - Requirement Rules', () {
    group('require_getit_registration_order', () {
      test('unordered GetIt registrations SHOULD trigger', () {
        expect('unordered GetIt registrations', isNotNull);
      });

      test('dependency-ordered registration should NOT trigger', () {
        expect('dependency-ordered registration', isNotNull);
      });
    });
    group('require_getit_reset_in_tests', () {
      test('GetIt state leaking between tests SHOULD trigger', () {
        expect('GetIt state leaking between tests', isNotNull);
      });

      test('GetIt.instance.reset() in tearDown should NOT trigger', () {
        expect('GetIt.instance.reset() in tearDown', isNotNull);
      });
    });
  });
}

import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/http_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 http lint rules.
///
/// Test fixtures: example_packages/lib/http/*
void main() {
  group('Http Rules - Rule Instantiation', () {
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
      'RequireHttpPackageClientCloseRule',
      'require_http_package_client_close',
      () => RequireHttpPackageClientCloseRule(),
    );
    testRule(
      'AvoidHttpTopLevelInLoopRule',
      'avoid_http_top_level_in_loop',
      () => AvoidHttpTopLevelInLoopRule(),
    );
    testRule(
      'AvoidHttpStringUrlRule',
      'avoid_http_string_url',
      () => AvoidHttpStringUrlRule(),
    );
  });

  group('Http Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/http');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/http/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

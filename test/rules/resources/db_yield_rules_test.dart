import 'dart:io';

import 'package:saropa_lints/src/rules/resources/db_yield_rules.dart';
import 'package:test/test.dart';

/// Tests for 3 Database Yield lint rules.
///
/// Test fixtures: example/lib/db_yield/*
void main() {
  group('Database Yield Rules - Rule Instantiation', () {
    test('RequireYieldAfterDbWriteRule', () {
      final rule = RequireYieldAfterDbWriteRule();
      expect(rule.code.lowerCaseName, 'require_yield_after_db_write');
      expect(
        rule.code.problemMessage,
        contains('[require_yield_after_db_write]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('SuggestYieldAfterDbReadRule', () {
      final rule = SuggestYieldAfterDbReadRule();
      expect(rule.code.lowerCaseName, 'suggest_yield_after_db_read');
      expect(
        rule.code.problemMessage,
        contains('[suggest_yield_after_db_read]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturnAwaitDbRule', () {
      final rule = AvoidReturnAwaitDbRule();
      expect(rule.code.lowerCaseName, 'avoid_return_await_db');
      expect(rule.code.problemMessage, contains('[avoid_return_await_db]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Database Yield Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/db_yield');

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
      test('\$fixture fixture exists', () {
        final file = File('example/lib/db_yield/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

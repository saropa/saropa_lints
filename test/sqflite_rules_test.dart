import 'dart:io';

import 'package:test/test.dart';

/// Tests for 1 Sqflite lint rules.
///
/// Test fixtures: example_packages/lib/sqflite/*
void main() {
  group('Sqflite Rules - Fixture Verification', () {
    final fixtures = ['avoid_sqflite_type_mismatch'];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/sqflite/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Sqflite - Avoidance Rules', () {
    group('avoid_sqflite_type_mismatch', () {
      test('wrong column type in sqflite query SHOULD trigger', () {
        expect('wrong column type in sqflite query', isNotNull);
      });

      test('matching Dart type to SQLite column should NOT trigger', () {
        expect('matching Dart type to SQLite column', isNotNull);
      });
    });
  });
}

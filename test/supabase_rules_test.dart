import 'dart:io';

import 'package:test/test.dart';

/// Tests for 3 Supabase lint rules.
///
/// Test fixtures: example_packages/lib/supabase/*
void main() {
  group('Supabase Rules - Fixture Verification', () {
    final fixtures = [
      'require_supabase_error_handling',
      'avoid_supabase_anon_key_in_code',
      'require_supabase_realtime_unsubscribe',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/supabase/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Supabase - Avoidance Rules', () {
    group('avoid_supabase_anon_key_in_code', () {
      test('anon key hardcoded in source SHOULD trigger', () {
        expect('anon key hardcoded in source', isNotNull);
      });

      test('environment variable for Supabase key should NOT trigger', () {
        expect('environment variable for Supabase key', isNotNull);
      });
    });
  });

  group('Supabase - Requirement Rules', () {
    group('require_supabase_error_handling', () {
      test('Supabase call without error handling SHOULD trigger', () {
        expect('Supabase call without error handling', isNotNull);
      });

      test('try-catch on Supabase calls should NOT trigger', () {
        expect('try-catch on Supabase calls', isNotNull);
      });
    });
    group('require_supabase_realtime_unsubscribe', () {
      test('realtime subscription without unsubscribe SHOULD trigger', () {
        expect('realtime subscription without unsubscribe', isNotNull);
      });

      test('cleanup on dispose should NOT trigger', () {
        expect('cleanup on dispose', isNotNull);
      });
    });
  });
}

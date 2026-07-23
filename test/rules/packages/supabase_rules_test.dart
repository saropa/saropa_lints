import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/supabase_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 Supabase lint rules.
///
/// Test fixtures: example_packages/lib/supabase/*
void main() {
  group('Supabase Rules - Rule Instantiation', () {
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
      'RequireSupabaseErrorHandlingRule',
      'require_supabase_error_handling',
      () => RequireSupabaseErrorHandlingRule(),
    );

    testRule(
      'AvoidSupabaseAnonKeyInCodeRule',
      'avoid_supabase_anon_key_in_code',
      () => AvoidSupabaseAnonKeyInCodeRule(),
    );

    testRule(
      'RequireSupabaseRealtimeUnsubscribeRule',
      'require_supabase_realtime_unsubscribe',
      () => RequireSupabaseRealtimeUnsubscribeRule(),
    );
  });

  group('Supabase Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/supabase');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/supabase/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

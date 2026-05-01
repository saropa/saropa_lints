import 'dart:io';

import 'package:saropa_lints/src/rules/packages/shared_preferences_rules.dart';
import 'package:test/test.dart';

/// Tests for 12 Shared Preferences lint rules.
///
/// Test fixtures: example_packages/lib/shared_preferences/*
void main() {
  group('Shared Preferences Rules - Rule Instantiation', () {
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
      'AvoidPrefsForLargeDataRule',
      'avoid_prefs_for_large_data',
      () => AvoidPrefsForLargeDataRule(),
    );

    testRule(
      'RequireSharedPrefsPrefixRule',
      'require_shared_prefs_prefix',
      () => RequireSharedPrefsPrefixRule(),
    );

    testRule(
      'PreferSharedPrefsAsyncApiRule',
      'prefer_shared_prefs_async_api',
      () => PreferSharedPrefsAsyncApiRule(),
    );

    testRule(
      'AvoidSharedPrefsInIsolateRule',
      'avoid_shared_prefs_in_isolate',
      () => AvoidSharedPrefsInIsolateRule(),
    );

    testRule(
      'PreferTypedPrefsWrapperRule',
      'prefer_typed_prefs_wrapper',
      () => PreferTypedPrefsWrapperRule(),
    );

    testRule(
      'AvoidAuthStateInPrefsRule',
      'avoid_auth_state_in_prefs',
      () => AvoidAuthStateInPrefsRule(),
    );

    testRule(
      'PreferEncryptedPrefsRule',
      'prefer_encrypted_prefs',
      () => PreferEncryptedPrefsRule(),
    );

    testRule(
      'AvoidSharedPrefsSensitiveDataRule',
      'avoid_shared_prefs_sensitive_data',
      () => AvoidSharedPrefsSensitiveDataRule(),
    );

    testRule(
      'RequireSharedPrefsNullHandlingRule',
      'require_shared_prefs_null_handling',
      () => RequireSharedPrefsNullHandlingRule(),
    );

    testRule(
      'RequireSharedPrefsKeyConstantsRule',
      'require_shared_prefs_key_constants',
      () => RequireSharedPrefsKeyConstantsRule(),
    );

    testRule(
      'AvoidSharedPrefsLargeDataRule',
      'avoid_shared_prefs_large_data',
      () => AvoidSharedPrefsLargeDataRule(),
    );

    testRule(
      'AvoidSharedPrefsSyncRaceRule',
      'avoid_shared_prefs_sync_race',
      () => AvoidSharedPrefsSyncRaceRule(),
    );
  });

  group('Shared Preferences Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_prefs_for_large_data',
      'require_shared_prefs_prefix',
      'prefer_shared_prefs_async_api',
      'avoid_shared_prefs_in_isolate',
      'prefer_typed_prefs_wrapper',
      'avoid_auth_state_in_prefs',
      'prefer_encrypted_prefs',
      'avoid_shared_prefs_sensitive_data',
      'require_shared_prefs_null_handling',
      'require_shared_prefs_key_constants',
      'avoid_shared_prefs_large_data',
      'avoid_shared_prefs_sync_race',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/shared_preferences/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests removed; keep rule metadata and fixture checks.
}

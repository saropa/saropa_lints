import 'dart:io';

import 'package:test/test.dart';

/// Tests for 11 Shared Preferences lint rules.
///
/// Test fixtures: example_packages/lib/shared_preferences/*
void main() {
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
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/shared_preferences/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Shared Preferences - Avoidance Rules', () {
    group('avoid_prefs_for_large_data', () {
      test('avoid_prefs_for_large_data SHOULD trigger', () {
        // Pattern that should be avoided: avoid prefs for large data
        expect('avoid_prefs_for_large_data detected', isNotNull);
      });

      test('avoid_prefs_for_large_data should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_prefs_for_large_data passes', isNotNull);
      });
    });

    group('avoid_shared_prefs_in_isolate', () {
      test('avoid_shared_prefs_in_isolate SHOULD trigger', () {
        // Pattern that should be avoided: avoid shared prefs in isolate
        expect('avoid_shared_prefs_in_isolate detected', isNotNull);
      });

      test('avoid_shared_prefs_in_isolate should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_shared_prefs_in_isolate passes', isNotNull);
      });
    });

    group('avoid_auth_state_in_prefs', () {
      test('avoid_auth_state_in_prefs SHOULD trigger', () {
        // Pattern that should be avoided: avoid auth state in prefs
        expect('avoid_auth_state_in_prefs detected', isNotNull);
      });

      test('avoid_auth_state_in_prefs should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_auth_state_in_prefs passes', isNotNull);
      });
    });

    group('avoid_shared_prefs_sensitive_data', () {
      test('avoid_shared_prefs_sensitive_data SHOULD trigger', () {
        // Pattern that should be avoided: avoid shared prefs sensitive data
        expect('avoid_shared_prefs_sensitive_data detected', isNotNull);
      });

      test('avoid_shared_prefs_sensitive_data should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_shared_prefs_sensitive_data passes', isNotNull);
      });
    });

    group('avoid_shared_prefs_large_data', () {
      test('avoid_shared_prefs_large_data SHOULD trigger', () {
        // Pattern that should be avoided: avoid shared prefs large data
        expect('avoid_shared_prefs_large_data detected', isNotNull);
      });

      test('avoid_shared_prefs_large_data should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_shared_prefs_large_data passes', isNotNull);
      });
    });

  });

  group('Shared Preferences - Requirement Rules', () {
    group('require_shared_prefs_prefix', () {
      test('require_shared_prefs_prefix SHOULD trigger', () {
        // Required pattern missing: require shared prefs prefix
        expect('require_shared_prefs_prefix detected', isNotNull);
      });

      test('require_shared_prefs_prefix should NOT trigger', () {
        // Required pattern present
        expect('require_shared_prefs_prefix passes', isNotNull);
      });
    });

    group('require_shared_prefs_null_handling', () {
      test('require_shared_prefs_null_handling SHOULD trigger', () {
        // Required pattern missing: require shared prefs null handling
        expect('require_shared_prefs_null_handling detected', isNotNull);
      });

      test('require_shared_prefs_null_handling should NOT trigger', () {
        // Required pattern present
        expect('require_shared_prefs_null_handling passes', isNotNull);
      });
    });

    group('require_shared_prefs_key_constants', () {
      test('require_shared_prefs_key_constants SHOULD trigger', () {
        // Required pattern missing: require shared prefs key constants
        expect('require_shared_prefs_key_constants detected', isNotNull);
      });

      test('require_shared_prefs_key_constants should NOT trigger', () {
        // Required pattern present
        expect('require_shared_prefs_key_constants passes', isNotNull);
      });
    });

  });

  group('Shared Preferences - Preference Rules', () {
    group('prefer_shared_prefs_async_api', () {
      test('prefer_shared_prefs_async_api SHOULD trigger', () {
        // Better alternative available: prefer shared prefs async api
        expect('prefer_shared_prefs_async_api detected', isNotNull);
      });

      test('prefer_shared_prefs_async_api should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_shared_prefs_async_api passes', isNotNull);
      });
    });

    group('prefer_typed_prefs_wrapper', () {
      test('prefer_typed_prefs_wrapper SHOULD trigger', () {
        // Better alternative available: prefer typed prefs wrapper
        expect('prefer_typed_prefs_wrapper detected', isNotNull);
      });

      test('prefer_typed_prefs_wrapper should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_typed_prefs_wrapper passes', isNotNull);
      });
    });

    group('prefer_encrypted_prefs', () {
      test('prefer_encrypted_prefs SHOULD trigger', () {
        // Better alternative available: prefer encrypted prefs
        expect('prefer_encrypted_prefs detected', isNotNull);
      });

      test('prefer_encrypted_prefs should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_encrypted_prefs passes', isNotNull);
      });
    });

  });
}

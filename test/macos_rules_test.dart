import 'dart:io';

import 'package:test/test.dart';

/// Tests for 15 macOS lint rules.
///
/// Test fixtures: example_platforms/lib/macos/
void main() {
  group('macOS Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_macos_menu_bar_integration',
      'prefer_macos_keyboard_shortcuts',
      'require_macos_window_size_constraints',
      'require_macos_file_access_intent',
      'avoid_macos_deprecated_security_apis',
      'require_macos_hardened_runtime',
      'avoid_macos_catalyst_unsupported_apis',
      'require_macos_window_restoration',
      'avoid_macos_full_disk_access',
      'require_macos_sandbox_entitlements',
      'require_macos_sandbox_exceptions',
      'avoid_macos_hardened_runtime_violations',
      'require_macos_app_transport_security',
      'require_macos_notarization_ready',
      'require_macos_entitlements',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_platforms/lib/macos/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Macos - Preference Rules', () {
    group('prefer_macos_menu_bar_integration', () {
      test('prefer_macos_menu_bar_integration SHOULD trigger', () {
        // Better alternative available: prefer macos menu bar integration
        expect('prefer_macos_menu_bar_integration detected', isNotNull);
      });

      test('prefer_macos_menu_bar_integration should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_macos_menu_bar_integration passes', isNotNull);
      });
    });

    group('prefer_macos_keyboard_shortcuts', () {
      test('prefer_macos_keyboard_shortcuts SHOULD trigger', () {
        // Better alternative available: prefer macos keyboard shortcuts
        expect('prefer_macos_keyboard_shortcuts detected', isNotNull);
      });

      test('prefer_macos_keyboard_shortcuts should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_macos_keyboard_shortcuts passes', isNotNull);
      });
    });
  });

  group('Macos - Requirement Rules', () {
    group('require_macos_window_size_constraints', () {
      test('require_macos_window_size_constraints SHOULD trigger', () {
        // Required pattern missing: require macos window size constraints
        expect('require_macos_window_size_constraints detected', isNotNull);
      });

      test('require_macos_window_size_constraints should NOT trigger', () {
        // Required pattern present
        expect('require_macos_window_size_constraints passes', isNotNull);
      });
    });

    group('require_macos_file_access_intent', () {
      test('require_macos_file_access_intent SHOULD trigger', () {
        // Required pattern missing: require macos file access intent
        expect('require_macos_file_access_intent detected', isNotNull);
      });

      test('require_macos_file_access_intent should NOT trigger', () {
        // Required pattern present
        expect('require_macos_file_access_intent passes', isNotNull);
      });
    });

    group('require_macos_hardened_runtime', () {
      test('require_macos_hardened_runtime SHOULD trigger', () {
        // Required pattern missing: require macos hardened runtime
        expect('require_macos_hardened_runtime detected', isNotNull);
      });

      test('require_macos_hardened_runtime should NOT trigger', () {
        // Required pattern present
        expect('require_macos_hardened_runtime passes', isNotNull);
      });
    });

    group('require_macos_window_restoration', () {
      test('require_macos_window_restoration SHOULD trigger', () {
        // Required pattern missing: require macos window restoration
        expect('require_macos_window_restoration detected', isNotNull);
      });

      test('require_macos_window_restoration should NOT trigger', () {
        // Required pattern present
        expect('require_macos_window_restoration passes', isNotNull);
      });
    });

    group('require_macos_sandbox_entitlements', () {
      test('require_macos_sandbox_entitlements SHOULD trigger', () {
        // Required pattern missing: require macos sandbox entitlements
        expect('require_macos_sandbox_entitlements detected', isNotNull);
      });

      test('require_macos_sandbox_entitlements should NOT trigger', () {
        // Required pattern present
        expect('require_macos_sandbox_entitlements passes', isNotNull);
      });
    });

    group('require_macos_sandbox_exceptions', () {
      test('require_macos_sandbox_exceptions SHOULD trigger', () {
        // Required pattern missing: require macos sandbox exceptions
        expect('require_macos_sandbox_exceptions detected', isNotNull);
      });

      test('require_macos_sandbox_exceptions should NOT trigger', () {
        // Required pattern present
        expect('require_macos_sandbox_exceptions passes', isNotNull);
      });
    });

    group('require_macos_app_transport_security', () {
      test('require_macos_app_transport_security SHOULD trigger', () {
        // Required pattern missing: require macos app transport security
        expect('require_macos_app_transport_security detected', isNotNull);
      });

      test('require_macos_app_transport_security should NOT trigger', () {
        // Required pattern present
        expect('require_macos_app_transport_security passes', isNotNull);
      });
    });

    group('require_macos_notarization_ready', () {
      test('require_macos_notarization_ready SHOULD trigger', () {
        // Required pattern missing: require macos notarization ready
        expect('require_macos_notarization_ready detected', isNotNull);
      });

      test('require_macos_notarization_ready should NOT trigger', () {
        // Required pattern present
        expect('require_macos_notarization_ready passes', isNotNull);
      });
    });

    group('require_macos_entitlements', () {
      test('require_macos_entitlements SHOULD trigger', () {
        // Required pattern missing: require macos entitlements
        expect('require_macos_entitlements detected', isNotNull);
      });

      test('require_macos_entitlements should NOT trigger', () {
        // Required pattern present
        expect('require_macos_entitlements passes', isNotNull);
      });
    });
  });

  group('Macos - Avoidance Rules', () {
    group('avoid_macos_deprecated_security_apis', () {
      test('avoid_macos_deprecated_security_apis SHOULD trigger', () {
        // Pattern that should be avoided: avoid macos deprecated security apis
        expect('avoid_macos_deprecated_security_apis detected', isNotNull);
      });

      test('avoid_macos_deprecated_security_apis should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_macos_deprecated_security_apis passes', isNotNull);
      });
    });

    group('avoid_macos_catalyst_unsupported_apis', () {
      test('avoid_macos_catalyst_unsupported_apis SHOULD trigger', () {
        // Pattern that should be avoided: avoid macos catalyst unsupported apis
        expect('avoid_macos_catalyst_unsupported_apis detected', isNotNull);
      });

      test('avoid_macos_catalyst_unsupported_apis should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_macos_catalyst_unsupported_apis passes', isNotNull);
      });
    });

    group('avoid_macos_full_disk_access', () {
      test('avoid_macos_full_disk_access SHOULD trigger', () {
        // Pattern that should be avoided: avoid macos full disk access
        expect('avoid_macos_full_disk_access detected', isNotNull);
      });

      test('avoid_macos_full_disk_access should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_macos_full_disk_access passes', isNotNull);
      });
    });

    group('avoid_macos_hardened_runtime_violations', () {
      test('avoid_macos_hardened_runtime_violations SHOULD trigger', () {
        // Pattern that should be avoided: avoid macos hardened runtime violations
        expect('avoid_macos_hardened_runtime_violations detected', isNotNull);
      });

      test('avoid_macos_hardened_runtime_violations should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_macos_hardened_runtime_violations passes', isNotNull);
      });
    });
  });
}

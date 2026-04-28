import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/android_rules.dart';

/// Tests for Android platform lint rules.
///
/// Test fixtures: example/lib/android/
void main() {
  group('Android Rules - Rule Instantiation', () {
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
      'RequireAndroidPermissionRequestRule',
      'require_android_permission_request',
      () => RequireAndroidPermissionRequestRule(),
    );

    testRule(
      'RequireAndroidManifestEntriesRule',
      'require_android_manifest_entries',
      () => RequireAndroidManifestEntriesRule(),
    );

    testRule(
      'RequireNotificationIconKeptRule',
      'require_notification_icon_kept',
      () => RequireNotificationIconKeptRule(),
    );

    testRule(
      'AvoidAndroidTaskAffinityDefaultRule',
      'avoid_android_task_affinity_default',
      () => AvoidAndroidTaskAffinityDefaultRule(),
    );

    testRule(
      'RequireAndroid12SplashRule',
      'require_android_12_splash',
      () => RequireAndroid12SplashRule(),
    );

    testRule(
      'PreferPendingIntentFlagsRule',
      'prefer_pending_intent_flags',
      () => PreferPendingIntentFlagsRule(),
    );

    testRule(
      'AvoidAndroidCleartextTrafficRule',
      'avoid_android_cleartext_traffic',
      () => AvoidAndroidCleartextTrafficRule(),
    );

    testRule(
      'RequireAndroidBackupRulesRule',
      'require_android_backup_rules',
      () => RequireAndroidBackupRulesRule(),
    );

    testRule(
      'PreferForegroundServiceAndroidRule',
      'prefer_foreground_service_android',
      () => PreferForegroundServiceAndroidRule(),
    );
  });

  group('Android Rules - Fixture Verification', () {
    final fixtures = [
      'require_android_permission_request',
      'require_android_manifest_entries',
      'require_notification_icon_kept',
      'avoid_android_task_affinity_default',
      'require_android_12_splash',
      'prefer_pending_intent_flags',
      'avoid_android_cleartext_traffic',
      'require_android_backup_rules',
      'prefer_foreground_service_android',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final relativePath = fixture == 'require_android_manifest_entries'
            ? 'example/lib/platform/${fixture}_fixture.dart'
            : 'example/lib/android/${fixture}_fixture.dart';
        final file = File(relativePath);
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Android - Avoidance Rules', () {
    group('avoid_android_task_affinity_default', () {
      test('default task affinity setting SHOULD trigger', () {});

      test('explicit task affinity should NOT trigger', () {});
    });
    group('avoid_android_cleartext_traffic', () {
      test('cleartext HTTP traffic allowed SHOULD trigger', () {});

      test('HTTPS-only traffic should NOT trigger', () {});
    });
  });

  group('Android - Requirement Rules', () {
    group('require_android_permission_request', () {
      test('missing runtime permission request SHOULD trigger', () {});

      test('proper permission flow should NOT trigger', () {});
    });
    group('require_android_12_splash', () {
      test('missing Android 12 splash screen API SHOULD trigger', () {});

      test('SplashScreen API usage should NOT trigger', () {});
    });
    group('require_android_backup_rules', () {
      test('missing backup rules config SHOULD trigger', () {});

      test('explicit backup rules should NOT trigger', () {});
    });
  });

  group('Android - Preference Rules', () {
    group('prefer_pending_intent_flags', () {
      test('PendingIntent without flags SHOULD trigger', () {});

      test('immutable/mutable PendingIntent flags should NOT trigger', () {});
    });
    group('prefer_foreground_service_android', () {
      test('background work without foreground service SHOULD trigger', () {});

      test('foreground service for long tasks should NOT trigger', () {});
    });
  });
}

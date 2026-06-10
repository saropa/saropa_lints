import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/android_rules.dart';

/// Tests for Android platform lint rules.
///
/// Test fixtures: example/lib/android/
// Gradle, manifest, and platform channel snippets from example/lib/android.
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
}

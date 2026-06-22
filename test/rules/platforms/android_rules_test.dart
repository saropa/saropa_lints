import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/saropa_lints.dart';

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

    testRule(
      'RequireAndroidExactAlarmPermissionRule',
      'require_android_exact_alarm_permission',
      () => RequireAndroidExactAlarmPermissionRule(),
    );

    testRule(
      'RequireAndroidPartialMediaPermissionRule',
      'require_android_partial_media_permission',
      () => RequireAndroidPartialMediaPermissionRule(),
    );
  });

  // These two rules cross-check AndroidManifest.xml, which the example project
  // does not provide with the specific permissions needed to trigger them, so
  // there is no example/lib fixture (stub fixtures are banned). Pin tier
  // membership and message specifics instead.
  group('Android Rules - new platform-readiness rules', () {
    test('exact-alarm rule is in the essential cumulative tier', () {
      expect(
        getRulesForTier('essential'),
        contains('require_android_exact_alarm_permission'),
      );
    });

    test('exact-alarm message names both satisfying permissions', () {
      final msg = RequireAndroidExactAlarmPermissionRule().code.problemMessage;
      expect(msg, contains('SCHEDULE_EXACT_ALARM'));
      expect(msg, contains('USE_EXACT_ALARM'));
      expect(msg.length, greaterThan(200));
    });

    test('partial-media rule is advisory (info) and professional tier', () {
      final rule = RequireAndroidPartialMediaPermissionRule();
      expect(rule.impact, LintImpact.info);
      expect(
        getRulesForTier('professional'),
        contains('require_android_partial_media_permission'),
      );
    });
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

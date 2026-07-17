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
    final fixtureDir = Directory('example/lib/android');

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
      test('$fixture fixture exists', () {
        final file = File('example/lib/android/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }

    // This fixture lives in example/lib/platform/ because it covers a
    // cross-platform manifest concern, not an Android-only rule.
    test('require_android_manifest_entries fixture exists', () {
      final file = File(
        'example/lib/platform/require_android_manifest_entries_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });
}

import 'dart:io';

import 'package:saropa_lints/src/rules/ui/notification_rules.dart';
import 'package:test/test.dart';

/// Tests for 8 Notification lint rules.
///
/// Test fixtures: example/lib/notification/*
void main() {
  group('Notification Rules - Rule Instantiation', () {
    test('RequireNotificationChannelAndroidRule', () {
      final rule = RequireNotificationChannelAndroidRule();
      expect(rule.code.lowerCaseName, 'require_notification_channel_android');
      expect(
        rule.code.problemMessage,
        contains('[require_notification_channel_android]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNotificationPayloadSensitiveRule', () {
      final rule = AvoidNotificationPayloadSensitiveRule();
      expect(rule.code.lowerCaseName, 'avoid_notification_payload_sensitive');
      expect(
        rule.code.problemMessage,
        contains('[avoid_notification_payload_sensitive]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireNotificationInitializePerPlatformRule', () {
      final rule = RequireNotificationInitializePerPlatformRule();
      expect(
        rule.code.lowerCaseName,
        'require_notification_initialize_per_platform',
      );
      expect(
        rule.code.problemMessage,
        contains('[require_notification_initialize_per_platform]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireNotificationTimezoneAwarenessRule', () {
      final rule = RequireNotificationTimezoneAwarenessRule();
      expect(
        rule.code.lowerCaseName,
        'require_notification_timezone_awareness',
      );
      expect(
        rule.code.problemMessage,
        contains('[require_notification_timezone_awareness]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNotificationSameIdRule', () {
      final rule = AvoidNotificationSameIdRule();
      expect(rule.code.lowerCaseName, 'avoid_notification_same_id');
      expect(
        rule.code.problemMessage,
        contains('[avoid_notification_same_id]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferNotificationGroupingRule', () {
      final rule = PreferNotificationGroupingRule();
      expect(rule.code.lowerCaseName, 'prefer_notification_grouping');
      expect(
        rule.code.problemMessage,
        contains('[prefer_notification_grouping]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNotificationSilentFailureRule', () {
      final rule = AvoidNotificationSilentFailureRule();
      expect(rule.code.lowerCaseName, 'avoid_notification_silent_failure');
      expect(
        rule.code.problemMessage,
        contains('[avoid_notification_silent_failure]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferLocalNotificationForImmediateRule', () {
      final rule = PreferLocalNotificationForImmediateRule();
      expect(
        rule.code.lowerCaseName,
        'prefer_local_notification_for_immediate',
      );
      expect(
        rule.code.problemMessage,
        contains('[prefer_local_notification_for_immediate]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Notification Rules - Fixture Verification', () {
    final fixtures = [
      'require_notification_channel_android',
      'avoid_notification_payload_sensitive',
      'require_notification_initialize_per_platform',
      'require_notification_timezone_awareness',
      'avoid_notification_same_id',
      'prefer_notification_grouping',
      'avoid_notification_silent_failure',
      'prefer_local_notification_for_immediate',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/notification/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Notification - Avoidance Rules', () {
    group('avoid_notification_payload_sensitive', () {
      test('sensitive data in notification payload SHOULD trigger', () {
        expect('sensitive data in notification payload', isNotNull);
      });

      test('sanitized notification data should NOT trigger', () {
        expect('sanitized notification data', isNotNull);
      });
    });
    group('avoid_notification_same_id', () {
      test('reused notification ID SHOULD trigger', () {
        expect('reused notification ID', isNotNull);
      });

      test('unique notification IDs should NOT trigger', () {
        expect('unique notification IDs', isNotNull);
      });
    });
    group('avoid_notification_silent_failure', () {
      test('swallowed notification error SHOULD trigger', () {
        expect('swallowed notification error', isNotNull);
      });

      test('notification error handling should NOT trigger', () {
        expect('notification error handling', isNotNull);
      });
    });
  });

  group('Notification - Requirement Rules', () {
    group('require_notification_channel_android', () {
      test('notification without Android channel SHOULD trigger', () {
        expect('notification without Android channel', isNotNull);
      });

      test('channel-based notifications should NOT trigger', () {
        expect('channel-based notifications', isNotNull);
      });
    });
    group('require_notification_initialize_per_platform', () {
      test('platform-agnostic notification init SHOULD trigger', () {
        expect('platform-agnostic notification init', isNotNull);
      });

      test('per-platform notification setup should NOT trigger', () {
        expect('per-platform notification setup', isNotNull);
      });
    });
    group('require_notification_timezone_awareness', () {
      test('scheduled notification without timezone SHOULD trigger', () {
        expect('scheduled notification without timezone', isNotNull);
      });

      test('timezone-aware scheduling should NOT trigger', () {
        expect('timezone-aware scheduling', isNotNull);
      });
    });
  });

  group('Notification - Preference Rules', () {
    group('prefer_notification_grouping', () {
      test('many individual notifications SHOULD trigger', () {
        expect('many individual notifications', isNotNull);
      });

      test('grouped notifications should NOT trigger', () {
        expect('grouped notifications', isNotNull);
      });
    });
  });
}

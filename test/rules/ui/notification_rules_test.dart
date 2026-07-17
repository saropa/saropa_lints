import 'dart:io';

import 'package:saropa_lints/src/rules/ui/notification_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 8 Notification lint rules.
///
/// Test fixtures: example/lib/notification/*
// Android channels, FCM, and local notification API usage in examples.
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
    final fixtureDir = Directory('example/lib/notification');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/notification/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/awesome_notifications_rules.dart';

/// Instantiation-pin tests for the 7 awesome_notifications lint rules.
///
/// These tests verify that each rule class can be instantiated, that its
/// LintCode has the correct name prefix, a problem message longer than 200
/// characters, and a non-null correction message.
///
/// Test fixture: example_packages/lib/awesome_notifications/
///   awesome_notifications_fixture.dart
void main() {
  group('AwesomeNotifications Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason:
              'Problem message must be >200 chars (saropa_lints requirement)',
        );
        expect(rule.code.correctionMessage, isNotNull);
        expect(
          rule.code.correctionMessage,
          isNotEmpty,
          reason: 'correctionMessage must not be empty',
        );
      });
    }

    testRule(
      'AwesomeNotificationsNonStaticListenerRule',
      'awesome_notifications_non_static_listener',
      () => AwesomeNotificationsNonStaticListenerRule(),
    );

    testRule(
      'AwesomeNotificationsHandlerWrongParameterTypeRule',
      'awesome_notifications_handler_wrong_parameter_type',
      () => AwesomeNotificationsHandlerWrongParameterTypeRule(),
    );

    testRule(
      'AwesomeNotificationsMissingPragmaAnnotationRule',
      'awesome_notifications_missing_pragma_annotation',
      () => AwesomeNotificationsMissingPragmaAnnotationRule(),
    );

    testRule(
      'AwesomeNotificationsUndeclaredChannelKeyRule',
      'awesome_notifications_undeclared_channel_key',
      () => AwesomeNotificationsUndeclaredChannelKeyRule(),
    );

    testRule(
      'AwesomeNotificationsCreateWithoutPermissionCheckRule',
      'awesome_notifications_create_without_permission_check',
      () => AwesomeNotificationsCreateWithoutPermissionCheckRule(),
    );

    testRule(
      'AwesomeNotificationsNegativeNotificationIdRule',
      'awesome_notifications_negative_notification_id',
      () => AwesomeNotificationsNegativeNotificationIdRule(),
    );

    testRule(
      'AwesomeNotificationsListenersBeforeDisplayRule',
      'awesome_notifications_listeners_before_display',
      () => AwesomeNotificationsListenersBeforeDisplayRule(),
    );
  });

  group('AwesomeNotifications Rules - Fix Generators', () {
    test(
      'AwesomeNotificationsNegativeNotificationIdRule has one fix generator',
      () {
        final rule = AwesomeNotificationsNegativeNotificationIdRule();
        expect(
          rule.fixGenerators,
          hasLength(1),
          reason:
              'Only negative_notification_id provides a quick fix (replace with'
              ' Random().nextInt(2147483647))',
        );
      },
    );

    test('Rules without quick fixes have empty fixGenerators', () {
      final rulesWithoutFixes = [
        AwesomeNotificationsNonStaticListenerRule(),
        AwesomeNotificationsHandlerWrongParameterTypeRule(),
        AwesomeNotificationsMissingPragmaAnnotationRule(),
        AwesomeNotificationsUndeclaredChannelKeyRule(),
        AwesomeNotificationsCreateWithoutPermissionCheckRule(),
        AwesomeNotificationsListenersBeforeDisplayRule(),
      ];
      for (final rule in rulesWithoutFixes) {
        expect(
          rule.fixGenerators,
          isEmpty,
          reason: '${rule.code.lowerCaseName} should have no fix generators',
        );
      }
    });
  });

  group('AwesomeNotifications Rules - Tags and Metadata', () {
    test('all rules carry the "packages" tag', () {
      final rules = [
        AwesomeNotificationsNonStaticListenerRule(),
        AwesomeNotificationsHandlerWrongParameterTypeRule(),
        AwesomeNotificationsMissingPragmaAnnotationRule(),
        AwesomeNotificationsUndeclaredChannelKeyRule(),
        AwesomeNotificationsCreateWithoutPermissionCheckRule(),
        AwesomeNotificationsNegativeNotificationIdRule(),
        AwesomeNotificationsListenersBeforeDisplayRule(),
      ];
      for (final rule in rules) {
        expect(
          rule.tags,
          contains('packages'),
          reason: '${rule.code.lowerCaseName} must have the "packages" tag',
        );
      }
    });
  });

  group('AwesomeNotifications Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/awesome_notifications');

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
        final file = File(
          'example_packages/lib/awesome_notifications/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/permission_handler_rules.dart';

/// Tests for 5 permission_handler lint rules.
///
/// Test fixtures: example_packages/lib/permission_handler/*
void main() {
  group('Permission Handler Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PermissionHandlerRequestInBuildRule',
      'permission_handler_request_in_build',
      () => PermissionHandlerRequestInBuildRule(),
    );
    testRule(
      'PermissionHandlerLocationAlwaysBeforeWhenInUseRule',
      'permission_handler_location_always_before_when_in_use',
      () => PermissionHandlerLocationAlwaysBeforeWhenInUseRule(),
    );
    testRule(
      'PermissionHandlerDeprecatedCalendarRule',
      'permission_handler_deprecated_calendar',
      () => PermissionHandlerDeprecatedCalendarRule(),
    );
    testRule(
      'PermissionHandlerStatusWithoutRequestRule',
      'permission_handler_status_without_request',
      () => PermissionHandlerStatusWithoutRequestRule(),
    );
    testRule(
      'PermissionHandlerBatchedRequestPreferredRule',
      'permission_handler_batched_request_preferred',
      () => PermissionHandlerBatchedRequestPreferredRule(),
    );
  });

  group('Permission Handler Rules - Fixture Verification', () {
    final fixtures = [
      'permission_handler_request_in_build',
      'permission_handler_location_always_before_when_in_use',
      'permission_handler_deprecated_calendar',
      'permission_handler_status_without_request',
      'permission_handler_batched_request_preferred',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/permission_handler/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}

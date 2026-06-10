import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/security/permission_rules.dart';

/// Tests for 6 Permission lint rules.
///
/// Test fixtures: example/lib/permission/*
// Runtime permission APIs and handler wiring in small examples.
void main() {
  group('Permission Rules - Rule Instantiation', () {
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
      'RequireLocationPermissionRationaleRule',
      'require_location_permission_rationale',
      () => RequireLocationPermissionRationaleRule(),
    );

    testRule(
      'RequireCameraPermissionCheckRule',
      'require_camera_permission_check',
      () => RequireCameraPermissionCheckRule(),
    );

    testRule(
      'PreferImageCroppingRule',
      'prefer_image_cropping',
      () => PreferImageCroppingRule(),
    );

    testRule(
      'AvoidPermissionHandlerNullSafetyRule',
      'avoid_permission_handler_null_safety',
      () => AvoidPermissionHandlerNullSafetyRule(),
    );

    testRule(
      'PreferPermissionRequestInContextRule',
      'prefer_permission_request_in_context',
      () => PreferPermissionRequestInContextRule(),
    );

    testRule(
      'AvoidPermissionRequestLoopRule',
      'avoid_permission_request_loop',
      () => AvoidPermissionRequestLoopRule(),
    );
  });

  group('Permission Rules - Fixture Verification', () {
    final fixtures = [
      'require_location_permission_rationale',
      'require_camera_permission_check',
      'prefer_image_cropping',
      'avoid_permission_handler_null_safety',
      'prefer_permission_request_in_context',
      'avoid_permission_request_loop',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/permission/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}

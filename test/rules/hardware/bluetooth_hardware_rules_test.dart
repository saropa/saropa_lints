import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/hardware/bluetooth_hardware_rules.dart';

/// Tests for 10 Bluetooth Hardware lint rules.
///
/// Test fixtures: example/lib/bluetooth_hardware/*
void main() {
  group('Bluetooth Hardware Rules - Rule Instantiation', () {
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
      'AvoidBluetoothScanWithoutTimeoutRule',
      'avoid_bluetooth_scan_without_timeout',
      () => AvoidBluetoothScanWithoutTimeoutRule(),
    );

    testRule(
      'RequireBluetoothStateCheckRule',
      'require_bluetooth_state_check',
      () => RequireBluetoothStateCheckRule(),
    );

    testRule(
      'RequireBleDisconnectHandlingRule',
      'require_ble_disconnect_handling',
      () => RequireBleDisconnectHandlingRule(),
    );

    testRule(
      'RequireAudioFocusHandlingRule',
      'require_audio_focus_handling',
      () => RequireAudioFocusHandlingRule(),
    );

    testRule(
      'RequireQrPermissionCheckRule',
      'require_qr_permission_check',
      () => RequireQrPermissionCheckRule(),
    );

    testRule(
      'RequireGeolocatorPermissionCheckRule',
      'require_geolocator_permission_check',
      () => RequireGeolocatorPermissionCheckRule(),
    );

    testRule(
      'RequireGeolocatorServiceEnabledRule',
      'require_geolocator_service_enabled',
      () => RequireGeolocatorServiceEnabledRule(),
    );

    testRule(
      'RequireGeolocatorStreamCancelRule',
      'require_geolocator_stream_cancel',
      () => RequireGeolocatorStreamCancelRule(),
    );

    testRule(
      'RequireGeolocatorErrorHandlingRule',
      'require_geolocator_error_handling',
      () => RequireGeolocatorErrorHandlingRule(),
    );

    testRule(
      'PreferBleMtuNegotiationRule',
      'prefer_ble_mtu_negotiation',
      () => PreferBleMtuNegotiationRule(),
    );
  });

  group('Bluetooth Hardware Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/bluetooth_hardware');

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
      test('\$fixture fixture exists', () {
        final file = File(
          'example/lib/bluetooth_hardware/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

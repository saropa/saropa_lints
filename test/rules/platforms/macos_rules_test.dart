import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/macos_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 15 macOS lint rules.
///
/// Test fixtures: example/lib/macos/
void main() {
  group('Macos Rules - Rule Instantiation', () {
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
      'PreferMacosMenuBarIntegrationRule',
      'prefer_macos_menu_bar_integration',
      () => PreferMacosMenuBarIntegrationRule(),
    );

    testRule(
      'PreferMacosKeyboardShortcutsRule',
      'prefer_macos_keyboard_shortcuts',
      () => PreferMacosKeyboardShortcutsRule(),
    );

    testRule(
      'RequireMacosWindowSizeConstraintsRule',
      'require_macos_window_size_constraints',
      () => RequireMacosWindowSizeConstraintsRule(),
    );

    testRule(
      'RequireMacosFileAccessIntentRule',
      'require_macos_file_access_intent',
      () => RequireMacosFileAccessIntentRule(),
    );

    testRule(
      'AvoidMacosDeprecatedSecurityApisRule',
      'avoid_macos_deprecated_security_apis',
      () => AvoidMacosDeprecatedSecurityApisRule(),
    );

    testRule(
      'RequireMacosHardenedRuntimeRule',
      'require_macos_hardened_runtime',
      () => RequireMacosHardenedRuntimeRule(),
    );

    testRule(
      'AvoidMacosCatalystUnsupportedApisRule',
      'avoid_macos_catalyst_unsupported_apis',
      () => AvoidMacosCatalystUnsupportedApisRule(),
    );

    testRule(
      'RequireMacosWindowRestorationRule',
      'require_macos_window_restoration',
      () => RequireMacosWindowRestorationRule(),
    );

    testRule(
      'AvoidMacosFullDiskAccessRule',
      'avoid_macos_full_disk_access',
      () => AvoidMacosFullDiskAccessRule(),
    );

    testRule(
      'RequireMacosSandboxEntitlementsRule',
      'require_macos_sandbox_entitlements',
      () => RequireMacosSandboxEntitlementsRule(),
    );

    testRule(
      'RequireMacosSandboxExceptionsRule',
      'require_macos_sandbox_exceptions',
      () => RequireMacosSandboxExceptionsRule(),
    );

    testRule(
      'AvoidMacosHardenedRuntimeViolationsRule',
      'avoid_macos_hardened_runtime_violations',
      () => AvoidMacosHardenedRuntimeViolationsRule(),
    );

    testRule(
      'RequireMacosAppTransportSecurityRule',
      'require_macos_app_transport_security',
      () => RequireMacosAppTransportSecurityRule(),
    );

    testRule(
      'RequireMacosNotarizationReadyRule',
      'require_macos_notarization_ready',
      () => RequireMacosNotarizationReadyRule(),
    );

    testRule(
      'RequireMacosEntitlementsRule',
      'require_macos_entitlements',
      () => RequireMacosEntitlementsRule(),
    );
  });

  group('macOS Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/macos');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/macos/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}

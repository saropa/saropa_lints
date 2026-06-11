import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/local_auth_rules.dart';

/// Tests for local_auth lint rules:
///   - 5 always-on 3.x correct-usage rules
///   - 4 version-gated migration rules (pack: local_auth_3, gate: < 3.0.0)
///
/// Test fixtures: example_packages/lib/local_auth/*
void main() {
  group('LocalAuth Rules - Rule Instantiation', () {
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
      'LocalAuthUncheckedResultRule',
      'local_auth_unchecked_result',
      () => LocalAuthUncheckedResultRule(),
    );
    testRule(
      'LocalAuthMissingCapabilityCheckRule',
      'local_auth_missing_capability_check',
      () => LocalAuthMissingCapabilityCheckRule(),
    );
    testRule(
      'LocalAuthUnhandledExceptionRule',
      'local_auth_unhandled_exception',
      () => LocalAuthUnhandledExceptionRule(),
    );
    testRule(
      'LocalAuthMissingLockoutHandlingRule',
      'local_auth_missing_lockout_handling',
      () => LocalAuthMissingLockoutHandlingRule(),
    );
    testRule(
      'LocalAuthBiometricOnlySensitiveRule',
      'local_auth_biometric_only_sensitive',
      () => LocalAuthBiometricOnlySensitiveRule(),
    );

    // Migration rules (local_auth_3 pack, gate: local_auth < 3.0.0)
    testRule(
      'LocalAuthDeprecatedOptionsClassRule',
      'local_auth_deprecated_options_class',
      () => LocalAuthDeprecatedOptionsClassRule(),
    );
    testRule(
      'LocalAuthUseErrorDialogsRemovedRule',
      'local_auth_use_error_dialogs_removed',
      () => LocalAuthUseErrorDialogsRemovedRule(),
    );
    testRule(
      'LocalAuthStickyAuthRenamedRule',
      'local_auth_sticky_auth_renamed',
      () => LocalAuthStickyAuthRenamedRule(),
    );
    testRule(
      'LocalAuthPlatformExceptionCatchRule',
      'local_auth_platform_exception_catch',
      () => LocalAuthPlatformExceptionCatchRule(),
    );
  });

  group('LocalAuth Rules - Fixture Verification', () {
    final fixtures = [
      'local_auth_unchecked_result',
      'local_auth_missing_capability_check',
      'local_auth_unhandled_exception',
      'local_auth_missing_lockout_handling',
      'local_auth_biometric_only_sensitive',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/local_auth/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }

    test('local_auth migration fixture exists', () {
      final file = File(
        'example_packages/lib/local_auth/local_auth_migration_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
  });
}

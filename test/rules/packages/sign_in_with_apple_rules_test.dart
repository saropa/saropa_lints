import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/sign_in_with_apple_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation pins for the 6 sign_in_with_apple lint rules.
///
/// Test fixtures: example_packages/lib/sign_in_with_apple/*
void main() {
  group('Sign In With Apple Rules - Rule Instantiation', () {
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
      'AppleSignInUnhandledAuthorizationExceptionRule',
      'apple_sign_in_unhandled_authorization_exception',
      () => AppleSignInUnhandledAuthorizationExceptionRule(),
    );
    testRule(
      'AppleSignInUnhandledCancelRule',
      'apple_sign_in_unhandled_cancel',
      () => AppleSignInUnhandledCancelRule(),
    );
    testRule(
      'AppleSignInUncheckedAvailabilityRule',
      'apple_sign_in_unchecked_availability',
      () => AppleSignInUncheckedAvailabilityRule(),
    );
    testRule(
      'AppleSignInNullIdentityTokenRule',
      'apple_sign_in_null_identity_token',
      () => AppleSignInNullIdentityTokenRule(),
    );
    testRule(
      'AppleSignInRelyingOnNameEmailRule',
      'apple_sign_in_relying_on_name_email',
      () => AppleSignInRelyingOnNameEmailRule(),
    );
    testRule(
      'AppleSignInUncheckedCredentialStateRule',
      'apple_sign_in_unchecked_credential_state',
      () => AppleSignInUncheckedCredentialStateRule(),
    );
  });

  group('Sign In With Apple Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/sign_in_with_apple');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/sign_in_with_apple/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

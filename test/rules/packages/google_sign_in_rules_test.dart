import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/google_sign_in_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for the six google_sign_in lint rules.
///
/// These tests verify that each rule class:
///   - constructs without error
///   - exposes the expected `lowerCaseName`
///   - embeds `[rule_name]` in the problem message (mandatory prefix)
///   - has a problem message > 200 characters (enforced by the pack system)
///   - has a non-null correction message
///
/// Test fixtures: example_packages/lib/google_sign_in/
void main() {
  group('Google Sign-In Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
        expect((rule.code.correctionMessage as String).isNotEmpty, isTrue);
      });
    }

    testRule(
      'AvoidPreV7GoogleSignInRule',
      'avoid_pre_v7_google_sign_in',
      AvoidPreV7GoogleSignInRule.new,
    );
    testRule(
      'GoogleSignInMissingExceptionHandlerRule',
      'google_sign_in_missing_exception_handler',
      GoogleSignInMissingExceptionHandlerRule.new,
    );
    testRule(
      'GoogleSignInUncheckedSupportsAuthenticateRule',
      'google_sign_in_unchecked_supports_authenticate',
      GoogleSignInUncheckedSupportsAuthenticateRule.new,
    );
    testRule(
      'GoogleSignInAuthTokenFromAuthenticateRule',
      'google_sign_in_auth_token_from_authenticate',
      GoogleSignInAuthTokenFromAuthenticateRule.new,
    );
    testRule(
      'GoogleSignInCanceledNotHandledRule',
      'google_sign_in_canceled_not_handled',
      GoogleSignInCanceledNotHandledRule.new,
    );
    testRule(
      'GoogleSignInAuthenticateBeforeInitializeRule',
      'google_sign_in_authenticate_before_initialize',
      GoogleSignInAuthenticateBeforeInitializeRule.new,
    );
  });

  group('Google Sign-In Rules - Metadata', () {
    test('AvoidPreV7GoogleSignInRule is codeSmell with warning impact', () {
      final rule = AvoidPreV7GoogleSignInRule();
      expect(rule.ruleType, RuleType.codeSmell);
      expect(rule.impact, LintImpact.warning);
    });

    test(
      'GoogleSignInMissingExceptionHandlerRule is bug with warning impact',
      () {
        final rule = GoogleSignInMissingExceptionHandlerRule();
        expect(rule.ruleType, RuleType.bug);
        expect(rule.impact, LintImpact.warning);
      },
    );

    test(
      'GoogleSignInUncheckedSupportsAuthenticateRule is codeSmell with warning impact',
      () {
        final rule = GoogleSignInUncheckedSupportsAuthenticateRule();
        expect(rule.ruleType, RuleType.codeSmell);
        expect(rule.impact, LintImpact.warning);
      },
    );

    test(
      'GoogleSignInAuthTokenFromAuthenticateRule is bug with error impact',
      () {
        final rule = GoogleSignInAuthTokenFromAuthenticateRule();
        expect(rule.ruleType, RuleType.bug);
        expect(rule.impact, LintImpact.error);
      },
    );

    test(
      'GoogleSignInCanceledNotHandledRule is codeSmell with info impact',
      () {
        final rule = GoogleSignInCanceledNotHandledRule();
        expect(rule.ruleType, RuleType.codeSmell);
        expect(rule.impact, LintImpact.info);
      },
    );

    test(
      'GoogleSignInAuthenticateBeforeInitializeRule is bug with warning impact',
      () {
        final rule = GoogleSignInAuthenticateBeforeInitializeRule();
        expect(rule.ruleType, RuleType.bug);
        expect(rule.impact, LintImpact.warning);
      },
    );

    test('all rules have packages tag', () {
      final rules = [
        AvoidPreV7GoogleSignInRule(),
        GoogleSignInMissingExceptionHandlerRule(),
        GoogleSignInUncheckedSupportsAuthenticateRule(),
        GoogleSignInAuthTokenFromAuthenticateRule(),
        GoogleSignInCanceledNotHandledRule(),
        GoogleSignInAuthenticateBeforeInitializeRule(),
      ];
      for (final rule in rules) {
        expect(
          rule.tags,
          contains('packages'),
          reason: '${rule.code.lowerCaseName} must have the packages tag',
        );
      }
    });
  });

  group('Google Sign-In Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/google_sign_in');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/google_sign_in/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}

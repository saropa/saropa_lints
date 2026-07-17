import 'dart:io';

import 'package:saropa_lints/src/rules/data/type_safety_rules.dart';
import 'package:test/test.dart';

/// Tests for 17 Type Safety lint rules.
///
/// Test fixtures: example/lib/type_safety/*
void main() {
  group('Type Safety Rules - Rule Instantiation', () {
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
      'AvoidUnsafeCastRule',
      'avoid_unsafe_cast',
      () => AvoidUnsafeCastRule(),
    );
    testRule(
      'PreferConstrainedGenericsRule',
      'prefer_constrained_generics',
      () => PreferConstrainedGenericsRule(),
    );
    testRule(
      'RequireCovariantDocumentationRule',
      'require_covariant_documentation',
      () => RequireCovariantDocumentationRule(),
    );
    testRule(
      'RequireSafeJsonParsingRule',
      'require_safe_json_parsing',
      () => RequireSafeJsonParsingRule(),
    );
    testRule(
      'RequireNullSafeExtensionsRule',
      'require_null_safe_extensions',
      () => RequireNullSafeExtensionsRule(),
    );
    testRule(
      'PreferSpecificNumericTypesRule',
      'prefer_specific_numeric_types',
      () => PreferSpecificNumericTypesRule(),
    );
    testRule(
      'AvoidNonNullAssertionRule',
      'avoid_non_null_assertion',
      () => AvoidNonNullAssertionRule(),
    );
    testRule(
      'AvoidTypeCastsRule',
      'avoid_type_casts',
      () => AvoidTypeCastsRule(),
    );
    testRule(
      'RequireFutureOrDocumentationRule',
      'require_futureor_documentation',
      () => RequireFutureOrDocumentationRule(),
    );
    testRule(
      'PreferExplicitTypeArgumentsRule',
      'prefer_explicit_type_arguments',
      () => PreferExplicitTypeArgumentsRule(),
    );
    testRule(
      'AvoidUnrelatedTypeCastsRule',
      'avoid_unrelated_type_casts',
      () => AvoidUnrelatedTypeCastsRule(),
    );
    testRule(
      'AvoidDynamicJsonAccessRule',
      'avoid_dynamic_json_access',
      () => AvoidDynamicJsonAccessRule(),
    );
    testRule(
      'RequireNullSafeJsonAccessRule',
      'require_null_safe_json_access',
      () => RequireNullSafeJsonAccessRule(),
    );
    testRule(
      'AvoidDynamicJsonChainsRule',
      'avoid_dynamic_json_chains',
      () => AvoidDynamicJsonChainsRule(),
    );
    testRule(
      'RequireEnumUnknownValueRule',
      'require_enum_unknown_value',
      () => RequireEnumUnknownValueRule(),
    );
    testRule(
      'RequireValidatorReturnNullRule',
      'require_validator_return_null',
      () => RequireValidatorReturnNullRule(),
    );
    testRule(
      'AvoidRedundantNullCheckRule',
      'avoid_redundant_null_check',
      () => AvoidRedundantNullCheckRule(),
    );
  });
  group('Type Safety Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/type_safety');

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
        final file = File('example/lib/type_safety/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}

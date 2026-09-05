import 'dart:io';

import 'package:saropa_lints/src/rules/data/type_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 19 Type lint rules.
///
/// Test fixtures: example/lib/type/*
// is / as / type aliases and inference edge cases in small fixtures.
void main() {
  group('Type Rules - Rule Instantiation', () {
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
      'AvoidCastingToExtensionTypeRule',
      'avoid_casting_to_extension_type',
      () => AvoidCastingToExtensionTypeRule(),
    );
    testRule(
      'AvoidCollectionMethodsWithUnrelatedTypesRule',
      'avoid_collection_methods_with_unrelated_types',
      () => AvoidCollectionMethodsWithUnrelatedTypesRule(),
    );
    testRule(
      'AvoidDynamicRule',
      'avoid_dynamic_type',
      () => AvoidDynamicRule(),
    );
    testRule(
      'AvoidImplicitlyNullableExtensionTypesRule',
      'avoid_implicitly_nullable_extension_types',
      () => AvoidImplicitlyNullableExtensionTypesRule(),
    );
    testRule(
      'AvoidNullableInterpolationRule',
      'avoid_nullable_interpolation',
      () => AvoidNullableInterpolationRule(),
    );
    testRule(
      'AvoidNullableParametersWithDefaultValuesRule',
      'avoid_nullable_parameters_with_default_values',
      () => AvoidNullableParametersWithDefaultValuesRule(),
    );
    testRule(
      'AvoidNullableToStringRule',
      'avoid_nullable_tostring',
      () => AvoidNullableToStringRule(),
    );
    testRule(
      'AvoidNullAssertionRule',
      'avoid_null_assertion',
      () => AvoidNullAssertionRule(),
    );
    testRule(
      'AvoidUnnecessaryTypeAssertionsRule',
      'avoid_unnecessary_type_assertions',
      () => AvoidUnnecessaryTypeAssertionsRule(),
    );
    testRule(
      'AvoidUnnecessaryTypeCastsRule',
      'avoid_unnecessary_type_casts',
      () => AvoidUnnecessaryTypeCastsRule(),
    );
    testRule(
      'AvoidUnrelatedTypeAssertionsRule',
      'avoid_unrelated_type_assertions',
      () => AvoidUnrelatedTypeAssertionsRule(),
    );
    testRule(
      'PreferCorrectTypeNameRule',
      'prefer_correct_type_name',
      () => PreferCorrectTypeNameRule(),
    );
    testRule(
      'PreferExplicitFunctionTypeRule',
      'prefer_explicit_function_type',
      () => PreferExplicitFunctionTypeRule(),
    );
    testRule(
      'PreferInlineFunctionTypesRule',
      'prefer_inline_function_types',
      () => PreferInlineFunctionTypesRule(),
    );
    testRule(
      'PreferResultTypeRule',
      'prefer_result_type',
      () => PreferResultTypeRule(),
    );
    testRule(
      'PreferTypeOverVarRule',
      'prefer_type_over_var',
      () => PreferTypeOverVarRule(),
    );
    testRule(
      'AvoidShadowingTypeParametersRule',
      'avoid_shadowing_type_parameters_class_methods',
      () => AvoidShadowingTypeParametersRule(),
    );
    testRule(
      'PreferFinalLocalsRule',
      'prefer_final_locals_with_fix',
      () => PreferFinalLocalsRule(),
    );
    testRule(
      'PreferConstDeclarationsRule',
      'prefer_const_declarations_with_fix',
      () => PreferConstDeclarationsRule(),
    );
    testRule(
      'ExternalWithInitializerRule',
      'external_with_initializer',
      () => ExternalWithInitializerRule(),
    );
    testRule(
      'TypeCheckWithNullRule',
      'type_check_with_null',
      () => TypeCheckWithNullRule(),
    );
    testRule(
      'InvalidRuntimeCheckWithJsInteropTypesRule',
      'invalid_runtime_check_with_js_interop_types',
      () => InvalidRuntimeCheckWithJsInteropTypesRule(),
    );
    testRule(
      'ArgumentMustBeNativeRule',
      'argument_must_be_native',
      () => ArgumentMustBeNativeRule(),
    );
    testRule(
      'DuplicateRecordFieldNameRule',
      'duplicate_field_name',
      () => DuplicateRecordFieldNameRule(),
    );
    testRule(
      'InvalidRecordFieldNameRule',
      'invalid_field_name',
      () => InvalidRecordFieldNameRule(),
    );
    testRule(
      'InvalidExtensionArgumentCountRule',
      'invalid_extension_argument_count',
      () => InvalidExtensionArgumentCountRule(),
    );
  });

  group('Type Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/type');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/type/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Type - Preference Rules', () {
    group('prefer_type_over_var', () {
      test('has conflictingRules metadata', () {
        final rule = PreferTypeOverVarRule();
        expect(
          rule.conflictingRules,
          contains('prefer_var_over_explicit_type'),
        );
      });

      test('rule offers quick fix (replace var with type)', () {
        final rule = PreferTypeOverVarRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('correction message mentions source.fixAll', () {
        final rule = PreferTypeOverVarRule();
        expect(rule.code.correctionMessage, contains('source.fixAll'));
      });

      test('correction message does not mention test coverage', () {
        final rule = PreferTypeOverVarRule();
        expect(
          rule.code.correctionMessage,
          isNot(contains('Verify the change works')),
        );
      });
    });

    group('prefer_final_locals_with_fix', () {
      test('rule offers quick fix (add final to local)', () {
        final rule = PreferFinalLocalsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('prefer_const_declarations_with_fix', () {
      test('rule offers quick fix (use const instead of final)', () {
        final rule = PreferConstDeclarationsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  group('Type - Annotation Rules', () {
    group('invalid_visible_outside_template_annotation', () {
      test('rule instantiation', () {
        final rule = InvalidVisibleOutsideTemplateAnnotationRule();
        expect(
          rule.code.lowerCaseName,
          'invalid_visible_outside_template_annotation',
        );
        expect(
          rule.code.problemMessage,
          contains('[invalid_visible_outside_template_annotation]'),
        );
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted non-stub metadata checks.

  group('countRequiredCaptureGroups', () {
    // Verifies the regex group counter used by avoid_nullable_interpolation
    // (v8) to narrow match-group suppression from blanket to precise.

    test('simple required groups in lookahead', () {
      // `(\d)(?=(\d{3})+$)` — two capturing groups, both required.
      // The lookahead `(?=...)` is non-capturing, but `(\d{3})` inside
      // it IS a capture group in Dart's RegExp. It's followed by `+`
      // (not `?`/`*`), so both groups are required.
      expect(countRequiredCaptureGroups(r'(\d)(?=(\d{3})+$)'), 2);
    });

    test('all groups required — no optional quantifiers', () {
      // `([a-z])([A-Z])` — two simple required groups
      expect(countRequiredCaptureGroups(r'([a-z])([A-Z])'), 2);
    });

    test('optional group followed by ?', () {
      // `(\w+)(?: (\w+))?` — group 1 required, group 2 optional
      expect(countRequiredCaptureGroups(r'(\w+)(?: (\w+))?'), 1);
    });

    test('optional group followed by *', () {
      // `(a)(b)*` — group 1 required, group 2 optional
      expect(countRequiredCaptureGroups(r'(a)(b)*'), 1);
    });

    test('alternation makes groups optional', () {
      // `(a)|(b)` — alternation: only one side matches
      expect(countRequiredCaptureGroups(r'(a)|(b)'), 0);
    });

    test('non-capturing group does not count', () {
      // `(?:prefix)(value)` — only one capture group
      expect(countRequiredCaptureGroups(r'(?:prefix)(value)'), 1);
    });

    test('escaped parens are not groups', () {
      // `\(literal\)(capture)` — only one capture group
      expect(countRequiredCaptureGroups(r'\(literal\)(capture)'), 1);
    });

    test('parens inside character class are literal', () {
      // `[()](capture)` — `[()]` is a char class, one capture group
      expect(countRequiredCaptureGroups(r'[()](capture)'), 1);
    });

    test('group 0 is always safe — not counted', () {
      // Empty pattern — zero capture groups, but group 0 still safe
      expect(countRequiredCaptureGroups(r'hello'), 0);
    });

    test('named capture group counts', () {
      // `(?<name>\w+)` — one named capture group, required
      expect(countRequiredCaptureGroups(r'(?<name>\w+)'), 1);
    });

    test('lookbehind is not a capture group', () {
      // `(?<=prefix)(value)` — lookbehind + one capture group
      expect(countRequiredCaptureGroups(r'(?<=prefix)(value)'), 1);
    });

    test('negative lookbehind is not a capture group', () {
      // `(?<!prefix)(value)` — negative lookbehind + one capture
      expect(countRequiredCaptureGroups(r'(?<!prefix)(value)'), 1);
    });

    test('unbalanced parens return null', () {
      // Missing closing paren — too malformed to parse
      expect(countRequiredCaptureGroups(r'(unclosed'), isNull);
    });

    test('nested groups — inner optional, outer required', () {
      // `(outer(inner)?)` — outer required, inner optional
      expect(countRequiredCaptureGroups(r'(outer(inner)?)'), 1);
    });

    test('real-world comma formatting pattern', () {
      // The pattern from health_summary.dart — 2 required groups
      // (group 2 is inside a lookahead but still a capture group)
      expect(countRequiredCaptureGroups(r'(\d)(?=(\d{3})+$)'), 2);
    });

    test('real-world camelCase splitter', () {
      // `([a-z0-9])([A-Z])` — 2 required groups
      expect(countRequiredCaptureGroups(r'([a-z0-9])([A-Z])'), 2);
    });
  });
}

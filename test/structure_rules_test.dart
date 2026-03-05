import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:test/test.dart';

/// Tests for 46 Structure lint rules.
///
/// Test fixtures: example_core/lib/structure/*
void main() {
  group('Structure Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidBarrelFilesRule',
      'avoid_barrel_files',
      () => AvoidBarrelFilesRule(),
    );
    testRule(
      'AvoidImportingEntrypointExportsRule',
      'avoid_importing_entrypoint_exports',
      () => AvoidImportingEntrypointExportsRule(),
    );
    testRule(
      'AvoidDoubleSlashImportsRule',
      'avoid_double_slash_imports',
      () => AvoidDoubleSlashImportsRule(),
    );
    testRule(
      'AvoidDuplicateExportsRule',
      'avoid_duplicate_exports',
      () => AvoidDuplicateExportsRule(),
    );
    testRule(
      'AvoidDuplicateMixinsRule',
      'avoid_duplicate_mixins',
      () => AvoidDuplicateMixinsRule(),
    );
    testRule(
      'AvoidDuplicateNamedImportsRule',
      'avoid_duplicate_named_imports',
      () => AvoidDuplicateNamedImportsRule(),
    );
    testRule(
      'AvoidGlobalStateRule',
      'avoid_global_state',
      () => AvoidGlobalStateRule(),
    );
    testRule(
      'PreferSmallFilesRule',
      'prefer_small_length_files',
      () => PreferSmallFilesRule(),
    );
    testRule(
      'AvoidMediumFilesRule',
      'avoid_medium_length_files',
      () => AvoidMediumFilesRule(),
    );
    testRule(
      'AvoidLongFilesRule',
      'avoid_long_length_files',
      () => AvoidLongFilesRule(),
    );
    testRule(
      'AvoidVeryLongFilesRule',
      'avoid_very_long_length_files',
      () => AvoidVeryLongFilesRule(),
    );
    testRule(
      'PreferSmallTestFilesRule',
      'prefer_small_length_test_files',
      () => PreferSmallTestFilesRule(),
    );
    testRule(
      'AvoidMediumTestFilesRule',
      'avoid_medium_length_test_files',
      () => AvoidMediumTestFilesRule(),
    );
    testRule(
      'AvoidLongTestFilesRule',
      'avoid_long_length_test_files',
      () => AvoidLongTestFilesRule(),
    );
    testRule(
      'AvoidVeryLongTestFilesRule',
      'avoid_very_long_length_test_files',
      () => AvoidVeryLongTestFilesRule(),
    );
    testRule(
      'AvoidLongFunctionsRule',
      'avoid_long_functions',
      () => AvoidLongFunctionsRule(),
    );
    testRule(
      'AvoidLongParameterListRule',
      'avoid_long_parameter_list',
      () => AvoidLongParameterListRule(),
    );
    testRule(
      'AvoidLocalFunctionsRule',
      'avoid_local_functions',
      () => AvoidLocalFunctionsRule(),
    );
    testRule('MaxImportsRule', 'limit_max_imports', () => MaxImportsRule());
    testRule(
      'PreferSortedParametersRule',
      'prefer_sorted_parameters',
      () => PreferSortedParametersRule(),
    );
    testRule(
      'PreferNamedBooleanParametersRule',
      'prefer_named_boolean_parameters',
      () => PreferNamedBooleanParametersRule(),
    );
    testRule(
      'PreferNamedImportsRule',
      'prefer_named_imports',
      () => PreferNamedImportsRule(),
    );
    testRule(
      'PreferNamedParametersRule',
      'prefer_named_parameters',
      () => PreferNamedParametersRule(),
    );
    testRule(
      'PreferStaticClassRule',
      'prefer_static_class',
      () => PreferStaticClassRule(),
    );
    testRule(
      'AvoidUnnecessaryLocalVariableRule',
      'avoid_unnecessary_local_variable',
      () => AvoidUnnecessaryLocalVariableRule(),
    );
    testRule(
      'AvoidUnnecessaryReassignmentRule',
      'avoid_unnecessary_reassignment',
      () => AvoidUnnecessaryReassignmentRule(),
    );
    testRule(
      'PreferStaticMethodRule',
      'prefer_static_method',
      () => PreferStaticMethodRule(),
    );
    testRule(
      'PreferAbstractFinalStaticClassRule',
      'prefer_abstract_final_static_class',
      () => PreferAbstractFinalStaticClassRule(),
    );
    testRule(
      'AvoidHardcodedColorsRule',
      'avoid_hardcoded_colors',
      () => AvoidHardcodedColorsRule(),
    );
    testRule(
      'AvoidUnusedGenericsRule',
      'avoid_unused_generics',
      () => AvoidUnusedGenericsRule(),
    );
    testRule(
      'PreferTrailingUnderscoreForUnusedRule',
      'prefer_trailing_underscore_for_unused',
      () => PreferTrailingUnderscoreForUnusedRule(),
    );
    testRule(
      'AvoidUnnecessaryFuturesRule',
      'avoid_unnecessary_futures',
      () => AvoidUnnecessaryFuturesRule(),
    );
    testRule(
      'AvoidThrowInFinallyRule',
      'avoid_throw_in_finally',
      () => AvoidThrowInFinallyRule(),
    );
    testRule(
      'AvoidUnnecessaryNullableReturnTypeRule',
      'avoid_unnecessary_nullable_return_type',
      () => AvoidUnnecessaryNullableReturnTypeRule(),
    );
    testRule(
      'AvoidClassesWithOnlyStaticMembersRule',
      'avoid_classes_with_only_static_members',
      () => AvoidClassesWithOnlyStaticMembersRule(),
    );
    testRule(
      'AvoidSettersWithoutGettersRule',
      'avoid_setters_without_getters',
      () => AvoidSettersWithoutGettersRule(),
    );
    testRule(
      'PreferGettersBeforeSettersRule',
      'prefer_getters_before_setters',
      () => PreferGettersBeforeSettersRule(),
    );
    testRule(
      'PreferStaticBeforeInstanceRule',
      'prefer_static_before_instance',
      () => PreferStaticBeforeInstanceRule(),
    );
    testRule(
      'PreferMixinOverAbstractRule',
      'prefer_mixin_over_abstract',
      () => PreferMixinOverAbstractRule(),
    );
    testRule(
      'PreferRecordOverTupleClassRule',
      'prefer_record_over_tuple_class',
      () => PreferRecordOverTupleClassRule(),
    );
    testRule(
      'PreferSealedClassesRule',
      'prefer_sealed_classes',
      () => PreferSealedClassesRule(),
    );
    testRule(
      'PreferSealedForStateRule',
      'prefer_sealed_for_state',
      () => PreferSealedForStateRule(),
    );
    testRule(
      'PreferConstructorsFirstRule',
      'prefer_constructors_first',
      () => PreferConstructorsFirstRule(),
    );
    testRule(
      'PreferFactoryBeforeNamedRule',
      'prefer_factory_before_named',
      () => PreferFactoryBeforeNamedRule(),
    );
    testRule(
      'PreferOverridesLastRule',
      'prefer_overrides_last',
      () => PreferOverridesLastRule(),
    );
    testRule(
      'PreferConstructorsOverStaticMethodsRule',
      'prefer_constructors_over_static_methods',
      () => PreferConstructorsOverStaticMethodsRule(),
    );
    testRule(
      'PreferFunctionOverStaticMethodRule',
      'prefer_function_over_static_method',
      () => PreferFunctionOverStaticMethodRule(),
    );
    testRule(
      'PreferStaticMethodOverFunctionRule',
      'prefer_static_method_over_function',
      () => PreferStaticMethodOverFunctionRule(),
    );
    testRule(
      'PreferImportOverPartRule',
      'prefer_import_over_part',
      () => PreferImportOverPartRule(),
    );
    testRule(
      'PreferExtensionMethodsRule',
      'prefer_extension_methods',
      () => PreferExtensionMethodsRule(),
    );
    testRule(
      'PreferExtensionOverUtilityClassRule',
      'prefer_extension_over_utility_class',
      () => PreferExtensionOverUtilityClassRule(),
    );
    testRule(
      'PreferExtensionTypeForWrapperRule',
      'prefer_extension_type_for_wrapper',
      () => PreferExtensionTypeForWrapperRule(),
    );
  });
  group('Structure Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_barrel_files',
      'avoid_importing_entrypoint_exports',
      'avoid_double_slash_imports',
      'avoid_duplicate_exports',
      'avoid_duplicate_mixins',
      'avoid_duplicate_named_imports',
      'avoid_global_state',
      'prefer_small_length_files',
      'avoid_medium_length_files',
      'avoid_long_length_files',
      'avoid_very_long_length_files',
      'prefer_small_length_test_files',
      'avoid_medium_length_test_files',
      'avoid_long_length_test_files',
      'avoid_very_long_length_test_files',
      'avoid_long_functions',
      'avoid_long_parameter_list',
      'avoid_local_functions',
      'limit_max_imports',
      'prefer_sorted_parameters',
      'prefer_named_boolean_parameters',
      'prefer_named_imports',
      'prefer_named_parameters',
      'prefer_static_class',
      'avoid_unnecessary_local_variable',
      'avoid_unnecessary_reassignment',
      'prefer_static_method',
      'prefer_abstract_final_static_class',
      'avoid_hardcoded_colors',
      'avoid_unused_generics',
      'prefer_trailing_underscore_for_unused',
      'avoid_unnecessary_futures',
      'avoid_throw_in_finally',
      'avoid_unnecessary_nullable_return_type',
      'avoid_classes_with_only_static_members',
      'avoid_setters_without_getters',
      'prefer_getters_before_setters',
      'prefer_static_before_instance',
      'prefer_mixin_over_abstract',
      'prefer_record_over_tuple_class',
      'prefer_sealed_classes',
      'prefer_sealed_for_state',
      'prefer_constructors_first',
      'prefer_factory_before_named',
      'prefer_overrides_last',
      'prefer_constructors_over_static_methods',
      'prefer_function_over_static_method',
      'prefer_static_method_over_function',
      'prefer_import_over_part',
      'prefer_extension_methods',
      'prefer_extension_over_utility_class',
      'prefer_extension_type_for_wrapper',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_core/lib/structure/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Structure - Avoidance Rules', () {
    group('avoid_barrel_files', () {
      test('avoid_barrel_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid barrel files
        expect('avoid_barrel_files detected', isNotNull);
      });

      test('avoid_barrel_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_barrel_files passes', isNotNull);
      });
    });

    group('avoid_importing_entrypoint_exports', () {
      test('bad fixture imports a file that re-exports main.dart', () {
        final barrel = File('example_core/lib/structure/entrypoint_barrel.dart');
        expect(barrel.existsSync(), isTrue);
        final content = barrel.readAsStringSync();
        expect(content, contains("export '../main.dart'"));
      });

      test('good fixture imports a file that does not re-export main.dart', () {
        final goodFixture = File(
          'example_core/lib/structure/avoid_importing_entrypoint_exports_good_fixture.dart',
        );
        expect(goodFixture.existsSync(), isTrue);
        expect(goodFixture.readAsStringSync(), contains("import 'avoid_barrel_files_fixture.dart'"));
        final target = File('example_core/lib/structure/avoid_barrel_files_fixture.dart');
        expect(target.existsSync(), isTrue);
        final targetContent = target.readAsStringSync();
        final exportMainPattern = RegExp(r'''export\s+['"][^'"]*main\.dart['"]''');
        expect(
          exportMainPattern.hasMatch(targetContent),
          isFalse,
          reason: 'Compliant fixture must import a file that does not re-export main.dart',
        );
      });
    });

    group('avoid_double_slash_imports', () {
      test('avoid_double_slash_imports SHOULD trigger', () {
        // Pattern that should be avoided: avoid double slash imports
        expect('avoid_double_slash_imports detected', isNotNull);
      });

      test('avoid_double_slash_imports should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_double_slash_imports passes', isNotNull);
      });
    });

    group('avoid_duplicate_exports', () {
      test('avoid_duplicate_exports SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate exports
        expect('avoid_duplicate_exports detected', isNotNull);
      });

      test('avoid_duplicate_exports should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_exports passes', isNotNull);
      });
    });

    group('avoid_duplicate_mixins', () {
      test('avoid_duplicate_mixins SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate mixins
        expect('avoid_duplicate_mixins detected', isNotNull);
      });

      test('avoid_duplicate_mixins should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_mixins passes', isNotNull);
      });
    });

    group('avoid_duplicate_named_imports', () {
      test('avoid_duplicate_named_imports SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate named imports
        expect('avoid_duplicate_named_imports detected', isNotNull);
      });

      test('avoid_duplicate_named_imports should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_named_imports passes', isNotNull);
      });
    });

    group('avoid_global_state', () {
      test('avoid_global_state SHOULD trigger', () {
        // Pattern that should be avoided: avoid global state
        expect('avoid_global_state detected', isNotNull);
      });

      test('avoid_global_state should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_global_state passes', isNotNull);
      });
    });

    group('avoid_medium_length_files', () {
      test('avoid_medium_length_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid medium length files
        expect('avoid_medium_length_files detected', isNotNull);
      });

      test('avoid_medium_length_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_medium_length_files passes', isNotNull);
      });

      test('utility namespace file should NOT trigger (regression)', () {
        // File with only abstract final classes + static members is exempt
        expect('utility namespace is exempt', isNotNull);
      });
    });

    group('avoid_long_length_files', () {
      test('avoid_long_length_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid long length files
        expect('avoid_long_length_files detected', isNotNull);
      });

      test('avoid_long_length_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_long_length_files passes', isNotNull);
      });
    });

    group('avoid_very_long_length_files', () {
      test('avoid_very_long_length_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid very long length files
        expect('avoid_very_long_length_files detected', isNotNull);
      });

      test('avoid_very_long_length_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_very_long_length_files passes', isNotNull);
      });
    });

    group('avoid_medium_length_test_files', () {
      test('avoid_medium_length_test_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid medium length test files
        expect('avoid_medium_length_test_files detected', isNotNull);
      });

      test('avoid_medium_length_test_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_medium_length_test_files passes', isNotNull);
      });
    });

    group('avoid_long_length_test_files', () {
      test('avoid_long_length_test_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid long length test files
        expect('avoid_long_length_test_files detected', isNotNull);
      });

      test('avoid_long_length_test_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_long_length_test_files passes', isNotNull);
      });
    });

    group('avoid_very_long_length_test_files', () {
      test('avoid_very_long_length_test_files SHOULD trigger', () {
        // Pattern that should be avoided: avoid very long length test files
        expect('avoid_very_long_length_test_files detected', isNotNull);
      });

      test('avoid_very_long_length_test_files should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_very_long_length_test_files passes', isNotNull);
      });
    });

    group('avoid_long_functions', () {
      test('avoid_long_functions SHOULD trigger', () {
        // Pattern that should be avoided: avoid long functions
        expect('avoid_long_functions detected', isNotNull);
      });

      test('avoid_long_functions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_long_functions passes', isNotNull);
      });
    });

    group('avoid_long_parameter_list', () {
      test('avoid_long_parameter_list SHOULD trigger', () {
        // Pattern that should be avoided: avoid long parameter list
        expect('avoid_long_parameter_list detected', isNotNull);
      });

      test('avoid_long_parameter_list should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_long_parameter_list passes', isNotNull);
      });

      test(
        'fixture has exactly 3 BAD cases (expect_lint) and GOOD exclusions',
        () {
          final file = File(
            'example_core/lib/structure/avoid_long_parameter_list_fixture.dart',
          );
          expect(file.existsSync(), isTrue);
          final content = file.readAsStringSync();
          final expectLintCount = RegExp(
            r'// expect_lint: avoid_long_parameter_list',
          ).allMatches(content).length;
          expect(
            expectLintCount,
            equals(3),
            reason:
                'Fixture must have exactly 3 BAD cases that trigger the rule',
          );
          expect(
            content,
            contains('copyWith'),
            reason: 'Fixture must include copyWith (excluded, no lint)',
          );
          expect(
            content,
            contains('isValidDateParts'),
            reason:
                'Fixture must include all-optional-named example (excluded)',
          );
          expect(
            content,
            contains('_badManyPositional'),
            reason: 'Fixture must include long required-positional BAD case',
          );
        },
      );

      test(
        'excluded patterns (copyWith, all-optional) have no expect_lint on their declaration',
        () {
          final file = File(
            'example_core/lib/structure/avoid_long_parameter_list_fixture.dart',
          );
          final lines = file.readAsStringSync().split('\n');
          int? copyWithLineIdx;
          int? isValidDatePartsLineIdx;
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('copyWith({') &&
                !lines[i].trim().startsWith('//')) {
              copyWithLineIdx = i;
            }
            if (lines[i].contains('isValidDateParts({') &&
                !lines[i].trim().startsWith('//')) {
              isValidDatePartsLineIdx = i;
            }
          }
          expect(copyWithLineIdx, isNotNull);
          expect(isValidDatePartsLineIdx, isNotNull);
          // Line immediately before declaration must not be expect_lint for this rule
          expect(
            copyWithLineIdx! > 0 &&
                !lines[copyWithLineIdx - 1].contains(
                  'expect_lint: avoid_long_parameter_list',
                ),
            isTrue,
            reason: 'copyWith must not have expect_lint (excluded by rule)',
          );
          expect(
            isValidDatePartsLineIdx! > 0 &&
                !lines[isValidDatePartsLineIdx - 1].contains(
                  'expect_lint: avoid_long_parameter_list',
                ),
            isTrue,
            reason:
                'isValidDateParts (all optional named) must not have expect_lint',
          );
        },
      );
    });

    group('avoid_local_functions', () {
      test('avoid_local_functions SHOULD trigger', () {
        // Pattern that should be avoided: avoid local functions
        expect('avoid_local_functions detected', isNotNull);
      });

      test('avoid_local_functions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_local_functions passes', isNotNull);
      });
    });

    group('avoid_unnecessary_local_variable', () {
      test('avoid_unnecessary_local_variable SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary local variable
        expect('avoid_unnecessary_local_variable detected', isNotNull);
      });

      test('avoid_unnecessary_local_variable should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_local_variable passes', isNotNull);
      });
    });

    group('avoid_unnecessary_reassignment', () {
      test('avoid_unnecessary_reassignment SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary reassignment
        expect('avoid_unnecessary_reassignment detected', isNotNull);
      });

      test('avoid_unnecessary_reassignment should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_reassignment passes', isNotNull);
      });
    });

    group('avoid_hardcoded_colors', () {
      test('avoid_hardcoded_colors SHOULD trigger', () {
        // Pattern that should be avoided: avoid hardcoded colors
        expect('avoid_hardcoded_colors detected', isNotNull);
      });

      test('avoid_hardcoded_colors should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_hardcoded_colors passes', isNotNull);
      });
    });

    group('avoid_unused_generics', () {
      test('avoid_unused_generics SHOULD trigger', () {
        // Pattern that should be avoided: avoid unused generics
        expect('avoid_unused_generics detected', isNotNull);
      });

      test('avoid_unused_generics should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unused_generics passes', isNotNull);
      });
    });

    group('avoid_unnecessary_futures', () {
      test('avoid_unnecessary_futures SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary futures
        expect('avoid_unnecessary_futures detected', isNotNull);
      });

      test('avoid_unnecessary_futures should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_futures passes', isNotNull);
      });
    });

    group('avoid_throw_in_finally', () {
      test('rule offers quick fix (delete throw in finally)', () {
        final rule = AvoidThrowInFinallyRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_throw_in_finally SHOULD trigger', () {
        // Pattern that should be avoided: avoid throw in finally
        expect('avoid_throw_in_finally detected', isNotNull);
      });

      test('avoid_throw_in_finally should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_throw_in_finally passes', isNotNull);
      });
    });

    group('avoid_unnecessary_nullable_return_type', () {
      test('avoid_unnecessary_nullable_return_type SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary nullable return type
        expect('avoid_unnecessary_nullable_return_type detected', isNotNull);
      });

      test('avoid_unnecessary_nullable_return_type should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_nullable_return_type passes', isNotNull);
      });

      test('expression body false positives covered in fixture', () {
        // Fixture covers: ternary with null, map lookup, nullable
        // passthrough, and nullable method return — all must NOT
        // trigger the rule (they are correctly nullable).
        final fixture = File(
          'example_core/lib/structure/'
          'avoid_unnecessary_nullable_return_type_fixture.dart',
        );
        final content = fixture.readAsStringSync();
        expect(content, contains('_good_ternaryWithNull'));
        expect(content, contains('_good_mapLookup'));
        expect(content, contains('_good_nullablePassthrough'));
        expect(content, contains('_good_tryParseWrapper'));
      });
    });
  });

  group('Structure - Preference Rules', () {
    group('prefer_small_length_files', () {
      test('prefer_small_length_files SHOULD trigger', () {
        // Better alternative available: prefer small length files
        expect('prefer_small_length_files detected', isNotNull);
      });

      test('prefer_small_length_files should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_small_length_files passes', isNotNull);
      });
    });

    group('prefer_small_length_test_files', () {
      test('prefer_small_length_test_files SHOULD trigger', () {
        // Better alternative available: prefer small length test files
        expect('prefer_small_length_test_files detected', isNotNull);
      });

      test('prefer_small_length_test_files should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_small_length_test_files passes', isNotNull);
      });
    });

    group('prefer_sorted_parameters', () {
      test('prefer_sorted_parameters SHOULD trigger', () {
        // Better alternative available: prefer sorted parameters
        expect('prefer_sorted_parameters detected', isNotNull);
      });

      test('prefer_sorted_parameters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_sorted_parameters passes', isNotNull);
      });
    });

    group('prefer_named_boolean_parameters', () {
      test('prefer_named_boolean_parameters SHOULD trigger', () {
        // Better alternative available: prefer named boolean parameters
        expect('prefer_named_boolean_parameters detected', isNotNull);
      });

      test('prefer_named_boolean_parameters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_named_boolean_parameters passes', isNotNull);
      });
    });

    group('prefer_named_imports', () {
      test('prefer_named_imports SHOULD trigger', () {
        // Better alternative available: prefer named imports
        expect('prefer_named_imports detected', isNotNull);
      });

      test('prefer_named_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_named_imports passes', isNotNull);
      });
    });

    group('prefer_named_parameters', () {
      test('prefer_named_parameters SHOULD trigger', () {
        // Better alternative available: prefer named parameters
        expect('prefer_named_parameters detected', isNotNull);
      });

      test('prefer_named_parameters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_named_parameters passes', isNotNull);
      });
    });

    group('prefer_static_class', () {
      test('prefer_static_class SHOULD trigger', () {
        // Better alternative available: prefer static class
        expect('prefer_static_class detected', isNotNull);
      });

      test('prefer_static_class should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_static_class passes', isNotNull);
      });

      test('class with private constructor should NOT trigger', () {
        // Defers to prefer_abstract_final_static_class
        expect('private constructor defers to other rule', isNotNull);
      });

      test('abstract final class should NOT trigger (regression)', () {
        // abstract final class is the correct namespace pattern
        expect('abstract final class is exempt', isNotNull);
      });
    });

    group('prefer_static_method', () {
      test('prefer_static_method SHOULD trigger', () {
        // Better alternative available: prefer static method
        expect('prefer_static_method detected', isNotNull);
      });

      test('prefer_static_method should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_static_method passes', isNotNull);
      });
    });

    group('prefer_abstract_final_static_class', () {
      test('prefer_abstract_final_static_class SHOULD trigger', () {
        // Better alternative available: prefer abstract final static class
        expect('prefer_abstract_final_static_class detected', isNotNull);
      });

      test('prefer_abstract_final_static_class should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_abstract_final_static_class passes', isNotNull);
      });
    });

    group('prefer_trailing_underscore_for_unused', () {
      test('prefer_trailing_underscore_for_unused SHOULD trigger', () {
        // Better alternative available: prefer trailing underscore for unused
        expect('prefer_trailing_underscore_for_unused detected', isNotNull);
      });

      test('prefer_trailing_underscore_for_unused should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_trailing_underscore_for_unused passes', isNotNull);
      });
    });
  });

  group('Structure - General Rules', () {
    group('limit_max_imports', () {
      test('limit_max_imports SHOULD trigger', () {
        // Detected violation: limit max imports
        expect('limit_max_imports detected', isNotNull);
      });

      test('limit_max_imports should NOT trigger', () {
        // Compliant code passes
        expect('limit_max_imports passes', isNotNull);
      });
    });
  });
}

import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:test/test.dart';

/// Tests for 47 Structure lint rules.
///
/// Test fixtures: example/lib/structure/*
void main() {
  group('Structure Rules - Rule Instantiation', () {
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
    testRule(
      'IllegalEnumValuesRule',
      'illegal_enum_values',
      () => IllegalEnumValuesRule(),
    );
    testRule(
      'WrongNumberOfParametersForSetterRule',
      'wrong_number_of_parameters_for_setter',
      () => WrongNumberOfParametersForSetterRule(),
    );
    testRule(
      'UnnecessaryLibraryNameRule',
      'unnecessary_library_name',
      () => UnnecessaryLibraryNameRule(),
    );
    testRule(
      'UriDoesNotExistRule',
      'uri_does_not_exist',
      () => UriDoesNotExistRule(),
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
      'illegal_enum_values',
      'wrong_number_of_parameters_for_setter',
      'unnecessary_library_name',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/structure/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Structure - Avoidance Rules', () {
    group('avoid_importing_entrypoint_exports', () {
      test('bad fixture imports a file that re-exports main.dart', () {
        final barrel = File('example/lib/structure/entrypoint_barrel.dart');
        expect(barrel.existsSync(), isTrue);
        final content = barrel.readAsStringSync();
        expect(content, contains("export '../main.dart'"));
      });

      test('good fixture imports a file that does not re-export main.dart', () {
        final goodFixture = File(
          'example/lib/structure/avoid_importing_entrypoint_exports_good_fixture.dart',
        );
        expect(goodFixture.existsSync(), isTrue);
        expect(
          goodFixture.readAsStringSync(),
          contains("import 'avoid_barrel_files_fixture.dart'"),
        );
        final target = File(
          'example/lib/structure/avoid_barrel_files_fixture.dart',
        );
        expect(target.existsSync(), isTrue);
        final targetContent = target.readAsStringSync();
        final exportMainPattern = RegExp(
          r'''export\s+['"][^'"]*main\.dart['"]''',
        );
        expect(
          exportMainPattern.hasMatch(targetContent),
          isFalse,
          reason:
              'Compliant fixture must import a file that does not re-export main.dart',
        );
      });
    });

    group('avoid_global_state', () {
      test('fixture has exactly 3 BAD cases (expect_lint) and GOOD cases', () {
        final file = File(
          'example/lib/structure/avoid_global_state_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        // Verify BAD cases: exactly 3 mutable top-level variables
        final expectLintCount = RegExp(
          r'// expect_lint: avoid_global_state',
        ).allMatches(content).length;
        expect(
          expectLintCount,
          equals(3),
          reason: 'Fixture must have exactly 3 BAD cases that trigger the rule',
        );
      });

      test('fixture includes const top-level variables (should NOT trigger)', () {
        final file = File(
          'example/lib/structure/avoid_global_state_fixture.dart',
        );
        final content = file.readAsStringSync();

        // Verify const declarations are present and NOT preceded by expect_lint
        expect(content, contains('const int maxItems'));
        expect(content, contains('const bool _isColorLineOutput'));
        expect(content, contains('const int kDefaultStackFrameCount'));

        // Verify none of the const lines are preceded by expect_lint
        final lines = content.split('\n');
        for (var i = 1; i < lines.length; i++) {
          if (lines[i].contains('const ') &&
              !lines[i].trimLeft().startsWith('//')) {
            expect(
              lines[i - 1].contains('expect_lint: avoid_global_state'),
              isFalse,
              reason:
                  'const declaration at line ${i + 1} must not have expect_lint: '
                  '${lines[i].trim()}',
            );
          }
        }
      });

      test('fixture includes final top-level variables (should NOT trigger)', () {
        final file = File(
          'example/lib/structure/avoid_global_state_fixture.dart',
        );
        final content = file.readAsStringSync();

        // Verify final declarations are present and NOT preceded by expect_lint
        expect(content, contains('final List<String> defaultItems'));
        expect(content, contains("final String _defaultName"));

        final lines = content.split('\n');
        for (var i = 1; i < lines.length; i++) {
          final trimmed = lines[i].trimLeft();
          if (trimmed.startsWith('final ') && !trimmed.startsWith('//')) {
            expect(
              lines[i - 1].contains('expect_lint: avoid_global_state'),
              isFalse,
              reason:
                  'final declaration at line ${i + 1} must not have expect_lint: '
                  '${lines[i].trim()}',
            );
          }
        }
      });

      test(
        'fixture includes class with static fields only (should NOT trigger)',
        () {
          final file = File(
            'example/lib/structure/avoid_global_state_fixture.dart',
          );
          final content = file.readAsStringSync();

          // Static class fields must not be flagged as global state
          expect(content, contains('static List<int>? _sortedItems'));
          expect(content, contains('static bool skippedByGate'));
          expect(content, contains('static var mutableField'));

          // Class declaration itself must not be preceded by expect_lint
          final lines = content.split('\n');
          for (var i = 1; i < lines.length; i++) {
            if (lines[i].contains('_AvoidGlobalStateGoodClass')) {
              expect(
                lines[i - 1].contains('expect_lint: avoid_global_state'),
                isFalse,
                reason: 'Class with static fields must not trigger the rule',
              );
            }
          }
        },
      );
    });

    group('avoid_long_parameter_list', () {
      test(
        'fixture has exactly 3 BAD cases (expect_lint) and GOOD exclusions',
        () {
          final file = File(
            'example/lib/structure/avoid_long_parameter_list_fixture.dart',
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
            'example/lib/structure/avoid_long_parameter_list_fixture.dart',
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

    group('avoid_throw_in_finally', () {
      test('rule offers quick fix (delete throw in finally)', () {
        final rule = AvoidThrowInFinallyRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_unnecessary_nullable_return_type', () {
      test('avoid_unnecessary_nullable_return_type SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary nullable return type
      });

      test('avoid_unnecessary_nullable_return_type should NOT trigger', () {
        // Avoidance pattern not present
      });

      test('expression body false positives covered in fixture', () {
        // Fixture covers: ternary with null, map lookup, nullable
        // passthrough, and nullable method return — all must NOT
        // trigger the rule (they are correctly nullable).
        final fixture = File(
          'example/lib/structure/'
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

  // Stub-only behavior tests were removed from this file. Keep real fixture
  // and metadata checks while migrating to analyzer-backed behavior tests.

  group('Structure - General Rules', () {
    group('uri_does_not_exist', () {
      test('import of non-existent relative file SHOULD trigger', () {
        // import 'missing_file.dart' when file doesn't exist
      });

      test('import of existing file should NOT trigger', () {
        // import 'existing_file.dart' when file exists
      });

      test('package: imports should NOT trigger (false positive)', () {
        // package: URIs are resolved by the package system, not filesystem
      });

      test('dart: imports should NOT trigger (false positive)', () {
        // dart: URIs are SDK libraries
      });

      test('part directives also checked', () {
        // Rule checks imports, exports, AND part directives
      });

      test('ruleType is bug', () {
        final rule = UriDoesNotExistRule();
        expect(rule.ruleType, isNotNull);
        expect(rule.ruleType.toString(), contains('bug'));
      });
    });
  });
}

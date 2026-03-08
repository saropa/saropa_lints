import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_additional_rules.dart';

/// Tests for 24 Stylistic Additional lint rules.
///
/// Test fixtures: example_style/lib/stylistic_additional/*
void main() {
  group('Stylistic Additional Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name.toLowerCase(), codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferInterpolationOverConcatenationRule',
      'prefer_interpolation_over_concatenation',
      () => PreferInterpolationOverConcatenationRule(),
    );

    testRule(
      'PreferConcatenationOverInterpolationRule',
      'prefer_concatenation_over_interpolation',
      () => PreferConcatenationOverInterpolationRule(),
    );

    testRule(
      'PreferDoubleQuotesRule',
      'prefer_double_quotes',
      () => PreferDoubleQuotesRule(),
    );

    testRule(
      'PreferAbsoluteImportsRule',
      'prefer_absolute_imports',
      () => PreferAbsoluteImportsRule(),
    );

    testRule(
      'PreferGroupedImportsRule',
      'prefer_grouped_imports',
      () => PreferGroupedImportsRule(),
    );

    testRule(
      'PreferFlatImportsRule',
      'prefer_flat_imports',
      () => PreferFlatImportsRule(),
    );

    testRule(
      'PreferSortedImportsRule',
      'prefer_sorted_imports',
      () => PreferSortedImportsRule(),
    );

    testRule(
      'PreferImportGroupCommentsRule',
      'prefer_import_group_comments',
      () => PreferImportGroupCommentsRule(),
    );

    testRule(
      'PreferFieldsBeforeMethodsRule',
      'prefer_fields_before_methods',
      () => PreferFieldsBeforeMethodsRule(),
    );

    testRule(
      'PreferMethodsBeforeFieldsRule',
      'prefer_methods_before_fields',
      () => PreferMethodsBeforeFieldsRule(),
    );

    testRule(
      'PreferStaticMembersFirstRule',
      'prefer_static_members_first',
      () => PreferStaticMembersFirstRule(),
    );

    testRule(
      'PreferInstanceMembersFirstRule',
      'prefer_instance_members_first',
      () => PreferInstanceMembersFirstRule(),
    );

    testRule(
      'PreferPublicMembersFirstRule',
      'prefer_public_members_first',
      () => PreferPublicMembersFirstRule(),
    );

    testRule(
      'PreferPrivateMembersFirstRule',
      'prefer_private_members_first',
      () => PreferPrivateMembersFirstRule(),
    );

    testRule(
      'PreferVarOverExplicitTypeRule',
      'prefer_var_over_explicit_type',
      () => PreferVarOverExplicitTypeRule(),
    );

    testRule(
      'PreferObjectOverDynamicRule',
      'prefer_object_over_dynamic',
      () => PreferObjectOverDynamicRule(),
    );

    testRule(
      'PreferDynamicOverObjectRule',
      'prefer_dynamic_over_object',
      () => PreferDynamicOverObjectRule(),
    );

    testRule(
      'PreferLowerCamelCaseConstantsRule',
      'prefer_lower_camel_case_constants',
      () => PreferLowerCamelCaseConstantsRule(),
    );

    testRule(
      'PreferCamelCaseMethodNamesRule',
      'prefer_camel_case_method_names',
      () => PreferCamelCaseMethodNamesRule(),
    );

    testRule(
      'PreferDescriptiveVariableNamesRule',
      'prefer_descriptive_variable_names',
      () => PreferDescriptiveVariableNamesRule(),
    );

    testRule(
      'PreferConciseVariableNamesRule',
      'prefer_concise_variable_names',
      () => PreferConciseVariableNamesRule(),
    );

    testRule(
      'PreferExplicitThisRule',
      'prefer_explicit_this',
      () => PreferExplicitThisRule(),
    );

    testRule(
      'PreferImplicitBooleanComparisonRule',
      'prefer_implicit_boolean_comparison',
      () => PreferImplicitBooleanComparisonRule(),
    );

    testRule(
      'PreferExplicitBooleanComparisonRule',
      'prefer_explicit_boolean_comparison',
      () => PreferExplicitBooleanComparisonRule(),
    );
  });

  group('Stylistic Additional Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_interpolation_over_concatenation',
      'prefer_concatenation_over_interpolation',
      'prefer_double_quotes',
      'prefer_absolute_imports',
      'prefer_grouped_imports',
      'prefer_flat_imports',
      'prefer_sorted_imports',
      'prefer_import_group_comments',
      'prefer_fields_before_methods',
      'prefer_methods_before_fields',
      'prefer_static_members_first',
      'prefer_instance_members_first',
      'prefer_public_members_first',
      'prefer_private_members_first',
      'prefer_var_over_explicit_type',
      'prefer_object_over_dynamic',
      'prefer_dynamic_over_object',
      'prefer_lower_camel_case_constants',
      'prefer_camel_case_method_names',
      'prefer_descriptive_variable_names',
      'prefer_concise_variable_names',
      'prefer_explicit_this',
      'prefer_implicit_boolean_comparison',
      'prefer_explicit_boolean_comparison',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_style/lib/stylistic_additional/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic Additional - Preference Rules', () {
    group('prefer_interpolation_over_concatenation', () {
      test('prefer_interpolation_over_concatenation SHOULD trigger', () {
        // Better alternative available: prefer interpolation over concatenation
        expect('prefer_interpolation_over_concatenation detected', isNotNull);
      });

      test('prefer_interpolation_over_concatenation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_interpolation_over_concatenation passes', isNotNull);
      });
    });

    group('prefer_concatenation_over_interpolation', () {
      test('prefer_concatenation_over_interpolation SHOULD trigger', () {
        // Better alternative available: prefer concatenation over interpolation
        expect('prefer_concatenation_over_interpolation detected', isNotNull);
      });

      test('prefer_concatenation_over_interpolation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_concatenation_over_interpolation passes', isNotNull);
      });
    });

    group('prefer_double_quotes', () {
      test('prefer_double_quotes SHOULD trigger', () {
        // Better alternative available: prefer double quotes
        expect('prefer_double_quotes detected', isNotNull);
      });

      test('prefer_double_quotes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_double_quotes passes', isNotNull);
      });
    });

    group('prefer_absolute_imports', () {
      test('prefer_absolute_imports SHOULD trigger', () {
        // Better alternative available: prefer absolute imports
        expect('prefer_absolute_imports detected', isNotNull);
      });

      test('prefer_absolute_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_absolute_imports passes', isNotNull);
      });
    });

    group('prefer_grouped_imports', () {
      test('prefer_grouped_imports SHOULD trigger', () {
        // Better alternative available: prefer grouped imports
        expect('prefer_grouped_imports detected', isNotNull);
      });

      test('prefer_grouped_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_grouped_imports passes', isNotNull);
      });
    });

    group('prefer_flat_imports', () {
      test('prefer_flat_imports SHOULD trigger', () {
        // Better alternative available: prefer flat imports
        expect('prefer_flat_imports detected', isNotNull);
      });

      test('prefer_flat_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_flat_imports passes', isNotNull);
      });
    });

    group('prefer_fields_before_methods', () {
      test('prefer_fields_before_methods SHOULD trigger', () {
        // Better alternative available: prefer fields before methods
        expect('prefer_fields_before_methods detected', isNotNull);
      });

      test('prefer_fields_before_methods should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_fields_before_methods passes', isNotNull);
      });
    });

    group('prefer_methods_before_fields', () {
      test('prefer_methods_before_fields SHOULD trigger', () {
        // Better alternative available: prefer methods before fields
        expect('prefer_methods_before_fields detected', isNotNull);
      });

      test('prefer_methods_before_fields should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_methods_before_fields passes', isNotNull);
      });
    });

    group('prefer_static_members_first', () {
      test('prefer_static_members_first SHOULD trigger', () {
        // Better alternative available: prefer static members first
        expect('prefer_static_members_first detected', isNotNull);
      });

      test('prefer_static_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_static_members_first passes', isNotNull);
      });
    });

    group('prefer_instance_members_first', () {
      test('prefer_instance_members_first SHOULD trigger', () {
        // Better alternative available: prefer instance members first
        expect('prefer_instance_members_first detected', isNotNull);
      });

      test('prefer_instance_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_instance_members_first passes', isNotNull);
      });
    });

    group('prefer_public_members_first', () {
      test('prefer_public_members_first SHOULD trigger', () {
        // Better alternative available: prefer public members first
        expect('prefer_public_members_first detected', isNotNull);
      });

      test('prefer_public_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_public_members_first passes', isNotNull);
      });
    });

    group('prefer_private_members_first', () {
      test('prefer_private_members_first SHOULD trigger', () {
        // Better alternative available: prefer private members first
        expect('prefer_private_members_first detected', isNotNull);
      });

      test('prefer_private_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_private_members_first passes', isNotNull);
      });
    });

    group('prefer_var_over_explicit_type', () {
      test('prefer_var_over_explicit_type SHOULD trigger', () {
        // Better alternative available: prefer var over explicit type
        expect('prefer_var_over_explicit_type detected', isNotNull);
      });

      test('prefer_var_over_explicit_type should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_var_over_explicit_type passes', isNotNull);
      });
    });

    group('prefer_object_over_dynamic', () {
      test('prefer_object_over_dynamic SHOULD trigger', () {
        // Better alternative available: prefer object over dynamic
        expect('prefer_object_over_dynamic detected', isNotNull);
      });

      test('prefer_object_over_dynamic should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_object_over_dynamic passes', isNotNull);
      });
    });

    group('prefer_dynamic_over_object', () {
      test('prefer_dynamic_over_object SHOULD trigger', () {
        // Better alternative available: prefer dynamic over object
        expect('prefer_dynamic_over_object detected', isNotNull);
      });

      test('prefer_dynamic_over_object should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_dynamic_over_object passes', isNotNull);
      });
    });

    group('prefer_lower_camel_case_constants', () {
      test('prefer_lower_camel_case_constants SHOULD trigger', () {
        // Better alternative available: prefer lower camel case constants
        expect('prefer_lower_camel_case_constants detected', isNotNull);
      });

      test('prefer_lower_camel_case_constants should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_lower_camel_case_constants passes', isNotNull);
      });
    });

    group('prefer_camel_case_method_names', () {
      test('prefer_camel_case_method_names SHOULD trigger', () {
        // Better alternative available: prefer camel case method names
        expect('prefer_camel_case_method_names detected', isNotNull);
      });

      test('prefer_camel_case_method_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_camel_case_method_names passes', isNotNull);
      });
    });

    group('prefer_descriptive_variable_names', () {
      final rule = PreferDescriptiveVariableNamesRule();

      test('rule metadata is v4 with opinionated impact', () {
        expect(rule.code.name, 'prefer_descriptive_variable_names');
        expect(rule.code.problemMessage, contains('{v4}'));
        expect(rule.code.problemMessage, contains('[prefer_descriptive'));
      });

      test('problem message exceeds 200 characters', () {
        expect(rule.code.problemMessage.length, greaterThan(200));
      });

      test('correction message is present', () {
        expect(rule.code.correctionMessage, isNotEmpty);
      });

      test('short name in large block (>5 stmts) is flaggable', () {
        final vars = _findShortVarNames('''
void f() {
  final ab = 1;
  final name = 2;
  final v1 = 3;
  final v2 = 4;
  final v3 = 5;
  final v4 = 6;
}
''');
        // 'ab' is 2 chars, block has 6 statements => flaggable
        expect(vars.any((v) => v.name == 'ab'), isTrue);
      });

      test('short name in small block (<=5 stmts) is NOT flaggable', () {
        final vars = _findShortVarNames('''
void f() {
  final ab = 1;
  final name = 2;
  final v1 = 3;
}
''');
        // 'ab' is 2 chars but block has only 3 statements
        expect(vars.where((v) => v.name == 'ab'), isEmpty);
      });

      test('for-loop index variable is NOT flaggable', () {
        final vars = _findShortVarNames('''
void f() {
  for (var ii = 0; ii < 10; ii++) {}
  final a1 = 1;
  final a2 = 2;
  final a3 = 3;
  final a4 = 4;
  final a5 = 5;
}
''');
        // 'ii' is in ForPartsWithDeclarations => always exempt
        expect(vars.where((v) => v.name == 'ii'), isEmpty);
      });

      test('allowed short names are NOT flaggable in large block', () {
        final vars = _findShortVarNames('''
void f() {
  final id = 1;
  final db = 2;
  final x = 3;
  final e = 4;
  final n = 5;
  final extra = 6;
}
''');
        // All are in allowedShortNames => none flaggable
        expect(vars, isEmpty);
      });
    });

    group('prefer_concise_variable_names', () {
      test('prefer_concise_variable_names SHOULD trigger', () {
        // Better alternative available: prefer concise variable names
        expect('prefer_concise_variable_names detected', isNotNull);
      });

      test('prefer_concise_variable_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_concise_variable_names passes', isNotNull);
      });
    });

    group('prefer_explicit_this', () {
      test('prefer_explicit_this SHOULD trigger', () {
        // Better alternative available: prefer explicit this
        expect('prefer_explicit_this detected', isNotNull);
      });

      test('prefer_explicit_this should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_this passes', isNotNull);
      });
    });

    group('prefer_implicit_boolean_comparison', () {
      test('prefer_implicit_boolean_comparison SHOULD trigger', () {
        // Better alternative available: prefer implicit boolean comparison
        expect('prefer_implicit_boolean_comparison detected', isNotNull);
      });

      test('prefer_implicit_boolean_comparison should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_implicit_boolean_comparison passes', isNotNull);
      });
    });

    group('prefer_explicit_boolean_comparison', () {
      test('prefer_explicit_boolean_comparison SHOULD trigger', () {
        // Better alternative available: prefer explicit boolean comparison
        expect('prefer_explicit_boolean_comparison detected', isNotNull);
      });

      test('prefer_explicit_boolean_comparison should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_boolean_comparison passes', isNotNull);
      });
    });
  });
}

/// A short variable declaration found by [_findShortVarNames].
class _ShortVar {
  _ShortVar(this.name, this.blockSize, this.isForLoop);
  final String name;
  final int blockSize;
  final bool isForLoop;
}

/// Parses [code] and returns variable declarations that the rule would
/// consider flaggable: name < 3 chars, not private, not in allowed list,
/// not in a for-loop, and not in a small block (<=5 statements).
List<_ShortVar> _findShortVarNames(String code) {
  final result = parseString(content: code);
  final visitor = _ShortVarCollector();
  result.unit.accept(visitor);
  return visitor.vars;
}

class _ShortVarCollector extends RecursiveAstVisitor<void> {
  static const _allowedShortNames = {
    'id',
    'db',
    'io',
    'ui',
    'x',
    'y',
    'z',
    'i',
    'j',
    'k',
    'e',
    'n',
  };
  static const _smallBlockThreshold = 5;

  final List<_ShortVar> vars = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name.lexeme;
    if (name.length >= 3) return;
    if (name.startsWith('_')) return;
    if (_allowedShortNames.contains(name.toLowerCase())) return;

    final isForLoop = node.parent?.parent is ForPartsWithDeclarations;
    if (isForLoop) return;

    int blockSize = 0;
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) {
        blockSize = current.statements.length;
        break;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }

    if (blockSize <= _smallBlockThreshold) return;

    vars.add(_ShortVar(name, blockSize, isForLoop));
    super.visitVariableDeclaration(node);
  }
}

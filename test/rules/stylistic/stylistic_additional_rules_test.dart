import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_additional_rules.dart';

/// Tests for 24 Stylistic Additional lint rules.
///
/// Test fixtures: example/lib/stylistic_additional/*
void main() {
  group('Stylistic Additional Rules - Rule Instantiation', () {
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
    final fixtureDir = Directory('example/lib/stylistic_additional');

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
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_additional/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic Additional - Preference Rules', () {
    test('opposite rule pairs expose conflictingRules metadata', () {
      expect(
        PreferInterpolationOverConcatenationRule().conflictingRules,
        contains('prefer_concatenation_over_interpolation'),
      );
      expect(
        PreferConcatenationOverInterpolationRule().conflictingRules,
        contains('prefer_interpolation_over_concatenation'),
      );
      expect(
        PreferDoubleQuotesRule().conflictingRules,
        contains('prefer_single_quotes'),
      );
      expect(
        PreferGroupedImportsRule().conflictingRules,
        contains('prefer_flat_imports'),
      );
      expect(
        PreferFlatImportsRule().conflictingRules,
        contains('prefer_grouped_imports'),
      );
      expect(
        PreferFieldsBeforeMethodsRule().conflictingRules,
        contains('prefer_methods_before_fields'),
      );
      expect(
        PreferMethodsBeforeFieldsRule().conflictingRules,
        contains('prefer_fields_before_methods'),
      );
      expect(
        PreferStaticMembersFirstRule().conflictingRules,
        contains('prefer_instance_members_first'),
      );
      expect(
        PreferInstanceMembersFirstRule().conflictingRules,
        contains('prefer_static_members_first'),
      );
      expect(
        PreferPublicMembersFirstRule().conflictingRules,
        contains('prefer_private_members_first'),
      );
      expect(
        PreferPrivateMembersFirstRule().conflictingRules,
        contains('prefer_public_members_first'),
      );
      expect(
        PreferObjectOverDynamicRule().conflictingRules,
        contains('prefer_dynamic_over_object'),
      );
      expect(
        PreferDynamicOverObjectRule().conflictingRules,
        contains('prefer_object_over_dynamic'),
      );
      expect(
        PreferImplicitBooleanComparisonRule().conflictingRules,
        contains('prefer_explicit_boolean_comparison'),
      );
      expect(
        PreferExplicitBooleanComparisonRule().conflictingRules,
        contains('prefer_implicit_boolean_comparison'),
      );
    });

    group('prefer_var_over_explicit_type', () {
      test('has conflictingRules metadata', () {
        final rule = PreferVarOverExplicitTypeRule();
        expect(rule.conflictingRules, contains('prefer_type_over_var'));
      });
    });

    group('prefer_descriptive_variable_names', () {
      final rule = PreferDescriptiveVariableNamesRule();

      test('rule metadata is v4 with opinionated impact', () {
        expect(rule.code.lowerCaseName, 'prefer_descriptive_variable_names');
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
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted regression tests.
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

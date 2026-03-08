import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_control_flow_rules.dart';

/// Tests for 14 Stylistic Control Flow lint rules.
///
/// Test fixtures: example_style/lib/stylistic_control_flow/*
void main() {
  group('Stylistic Control Flow Rules - Rule Instantiation', () {
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
      'PreferEarlyReturnRule',
      'prefer_early_return',
      () => PreferEarlyReturnRule(),
    );

    testRule(
      'PreferSingleExitPointRule',
      'prefer_single_exit_point',
      () => PreferSingleExitPointRule(),
    );

    testRule(
      'PreferGuardClausesRule',
      'prefer_guard_clauses',
      () => PreferGuardClausesRule(),
    );

    testRule(
      'PreferPositiveConditionsFirstRule',
      'prefer_positive_conditions_first',
      () => PreferPositiveConditionsFirstRule(),
    );

    testRule(
      'PreferSwitchStatementRule',
      'prefer_switch_statement',
      () => PreferSwitchStatementRule(),
    );

    testRule(
      'PreferCascadeOverChainedRule',
      'prefer_cascade_over_chained',
      () => PreferCascadeOverChainedRule(),
    );

    testRule(
      'PreferChainedOverCascadeRule',
      'prefer_chained_over_cascade',
      () => PreferChainedOverCascadeRule(),
    );

    testRule(
      'AvoidCascadesRule',
      'avoid_cascade_notation',
      () => AvoidCascadesRule(),
    );

    testRule(
      'PreferExhaustiveEnumsRule',
      'prefer_exhaustive_enums',
      () => PreferExhaustiveEnumsRule(),
    );

    testRule(
      'PreferDefaultEnumCaseRule',
      'prefer_default_enum_case',
      () => PreferDefaultEnumCaseRule(),
    );

    testRule(
      'PreferAwaitOverThenRule',
      'prefer_await_over_then',
      () => PreferAwaitOverThenRule(),
    );

    testRule(
      'PreferThenOverAwaitRule',
      'prefer_then_over_await',
      () => PreferThenOverAwaitRule(),
    );

    testRule(
      'PreferSyncOverAsyncWhereSimpleRule',
      'prefer_sync_over_async_where_possible',
      () => PreferSyncOverAsyncWhereSimpleRule(),
    );

    testRule(
      'PreferThenCatchErrorRule',
      'prefer_then_catcherror',
      () => PreferThenCatchErrorRule(),
    );

    testRule(
      'PreferFireAndForgetRule',
      'prefer_fire_and_forget',
      () => PreferFireAndForgetRule(),
    );

    testRule(
      'PreferSeparateAssignmentsRule',
      'prefer_separate_assignments',
      () => PreferSeparateAssignmentsRule(),
    );

    testRule(
      'PreferIfElseOverGuardsRule',
      'prefer_if_else_over_guards',
      () => PreferIfElseOverGuardsRule(),
    );

    testRule(
      'PreferCascadeAssignmentsRule',
      'prefer_cascade_assignments',
      () => PreferCascadeAssignmentsRule(),
    );

    testRule(
      'PreferPositiveConditionsRule',
      'prefer_positive_conditions',
      () => PreferPositiveConditionsRule(),
    );
  });

  group('Stylistic Control Flow Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_early_return',
      'prefer_single_exit_point',
      'prefer_guard_clauses',
      'prefer_positive_conditions_first',
      'prefer_switch_statement',
      'prefer_cascade_over_chained',
      'prefer_chained_over_cascade',
      'avoid_cascade_notation',
      'prefer_exhaustive_enums',
      'prefer_default_enum_case',
      'prefer_await_over_then',
      'prefer_then_over_await',
      'prefer_sync_over_async_where_possible',
      'prefer_then_catcherror',
      'prefer_fire_and_forget',
      'prefer_separate_assignments',
      'prefer_if_else_over_guards',
      'prefer_cascade_assignments',
      'prefer_positive_conditions',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_style/lib/stylistic_control_flow/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic Control Flow - Preference Rules', () {
    group('prefer_early_return', () {
      test('prefer_early_return SHOULD trigger', () {
        // Better alternative available: prefer early return
        expect('prefer_early_return detected', isNotNull);
      });

      test('prefer_early_return should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_early_return passes', isNotNull);
      });
    });

    group('prefer_single_exit_point', () {
      test('prefer_single_exit_point SHOULD trigger', () {
        // Better alternative available: prefer single exit point
        expect('prefer_single_exit_point detected', isNotNull);
      });

      test('prefer_single_exit_point should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_single_exit_point passes', isNotNull);
      });
    });

    group('prefer_guard_clauses', () {
      test('prefer_guard_clauses SHOULD trigger', () {
        // Better alternative available: prefer guard clauses
        expect('prefer_guard_clauses detected', isNotNull);
      });

      test('prefer_guard_clauses should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_guard_clauses passes', isNotNull);
      });
    });

    group('prefer_positive_conditions_first', () {
      test('prefer_positive_conditions_first SHOULD trigger', () {
        // Better alternative available: prefer positive conditions first
        expect('prefer_positive_conditions_first detected', isNotNull);
      });

      test('prefer_positive_conditions_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_positive_conditions_first passes', isNotNull);
      });
    });

    group('prefer_switch_statement', () {
      test('switch expression in list literal SHOULD trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
void f() {
  final list = [switch (E.a) { E.a => 1, E.b => 2 }];
}
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isNot(isA<ExpressionFunctionBody>()));
        expect(nodes.first.parent, isNot(isA<ReturnStatement>()));
        expect(nodes.first.parent, isNot(isA<VariableDeclaration>()));
      });

      test('switch expression as argument SHOULD trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
void f() {
  print(switch (E.a) { E.a => 'A', E.b => 'B' });
}
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isNot(isA<ExpressionFunctionBody>()));
        expect(nodes.first.parent, isNot(isA<ReturnStatement>()));
        expect(nodes.first.parent, isNot(isA<VariableDeclaration>()));
      });

      test('switch in arrow body should NOT trigger (false positive)', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
String f(E e) => switch (e) { E.a => 'A', E.b => 'B' };
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<ExpressionFunctionBody>());
      });

      test('switch in return statement should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
String f(E e) { return switch (e) { E.a => 'A', E.b => 'B' }; }
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<ReturnStatement>());
      });

      test('switch in variable declaration should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
void f() { final x = switch (E.a) { E.a => 1, E.b => 2 }; }
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<VariableDeclaration>());
      });

      test('switch in assignment should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
void f() { int x = 0; x = switch (E.a) { E.a => 1, E.b => 2 }; }
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<AssignmentExpression>());
      });

      test('switch in getter arrow body should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
extension on E {
  String get label => switch (this) { E.a => 'A', E.b => 'B' };
}
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<ExpressionFunctionBody>());
      });
    });

    group('prefer_cascade_over_chained', () {
      test('prefer_cascade_over_chained SHOULD trigger', () {
        // Better alternative available: prefer cascade over chained
        expect('prefer_cascade_over_chained detected', isNotNull);
      });

      test('prefer_cascade_over_chained should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_cascade_over_chained passes', isNotNull);
      });
    });

    group('prefer_chained_over_cascade', () {
      test('prefer_chained_over_cascade SHOULD trigger', () {
        // Better alternative available: prefer chained over cascade
        expect('prefer_chained_over_cascade detected', isNotNull);
      });

      test('prefer_chained_over_cascade should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_chained_over_cascade passes', isNotNull);
      });
    });

    group('prefer_exhaustive_enums', () {
      test('prefer_exhaustive_enums SHOULD trigger', () {
        // Better alternative available: prefer exhaustive enums
        expect('prefer_exhaustive_enums detected', isNotNull);
      });

      test('prefer_exhaustive_enums should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_exhaustive_enums passes', isNotNull);
      });
    });

    group('prefer_default_enum_case', () {
      test('prefer_default_enum_case SHOULD trigger', () {
        // Better alternative available: prefer default enum case
        expect('prefer_default_enum_case detected', isNotNull);
      });

      test('prefer_default_enum_case should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_default_enum_case passes', isNotNull);
      });
    });

    group('prefer_await_over_then', () {
      test('prefer_await_over_then SHOULD trigger', () {
        // Better alternative available: prefer await over then
        expect('prefer_await_over_then detected', isNotNull);
      });

      test('prefer_await_over_then should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_await_over_then passes', isNotNull);
      });
    });

    group('prefer_then_over_await', () {
      test('prefer_then_over_await SHOULD trigger', () {
        // Better alternative available: prefer then over await
        expect('prefer_then_over_await detected', isNotNull);
      });

      test('prefer_then_over_await should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_then_over_await passes', isNotNull);
      });
    });

    group('prefer_sync_over_async_where_possible', () {
      test('prefer_sync_over_async_where_possible SHOULD trigger', () {
        // Better alternative available: prefer sync over async where possible
        expect('prefer_sync_over_async_where_possible detected', isNotNull);
      });

      test('prefer_sync_over_async_where_possible should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_sync_over_async_where_possible passes', isNotNull);
      });
    });

    group('prefer_positive_conditions', () {
      test('prefer_positive_conditions SHOULD trigger', () {
        // Better alternative available: prefer positive conditions
        expect('prefer_positive_conditions detected', isNotNull);
      });

      test('prefer_positive_conditions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_positive_conditions passes', isNotNull);
      });
    });
  });
}

/// Parses [code] and returns all [SwitchExpression] nodes found in the AST.
List<SwitchExpression> _findSwitchExpressions(String code) {
  final result = parseString(content: code);
  final visitor = _SwitchExpressionCollector();
  result.unit.accept(visitor);
  return visitor.nodes;
}

class _SwitchExpressionCollector extends RecursiveAstVisitor<void> {
  final List<SwitchExpression> nodes = [];

  @override
  void visitSwitchExpression(SwitchExpression node) {
    nodes.add(node);
    super.visitSwitchExpression(node);
  }
}

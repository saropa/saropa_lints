import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_control_flow_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 14 Stylistic Control Flow lint rules.
///
/// Test fixtures: example/lib/stylistic_control_flow/*
// Control flow style rules: for/else/try patterns; see fixtures for LINT cases.
void main() {
  group('Stylistic Control Flow Rules - Rule Instantiation', () {
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
    final fixtureDir = Directory('example/lib/stylistic_control_flow');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_control_flow/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic Control Flow - Preference Rules', () {
    group('prefer_positive_conditions_first', () {
      test('negated guard (!condition) SHOULD trigger', () {
        final guards = _findNegatedGuards('''
void f(bool isValid) {
  if (!isValid) return;
  print('ok');
}
''');
        expect(guards, hasLength(1));
      });

      test('negated guard in block form SHOULD trigger', () {
        final guards = _findNegatedGuards('''
void f(bool ready) {
  if (!ready) {
    return;
  }
  print('ok');
}
''');
        expect(guards, hasLength(1));
      });

      test('null-guard (== null) should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(int? value) {
  if (value == null) return;
  print(value);
}
''');
        expect(guards, isEmpty);
      });

      test('null on left side (null == x) should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(int? value) {
  if (null == value) return;
  print(value);
}
''');
        expect(guards, isEmpty);
      });

      test('positive condition should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(bool ok) {
  if (ok) return;
  print('not ok');
}
''');
        expect(guards, isEmpty);
      });

      test('if with else should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(bool ok) {
  if (!ok) {
    return;
  } else {
    print('ok');
  }
}
''');
        expect(guards, isEmpty);
      });

      test('non-return body should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(bool ok) {
  if (!ok) print('bad');
  print('continue');
}
''');
        expect(guards, isEmpty);
      });

      test('throw guard should NOT trigger', () {
        final guards = _findNegatedGuards('''
void f(bool ok) {
  if (!ok) throw Exception('bad');
  print('ok');
}
''');
        expect(guards, isEmpty);
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

      test('switch in yield statement should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
Stream<String> f() async* {
  yield switch (E.a) { E.a => 'A', E.b => 'B' };
}
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<YieldStatement>());
      });

      test('switch as named argument should NOT trigger', () {
        final nodes = _findSwitchExpressions('''
enum E { a, b }
void g({required String label}) {}
void f() {
  g(label: switch (E.a) { E.a => 'A', E.b => 'B' });
}
''');
        expect(nodes, hasLength(1));
        expect(nodes.first.parent, isA<NamedExpression>());
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

/// Parses [code] and returns if-statements that match the rule's trigger:
/// guard clause with negated condition (! operator), single return, no else.
List<IfStatement> _findNegatedGuards(String code) {
  final result = parseString(content: code);
  final visitor = _NegatedGuardCollector();
  result.unit.accept(visitor);
  return visitor.nodes;
}

class _NegatedGuardCollector extends RecursiveAstVisitor<void> {
  final List<IfStatement> nodes = [];

  @override
  void visitIfStatement(IfStatement node) {
    if (node.elseStatement == null) {
      Statement? inner = node.thenStatement;
      if (inner is Block && inner.statements.length == 1) {
        inner = inner.statements.first;
      }
      if (inner is ReturnStatement) {
        final condition = node.expression;
        if (condition is PrefixExpression &&
            condition.operator.type == TokenType.BANG) {
          nodes.add(node);
        }
      }
    }
    super.visitIfStatement(node);
  }
}

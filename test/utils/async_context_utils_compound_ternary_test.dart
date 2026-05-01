import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/async_context_utils.dart';
import 'package:test/test.dart';

/// Behavioral checks for `ContextUsageFinder` recognition of compound
/// `&&` mounted guards in ternary conditions (avoid_context_across_async v7,
/// avoid_context_after_await_in_static v5).
///
/// Reproduces the false positive documented in
/// `bugs/avoid_context_across_async_false_positive_compound_ternary_guard.md`:
/// `context != null && context.mounted ? context : null` was flagging both
/// the LHS context (in the null check) and the then-branch context, even
/// though the compound guards both the null and unmounted cases.
///
/// The fix's structural pieces — `isInsideMountedGuardedCondition`,
/// `isNullCheckOperand`, `isAstDescendant` — were extracted as top-level
/// helpers in `async_context_utils.dart` so the static-method visitor
/// (`_StaticContextUsageFinder`, library-private) reuses the same logic
/// with a different `isMountedCheck` predicate (param-name aware). This
/// file covers BOTH: behavioral tests against `ContextUsageFinder`, and
/// direct tests against the shared helpers driven with a param-name
/// predicate that mirrors the static-method visitor's contract.
void main() {
  group('ContextUsageFinder — compound mounted guard ternary', () {
    test('plain mounted ternary: `context.mounted ? context : null`', () {
      final reported = _walk('''
Object f(Object context) {
  return context.mounted ? context : null;
}
''');
      // `context.mounted` is the only allowed PrefixedIdentifier reference;
      // the then-branch context is guarded — nothing else should be reported.
      expect(reported, isEmpty);
    });

    test(
      'compound nullable guard: `context != null && context.mounted ? context : null`',
      () {
        final reported = _walk('''
Object f(Object? context) {
  return context != null && context.mounted ? context : null;
}
''');
        // Bug fix: the LHS `context` (in `context != null`) and the
        // then-branch `context` are both part of the compound guard. Only
        // `context.mounted` reads `context` here, and it's already excluded
        // by the existing PrefixedIdentifier skip.
        expect(reported, isEmpty);
      },
    );

    test(
      'mounted on left of `&&`: `context.mounted && other ? context : null`',
      () {
        final reported = _walk('''
Object f(Object context, bool other) {
  return context.mounted && other ? context : null;
}
''');
        expect(reported, isEmpty);
      },
    );

    test(
      'mounted on right of `&&`: `other && context.mounted ? context : null`',
      () {
        final reported = _walk('''
Object f(Object context, bool other) {
  return other && context.mounted ? context : null;
}
''');
        expect(reported, isEmpty);
      },
    );

    test(
      'unguarded ternary still reports: `other ? context : null` is not safe',
      () {
        final reported = _walk('''
Object f(Object context, bool other) {
  return other ? context : null;
}
''');
        // Sanity check that the new skips are scoped — without a mounted
        // operand in the condition, the then-branch context is still flagged.
        expect(reported, equals(['context']));
      },
    );

    test(
      'unguarded `context != null` outside a mounted compound still reports the LHS',
      () {
        final reported = _walk('''
Object f(Object? context) {
  return context != null ? context : null;
}
''');
        // The new Gap-2 skip only kicks in when the enclosing condition
        // also contains a mounted check. Plain `context != null ? context :
        // null` carries no mounted protection, so both `context` references
        // remain reportable.
        expect(reported, equals(['context', 'context']));
      },
    );
  });

  // The static-method visitor (`_StaticContextUsageFinder`, used by
  // `avoid_context_after_await_in_static`) is library-private but reuses
  // the same shared helpers. Driving the helpers directly with a param-
  // name predicate mirrors that visitor's call shape and lets us verify
  // the static path without exposing the visitor.
  group('isInsideMountedGuardedCondition / isNullCheckOperand', () {
    test(
      'compound `param != null && param.mounted` ternary: param-name predicate sees a guard',
      () {
        final probe = _findCompoundProbe(
          source: '''
Object f(Object? ctx) {
  return ctx != null && ctx.mounted ? ctx : null;
}
''',
          paramName: 'ctx',
        );
        // The helpers must agree this is a guarded structure.
        expect(probe.isInsideGuard, isTrue);
        expect(probe.isNullCheck, isTrue);
      },
    );

    test(
      'compound `&&` with a different param name: predicate filters it out',
      () {
        // Here the predicate only counts `ctx.mounted` as a mounted check;
        // an `other.mounted` operand should NOT satisfy a `ctx`-scoped
        // guard, modeling how the static visitor avoids cross-param leaks.
        final probe = _findCompoundProbe(
          source: '''
Object f(Object? ctx, Object other) {
  return ctx != null && other.mounted ? ctx : null;
}
''',
          paramName: 'ctx',
        );
        expect(probe.isInsideGuard, isFalse);
      },
    );

    test('plain ternary without `&&`: not a guard for the LHS', () {
      // Here the ternary's condition IS the null-check directly — no
      // surrounding `&&` to walk past — so use the bare-null-check probe.
      final probe = _findBareNullCheckProbe(
        source: '''
Object f(Object? ctx) {
  return ctx != null ? ctx : null;
}
''',
        paramName: 'ctx',
      );
      // `ctx != null` alone has no mounted operand — the helper rejects.
      expect(probe.isInsideGuard, isFalse);
      // Structural test still holds: `ctx` is the LHS of `!= null`.
      expect(probe.isNullCheck, isTrue);
    });

    test(
      'isNullCheckOperand rejects `==` (only `!=` counts as a null guard)',
      () {
        // `ctx == null ? ... : ...` is the inverse polarity — the
        // helper must NOT treat it as a null-guard operand, otherwise
        // we would incorrectly skip context refs sitting inside a
        // condition that proves the value IS null.
        final probe = _findEqEqProbe(
          source: '''
Object f(Object? ctx) {
  return ctx == null ? null : ctx;
}
''',
        );
        expect(probe.isNullCheck, isFalse);
      },
    );
  });
}

/// Result bundle for a compound-ternary helper probe.
class _Probe {
  _Probe({required this.isInsideGuard, required this.isNullCheck});
  final bool isInsideGuard;
  final bool isNullCheck;
}

/// Parses [source], finds the `param != null` BinaryExpression at the LHS
/// of a compound `&&` inside the only ternary's condition, and runs the
/// shared helpers against the LHS [paramName] identifier with an
/// `isMountedCheck` predicate that recognizes `<paramName>.mounted` and
/// recurses through `&&`.
_Probe _findCompoundProbe({required String source, required String paramName}) {
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;

  ConditionalExpression? ternary;
  unit.accept(_PickConditional((node) => ternary ??= node));
  expect(ternary, isNotNull, reason: 'fixture must contain one ternary');

  // The condition is a BinaryExpression `&&` whose left operand is
  // `param != null`. Extract that null-check expression and its LHS.
  final and = ternary!.condition;
  expect(and, isA<BinaryExpression>());
  final left = (and as BinaryExpression).leftOperand;
  expect(left, isA<BinaryExpression>(), reason: 'expected `param != null`');
  final nullCheck = left as BinaryExpression;
  final lhs = nullCheck.leftOperand;
  expect(
    lhs,
    isA<SimpleIdentifier>(),
    reason: 'expected `<param>` as LHS of `!=`',
  );

  // Predicate: `<paramName>.mounted` is the only literal mounted check;
  // recurse through `&&` so compound conditions resolve correctly.
  bool isMountedCheck(Expression expr) {
    if (expr is PrefixedIdentifier &&
        expr.identifier.name == 'mounted' &&
        expr.prefix.name == paramName) {
      return true;
    }
    if (expr is BinaryExpression &&
        expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
      return isMountedCheck(expr.leftOperand) ||
          isMountedCheck(expr.rightOperand);
    }
    return false;
  }

  return _Probe(
    isInsideGuard: isInsideMountedGuardedCondition(nullCheck, isMountedCheck),
    isNullCheck: isNullCheckOperand(lhs as SimpleIdentifier, nullCheck),
  );
}

/// Parses [source] containing `param != null ? param : null` (no `&&`)
/// and runs the helpers against the LHS of the ternary's condition —
/// which IS the `!=` BinaryExpression directly, with no surrounding `&&`.
/// Used to verify the helpers correctly reject this as a mounted guard
/// (no mounted operand in the condition).
_Probe _findBareNullCheckProbe({
  required String source,
  required String paramName,
}) {
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;

  ConditionalExpression? ternary;
  unit.accept(_PickConditional((node) => ternary ??= node));
  expect(ternary, isNotNull);

  final cond = ternary!.condition;
  expect(cond, isA<BinaryExpression>(), reason: 'expected `param != null`');
  final nullCheck = cond as BinaryExpression;
  final lhs = nullCheck.leftOperand;
  expect(lhs, isA<SimpleIdentifier>());

  // Same predicate shape as the compound probe — there is no mounted
  // operand here so the predicate's outcome is what we're testing.
  bool isMountedCheck(Expression expr) {
    if (expr is PrefixedIdentifier &&
        expr.identifier.name == 'mounted' &&
        expr.prefix.name == paramName) {
      return true;
    }
    if (expr is BinaryExpression &&
        expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
      return isMountedCheck(expr.leftOperand) ||
          isMountedCheck(expr.rightOperand);
    }
    return false;
  }

  return _Probe(
    isInsideGuard: isInsideMountedGuardedCondition(nullCheck, isMountedCheck),
    isNullCheck: isNullCheckOperand(lhs as SimpleIdentifier, nullCheck),
  );
}

/// Parses [source] containing `<id> == null ? ... : ...` and asks the
/// shared helper whether the LHS satisfies `isNullCheckOperand` — it
/// must NOT, since `==` is opposite polarity.
_Probe _findEqEqProbe({required String source}) {
  final unit = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;

  ConditionalExpression? ternary;
  unit.accept(_PickConditional((node) => ternary ??= node));
  expect(ternary, isNotNull);
  final cond = ternary!.condition;
  expect(cond, isA<BinaryExpression>());
  final binary = cond as BinaryExpression;
  return _Probe(
    isInsideGuard: false,
    isNullCheck: isNullCheckOperand(
      binary.leftOperand as SimpleIdentifier,
      binary,
    ),
  );
}

/// Picks the first `ConditionalExpression` it sees.
class _PickConditional extends RecursiveAstVisitor<void> {
  _PickConditional(this.onPick);
  final void Function(ConditionalExpression) onPick;

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    onPick(node);
    super.visitConditionalExpression(node);
  }
}

/// Parses [body] as a compilation unit and walks every block/expression
/// function body with [ContextUsageFinder], collecting the lexeme of each
/// reported `context` identifier in source order.
List<String> _walk(String unitSource) {
  final result = parseString(
    content: unitSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final reported = <SimpleIdentifier>[];
  result.unit.accept(
    _BodyVisitor((body) {
      body.visitChildren(ContextUsageFinder(onContextFound: reported.add));
    }),
  );
  return reported.map((n) => n.name).toList();
}

/// Picks every `BlockFunctionBody` / `ExpressionFunctionBody` so the
/// finder runs against the real method body shape used by the rule.
class _BodyVisitor extends RecursiveAstVisitor<void> {
  _BodyVisitor(this.onBody);
  final void Function(FunctionBody) onBody;

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    onBody(node);
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    onBody(node);
    super.visitExpressionFunctionBody(node);
  }
}

// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace raw literal matchers with proper test matchers.
///
/// Handles three patterns reported by [AvoidMisusedTestMatchersRule]:
///   - `expect(x, true/false)` → `expect(x, isTrue/isFalse)`
///   - `expect(x, null)` → `expect(x, isNull)`
///   - `expect(x.length, N)` → `expect(x, hasLength(N))`
class ReplaceMisusedTestMatcherFix extends SaropaFixProducer {
  ReplaceMisusedTestMatcherFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceMisusedTestMatcher',
    50,
    'Replace with proper test matcher',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Navigate up to the expect() MethodInvocation regardless of which
    // child the diagnostic was reported on (the literal for bool/null,
    // or the full invocation for length).
    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    if (invocation.methodName.name != 'expect') return;

    final positionalArgs = invocation.argumentList.arguments
        .where((e) => e is! NamedExpression)
        .toList();
    if (positionalArgs.length < 2) return;

    final actual = positionalArgs[0];
    final matcher = positionalArgs[1];

    // Pattern 1: expect(x, true) → expect(x, isTrue)
    // Pattern 2: expect(x, false) → expect(x, isFalse)
    if (matcher is BooleanLiteral) {
      final replacement = matcher.value ? 'isTrue' : 'isFalse';
      await _replaceMatcher(builder, matcher, replacement);
      return;
    }

    // Pattern 3: expect(x, null) → expect(x, isNull)
    if (matcher is NullLiteral) {
      await _replaceMatcher(builder, matcher, 'isNull');
      return;
    }

    // Pattern 4: expect(x.length, N) → expect(x, hasLength(N))
    if (matcher is IntegerLiteral && _isLengthAccess(actual)) {
      final value = matcher.value;
      if (value == null) return;

      // Strip the trailing `.length` from the actual expression to get the
      // collection receiver, then rewrite the whole invocation.
      final receiverSrc = _stripLengthSuffix(actual);
      if (receiverSrc == null) return;

      final replacement = 'expect($receiverSrc, hasLength($value))';
      await _replaceInvocation(builder, invocation, replacement);
      return;
    }
  }

  /// Replaces just the matcher argument (bool/null literal) with a proper
  /// matcher identifier, preserving the rest of the expect() call.
  Future<void> _replaceMatcher(
    ChangeBuilder builder,
    Expression matcher,
    String replacement,
  ) async {
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(matcher.offset, matcher.length),
        replacement,
      );
    });
  }

  /// Replaces the entire expect() invocation (needed for length rewrites
  /// where the actual argument also changes).
  Future<void> _replaceInvocation(
    ChangeBuilder builder,
    MethodInvocation invocation,
    String replacement,
  ) async {
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        replacement,
      );
    });
  }

  /// Returns the source text of the expression minus the trailing `.length`.
  String? _stripLengthSuffix(Expression expr) {
    // PropertyAccess: `collection.length` — receiver is `collection`
    if (expr is PropertyAccess) {
      return expr.target?.toSource();
    }
    // PrefixedIdentifier: `list.length` — prefix is `list`
    if (expr is PrefixedIdentifier) {
      return expr.prefix.toSource();
    }
    return null;
  }

  /// Whether the expression accesses `.length` on a receiver.
  bool _isLengthAccess(Expression expr) {
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'length';
    }
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'length';
    }
    return false;
  }
}

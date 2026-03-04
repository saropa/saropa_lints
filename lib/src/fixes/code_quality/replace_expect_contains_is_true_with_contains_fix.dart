// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace expect(x.contains(y), isTrue) with expect(x, contains(y)).
///
/// **Rule:** [PreferTestMatchersRule] (contains/isTrue pattern).
///
/// **Behavior:** Rewrites the [MethodInvocation] for `expect` so the first
/// argument is the receiver of `.contains()` and the second is `contains(arg)`.
/// Only applies when the matcher is the `isTrue` identifier; `isFalse` is
/// not rewritten (would require `isNot(contains(y))`). Requires a non-empty
/// argument list for the `.contains()` call.
class ReplaceExpectContainsIsTrueWithContainsFix extends SaropaFixProducer {
  ReplaceExpectContainsIsTrueWithContainsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceExpectContainsIsTrueWithContains',
    50,
    'Use expect(x, contains(y))',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final MethodInvocation? expectCall = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (expectCall == null || expectCall.methodName.name != 'expect') return;

    final List<Expression> args = expectCall.argumentList.arguments.toList();
    if (args.length < 2) return;

    final Expression actual = args[0];
    final Expression matcher = args[1];

    if (actual is! MethodInvocation ||
        actual.methodName.name != 'contains') {
      return;
    }
    if (matcher is! SimpleIdentifier ||
        (matcher.name != 'isTrue' && matcher.name != 'isFalse')) {
      return;
    }
    if (matcher.name == 'isFalse') {
      // expect(x.contains(y), isFalse) -> expect(x, isNot(contains(y)))
      // Skip for simplicity; only fix isTrue case
      return;
    }

    final Expression? containsTarget = actual.target;
    if (containsTarget == null) return;
    final List<Expression> containsArgs = actual.argumentList.arguments.toList();
    if (containsArgs.isEmpty) return;
    final Expression firstArg = containsArgs[0];

    final String targetSrc = containsTarget.toSource();
    final String argSrc = firstArg.toSource();
    final String replacement = 'expect($targetSrc, contains($argSrc))';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(expectCall.offset, expectCall.length),
        replacement,
      );
    });
  }
}

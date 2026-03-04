// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace expect(list.length, equals(0)) with expect(list, isEmpty).
///
/// Matches [PreferTestMatchersRule] for the length/equals(0) pattern.
class ReplaceExpectLengthEqualsZeroWithIsEmptyFix extends SaropaFixProducer {
  ReplaceExpectLengthEqualsZeroWithIsEmptyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceExpectLengthEqualsZeroWithIsEmpty',
    50,
    'Use expect(list, isEmpty)',
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

    if (actual is! PropertyAccess ||
        actual.propertyName.name != 'length') {
      return;
    }
    if (matcher is! MethodInvocation ||
        matcher.methodName.name != 'equals') {
      return;
    }
    final List<Expression> matcherArgs = matcher.argumentList.arguments.toList();
    if (matcherArgs.isEmpty) return;
    final Expression matcherArg = matcherArgs[0];
    if (matcherArg is! IntegerLiteral || matcherArg.value != 0) return;

    final Expression? lengthTarget = actual.target;
    if (lengthTarget == null) return;
    final String listSrc = lengthTarget.toSource();
    final String replacement = 'expect($listSrc, isEmpty)';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(expectCall.offset, expectCall.length),
        replacement,
      );
    });
  }
}

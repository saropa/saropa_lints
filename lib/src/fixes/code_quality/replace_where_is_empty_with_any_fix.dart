// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace where().isEmpty/isNotEmpty with !any()/any().
///
/// Matches [PreferAnyOrEveryRule].
class ReplaceWhereIsEmptyWithAnyFix extends SaropaFixProducer {
  ReplaceWhereIsEmptyWithAnyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWhereIsEmptyWithAny',
    50,
    'Use .any() instead of .where().isEmpty/isNotEmpty',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final PropertyAccess? access = node is PropertyAccess
        ? node
        : node.thisOrAncestorOfType<PropertyAccess>();
    if (access == null) return;

    final String propertyName = access.propertyName.name;
    if (propertyName != 'isEmpty' && propertyName != 'isNotEmpty') return;

    final Expression? target = access.target;
    if (target is! MethodInvocation || target.methodName.name != 'where') return;

    final Expression? whereReceiver = target.target;
    if (whereReceiver == null) return;

    final String receiverSrc = whereReceiver.toSource();
    final String argsSrc = target.argumentList.arguments
        .map((e) => e.toSource())
        .join(', ');
    final bool useNegation = propertyName == 'isEmpty';
    final String replacement =
        useNegation
            ? '!$receiverSrc.any($argsSrc)'
            : '$receiverSrc.any($argsSrc)';

    final int start = target.offset;
    final int end = access.end;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(start, end - start), replacement);
    });
  }
}

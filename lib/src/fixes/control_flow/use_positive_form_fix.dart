// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `!x.isEmpty` with `x.isNotEmpty`.
class UsePositiveFormFix extends SaropaFixProducer {
  UsePositiveFormFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.usePositiveForm',
    50,
    'Use positive form',
  );

  @override
  FixKind get fixKind => _fixKind;

  static const _positiveForm = <String, String>{
    'isEmpty': 'isNotEmpty',
    'isEven': 'isOdd',
    'isOdd': 'isEven',
    'isNaN': 'isFinite',
    'isInfinite': 'isFinite',
    'isNegative': 'isNonNegative',
    'isFinite': 'isInfinite',
  };

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final prefix = node is PrefixExpression
        ? node
        : node.thisOrAncestorOfType<PrefixExpression>();
    if (prefix == null) return;

    final operand = prefix.operand;
    String? targetSource;
    String? propertyName;

    if (operand is PropertyAccess) {
      targetSource = operand.target?.toSource();
      propertyName = operand.propertyName.name;
    } else if (operand is PrefixedIdentifier) {
      targetSource = operand.prefix.toSource();
      propertyName = operand.identifier.name;
    }

    if (targetSource == null || propertyName == null) return;

    final positive = _positiveForm[propertyName];
    if (positive == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(prefix.offset, prefix.length),
        '$targetSource.$positive',
      );
    });
  }
}

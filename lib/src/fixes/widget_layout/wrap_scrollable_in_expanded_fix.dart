// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Wraps the scrollable in `Expanded(child: ...)`.
class WrapScrollableInExpandedFix extends SaropaFixProducer {
  WrapScrollableInExpandedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapScrollableInExpandedFix',
    50,
    'Wrap in Expanded',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node?.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final parent = ctorName.parent;
    if (parent is! InstanceCreationExpression) return;
    final ice = parent;

    final wrapped = 'Expanded(child: ${ice.toSource()})';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(ice.offset, ice.length),
        wrapped,
      );
    });
  }
}

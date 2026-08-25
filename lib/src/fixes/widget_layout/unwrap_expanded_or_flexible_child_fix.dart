// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces `Expanded(child: w)` / `Flexible(child: w)` with `w`.
///
/// Used when flex parent data should not wrap the child (call site, invalid
/// parent, etc.). Does not apply to [Spacer] (no child).
class UnwrapExpandedOrFlexibleChildFix extends SaropaFixProducer {
  UnwrapExpandedOrFlexibleChildFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.unwrapExpandedOrFlexibleChildFix',
    50,
    'Unwrap and use child only',
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
    final type = ice.constructorName.type.name.lexeme;
    if (type != 'Expanded' && type != 'Flexible') return;

    NamedExpression? childArg;
    for (final arg in ice.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        childArg = arg;
        break;
      }
    }
    if (childArg == null) return;

    final childSource = childArg.expression.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(ice.offset, ice.length),
        childSource,
      );
    });
  }
}

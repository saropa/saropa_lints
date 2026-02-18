// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with SizedBox.square
class PreferSizedBoxSquareFix extends SaropaFixProducer {
  PreferSizedBoxSquareFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferSizedBoxSquareFix',
    50,
    'Replace with SizedBox.square',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (target == null) return;

    // Find width and height arguments
    final args = target.argumentList.arguments;
    NamedExpression? widthArg;
    NamedExpression? heightArg;
    for (final arg in args) {
      if (arg is NamedExpression) {
        if (arg.name.label.name == 'width') widthArg = arg;
        if (arg.name.label.name == 'height') heightArg = arg;
      }
    }
    if (widthArg == null) return;

    // Build replacement: rename width: to dimension: and remove height:
    final source = target.toSource();
    var replacement = source.replaceFirst('SizedBox(', 'SizedBox.square(');
    // Rename width: to dimension:
    final widthSrc = widthArg.toSource();
    replacement = replacement.replaceFirst(
      widthSrc,
      widthSrc.replaceFirst('width:', 'dimension:'),
    );
    // Remove height: argument if present
    if (heightArg != null) {
      final heightSrc = heightArg.toSource();
      // Remove with leading or trailing comma
      replacement = replacement.replaceFirst(', $heightSrc', '');
      replacement = replacement.replaceFirst('$heightSrc, ', '');
      replacement = replacement.replaceFirst(heightSrc, '');
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}

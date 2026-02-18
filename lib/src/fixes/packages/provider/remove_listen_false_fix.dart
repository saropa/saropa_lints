// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Remove listen: false to enable rebuilds
class RemoveListenFalseFix extends SaropaFixProducer {
  RemoveListenFalseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeListenFalseFix',
    50,
    'Remove listen: false to enable rebuilds',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    // Find and remove only the 'listen: false' named argument
    for (final arg in target.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'listen') {
        await builder.addDartFileEdit(file, (builder) {
          // Find preceding comma if not first argument
          final idx = target.argumentList.arguments.indexOf(arg);
          if (idx > 0) {
            // Delete from preceding comma to end of argument
            final prevArg = target.argumentList.arguments[idx - 1];
            builder.addDeletion(
              SourceRange(prevArg.end, arg.end - prevArg.end),
            );
          } else if (target.argumentList.arguments.length > 1) {
            // Delete from start to next argument (including comma)
            final nextArg = target.argumentList.arguments[1];
            builder.addDeletion(
              SourceRange(arg.offset, nextArg.offset - arg.offset),
            );
          } else {
            // Only argument - just delete it
            builder.addDeletion(SourceRange(arg.offset, arg.length));
          }
        });
        return;
      }
    }
  }
}

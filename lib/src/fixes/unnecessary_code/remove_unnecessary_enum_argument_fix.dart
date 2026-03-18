// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary enum constructor argument (e.g. default value).
class RemoveUnnecessaryEnumArgumentFix extends SaropaFixProducer {
  RemoveUnnecessaryEnumArgumentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryEnumArgumentFix',
    50,
    'Remove unnecessary enum argument',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final arg = node is Expression
        ? node
        : node.thisOrAncestorOfType<Expression>();
    if (arg == null) return;

    final args = arg.parent;
    if (args is! ArgumentList) return;

    final content = unitResult.content;
    final arguments = args.arguments;
    final idx = arguments.indexOf(arg);
    if (idx < 0) return;

    int start = arg.offset;
    int end = arg.end;
    if (idx > 0) {
      start = arguments[idx - 1].end;
      while (start < content.length &&
          (content[start] == ',' || content[start] == ' ')) {
        start++;
      }
    } else if (idx < arguments.length - 1) {
      while (end < content.length &&
          (content[end] == ',' || content[end] == ' ')) {
        end++;
      }
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(start, end - start));
    });
  }
}

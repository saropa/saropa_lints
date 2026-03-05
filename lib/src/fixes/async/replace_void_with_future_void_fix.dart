// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace void return type with `Future<void>` for async functions.
///
/// Matches [AvoidVoidAsyncRule].
class ReplaceVoidWithFutureVoidFix extends SaropaFixProducer {
  ReplaceVoidWithFutureVoidFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceVoidWithFutureVoid',
    50,
    'Change return type to Future<void>',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final TypeAnnotation? returnType =
        node.thisOrAncestorOfType<MethodDeclaration>()?.returnType ??
        node.thisOrAncestorOfType<FunctionDeclaration>()?.returnType;
    if (returnType == null) return;

    final String src = returnType.toSource().trim();
    if (src != 'void') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(returnType.offset, returnType.length),
        'Future<void>',
      );
    });
  }
}

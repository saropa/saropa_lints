// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove the explicit type annotation from a closure parameter
/// so the type is inferred (e.g. `(int x) => …` becomes `(x) => …`).
///
/// Matches `AvoidTypesOnClosureParametersRule`. The rule reports at a
/// [SimpleFormalParameter] whose ancestor is a [FunctionExpression] (i.e.
/// a closure, not a top-level/method declaration where types still serve
/// as the declared API). We delete from the type's start through the
/// whitespace separating it from the parameter name.
class RemoveClosureParameterTypeFix extends SaropaFixProducer {
  RemoveClosureParameterTypeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeClosureParameterType',
    50,
    'Remove parameter type annotation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final SimpleFormalParameter? param = node is SimpleFormalParameter
        ? node
        : node.thisOrAncestorOfType<SimpleFormalParameter>();
    if (param == null) return;

    final TypeAnnotation? type = param.type;
    if (type == null) return;
    final Token? nameToken = param.name;
    if (nameToken == null) return;

    // Delete from the type start up to the parameter name start so any
    // whitespace between them is removed too — leaving `(x)` rather than
    // `( x)`.
    final int start = type.offset;
    final int end = nameToken.offset;
    if (end <= start) return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}

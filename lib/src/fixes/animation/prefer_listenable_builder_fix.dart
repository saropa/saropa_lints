// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces the constructor name `AnimatedBuilder` with `ListenableBuilder`.
///
/// Matches [PreferListenableBuilderRule] diagnostics. The replacement is a
/// pure rename: the two widgets share the same named parameters
/// (`animation`, `builder`, `child`) so no argument restructuring is needed.
class PreferListenableBuilderFix extends SaropaFixProducer {
  PreferListenableBuilderFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferListenableBuilder',
    80,
    'Replace AnimatedBuilder with ListenableBuilder',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Diagnostic is reported at the ConstructorName, so covering node is
    // typically that node or an identifier inside it.
    final AstNode? node = coveringNode;
    if (node == null) return;

    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final NamedType namedType = ctorName.type;
    // Guard: only rewrite when we are still targeting AnimatedBuilder.
    if (namedType.name.lexeme != 'AnimatedBuilder') return;

    await builder.addDartFileEdit(file, (b) {
      // Replace just the type identifier token; argument list is preserved.
      b.addSimpleReplacement(
        SourceRange(namedType.name.offset, namedType.name.length),
        'ListenableBuilder',
      );
    });
  }
}

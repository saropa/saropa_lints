// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../analyzer_compat.dart';
import '../../native/saropa_fix.dart';

/// Renames `class Foo` to `class SliverFoo` when it does not already start with
/// `Sliver`.
class PrependSliverToClassNameFix extends SaropaFixProducer {
  PrependSliverToClassNameFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.prependSliverToClassNameFix',
    50,
    'Prefix class name with Sliver',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final classDecl = node is ClassDeclaration
        ? node
        : node?.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final nameToken = classDecl.nameToken;
    final name = nameToken.lexeme;
    if (name.startsWith('Sliver')) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(nameToken.offset, nameToken.length),
        'Sliver$name',
      );
    });
  }
}

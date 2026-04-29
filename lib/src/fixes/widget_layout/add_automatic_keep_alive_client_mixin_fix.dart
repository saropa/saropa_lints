// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Adds `with AutomaticKeepAliveClientMixin` to a [State] subclass declaration.
class AddAutomaticKeepAliveClientMixinFix extends SaropaFixProducer {
  AddAutomaticKeepAliveClientMixinFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addAutomaticKeepAliveClientMixinFix',
    50,
    'Add AutomaticKeepAliveClientMixin',
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

    final extendsClause = classDecl.extendsClause;
    if (extendsClause == null) return;
    if (extendsClause.superclass.name.lexeme != 'State') return;

    final withClause = classDecl.withClause;
    if (withClause != null) {
      for (final m in withClause.mixinTypes) {
        if (m.name.lexeme == 'AutomaticKeepAliveClientMixin') return;
      }
    }

    late final int insertOffset;
    late final String insertion;
    if (withClause == null) {
      insertOffset = extendsClause.end;
      insertion = ' with AutomaticKeepAliveClientMixin';
    } else {
      insertOffset = withClause.mixinTypes.last.end;
      insertion = ', AutomaticKeepAliveClientMixin';
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}

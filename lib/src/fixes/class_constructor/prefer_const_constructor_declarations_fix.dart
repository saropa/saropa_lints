// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add `const` keyword to a generative constructor declaration.
///
/// Matches [PreferConstConstructorDeclarationsRule] (and
/// [PreferConstConstructorsInImmutablesRule] when wired there).
///
/// The diagnostic is reported at the [ConstructorDeclaration] node or an
/// ancestor [ClassDeclaration]; we locate the first non-factory,
/// non-const generative constructor in the class and insert `const ` at
/// its offset.
class PreferConstConstructorDeclarationsFix extends SaropaFixProducer {
  PreferConstConstructorDeclarationsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferConstConstructorDeclarations',
    50,
    'Add const to constructor declaration',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // Prefer a ConstructorDeclaration if the diagnostic is reported directly
    // on one; otherwise walk the enclosing class body and pick the first
    // eligible generative constructor.
    ConstructorDeclaration? target = node is ConstructorDeclaration
        ? node
        : node.thisOrAncestorOfType<ConstructorDeclaration>();

    if (target == null) {
      final ClassDeclaration? cls = node is ClassDeclaration
          ? node
          : node.thisOrAncestorOfType<ClassDeclaration>();
      if (cls == null) return;
      final body = cls.body;
      if (body is! BlockClassBody) return;
      for (final ClassMember m in body.members) {
        if (m is ConstructorDeclaration &&
            m.factoryKeyword == null &&
            m.constKeyword == null) {
          target = m;
          break;
        }
      }
    }

    if (target == null) return;
    if (target.constKeyword != null) return;
    if (target.factoryKeyword != null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target!.offset, 'const ');
    });
  }
}

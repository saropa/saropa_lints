// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add `final` to a non-final instance field declaration.
///
/// Matches [PreferFinalFieldsRule] and [PreferFinalFieldsAlwaysRule]. The
/// diagnostic is reported at the [FieldDeclaration] node; the fix either
/// replaces a leading `var` keyword with `final` or inserts `final ` before
/// the type annotation.
class PreferFinalFieldsFix extends SaropaFixProducer {
  PreferFinalFieldsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferFinalFields',
    50,
    'Add final to field declaration',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final FieldDeclaration? field = node is FieldDeclaration
        ? node
        : node.thisOrAncestorOfType<FieldDeclaration>();
    if (field == null) return;

    final VariableDeclarationList list = field.fields;
    if (list.isFinal || list.isConst || list.isLate) return;

    final Token? keyword = list.keyword;
    await builder.addDartFileEdit(file, (builder) {
      if (keyword != null && keyword.lexeme == 'var') {
        builder.addSimpleReplacement(
          SourceRange(keyword.offset, keyword.length),
          'final',
        );
      } else {
        builder.addSimpleInsertion(list.offset, 'final ');
      }
    });
  }
}

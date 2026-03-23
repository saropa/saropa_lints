// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: `CurvedAnimation? opacityAnimation` → `late CurvedAnimation opacityAnimation`
/// on [State] subclasses for [DropdownMenuItemButton].
///
/// Matches field diagnostics from rule `prefer_dropdown_menu_item_button_opacity_animation`.
class PreferDropdownMenuItemButtonOpacityAnimationFieldFix
    extends SaropaFixProducer {
  PreferDropdownMenuItemButtonOpacityAnimationFieldFix({
    required super.context,
  });

  static const _fixKind = FixKind(
    'saropa.fix.preferDropdownMenuItemButtonOpacityAnimationField',
    80,
    "Use late non-nullable CurvedAnimation for opacityAnimation",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final VariableDeclaration? decl = node is VariableDeclaration
        ? node
        : node.thisOrAncestorOfType<VariableDeclaration>();
    if (decl == null) return;
    if (decl.name.lexeme != 'opacityAnimation') return;

    final AstNode? listParent = decl.parent;
    if (listParent is! VariableDeclarationList) return;
    final VariableDeclarationList list = listParent;
    if (list.parent is! FieldDeclaration) return;

    final TypeAnnotation? typeAnn = list.type;
    if (typeAnn is! NamedType) return;
    if (typeAnn.name.lexeme != 'CurvedAnimation') return;
    final question = typeAnn.question;
    if (question == null) return;

    final int insertAt =
        list.lateKeyword?.offset ?? list.keyword?.offset ?? typeAnn.offset;

    await builder.addDartFileEdit(file, (b) {
      if (list.lateKeyword == null) {
        b.addInsertion(insertAt, (eb) => eb.write('late '));
      }
      b.addSimpleReplacement(SourceRange(question.offset, question.length), '');
    });
  }
}

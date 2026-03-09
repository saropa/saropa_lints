// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `var` with the inferred explicit type.
///
/// Matches [PreferTypeOverVarRule]. Looks up the static type of the
/// first variable's initializer and replaces the `var` keyword with
/// the type's display string. Bails out when the type is `dynamic`,
/// `null`, or otherwise unresolvable.
class ReplaceVarWithTypeFix extends SaropaFixProducer {
  ReplaceVarWithTypeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceVarWithType',
    50,
    'Replace var with explicit type',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final list = node is VariableDeclarationList
        ? node
        : node.thisOrAncestorOfType<VariableDeclarationList>();
    if (list == null) return;

    final keyword = list.keyword;
    if (keyword == null || keyword.lexeme != 'var') return;

    // Use the static type from the first variable's initializer.
    if (list.variables.isEmpty) return;
    final staticType = list.variables.first.initializer?.staticType;
    if (staticType == null || staticType is DynamicType) return;

    final typeName = staticType.getDisplayString();

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(keyword.offset, keyword.length),
        typeName,
      );
    });
  }
}

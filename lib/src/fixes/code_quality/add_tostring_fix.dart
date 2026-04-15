// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Generate a `toString()` override listing all instance fields.
///
/// Matches [AvoidDefaultToStringRule].
class AddToStringFix extends SaropaFixProducer {
  AddToStringFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addToString',
    50,
    'Add toString() override',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final body = classDecl.body;
    if (body is! BlockClassBody) return;

    // Collect non-static field names for the toString body.
    final fields = <String>[];
    for (final member in body.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        for (final variable in member.fields.variables) {
          fields.add(variable.name.lexeme);
        }
      }
    }
    if (fields.isEmpty) return;

    final className = classDecl.namePart.typeName.lexeme;
    // Use the class declaration node to derive indentation level.
    final indent = getLineIndent(classDecl);
    final memberIndent = '$indent  ';

    // Format: ClassName(field1: $field1, field2: $field2)
    final fieldParts = fields.map((f) => '$f: \$$f').join(', ');
    final method =
        '\n$memberIndent\n'
        '$memberIndent@override\n'
        "${memberIndent}String toString() => '$className($fieldParts)';\n";

    // Insert before the closing brace of the class body.
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(body.rightBracket.offset, method);
    });
  }
}

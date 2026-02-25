import 'package:analyzer/dart/ast/ast.dart';

/// Checks if the outer type itself is nullable (has a trailing `?`).
///
/// Uses the AST `question` token rather than string matching to avoid
/// false positives when `?` appears only on inner generic parameters
/// (e.g. `Future<String?>` is non-nullable, `Future<String>?` is nullable).
bool isOuterTypeNullable(TypeAnnotation typeAnnotation) {
  if (typeAnnotation is NamedType) {
    return typeAnnotation.question != null;
  }

  if (typeAnnotation is GenericFunctionType) {
    return typeAnnotation.question != null;
  }

  if (typeAnnotation is RecordTypeAnnotation) {
    return typeAnnotation.question != null;
  }

  return false;
}

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';

/// Parses [classSource] and returns the [FunctionBody] of the method named
/// [methodName] inside the first [ClassDeclaration].
///
/// Uses [bodyMembers] from analyzer_compat.dart for cross-version safety.
/// Throws [StateError] if no matching method is found.
FunctionBody parseMethodBody(String methodName, String classSource) {
  final unit = parseString(
    content: classSource,
    throwIfDiagnostics: false,
  ).unit;
  for (final decl in unit.declarations) {
    if (decl is ClassDeclaration) {
      for (final member in decl.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == methodName) {
          return member.body;
        }
      }
    }
  }
  throw StateError('No $methodName() found');
}

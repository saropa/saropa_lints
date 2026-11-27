/// Traces a `FutureBuilder.future` argument back to the same-file method(s)
/// that produce it, for `require_error_widget`.
///
/// Name-based (works without type resolution). Anything that cannot be traced
/// with certainty, including locals, parameters, getters, inherited members,
/// overridable members and declarations in other files, yields false so the
/// rule keeps reporting.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'analyzer_compat.dart';
import 'future_catch_all_utils.dart';
import 'future_override_utils.dart';
import 'future_source_scope.dart';

/// Whether [future] is certain never to complete with an error: either a direct
/// call to a self-handling method, or a field / top-level variable whose every
/// assigned value is such a call.
bool futureCannotError(Expression future) {
  final Expression expr = future.unParenthesized;
  // Enum / extension members are not modeled; a same-named top-level function
  // must not be mistaken for the member that is really called.
  if (isUntracedContainer(containerOf(expr))) return false;
  if (expr is MethodInvocation) return _isSafeCall(expr);

  final String? name = tracedVariableName(expr);
  if (name == null) return false;
  // `this.x` names the field even when a local shadows the bare name.
  if (expr is SimpleIdentifier && isShadowedLocally(expr, name)) return false;
  return _isSafeVariable(expr, name);
}

/// Whether [call] targets a same-file method or function whose body handles
/// every failure itself.
bool _isSafeCall(MethodInvocation call) {
  final String name = call.methodName.name;
  final Expression? target = call.realTarget;
  final CompilationUnitMember? container = containerOf(call);
  if (isUntracedContainer(container)) return false;
  // `Name._load()` is traceable only when Name is the enclosing class.
  final bool isOwnStatic =
      target is SimpleIdentifier &&
      container is ClassDeclaration &&
      target.name == container.nameToken.lexeme;
  if (target != null && target is! ThisExpression && !isOwnStatic) return false;
  // A local function or parameter of the same name wins over the member.
  if (target == null && isShadowedLocally(call, name)) return false;
  final CompilationUnit? unit = call.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null) return false;

  for (final ClassMember member in membersOf(container)) {
    if (member is MethodDeclaration && member.name.lexeme == name) {
      if (member.isGetter || member.isSetter) return false;
      // An override (subclass here, or anywhere for a public member of an
      // open type) would run instead of the traced body.
      if (!member.isStatic && memberCanBeOverridden(name, container!, unit)) {
        return false;
      }
      return bodyCannotCompleteWithError(member.body);
    }
    // A function-typed field: the invoked closure is unknown.
    if (member is FieldDeclaration && declaresVariable(member.fields, name)) {
      return false;
    }
  }
  // `this.x()` / `Name.x()` that is not declared here is inherited or missing.
  if (target != null) return false;

  for (final CompilationUnitMember declaration in unit.declarations) {
    if (declaration is FunctionDeclaration &&
        declaration.name.lexeme == name &&
        !declaration.isGetter &&
        !declaration.isSetter) {
      return bodyCannotCompleteWithError(declaration.functionExpression.body);
    }
  }
  return false;
}

/// The field (in [container]) or top-level variable list declaring [name].
VariableDeclarationList? _findDeclaration(
  CompilationUnit unit,
  CompilationUnitMember? container,
  String name,
) {
  for (final ClassMember member in membersOf(container)) {
    if (member is FieldDeclaration && declaresVariable(member.fields, name)) {
      return member.fields;
    }
  }
  for (final CompilationUnitMember declaration in unit.declarations) {
    if (declaration is TopLevelVariableDeclaration &&
        declaresVariable(declaration.variables, name)) {
      return declaration.variables;
    }
  }
  return null;
}

/// Whether every value the variable [name] (read at [use]) can hold comes from
/// a self-handling call.
bool _isSafeVariable(Expression use, String name) {
  final CompilationUnit? unit = use.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null) return false;
  final CompilationUnitMember? container = containerOf(use);
  final VariableDeclarationList? list = _findDeclaration(unit, container, name);
  if (list == null) return false;
  // A top-level variable has no owning class, even when read inside one.
  final AstNode? declaration = list.parent;
  final bool isField = declaration is FieldDeclaration;
  // A subclass getter named like the field would be read instead of it.
  if (isField &&
      !declaration.isStatic &&
      memberCanBeOverridden(name, container!, unit)) {
    return false;
  }

  final Expression? initializer = list.variables
      .firstWhere((VariableDeclaration v) => v.name.lexeme == name)
      .initializer;
  // `final x = ...` can never be reassigned, so the checks below are moot.
  final bool isFixed = list.isFinal && initializer != null;
  // A public variable that can still be written may be set by another file.
  if (!isFixed && !name.startsWith('_')) return false;
  // A `part` file shares private names and is not visible from this unit.
  if (!isFixed &&
      unit.directives.any(
        (Directive d) => d is PartDirective || d is PartOfDirective,
      )) {
    return false;
  }

  final FutureSourceCollector collector = FutureSourceCollector(
    name,
    isField ? container : null,
  );
  unit.accept(collector);
  if (collector.hasUnknownSource) return false;

  // `null` never errors, but on its own proves nothing about the future.
  final List<Expression> sources =
      <Expression>[
          ?initializer,
          ...collector.sources,
        ].map((Expression e) => e.unParenthesized).toList()
        ..removeWhere((Expression e) => e is NullLiteral);
  return sources.isNotEmpty &&
      sources.every((Expression e) => e is MethodInvocation && _isSafeCall(e));
}

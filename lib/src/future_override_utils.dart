/// Decides whether a class or mixin member that `require_error_widget` traced
/// a future to could be replaced by an override, so the traced body might not
/// be the code that actually runs.
///
/// Name-based and one-sided like the rest of the future tracing: any shape
/// that cannot be ruled out counts as overridable, which keeps the diagnostic.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'analyzer_compat.dart';

/// Whether the instance member [name] declared in [container] could be
/// overridden, here or in another library.
///
/// The call `_load()` inside the State dispatches dynamically, so a subclass
/// that overrides `_load` (or a getter that replaces a `_future` field) runs
/// its own code and the catch-all in the traced body proves nothing.
bool memberCanBeOverridden(
  String name,
  CompilationUnitMember container,
  CompilationUnit unit,
) {
  // A `part` file shares the library, so a subclass in it is invisible here.
  if (unit.directives.any(
    (Directive d) => d is PartDirective || d is PartOfDirective,
  )) {
    return true;
  }
  // A public member of a type other libraries can extend or mix in may be
  // overridden anywhere, so only private members or closed types qualify.
  if (!name.startsWith('_') && _isOpenToOtherLibraries(container)) return true;
  return _hasSameFileOverride(name, _typeName(container), unit);
}

/// Name of the class or mixin; empty for anything else (never matched).
String _typeName(CompilationUnitMember container) {
  if (container is ClassDeclaration) return container.nameToken.lexeme;
  if (container is MixinDeclaration) return container.name.lexeme;
  return '';
}

/// Whether code in another library can subclass or mix in [container].
bool _isOpenToOtherLibraries(CompilationUnitMember container) {
  // Any class can apply a mixin and declare the same member.
  if (container is MixinDeclaration) return true;
  if (container is! ClassDeclaration) return true;
  // A private type cannot be named outside its library.
  if (container.nameToken.lexeme.startsWith('_')) return false;
  // `mixin class` can be mixed in even when it is otherwise closed.
  if (container.mixinKeyword != null) return true;
  // `final`, `sealed` and `interface` forbid `extends` outside the library;
  // an `implements` elsewhere does not inherit the calling code at all.
  return container.finalKeyword == null &&
      container.sealedKeyword == null &&
      container.interfaceKeyword == null;
}

/// Whether a same-file subtype of [typeName] declares a member called [name].
/// Subtypes are found transitively through `extends`, `with` and class
/// aliases, by name only (no resolution).
bool _hasSameFileOverride(String name, String typeName, CompilationUnit unit) {
  final Set<String> family = <String>{typeName};
  final List<CompilationUnitMember> subtypes = <CompilationUnitMember>[];
  bool grew = true;
  // Repeat until no new subtype appears, so grandchildren are included.
  while (grew) {
    grew = false;
    for (final CompilationUnitMember d in unit.declarations) {
      final String? own = _declaredName(d);
      if (own == null || family.contains(own)) continue;
      if (_superNames(d).any(family.contains)) {
        family.add(own);
        subtypes.add(d);
        grew = true;
      }
    }
  }
  return subtypes.any((CompilationUnitMember d) => _declaresMember(d, name));
}

/// Name of a declaration that can inherit members; null for all others.
String? _declaredName(CompilationUnitMember d) {
  if (d is ClassDeclaration) return d.nameToken.lexeme;
  if (d is ClassTypeAlias) return d.name.lexeme;
  if (d is EnumDeclaration) return d.nameToken.lexeme;
  return null;
}

/// Names in the `extends` and `with` clauses of [d].
Iterable<String> _superNames(CompilationUnitMember d) {
  final List<NamedType> types = <NamedType>[];
  if (d is ClassDeclaration) {
    final NamedType? superclass = d.extendsClause?.superclass;
    if (superclass != null) types.add(superclass);
    types.addAll(d.withClause?.mixinTypes ?? const <NamedType>[]);
  } else if (d is ClassTypeAlias) {
    types
      ..add(d.superclass)
      ..addAll(d.withClause.mixinTypes);
  } else if (d is EnumDeclaration) {
    types.addAll(d.withClause?.mixinTypes ?? const <NamedType>[]);
  }
  return types.map((NamedType t) => t.name.lexeme);
}

/// Whether [d] declares a non-static method, getter, setter or field [name].
bool _declaresMember(CompilationUnitMember d, String name) {
  final List<ClassMember> members = d is ClassDeclaration
      ? d.bodyMembers
      : d is EnumDeclaration
      ? d.bodyMembers
      : const <ClassMember>[];
  for (final ClassMember m in members) {
    if (m is MethodDeclaration && !m.isStatic && m.name.lexeme == name) {
      return true;
    }
    if (m is FieldDeclaration &&
        !m.isStatic &&
        m.fields.variables.any(
          (VariableDeclaration v) => v.name.lexeme == name,
        )) {
      return true;
    }
  }
  return false;
}

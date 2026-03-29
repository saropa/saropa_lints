// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Compile-time Dart **shape** rules: constructor and enum restrictions that
/// mirror (or supplement) the analyzer’s own compile-time errors, plus
/// [package:meta](https://pub.dev/packages/meta) annotation misuse.
///
/// ## Why this file exists
///
/// These diagnostics are grouped here (instead of `structure_rules.dart`) so
/// `structure_rules.dart` stays maintainable. Rules are **syntactic / structural**
/// with minimal heuristic string matching: they use AST node types, the element
/// model for `Enum` (`implements Enum`, `mixin … on Enum`), and resolved
/// annotation elements for `literal` / `nonVirtual`.
///
/// ## Performance
///
/// Each rule registers narrow callbacks (`addClassDeclaration`, `addAnnotation`,
/// etc.). No full-unit traversal, no recursion, and no async—safe under the
/// analyzer’s single-threaded visit model.
///
/// ## Overlap with the SDK analyzer
///
/// Several codes duplicate native analyzer diagnostics (e.g. extension override
/// arity). Projects may see both; this matches the pattern used elsewhere in
/// saropa_lints (e.g. URI existence) for consistent severity and messaging inside
/// the plugin tier system.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

// ---------------------------------------------------------------------------
// Helpers (library-private)
// ---------------------------------------------------------------------------

bool _isPackageMetaTopLevelVariable(Annotation ann, String expectedName) {
  final Element? el = ann.element;
  TopLevelVariableElement? variable;
  if (el is TopLevelVariableElement) {
    variable = el;
  } else if (el is PropertyAccessorElement) {
    final PropertyInducingElement v = el.variable;
    if (v is TopLevelVariableElement) {
      variable = v;
    }
  }
  if (variable == null) return false;
  if (variable.name != expectedName) return false;
  final LibraryElement? lib = variable.library;
  if (lib == null) return false;
  final Uri uri = lib.uri;
  return uri.isScheme('package') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'meta';
}

bool _isDartCoreEnumElement(Element? e) =>
    e != null && e.name == 'Enum' && e.library?.uri.toString() == 'dart:core';

bool _interfaceTypeIsCoreEnum(InterfaceType? type) {
  if (type == null) return false;
  return _isDartCoreEnumElement(type.element);
}

bool _typeImplementsEnum(InterfaceType type) {
  if (_interfaceTypeIsCoreEnum(type)) return true;
  final InterfaceElement elem = type.element;
  if (elem is ClassElement) {
    final InterfaceType? sup = elem.supertype;
    if (sup != null && _typeImplementsEnum(sup)) return true;
    for (final InterfaceType i in elem.interfaces) {
      if (_typeImplementsEnum(i)) return true;
    }
    for (final InterfaceType m in elem.mixins) {
      if (_typeImplementsEnum(m)) return true;
    }
  } else if (elem is MixinElement) {
    for (final InterfaceType c in elem.superclassConstraints) {
      if (_typeImplementsEnum(c)) return true;
    }
  }
  return false;
}

bool _namedTypeImplementsEnum(NamedType t) {
  final Element? element = t.element;
  if (element is InterfaceElement) {
    return _typeImplementsEnum(element.thisType);
  }
  return false;
}

bool _classDeclarationImplementsEnum(ClassDeclaration node) {
  final ImplementsClause? impl = node.implementsClause;
  if (impl == null) return false;
  for (final NamedType t in impl.interfaces) {
    if (_namedTypeImplementsEnum(t)) return true;
  }
  return false;
}

bool _mixinOnEnum(MixinDeclaration node) {
  final MixinOnClause? on = node.onClause;
  if (on == null) return false;
  for (final NamedType t in on.superclassConstraints) {
    if (_namedTypeImplementsEnum(t)) return true;
  }
  return false;
}

bool _methodHasConcreteBody(MethodDeclaration m) {
  if (m.externalKeyword != null) return false;
  return m.body is BlockFunctionBody || m.body is ExpressionFunctionBody;
}

bool _hasSuperFormalParameter(ConstructorDeclaration c) {
  for (final FormalParameter p in c.parameters.parameters) {
    if (p is SuperFormalParameter) return true;
    if (p is DefaultFormalParameter && p.parameter is SuperFormalParameter) {
      return true;
    }
  }
  return false;
}

bool _superFormalParameterLocationInvalid(ConstructorDeclaration c) {
  if (c.factoryKeyword != null) return true;
  if (c.redirectedConstructor != null) return true;
  for (final ConstructorInitializer i in c.initializers) {
    if (i is RedirectingConstructorInvocation) return true;
  }
  return false;
}

void _reportIllegalConcreteEnumMember(
  ClassMember m,
  SaropaDiagnosticReporter reporter,
  LintCode code,
) {
  if (m is FieldDeclaration && !m.isStatic) {
    for (final VariableDeclaration v in m.fields.variables) {
      final String lex = v.name.lexeme;
      if (lex == 'index' || lex == 'hashCode') {
        reporter.atToken(v.name, code);
      }
    }
  } else if (m is MethodDeclaration && !m.isStatic) {
    final Token nameTok = m.name;
    final String name = nameTok.lexeme;
    if (m.isGetter && (name == 'index' || name == 'hashCode')) {
      if (_methodHasConcreteBody(m)) {
        reporter.atToken(nameTok, code);
      }
    }
    if (m.operatorKeyword != null &&
        name == '==' &&
        _methodHasConcreteBody(m)) {
      reporter.atToken(nameTok, code);
    }
  }
}

// =============================================================================
// duplicate_constructor
// =============================================================================

/// More than one unnamed constructor or duplicate same-named constructor.
///
/// **Bad:**
/// ```dart
/// class C {
///   C();
///   C();
///   C.named();
///   C.named();
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class C {
///   C();
///   C.named();
/// }
/// ```
class DuplicateConstructorRule extends SaropaLintRule {
  DuplicateConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'duplicate_constructor',
    '[duplicate_constructor] Class or enum declares more than one constructor with the same name (including more than one unnamed constructor). Duplicate constructors are invalid Dart and prevent compilation. {v1}',
    correctionMessage:
        'Remove or rename duplicate constructors so each constructor name is unique.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void checkMembers(List<ClassMember> members) {
      final List<ConstructorDeclaration> ctors = members
          .whereType<ConstructorDeclaration>()
          .toList();
      if (ctors.length < 2) return;

      int unnamed = 0;
      final Map<String, int> perName = <String, int>{};
      for (final ConstructorDeclaration c in ctors) {
        final Token? nameTok = c.name;
        if (nameTok == null) {
          unnamed++;
        } else {
          final String n = nameTok.lexeme;
          perName[n] = (perName[n] ?? 0) + 1;
        }
      }
      if (unnamed > 1) {
        for (final ConstructorDeclaration c in ctors) {
          if (c.name == null) reporter.atNode(c, code);
        }
      }
      for (final MapEntry<String, int> e in perName.entries) {
        if (e.value <= 1) continue;
        for (final ConstructorDeclaration c in ctors) {
          if (c.name?.lexeme == e.key) reporter.atNode(c, code);
        }
      }
    }

    context.addClassDeclaration(
      (ClassDeclaration node) => checkMembers(node.body.members),
    );
    context.addEnumDeclaration(
      (EnumDeclaration node) => checkMembers(node.body.members),
    );
  }
}

// =============================================================================
// conflicting_constructor_and_static_member
// =============================================================================

/// Named constructor shares a name with a static member (invalid Dart).
///
/// **Bad:**
/// ```dart
/// class C {
///   C.foo();
///   static void foo() {}
/// }
/// ```
class ConflictingConstructorAndStaticMemberRule extends SaropaLintRule {
  ConflictingConstructorAndStaticMemberRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'conflicting_constructor_and_static_member',
    '[conflicting_constructor_and_static_member] A named constructor uses the same name as a static field, getter, setter, or method. Dart does not allow a named constructor and a static member to share an identifier. {v1}',
    correctionMessage:
        'Rename the constructor or the static member so the names differ.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void check(List<ClassMember> members) {
      final Set<String> ctorNames = <String>{};
      for (final ClassMember m in members) {
        if (m is ConstructorDeclaration) {
          final Token? n = m.name;
          if (n != null) ctorNames.add(n.lexeme);
        }
      }
      if (ctorNames.isEmpty) return;

      final Set<String> staticNames = <String>{};
      for (final ClassMember m in members) {
        if (m is MethodDeclaration && m.isStatic) {
          final Token? n = m.name;
          if (n != null) staticNames.add(n.lexeme);
        } else if (m is FieldDeclaration && m.isStatic) {
          for (final VariableDeclaration v in m.fields.variables) {
            staticNames.add(v.name.lexeme);
          }
        }
      }

      for (final String name in ctorNames.intersection(staticNames)) {
        for (final ClassMember m in members) {
          if (m is ConstructorDeclaration && m.name?.lexeme == name) {
            reporter.atToken(m.name!, code);
          }
          if (m is MethodDeclaration && m.isStatic && m.name.lexeme == name) {
            reporter.atToken(m.name, code);
          }
          if (m is FieldDeclaration && m.isStatic) {
            for (final VariableDeclaration v in m.fields.variables) {
              if (v.name.lexeme == name) reporter.atToken(v.name, code);
            }
          }
        }
      }
    }

    context.addClassDeclaration((ClassDeclaration node) => check(node.body.members));
    context.addEnumDeclaration((EnumDeclaration node) => check(node.body.members));
  }
}

// =============================================================================
// field_initializer_redirecting_constructor
// =============================================================================

/// Redirecting constructor must not mix field/super initializers with redirect.
///
/// **Bad:**
/// ```dart
/// class C {
///   final int x;
///   C() : x = 1, this.named();
///   C.named();
/// }
/// ```
class FieldInitializerRedirectingConstructorRule extends SaropaLintRule {
  FieldInitializerRedirectingConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'field_initializer_redirecting_constructor',
    '[field_initializer_redirecting_constructor] A redirecting constructor cannot initialize instance fields or invoke a super constructor; it may only forward to another constructor of the same class. {v1}',
    correctionMessage:
        'Remove field or super initializers from the redirecting constructor, or use a non-redirecting constructor.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      if (node.redirectedConstructor != null) {
        if (node.initializers.isNotEmpty) {
          reporter.atNode(node.initializers.first, code);
        }
        return;
      }
      bool hasRedirect = false;
      for (final ConstructorInitializer i in node.initializers) {
        if (i is RedirectingConstructorInvocation) hasRedirect = true;
      }
      if (!hasRedirect) return;
      for (final ConstructorInitializer i in node.initializers) {
        if (i is ConstructorFieldInitializer ||
            i is SuperConstructorInvocation) {
          reporter.atNode(i, code);
        }
      }
    });
  }
}

// =============================================================================
// invalid_super_formal_parameter_location
// =============================================================================

/// Super parameter only allowed on non-redirecting generative constructors.
class InvalidSuperFormalParameterLocationRule extends SaropaLintRule {
  InvalidSuperFormalParameterLocationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'invalid_super_formal_parameter_location',
    '[invalid_super_formal_parameter_location] Super parameters (super.x) are only allowed on non-redirecting generative constructors. They cannot be used on factory constructors or constructors that redirect. {v1}',
    correctionMessage:
        'Use a normal parameter and pass it explicitly to the super constructor, or use a generative constructor that does not redirect.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      if (!_hasSuperFormalParameter(node)) return;
      if (_superFormalParameterLocationInvalid(node)) {
        reporter.atNode(node.parameters, code);
      }
    });
  }
}

// =============================================================================
// illegal_concrete_enum_member
// =============================================================================

/// Concrete `index`, `hashCode`, or `==` on enum / Enum implementer / mixin on Enum.
class IllegalConcreteEnumMemberRule extends SaropaLintRule {
  IllegalConcreteEnumMemberRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'illegal_concrete_enum_member',
    '[illegal_concrete_enum_member] A concrete instance member named index, hashCode, or operator == cannot be declared where Enum semantics apply (enum declaration, class implementing Enum, or mixin on Enum). {v1}',
    correctionMessage:
        'Remove the member, make it abstract, or rename it so it does not conflict with Enum.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addEnumDeclaration((EnumDeclaration node) {
      for (final ClassMember m in node.body.members) {
        _reportIllegalConcreteEnumMember(m, reporter, code);
      }
    });

    context.addClassDeclaration((ClassDeclaration node) {
      if (!_classDeclarationImplementsEnum(node)) return;
      for (final ClassMember m in node.body.members) {
        _reportIllegalConcreteEnumMember(m, reporter, code);
      }
    });

    context.addMixinDeclaration((MixinDeclaration node) {
      if (!_mixinOnEnum(node)) return;
      for (final ClassMember m in node.body.members) {
        _reportIllegalConcreteEnumMember(m, reporter, code);
      }
    });
  }
}

// =============================================================================
// invalid_literal_annotation
// =============================================================================

/// `@literal` must annotate a const constructor (package:meta).
class InvalidLiteralAnnotationRule extends SaropaLintRule {
  InvalidLiteralAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'annotations'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'invalid_literal_annotation',
    '[invalid_literal_annotation] The package:meta `literal` annotation is only meaningful on const constructors. Applying it elsewhere is invalid. {v1}',
    correctionMessage: 'Remove the annotation or make the constructor const.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAnnotation((Annotation node) {
      if (!_isPackageMetaTopLevelVariable(node, 'literal')) return;
      final AstNode? parent = node.parent;
      if (parent is! ConstructorDeclaration) {
        reporter.atNode(node, code);
        return;
      }
      if (parent.constKeyword == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// invalid_non_virtual_annotation
// =============================================================================

/// `@nonVirtual` only on concrete instance members of class or mixin (package:meta).
class InvalidNonVirtualAnnotationRule extends SaropaLintRule {
  InvalidNonVirtualAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'annotations'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'invalid_non_virtual_annotation',
    '[invalid_non_virtual_annotation] package:meta `nonVirtual` applies only to concrete instance members in a class or mixin. It is invalid on static, abstract, or non-instance declarations (including extensions and extension types). {v1}',
    correctionMessage:
        'Remove the annotation or move it to a concrete instance method, getter, setter, operator, or field in a class or mixin.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAnnotation((Annotation node) {
      if (!_isPackageMetaTopLevelVariable(node, 'nonVirtual')) return;
      final AstNode? parent = node.parent;

      if (parent is MethodDeclaration) {
        if (parent.isStatic ||
            parent.isAbstract ||
            parent.externalKeyword != null) {
          reporter.atNode(node, code);
          return;
        }
        if (!_methodHasConcreteBody(parent)) {
          reporter.atNode(node, code);
          return;
        }
        if (parent.thisOrAncestorOfType<ExtensionDeclaration>() != null ||
            parent.thisOrAncestorOfType<ExtensionTypeDeclaration>() != null) {
          reporter.atNode(node, code);
        }
        return;
      }

      if (parent is FieldDeclaration) {
        if (parent.isStatic || parent.abstractKeyword != null) {
          reporter.atNode(node, code);
          return;
        }
        if (parent.thisOrAncestorOfType<ExtensionDeclaration>() != null ||
            parent.thisOrAncestorOfType<ExtensionTypeDeclaration>() != null) {
          reporter.atNode(node, code);
        }
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// abstract_field_initializer
// =============================================================================

/// Abstract instance field must not have an initializer (invalid Dart shape).
///
/// Since: v10.0.3 | Rule version: v1
///
/// Mirrors the analyzer `abstract_field_initializer` diagnostic for tiered
/// reporting alongside other Saropa compile-time shape rules.
///
/// **BAD:**
/// ```dart
/// abstract class C {
///   abstract int x = 0;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// abstract class C {
///   abstract final int x;
/// }
/// ```
class AbstractFieldInitializerRule extends SaropaLintRule {
  AbstractFieldInitializerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'abstract_field_initializer',
    '[abstract_field_initializer] Abstract fields cannot have initializers. Remove the initializer or drop the abstract modifier so the declaration matches valid Dart semantics. {v1}',
    correctionMessage:
        'Use an abstract field without an initializer, or a concrete field with an initializer.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.abstractKeyword == null) return;
      for (final VariableDeclaration v in node.fields.variables) {
        if (v.initializer != null) {
          reporter.atToken(v.name, code);
        }
      }
    });
  }
}

// =============================================================================
// undefined_enum_constructor
// =============================================================================

/// Enum constructor invocation does not resolve (typo or missing constructor).
///
/// Since: v10.0.3 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// enum E { a(1); const E(int x); }
/// void f() { E.missing(1); }
/// ```
///
/// **GOOD:**
/// ```dart
/// enum E { a(1); const E(int x); }
/// void f() { E.a; }
/// ```
class UndefinedEnumConstructorRule extends SaropaLintRule {
  UndefinedEnumConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'architecture', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'undefined_enum_constructor',
    '[undefined_enum_constructor] This enum constructor call does not resolve to a declared enum constructor. Fix the name or add the constructor to the enum. {v1}',
    correctionMessage:
        'Use an existing enum value or constructor, or declare the missing constructor on the enum.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      final Element? typeEl = typeNode.element;
      if (typeEl is! EnumElement) return;

      final ConstructorName ctorName = node.constructorName;
      if (ctorName.name == null) return;

      final Element? ctorEl = ctorName.element;
      if (ctorEl != null) return;

      final SimpleIdentifier? nameNode = ctorName.name;
      if (nameNode != null) {
        reporter.atNode(nameNode, code);
      } else {
        reporter.atNode(ctorName, code);
      }
    });
  }
}

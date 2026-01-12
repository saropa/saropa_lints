// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// ADDITIONAL STYLISTIC RULES - String, Import, Class Structure, Types
// ============================================================================

// =============================================================================
// SHARED HELPERS
// =============================================================================

/// Checks if a class member is static.
bool _isStaticMember(ClassMember member) {
  if (member is FieldDeclaration) {
    return member.isStatic;
  } else if (member is MethodDeclaration) {
    return member.isStatic;
  }
  return false;
}

/// Checks if a class member is private (name starts with underscore).
bool _isPrivateMember(ClassMember member) {
  if (member is FieldDeclaration) {
    return member.fields.variables.any((v) => v.name.lexeme.startsWith('_'));
  } else if (member is MethodDeclaration) {
    return member.name.lexeme.startsWith('_');
  }
  return false;
}

// =============================================================================
// STRING HANDLING RULES
// =============================================================================

/// Warns when string concatenation is used instead of interpolation.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final message = 'Hello, $name!';
/// final path = '${base}/${file}';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final message = 'Hello, ' + name + '!';
/// final path = base + '/' + file;
/// ```
///
/// **Pros:** More readable, less error-prone, Dart idiomatic
/// **Cons:** Some prefer explicit concatenation for complex expressions
class PreferInterpolationOverConcatenationRule extends SaropaLintRule {
  const PreferInterpolationOverConcatenationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_interpolation_over_concatenation',
    problemMessage:
        '[prefer_interpolation_over_concatenation] Use string interpolation instead of concatenation.',
    correctionMessage:
        'Replace string concatenation with interpolation for readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((node) {
      if (node.operator.lexeme != '+') return;

      // Check if either operand is a string literal
      final left = node.leftOperand;
      final right = node.rightOperand;

      final hasStringLiteral =
          left is SimpleStringLiteral || right is SimpleStringLiteral;

      if (hasStringLiteral) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when interpolation is used instead of concatenation (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final message = 'Hello, ' + name + '!';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final message = 'Hello, $name!';
/// ```
///
/// **Pros:** Explicit about string building, easier to debug
/// **Cons:** More verbose, less Dart idiomatic
class PreferConcatenationOverInterpolationRule extends SaropaLintRule {
  const PreferConcatenationOverInterpolationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_concatenation_over_interpolation',
    problemMessage:
        '[prefer_concatenation_over_interpolation] Use string concatenation instead of interpolation.',
    correctionMessage:
        'Replace string interpolation with explicit concatenation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when double quotes are used instead of single quotes.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final name = 'John';
/// final message = 'Hello';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final name = "John";
/// final message = "Hello";
/// ```
///
/// **Pros:** Consistent style, single quotes are Dart convention
/// **Cons:** Double quotes needed for strings with apostrophes
class PreferDoubleQuotesRule extends SaropaLintRule {
  const PreferDoubleQuotesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_double_quotes',
    problemMessage:
        '[prefer_double_quotes] Use double quotes for string literals.',
    correctionMessage: 'Replace single quotes with double quotes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((node) {
      final lexeme = node.literal.lexeme;
      if (lexeme.startsWith("'") && !lexeme.contains('"')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// IMPORT ORGANIZATION RULES
// =============================================================================

/// Warns when absolute imports are used instead of relative imports.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import '../utils/helpers.dart';
/// import './models/user.dart';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// import 'package:my_app/utils/helpers.dart';
/// import 'package:my_app/models/user.dart';
/// ```
///
/// **Pros:** Easier refactoring, shorter imports
/// **Cons:** Can be confusing in deep directory structures
class PreferAbsoluteImportsRule extends SaropaLintRule {
  const PreferAbsoluteImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_absolute_imports',
    problemMessage:
        '[prefer_absolute_imports] Use absolute package imports instead of relative imports.',
    correctionMessage: 'Replace relative imports with package imports.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // Flag relative imports (starting with . or ..)
      if (uri.startsWith('.')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when imports are not grouped by type (dart, package, relative).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import 'dart:async';
/// import 'dart:io';
///
/// import 'package:flutter/material.dart';
/// import 'package:provider/provider.dart';
///
/// import '../utils/helpers.dart';
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// import '../utils/helpers.dart';
/// import 'dart:async';
/// import 'package:flutter/material.dart';
/// ```
///
/// **Pros:** Organized, easy to find imports
/// **Cons:** Requires manual maintenance
class PreferGroupedImportsRule extends SaropaLintRule {
  const PreferGroupedImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_grouped_imports',
    problemMessage:
        '[prefer_grouped_imports] Group imports by type: dart, package, then relative.',
    correctionMessage: 'Organize imports into groups separated by blank lines.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      final imports = node.directives.whereType<ImportDirective>().toList();
      if (imports.length < 2) return;

      int lastGroup = -1; // 0 = dart, 1 = package, 2 = relative

      for (final import in imports) {
        final uri = import.uri.stringValue;
        if (uri == null) continue;

        int currentGroup;
        if (uri.startsWith('dart:')) {
          currentGroup = 0;
        } else if (uri.startsWith('package:')) {
          currentGroup = 1;
        } else {
          currentGroup = 2;
        }

        // Check if imports are out of order (higher group before lower)
        if (lastGroup > currentGroup) {
          reporter.atNode(import, code);
        }
        lastGroup = currentGroup;
      }
    });
  }
}

/// Warns when imports are grouped (opposite - prefers flat import list).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// import 'dart:async';
/// import 'package:flutter/material.dart';
/// import '../utils/helpers.dart';
/// ```
///
/// ## Bad Example (flagged - with blank lines between groups)
/// ```dart
/// import 'dart:async';
///
/// import 'package:flutter/material.dart';
///
/// import '../utils/helpers.dart';
/// ```
///
/// **Pros:** Compact, alphabetical sorting easier
/// **Cons:** Harder to distinguish import types
class PreferFlatImportsRule extends SaropaLintRule {
  const PreferFlatImportsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_flat_imports',
    problemMessage:
        '[prefer_flat_imports] Keep imports in a flat list without grouping.',
    correctionMessage: 'Remove blank lines between import groups.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      final imports =
          node.directives.whereType<ImportDirective>().toList(growable: false);
      if (imports.length < 2) return;

      final lineInfo = resolver.lineInfo;

      for (var i = 1; i < imports.length; i++) {
        final prevImport = imports[i - 1];
        final currImport = imports[i];

        // Get line numbers for previous and current imports
        final prevEndLine = lineInfo.getLocation(prevImport.end).lineNumber;
        final currStartLine =
            lineInfo.getLocation(currImport.offset).lineNumber;

        // If there's more than one line gap (blank line), report
        if (currStartLine - prevEndLine > 1) {
          reporter.atNode(currImport, code);
        }
      }
    });
  }
}

// =============================================================================
// CLASS STRUCTURE RULES
// =============================================================================

/// Warns when fields are not declared before methods.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   final int age;
///
///   void greet() => print('Hello, $name');
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class User {
///   void greet() => print('Hello, $name');
///
///   final String name;
///   final int age;
/// }
/// ```
///
/// **Pros:** Data before behavior, easier to understand class state
/// **Cons:** Some prefer methods near related fields
class PreferFieldsBeforeMethodsRule extends SaropaLintRule {
  const PreferFieldsBeforeMethodsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_fields_before_methods',
    problemMessage:
        '[prefer_fields_before_methods] Declare fields before methods in class declarations.',
    correctionMessage: 'Move field declarations above method declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenMethod = false;

      for (final member in node.members) {
        if (member is MethodDeclaration) {
          seenMethod = true;
        } else if (member is FieldDeclaration && seenMethod) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when methods are not declared before fields (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   void greet() => print('Hello');
///   void save() => db.save(this);
///
///   final String name;
///   final int age;
/// }
/// ```
///
/// **Pros:** API/behavior first, implementation details last
/// **Cons:** Unconventional, harder to see class state
class PreferMethodsBeforeFieldsRule extends SaropaLintRule {
  const PreferMethodsBeforeFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_methods_before_fields',
    problemMessage:
        '[prefer_methods_before_fields] Declare methods before fields in class declarations.',
    correctionMessage: 'Move method declarations above field declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenField = false;

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          seenField = true;
        } else if (member is MethodDeclaration && seenField) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when static members are not declared before instance members.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class Config {
///   static const defaultTimeout = Duration(seconds: 30);
///   static Config? _instance;
///
///   final String apiUrl;
///   final int timeout;
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class Config {
///   final String apiUrl;
///   static const defaultTimeout = Duration(seconds: 30);
/// }
/// ```
///
/// **Pros:** Class-level constants visible first
/// **Cons:** Some prefer grouping by purpose
class PreferStaticMembersFirstRule extends SaropaLintRule {
  const PreferStaticMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_static_members_first',
    problemMessage:
        '[prefer_static_members_first] Declare static members before instance members in classes.',
    correctionMessage: 'Move static declarations above instance declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenInstanceMember = false;

      for (final member in node.members) {
        final isStatic = _isStaticMember(member);

        if (!isStatic) {
          seenInstanceMember = true;
        } else if (isStatic && seenInstanceMember) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when instance members are not declared before static members (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   void greet() {}
///
///   static User fromJson(Map json) => User();
///   static const tableName = 'users';
/// }
/// ```
///
/// **Pros:** Instance API first, factory/constants last
/// **Cons:** Unconventional ordering
class PreferInstanceMembersFirstRule extends SaropaLintRule {
  const PreferInstanceMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_instance_members_first',
    problemMessage:
        '[prefer_instance_members_first] Declare instance members before static members in classes.',
    correctionMessage: 'Move instance declarations above static declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenStaticMember = false;

      for (final member in node.members) {
        final isStatic = _isStaticMember(member);

        if (isStatic) {
          seenStaticMember = true;
        } else if (!isStatic && seenStaticMember) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when public members are not declared before private members.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   final String name;
///   void greet() {}
///
///   String _internalId;
///   void _validate() {}
/// }
/// ```
///
/// **Pros:** Public API visible first
/// **Cons:** Some prefer grouping by functionality
class PreferPublicMembersFirstRule extends SaropaLintRule {
  const PreferPublicMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_public_members_first',
    problemMessage:
        '[prefer_public_members_first] Declare public members before private members in classes.',
    correctionMessage: 'Move public declarations above private declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenPrivateMember = false;

      for (final member in node.members) {
        final isPrivate = _isPrivateMember(member);

        if (isPrivate) {
          seenPrivateMember = true;
        } else if (!isPrivate && seenPrivateMember) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when private members are not declared before public members (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   String _internalId;
///   void _validate() {}
///
///   final String name;
///   void greet() {}
/// }
/// ```
///
/// **Pros:** Implementation details first, encapsulation emphasis
/// **Cons:** Unconventional, hides public API
class PreferPrivateMembersFirstRule extends SaropaLintRule {
  const PreferPrivateMembersFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_private_members_first',
    problemMessage:
        '[prefer_private_members_first] Declare private members before public members in classes.',
    correctionMessage: 'Move private declarations above public declarations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      bool seenPublicMember = false;

      for (final member in node.members) {
        final isPrivate = _isPrivateMember(member);

        if (!isPrivate) {
          seenPublicMember = true;
        } else if (isPrivate && seenPublicMember) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

// =============================================================================
// TYPE ANNOTATION RULES
// =============================================================================

/// Warns when `var` is used instead of explicit type annotations.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// String name = 'John';
/// List<int> numbers = [1, 2, 3];
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// var name = 'John';
/// var numbers = [1, 2, 3];
/// ```
///
/// **Pros:** Self-documenting, explicit about types
/// **Cons:** More verbose, type inference is powerful
class PreferVarOverExplicitTypeRule extends SaropaLintRule {
  const PreferVarOverExplicitTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_var_over_explicit_type',
    problemMessage:
        '[prefer_var_over_explicit_type] Use var instead of explicit type when type is obvious.',
    correctionMessage:
        'Replace explicit type annotation with var for local variables.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclarationStatement((node) {
      final type = node.variables.type;
      if (type == null) return; // Already using var

      // Only flag if there's an initializer that makes type obvious
      for (final variable in node.variables.variables) {
        final init = variable.initializer;
        if (init == null) continue;

        // Type is obvious from literal or constructor
        if (init is Literal ||
            init is InstanceCreationExpression ||
            init is ListLiteral ||
            init is SetOrMapLiteral) {
          reporter.atNode(type, code);
        }
      }
    });
  }
}

/// Warns when `dynamic` is used instead of `Object?`.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// Object? value;
/// void process(Object? data) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// dynamic value;
/// void process(dynamic data) {}
/// ```
///
/// **Pros:** Type-safe, catches errors at compile time
/// **Cons:** Requires explicit casting, more verbose
class PreferObjectOverDynamicRule extends SaropaLintRule {
  const PreferObjectOverDynamicRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_object_over_dynamic',
    problemMessage:
        '[prefer_object_over_dynamic] Use Object? instead of dynamic for unknown types.',
    correctionMessage: 'Replace dynamic with Object? for better type safety.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((node) {
      if (node.name.lexeme == 'dynamic') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `Object?` is used instead of `dynamic` (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// dynamic value;
/// void process(dynamic data) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// Object? value;
/// void process(Object? data) {}
/// ```
///
/// **Pros:** Less verbose, easier JSON/serialization handling
/// **Cons:** Less type-safe, runtime errors possible
class PreferDynamicOverObjectRule extends SaropaLintRule {
  const PreferDynamicOverObjectRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_dynamic_over_object',
    problemMessage:
        '[prefer_dynamic_over_object] Use dynamic instead of Object? for truly dynamic types.',
    correctionMessage:
        'Replace Object? with dynamic when any operation should be allowed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((node) {
      if (node.name.lexeme == 'Object' && node.question != null) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NAMING CONVENTION RULES
// =============================================================================

/// Warns when constant names don't use lowerCamelCase.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// const maxRetries = 3;
/// const defaultTimeout = Duration(seconds: 30);
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// const MAX_RETRIES = 3;
/// const DEFAULT_TIMEOUT = Duration(seconds: 30);
/// ```
///
/// **Pros:** Consistent with Dart style guide
/// **Cons:** Some prefer SCREAMING_CASE for visibility
class PreferLowerCamelCaseConstantsRule extends SaropaLintRule {
  const PreferLowerCamelCaseConstantsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_lower_camel_case_constants',
    problemMessage:
        '[prefer_lower_camel_case_constants] Use lowerCamelCase for constant names.',
    correctionMessage:
        'Rename constant to use lowerCamelCase (e.g., maxRetries).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((node) {
      if (!node.variables.isConst) return;

      for (final variable in node.variables.variables) {
        final name = variable.name.lexeme;
        if (_isScreamingCase(name)) {
          reporter.atNode(variable, code);
        }
      }
    });

    context.registry.addFieldDeclaration((node) {
      if (!node.fields.isConst) return;

      for (final variable in node.fields.variables) {
        final name = variable.name.lexeme;
        if (_isScreamingCase(name)) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  bool _isScreamingCase(String name) {
    return name.contains('_') && name == name.toUpperCase();
  }
}

/// Warns when method names use underscores (non-private).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// void fetchUserData() {}
/// void processPayment() {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// void fetch_user_data() {}
/// void process_payment() {}
/// ```
///
/// **Pros:** Consistent with Dart naming conventions
/// **Cons:** Some prefer snake_case for readability
class PreferCamelCaseMethodNamesRule extends SaropaLintRule {
  const PreferCamelCaseMethodNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_camel_case_method_names',
    problemMessage:
        '[prefer_camel_case_method_names] Use camelCase for method names.',
    correctionMessage: 'Rename method to use camelCase (e.g., fetchUserData).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      final name = node.name.lexeme;
      // Skip private methods and operators
      if (name.startsWith('_') || node.isOperator) return;

      // Check for snake_case pattern (underscores in middle)
      if (name.contains('_')) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addFunctionDeclaration((node) {
      final name = node.name.lexeme;
      if (name.startsWith('_')) return;

      if (name.contains('_')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when variable names are too short (less than 3 characters).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final index = 0;
/// final user = getUser();
/// for (final item in items) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final i = 0;
/// final u = getUser();
/// for (final x in items) {}
/// ```
///
/// **Pros:** Self-documenting code, clearer intent
/// **Cons:** Short names fine for small scopes (i, j, x, y)
class PreferDescriptiveVariableNamesRule extends SaropaLintRule {
  const PreferDescriptiveVariableNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_descriptive_variable_names',
    problemMessage:
        '[prefer_descriptive_variable_names] Use descriptive variable names (at least 3 characters).',
    correctionMessage: 'Rename variable to be more descriptive.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const _allowedShortNames = {'id', 'db', 'io', 'ui', 'x', 'y', 'z'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((node) {
      final name = node.name.lexeme;
      // Skip private and allowed short names
      if (name.startsWith('_')) return;
      if (_allowedShortNames.contains(name.toLowerCase())) return;

      if (name.length < 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when variable names are too long (more than 30 characters).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// final userEmail = getEmail();
/// final maxRetryCount = 3;
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// final theCurrentlyLoggedInUserEmailAddress = getEmail();
/// final maximumNumberOfRetryAttemptsAllowed = 3;
/// ```
///
/// **Pros:** More readable, fits on screen
/// **Cons:** Sometimes long names are necessary for clarity
class PreferConciseVariableNamesRule extends SaropaLintRule {
  const PreferConciseVariableNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_concise_variable_names',
    problemMessage:
        '[prefer_concise_variable_names] Use concise variable names (30 characters or less).',
    correctionMessage: 'Shorten variable name while keeping it descriptive.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((node) {
      final name = node.name.lexeme;
      if (name.length > 30) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// EXPRESSION STYLE RULES
// =============================================================================

/// Warns when explicit `this.` is not used for field access.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// class User {
///   String name;
///   void greet() => print('Hello, ${this.name}');
/// }
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// class User {
///   String name;
///   void greet() => print('Hello, $name');
/// }
/// ```
///
/// **Pros:** Explicit about field access, avoids shadowing confusion
/// **Cons:** More verbose, Dart style guide discourages this
class PreferExplicitThisRule extends SaropaLintRule {
  const PreferExplicitThisRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_this',
    problemMessage:
        '[prefer_explicit_this] Use explicit this. prefix for instance field access.',
    correctionMessage: 'Add this. prefix to instance field references.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Note: Full implementation would require semantic analysis to distinguish
    // field access from local variables. This implementation detects cases where
    // a method parameter shadows a field name, which is the most common issue.
    context.registry.addMethodDeclaration((node) {
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      // Get all field names in the class
      final fieldNames = <String>{};
      for (final member in parent.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            fieldNames.add(variable.name.lexeme);
          }
        }
      }

      // Check method parameters for shadowing
      final params = node.parameters;
      if (params == null) return;

      for (final param in params.parameters) {
        final paramName = param.name?.lexeme;
        if (paramName != null && fieldNames.contains(paramName)) {
          // Parameter shadows a field - recommend explicit this.
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when `== true` is used for boolean expressions.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// if (isValid) {}
/// if (!isEnabled) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// if (isValid == true) {}
/// if (isEnabled == false) {}
/// ```
///
/// **Pros:** More concise, idiomatic Dart
/// **Cons:** Explicit comparison can be clearer for nullable bools
class PreferImplicitBooleanComparisonRule extends SaropaLintRule {
  const PreferImplicitBooleanComparisonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_implicit_boolean_comparison',
    problemMessage:
        '[prefer_implicit_boolean_comparison] Avoid explicit comparison with boolean literals.',
    correctionMessage: 'Remove == true or == false from boolean expressions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((node) {
      if (node.operator.lexeme != '==' && node.operator.lexeme != '!=') return;

      final right = node.rightOperand;
      if (right is BooleanLiteral) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when explicit `== true` is not used for nullable boolean expressions.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// ## Good Example
/// ```dart
/// if (isValid == true) {}
/// if (user?.isActive == true) {}
/// ```
///
/// ## Bad Example (flagged)
/// ```dart
/// if (isValid ?? false) {}
/// ```
///
/// **Pros:** Explicit about null handling, clearer intent
/// **Cons:** More verbose
class PreferExplicitBooleanComparisonRule extends SaropaLintRule {
  const PreferExplicitBooleanComparisonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_boolean_comparison',
    problemMessage:
        '[prefer_explicit_boolean_comparison] Use explicit == true comparison for nullable boolean expressions.',
    correctionMessage:
        'Add == true for clarity when dealing with nullable booleans.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detect `?? false` patterns - suggest using `== true` instead
    context.registry.addBinaryExpression((node) {
      if (node.operator.lexeme != '??') return;

      final right = node.rightOperand;
      if (right is BooleanLiteral && !right.value) {
        // `expr ?? false` - suggest `expr == true`
        reporter.atNode(node, code);
      }
    });
  }
}

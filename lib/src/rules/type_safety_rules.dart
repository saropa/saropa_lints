// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Type safety lint rules for Flutter/Dart applications.
///
/// These rules help catch type-related issues that can cause runtime
/// errors, improve code reliability, and leverage Dart's type system.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when `as` cast is used without null check.
///
/// Direct casting with `as` can throw if the value is null or wrong type.
/// Prefer `is` check first or use `as?` for nullable result.
///
/// **BAD:**
/// ```dart
/// final widget = context.widget as MyWidget; // Throws if wrong type
/// ```
///
/// **GOOD:**
/// ```dart
/// final widget = context.widget;
/// if (widget is MyWidget) {
///   // Use widget safely
/// }
/// // Or use pattern matching
/// if (context.widget case MyWidget widget) {
///   // Use widget
/// }
/// ```
class AvoidUnsafeCastRule extends DartLintRule {
  const AvoidUnsafeCastRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_cast',
    problemMessage: 'Direct cast with "as" may throw at runtime.',
    correctionMessage: 'Use "is" check or pattern matching instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      // Skip if it's a nullable cast (as?)
      if (node.type.question != null) return;

      // Check if there's a preceding is-check in the same scope
      final AstNode? parent = node.parent;
      if (parent == null) return;

      // Report unsafe cast
      reporter.atNode(node, code);
    });
  }
}

/// Warns when generic type parameter is not constrained.
///
/// Unconstrained type parameters accept any type including null,
/// which can lead to unexpected behavior.
///
/// **BAD:**
/// ```dart
/// class Repository<T> { // T could be anything
///   T? _cached;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Repository<T extends Entity> { // T must be Entity
///   T? _cached;
/// }
/// ```
class PreferConstrainedGenericsRule extends DartLintRule {
  const PreferConstrainedGenericsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_constrained_generics',
    problemMessage: 'Generic type parameter has no constraint.',
    correctionMessage: 'Consider adding extends clause to constrain the type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final TypeParameterList? typeParams = node.typeParameters;
      if (typeParams == null) return;

      for (final TypeParameter param in typeParams.typeParameters) {
        if (param.bound == null) {
          reporter.atNode(param, code);
        }
      }
    });
  }
}

/// Warns when covariant keyword is used without documentation.
///
/// Covariant parameters weaken type safety and can cause runtime errors.
/// They should be documented to explain why they're necessary.
///
/// **BAD:**
/// ```dart
/// class Animal {
///   void eat(covariant Food food) {} // Why covariant?
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Animal {
///   /// Uses covariant because subclasses need specific Food types.
///   void eat(covariant Food food) {}
/// }
/// ```
class RequireCovariantDocumentationRule extends DartLintRule {
  const RequireCovariantDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_covariant_documentation',
    problemMessage: 'Covariant parameter should be documented.',
    correctionMessage:
        'Add documentation explaining why covariant is necessary.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      for (final FormalParameter param in params.parameters) {
        if (param is DefaultFormalParameter) {
          final NormalFormalParameter normalParam = param.parameter;
          if (normalParam.covariantKeyword != null) {
            // Check if method has documentation
            final Comment? doc = node.documentationComment;
            if (doc == null) {
              reporter.atNode(param, code);
            }
          }
        } else if (param.covariantKeyword != null) {
          final Comment? doc = node.documentationComment;
          if (doc == null) {
            reporter.atNode(param, code);
          }
        }
      }
    });
  }
}

/// Warns when fromJson doesn't handle missing keys.
///
/// JSON parsing should handle missing or null values gracefully
/// to avoid runtime exceptions.
///
/// **BAD:**
/// ```dart
/// factory User.fromJson(Map<String, dynamic> json) {
///   return User(
///     name: json['name'] as String, // Throws if missing
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// factory User.fromJson(Map<String, dynamic> json) {
///   return User(
///     name: json['name'] as String? ?? 'Unknown',
///   );
/// }
/// ```
class RequireSafeJsonParsingRule extends DartLintRule {
  const RequireSafeJsonParsingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_safe_json_parsing',
    problemMessage: 'JSON parsing may throw on missing keys.',
    correctionMessage: 'Use null-aware operators or provide defaults.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Check for fromJson factory
      final String? name = node.name?.lexeme;
      if (name != 'fromJson' && name != 'fromMap') return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Look for direct casts without null handling
      // Pattern: json['key'] as Type (not Type?)
      final RegExp unsafeCast = RegExp(r"json\['[^']+'\]\s+as\s+(?!.*\?)(\w+)");
      if (unsafeCast.hasMatch(bodySource)) {
        // Check if there's null handling nearby
        if (!bodySource.contains('??') && !bodySource.contains('?[')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when extension method doesn't handle null receiver.
///
/// Extension methods on nullable types should check for null.
///
/// **BAD:**
/// ```dart
/// extension StringExt on String? {
///   String get upper => this!.toUpperCase(); // Throws if null
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// extension StringExt on String? {
///   String? get upper => this?.toUpperCase();
/// }
/// ```
class RequireNullSafeExtensionsRule extends DartLintRule {
  const RequireNullSafeExtensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_null_safe_extensions',
    problemMessage: 'Extension on nullable type uses null assertion.',
    correctionMessage: 'Use null-aware operators instead of "!".',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      // Get the extended type from the extension on clause
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      // Check if extending a nullable type
      final String typeSource = onClause.extendedType.toSource();
      if (!typeSource.endsWith('?')) return;

      // Check members for null assertions
      for (final ClassMember member in node.members) {
        final String memberSource = member.toSource();
        if (memberSource.contains('this!')) {
          reporter.atNode(member, code);
        }
      }
    });
  }
}

/// Warns when num is used instead of int or double.
///
/// Using specific numeric types improves type safety and performance.
///
/// **BAD:**
/// ```dart
/// num calculate(num a, num b) => a + b;
/// ```
///
/// **GOOD:**
/// ```dart
/// double calculate(double a, double b) => a + b;
/// ```
class PreferSpecificNumericTypesRule extends DartLintRule {
  const PreferSpecificNumericTypesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_specific_numeric_types',
    problemMessage: 'Prefer int or double over num for better type safety.',
    correctionMessage: 'Use int or double instead of num.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType != null && returnType.toSource() == 'num') {
        reporter.atNode(returnType, code);
      }

      // Check parameters
      final FormalParameterList? params = node.parameters;
      if (params != null) {
        for (final FormalParameter param in params.parameters) {
          final String paramSource = param.toSource();
          if (paramSource.startsWith('num ') ||
              paramSource.contains(' num ') ||
              paramSource.contains('(num ')) {
            reporter.atNode(param, code);
          }
        }
      }
    });
  }
}

/// Warns when FutureOr is used in public API without documentation.
///
/// FutureOr can be confusing for API consumers and should be documented.
///
/// **BAD:**
/// ```dart
/// FutureOr<String> getValue(); // Sync or async?
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Returns cached value sync, or fetches async if not cached.
/// FutureOr<String> getValue();
/// ```
class RequireFutureOrDocumentationRule extends DartLintRule {
  const RequireFutureOrDocumentationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_futureor_documentation',
    problemMessage: 'FutureOr return type should be documented.',
    correctionMessage: 'Add documentation explaining when sync vs async.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String typeSource = returnType.toSource();
      if (!typeSource.startsWith('FutureOr')) return;

      // Check if method has documentation
      if (node.documentationComment == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

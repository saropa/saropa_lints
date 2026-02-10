// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Type safety lint rules for Flutter/Dart applications.
///
/// These rules help catch type-related issues that can cause runtime
/// errors, improve code reliability, and leverage Dart's type system.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';
import '../type_annotation_utils.dart';

/// Warns when `as` cast is used without null check.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Direct casting with `as` can throw if the value is null or wrong type.
/// Prefer `is` check first or use `as?` for nullable result.
///
/// Skips provably safe casts:
/// - Cast to `Object` (every non-null Dart value is an Object)
/// - Same-type casts (redundant but safe)
/// - Upcasts to a supertype (e.g. `int as num`)
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
class AvoidUnsafeCastRule extends SaropaLintRule {
  const AvoidUnsafeCastRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_cast',
    problemMessage:
        '[avoid_unsafe_cast] Direct cast with "as" may throw at runtime. Direct casting with as can throw if the value is null or wrong type. Prefer is check first or use as? for nullable result. {v5}',
    correctionMessage:
        'Use "is" check or pattern matching instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      // Skip if it's a nullable cast (as?)
      if (node.type.question != null) return;

      // Skip provably safe casts
      if (_isSafeCast(node)) return;

      final AstNode? parent = node.parent;
      if (parent == null) return;

      // Report unsafe cast
      reporter.atNode(node, code);
    });
  }

  /// Returns true if the cast is provably safe at compile time.
  bool _isSafeCast(AsExpression node) {
    final DartType? sourceType = node.expression.staticType;
    final String targetName = node.type.toSource().replaceAll('?', '');

    // Cast to Object is always safe (every Dart value is an Object)
    if (targetName == 'Object') return true;

    if (sourceType == null || sourceType is DynamicType) return false;

    // Check if target is the same type or a supertype (upcast)
    if (sourceType is InterfaceType) {
      final String? sourceName = sourceType.element.name;

      // Same-type cast is safe
      if (sourceName == targetName) return true;

      // Upcast to a supertype is safe
      for (final InterfaceType supertype in sourceType.allSupertypes) {
        if (supertype.element.name == targetName) return true;
      }
    }

    return false;
  }
}

/// Warns when generic type parameter is not constrained.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class PreferConstrainedGenericsRule extends SaropaLintRule {
  const PreferConstrainedGenericsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_constrained_generics',
    problemMessage:
        '[prefer_constrained_generics] Generic type parameter has no constraint. Unconstrained type parameters accept any type including null, which can lead to unexpected behavior. This weakens type safety, allowing errors to reach runtime where they crash instead of being caught at compile time. {v4}',
    correctionMessage:
        'Add extends clause to constrain the type. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class RequireCovariantDocumentationRule extends SaropaLintRule {
  const RequireCovariantDocumentationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_covariant_documentation',
    problemMessage:
        '[require_covariant_documentation] Covariant parameter must be documented. Covariant parameters weaken type safety and can cause runtime errors. They must be documented to explain why they\'re necessary. {v5}',
    correctionMessage:
        'Add documentation explaining why covariant is necessary. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class RequireSafeJsonParsingRule extends SaropaLintRule {
  const RequireSafeJsonParsingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_safe_json_parsing',
    problemMessage:
        '[require_safe_json_parsing] JSON parsing may throw on missing keys. JSON parsing should handle missing or null values gracefully to avoid runtime exceptions. This weakens type safety, allowing errors to reach runtime where they crash instead of being caught at compile time. {v4}',
    correctionMessage:
        'Use null-aware operators or provide defaults. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Regex to match unsafe casts in JSON parsing.
  /// Matches: map['key'] as Type, json['key'] as Type, data['key'] as Type
  /// Excludes: Type? (nullable cast) and as Type?
  static final RegExp _unsafeCastPattern = RegExp(
    r"\w+\['[^']+'\]\s+as\s+(?!(\w+\?|dynamic))(\w+)",
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Check for fromJson factory
      final String? name = node.name?.lexeme;
      if (name != 'fromJson' && name != 'fromMap') return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Look for direct casts without null handling
      // Pattern: map['key'] as Type (not Type? or dynamic)
      if (_unsafeCastPattern.hasMatch(bodySource)) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class RequireNullSafeExtensionsRule extends SaropaLintRule {
  const RequireNullSafeExtensionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_null_safe_extensions',
    problemMessage:
        '[require_null_safe_extensions] Extension method on a nullable type does not handle null receivers. This can cause runtime exceptions. Extension methods on nullable types should check for null. {v4}',
    correctionMessage:
        'Add null checks or use ?. to safely handle nullable receivers in extension methods.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExtensionDeclaration((ExtensionDeclaration node) {
      // Get the extended type from the extension on clause
      final ExtensionOnClause? onClause = node.onClause;
      if (onClause == null) return;

      // Check if extending a nullable type
      if (!isOuterTypeNullable(onClause.extendedType)) return;

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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class PreferSpecificNumericTypesRule extends SaropaLintRule {
  const PreferSpecificNumericTypesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_specific_numeric_types',
    problemMessage:
        '[prefer_specific_numeric_types] Prefer int or double over num to improve type safety. This weakens type safety, allowing errors to reach runtime where they crash instead of being caught at compile time. {v4}',
    correctionMessage:
        'Use int or double instead of num. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Warns when the non-null assertion operator (!) is used.
///
/// Since: v4.9.16 | Updated: v4.13.0 | Rule version: v2
///
/// The `!` operator can cause runtime crashes if the value is null.
/// Prefer null-aware operators or explicit null checks.
///
/// **BAD:**
/// ```dart
/// final name = user.name!; // Crashes if null
/// ```
///
/// **GOOD:**
/// ```dart
/// final name = user.name ?? 'Unknown';
/// // Or use null-aware access
/// final length = user.name?.length;
/// ```
class AvoidNonNullAssertionRule extends SaropaLintRule {
  const AvoidNonNullAssertionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_non_null_assertion',
    problemMessage:
        '[avoid_non_null_assertion] Non-null assertion operator (!) throws a runtime exception if the value is null, crashing the app. '
        'The resulting _CastError provides no context about which variable was null or why, making production crashes from error reports and stack traces alone difficult to diagnose and reproduce. {v2}',
    correctionMessage:
        'Use null-aware operators (?., ??) or explicit null checks (if (value != null)) to handle nullability safely. '
        'When null is truly impossible due to prior validation, add an assert with a descriptive message or use a guard clause that throws a meaningful exception.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPostfixExpression((PostfixExpression node) {
      if (node.operator.lexeme == '!') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `as` keyword is used for type casting.
///
/// Since: v4.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Type casts with `as` can throw at runtime. Prefer `is` checks
/// or pattern matching for safer type narrowing.
///
/// **BAD:**
/// ```dart
/// final widget = obj as Widget;
/// ```
///
/// **GOOD:**
/// ```dart
/// if (obj is Widget) {
///   // obj is automatically cast to Widget
/// }
/// ```
class AvoidTypeCastsRule extends SaropaLintRule {
  const AvoidTypeCastsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_type_casts',
    problemMessage:
        '[avoid_type_casts] Type cast with "as" may throw at runtime. Type casts with as can throw at runtime. Prefer is checks or pattern matching for safer type narrowing. {v2}',
    correctionMessage:
        'Use "is" check or pattern matching instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when FutureOr is used in public API without documentation.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class RequireFutureOrDocumentationRule extends SaropaLintRule {
  const RequireFutureOrDocumentationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_futureor_documentation',
    problemMessage:
        '[require_futureor_documentation] FutureOr return type must be documented. FutureOr can be confusing for API consumers and must be documented. FutureOr is used in public API without documentation. {v4}',
    correctionMessage:
        'Add documentation explaining when sync vs async. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Warns when generic types lack explicit type arguments.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v5
///
/// Explicit type arguments improve code clarity and prevent
/// accidental type inference issues.
///
/// **BAD:**
/// ```dart
/// final list = []; // List<dynamic>
/// final map = {}; // Map<dynamic, dynamic>
/// final future = Future.value(1); // Inferred
/// ```
///
/// **GOOD:**
/// ```dart
/// final list = <String>[];
/// final map = <String, int>{};
/// final future = Future<int>.value(1);
/// ```
class PreferExplicitTypeArgumentsRule extends SaropaLintRule {
  const PreferExplicitTypeArgumentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  // Performance note: No requiredPatterns override because empty collection
  // literals (`[]`, `{}`) and generic constructors (`Future`, `Completer`) are
  // ubiquitous in Dart code. Pattern-based filtering would not provide
  // meaningful early-exit optimization for this rule.

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_type_arguments',
    problemMessage:
        '[prefer_explicit_type_arguments] Generic type without explicit type arguments. Explicit type arguments improve code clarity and prevent accidental type inference issues. Collections with types inferred from context are skipped. {v6}',
    correctionMessage:
        'Add explicit type arguments to the generic type so that the intended types are visible without relying on inference.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      if (node.typeArguments == null &&
          node.elements.isEmpty &&
          !_hasInferredTypeArgs(node.staticType)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (node.typeArguments == null &&
          node.elements.isEmpty &&
          !_hasInferredTypeArgs(node.staticType)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      // Check for generic types without explicit args
      final TypeArgumentList? typeArgs =
          node.constructorName.type.typeArguments;
      final String? typeName = node.constructorName.type.element?.name;

      // Only check common generic types
      const Set<String> genericTypes = <String>{
        'Future',
        'Stream',
        'Completer',
        'StreamController',
        'ValueNotifier',
        'BehaviorSubject',
        'PublishSubject',
      };

      if (typeName != null &&
          genericTypes.contains(typeName) &&
          typeArgs == null) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  /// Returns true if [staticType] has non-dynamic type arguments inferred
  /// from context (return type, variable type, parameter type).
  static bool _hasInferredTypeArgs(DartType? staticType) {
    if (staticType is! InterfaceType) return false;
    final typeArgs = staticType.typeArguments;
    return typeArgs.isNotEmpty &&
        !typeArgs.every((DartType t) => t is DynamicType);
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferExplicitTypeArgumentsFix()];
}

/// Quick fix for [PreferExplicitTypeArgumentsRule].
///
/// Adds explicit type arguments to empty collection literals and generic
/// constructor calls. The fix infers the correct type from the static type
/// analysis and inserts the appropriate type annotation.
///
/// Handles:
/// - Empty list literals: `[]` → `<String>[]`
/// - Empty set/map literals: `{}` → `<String, int>{}`
/// - Generic constructors: `Future.value(1)` → `Future<int>.value(1)`
///
/// Note: The three handlers have similar type-extraction logic but are kept
/// separate because each has unique insertion logic (different AST node
/// properties for the insertion point). Extracting a shared helper would
/// require passing node-specific accessors, adding complexity without benefit.
class _PreferExplicitTypeArgumentsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Fix for empty list literals
    context.registry.addListLiteral((ListLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.typeArguments != null) return;

      final DartType? listType = node.staticType;
      if (listType is! InterfaceType) return;

      final List<DartType> typeArgs = listType.typeArguments;
      if (typeArgs.isEmpty) return;

      final String typeArgStr =
          typeArgs.map((DartType t) => t.getDisplayString()).join(', ');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add <$typeArgStr>',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.leftBracket.offset, '<$typeArgStr>');
      });
    });

    // Fix for empty set/map literals
    context.registry.addSetOrMapLiteral((SetOrMapLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.typeArguments != null) return;

      final DartType? type = node.staticType;
      if (type is! InterfaceType) return;

      final List<DartType> typeArgs = type.typeArguments;
      if (typeArgs.isEmpty) return;

      final String typeArgStr =
          typeArgs.map((DartType t) => t.getDisplayString()).join(', ');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add <$typeArgStr>',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.leftBracket.offset, '<$typeArgStr>');
      });
    });

    // Fix for generic constructor calls
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final TypeArgumentList? existingTypeArgs =
          node.constructorName.type.typeArguments;
      if (existingTypeArgs != null) return;

      final DartType? staticType = node.staticType;
      if (staticType is! InterfaceType) return;

      final List<DartType> typeArgs = staticType.typeArguments;
      if (typeArgs.isEmpty) return;

      final String typeArgStr =
          typeArgs.map((DartType t) => t.getDisplayString()).join(', ');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add <$typeArgStr>',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert after the type name
        final NamedType namedType = node.constructorName.type;
        builder.addSimpleInsertion(namedType.name2.end, '<$typeArgStr>');
      });
    });
  }
}

/// Detects casts between unrelated types that will always fail at runtime.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// When casting between types that have no inheritance relationship,
/// the cast will always throw a TypeError at runtime.
///
/// **BAD:**
/// ```dart
/// final str = 'hello';
/// final num = str as int; // String and int are unrelated!
///
/// final widget = myButton as TextField; // Always fails if unrelated
/// ```
///
/// **GOOD:**
/// ```dart
/// final obj = getValue();
/// if (obj is int) {
///   // Use obj safely as int
/// }
/// // Or check relationship first
/// if (widget is TextField) {
///   // Use widget as TextField
/// }
/// ```
class AvoidUnrelatedTypeCastsRule extends SaropaLintRule {
  const AvoidUnrelatedTypeCastsRule() : super(code: _code);

  /// Critical issue - always-failing cast causes runtime crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_unrelated_type_casts',
    problemMessage:
        '[avoid_unrelated_type_casts] Casting between unrelated types (such as String to int) will always throw a runtime error, leading to crashes and unpredictable behavior. This often indicates a logic error or misunderstanding of the type system. Always ensure types are compatible before casting to prevent runtime failures and improve code safety. {v3}',
    correctionMessage:
        'Before casting, use an "is" check or verify the type hierarchy to ensure the cast is valid. Refactor code to avoid unnecessary or unsafe casts and rely on type-safe patterns.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Types that are clearly unrelated to each other (leaf types).
  /// Casting between these types will always fail.
  static const Set<String> _leafTypes = <String>{
    'String',
    'int',
    'double',
    'bool',
    'Symbol',
    'Type',
    'Null',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      final Expression expression = node.expression;
      final TypeAnnotation targetType = node.type;

      // Get the source type from the expression
      final String? sourceTypeName = _getTypeName(expression);
      final String targetTypeName = targetType.toSource().replaceAll('?', '');

      if (sourceTypeName == null) return;

      // Check if both are leaf types and different
      if (_leafTypes.contains(sourceTypeName) &&
          _leafTypes.contains(targetTypeName) &&
          sourceTypeName != targetTypeName) {
        reporter.atNode(node, code);
      }
    });
  }

  String? _getTypeName(Expression expression) {
    // Handle simple literals
    if (expression is StringLiteral) return 'String';
    if (expression is IntegerLiteral) return 'int';
    if (expression is DoubleLiteral) return 'double';
    if (expression is BooleanLiteral) return 'bool';
    if (expression is NullLiteral) return 'Null';

    // Try to get static type from the expression
    final staticType = expression.staticType;
    if (staticType != null) {
      final String typeName = staticType.getDisplayString();
      for (final String leafType in _leafTypes) {
        if (typeName == leafType || typeName == '$leafType?') {
          return leafType;
        }
      }
    }

    return null;
  }
}

/// Detects chained JSON access without null checks.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v6
///
/// Accessing nested JSON with chained bracket notation like
/// `json['key']['nested']` without null checks can cause
/// null pointer exceptions when intermediate keys don't exist.
///
/// **BAD:**
/// ```dart
/// final name = json['user']['profile']['name']; // Throws if any key missing
/// final data = response['data']['items'][0]; // Unsafe chain
/// ```
///
/// **GOOD:**
/// ```dart
/// final user = json['user'] as Map<String, dynamic>?;
/// final profile = user?['profile'] as Map<String, dynamic>?;
/// final name = profile?['name'];
///
/// // Or use extension methods
/// final name = json.optionalString(['user', 'profile', 'name']);
/// ```
class AvoidDynamicJsonAccessRule extends SaropaLintRule {
  const AvoidDynamicJsonAccessRule() : super(code: _code);

  /// High impact - null access causes runtime crash.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_json_access',
    problemMessage:
        '[avoid_dynamic_json_access] Chained dynamic JSON access without null checks throws NoSuchMethodError at runtime when any intermediate key is missing or null. This causes unhandled crashes in production when API responses deviate from the expected schema, with no compile-time safety net. {v6}',
    correctionMessage:
        'Use null-aware operators (?.) for safe access, or validate each level exists before accessing nested properties to prevent runtime crashes.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Check if target is also an index expression (chained access)
      final Expression? targetExpr = node.target;
      if (targetExpr is! IndexExpression) return;
      final IndexExpression target = targetExpr;

      // Check if the index is a string literal (JSON key access pattern)
      if (node.index is! SimpleStringLiteral) return;
      if (target.index is! SimpleStringLiteral) return;

      // Check if parent is NOT a null-aware access
      final AstNode? parent = node.parent;

      // Skip if using null-aware index (?[])
      if (node.question != null) return;
      if (target.question != null) return;

      // Skip if inside null check pattern
      if (parent is BinaryExpression) {
        if (parent.operator.lexeme == '??' || parent.operator.lexeme == '?.') {
          return;
        }
      }

      // Skip if wrapped in try-catch
      if (_isInsideTryCatch(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) return true;
      current = current.parent;
    }
    return false;
  }
}

/// Detects JSON map access without null safety handling.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
///
/// Accessing a JSON map with bracket notation `json['key']` returns
/// dynamic and can be null. Directly using this value without
/// null check causes runtime errors.
///
/// **BAD:**
/// ```dart
/// final name = json['name'] as String; // Throws if null
/// final age = json['age'] as int; // Throws if key missing
/// widget.text = json['text']; // Assigns potentially null
/// ```
///
/// **GOOD:**
/// ```dart
/// final name = json['name'] as String? ?? 'default';
/// final age = json['age'] as int?;
/// if (age != null) { ... }
///
/// // Or with type check
/// final nameValue = json['name'];
/// if (nameValue is String) { ... }
/// ```
class RequireNullSafeJsonAccessRule extends SaropaLintRule {
  const RequireNullSafeJsonAccessRule() : super(code: _code);

  /// Critical issue - null access causes crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_null_safe_json_access',
    problemMessage:
        '[require_null_safe_json_access] Accessing values from a JSON map without checking for key existence or null values can throw exceptions (such as NoSuchMethodError or TypeError) if the key is missing or the value is null. This is a common source of runtime crashes and unstable code, especially when dealing with data from APIs, user input, or external sources. Null-safe access is essential for robust, production-quality Dart and Flutter applications. {v4}',
    correctionMessage:
        'Always use null-aware operators (such as ?. or ??) or explicitly check for key existence before accessing values in a JSON map. This prevents runtime exceptions and makes your code safer and more maintainable. Audit your codebase for direct JSON map access and refactor to use null-safe patterns, especially in code that handles external or untrusted data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAsExpression((AsExpression node) {
      final Expression expression = node.expression;

      // Check if expression is an index expression (map access)
      if (expression is! IndexExpression) return;

      // Check if index is a string literal (JSON key pattern)
      if (expression.index is! SimpleStringLiteral) return;

      // Check if type is non-nullable (doesn't end with ?)
      final TypeAnnotation targetType = node.type;
      if (targetType.question != null) return; // Has ? so it's nullable

      // Check if there's null coalescing after
      final AstNode? parent = node.parent;
      if (parent is BinaryExpression && parent.operator.lexeme == '??') {
        return; // Has null coalescing
      }

      // Check if inside null check conditional
      if (_hasNullCheckGuard(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _hasNullCheckGuard(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;
    while (current != null && depth < 5) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('!= null') ||
            condition.contains('is ') ||
            condition.contains('case ')) {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Detects deeply chained JSON access patterns.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// Accessing JSON with deeply chained bracket notation like
/// `json['a']['b']['c']` is error-prone and difficult to maintain.
/// Prefer flattening or using helper methods.
///
/// **BAD:**
/// ```dart
/// final value = json['data']['user']['address']['city'];
/// final item = response['results']['items']['first']['name'];
/// ```
///
/// **GOOD:**
/// ```dart
/// final data = json['data'] as Map<String, dynamic>?;
/// final user = data?['user'] as Map<String, dynamic>?;
/// final address = user?['address'] as Map<String, dynamic>?;
/// final city = address?['city'] as String?;
///
/// // Or create a typed model
/// final user = User.fromJson(json);
/// final city = user.address?.city;
/// ```
class AvoidDynamicJsonChainsRule extends SaropaLintRule {
  const AvoidDynamicJsonChainsRule() : super(code: _code);

  /// Critical issue - deep chains are fragile and crash on missing keys.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_json_chains',
    problemMessage:
        '[avoid_dynamic_json_chains] Deep dynamic access throws NoSuchMethodError '
        'or TypeError at runtime when any nested key is missing. Chaining multiple dynamic map accesses (e.g., json["a"]["b"]["c"]) is fragile and will crash if any key is missing or null. This leads to runtime exceptions, broken features, and poor user experience. Always check each level for null before accessing the next. {v3}',
    correctionMessage:
        'Break deep dynamic map accesses into separate statements with null checks at each level. Use safe navigation (?.) or explicit checks to prevent runtime errors and improve code robustness.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Count chain depth
      int depth = _getChainDepth(node);

      // Report if chain is 3 or more levels deep
      if (depth >= 3) {
        // Only report on the outermost expression to avoid duplicates
        final AstNode? parent = node.parent;
        if (parent is IndexExpression) return; // Not outermost

        reporter.atNode(node, code);
      }
    });
  }

  int _getChainDepth(IndexExpression node) {
    int depth = 1;
    Expression? target = node.target;

    while (target is IndexExpression) {
      // Only count if index is a string literal (JSON key pattern)
      if (target.index is SimpleStringLiteral) {
        depth++;
      }
      target = target.target;
    }

    return depth;
  }
}

/// Detects enum parsing from API without fallback for unknown values.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v6
///
/// When parsing enums from external data (API responses, JSON), new
/// values may be added that the app doesn't know about. Without a
/// fallback, this crashes the app.
///
/// **BAD:**
/// ```dart
/// final status = Status.values.byName(json['status']); // Throws on unknown
/// final type = MyEnum.values.firstWhere((e) => e.name == data); // Throws
/// ```
///
/// **GOOD:**
/// ```dart
/// final status = Status.values.asNameMap()[json['status']] ?? Status.unknown;
///
/// // Or with tryByName extension
/// final type = MyEnum.values.tryByName(data) ?? MyEnum.fallback;
///
/// // Or exhaustive switch with default
/// Status parseStatus(String value) {
///   return switch (value) {
///     'active' => Status.active,
///     'inactive' => Status.inactive,
///     _ => Status.unknown,
///   };
/// }
/// ```
class RequireEnumUnknownValueRule extends SaropaLintRule {
  const RequireEnumUnknownValueRule() : super(code: _code);

  /// High impact - crashes on new API values.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_enum_unknown_value',
    problemMessage:
        '[require_enum_unknown_value] Enum parsing without a fallback value throws an ArgumentError when the input string does not match any enum member. Backend API changes or new enum values added server-side will crash the app in production for all users until a client update is deployed. {v6}',
    correctionMessage:
        'Add a fallback enum value (e.g., .unknown) using the orElse parameter, or use MyEnum.values.tryByName() to safely handle unknown values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for .byName() calls on enum.values
      if (methodName == 'byName') {
        final Expression? target = node.target;
        if (target != null && target.toSource().contains('.values')) {
          // Check if result has fallback
          if (!_hasFallback(node)) {
            reporter.atNode(node, code);
          }
        }
      }

      // Check for .firstWhere() on enum.values without orElse
      if (methodName == 'firstWhere') {
        final Expression? target = node.target;
        if (target != null && target.toSource().contains('.values')) {
          // Check if has orElse parameter
          bool hasOrElse = false;
          for (final Expression arg in node.argumentList.arguments) {
            if (arg is NamedExpression && arg.name.label.name == 'orElse') {
              hasOrElse = true;
              break;
            }
          }
          if (!hasOrElse && !_hasFallback(node)) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  bool _hasFallback(AstNode node) {
    final AstNode? parent = node.parent;

    // Check for null coalescing
    if (parent is BinaryExpression && parent.operator.lexeme == '??') {
      return true;
    }

    // Check for conditional expression
    if (parent is ConditionalExpression) {
      return true;
    }

    // Check if assigned to nullable variable
    if (parent is VariableDeclaration) {
      final String source = parent.toSource();
      if (source.contains('?')) return true;
    }

    return false;
  }
}

/// Detects form validators that don't return null for valid input.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// Form validators in Flutter must return null when input is valid.
/// Returning a string always shows an error message. Forgetting to
/// return null for the valid case breaks form validation.
///
/// **BAD:**
/// ```dart
/// validator: (value) {
///   if (value == null || value.isEmpty) {
///     return 'Required field';
///   }
///   // Forgot to return null! Always shows error
/// }
///
/// validator: (value) {
///   return value!.isEmpty ? 'Required' : 'Valid'; // Never valid!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// validator: (value) {
///   if (value == null || value.isEmpty) {
///     return 'Required field';
///   }
///   return null; // Valid input
/// }
///
/// validator: (value) {
///   return value!.isEmpty ? 'Required' : null;
/// }
/// ```
class RequireValidatorReturnNullRule extends SaropaLintRule {
  const RequireValidatorReturnNullRule() : super(code: _code);

  /// Critical issue - forms never validate successfully.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_validator_return_null',
    problemMessage:
        '[require_validator_return_null] Non-null return on valid input shows '
        'error message even when field is correct, confusing users. Validator functions in forms must return null for valid input. Returning a non-null value causes error messages to display even when the field is correct, leading to user frustration and broken form validation. {v3}',
    correctionMessage:
        'Always return null from validator functions when the input is valid. This ensures error messages are only shown for invalid input and provides a correct user experience.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextFormField') return;

      // Find validator argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'validator') {
          final Expression validatorExpr = arg.expression;

          // Check function expression validators
          if (validatorExpr is FunctionExpression) {
            final FunctionBody body = validatorExpr.body;
            if (!_hasNullReturn(body)) {
              reporter.atNode(arg.name, code);
            }
          }
        }
      }
    });
  }

  bool _hasNullReturn(FunctionBody body) {
    final String source = body.toSource();

    // Check for explicit return null
    if (source.contains('return null')) return true;

    // Check for conditional with null
    // Pattern: condition ? 'error' : null
    final ternaryWithNullPattern = RegExp(
        r"\?\s*['" + r'"' + r"][^'" + r'"' + r"]+['" + r'"' + r"]\s*:\s*null");
    if (ternaryWithNullPattern.hasMatch(source)) {
      return true;
    }

    // Pattern: condition ? null : 'error'
    final nullThenStringPattern = RegExp(r"\?\s*null\s*:\s*['" + r'"' + r"]");
    if (nullThenStringPattern.hasMatch(source)) {
      return true;
    }

    // Check for switch expression with null case
    if (source.contains('=> null') || source.contains('_ => null')) {
      return true;
    }

    return false;
  }
}

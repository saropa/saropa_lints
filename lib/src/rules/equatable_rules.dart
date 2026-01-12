// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Shared Utilities
// =============================================================================

/// Checks if a class declaration extends Equatable or uses EquatableMixin.
bool isEquatable(ClassDeclaration node) {
  // Check extends Equatable
  final ExtendsClause? extendsClause = node.extendsClause;
  if (extendsClause != null) {
    final String superclassName = extendsClause.superclass.name2.lexeme;
    if (superclassName == 'Equatable') return true;
  }

  // Check mixes in EquatableMixin
  final WithClause? withClause = node.withClause;
  if (withClause != null) {
    for (final NamedType mixin in withClause.mixinTypes) {
      if (mixin.name2.lexeme == 'EquatableMixin') return true;
    }
  }

  return false;
}

// =============================================================================
// Equatable Rules
// =============================================================================

/// Warns when a class overrides operator == but doesn't extend Equatable.
///
/// Alias: prefer_equatable, use_equatable_for_equality
///
/// Equatable provides consistent hashCode and equality implementations
/// with less boilerplate and fewer opportunities for bugs.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person {
///   final String name;
///   final int age;
///
///   @override
///   bool operator ==(Object other) =>
///       other is Person && name == other.name && age == other.age;
///
///   @override
///   int get hashCode => Object.hash(name, age);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
class ExtendEquatableRule extends SaropaLintRule {
  const ExtendEquatableRule() : super(code: _code);

  /// Maintainability issue. Cleaner equality pattern available.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'extend_equatable',
    problemMessage:
        'Class overrides operator == but does not extend Equatable.',
    correctionMessage:
        'Consider extending Equatable for cleaner equality implementation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable
      if (_extendsEquatable(node)) return;

      // Check if class mixes in EquatableMixin
      if (_mixesInEquatable(node)) return;

      // Check if class overrides operator ==
      bool hasEqualsOverride = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == '==' &&
            member.isOperator) {
          hasEqualsOverride = true;
          break;
        }
      }

      if (hasEqualsOverride) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _extendsEquatable(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final String superclassName = extendsClause.superclass.name2.lexeme;
    return superclassName == 'Equatable';
  }

  bool _mixesInEquatable(ClassDeclaration node) {
    final WithClause? withClause = node.withClause;
    if (withClause == null) return false;

    for (final NamedType mixin in withClause.mixinTypes) {
      if (mixin.name2.lexeme == 'EquatableMixin') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when an Equatable subclass has fields not listed in props.
///
/// Alias: require_equatable_all_fields_in_props, missing_props_field, equatable_props_incomplete
///
/// All fields should be included in props for correct equality comparison.
/// Missing fields can lead to subtle equality bugs.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///   final String email; // Missing from props!
///
///   @override
///   List<Object?> get props => [name, age]; // email is missing
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///   final String email;
///
///   @override
///   List<Object?> get props => [name, age, email]; // All fields included
/// }
/// ```
///
/// Alias: require_props_consistency
class ListAllEquatableFieldsRule extends SaropaLintRule {
  const ListAllEquatableFieldsRule() : super(code: _code);

  /// Potential bug. Missing field in equality comparison.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'list_all_equatable_fields',
    problemMessage: 'Equatable class has fields not included in props.',
    correctionMessage:
        'Add all instance fields to the props getter for correct equality.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Collect all instance fields
      final Set<String> instanceFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final VariableDeclaration variable in member.fields.variables) {
            instanceFields.add(variable.name.lexeme);
          }
        }
      }

      if (instanceFields.isEmpty) return;

      // Find props getter
      MethodDeclaration? propsGetter;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          propsGetter = member;
          break;
        }
      }

      if (propsGetter == null) {
        // No props getter at all - definitely missing fields
        reporter.atNode(node, code);
        return;
      }

      // Extract identifiers from props return value
      final Set<String> propsFields = <String>{};
      final FunctionBody body = propsGetter.body;

      if (body is ExpressionFunctionBody) {
        _extractIdentifiers(body.expression, propsFields);
      } else if (body is BlockFunctionBody) {
        for (final Statement statement in body.block.statements) {
          if (statement is ReturnStatement && statement.expression != null) {
            _extractIdentifiers(statement.expression!, propsFields);
          }
        }
      }

      // Check if all instance fields are in props
      final Set<String> missingFields = instanceFields.difference(propsFields);
      if (missingFields.isNotEmpty) {
        reporter.atNode(propsGetter, code);
      }
    });
  }

  void _extractIdentifiers(Expression expr, Set<String> identifiers) {
    if (expr is ListLiteral) {
      for (final CollectionElement element in expr.elements) {
        if (element is Expression) {
          _extractIdentifiers(element, identifiers);
        }
      }
    } else if (expr is SimpleIdentifier) {
      identifiers.add(expr.name);
    } else if (expr is PrefixedIdentifier) {
      // Handle this.field or super.field
      identifiers.add(expr.identifier.name);
    } else if (expr is PropertyAccess) {
      // Handle expressions like this.field
      if (expr.target is ThisExpression) {
        identifiers.add(expr.propertyName.name);
      }
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddMissingFieldsToPropsHint()];
}

class _AddMissingFieldsToPropsHint extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.lexeme != 'props' || !node.isGetter) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Review: ensure all fields are in props',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Ensure all instance fields are included in props\n  ',
        );
      });
    });
  }
}

/// Warns when a class extends Equatable but could use EquatableMixin instead.
///
/// Alias: use_equatable_mixin, equatable_mixin_over_extends
///
/// Using EquatableMixin is preferred when:
/// - The class already extends another class
/// - You want to preserve the class hierarchy
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   // ... but Person needs to extend Entity
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Person extends Entity with EquatableMixin {
///   final String name;
///
///   @override
///   List<Object?> get props => [name];
/// }
/// ```
///
/// NOTE: This rule only triggers when a class extends Equatable directly
/// and could benefit from using the mixin pattern instead. It's primarily
/// about awareness of the mixin option.
class PreferEquatableMixinRule extends SaropaLintRule {
  const PreferEquatableMixinRule() : super(code: _code);

  /// Style preference. Consider mixin for flexibility.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_equatable_mixin',
    problemMessage:
        'Consider using EquatableMixin instead of extending Equatable.',
    correctionMessage:
        'EquatableMixin allows you to extend other classes while keeping '
        'Equatable functionality. Change to: class X with EquatableMixin',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name2.lexeme;

      // Only suggest for classes that directly extend Equatable
      if (superclassName != 'Equatable') return;

      // Check if class already uses any mixins - if so, mixin pattern
      // would be even more appropriate
      final WithClause? withClause = node.withClause;
      if (withClause != null && withClause.mixinTypes.isNotEmpty) {
        // Already using mixins, strongly suggest EquatableMixin
        reporter.atNode(extendsClause, code);
        return;
      }

      // For classes extending only Equatable with no mixins,
      // this is more of a suggestion for awareness
      // Report at INFO level
      reporter.atNode(extendsClause, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToEquatableMixinFix()];
}

class _ConvertToEquatableMixinFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      if (extendsClause.superclass.name2.lexeme != 'Equatable') {
        return;
      }

      final WithClause? withClause = node.withClause;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Convert to EquatableMixin',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        if (withClause != null) {
          // Already has mixins, just remove extends Equatable and add mixin
          builder.addSimpleReplacement(
            SourceRange(extendsClause.offset, extendsClause.length),
            '',
          );

          // Add EquatableMixin to existing with clause
          final int insertOffset = withClause.mixinTypes.last.end;
          builder.addSimpleInsertion(insertOffset, ', EquatableMixin');
        } else {
          // Replace 'extends Equatable' with 'with EquatableMixin'
          builder.addSimpleReplacement(
            SourceRange(extendsClause.offset, extendsClause.length),
            'with EquatableMixin',
          );
        }
      });
    });
  }
}

/// Warns when an Equatable class doesn't override stringify to true.
///
/// Alias: equatable_stringify, require_stringify_override
///
/// Overriding stringify to true provides better debugging output by including
/// field values in toString() instead of just the class name.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
///   // Missing stringify override - toString() shows "Person"
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
///
///   @override
///   bool get stringify => true;
///   // toString() now shows "Person(name, age)"
/// }
/// ```
class PreferEquatableStringifyRule extends SaropaLintRule {
  const PreferEquatableStringifyRule() : super(code: _code);

  /// Style preference. Improves debugging output.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_equatable_stringify',
    problemMessage: 'Equatable class does not override stringify to true.',
    correctionMessage:
        'Add: @override bool get stringify => true; for better debugging.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class already overrides stringify
      bool hasStringifyOverride = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'stringify' &&
            member.isGetter) {
          hasStringifyOverride = true;
          break;
        }
      }

      if (!hasStringifyOverride) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddStringifyOverrideFix()];
}

class _AddStringifyOverrideFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find props getter to insert after it
      MethodDeclaration? propsGetter;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          propsGetter = member;
          break;
        }
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add stringify override',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final int insertOffset = propsGetter?.end ?? node.rightBracket.offset;
        builder.addSimpleInsertion(
          insertOffset,
          '\n\n  @override\n  bool get stringify => true;',
        );
      });
    });
  }
}

/// Warns when an Equatable class is not annotated with @immutable.
///
/// Alias: require_immutable_annotation, immutable_equatable
///
/// Equatable classes should be immutable to ensure correct equality
/// behavior. The @immutable annotation documents this intent and enables
/// additional static analysis.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// @immutable
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
class PreferImmutableAnnotationRule extends SaropaLintRule {
  const PreferImmutableAnnotationRule() : super(code: _code);

  /// Style preference. Documents immutability intent.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_immutable_annotation',
    problemMessage: 'Equatable class is not annotated with @immutable.',
    correctionMessage:
        'Add @immutable annotation to document immutability intent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class has @immutable annotation
      bool hasImmutableAnnotation = false;
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'immutable') {
          hasImmutableAnnotation = true;
          break;
        }
      }

      if (!hasImmutableAnnotation) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddImmutableAnnotationFix()];
}

class _AddImmutableAnnotationFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add @immutable annotation',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert before class declaration or first annotation
        final int insertOffset =
            node.metadata.isNotEmpty ? node.metadata.first.offset : node.offset;
        builder.addSimpleInsertion(insertOffset, '@immutable\n');
      });
    });
  }
}

/// Warns when Freezed is used without explicit_to_json in build.yaml for nested objects.
///
/// Alias: freezed_explicit_json, require_explicit_to_json
///
/// When using Freezed with nested objects, explicit_to_json: true is required
/// in build.yaml to ensure proper JSON serialization of nested objects.
/// Without it, nested objects may not serialize correctly.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     required Address address, // Nested object - needs explicit_to_json
///   }) = _User;
/// }
/// ```
///
/// #### GOOD:
/// Configure in build.yaml:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       json_serializable:
///         options:
///           explicit_to_json: true
/// ```
class RequireFreezedExplicitJsonRule extends SaropaLintRule {
  const RequireFreezedExplicitJsonRule() : super(code: _code);

  /// Potential bug. Nested objects may not serialize correctly.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_explicit_json',
    problemMessage:
        'Freezed class with nested objects may need explicit_to_json in build.yaml.',
    correctionMessage:
        'Add explicit_to_json: true to build.yaml under json_serializable options.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has @freezed annotation
      if (!_hasFreezedAnnotation(node)) return;

      // Check if class has nested objects (non-primitive types)
      if (!_hasNestedObjects(node)) return;

      // If we get here, the class has nested objects
      reporter.atNode(node, code);
    });
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String annotationName = annotation.name.name;
      if (annotationName == 'freezed' || annotationName == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _hasNestedObjects(ClassDeclaration node) {
    // Check factory constructors for complex type parameters
    for (final ClassMember member in node.members) {
      if (member is ConstructorDeclaration && member.factoryKeyword != null) {
        for (final FormalParameter param in member.parameters.parameters) {
          if (_isComplexType(param)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _isComplexType(FormalParameter param) {
    TypeAnnotation? type;

    if (param is SimpleFormalParameter) {
      type = param.type;
    } else if (param is DefaultFormalParameter) {
      final FormalParameter innerParam = param.parameter;
      if (innerParam is SimpleFormalParameter) {
        type = innerParam.type;
      }
    }

    if (type is NamedType) {
      final String typeName = type.name2.lexeme;
      // Skip primitive types, common Flutter/Dart types, and collections
      const Set<String> primitiveTypes = <String>{
        'String',
        'int',
        'double',
        'bool',
        'num',
        'dynamic',
        'Object',
        'void',
        'DateTime',
        'Duration',
        'Uri',
        'BigInt',
        'List',
        'Map',
        'Set',
        'Iterable',
      };
      if (!primitiveTypes.contains(typeName)) {
        // Check if it's a type argument of a collection
        final TypeArgumentList? typeArgs = type.typeArguments;
        if (typeArgs == null) {
          return true; // Non-primitive, non-collection type
        }
      }

      // Check type arguments for nested complex types
      final TypeArgumentList? typeArgs = type.typeArguments;
      if (typeArgs != null) {
        for (final TypeAnnotation arg in typeArgs.arguments) {
          if (arg is NamedType) {
            final String argTypeName = arg.name2.lexeme;
            const Set<String> primitiveTypes = <String>{
              'String',
              'int',
              'double',
              'bool',
              'num',
              'dynamic',
              'Object',
            };
            if (!primitiveTypes.contains(argTypeName)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }
}

/// Warns when Freezed nullable fields could use @Default annotation instead.
///
/// Alias: freezed_default_annotation, prefer_freezed_defaults
///
/// Using @Default annotation instead of nullable types provides clearer
/// intent and better code when the field should have a default value
/// rather than being truly optional.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     int? count, // Should this be nullable or have a default?
///     List<String>? items, // Empty list might be better default
///   }) = _User;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({
///     required String name,
///     @Default(0) int count, // Clear default value
///     @Default([]) List<String> items, // Empty list as default
///   }) = _User;
/// }
/// ```
class PreferFreezedDefaultValuesRule extends SaropaLintRule {
  const PreferFreezedDefaultValuesRule() : super(code: _code);

  /// Style preference. Clearer intent for optional fields.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_freezed_default_values',
    problemMessage:
        'Freezed nullable field could use @Default annotation instead.',
    correctionMessage:
        'Consider using @Default(value) instead of nullable type if field has a sensible default.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has @freezed annotation
      if (!_hasFreezedAnnotation(node)) return;

      // Check factory constructors for nullable parameters without @Default
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.factoryKeyword != null) {
          for (final FormalParameter param in member.parameters.parameters) {
            if (_isNullableWithoutDefault(param)) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }

  bool _hasFreezedAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String annotationName = annotation.name.name;
      if (annotationName == 'freezed' || annotationName == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _isNullableWithoutDefault(FormalParameter param) {
    // Handle DefaultFormalParameter (optional parameters)
    FormalParameter actualParam = param;
    if (param is DefaultFormalParameter) {
      actualParam = param.parameter;
    }

    // Check if parameter has @Default annotation
    final NodeList<Annotation>? metadata =
        actualParam is NormalFormalParameter ? actualParam.metadata : null;
    if (metadata != null) {
      for (final Annotation annotation in metadata) {
        if (annotation.name.name == 'Default') {
          return false; // Already has @Default
        }
      }
    }

    // Check if type is nullable
    if (actualParam is SimpleFormalParameter) {
      final TypeAnnotation? type = actualParam.type;
      if (type is NamedType) {
        // Check for ? suffix indicating nullable
        if (type.question != null) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Warns when a simple Equatable class could be replaced with a Dart 3 record.
///
/// Alias: use_record_instead_of_equatable, equatable_to_record
///
/// Simple data classes that only hold values and use Equatable for
/// equality can often be replaced with Dart 3 records for cleaner code.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Point extends Equatable {
///   final int x;
///   final int y;
///
///   const Point(this.x, this.y);
///
///   @override
///   List<Object?> get props => [x, y];
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// typedef Point = ({int x, int y});
/// // Or use inline:
/// final point = (x: 10, y: 20);
/// ```
class PreferRecordOverEquatableRule extends SaropaLintRule {
  const PreferRecordOverEquatableRule() : super(code: _code);

  /// Style preference. Records are more concise.
  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_record_over_equatable',
    problemMessage:
        'Simple Equatable class could be replaced with a Dart 3 record.',
    correctionMessage:
        'Consider using a record type: typedef ClassName = ({Type field, ...});',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxFieldsForRecord = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class is a simple data class suitable for record
      if (_isSimpleDataClass(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isSimpleDataClass(ClassDeclaration node) {
    // Count fields
    int fieldCount = 0;
    bool hasOnlyFinalFields = true;

    for (final ClassMember member in node.members) {
      if (member is FieldDeclaration) {
        if (member.isStatic) continue;

        // Check if fields are final
        if (!member.fields.isFinal) {
          hasOnlyFinalFields = false;
        }

        fieldCount += member.fields.variables.length;
      }
    }

    // Too few or too many fields
    if (fieldCount == 0 || fieldCount > _maxFieldsForRecord) {
      return false;
    }

    // Has non-final fields (not suitable for immutable record)
    if (!hasOnlyFinalFields) {
      return false;
    }

    // Check for methods other than props, stringify, and constructors
    bool hasComplexMethods = false;
    for (final ClassMember member in node.members) {
      if (member is MethodDeclaration) {
        final String methodName = member.name.lexeme;
        // Allow props, stringify, toString, hashCode, == (inherited from Equatable)
        if (methodName != 'props' &&
            methodName != 'stringify' &&
            methodName != 'toString' &&
            methodName != 'hashCode' &&
            methodName != '==') {
          hasComplexMethods = true;
          break;
        }
      }
    }

    // If it has complex methods, it's not a simple data class
    if (hasComplexMethods) {
      return false;
    }

    return true;
  }
}

/// Warns when Equatable class has non-final (mutable) fields.
///
/// Alias: no_mutable_equatable_field, equatable_final_fields
///
/// All fields in Equatable classes should be final to ensure correct
/// equality behavior. Mutable fields can change after comparison,
/// leading to bugs where equal objects become unequal.
///
/// **BAD:**
/// ```dart
/// class Person extends Equatable {
///   String name; // Non-final field - can change after comparison!
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
class AvoidMutableFieldInEquatableRule extends SaropaLintRule {
  const AvoidMutableFieldInEquatableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_mutable_field_in_equatable',
    problemMessage:
        'Equatable class has non-final field. Equality may change unexpectedly.',
    correctionMessage:
        'Make all fields final. Use copyWith pattern for updates.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Find non-final instance fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          // Check if fields are final
          if (!member.fields.isFinal && !member.fields.isConst) {
            // Report each non-final field
            for (final VariableDeclaration variable
                in member.fields.variables) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Equatable class doesn't have a copyWith method.
///
/// Alias: copy_with_for_equatable, add_copy_with
///
/// Equatable classes are typically immutable. A copyWith method makes it
/// easy to create modified copies without mutating the original.
///
/// **BAD:**
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///
///   Person copyWith({String? name, int? age}) {
///     return Person(name: name ?? this.name, age: age ?? this.age);
///   }
///
///   @override
///   List<Object?> get props => [name, age];
/// }
/// ```
class RequireEquatableCopyWithRule extends SaropaLintRule {
  const RequireEquatableCopyWithRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_equatable_copy_with',
    problemMessage: 'Equatable class should have a copyWith method.',
    correctionMessage: 'Add copyWith method to easily create modified copies.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class has copyWith method
      bool hasCopyWith = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'copyWith') {
          hasCopyWith = true;
          break;
        }
      }

      if (!hasCopyWith) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when copyWith methods can't set nullable fields to null.
///
/// Alias: copy_with_nullable, nullable_copy_with
///
/// Standard copyWith pattern can't distinguish between "not provided" and
/// "explicitly null". Use a sentinel value or wrapper class to support
/// setting nullable fields back to null.
///
/// **BAD:**
/// ```dart
/// User copyWith({String? name}) {
///   return User(name: name ?? this.name); // Can't set name to null!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// User copyWith({Optional<String>? name}) {
///   return User(name: name != null ? name.value : this.name);
/// }
/// // Or using freezed with @Default
/// ```
class RequireCopyWithNullHandlingRule extends SaropaLintRule {
  const RequireCopyWithNullHandlingRule() : super(code: _code);

  /// copyWith that can't set null makes state management difficult.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_copy_with_null_handling',
    problemMessage:
        'copyWith with ?? operator cannot set nullable fields to null.',
    correctionMessage:
        'Use a wrapper type like Optional<T> or generated copyWith from freezed.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'copyWith') return;

      // Check method body for ?? operator on nullable parameters
      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) {
        return;
      }

      // Get nullable parameters
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      final Set<String> nullableParams = <String>{};
      for (final FormalParameter param in params.parameters) {
        String? paramName;
        String? typeSource;

        if (param is DefaultFormalParameter) {
          final NormalFormalParameter inner = param.parameter;
          if (inner is SimpleFormalParameter) {
            paramName = inner.name?.lexeme;
            typeSource = inner.type?.toSource();
          }
        } else if (param is SimpleFormalParameter) {
          paramName = param.name?.lexeme;
          typeSource = param.type?.toSource();
        }

        // Check if type is nullable (ends with ?)
        if (paramName != null &&
            typeSource != null &&
            typeSource.endsWith('?')) {
          nullableParams.add(paramName);
        }
      }

      if (nullableParams.isEmpty) return;

      // Check if body uses ?? with nullable params
      final String bodySource = body.toSource();
      for (final String paramName in nullableParams) {
        // Pattern: paramName ?? this.paramName
        if (bodySource.contains('$paramName ??') ||
            bodySource.contains('$paramName??')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// require_deep_equality_collections
// =============================================================================

/// Collection fields in Equatable need DeepCollectionEquality.
///
/// List/Map/Set fields compared by reference, not contents.
/// Use DeepCollectionEquality for proper comparison.
///
/// **BAD:**
/// ```dart
/// class MyState extends Equatable {
///   final List<Item> items;
///   @override
///   List<Object?> get props => [items];  // Compares by reference!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyState extends Equatable {
///   final List<Item> items;
///   @override
///   List<Object?> get props => [DeepCollectionEquality().hash(items)];
/// }
/// ```
class RequireDeepEqualityCollectionsRule extends SaropaLintRule {
  const RequireDeepEqualityCollectionsRule() : super(code: _code);

  /// State comparison bugs from reference equality.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_deep_equality_collections',
    problemMessage:
        'Collection in Equatable props compared by reference, not contents.',
    correctionMessage:
        'Use DeepCollectionEquality().hash(collection) or wrap in unmodifiable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Equatable') return;

      // Find collection fields
      final Set<String> collectionFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field
              in member.fields.variables) {
            final String? typeSource = member.fields.type?.toSource();
            if (typeSource != null &&
                (typeSource.startsWith('List') ||
                    typeSource.startsWith('Set') ||
                    typeSource.startsWith('Map') ||
                    typeSource.startsWith('Iterable'))) {
              final String? fieldName = field.name.lexeme;
              if (fieldName != null) {
                collectionFields.add(fieldName);
              }
            }
          }
        }
      }

      if (collectionFields.isEmpty) return;

      // Find props getter
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          final String propsSource = member.toSource();

          // Check if collections are used without DeepCollectionEquality
          for (final String fieldName in collectionFields) {
            if (propsSource.contains(fieldName) &&
                !propsSource.contains('DeepCollectionEquality') &&
                !propsSource.contains('ListEquality') &&
                !propsSource.contains('SetEquality') &&
                !propsSource.contains('MapEquality')) {
              reporter.atNode(member, code);
              return;
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_equatable_datetime
// =============================================================================

/// DateTime equality is problematic due to microsecond precision.
///
/// DateTime comparisons can fail due to microsecond differences.
/// Compare truncated or formatted values instead.
///
/// **BAD:**
/// ```dart
/// class Event extends Equatable {
///   final DateTime timestamp;
///   @override
///   List<Object?> get props => [timestamp];  // Microsecond differences!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// List<Object?> get props => [timestamp.millisecondsSinceEpoch];
/// ```
class AvoidEquatableDatetimeRule extends SaropaLintRule {
  const AvoidEquatableDatetimeRule() : super(code: _code);

  /// Flaky equality from microsecond precision.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_equatable_datetime',
    problemMessage:
        'DateTime in Equatable props may cause flaky equality checks.',
    correctionMessage:
        'Use timestamp.millisecondsSinceEpoch or toIso8601String() instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Equatable') return;

      // Find DateTime fields
      final Set<String> dateTimeFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeSource = member.fields.type?.toSource();
          if (typeSource != null && typeSource.contains('DateTime')) {
            for (final VariableDeclaration field
                in member.fields.variables) {
              final String? fieldName = field.name.lexeme;
              if (fieldName != null) {
                dateTimeFields.add(fieldName);
              }
            }
          }
        }
      }

      if (dateTimeFields.isEmpty) return;

      // Find props getter
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          final String propsSource = member.toSource();

          // Check if DateTime fields are used directly
          for (final String fieldName in dateTimeFields) {
            // Check for direct field reference without conversion
            if (propsSource.contains(fieldName) &&
                !propsSource.contains('$fieldName.millisecondsSinceEpoch') &&
                !propsSource.contains('$fieldName.toIso8601String') &&
                !propsSource.contains('$fieldName?.millisecondsSinceEpoch') &&
                !propsSource.contains('$fieldName?.toIso8601String')) {
              reporter.atNode(member, code);
              return;
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// prefer_unmodifiable_collections
// =============================================================================

/// Make collection fields unmodifiable to prevent mutation.
///
/// Mutable collections in state classes can be modified externally,
/// breaking immutability expectations.
///
/// **BAD:**
/// ```dart
/// class State {
///   final List<Item> items;
///   State(this.items);  // Can be mutated externally!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class State {
///   final List<Item> items;
///   State(List<Item> items) : items = List.unmodifiable(items);
/// }
/// ```
class PreferUnmodifiableCollectionsRule extends SaropaLintRule {
  const PreferUnmodifiableCollectionsRule() : super(code: _code);

  /// State mutation bugs from mutable collections.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_unmodifiable_collections',
    problemMessage:
        'Collection field may be mutated externally. Consider making unmodifiable.',
    correctionMessage:
        'Use List.unmodifiable(), Map.unmodifiable(), or UnmodifiableSetView().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a state/model class (extends Equatable or has immutable intent)
      final ExtendsClause? extendsClause = node.extendsClause;
      bool isImmutableClass = false;

      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'Equatable' ||
            superName.contains('State') ||
            superName.contains('Event')) {
          isImmutableClass = true;
        }
      }

      // Check for @immutable annotation
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'immutable') {
          isImmutableClass = true;
          break;
        }
      }

      if (!isImmutableClass) return;

      // Find collection fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isFinal) {
          final String? typeSource = member.fields.type?.toSource();
          if (typeSource != null &&
              (typeSource.startsWith('List') ||
                  typeSource.startsWith('Set') ||
                  typeSource.startsWith('Map'))) {
            // Check if constructor makes it unmodifiable
            bool madeUnmodifiable = false;

            for (final ClassMember constructor in node.members) {
              if (constructor is ConstructorDeclaration) {
                final String? initSource = constructor.initializers
                    .map((e) => e.toSource())
                    .join();
                if (initSource != null &&
                    (initSource.contains('List.unmodifiable') ||
                        initSource.contains('Map.unmodifiable') ||
                        initSource.contains('UnmodifiableSetView') ||
                        initSource.contains('List.of') ||
                        initSource.contains('.toList()') ||
                        initSource.contains('.toSet()') ||
                        initSource.contains('.toMap()'))) {
                  madeUnmodifiable = true;
                  break;
                }
              }
            }

            if (!madeUnmodifiable) {
              reporter.atNode(member, code);
            }
          }
        }
      }
    });
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
      if (!_isEquatable(node)) return;

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

  bool _isEquatable(ClassDeclaration node) {
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
      if (!_isEquatable(node)) return;

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

  bool _isEquatable(ClassDeclaration node) {
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
      if (!_isEquatable(node)) return;

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

  bool _isEquatable(ClassDeclaration node) {
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
      if (!_isEquatable(node)) return;

      // Check if class is a simple data class suitable for record
      if (_isSimpleDataClass(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isEquatable(ClassDeclaration node) {
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
      if (!_isEquatable(node)) return;

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

  bool _isEquatable(ClassDeclaration node) {
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
}

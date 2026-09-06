// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';
import '../../type_annotation_utils.dart';

// =============================================================================
// Shared Utilities
// =============================================================================

/// Checks if a class declaration extends Equatable or uses EquatableMixin.
bool isEquatable(ClassDeclaration node) {
  // Check extends Equatable
  final ExtendsClause? extendsClause = node.extendsClause;
  if (extendsClause != null) {
    final String superclassName = extendsClause.superclass.name.lexeme;
    if (superclassName == 'Equatable') return true;
  }

  // Check mixes in EquatableMixin
  final WithClause? withClause = node.withClause;
  if (withClause != null) {
    for (final NamedType mixin in withClause.mixinTypes) {
      if (mixin.name.lexeme == 'EquatableMixin') return true;
    }
  }

  return false;
}

// =============================================================================
// Equatable Rules
// =============================================================================

/// Warns when a class overrides operator == but doesn't extend Equatable.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v2
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
  ExtendEquatableRule() : super(code: _code);

  /// Maintainability issue. Cleaner equality pattern available.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  /// Alias: extend_equatable
  static const LintCode _code = LintCode(
    'require_extend_equatable',
    '[require_extend_equatable] Class overrides operator == but does not extend Equatable. Equatable provides consistent hashCode and equality implementations with less boilerplate and fewer opportunities for bugs. {v2}',
    correctionMessage:
        'Prefer extending Equatable for cleaner equality implementation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable
      if (_extendsEquatable(node)) return;

      // Check if class mixes in EquatableMixin
      if (_mixesInEquatable(node)) return;

      // Check if class overrides operator ==
      bool hasEqualsOverride = false;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.name.lexeme == '==' &&
            member.isOperator) {
          hasEqualsOverride = true;
          break;
        }
      }

      if (hasEqualsOverride) {
        reporter.atNode(node);
      }
    });
  }

  bool _extendsEquatable(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'Equatable';
  }

  bool _mixesInEquatable(ClassDeclaration node) {
    final WithClause? withClause = node.withClause;
    if (withClause == null) return false;

    for (final NamedType mixin in withClause.mixinTypes) {
      if (mixin.name.lexeme == 'EquatableMixin') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when an Equatable subclass has fields not listed in props.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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
  ListAllEquatableFieldsRule() : super(code: _code);

  /// Potential bug. Missing field in equality comparison.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'list_all_equatable_fields',
    '[list_all_equatable_fields] Equatable class has fields not included in props. Equality checks fail silently when these fields differ, causing inconsistent behavior in collections, comparisons, and UI updates. Two objects with different field values will be treated as equal, leading to missed rebuilds, incorrect deduplication, and subtle bugs that are extremely hard to trace. {v3}',
    correctionMessage:
        'Add all instance fields to the props getter for correct equality. Otherwise, objects may not compare as equal when expected, leading to subtle bugs.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Collect all instance fields
      final Set<String> instanceFields = <String>{};
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final VariableDeclaration variable in member.fields.variables) {
            instanceFields.add(variable.name.lexeme);
          }
        }
      }

      if (instanceFields.isEmpty) return;

      // Find props getter
      MethodDeclaration? propsGetter;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          propsGetter = member;
          break;
        }
      }

      if (propsGetter == null) {
        // No props getter at all - definitely missing fields
        reporter.atNode(node);
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
        reporter.atNode(propsGetter);
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
}

/// Warns when a class extends Equatable but could use EquatableMixin instead.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferEquatableMixinRule() : super(code: _code);

  /// Style preference. Consider mixin for flexibility.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  /// Alias: prefer_equatable_mixin_pattern
  static const LintCode _code = LintCode(
    'prefer_equatable_mixin',
    '[prefer_equatable_mixin] Use EquatableMixin instead of extending Equatable. Using EquatableMixin is preferred when: - The class already extends another class - You want to preserve the class hierarchy. {v2}',
    correctionMessage:
        'EquatableMixin allows you to extend other classes while keeping '
        'Equatable functionality. Change to: class X with EquatableMixin. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;

      // Only suggest for classes that directly extend Equatable
      if (superclassName != 'Equatable') return;

      // Check if class already uses any mixins - if so, mixin pattern
      // would be even more appropriate
      final WithClause? withClause = node.withClause;
      if (withClause != null && withClause.mixinTypes.isNotEmpty) {
        // Already using mixins, strongly suggest EquatableMixin
        reporter.atNode(extendsClause);
        return;
      }

      // For classes extending only Equatable with no mixins,
      // this is more of a suggestion for awareness
      // Report at INFO level
      reporter.atNode(extendsClause);
    });
  }
}

/// Warns when an Equatable class doesn't override stringify to true.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
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
  PreferEquatableStringifyRule() : super(code: _code);

  /// Style preference. Improves debugging output.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'prefer_equatable_stringify',
    '[prefer_equatable_stringify] Equatable class does not override stringify to true. Overriding stringify to true provides better debugging output by including field values in toString() instead of just the class name. {v2}',
    correctionMessage:
        'Add: @override bool get stringify => true; to improve debugging. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class already overrides stringify
      bool hasStringifyOverride = false;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'stringify' &&
            member.isGetter) {
          hasStringifyOverride = true;
          break;
        }
      }

      if (!hasStringifyOverride) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when an Equatable class is not annotated with @immutable.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
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
  PreferImmutableAnnotationRule() : super(code: _code);

  /// Style preference. Documents immutability intent.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'prefer_immutable_annotation',
    '[prefer_immutable_annotation] Equatable class is not annotated with @immutable. Equatable classes must be immutable to ensure correct equality behavior. The @immutable annotation documents this intent and enables additional static analysis. {v2}',
    correctionMessage:
        'Add @immutable annotation to document immutability intent. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a simple Equatable class could be replaced with a Dart 3 record.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v5
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
  PreferRecordOverEquatableRule() : super(code: _code);

  /// Style preference. Records are more concise.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  @override
  String get exampleBad =>
      'class Point extends Equatable {\n'
      '  final int x, y;\n'
      '  const Point(this.x, this.y);\n'
      '  @override List<Object?> get props => [x, y];\n'
      '}';

  @override
  String get exampleGood => 'typedef Point = ({int x, int y});';

  static const LintCode _code = LintCode(
    'prefer_record_over_equatable',
    '[prefer_record_over_equatable] Simple Equatable class with only final fields and no custom methods detected. Dart 3 records provide built-in equality and immutability with far less boilerplate. Replace with a typedef record. {v5}',
    correctionMessage:
        'Replace the Equatable subclass with a Dart 3 record: typedef ClassName = ({Type field, ...}); for less boilerplate.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _maxFieldsForRecord = 5;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class is a simple data class suitable for record
      if (_isSimpleDataClass(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isSimpleDataClass(ClassDeclaration node) {
    // Count fields
    int fieldCount = 0;
    bool hasOnlyFinalFields = true;

    for (final ClassMember member in node.bodyMembers) {
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
    for (final ClassMember member in node.bodyMembers) {
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
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v4
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
  AvoidMutableFieldInEquatableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'avoid_mutable_field_in_equatable',
    '[avoid_mutable_field_in_equatable] Equatable classes should only have final fields. Mutable fields break value equality, causing bugs in collections, state management, and UI updates. Changing a field after object creation makes == and hashCode unreliable. {v4}',
    correctionMessage:
        'Make all fields in Equatable classes final to ensure correct value equality and predictable behavior.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Find non-final instance fields
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration && !member.isStatic) {
          // Check if fields are final
          if (!member.fields.isFinal && !member.fields.isConst) {
            // Report each non-final field
            for (final VariableDeclaration variable
                in member.fields.variables) {
              reporter.atNode(variable);
            }
          }
        }
      }
    });
  }
}

/// Warns when Equatable class doesn't have a copyWith method.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
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
  RequireEquatableCopyWithRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'require_equatable_copy_with',
    '[require_equatable_copy_with] Equatable class lacks copyWith method. Without copyWith, creating modified copies requires manually constructing new instances with all fields, leading to verbose code and errors when fields are added or removed from the class. {v2}',
    correctionMessage:
        'Add a copyWith method that accepts optional named parameters for each field and returns a new instance. This enables concise immutable updates and maintains compatibility when the class structure evolves.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Equatable or mixes in EquatableMixin
      if (!isEquatable(node)) return;

      // Check if class has copyWith method
      bool hasCopyWith = false;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'copyWith') {
          hasCopyWith = true;
          break;
        }
      }

      if (!hasCopyWith) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when copyWith methods can't set nullable fields to null.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
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
  RequireCopyWithNullHandlingRule() : super(code: _code);

  /// copyWith that can't set null makes state management difficult.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'require_copy_with_null_handling',
    '[require_copy_with_null_handling] copyWith with ?? operator cannot set nullable fields to null. Standard copyWith pattern can\'t distinguish between "not provided" and "explicitly null". Use a sentinel value or wrapper class to support setting nullable fields back to null. {v2}',
    correctionMessage:
        'Use a wrapper type like Optional<T> or generated copyWith from freezed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        TypeAnnotation? paramType;

        if (param is DefaultFormalParameter) {
          final NormalFormalParameter inner = param.parameter;
          if (inner is SimpleFormalParameter) {
            paramName = inner.name?.lexeme;
            paramType = inner.type;
          }
        } else if (param is SimpleFormalParameter) {
          paramName = param.name?.lexeme;
          paramType = param.type;
        }

        // Check if outer type is nullable via AST question token
        if (paramName != null &&
            paramType != null &&
            isOuterTypeNullable(paramType)) {
          nullableParams.add(paramName);
        }
      }

      if (nullableParams.isEmpty) return;

      // Check if body uses ?? with nullable params (word-boundary to avoid FPs)
      final String bodySource = body.toSource();
      final Set<String> flaggedParams = <String>{};
      for (final String paramName in nullableParams) {
        final pattern = RegExp(r'\b' + RegExp.escape(paramName) + r'\s*\?\?');
        if (pattern.hasMatch(bodySource)) {
          flaggedParams.add(paramName);
        }
      }
      if (flaggedParams.isEmpty) return;

      // The rule only matters when the underlying class FIELD is nullable --
      // that's the only case where `??` actually loses the ability to set
      // null. A non-nullable field (e.g. `bool showDetails`) can never be set
      // to null in the first place, so `paramName ?? this.paramName` is the
      // correct, complete pattern and the sentinel/wrapper suggestion is a
      // false positive. See
      // plans/history/2026.09/2026.09.05/require_copy_with_null_handling_false_positive_non_nullable_fields.md.
      final Set<String> nullableFieldNames = _collectNullableFieldNames(node);
      final bool anyFlaggedFieldIsNullable = flaggedParams.any(
        nullableFieldNames.contains,
      );
      if (!anyFlaggedFieldIsNullable) return;

      reporter.atNode(node);
    });
  }

  /// Walks up from the `copyWith` method to its enclosing class and collects
  /// the names of instance fields declared with a nullable type.
  ///
  /// Used to distinguish "?? loses the ability to null out a nullable field"
  /// (a real bug) from "?? on a non-nullable field" (correct and harmless --
  /// the field could never be null anyway, so there's nothing to lose).
  ///
  /// Known limitations of matching by NAME rather than by resolved element
  /// (accepted trade-off -- correct for the common case, not worth the
  /// complexity of full type resolution for a heuristic rule):
  /// - Inherited fields (declared on a superclass, not this class) are
  ///   invisible here, so a `??` on an inherited nullable field is missed.
  /// - A `copyWith` parameter renamed relative to its field (e.g.
  ///   `copyWith({String? newName})` backing a `name` field) won't match.
  /// - `static` fields are skipped by the `FieldDeclaration` check already
  ///   (copyWith never legitimately assigns from a static field via `this.`),
  ///   but a same-named static and instance field could theoretically
  ///   collide in the name set.
  /// - A field typed via a `typedef` that expands to a nullable type is not
  ///   detected, since `isOuterTypeNullable` only reads the AST's `?` token.
  Set<String> _collectNullableFieldNames(MethodDeclaration node) {
    // copyWith is always a member of a class body; walk up to find it.
    final ClassDeclaration? enclosingClass = node
        .thisOrAncestorOfType<ClassDeclaration>();
    if (enclosingClass == null) return const <String>{};

    final Set<String> nullableFieldNames = <String>{};
    // Use the `bodyMembers` compat shim (analyzer_compat.dart) instead of
    // `.body.members` directly -- the raw member-access path has moved
    // between analyzer versions (v9 exposes `.members` on the declaration
    // itself, v12 moved it onto `.body`), and this rule must keep working
    // across the pinned analyzer range without another version-fragility
    // bug like the one that broke this code the first time it was written.
    for (final ClassMember member in enclosingClass.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      final TypeAnnotation? fieldType = member.fields.type;
      // A field with no explicit type annotation (inferred, e.g. `var x = 1`)
      // can't be proven nullable from the AST alone -- skip it rather than
      // risk a false positive from assuming it's nullable.
      if (fieldType == null || !isOuterTypeNullable(fieldType)) continue;

      for (final VariableDeclaration variable in member.fields.variables) {
        nullableFieldNames.add(variable.name.lexeme);
      }
    }
    return nullableFieldNames;
  }
}

// =============================================================================
// require_deep_equality_collections
// =============================================================================

/// Collection fields in Equatable need DeepCollectionEquality.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireDeepEqualityCollectionsRule() : super(code: _code);

  /// State comparison bugs from reference equality.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'require_deep_equality_collections',
    '[require_deep_equality_collections] Collections (List, Map, Set) in Equatable props are compared by reference, not by contents. This causes false negatives in equality checks, leading to subtle bugs, missed UI updates, broken state management, and wasted rebuilds. In production, this can result in persistent UI glitches, incorrect state restoration, and hard-to-diagnose logic errors. Collections with identical contents but different references will not compare as equal, undermining the reliability of Equatable-based state classes. {v3}',
    correctionMessage:
        'Use DeepCollectionEquality().equals() and .hash() for collections, or wrap collections in unmodifiable views. Always document equality logic for collection fields, and add tests to verify correct behavior. This ensures reliable state comparison and prevents UI bugs and wasted rebuilds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Equatable') return;

      // Find collection fields
      final Set<String> collectionFields = <String>{};
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final String? typeSource = member.fields.type?.toSource();
            if (typeSource != null &&
                (typeSource.startsWith('List') ||
                    typeSource.startsWith('Set') ||
                    typeSource.startsWith('Map') ||
                    typeSource.startsWith('Iterable'))) {
              final String fieldName = field.name.lexeme;
              collectionFields.add(fieldName);
            }
          }
        }
      }

      if (collectionFields.isEmpty) return;

      // Find props getter
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          final String propsSource = member.toSource();

          // Check if collections are used without DeepCollectionEquality
          final hasEqualityHelper = RegExp(
            r'\b(DeepCollectionEquality|ListEquality|SetEquality|MapEquality)\b',
          ).hasMatch(propsSource);
          for (final String fieldName in collectionFields) {
            if (RegExp(
                  r'\b' + RegExp.escape(fieldName) + r'\b',
                ).hasMatch(propsSource) &&
                !hasEqualityHelper) {
              reporter.atNode(member);
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
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidEquatableDatetimeRule() : super(code: _code);

  /// Flaky equality from microsecond precision.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'avoid_equatable_datetime',
    '[avoid_equatable_datetime] DateTime in Equatable props may cause flaky equality checks. DateTime comparisons can fail due to microsecond differences. Compare truncated or formatted values instead. {v2}',
    correctionMessage:
        'Use timestamp.millisecondsSinceEpoch or toIso8601String() instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Equatable') return;

      // Find DateTime fields
      final Set<String> dateTimeFields = <String>{};
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final String? typeSource = member.fields.type?.toSource();
          if (typeSource != null &&
              RegExp(r'\bDateTime\b').hasMatch(typeSource)) {
            for (final VariableDeclaration field in member.fields.variables) {
              final String fieldName = field.name.lexeme;
              dateTimeFields.add(fieldName);
            }
          }
        }
      }

      if (dateTimeFields.isEmpty) return;

      // Find props getter
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'props' &&
            member.isGetter) {
          final String propsSource = member.toSource();

          // Check if DateTime fields are used directly (word-boundary)
          for (final String fieldName in dateTimeFields) {
            final fieldRef = RegExp(r'\b' + RegExp.escape(fieldName) + r'\b');
            final withEpoch = RegExp(
              r'\b' +
                  RegExp.escape(fieldName) +
                  r'\s*[?.]\s*(millisecondsSinceEpoch|toIso8601String)\b',
            );
            if (fieldRef.hasMatch(propsSource) &&
                !withEpoch.hasMatch(propsSource)) {
              reporter.atNode(member);
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
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v3
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
  PreferUnmodifiableCollectionsRule() : super(code: _code);

  /// State mutation bugs from mutable collections.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'prefer_unmodifiable_collections',
    '[prefer_unmodifiable_collections] Equatable class exposes mutable collection field. External code can modify the collection contents without creating a new instance, breaking Equatable\'s equality contract and causing inconsistent state where equal objects have different contents. {v3}',
    correctionMessage:
        'Wrap the collection in List.unmodifiable(), Map.unmodifiable(), or UnmodifiableSetView() to prevent external modifications. This enforces immutability and preserves Equatable semantics while still allowing read access.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final unmodifiablePattern = RegExp(
      r'\b(List\.unmodifiable|Map\.unmodifiable|UnmodifiableSetView|List\.of)\b'
      r'|\.(toList|toSet|toMap)\s*\(\)',
    );
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a state/model class (extends Equatable or has immutable intent)
      final ExtendsClause? extendsClause = node.extendsClause;
      bool isImmutableClass = false;

      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'Equatable' ||
            superName.endsWith('State') ||
            superName.endsWith('Event')) {
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
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration && member.fields.isFinal) {
          final String? typeSource = member.fields.type?.toSource();
          if (typeSource != null &&
              (typeSource.startsWith('List') ||
                  typeSource.startsWith('Set') ||
                  typeSource.startsWith('Map'))) {
            // Check if constructor makes it unmodifiable
            bool madeUnmodifiable = false;

            for (final ClassMember constructor in node.bodyMembers) {
              if (constructor is ConstructorDeclaration) {
                final String initSource = constructor.initializers
                    .map((e) => e.toSource())
                    .join();
                if (unmodifiablePattern.hasMatch(initSource)) {
                  madeUnmodifiable = true;
                  break;
                }
              }
            }

            if (!madeUnmodifiable) {
              reporter.atNode(member);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// Rules moved from state_management_rules.dart
// =============================================================================

/// Warns when Equatable class doesn't override props.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Alias: equatable_missing_props, props_override_required
///
/// Equatable requires props getter to define which fields affect equality.
///
/// **BAD:**
/// ```dart
/// class User extends Equatable {
///   final String name;
///   // Missing props!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class User extends Equatable {
///   final String name;
///   @override
///   List<Object?> get props => [name];
/// }
/// ```
class RequireEquatablePropsOverrideRule extends SaropaLintRule {
  RequireEquatablePropsOverrideRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'require_equatable_props_override',
    '[require_equatable_props_override] Without props override, equality '
        'defaults to identity comparison, breaking state deduplication. {v1}',
    correctionMessage: 'Add: List<Object?> get props => [field1, field2];',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'Equatable') return;

      // Check for props getter
      bool hasProps = false;
      for (final member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.isGetter &&
            member.name.lexeme == 'props') {
          hasProps = true;
          break;
        }
      }

      if (!hasProps) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when an Equatable class includes mutable collections in `props`.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Equatable performs shallow `==` on each prop. Mutable `List`, `Map`, or
/// `Set` values may change after construction, making equality checks
/// non-deterministic and hash codes unstable.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class UserState extends Equatable {
///   final List<String> tags;
///   @override
///   List<Object?> get props => [tags]; // ← mutable list in props
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class UserState extends Equatable {
///   final List<String> tags;
///   @override
///   List<Object?> get props => [List.unmodifiable(tags)];
/// }
/// ```
class AvoidEquatableNestedEqualityRule extends SaropaLintRule {
  AvoidEquatableNestedEqualityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'Equatable'};

  static const LintCode _code = LintCode(
    'avoid_equatable_nested_equality',
    '[avoid_equatable_nested_equality] Including a mutable collection (List, '
        'Map, or Set) directly in Equatable props can cause non-deterministic '
        'equality checks and unstable hash codes. Equatable performs shallow '
        'comparison, so if the collection mutates after construction, two '
        '"equal" instances may later compare as different. Wrap collections '
        'with List.unmodifiable or use immutable types. {v1}',
    correctionMessage:
        'Wrap the collection with List.unmodifiable(), Map.unmodifiable(), '
        'or use an immutable collection type in props.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (!node.isGetter || node.name.lexeme != 'props') return;

      // Must be inside an Equatable class
      final ClassDeclaration? cls = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (cls == null) return;

      if (!isEquatable(cls)) return;

      // Analyze props return expression
      final FunctionBody body = node.body;
      ListLiteral? propsList;

      if (body is ExpressionFunctionBody) {
        final Expression expr = body.expression;
        if (expr is ListLiteral) propsList = expr;
      } else if (body is BlockFunctionBody) {
        for (final Statement stmt in body.block.statements) {
          if (stmt is ReturnStatement) {
            final expr = stmt.expression;
            if (expr is ListLiteral) {
              propsList = expr;
              break;
            }
          }
        }
      }

      if (propsList == null) return;

      for (final CollectionElement element in propsList.elements) {
        if (element is! Expression) continue;
        final DartType? type = element.staticType;
        if (type == null) continue;

        if (type.isDartCoreList || type.isDartCoreMap || type.isDartCoreSet) {
          reporter.atNode(element);
        }
      }
    });
  }
}

// =============================================================================
// prefer_sorted_equatable_props
// =============================================================================

/// Warns when `props` lists fields in a different order than they were
/// declared in the class body.
///
/// Since: v14.4.0 | Rule version: v1
///
/// `props` order has no effect on equality or hashing — `Equatable`
/// compares element-by-element position-independently of the source field
/// layout, so a reordered list is never a functional bug. It is, however, a
/// maintenance hazard: a reviewer skimming the field declarations naturally
/// expects `props` to mirror that order, and a `props` list that silently
/// drifts out of sync makes it much easier to miss a genuinely *missing*
/// field (see `list_all_equatable_fields`) because the reviewer can no
/// longer just diff the two lists positionally.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///   final String email;
///   const Person(this.name, this.age, this.email);
///   @override
///   List<Object?> get props => [age, name, email]; // out of order
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class Person extends Equatable {
///   final String name;
///   final int age;
///   final String email;
///   const Person(this.name, this.age, this.email);
///   @override
///   List<Object?> get props => [name, age, email]; // matches declaration order
/// }
/// ```
class PreferSortedEquatablePropsRule extends SaropaLintRule {
  PreferSortedEquatablePropsRule() : super(code: _code);

  /// Readability-only concern: props order never affects equality/hashCode.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Cheap pre-filter: skip parsing files that can't possibly declare an
  // Equatable subclass at all.
  @override
  Set<String>? get requiredPatterns => const <String>{'Equatable'};

  static const LintCode _code = LintCode(
    'prefer_sorted_equatable_props',
    '[prefer_sorted_equatable_props] The props getter of this Equatable '
        'subclass lists fields in a different order than they were '
        'declared in the class body. Equatable compares props '
        'element-by-element, so the order has no effect on equality or '
        'hashCode correctness — but a props list that has drifted out of '
        'sync with the field declaration order is a maintenance hazard: '
        'reviewers naturally expect to diff the two lists positionally to '
        'confirm every field is covered, and a silently reordered list '
        'makes it far easier to overlook a field that is missing entirely, '
        'or to introduce a copy-paste mistake the next time a field is '
        'added. Keeping props in declaration order keeps the getter '
        'self-documenting and trivial to audit at a glance. {v1}',
    correctionMessage:
        'Reorder the props list so its fields appear in the same order as '
        'the corresponding field declarations in the class body.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Only Equatable/EquatableMixin classes carry a meaningful `props`.
      if (!isEquatable(node)) return;

      // Field declaration order, as written in the class body. Static
      // fields are excluded since they can never appear in an instance
      // props list.
      final List<String> declaredOrder = <String>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration && !member.isStatic) {
          for (final VariableDeclaration variable in member.fields.variables) {
            declaredOrder.add(variable.name.lexeme);
          }
        }
      }
      if (declaredOrder.isEmpty) return;

      // Locate the props getter; nothing to compare without one (the
      // missing-getter case is already covered by
      // require_equatable_props_override / list_all_equatable_fields).
      MethodDeclaration? propsGetter;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration &&
            member.isGetter &&
            member.name.lexeme == 'props') {
          propsGetter = member;
          break;
        }
      }
      if (propsGetter == null) return;

      // Extract the props list literal, from either an arrow body or a
      // single return statement inside a block body.
      final ListLiteral? propsList = _extractPropsListLiteral(propsGetter.body);
      if (propsList == null) return;

      // Only plain identifiers count as "a field reference" for ordering
      // purposes — anything else (a method call, `DeepCollectionEquality`
      // wrapper, literal) can't be matched back to a declared field name
      // and is skipped rather than guessed at.
      final List<String> propsOrder = <String>[];
      for (final CollectionElement element in propsList.elements) {
        if (element is SimpleIdentifier) {
          propsOrder.add(element.name);
        } else if (element is PropertyAccess &&
            element.target is ThisExpression) {
          propsOrder.add(element.propertyName.name);
        }
      }

      // Compare only the names that appear in BOTH lists — a field missing
      // from props (or an extra props entry with no matching field) is a
      // different, already-covered concern, not an ordering one.
      final Set<String> declaredSet = declaredOrder.toSet();
      final List<String> filteredDeclaredOrder = declaredOrder
          .where(propsOrder.toSet().contains)
          .toList();
      final List<String> filteredPropsOrder = propsOrder
          .where(declaredSet.contains)
          .toList();

      // Fewer than two shared fields means there is no possible ordering
      // to violate.
      if (filteredDeclaredOrder.length < 2) return;

      if (!_sameOrder(filteredDeclaredOrder, filteredPropsOrder)) {
        reporter.atNode(propsList);
      }
    });
  }

  /// Pulls the returned list literal out of an expression-bodied or
  /// block-bodied getter. Returns null for any other shape (e.g. a getter
  /// that computes props via a helper call rather than a literal).
  ListLiteral? _extractPropsListLiteral(FunctionBody body) {
    if (body is ExpressionFunctionBody) {
      final Expression expr = body.expression;
      return expr is ListLiteral ? expr : null;
    }
    if (body is BlockFunctionBody) {
      for (final Statement statement in body.block.statements) {
        if (statement is ReturnStatement) {
          final Expression? expr = statement.expression;
          if (expr is ListLiteral) return expr;
        }
      }
    }
    return null;
  }

  /// True when [a] and [b] are the same length and equal element-by-element
  /// (i.e. identical order, not just identical membership).
  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

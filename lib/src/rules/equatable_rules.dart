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
          '// TODO: Ensure all instance fields are included in props\n  ',
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

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when exception classes have non-final fields.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNonFinalExceptionClassFieldsRule extends SaropaLintRule {
  const AvoidNonFinalExceptionClassFieldsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_non_final_exception_class_fields',
    problemMessage: '[avoid_non_final_exception_class_fields] Mutable exception fields '
        'allow modification after throw, corrupting error data for handlers.',
    correctionMessage: 'Make all fields final in exception classes.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this class extends Exception or Error
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Exception' &&
          superName != 'Error' &&
          !superName.endsWith('Exception') &&
          !superName.endsWith('Error')) {
        return;
      }

      // Check all field declarations
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          if (member.isStatic) continue;
          if (member.fields.isFinal || member.fields.isConst) continue;

          for (final VariableDeclaration variable in member.fields.variables) {
            reporter.atToken(variable.name, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForNonFinalExceptionFieldFix()];
}

/// Warns when a catch clause only contains a rethrow.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   doSomething();
/// } catch (e) {
///   rethrow;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Remove the try-catch entirely, or add meaningful handling
/// doSomething();
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidOnlyRethrowRule extends SaropaLintRule {
  const AvoidOnlyRethrowRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_only_rethrow',
    problemMessage: '[avoid_only_rethrow] Catch-rethrow with no handling is dead code that '
        'adds nesting and complexity without providing any value.',
    correctionMessage: 'Remove the try-catch or add meaningful error handling.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final Block body = node.body;
      if (body.statements.length == 1) {
        final Statement statement = body.statements.first;
        if (statement is ExpressionStatement && statement.expression is RethrowExpression) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForOnlyRethrowFix()];
}

/// Warns when throw is used inside a catch block, which loses the stack trace.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   something();
/// } catch (e) {
///   throw Exception('Failed');  // Loses original stack trace
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// try {
///   something();
/// } catch (e, stackTrace) {
///   throw Exception('Failed: $e');  // Or use Error.throwWithStackTrace
/// }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidThrowInCatchBlockRule extends SaropaLintRule {
  const AvoidThrowInCatchBlockRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_throw_in_catch_block',
    problemMessage:
        '[avoid_throw_in_catch_block] Throwing a new error in a catch block without preserving the original stack trace makes debugging much harder. This can hide the root cause of failures and lead to incomplete error logs, making it difficult to diagnose and fix issues.',
    correctionMessage:
        'Use rethrow to propagate the original error, or Error.throwWithStackTrace to preserve the stack trace when throwing a new error. Always document error handling logic for maintainability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      // Visit the catch body to find throw statements
      node.body.visitChildren(_ThrowVisitor(reporter, code));
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForThrowInCatchFix()];
}

class _ThrowVisitor extends RecursiveAstVisitor<void> {
  _ThrowVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitThrowExpression(ThrowExpression node) {
    reporter.atNode(node, code);
    super.visitThrowExpression(node);
  }
}

/// Warns when throwing an object that doesn't have a toString() override.
///
/// Objects without toString() will display unhelpful messages when thrown.
///
/// Example of **bad** code:
/// ```dart
/// class MyError {}
/// throw MyError();  // toString() returns "Instance of 'MyError'"
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyError {
///   final String message;
///   MyError(this.message);
///   @override
///   String toString() => 'MyError: $message';
/// }
/// throw MyError('Something went wrong');
/// ```
class AvoidThrowObjectsWithoutToStringRule extends SaropaLintRule {
  const AvoidThrowObjectsWithoutToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_throw_objects_without_tostring',
    problemMessage:
        '[avoid_throw_objects_without_tostring] Thrown objects should have a useful toString() method for error reporting and debugging. Throwing objects without a meaningful string representation makes error logs cryptic and hinders troubleshooting, especially in production.',
    correctionMessage:
        'Throw Exception or Error subclasses, or implement toString() on custom error objects. Ensure error messages are clear and actionable for maintainers and support teams.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Types that are known to have useful toString implementations
  static const Set<String> _knownGoodTypes = <String>{
    'Exception',
    'Error',
    'String',
    'FormatException',
    'ArgumentError',
    'StateError',
    'RangeError',
    'UnsupportedError',
    'UnimplementedError',
    'ConcurrentModificationError',
    'TypeError',
    'AssertionError',
    'NoSuchMethodError',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      final Expression expression = node.expression;
      final DartType? type = expression.staticType;

      if (type == null) return;

      // Check if it's a known good type
      final String typeName = type.getDisplayString();

      // Allow Exception and Error subtypes (they typically have good toString)
      if (_knownGoodTypes.any((String t) => typeName.contains(t))) {
        return;
      }

      // Allow String throws (rare but valid)
      if (type.isDartCoreString) return;

      // Check if the type has a custom toString
      if (type is InterfaceType) {
        final bool hasToString = type.element.methods.any(
          (MethodElement e) =>
              e.name == 'toString' && (e as Element).enclosingElement == type.element,
        );
        if (hasToString) return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when exception classes are private.
class PreferPublicExceptionClassesRule extends SaropaLintRule {
  const PreferPublicExceptionClassesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_public_exception_classes',
    problemMessage: '[prefer_public_exception_classes] Private exception classes cannot be '
        'caught by name outside this library, forcing generic catch blocks.',
    correctionMessage: 'Remove underscore prefix from exception class name.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (!className.startsWith('_')) return;

      // Check if this class extends Exception or Error
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName == 'Exception' ||
          superName == 'Error' ||
          superName.endsWith('Exception') ||
          superName.endsWith('Error')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

class _AddHackForNonFinalExceptionFieldFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for non-final field',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: make this field final\n  ',
        );
      });
    });
  }
}

class _AddHackForOnlyRethrowFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for pointless rethrow',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: remove try-catch or add error handling */ ',
        );
      });
    });
  }
}

class _AddHackForThrowInCatchFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for throw in catch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: use rethrow or Error.throwWithStackTrace */ ',
        );
      });
    });
  }
}

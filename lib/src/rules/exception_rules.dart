// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when exception classes have non-final fields.
class AvoidNonFinalExceptionClassFieldsRule extends DartLintRule {
  const AvoidNonFinalExceptionClassFieldsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_non_final_exception_class_fields',
    problemMessage: 'Exception class fields should be final.',
    correctionMessage: 'Make all fields final in exception classes.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this class extends Exception or Error
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name2.lexeme;
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
class AvoidOnlyRethrowRule extends DartLintRule {
  const AvoidOnlyRethrowRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_only_rethrow',
    problemMessage: 'Catch clause only contains rethrow.',
    correctionMessage: 'Remove the try-catch or add meaningful error handling.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
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
class AvoidThrowInCatchBlockRule extends DartLintRule {
  const AvoidThrowInCatchBlockRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_throw_in_catch_block',
    problemMessage: 'Throwing in catch block loses the original stack trace.',
    correctionMessage: 'Use rethrow or Error.throwWithStackTrace to preserve stack trace.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      // Visit the catch body to find throw statements
      node.body.visitChildren(_ThrowVisitor(reporter, code));
    });
  }
}

class _ThrowVisitor extends RecursiveAstVisitor<void> {
  _ThrowVisitor(this.reporter, this.code);

  final ErrorReporter reporter;
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
class AvoidThrowObjectsWithoutToStringRule extends DartLintRule {
  const AvoidThrowObjectsWithoutToStringRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_throw_objects_without_tostring',
    problemMessage: 'Thrown object may not have a useful toString() method.',
    correctionMessage: 'Consider throwing an Exception or Error subclass, or implement toString().',
    errorSeverity: ErrorSeverity.INFO,
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
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
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
          (MethodElement e) => e.name == 'toString' && e.enclosingElement3 == type.element,
        );
        if (hasToString) return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when exception classes are private.
class PreferPublicExceptionClassesRule extends DartLintRule {
  const PreferPublicExceptionClassesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_public_exception_classes',
    problemMessage: 'Exception classes should be public.',
    correctionMessage: 'Remove underscore prefix from exception class name.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (!className.startsWith('_')) return;

      // Check if this class extends Exception or Error
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name2.lexeme;
      if (superName == 'Exception' ||
          superName == 'Error' ||
          superName.endsWith('Exception') ||
          superName.endsWith('Error')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

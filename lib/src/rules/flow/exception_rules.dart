// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../fixes/exception/remove_leading_underscore_from_exception_class_fix.dart';
import '../../fixes/exception/remove_try_catch_only_rethrow_fix.dart';
import '../../fixes/exception/replace_throw_with_rethrow_fix.dart';
import '../../saropa_lint_rule.dart';

/// Warns when exception classes have non-final fields.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNonFinalExceptionClassFieldsRule extends SaropaLintRule {
  AvoidNonFinalExceptionClassFieldsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_non_final_exception_class_fields',
    '[avoid_non_final_exception_class_fields] Mutable exception fields '
        'allow modification after throw, corrupting error data for handlers. {v4}',
    correctionMessage: 'Make all fields final in exception classes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
      for (final ClassMember member in node.bodyMembers) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidOnlyRethrowRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_only_rethrow',
    '[avoid_only_rethrow] Catch-rethrow with no handling is dead code that '
        'adds nesting and complexity without providing any value. {v4}',
    correctionMessage: 'Remove the try-catch or add meaningful error handling.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final Block body = node.body;
      if (body.statements.length == 1) {
        final Statement statement = body.statements.first;
        if (statement is ExpressionStatement &&
            statement.expression is RethrowExpression) {
          reporter.atNode(node);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveTryCatchOnlyRethrowFix(context: context),
  ];
}

/// Warns when throw is used inside a catch block, which loses the stack trace.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
  AvoidThrowInCatchBlockRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_throw_in_catch_block',
    '[avoid_throw_in_catch_block] Throwing a new error in a catch block without preserving the original stack trace makes debugging much harder. This can hide the root cause of failures and lead to incomplete error logs, making it difficult to diagnose and fix issues. {v6}',
    correctionMessage:
        'Use rethrow to propagate the original error, or Error.throwWithStackTrace to preserve the stack trace when throwing a new error. Always document error handling logic for maintainability.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      // Visit the catch body to find throw statements
      node.body.visitChildren(_ThrowVisitor(reporter, code));
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceThrowWithRethrowFix(context: context),
  ];
}

class _ThrowVisitor extends RecursiveAstVisitor<void> {
  _ThrowVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitThrowExpression(ThrowExpression node) {
    reporter.atNode(node);
    super.visitThrowExpression(node);
  }
}

/// Warns when throwing an object that doesn't have a toString() override.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
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
  AvoidThrowObjectsWithoutToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_throw_objects_without_tostring',
    '[avoid_throw_objects_without_tostring] Thrown objects without a useful toString() method produce cryptic error logs that hinder troubleshooting. When caught in production, these errors display unhelpful messages like "Instance of MyClass" instead of actionable details, making it nearly impossible to diagnose root causes from crash reports. {v7}',
    correctionMessage:
        'Throw Exception or Error subclasses, or implement toString() on custom error objects. Ensure error messages are clear and actionable for maintainers and support teams.',
    severity: DiagnosticSeverity.INFO,
  );

  // Types that are known to have useful toString implementations (word-boundary)
  static final RegExp _knownGoodTypesRegex = RegExp(
    r'\b(Exception|Error|String|FormatException|ArgumentError|StateError|'
    r'RangeError|UnsupportedError|UnimplementedError|'
    r'ConcurrentModificationError|TypeError|AssertionError|NoSuchMethodError)\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      // `Error.throwWithStackTrace(obj, stack)` always returns Never, so the
      // throw operand's own static type is Never — useless for this rule. The
      // value actually thrown is the FIRST argument; inspect its type instead,
      // otherwise every such throw misfires regardless of whether `obj`'s class
      // declares a useful toString().
      final Expression expression = _resolveThrownExpression(node.expression);
      final DartType? type = expression.staticType;

      if (type == null) return;

      // Check if it's a known good type
      final String typeName = type.getDisplayString();

      // Allow Exception and Error subtypes (they typically have good toString)
      if (_knownGoodTypesRegex.hasMatch(typeName)) {
        return;
      }

      // Allow String throws (rare but valid)
      if (type.isDartCoreString) return;

      // Allow any thrown class that declares toString() anywhere in its
      // hierarchy other than Object (directly or inherited from a real
      // supertype) — those produce useful error messages.
      if (type is InterfaceType && _hasUsefulToString(type)) return;

      reporter.atNode(node);
    });
  }

  /// Returns the expression whose static type is the value actually thrown.
  ///
  /// For `Error.throwWithStackTrace(obj, stack)` the throw operand's static
  /// type is `Never`, so the genuine thrown value is the call's first argument.
  /// Returns [operand] unchanged for ordinary throws.
  static Expression _resolveThrownExpression(Expression operand) {
    if (operand is! MethodInvocation ||
        operand.methodName.name != 'throwWithStackTrace') {
      return operand;
    }

    // Confirm the target is dart:core's Error.throwWithStackTrace, not some
    // unrelated method that happens to share the name.
    final Element? invoked = operand.methodName.element;
    final Element? owner = invoked?.enclosingElement;
    final bool isCoreError = owner is InterfaceElement &&
        owner.name == 'Error' &&
        owner.library.name == 'dart.core';
    if (!isCoreError) return operand;

    // Nullable-safe: an empty argument list cannot identify a thrown value, so
    // fall back to the original operand (which resolves to Never and is skipped
    // by the null-type guard upstream rather than misfiring).
    final NodeList<Expression> args = operand.argumentList.arguments;
    return args.isEmpty ? operand : args.first;
  }

  /// True when [type] (or any non-Object supertype) declares `toString()`.
  ///
  /// A direct override and an inherited override from a real supertype both
  /// yield actionable error messages; only the default `Object.toString()`
  /// ("Instance of ...") is unhelpful.
  static bool _hasUsefulToString(InterfaceType type) {
    final Iterable<InterfaceType> hierarchy = <InterfaceType>[
      type,
      ...type.allSupertypes,
    ];
    for (final InterfaceType current in hierarchy) {
      if (current.isDartCoreObject) continue;
      final bool declaresToString = current.element.methods.any(
        (MethodElement e) => e.name == 'toString',
      );
      if (declaresToString) return true;
    }
    return false;
  }
}

/// Warns when exception classes are private.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
class PreferPublicExceptionClassesRule extends SaropaLintRule {
  PreferPublicExceptionClassesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_public_exception_classes',
    '[prefer_public_exception_classes] Private exception classes cannot be '
        'caught by name outside this library, forcing generic catch blocks. {v4}',
    correctionMessage: 'Remove underscore prefix from exception class name.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.nameToken.lexeme;
      if (!className.startsWith('_')) return;

      // Check if this class extends Exception or Error
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName == 'Exception' ||
          superName == 'Error' ||
          superName.endsWith('Exception') ||
          superName.endsWith('Error')) {
        reporter.atToken(node.nameToken, code);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveLeadingUnderscoreFromExceptionClassFix(context: context),
  ];
}

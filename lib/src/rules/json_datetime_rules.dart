// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// JSON and DateTime parsing rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when parsing JSON and dates
/// that can cause runtime crashes or data corruption.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when jsonDecode is used without try-catch.
///
/// jsonDecode throws FormatException on malformed JSON. Without
/// error handling, this crashes the app.
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body);
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final data = jsonDecode(response.body);
/// } on FormatException catch (e) {
///   // Handle malformed JSON
/// }
/// ```
class RequireJsonDecodeTryCatchRule extends SaropaLintRule {
  const RequireJsonDecodeTryCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_json_decode_try_catch',
    problemMessage: 'jsonDecode throws on malformed JSON. Wrap in try-catch.',
    correctionMessage: 'Add try-catch for FormatException around jsonDecode.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final String source = node.function.toSource();
      if (source != 'jsonDecode') return;

      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when DateTime.parse is used without try-catch or tryParse.
///
/// DateTime.parse throws FormatException on invalid date strings.
/// Use tryParse or wrap in try-catch for user-provided dates.
///
/// **BAD:**
/// ```dart
/// final date = DateTime.parse(userInput);
/// ```
///
/// **GOOD:**
/// ```dart
/// final date = DateTime.tryParse(userInput);
/// if (date == null) {
///   // Handle invalid date
/// }
///
/// // Or with try-catch:
/// try {
///   final date = DateTime.parse(userInput);
/// } on FormatException {
///   // Handle invalid date
/// }
/// ```
class AvoidDateTimeParseUnvalidatedRule extends SaropaLintRule {
  const AvoidDateTimeParseUnvalidatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_datetime_parse_unvalidated',
    problemMessage:
        'DateTime.parse throws on invalid input. Use tryParse or try-catch.',
    correctionMessage: 'Replace with DateTime.tryParse() or wrap in try-catch.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseTryParseFix()];
}

class _UseTryParseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      if (node.methodName.name != 'parse') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'DateTime') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use DateTime.tryParse()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'tryParse',
        );
      });
    });
  }
}

/// Warns when int/double/num/BigInt/Uri.parse is used without try-catch.
///
/// These parse methods throw FormatException on invalid input. Dynamic data
/// (user input, API responses, file contents) should use tryParse instead
/// to return null on failure, preventing runtime crashes.
///
/// **BAD:**
/// ```dart
/// final age = int.parse(userInput); // Throws on "abc"!
/// final price = double.parse(json['price'] as String); // Throws on null/invalid!
/// final uri = Uri.parse(untrustedUrl); // Throws on malformed URL!
/// ```
///
/// **GOOD:**
/// ```dart
/// final age = int.tryParse(userInput) ?? 0;
/// final price = double.tryParse(json['price'] as String?) ?? 0.0;
/// final uri = Uri.tryParse(untrustedUrl); // Returns null on invalid URL
/// ```
class PreferTryParseForDynamicDataRule extends SaropaLintRule {
  const PreferTryParseForDynamicDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'prefer_try_parse_for_dynamic_data',
    problemMessage:
        'parse() throws on invalid input. Use tryParse() for dynamic data.',
    correctionMessage: 'Replace with tryParse() and handle null result.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _parseTypes = <String>{
    'int',
    'double',
    'num',
    'BigInt',
    'Uri',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'parse') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_parseTypes.contains(target.name)) return;

      // Check if inside try-catch
      if (!_isInsideTryCatch(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseNumTryParseFix()];
}

class _UseNumTryParseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      if (node.methodName.name != 'parse') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use ${target.name}.tryParse()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'tryParse',
        );
      });
    });
  }
}

/// Warns when Duration constructor can use cleaner units.
///
/// Duration(seconds: 60) is clearer as Duration(minutes: 1).
/// This rule suggests using larger units when they divide evenly.
///
/// **BAD:**
/// ```dart
/// Duration(seconds: 60);
/// Duration(milliseconds: 1000);
/// Duration(minutes: 60);
/// ```
///
/// **GOOD:**
/// ```dart
/// Duration(minutes: 1);
/// Duration(seconds: 1);
/// Duration(hours: 1);
/// ```
class PreferDurationConstantsRule extends SaropaLintRule {
  const PreferDurationConstantsRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'prefer_duration_constants',
    problemMessage: 'Duration can use a cleaner unit.',
    correctionMessage: 'Use a larger unit for cleaner code.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      if (typeName != 'Duration') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final String name = arg.name.label.name;
        final Expression value = arg.expression;

        if (value is! IntegerLiteral) continue;
        final int intValue = value.value ?? 0;
        if (intValue <= 0) continue;

        // Check for conversions
        if (name == 'milliseconds' &&
            intValue >= 1000 &&
            intValue % 1000 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'seconds' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'minutes' && intValue >= 60 && intValue % 60 == 0) {
          reporter.atNode(arg, code);
        } else if (name == 'hours' && intValue >= 24 && intValue % 24 == 0) {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when DateTime.now() is used in test files.
///
/// Tests using DateTime.now() can be flaky and hard to debug.
/// Use a clock abstraction or fixed datetime values for predictable tests.
///
/// **BAD:**
/// ```dart
/// // In *_test.dart file:
/// test('checks expiry', () {
///   final now = DateTime.now(); // Flaky!
///   expect(isExpired(now), isFalse);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use fixed datetime or clock package
/// test('checks expiry', () {
///   final fixedTime = DateTime(2024, 1, 15, 10, 30);
///   expect(isExpired(fixedTime), isFalse);
/// });
/// ```
class AvoidDatetimeNowInTestsRule extends SaropaLintRule {
  const AvoidDatetimeNowInTestsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_datetime_now_in_tests',
    problemMessage: 'DateTime.now() in tests can cause flaky behavior.',
    correctionMessage:
        'Use fixed datetime values or a clock abstraction for predictable tests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String filePath = resolver.path;
    if (!filePath.endsWith('_test.dart')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for DateTime.now()
      if (node.methodName.name != 'now') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      reporter.atNode(node, code);
    });
  }
}

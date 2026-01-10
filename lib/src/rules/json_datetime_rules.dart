// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// JSON and DateTime parsing rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when parsing JSON and dates
/// that can cause runtime crashes or data corruption.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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

/// Warns when double is used for money/currency values.
///
/// Floating point arithmetic has precision issues (0.1 + 0.2 != 0.3).
/// Use int cents or a Decimal package for monetary calculations.
///
/// **BAD:**
/// ```dart
/// double price = 19.99;
/// double total = price * quantity;
/// ```
///
/// **GOOD:**
/// ```dart
/// int priceInCents = 1999;
/// int totalInCents = priceInCents * quantity;
///
/// // Or use a Decimal package:
/// Decimal price = Decimal.parse('19.99');
/// ```
class AvoidDoubleForMoneyRule extends SaropaLintRule {
  const AvoidDoubleForMoneyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_double_for_money',
    problemMessage:
        'double has precision issues for money. Use int cents or Decimal.',
    correctionMessage: 'Store money as int cents or use a Decimal package.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _moneyIndicators = <String>{
    'price',
    'cost',
    'amount',
    'total',
    'balance',
    'payment',
    'fee',
    'tax',
    'discount',
    'subtotal',
    'revenue',
    'profit',
    'salary',
    'wage',
    'budget',
    'expense',
    'income',
    'money',
    'currency',
    'dollar',
    'euro',
    'pound',
    'yen',
    'cent',
  };

  /// Words containing money indicators that are NOT money-related.
  /// Used to prevent false positives like "percent" matching "cent".
  static const Set<String> _falsePositivePatterns = <String>{
    'percent', // percentage values, not cents
    'percentage',
    'center', // UI centering
    'centered',
    'centimeter', // measurements
    'accent', // colors, text styling
    'accented',
    'recent', // time-related
    'recently',
    'descent', // typography, movement
    'descend',
    'innocent', // not money
    'incentive', // could be money, but often not
    'concentrate',
    'central',
    'century',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      // Check type
      final VariableDeclarationList? parent =
          node.parent is VariableDeclarationList
              ? node.parent as VariableDeclarationList
              : null;
      if (parent == null) return;

      final String? typeName = parent.type?.toSource();
      if (typeName != 'double' && typeName != 'double?') return;

      // Check variable name for money indicators
      final String varName = node.name.lexeme.toLowerCase();
      if (_containsMoneyIndicator(varName)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final String? typeName = node.fields.type?.toSource();
      if (typeName != 'double' && typeName != 'double?') return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String varName = variable.name.lexeme.toLowerCase();
        if (_containsMoneyIndicator(varName)) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  /// Checks if a variable name contains a money indicator while avoiding
  /// false positives like "percent" matching "cent".
  static bool _containsMoneyIndicator(String varName) {
    // First check if the name contains any false positive patterns
    for (final String falsePositive in _falsePositivePatterns) {
      if (varName.contains(falsePositive)) {
        return false;
      }
    }

    // Then check for money indicators
    for (final String indicator in _moneyIndicators) {
      if (varName.contains(indicator)) {
        return true;
      }
    }

    return false;
  }
}

/// Warns when sensitive data appears in log statements.
///
/// Logging passwords, tokens, or credentials creates security risks
/// if logs are stored or transmitted insecurely.
///
/// **BAD:**
/// ```dart
/// logger.info('Login with password: $password');
/// print('Token: $authToken');
/// ```
///
/// **GOOD:**
/// ```dart
/// logger.info('Login attempt for user: $userId');
/// logger.debug('Auth token received', {'tokenLength': token.length});
/// ```
class AvoidSensitiveDataInLogsRule extends SaropaLintRule {
  const AvoidSensitiveDataInLogsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_sensitive_data_in_logs',
    problemMessage: 'Sensitive data in logs creates security risks.',
    correctionMessage:
        'Remove sensitive data or log only non-sensitive metadata.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitiveNames = <String>{
    'password',
    'passwd',
    'pwd',
    'secret',
    'token',
    'authtoken',
    'accesstoken',
    'refreshtoken',
    'apikey',
    'api_key',
    'privatekey',
    'private_key',
    'credential',
    'ssn',
    'creditcard',
    'cardnumber',
    'cvv',
    'pin',
  };

  static const Set<String> _logMethods = <String>{
    'print',
    'debugPrint',
    'log',
    'info',
    'debug',
    'warning',
    'error',
    'severe',
    'fine',
    'finer',
    'finest',
    'trace',
    'verbose',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_logMethods.contains(node.methodName.name)) return;

      // Check arguments for sensitive variable names
      for (final Expression arg in node.argumentList.arguments) {
        if (_containsSensitiveData(arg)) {
          reporter.atNode(arg, code);
        }
      }
    });

    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final String funcName = node.function.toSource();
      if (!_logMethods.contains(funcName)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (_containsSensitiveData(arg)) {
          reporter.atNode(arg, code);
        }
      }
    });
  }

  bool _containsSensitiveData(Expression arg) {
    final String source = arg.toSource().toLowerCase();
    for (final String sensitive in _sensitiveNames) {
      // Check for variable interpolation like $password or ${password}
      if (source.contains('\$$sensitive') ||
          source.contains('\${$sensitive') ||
          source.contains('$sensitive:') ||
          source.contains('$sensitive =')) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when GetIt is used in tests without reset in setUp.
///
/// GetIt singletons persist across tests, causing test pollution.
/// Reset the container in setUp to ensure test isolation.
///
/// **BAD:**
/// ```dart
/// void main() {
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///     // Uses stale singleton from previous test!
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   setUp(() {
///     GetIt.I.reset();
///     GetIt.I.registerSingleton<MyService>(MockMyService());
///   });
///
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///   });
/// }
/// ```
class RequireGetItResetInTestsRule extends SaropaLintRule {
  const RequireGetItResetInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  bool get skipTestFiles => false; // This rule specifically targets test files

  static const LintCode _code = LintCode(
    name: 'require_getit_reset_in_tests',
    problemMessage: 'GetIt singletons persist across tests. Reset in setUp.',
    correctionMessage: 'Add GetIt.I.reset() in setUp() or setUpAll().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only run in test files
    final String path = resolver.source.fullName.replaceAll('\\', '/');
    if (!path.contains('_test.dart') && !path.contains('/test/')) {
      return;
    }

    context.registry.addCompilationUnit((CompilationUnit unit) {
      final String source = unit.toSource();

      // Check if GetIt is used
      if (!source.contains('GetIt.I') && !source.contains('GetIt.instance')) {
        return;
      }

      // Check if reset is called (typically in setUp/setUpAll)
      final bool hasReset = source.contains('.reset()') ||
          source.contains('.resetLazySingleton') ||
          source.contains('GetIt.I.reset') ||
          source.contains('getIt.reset');

      // Only report if GetIt is used but never reset
      if (!hasReset) {
        // Find the first GetIt usage and report there
        unit.visitChildren(_GetItUsageVisitor(reporter, code));
      }
    });
  }
}

class _GetItUsageVisitor extends RecursiveAstVisitor<void> {
  _GetItUsageVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool _reported = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_reported) return;

    if (node.prefix.name == 'GetIt' &&
        (node.identifier.name == 'I' || node.identifier.name == 'instance')) {
      reporter.atNode(node, code);
      _reported = true;
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when WebSocket listeners don't have error handlers.
///
/// WebSocket streams can emit errors. Without error handling,
/// the app may crash or behave unexpectedly.
///
/// **BAD:**
/// ```dart
/// socket.stream.listen((data) {
///   processData(data);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// socket.stream.listen(
///   (data) => processData(data),
///   onError: (error) => handleError(error),
///   onDone: () => handleDisconnect(),
/// );
/// ```
class RequireWebSocketErrorHandlingRule extends SaropaLintRule {
  const RequireWebSocketErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_websocket_error_handling',
    problemMessage: 'WebSocket listener without onError can crash on errors.',
    correctionMessage: 'Add onError handler to WebSocket stream.listen().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is WebSocket-related
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('socket') &&
          !targetSource.contains('Socket') &&
          !targetSource.contains('channel') &&
          !targetSource.contains('Channel') &&
          !targetSource.contains('.stream')) {
        return;
      }

      // Check for onError parameter
      bool hasOnError = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onError') {
          hasOnError = true;
          break;
        }
      }

      if (!hasOnError) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when autoPlay: true is set on audio/video players.
///
/// Autoplaying audio is blocked on iOS/web and annoying to users.
/// Require explicit user interaction to start playback.
///
/// **BAD:**
/// ```dart
/// VideoPlayerController.asset('video.mp4')..initialize()..play();
/// AudioPlayer()..setUrl(url)..play(); // Auto-plays on load
/// BetterPlayerController(configuration: BetterPlayerConfiguration(autoPlay: true));
/// ```
///
/// **GOOD:**
/// ```dart
/// VideoPlayerController.asset('video.mp4')..initialize();
/// // User presses play button to start
///
/// BetterPlayerController(configuration: BetterPlayerConfiguration(autoPlay: false));
/// ```
class AvoidAutoplayAudioRule extends SaropaLintRule {
  const AvoidAutoplayAudioRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_autoplay_audio',
    problemMessage: 'Autoplay is blocked on iOS/web and annoys users.',
    correctionMessage:
        'Set autoPlay: false and require user interaction to play.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'autoPlay' &&
          node.name.label.name != 'autoplay') {
        return;
      }

      final Expression value = node.expression;
      if (value is BooleanLiteral && value.value) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_DisableAutoplayFix()];
}

class _DisableAutoplayFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Set autoPlay to false',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          value.sourceRange,
          'false',
        );
      });
    });
  }
}

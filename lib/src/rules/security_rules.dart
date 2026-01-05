// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Security lint rules for Flutter/Dart applications.
///
/// These rules help detect common security vulnerabilities and
/// unsafe practices that could expose user data or compromise
/// application integrity.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when sensitive data might be logged.
///
/// Logging PII (Personally Identifiable Information) or sensitive data
/// can expose it in crash reports, log files, or debugging tools.
///
/// **BAD:**
/// ```dart
/// print('User password: $password');
/// log('Credit card: ${user.creditCard}');
/// debugPrint('Token: $authToken');
/// ```
///
/// **GOOD:**
/// ```dart
/// print('User authenticated successfully');
/// log('Payment processed');
/// debugPrint('Token refreshed');
/// ```
class AvoidLoggingSensitiveDataRule extends DartLintRule {
  const AvoidLoggingSensitiveDataRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_logging_sensitive_data',
    problemMessage: 'Potential sensitive data in log statement.',
    correctionMessage:
        'Remove sensitive data from logs. Never log passwords, tokens, or PII.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitivePatterns = <String>{
    'password',
    'passwd',
    'secret',
    'token',
    'apikey',
    'api_key',
    'apiKey',
    'auth',
    'credential',
    'creditcard',
    'credit_card',
    'creditCard',
    'ssn',
    'social_security',
    'socialSecurity',
    'pin',
    'cvv',
    'private',
    'privatekey',
    'private_key',
    'privateKey',
  };

  static const Set<String> _loggingFunctions = <String>{
    'print',
    'debugPrint',
    'log',
    'logger',
    'Logger',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check direct logging calls
      if (!_loggingFunctions.contains(methodName)) {
        // Check for logger method calls like logger.info(), log.debug()
        final Expression? target = node.target;
        if (target is SimpleIdentifier) {
          final String targetName = target.name.toLowerCase();
          if (!targetName.contains('log')) return;
        } else {
          return;
        }
      }

      // Check arguments for sensitive data
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource().toLowerCase();
        for (final String pattern in _sensitivePatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });

    // Also check function expression invocations like print(...)
    context.registry.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;
      if (function is! SimpleIdentifier) return;

      if (!_loggingFunctions.contains(function.name)) return;

      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource().toLowerCase();
        for (final String pattern in _sensitivePatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when SharedPreferences is used for sensitive data.
///
/// SharedPreferences stores data in plain text and is not suitable
/// for sensitive information like tokens, passwords, or PII.
///
/// **BAD:**
/// ```dart
/// prefs.setString('auth_token', token);
/// prefs.setString('password', password);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use flutter_secure_storage instead
/// secureStorage.write(key: 'auth_token', value: token);
/// ```
class RequireSecureStorageRule extends DartLintRule {
  const RequireSecureStorageRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_secure_storage',
    problemMessage: 'Sensitive data should not be stored in SharedPreferences.',
    correctionMessage:
        'Use flutter_secure_storage or other encrypted storage for sensitive data.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitiveKeys = <String>{
    'token',
    'auth',
    'password',
    'secret',
    'key',
    'credential',
    'session',
    'refresh',
    'access',
    'api',
    'private',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SharedPreferences set methods
      if (!methodName.startsWith('set')) return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if it's a SharedPreferences or similar
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check the key for sensitive patterns
      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      final String keySource = firstArg.toSource().toLowerCase();

      for (final String pattern in _sensitiveKeys) {
        if (keySource.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when hardcoded credentials are detected in source code.
///
/// Credentials should never be hardcoded. Use environment variables,
/// secure vaults, or configuration files that are not committed.
///
/// **BAD:**
/// ```dart
/// const apiKey = 'sk-1234567890abcdef';
/// final password = 'admin123';
/// ```
///
/// **GOOD:**
/// ```dart
/// final apiKey = const String.fromEnvironment('API_KEY');
/// final password = await secureStorage.read(key: 'password');
/// ```
class AvoidHardcodedCredentialsRule extends DartLintRule {
  const AvoidHardcodedCredentialsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_credentials',
    problemMessage: 'Potential hardcoded credential detected.',
    correctionMessage:
        'Use environment variables or secure storage instead of hardcoding credentials.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _credentialNames = <String>{
    'password',
    'passwd',
    'secret',
    'apikey',
    'api_key',
    'apiKey',
    'token',
    'auth_token',
    'authToken',
    'access_token',
    'accessToken',
    'refresh_token',
    'refreshToken',
    'private_key',
    'privateKey',
    'client_secret',
    'clientSecret',
  };

  // Patterns that look like real credentials
  static final RegExp _credentialPatterns = RegExp(
    r'^(sk-|pk-|ghp_|gho_|Bearer |Basic )[a-zA-Z0-9]+',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final String varName = node.name.lexeme.toLowerCase();

      // Check if variable name suggests credentials
      final bool isCredentialName = _credentialNames.any(
        (String pattern) => varName.contains(pattern),
      );

      if (!isCredentialName) return;

      // Check if it's assigned a string literal
      final Expression? initializer = node.initializer;
      if (initializer is StringLiteral) {
        final String? value = initializer.stringValue;
        if (value != null && value.isNotEmpty && value.length > 3) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check for string literals that look like credentials
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (_credentialPatterns.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when user input is used without sanitization.
///
/// Unsanitized user input can lead to injection attacks, XSS,
/// or other security vulnerabilities.
///
/// **BAD:**
/// ```dart
/// final query = 'SELECT * FROM users WHERE name = "$userInput"';
/// webView.loadUrl(userProvidedUrl);
/// ```
///
/// **GOOD:**
/// ```dart
/// final query = 'SELECT * FROM users WHERE name = ?';
/// db.rawQuery(query, [userInput]);
///
/// if (Uri.tryParse(userProvidedUrl)?.hasScheme == true) {
///   webView.loadUrl(userProvidedUrl);
/// }
/// ```
class RequireInputSanitizationRule extends DartLintRule {
  const RequireInputSanitizationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_input_sanitization',
    problemMessage: 'User input should be validated or sanitized before use.',
    correctionMessage:
        'Validate and sanitize user input to prevent injection attacks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SQL-like operations
      if (methodName == 'rawQuery' ||
          methodName == 'rawInsert' ||
          methodName == 'rawUpdate' ||
          methodName == 'rawDelete' ||
          methodName == 'execute') {
        // Check if first argument is string interpolation
        if (node.argumentList.arguments.isEmpty) return;

        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is StringInterpolation) {
          reporter.atNode(node, code);
        }
      }

      // Check for URL loading
      if (methodName == 'loadUrl' ||
          methodName == 'loadRequest' ||
          methodName == 'launchUrl') {
        if (node.argumentList.arguments.isEmpty) return;

        final Expression firstArg = node.argumentList.arguments.first;
        // If it's a direct variable without validation, flag it
        if (firstArg is SimpleIdentifier) {
          final String name = firstArg.name.toLowerCase();
          if (name.contains('user') ||
              name.contains('input') ||
              name.contains('param')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when WebView has JavaScript enabled without consideration.
///
/// Enabling JavaScript in WebView can expose the app to XSS attacks
/// if loading untrusted content.
///
/// **BAD:**
/// ```dart
/// WebView(
///   initialUrl: url,
///   javascriptMode: JavascriptMode.unrestricted,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// WebView(
///   initialUrl: trustedUrl,
///   javascriptMode: JavascriptMode.disabled, // or carefully controlled
///   navigationDelegate: (request) {
///     // Validate navigation
///   },
/// )
/// ```
class AvoidWebViewJavaScriptEnabledRule extends DartLintRule {
  const AvoidWebViewJavaScriptEnabledRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_webview_javascript_enabled',
    problemMessage:
        'WebView with JavaScript enabled may be vulnerable to XSS attacks.',
    correctionMessage:
        'Consider disabling JavaScript or ensure only trusted content is loaded.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'WebView' &&
          constructorName != 'WebViewWidget' &&
          constructorName != 'InAppWebView') {
        return;
      }

      // Check for JavaScript mode
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'javascriptMode' ||
              name == 'javaScriptEnabled' ||
              name == 'initialSettings') {
            final String argSource = arg.expression.toSource();
            if (argSource.contains('unrestricted') ||
                argSource.contains('true')) {
              reporter.atNode(arg, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when biometric authentication lacks a fallback mechanism.
///
/// Not all devices support biometrics, and users should have an
/// alternative authentication method.
///
/// **BAD:**
/// ```dart
/// final authenticated = await localAuth.authenticate(
///   localizedReason: 'Authenticate',
///   biometricOnly: true,
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final authenticated = await localAuth.authenticate(
///   localizedReason: 'Authenticate',
///   biometricOnly: false, // Allow PIN/password fallback
/// );
/// // Or provide manual fallback
/// if (!canUseBiometrics) {
///   showPinDialog();
/// }
/// ```
class RequireBiometricFallbackRule extends DartLintRule {
  const RequireBiometricFallbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_biometric_fallback',
    problemMessage:
        'Biometric authentication should have a fallback mechanism.',
    correctionMessage:
        'Set biometricOnly to false or provide an alternative auth method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'authenticate') return;

      // Check if it's a biometric authentication call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('auth') && !targetSource.contains('bio')) {
        return;
      }

      // Check for biometricOnly: true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'biometricOnly') {
            if (arg.expression is BooleanLiteral) {
              final BooleanLiteral boolLit = arg.expression as BooleanLiteral;
              if (boolLit.value) {
                reporter.atNode(arg, code);
                return;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when eval-like patterns are detected.
///
/// Dynamic code execution (eval, Function constructor, etc.) can
/// be exploited for code injection attacks.
///
/// **BAD:**
/// ```dart
/// Function.apply(dynamicFunction, args);
/// dart:mirrors to invoke dynamic code
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use static dispatch or switch/case instead
/// switch (actionName) {
///   case 'action1': doAction1(); break;
///   case 'action2': doAction2(); break;
/// }
/// ```
class AvoidEvalLikePatternsRule extends DartLintRule {
  const AvoidEvalLikePatternsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_eval_like_patterns',
    problemMessage: 'Dynamic code execution pattern detected.',
    correctionMessage:
        'Avoid dynamic code execution. Use static dispatch or explicit mappings.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for Function.apply
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'apply') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'Function') {
          reporter.atNode(node, code);
        }
      }

      // Check for noSuchMethod invocations that might indicate dynamic dispatch
      if (methodName == 'noSuchMethod') {
        reporter.atNode(node, code);
      }
    });

    // Check for dart:mirrors import
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri != null && uri.contains('dart:mirrors')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when certificate pinning is not implemented for HTTPS.
///
/// Without certificate pinning, the app is vulnerable to
/// man-in-the-middle attacks with forged certificates.
///
/// **BAD:**
/// ```dart
/// final client = HttpClient();
/// // No certificate validation
/// ```
///
/// **GOOD:**
/// ```dart
/// final client = HttpClient()
///   ..badCertificateCallback = (cert, host, port) {
///     // Validate against pinned certificate
///     return cert.sha256 == expectedSha256;
///   };
/// ```
class RequireCertificatePinningRule extends DartLintRule {
  const RequireCertificatePinningRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_certificate_pinning',
    problemMessage: 'HttpClient should implement certificate pinning.',
    correctionMessage:
        'Set badCertificateCallback to validate server certificates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'HttpClient') return;

      // Check if followed by badCertificateCallback assignment
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) {
        // Look for cascade or subsequent assignment
        final AstNode? grandparent = parent.parent?.parent;
        if (grandparent is VariableDeclarationStatement) {
          // Check if there's a cascade
          if (node.parent is! CascadeExpression) {
            // Simple HttpClient() without configuration
            reporter.atNode(node.constructorName, code);
          }
        }
      } else if (parent is! CascadeExpression) {
        // HttpClient created without cascade configuration
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

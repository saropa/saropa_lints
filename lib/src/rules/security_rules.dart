// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Security lint rules for Flutter/Dart applications.
///
/// These rules help detect common security vulnerabilities and
/// unsafe practices that could expose user data or compromise
/// application integrity.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidLoggingSensitiveDataRule extends SaropaLintRule {
  const AvoidLoggingSensitiveDataRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_logging_sensitive_data',
    problemMessage:
        'Sensitive data in log. Will appear in crash reports and debug output.',
    correctionMessage:
        'Remove passwords, tokens, and PII from logs. Log a success/failure message instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Sensitive patterns that indicate PII or credentials.
  /// These should be specific enough to avoid false positives.
  /// For example, 'pin' is avoided since it matches "spinning", "pinned".
  static const Set<String> _sensitivePatterns = <String>{
    'password',
    'passwd',
    'secret',
    'token',
    'apikey',
    'api_key',
    'apiKey',
    'credential',
    'creditcard',
    'credit_card',
    'creditCard',
    'ssn',
    'social_security',
    'socialSecurity',
    'pincode', // More specific than 'pin'
    'pin_code',
    'cvv',
    'privatekey',
    'private_key',
    'privateKey',
  };

  /// Patterns that look sensitive but are actually safe.
  /// These are checked before flagging to avoid false positives.
  /// Example: "oauth" contains "auth" but is not sensitive data.
  static const Set<String> _safePatterns = <String>{
    'oauth', // OAuth protocol name, not actual auth data
    'authenticated', // Past tense verb, not a credential
    'authentication', // Noun describing process, not a credential
    'authorize', // Verb, not a credential
    'authorization', // Noun describing process, not a credential
    'unauthorized', // Error state, not a credential
    'unauthenticated', // Error state, not a credential
  };

  static const Set<String> _loggingFunctions = <String>{
    'print',
    'debugPrint',
    'log',
    'logger',
    'Logger',
  };

  /// Checks if a sensitive pattern match is actually a false positive.
  ///
  /// Returns true if the match is within a safe pattern (e.g., "auth" in "oauth").
  static bool _isSafeMatch(String source, String sensitivePattern) {
    // Check if any safe pattern contains this sensitive pattern
    // and appears in the source
    for (final String safePattern in _safePatterns) {
      if (safePattern.contains(sensitivePattern) &&
          source.contains(safePattern)) {
        return true;
      }
    }
    return false;
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
          if (argSource.contains(pattern) &&
              !_isSafeMatch(argSource, pattern)) {
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
          if (argSource.contains(pattern) &&
              !_isSafeMatch(argSource, pattern)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForSensitiveLoggingFix()];
}

class _AddHackForSensitiveLoggingFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for sensitive data logging',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: remove sensitive data from this log statement\n',
        );
      });
    });

    context.registry.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for sensitive data logging',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: remove sensitive data from this log statement\n',
        );
      });
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
class RequireSecureStorageRule extends SaropaLintRule {
  const RequireSecureStorageRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_secure_storage',
    problemMessage:
        'SharedPreferences stores in plain text. Sensitive data will be readable on rooted devices.',
    correctionMessage:
        'Use flutter_secure_storage: secureStorage.write(key: k, value: v).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns for sensitive keys - must match as word boundaries.
  /// Removed overly broad patterns like 'key' that cause false positives.
  static const Set<String> _sensitiveKeys = <String>{
    'token',
    'auth_token',
    'authtoken',
    'password',
    'secret',
    'api_key',
    'apikey',
    'credential',
    'session_id',
    'sessionid',
    'refresh_token',
    'access_token',
    'private_key',
    'privatekey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidHardcodedCredentialsRule extends SaropaLintRule {
  const AvoidHardcodedCredentialsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_credentials',
    problemMessage:
        'Hardcoded credential will be committed to version control and exposed.',
    correctionMessage:
        "Use String.fromEnvironment('KEY') or read from secure storage at runtime.",
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
  // Note: Bearer/Basic tokens should be a single base64-like token without spaces
  static final RegExp _credentialPatterns = RegExp(
    r'^(sk-[a-zA-Z0-9]{20,}|pk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36,}|gho_[a-zA-Z0-9]{36,}|Bearer [a-zA-Z0-9._-]{20,}$|Basic [a-zA-Z0-9+/=]{10,}$)',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForHardcodedCredentialsFix()];
}

class _AddHackForHardcodedCredentialsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for hardcoded credential',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: use environment variable or secure storage instead\n',
        );
      });
    });

    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for hardcoded credential',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: use environment variable or secure storage instead\n',
        );
      });
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
class RequireInputSanitizationRule extends SaropaLintRule {
  const RequireInputSanitizationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_input_sanitization',
    problemMessage: 'User input should be validated or sanitized before use.',
    correctionMessage:
        'Validate and sanitize user input to prevent injection attacks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidWebViewJavaScriptEnabledRule extends SaropaLintRule {
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireBiometricFallbackRule extends SaropaLintRule {
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidEvalLikePatternsRule extends SaropaLintRule {
  const AvoidEvalLikePatternsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_eval_like_patterns',
    problemMessage: 'Dynamic code execution pattern detected.',
    correctionMessage:
        'Avoid dynamic code execution. Use static dispatch or explicit mappings.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for Function.apply - dynamic function invocation
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'apply') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'Function') {
          reporter.atNode(node, code);
        }
      }

      // Note: noSuchMethod invocations are NOT flagged because they're
      // commonly used for mocking/proxying and are not security risks
      // when the target is controlled by the application.
    });

    // Check for dart:mirrors import - reflection is a security risk
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri != null && uri.contains('dart:mirrors')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForEvalPatternFix()];
}

class _AddHackForEvalPatternFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for dynamic code execution',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: replace with static dispatch or explicit mapping\n',
        );
      });
    });

    context.registry.addImportDirective((ImportDirective node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for dart:mirrors import',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: remove dart:mirrors usage for security\n',
        );
      });
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
class RequireCertificatePinningRule extends SaropaLintRule {
  const RequireCertificatePinningRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_certificate_pinning',
    problemMessage: 'HttpClient should implement certificate pinning.',
    correctionMessage:
        'Set badCertificateCallback to validate server certificates.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'HttpClient') return;

      // Check if part of a cascade expression that configures certificate callback
      AstNode? current = node.parent;
      while (current != null) {
        if (current is CascadeExpression) {
          // Check if any cascade section sets badCertificateCallback
          final String cascadeSource = current.toSource();
          if (cascadeSource.contains('badCertificateCallback')) {
            return; // Properly configured
          }
        }
        current = current.parent;
      }

      // Not configured with certificate pinning
      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when tokens or API keys appear in URLs.
///
/// Tokens in URLs are logged, cached, and visible in browser history.
/// Use headers or request body instead.
///
/// Example of **bad** code:
/// ```dart
/// final url = 'https://api.example.com?token=$apiToken';
/// final url = 'https://api.example.com?api_key=abc123';
/// ```
///
/// Example of **good** code:
/// ```dart
/// final response = await http.get(
///   Uri.parse('https://api.example.com'),
///   headers: {'Authorization': 'Bearer $apiToken'},
/// );
/// ```
class AvoidTokenInUrlRule extends SaropaLintRule {
  const AvoidTokenInUrlRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_token_in_url',
    problemMessage: 'Avoid putting tokens or API keys in URLs.',
    correctionMessage:
        'Use Authorization header or request body for sensitive data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static final RegExp _tokenPattern = RegExp(
    r'[?&](token|api_key|apikey|api-key|access_token|auth|key|secret|password|bearer)=',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (_tokenPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addStringInterpolation((StringInterpolation node) {
      final String source = node.toSource().toLowerCase();
      if (_tokenPattern.hasMatch(source)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when sensitive data is copied to clipboard.
///
/// Clipboard contents can be accessed by other apps and may persist
/// across app sessions. Never copy passwords or tokens to clipboard.
///
/// Example of **bad** code:
/// ```dart
/// Clipboard.setData(ClipboardData(text: password));
/// Clipboard.setData(ClipboardData(text: user.secretToken));
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Don't copy sensitive data to clipboard
/// // Use secure input fields with obscureText instead
/// ```
class AvoidClipboardSensitiveRule extends SaropaLintRule {
  const AvoidClipboardSensitiveRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_clipboard_sensitive',
    problemMessage: 'Avoid copying sensitive data to clipboard.',
    correctionMessage:
        'Clipboard can be read by other apps. Never copy passwords or tokens.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitivePatterns = <String>{
    'password',
    'passwd',
    'secret',
    'token',
    'apikey',
    'api_key',
    'credential',
    'private',
    'auth',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'setData') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check arguments for sensitive variable names
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

/// Warns when passwords are stored in SharedPreferences.
///
/// SharedPreferences is plain text storage. Use flutter_secure_storage
/// or other encrypted storage for passwords.
///
/// Example of **bad** code:
/// ```dart
/// prefs.setString('password', userPassword);
/// prefs.setString('user_password', value);
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Use flutter_secure_storage
/// await secureStorage.write(key: 'password', value: userPassword);
/// ```
class AvoidStoringPasswordsRule extends SaropaLintRule {
  const AvoidStoringPasswordsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_storing_passwords',
    problemMessage: 'Never store passwords in SharedPreferences.',
    correctionMessage:
        'Use flutter_secure_storage for passwords and sensitive data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SharedPreferences set methods
      if (!methodName.startsWith('set')) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      final String keySource = firstArg.toSource().toLowerCase();

      if (keySource.contains('password') || keySource.contains('passwd')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when SQL queries are built using string interpolation.
///
/// Building SQL queries with string interpolation or concatenation
/// exposes your application to SQL injection attacks. Always use
/// parameterized queries instead.
///
/// **BAD:**
/// ```dart
/// db.rawQuery('SELECT * FROM users WHERE id = $userId');
/// db.execute('DELETE FROM users WHERE name = "$name"');
/// db.rawQuery('SELECT * FROM users WHERE email = ' + email);
/// ```
///
/// **GOOD:**
/// ```dart
/// db.rawQuery('SELECT * FROM users WHERE id = ?', [userId]);
/// db.query('users', where: 'id = ?', whereArgs: [userId]);
/// ```
class AvoidDynamicSqlRule extends SaropaLintRule {
  const AvoidDynamicSqlRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_sql',
    problemMessage:
        'SQL query built with string interpolation is vulnerable to SQL injection.',
    correctionMessage:
        'Use parameterized queries with ? placeholders and arguments list.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// SQL method names that take a raw query string.
  static const Set<String> _sqlMethods = <String>{
    'rawQuery',
    'rawInsert',
    'rawUpdate',
    'rawDelete',
    'execute',
    'executeSql',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_sqlMethods.contains(methodName)) return;

      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;

      // Check for string interpolation
      if (firstArg is StringInterpolation) {
        reporter.atNode(firstArg, code);
        return;
      }

      // Check for string concatenation (binary + with strings)
      if (firstArg is BinaryExpression && firstArg.operator.lexeme == '+') {
        // Check if either side looks like SQL
        final String leftSource = firstArg.leftOperand.toSource().toLowerCase();
        if (leftSource.contains('select') ||
            leftSource.contains('insert') ||
            leftSource.contains('update') ||
            leftSource.contains('delete') ||
            leftSource.contains('from') ||
            leftSource.contains('where')) {
          reporter.atNode(firstArg, code);
          return;
        }
      }

      // Check for adjacent strings with interpolation
      if (firstArg is AdjacentStrings) {
        for (final StringLiteral string in firstArg.strings) {
          if (string is StringInterpolation) {
            reporter.atNode(firstArg, code);
            return;
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDynamicSqlFix()];
}

class _AddHackForDynamicSqlFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO: Use parameterized query',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Use parameterized query with ? placeholders\n',
        );
      });
    });
  }
}

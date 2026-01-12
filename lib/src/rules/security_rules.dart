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

// cspell:ignore pincode plaintext sessionid expir isbefore accountnumber cardnumber
// cspell:ignore sharedpreferences returnurl launchurl creds phonenumber socialsecurity
// cspell:ignore deleteaccount taxid idtoken localauthentication faceid routingnumber
// cspell:ignore encryptedbox changepassword getexternalstoragedirectory

/// Warns when sensitive data might be logged.
///
/// Alias: no_sensitive_logs, pii_in_logs, credential_logging
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

  /// Logging PII exposes sensitive data in crash reports and logs.
  /// Each occurrence is a potential data breach.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_logging_sensitive_data',
    problemMessage:
        '[avoid_logging_sensitive_data] Sensitive data in log. Will appear in crash reports and debug output.',
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
  List<Fix> getFixes() => <Fix>[_AddTodoForSensitiveLoggingFix()];
}

class _AddTodoForSensitiveLoggingFix extends DartFix {
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
/// Alias: use_secure_storage, no_plaintext_storage, encrypted_storage
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

  /// Plain text storage of credentials is readable on rooted devices.
  /// Each occurrence exposes sensitive data.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_secure_storage',
    problemMessage:
        '[require_secure_storage] SharedPreferences stores in plain text. Sensitive data will be readable on rooted devices.',
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
/// Alias: no_hardcoded_secrets, embedded_credentials, hardcoded_password
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

  /// Hardcoded credentials will be committed to version control.
  /// Each occurrence is a security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_credentials',
    problemMessage:
        '[avoid_hardcoded_credentials] Hardcoded credential will be committed to version control and exposed.',
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
  List<Fix> getFixes() => <Fix>[_AddTodoForHardcodedCredentialsFix()];
}

class _AddTodoForHardcodedCredentialsFix extends DartFix {
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
/// Alias: validate_input, sanitize_user_input, injection_prevention
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

  /// Unsanitized input enables injection attacks.
  /// Each occurrence is a potential security exploit.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_input_sanitization',
    problemMessage:
        '[require_input_sanitization] User input should be validated or sanitized before use.',
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

  /// JavaScript in WebView can enable XSS attacks with untrusted content.
  /// Review each occurrence for security implications.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_webview_javascript_enabled',
    problemMessage:
        '[avoid_webview_javascript_enabled] WebView with JavaScript enabled may be vulnerable to XSS attacks.',
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

  /// Missing biometric fallback is a usability issue, not a security risk.
  /// Address for better UX on devices without biometrics.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_biometric_fallback',
    problemMessage:
        '[require_biometric_fallback] Biometric authentication should have a fallback mechanism.',
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

  /// Dynamic code execution enables code injection attacks.
  /// Each occurrence is a serious security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_eval_like_patterns',
    problemMessage:
        '[avoid_eval_like_patterns] Dynamic code execution pattern detected.',
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
  List<Fix> getFixes() => <Fix>[_AddTodoForEvalPatternFix()];
}

class _AddTodoForEvalPatternFix extends DartFix {
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

  /// Missing certificate pinning enables man-in-the-middle attacks.
  /// Important for apps handling sensitive data.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_certificate_pinning',
    problemMessage:
        '[require_certificate_pinning] HttpClient should implement certificate pinning.',
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

  /// Tokens in URLs are logged and visible in browser history.
  /// Each occurrence exposes credentials.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_token_in_url',
    problemMessage:
        '[avoid_token_in_url] Avoid putting tokens or API keys in URLs.',
    correctionMessage:
        'Use Authorization header or request body for sensitive data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Pattern to detect sensitive tokens in URLs.
  ///
  /// Matches specific token parameter names that are clearly sensitive.
  /// Generic patterns like 'key' and 'auth' are in [AvoidGenericKeyInUrlRule].
  static final RegExp _tokenPattern = RegExp(
    r'[?&](token|api_key|apikey|api-key|access_token|secret|password|bearer)=',
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

  /// Clipboard data is accessible by other apps and persists.
  /// Each occurrence risks credential exposure.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_clipboard_sensitive',
    problemMessage:
        '[avoid_clipboard_sensitive] Avoid copying sensitive data to clipboard.',
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

  /// Passwords in SharedPreferences are stored as plain text.
  /// Each occurrence exposes user credentials.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_storing_passwords',
    problemMessage:
        '[avoid_storing_passwords] Never store passwords in SharedPreferences.',
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

  /// String interpolation in SQL enables SQL injection attacks.
  /// Each occurrence is a critical security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_sql',
    problemMessage:
        '[avoid_dynamic_sql] SQL query built with string interpolation is vulnerable to SQL injection.',
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
  List<Fix> getFixes() => <Fix>[_AddTodoForDynamicSqlFix()];
}

class _AddTodoForDynamicSqlFix extends DartFix {
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
        message: 'Add HACK: Use parameterized query',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use parameterized query with ? placeholders\n',
        );
      });
    });
  }
}

/// Warns when generic key/auth parameters appear in URLs (insanity tier).
///
/// This is a stricter variant of [AvoidTokenInUrlRule] that catches
/// generic parameter names that might contain sensitive data. More prone
/// to false positives in test code.
///
/// Example of flagged code:
/// ```dart
/// final url = 'https://api.example.com?key=$apiKey';
/// final url = 'https://api.example.com?auth=$authValue';
/// final url = 'https://api.example.com?authtoken=$token';
/// ```
class AvoidGenericKeyInUrlRule extends SaropaLintRule {
  const AvoidGenericKeyInUrlRule() : super(code: _code);

  /// Generic key parameters in URLs may contain sensitive data.
  /// Review for potential credential exposure.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_generic_key_in_url',
    problemMessage:
        '[avoid_generic_key_in_url] Generic key/auth parameter in URL may contain sensitive data.',
    correctionMessage:
        'Consider using Authorization header instead of URL parameters.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Generic patterns that might indicate sensitive data but have higher
  /// false positive rates than the specific patterns in [AvoidTokenInUrlRule].
  static final RegExp _genericKeyPattern = RegExp(
    r'[?&](key|auth|authtoken|auth_token|auth-token)=',
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
      if (_genericKeyPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addStringInterpolation((StringInterpolation node) {
      final String source = node.toSource().toLowerCase();
      if (_genericKeyPattern.hasMatch(source)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Random() is used instead of Random.secure().
///
/// Random() uses a predictable pseudo-random number generator that is
/// not suitable for security-sensitive operations like generating tokens,
/// passwords, or cryptographic keys.
///
/// **BAD:**
/// ```dart
/// final random = Random();
/// final token = List.generate(32, (_) => random.nextInt(256));
/// ```
///
/// **GOOD:**
/// ```dart
/// final random = Random.secure();
/// final token = List.generate(32, (_) => random.nextInt(256));
/// ```
class PreferSecureRandomRule extends SaropaLintRule {
  const PreferSecureRandomRule() : super(code: _code);

  /// Random() is predictable and unsuitable for security.
  /// Use Random.secure() for tokens and crypto operations.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_secure_random',
    problemMessage:
        '[prefer_secure_random] Random() is predictable. Use Random.secure() for security-sensitive code.',
    correctionMessage:
        'Replace Random() with Random.secure() for tokens, passwords, or crypto.',
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
      if (constructorName != 'Random') return;

      // Check if it's Random() not Random.secure()
      final String? namedConstructor = node.constructorName.name?.name;
      if (namedConstructor == 'secure') return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseSecureRandomFix()];
}

class _UseSecureRandomFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use Random.secure()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'Random.secure()',
        );
      });
    });
  }
}

/// Warns when `List<int>` is used for binary data instead of Uint8List.
///
/// Uint8List is more memory-efficient for binary data and provides better
/// interoperability with native code and I/O operations. `List<int>` uses
/// 8 bytes per element vs 1 byte for Uint8List.
///
/// **BAD:**
/// ```dart
/// final List<int> bytes = utf8.encode(text);
/// final List<int> fileContents = await file.readAsBytes();
/// ```
///
/// **GOOD:**
/// ```dart
/// final Uint8List bytes = Uint8List.fromList(utf8.encode(text));
/// final Uint8List fileContents = await file.readAsBytes();
/// ```
class PreferTypedDataRule extends SaropaLintRule {
  const PreferTypedDataRule() : super(code: _code);

  /// `List<int>` for binary data is inefficient but functional.
  /// Optimization suggestion, not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_typed_data',
    problemMessage:
        '[prefer_typed_data] List<int> for binary data wastes memory. Use Uint8List instead.',
    correctionMessage:
        'Use Uint8List for binary data - 8x more memory efficient.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      // Get the type from the parent VariableDeclarationList
      final AstNode? parent = node.parent;
      if (parent is! VariableDeclarationList) return;

      final TypeAnnotation? typeAnnotation = parent.type;
      if (typeAnnotation == null) return;

      final String typeSource = typeAnnotation.toSource();

      // Check for List<int> pattern
      if (typeSource == 'List<int>' || typeSource == 'List<int>?') {
        // Check if this looks like binary data based on variable name
        final String varName = node.name.lexeme.toLowerCase();
        if (varName.contains('byte') ||
            varName.contains('data') ||
            varName.contains('buffer') ||
            varName.contains('content') ||
            varName.contains('binary')) {
          reporter.atNode(typeAnnotation, code);
        }
      }
    });
  }
}

/// Warns when .toList() is called unnecessarily on iterable operations.
///
/// Calling .toList() after .map(), .where(), .take(), etc. creates an
/// intermediate list that may not be needed. Dart's lazy iterables are
/// more memory efficient.
///
/// **BAD:**
/// ```dart
/// final names = users.map((u) => u.name).toList();
/// for (final name in names) { ... }
///
/// final adults = users.where((u) => u.age >= 18).toList();
/// return adults.length;
/// ```
///
/// **GOOD:**
/// ```dart
/// final names = users.map((u) => u.name);
/// for (final name in names) { ... }
///
/// final adults = users.where((u) => u.age >= 18);
/// return adults.length;
/// ```
class AvoidUnnecessaryToListRule extends SaropaLintRule {
  const AvoidUnnecessaryToListRule() : super(code: _code);

  /// Unnecessary toList() is inefficient but functional.
  /// Performance optimization, not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_to_list',
    problemMessage:
        '[avoid_unnecessary_to_list] .toList() may be unnecessary here. Lazy iterables are more efficient.',
    correctionMessage:
        'Remove .toList() unless you need to modify the list or access by index.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toList') return;

      // Check if this is chained after an iterable method
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      final String previousMethod = target.methodName.name;
      const Set<String> iterableMethods = <String>{
        'map',
        'where',
        'take',
        'skip',
        'takeWhile',
        'skipWhile',
        'expand',
        'cast',
        'whereType',
      };

      if (!iterableMethods.contains(previousMethod)) return;

      // Check how the result is used
      final AstNode? parent = node.parent;

      // If it's assigned to a variable, check if the variable type requires List
      if (parent is VariableDeclaration) {
        final AstNode? declParent = parent.parent;
        if (declParent is VariableDeclarationList) {
          final TypeAnnotation? type = declParent.type;
          if (type != null && type.toSource().startsWith('List')) {
            return; // List type is explicitly required
          }
        }
      }

      // If it's returned directly, we can't easily check the return type
      if (parent is ReturnStatement) return;

      // If passed as argument, we can't easily check parameter type
      if (parent is ArgumentList) return;

      // Otherwise, suggest removing toList
      reporter.atNode(node.methodName, code);
    });
  }
}

/// Warns when API endpoints don't verify authentication.
///
/// All authenticated endpoints should check auth status before
/// processing. Missing checks expose sensitive data.
///
/// **BAD:**
/// ```dart
/// Future<Response> getUserProfile(Request request) async {
///   final userId = request.params['id'];
///   return Response.ok(await db.getUser(userId)); // No auth check!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<Response> getUserProfile(Request request) async {
///   final token = request.headers['Authorization'];
///   if (!await authService.verifyToken(token)) {
///     return Response.unauthorized();
///   }
///   final userId = request.params['id'];
///   return Response.ok(await db.getUser(userId));
/// }
/// ```
class RequireAuthCheckRule extends SaropaLintRule {
  const RequireAuthCheckRule() : super(code: _code);

  /// Missing auth check exposes protected endpoints.
  /// Each occurrence is an unauthorized access risk.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_auth_check',
    problemMessage:
        '[require_auth_check] Protected endpoint may be missing authentication check.',
    correctionMessage:
        'Add authentication verification before processing protected requests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _protectedEndpointPatterns = <String>{
    'profile',
    'user',
    'account',
    'settings',
    'private',
    'admin',
    'dashboard',
    'order',
    'payment',
    'wallet',
    'transaction',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme.toLowerCase();

      // Check if function name suggests protected endpoint
      bool looksProtected = false;
      for (final String pattern in _protectedEndpointPatterns) {
        if (functionName.contains(pattern)) {
          looksProtected = true;
          break;
        }
      }

      if (!looksProtected) return;

      // Check return type suggests an API response
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String returnTypeStr = returnType.toSource();
      if (!returnTypeStr.contains('Response') &&
          !returnTypeStr.contains('Future')) {
        return;
      }

      // Check if function body has auth verification
      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      final bool hasAuthCheck = bodySource.contains('verifyToken') ||
          bodySource.contains('authenticate') ||
          bodySource.contains('Authorization') ||
          bodySource.contains('isAuthenticated') ||
          bodySource.contains('checkAuth') ||
          bodySource.contains('unauthorized') ||
          bodySource.contains('Unauthorized');

      if (!hasAuthCheck) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when token refresh logic is missing for auth tokens.
///
/// Access tokens expire. Without refresh logic, users get logged out
/// unexpectedly. Implement proactive token refresh.
///
/// **BAD:**
/// ```dart
/// class AuthService {
///   String? accessToken;
///
///   Future<Response> makeRequest(String url) async {
///     return http.get(url, headers: {'Authorization': 'Bearer $accessToken'});
///     // Token may be expired!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class AuthService {
///   String? accessToken;
///   String? refreshToken;
///   DateTime? tokenExpiry;
///
///   Future<Response> makeRequest(String url) async {
///     if (tokenExpiry?.isBefore(DateTime.now()) ?? true) {
///       await refreshAccessToken();
///     }
///     return http.get(url, headers: {'Authorization': 'Bearer $accessToken'});
///   }
/// }
/// ```
class RequireTokenRefreshRule extends SaropaLintRule {
  const RequireTokenRefreshRule() : super(code: _code);

  /// Missing token refresh causes unexpected logouts.
  /// UX issue rather than security vulnerability.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_token_refresh',
    problemMessage:
        '[require_token_refresh] Auth service stores access token but may lack refresh logic.',
    correctionMessage:
        'Implement token refresh to handle expiration gracefully.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Check if class is auth-related
      if (!className.contains('auth') &&
          !className.contains('session') &&
          !className.contains('token')) {
        return;
      }

      bool hasAccessToken = false;
      bool hasRefreshToken = false;
      bool hasRefreshMethod = false;
      bool hasExpiryCheck = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String fieldSource = member.toSource().toLowerCase();
          if (fieldSource.contains('accesstoken') ||
              fieldSource.contains('access_token')) {
            hasAccessToken = true;
          }
          if (fieldSource.contains('refreshtoken') ||
              fieldSource.contains('refresh_token')) {
            hasRefreshToken = true;
          }
          if (fieldSource.contains('expir')) {
            hasExpiryCheck = true;
          }
        }
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme.toLowerCase();
          if (methodName.contains('refresh')) {
            hasRefreshMethod = true;
          }
          // Check method body for expiry checks
          final String bodySource = member.body.toSource().toLowerCase();
          if (bodySource.contains('expir') || bodySource.contains('isbefore')) {
            hasExpiryCheck = true;
          }
        }
      }

      // If has access token but no refresh logic, warn
      if (hasAccessToken && !hasRefreshToken && !hasRefreshMethod) {
        reporter.atToken(node.name, code);
      }
      if (hasAccessToken && !hasExpiryCheck) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when JWT is decoded on client for authorization decisions.
///
/// JWTs can be manipulated on the client. Never trust client-decoded
/// JWT claims for authorization - always verify on the server.
///
/// **BAD:**
/// ```dart
/// final jwt = decodeJwt(token);
/// if (jwt['role'] == 'admin') {
///   showAdminPanel(); // User could modify JWT payload!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Verify role on server
/// final response = await api.getUserRole(token);
/// if (response.role == 'admin') {
///   showAdminPanel();
/// }
/// ```
class AvoidJwtDecodeClientRule extends SaropaLintRule {
  const AvoidJwtDecodeClientRule() : super(code: _code);

  /// Client-decoded JWTs can be manipulated for authorization bypass.
  /// Each occurrence risks privilege escalation.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_jwt_decode_client',
    problemMessage:
        '[avoid_jwt_decode_client] Decoding JWT on client for authorization is insecure.',
    correctionMessage:
        'Verify JWT claims on the server. Client-decoded JWTs can be manipulated.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      // Check for JWT decode calls
      if (!methodName.contains('decode') && !methodName.contains('parse')) {
        return;
      }

      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        if (!targetSource.contains('jwt') && !targetSource.contains('token')) {
          return;
        }
      }

      // Check if result is used for authorization decisions
      AstNode? current = node.parent;
      while (current != null) {
        if (current is IfStatement) {
          final String condition = current.expression.toSource().toLowerCase();
          if (condition.contains('role') ||
              condition.contains('admin') ||
              condition.contains('permission') ||
              condition.contains('scope') ||
              condition.contains('claim')) {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });

    // Also check for direct JWT library usage
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName =
          node.constructorName.type.name.lexeme.toLowerCase();
      if (typeName.contains('jwt') || typeName.contains('jsonwebtoken')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when logout doesn't clear all sensitive data.
///
/// Logout must clear tokens, cached user data, and sensitive state.
/// Incomplete cleanup leaves users vulnerable.
///
/// **BAD:**
/// ```dart
/// Future<void> logout() async {
///   await api.logout();
///   // Token still in storage! User data still cached!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> logout() async {
///   await api.logout();
///   await secureStorage.deleteAll();
///   await cache.clear();
///   _userController.add(null);
///   _isLoggedIn = false;
/// }
/// ```
class RequireLogoutCleanupRule extends SaropaLintRule {
  const RequireLogoutCleanupRule() : super(code: _code);

  /// Incomplete logout cleanup leaves sensitive data accessible.
  /// Each occurrence risks data leakage after logout.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_logout_cleanup',
    problemMessage:
        '[require_logout_cleanup] Logout may not clear all sensitive data.',
    correctionMessage:
        'Ensure logout clears tokens, cached user data, and resets auth state.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      if (methodName != 'logout' &&
          methodName != 'signout' &&
          methodName != 'sign_out') {
        return;
      }

      final String bodySource = node.body.toSource().toLowerCase();

      // Check for cleanup operations
      final bool clearsStorage = bodySource.contains('delete') ||
          bodySource.contains('remove') ||
          bodySource.contains('clear');

      final bool clearsToken = bodySource.contains('token') ||
          bodySource.contains('credential') ||
          bodySource.contains('auth');

      final bool clearsCache =
          bodySource.contains('cache') || bodySource.contains('storage');

      // If logout method is too simple, warn
      if (!clearsStorage || (!clearsToken && !clearsCache)) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when auth tokens are passed in query parameters.
///
/// Query parameters are logged in server access logs, browser history,
/// and can leak through referrer headers. Use Authorization header instead.
///
/// **BAD:**
/// ```dart
/// final url = 'https://api.example.com/user?token=$accessToken';
/// await http.get(Uri.parse(url));
/// ```
///
/// **GOOD:**
/// ```dart
/// await http.get(
///   Uri.parse('https://api.example.com/user'),
///   headers: {'Authorization': 'Bearer $accessToken'},
/// );
/// ```
class AvoidAuthInQueryParamsRule extends SaropaLintRule {
  const AvoidAuthInQueryParamsRule() : super(code: _code);

  /// Auth tokens in query params are logged and leak via referrers.
  /// Each occurrence exposes credentials.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_auth_in_query_params',
    problemMessage:
        '[avoid_auth_in_query_params] Auth token in query parameter is insecure. Use Authorization header.',
    correctionMessage:
        'Move token to Authorization header to prevent logging and leakage.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _tokenPatterns = <String>{
    'token=',
    'access_token=',
    'auth_token=',
    'api_key=',
    'apikey=',
    'secret=',
    'password=',
    'credential=',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      final String fullString = node.toSource().toLowerCase();

      for (final String pattern in _tokenPatterns) {
        if (fullString.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addAdjacentStrings((AdjacentStrings node) {
      final String fullString = node.toSource().toLowerCase();

      for (final String pattern in _tokenPatterns) {
        if (fullString.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for string concatenation with token
      if (node.operator.lexeme != '+') return;

      final String fullExpr = node.toSource().toLowerCase();
      for (final String pattern in _tokenPatterns) {
        if (fullExpr.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when auth tokens are stored in SharedPreferences instead of secure storage.
///
/// SharedPreferences stores data as plain text on disk. Auth tokens, session
/// data, and credentials must use flutter_secure_storage or platform keychain.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// await prefs.setString('auth_token', token);
/// await prefs.setString('session_id', sessionId);
/// ```
///
/// **GOOD:**
/// ```dart
/// final secureStorage = FlutterSecureStorage();
/// await secureStorage.write(key: 'auth_token', value: token);
/// await secureStorage.write(key: 'session_id', value: sessionId);
/// ```
class AvoidAuthStateInPrefsRule extends SaropaLintRule {
  const AvoidAuthStateInPrefsRule() : super(code: _code);

  /// Auth tokens in SharedPreferences are stored as plain text.
  /// Each occurrence exposes credentials on rooted devices.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_auth_state_in_prefs',
    problemMessage:
        '[avoid_auth_state_in_prefs] Auth tokens in SharedPreferences are stored as plain text.',
    correctionMessage:
        'Use flutter_secure_storage or platform keychain for sensitive data.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitiveKeys = <String>{
    'token',
    'auth_token',
    'access_token',
    'refresh_token',
    'session',
    'session_id',
    'credential',
    'password',
    'secret',
    'api_key',
    'apikey',
    'bearer',
    'jwt',
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
      if (methodName != 'setString' &&
          methodName != 'setStringList' &&
          methodName != 'setBool') {
        return;
      }

      // Check if called on SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check if key contains sensitive patterns
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final String keySource = args.arguments.first.toSource().toLowerCase();
      for (final String sensitive in _sensitiveKeys) {
        if (keySource.contains(sensitive)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSecureStorageTodoFix()];
}

class _AddSecureStorageTodoFix extends DartFix {
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
        message: 'Add HACK: Use flutter_secure_storage instead',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use flutter_secure_storage for auth tokens\n',
        );
      });
    });
  }
}

/// Warns when sensitive data uses SharedPreferences instead of encrypted storage.
///
/// SharedPreferences are plain text. Use encrypted_shared_preferences or
/// flutter_secure_storage for passwords, PINs, and personal data.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// await prefs.setString('user_password', password);
/// await prefs.setString('pin_code', pin);
/// await prefs.setString('credit_card', cardNumber);
/// ```
///
/// **GOOD:**
/// ```dart
/// final secureStorage = FlutterSecureStorage();
/// await secureStorage.write(key: 'user_password', value: password);
/// // Or use encrypted_shared_preferences
/// ```
class PreferEncryptedPrefsRule extends SaropaLintRule {
  const PreferEncryptedPrefsRule() : super(code: _code);

  /// Sensitive data in SharedPreferences is unencrypted.
  /// Each occurrence exposes personal data.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_encrypted_prefs',
    problemMessage:
        '[prefer_encrypted_prefs] Sensitive data in SharedPreferences is stored unencrypted.',
    correctionMessage:
        'Use flutter_secure_storage or encrypted_shared_preferences.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitivePatterns = <String>{
    'password',
    'passwd',
    'pin',
    'credit_card',
    'card_number',
    'cvv',
    'ssn',
    'social_security',
    'bank_account',
    'routing_number',
    'private_key',
    'secret_key',
    'encryption_key',
    'dob',
    'date_of_birth',
    'mother_maiden',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!methodName.startsWith('set') && !methodName.startsWith('get')) {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final String keySource = args.arguments.first.toSource().toLowerCase();
      for (final String sensitive in _sensitivePatterns) {
        if (keySource.contains(sensitive)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddEncryptedPrefsTodoFix()];
}

class _AddEncryptedPrefsTodoFix extends DartFix {
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
        message: 'Add HACK: Use encrypted storage',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use flutter_secure_storage or encrypted_shared_preferences\n',
        );
      });
    });
  }
}

/// Warns when deep link handlers don't validate parameters.
///
/// Deep links can pass arbitrary data to your app. Validate and sanitize
/// all deep link parameters before using them to prevent injection attacks.
///
/// **BAD:**
/// ```dart
/// void handleDeepLink(Uri uri) {
///   final userId = uri.queryParameters['user_id'];
///   fetchUser(userId!); // No validation!
/// }
///
/// void onGenerateRoute(RouteSettings settings) {
///   final args = settings.arguments as Map<String, dynamic>;
///   return UserPage(userId: args['id']); // No validation!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void handleDeepLink(Uri uri) {
///   final userId = uri.queryParameters['user_id'];
///   if (userId == null || !_isValidUserId(userId)) {
///     throw InvalidDeepLinkException('Invalid user_id');
///   }
///   fetchUser(userId);
/// }
///
/// bool _isValidUserId(String id) {
///   return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) && id.length <= 36;
/// }
/// ```
class RequireDeepLinkValidationRule extends SaropaLintRule {
  const RequireDeepLinkValidationRule() : super(code: _code);

  /// Deep links without validation enable injection attacks.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_deep_link_validation',
    problemMessage:
        '[require_deep_link_validation] Deep link parameter used without validation. Validate before use.',
    correctionMessage:
        'Add null check and format validation for deep link parameters.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for queryParameters access
      if (node.methodName.name != '[]') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('queryParameters') &&
          !targetSource.contains('pathSegments') &&
          !targetSource.contains('arguments')) {
        return;
      }

      // Check if the result is validated before use
      // Look for nearby null checks or validation
      AstNode? current = node.parent;

      // If it's inside an if condition or null check, it's likely validated
      while (current != null) {
        if (current is IfStatement) {
          final String condition = current.expression.toSource();
          if (condition.contains('==') ||
              condition.contains('!=') ||
              condition.contains('null') ||
              condition.contains('isValid') ||
              condition.contains('hasMatch')) {
            return; // Has validation
          }
        }
        if (current is ConditionalExpression ||
            current is AssertStatement ||
            current is ThrowExpression) {
          return; // Has some form of validation
        }
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      // Check if immediately null-asserted without check (dangerous)
      final AstNode? parent = node.parent;
      if (parent is PostfixExpression && parent.operator.lexeme == '!') {
        reporter.atNode(node, code);
        return;
      }

      // Check if used directly in a dangerous context
      if (parent is MethodInvocation) {
        final String methodName = parent.methodName.name;
        if (methodName == 'parse' ||
            methodName == 'int' ||
            methodName == 'double' ||
            methodName == 'Uri') {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check for RouteSettings.arguments usage
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'arguments') return;

      final String targetSource = node.target?.toSource() ?? '';
      if (!targetSource.contains('settings') &&
          !targetSource.contains('route') &&
          !targetSource.contains('RouteSettings')) {
        return;
      }

      // Check if cast without validation
      final AstNode? parent = node.parent;
      if (parent is AsExpression) {
        // Check if there's validation nearby
        AstNode? current = parent.parent;
        while (current != null) {
          if (current is IfStatement || current is AssertStatement) {
            return; // Has some validation
          }
          if (current is MethodDeclaration || current is FunctionDeclaration) {
            break;
          }
          current = current.parent;
        }
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDeepLinkValidationFix()];
}

class _AddDeepLinkValidationFix extends DartFix {
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
        message: 'Add HACK: Validate deep link parameter',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Validate this deep link parameter before use\n',
        );
      });
    });
  }
}

/// Warns when sensitive data is stored without encryption.
///
/// Sensitive data (PII, financial, health) must be encrypted at rest.
/// Use AES-256 or platform encryption APIs, not custom schemes.
///
/// **BAD:**
/// ```dart
/// await prefs.setString('credit_card', cardNumber);
/// await file.writeAsString(jsonEncode(userProfile));
/// box.put('ssn', socialSecurityNumber);
/// ```
///
/// **GOOD:**
/// ```dart
/// await secureStorage.write(key: 'credit_card', value: cardNumber);
/// await encryptedBox.put('ssn', socialSecurityNumber);
/// final encrypted = await encrypter.encrypt(data);
/// await file.writeAsBytes(encrypted);
/// ```
class RequireDataEncryptionRule extends SaropaLintRule {
  const RequireDataEncryptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_data_encryption',
    problemMessage:
        '[require_data_encryption] Sensitive data stored without encryption. Use secure storage.',
    correctionMessage:
        'Use flutter_secure_storage, encrypted Hive box, or AES encryption.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitiveKeywords = {
    'password',
    'passwd',
    'secret',
    'token',
    'api_key',
    'apikey',
    'credit',
    'card',
    'ssn',
    'social_security',
    'bank',
    'account_number',
    'pin',
    'cvv',
    'auth',
    'credential',
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

      // Check for storage write operations
      if (methodName != 'setString' &&
          methodName != 'put' &&
          methodName != 'write' &&
          methodName != 'writeAsString' &&
          methodName != 'writeAsBytes' &&
          methodName != 'insert') {
        return;
      }

      // Check if target is secure storage (allowed)
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        if (targetSource.contains('secure') ||
            targetSource.contains('encrypt') ||
            targetSource.contains('encryptedbox')) {
          return; // Using secure storage
        }
      }

      // Check if key/value contains sensitive data
      final String nodeSource = node.toSource().toLowerCase();

      for (final String keyword in _sensitiveKeywords) {
        if (nodeSource.contains(keyword)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when sensitive data is displayed without masking.
///
/// Sensitive data (SSN, credit cards, passwords) should be partially masked
/// when displayed to prevent shoulder surfing.
///
/// **BAD:**
/// ```dart
/// Text(creditCardNumber); // Shows full number
/// Text(socialSecurityNumber);
/// Text(user.phoneNumber);
/// ```
///
/// **GOOD:**
/// ```dart
/// Text('****-****-****-${creditCardNumber.substring(12)}'); // Show last 4
/// Text('***-**-${ssn.substring(7)}');
/// Text(maskPhoneNumber(user.phoneNumber)); // Custom masking
/// ```
class PreferDataMaskingRule extends SaropaLintRule {
  const PreferDataMaskingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_data_masking',
    problemMessage:
        '[prefer_data_masking] Sensitive data displayed without masking. Consider partial masking.',
    correctionMessage:
        'Mask sensitive data: "****-****-****-1234" instead of full number.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _sensitivePatterns = {
    'creditcard',
    'credit_card',
    'cardnumber',
    'card_number',
    'ssn',
    'socialsecurity',
    'social_security',
    'accountnumber',
    'account_number',
    'routingnumber',
    'routing_number',
    'phonenumber',
    'phone_number',
    'taxid',
    'tax_id',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for Text widgets
      if (typeName != 'Text' && typeName != 'SelectableText') return;

      final String nodeSource = node.toSource().toLowerCase();

      // Check if displaying sensitive data
      for (final String pattern in _sensitivePatterns) {
        if (nodeSource.contains(pattern)) {
          // Check if already masked
          if (nodeSource.contains('mask') ||
              nodeSource.contains('****') ||
              nodeSource.contains('•••') ||
              nodeSource.contains('substring')) {
            return; // Already masked
          }

          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when sensitive screens don't disable screenshots.
///
/// Financial and authentication screens should disable screenshots using
/// platform APIs to prevent sensitive data exposure.
///
/// **BAD:**
/// ```dart
/// class PaymentScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(...); // No screenshot protection
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class PaymentScreen extends StatefulWidget {
///   @override
///   void initState() {
///     super.initState();
///     FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
///   }
///
///   @override
///   void dispose() {
///     FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
///     super.dispose();
///   }
/// }
/// ```
class AvoidScreenshotSensitiveRule extends SaropaLintRule {
  const AvoidScreenshotSensitiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_screenshot_sensitive',
    problemMessage:
        '[avoid_screenshot_sensitive] Sensitive screen without screenshot protection. Consider FLAG_SECURE.',
    correctionMessage:
        'Use FlutterWindowManager.addFlags(FLAG_SECURE) for sensitive screens.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _sensitiveScreenNames = {
    'payment',
    'checkout',
    'login',
    'signin',
    'signup',
    'password',
    'creditcard',
    'banking',
    'transfer',
    'auth',
    'otp',
    'verify',
    'pin',
    'biometric',
    'settings',
    'account',
    'profile',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Check if this looks like a sensitive screen
      bool isSensitive = false;
      for (final String pattern in _sensitiveScreenNames) {
        if (className.contains(pattern) &&
            (className.contains('screen') ||
                className.contains('page') ||
                className.contains('view') ||
                className.contains('widget'))) {
          isSensitive = true;
          break;
        }
      }

      if (!isSensitive) return;

      // Check if has screenshot protection
      final String classSource = node.toSource();
      if (classSource.contains('FLAG_SECURE') ||
          classSource.contains('WindowManager') ||
          classSource.contains('secureFlag') ||
          classSource.contains('screenshot') ||
          classSource.contains('Screenshot')) {
        return; // Has protection
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when password fields don't use secure keyboard settings.
///
/// Password fields should use secure text entry to disable keyboard
/// autocomplete, suggestions, and clipboard history.
///
/// **BAD:**
/// ```dart
/// TextField(
///   controller: passwordController,
///   obscureText: true,
///   // Missing security settings
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   controller: passwordController,
///   obscureText: true,
///   enableSuggestions: false,
///   autocorrect: false,
///   keyboardType: TextInputType.visiblePassword,
/// )
/// ```
class RequireSecurePasswordFieldRule extends SaropaLintRule {
  const RequireSecurePasswordFieldRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_secure_password_field',
    problemMessage:
        '[require_secure_password_field] Password field missing secure keyboard settings.',
    correctionMessage:
        'Add enableSuggestions: false and autocorrect: false for passwords.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'TextField' &&
          typeName != 'TextFormField' &&
          typeName != 'CupertinoTextField') {
        return;
      }

      final String nodeSource = node.toSource();

      // Check if this is a password field
      if (!nodeSource.contains('obscureText: true') &&
          !nodeSource.contains('obscureText:true')) {
        return; // Not a password field
      }

      // Check for secure keyboard settings
      final bool hasEnableSuggestions =
          nodeSource.contains('enableSuggestions: false');
      final bool hasAutocorrect = nodeSource.contains('autocorrect: false');

      if (!hasEnableSuggestions || !hasAutocorrect) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSecureKeyboardSettingsFix()];
}

class _AddSecureKeyboardSettingsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'TextField' &&
          typeName != 'TextFormField' &&
          typeName != 'CupertinoTextField') {
        return;
      }

      final String nodeSource = node.toSource();
      final bool hasEnableSuggestions =
          nodeSource.contains('enableSuggestions: false');
      final bool hasAutocorrect = nodeSource.contains('autocorrect: false');

      if (hasEnableSuggestions && hasAutocorrect) return;

      // Build the properties to add
      final List<String> propsToAdd = <String>[];
      if (!hasEnableSuggestions) propsToAdd.add('enableSuggestions: false');
      if (!hasAutocorrect) propsToAdd.add('autocorrect: false');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add secure keyboard settings',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the last named argument to insert after
        final ArgumentList args = node.argumentList;
        if (args.arguments.isEmpty) return;

        final Expression lastArg = args.arguments.last;
        final String insertion = ', ${propsToAdd.join(', ')}';

        builder.addSimpleInsertion(lastArg.end, insertion);
      });
    });
  }
}

/// Warns when file paths from user input might allow path traversal.
///
/// File paths like `../../../etc/passwd` can access arbitrary files.
/// Sanitize paths and validate they stay within allowed directories.
///
/// **BAD:**
/// ```dart
/// Future<String> readFile(String userPath) async {
///   final file = File('/data/$userPath');
///   return file.readAsString();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String> readFile(String userPath) async {
///   // Sanitize path
///   final sanitized = path.basename(userPath);
///   if (sanitized != userPath || userPath.contains('..')) {
///     throw SecurityException('Invalid path');
///   }
///   final file = File('/data/$sanitized');
///   final resolved = file.resolveSymbolicLinksSync();
///   if (!resolved.startsWith('/data/')) {
///     throw SecurityException('Path outside allowed directory');
///   }
///   return file.readAsString();
/// }
/// ```
class AvoidPathTraversalRule extends SaropaLintRule {
  const AvoidPathTraversalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_path_traversal',
    problemMessage:
        '[avoid_path_traversal] File path may be vulnerable to path traversal attack.',
    correctionMessage:
        'Validate paths: check for "..", use basename, verify resolved path.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for File/Directory creation
      if (typeName != 'File' && typeName != 'Directory') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      final String argSource = firstArg.toSource();

      // Check if path uses string interpolation with variable
      if (argSource.contains(r'$') || argSource.contains('+')) {
        // Path includes dynamic content

        // Check if there's nearby validation
        AstNode? current = node.parent;
        bool hasValidation = false;

        while (current != null) {
          final String source = current.toSource();

          // Check for path traversal validation patterns
          if (source.contains('..') &&
              (source.contains('throw') || source.contains('return'))) {
            hasValidation = true;
            break;
          }
          if (source.contains('basename') ||
              source.contains('resolveSymbolicLinks') ||
              source.contains('startsWith') ||
              source.contains('sanitize') ||
              source.contains('validate')) {
            hasValidation = true;
            break;
          }

          if (current is MethodDeclaration || current is FunctionDeclaration) {
            break;
          }
          current = current.parent;
        }

        if (!hasValidation) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when user content is displayed in WebViews without HTML escaping.
///
/// User content displayed in WebViews must be HTML-escaped to prevent XSS
/// attacks. Use html.escape() or sanitization libraries.
///
/// **BAD:**
/// ```dart
/// WebView(
///   initialUrl: 'data:text/html,<html><body>$userComment</body></html>',
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'dart:convert' show htmlEscape;
///
/// WebView(
///   initialUrl: 'data:text/html,<html><body>${htmlEscape.convert(userComment)}</body></html>',
/// )
///
/// // Or use a sanitization library
/// final sanitized = sanitizeHtml(userComment);
/// ```
class PreferHtmlEscapeRule extends SaropaLintRule {
  const PreferHtmlEscapeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_html_escape',
    problemMessage:
        '[prefer_html_escape] User content in WebView without HTML escaping. XSS vulnerability.',
    correctionMessage:
        'Use htmlEscape.convert() or a sanitization library for user content.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for WebView widgets
      if (typeName != 'WebView' &&
          typeName != 'WebViewWidget' &&
          typeName != 'InAppWebView') {
        return;
      }

      final String nodeSource = node.toSource();

      // Check for data URL with HTML content
      if (!nodeSource.contains('data:text/html') &&
          !nodeSource.contains('loadHtml') &&
          !nodeSource.contains('loadData')) {
        return;
      }

      // Check if content has interpolation (user content)
      if (nodeSource.contains(r'$')) {
        // Check for escaping/sanitization
        if (nodeSource.contains('htmlEscape') ||
            nodeSource.contains('sanitize') ||
            nodeSource.contains('escape') ||
            nodeSource.contains('HtmlUnescape')) {
          return; // Has escaping
        }

        reporter.atNode(node, code);
      }
    });

    // Also check for direct loadHtml calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'loadHtml' &&
          methodName != 'loadHtmlString' &&
          methodName != 'loadData') {
        return;
      }

      final String nodeSource = node.toSource();

      // Check for interpolation without escaping
      if (nodeSource.contains(r'$') &&
          !nodeSource.contains('htmlEscape') &&
          !nodeSource.contains('sanitize') &&
          !nodeSource.contains('escape')) {
        reporter.atNode(node, code);
      }
    });
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
///
/// **Quick fix available:** Comments out the log statement for review.
class AvoidSensitiveDataInLogsRule extends SaropaLintRule {
  const AvoidSensitiveDataInLogsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_sensitive_data_in_logs',
    problemMessage:
        '[avoid_sensitive_data_in_logs] Sensitive data in logs creates security risks.',
    correctionMessage:
        'Remove sensitive data or log only non-sensitive metadata.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // cspell:disable
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
  // cspell:enable

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

  /// Pre-compiled regex patterns for each sensitive name.
  /// Pattern 1: $password at word boundary (not inside braces)
  /// Pattern 2: ${password} with ONLY the variable name inside braces
  static final Map<String, (RegExp, RegExp)> _sensitivePatterns = {
    for (final String name in _sensitiveNames)
      name: (
        RegExp(r'\$' + RegExp.escape(name) + r'(?![a-z0-9_\{])'),
        RegExp(r'\$\{\s*' + RegExp.escape(name) + r'\s*\}'),
      ),
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

  /// Checks if the argument contains direct interpolation of sensitive data.
  /// Only flags patterns that actually expose the value:
  /// - `$password` (direct interpolation)
  /// - `${password}` (braced direct interpolation)
  ///
  /// Does NOT flag expressions that don't expose the value:
  /// - `${password != null}` (null check)
  /// - `${password.length}` (property access)
  /// - `${password?.isEmpty}` (null-safe method call)
  bool _containsSensitiveData(Expression arg) {
    final String source = arg.toSource().toLowerCase();
    for (final patterns in _sensitivePatterns.values) {
      final (directPattern, bracedPattern) = patterns;
      if (directPattern.hasMatch(source) || bracedPattern.hasMatch(source)) {
        return true;
      }
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutSensitiveLogFix()];
}

class _CommentOutSensitiveLogFix extends DartFix {
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

      // Find the statement containing this method invocation
      AstNode? current = node;
      while (current != null && current is! Statement) {
        current = current.parent;
      }
      if (current == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out sensitive log statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          current!.sourceRange,
          '// SECURITY: ${current.toSource()}',
        );
      });
    });

    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      AstNode? current = node;
      while (current != null && current is! Statement) {
        current = current.parent;
      }
      if (current == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out sensitive log statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          current!.sourceRange,
          '// SECURITY: ${current.toSource()}',
        );
      });
    });
  }
}

// =============================================================================
// Part 5 Rules: Package-Specific Security Rules
// =============================================================================

/// Warns when sensitive data is stored in SharedPreferences.
///
/// SharedPreferences stores data unencrypted on disk, making it readable
/// to anyone with device access or app data backup.
///
/// **BAD:**
/// ```dart
/// prefs.setString('password', userPassword);
/// prefs.setString('auth_token', jwt);
/// prefs.setString('api_key', apiKey);
/// ```
///
/// **GOOD:**
/// ```dart
/// await secureStorage.write(key: 'password', value: userPassword);
/// await secureStorage.write(key: 'auth_token', value: jwt);
/// ```
class AvoidSharedPrefsSensitiveDataRule extends SaropaLintRule {
  const AvoidSharedPrefsSensitiveDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_shared_prefs_sensitive_data',
    problemMessage:
        '[avoid_shared_prefs_sensitive_data] Storing sensitive data in SharedPreferences. Data is unencrypted.',
    correctionMessage:
        'Use flutter_secure_storage for passwords, tokens, and API keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'passwd',
    'token',
    'auth_token',
    'authtoken',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'api_key',
    'apikey',
    'secret',
    'private_key',
    'privatekey',
    'credential',
    'jwt',
    'bearer',
    'session_id',
    'sessionid',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check SharedPreferences setter methods
      if (!methodName.startsWith('set')) return;

      // Check if it's on SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') &&
          !targetSource.contains('sharedpreferences')) {
        return;
      }

      // Check first argument (key) for sensitive patterns
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression keyArg = args.first;
      final String keySource = keyArg.toSource().toLowerCase();

      for (final String sensitiveKey in _sensitiveKeys) {
        if (keySource.contains(sensitiveKey)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseSecureStorageFix()];
}

class _UseSecureStorageFix extends DartFix {
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
        message: 'Add HACK: Use flutter_secure_storage',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Replace with FlutterSecureStorage().write()\n',
        );
      });
    });
  }
}

/// Warns when authentication tokens are stored in SharedPreferences instead
/// of flutter_secure_storage.
///
/// This rule complements `avoid_shared_prefs_sensitive_data` by specifically
/// checking for auth token patterns in the VALUE being stored, not just the key.
/// This catches cases where the key is generic but the value is clearly auth data.
///
/// **BAD:**
/// ```dart
/// prefs.setString('data', jwtToken);  // Value contains auth token
/// prefs.setString('user', bearerToken);
/// ```
///
/// **GOOD:**
/// ```dart
/// await FlutterSecureStorage().write(key: 'auth', value: jwtToken);
/// ```
class RequireSecureStorageForAuthRule extends SaropaLintRule {
  const RequireSecureStorageForAuthRule() : super(code: _code);

  /// Storing auth tokens in SharedPreferences exposes credentials.
  /// Critical security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_secure_storage_for_auth',
    problemMessage:
        '[require_secure_storage_for_auth] Auth token stored in SharedPreferences. Use flutter_secure_storage.',
    correctionMessage:
        'Use FlutterSecureStorage for JWT, bearer tokens, and auth credentials.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Auth-specific patterns to check in VALUE (not key).
  /// Key-based detection is handled by `avoid_shared_prefs_sensitive_data`.
  static const Set<String> _authValuePatterns = <String>{
    'jwt',
    'bearer',
    'accesstoken',
    'access_token',
    'refreshtoken',
    'refresh_token',
    'idtoken',
    'id_token',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'setString') return;

      // Check if it's SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetType = target.staticType?.toString() ?? '';
      final String targetSource = target.toSource().toLowerCase();

      final bool isPrefs = targetType.contains('SharedPreferences') ||
          targetSource.contains('pref') ||
          targetSource.contains('sharedpreferences');

      if (!isPrefs) return;

      // Check VALUE argument for auth patterns (key is checked by other rule)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) return;

      final String valueSource = args[1].toSource().toLowerCase();

      for (final String pattern in _authValuePatterns) {
        if (valueSource.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when SharedPreferences getter results are used without null handling.
///
/// SharedPreferences getters return null when the key doesn't exist.
/// Using the result without null handling causes crashes.
///
/// **BAD:**
/// ```dart
/// final String name = prefs.getString('name')!;
/// final int count = prefs.getInt('count') ?? 0;  // Good, but detect the first case
/// ```
///
/// **GOOD:**
/// ```dart
/// final String? name = prefs.getString('name');
/// final String name = prefs.getString('name') ?? 'default';
/// ```
class RequireSharedPrefsNullHandlingRule extends SaropaLintRule {
  const RequireSharedPrefsNullHandlingRule() : super(code: _code);

  /// Null assertion on SharedPreferences getter causes runtime crash
  /// when key doesn't exist - a common source of production crashes.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_shared_prefs_null_handling',
    problemMessage:
        '[require_shared_prefs_null_handling] SharedPreferences getter used with null assertion. Returns null if key missing.',
    correctionMessage:
        'Use null-aware operator (??) with a default value, or handle nullable type.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _getterMethods = <String>{
    'getString',
    'getInt',
    'getDouble',
    'getBool',
    'getStringList',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPostfixExpression((PostfixExpression node) {
      // Check for ! operator
      if (node.operator.lexeme != '!') return;

      final Expression operand = node.operand;
      if (operand is! MethodInvocation) return;

      final String methodName = operand.methodName.name;
      if (!_getterMethods.contains(methodName)) return;

      // Check if it's SharedPreferences
      final Expression? target = operand.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (targetSource.contains('pref') ||
          targetSource.contains('sharedpreferences')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when string literals are used as SharedPreferences keys.
///
/// Using string literals for keys is error-prone and makes refactoring difficult.
/// Define keys as constants for type safety and easier maintenance.
///
/// **BAD:**
/// ```dart
/// prefs.getString('user_name');
/// prefs.setInt('login_count', count);
/// ```
///
/// **GOOD:**
/// ```dart
/// static const String kUserName = 'user_name';
/// prefs.getString(kUserName);
/// prefs.setInt(PrefsKeys.loginCount, count);
/// ```
class RequireSharedPrefsKeyConstantsRule extends SaropaLintRule {
  const RequireSharedPrefsKeyConstantsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_shared_prefs_key_constants',
    problemMessage:
        '[require_shared_prefs_key_constants] String literal used as SharedPreferences key. Use named constants.',
    correctionMessage:
        'Define keys as constants (e.g., static const kUserName = "user_name").',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _prefsMethods = <String>{
    'getString',
    'getInt',
    'getDouble',
    'getBool',
    'getStringList',
    'setString',
    'setInt',
    'setDouble',
    'setBool',
    'setStringList',
    'remove',
    'containsKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_prefsMethods.contains(methodName)) return;

      // Check if it's SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') &&
          !targetSource.contains('sharedpreferences')) {
        return;
      }

      // Check first argument for string literal
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression keyArg = args.first;
      if (keyArg is SimpleStringLiteral || keyArg is AdjacentStrings) {
        reporter.atNode(keyArg, code);
      }
    });
  }
}

/// Warns when Uri.parse is used on user input without scheme validation.
///
/// Parsing URLs from user input without validation can lead to
/// security issues like SSRF or accessing unintended protocols.
///
/// **BAD:**
/// ```dart
/// final url = Uri.parse(userInput);
/// http.get(url);
/// ```
///
/// **GOOD:**
/// ```dart
/// final url = Uri.parse(userInput);
/// if (url.scheme != 'https') {
///   throw SecurityException('Only HTTPS allowed');
/// }
/// http.get(url);
/// ```
class RequireUrlValidationRule extends SaropaLintRule {
  const RequireUrlValidationRule() : super(code: _code);

  /// Security vulnerability - unvalidated URLs can be exploited.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_url_validation',
    problemMessage:
        '[require_url_validation] Uri.parse on variable without scheme validation. Potential SSRF risk.',
    correctionMessage:
        'Validate url.scheme is https/http before making requests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check for Uri.parse
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Uri') {
        return;
      }

      if (node.methodName.name != 'parse') {
        return;
      }

      // Check if argument is a variable (not a literal)
      final args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }

      final urlArg = args.first;

      // Skip string literals - they're static URLs
      if (urlArg is StringLiteral) {
        return;
      }

      // Find enclosing method/function
      AstNode? current = node.parent;
      Block? enclosingBlock;

      while (current != null) {
        if (current is Block) {
          enclosingBlock = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBlock == null) {
        return;
      }

      // Check if there's a scheme validation in the same block
      final blockSource = enclosingBlock.toSource();
      if (blockSource.contains('.scheme') &&
          (blockSource.contains('https') || blockSource.contains('http'))) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when redirect URL is taken from parameter without domain validation.
///
/// Open redirects can be used for phishing attacks. Always validate
/// redirect URLs against an allowlist of trusted domains.
///
/// **Quick fix available:** Adds a `// ignore:` comment for manual domain validation.
///
/// **BAD:**
/// ```dart
/// void handleRedirect(String redirectUrl) {
///   Navigator.of(context).pushNamed(redirectUrl);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void handleRedirect(String redirectUrl) {
///   final uri = Uri.parse(redirectUrl);
///   if (!trustedDomains.contains(uri.host)) {
///     throw SecurityException('Untrusted redirect domain');
///   }
///   Navigator.of(context).pushNamed(redirectUrl);
/// }
/// ```
class AvoidRedirectInjectionRule extends SaropaLintRule {
  const AvoidRedirectInjectionRule() : super(code: _code);

  /// Security vulnerability - open redirects enable phishing.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'avoid_redirect_injection',
    problemMessage:
        '[avoid_redirect_injection] Redirect URL from parameter without domain validation. Open redirect risk.',
    correctionMessage:
        'Validate redirect URL host against trusted domains allowlist.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _redirectTerms = [
    'redirect',
    'returnurl',
    'return_url',
    'next',
    'callback',
    'goto',
    'target',
    'destination',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name.toLowerCase();

      // Check for navigation methods
      if (!methodName.contains('push') &&
          !methodName.contains('navigate') &&
          !methodName.contains('go') &&
          methodName != 'launch' &&
          methodName != 'launchurl') {
        return;
      }

      // Check arguments for redirect-related variable names
      for (final arg in node.argumentList.arguments) {
        // Get the actual expression (unwrap NamedExpression if needed)
        final Expression actualArg =
            arg is NamedExpression ? arg.expression : arg;

        // Skip property access on typed objects (e.g., item.destination)
        // Even though item.destination has type String, the source is a typed
        // object property which is less likely to be user-controlled injection
        if (actualArg is PropertyAccess || actualArg is PrefixedIdentifier) {
          continue;
        }

        // Only flag String or Uri types - not object types like AppGridMenuItem
        final argType = actualArg.staticType;

        // If type is resolved, check if it's a URL-like type
        if (argType != null) {
          final typeName = argType.getDisplayString();

          // Skip custom object types (start with uppercase, not String/Uri/dynamic)
          final isCustomType = typeName.isNotEmpty &&
              typeName[0].toUpperCase() == typeName[0] &&
              !typeName.startsWith('String') &&
              !typeName.startsWith('Uri') &&
              typeName != 'dynamic' &&
              typeName != 'Object' &&
              typeName != 'Object?';

          if (isCustomType) {
            continue;
          }

          // Also skip obvious non-URL primitive types
          final isUrlType = typeName == 'String' ||
              typeName == 'String?' ||
              typeName == 'Uri' ||
              typeName == 'Uri?' ||
              typeName == 'dynamic';

          if (!isUrlType) {
            continue;
          }
        }
        // If type is null (unresolved) and not property access, continue checking
        // The property access case is already handled above

        final argSource = arg.toSource().toLowerCase();

        // Check if argument name suggests redirect
        final isRedirectRelated =
            _redirectTerms.any((term) => argSource.contains(term));

        if (!isRedirectRelated) {
          continue;
        }

        // Skip if there's validation nearby
        AstNode? current = node.parent;
        Block? enclosingBlock;

        while (current != null) {
          if (current is Block) {
            enclosingBlock = current;
            break;
          }
          current = current.parent;
        }

        if (enclosingBlock != null) {
          final blockSource = enclosingBlock.toSource().toLowerCase();
          if (blockSource.contains('.host') ||
              blockSource.contains('.authority') ||
              blockSource.contains('allowlist') ||
              blockSource.contains('whitelist') ||
              blockSource.contains('trusted')) {
            continue;
          }
        }

        reporter.atNode(arg, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddRedirectValidationCommentFix()];
}

class _AddRedirectValidationCommentFix extends DartFix {
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

      // Find the statement containing this invocation
      AstNode? current = node;
      while (current != null && current is! ExpressionStatement) {
        current = current.parent;
      }
      if (current == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add domain validation comment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          current!.offset,
          '// HACK: Validate redirect URL host against trusted domains allowlist\n    ',
        );
      });
    });
  }
}

/// Warns when sensitive data is written to external storage.
///
/// External storage is accessible by other apps and users. Sensitive
/// data should be stored in app-private directories or encrypted.
///
/// **BAD:**
/// ```dart
/// final dir = await getExternalStorageDirectory();
/// File('${dir.path}/user_credentials.json').writeAsString(creds);
/// ```
///
/// **GOOD:**
/// ```dart
/// final dir = await getApplicationDocumentsDirectory();
/// File('${dir.path}/user_credentials.json').writeAsString(creds);
/// ```
///
/// **ALSO GOOD (if external needed):**
/// ```dart
/// final dir = await getExternalStorageDirectory();
/// final encrypted = await encrypt(creds);
/// File('${dir.path}/data.enc').writeAsString(encrypted);
/// ```
class AvoidExternalStorageSensitiveRule extends SaropaLintRule {
  const AvoidExternalStorageSensitiveRule() : super(code: _code);

  /// Security vulnerability - sensitive data exposed.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_external_storage_sensitive',
    problemMessage:
        '[avoid_external_storage_sensitive] Sensitive data written to external storage. Accessible by other apps.',
    correctionMessage:
        'Use getApplicationDocumentsDirectory() or encrypt data first.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _sensitiveTerms = [
    'credential',
    'password',
    'token',
    'secret',
    'private',
    'auth',
    'session',
    'api_key',
    'apikey',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;

      // Check for file write methods
      if (methodName != 'writeAsString' &&
          methodName != 'writeAsBytes' &&
          methodName != 'writeAsStringSync' &&
          methodName != 'writeAsBytesSync') {
        return;
      }

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) {
        return;
      }

      final methodSource = enclosingMethod.toSource().toLowerCase();

      // Check if using external storage
      if (!methodSource.contains('getexternalstoragedirectory') &&
          !methodSource.contains('external')) {
        return;
      }

      // Check if writing sensitive data
      final writeDataSource = node.argumentList.arguments.isNotEmpty
          ? node.argumentList.arguments.first.toSource().toLowerCase()
          : '';

      final isSensitive =
          _sensitiveTerms.any((term) => writeDataSource.contains(term));

      // Also check the file path
      final filePathSource = node.target?.toSource().toLowerCase() ?? '';
      final pathSensitive =
          _sensitiveTerms.any((term) => filePathSource.contains(term));

      if (isSensitive || pathSensitive) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when payment or sensitive operations lack biometric authentication.
///
/// Critical operations like payments should require additional authentication
/// to prevent unauthorized access even if the device is unlocked.
///
/// **BAD:**
/// ```dart
/// void processPayment(PaymentDetails details) async {
///   await paymentApi.charge(details);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processPayment(PaymentDetails details) async {
///   final authenticated = await LocalAuthentication().authenticate(
///     localizedReason: 'Confirm payment',
///   );
///   if (!authenticated) return;
///   await paymentApi.charge(details);
/// }
/// ```
class PreferLocalAuthRule extends SaropaLintRule {
  const PreferLocalAuthRule() : super(code: _code);

  /// Security best practice for sensitive operations.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_local_auth',
    problemMessage:
        '[prefer_local_auth] Payment/sensitive operation without biometric authentication.',
    correctionMessage:
        'Add LocalAuthentication().authenticate() before sensitive operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const _sensitiveOperations = [
    'payment',
    'charge',
    'transfer',
    'withdraw',
    'delete_account',
    'deleteaccount',
    'change_password',
    'changepassword',
    'export',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      final methodName = node.name.lexeme.toLowerCase();

      // Check if method name suggests sensitive operation
      final isSensitive =
          _sensitiveOperations.any((op) => methodName.contains(op));

      if (!isSensitive) {
        return;
      }

      final methodSource = node.toSource().toLowerCase();

      // Check if authentication is present
      if (methodSource.contains('localauthentication') ||
          methodSource.contains('authenticate') ||
          methodSource.contains('biometric') ||
          methodSource.contains('fingerprint') ||
          methodSource.contains('faceid')) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// Part 6: Additional Security Rules
// =============================================================================

/// Warns when JWT/auth tokens are stored in SharedPreferences.
///
/// Alias: insecure_token_storage, shared_prefs_auth_data
///
/// SharedPreferences is not encrypted. Auth tokens should use
/// flutter_secure_storage which encrypts data at rest.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// await prefs.setString('jwt', token);  // Unencrypted!
/// await prefs.setString('access_token', token);
/// ```
///
/// **GOOD:**
/// ```dart
/// final storage = FlutterSecureStorage();
/// await storage.write(key: 'jwt', value: token);  // Encrypted
/// ```
class RequireSecureStorageAuthDataRule extends SaropaLintRule {
  const RequireSecureStorageAuthDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_secure_storage_auth_data',
    problemMessage:
        '[require_secure_storage_auth_data] Auth tokens in SharedPreferences are insecure. Use FlutterSecureStorage.',
    correctionMessage:
        'Replace SharedPreferences with FlutterSecureStorage for sensitive data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitiveKeys = <String>{
    'jwt',
    'token',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'auth_token',
    'authtoken',
    'api_key',
    'apikey',
    'secret',
    'password',
    'session',
    'bearer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for SharedPreferences set methods
      final methodName = node.methodName.name;
      if (methodName != 'setString' && methodName != 'setStringList') return;

      // Check target is SharedPreferences-like
      final target = node.target;
      if (target == null) return;
      final targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('prefs') &&
          !targetSource.contains('sharedpreferences') &&
          !targetSource.contains('preferences')) {
        return;
      }

      // Check if key is sensitive
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      String? keyValue;
      final firstArg = args.first;
      if (firstArg is SimpleStringLiteral) {
        keyValue = firstArg.value.toLowerCase();
      } else if (firstArg is StringInterpolation) {
        keyValue = firstArg.toSource().toLowerCase();
      }

      if (keyValue != null) {
        for (final sensitiveKey in _sensitiveKeys) {
          if (keyValue.contains(sensitiveKey)) {
            reporter.atNode(node.methodName, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// WebView Security Rules
// =============================================================================

/// Warns when WebView is created without explicitly disabling JavaScript.
///
/// Many WebViews don't need JavaScript, and leaving it enabled increases
/// the attack surface for XSS vulnerabilities. Explicitly disable JavaScript
/// when it's not required.
///
/// **BAD:**
/// ```dart
/// WebView(initialUrl: 'https://example.com') // JS enabled by default!
///
/// InAppWebView(
///   initialSettings: InAppWebViewSettings(
///     javaScriptEnabled: true, // Explicitly enabling JS
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   javascriptMode: JavascriptMode.disabled, // Explicitly disabled
/// )
///
/// // Or if JS is needed, document why:
/// WebView(
///   initialUrl: trustedUrl, // Only trusted content
///   javascriptMode: JavascriptMode.unrestricted, // Required for X feature
///   navigationDelegate: validateNavigation, // With navigation validation
/// )
/// ```
class PreferWebViewJavaScriptDisabledRule extends SaropaLintRule {
  const PreferWebViewJavaScriptDisabledRule() : super(code: _code);

  /// JavaScript in WebView increases XSS attack surface.
  /// Review each occurrence for security implications.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_webview_javascript_disabled',
    problemMessage:
        '[prefer_webview_javascript_disabled] WebView without explicit JavaScript setting. Disable JS if not needed.',
    correctionMessage:
        'Add javascriptMode: JavascriptMode.disabled or javaScriptEnabled: false.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
    'WebViewX',
    'FlutterWebView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (!_webViewTypes.contains(typeName)) return;

      // Check for JavaScript-related parameters
      bool hasJavaScriptSetting = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name.toLowerCase();
          if (paramName == 'javascriptmode' ||
              paramName == 'javascriptenabled' ||
              paramName == 'javaScriptEnabled'.toLowerCase()) {
            hasJavaScriptSetting = true;
            break;
          }
          // Check for settings objects that might contain JS settings
          if (paramName == 'initialsettings' ||
              paramName == 'settings' ||
              paramName == 'options') {
            final String argSource = arg.expression.toSource().toLowerCase();
            if (argSource.contains('javascript')) {
              hasJavaScriptSetting = true;
              break;
            }
          }
        }
      }

      if (!hasJavaScriptSetting) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when WebView allows loading mixed (HTTP) content on HTTPS pages.
///
/// Loading insecure HTTP content in a secure HTTPS context bypasses
/// encryption and enables man-in-the-middle attacks.
///
/// **BAD:**
/// ```dart
/// InAppWebView(
///   initialSettings: InAppWebViewSettings(
///     mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
///   ),
/// )
///
/// AndroidWebViewController()
///   ..setJavaScriptMode(JavaScriptMode.unrestricted)
///   ..loadRequest(Uri.parse(url))
///   ..enableDebugging(true)
///   ..setMediaPlaybackRequiresUserGesture(true)
///   ..setBackgroundColor(Colors.white);
/// // Missing: setMixedContentMode
/// ```
///
/// **GOOD:**
/// ```dart
/// InAppWebView(
///   initialSettings: InAppWebViewSettings(
///     mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
///   ),
/// )
/// ```
class AvoidWebViewInsecureContentRule extends SaropaLintRule {
  const AvoidWebViewInsecureContentRule() : super(code: _code);

  /// Mixed content bypasses HTTPS encryption.
  /// Critical security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_webview_insecure_content',
    problemMessage:
        '[avoid_webview_insecure_content] WebView configured to allow mixed (insecure) content. Security risk.',
    correctionMessage:
        'Set mixedContentMode to MIXED_CONTENT_NEVER_ALLOW or never.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for InAppWebViewSettings or similar
      if (typeName != 'InAppWebViewSettings' &&
          typeName != 'AndroidInAppWebViewOptions' &&
          typeName != 'WebSettings') {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name.toLowerCase();
          if (paramName == 'mixedcontentmode') {
            final String value = arg.expression.toSource().toLowerCase();
            if (value.contains('always_allow') ||
                value.contains('alwaysallow') ||
                value.contains('compatibility_mode') ||
                value.contains('compatibilitymode')) {
              reporter.atNode(arg, code);
              return;
            }
          }
        }
      }
    });

    // Also check for method invocations
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      if (methodName == 'setmixedcontentmode' ||
          methodName == 'allowmixedcontent') {
        for (final Expression arg in node.argumentList.arguments) {
          final String argSource = arg.toSource().toLowerCase();
          if (argSource.contains('always') ||
              argSource.contains('compatibility')) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when WebView lacks error handling for resource loading failures.
///
/// WebViews can fail to load resources due to network issues, invalid URLs,
/// SSL errors, or blocked content. Without error handling, users see blank
/// pages or confusing behavior.
///
/// **BAD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
/// ) // No error handling!
///
/// InAppWebView(
///   initialUrlRequest: URLRequest(url: Uri.parse(url)),
/// ) // No onLoadError or onReceivedError
/// ```
///
/// **GOOD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   onWebResourceError: (error) {
///     showErrorDialog(error.description);
///   },
/// )
///
/// InAppWebView(
///   initialUrlRequest: URLRequest(url: Uri.parse(url)),
///   onLoadError: (controller, url, code, message) {
///     showErrorPage(message);
///   },
///   onReceivedError: (controller, request, error) {
///     handleError(error);
///   },
/// )
/// ```
class RequireWebViewErrorHandlingRule extends SaropaLintRule {
  const RequireWebViewErrorHandlingRule() : super(code: _code);

  /// Missing error handling creates poor UX on network failures.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_webview_error_handling',
    problemMessage:
        '[require_webview_error_handling] WebView without error handler. Network failures show blank page.',
    correctionMessage:
        'Add onWebResourceError, onLoadError, or onReceivedError callback.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
    'WebViewX',
  };

  static const Set<String> _errorHandlerParams = <String>{
    'onwebresourceerror',
    'onloaderror',
    'onreceivederror',
    'onreceivedservertrust',
    'onerror',
    'onhttperror',
    'onreceivedservererror',
    'onreceivedsslerror',
    'errorbuilder',
    'onpageerror',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (!_webViewTypes.contains(typeName)) return;

      // Check for error handling callbacks
      bool hasErrorHandler = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name.toLowerCase();
          if (_errorHandlerParams.contains(paramName)) {
            hasErrorHandler = true;
            break;
          }
        }
      }

      if (!hasErrorHandler) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when API keys appear to be hardcoded in source code.
///
/// Alias: hardcoded_api_key, api_key_in_source, secret_in_code
///
/// HEURISTIC: Detects string patterns that look like API keys.
/// May have false positives for non-sensitive keys.
///
/// **BAD:**
/// ```dart
/// const apiKey = 'sk_live_abc123xyz789';
/// final headers = {'X-API-Key': 'AIzaSyAbc123...'};
/// ```
///
/// **GOOD:**
/// ```dart
/// final apiKey = dotenv.get('API_KEY');
/// final headers = {'X-API-Key': Config.apiKey};
/// ```
class AvoidApiKeyInCodeRule extends SaropaLintRule {
  const AvoidApiKeyInCodeRule() : super(code: _code);

  /// Hardcoded API keys can be extracted from builds.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_api_key_in_code',
    problemMessage:
        '[avoid_api_key_in_code] Hardcoded API key detected. Keys in source code can be extracted from builds.',
    correctionMessage:
        'Use environment variables, secure storage, or build config to inject keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Patterns that indicate API key prefixes.
  static const List<String> _apiKeyPrefixes = <String>[
    'sk_live_',
    'sk_test_',
    'pk_live_',
    'pk_test_',
    'AIzaSy',
    'AKIA',
    'ghp_',
    'gho_',
    'glpat-',
    'xoxb-',
    'xoxp-',
    'sk-',
    'rk_live_',
    'rk_test_',
  ];

  /// Variable name patterns that suggest API keys.
  static const Set<String> _apiKeyNamePatterns = <String>{
    'apikey',
    'api_key',
    'apiKey',
    'secretkey',
    'secret_key',
    'secretKey',
    'accesskey',
    'access_key',
    'accessKey',
    'privatekey',
    'private_key',
    'privateKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final String varName = node.name.lexeme.toLowerCase();

      // Check if variable name suggests an API key
      final bool nameMatchesApiKey = _apiKeyNamePatterns.any(
        (pattern) => varName.contains(pattern),
      );

      if (!nameMatchesApiKey) return;

      // Check if value is a hardcoded string
      final Expression? initializer = node.initializer;
      if (initializer == null) return;

      if (initializer is SimpleStringLiteral) {
        final String value = initializer.value;
        // Check length to avoid false positives on short placeholder strings
        if (value.length >= 16) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check string literals with API key patterns
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      for (final String prefix in _apiKeyPrefixes) {
        if (value.startsWith(prefix) && value.length > prefix.length + 10) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when sensitive data is stored in unencrypted storage.
///
/// Alias: encrypt_sensitive_storage, secure_storage_required
///
/// Hive and SharedPreferences store data in plain files. Use encrypted
/// storage for tokens, passwords, and personal data.
///
/// **BAD:**
/// ```dart
/// await prefs.setString('auth_token', token);
/// await box.put('password', password);
/// ```
///
/// **GOOD:**
/// ```dart
/// await secureStorage.write(key: 'auth_token', value: token);
/// await encryptedBox.put('password', password);
/// ```
class AvoidStoringSensitiveUnencryptedRule extends SaropaLintRule {
  const AvoidStoringSensitiveUnencryptedRule() : super(code: _code);

  /// Unencrypted sensitive data is readable on rooted/jailbroken devices.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_storing_sensitive_unencrypted',
    problemMessage:
        '[avoid_storing_sensitive_unencrypted] Sensitive data stored without encryption. Data can be read on rooted devices.',
    correctionMessage:
        'Use flutter_secure_storage or an encrypted Hive box for sensitive data.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Keys that indicate sensitive data.
  static const Set<String> _sensitiveKeys = <String>{
    'token',
    'password',
    'secret',
    'credential',
    'auth',
    'session',
    'jwt',
    'refresh',
    'access_token',
    'api_key',
    'private_key',
    'pin',
    'biometric',
  };

  /// Storage methods that are not secure.
  static const Set<String> _unsecureMethods = <String>{
    'setString',
    'setInt',
    'setBool',
    'setDouble',
    'setStringList',
    'put',
    'add',
    'write',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_unsecureMethods.contains(methodName)) return;

      // Check target for SharedPreferences or Hive box
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      // Skip if using secure storage
      if (targetSource.contains('secure') ||
          targetSource.contains('encrypted')) {
        return;
      }

      // Check if it's SharedPreferences or Hive
      final bool isStorage = targetSource.contains('pref') ||
          targetSource.contains('box') ||
          targetSource.contains('storage');

      if (!isStorage) return;

      // Check the key argument for sensitive names
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      String? keyValue;

      if (firstArg is SimpleStringLiteral) {
        keyValue = firstArg.value.toLowerCase();
      } else if (firstArg is NamedExpression &&
          firstArg.expression is SimpleStringLiteral) {
        keyValue =
            (firstArg.expression as SimpleStringLiteral).value.toLowerCase();
      }

      if (keyValue != null) {
        for (final String sensitiveKey in _sensitiveKeys) {
          if (keyValue.contains(sensitiveKey)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

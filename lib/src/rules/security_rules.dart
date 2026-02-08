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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m6},
        web: <OwaspWeb>{OwaspWeb.a09},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_logging_sensitive_data',
    problemMessage:
        '[avoid_logging_sensitive_data] Logging sensitive data such as passwords, tokens, or personally identifiable information (PII) exposes users to privacy risks and can result in data leaks if logs are accessed by unauthorized parties. Sensitive information in logs may appear in crash reports, debug output, or be inadvertently shared with third parties, leading to compliance violations and loss of user trust. Always sanitize logs to prevent exposure of confidential data.',
    correctionMessage:
        'Remove all sensitive data (passwords, tokens, PII) from logs. Instead, log only non-sensitive metadata or a generic success/failure message. Use dedicated logging utilities to redact or filter sensitive fields before outputting logs.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'require_secure_storage',
    problemMessage:
        '[require_secure_storage] SharedPreferences stores data in plain XML. '
        'On rooted/jailbroken devices, attackers extract credentials for account takeover.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_credentials',
    problemMessage:
        '[avoid_hardcoded_credentials] Hardcoding credentials (such as passwords, API keys, or tokens) in source code exposes them to anyone with access to the codebase, including public repositories and version control history. This can lead to unauthorized access, data breaches, and compromised systems. Credentials should always be stored securely and never committed to version control.',
    correctionMessage:
        'Store credentials in secure storage or environment variables. Use String.fromEnvironment(\'KEY\') or a secure vault at runtime. Never commit secrets to source control.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'require_input_sanitization',
    problemMessage:
        '[require_input_sanitization] Unsanitized user input in SQL or commands '
        'enables injection attacks, allowing data theft or system compromise.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a05, OwaspWeb.a06},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_webview_javascript_enabled',
    problemMessage:
        '[avoid_webview_javascript_enabled] WebView with JavaScript enabled expands the attack surface to cross-site scripting (XSS) vulnerabilities. Malicious scripts injected through untrusted content can steal session tokens, access device APIs, redirect users to phishing pages, and exfiltrate sensitive data without the user\'s knowledge.',
    correctionMessage:
        'Disable JavaScript with javaScriptEnabled: false unless required, and ensure only trusted HTTPS content is loaded when JavaScript must remain enabled.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a04},
      );

  static const LintCode _code = LintCode(
    name: 'require_biometric_fallback',
    problemMessage:
        '[require_biometric_fallback] Biometric-only auth locks out users with damaged sensors. Not all devices support biometrics, and users must have an alternative authentication method.',
    correctionMessage:
        'Set biometricOnly to false or provide an alternative auth method. Audit similar patterns across the codebase to ensure consistent security practices.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4, OwaspMobile.m7},
        web: <OwaspWeb>{OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_eval_like_patterns',
    problemMessage:
        '[avoid_eval_like_patterns] Dynamic code execution allows arbitrary '
        'code injection, enabling attackers to execute malicious code.',
    correctionMessage:
        'Use static dispatch or explicit mappings instead of dynamic invocation.',
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

/// Warns when code is loaded dynamically at runtime, bypassing compile-time
/// dependency verification.
///
/// Dynamic code loading via `Isolate.spawnUri()` or runtime package management
/// commands allows execution of unverified code, creating supply chain attack
/// vectors. Attackers can inject malicious code through compromised URIs or
/// package sources.
///
/// **BAD:**
/// ```dart
/// // Loading code from a dynamic URI
/// await Isolate.spawnUri(Uri.parse(userUrl), [], null);
///
/// // Running package management at runtime
/// await Process.run('pub', ['get']);
/// await Process.run('flutter', ['pub', 'add', 'malicious_pkg']);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use static imports for all code dependencies
/// import 'package:myapp/worker.dart';
///
/// // Use Isolate.run for compute-heavy tasks
/// final result = await Isolate.run(() => heavyComputation());
///
/// // Use Isolate.spawn with static entry points
/// await Isolate.spawn(staticEntryPoint, message);
/// ```
///
/// **OWASP:** `M2:Inadequate-Supply-Chain-Security`
class AvoidDynamicCodeLoadingRule extends SaropaLintRule {
  const AvoidDynamicCodeLoadingRule() : super(code: _code);

  /// Runtime code loading enables supply chain attacks.
  /// Each occurrence is a critical security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m2},
      );

  @override
  Set<String>? get requiredPatterns => const <String>{'Isolate', 'Process'};

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_code_loading',
    problemMessage:
        '[avoid_dynamic_code_loading] Dynamic code loading at runtime '
        'bypasses compile-time dependency verification, allowing execution '
        'of unverified code and creating supply chain attack vectors.',
    correctionMessage:
        'Use static imports for all code dependencies. For background '
        'computation, use Isolate.run() or Isolate.spawn() with static '
        'entry points instead of Isolate.spawnUri().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Package manager executables to detect.
  static const Set<String> _packageManagers = <String>{
    'pub',
    'dart',
    'flutter',
    'npm',
    'npx',
    'yarn',
    'pnpm',
    'pip',
    'gem',
    'bundle',
    'cargo',
  };

  /// Package management subcommands that modify dependencies.
  static const Set<String> _installCommands = <String>{
    'get',
    'add',
    'install',
    'update',
    'upgrade',
    'pub',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();

      // Detect Isolate.spawnUri() - all calls are flagged
      if (methodName == 'spawnUri' && targetSource == 'Isolate') {
        reporter.atNode(node, code);
        return;
      }

      // Detect Process.run() / Process.start() with package management
      if ((methodName == 'run' || methodName == 'start') &&
          targetSource == 'Process') {
        _checkForPackageManagement(node, reporter);
      }
    });
  }

  void _checkForPackageManagement(
    MethodInvocation node,
    SaropaDiagnosticReporter reporter,
  ) {
    final NodeList<Expression> args = node.argumentList.arguments;
    if (args.isEmpty) return;

    final Expression firstArg = args.first;
    if (firstArg is! StringLiteral) return;

    final String? executable = firstArg.stringValue;
    if (executable == null) return;

    if (!_packageManagers.contains(executable)) return;

    // Check if second argument contains install-like commands
    if (args.length < 2) return;
    final Expression secondArg = args[1];
    if (secondArg is! ListLiteral) return;

    for (final CollectionElement element in secondArg.elements) {
      if (element is! Expression) continue;
      if (element is StringLiteral) {
        final String? value = element.stringValue;
        if (value != null && _installCommands.contains(value)) {
          reporter.atNode(node, code);
          return;
        }
      }
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForDynamicCodeLoadingFix()];
}

class _AddTodoForDynamicCodeLoadingFix extends DartFix {
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
        message: 'Add HACK comment for dynamic code loading',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the start of the statement
        AstNode? statement = node.parent;
        while (statement != null && statement is! ExpressionStatement) {
          statement = statement.parent;
        }
        final int offset = statement?.offset ?? node.offset;

        builder.addSimpleInsertion(
          offset,
          '// HACK: replace dynamic code loading with static imports\n',
        );
      });
    });
  }
}

/// Warns when native libraries are loaded from dynamic or absolute paths.
///
/// Loading native libraries via `DynamicLibrary.open()` with non-constant or
/// path-containing arguments bypasses Dart's package management, allowing
/// attackers to substitute malicious native libraries.
///
/// **BAD:**
/// ```dart
/// // Dynamic path - attacker can control library location
/// DynamicLibrary.open(userProvidedPath);
///
/// // Absolute path - can be replaced on compromised device
/// DynamicLibrary.open('/usr/lib/libcrypto.so');
///
/// // Relative path with directory traversal
/// DynamicLibrary.open('../libs/libfoo.dylib');
/// ```
///
/// **GOOD:**
/// ```dart
/// // Bundled library name - loaded from app package
/// DynamicLibrary.open('libfoo.dylib');
///
/// // Process library (current process)
/// DynamicLibrary.process();
///
/// // Executable library
/// DynamicLibrary.executable();
/// ```
///
/// **OWASP:** `M2:Inadequate-Supply-Chain-Security`
class AvoidUnverifiedNativeLibraryRule extends SaropaLintRule {
  const AvoidUnverifiedNativeLibraryRule() : super(code: _code);

  /// Loading unverified native code enables supply chain attacks.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m2},
      );

  @override
  Set<String>? get requiredPatterns => const <String>{'DynamicLibrary'};

  static const LintCode _code = LintCode(
    name: 'avoid_unverified_native_library',
    problemMessage:
        '[avoid_unverified_native_library] Loading native libraries from '
        'dynamic or absolute paths bypasses package verification, allowing '
        'attackers to substitute malicious native code.',
    correctionMessage:
        'Use library names without paths (e.g., \'libfoo.so\') to load '
        'from verified app bundle resources. Avoid loading from dynamic '
        'paths or user-provided locations.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'open') return;

      final Expression? target = node.target;
      if (target == null) return;
      if (target.toSource() != 'DynamicLibrary') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Non-constant argument (variable, interpolation, etc.)
      if (firstArg is! SimpleStringLiteral) {
        reporter.atNode(node, code);
        return;
      }

      // String literal with path separators or traversal
      final String value = firstArg.value;
      if (value.contains('/') || value.contains(r'\') || value.contains('..')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForUnverifiedNativeLibraryFix()];
}

class _AddTodoForUnverifiedNativeLibraryFix extends DartFix {
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
        message: 'Add HACK comment for unverified native library',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        AstNode? statement = node.parent;
        while (statement != null && statement is! ExpressionStatement) {
          statement = statement.parent;
        }
        final int offset = statement?.offset ?? node.offset;

        builder.addSimpleInsertion(
          offset,
          '// HACK: use bundled library name without path\n',
        );
      });
    });
  }
}

/// Warns when signing configuration (keystore paths, passwords, aliases)
/// is hardcoded in source code.
///
/// Hardcoded signing configuration is extractable from compiled binaries
/// via reverse engineering, enabling attackers to sign malicious builds
/// or access signing infrastructure.
///
/// **BAD:**
/// ```dart
/// const keystorePath = '/path/to/release.keystore';
/// const storePassword = 'mySecretPassword';
/// const keyAlias = 'upload';
/// final config = 'key.properties';
/// ```
///
/// **GOOD:**
/// ```dart
/// final keystorePath = Platform.environment['KEYSTORE_PATH'];
/// final storePassword = Platform.environment['STORE_PASSWORD'];
/// final keyAlias = Platform.environment['KEY_ALIAS'];
/// ```
///
/// **OWASP:** `M7:Insufficient-Binary-Protections`
class AvoidHardcodedSigningConfigRule extends SaropaLintRule {
  const AvoidHardcodedSigningConfigRule() : super(code: _code);

  /// Signing config in source code aids reverse engineering.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m7},
      );

  @override
  Set<String>? get requiredPatterns => const <String>{
        'keystore',
        'jks',
        'signing',
        'storePassword',
        'keyPassword',
        'keyAlias',
        'key.properties',
      };

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_signing_config',
    problemMessage:
        '[avoid_hardcoded_signing_config] Hardcoding keystore paths, '
        'passwords, or signing configuration in source code exposes them '
        'to reverse engineering. These values are extractable from compiled '
        'binaries and enable attackers to sign malicious builds.',
    correctionMessage:
        'Store signing configuration in environment variables or secure '
        'CI/CD secrets. Use Platform.environment or load from external '
        'configuration files excluded from version control.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns in string literals that indicate signing configuration.
  static const Set<String> _signingStringPatterns = <String>{
    '.keystore',
    '.jks',
    'key.properties',
    'signingconfig',
    'storepassword',
    'keypassword',
    'keyalias',
  };

  /// Variable name patterns that indicate signing configuration.
  ///
  /// Note: `storepassword` and `keypassword` are intentionally excluded
  /// because [AvoidHardcodedCredentialsRule] already detects any variable
  /// containing `password` at ERROR severity.
  static const Set<String> _signingVarPatterns = <String>{
    'keystore',
    'keystorepath',
    'keyalias',
    'signingconfig',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check string literals for signing-related content
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      // Skip import URIs
      if (node.parent is ImportDirective || node.parent is ExportDirective) {
        return;
      }

      final String lower = node.value.toLowerCase();
      for (final String pattern in _signingStringPatterns) {
        if (lower.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    // Check variable names with signing-related names assigned strings
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final String varName = node.name.lexeme.toLowerCase();

      final bool isSigningVar = _signingVarPatterns.any(varName.contains);
      if (!isSigningVar) return;

      final Expression? initializer = node.initializer;
      if (initializer is StringLiteral) {
        final String? value = initializer.stringValue;
        if (value != null && value.isNotEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForHardcodedSigningConfigFix()];
}

class _AddTodoForHardcodedSigningConfigFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add comment to use environment variable',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        AstNode? statement = node.parent;
        while (statement != null &&
            statement is! VariableDeclarationStatement &&
            statement is! ExpressionStatement) {
          statement = statement.parent;
        }
        final int offset = statement?.offset ?? node.offset;

        builder.addSimpleInsertion(
          offset,
          '// HACK: use Platform.environment or CI/CD secrets instead\n',
        );
      });
    });

    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add comment to use environment variable',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        AstNode? statement = node.parent?.parent;
        final int offset = statement?.offset ?? node.offset;

        builder.addSimpleInsertion(
          offset,
          '// HACK: use Platform.environment or CI/CD secrets instead\n',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m5},
        web: <OwaspWeb>{OwaspWeb.a02, OwaspWeb.a05},
      );

  static const LintCode _code = LintCode(
    name: 'require_certificate_pinning',
    problemMessage:
        '[require_certificate_pinning] HttpClient without certificate pinning accepts any valid certificate, making it vulnerable to man-in-the-middle attacks. Attackers on the same network can intercept, read, and modify all HTTPS traffic including authentication tokens, personal data, and financial information without detection.',
    correctionMessage:
        'Set badCertificateCallback to validate the server certificate fingerprint against a known pin, rejecting connections that do not match your expected certificate.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_token_in_url',
    problemMessage:
        '[avoid_token_in_url] Tokens in URLs are logged in browser history, '
        'server logs, and referrer headers, exposing credentials.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m6},
        web: <OwaspWeb>{OwaspWeb.a04},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_clipboard_sensitive',
    problemMessage:
        '[avoid_clipboard_sensitive] Clipboard contents persist and are '
        'readable by other apps, exposing passwords and tokens.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_storing_passwords',
    problemMessage:
        '[avoid_storing_passwords] SharedPreferences stores passwords in '
        'plaintext, readable by anyone with device access or backup.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_dynamic_sql',
    problemMessage:
        '[avoid_dynamic_sql] Constructing SQL queries by concatenating or interpolating user input directly into the query string exposes your application to SQL injection attacks. Attackers can craft input that alters the structure of your query, allowing them to read, modify, or delete arbitrary data, escalate privileges, or compromise the entire database. SQL injection is one of the most critical and well-documented security vulnerabilities in software development, and has led to major data breaches across industries.',
    correctionMessage:
        'Always use parameterized queries, prepared statements, or trusted query builders to safely insert user input into SQL queries. Never concatenate or interpolate user data directly into SQL strings. Audit your codebase for dynamic SQL construction and refactor to use safe patterns. Test your application for SQL injection vulnerabilities using automated tools or manual review. Document secure query practices in your team guidelines.',
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

/// Warns when generic key/auth parameters appear in URLs (pedantic tier).
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_generic_key_in_url',
    problemMessage:
        '[avoid_generic_key_in_url] Sensitive data embedded in URL query parameters is logged by web servers, proxy caches, browser history, and analytics tools. This exposes API keys, tokens, and credentials in access logs and referrer headers, where they persist indefinitely and can be harvested by attackers with log access.',
    correctionMessage:
        'Move sensitive parameters to the Authorization header or request body where they are not logged by intermediate network infrastructure.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_secure_random',
    problemMessage:
        '[prefer_secure_random] Random() uses a predictable pseudo-random number generator that produces reproducible sequences from a known seed. Tokens, passwords, encryption keys, or nonces generated with Random() can be predicted by attackers, enabling session hijacking, credential guessing, and cryptographic attacks.',
    correctionMessage:
        'Replace Random() with Random.secure() for security-sensitive operations such as token generation, password creation, nonce generation, and cryptographic key derivation.',
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
        '[prefer_typed_data] List<int> for binary data wastes memory. Use Uint8List instead. Uint8List is more memory-efficient for binary data and provides better interoperability with native code and I/O operations. List<int> uses 8 bytes per element vs 1 byte for Uint8List.',
    correctionMessage:
        'Use Uint8List for binary data - 8x more memory efficient. Audit similar patterns across the codebase to ensure consistent security practices.',
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
        '[avoid_unnecessary_to_list] .toList() may be unnecessary here. Lazy iterables are more efficient. Calling .toList() after .map(), .where(), .take(), etc. creates an intermediate list that may not be needed. Dart\'s lazy iterables are more memory efficient.',
    correctionMessage:
        'Remove .toList() unless you need to modify the list or access by index. Audit similar patterns across the codebase to ensure consistent security practices.',
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
/// Detects server-side request handler functions with protected-sounding
/// names that lack authentication checks. Uses parameter and return type
/// analysis to distinguish API endpoints from Flutter UI code.
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3},
        web: <OwaspWeb>{OwaspWeb.a01, OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_auth_check',
    problemMessage:
        '[require_auth_check] Missing auth check allows unauthorized access '
        'to protected user data and privileged operations.',
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

  /// Function name prefixes that indicate Flutter UI code, not API endpoints.
  static const Set<String> _uiPrefixes = <String>{
    'show',
    'build',
    'init',
    'dispose',
    'create',
    'open',
    'close',
    'navigate',
    'push',
    'pop',
    'render',
    'draw',
    'paint',
    'layout',
    'animate',
    'on', // onTap, onPressed, onSettingsChanged, etc.
  };

  /// Parameter type names that indicate Flutter UI context, not API requests.
  static const Set<String> _uiParamTypes = <String>{
    'BuildContext',
    'WidgetTester',
    'State',
    'Widget',
    'Key',
    'Animation',
    'ScrollController',
    'TextEditingController',
    'FocusNode',
    'GlobalKey',
  };

  /// Parameter type names that indicate a server-side request handler.
  static const Set<String> _requestParamTypes = <String>{
    'Request',
    'HttpRequest',
    'RequestContext',
    'HttpHeaders',
    'HttpContext',
    'RequestHandler',
  };

  /// Return type keywords that indicate an API response.
  static const Set<String> _responseReturnTypes = <String>{
    'Response',
    'HttpResponse',
  };

  /// Auth verification patterns found in function bodies.
  static const Set<String> _authCheckPatterns = <String>{
    'verifyToken',
    'authenticate',
    'Authorization',
    'isAuthenticated',
    'checkAuth',
    'unauthorized',
    'Unauthorized',
    'requireAuth',
    'ensureAuth',
    'validateToken',
    'authGuard',
    'authMiddleware',
    'verifySession',
    'checkPermission',
    'hasPermission',
    'isAuthorized',
    'forbidden',
    'Forbidden',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      final String functionName = node.name.lexeme.toLowerCase();

      // Skip Flutter UI functions by name prefix
      for (final String prefix in _uiPrefixes) {
        if (functionName.startsWith(prefix)) return;
      }

      // Skip private functions (unlikely to be direct API handlers)
      if (functionName.startsWith('_')) return;

      // Check if function name suggests protected endpoint
      bool looksProtected = false;
      for (final String pattern in _protectedEndpointPatterns) {
        if (functionName.contains(pattern)) {
          looksProtected = true;
          break;
        }
      }

      if (!looksProtected) return;

      // Analyze return type - require an API response type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      final String returnTypeStr = returnType.toSource();
      final bool hasResponseReturnType = _responseReturnTypes.any(
        returnTypeStr.contains,
      );

      // If return type has no Response indicator, check parameters
      // to confirm this is actually a server-side handler
      if (!hasResponseReturnType) {
        if (!_hasRequestParam(node)) return;
      }

      // Skip if any parameter is a Flutter UI type
      if (_hasUiParam(node)) return;

      // Check if function body has auth verification
      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      final bool hasAuthCheck = _authCheckPatterns.any(bodySource.contains);

      if (!hasAuthCheck) {
        reporter.atToken(node.name, code);
      }
    });
  }

  /// Returns true if the function has a server-side request parameter.
  static bool _hasRequestParam(FunctionDeclaration node) {
    final FormalParameterList? params = node.functionExpression.parameters;
    if (params == null) return false;

    for (final FormalParameter param in params.parameters) {
      final String? paramType = _extractParamType(param);
      if (paramType != null && _requestParamTypes.any(paramType.contains)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if the function has a Flutter UI parameter type.
  static bool _hasUiParam(FunctionDeclaration node) {
    final FormalParameterList? params = node.functionExpression.parameters;
    if (params == null) return false;

    for (final FormalParameter param in params.parameters) {
      final String? paramType = _extractParamType(param);
      if (paramType != null && _uiParamTypes.any(paramType.contains)) {
        return true;
      }
    }
    return false;
  }

  /// Extracts the type string from a formal parameter.
  static String? _extractParamType(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    }
    if (param is DefaultFormalParameter) {
      final NormalFormalParameter normalParam = param.parameter;
      if (normalParam is SimpleFormalParameter) {
        return normalParam.type?.toSource();
      }
    }
    return null;
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_token_refresh',
    problemMessage:
        '[require_token_refresh] Auth service stores access token but may lack refresh logic. Access tokens expire. Without refresh logic, users get logged out unexpectedly. Implement proactive token refresh.',
    correctionMessage:
        'Implement token refresh to handle expiration gracefully. Audit similar patterns across the codebase to ensure consistent security practices.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_jwt_decode_client',
    problemMessage:
        '[avoid_jwt_decode_client] Decoding JWT tokens on the client for authorization decisions is insecure because the client cannot verify token signatures. Attackers can craft or modify JWT claims to bypass permission checks, escalate privileges, and access restricted features or data without valid server-issued credentials.',
    correctionMessage:
        'Verify JWT claims and signature on the server side only. Use client-decoded JWT data for display purposes only, never for authorization or access control decisions.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_logout_cleanup',
    problemMessage:
        '[require_logout_cleanup] Incomplete logout cleanup leaves session tokens, cached user data, and authentication state accessible in local storage. On shared or stolen devices, the next user can access the previous account, personal data, and session tokens without re-authenticating, enabling unauthorized account access.',
    correctionMessage:
        'Ensure logout clears all tokens from secure storage, removes cached user data, resets navigation state, and invalidates the server session to prevent unauthorized access.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a03, OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_auth_in_query_params',
    problemMessage:
        '[avoid_auth_in_query_params] Query params are logged in server logs, '
        'browser history, and referrer headers, leaking auth tokens.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4, OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a01, OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'require_deep_link_validation',
    problemMessage:
        '[require_deep_link_validation] Deep link parameter used without validation allows attackers to craft malicious URLs that inject arbitrary data into your app. Unvalidated deep link parameters can cause crashes from unexpected types, unauthorized access to restricted screens, or execution of unintended actions on behalf of the user.',
    correctionMessage:
        'Add null checks, type validation, and format verification for all deep link parameters before using them for navigation or data operations.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m9, OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'require_data_encryption',
    problemMessage:
        '[require_data_encryption] Unencrypted sensitive data exposes '
        'credentials to attackers via device access or backup extraction.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m6},
        web: <OwaspWeb>{OwaspWeb.a04},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_data_masking',
    problemMessage:
        '[prefer_data_masking] Unmasked sensitive data visible in UI and screenshots. Sensitive data (SSN, credit cards, passwords) must be partially masked when displayed to prevent shoulder surfing.',
    correctionMessage:
        'Mask sensitive data: "****-****-****-1234" instead of full number. Audit similar patterns across the codebase to ensure consistent security practices.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m6},
        web: <OwaspWeb>{OwaspWeb.a04},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_screenshot_sensitive',
    problemMessage:
        '[avoid_screenshot_sensitive] Sensitive screen allows screenshots and screen recording. Financial and authentication screens should disable screenshots using platform APIs to prevent sensitive data exposure.',
    correctionMessage:
        'Use FlutterWindowManager.addFlags(FLAG_SECURE) for sensitive screens. Audit similar patterns across the codebase to ensure consistent security practices.',
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
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1, OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a02, OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_secure_password_field',
    problemMessage:
        '[require_secure_password_field] Password input fields must disable suggestions and autocorrect to prevent sensitive information from being stored in device dictionaries or suggested to users inappropriately. Failing to do so increases the risk of password leakage, accidental exposure, and poor user privacy. Always configure password fields to maximize security and user trust.',
    correctionMessage:
        'Set enableSuggestions: false and autocorrect: false on all password fields (TextField, TextFormField, CupertinoTextField) to prevent password suggestions and autocorrect. This helps protect user credentials from being stored or exposed.',
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

/// Warns when File/Directory paths include function parameters without
/// validation, which could allow path traversal attacks.
///
/// Path traversal attacks use sequences like `../` to escape intended
/// directories and access arbitrary files (e.g., `../../../etc/passwd`).
///
/// This rule only flags paths containing **function parameters** (user input).
/// Paths using trusted sources like `getApplicationDocumentsDirectory()`,
/// private constants, or `MethodChannel` results are NOT flagged.
///
/// The rule also skips paths where validation is detected (e.g., `basename()`,
/// `startsWith()`, `isWithin()`, `sanitize()`).
///
/// **BAD:**
/// ```dart
/// // Parameter used directly in path - user could pass '../../../etc/passwd'
/// Future<String> readFile(String userPath) async {
///   final file = File('/data/$userPath');  // LINT
///   return file.readAsString();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Trusted source - no user input
/// Future<File> getAppFile() async {
///   final dir = await getApplicationDocumentsDirectory();
///   return File('${dir.path}/data.json');  // OK - trusted source
/// }
///
/// // Parameter with validation
/// Future<String> readFile(String userPath) async {
///   final sanitized = path.basename(userPath);
///   if (sanitized != userPath || userPath.contains('..')) {
///     throw SecurityException('Invalid path');
///   }
///   final file = File('/data/$sanitized');
///   if (!file.path.startsWith('/data/')) {
///     throw SecurityException('Path outside allowed directory');
///   }
///   return file.readAsString();
/// }
/// ```
///
/// **OWASP:** `M4:Insufficient-Input-Output-Validation`, `A01:Broken-Access`,
/// `A03:Injection`
///
/// See also: `require_file_path_sanitization` for a similar rule.
class AvoidPathTraversalRule extends SaropaLintRule {
  const AvoidPathTraversalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a01, OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_path_traversal',
    problemMessage:
        '[avoid_path_traversal] File paths constructed from user input may allow path traversal attacks (e.g., "../"), enabling access to sensitive files outside the intended directory. This is a critical security risk.',
    correctionMessage:
        'Sanitize and validate file paths to prevent traversal (e.g., remove "../", use path package), and restrict access to allowed directories only.',
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

      // Check if path uses string interpolation or concatenation
      if (!argSource.contains(r'$') && !argSource.contains('+')) return;

      // Get function parameters - only flag if user input (parameters) is used
      final FormalParameterList? params = _getFunctionParameters(node);
      if (params == null) return;

      // Check if any parameter is used in the path
      String? usedParam;
      for (final FormalParameter param in params.parameters) {
        final String paramName = param.name?.lexeme ?? '';
        if (paramName.isNotEmpty && argSource.contains(paramName)) {
          usedParam = paramName;
          break;
        }
      }

      // No parameter used in path - safe (e.g., system APIs, constants)
      if (usedParam == null) return;

      // Parameter is used - check for validation
      if (_hasPathValidation(node)) return;

      reporter.atNode(node, code);
    });
  }

  /// Gets the parameters of the enclosing function or method.
  FormalParameterList? _getFunctionParameters(AstNode node) {
    final FunctionDeclaration? funcDecl =
        node.thisOrAncestorOfType<FunctionDeclaration>();
    if (funcDecl != null) {
      return funcDecl.functionExpression.parameters;
    }

    final MethodDeclaration? methodDecl =
        node.thisOrAncestorOfType<MethodDeclaration>();
    if (methodDecl != null) {
      return methodDecl.parameters;
    }

    return null;
  }

  /// Checks if there's path validation in the enclosing scope.
  bool _hasPathValidation(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      final String source = current.toSource();

      // Check for path traversal validation patterns
      if (source.contains('..') &&
          (source.contains('throw') || source.contains('return'))) {
        return true;
      }
      if (source.contains('basename') ||
          source.contains('resolveSymbolicLinks') ||
          source.contains('startsWith') ||
          source.contains('sanitize') ||
          source.contains('validate') ||
          source.contains('isWithin') ||
          source.contains('normalize')) {
        return true;
      }

      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }

    return false;
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a03},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_html_escape',
    problemMessage:
        '[prefer_html_escape] Displaying user-generated content in a WebView without proper HTML escaping exposes your app to cross-site scripting (XSS) attacks. Malicious input can execute scripts, steal user data, or compromise device security. Always sanitize and escape user content before rendering it in a web context.',
    correctionMessage:
        'Escape all user content using htmlEscape.convert() or a trusted sanitization library before displaying it in a WebView or similar widget. This prevents XSS and protects users from malicious input.',
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

// NOTE: avoid_sensitive_data_in_logs was removed in v4.2.3 - duplicate of
// avoid_sensitive_in_logs in debug_rules.dart. The debug_rules version uses
// proper AST analysis instead of regex matching for more accurate detection.

// =============================================================================
// Part 5 Rules: Package-Specific Security Rules
// =============================================================================

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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3, OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a02, OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_secure_storage_for_auth',
    problemMessage:
        '[require_secure_storage_for_auth] Auth tokens in SharedPreferences '
        'leak via backup extraction, enabling account takeover.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a03, OwaspWeb.a10},
      );

  static const LintCode _code = LintCode(
    name: 'require_url_validation',
    problemMessage:
        '[require_url_validation] Uri.parse on user input without scheme validation enables SSRF attacks. Attackers can make your app connect to internal servers, databases, or use malicious protocols to exfiltrate data.',
    correctionMessage:
        'Validate url.scheme is https or http before making requests, and reject file://, data://, and other dangerous schemes that could access local resources.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a01},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_redirect_injection',
    problemMessage:
        '[avoid_redirect_injection] Redirect URL read from a parameter or user input without domain validation creates an open redirect vulnerability. Attackers craft URLs pointing to your app that redirect victims to phishing sites, credential harvesters, or malware downloads while appearing to originate from your trusted domain.',
    correctionMessage:
        'Validate the redirect URL host against an allowlist of trusted domains before performing the redirect, and reject URLs with unexpected schemes or external hosts.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a01},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_external_storage_sensitive',
    problemMessage:
        '[avoid_external_storage_sensitive] External storage is world-readable '
        'on Android, exposing credentials to any installed app.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_local_auth',
    problemMessage:
        '[prefer_local_auth] Payment/sensitive operation without biometric authentication. Critical operations like payments should require additional authentication to prevent unauthorized access even if the device is unlocked.',
    correctionMessage:
        'Add LocalAuthentication().authenticate() before sensitive operations. Audit similar patterns across the codebase to ensure consistent security practices.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m3, OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a02, OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'require_secure_storage_auth_data',
    problemMessage:
        '[require_secure_storage_auth_data] Plaintext auth tokens enable '
        'session hijacking via device backup or physical access.',
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a05, OwaspWeb.a06},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_webview_javascript_disabled',
    problemMessage:
        '[prefer_webview_javascript_disabled] WebView with JavaScript enabled expands the attack surface for cross-site scripting and remote code execution. Malicious scripts can steal authentication tokens, access device APIs through JavaScript bridges, read local storage, and exfiltrate user data to attacker-controlled servers without detection.',
    correctionMessage:
        'Set javaScriptEnabled: false or javascriptMode: JavascriptMode.disabled unless JavaScript is required, and restrict content to trusted HTTPS sources only.',
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
          // cspell:ignore javascriptmode javascriptenabled initialsettings
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a05},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_webview_insecure_content',
    problemMessage:
        '[avoid_webview_insecure_content] Allowing mixed (HTTP and HTTPS) content in a WebView exposes users to man-in-the-middle attacks, data interception, and content tampering. Insecure content can compromise the confidentiality and integrity of user data. Always restrict WebView to load only secure (HTTPS) content.',
    correctionMessage:
        'Set mixedContentMode to MIXED_CONTENT_NEVER_ALLOW (or equivalent) to block insecure HTTP content in WebView. This ensures all loaded resources are secure and protects users from network-based attacks.',
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
          // cspell:disable
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
          // cspell:enable
        }
      }
    });

    // Also check for method invocations
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      // cspell:ignore setmixedcontentmode allowmixedcontent
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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a05},
      );

  static const LintCode _code = LintCode(
    name: 'require_webview_error_handling',
    problemMessage:
        '[require_webview_error_handling] WebView without an error handler displays a blank white page when network requests fail, SSL errors occur, or resources cannot be loaded. Users see no feedback about what went wrong and have no way to retry, creating a confusing and broken experience that appears as an app crash.',
    correctionMessage:
        'Add an onWebResourceError or onLoadError callback that displays a user-friendly error message with a retry option when WebView content fails to load.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
    'WebViewX',
  };

  // cspell:disable
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
  // cspell:enable

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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
        web: <OwaspWeb>{OwaspWeb.a07},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_api_key_in_code',
    problemMessage:
        '[avoid_api_key_in_code] Hardcoded keys are extractable from app '
        'binaries, enabling unauthorized API access and billing abuse.',
    correctionMessage:
        'Use environment variables, secure storage, or build config to inject keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // cspell:disable
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
  // cspell:enable

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

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m9},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_storing_sensitive_unencrypted',
    problemMessage:
        '[avoid_storing_sensitive_unencrypted] Unencrypted sensitive data exposed '
        'via device backup extraction or rooted device access, enabling identity theft.',
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

// =============================================================================
// OWASP Coverage Gap Rules (v3.2.0)
// =============================================================================

/// Warns when SSL/TLS certificate errors are ignored.
///
/// Alias: ssl_pinning_bypass, ignore_certificate_errors
///
/// Ignoring SSL certificate errors allows man-in-the-middle attacks.
/// The `badCertificateCallback` should never unconditionally return `true`.
///
/// **BAD:**
/// ```dart
/// HttpClient client = HttpClient()
///   ..badCertificateCallback = (cert, host, port) => true;
///
/// // Or with HttpOverrides
/// class MyHttpOverrides extends HttpOverrides {
///   @override
///   HttpClient createHttpClient(SecurityContext? context) {
///     return super.createHttpClient(context)
///       ..badCertificateCallback = (_, __, ___) => true;
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// HttpClient client = HttpClient()
///   ..badCertificateCallback = (cert, host, port) {
///     // Validate certificate properly
///     return cert.sha256.equals(pinnedCertHash);
///   };
/// ```
class AvoidIgnoringSslErrorsRule extends SaropaLintRule {
  const AvoidIgnoringSslErrorsRule() : super(code: _code);

  /// Ignoring SSL errors enables man-in-the-middle attacks.
  /// Critical security vulnerability.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m5},
        web: <OwaspWeb>{OwaspWeb.a05},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_ignoring_ssl_errors',
    problemMessage:
        '[avoid_ignoring_ssl_errors] Bypassing or ignoring SSL/TLS certificate errors disables the core security guarantees of HTTPS, allowing man-in-the-middle attackers to intercept, modify, or steal all data sent over the network. This exposes user credentials, tokens, and sensitive personal data to silent compromise, and is a leading cause of real-world security breaches. SSL validation must never be disabled in production code.',
    correctionMessage:
        'Always validate SSL/TLS certificates in your network stack. Never return true unconditionally or bypass certificate checks, even for testing. Use certificate pinning or trusted certificate authorities for additional security. Audit your codebase for insecure SSL handling and refactor to enforce strict validation. Document secure network practices for your team.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for badCertificateCallback assignments
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      final Expression leftSide = node.leftHandSide;
      if (leftSide is! PropertyAccess) return;

      final String propertyName = leftSide.propertyName.name;
      if (propertyName != 'badCertificateCallback') return;

      // Check if the right side unconditionally returns true
      final Expression rightSide = node.rightHandSide;
      if (_returnsUnconditionalTrue(rightSide)) {
        reporter.atNode(node, code);
      }
    });

    // Check for cascade assignments
    context.registry.addCascadeExpression((CascadeExpression node) {
      for (final Expression section in node.cascadeSections) {
        if (section is! AssignmentExpression) continue;

        final Expression leftSide = section.leftHandSide;
        if (leftSide is! PropertyAccess) continue;

        final String propertyName = leftSide.propertyName.name;
        if (propertyName != 'badCertificateCallback') continue;

        final Expression rightSide = section.rightHandSide;
        if (_returnsUnconditionalTrue(rightSide)) {
          reporter.atNode(section, code);
        }
      }
    });

    // Check for named parameter in constructor calls (e.g., dio)
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;

        // cspell:disable
        final String paramName = arg.name.label.name.toLowerCase();
        if (paramName != 'onbadcertificate' &&
            paramName != 'badcertificatecallback' &&
            paramName != 'validatecertificate') {
          continue;
        }
        // cspell:enable

        if (_returnsUnconditionalTrue(arg.expression)) {
          reporter.atNode(arg, code);
        }
      }
    });
  }

  /// Checks if an expression unconditionally returns true.
  bool _returnsUnconditionalTrue(Expression expr) {
    // Check for: (_, __, ___) => true or (a, b, c) => true
    if (expr is FunctionExpression) {
      final FunctionBody body = expr.body;
      if (body is ExpressionFunctionBody) {
        final Expression bodyExpr = body.expression;
        if (bodyExpr is BooleanLiteral && bodyExpr.value == true) {
          return true;
        }
      }
      // Check block body with just 'return true;'
      if (body is BlockFunctionBody) {
        final NodeList<Statement> statements = body.block.statements;
        if (statements.length == 1 && statements.first is ReturnStatement) {
          final Expression? returnExpr =
              (statements.first as ReturnStatement).expression;
          if (returnExpr is BooleanLiteral && returnExpr.value == true) {
            return true;
          }
        }
      }
    }
    // Check for: true (as a direct boolean)
    if (expr is BooleanLiteral && expr.value == true) {
      return true;
    }
    return false;
  }
}

/// Warns when HTTP (non-HTTPS) URLs are hardcoded in source code.
///
/// Alias: no_http_urls, https_only, insecure_url
///
/// HTTP traffic is unencrypted and vulnerable to interception.
/// Always use HTTPS for network communication.
///
/// **BAD:**
/// ```dart
/// const apiUrl = 'http://api.example.com/v1';
/// final response = await http.get(Uri.parse('http://example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// const apiUrl = 'https://api.example.com/v1';
/// final response = await http.get(Uri.parse('https://example.com/data'));
///
/// // Safe replacement patterns are allowed:
/// final secureUrl = url.replaceFirst('http://', 'https://');
/// ```
class RequireHttpsOnlyRule extends SaropaLintRule {
  const RequireHttpsOnlyRule() : super(code: _code);

  /// HTTP traffic is unencrypted and can be intercepted.
  /// Critical for any network communication.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m5},
        web: <OwaspWeb>{OwaspWeb.a05},
      );

  static const LintCode _code = LintCode(
    name: 'require_https_only',
    problemMessage:
        '[require_https_only] HTTP URL detected in network request. Unencrypted HTTP traffic is vulnerable to interception, modification, and eavesdropping by any attacker on the network path. Sensitive data including credentials, personal information, and session tokens transmitted over HTTP can be silently captured in plaintext.',
    correctionMessage:
        'Replace http:// with https:// to encrypt all network traffic and prevent man-in-the-middle attacks, data interception, and content tampering.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Localhost patterns that are safe to use HTTP.
  static const List<String> _allowedHttpPatterns = <String>[
    'http://localhost',
    'http://127.0.0.1',
    'http://10.0.2.2', // Android emulator localhost
    'http://0.0.0.0',
    'http://[::1]', // IPv6 localhost
  ];

  /// Checks if this 'http://' string is part of a safe replacement pattern
  /// like `url.replaceFirst('http://', 'https://')`.
  static bool _isSafeReplacementPattern(SimpleStringLiteral node) {
    final AstNode? parent = node.parent;
    if (parent is! ArgumentList) return false;

    final AstNode? grandparent = parent.parent;
    if (grandparent is! MethodInvocation) return false;

    final String methodName = grandparent.methodName.name;
    if (!const <String>{'replaceFirst', 'replaceAll', 'replace'}
        .contains(methodName)) {
      return false;
    }

    // Check if first arg is 'http://' and second is 'https://'
    final NodeList<Expression> args = parent.arguments;
    if (args.length < 2) return false;

    final Expression first = args[0];
    final Expression second = args[1];
    if (first is! SimpleStringLiteral || second is! SimpleStringLiteral) {
      return false;
    }

    return first.value == 'http://' && second.value == 'https://';
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    checkHttpUrls(context, (AstNode node) => reporter.atNode(node, code));
  }

  /// Shared detection logic for HTTP URL checking.
  ///
  /// Used by both [RequireHttpsOnlyRule] and [RequireHttpsOnlyTestRule]
  /// to avoid duplicating the detection logic across production and test
  /// rule variants.
  static void checkHttpUrls(
    CustomLintContext context,
    void Function(AstNode node) onViolation,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check if it's an HTTP URL
      if (!value.startsWith('http://')) return;

      // Allow localhost for development
      for (final String pattern in _allowedHttpPatterns) {
        if (value.startsWith(pattern)) return;
      }

      // Allow safe http→https replacement patterns
      if (_isSafeReplacementPattern(node)) return;

      onViolation(node);
    });

    // Also check string interpolations that might construct HTTP URLs
    context.registry.addStringInterpolation((StringInterpolation node) {
      // Get the first element to check for http:// prefix
      final List<InterpolationElement> elements = node.elements;
      if (elements.isEmpty) return;

      final InterpolationElement first = elements.first;
      if (first is! InterpolationString) return;

      final String value = first.value;
      if (!value.startsWith('http://')) return;

      // Allow localhost
      for (final String pattern in _allowedHttpPatterns) {
        if (value.startsWith(pattern)) return;
      }

      onViolation(node);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithHttpsFix()];
}

class _ReplaceWithHttpsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String value = node.value;
      if (!value.startsWith('http://')) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with HTTPS',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final String newValue = value.replaceFirst('http://', 'https://');
        builder.addSimpleReplacement(
          node.sourceRange,
          "'$newValue'",
        );
      });
    });
  }
}

/// Detects HTTP URLs in test files at reduced severity.
///
/// This is the test-file companion to [RequireHttpsOnlyRule]. The production
/// rule skips test files entirely; this rule covers them at INFO severity
/// so teams can independently disable it without losing production protection.
///
/// **Bad:**
/// ```dart
/// test('parses URL', () {
///   final url = 'http://example.com/path'; // INFO
/// });
/// ```
///
/// **Good:**
/// ```dart
/// test('parses URL', () {
///   final url = 'https://example.com/path';
/// });
/// ```
class RequireHttpsOnlyTestRule extends SaropaLintRule {
  const RequireHttpsOnlyTestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => const <FileType>{FileType.test};

  static const LintCode _code = LintCode(
    name: 'require_https_only_test',
    problemMessage: '[require_https_only_test] HTTP URL detected in test file. '
        'Consider using HTTPS even in test data.',
    correctionMessage:
        'Replace http:// with https:// or disable this rule for test files.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    RequireHttpsOnlyRule.checkHttpUrls(
      context,
      (AstNode node) => reporter.atNode(node, code),
    );
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceWithHttpsFix()];
}

/// Warns when JSON is decoded from untrusted sources without type validation.
///
/// Alias: unsafe_json_decode, json_injection, untrusted_deserialization
///
/// Deserializing JSON from network responses without type checking can lead
/// to unexpected behavior or security vulnerabilities if the data structure
/// differs from expectations.
///
/// **BAD:**
/// ```dart
/// final data = jsonDecode(response.body);
/// final name = data['name'];  // No type checking!
///
/// // Or with dynamic usage:
/// final Map<String, dynamic> json = jsonDecode(input);
/// executeCommand(json['command']);  // Untrusted command!
/// ```
///
/// **GOOD:**
/// ```dart
/// final Map<String, dynamic> data = jsonDecode(response.body);
/// if (data case {'name': String name, 'age': int age}) {
///   // Type-safe usage
/// }
///
/// // Or with a model class:
/// final user = User.fromJson(jsonDecode(response.body));
/// ```
class AvoidUnsafeDeserializationRule extends SaropaLintRule {
  const AvoidUnsafeDeserializationRule() : super(code: _code);

  /// Untrusted deserialization can lead to data integrity issues.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a08},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_deserialization',
    problemMessage:
        '[avoid_unsafe_deserialization] Unvalidated JSON from untrusted sources can crash the app, inject malicious data, or corrupt application state. Attackers can exploit this vulnerability to trigger unexpected behavior, bypass security checks, or cause data loss by crafting malicious payloads.',
    correctionMessage:
        'Validate JSON structure with pattern matching or deserialize into typed model classes.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _dangerousMethods = <String>{
    'jsondecode',
    'json.decode',
  };

  static const Set<String> _dangerousOperations = <String>{
    'execute',
    'eval',
    'run',
    'command',
    'shell',
    'process',
    'spawn',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      // cspell:ignore jsondecode
      // Check for jsonDecode
      if (methodName != 'jsondecode' && methodName != 'decode') return;

      // If it's decode, check if target is json
      if (methodName == 'decode') {
        final Expression? target = node.target;
        if (target == null) return;
        final String targetName = target.toSource().toLowerCase();
        if (targetName != 'json') return;
      }

      // Check if the result is used in a dangerous way
      // Look at the parent to see how the result is used
      AstNode? current = node.parent;
      Block? enclosingBlock;

      while (current != null) {
        if (current is Block) {
          enclosingBlock = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBlock == null) return;

      // Check if there's type validation in the block
      final String blockSource = enclosingBlock.toSource().toLowerCase();

      // cspell:disable
      // Check for pattern matching or type checking
      final bool hasTypeCheck = blockSource.contains('case {') ||
          blockSource.contains('is map') ||
          blockSource.contains('is list') ||
          blockSource.contains('.fromjson') ||
          blockSource.contains('.frommap') ||
          blockSource.contains('jsonserializable') ||
          blockSource.contains('freezed');
      // cspell:enable

      if (hasTypeCheck) return;

      // Check for dangerous operations on the decoded data
      final bool hasDangerousOperation = _dangerousOperations.any(
        (op) => blockSource.contains(op),
      );

      // Only flag if there's a dangerous operation without type checking
      if (hasDangerousOperation) {
        reporter.atNode(node, code);
      }
    });

    // Check for function expression invocations like jsonDecode(...)
    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final String funcName = node.function.toSource().toLowerCase();

      if (!_dangerousMethods.any((m) => funcName.contains(m))) return;

      // Find enclosing block
      AstNode? current = node.parent;
      Block? enclosingBlock;

      while (current != null) {
        if (current is Block) {
          enclosingBlock = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBlock == null) return;

      final String blockSource = enclosingBlock.toSource().toLowerCase();

      // cspell:ignore fromjson frommap
      // Check for type validation
      final bool hasTypeCheck = blockSource.contains('case {') ||
          blockSource.contains('is map') ||
          blockSource.contains('is list') ||
          blockSource.contains('.fromjson') ||
          blockSource.contains('.frommap');

      if (hasTypeCheck) return;

      // Check for dangerous operations
      final bool hasDangerousOperation = _dangerousOperations.any(
        (op) => blockSource.contains(op),
      );

      if (hasDangerousOperation) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when user-controlled input is used directly in HTTP requests.
///
/// Alias: ssrf_prevention, user_url_validation, untrusted_url
///
/// Using user input directly in HTTP client methods enables Server-Side
/// Request Forgery (SSRF) attacks where attackers can probe internal
/// networks or access restricted resources.
///
/// **BAD:**
/// ```dart
/// final url = textController.text;
/// final response = await http.get(Uri.parse(url));
///
/// // Or with user input from text field:
/// void fetchData(String userUrl) async {
///   final data = await dio.get(userUrl);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final userInput = textController.text;
/// final uri = Uri.parse(userInput);
///
/// // Validate scheme and host
/// if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) {
///   throw SecurityException('Invalid URL');
/// }
/// final response = await http.get(uri);
///
/// // Or use an allowlist:
/// if (!trustedDomains.any((d) => userUrl.contains(d))) {
///   throw SecurityException('Untrusted domain');
/// }
/// ```
class AvoidUserControlledUrlsRule extends SaropaLintRule {
  const AvoidUserControlledUrlsRule() : super(code: _code);

  /// SSRF can expose internal services and data.
  /// Critical vulnerability in server-facing applications.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m4},
        web: <OwaspWeb>{OwaspWeb.a10},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_user_controlled_urls',
    problemMessage:
        '[avoid_user_controlled_urls] Allowing user-controlled URLs to be loaded without validation exposes your app to security vulnerabilities such as phishing, open redirects, and malicious content injection. This can compromise user data and app integrity. Always validate and sanitize URLs before loading or displaying them. See https://owasp.org/www-community/attacks/Unvalidated_Redirects_and_Forwards_Cheat_Sheet and https://pub.dev/packages/webview_flutter#security-considerations.',
    correctionMessage:
        'Implement strict validation and sanitization of all user-provided URLs to prevent security breaches and protect users from malicious content. See https://owasp.org/www-community/attacks/Unvalidated_Redirects_and_Forwards_Cheat_Sheet and https://pub.dev/packages/webview_flutter#security-considerations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // cspell:disable
  /// Patterns indicating user input sources.
  static const Set<String> _userInputPatterns = <String>{
    'textcontroller',
    'controller.text',
    'textfield',
    'userinput',
    'user_input',
    'forminput',
    'form_input',
    'inputtext',
    'input_text',
    'urlfield',
    'url_field',
    'urlcontroller',
    'url_controller',
  };
  // cspell:enable

  /// HTTP methods that make requests.
  static const Set<String> _httpMethods = <String>{
    'get',
    'post',
    'put',
    'delete',
    'patch',
    'head',
    'request',
    'fetch',
    'send',
    'download',
    'upload',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      // Check if this is an HTTP method
      if (!_httpMethods.contains(methodName)) return;

      // Check if target looks like an HTTP client
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      final bool isHttpClient = targetSource.contains('http') ||
          targetSource.contains('dio') ||
          targetSource.contains('client') ||
          targetSource.contains('api');

      if (!isHttpClient) return;

      // Check arguments for user-controlled input
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource().toLowerCase();

        // Check for user input patterns
        final bool isUserControlled =
            _userInputPatterns.any((p) => argSource.contains(p));

        if (!isUserControlled) continue;

        // Check if there's validation in the enclosing block
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
          final String blockSource = enclosingBlock.toSource().toLowerCase();

          // cspell:ignore allowedhost trusteddom
          // Check for URL validation patterns
          final bool hasValidation = blockSource.contains('.scheme') ||
              blockSource.contains('.host') ||
              blockSource.contains('allowlist') ||
              blockSource.contains('whitelist') ||
              blockSource.contains('allowedhost') ||
              blockSource.contains('allowed_host') ||
              blockSource.contains('trusteddom') ||
              blockSource.contains('trusted_dom');

          if (hasValidation) continue;
        }

        reporter.atNode(arg, code);
      }
    });

    // Check for Uri.parse with user input passed to HTTP methods
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Uri') return;

      // Check if any argument contains user input patterns
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource().toLowerCase();

        final bool isUserControlled =
            _userInputPatterns.any((p) => argSource.contains(p));

        if (!isUserControlled) continue;

        // Find where this Uri is used
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodInvocation) {
            final String methodName = current.methodName.name.toLowerCase();
            if (_httpMethods.contains(methodName)) {
              // Check for validation in enclosing block
              AstNode? blockSearch = current.parent;
              Block? enclosingBlock;

              while (blockSearch != null) {
                if (blockSearch is Block) {
                  enclosingBlock = blockSearch;
                  break;
                }
                blockSearch = blockSearch.parent;
              }

              if (enclosingBlock != null) {
                final String blockSource =
                    enclosingBlock.toSource().toLowerCase();
                final bool hasValidation = blockSource.contains('.scheme') ||
                    blockSource.contains('.host') ||
                    blockSource.contains('allowlist') ||
                    blockSource.contains('whitelist');

                if (!hasValidation) {
                  reporter.atNode(arg, code);
                }
              }
              break;
            }
          }
          current = current.parent;
        }
      }
    });
  }
}

/// Warns when catch blocks silently swallow exceptions without logging.
///
/// Alias: silent_catch, empty_catch_logging, exception_swallowing
///
/// Catch blocks that neither log the exception nor rethrow it hide errors
/// and make debugging impossible. Security-relevant exceptions may go
/// unnoticed, violating OWASP logging requirements.
///
/// **BAD:**
/// ```dart
/// try {
///   await authenticate(user);
/// } catch (e) {
///   // Silent catch - security failure goes unlogged
/// }
///
/// try {
///   await processPayment();
/// } catch (e) {
///   showError('Payment failed');  // No logging!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await authenticate(user);
/// } catch (e, stackTrace) {
///   logger.error('Authentication failed', error: e, stackTrace: stackTrace);
///   rethrow;
/// }
///
/// try {
///   await processPayment();
/// } catch (e, stackTrace) {
///   log.severe('Payment processing failed: $e');
///   analytics.trackError(e, stackTrace);
///   showError('Payment failed');
/// }
/// ```
class RequireCatchLoggingRule extends SaropaLintRule {
  const RequireCatchLoggingRule() : super(code: _code);

  /// Silent exception swallowing hides security-relevant errors.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m8},
        web: <OwaspWeb>{OwaspWeb.a09},
      );

  static const LintCode _code = LintCode(
    name: 'require_catch_logging',
    problemMessage:
        '[require_catch_logging] Catch block swallows the exception without logging or rethrowing. Security-relevant errors such as authentication failures, permission violations, and data corruption go completely undetected. This prevents incident response, makes debugging production issues impossible, and hides potential attack activity.',
    correctionMessage:
        'Log the exception with a structured logger (e.g., logger.error(message, error, stackTrace)) or rethrow to ensure errors are visible for debugging and monitoring.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // cspell:disable
  /// Patterns that indicate logging is present.
  static const Set<String> _loggingPatterns = <String>{
    'log',
    'logger',
    'print',
    'debugprint',
    'console',
    'error',
    'warning',
    'severe',
    'info',
    'debug',
    'trace',
    'analytics',
    'crashlytics',
    'sentry',
    'bugsnag',
    'firebase',
    'recordError',
    'record_error',
    'reporterror',
    'report_error',
  };
  // cspell:enable

  /// Patterns that indicate the exception is being handled appropriately.
  static const Set<String> _rethrowPatterns = <String>{
    'rethrow',
    'throw',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final Block body = node.body;

      // Empty catch blocks are always bad
      if (body.statements.isEmpty) {
        reporter.atNode(node, code);
        return;
      }

      final String bodySource = body.toSource().toLowerCase();

      // Check for logging
      final bool hasLogging = _loggingPatterns.any(
        (pattern) => bodySource.contains(pattern),
      );

      if (hasLogging) return;

      // Check for rethrow
      final bool hasRethrow = _rethrowPatterns.any(
        (pattern) => bodySource.contains(pattern),
      );

      if (hasRethrow) return;

      // Check if the exception variable is used (might be passed to a function)
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam != null) {
        final String exceptionName = exceptionParam.name.lexeme;
        // Check if exception is used in a function call (might be custom logging)
        if (bodySource.contains(exceptionName.toLowerCase())) {
          // Exception is referenced - might be passed to a custom logger
          // Only flag if it's just assignment or simple property access
          final bool isJustAssignment = _isOnlyAssignmentOrPropertyAccess(
            body,
            exceptionName,
          );
          if (!isJustAssignment) return;
        }
      }

      reporter.atNode(node, code);
    });
  }

  /// Checks if the exception is only used in assignments or property access
  /// (which doesn't count as proper error handling).
  bool _isOnlyAssignmentOrPropertyAccess(Block body, String exceptionName) {
    final String source = body.toSource();

    // Common patterns that are NOT proper handling:
    // - e.toString()
    // - e.message
    // - final msg = e.toString();

    // If there's a method call that's not just toString/message, consider it handled
    final RegExp methodCallPattern = RegExp(
      r'\b' + RegExp.escape(exceptionName) + r'\.\w+\(',
      caseSensitive: false,
    );

    if (methodCallPattern.hasMatch(source)) {
      // Check if it's just toString or message
      final String lowerSource = source.toLowerCase();
      final bool isOnlyBasicMethods =
          lowerSource.contains('$exceptionName.tostring()'.toLowerCase()) ||
              lowerSource.contains('$exceptionName.message'.toLowerCase());

      if (!isOnlyBasicMethods) {
        return false; // Passed to a method, consider it handled
      }
    }

    // Check if exception is passed as argument to a function
    final RegExp funcArgPattern = RegExp(
      r'\w+\([^)]*\b' + RegExp.escape(exceptionName) + r'\b',
      caseSensitive: false,
    );

    if (funcArgPattern.hasMatch(source)) {
      return false; // Passed to a function, consider it handled
    }

    return true;
  }
}

// =============================================================================
// require_secure_storage_error_handling
// =============================================================================

/// Secure storage operations can fail and need error handling.
///
/// Secure storage may fail on some devices due to:
/// - Biometric unavailable
/// - Device not secure
/// - Storage corrupted
/// - Permission issues
///
/// **BAD:**
/// ```dart
/// final value = await secureStorage.read(key: 'token');
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final value = await secureStorage.read(key: 'token');
/// } on PlatformException catch (e) {
///   // Handle storage failure
/// }
/// ```
class RequireSecureStorageErrorHandlingRule extends SaropaLintRule {
  const RequireSecureStorageErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_secure_storage_error_handling',
    problemMessage:
        '[require_secure_storage_error_handling] Secure storage operation '
        'without error handling. May fail on some devices.',
    correctionMessage: 'Wrap in try-catch to handle PlatformException.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _secureStorageMethods = <String>{
    'read',
    'write',
    'delete',
    'deleteAll',
    'readAll',
    'containsKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      // Check if this is a secure storage call
      final String methodName = expr.methodName.name;
      if (!_secureStorageMethods.contains(methodName)) return;

      // Check if target looks like secure storage
      final Expression? target = expr.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('securestorage') &&
          !targetSource.contains('flutter_secure_storage') &&
          !targetSource.contains('_storage') &&
          !targetSource.contains('keychain')) {
        return;
      }

      // Check if inside try-catch
      if (_isInsideTryCatch(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) return true;
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// avoid_secure_storage_large_data
// =============================================================================

/// Secure storage isn't designed for large data (>1KB).
///
/// Secure storage is slow and has size limits. For large data,
/// use regular encrypted file storage.
///
/// **BAD:**
/// ```dart
/// await secureStorage.write(key: 'userData', value: largeJsonString);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Store large data in encrypted file
/// await encryptedFile.writeAsString(largeJsonString);
/// // Only store small tokens/keys in secure storage
/// await secureStorage.write(key: 'token', value: token);
/// ```
class AvoidSecureStorageLargeDataRule extends SaropaLintRule {
  const AvoidSecureStorageLargeDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_secure_storage_large_data',
    problemMessage:
        '[avoid_secure_storage_large_data] `[HEURISTIC]` Storing large data in '
        'secure storage. It\'s designed for small secrets like tokens.',
    correctionMessage:
        'Use encrypted file storage for large data. Secure storage is slow '
        'and has size limits.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'write') return;

      // Check if target is secure storage
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('securestorage') &&
          !targetSource.contains('_storage')) {
        return;
      }

      // Check the value being written
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          final Expression value = arg.expression;

          // cspell:ignore imagedata
          // Check for indicators of large data
          final String valueSource = value.toSource().toLowerCase();
          if (valueSource.contains('jsonencode') ||
              valueSource.contains('jsonfile') ||
              valueSource.contains('imagedata') ||
              valueSource.contains('bytes') ||
              valueSource.contains('base64')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// Clipboard Security Rules (from v4.1.7)
// =============================================================================

/// Warns when sensitive data is copied to clipboard.
///
/// `[HEURISTIC]` - Detects Clipboard.setData with sensitive variable names.
///
/// Clipboard contents are accessible to other apps. Don't copy passwords,
/// tokens, secrets, or API keys to the clipboard.
///
/// **BAD:**
/// ```dart
/// void copyPassword(String password) {
///   Clipboard.setData(ClipboardData(text: password)); // Accessible to other apps!
/// }
///
/// void shareToken() {
///   Clipboard.setData(ClipboardData(text: apiKey)); // Security risk!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void copyPublicId(String userId) {
///   Clipboard.setData(ClipboardData(text: userId)); // OK - public data
/// }
/// ```
class AvoidSensitiveDataInClipboardRule extends SaropaLintRule {
  const AvoidSensitiveDataInClipboardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_sensitive_data_in_clipboard',
    problemMessage:
        '[avoid_sensitive_data_in_clipboard] Copying sensitive data such as passwords, tokens, or personal information to the clipboard exposes users to data theft, as other apps or malicious actors can access clipboard contents. This is a significant privacy and security risk, especially on shared or compromised devices. See https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure.html and https://api.flutter.dev/flutter/services/Clipboard-class.html.',
    correctionMessage:
        'Avoid placing sensitive data on the clipboard and implement safeguards to prevent accidental exposure. Educate users about the risks and follow platform-specific security guidelines. See https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure.html and https://api.flutter.dev/flutter/services/Clipboard-class.html.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _sensitivePattern = RegExp(
    r'\b(password|passwd|pwd|secret|token|apiKey|api_key|accessToken|'
    r'access_token|refreshToken|refresh_token|privateKey|private_key|'
    r'secretKey|secret_key|credential|authToken|bearer|jwt|pin|otp)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setData') return;

      // Check if called on Clipboard
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check the argument for sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (_sensitivePattern.hasMatch(argSource)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when clipboard paste is used without validation.
///
/// `[HEURISTIC]` - Detects Clipboard.getData without validation.
///
/// Pasted content can be unexpected format or malicious.
/// Validate clipboard data before using it.
///
/// **BAD:**
/// ```dart
/// void pasteApiKey() async {
///   final data = await Clipboard.getData('text/plain');
///   _apiKey = data?.text ?? ''; // No validation!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void pasteApiKey() async {
///   final data = await Clipboard.getData('text/plain');
///   final text = data?.text ?? '';
///   if (_isValidApiKeyFormat(text)) {
///     _apiKey = text;
///   }
/// }
/// ```
class RequireClipboardPasteValidationRule extends SaropaLintRule {
  const RequireClipboardPasteValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_clipboard_paste_validation',
    problemMessage:
        '[require_clipboard_paste_validation] Clipboard data used without validation. Pasted content can be unexpected format or malicious. Validate clipboard data before using it. This creates a security vulnerability that attackers can exploit to compromise user data or application integrity.',
    correctionMessage:
        'Validate clipboard content format and sanitize before using. Audit similar patterns across the codebase to ensure consistent security practices.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getData') return;

      // Check if called on Clipboard
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check if the result is used directly without validation
      final AstNode? parent = node.parent;
      if (parent is AwaitExpression) {
        final AstNode? awaitParent = parent.parent;
        if (awaitParent is VariableDeclaration) {
          // Check if there's validation logic nearby
          final AstNode? block = _findContainingBlockForClipboard(awaitParent);
          if (block != null && !_hasValidationLogicForClipboard(block)) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  AstNode? _findContainingBlockForClipboard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) return current;
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasValidationLogicForClipboard(AstNode block) {
    final String source = block.toSource();
    // Check for common validation patterns
    return source.contains('isValid') ||
        source.contains('validate') ||
        source.contains('RegExp') ||
        source.contains('.contains(') ||
        source.contains('.startsWith(') ||
        source.contains('.length');
  }
}

/// Warns when encryption keys are stored as class fields.
///
/// `[HEURISTIC]` - Detects fields with key-related names.
///
/// Keys kept in memory can be extracted from memory dumps.
/// Load keys on demand and clear after use.
///
/// **BAD:**
/// ```dart
/// class EncryptionService {
///   final String encryptionKey; // Stays in memory!
///   final Uint8List privateKey; // Extractable from dump!
///
///   EncryptionService(this.encryptionKey, this.privateKey);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class EncryptionService {
///   Future<String> encrypt(String data) async {
///     final key = await _loadKeyFromSecureStorage();
///     try {
///       return _encrypt(data, key);
///     } finally {
///       _clearKey(key); // Clear after use
///     }
///   }
/// }
/// ```
class AvoidEncryptionKeyInMemoryRule extends SaropaLintRule {
  const AvoidEncryptionKeyInMemoryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_encryption_key_in_memory',
    problemMessage:
        '[avoid_encryption_key_in_memory] Encryption key stored as a persistent class field remains in process memory for the lifetime of the object. Memory dumps, debugging tools, or memory-scanning malware can extract the key, compromising all data encrypted with it. Keys in memory survive garbage collection and are visible in heap snapshots.',
    correctionMessage:
        'Load encryption keys on demand from secure storage, use them immediately for the operation, and clear the variable after use to minimize the exposure window.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _keyFieldPattern = RegExp(
    r'\b(encryption|private|secret|aes|rsa|hmac).*key\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final String fieldName = variable.name.lexeme;

        if (_keyFieldPattern.hasMatch(fieldName)) {
          // Check if it's a final field (stored persistently)
          if (node.fields.isFinal || node.fields.isConst) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}

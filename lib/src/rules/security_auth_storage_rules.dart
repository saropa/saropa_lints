// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Security lint rules (split file).
library;

// cspell:ignore pincode plaintext sessionid expir isbefore accountnumber cardnumber
// cspell:ignore sharedpreferences returnurl launchurl creds phonenumber socialsecurity
// cspell:ignore deleteaccount taxid idtoken localauthentication faceid routingnumber
// cspell:ignore encryptedbox changepassword getexternalstoragedirectory

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

class RequireSecureStorageRule extends SaropaLintRule {
  RequireSecureStorageRule() : super(code: _code);

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
    'require_secure_storage',
    '[require_secure_storage] SharedPreferences stores data in plain XML. '
        'On rooted/jailbroken devices, attackers extract credentials for account takeover. {v7}',
    correctionMessage:
        'Use flutter_secure_storage: secureStorage.write(key: k, value: v).',
    severity: DiagnosticSeverity.WARNING,
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
  static final List<RegExp> _prefSharedTargetPatterns = [
    RegExp(r'\bpref\b'),
    RegExp(r'\bshared\b'),
  ];
  static final List<RegExp> _sensitiveKeyPatterns = _sensitiveKeys
      .map((s) => RegExp('\\b${RegExp.escape(s)}\\b'))
      .toList();

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!methodName.startsWith('set')) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_prefSharedTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      final String keySource = firstArg.toSource().toLowerCase();

      if (_sensitiveKeyPatterns.any((p) => p.hasMatch(keySource))) {
        reporter.atNode(node);
        return;
      }
    });
  }
}

/// Warns when hardcoded credentials are detected in source code.
///
/// Since: v0.1.8 | Updated: v4.13.0 | Rule version: v5
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
  AvoidHardcodedCredentialsRule() : super(code: _code);

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
    'avoid_hardcoded_credentials',
    '[avoid_hardcoded_credentials] Hardcoding credentials (such as passwords, API keys, or tokens) in source code exposes them to anyone with access to the codebase, including public repositories and version control history. This can lead to unauthorized access, data breaches, and compromised systems. Credentials should always be stored securely and never committed to version control. {v5}',
    correctionMessage:
        'Store credentials in secure storage or environment variables. Use String.fromEnvironment(\'KEY\') or a secure vault at runtime. Never commit secrets to source control.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
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
          reporter.atNode(node);
        }
      }
    });

    // Also check for string literals that look like credentials
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (_credentialPatterns.hasMatch(value)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when user input is used without sanitization.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
class RequireBiometricFallbackRule extends SaropaLintRule {
  RequireBiometricFallbackRule() : super(code: _code);

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
    'require_biometric_fallback',
    '[require_biometric_fallback] Biometric-only auth locks out users with damaged sensors. Not all devices support biometrics, and users must have an alternative authentication method. {v6}',
    correctionMessage:
        'Set biometricOnly to false or provide an alternative auth method. Audit similar patterns across the codebase to ensure consistent security practices.',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _authBioTargetPatterns = [
    RegExp(r'\bauth\b'),
    RegExp(r'\bbio\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'authenticate') return;

      // Check if it's a biometric authentication call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_authBioTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      // Check for biometricOnly: true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'biometricOnly') {
            if (arg.expression is BooleanLiteral) {
              final BooleanLiteral boolLit = arg.expression as BooleanLiteral;
              if (boolLit.value) {
                reporter.atNode(arg);
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
/// Since: v4.8.3 | Updated: v4.13.0 | Rule version: v7
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
class AvoidStoringPasswordsRule extends SaropaLintRule {
  AvoidStoringPasswordsRule() : super(code: _code);

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
    'avoid_storing_passwords',
    '[avoid_storing_passwords] SharedPreferences stores passwords in '
        'plaintext, readable by anyone with device access or backup. {v4}',
    correctionMessage:
        'Use flutter_secure_storage for passwords and sensitive data.',
    severity: DiagnosticSeverity.ERROR,
  );

  static final List<RegExp> _prefSharedTargetPatterns = [
    RegExp(r'\bpref\b'),
    RegExp(r'\bshared\b'),
  ];
  static final List<RegExp> _passwordKeyPatterns = [
    RegExp(r'\bpassword\b'),
    RegExp(r'\bpasswd\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!methodName.startsWith('set')) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_prefSharedTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      final String keySource = firstArg.toSource().toLowerCase();

      if (_passwordKeyPatterns.any((p) => p.hasMatch(keySource))) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when SQL queries are built using string interpolation.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v3
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
class RequireAuthCheckRule extends SaropaLintRule {
  RequireAuthCheckRule() : super(code: _code);

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
    'require_auth_check',
    '[require_auth_check] Missing auth check allows unauthorized access '
        'to protected user data and privileged operations. {v5}',
    correctionMessage:
        'Add authentication verification before processing protected requests.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
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
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v2
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
  RequireTokenRefreshRule() : super(code: _code);

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
    'require_token_refresh',
    '[require_token_refresh] Auth service stores access token but may lack refresh logic. Access tokens expire. Without refresh logic, users get logged out unexpectedly. Implement proactive token refresh. {v2}',
    correctionMessage:
        'Implement token refresh to handle expiration gracefully. Audit similar patterns across the codebase to ensure consistent security practices.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Whole-word match to avoid FPs (e.g. "Oauth" should not match "auth").
  static bool _containsWord(String text, String word) {
    return RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static final RegExp _refreshMethodPattern = RegExp(r'\brefresh\b');
  static final List<RegExp> _expiryBodyPatterns = [
    RegExp(r'\bexpir\b'),
    RegExp(r'\bisbefore\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Check if class is auth-related (whole-word to avoid Oauth, SessionId, etc.)
      if (!_containsWord(className, 'auth') &&
          !_containsWord(className, 'session') &&
          !_containsWord(className, 'token')) {
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
          if (_refreshMethodPattern.hasMatch(methodName)) {
            hasRefreshMethod = true;
          }
          final String bodySource = member.body.toSource().toLowerCase();
          if (_expiryBodyPatterns.any((p) => p.hasMatch(bodySource))) {
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
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v4
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
  AvoidJwtDecodeClientRule() : super(code: _code);

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
    'avoid_jwt_decode_client',
    '[avoid_jwt_decode_client] Decoding JWT tokens on the client for authorization decisions is insecure because the client cannot verify token signatures. Attackers can craft or modify JWT claims to bypass permission checks, escalate privileges, and access restricted features or data without valid server-issued credentials. {v4}',
    correctionMessage:
        'Verify JWT claims and signature on the server side only. Use client-decoded JWT data for display purposes only, never for authorization or access control decisions.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _jwtDecodeMethodPatterns = [
    RegExp(r'\bdecode\b'),
    RegExp(r'\bparse\b'),
  ];
  static final List<RegExp> _jwtTokenTargetPatterns = [
    RegExp(r'\bjwt\b'),
    RegExp(r'\btoken\b'),
  ];
  static final List<RegExp> _jwtTypePatterns = [
    RegExp(r'\bjwt\b'),
    RegExp(r'\bjsonwebtoken\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      if (!_jwtDecodeMethodPatterns.any((p) => p.hasMatch(methodName))) {
        return;
      }

      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        if (!_jwtTokenTargetPatterns.any((p) => p.hasMatch(targetSource))) {
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
            reporter.atNode(node);
            return;
          }
        }
        current = current.parent;
      }
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme
          .toLowerCase();
      if (_jwtTypePatterns.any((p) => p.hasMatch(typeName))) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when logout doesn't clear all sensitive data.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireLogoutCleanupRule() : super(code: _code);

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
    'require_logout_cleanup',
    '[require_logout_cleanup] Incomplete logout cleanup leaves session tokens, cached user data, and authentication state accessible in local storage. On shared or stolen devices, the next user can access the previous account, personal data, and session tokens without re-authenticating, enabling unauthorized account access. {v4}',
    correctionMessage:
        'Ensure logout clears all tokens from secure storage, removes cached user data, resets navigation state, and invalidates the server session to prevent unauthorized access.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _logoutStoragePatterns = [
    RegExp(r'\bdelete\b'),
    RegExp(r'\bremove\b'),
    RegExp(r'\bclear\b'),
  ];
  static final List<RegExp> _logoutTokenPatterns = [
    RegExp(r'\btoken\b'),
    RegExp(r'\bcredential\b'),
    RegExp(r'\bauth\b'),
  ];
  static final List<RegExp> _logoutCachePatterns = [
    RegExp(r'\bcache\b'),
    RegExp(r'\bstorage\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme.toLowerCase();

      if (methodName != 'logout' &&
          methodName != 'signout' &&
          methodName != 'sign_out') {
        return;
      }

      final String bodySource = node.body.toSource().toLowerCase();

      final bool clearsStorage = _logoutStoragePatterns.any(
        (p) => p.hasMatch(bodySource),
      );
      final bool clearsToken = _logoutTokenPatterns.any(
        (p) => p.hasMatch(bodySource),
      );
      final bool clearsCache = _logoutCachePatterns.any(
        (p) => p.hasMatch(bodySource),
      );

      if (!clearsStorage || (!clearsToken && !clearsCache)) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when auth tokens are passed in query parameters.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v3
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
  AvoidAuthInQueryParamsRule() : super(code: _code);

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
    'avoid_auth_in_query_params',
    '[avoid_auth_in_query_params] Query params are logged in server logs, '
        'browser history, and referrer headers, leaking auth tokens. {v3}',
    correctionMessage:
        'Move token to Authorization header to prevent logging and leakage.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addStringInterpolation((StringInterpolation node) {
      final String fullString = node.toSource().toLowerCase();

      for (final String pattern in _tokenPatterns) {
        if (fullString.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });

    context.addAdjacentStrings((AdjacentStrings node) {
      final String fullString = node.toSource().toLowerCase();

      for (final String pattern in _tokenPatterns) {
        if (fullString.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });

    context.addBinaryExpression((BinaryExpression node) {
      // Check for string concatenation with token
      if (node.operator.lexeme != '+') return;

      final String fullExpr = node.toSource().toLowerCase();
      for (final String pattern in _tokenPatterns) {
        if (fullExpr.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when deep link handlers don't validate parameters.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v3
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
class RequireDataEncryptionRule extends SaropaLintRule {
  RequireDataEncryptionRule() : super(code: _code);

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
    'require_data_encryption',
    '[require_data_encryption] Unencrypted sensitive data exposes '
        'credentials to attackers via device access or backup extraction. {v5}',
    correctionMessage:
        'Use flutter_secure_storage, encrypted Hive box, or AES encryption.',
    severity: DiagnosticSeverity.WARNING,
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
  static final List<RegExp> _secureStorageTargetPatterns = [
    RegExp(r'\bsecure\b'),
    RegExp(r'\bencrypt\b'),
    RegExp(r'\bencryptedbox\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'setString' &&
          methodName != 'put' &&
          methodName != 'write' &&
          methodName != 'writeAsString' &&
          methodName != 'writeAsBytes' &&
          methodName != 'insert') {
        return;
      }

      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        if (_secureStorageTargetPatterns.any((p) => p.hasMatch(targetSource))) {
          return;
        }
      }

      // Check if key/value contains sensitive data
      final String nodeSource = node.toSource().toLowerCase();

      for (final String keyword in _sensitiveKeywords) {
        if (nodeSource.contains(keyword)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when sensitive data is displayed without masking.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
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
class RequireSecurePasswordFieldRule extends SaropaLintRule {
  RequireSecurePasswordFieldRule() : super(code: _code);

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
    'require_secure_password_field',
    '[require_secure_password_field] Password input fields must disable suggestions and autocorrect to prevent sensitive information from being stored in device dictionaries or suggested to users inappropriately. Failing to do so increases the risk of password leakage, accidental exposure, and poor user privacy. Always configure password fields to maximize security and user trust. {v5}',
    correctionMessage:
        'Set enableSuggestions: false and autocorrect: false on all password fields (TextField, TextFormField, CupertinoTextField) to prevent password suggestions and autocorrect. This helps protect user credentials from being stored or exposed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

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
      final bool hasEnableSuggestions = nodeSource.contains(
        'enableSuggestions: false',
      );
      final bool hasAutocorrect = nodeSource.contains('autocorrect: false');

      if (!hasEnableSuggestions || !hasAutocorrect) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when File/Directory paths include function parameters without
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v7
///
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
class RequireSecureStorageForAuthRule extends SaropaLintRule {
  RequireSecureStorageForAuthRule() : super(code: _code);

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
    'require_secure_storage_for_auth',
    '[require_secure_storage_for_auth] Auth tokens in SharedPreferences '
        'leak via backup extraction, enabling account takeover. {v4}',
    correctionMessage:
        'Use FlutterSecureStorage for JWT, bearer tokens, and auth credentials.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Target source patterns for SharedPreferences (word-boundary).
  static final List<RegExp> _prefTargetSourcePatterns = [
    RegExp(r'\bpref\b'),
    RegExp(r'\bsharedpreferences\b'),
  ];

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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'setString') return;

      // Check if it's SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetType = target.staticType?.toString() ?? '';
      final String targetSource = target.toSource().toLowerCase();

      final bool isPrefs =
          targetType.contains('SharedPreferences') ||
          _prefTargetSourcePatterns.any((p) => p.hasMatch(targetSource));

      if (!isPrefs) return;

      // Check VALUE argument for auth patterns (key is checked by other rule)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) return;

      final String valueSource = args[1].toSource().toLowerCase();

      for (final String pattern in _authValuePatterns) {
        if (valueSource.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when Uri.parse is used on user input without scheme validation.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v5
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
class PreferLocalAuthRule extends SaropaLintRule {
  PreferLocalAuthRule() : super(code: _code);

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
    'prefer_local_auth',
    '[prefer_local_auth] Payment/sensitive operation without biometric authentication. Critical operations like payments should require additional authentication to prevent unauthorized access even if the device is unlocked. {v3}',
    correctionMessage:
        'Add LocalAuthentication().authenticate() before sensitive operations. Audit similar patterns across the codebase to ensure consistent security practices.',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _sensitiveOperationPatterns = [
    RegExp(r'\bpayment\b'),
    RegExp(r'\bcharge\b'),
    RegExp(r'\btransfer\b'),
    RegExp(r'\bwithdraw\b'),
    RegExp(r'\bdelete_account\b'),
    RegExp(r'\bdeleteaccount\b'),
    RegExp(r'\bchange_password\b'),
    RegExp(r'\bchangepassword\b'),
    RegExp(r'\bexport\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((node) {
      final methodName = node.name.lexeme.toLowerCase();

      // Check if method name suggests sensitive operation
      final isSensitive = _sensitiveOperationPatterns.any(
        (p) => p.hasMatch(methodName),
      );

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

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// Part 6: Additional Security Rules
// =============================================================================

/// Warns when JWT/auth tokens are stored in SharedPreferences.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v3
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
  RequireSecureStorageAuthDataRule() : super(code: _code);

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
    'require_secure_storage_auth_data',
    '[require_secure_storage_auth_data] Plaintext auth tokens enable '
        'session hijacking via device backup or physical access. {v3}',
    correctionMessage:
        'Replace SharedPreferences with FlutterSecureStorage for sensitive data.',
    severity: DiagnosticSeverity.ERROR,
  );

  static final List<RegExp> _prefsTargetSourcePatterns = [
    RegExp(r'\bprefs\b'),
    RegExp(r'\bsharedpreferences\b'),
    RegExp(r'\bpreferences\b'),
  ];

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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for SharedPreferences set methods
      final methodName = node.methodName.name;
      if (methodName != 'setString' && methodName != 'setStringList') return;

      // Check target is SharedPreferences-like
      final target = node.target;
      if (target == null) return;
      final targetSource = target.toSource().toLowerCase();
      if (!_prefsTargetSourcePatterns.any((p) => p.hasMatch(targetSource))) {
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
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
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
class AvoidStoringSensitiveUnencryptedRule extends SaropaLintRule {
  AvoidStoringSensitiveUnencryptedRule() : super(code: _code);

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
    'avoid_storing_sensitive_unencrypted',
    '[avoid_storing_sensitive_unencrypted] Unencrypted sensitive data exposed '
        'via device backup extraction or rooted device access, enabling identity theft. {v4}',
    correctionMessage:
        'Use flutter_secure_storage or an encrypted Hive box for sensitive data.',
    severity: DiagnosticSeverity.ERROR,
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

  static final List<RegExp> _skipSecureTargetPatterns = [
    RegExp(r'\bsecure\b'),
    RegExp(r'\bencrypted\b'),
  ];

  static final List<RegExp> _storageTargetPatterns = [
    RegExp(r'\bpref\b'),
    RegExp(r'\bbox\b'),
    RegExp(r'\bstorage\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_unsecureMethods.contains(methodName)) return;

      // Check target for SharedPreferences or Hive box
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      // Skip if using secure storage
      if (_skipSecureTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      // Check if it's SharedPreferences or Hive
      final bool isStorage = _storageTargetPatterns.any(
        (p) => p.hasMatch(targetSource),
      );

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
        keyValue = (firstArg.expression as SimpleStringLiteral).value
            .toLowerCase();
      }

      if (keyValue != null) {
        for (final String sensitiveKey in _sensitiveKeys) {
          if (keyValue.contains(sensitiveKey)) {
            reporter.atNode(node);
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
/// Since: v4.0.0 | Updated: v4.13.0 | Rule version: v3
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
class RequireSecureStorageErrorHandlingRule extends SaropaLintRule {
  RequireSecureStorageErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_secure_storage_error_handling',
    '[require_secure_storage_error_handling] Secure storage operation '
        'without error handling. May fail on some devices. {v3}',
    correctionMessage: 'Wrap in try-catch to handle PlatformException.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _secureStorageMethods = <String>{
    'read',
    'write',
    'delete',
    'deleteAll',
    'readAll',
    'containsKey',
  };

  static final List<RegExp> _secureStorageTargetPatterns = [
    RegExp(r'\bsecurestorage\b'),
    RegExp(r'\bflutter_secure_storage\b'),
    RegExp(r'\b_storage\b'),
    RegExp(r'\bkeychain\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAwaitExpression((AwaitExpression node) {
      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      // Check if this is a secure storage call
      final String methodName = expr.methodName.name;
      if (!_secureStorageMethods.contains(methodName)) return;

      // Check if target looks like secure storage
      final Expression? target = expr.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_secureStorageTargetPatterns.any((p) => p.hasMatch(targetSource))) {
        return;
      }

      // Check if inside try-catch
      if (_isInsideTryCatch(node)) return;

      reporter.atNode(node);
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
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v3
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
  AvoidSecureStorageLargeDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_secure_storage_large_data',
    '[avoid_secure_storage_large_data] `[HEURISTIC]` Storing large data in '
        'secure storage. It\'s designed for small secrets like tokens. {v3}',
    correctionMessage:
        'Use encrypted file storage for large data. Secure storage is slow '
        'and has size limits.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _secureStorageTargetShortPatterns = [
    RegExp(r'\bsecurestorage\b'),
    RegExp(r'\b_storage\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'write') return;

      // Check if target is secure storage
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!_secureStorageTargetShortPatterns.any(
        (p) => p.hasMatch(targetSource),
      )) {
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
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when FlutterSecureStorage is used without biometric protection.
///
/// Since: v4.13.0 | Rule version: v1
///
/// **Purpose for developers:** Sensitive data in [FlutterSecureStorage](https://pub.dev/packages/flutter_secure_storage)
/// should require device unlock or biometrics so that reading/writing is protected
/// when the device is locked. This rule flags any FlutterSecureStorage constructor
/// call that does not pass [AndroidOptions](https://pub.dev/documentation/flutter_secure_storage/latest/android_options/AndroidOptions-class.html)
/// or [IOSOptions](https://pub.dev/documentation/flutter_secure_storage/latest/ios_options/IOSOptions-class.html)
/// with `authenticationRequired: true`. Detection is exact: we only check for the
/// named args `aOptions`/`iOptions` and the named arg `authenticationRequired`
/// set to `true` inside those option constructors. No string heuristics.
///
/// **BAD:**
/// ```dart
/// final storage = FlutterSecureStorage();
/// // or
/// final storage = FlutterSecureStorage(
///   aOptions: AndroidOptions(encryptedSharedPreferences: true),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final storage = FlutterSecureStorage(
///   aOptions: AndroidOptions(authenticationRequired: true),
///   iOptions: IOSOptions(authenticationRequired: true),
/// );
/// ```
class PreferBiometricProtectionRule extends SaropaLintRule {
  PreferBiometricProtectionRule() : super(code: _code);

  /// Sensitive data without biometric gate is a security gap.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m2, OwaspMobile.m9},
    web: <OwaspWeb>{OwaspWeb.a02},
  );

  static const LintCode _code = LintCode(
    'prefer_biometric_protection',
    '[prefer_biometric_protection] FlutterSecureStorage should use '
        'authenticationRequired in options so access requires device unlock or biometrics. {v1}',
    correctionMessage:
        'Add aOptions: AndroidOptions(authenticationRequired: true) and/or '
        'iOptions: IOSOptions(authenticationRequired: true) to FlutterSecureStorage.',
    severity: DiagnosticSeverity.INFO,
  );

  static bool _hasAuthenticationRequired(Expression optionsExpr) {
    if (optionsExpr is! InstanceCreationExpression) return false;
    for (final arg in optionsExpr.argumentList.arguments) {
      if (arg is NamedExpression &&
          arg.name.label.name == 'authenticationRequired') {
        final expr = arg.expression;
        if (expr is BooleanLiteral && expr.value) return true;
      }
    }
    return false;
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'FlutterSecureStorage') return;

      bool hasBiometric = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          if (name == 'aOptions' || name == 'iOptions') {
            if (_hasAuthenticationRequired(arg.expression)) {
              hasBiometric = true;
              break;
            }
          }
        }
      }

      if (!hasBiometric) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// Clipboard Security Rules (from v4.1.7)
// =============================================================================

/// Warns when sensitive data is copied to clipboard.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v3
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
  AvoidSensitiveDataInClipboardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_sensitive_data_in_clipboard',
    '[avoid_sensitive_data_in_clipboard] Copying sensitive data such as passwords, tokens, or personal information to the clipboard exposes users to data theft, as other apps or malicious actors can access clipboard contents. This is a significant privacy and security risk, especially on shared or compromised devices. See https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure.html and https://api.flutter.dev/flutter/services/Clipboard-class.html. {v3}',
    correctionMessage:
        'Avoid placing sensitive data on the clipboard and implement safeguards to prevent accidental exposure. Educate users about the risks and follow platform-specific security guidelines. See https://owasp.org/www-project-top-ten/2017/A3_2017-Sensitive_Data_Exposure.html and https://api.flutter.dev/flutter/services/Clipboard-class.html.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _sensitivePattern = RegExp(
    r'\b(password|passwd|pwd|secret|token|apiKey|api_key|accessToken|'
    r'access_token|refreshToken|refresh_token|privateKey|private_key|'
    r'secretKey|secret_key|credential|authToken|bearer|jwt|pin|otp)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setData') return;

      // Check if called on Clipboard
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check the argument for sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (_sensitivePattern.hasMatch(argSource)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when clipboard paste is used without validation.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
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
  RequireClipboardPasteValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_clipboard_paste_validation',
    '[require_clipboard_paste_validation] Clipboard data used without validation. Pasted content can be unexpected format or malicious. Validate clipboard data before using it. This creates a security vulnerability that attackers can exploit to compromise user data or application integrity. {v2}',
    correctionMessage:
        'Validate clipboard content format and sanitize before using. Audit similar patterns across the codebase to ensure consistent security practices.',
    severity: DiagnosticSeverity.INFO,
  );

  static final List<RegExp> _validationLogicPatterns = [
    RegExp(r'\bisValid\b'),
    RegExp(r'\bvalidate\b'),
    RegExp(r'\bRegExp\b'),
    RegExp(r'\.contains\('),
    RegExp(r'\.startsWith\('),
    RegExp(r'\.length\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(node);
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
    final String blockSource = block.toSource();
    return _validationLogicPatterns.any((p) => p.hasMatch(blockSource));
  }
}

/// Warns when encryption keys are stored as class fields.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
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
  AvoidEncryptionKeyInMemoryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_encryption_key_in_memory',
    '[avoid_encryption_key_in_memory] Encryption key stored as a persistent class field remains in process memory for the lifetime of the object. Memory dumps, debugging tools, or memory-scanning malware can extract the key, compromising all data encrypted with it. Keys in memory survive garbage collection and are visible in heap snapshots. {v2}',
    correctionMessage:
        'Load encryption keys on demand from secure storage, use them immediately for the operation, and clear the variable after use to minimize the exposure window.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _keyFieldPattern = RegExp(
    r'\b(encryption|private|secret|aes|rsa|hmac).*key\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final String fieldName = variable.name.lexeme;

        if (_keyFieldPattern.hasMatch(fieldName)) {
          // Check if it's a final field (stored persistently)
          if (node.fields.isFinal || node.fields.isConst) {
            reporter.atNode(variable);
          }
        }
      }
    });
  }
}

// =============================================================================
// OAUTH PKCE RULES
// =============================================================================

/// Warns when OAuth authorization flows lack PKCE (Proof Key for Code
/// Exchange) parameters.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Mobile OAuth without PKCE is vulnerable to authorization code
/// interception attacks. A malicious app can intercept the redirect URI
/// and steal the authorization code. PKCE adds a code verifier/challenge
/// pair that prevents this attack. All mobile OAuth flows should use PKCE.
///
/// **BAD:**
/// ```dart
/// final result = await appAuth.authorizeAndExchangeCode(
///   AuthorizationTokenRequest('clientId', 'redirectUrl',
///     serviceConfiguration: config),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await appAuth.authorizeAndExchangeCode(
///   AuthorizationTokenRequest('clientId', 'redirectUrl',
///     serviceConfiguration: config,
///     codeVerifier: generateCodeVerifier()),
/// );
/// ```
class PreferOauthPkceRule extends SaropaLintRule {
  PreferOauthPkceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_oauth_pkce',
    '[prefer_oauth_pkce] OAuth authorization request without PKCE (Proof Key for Code Exchange). Mobile OAuth flows without PKCE are vulnerable to authorization code interception — a malicious app registers for the same redirect URI and steals the code before your app receives it. PKCE binds the authorization request to the token exchange with a code verifier/challenge pair, preventing interception. All mobile OAuth flows must use PKCE per RFC 7636. {v1}',
    correctionMessage:
        'Add codeVerifier (or codeChallenge) parameter to the authorization request. Use a cryptographically random code verifier generated with PKCE utilities.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Constructor/class names related to OAuth authorization.
  static const Set<String> _oauthConstructors = <String>{
    'AuthorizationTokenRequest',
    'AuthorizationRequest',
    'EndSessionRequest',
  };

  /// Method names related to OAuth authorization.
  static const Set<String> _oauthMethods = <String>{
    'authorizeAndExchangeCode',
    'authorize',
    'exchangeCode',
  };

  static final List<RegExp> _oauthTargetPatterns = [
    RegExp(r'appAuth'),
    RegExp(r'AppAuth'),
    RegExp(r'oauth'),
    RegExp(r'OAuth'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check OAuth constructor calls for PKCE parameters
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_oauthConstructors.contains(typeName)) return;

      // Check for PKCE-related parameters
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'codeVerifier' ||
              paramName == 'codeChallenge' ||
              paramName == 'pkce') {
            return; // Has PKCE, OK
          }
        }
      }

      reporter.atNode(node.constructorName, code);
    });

    // Check OAuth method calls
    context.addMethodInvocation((MethodInvocation node) {
      if (!_oauthMethods.contains(node.methodName.name)) return;

      // Check if target looks like an OAuth/AppAuth instance
      final String? targetSource = node.target?.toSource();
      if (targetSource == null) return;

      final bool isOAuth = _oauthTargetPatterns.any(
        (p) => p.hasMatch(targetSource),
      );

      if (!isOAuth) return;

      // Check if arguments contain PKCE parameters
      final String argsSource = node.argumentList.toSource();
      if (argsSource.contains('codeVerifier') ||
          argsSource.contains('codeChallenge') ||
          argsSource.contains('pkce')) {
        return; // Has PKCE, OK
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// require_session_timeout
// =============================================================================

/// Warns when authentication sign-in calls lack session timeout handling.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Sessions without timeout remain valid forever if tokens are stolen.
/// Authentication sign-in calls should be paired with idle timeout and
/// absolute session limit logic. Without timeouts, compromised tokens
/// grant indefinite access to user accounts.
///
/// **BAD:**
/// ```dart
/// Future<void> login() async {
///   await FirebaseAuth.instance.signInWithEmailAndPassword(
///     email: email,
///     password: password,
///   );
///   // No session timeout configured
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> login() async {
///   await FirebaseAuth.instance.signInWithEmailAndPassword(
///     email: email,
///     password: password,
///   );
///   _sessionTimer = Timer(sessionTimeout, _handleSessionExpiry);
/// }
/// ```
class RequireSessionTimeoutRule extends SaropaLintRule {
  RequireSessionTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'signIn', 'signUp'};

  static const LintCode _code = LintCode(
    'require_session_timeout',
    '[require_session_timeout] Authentication sign-in without session '
        'timeout handling. Sessions without timeout remain valid forever if '
        'tokens are stolen or compromised. This is a security risk that '
        'allows indefinite access to user accounts. Implement idle timeout '
        'and absolute session limits after successful authentication. {v1}',
    correctionMessage:
        'Add session timeout logic (Timer, Duration) after sign-in to '
        'automatically expire sessions.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Method name patterns that indicate authentication sign-in.
  /// Only matches Firebase/Auth SDK methods to minimize false positives.
  static const Set<String> _signInMethods = <String>{
    'signIn',
    'signInWithEmailAndPassword',
    'signInWithCredential',
    'signInWithCustomToken',
    'signInWithPopup',
    'signInWithRedirect',
    'signInAnonymously',
    'signInWithPhoneNumber',
    'signInWithProvider',
    'signInWithApple',
    'signInWithGoogle',
  };

  /// Tokens that indicate session timeout handling is present.
  static const Set<String> _timeoutIndicators = <String>{
    'Timer(',
    'sessionTimeout',
    'sessionExpiry',
    'sessionDuration',
    'idleTimeout',
    'tokenExpiry',
    'expiresIn',
    'expiresAt',
    'refreshToken',
    'sessionTimer',
    'autoLogout',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if this is a sign-in method
      if (!_isSignInMethod(methodName)) return;

      // Check the enclosing method/function for timeout handling
      final AstNode? enclosingMethod = _findEnclosingMethod(node);
      if (enclosingMethod == null) return;

      final String bodySource = enclosingMethod.toSource();

      // Check if timeout handling exists in the enclosing method
      for (final String indicator in _timeoutIndicators) {
        if (RegExp(RegExp.escape(indicator)).hasMatch(bodySource)) return;
      }

      reporter.atNode(node);
    });
  }

  bool _isSignInMethod(String name) {
    if (_signInMethods.contains(name)) return true;
    // Match methods starting with signIn/signUp (Firebase convention)
    if (name.startsWith('signIn') || name.startsWith('signUp')) return true;
    return false;
  }

  AstNode? _findEnclosingMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

// =============================================================================
// avoid_stack_trace_in_production
// =============================================================================

/// Warns when stack traces are exposed to users in production code.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: no_stack_trace_leak, hide_stack_trace
///
/// Stack traces contain internal architecture details: class names, file
/// paths, package versions, and line numbers. Exposing them to users via
/// `print()`, `Text()`, error dialogs, or `SnackBar` content leaks
/// implementation details that aid attackers in crafting targeted exploits.
///
/// **OWASP:** `M10:Extraneous-Functionality`
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   print(stackTrace);
///   showDialog(
///     context: context,
///     builder: (_) => Text('$stackTrace'),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   // Log to crash reporter, not to user
///   FirebaseCrashlytics.instance.recordError(e, stackTrace);
///   if (kDebugMode) print(stackTrace);
///   showDialog(
///     context: context,
///     builder: (_) => Text('Something went wrong. Please try again.'),
///   );
/// }
/// ```

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// SharedPreferences-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of SharedPreferences including
/// key management, data size limits, security, and null handling.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_prefs_for_large_data (from firebase_rules.dart)
// =============================================================================

/// Warns when SharedPreferences is used to store large data.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: no_large_prefs, use_database_for_large_data
///
/// SharedPreferences loads the entire file on first access. Storing large
/// amounts of data causes slow startup and memory issues. Use a database
/// for collections or large values.
///
/// **BAD:**
/// ```dart
/// // Storing large list in SharedPreferences
/// prefs.setStringList('all_users', hundredsOfUsers);
///
/// // Storing large JSON blob
/// prefs.setString('cache_data', jsonEncode(largeData));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use Hive, Isar, or SQLite for collections
/// await box.put('users', users);
///
/// // Use SharedPreferences only for small settings
/// prefs.setBool('dark_mode', true);
/// prefs.setString('locale', 'en_US');
/// ```
class AvoidPrefsForLargeDataRule extends SaropaLintRule {
  AvoidPrefsForLargeDataRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_prefs_for_large_data',
    '[avoid_prefs_for_large_data] SharedPreferences loads its entire file into memory on first access, making it unsuitable for large datasets. Storing collections or large JSON blobs here causes slow app startup, excessive memory consumption, UI freezes, and potential data corruption on write failures. {v3}',
    correctionMessage:
        'Use a database such as Hive, Isar, or SQLite for collections and large data. Reserve SharedPreferences for small, simple settings like booleans and locale strings.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for setStringList which is often misused for large data
      if (methodName != 'setStringList') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if target looks like SharedPreferences
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check for patterns that suggest large data storage
      if (node.argumentList.arguments.length >= 2) {
        final Expression keyArg = node.argumentList.arguments.first;
        final String keySource = keyArg.toSource().toLowerCase();

        // Flag keys that suggest storing collections
        final List<String> largeDataPatterns = <String>[
          'users',
          'items',
          'products',
          'orders',
          'messages',
          'history',
          'cache',
          'data',
          'list',
          'all_',
          'every',
        ];

        if (largeDataPatterns.any((String p) => keySource.contains(p))) {
          reporter.atNode(node);
        }
      }
    });
  }
}

// =============================================================================
// require_shared_prefs_prefix (from hive_rules.dart)
// =============================================================================

/// Warns when SharedPreferences.setPrefix is not called for app isolation.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Setting a prefix avoids key conflicts between different apps or plugins
/// that use SharedPreferences.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// prefs.setString('theme', 'dark'); // Could conflict with plugins
/// ```
///
/// **GOOD:**
/// ```dart
/// SharedPreferences.setPrefix('myapp_');
/// final prefs = await SharedPreferences.getInstance();
/// prefs.setString('theme', 'dark'); // Now prefixed as 'myapp_theme'
/// ```
class RequireSharedPrefsPrefixRule extends SaropaLintRule {
  RequireSharedPrefsPrefixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_shared_prefs_prefix',
    '[require_shared_prefs_prefix] SharedPreferences usage detected. '
        'Consider calling SharedPreferences.setPrefix() to avoid key conflicts. {v2}',
    correctionMessage:
        'Call SharedPreferences.setPrefix("myapp_") at app startup.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'SharedPreferences') return;

      // Check for getInstance() without setPrefix
      if (node.methodName.name == 'getInstance') {
        // This is an INFO-level reminder
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_shared_prefs_async_api (from hive_rules.dart)
// =============================================================================

/// Warns when legacy SharedPreferences API is used instead of SharedPreferencesAsync.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// SharedPreferencesAsync provides better error handling and is the recommended
/// API for new code.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// await prefs.setString('key', 'value');
/// ```
///
/// **GOOD:**
/// ```dart
/// final prefs = SharedPreferencesAsync();
/// await prefs.setString('key', 'value');
/// ```
class PreferSharedPrefsAsyncApiRule extends SaropaLintRule {
  PreferSharedPrefsAsyncApiRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_shared_prefs_async_api',
    '[prefer_shared_prefs_async_api] Legacy SharedPreferences.getInstance() '
        'detected. Consider using SharedPreferencesAsync for new code. {v2}',
    correctionMessage:
        'Use SharedPreferencesAsync() instead of SharedPreferences.getInstance().',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'SharedPreferences') return;

      if (node.methodName.name == 'getInstance') {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_shared_prefs_in_isolate (from hive_rules.dart)
// =============================================================================

/// Warns when SharedPreferences is used inside an isolate.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// SharedPreferences doesn't work in isolates. Use alternative storage
/// or pass data through ports.
///
/// **BAD:**
/// ```dart
/// Future<void> backgroundTask(SendPort sendPort) async {
///   final prefs = await SharedPreferences.getInstance(); // Won't work!
///   final value = prefs.getString('key');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> backgroundTask(Map<String, dynamic> data) async {
///   final key = data['key']; // Pass data instead of using prefs
/// }
/// ```
class AvoidSharedPrefsInIsolateRule extends SaropaLintRule {
  AvoidSharedPrefsInIsolateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_shared_prefs_in_isolate',
    '[avoid_shared_prefs_in_isolate] SharedPreferences used in isolate context. '
        'SharedPreferences does not work in isolates. {v2}',
    correctionMessage:
        'Pass required data through SendPort/ReceivePort instead.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'SharedPreferences') return;

      if (node.methodName.name == 'getInstance') {
        // Check if inside an isolate context
        if (_isInsideIsolateContext(node)) {
          reporter.atNode(node);
        }
      }
    });
  }

  bool _isInsideIsolateContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionDeclaration) {
        // Check for common isolate entry point patterns
        final params = current.functionExpression.parameters;
        if (params != null) {
          for (final param in params.parameters) {
            final typeName = _getParameterTypeName(param);
            if (typeName == 'SendPort' ||
                typeName == 'ReceivePort' ||
                typeName == 'IsolateStartRequest') {
              return true;
            }
          }
        }
        // Check function name for isolate hints
        final name = current.name.lexeme.toLowerCase();
        if (name.contains('isolate') ||
            name.contains('background') ||
            name.contains('worker')) {
          return true;
        }
      }
      // Check for Isolate.spawn or compute context
      if (current is MethodInvocation) {
        final methodName = current.methodName.name;
        if (methodName == 'spawn' || methodName == 'compute') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  String? _getParameterTypeName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      final inner = param.parameter;
      if (inner is SimpleFormalParameter) {
        return inner.type?.toSource();
      }
    }
    return null;
  }
}

// =============================================================================
// prefer_typed_prefs_wrapper (from package_specific_rules.dart)
// =============================================================================

/// Warns when SharedPreferences is used directly without a typed wrapper.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: typed_prefs, shared_preferences_wrapper
///
/// Direct SharedPreferences access scatters string keys throughout code and
/// lacks type safety. Create a typed wrapper class for maintainability.
///
/// **BAD:**
/// ```dart
/// // Scattered throughout codebase
/// final prefs = await SharedPreferences.getInstance();
/// prefs.setString('user_name', name);  // Typo-prone key
/// prefs.setInt('user-age', age);       // Inconsistent naming
///
/// // Elsewhere...
/// final name = prefs.getString('userName'); // Wrong key, returns null!
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserPreferences {
///   static const _keyName = 'user_name';
///   static const _keyAge = 'user_age';
///
///   final SharedPreferences _prefs;
///   UserPreferences(this._prefs);
///
///   String? get userName => _prefs.getString(_keyName);
///   set userName(String? value) =>
///       value == null ? _prefs.remove(_keyName) : _prefs.setString(_keyName, value);
///
///   int get userAge => _prefs.getInt(_keyAge) ?? 0;
///   set userAge(int value) => _prefs.setInt(_keyAge, value);
/// }
/// ```
class PreferTypedPrefsWrapperRule extends SaropaLintRule {
  PreferTypedPrefsWrapperRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_typed_prefs_wrapper',
    '[prefer_typed_prefs_wrapper] Direct SharedPreferences access with '
        'string literal key. Scattered keys are error-prone. {v2}',
    correctionMessage:
        'Create a typed wrapper class with properties for each preference.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SharedPreferences set/get methods
      if (!methodName.startsWith('set') && !methodName.startsWith('get')) {
        return;
      }

      // Check target for SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check if key is a string literal (not a constant)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression keyArg = args.first;
      if (keyArg is SimpleStringLiteral) {
        // Direct string literal - suggests not using a wrapper
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_auth_state_in_prefs (from security_rules.dart)
// =============================================================================

/// Warns when auth tokens are stored in SharedPreferences instead of secure storage.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v2
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
  AvoidAuthStateInPrefsRule() : super(code: _code);

  /// Auth tokens in SharedPreferences are stored as plain text.
  /// Each occurrence exposes credentials on rooted devices.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m9},
    web: <OwaspWeb>{OwaspWeb.a02, OwaspWeb.a07},
  );

  static const LintCode _code = LintCode(
    'avoid_auth_state_in_prefs',
    '[avoid_auth_state_in_prefs] SharedPreferences stores tokens in '
        'plaintext, exposing credentials on rooted devices or backups. {v2}',
    correctionMessage:
        'Use flutter_secure_storage or platform keychain for sensitive data.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// =============================================================================
// prefer_encrypted_prefs (from security_rules.dart)
// =============================================================================

/// Warns when sensitive data uses SharedPreferences instead of encrypted storage.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v2
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
  PreferEncryptedPrefsRule() : super(code: _code);

  /// Sensitive data in SharedPreferences is unencrypted.
  /// Each occurrence exposes personal data.
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
    'prefer_encrypted_prefs',
    '[prefer_encrypted_prefs] Unencrypted sensitive data is exposed via '
        'device backup, file browser, or rooted device access. {v2}',
    correctionMessage:
        'Use flutter_secure_storage or encrypted_shared_preferences.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_shared_prefs_sensitive_data (from security_rules.dart)
// =============================================================================

/// Warns when sensitive data is stored in SharedPreferences.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_storing_sensitive_in_prefs, no_sensitive_prefs, prefs_sensitive_data
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
  AvoidSharedPrefsSensitiveDataRule() : super(code: _code);

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
    'avoid_shared_prefs_sensitive_data',
    '[avoid_shared_prefs_sensitive_data] SharedPreferences stores data '
        'as plaintext XML, readable via backup extraction or rooted device. {v3}',
    correctionMessage:
        'Use flutter_secure_storage for passwords, tokens, and API keys.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// =============================================================================
// require_shared_prefs_null_handling (from security_rules.dart)
// =============================================================================

/// Warns when SharedPreferences getter results are used without null handling.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireSharedPrefsNullHandlingRule() : super(code: _code);

  /// Null assertion on SharedPreferences getter causes runtime crash
  /// when key doesn't exist - a common source of production crashes.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_shared_prefs_null_handling',
    '[require_shared_prefs_null_handling] SharedPreferences getter with null assertion (!) crashes with a NoSuchMethodError if the key does not exist. This is a common source of production crashes on first launch, after app updates that add new preference keys, or when storage is cleared by the OS under memory pressure. {v3}',
    correctionMessage:
        'Use the null-aware operator (??) with a sensible default value, or handle the nullable return type explicitly to prevent null assertion crashes in production.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPostfixExpression((PostfixExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// require_shared_prefs_key_constants (from security_rules.dart)
// =============================================================================

/// Warns when string literals are used as SharedPreferences keys.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v4
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
  RequireSharedPrefsKeyConstantsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_shared_prefs_key_constants',
    '[require_shared_prefs_key_constants] String literal used as SharedPreferences key. Use named constants. Using string literals for keys is error-prone and makes refactoring difficult. Define keys as constants for type safety and easier maintenance. {v4}',
    correctionMessage:
        'Define keys as constants (e.g., static const kUserName = "user_name"). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(keyArg);
      }
    });
  }
}

// =============================================================================
// SHARED PREFERENCES LARGE DATA RULES
// =============================================================================

/// Warns when SharedPreferences is used to store large or serialized data.
///
/// Since: v4.15.0 | Rule version: v1
///
/// SharedPreferences is backed by an XML file (Android) or plist (iOS)
/// that is read entirely into memory on first access. Storing large JSON
/// blobs, base64 images, or serialized objects degrades startup time and
/// wastes memory. Use a proper database (Hive, Isar, sqflite) for data
/// larger than simple key-value pairs.
///
/// **BAD:**
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// await prefs.setString('user_data', jsonEncode(largeObject));
/// ```
///
/// **GOOD:**
/// ```dart
/// final box = await Hive.openBox('userData');
/// await box.put('user_data', largeObject);
/// ```
class AvoidSharedPrefsLargeDataRule extends SaropaLintRule {
  AvoidSharedPrefsLargeDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_shared_prefs_large_data',
    '[avoid_shared_prefs_large_data] SharedPreferences setString called with serialized data (jsonEncode, json.encode, toJson, toString). SharedPreferences loads the entire XML/plist file into memory on first access. Storing JSON blobs or serialized objects wastes memory, degrades app startup time, and risks exceeding platform limits. Use a proper database (Hive, Isar, sqflite) for structured or large data. {v1}',
    correctionMessage:
        'Use a local database (Hive, Isar, or sqflite) for storing serialized objects. SharedPreferences is intended for simple key-value pairs like booleans, small strings, and numbers.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Patterns in the value argument that indicate serialized data.
  static const Set<String> _serializationPatterns = <String>{
    'jsonEncode',
    'json.encode',
    'toJson',
    'toMap',
    'serialize',
    'base64Encode',
    'base64.encode',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'setString' && methodName != 'setStringList') return;

      // Check if target is SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') &&
          !targetSource.contains('sharedpreferences')) {
        return;
      }

      // Check if value argument contains serialization
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.length < 2) return;

      final String valueSource = args[1].toSource();
      for (final String pattern in _serializationPatterns) {
        if (valueSource.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_shared_prefs_sync_race
// =============================================================================

/// Warns when SharedPreferences write methods are not awaited in async code.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: prefs_await_writes, shared_prefs_race_condition
///
/// SharedPreferences write methods (`setBool`, `setString`, etc.) return
/// `Future<bool>`. When multiple writes are not awaited, they execute
/// concurrently with non-deterministic ordering. The last write wins,
/// potentially losing earlier values. This is especially dangerous during
/// logout/cleanup flows where multiple preferences are cleared.
///
/// **BAD:**
/// ```dart
/// Future<void> saveSettings() async {
///   prefs.setBool('darkMode', true);    // Not awaited!
///   prefs.setString('locale', 'en');    // Race condition!
///   prefs.setInt('fontSize', 16);       // May overwrite others!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> saveSettings() async {
///   await prefs.setBool('darkMode', true);
///   await prefs.setString('locale', 'en');
///   await prefs.setInt('fontSize', 16);
/// }
/// ```
class AvoidSharedPrefsSyncRaceRule extends SaropaLintRule {
  AvoidSharedPrefsSyncRaceRule() : super(code: _code);

  /// Race conditions cause silent data loss.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_shared_prefs_sync_race',
    '[avoid_shared_prefs_sync_race] SharedPreferences write method called '
        'without await in async context. Un-awaited writes execute concurrently '
        'with non-deterministic ordering, so the last write wins and earlier '
        'values may be silently lost. This is especially dangerous during '
        'logout or cleanup flows where multiple preferences are cleared. {v1}',
    correctionMessage:
        'Add await before the SharedPreferences write call to ensure '
        'sequential execution.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _writeMethods = <String>{
    'setBool',
    'setString',
    'setInt',
    'setDouble',
    'setStringList',
    'remove',
    'clear',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_writeMethods.contains(node.methodName.name)) return;

      // Check if target looks like SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') &&
          !targetSource.contains('sharedpreferences')) {
        return;
      }

      // Already awaited — OK
      if (node.parent is AwaitExpression) return;

      // Explicitly marked fire-and-forget — OK
      final AstNode? grandparent = node.parent?.parent;
      if (grandparent is MethodInvocation &&
          grandparent.methodName.name == 'unawaited') {
        return;
      }

      // Check if inside async function
      if (!_isInsideAsyncFunction(node)) return;

      reporter.atNode(node);
    });
  }

  bool _isInsideAsyncFunction(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        return current.body.isAsynchronous;
      }
      if (current is MethodDeclaration) {
        return current.body.isAsynchronous;
      }
      if (current is FunctionDeclaration) {
        return current.functionExpression.body.isAsynchronous;
      }
      current = current.parent;
    }
    return false;
  }
}

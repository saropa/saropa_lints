// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Android platform lint rules for Flutter applications.
///
/// These rules help ensure proper Android-specific configurations including
/// runtime permissions, splash screens, PendingIntent flags, and more.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// require_android_permission_request
// =============================================================================

/// Warns when Android permissions are declared but runtime request is missing.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: android_runtime_permission, request_permission
///
/// Android 6.0+ (API 23) requires runtime permission requests for dangerous
/// permissions. Declaring in manifest isn't enough; you must call
/// requestPermission() at runtime.
///
/// **BAD:**
/// ```dart
/// // Just using permission without requesting
/// final position = await Geolocator.getCurrentPosition();
/// final contacts = await ContactsService.getContacts();
/// ```
///
/// **GOOD:**
/// ```dart
/// // Request permission before using
/// final status = await Permission.location.request();
/// if (status.isGranted) {
///   final position = await Geolocator.getCurrentPosition();
/// }
/// ```
class RequireAndroidPermissionRequestRule extends SaropaLintRule {
  const RequireAndroidPermissionRequestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_android_permission_request',
    problemMessage:
        '[require_android_permission_request] Permission-gated API called without '
        'runtime permission request. Android 6+ will deny access or crash. {v2}',
    correctionMessage:
        'Call Permission.X.request() before using permission-gated APIs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// APIs that require runtime permissions
  static const Map<String, String> _permissionGatedApis = <String, String>{
    'getCurrentPosition': 'location',
    'getPositionStream': 'location',
    'getCurrentLocation': 'location',
    'getContacts': 'contacts',
    'pickImage': 'photos',
    'pickVideo': 'photos',
    'takePicture': 'camera',
    'availableCameras': 'camera',
    'CameraController': 'camera',
    'record': 'microphone',
    'startRecording': 'microphone',
    'getExternalStorageDirectory': 'storage',
    'scanForDevices': 'bluetooth',
    'startScan': 'bluetooth',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if this is a permission-gated API
      if (!_permissionGatedApis.containsKey(methodName)) return;

      // Check if there's a permission request in the same function
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      // Check for permission request patterns
      if (bodySource.contains('.request()') ||
          bodySource.contains('requestPermission') ||
          bodySource.contains('Permission.') ||
          bodySource.contains('permission_handler') ||
          bodySource.contains('.isGranted') ||
          bodySource.contains('checkPermission')) {
        return; // Has permission handling
      }

      reporter.atNode(node, code);
    });

    // Also check for CameraController instantiation
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'CameraController') return;

      // Check for permission request in surrounding context
      AstNode? functionBody;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();

      if (!bodySource.contains('.request()') &&
          !bodySource.contains('Permission.') &&
          !bodySource.contains('.isGranted')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// avoid_android_task_affinity_default
// =============================================================================

/// Warns when multiple activities use default taskAffinity.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: task_affinity, android_back_stack
///
/// Multiple activities with default taskAffinity can cause confusing back stack
/// behavior. Set explicit affinity for each activity in AndroidManifest.xml.
///
/// This rule detects code patterns that suggest multiple activities or deep
/// linking without proper configuration.
///
/// **BAD:**
/// ```dart
/// // Launching activity without considering back stack
/// await platform.invokeMethod('startActivity', {'class': 'SecondActivity'});
/// ```
///
/// **GOOD:**
/// ```dart
/// // Document that activities have explicit taskAffinity in manifest
/// // Or use Flutter's navigation which manages the stack properly
/// Navigator.push(context, MaterialPageRoute(...));
/// ```
class AvoidAndroidTaskAffinityDefaultRule extends SaropaLintRule {
  const AvoidAndroidTaskAffinityDefaultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_android_task_affinity_default',
    problemMessage:
        '[avoid_android_task_affinity_default] Starting Android activity via '
        'platform channel. Verify taskAffinity is set in AndroidManifest.xml. {v2}',
    correctionMessage:
        'Set android:taskAffinity on activities or use Flutter navigation.',
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

      // Check for platform channel activity launching
      if (methodName != 'invokeMethod') return;

      // Check arguments for activity-related calls
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource().toLowerCase();
        if (argSource.contains('activity') ||
            argSource.contains('startactivity') ||
            argSource.contains('intent')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// require_android_12_splash
// =============================================================================

/// Warns when Flutter app may show double splash on Android 12+.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: android_splash, splash_screen_api_31
///
/// Android 12+ enforces a system splash screen. Without customization via
/// themes, the app may show both system splash and Flutter splash, causing
/// a jarring double-splash experience.
///
/// **BAD:**
/// ```dart
/// // Custom splash screen without Android 12 configuration
/// class SplashScreen extends StatelessWidget {
///   Widget build(context) => Container(color: Colors.blue, child: Logo());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Configure in styles.xml for Android 12+:
/// // <item name="android:windowSplashScreenBackground">@color/splash</item>
/// // <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash</item>
/// // Then optionally show a minimal Flutter splash for initialization
/// ```
class RequireAndroid12SplashRule extends SaropaLintRule {
  const RequireAndroid12SplashRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_android_12_splash',
    problemMessage:
        '[require_android_12_splash] Flutter splash screen widget detected. '
        'Android 12+ shows system splash first, causing potential double-splash. {v2}',
    correctionMessage:
        'Configure Android 12 splash in styles.xml or use flutter_native_splash.',
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

      // Check for splash screen class names
      if (!className.contains('splash')) return;

      // Check if it's a widget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass.contains('Widget') ||
          superclass.contains('State') ||
          superclass == 'StatelessWidget' ||
          superclass == 'StatefulWidget') {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// prefer_pending_intent_flags
// =============================================================================

/// Warns when PendingIntent is created without FLAG_IMMUTABLE or FLAG_MUTABLE.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: pending_intent_flag, android_12_pending_intent
///
/// Android 12+ (API 31) requires PendingIntent to specify either
/// FLAG_IMMUTABLE or FLAG_MUTABLE. Without this flag, the app crashes.
///
/// **BAD:**
/// ```dart
/// // Platform channel creating PendingIntent without flag
/// await platform.invokeMethod('createPendingIntent', {
///   'requestCode': 0,
///   'intent': intentData,
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// await platform.invokeMethod('createPendingIntent', {
///   'requestCode': 0,
///   'intent': intentData,
///   'flags': 'FLAG_IMMUTABLE', // or FLAG_MUTABLE if needed
/// });
/// ```
class PreferPendingIntentFlagsRule extends SaropaLintRule {
  const PreferPendingIntentFlagsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_pending_intent_flags',
    problemMessage:
        '[prefer_pending_intent_flags] PendingIntent without FLAG_IMMUTABLE or '
        'FLAG_MUTABLE crashes on Android 12+. {v2}',
    correctionMessage:
        'Specify FLAG_IMMUTABLE (preferred) or FLAG_MUTABLE in PendingIntent flags.',
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

      // Check for platform channel calls that might create PendingIntent
      if (methodName != 'invokeMethod') return;

      // Check first argument for PendingIntent-related method names
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String firstArg = args.first.toSource().toLowerCase();
      if (!firstArg.contains('pendingintent') &&
          !firstArg.contains('pending_intent') &&
          !firstArg.contains('notification') &&
          !firstArg.contains('alarm') &&
          !firstArg.contains('broadcast')) {
        return;
      }

      // Check if flags are specified
      final String fullSource = node.toSource().toLowerCase();
      if (fullSource.contains('flag_immutable') ||
          fullSource.contains('flag_mutable') ||
          fullSource.contains('immutable') ||
          fullSource.contains('mutable')) {
        return; // Flags are specified
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// avoid_android_cleartext_traffic
// =============================================================================

/// Warns when HTTP (non-HTTPS) URLs are used without platform check.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: cleartext_traffic, android_network_security
///
/// Android 9+ (API 28) blocks cleartext (HTTP) traffic by default. Enable
/// cleartextTrafficPermitted only for specific debug domains, never production.
///
/// **BAD:**
/// ```dart
/// // HTTP URL without platform consideration
/// final response = await http.get(Uri.parse('http://api.example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use HTTPS
/// final response = await http.get(Uri.parse('https://api.example.com/data'));
///
/// // Or configure network_security_config.xml for specific debug domains
/// ```
class AvoidAndroidCleartextTrafficRule extends SaropaLintRule {
  const AvoidAndroidCleartextTrafficRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_android_cleartext_traffic',
    problemMessage:
        '[avoid_android_cleartext_traffic] HTTP URL detected. Android 9+ blocks '
        'cleartext traffic by default. This request will fail silently. {v2}',
    correctionMessage:
        'Use HTTPS or configure network_security_config.xml for debug builds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Uri.parse with http://
      if (node.methodName.name == 'parse') {
        final Expression? target = node.target;
        if (target is SimpleIdentifier && target.name == 'Uri') {
          final NodeList<Expression> args = node.argumentList.arguments;
          if (args.isNotEmpty) {
            final String urlArg = args.first.toSource();
            // Check for http:// but not https://
            if (urlArg.contains("'http://") ||
                urlArg.contains('"http://') ||
                (urlArg.contains('http://') && !urlArg.contains('https://'))) {
              // Allow localhost for development
              if (!urlArg.contains('localhost') &&
                  !urlArg.contains('127.0.0.1') &&
                  !urlArg.contains('10.0.2.2')) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }

      // Check for http.get/post with http:// URLs
      final String methodName = node.methodName.name;
      if (methodName == 'get' ||
          methodName == 'post' ||
          methodName == 'put' ||
          methodName == 'delete') {
        final NodeList<Expression> args = node.argumentList.arguments;
        if (args.isNotEmpty) {
          final String firstArg = args.first.toSource();
          if (firstArg.contains("'http://") || firstArg.contains('"http://')) {
            if (!firstArg.contains('localhost') &&
                !firstArg.contains('127.0.0.1') &&
                !firstArg.contains('10.0.2.2')) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// require_android_backup_rules
// =============================================================================

/// Warns when sensitive data storage is used without backup exclusion.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: android_backup, backup_rules
///
/// Android auto-backup includes SharedPreferences by default. Define
/// backup_rules.xml to control what's backed up. Sensitive data in
/// shared_prefs backs up by default, potentially exposing it in backups.
///
/// **BAD:**
/// ```dart
/// // Storing sensitive data that will be backed up
/// prefs.setString('auth_token', token);
/// prefs.setString('session_id', sessionId);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use flutter_secure_storage (excluded from backup on Android)
/// secureStorage.write(key: 'auth_token', value: token);
///
/// // Or configure backup_rules.xml to exclude sensitive data
/// ```
class RequireAndroidBackupRulesRule extends SaropaLintRule {
  const RequireAndroidBackupRulesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_android_backup_rules',
    problemMessage:
        '[require_android_backup_rules] Sensitive data in SharedPreferences '
        'may be included in Android auto-backup. {v3}',
    correctionMessage:
        'Use flutter_secure_storage or configure backup_rules.xml to exclude sensitive data.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Cached regex patterns for performance
  static final RegExp _camelCaseBoundary = RegExp(r'([a-z])([A-Z])');
  static final RegExp _wordSplitPattern = RegExp(r'[_\s]+');

  /// Sensitive key patterns that should use secure storage.
  /// Uses word-boundary matching to avoid false positives like
  /// "authentication_method" matching "auth".
  static const Set<String> _sensitiveKeyPatterns = <String>{
    'token',
    'auth_token',
    'access_token',
    'refresh_token',
    'session_id',
    'session_token',
    'password',
    'secret',
    'credential',
    'api_key',
    'apikey',
    'private_key',
    'auth_key',
  };

  /// Helper to split camelCase/snake_case into words for matching.
  static List<String> _splitIntoWords(String input) {
    // Split on underscores and camelCase boundaries
    return input
        .replaceAllMapped(
          _camelCaseBoundary,
          (Match m) => '${m.group(1)}_${m.group(2)}',
        )
        .toLowerCase()
        .split(_wordSplitPattern)
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SharedPreferences setString with sensitive keys
      if (!methodName.startsWith('set')) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check if storing sensitive data
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String keyArg = args.first.toSource().toLowerCase();

      // Check for exact sensitive patterns (avoiding substring false positives)
      for (final String pattern in _sensitiveKeyPatterns) {
        // Check if the key argument contains the exact pattern
        if (keyArg.contains("'$pattern'") ||
            keyArg.contains('"$pattern"') ||
            keyArg.endsWith("$pattern'") ||
            keyArg.endsWith('$pattern"')) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Also check using word splitting for camelCase/snake_case keys
      final List<String> keyWords = _splitIntoWords(keyArg);
      for (final String pattern in _sensitiveKeyPatterns) {
        final List<String> patternWords = _splitIntoWords(pattern);
        // Check if all pattern words appear in the key words
        if (patternWords.every(
          (String word) => keyWords.contains(word),
        )) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// prefer_foreground_service_android
// =============================================================================

/// Warns when long-running background work lacks a foreground service.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Android aggressively kills background services and tasks. Starting with
/// Android 8 (Oreo), background execution limits mean that Timer.periodic,
/// Isolate.spawn, or scheduled work running outside a foreground service
/// will be killed within minutes. Use a foreground service with a
/// notification for any ongoing work (music playback, GPS tracking,
/// file upload).
///
/// **BAD:**
/// ```dart
/// Timer.periodic(Duration(seconds: 30), (_) {
///   uploadData();
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use flutter_foreground_task or android_alarm_manager
/// FlutterForegroundTask.startService(
///   notificationTitle: 'Uploading',
///   callback: uploadCallback,
/// );
/// ```
class PreferForegroundServiceAndroidRule extends SaropaLintRule {
  const PreferForegroundServiceAndroidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_foreground_service_android',
    problemMessage:
        '[prefer_foreground_service_android] Long-running periodic timer '
        'without foreground service. Android 8+ aggressively kills background '
        'tasks — Timer.periodic and Isolate.spawn are terminated within '
        'minutes when the app is backgrounded. Use a foreground service with '
        'notification (flutter_foreground_task, android_alarm_manager) for '
        'reliable ongoing work like uploads, GPS tracking, or audio. {v1}',
    correctionMessage:
        'Use FlutterForegroundTask.startService() or WorkManager for '
        'reliable background execution on Android.',
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

      // Detect Timer.periodic calls
      if (methodName != 'periodic') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Timer') return;

      // Check if there's a foreground service setup in the enclosing body
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody) {
          final String bodySource = current.toSource();
          if (bodySource.contains('ForegroundTask') ||
              bodySource.contains('foregroundService') ||
              bodySource.contains('ForegroundService') ||
              bodySource.contains('WorkManager') ||
              bodySource.contains('startForeground') ||
              bodySource.contains('AlarmManager')) {
            return; // Has foreground service, OK
          }
          break;
        }
        current = current.parent;
      }

      // Check enclosing class for foreground service patterns
      current = node.parent;
      while (current != null) {
        if (current is ClassDeclaration) {
          final String classSource = current.toSource();
          if (classSource.contains('ForegroundTask') ||
              classSource.contains('ForegroundService') ||
              classSource.contains('WorkManager')) {
            return; // Class uses foreground service, OK
          }
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Notification lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper notification handling on Android
/// and prevent sensitive data exposure in notification payloads.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

/// Warns when Android notifications don't specify a channel ID.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Starting with Android 8.0 (API 26), notifications must use notification
/// channels. Without a channel ID, notifications won't display on newer
/// Android versions.
///
/// **BAD:**
/// ```dart
/// final notification = NotificationDetails(
///   android: AndroidNotificationDetails('title', 'body'),
/// );
///
/// flutterLocalNotificationsPlugin.show(0, 'title', 'body', notification);
/// ```
///
/// **GOOD:**
/// ```dart
/// final notification = NotificationDetails(
///   android: AndroidNotificationDetails(
///     'channel_id',  // Required for Android 8.0+
///     'Channel Name',
///     channelDescription: 'Channel description',
///     importance: Importance.high,
///   ),
/// );
/// ```
class RequireNotificationChannelAndroidRule extends SaropaLintRule {
  RequireNotificationChannelAndroidRule() : super(code: _code);

  /// Missing channel means notifications won't display on Android 8.0+.
  /// Critical functionality bug affecting most Android users.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_notification_channel_android',
    '[require_notification_channel_android] Android notification is missing a channel ID or description. Without these, notifications may not appear or may be grouped incorrectly on Android 8.0+ devices, reducing reliability and user engagement. {v2}',
    correctionMessage:
        'Add a channelId and channelDescription to your AndroidNotificationDetails to ensure notifications are delivered and categorized correctly on Android 8.0+ devices. This improves reliability and user experience.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for AndroidNotificationDetails constructor
      if (typeName != 'AndroidNotificationDetails') return;

      // Check if channelDescription is provided as named argument
      bool hasChannelDescription = false;
      bool hasImportance = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'channelDescription') {
            hasChannelDescription = true;
          }
          if (name == 'importance') {
            hasImportance = true;
          }
        }
      }

      // Warn if missing channelDescription
      if (!hasChannelDescription) {
        reporter.atNode(node.constructorName, code);
        return;
      }

      // Also suggest setting importance for visibility
      if (!hasImportance) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when notification payloads contain sensitive data.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v4
///
/// Notification content appears on lock screens and can be visible to others.
/// Never include passwords, tokens, PII, or financial data in notifications.
///
/// **BAD:**
/// ```dart
/// showNotification(
///   title: 'New Payment',
///   body: 'Your card ending in 1234 was charged \$100. Token: $token',
/// );
///
/// pushNotification(
///   title: 'Login Alert',
///   body: 'Password changed for user: $email',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// showNotification(
///   title: 'New Payment',
///   body: 'You have a new transaction. Tap to view details.',
/// );
///
/// pushNotification(
///   title: 'Security Alert',
///   body: 'Your account settings were updated.',
/// );
/// ```
class AvoidNotificationPayloadSensitiveRule extends SaropaLintRule {
  AvoidNotificationPayloadSensitiveRule() : super(code: _code);

  /// Sensitive data visible on lock screen exposes user credentials.
  /// Privacy/security issue that can expose passwords, tokens, PII.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_notification_payload_sensitive',
    '[avoid_notification_payload_sensitive] Sensitive data in notifications exposes passwords, tokens, or PII on the lock screen. Anyone nearby can read this information without unlocking the device, creating a security vulnerability. {v4}',
    correctionMessage:
        'Use generic messages like "New message received" instead of actual content, and require user authentication before displaying sensitive details inside the app.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitivePatterns = <String>{
    'password',
    'passwd',
    'token',
    'secret',
    'credential',
    'api_key',
    'apikey',
    'ssn',
    'social_security',
    'credit_card',
    'card_number',
    'cvv',
    'pin',
    'otp',
    'verification_code',
    'auth_code',
    'private_key',
    'bank_account',
    'routing_number',
  };

  static const Set<String> _notificationMethods = <String>{
    'show',
    'showNotification',
    'displayNotification',
    'pushNotification',
    'sendNotification',
    'notify',
    'zonedSchedule',
    'schedule',
    'periodicallyShow',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a notification method
      if (!_notificationMethods.contains(methodName)) return;

      // Check all arguments for sensitive data
      for (final Expression arg in node.argumentList.arguments) {
        String argSource;

        if (arg is NamedExpression) {
          // Check common notification parameter names
          final String paramName = arg.name.label.name.toLowerCase();
          if (paramName != 'body' &&
              paramName != 'title' &&
              paramName != 'payload' &&
              paramName != 'message' &&
              paramName != 'content') {
            continue;
          }
          argSource = arg.expression.toSource().toLowerCase();
        } else {
          argSource = arg.toSource().toLowerCase();
        }

        for (final String pattern in _sensitivePatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });

    // Also check NotificationDetails/AndroidNotificationDetails creation
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'NotificationDetails' &&
          typeName != 'AndroidNotificationDetails' &&
          typeName != 'DarwinNotificationDetails') {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;

        final String paramName = arg.name.label.name.toLowerCase();
        if (paramName != 'body' &&
            paramName != 'subtitle' &&
            paramName != 'ticker') {
          continue;
        }

        final String argSource = arg.expression.toSource().toLowerCase();
        for (final String pattern in _sensitivePatterns) {
          if (argSource.contains(pattern)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

/// Warns when FlutterLocalNotificationsPlugin.initialize is called without
///
/// Since: v2.3.2 | Updated: v4.13.0 | Rule version: v4
///
/// both iOS and Android settings.
///
/// Alias: notification_platform_settings, require_notification_settings
///
/// **Quick fix available:** Adds reminder comment for missing platform settings.
///
/// ## Why This Matters
///
/// The flutter_local_notifications plugin requires platform-specific settings
/// to function correctly. Missing settings will cause notifications to fail
/// silently on that platform, which is difficult to debug:
/// - Missing `android:` → Notifications won't show on Android
/// - Missing `iOS:` → Notifications won't show on iOS
///
/// ## Detection
///
/// This rule checks `InitializationSettings` constructor calls for both
/// `android:` and `iOS:` named parameters. macOS and Linux are not checked
/// as they're less common for mobile apps.
///
/// ## Example
///
/// ### BAD:
/// ```dart
/// // Notifications will fail silently on iOS!
/// await plugin.initialize(
///   InitializationSettings(android: androidSettings),
/// );
/// ```
///
/// ### GOOD:
/// ```dart
/// await plugin.initialize(
///   InitializationSettings(
///     android: AndroidInitializationSettings('@mipmap/ic_launcher'),
///     iOS: DarwinInitializationSettings(),
///   ),
/// );
/// ```
class RequireNotificationInitializePerPlatformRule extends SaropaLintRule {
  RequireNotificationInitializePerPlatformRule() : super(code: _code);

  /// High impact - notifications fail silently, hard to debug.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_notification_initialize_per_platform',
    '[require_notification_initialize_per_platform] Missing platform-specific initialization settings (android: or iOS: parameters) causes notifications to fail silently, breaking critical app functionality. Users on the unconfigured platform will never receive time-sensitive alerts, security notifications, or important updates. {v4}',
    correctionMessage:
        'Add both android: and iOS: parameters to ensure notifications work on all platforms.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'InitializationSettings') return;

      // Check for android and iOS settings
      bool hasAndroid = false;
      bool hasIOS = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'android') hasAndroid = true;
          if (name == 'iOS') hasIOS = true;
        }
      }

      // Warn if either is missing
      if (!hasAndroid || !hasIOS) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when scheduled notifications use DateTime instead of TZDateTime.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// Scheduled notifications require timezone-aware datetime handling to ensure
/// notifications fire at the correct time across timezone changes, daylight
/// saving time transitions, and for users in different time zones.
///
/// **BAD:**
/// ```dart
/// await flutterLocalNotificationsPlugin.zonedSchedule(
///   0,
///   'title',
///   'body',
///   DateTime.now().add(Duration(hours: 1)), // Wrong type!
///   notificationDetails,
/// );
///
/// // Using DateTime.parse or DateTime.now() for scheduling
/// final scheduledTime = DateTime.now().add(Duration(days: 1));
/// await plugin.schedule(0, 'title', 'body', scheduledTime, details);
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:timezone/timezone.dart' as tz;
///
/// await flutterLocalNotificationsPlugin.zonedSchedule(
///   0,
///   'title',
///   'body',
///   tz.TZDateTime.now(tz.local).add(Duration(hours: 1)),
///   notificationDetails,
///   uiLocalNotificationDateInterpretation:
///       UILocalNotificationDateInterpretation.absoluteTime,
/// );
/// ```
class RequireNotificationTimezoneAwarenessRule extends SaropaLintRule {
  RequireNotificationTimezoneAwarenessRule() : super(code: _code);

  /// Medium impact - notifications may fire at wrong time, but not a crash.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_notification_timezone_awareness',
    '[require_notification_timezone_awareness] Scheduled notification should use TZDateTime instead of DateTime. Scheduled notifications require timezone-aware datetime handling to ensure notifications fire at the correct time across timezone changes, daylight saving time transitions, and for users in different time zones. {v3}',
    correctionMessage:
        'Use tz.TZDateTime.now(tz.local) or tz.TZDateTime.from() for timezone-aware scheduling.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Methods that schedule notifications and require timezone-aware datetime.
  static const Set<String> _schedulingMethods = <String>{
    'zonedSchedule',
    'schedule',
    'periodicallyShow',
    'showDailyAtTime',
    'showWeeklyAtDayAndTime',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a scheduling method
      if (!_schedulingMethods.contains(methodName)) return;

      // Check the target to ensure it's notification-related
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        // Only check notification plugin calls
        if (!targetSource.contains('notification') &&
            !targetSource.contains('plugin')) {
          return;
        }
      }

      // Check arguments for DateTime usage instead of TZDateTime
      for (final Expression arg in node.argumentList.arguments) {
        // Skip named expressions that aren't time-related
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name.toLowerCase();
          if (paramName != 'scheduleddate' &&
              paramName != 'time' &&
              paramName != 'datetime' &&
              paramName != 'date') {
            continue;
          }
          _checkForDateTime(arg.expression, node, reporter);
        } else {
          // Check positional arguments for DateTime expressions
          _checkForDateTime(arg, node, reporter);
        }
      }
    });

    // Also check for DateTime.now() or DateTime.parse() in notification context
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Check for DateTime constructor usage near notification scheduling
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DateTime') return;

      // Check if this is in a notification scheduling context
      if (_isInNotificationSchedulingContext(node)) {
        reporter.atNode(node);
      }
    });
  }

  void _checkForDateTime(
    Expression expr,
    MethodInvocation parentCall,
    SaropaDiagnosticReporter reporter,
  ) {
    final String exprSource = expr.toSource();

    // Check for DateTime patterns that should be TZDateTime
    if (exprSource.contains('DateTime.now()') ||
        exprSource.contains('DateTime.parse(') ||
        exprSource.contains('DateTime(')) {
      // Verify this is a datetime argument, not some other type
      final String? staticTypeName = expr.staticType?.element?.name;
      if (staticTypeName == 'DateTime') {
        reporter.atNode(expr);
      }
    }
  }

  bool _isInNotificationSchedulingContext(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;
    const int maxDepth = 10;

    while (current != null && depth < maxDepth) {
      if (current is MethodInvocation) {
        final String methodName = current.methodName.name;
        if (_schedulingMethods.contains(methodName)) {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when notifications use the same ID for different notifications.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: notification_id, duplicate_notification_id
///
/// Using the same notification ID for different notifications causes
/// them to overwrite each other. Use unique IDs for each notification.
///
/// **BAD:**
/// ```dart
/// const notificationId = 0;
/// await showNotification(id: notificationId, title: 'Message 1');
/// await showNotification(id: notificationId, title: 'Message 2'); // Overwrites!
/// ```
///
/// **GOOD:**
/// ```dart
/// int _notificationCounter = 0;
/// Future<void> showNotification(String title) async {
///   final id = _notificationCounter++;
///   await notify(id: id, title: title);
/// }
/// ```
class AvoidNotificationSameIdRule extends SaropaLintRule {
  AvoidNotificationSameIdRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_notification_same_id',
    '[avoid_notification_same_id] Static or hardcoded notification ID causes newer notifications to silently replace older ones using the same identifier. Users will miss important alerts, messages, and time-sensitive updates without any indication that previous notifications were overwritten, leading to lost information and degraded communication reliability. {v3}',
    correctionMessage:
        'Generate a unique ID per notification using DateTime.now().millisecondsSinceEpoch or an incrementing counter to prevent silent notification replacement.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!methodName.contains('show') && !methodName.contains('notify')) {
        return;
      }

      // Check for notification-related method names
      if (!methodName.toLowerCase().contains('notification') &&
          !methodName.toLowerCase().contains('notify')) {
        return;
      }

      // Check for id parameter with literal value
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'id') {
          final Expression idExpr = arg.expression;
          if (idExpr is IntegerLiteral ||
              (idExpr is SimpleIdentifier &&
                  (idExpr.name.startsWith('_') ||
                      idExpr.name.contains('Id') ||
                      idExpr.name.contains('ID')))) {
            // Check if it's a constant
            if (idExpr is IntegerLiteral) {
              reporter.atNode(idExpr);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// prefer_notification_grouping
// =============================================================================

/// Warns when multiple notifications are shown without grouping.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: notification_grouping, group_notifications
///
/// Multiple notifications from the same app should be grouped. On Android,
/// use setGroup() to visually group related notifications. This provides
/// a better user experience and reduces notification clutter.
///
/// **BAD:**
/// ```dart
/// // Multiple notifications without grouping
/// for (final message in messages) {
///   await flutterLocalNotificationsPlugin.show(
///     message.id,
///     'New Message',
///     message.text,
///     NotificationDetails(android: AndroidNotificationDetails(...)),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// const String groupKey = 'com.example.messages';
///
/// for (final message in messages) {
///   await flutterLocalNotificationsPlugin.show(
///     message.id,
///     'New Message',
///     message.text,
///     NotificationDetails(
///       android: AndroidNotificationDetails(
///         'channel_id',
///         'Channel Name',
///         groupKey: groupKey, // Group related notifications
///       ),
///     ),
///   );
/// }
///
/// // Show summary notification
/// await flutterLocalNotificationsPlugin.show(
///   0,
///   '${messages.length} new messages',
///   '',
///   NotificationDetails(
///     android: AndroidNotificationDetails(
///       'channel_id',
///       'Channel Name',
///       groupKey: groupKey,
///       setAsGroupSummary: true,
///     ),
///   ),
/// );
/// ```
class PreferNotificationGroupingRule extends SaropaLintRule {
  PreferNotificationGroupingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_notification_grouping',
    '[prefer_notification_grouping] Multiple notifications shown in loop '
        'without groupKey. Notifications will clutter the notification shade. {v2}',
    correctionMessage:
        'Add groupKey to AndroidNotificationDetails to group related notifications.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for notification show methods
      if (methodName != 'show' &&
          methodName != 'zonedSchedule' &&
          methodName != 'periodicallyShow') {
        return;
      }

      // Check if this is inside a loop
      bool isInsideLoop = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is ForStatement ||
            current is ForElement ||
            current is WhileStatement ||
            current is DoStatement) {
          isInsideLoop = true;
          break;
        }
        if (current is MethodInvocation) {
          final String method = current.methodName.name;
          if (method == 'forEach' || method == 'map') {
            isInsideLoop = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!isInsideLoop) return;

      // Check if groupKey is specified
      final String nodeSource = node.toSource();
      if (nodeSource.contains('groupKey')) {
        return; // Has grouping
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_notification_silent_failure
// =============================================================================

/// Warns when notification show/schedule is called without error handling.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: notification_error_handling, handle_notification_failure
///
/// Notification operations can fail silently (permission denied, channel
/// doesn't exist, etc.). Always handle errors to provide user feedback.
///
/// **BAD:**
/// ```dart
/// await flutterLocalNotificationsPlugin.show(0, 'Title', 'Body', details);
/// // If this fails, user gets no feedback
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await flutterLocalNotificationsPlugin.show(0, 'Title', 'Body', details);
/// } catch (e) {
///   // Handle error - maybe permissions were revoked
///   debugPrint('Failed to show notification: $e');
///   // Optionally show in-app message instead
/// }
/// ```
class AvoidNotificationSilentFailureRule extends SaropaLintRule {
  AvoidNotificationSilentFailureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_notification_silent_failure',
    '[avoid_notification_silent_failure] Notification operation without '
        'error handling. Failures will be silent and hard to debug. {v2}',
    correctionMessage:
        'Wrap notification calls in try-catch to handle permission or platform errors.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _notificationMethods = <String>{
    'show',
    'zonedSchedule',
    'schedule',
    'periodicallyShow',
    'showDailyAtTime',
    'showWeeklyAtDayAndTime',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_notificationMethods.contains(methodName)) return;

      // Check if target looks like a notification plugin
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('notification') &&
          !targetSource.contains('plugin')) {
        return;
      }

      // Check if inside try-catch
      bool isInsideTryCatch = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is TryStatement) {
          isInsideTryCatch = true;
          break;
        }
        if (current is FunctionBody) {
          break;
        }
        current = current.parent;
      }

      if (isInsideTryCatch) return;

      // Check for .catchError
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodInvocation) {
          final String parentMethod = parent.methodName.name;
          if (parentMethod == 'catchError' || parentMethod == 'onError') {
            return; // Has error handling
          }
        }
        if (parent is! MethodInvocation &&
            parent is! CascadeExpression &&
            parent is! AwaitExpression) {
          break;
        }
        parent = parent.parent;
      }

      reporter.atNode(node);
    });
  }
}

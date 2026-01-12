// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Notification lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper notification handling on Android
/// and prevent sensitive data exposure in notification payloads.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Android notifications don't specify a channel ID.
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
  const RequireNotificationChannelAndroidRule() : super(code: _code);

  /// Missing channel means notifications won't display on Android 8.0+.
  /// Critical functionality bug affecting most Android users.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_notification_channel_android',
    problemMessage:
        '[require_notification_channel_android] Android notification should specify channel ID and description.',
    correctionMessage:
        'Add channelId and channelDescription for Android 8.0+ compatibility.',
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

  @override
  List<Fix> getFixes() => <Fix>[_AddNotificationChannelFix()];
}

class _AddNotificationChannelFix extends DartFix {
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
        message: 'Add HACK comment for missing channel settings',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add channelDescription and importance for Android 8.0+\n',
        );
      });
    });
  }
}

/// Warns when notification payloads contain sensitive data.
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
  const AvoidNotificationPayloadSensitiveRule() : super(code: _code);

  /// Sensitive data visible on lock screen exposes user credentials.
  /// Privacy/security issue that can expose passwords, tokens, PII.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_notification_payload_sensitive',
    problemMessage:
        '[avoid_notification_payload_sensitive] Notification may contain sensitive data visible on lock screen.',
    correctionMessage:
        'Remove sensitive info from notifications. Use generic messages instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });

    // Also check NotificationDetails/AndroidNotificationDetails creation
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSensitiveNotificationTodoFix()];
}

class _AddSensitiveNotificationTodoFix extends DartFix {
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
        message: 'Add HACK: Remove sensitive data from notification',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Remove sensitive data - notifications are visible on lock screen\n',
        );
      });
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Remove sensitive data from notification',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Remove sensitive data - notifications are visible on lock screen\n',
        );
      });
    });
  }
}

/// Warns when FlutterLocalNotificationsPlugin.initialize is called without
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
  const RequireNotificationInitializePerPlatformRule() : super(code: _code);

  /// High impact - notifications fail silently, hard to debug.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_notification_initialize_per_platform',
    problemMessage:
        '[require_notification_initialize_per_platform] InitializationSettings should include both android and iOS settings.',
    correctionMessage:
        'Add both android: and iOS: parameters to ensure notifications work on all platforms.',
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

  @override
  List<Fix> getFixes() => <Fix>[_AddPlatformSettingsTodoFix()];
}

class _AddPlatformSettingsTodoFix extends DartFix {
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

      // Determine which settings are missing
      bool hasAndroid = false;
      bool hasIOS = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'android') hasAndroid = true;
          if (name == 'iOS') hasIOS = true;
        }
      }

      String message = 'Add TODO: Add ';
      if (!hasAndroid && !hasIOS) {
        message += 'android and iOS settings';
      } else if (!hasAndroid) {
        message += 'android settings';
      } else {
        message += 'iOS settings';
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: message,
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        String todoText = '// HACK: Add ';
        if (!hasAndroid && !hasIOS) {
          todoText +=
              'both android: and iOS: parameters for cross-platform support\n';
        } else if (!hasAndroid) {
          todoText +=
              'android: AndroidInitializationSettings for Android support\n';
        } else {
          todoText += 'iOS: DarwinInitializationSettings for iOS support\n';
        }

        builder.addSimpleInsertion(node.offset, todoText);
      });
    });
  }
}

/// Warns when scheduled notifications use DateTime instead of TZDateTime.
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
  const RequireNotificationTimezoneAwarenessRule() : super(code: _code);

  /// Medium impact - notifications may fire at wrong time, but not a crash.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_notification_timezone_awareness',
    problemMessage:
        '[require_notification_timezone_awareness] Scheduled notification should use TZDateTime instead of DateTime.',
    correctionMessage:
        'Use tz.TZDateTime.now(tz.local) or tz.TZDateTime.from() for timezone-aware scheduling.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      // Check for DateTime constructor usage near notification scheduling
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DateTime') return;

      // Check if this is in a notification scheduling context
      if (_isInNotificationSchedulingContext(node)) {
        reporter.atNode(node, code);
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
        reporter.atNode(expr, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_AddTimezoneAwarenessFix()];
}

class _AddTimezoneAwarenessFix extends DartFix {
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
        message: 'Add HACK comment for timezone-aware datetime',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use TZDateTime instead of DateTime for timezone-aware scheduling\n',
        );
      });
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for timezone-aware datetime',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use tz.TZDateTime instead of DateTime\n',
        );
      });
    });
  }
}

/// Warns when notifications use the same ID for different notifications.
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
  const AvoidNotificationSameIdRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_notification_same_id',
    problemMessage:
        '[avoid_notification_same_id] Static notification ID. Different notifications will overwrite each other.',
    correctionMessage:
        'Use unique IDs for each notification (e.g., incrementing counter).',
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
              reporter.atNode(idExpr, code);
            }
          }
        }
      }
    });
  }
}

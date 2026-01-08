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

  static const LintCode _code = LintCode(
    name: 'require_notification_channel_android',
    problemMessage:
        'Android notification should specify channel ID and description.',
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
        message: 'Add TODO: specify channel description',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Add channelDescription and importance for Android 8.0+\n',
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

  static const LintCode _code = LintCode(
    name: 'avoid_notification_payload_sensitive',
    problemMessage:
        'Notification may contain sensitive data visible on lock screen.',
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
        message: 'Add TODO: Remove sensitive data from notification',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Remove sensitive data - notifications are visible on lock screen\n',
        );
      });
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO: Remove sensitive data from notification',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Remove sensitive data - notifications are visible on lock screen\n',
        );
      });
    });
  }
}

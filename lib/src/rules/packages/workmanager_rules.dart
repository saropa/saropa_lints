// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Workmanager-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the workmanager package for
/// background task scheduling, including constraints and result handling.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// WORKMANAGER RULES
// =============================================================================

/// Warns when WorkManager task registration lacks constraints.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: workmanager_constraints, require_task_constraints
///
/// WorkManager tasks without constraints may run at inappropriate times,
/// draining battery or using metered data unexpectedly.
///
/// **BAD:**
/// ```dart
/// Workmanager().registerPeriodicTask(
///   'sync',
///   'syncTask',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Workmanager().registerPeriodicTask(
///   'sync',
///   'syncTask',
///   constraints: Constraints(
///     networkType: NetworkType.connected,
///     requiresBatteryNotLow: true,
///   ),
/// );
/// ```
class RequireWorkmanagerConstraintsRule extends SaropaLintRule {
  RequireWorkmanagerConstraintsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_workmanager_constraints',
    '[require_workmanager_constraints] WorkManager task registered without constraints runs unconditionally regardless of network availability, battery level, or charging state. This drains battery during low-power conditions, consumes metered mobile data, and causes failed network connection requests when connectivity is unavailable, wasting battery, memory, and processing resources. {v3}',
    correctionMessage:
        'Add Constraints(networkType: NetworkType.connected) and optionally requiresBatteryNotLow or requiresCharging to control when background tasks execute.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _taskMethods = <String>{
    'registerPeriodicTask',
    'registerOneOffTask',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_taskMethods.contains(methodName)) return;

      // Check if it's a Workmanager call
      final String? targetSource = node.target?.toSource();
      if (targetSource == null) return;
      if (!targetSource.contains('Workmanager') &&
          !targetSource.contains('workmanager')) {
        return;
      }

      // Check for constraints parameter
      final bool hasConstraints = node.argumentList.arguments.any((
        Expression arg,
      ) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'constraints';
        }
        return false;
      });

      if (!hasConstraints) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when WorkManager callback does not return a result.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: workmanager_return_result, require_task_result
///
/// WorkManager callbacks must return a bool (or `Future<bool>`) to indicate
/// success or failure. Without proper returns, task scheduling may behave
/// unexpectedly.
///
/// **BAD:**
/// ```dart
/// Workmanager().executeTask((task, inputData) async {
///   await doWork();
///   // No return!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// Workmanager().executeTask((task, inputData) async {
///   try {
///     await doWork();
///     return true;
///   } catch (e) {
///     return false;
///   }
/// });
/// ```
class RequireWorkmanagerResultReturnRule extends SaropaLintRule {
  RequireWorkmanagerResultReturnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_workmanager_result_return',
    '[require_workmanager_result_return] Missing return value makes '
        'WorkManager assume failure, triggering unnecessary retries. {v2}',
    correctionMessage:
        'Return true/false from the executeTask callback to indicate success.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'executeTask') return;

      // Check if it's a Workmanager call
      final String? targetSource = node.target?.toSource();
      if (targetSource == null) return;
      if (!targetSource.contains('Workmanager') &&
          !targetSource.contains('workmanager')) {
        return;
      }

      // Find the callback
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression callback = args.arguments.first;
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;
      final String bodySource = body.toSource();

      // Check for any return statement - the callback must return something
      // We use a simple heuristic: if there's no 'return' keyword followed by
      // something, the callback likely doesn't return properly
      if (!bodySource.contains('return ')) {
        reporter.atNode(callback);
      }
    });
  }
}

/// Warns when workmanager is needed for reliable background tasks.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Dart isolates die when the app goes to background. For reliable
/// background execution on iOS and Android, use the workmanager package.
///
/// ## Why This Matters
///
/// - Isolates are killed when app backgrounds
/// - Data sync may be interrupted
/// - Scheduled tasks won't run
///
/// ## Example
///
/// **BAD:**
/// ```dart
/// // Timer in isolate - won't work in background
/// Timer.periodic(Duration(hours: 1), (_) => syncData());
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use workmanager for background tasks
/// Workmanager().registerPeriodicTask(
///   'hourlySync',
///   'syncData',
///   frequency: Duration(hours: 1),
/// );
/// ```
///
/// @see [workmanager package](https://pub.dev/packages/workmanager)
class RequireWorkmanagerForBackgroundRule extends SaropaLintRule {
  /// Creates a new instance of [RequireWorkmanagerForBackgroundRule].
  RequireWorkmanagerForBackgroundRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_workmanager_for_background',
    '[require_workmanager_for_background] Periodic task detected without workmanager. Dart isolates die when '
        'app backgrounds. Use workmanager for reliable background tasks. {v2}',
    correctionMessage:
        'Replace Timer.periodic with Workmanager().registerPeriodicTask() '
        'for reliable background execution.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String fileSource = context.fileContent;

    // Skip if workmanager is already being used
    if (fileSource.contains('Workmanager') ||
        fileSource.contains('workmanager')) {
      return;
    }

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      // Detect Timer.periodic
      if (methodName == 'periodic') {
        if (target != null && target.toSource() == 'Timer') {
          reporter.atNode(node);
        }
      }
    });
  }
}

// =============================================================================
// FIX CLASSES
// =============================================================================

// ignore_for_file: depend_on_referenced_packages

/// Lifecycle rules for Flutter applications.
///
/// These rules ensure proper handling of app lifecycle states, including
/// pausing background work and refreshing data when the app resumes.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Timer or periodic work runs without AppLifecycleState check.
///
/// Timers and periodic callbacks should pause when the app is backgrounded
/// to save battery and avoid unexpected behavior.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) => refresh());
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> with WidgetsBindingObserver {
///   Timer? _timer;
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) {
///       _timer?.cancel();
///     } else if (state == AppLifecycleState.resumed) {
///       _startTimer();
///     }
///   }
/// }
/// ```
class AvoidWorkInPausedStateRule extends SaropaLintRule {
  const AvoidWorkInPausedStateRule() : super(code: _code);

  /// Battery drain and unexpected behavior in background.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_work_in_paused_state',
    problemMessage:
        'Timer.periodic without lifecycle handling. Will run when app is backgrounded.',
    correctionMessage:
        'Add WidgetsBindingObserver and pause timer in didChangeAppLifecycleState.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check for Timer.periodic
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Timer') {
        return;
      }

      if (node.methodName.name != 'periodic') {
        return;
      }

      // Find enclosing class
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) {
        return;
      }

      // Check if class has WidgetsBindingObserver
      final classSource = enclosingClass.toSource();
      if (classSource.contains('WidgetsBindingObserver') &&
          classSource.contains('didChangeAppLifecycleState')) {
        return;
      }

      reporter.atNode(node, code);
    });

    // Also check Stream.periodic
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      final constructorName = node.constructorName.name?.name;

      if (typeName != 'Stream' || constructorName != 'periodic') {
        return;
      }

      // Find enclosing class
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) {
        return;
      }

      // Check if class has WidgetsBindingObserver
      final classSource = enclosingClass.toSource();
      if (classSource.contains('WidgetsBindingObserver') &&
          classSource.contains('didChangeAppLifecycleState')) {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when WidgetsBindingObserver doesn't handle resumed state.
///
/// When app returns from background, data may be stale and should be
/// refreshed. Missing resumed handling leads to outdated UI.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> with WidgetsBindingObserver {
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) {
///       saveData();
///     }
///     // Missing resumed handling!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> with WidgetsBindingObserver {
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) {
///       saveData();
///     } else if (state == AppLifecycleState.resumed) {
///       refreshData();
///     }
///   }
/// }
/// ```
class RequireResumeStateRefreshRule extends SaropaLintRule {
  const RequireResumeStateRefreshRule() : super(code: _code);

  /// Stale data after returning from background.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_resume_state_refresh',
    problemMessage:
        'didChangeAppLifecycleState handles paused but not resumed.',
    correctionMessage:
        'Add handling for AppLifecycleState.resumed to refresh data.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      if (node.name.lexeme != 'didChangeAppLifecycleState') {
        return;
      }

      final methodSource = node.toSource();

      // Check if it handles paused
      final handlesPaused = methodSource.contains('AppLifecycleState.paused') ||
          methodSource.contains('.paused');

      if (!handlesPaused) {
        return;
      }

      // Check if it handles resumed
      final handlesResumed =
          methodSource.contains('AppLifecycleState.resumed') ||
              methodSource.contains('.resumed');

      if (!handlesResumed) {
        reporter.atNode(node, code);
      }
    });
  }
}

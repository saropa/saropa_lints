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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_work_in_paused_state',
    problemMessage:
        '[avoid_work_in_paused_state] Timer.periodic without lifecycle handling. Will run when app is backgrounded.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_resume_state_refresh',
    problemMessage:
        '[require_resume_state_refresh] didChangeAppLifecycleState handles paused but not resumed.',
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

/// Warns when didUpdateWidget doesn't compare oldWidget.
///
/// Alias: did_update_widget_compare, compare_old_widget
///
/// didUpdateWidget receives the old widget for comparison. Without comparing
/// oldWidget to widget, you might trigger unnecessary updates.
///
/// **BAD:**
/// ```dart
/// @override
/// void didUpdateWidget(MyWidget oldWidget) {
///   super.didUpdateWidget(oldWidget);
///   _updateState(); // Always updates, even if nothing changed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void didUpdateWidget(MyWidget oldWidget) {
///   super.didUpdateWidget(oldWidget);
///   if (oldWidget.value != widget.value) {
///     _updateState(); // Only updates when value changed
///   }
/// }
/// ```
class RequireDidUpdateWidgetCheckRule extends SaropaLintRule {
  const RequireDidUpdateWidgetCheckRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_did_update_widget_check',
    problemMessage:
        '[require_did_update_widget_check] didUpdateWidget should compare oldWidget properties before updating.',
    correctionMessage:
        'Compare oldWidget.property != widget.property before state updates.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'didUpdateWidget') return;

      final FunctionBody body = node.body;
      if (body is EmptyFunctionBody) return;

      // Get the actual parameter name (usually 'oldWidget' but could vary)
      final NodeList<FormalParameter>? params = node.parameters?.parameters;
      if (params == null || params.isEmpty) return;

      String paramName = 'oldWidget';
      final FormalParameter firstParam = params.first;
      if (firstParam is SimpleFormalParameter) {
        paramName = firstParam.name?.lexeme ?? 'oldWidget';
      } else if (firstParam is DefaultFormalParameter) {
        final NormalFormalParameter normalParam = firstParam.parameter;
        if (normalParam is SimpleFormalParameter) {
          paramName = normalParam.name?.lexeme ?? 'oldWidget';
        }
      }

      final String bodySource = body.toSource();

      // Check if it only calls super.didUpdateWidget
      final String trimmed = bodySource
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('{', '')
          .replaceAll('}', '');

      // If body only contains super call, no need to warn
      if (trimmed == 'super.didUpdateWidget($paramName);') return;

      // Check if the parameter is accessed for comparison
      // Look for: paramName.property, paramName != , paramName == , paramName.hashCode
      final RegExp comparisonPattern = RegExp(
        '${RegExp.escape(paramName)}\\s*\\.\\w+\\s*[!=]=|'
        '${RegExp.escape(paramName)}\\s*[!=]=|'
        '[!=]=\\s*${RegExp.escape(paramName)}',
      );

      if (!comparisonPattern.hasMatch(bodySource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// v4.1.6 Rules - Late Initialization
// =============================================================================

/// Warns when late widget fields are initialized in build() instead of initState().
///
/// Late fields in StatefulWidget State classes should be initialized in
/// initState(), not build(). build() can be called multiple times, causing
/// redundant initialization or state loss.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   Widget build(BuildContext context) {
///     _controller = TextEditingController(); // Wrong! Recreated on every build!
///     return TextField(controller: _controller);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController(); // Correct!
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(controller: _controller);
///   }
/// }
/// ```
class RequireLateInitializationInInitStateRule extends SaropaLintRule {
  const RequireLateInitializationInInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_late_initialization_in_init_state',
    problemMessage:
        '[require_late_initialization_in_init_state] Late field should be initialized in initState(), not build().',
    correctionMessage:
        'Move initialization to initState() to avoid redundant recreation.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('State<')) return;

      // Collect late fields
      final Set<String> lateFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable in member.fields.variables) {
            // Only track uninitialized late fields
            if (variable.initializer == null) {
              lateFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (lateFields.isEmpty) return;

      // Find build method and check for late field assignments
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          _checkBuildMethodForLateAssignments(member, lateFields, reporter);
        }
      }
    });
  }

  void _checkBuildMethodForLateAssignments(
    MethodDeclaration buildMethod,
    Set<String> lateFields,
    SaropaDiagnosticReporter reporter,
  ) {
    final FunctionBody? body = buildMethod.body;
    if (body == null) return;

    // Find all assignment expressions in the build method
    final String bodySource = body.toSource();

    for (final String fieldName in lateFields) {
      // Check for direct assignment: fieldName =
      // or this.fieldName =
      final RegExp assignmentPattern = RegExp(
        '(?:^|[^\\w])(?:this\\.)?$fieldName\\s*=\\s*[^=]',
      );

      if (assignmentPattern.hasMatch(bodySource)) {
        // Report at the build method level
        reporter.atNode(buildMethod, code);
        return; // Only report once per build method
      }
    }
  }
}

// ignore_for_file: depend_on_referenced_packages

/// Lifecycle rules for Flutter applications.
///
/// These rules ensure proper handling of app lifecycle states, including
/// pausing background work and refreshing data when the app resumes.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

/// Warns when Timer or periodic work runs without AppLifecycleState check.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidWorkInPausedStateRule() : super(code: _code);

  /// Battery drain and unexpected behavior in background.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_work_in_paused_state',
    '[avoid_work_in_paused_state] Timer.periodic without lifecycle handling. Will run when app is backgrounded. Timers and periodic callbacks should pause when the app is backgrounded to save battery and avoid unexpected behavior. {v2}',
    correctionMessage:
        'Add WidgetsBindingObserver and pause timer in didChangeAppLifecycleState. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
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

      reporter.atNode(node);
    });

    // Also check Stream.periodic
    context.addInstanceCreationExpression((node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when WidgetsBindingObserver doesn't handle resumed state.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireResumeStateRefreshRule() : super(code: _code);

  /// Stale data after returning from background.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_resume_state_refresh',
    '[require_resume_state_refresh] App handles paused state but not resumed, leaving UI stale after returning from background. When app returns from background, data may be stale and must be refreshed. Missing resumed handling leads to outdated UI. {v2}',
    correctionMessage:
        'Handle AppLifecycleState.resumed to refresh data when app returns to foreground.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((node) {
      if (node.name.lexeme != 'didChangeAppLifecycleState') {
        return;
      }

      final methodSource = node.toSource();

      // Check if it handles paused
      final handlesPaused =
          methodSource.contains('AppLifecycleState.paused') ||
          methodSource.contains('.paused');

      if (!handlesPaused) {
        return;
      }

      // Check if it handles resumed
      final handlesResumed =
          methodSource.contains('AppLifecycleState.resumed') ||
          methodSource.contains('.resumed');

      if (!handlesResumed) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when didUpdateWidget doesn't compare oldWidget.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v3
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
  RequireDidUpdateWidgetCheckRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_did_update_widget_check',
    '[require_did_update_widget_check] didUpdateWidget triggers updates without checking if properties changed, causing unnecessary rebuilds. didUpdateWidget receives the old widget for comparison. Without comparing oldWidget to widget, you might trigger unnecessary updates. {v3}',
    correctionMessage:
        'Compare properties using operators (oldWidget.x != widget.x) or functions (listEquals, setEquals, mapEquals) before updating state.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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

      // Strip super.didUpdateWidget(paramName) and check if paramName
      // is still referenced anywhere in the body. This catches operator-based
      // comparisons (!=, ==) and function-based comparisons (listEquals,
      // setEquals, mapEquals, identical) without maintaining a regex.
      final RegExp superCallPattern = RegExp(
        r'super\s*\.\s*didUpdateWidget\s*\(\s*' +
            RegExp.escape(paramName) +
            r'\s*\)',
      );
      final String bodyWithoutSuper = bodySource.replaceAll(
        superCallPattern,
        '',
      );

      if (!bodyWithoutSuper.contains(paramName)) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// v4.1.6 Rules - Late Initialization
// =============================================================================

/// Warns when late widget fields are initialized in build() instead of initState().
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v3
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
  RequireLateInitializationInInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_late_initialization_in_init_state',
    '[require_late_initialization_in_init_state] Late field initialized in build() recreates the object on every setState() call. AnimationController instances restart their animations, StreamSubscription objects create duplicate listeners, and the resulting UI jank becomes visible to users. This also wastes memory by allocating new objects on every widget rebuild cycle. {v3}',
    correctionMessage:
        'Move late field initialization into initState(), which executes only once when the State object is first created, ensuring stable object lifecycle and preventing duplicate allocations.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('State<')) return;

      // Collect late fields
      final classBody = node.body;
      if (classBody is! BlockClassBody) return;

      final Set<String> lateFields = <String>{};
      for (final ClassMember member in classBody.members) {
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
      for (final ClassMember member in classBody.members) {
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
        reporter.atNode(buildMethod);
        return; // Only report once per build method
      }
    }
  }
}

/// Warns when State subclasses use Timer or stream subscriptions without
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v4
///
/// lifecycle handling.
///
/// Timer.periodic, Timer() constructor, and .listen() calls in State
/// subclasses should have corresponding lifecycle handling to pause or
/// stop background work when the app is not active.
///
/// **Note:** StreamBuilder is intentionally not flagged. Flutter's
/// StreamBuilder manages its own subscription lifecycle through
/// State.dispose(), so it does not require manual lifecycle handling.
///
/// ## Lifecycle Methods
///
/// - WidgetsBindingObserver: didChangeAppLifecycleState
/// - AppLifecycleListener: onStateChange
///
/// **Bad:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) => refresh());
///   }
/// }
/// ```
///
/// **Good:**
/// ```dart
/// class _MyState extends State<MyWidget> with WidgetsBindingObserver {
///   Timer? _timer;
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) _timer?.cancel();
///     else if (state == AppLifecycleState.resumed) _startTimer();
///   }
/// }
/// ```
class RequireAppLifecycleHandlingRule extends SaropaLintRule {
  /// Creates a new instance of [RequireAppLifecycleHandlingRule].
  RequireAppLifecycleHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresWidgets => true;

  @override
  List<String> get configAliases => const <String>[
    'require_ios_lifecycle_handling',
  ];

  static const LintCode _code = LintCode(
    'require_app_lifecycle_handling',
    '[require_app_lifecycle_handling] Timer or subscription detected '
        'without lifecycle handling. '
        'Stop background work when app is inactive to save battery. {v4}',
    correctionMessage:
        'Implement WidgetsBindingObserver and pause/resume in '
        'didChangeAppLifecycleState, or use AppLifecycleListener.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;
      if (_hasLifecycleHandling(node)) return;
      if (_hasBackgroundWork(node)) {
        reporter.atToken(node.namePart.typeName, code);
      }
    });
  }

  static bool _extendsState(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;
    return extendsClause.superclass.name.lexeme == 'State';
  }

  static bool _hasLifecycleHandling(ClassDeclaration node) {
    final WithClause? withClause = node.withClause;
    if (withClause != null) {
      for (final NamedType mixin in withClause.mixinTypes) {
        if (mixin.name.lexeme == 'WidgetsBindingObserver') return true;
      }
    }

    final ImplementsClause? implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final NamedType interface in implementsClause.interfaces) {
        if (interface.name.lexeme == 'WidgetsBindingObserver') return true;
      }
    }

    final classBody = node.body;
    if (classBody is! BlockClassBody) return false;

    for (final ClassMember member in classBody.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'didChangeAppLifecycleState') {
        return true;
      }
      if (member is FieldDeclaration) {
        final String? typeName = member.fields.type?.toSource();
        if (typeName != null && typeName.contains('AppLifecycleListener')) {
          return true;
        }
      }
    }

    return false;
  }

  static final RegExp _timerConstructorPattern = RegExp(r'\bTimer\(');

  static bool _hasBackgroundWork(ClassDeclaration node) {
    final classBody = node.body;
    if (classBody is! BlockClassBody) return false;

    for (final ClassMember member in classBody.members) {
      if (member is MethodDeclaration) {
        final String bodySource = member.body.toSource();
        if (bodySource.contains('Timer.periodic')) return true;
        if (_timerConstructorPattern.hasMatch(bodySource)) return true;
        if (bodySource.contains('.listen(')) return true;
      }
    }
    return false;
  }
}

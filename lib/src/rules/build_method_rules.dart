// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Build method anti-pattern rules for Flutter applications.
///
/// These rules detect expensive or side-effect operations
/// that should not be performed inside build() methods.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Gradient objects are created inside build().
///
/// Alias: gradient_in_build, no_gradient_in_build, cache_gradient
///
/// Creating Gradient objects in build() prevents Flutter from reusing them,
/// causing unnecessary object allocations on every rebuild.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Container(
///     decoration: BoxDecoration(
///       gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
///     ),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// static const _gradient = LinearGradient(colors: [Colors.red, Colors.blue]);
///
/// @override
/// Widget build(BuildContext context) {
///   return Container(
///     decoration: const BoxDecoration(gradient: _gradient),
///   );
/// }
/// ```
class AvoidGradientInBuildRule extends SaropaLintRule {
  const AvoidGradientInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_gradient_in_build',
    problemMessage:
        '[avoid_gradient_in_build] Creating Gradient in build() prevents reuse and causes allocations. This leads to unnecessary memory usage, slower UI performance, and increased battery drain.',
    correctionMessage:
        'Store gradient as a static const field or create outside build().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _gradientTypes = <String>{
    'LinearGradient',
    'RadialGradient',
    'SweepGradient',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only process build methods
      if (node.name.lexeme != 'build') return;

      // Visit all nodes in the build method body
      node.body.visitChildren(_GradientVisitor(reporter, code, _gradientTypes));
    });
  }
}

class _GradientVisitor extends GeneralizingAstVisitor<void> {
  _GradientVisitor(this.reporter, this.code, this.gradientTypes);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> gradientTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.element?.name ??
        node.constructorName.type.name2.lexeme;

    if (gradientTypes.contains(typeName)) {
      // Skip const gradients - they're properly reused
      if (node.keyword?.lexeme != 'const') {
        reporter.atNode(node, code);
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Implicit constructor calls may appear as method invocations
    final String methodName = node.methodName.name;
    if (gradientTypes.contains(methodName)) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when showDialog is called inside build().
///
/// Alias: dialog_in_build, no_show_dialog_in_build, infinite_dialog_loop
///
/// Calling showDialog in build() causes infinite dialog loops because
/// build() is called repeatedly and each call opens a new dialog.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   if (hasError) {
///     showDialog(...); // Opens infinite dialogs!
///   }
///   return Container();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _showErrorDialog() {
///   showDialog(...);
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return ElevatedButton(
///     onPressed: hasError ? _showErrorDialog : null,
///     child: Text('Check'),
///   );
/// }
/// ```
class AvoidDialogInBuildRule extends SaropaLintRule {
  const AvoidDialogInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_dialog_in_build',
    problemMessage:
        '[avoid_dialog_in_build] Calling showDialog (or similar) inside build() will cause your app to enter an infinite loop, repeatedly showing dialogs and freezing the UI. This results in a poor user experience and may crash the app.',
    correctionMessage:
        'Move all dialog calls out of build() and into event handlers (e.g., onPressed) or lifecycle methods (e.g., initState) to prevent infinite loops and keep your app responsive.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _dialogMethods = <String>{
    'showDialog',
    'showModalBottomSheet',
    'showBottomSheet',
    'showCupertinoDialog',
    'showCupertinoModalPopup',
    'showGeneralDialog',
    'showMenu',
    'showTimePicker',
    'showDatePicker',
    'showDateRangePicker',
    'showSearch',
    'showLicensePage',
    'showAboutDialog',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      node.body.visitChildren(_DialogVisitor(reporter, code, _dialogMethods));
    });
  }
}

class _DialogVisitor extends RecursiveAstVisitor<void> {
  _DialogVisitor(this.reporter, this.code, this.dialogMethods);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> dialogMethods;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Skip if inside a callback (onPressed, onTap, etc.)
    if (_isInsideCallback(node)) {
      super.visitMethodInvocation(node);
      return;
    }

    if (dialogMethods.contains(node.methodName.name)) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  bool _isInsideCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        // Check if this is a callback parameter
        final parent = current.parent;
        if (parent is NamedExpression) {
          final String name = parent.name.label.name;
          if (_callbackNames.contains(name)) {
            return true;
          }
        }
        if (parent is ArgumentList) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  static const Set<String> _callbackNames = <String>{
    'onPressed',
    'onTap',
    'onLongPress',
    'onDoubleTap',
    'onChanged',
    'onSubmitted',
    'onComplete',
    'onDismissed',
    'builder',
    'itemBuilder',
  };
}

/// Warns when showSnackBar is called inside build().
///
/// Alias: snackbar_in_build, no_snackbar_in_build, repeated_snackbar
///
/// Calling showSnackBar in build() causes repeated snackbars on every
/// rebuild, flooding the snackbar queue.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   if (hasError) {
///     ScaffoldMessenger.of(context).showSnackBar(...);
///   }
///   return Container();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _showError() {
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return ElevatedButton(
///     onPressed: _showError,
///     child: Text('Show Error'),
///   );
/// }
/// ```
class AvoidSnackbarInBuildRule extends SaropaLintRule {
  const AvoidSnackbarInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_snackbar_in_build',
    problemMessage:
        '[avoid_snackbar_in_build] showSnackBar in build() causes repeated snackbars. This leads to poor UX and can overwhelm users with duplicate messages.',
    correctionMessage: 'Move snackbar calls to event handlers.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      node.body.visitChildren(_SnackbarVisitor(reporter, code));
    });
  }
}

class _SnackbarVisitor extends RecursiveAstVisitor<void> {
  _SnackbarVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Skip if inside a callback
    if (_isInsideCallback(node)) {
      super.visitMethodInvocation(node);
      return;
    }

    if (node.methodName.name == 'showSnackBar') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  bool _isInsideCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when analytics calls are made inside build().
///
/// Alias: analytics_in_build, no_tracking_in_build, duplicate_analytics_events
///
/// Analytics calls in build() fire on every rebuild, causing duplicate
/// events and inaccurate tracking data.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   analytics.logEvent('page_view'); // Fires repeatedly!
///   return Container();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   analytics.logEvent('page_view');
/// }
/// ```
class AvoidAnalyticsInBuildRule extends SaropaLintRule {
  const AvoidAnalyticsInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_analytics_in_build',
    problemMessage:
        '[avoid_analytics_in_build] Analytics calls in build() fire on every rebuild. This can skew analytics data and degrade app performance.',
    correctionMessage: 'Move analytics to initState() or event handlers.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _analyticsMethods = <String>{
    'logEvent',
    'logScreenView',
    'trackEvent',
    'track',
    'logPageView',
    'setCurrentScreen',
    'setUserProperty',
    'logLogin',
    'logPurchase',
    'logShare',
    'logSearch',
    'logSelectContent',
    'logSignUp',
    'logBeginCheckout',
    'logViewItem',
    'logAddToCart',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      node.body
          .visitChildren(_AnalyticsVisitor(reporter, code, _analyticsMethods));
    });
  }
}

class _AnalyticsVisitor extends RecursiveAstVisitor<void> {
  _AnalyticsVisitor(this.reporter, this.code, this.analyticsMethods);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> analyticsMethods;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Skip if inside a callback
    if (_isInsideCallback(node)) {
      super.visitMethodInvocation(node);
      return;
    }

    if (analyticsMethods.contains(node.methodName.name)) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  bool _isInsideCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when jsonEncode is called inside build().
///
/// Alias: json_in_build, no_json_encode_in_build, expensive_build_operation
///
/// JSON encoding is expensive. Doing it in build() causes performance issues
/// because build() is called frequently (60fps during animations).
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final json = jsonEncode(largeObject); // Expensive!
///   return Text(json);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// String? _cachedJson;
///
/// @override
/// void initState() {
///   super.initState();
///   _cachedJson = jsonEncode(largeObject);
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Text(_cachedJson ?? '');
/// }
/// ```
class AvoidJsonEncodeInBuildRule extends SaropaLintRule {
  const AvoidJsonEncodeInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_json_encode_in_build',
    problemMessage:
        '[avoid_json_encode_in_build] jsonEncode in build() is expensive and causes jank.',
    correctionMessage: 'Cache JSON encoding result outside of build().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      node.body.visitChildren(_JsonEncodeVisitor(reporter, code));
    });
  }
}

class _JsonEncodeVisitor extends RecursiveAstVisitor<void> {
  _JsonEncodeVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'jsonEncode' ||
        node.methodName.name == 'json.encode') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final String source = node.function.toSource();
    if (source == 'jsonEncode') {
      reporter.atNode(node, code);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when GetIt.I or GetIt.instance is used inside build().
///
/// Alias: getit_in_build, service_locator_in_build, inject_dependencies
///
/// Service locator calls in build() hide dependencies and make
/// testing difficult. Inject dependencies via constructor instead.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final service = GetIt.I<MyService>();
///   return Text(service.value);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   const MyWidget({required this.service});
///   final MyService service;
///
///   @override
///   Widget build(BuildContext context) {
///     return Text(service.value);
///   }
/// }
/// ```
class AvoidGetItInBuildRule extends SaropaLintRule {
  const AvoidGetItInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_getit_in_build',
    problemMessage:
        '[avoid_getit_in_build] GetIt service locator in build() hides dependencies.',
    correctionMessage:
        'Inject dependencies via constructor or access in initState().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      final String bodySource = node.body.toSource();
      if (bodySource.contains('GetIt.I') ||
          bodySource.contains('GetIt.instance') ||
          bodySource.contains('getIt<') ||
          bodySource.contains('getIt(')) {
        // Find the actual GetIt usage
        node.body.visitChildren(_GetItVisitor(reporter, code));
      }
    });
  }
}

class _GetItVisitor extends RecursiveAstVisitor<void> {
  _GetItVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'GetIt' &&
        (node.identifier.name == 'I' || node.identifier.name == 'instance')) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String? targetName = node.target?.toSource();
    if (targetName == 'GetIt.I' || targetName == 'GetIt.instance') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Canvas operations are used outside of CustomPainter.
///
/// Alias: canvas_in_build, no_canvas_in_build, use_custom_painter
///
/// Canvas operations should only be in CustomPainter.paint(), not in
/// build methods or other locations.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final canvas = Canvas(recorder);
///   canvas.drawRect(...); // Wrong place!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyPainter extends CustomPainter {
///   @override
///   void paint(Canvas canvas, Size size) {
///     canvas.drawRect(...);
///   }
/// }
/// ```
class AvoidCanvasInBuildRule extends SaropaLintRule {
  const AvoidCanvasInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_canvas_operations_in_build',
    problemMessage:
        '[avoid_canvas_operations_in_build] Canvas operations belong in CustomPainter, not build(). Doing this in build() can cause performance issues and unpredictable rendering.',
    correctionMessage: 'Move canvas operations to CustomPainter.paint().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      final String bodySource = node.body.toSource();
      if (bodySource.contains('Canvas(') ||
          bodySource.contains('.drawRect') ||
          bodySource.contains('.drawCircle') ||
          bodySource.contains('.drawPath') ||
          bodySource.contains('.drawLine')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when hardcoded feature flags (if true/false) are used.
///
/// Alias: literal_boolean_condition, if_true_if_false, dead_code_condition
///
/// Hardcoded conditions like `if (true)` or `if (false)` suggest
/// incomplete feature flag implementation or dead code.
///
/// **BAD:**
/// ```dart
/// if (true) {
///   // This always runs - is this intentional?
///   showNewFeature();
/// }
///
/// if (false) {
///   // Dead code - remove or use proper feature flag
///   showOldFeature();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (FeatureFlags.newFeatureEnabled) {
///   showNewFeature();
/// }
/// ```
class AvoidHardcodedFeatureFlagsRule extends SaropaLintRule {
  const AvoidHardcodedFeatureFlagsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_feature_flags',
    problemMessage:
        '[avoid_hardcoded_feature_flags] Hardcoded if(true)/if(false) suggests incomplete feature flag.',
    correctionMessage: 'Use a proper feature flag system or remove dead code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final Expression condition = node.expression;
      if (condition is BooleanLiteral) {
        reporter.atNode(condition, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddFeatureFlagTodoFix()];
}

class _AddFeatureFlagTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression condition = node.expression;
      if (condition is! BooleanLiteral) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK to replace with feature flag',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Replace hardcoded ${condition.value} with feature flag\n    ',
        );
      });
    });
  }
}

/// Warns when multiple setState calls are made in the same method.
///
/// Alias: combine_setstate, multiple_setstate, batch_setstate
///
/// Multiple setState calls cause multiple rebuilds. Combine them for
/// better performance.
///
/// **BAD:**
/// ```dart
/// void updateData() {
///   setState(() { _name = 'John'; });
///   setState(() { _age = 30; });
///   setState(() { _email = 'j@e.com'; });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void updateData() {
///   setState(() {
///     _name = 'John';
///     _age = 30;
///     _email = 'j@e.com';
///   });
/// }
/// ```
class PreferSingleSetStateRule extends SaropaLintRule {
  const PreferSingleSetStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_single_setstate',
    problemMessage:
        '[prefer_single_setstate] Multiple setState calls cause unnecessary rebuilds.',
    correctionMessage: 'Combine setState calls into a single call.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip build methods - this rule is for other methods
      if (node.name.lexeme == 'build') return;

      int setStateCount = 0;
      MethodInvocation? firstSetState;

      node.body.visitChildren(_SetStateCountVisitor(
        onSetState: (MethodInvocation inv) {
          setStateCount++;
          firstSetState ??= inv;
        },
      ));

      if (setStateCount > 1 && firstSetState != null) {
        reporter.atNode(firstSetState!, code);
      }
    });
  }
}

class _SetStateCountVisitor extends RecursiveAstVisitor<void> {
  _SetStateCountVisitor({required this.onSetState});

  final void Function(MethodInvocation) onSetState;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onSetState(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Isolate.run is used for simple computations.
///
/// Alias: use_compute, isolate_run_overhead, prefer_compute_function
///
/// For simple, quick operations, the overhead of spawning an isolate
/// is greater than running inline. Use compute() for heavy work.
///
/// **BAD:**
/// ```dart
/// final result = await Isolate.run(() => a + b); // Too simple
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = a + b; // Simple math - no isolate needed
///
/// // For heavy computation:
/// final result = await compute(parseJson, jsonString);
/// ```
class PreferComputeOverIsolateRunRule extends SaropaLintRule {
  const PreferComputeOverIsolateRunRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_compute_over_isolate_run',
    problemMessage:
        '[prefer_compute_over_isolate_run] Consider using compute() instead of Isolate.run().',
    correctionMessage: 'compute() provides better error handling and typing.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'run') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Isolate') return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when List.generate is used in widget children.
///
/// Alias: no_list_generate_in_children, collection_for_children, prefer_collection_for
///
/// For building widget lists, prefer for-in collection or spread
/// for better readability and performance.
///
/// **BAD:**
/// ```dart
/// Column(
///   children: List.generate(items.length, (i) => Text(items[i])),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(
///   children: [for (final item in items) Text(item)],
/// )
/// // Or:
/// Column(
///   children: items.map((item) => Text(item)).toList(),
/// )
/// ```
class PreferForLoopInChildrenRule extends SaropaLintRule {
  const PreferForLoopInChildrenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_for_loop_in_children',
    problemMessage:
        '[prefer_for_loop_in_children] Prefer collection-for over List.generate in children.',
    correctionMessage: 'Use [for (final item in items) Widget(item)].',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'generate') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'List') return;

      // Check if inside a children argument
      AstNode? current = node.parent;
      while (current != null) {
        if (current is NamedExpression &&
            current.name.label.name == 'children') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when multiple decoration widgets could be a Container.
///
/// Alias: combine_decoration_widgets, nested_padding_decoratedbox, use_container
///
/// Using nested Padding, DecoratedBox, etc. is verbose when
/// Container provides all these features in one widget.
///
/// **BAD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(8),
///   child: DecoratedBox(
///     decoration: BoxDecoration(color: Colors.red),
///     child: SizedBox(width: 100, height: 100, child: child),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Container(
///   padding: EdgeInsets.all(8),
///   decoration: BoxDecoration(color: Colors.red),
///   width: 100,
///   height: 100,
///   child: child,
/// )
/// ```
class PreferContainerRule extends SaropaLintRule {
  const PreferContainerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_container',
    problemMessage:
        '[prefer_container] Nested decoration widgets could be a single Container.',
    correctionMessage: 'Use Container with padding, decoration, and size.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _containerRelatedWidgets = <String>{
    'Padding',
    'DecoratedBox',
    'SizedBox',
    'ColoredBox',
    'Align',
    'Center',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (!_containerRelatedWidgets.contains(typeName)) return;

      // Check if child is also a container-related widget
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (childExpr is InstanceCreationExpression) {
            final String? childType =
                childExpr.constructorName.type.element?.name;
            if (_containerRelatedWidgets.contains(childType)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

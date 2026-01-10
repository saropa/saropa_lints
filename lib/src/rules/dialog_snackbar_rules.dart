import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when SnackBar is created without explicit duration.
///
/// The default SnackBar duration (4 seconds) may not be appropriate for
/// all messages. Explicitly setting duration makes intent clear and
/// ensures UX consistency.
///
/// **BAD:**
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(content: Text('Message')),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(
///     content: Text('Message'),
///     duration: Duration(seconds: 4),
///   ),
/// );
/// ```
class RequireSnackbarDurationRule extends SaropaLintRule {
  const RequireSnackbarDurationRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_snackbar_duration',
    problemMessage: 'SnackBar should have explicit duration.',
    correctionMessage:
        'Add duration parameter for consistent UX timing.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'SnackBar') return;

      // Check for duration parameter
      bool hasDuration = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'duration') {
          hasDuration = true;
          break;
        }
      }

      if (!hasDuration) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when showDialog is called without explicit barrierDismissible.
///
/// The barrierDismissible parameter controls whether tapping outside
/// the dialog closes it. Making this explicit improves code clarity
/// and prevents accidental dialog dismissals.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(...),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false, // or true, but explicit
///   builder: (context) => AlertDialog(...),
/// );
/// ```
class RequireDialogBarrierDismissibleRule extends SaropaLintRule {
  const RequireDialogBarrierDismissibleRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_dialog_barrier_dismissible',
    problemMessage: 'showDialog should have explicit barrierDismissible.',
    correctionMessage:
        'Add barrierDismissible: true or false to make intent clear.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      // Check for barrierDismissible parameter
      bool hasBarrierDismissible = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'barrierDismissible') {
          hasBarrierDismissible = true;
          break;
        }
      }

      if (!hasBarrierDismissible) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when showDialog result is not handled.
///
/// Dialogs that return values (like confirmation dialogs) should have
/// their results awaited and processed. Ignoring the result can lead
/// to missed user actions.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.pop(context, true),
///         child: Text('Confirm'),
///       ),
///     ],
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await showDialog<bool>(
///   context: context,
///   builder: (context) => AlertDialog(...),
/// );
/// if (result == true) {
///   // Handle confirmation
/// }
/// ```
class RequireDialogResultHandlingRule extends SaropaLintRule {
  const RequireDialogResultHandlingRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_dialog_result_handling',
    problemMessage: 'showDialog result should be awaited or handled.',
    correctionMessage:
        'Use await showDialog() or .then() to handle the dialog result.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      // Check if the result is used
      final AstNode? parent = node.parent;

      // Check if it's awaited
      if (parent is AwaitExpression) return;

      // Check if .then() is called on it
      if (parent is MethodInvocation && parent.methodName.name == 'then') {
        return;
      }

      // Check if assigned to a variable
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression) return;

      // Check if it's the expression of an expression statement (i.e., not used)
      if (parent is ExpressionStatement) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when showSnackBar is called without clearing previous snackbars.
///
/// Multiple snackbars can queue up, leading to poor UX where users
/// see stale messages. Consider clearing or hiding previous snackbars
/// before showing new ones.
///
/// **BAD:**
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(content: Text('New message')),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final messenger = ScaffoldMessenger.of(context);
/// messenger.clearSnackBars();
/// messenger.showSnackBar(
///   SnackBar(content: Text('New message')),
/// );
/// ```
class AvoidSnackbarQueueBuildupRule extends SaropaLintRule {
  const AvoidSnackbarQueueBuildupRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_snackbar_queue_buildup',
    problemMessage: 'Consider clearing snackbars before showing new ones.',
    correctionMessage:
        'Call clearSnackBars() or hideCurrentSnackBar() before showSnackBar().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showSnackBar') return;

      // Check if preceded by clearSnackBars or hideCurrentSnackBar in same block
      final AstNode? parent = node.parent;
      if (parent is! ExpressionStatement) return;

      final AstNode? block = parent.parent;
      if (block is! Block) return;

      bool foundClearBefore = false;
      for (final Statement statement in block.statements) {
        // If we reach the current statement, stop checking
        if (statement == parent) break;

        // Check if this is a clearSnackBars or hideCurrentSnackBar call
        if (statement is ExpressionStatement &&
            statement.expression is MethodInvocation) {
          final MethodInvocation methodCall =
              statement.expression as MethodInvocation;
          final String methodName = methodCall.methodName.name;
          if (methodName == 'clearSnackBars' ||
              methodName == 'hideCurrentSnackBar') {
            foundClearBefore = true;
            break;
          }
        }
      }

      if (!foundClearBefore) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

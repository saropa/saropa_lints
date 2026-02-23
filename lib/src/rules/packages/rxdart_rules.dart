// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// RxDart lint rules for Flutter/Dart applications.
///
/// These rules help identify common misuses of the rxdart package,
/// including unsafe BehaviorSubject value access after close.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_behavior_subject_last_value
// =============================================================================

/// Warns when `.value` is accessed on a `BehaviorSubject` inside an
/// `isClosed` true-branch.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `BehaviorSubject` retains its last emitted value even after `close()`.
/// Accessing `.value` on a closed subject returns stale data that has been
/// superseded, which can cause subtle logic errors and prevents garbage
/// collection of the retained value.
///
/// **BAD:**
/// ```dart
/// if (_subject.isClosed) {
///   return _subject.value; // Stale data from a closed subject
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!_subject.isClosed) {
///   return _subject.value; // Subject is still active
/// }
/// return fallbackValue;
/// ```
class AvoidBehaviorSubjectLastValueRule extends SaropaLintRule {
  AvoidBehaviorSubjectLastValueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'BehaviorSubject'};

  static const LintCode _code = LintCode(
    'avoid_behavior_subject_last_value',
    '[avoid_behavior_subject_last_value] Accessing .value on a '
        'BehaviorSubject that may be closed. BehaviorSubject retains its last '
        'emitted value even after close() is called. Reading .value on a '
        'closed subject returns stale data that no longer reflects the '
        'current state, which can cause subtle logic errors and prevents '
        'garbage collection of the retained object. If replay behavior is '
        'not needed, consider using PublishSubject instead. {v1}',
    correctionMessage:
        'Guard .value access with an isClosed check that returns a '
        'fallback when closed, or use PublishSubject if replay is not '
        'needed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      // Check for .value access
      if (node.propertyName.name != 'value') return;

      // Check if target looks like a BehaviorSubject
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource();

      // Walk up to find if inside an `if (x.isClosed)` true-branch
      if (!_isInsideIsClosedTrueBranch(node, targetSource)) return;

      reporter.atNode(node, code);
    });
  }

  /// Returns true if [node] is inside the then-branch of
  /// `if (subject.isClosed)`.
  static bool _isInsideIsClosedTrueBranch(AstNode node, String subjectSource) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        // Match: subject.isClosed (without negation)
        if (condition == '$subjectSource.isClosed' ||
            condition == '$subjectSource.isClosed == true') {
          // Check that we are in the then-branch (not else)
          final Statement thenBranch = current.thenStatement;
          if (_isAncestor(thenBranch, node)) return true;
        }
      }
      // Stop at method/function boundary
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  /// Returns true if [ancestor] is an ancestor of [target].
  static bool _isAncestor(AstNode ancestor, AstNode target) {
    AstNode? current = target;
    while (current != null) {
      if (identical(current, ancestor)) return true;
      current = current.parent;
    }
    return false;
  }
}

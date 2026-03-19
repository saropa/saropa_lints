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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

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

// =============================================================================
// prefer_rxdart_for_complex_streams
// =============================================================================

/// Suggests RxDart for complex stream transformations.
///
/// RxDart provides operators (combineLatest, switchMap, etc.) that simplify
/// complex stream logic compared to raw Dart Stream.
///
/// **Bad:** Long chain of stream.map().where().asyncMap() without rxdart.
///
/// **Good:** Use rxdart operators for complex transformations.
class PreferRxdartForComplexStreamsRule extends SaropaLintRule {
  PreferRxdartForComplexStreamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_rxdart_for_complex_streams',
    '[prefer_rxdart_for_complex_streams] Complex stream transformation. '
        'Consider rxdart package for combineLatest, switchMap, and other operators.',
    correctionMessage:
        'Add rxdart for stream operators when logic gets complex.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String content = context.fileContent;
    if (RegExp(r'\brxdart\b').hasMatch(content)) return;
    if (RegExp(r'\bRx\b').hasMatch(content)) return;

    context.addMethodInvocation((MethodInvocation node) {
      final String name = node.methodName.name;
      if (name != 'map' && name != 'where' && name != 'asyncMap') return;
      final Expression? target = node.realTarget;
      if (target == null) return;
      final String? typeStr = target.staticType?.getDisplayString();
      if (typeStr == null || !typeStr.startsWith('Stream')) return;
      reporter.atNode(node);
    });
  }
}

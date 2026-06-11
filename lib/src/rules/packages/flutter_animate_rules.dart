// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// flutter_animate package lint rules.
///
/// Covers animation correctness and best-practice patterns for the
/// `flutter_animate` package (^4.5.2+).  All rules are import-gated:
/// they only run when the file imports `package:flutter_animate/`.
///
/// Rules implemented here:
///   - flutter_animate_unconditional_repeat_in_on_play  (WARNING / bug)
///   - flutter_animate_restart_on_hot_reload_in_release (ERROR   / bug)
///   - flutter_animate_no_key_in_list                   (WARNING / codeSmell)
///   - flutter_animate_empty_animate_list               (WARNING / codeSmell)
///   - flutter_animate_fixed_target_literal             (INFO    / codeSmell)
///   - flutter_animate_auto_play_false_no_driver        (INFO    / codeSmell)
///
/// flutter_animate_external_controller_not_disposed is intentionally absent:
/// it overlaps with the disposal_rules.dart family (require_animation_controller_dispose,
/// require_dispose_implementation, require_change_notifier_dispose) and was
/// dropped per the 2026-06-11 validation review.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../project_context.dart' show RuleCost;
import '../../saropa_lint_rule.dart';

// =============================================================================
// flutter_animate_unconditional_repeat_in_on_play
// =============================================================================

/// Flags an `onPlay:` callback on `Animate`/`.animate()` whose body calls
/// `.repeat()` without any `if` or conditional guard.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The documented loop idiom `onPlay: (c) => c.repeat(reverse: true)` creates
/// an animation that runs forever.  Flutter's `AnimationController` does NOT
/// pause when the widget scrolls off-screen, is hidden behind a route, or is
/// placed in an `Offstage`.  Every vsync tick fires a new frame, consuming CPU
/// and preventing the rasterizer thread from sleeping (flutter/flutter #5469,
/// #128197).  The correct approach is to gate the repeat on a
/// `VisibilityDetector` callback, a `WidgetsBindingObserver` lifecycle check,
/// or a mounted/visibility flag.
///
/// **Bad:**
/// ```dart
/// Animate(
///   onPlay: (controller) => controller.repeat(reverse: true),
///   child: myWidget,
/// )
/// ```
///
/// **Good:**
/// ```dart
/// Animate(
///   onPlay: (controller) {
///     if (_isVisible) controller.repeat(reverse: true);
///   },
///   child: myWidget,
/// )
/// ```
class FlutterAnimateUnconditionalRepeatInOnPlayRule extends SaropaLintRule {
  FlutterAnimateUnconditionalRepeatInOnPlayRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'flutter_animate_unconditional_repeat_in_on_play',
    '[flutter_animate_unconditional_repeat_in_on_play] The onPlay: callback calls controller.repeat() unconditionally. AnimationController does not pause when the widget scrolls off-screen or is hidden, so an unconditional repeat burns CPU every vsync tick. Gate the repeat on a visibility check, a WidgetsBindingObserver lifecycle state, or a mounted flag. (flutter/flutter #5469, #128197) {v1}',
    correctionMessage:
        'Wrap controller.repeat() in an if-guard, e.g. if (_isVisible) controller.repeat(reverse: true);',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;
      if (node.name.label.name != 'onPlay') return;

      // Only care when the parent ArgumentList belongs to Animate()/animate().
      if (!_isAnimateCall(node)) return;

      final Expression value = node.expression;
      if (value is! FunctionExpression) return;

      // Walk the function body looking for a .repeat() call.
      final _RepeatFinder finder = _RepeatFinder();
      value.body.accept(finder);

      // No repeat call found — nothing to report.
      if (!finder.hasUnguardedRepeat) return;

      reporter.atNode(node);
    });
  }
}

/// Walks a function body and detects whether any `MethodInvocation` named
/// `repeat` exists outside an `IfStatement` or `ConditionalExpression`.
class _RepeatFinder extends RecursiveAstVisitor<void> {
  bool hasUnguardedRepeat = false;

  // Track nesting depth inside guards so we can skip deeply nested ones.
  int _guardDepth = 0;

  @override
  void visitIfStatement(IfStatement node) {
    _guardDepth++;
    super.visitIfStatement(node);
    _guardDepth--;
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _guardDepth++;
    super.visitConditionalExpression(node);
    _guardDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'repeat' && _guardDepth == 0) {
      hasUnguardedRepeat = true;
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// flutter_animate_restart_on_hot_reload_in_release
// =============================================================================

/// Flags `Animate.restartOnHotReload = true` when not guarded by `kDebugMode`
/// or `assert(...)`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `Animate.restartOnHotReload` is a development convenience that restarts all
/// running animations on every Flutter hot-reload.  When left `true` in
/// production it causes every `Animate` widget to restart whenever Flutter
/// internally reassembles the tree, producing unexpected animation replays and
/// adding overhead on every reassembly.  The package README explicitly marks
/// this flag as "for animation testing during development."  Shipping it `true`
/// is a defect.
///
/// **Bad:**
/// ```dart
/// void main() {
///   Animate.restartOnHotReload = true;  // ships in release!
///   runApp(const MyApp());
/// }
/// ```
///
/// **Good:**
/// ```dart
/// void main() {
///   if (kDebugMode) Animate.restartOnHotReload = true;
///   runApp(const MyApp());
/// }
/// ```
class FlutterAnimateRestartOnHotReloadInReleaseRule extends SaropaLintRule {
  FlutterAnimateRestartOnHotReloadInReleaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'flutter_animate_restart_on_hot_reload_in_release',
    '[flutter_animate_restart_on_hot_reload_in_release] Animate.restartOnHotReload is set to true without a kDebugMode or assert guard. This flag is a development convenience; in production it restarts every Animate widget during widget-tree reassembly, causing unexpected animation replays and adding overhead on each rebuild. The package README labels this "for animation testing during development." Wrap in if (kDebugMode) { ... } or an assert. {v1}',
    correctionMessage:
        'Wrap in if (kDebugMode) { Animate.restartOnHotReload = true; } or remove the line from production code.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAssignmentExpression((AssignmentExpression node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;

      // Left side must be `Animate.restartOnHotReload`.
      final Expression lhs = node.leftHandSide;
      if (lhs is! PrefixedIdentifier) return;
      if (lhs.prefix.name != 'Animate') return;
      if (lhs.identifier.name != 'restartOnHotReload') return;

      // Right side must be the literal `true`.
      final Expression rhs = node.rightHandSide;
      if (rhs is! BooleanLiteral || !rhs.value) return;

      // Skip when the assignment is already guarded by kDebugMode or assert.
      if (_isGuardedByDebugMode(node)) return;

      reporter.atNode(node);
    });
  }

  /// Returns true when [node] is nested inside an `IfStatement` whose condition
  /// references `kDebugMode`, or inside an `AssertStatement`.
  bool _isGuardedByDebugMode(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is AssertStatement) return true;
      if (current is IfStatement) {
        final _DebugModeChecker checker = _DebugModeChecker();
        // analyzer 12.x: IfStatement.condition was renamed to .expression
        // (the package-pinned type only exposes .expression).
        current.expression.accept(checker);
        if (checker.found) return true;
      }
      // Stop at function boundary to avoid matching an outer unrelated guard.
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }
}

/// Detects whether an expression references `kDebugMode`.
class _DebugModeChecker extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'kDebugMode') found = true;
    super.visitSimpleIdentifier(node);
  }
}

// =============================================================================
// flutter_animate_no_key_in_list
// =============================================================================

/// Flags an `Animate(...)` or `.animate()` element inside a `children: [...]`
/// list of Column/Row/ListView/Stack/Wrap/AnimateList that carries no `key:`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `Animate` is a `StatefulWidget`.  When Flutter's reconciler replaces a slot
/// in a multi-child widget, it creates a new `State` object, resetting and
/// replaying the animation from the beginning.  A stable `Key` anchors the
/// widget identity across rebuilds so the animation state is preserved.  The
/// flutter_animate README itself documents `key: UniqueKey()` as the mechanism
/// to FORCE a restart — confirming that keys are load-bearing for state
/// identity.
///
/// Note: static lists that never reorder are a mild false positive (accepted at
/// WARNING severity to let teams apply judgment).  Test files are skipped.
///
/// **Bad:**
/// ```dart
/// Column(children: [
///   myWidget.animate().fade(),  // no key → new State on every rebuild
/// ])
/// ```
///
/// **Good:**
/// ```dart
/// Column(children: [
///   myWidget.animate(key: ValueKey(id)).fade(),
/// ])
/// ```
class FlutterAnimateNoKeyInListRule extends SaropaLintRule {
  FlutterAnimateNoKeyInListRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'flutter_animate_no_key_in_list',
    '[flutter_animate_no_key_in_list] An Animate widget or .animate() call inside a children: list (Column, Row, ListView, Stack, Wrap, AnimateList) carries no key:. Without a stable key, Flutter creates a new State on every rebuild, restarting the animation unexpectedly. Assign a key: (e.g. ValueKey(id)) to the Animate call or its immediate child widget to preserve animation state across rebuilds. {v1}',
    correctionMessage:
        'Add key: ValueKey(uniqueId) to the .animate() call or to its immediate child widget.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Multi-child widgets whose `children:` list is the context of concern.
  static const Set<String> _multiChildWidgets = <String>{
    'Column',
    'Row',
    'ListView',
    'Stack',
    'Wrap',
    'AnimateList',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;

      // The ListLiteral must be the value of a `children:` named arg.
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression) return;
      if (parent.name.label.name != 'children') return;

      // The named arg's grandparent must be an ArgumentList of a recognised
      // multi-child widget constructor.
      final AstNode? argList = parent.parent;
      if (argList is! ArgumentList) return;
      final AstNode? call = argList.parent;
      if (!_isMultiChildWidget(call)) return;

      // Scan each list element for Animate or .animate() without a key:.
      for (final CollectionElement element in node.elements) {
        if (element is! Expression) continue;
        final Expression expr = element;

        // Shape 1: Animate(...) constructor — no key: arg present.
        if (expr is InstanceCreationExpression) {
          final String typeName = expr.constructorName.type.name.lexeme;
          if (typeName == 'Animate' && !_hasKeyArg(expr.argumentList)) {
            reporter.atNode(expr);
          }
          continue;
        }

        // Shape 2: someWidget.animate(...) — check the outermost .animate()
        // call in the chain for a key: arg; also accept key: on the receiver
        // widget itself if it is an InstanceCreationExpression.
        final MethodInvocation? animateCall = _findOutermostAnimateCall(expr);
        if (animateCall == null) continue;

        // key: on the .animate() call itself.
        if (_hasKeyArg(animateCall.argumentList)) continue;

        // key: on the immediate child widget (receiver of .animate()).
        final Expression? receiver = animateCall.realTarget;
        if (receiver is InstanceCreationExpression &&
            _hasKeyArg(receiver.argumentList)) {
          continue;
        }

        reporter.atNode(animateCall);
      }
    });
  }

  /// True when [call] is an `InstanceCreationExpression` or
  /// `MethodInvocation` whose constructor/method type name is one of the
  /// recognized multi-child widgets.
  bool _isMultiChildWidget(AstNode? call) {
    if (call is InstanceCreationExpression) {
      return _multiChildWidgets.contains(call.constructorName.type.name.lexeme);
    }
    if (call is MethodInvocation) {
      return _multiChildWidgets.contains(call.methodName.name);
    }
    return false;
  }

  /// Returns true when [args] contains a named argument named `key`.
  bool _hasKeyArg(ArgumentList args) {
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'key') return true;
    }
    return false;
  }

  /// Walks up a method-invocation chain to find the outermost `.animate()`
  /// call (i.e., the one closest to the list-element boundary), which is
  /// the call that should carry the `key:` argument.
  MethodInvocation? _findOutermostAnimateCall(Expression expr) {
    MethodInvocation? found;
    // Walk down through chained calls (.animate().fade().slideX() ...).
    Expression current = expr;
    while (current is MethodInvocation) {
      if (current.methodName.name == 'animate') found = current;
      final Expression? target = current.target;
      if (target == null) break;
      current = target;
    }
    return found;
  }
}

// =============================================================================
// flutter_animate_empty_animate_list
// =============================================================================

/// Flags `AnimateList(children: [])` or `[].animate(...)` where the children
/// expression is a literal empty list.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `AnimateList` with an empty `children` list creates wrapper machinery
/// (internal `Animate` instances) over zero children.  No animation plays, no
/// child is rendered, and the allocation is pure overhead — dead code in the
/// same sense as an empty `Column(children: [])`.  This is typically a
/// copy-paste error where items were removed but the enclosing animated list
/// was not.
///
/// **Bad:**
/// ```dart
/// AnimateList(children: [])
/// [].animate(interval: 200.ms)
/// ```
///
/// **Good:**
/// ```dart
/// AnimateList(children: myItems)
/// myItems.animate(interval: 200.ms)
/// ```
class FlutterAnimateEmptyAnimateListRule extends SaropaLintRule {
  FlutterAnimateEmptyAnimateListRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'flutter_animate_empty_animate_list',
    '[flutter_animate_empty_animate_list] AnimateList(children: []) or [].animate(...) constructs the flutter_animate wrapper machinery over zero children. No animation plays, nothing is rendered, and the widget allocation is pure overhead — equivalent to an empty Column(children: []). This is typically a copy-paste error where items were removed but the animated list wrapper was not. Either populate children or remove the AnimateList entirely. {v1}',
    correctionMessage:
        'Populate children with actual widgets, or remove the empty AnimateList.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Shape 1: AnimateList(children: []).
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;
      if (node.constructorName.type.name.lexeme != 'AnimateList') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'children') continue;
        final Expression value = arg.expression;
        if (value is ListLiteral && value.elements.isEmpty) {
          reporter.atNode(node);
        }
        break;
      }
    });

    // Shape 2: [].animate(...) — empty list literal receiver.
    context.addMethodInvocation((MethodInvocation node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;
      if (node.methodName.name != 'animate') return;

      final Expression? target = node.realTarget;
      if (target is ListLiteral && target.elements.isEmpty) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// flutter_animate_fixed_target_literal
// =============================================================================

/// Flags a `target:` named arg on `Animate`/`.animate()` whose value is a
/// numeric literal.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The `target` parameter is designed for state-driven animation: when the
/// value changes via `setState`, `Animate` automatically plays to the new
/// position.  Passing a numeric literal (e.g. `target: 1.0`) hard-codes the
/// value to never change, so the animation plays once to that position on
/// mount — exactly what `autoPlay: true` (the default) already does.  The
/// developer almost certainly intended to pass a state variable (`target:
/// _isActive ? 1.0 : 0.0`) but wrote a literal instead.
///
/// **Bad:**
/// ```dart
/// myWidget.animate(target: 1.0).fade()
/// ```
///
/// **Good:**
/// ```dart
/// myWidget.animate(target: _isActive ? 1.0 : 0.0).fade()
/// ```
class FlutterAnimateFixedTargetLiteralRule extends SaropaLintRule {
  FlutterAnimateFixedTargetLiteralRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.trivial;

  static const LintCode _code = LintCode(
    'flutter_animate_fixed_target_literal',
    '[flutter_animate_fixed_target_literal] The target: parameter on Animate/.animate() is a fixed numeric literal. The target parameter is designed for state-driven animation: when its value changes the widget automatically animates to the new position. A literal value (e.g. 1.0) never changes, so the effect is identical to the default autoPlay: true — but the intent is misleading. Pass a state variable or conditional expression instead, e.g. target: _isActive ? 1.0 : 0.0. {v1}',
    correctionMessage:
        'Replace the literal with a state variable or conditional expression, e.g. target: _isActive ? 1.0 : 0.0.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;
      if (node.name.label.name != 'target') return;
      if (!_isAnimateCall(node)) return;

      final Expression value = node.expression;

      // Direct numeric literal: 1.0 or 1.
      if (value is DoubleLiteral || value is IntegerLiteral) {
        reporter.atNode(node);
        return;
      }

      // Unary-minus numeric literal: -1.0 or -1.
      if (value is PrefixExpression &&
          value.operator.lexeme == '-' &&
          (value.operand is DoubleLiteral || value.operand is IntegerLiteral)) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// flutter_animate_auto_play_false_no_driver
// =============================================================================

/// Flags `autoPlay: false` on `Animate`/`.animate()` when none of
/// `controller:`, `adapter:`, or `target:` is also present.
///
/// Since: v4.17.0 | Rule version: v1
///
/// Setting `autoPlay: false` disables the automatic `_controller.forward()`
/// call on mount.  Without a `controller:`, `adapter:`, or `target:` to drive
/// playback, the animation can never start — the widget stays permanently at
/// the `value` position (default 0), which renders as the animation's start
/// state (typically invisible if `FadeEffect` is the first effect).  This is
/// most often a copy-paste error where the developer set `autoPlay: false`
/// intending to wire up a controller but never did.
///
/// **Bad:**
/// ```dart
/// myWidget.animate(autoPlay: false).fade()  // nothing drives it
/// ```
///
/// **Good:**
/// ```dart
/// myWidget.animate(autoPlay: false, controller: _controller).fade()
/// ```
class FlutterAnimateAutoPlayFalseNoDriverRule extends SaropaLintRule {
  FlutterAnimateAutoPlayFalseNoDriverRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'flutter_animate_auto_play_false_no_driver',
    '[flutter_animate_auto_play_false_no_driver] autoPlay: false is set on Animate/.animate() but none of controller:, adapter:, or target: is present in the same call. Without one of these the animation can never start: the widget stays permanently at its initial position (value 0), which renders as the animation start state — typically invisible when FadeEffect is the first effect. This is most often a copy-paste error where a controller was intended but never wired up. {v1}',
    correctionMessage:
        'Add controller:, adapter:, or target: to drive the animation, or remove autoPlay: false to use the default auto-play behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Named args that count as valid animation drivers.
  static const Set<String> _driverArgs = <String>{
    'controller',
    'adapter',
    'target',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (!fileImportsPackage(node, PackageImports.flutterAnimate)) return;
      if (node.name.label.name != 'autoPlay') return;
      if (!_isAnimateCall(node)) return;

      // Value must be the literal `false`.
      final Expression value = node.expression;
      if (value is! BooleanLiteral || value.value) return;

      // If any driver arg is present in the same ArgumentList, do not report.
      final AstNode? argList = node.parent;
      if (argList is! ArgumentList) return;

      for (final Expression arg in argList.arguments) {
        if (arg is NamedExpression &&
            _driverArgs.contains(arg.name.label.name)) {
          return;
        }
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

/// Returns true when [namedExpr] is a named argument inside an `Animate(...)`
/// constructor or an `.animate(...)` method invocation.
///
/// Syntactic check only (no type resolution) so it works under the scan CLI
/// and in files with partial resolution.
bool _isAnimateCall(NamedExpression namedExpr) {
  final AstNode? argList = namedExpr.parent;
  if (argList is! ArgumentList) return false;

  final AstNode? call = argList.parent;

  // Animate(...) constructor.
  if (call is InstanceCreationExpression) {
    return call.constructorName.type.name.lexeme == 'Animate';
  }

  // .animate(...) method invocation.
  if (call is MethodInvocation) {
    return call.methodName.name == 'animate';
  }

  return false;
}

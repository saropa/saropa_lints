// ignore_for_file: depend_on_referenced_packages

/// Detects `dispose()` calls on `late` fields whose initialization is
/// conditional, since accessing an unassigned `late` field throws
/// `LateInitializationError` at teardown.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart';

/// Warns when a `dispose()`-shaped call targets a `late` field whose
/// assignment inside `initState()` is conditional, since Dart does not
/// verify at compile time that a `late` field is assigned before every read.
///
/// Since: v14.5.11 | Updated: v14.5.11 | Rule version: v1
///
/// Closes a competitive gap with DCM's `avoid-disposing-late-fields`.
///
/// A `late final AnimationController _controller;` field initialized only
/// inside an `if` branch of `initState()` (e.g. behind a feature flag or a
/// data-dependent condition) crashes with `LateInitializationError` when
/// `dispose()` unconditionally calls `_controller.dispose()` on a widget
/// instance that took the branch skipping assignment. Because this happens
/// during teardown, the crash is easy to miss in manual testing — it only
/// reproduces on the specific navigation path that skips the conditional.
///
/// This rule uses a conservative heuristic (v1 scope, see the proposal doc):
/// it flags only when NO unconditional assignment to the field exists
/// anywhere at the top level of `initState()`, and no `if`/`else if`/`else`
/// chain assigns the field in every branch (full branch coverage is treated
/// as safe). It intentionally accepts false negatives on more complex
/// control flow (loops, switch, try/catch, helper-method delegation) rather
/// than risk false positives — see disposal_rules.dart for the same
/// trade-off applied to sibling lifecycle rules.
///
/// **BAD:**
/// ```dart
/// class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
///   late final AnimationController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     if (widget.autoPlay) {
///       _controller = AnimationController(vsync: this);
///     }
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose(); // LINT — may never have been assigned
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
///     with SingleTickerProviderStateMixin {
///   late final AnimationController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = AnimationController(vsync: this); // unconditional
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose(); // OK — provably initialized
///     super.dispose();
///   }
/// }
/// ```
class AvoidDisposingLateFieldsRule extends SaropaLintRule {
  AvoidDisposingLateFieldsRule() : super(code: _code);

  /// Crashes at widget teardown — a real, if narrow-trigger, bug class.
  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'disposal', 'flutter', 'reliability', 'late'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // Cheap pre-filters: only worth walking a class when it both declares a
  // `late` field and calls something named `dispose` — skips the vast
  // majority of files before any AST work happens.
  @override
  Set<String> get requiredPatterns => const {'late', 'dispose'};

  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_disposing_late_fields',
    '[avoid_disposing_late_fields] This dispose() call targets a late field '
        'that is only assigned inside a conditional branch of initState(), '
        'with no unconditional assignment or full if/else branch coverage '
        'proving it is always set. Dart does not check at compile time that '
        'a late field is assigned before every read, so if the widget takes '
        'the code path that skips initialization, this dispose() call '
        'throws LateInitializationError during widget teardown — a crash '
        'that is easy to miss in manual testing because it only reproduces '
        'on the specific navigation path that skipped the conditional. {v1}',
    correctionMessage:
        'Assign the late field unconditionally in initState(), assign it in '
        'every branch of the if/else chain (including an else), or guard '
        'the dispose() call with the same condition used to initialize it.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Only `late` fields with no inline initializer are candidates — a
      // `late final _x = _compute();` lazy initializer always runs exactly
      // once on first read and cannot throw at dispose() unless the field
      // was never read at all before dispose(), which is a different
      // (unreachable-initialization) problem out of scope for this rule.
      final List<String> candidateFields = <String>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration && member.fields.isLate) {
          for (final VariableDeclaration variable
              in member.fields.variables) {
            if (variable.initializer == null) {
              candidateFields.add(variable.name.lexeme);
            }
          }
        }
      }
      if (candidateFields.isEmpty) return;

      MethodDeclaration? initState;
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'initState') initState = member;
          if (member.name.lexeme == 'dispose') disposeMethod = member;
        }
      }
      // No dispose() at all means there is nothing to flag here — a
      // sibling rule (require_*_dispose) already covers "missing dispose".
      if (disposeMethod == null) return;
      final FunctionBody disposeBody = disposeMethod.body;
      if (disposeBody is! BlockFunctionBody) return;

      for (final String fieldName in candidateFields) {
        if (_isProvablyInitialized(fieldName, initState)) continue;

        final _DisposeCallFinder finder = _DisposeCallFinder(fieldName);
        disposeBody.block.accept(finder);
        final MethodInvocation? call = finder.match;
        if (call != null) {
          reporter.atNode(call);
        }
      }
    });
  }

  /// True when [fieldName] is assigned unconditionally somewhere at the top
  /// level of [initState]'s body, or is assigned in every branch of an
  /// `if`/`else if`/`else` chain (full coverage). Returns true (safe, do not
  /// flag) when [initState] is absent — a constructor-initializer-list
  /// assignment (rare for `State`, but possible) cannot be disproved by this
  /// heuristic, and treating "unknown" as unsafe would false-positive on
  /// that legitimate pattern.
  static bool _isProvablyInitialized(
    String fieldName,
    MethodDeclaration? initState,
  ) {
    if (initState == null) return true;
    final FunctionBody body = initState.body;
    if (body is! BlockFunctionBody) return true;
    return _blockAssigns(fieldName, body.block);
  }

  /// True when [fieldName] is provably assigned by walking the top-level
  /// statements of [block] — an unconditional assignment statement, or an
  /// `if` chain where every branch (recursively) assigns it.
  static bool _blockAssigns(String fieldName, Block block) {
    for (final Statement statement in block.statements) {
      if (_branchAssigns(fieldName, statement)) return true;
    }
    return false;
  }

  /// True when [statement] — one arm of an if/else chain, or a top-level
  /// statement — provably assigns [fieldName].
  static bool _branchAssigns(String fieldName, Statement statement) {
    if (statement is Block) return _blockAssigns(fieldName, statement);
    if (statement is ExpressionStatement) {
      final Expression expr = statement.expression;
      if (expr is AssignmentExpression) {
        return assignmentTargetFieldName(expr) == fieldName;
      }
      return false;
    }
    if (statement is IfStatement) return _ifCoversAllBranches(fieldName, statement);
    return false;
  }

  /// True when [ifStmt]'s `then` branch assigns [fieldName] AND it has an
  /// `else` branch that also (recursively, for `else if` chains) assigns
  /// it — i.e. every path through the chain assigns the field, matching
  /// edge case 5 in the proposal ("branches together cover all paths").
  static bool _ifCoversAllBranches(String fieldName, IfStatement ifStmt) {
    if (!_branchAssigns(fieldName, ifStmt.thenStatement)) return false;
    final Statement? elseBranch = ifStmt.elseStatement;
    if (elseBranch == null) return false;
    return _branchAssigns(fieldName, elseBranch);
  }

  static bool _extendsState(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) return false;
    return extendsClause.superclass.name.lexeme == 'State';
  }
}

/// Finds the first unguarded `fieldName.dispose()` / `fieldName?.dispose()`
/// call inside a dispose() method body. "Unguarded" means no `IfStatement`
/// ancestor between the call and the enclosing method — a dispose() call
/// already wrapped in a conditional (e.g. `if (widget.autoPlay) {
/// _controller.dispose(); }`) is treated as intentionally guarded and is
/// not flagged, matching edge case 4 in the proposal: the guard at the call
/// site proves safety even though initialization was conditional.
class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.fieldName);

  final String fieldName;
  MethodInvocation? match;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (match == null &&
        node.methodName.name == 'dispose' &&
        node.target != null &&
        extractTargetName(node.target!) == fieldName &&
        !_isGuarded(node)) {
      match = node;
    }
    super.visitMethodInvocation(node);
  }

  static bool _isGuarded(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) return true;
      if (current is MethodDeclaration) break;
      current = current.parent;
    }
    return false;
  }
}

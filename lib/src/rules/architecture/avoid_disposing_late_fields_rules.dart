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
/// Since: v14.5.11 | Updated: v14.5.11 | Rule version: v2
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
/// trade-off applied to sibling lifecycle rules. Concretely: any top-level
/// `initState()` statement this heuristic cannot classify (a helper-method
/// call, `try`/`catch`, a loop, a `switch`) is treated as "possibly
/// initializes it, cannot prove otherwise" and skips the whole field —
/// never as proof the field is *unsafe* (Finish Report 2026-09-04,
/// Priority 1: fixes a default-safe/unsafe polarity bug where unanalyzable
/// shapes were previously mis-scored as unsafe, false-positiving on the
/// common `_setupController();` delegation pattern).
///
/// v2 extends that bail-to-safe policy INSIDE `if`/`else` branches, which
/// previously had no bail-out at all: an unanalyzable shape nested in a
/// branch fell through to "this branch does not assign", so a fully-covered
/// `if (x) { _setupA(); } else { _setupB(); }` was reported as unsafe even
/// though both arms initialize the field. v2 also recognizes `switch`,
/// `switch` expression and ternary guards at the dispose() call site (not
/// just `if`), and matches the cascade disposal form
/// `_controller..dispose();`, which the target-based call matcher could
/// never see because a cascade section carries no target of its own.
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
        'on the specific navigation path that skipped the conditional. {v2}',
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

      final List<String> candidateFields = _lateUninitializedFields(node);
      if (candidateFields.isEmpty) return;

      final (MethodDeclaration? initState, MethodDeclaration? disposeMethod) =
          _findLifecycleMethods(node);
      // No dispose() at all means there is nothing to flag here — a
      // sibling rule (require_*_dispose) already covers "missing dispose".
      if (disposeMethod == null) return;
      // `disposeBody.accept()` walks either a `{ ... }` block body or a
      // `=> expr;` arrow body — both are AstNodes, so the visitor traverses
      // into either shape. Previously this bailed out entirely for
      // arrow-bodied dispose() (`void dispose() => _controller.dispose();`),
      // a legal and not-uncommon single-statement override, silently
      // skipping every field in the class (Finish Report 2026-09-04, Issue:
      // "Silent whole-class skip for arrow-bodied dispose()").
      final FunctionBody disposeBody = disposeMethod.body;

      for (final String fieldName in candidateFields) {
        if (_isProvablyInitialized(fieldName, initState)) continue;

        final _DisposeCallFinder finder = _DisposeCallFinder(fieldName);
        disposeBody.accept(finder);
        // AstNode, not MethodInvocation: a cascade section reaches this via
        // _DisposeCallFinder.visitCascadeExpression (see that method's doc).
        final AstNode? call = finder.match;
        if (call != null) {
          reporter.atNode(call);
        }
      }
    });
  }

  /// Collects `late` fields declared with no inline initializer — a
  /// `late final _x = _compute();` lazy initializer always runs exactly once
  /// on first read and cannot throw at dispose() unless the field was never
  /// read at all before dispose(), which is a different
  /// (unreachable-initialization) problem out of scope for this rule.
  ///
  /// Extracted from `runWithReporter` to keep that method's nesting within
  /// the project's ≤3-levels guideline (Finish Report 2026-09-04, Concern:
  /// the inline version nested five levels deep).
  static List<String> _lateUninitializedFields(ClassDeclaration node) {
    final List<String> fields = <String>[];
    for (final ClassMember member in node.bodyMembers) {
      if (member is! FieldDeclaration || !member.fields.isLate) continue;
      for (final VariableDeclaration variable in member.fields.variables) {
        if (variable.initializer == null) fields.add(variable.name.lexeme);
      }
    }
    return fields;
  }

  /// Locates the `initState()` and `dispose()` overrides on [node], if
  /// present. Extracted alongside [_lateUninitializedFields] to keep
  /// `runWithReporter` shallow (Finish Report 2026-09-04, Concern: nesting
  /// depth).
  static (MethodDeclaration?, MethodDeclaration?) _findLifecycleMethods(
    ClassDeclaration node,
  ) {
    MethodDeclaration? initState;
    MethodDeclaration? disposeMethod;
    for (final ClassMember member in node.bodyMembers) {
      if (member is! MethodDeclaration) continue;
      if (member.name.lexeme == 'initState') initState = member;
      if (member.name.lexeme == 'dispose') disposeMethod = member;
    }
    return (initState, disposeMethod);
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
    if (body is ExpressionFunctionBody) {
      // Arrow-bodied initState() (`void initState() => _x = Foo();`) has a
      // single expression instead of statements. Only an unconditional
      // assignment to this exact field is provably safe; any other shape
      // (a helper call, a cascade, a conditional expression) can't be
      // classified by this heuristic, so — consistent with the
      // false-negative-preferring design used everywhere else in this rule —
      // it is treated as "cannot prove unsafe" rather than flagged.
      // Previously this branch didn't exist and ALL arrow bodies fell
      // through to `body is! BlockFunctionBody` returning true unconditionally,
      // which happened to be correct only by luck for the assignment case
      // (Finish Report 2026-09-04, Issue: "Silent per-class miss for
      // arrow-bodied initState()").
      final Expression expr = body.expression;
      if (expr is AssignmentExpression) {
        return assignmentTargetFieldName(expr) == fieldName &&
            _isPlainAssignment(expr);
      }
      return true;
    }
    if (body is! BlockFunctionBody) return true;
    // A top-level statement shape this heuristic can't analyze (helper-method
    // delegation, try/catch, loops, switch) might still assign the field
    // unconditionally — treating it as "unsafe" would false-positive on
    // exactly the patterns the class doc promises are false-negative-only,
    // so bail to "safe" instead of falling through to _blockAssigns' `false`.
    if (_hasUnanalyzableStatement(body.block)) return true;
    return _blockAssigns(fieldName, body.block);
  }

  /// True only for a plain `=` assignment, not a compound operator like
  /// `??=`, `+=`, etc. This matters specifically for `late` fields: `_x ??=
  /// value;` READS `_x` before deciding whether to assign it, so if `_x` was
  /// never initialized, the read itself throws `LateInitializationError`
  /// before the assignment can run — treating `??=` as proof of safe
  /// initialization is backwards (Finish Report 2026-09-04, Concern: "`??=`
  /// counted as a full/safe assignment").
  static bool _isPlainAssignment(AssignmentExpression expr) {
    return expr.operator.lexeme == '=';
  }

  /// True if [block] contains a top-level statement that MIGHT assign
  /// [fieldName] through a path this heuristic can't see into: a bare
  /// (implicit-`this`) helper-method call (`_setupController();`), a
  /// `try`/`catch`, a loop, or a `switch`.
  ///
  /// This must NOT treat `super.initState();` — present at the top of
  /// nearly every real `initState()` override — as unanalyzable: an
  /// earlier version of this check flagged ANY unrecognized
  /// `ExpressionStatement` (super calls included), which bailed to "safe,
  /// don't flag" on almost every class in existence and silently defeated
  /// the whole rule (caught via manual verification against the fixture
  /// after the Finish Report 2026-09-04 Priority 1 fix landed — the
  /// original _bad1/_bad2 cases stopped firing). The fix: only a
  /// `MethodInvocation` with NO explicit target (`node.target == null`) —
  /// an implicit-`this` call that could be a private helper method
  /// defined on this same class — is ambiguous enough to bail on.
  /// `super.foo()`, `widget.foo()`, `SomeClass.foo()`, and any other
  /// invocation with an explicit target cannot assign a private field of
  /// this class through ordinary method-call semantics, so those are safe
  /// to skip over rather than bail on.
  static bool _hasUnanalyzableStatement(Block block) {
    for (final Statement statement in block.statements) {
      if (_isUnanalyzableStatement(statement)) return true;
    }
    return false;
  }

  /// Statement-level half of [_hasUnanalyzableStatement], split out so the
  /// same "can this shape hide an assignment?" test can be applied
  /// RECURSIVELY to the arms of an `if`/`else` chain, not just to the
  /// top-level statements of `initState()`'s block.
  ///
  /// Why the recursion matters (the bug this fixes): the previous version
  /// `continue`d past every `IfStatement` without looking inside it, on the
  /// theory that `_branchAssigns` handles `if` shapes. But `_branchAssigns`
  /// has no bail-out of its own — a helper call, `try`, loop, or `switch`
  /// nested INSIDE a branch simply falls through to `return false` ("this
  /// branch does not assign"), which the caller then reads as proof the
  /// field is unsafe. The result was a false positive on the fully-covered
  /// delegation pattern:
  ///
  /// ```dart
  /// if (widget.useAdvanced) { _setupAdvancedController(); }
  /// else { _setupBasicController(); }
  /// ```
  ///
  /// Both branches genuinely initialize the field, but neither is a shape
  /// this heuristic can see into. Recursing here makes the whole field bail
  /// to "safe" — exactly the policy already applied to the identical shapes
  /// at the top level, so the two levels are now consistent rather than
  /// silently opposite.
  ///
  /// The trade-off is a deliberate false negative: an `if` whose OTHER arm
  /// is unanalyzable no longer proves the field unsafe. That matches this
  /// rule's stated design (accept false negatives, never false positives).
  static bool _isUnanalyzableStatement(Statement statement) {
    // A nested `{ ... }` block (a branch body, or a labeled statement) is
    // walked the same way as the enclosing one.
    if (statement is Block) return _hasUnanalyzableStatement(statement);
    // Recurse into BOTH arms: either one hiding an assignment behind a shape
    // this heuristic can't read makes the whole chain unprovable.
    if (statement is IfStatement) {
      if (_isUnanalyzableStatement(statement.thenStatement)) return true;
      final Statement? elseBranch = statement.elseStatement;
      return elseBranch != null && _isUnanalyzableStatement(elseBranch);
    }
    // `try`/loop/`switch` bodies are invisible to `_branchAssigns` — bail
    // rather than risk mis-scoring a hidden assignment as "unsafe".
    if (statement is TryStatement ||
        statement is ForStatement ||
        statement is WhileStatement ||
        statement is DoStatement ||
        statement is SwitchStatement) {
      return true;
    }
    // Only an `ExpressionStatement` can possibly be a helper-delegation
    // call; everything else (`return`, `assert`, a bare variable
    // declaration) cannot assign the field, so it's safe to move on.
    if (statement is! ExpressionStatement) return false;
    final Expression expr = statement.expression;
    // A plain assignment is handled by `_branchAssigns`; anything that
    // isn't a `MethodInvocation` either (a bare identifier, an index
    // expression) can't assign a field, so it's also safe to skip.
    if (expr is! MethodInvocation) return false;
    // A bare (implicit-`this`) call like `_setupController();` might be
    // a private helper that assigns the field — this heuristic can't
    // see inside it, so bail. A call with an explicit target
    // (`super.foo()`, `widget.foo()`, `SomeClass.foo()`) cannot assign a
    // private field of this class through ordinary method-call
    // semantics, so it's safe to keep scanning past it.
    return expr.target == null;
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
        // See `_isPlainAssignment` doc: a compound operator like `??=` reads
        // the (possibly-uninitialized) field before assigning it, so it is
        // not proof of safe initialization.
        return assignmentTargetFieldName(expr) == fieldName &&
            _isPlainAssignment(expr);
      }
      return false;
    }
    if (statement is IfStatement)
      return _ifCoversAllBranches(fieldName, statement);
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

/// Cleanup verbs this rule treats as "dispose()-shaped" — matching the
/// scope the rule's own doc comment and the originating proposal describe
/// ("another `.dispose()`-shaped call") and the sibling rules in
/// disposal_rules.dart, which cover `StreamSubscription.cancel()` and
/// `StreamController.close()` alongside `.dispose()` (Finish Report
/// 2026-09-04, Priority 4: ".dispose()-only matching narrower than the
/// stated scope").
const Set<String> _cleanupVerbs = {'dispose', 'close', 'cancel'};

/// Finds the first unguarded `fieldName.dispose()` / `fieldName?.dispose()`
/// / `fieldName..dispose()` (or `.close()` / `.cancel()`, see
/// [_cleanupVerbs]) call inside a dispose() method body. "Unguarded" means
/// no conditional ancestor between the call and the enclosing method — a
/// dispose() call already wrapped in a conditional (e.g.
/// `if (widget.autoPlay) { _controller.dispose(); }`) is treated as
/// intentionally guarded and is not flagged, matching edge case 4 in the
/// proposal: the guard at the call site proves safety even though
/// initialization was conditional.
class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.fieldName);

  final String fieldName;

  /// The offending call node. Typed as [AstNode] rather than
  /// [MethodInvocation] because a cascade section is also a
  /// [MethodInvocation] but is reached through [visitCascadeExpression];
  /// keeping the wider type documents that either entry point can fill it.
  AstNode? match;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (match == null &&
        _cleanupVerbs.contains(node.methodName.name) &&
        node.target != null &&
        extractTargetName(node.target!) == fieldName &&
        !_isGuarded(node)) {
      match = node;
    }
    super.visitMethodInvocation(node);
  }

  /// Catches the cascade form `_controller..dispose();`.
  ///
  /// [visitMethodInvocation] cannot see this case: in a cascade the section
  /// `..dispose()` is a [MethodInvocation] with a NULL target — the real
  /// target lives on the enclosing [CascadeExpression] — so the
  /// `node.target != null` guard above rejects it and the field was never
  /// flagged (a silent false negative for a perfectly ordinary disposal
  /// style). Target-name extraction reuses [extractTargetName], the same
  /// helper `_CascadeCleanupVisitor` in target_matcher_utils.dart resolves
  /// cascade targets with (Simple/Prefixed/PropertyAccess identifiers). That
  /// visitor itself is not reused directly because its public entry points
  /// (`hasCascadeCleanup*`) return only a `bool` over a whole
  /// [FunctionBody], while this rule needs the offending NODE to report at,
  /// and needs to apply the [_isGuarded] check per call site.
  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (match == null && extractTargetName(node.target) == fieldName) {
      for (final Expression section in node.cascadeSections) {
        if (section is MethodInvocation &&
            _cleanupVerbs.contains(section.methodName.name) &&
            !_isGuarded(node)) {
          match = section;
          break;
        }
      }
    }
    super.visitCascadeExpression(node);
  }

  /// True when [node] sits inside any conditional construct within the
  /// enclosing method.
  ///
  /// `IfStatement` alone was too narrow: a dispose() call placed in a
  /// `switch` case arm, a `switch` expression arm, or a ternary is just as
  /// deliberately conditional as one inside an `if`, but was treated as
  /// unguarded and flagged. Since the whole point of the guard check is
  /// "the author gated this call on something", every conditional ancestor
  /// shape has to count, or the rule false-positives on hand-written
  /// switch-based teardown.
  ///
  /// `SwitchPatternCase`/`SwitchCase` are matched in addition to
  /// `SwitchStatement` because a `SwitchMember` is not always reached
  /// through a `SwitchStatement` parent chain in every analyzer AST shape
  /// (a `SwitchExpressionCase` hangs off a `SwitchExpression`), and matching
  /// the member directly is the cheaper, shape-independent test.
  static bool _isGuarded(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement ||
          current is SwitchStatement ||
          current is SwitchExpression ||
          current is SwitchMember ||
          current is SwitchExpressionCase ||
          current is ConditionalExpression) {
        return true;
      }
      // Stop at the method boundary: a conditional wrapping the whole
      // dispose() method (impossible in valid Dart) is not the target, and
      // walking past it would leak into unrelated enclosing code.
      if (current is MethodDeclaration) break;
      current = current.parent;
    }
    return false;
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:meta/meta.dart';

import '../../async_context_utils.dart';
import '../../fixes/remove_empty_set_state_fix.dart';
import '../../fixes/widget_lifecycle/wrap_set_state_in_mounted_check_fix.dart';
import '../../saropa_lint_rule.dart';
import 'state_lifecycle_dispose_scan.dart';

/// Shared regex for detecting private method calls (e.g., `_dispose()`).
/// Used by multiple rules to detect calls to private helper methods.
final RegExp _privateMethodCallPattern = RegExp(r'_(\w+)\s*\(');

/// True when [node] is a `State<T>` subclass declaration.
///
/// Resolves the superclass element (falling back to the lexeme when the type
/// is unresolved, e.g. a Flutter `State` with no analyzed Flutter SDK) so that
/// a method merely *named* `initState`/`didChangeDependencies`/`dispose` on a
/// plain (non-State) class is not mistaken for a Flutter lifecycle override.
/// The lifecycle hazards these rules detect only exist inside a real State
/// subclass; gating here prevents firing on unrelated same-named methods.
bool _isStateSubclass(ClassDeclaration node) {
  final ExtendsClause? extendsClause = node.extendsClause;
  if (extendsClause == null) return false;
  final NamedType superclass = extendsClause.superclass;
  // Prefer the resolved element name; fall back to the lexeme when the
  // superclass type does not resolve (no Flutter SDK in the analysis context).
  final String? resolvedName = superclass.element?.name;
  if (resolvedName != null) return resolvedName == 'State';
  return superclass.name.lexeme == 'State';
}

/// True when [initializer] reads a controller from the enclosing widget
/// (`widget.controller`, `widget.config.controller`), meaning the PARENT owns
/// it and is responsible for disposal. The Flutter contract is that whoever
/// creates a controller disposes it, so a State that disposes a parent-supplied
/// controller is the actual bug — flagging "missing disposal" here would push
/// developers toward a double-dispose crash. Narrow on purpose: a locally
/// constructed controller (`ScrollController()`) is NOT parent-owned and still
/// needs disposal, so only an explicit `widget.<member>` read short-circuits.
bool _isParentOwnedFieldInitializer(Expression initializer) {
  // `widget.controller`
  if (initializer is PrefixedIdentifier) {
    return initializer.prefix.name == 'widget';
  }
  // `widget.config.controller` (chained) — receiver root is still `widget`.
  if (initializer is PropertyAccess) {
    final Expression? target = initializer.target;
    if (target is SimpleIdentifier) {
      return target.name == 'widget';
    }
    if (target is PrefixedIdentifier) {
      return target.prefix.name == 'widget';
    }
  }
  return false;
}

class AvoidContextInInitStateDisposeRule extends SaropaLintRule {
  AvoidContextInInitStateDisposeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_context_in_initstate_dispose',
    '[avoid_context_in_initstate_dispose] BuildContext used in initState or dispose may reference an unmounted widget, causing runtime errors or silent failures. '
        'In initState the widget tree is not yet fully built, and in dispose the widget has been removed, so context-dependent lookups (Theme.of, Navigator.of) can return stale or invalid data. {v7}',
    correctionMessage:
        'Use WidgetsBinding.instance.addPostFrameCallback to defer context access until after the widget is mounted. '
        'For dispose, move context-dependent cleanup to deactivate() or use a pre-captured reference to ensure the widget tree is in a valid state when context is accessed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;

      // Only check initState and dispose methods
      if (methodName != 'initState' && methodName != 'dispose') {
        return;
      }

      // Check if this is in a State class (has @override annotation typically)
      final FunctionBody body = node.body;
      if (body is EmptyFunctionBody) {
        return;
      }

      // Visit the method body to find context usages
      final _ContextUsageVisitor visitor = _ContextUsageVisitor(methodName);
      body.accept(visitor);

      // Report each unsafe context usage
      for (final SimpleIdentifier contextNode in visitor.unsafeContextUsages) {
        reporter.atNode(contextNode);
      }
    });
  }

  /// Exposed for unit tests: the unsafe-`context`-usage detection for one
  /// initState/dispose [method] body. Pure syntactic analysis (no resolved
  /// types), so it is verifiable on `parseString` ASTs.
  @visibleForTesting
  static List<SimpleIdentifier> unsafeContextUsagesForTesting(
    MethodDeclaration method,
  ) {
    final _ContextUsageVisitor visitor = _ContextUsageVisitor(
      method.name.lexeme,
    );
    method.body.accept(visitor);
    return visitor.unsafeContextUsages;
  }
}

/// Visitor that finds unsafe `context` usages in initState/dispose methods.
///
/// It tracks when we're inside safe callback regions (like addPostFrameCallback)
/// and only reports context usages that are outside these safe regions.
class _ContextUsageVisitor extends RecursiveAstVisitor<void> {
  _ContextUsageVisitor(this.methodName);

  final String methodName;
  final List<SimpleIdentifier> unsafeContextUsages = <SimpleIdentifier>[];

  /// Depth of safe callback nesting (addPostFrameCallback, Future.microtask, etc.)
  int _safeCallbackDepth = 0;

  /// Names of methods/functions that make context usage safe
  /// (they defer execution until after the widget is mounted)
  static const Set<String> _safeCallbackMethods = <String>{
    'addPostFrameCallback',
    'scheduleFrameCallback',
    'microtask', // Future.microtask
    'scheduleMicrotask',
    'Future', // Future(() => ...) or Future.delayed
    'Timer', // Timer or Timer.run
    'run', // Timer.run
    'delayed', // Future.delayed
  };

  /// Methods on `context` that perform an inherited-widget / render-tree
  /// lookup — these are the genuinely-unsafe uses in initState/dispose.
  static const Set<String> _inheritedAccessorMethods = <String>{
    'dependOnInheritedWidgetOfExactType',
    'getInheritedWidgetOfExactType',
    'dependOnInheritedElement',
    'getElementForInheritedWidgetOfExactType',
    'findAncestorWidgetOfExactType',
    'findAncestorStateOfType',
    'findRootAncestorStateOfType',
    'findAncestorRenderObjectOfType',
    'findRenderObject',
    'visitAncestorElements',
    'visitChildElements',
    // provider / riverpod / watch_it extension accessors on BuildContext
    'watch',
    'read',
    'select',
  };

  /// Properties on `context` that read the (possibly unmounted) render tree.
  static const Set<String> _inheritedProps = <String>{'size', 'owner'};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Only flag `context` when it actually performs an inherited-widget /
    // render-tree lookup (`Theme.of(context)`, `context.watch()`,
    // `context.size`, `context.dependOnInheritedWidgetOfExactType(...)`).
    // A bare `context` forwarded as an argument to an ordinary helper that
    // does no `.of(context)` lookup (e.g. `resolveColor(context)`) registers
    // no dependency and reads no unmounted tree, so flagging it is a false
    // positive — the pre-narrowing behavior fired on the mere token.
    if (node.name == 'context' &&
        _safeCallbackDepth == 0 &&
        !_isContextParameter(node) &&
        _isUnsafeInheritedUsage(node)) {
      unsafeContextUsages.add(node);
    }
    super.visitSimpleIdentifier(node);
  }

  /// True when [node] (a `context` identifier) is used in an inherited-widget
  /// or render-tree lookup shape, rather than merely forwarded as data.
  bool _isUnsafeInheritedUsage(SimpleIdentifier node) {
    final AstNode? parent = node.parent;

    // `context.<accessor>(...)` — context is the receiver of an inherited call.
    if (parent is MethodInvocation && identical(parent.realTarget, node)) {
      return _inheritedAccessorMethods.contains(parent.methodName.name);
    }

    // `context.size` / `context.owner` — context is the receiver of a
    // render-tree property read.
    if (parent is PropertyAccess && identical(parent.realTarget, node)) {
      return _inheritedProps.contains(parent.propertyName.name);
    }
    if (parent is PrefixedIdentifier && identical(parent.prefix, node)) {
      return _inheritedProps.contains(parent.identifier.name);
    }

    // `X.of(context)` / `X.maybeOf(context)` — context is an argument to a
    // static inherited accessor (Theme.of, MediaQuery.of, Navigator.of, …).
    if (parent is ArgumentList) {
      final AstNode? grandparent = parent.parent;
      if (grandparent is MethodInvocation) {
        final String m = grandparent.methodName.name;
        return m == 'of' || m == 'maybeOf';
      }
    }

    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // Check if this is a safe callback method
    final bool isSafeCallback = _safeCallbackMethods.contains(methodName);

    if (isSafeCallback) {
      // Visit the target (e.g., WidgetsBinding.instance) outside safe context
      node.target?.accept(this);
      node.typeArguments?.accept(this);

      // Visit arguments inside safe context
      _safeCallbackDepth++;
      node.argumentList.accept(this);
      _safeCallbackDepth--;
    } else {
      super.visitMethodInvocation(node);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String constructorName = node.constructorName.type.name.lexeme;

    // Check for Future(...) or Timer(...) constructors
    if (constructorName == 'Future' || constructorName == 'Timer') {
      // Visit type arguments outside safe context
      node.constructorName.accept(this);

      // Visit arguments inside safe context
      _safeCallbackDepth++;
      node.argumentList.accept(this);
      _safeCallbackDepth--;
    } else {
      super.visitInstanceCreationExpression(node);
    }
  }

  /// Check if this 'context' identifier is a parameter declaration
  /// (like in a callback: `(context) => ...`)
  bool _isContextParameter(SimpleIdentifier node) {
    final AstNode? parent = node.parent;

    // Check if it's a simple formal parameter
    if (parent is SimpleFormalParameter) {
      return true;
    }

    // Check if it's a declared identifier in a function expression
    if (parent is DeclaredIdentifier) {
      return true;
    }

    return false;
  }
}

/// Warns when a setState callback body is empty without a `mounted` guard.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// An empty `setState(() {})` still triggers a rebuild, but moving state
/// changes inside the callback makes the intent clearer.
///
/// The rule **does not fire** when the call is inside a `mounted` guard
/// (`if (mounted) setState(() {})`, ternary, or early-return pattern),
/// because these indicate intentional rebuilds after async gaps or
/// external state mutations — a common and valid Flutter idiom.
///
/// Example of **bad** code:
/// ```dart
/// setState(() {});
/// ```
///
/// Example of **good** code:
/// ```dart
/// setState(() {
///   _value = newValue;
/// });
///
/// // Also OK — mounted guard makes the intent clear:
/// if (mounted) setState(() {});
/// ```
class AvoidEmptySetStateRule extends SaropaLintRule {
  AvoidEmptySetStateRule() : super(code: _code);

  /// Style preference. Large counts are normal in codebases that use the
  /// `if (mounted) setState(() {})` idiom after async gaps.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveEmptySetStateFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_empty_setstate',
    '[avoid_empty_setstate] setState callback is empty — state was likely modified before this call. An empty setState(() {}) still triggers a rebuild, but moving state changes inside the callback makes the intent clearer. {v5}',
    correctionMessage:
        'Move state changes inside the callback for clarity, or suppress if intentional. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression callback = args.first;
      if (callback is FunctionExpression) {
        final FunctionBody body = callback.body;
        if (body is BlockFunctionBody && body.block.statements.isEmpty) {
          if (_isInsideMountedGuard(node)) return;
          reporter.atNode(node);
        }
      }
    });
  }

  static final RegExp _mountedInSourcePattern = RegExp(r'\bmounted\b');

  /// Walk ancestors to check if [node] is inside a `mounted` guard.
  ///
  /// Handles `if (mounted) setState(…)`, ternary guards, and
  /// early-return patterns (`if (!mounted) return;` before setState).
  static bool _isInsideMountedGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement &&
          _mountedInSourcePattern.hasMatch(current.expression.toSource())) {
        return true;
      }
      if (current is ConditionalExpression &&
          _mountedInSourcePattern.hasMatch(current.condition.toSource())) {
        return true;
      }
      // Stop at method/function boundary
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Expanded with empty child is used instead of Spacer.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v8
///
/// `Spacer()` is clearer and more semantic than `Expanded(child: SizedBox())`.
///
/// Example of **bad** code:
/// ```dart
/// Row(
///   children: [
///     Text('Start'),
///     Expanded(child: SizedBox()),  // Use Spacer instead
///     Text('End'),
///   ],
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Row(
///   children: [
///     Text('Start'),
///     Spacer(),
///     Text('End'),
///   ],
/// )
/// ```
class AvoidLateContextRule extends SaropaLintRule {
  AvoidLateContextRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_late_context',
    '[avoid_late_context] BuildContext in late field initializer captures a stale reference that may become invalid after rebuilds. '
        'Late fields are initialized once on first access, but BuildContext changes whenever the widget rebuilds, so the captured context points to an outdated element that may no longer exist in the tree. {v8}',
    correctionMessage:
        'Initialize context-dependent values in didChangeDependencies() (which runs after every dependency change) or directly in build(). '
        'For one-time initialization, use addPostFrameCallback in initState to safely access context after the first frame is rendered.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Only check late fields
      if (!node.fields.isLate) return;

      // Check if we're in a State class
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass != 'State') return;

      // Check each variable's initializer
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer != null && _usesContext(initializer)) {
          reporter.atNode(variable);
        }
      }
    });
  }

  bool _usesContext(Expression expr) {
    // Check for direct 'context' usage
    if (expr is SimpleIdentifier && expr.name == 'context') {
      return true;
    }

    // Check for method calls like Theme.of(context)
    if (expr is MethodInvocation) {
      // Check arguments
      for (final Expression arg in expr.argumentList.arguments) {
        if (_usesContext(arg)) return true;
      }
      // Check target
      final Expression? target = expr.target;
      if (target != null && _usesContext(target)) return true;
    }

    // Check property access
    if (expr is PrefixedIdentifier) {
      if (_usesContext(expr.prefix)) return true;
    }

    if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target != null && _usesContext(target)) return true;
    }

    return false;
  }
}

/// Warns when a widget has a "padding" parameter that is used as margin.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// This occurs when a widget accepts a `padding` parameter but uses it
/// to wrap the return value with a `Padding` widget or `.withPadding()` extension,
/// which is semantically margin behavior.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final EdgeInsets? padding;
///
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: padding ?? EdgeInsets.zero,
///       child: Container(),
///     );  // Using "padding" parameter as margin!
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final EdgeInsets? margin;  // Renamed to "margin"
///
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: margin ?? EdgeInsets.zero,
///       child: Container(),
///     );
///   }
/// }
/// ```
class AvoidMountedInSetStateRule extends SaropaLintRule {
  AvoidMountedInSetStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_mounted_in_setstate',
    '[avoid_mounted_in_setstate] Checking the mounted property inside a setState callback is an anti-pattern. If the widget is not mounted, setState should not be called at all. Placing the check inside the callback can lead to subtle bugs where partial state updates execute before the mounted check runs. {v5}',
    correctionMessage:
        'Always check if the widget is mounted before calling setState, not inside the callback. This ensures state updates are only triggered when the widget is in the tree, preventing runtime errors and unexpected behavior. See Flutter documentation on widget lifecycle and setState usage.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;

      // Check if the callback contains 'mounted' reference
      final _MountedVisitor visitor = _MountedVisitor();
      firstArg.accept(visitor);

      for (final SimpleIdentifier mountedRef in visitor.mountedReferences) {
        reporter.atNode(mountedRef);
      }
    });
  }
}

class _MountedVisitor extends RecursiveAstVisitor<void> {
  final List<SimpleIdentifier> mountedReferences = <SimpleIdentifier>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'mounted') {
      mountedReferences.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a method returns a Widget.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Methods that return widgets can cause unnecessary rebuilds. Consider
/// extracting to a separate widget class.
class AvoidStateConstructorsRule extends SaropaLintRule {
  AvoidStateConstructorsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_state_constructors',
    '[avoid_state_constructors] State class must not have a constructor body. Constructor logic runs before the framework initializes the State object, risking errors that bypass the widget lifecycle contract. {v4}',
    correctionMessage:
        'Use initState() for initialization instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Check constructors for bodies
      for (final ClassMember member in node.bodyMembers) {
        if (member is ConstructorDeclaration) {
          final FunctionBody body = member.body;
          if (body is BlockFunctionBody && body.block.statements.isNotEmpty) {
            reporter.atNode(member);
          }
        }
      }
    });
  }
}

/// Warns when a StatelessWidget has initialized fields.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final List<int> items = [];  // Initialized in StatelessWidget
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final List<int> items;
///   const MyWidget({required this.items});
/// }
/// ```
class AvoidStatelessWidgetInitializedFieldsRule extends SaropaLintRule {
  AvoidStatelessWidgetInitializedFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_stateless_widget_initialized_fields',
    '[avoid_stateless_widget_initialized_fields] StatelessWidget must not have initialized fields. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v4}',
    correctionMessage:
        'Pass values through the constructor instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget') return;

      // Check for initialized fields
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.initializer != null) {
              // Skip static fields
              if (member.isStatic) continue;
              reporter.atNode(variable);
            }
          }
        }
      }
    });
  }
}

/// Warns when setState is called directly in a lifecycle method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// In initState/didChangeDependencies, state assignments take effect before
/// the first build, so wrapping them in setState is unnecessary and misleading.
/// However, setState inside closures (stream listeners, Future callbacks) is
/// fine — those execute after the lifecycle method returns.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   setState(() { _value = 42; }); // unnecessary — assign directly
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _value = 42; // direct assignment before first build
///   _sub = stream.listen((_) {
///     if (mounted) setState(() {}); // deferred — runs after build
///   });
/// }
/// ```
class AvoidUnnecessarySetStateRule extends SaropaLintRule {
  AvoidUnnecessarySetStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_setstate',
    '[avoid_unnecessary_setstate] setState called in lifecycle method where not needed. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v6}',
    correctionMessage:
        'In initState/dispose, modify state directly without setState. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'dispose',
    'didChangeDependencies',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      if (!_lifecycleMethods.contains(methodName)) return;

      // Check if in a State class
      final ClassDeclaration? parent = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (parent == null) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.element?.name != 'State') return;

      // Find setState calls in this method
      node.body.visitChildren(
        _SetStateCallFinder((MethodInvocation setStateCall) {
          reporter.atNode(setStateCall);
        }),
      );
    });
  }
}

class _SetStateCallFinder extends RecursiveAstVisitor<void> {
  _SetStateCallFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }

  /// Stop recursion into closures — setState inside a callback (e.g. .listen,
  /// Future.delayed) runs after the lifecycle method, so it's not "unnecessary"
  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Intentionally do not call super — skip closure bodies
  }
}

// =============================================================================
// require_init_state_idempotent
// =============================================================================

/// Warns when initState registers listeners without matching remove in dispose.
///
/// initState may run multiple times (e.g. widget remount). Listeners must be
/// removed in dispose to avoid leaks and duplicate callbacks.
///
/// **BAD:**
/// ```dart
/// void initState() {
///   super.initState();
///   eventBus.addListener('auth', _onAuthChange);
/// }
/// void dispose() { super.dispose(); }
/// ```
///
/// **GOOD:**
/// ```dart
/// void initState() {
///   super.initState();
///   eventBus.addListener('auth', _onAuthChange);
/// }
/// void dispose() {
///   eventBus.removeListener('auth', _onAuthChange);
///   super.dispose();
/// }
/// ```
class RequireInitStateIdempotentRule extends SaropaLintRule {
  RequireInitStateIdempotentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => const <String>{
    'initState',
    'addListener',
    'addObserver',
  };

  static const LintCode _code = LintCode(
    'require_init_state_idempotent',
    '[require_init_state_idempotent] initState registers a listener without a matching removeListener/removeObserver in dispose. Widget remount or hot reload can cause duplicate listeners.',
    correctionMessage:
        'Add matching removeListener or removeObserver in dispose().',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _registerMethods = <String>{
    'addListener',
    'addObserver',
  };
  static const Set<String> _removeMethods = <String>{
    'removeListener',
    'removeObserver',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;
      // thisOrAncestorOfType: a method's direct parent is the class body, not
      // the ClassDeclaration. Gate on a resolved State subclass.
      final ClassDeclaration? parent = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (parent == null || !_isStateSubclass(parent)) return;

      final List<MethodInvocation> registerCalls = [];
      node.body.visitChildren(
        _ListenerCallCollector(registerCalls, _registerMethods),
      );

      if (registerCalls.isEmpty) return;

      MethodDeclaration? disposeMethod;
      for (final member in parent.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Detect removal as a real AST invocation of removeListener/removeObserver
      // rather than a substring of the dispose body source. A substring match
      // counted the word "removeListener" appearing inside a comment or string
      // literal (e.g. a log message) as a genuine removal, suppressing the
      // warning when no listener was actually removed.
      final List<MethodInvocation> removeCalls = [];
      disposeMethod?.body.visitChildren(
        _ListenerCallCollector(removeCalls, _removeMethods),
      );
      final bool hasRemove = removeCalls.isNotEmpty;

      if (!hasRemove) {
        for (final call in registerCalls) {
          reporter.atNode(call);
        }
      }
    });
  }
}

class _ListenerCallCollector extends RecursiveAstVisitor<void> {
  _ListenerCallCollector(this.calls, this.methodNames);
  final List<MethodInvocation> calls;
  final Set<String> methodNames;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (methodNames.contains(node.methodName.name)) {
      calls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a StatefulWidget could be a StatelessWidget.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// If a State class never calls setState and has no mutable state,
/// it should probably be a StatelessWidget.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
class AvoidUnnecessaryStatefulWidgetsRule extends SaropaLintRule {
  AvoidUnnecessaryStatefulWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_stateful_widgets',
    '[avoid_unnecessary_stateful_widgets] StatefulWidget may be unnecessary. If a State class never calls setState and has no mutable state, it should probably be a StatelessWidget. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v6}',
    correctionMessage:
        'Use StatelessWidget if no mutable state is needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.element?.name != 'State') return;

      // Check for setState calls
      bool hasSetState = false;
      bool hasMutableFields = false;

      for (final ClassMember member in node.bodyMembers) {
        // Check for non-final instance fields
        if (member is FieldDeclaration && !member.isStatic) {
          if (!member.fields.isFinal && !member.fields.isConst) {
            hasMutableFields = true;
          }
        }

        // Check for setState in any method
        if (member is MethodDeclaration) {
          member.body.visitChildren(
            _SetStatePresenceChecker((bool found) {
              if (found) hasSetState = true;
            }),
          );
        }
      }

      // If no setState and no mutable fields, probably unnecessary
      if (!hasSetState && !hasMutableFields) {
        reporter.atNode(node);
      }
    });
  }
}

class _SetStatePresenceChecker extends RecursiveAstVisitor<void> {
  _SetStatePresenceChecker(this.onResult);
  final void Function(bool) onResult;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onResult(true);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when anonymous functions are used in listener methods.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
class AvoidUnremovableCallbacksInListenersRule extends SaropaLintRule {
  AvoidUnremovableCallbacksInListenersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unremovable_callbacks_in_listeners',
    '[avoid_unremovable_callbacks_in_listeners] Anonymous function cannot be removed from listener. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v6}',
    correctionMessage:
        'Use a named function or store reference to remove later. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const List<String> _listenerMethods = <String>[
    'addListener',
    'addPostFrameCallback',
    'addPersistentFrameCallback',
    'addTimingsCallback',
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_listenerMethods.contains(node.methodName.name)) return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is FunctionExpression) {
        reporter.atNode(firstArg);
      }
    });
  }
}

/// Warns when `setState()` is called without a `mounted` check.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Calling `setState()` after a widget has been unmounted (e.g., after an
/// async operation completes) can cause errors. Always check `mounted` before
/// calling `setState()` in async contexts.
///
/// **Safe patterns (not reported):**
/// - `mounted ? setState(() { ... }) : null`
/// - `if (mounted) { setState(() { ... }); }`
/// - `if (!mounted) return; setState(...)`
/// - Inside a `_setStateSafe` wrapper method
///
/// Example of **bad** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() {  // BAD: widget may be unmounted
///     _data = data;
///   });
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     setState(() {
///       _data = data;
///     });
///   }
/// }
/// ```
class AvoidUnsafeSetStateRule extends SaropaLintRule {
  AvoidUnsafeSetStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unsafe_setstate',
    '[avoid_unsafe_setstate] setState() called without a mounted check. Calling setState() after a widget has been unmounted (e.g., after an async operation completes) can cause errors. Always check mounted before calling setState() in async contexts. {v6}',
    correctionMessage:
        'Wrap in `if (mounted)` or use `mounted ? setState(..) : null`. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') {
        return;
      }

      // Check if this setState is safe
      if (_isSafeSetState(node)) {
        return;
      }

      reporter.atNode(node);
    });
  }

  /// Check if this setState call is properly guarded
  bool _isSafeSetState(MethodInvocation node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Check for ternary: mounted ? setState(...) : ...
      if (current is ConditionalExpression) {
        if (_isMountedCheck(current.condition)) {
          return true;
        }
      }

      // Check for if statement: if (mounted) { setState(...) }
      // The guard only holds in the branch that executes when mounted is true.
      // For `if (mounted)` that is the THEN branch; for `if (!mounted)` it is
      // the ELSE branch. setState in the opposite branch runs when NOT mounted
      // (the opposite of guarded), so an `if (mounted)` ancestor must not be
      // treated as a guard unless the call sits in the mounted-true branch.
      if (current is IfStatement && _isMountedCheck(current.expression)) {
        final bool negated = _isNegatedMountedCheck(current.expression);
        final Statement guardedBranch = negated
            ? (current.elseStatement ?? current.thenStatement)
            : current.thenStatement;
        // When negated with no else, no branch is the mounted-true guard.
        final bool hasGuardedBranch = !negated || current.elseStatement != null;
        if (hasGuardedBranch && _containsNode(guardedBranch, node)) {
          return true;
        }
      }

      // Check for block with early return: if (!mounted) return;
      if (current is Block) {
        if (_hasEarlyMountedReturn(current, node)) {
          return true;
        }
      }

      // Check if we're inside a _setStateSafe method definition
      if (current is MethodDeclaration) {
        final String methodName = current.name.lexeme;
        if (methodName == '_setStateSafe' || methodName == 'setStateSafe') {
          return true;
        }
      }

      // Check if we're inside a call to _setStateSafe
      if (current is MethodInvocation) {
        final String methodName = current.methodName.name;
        if (methodName == '_setStateSafe' || methodName == 'setStateSafe') {
          return true;
        }
      }

      current = current.parent;
    }

    return false;
  }

  static final RegExp _mountedPattern = RegExp(r'\bmounted\b');

  /// Check if an expression is a mounted check
  bool _isMountedCheck(Expression condition) {
    final String condSource = condition.toSource();
    if (condSource == 'mounted') return true;
    if (_mountedPattern.hasMatch(condSource)) return true;
    return false;
  }

  /// True when [condition] is a NEGATED mounted check (`!mounted` or
  /// `mounted == false`), meaning the mounted-true guard lives in the ELSE
  /// branch of the enclosing `if`, not the then branch.
  bool _isNegatedMountedCheck(Expression condition) {
    // `!mounted` (and `!(mounted)`): a prefix `!` over a mounted expression.
    if (condition is PrefixExpression &&
        condition.operator.type == TokenType.BANG) {
      return _isMountedCheck(condition.operand);
    }
    // `mounted == false` / `false == mounted`.
    if (condition is BinaryExpression &&
        condition.operator.type == TokenType.EQ_EQ) {
      final String left = condition.leftOperand.toSource();
      final String right = condition.rightOperand.toSource();
      final bool mentionsMounted = left == 'mounted' || right == 'mounted';
      final bool mentionsFalse = left == 'false' || right == 'false';
      return mentionsMounted && mentionsFalse;
    }
    return false;
  }

  /// Check if a block has an early return guarded by !mounted before this node
  bool _hasEarlyMountedReturn(Block block, AstNode targetNode) {
    for (final Statement statement in block.statements) {
      // If we've reached the target node, stop looking
      if (_containsNode(statement, targetNode)) {
        break;
      }

      // Look for: if (!mounted) return;
      if (statement is IfStatement) {
        final String condition = statement.expression.toSource();
        if (condition == '!mounted' || condition == 'mounted == false') {
          final Statement thenStatement = statement.thenStatement;
          if (thenStatement is Block) {
            if (thenStatement.statements.isNotEmpty &&
                thenStatement.statements.first is ReturnStatement) {
              return true;
            }
          } else if (thenStatement is ReturnStatement) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Check if a node contains another node
  bool _containsNode(AstNode container, AstNode target) {
    if (container == target) {
      return true;
    }

    bool found = false;
    container.visitChildren(
      _NodeFinder(target, (bool result) {
        found = result;
      }),
    );

    return found;
  }
}

/// Helper visitor to find if a node exists within another node
class _NodeFinder extends GeneralizingAstVisitor<void> {
  _NodeFinder(this.target, this.onFound);

  final AstNode target;
  final void Function(bool) onFound;

  @override
  void visitNode(AstNode node) {
    if (node == target) {
      onFound(true);
      return;
    }
    super.visitNode(node);
  }
}

/// Warns when a widget that has its own padding property is wrapped in Padding.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(8),
///   child: Container(...),  // Container has padding property
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Container(
///   padding: EdgeInsets.all(8),
///   ...
/// )
/// ```
class RequireDisposeRule extends SaropaLintRule {
  RequireDisposeRule() : super(code: _code);

  /// Each occurrence is a serious issue that should be fixed immediately.
  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_field_dispose',
    '[require_field_dispose] Disposable field may not be properly disposed. {v3}',
    correctionMessage:
        'Add a dispose() method that disposes this field, '
        'or ensure the existing dispose() method handles it.',
    // SEV-01 (kept WARNING): parent-owned controllers are now skipped, but
    // disposal via an AutoDispose mixin (string-only detection) and the lexeme-
    // only `State` superclass check still risk false ERRORs.
    severity: DiagnosticSeverity.WARNING,
  );

  /// Map of disposable type names to their disposal method.
  /// NOTE: Timer and StreamSubscription are handled by RequireTimerCancellationRule.
  /// List of controller types that are managed by widgets/plugins and do NOT require manual disposal.
  /// These controllers either do not have a dispose() method, or their lifecycle is managed by the framework/plugin.
  /// See: https://pub.dev/documentation/webview_flutter/latest/webview_flutter/WebViewController-class.html
  /// See: https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMapController-class.html
  /// See: https://pub.dev/documentation/flutter_map/latest/flutter_map/MapController-class.html
  /// See: https://pub.dev/documentation/flutter_quill/latest/flutter_quill/QuillController-class.html
  /// See: https://pub.dev/packages/chewie (VideoPlayerController managed by Chewie)
  static const Set<String> _neverDisposeTypes = <String>{
    'WebViewController',
    'GoogleMapController',
    'MapController',
    'QuillController',
  };

  /// Map of controller types that require manual disposal when manually instantiated.
  /// If these are managed by a widget (e.g., DefaultTabController, ListView.builder, AnimatedWidget, TextFormField),
  /// disposal is handled automatically and should NOT be flagged.
  /// If manually instantiated in the State class, disposal IS required.
  static const Map<String, String> _disposableTypes = <String, String>{
    // Flutter Framework - Controllers (dispose)
    'TextEditingController': 'dispose',
    'AnimationController': 'dispose',
    'ScrollController': 'dispose',
    'TabController': 'dispose',
    'PageController': 'dispose',
    'TransformationController': 'dispose',
    'MaterialStatesController': 'dispose',
    'SearchController': 'dispose',
    'UndoHistoryController': 'dispose',
    'DraggableScrollableController': 'dispose',
    'MenuController': 'dispose',
    'OverlayPortalController': 'dispose',
    'RestorableTextEditingController': 'dispose',
    // Flutter Framework - Focus (dispose)
    'FocusNode': 'dispose',
    'FocusScopeNode': 'dispose',
    // Flutter Framework - Notifiers (dispose)
    'ChangeNotifier': 'dispose',
    'ValueNotifier': 'dispose',
    // Streams (close)
    'StreamController': 'close',
    // Common Packages (dispose)
    'CameraController': 'dispose',
    'VideoPlayerController': 'dispose',
    'AudioPlayer': 'dispose',
    // State Management (close)
    'Bloc': 'close',
    'Cubit': 'close',
    'ProviderSubscription': 'close',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      if (!_isStateClass(node)) {
        return;
      }

      // Find all disposable fields
      final List<_DisposableField> disposableFields = <_DisposableField>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final _DisposableField? field = _getDisposableField(member);
          if (field != null) {
            disposableFields.add(field);
          }
        }
      }

      if (disposableFields.isEmpty) {
        return;
      }

      // Find the dispose method and collect all method declarations so helper
      // bodies can be searched as real AST (not concatenated source text).
      MethodDeclaration? disposeMethod;
      final Map<String, MethodDeclaration> methodDecls =
          <String, MethodDeclaration>{};

      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          methodDecls[methodName] = member;
          if (methodName == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      // Check each disposable field
      for (final _DisposableField field in disposableFields) {
        if (disposeMethod == null) {
          // No dispose method at all
          reporter.atNode(field.declaration.fields, code);
        } else if (!_isFieldDisposedAst(field, disposeMethod, methodDecls)) {
          // Dispose method exists but doesn't dispose this field
          reporter.atNode(field.declaration.fields, code);
        }
      }
    });
  }

  /// AST-based disposal check. Walks the dispose method body (and any private
  /// helper methods it transitively calls) looking for the field being disposed
  /// as either a direct/null-aware/this-qualified invocation
  /// (`_x.dispose()`, `_x?.dispose()`, `this._x.dispose()`) or a TOP-LEVEL
  /// cascade section (`_x..dispose()`, `_x?..a()..dispose()`).
  ///
  /// Why AST instead of the prior whitespace-normalized regex: the regex
  /// cascade pattern `name\??(?:\.\.[^;]+)*\.\.method\(` let `[^;]+` swallow a
  /// nested expression, so a sibling field disposed INSIDE this field's cascade
  /// argument (`_a..addListener(_b..dispose())`) wrongly satisfied `_a`. A
  /// cascade section is a structural concept the AST models exactly, so this
  /// cannot cross into another field's disposal.
  static bool _isFieldDisposedAst(
    _DisposableField field,
    MethodDeclaration disposeMethod,
    Map<String, MethodDeclaration> methodDecls,
  ) {
    final visitor = _FieldDisposalVisitor(
      fieldName: field.name,
      disposeMethod: field.disposeMethod,
      methodDecls: methodDecls,
    );
    disposeMethod.body.accept(visitor);
    return visitor.disposed;
  }

  /// Check if a class extends `State<T>` (resolved-element aware).
  bool _isStateClass(ClassDeclaration node) => _isStateSubclass(node);

  /// Extract disposable field info from a field declaration
  /// Determines if a field is a disposable controller that requires manual disposal.
  /// Returns null if the field should NOT be flagged (either managed by widget/plugin, or not disposable).
  ///
  /// Logic:
  /// - If the type is in _neverDisposeTypes, skip (never requires disposal).
  /// - If the type is in _disposableTypes, require disposal ONLY if manually instantiated in State class.
  ///   (This rule assumes manual instantiation if the field is declared in the State class.)
  /// - Otherwise, skip.
  ///
  /// Edge cases:
  /// - If a controller is managed by a widget (e.g., DefaultTabController, ListView.builder, AnimatedWidget, TextFormField),
  ///   do NOT flag for disposal. This rule cannot always detect widget-managed controllers, so it errs on the side of not flagging
  ///   if the type is not manually instantiated.
  /// - If a plugin introduces a new controller type, update _neverDisposeTypes as needed.
  ///
  /// References:
  /// - https://pub.dev/documentation/webview_flutter/latest/webview_flutter/WebViewController-class.html
  /// - https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMapController-class.html
  /// - https://pub.dev/documentation/flutter_map/latest/flutter_map/MapController-class.html
  /// - https://pub.dev/documentation/flutter_quill/latest/flutter_quill/QuillController-class.html
  /// - https://pub.dev/packages/chewie
  _DisposableField? _getDisposableField(FieldDeclaration node) {
    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return null;
    }

    String typeName = '';
    if (type is NamedType) {
      typeName = type.name.lexeme;
    }

    // Skip controller types that never require manual disposal
    if (_neverDisposeTypes.contains(typeName)) {
      return null;
    }

    // Only require disposal for known disposable types
    if (!_disposableTypes.containsKey(typeName)) {
      return null;
    }

    // Get the field name
    if (node.fields.variables.isEmpty) {
      return null;
    }

    // Ownership transfer: a field whose initializer reads from `widget.*` (or
    // any other field/parameter) is owned by the parent that constructed it.
    // The Flutter contract is that whoever creates a controller disposes it, so
    // a State that disposes a parent-supplied controller is the actual bug. At
    // ERROR severity, flagging "missing disposal" here would break correct code
    // and push the developer toward a double-dispose crash. Only fields the
    // State constructs itself need local disposal, so skip parent-derived ones.
    final Expression? initializer = node.fields.variables.first.initializer;
    if (initializer != null && _isParentOwnedInitializer(initializer)) {
      return null;
    }

    final String fieldName = node.fields.variables.first.name.lexeme;
    final String? disposeMethod = _disposableTypes[typeName];
    if (disposeMethod == null) return null;

    return _DisposableField(
      name: fieldName,
      typeName: typeName,
      disposeMethod: disposeMethod,
      declaration: node,
    );
  }

  /// True when [initializer] reads the controller from the enclosing widget
  /// (`widget.controller`), meaning the parent owns it and is responsible for
  /// disposal. Delegates to the shared [_isParentOwnedFieldInitializer].
  static bool _isParentOwnedInitializer(Expression initializer) =>
      _isParentOwnedFieldInitializer(initializer);
}

/// Walks a dispose method (and the private helper methods it transitively
/// calls) to determine whether a specific field is disposed. Operates on the
/// AST so a cascade section or invocation is matched structurally — a disposal
/// nested inside another field's cascade argument cannot satisfy this field.
class _FieldDisposalVisitor extends RecursiveAstVisitor<void> {
  _FieldDisposalVisitor({
    required this.fieldName,
    required this.disposeMethod,
    required this.methodDecls,
    Set<String>? visited,
  }) : _visited = visited ?? <String>{};

  final String fieldName;
  final String disposeMethod;
  final Map<String, MethodDeclaration> methodDecls;
  final Set<String> _visited;

  bool disposed = false;

  bool _matchesMethodName(String name) =>
      name == disposeMethod || name == '${disposeMethod}Safe';

  /// True when [target] refers to this field: a bare `_x`, or `this._x`.
  bool _isFieldTarget(Expression? target) {
    if (target is SimpleIdentifier) return target.name == fieldName;
    if (target is PropertyAccess &&
        target.target is ThisExpression &&
        target.propertyName.name == fieldName) {
      return true;
    }
    if (target is PrefixedIdentifier &&
        target.prefix.name == 'this' &&
        target.identifier.name == fieldName) {
      return true;
    }
    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Direct / null-aware / this-qualified call: `_x.dispose()`,
    // `_x?.dispose()`, `this._x.dispose()`.
    if (_matchesMethodName(node.methodName.name) &&
        _isFieldTarget(node.realTarget)) {
      disposed = true;
    }

    // Follow private helper calls (implicit-this or `this`) so disposal inside
    // a `_cleanup()` helper still counts. Recurse into the helper's body once.
    final Expression? target = node.target;
    if ((target == null || target is ThisExpression) &&
        node.methodName.name.startsWith('_') &&
        !_visited.contains(node.methodName.name)) {
      final MethodDeclaration? helper = methodDecls[node.methodName.name];
      if (helper != null) {
        _visited.add(node.methodName.name);
        helper.body.accept(this);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    // A cascade `_x..a()..dispose()` disposes `_x` only when the cascade TARGET
    // is this field AND one of its TOP-LEVEL sections invokes the dispose
    // method. Checking sections directly (not descendants) prevents a nested
    // `..dispose()` on a different field inside a section argument from
    // matching. The target may carry a null-aware marker (`_x?..dispose()`).
    if (_isFieldTarget(node.target)) {
      for (final Expression section in node.cascadeSections) {
        if (section is MethodInvocation &&
            _matchesMethodName(section.methodName.name)) {
          disposed = true;
          break;
        }
      }
    }
    super.visitCascadeExpression(node);
  }
}

/// Helper class to track disposable field information
class _DisposableField {
  const _DisposableField({
    required this.name,
    required this.typeName,
    required this.disposeMethod,
    required this.declaration,
  });

  final String name;
  final String typeName;
  final String disposeMethod;
  final FieldDeclaration declaration;
}

/// Requires Timer and StreamSubscription fields to be canceled in dispose().
///
/// Since: v1.1.17 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: require_timer_cancel
///
/// Timers and stream subscriptions that aren't canceled will continue running
/// after the widget is disposed, causing:
/// - Crashes if they call setState on a disposed widget
/// - Memory leaks from retained references
/// - Wasted CPU cycles
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       setState(() => _count++);  // 💥 Crashes after dispose!
///     });
///   }
///
///   @override
///   void dispose() {
///     // Missing: _timer?.cancel();
///     super.dispose();
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///
///   @override
///   void dispose() {
///     _timer?.cancel();
///     _timer = null;
///     super.dispose();
///   }
/// }
/// ```
class RequireTimerCancellationRule extends SaropaLintRule {
  RequireTimerCancellationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_timer_cancellation',
    '[require_timer_cancellation] Timer or StreamSubscription must be canceled in dispose(). Timers and stream subscriptions that aren\'t canceled will continue running after the widget is disposed, causing: - Crashes if they call setState on a disposed widget - Memory leaks from retained references - Wasted CPU cycles. {v5}',
    correctionMessage:
        'Add cancel() in dispose() to prevent crashes and memory leaks. Verify the change works correctly with existing tests and add coverage for the new behavior. '
        'Uncanceled timers continue firing after widget disposal.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Types that require cancel() to be called
  static const Map<String, String> _cancellableTypes = <String, String>{
    'Timer': 'cancel',
    'StreamSubscription': 'cancel',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes
      if (!_isStateClass(node)) {
        return;
      }

      // Find all cancellable fields
      final List<_CancellableField> cancellableFields = <_CancellableField>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final _CancellableField? field = _getCancellableField(member);
          if (field != null) {
            cancellableFields.add(field);
          }
        }
      }

      if (cancellableFields.isEmpty) {
        return;
      }

      // Collect all method bodies for helper method expansion
      MethodDeclaration? disposeMethod;
      final Map<String, String> methodBodies = <String, String>{};

      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          methodBodies[methodName] = member.body.toSource();
          if (methodName == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      // Expand dispose body to include helper methods
      String disposeBody = '';
      if (disposeMethod != null) {
        disposeBody = _expandMethodCalls(
          disposeMethod.body.toSource(),
          methodBodies,
        );
      }

      // Check each cancellable field
      for (final _CancellableField field in cancellableFields) {
        if (disposeMethod == null) {
          reporter.atNode(field.declaration.fields, code);
        } else if (!_isFieldCanceled(field, disposeBody)) {
          reporter.atNode(field.declaration.fields, code);
        }
      }
    });
  }

  /// Check if a class extends `State<T>` (resolved-element aware).
  bool _isStateClass(ClassDeclaration node) => _isStateSubclass(node);

  /// Extract cancellable field info from a field declaration
  _CancellableField? _getCancellableField(FieldDeclaration node) {
    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return null;
    }

    String typeName = '';
    if (type is NamedType) {
      typeName = type.name.lexeme;
    }

    if (!_cancellableTypes.containsKey(typeName)) {
      return null;
    }

    if (node.fields.variables.isEmpty) {
      return null;
    }

    final String fieldName = node.fields.variables.first.name.lexeme;

    return _CancellableField(
      name: fieldName,
      typeName: typeName,
      declaration: node,
    );
  }

  /// Expand helper method calls to include their implementations
  String _expandMethodCalls(
    String body,
    Map<String, String> methodBodies, {
    int depth = 0,
  }) {
    if (depth > 3) {
      return body;
    }

    final StringBuffer expanded = StringBuffer(body);

    for (final RegExpMatch match in _privateMethodCallPattern.allMatches(
      body,
    )) {
      final String methodName = '_${match.group(1)}';
      final String? methodBody = methodBodies[methodName];
      if (methodBody != null) {
        final String expandedMethodBody = _expandMethodCalls(
          methodBody,
          methodBodies,
          depth: depth + 1,
        );
        expanded.write(' $expandedMethodBody');
      }
    }

    return expanded.toString();
  }

  /// Check if a field is properly canceled
  bool _isFieldCanceled(_CancellableField field, String disposeBody) {
    final String name = field.name;

    // Common cancellation patterns (compiled once, not inside loop)
    final List<String> patterns = <String>[
      '$name.cancel(',
      '$name?.cancel(',
      '$name..cancel(',
      '$name.cancelSafe(',
      '$name?.cancelSafe(',
      '$name..cancelSafe(',
    ];
    final List<RegExp> compiledPatterns = patterns
        .map((p) => RegExp(RegExp.escape(p)))
        .toList();

    for (final RegExp re in compiledPatterns) {
      if (re.hasMatch(disposeBody)) {
        return true;
      }
    }

    return false;
  }
}

/// Helper class to track cancellable field information
class _CancellableField {
  const _CancellableField({
    required this.name,
    required this.typeName,
    required this.declaration,
  });

  final String name;
  final String typeName;
  final FieldDeclaration declaration;
}

/// Suggests nullifying nullable disposable fields after disposal.
///
/// Since: v1.1.17 | Updated: v4.13.0 | Rule version: v7
///
/// When a nullable disposable field (Timer?, StreamSubscription?, etc.) is
/// disposed/canceled, it's good practice to also set it to null. This:
/// - Helps garbage collection
/// - Prevents accidental reuse of disposed resources
/// - Makes it clear the resource has been cleaned up
///
/// Example of **bad** code:
/// ```dart
/// void _cancelTimer() {
///   _timer?.cancel();
///   // Missing: _timer = null;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void _cancelTimer() {
///   _timer?.cancel();
///   _timer = null;
/// }
/// ```
class NullifyAfterDisposeRule extends SaropaLintRule {
  NullifyAfterDisposeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'nullify_after_dispose',
    '[nullify_after_dispose] Nullable disposable field must be set to null after disposal. When a nullable disposable field (Timer?, StreamSubscription?, etc.) is disposed/canceled, it\'s good practice to also set it to null. This: - Helps garbage collection - Prevents accidental reuse of disposed resources - Makes it clear the resource has been cleaned up. {v8}',
    correctionMessage:
        'Add `fieldName = null;` after disposing to help garbage collection. Verify the change works correctly with existing tests and add coverage for the new behavior. '
        'and prevent accidental reuse.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Map of disposable type names to their disposal method
  static const Map<String, String> _disposableTypes = <String, String>{
    'Timer': 'cancel',
    'StreamSubscription': 'cancel',
    'StreamController': 'close',
    'AnimationController': 'dispose',
    'TextEditingController': 'dispose',
    'ScrollController': 'dispose',
    'TabController': 'dispose',
    'PageController': 'dispose',
    'FocusNode': 'dispose',
    'ChangeNotifier': 'dispose',
    'ValueNotifier': 'dispose',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if this is a disposal method call
      final String? disposedType = _getDisposedType(methodName);
      if (disposedType == null) {
        return;
      }

      // Get the target (e.g., _timer in _timer?.cancel())
      final Expression? target = node.realTarget;
      if (target is! SimpleIdentifier) {
        return;
      }

      final String fieldName = target.name;

      // This rule only applies to nullable INSTANCE FIELDS. A SimpleIdentifier
      // target can equally be a local variable or parameter (e.g. a method-local
      // `final ui.Codec codec` calling `codec.dispose()`). Locals die at scope
      // exit and need no nullification — a `final` local cannot even be nulled —
      // so resolve the name against the enclosing class's declared fields and
      // bail when it is not one. Without this guard a local was treated as a
      // non-final nullable field and falsely flagged (false-positive class:
      // nullify_after_dispose on local disposables).
      final ClassDeclaration? classNode = _findContainingClass(node);
      if (classNode == null) {
        return;
      }
      final FieldDeclaration? field = _findField(classNode, fieldName);
      if (field == null) {
        // Target is a local variable or parameter, not a class field.
        return;
      }

      // Skip if field is final or non-nullable (can't be set to null)
      if (_isFieldFinalOrNonNullable(field)) {
        return;
      }

      // Ensure this is a direct expression statement
      final AstNode? parent = node.parent;
      if (parent is! ExpressionStatement) {
        return;
      }

      // Find the containing block to check for nullification
      final Block? containingBlock = _findContainingBlock(node);
      if (containingBlock == null) {
        return;
      }

      // Check if the field is nullified after this statement
      if (_isNullifiedAfter(containingBlock, parent, fieldName)) {
        return;
      }

      // Skip if the field is reassigned after cancel (debounce/reset pattern)
      if (_isReassignedAfter(containingBlock, parent, fieldName)) {
        return;
      }

      // Report the issue
      reporter.atNode(node);
    });
  }

  /// Get the type being disposed based on the method name
  String? _getDisposedType(String methodName) {
    // Check both regular and Safe versions
    final String baseMethod = methodName.endsWith('Safe')
        ? methodName.replaceAll('Safe', '')
        : methodName;

    for (final MapEntry<String, String> entry in _disposableTypes.entries) {
      if (entry.value == baseMethod) {
        return entry.key;
      }
    }
    return null;
  }

  /// Find the containing block statement
  Block? _findContainingBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Find the containing class declaration
  ClassDeclaration? _findContainingClass(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Find the field declaration named [fieldName] on [classNode], or null when
  /// the class declares no such field. A null result means the disposal target
  /// is a local variable or parameter rather than an instance field, so the
  /// rule must not report on it.
  FieldDeclaration? _findField(ClassDeclaration classNode, String fieldName) {
    for (final ClassMember member in classNode.bodyMembers) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          if (variable.name.lexeme == fieldName) {
            return member;
          }
        }
      }
    }
    return null;
  }

  /// Check if a field is final or has a non-nullable type. Either case means it
  /// can't be set to null, so the "nullify after dispose" advice does not apply.
  bool _isFieldFinalOrNonNullable(FieldDeclaration field) {
    // Final fields can't be reassigned.
    if (field.fields.isFinal) {
      return true;
    }
    // Non-nullable types can't be set to null.
    final TypeAnnotation? type = field.fields.type;
    return type is NamedType && type.question == null;
  }

  /// Check if the field is set to null after the given statement
  bool _isNullifiedAfter(
    Block block,
    ExpressionStatement disposeStatement,
    String fieldName,
  ) {
    bool foundDisposeStatement = false;

    for (final Statement statement in block.statements) {
      if (statement == disposeStatement) {
        foundDisposeStatement = true;
        continue;
      }

      if (!foundDisposeStatement) {
        continue;
      }

      // Look for assignment to null: fieldName = null
      if (statement is ExpressionStatement) {
        final Expression expression = statement.expression;
        if (expression is AssignmentExpression) {
          final Expression leftSide = expression.leftHandSide;
          final Expression rightSide = expression.rightHandSide;

          if (leftSide is SimpleIdentifier &&
              leftSide.name == fieldName &&
              rightSide is NullLiteral) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if the field is reassigned after the given statement
  /// (e.g., debounce pattern: cancel then create new Timer)
  bool _isReassignedAfter(
    Block block,
    ExpressionStatement disposeStatement,
    String fieldName,
  ) {
    bool foundDisposeStatement = false;

    for (final Statement statement in block.statements) {
      if (statement == disposeStatement) {
        foundDisposeStatement = true;
        continue;
      }

      if (!foundDisposeStatement) {
        continue;
      }

      // Look for reassignment: fieldName = <something>
      if (statement is ExpressionStatement) {
        final Expression expression = statement.expression;
        if (expression is AssignmentExpression) {
          final Expression leftSide = expression.leftHandSide;

          if (leftSide is SimpleIdentifier &&
              leftSide.name == fieldName &&
              expression.rightHandSide is! NullLiteral) {
            return true;
          }
        }
      }
    }

    return false;
  }
}

/// Warns when setState is called after an async gap without mounted check.
///
/// Since: v2.3.5 | Updated: v4.13.0 | Rule version: v9
///
/// **Quick fix available:** Wraps the setState call in `if (mounted) { ... }`.
///
/// Example of **bad** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() { _data = data; });  // May call on unmounted widget
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     setState(() { _data = data; });
///   }
/// }
/// ```
class UseSetStateSynchronouslyRule extends SaropaLintRule {
  UseSetStateSynchronouslyRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'use_setstate_synchronously',
    '[use_setstate_synchronously] setState called after async gap without mounted check. Quick fix available: Wraps the setState call in if (mounted) { .. }. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v11}',
    correctionMessage:
        'Check mounted before calling setState after await. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final body = node.body;
      // Only check async methods with block body
      if (body is! BlockFunctionBody) return;
      if (!body.isAsynchronous) return;

      // Walk the body in source order — previously we iterated only top-level
      // statements which collapsed compound statements (try/if/for/switch) into
      // a single iteration. That made every setState inside a try block look
      // post-await whenever ANY descendant await existed, even ones lexically
      // BEFORE the await. See bugs/use_setstate_synchronously_false_positive_setstate_before_await_inside_try.md.
      body.accept(_OrderedSetStateScanner(reporter));
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        WrapSetStateInMountedCheckFix(context: context),
  ];
}

// Note: _SetStateWithMountedCheckFinder and _AwaitFinder removed.
// Now using shared utilities from async_context_utils.dart:
// - SetStateWithMountedCheckFinder
// - AwaitFinder
// - containsAwait(), isNegatedMountedGuard(), checksMounted(), etc.

/// Visitor for `use_setstate_synchronously` that walks the function body in
/// strict source order so the rule can tell which `setState` calls are
/// lexically BEFORE the first `await` and which are AFTER.
///
/// The previous implementation iterated only the function body's top-level
/// statements. When the body was a single compound statement (`try { ... }`
/// being the common shape in this codebase, since every method is wrapped in
/// mandatory error handling), it could not distinguish a `setState` lexically
/// before the inner `await` from one after — both were reported.
///
/// State tracked while walking:
/// - `_seenAwait`: monotonically true once any `AwaitExpression` is visited.
/// - `_guardStack`: parallel to the lexical Block stack. Each entry records
///   whether a `if (!mounted) return;` early-exit guard has fired at the
///   top level of that Block AFTER the most recent await. Any await resets
///   every entry (the new async gap invalidates prior guards).
///
/// A `setState(...)` is reported only when ALL of:
/// - `_seenAwait` is true (lexically after at least one await), AND
/// - no Block on the stack has an active post-await guard, AND
/// - the call has no inline `if (mounted)` ancestor (`hasAncestorMountedCheck`).
///
/// Nested function expressions are skipped — they have their own async scope.
class _OrderedSetStateScanner extends RecursiveAstVisitor<void> {
  _OrderedSetStateScanner(this._reporter);

  final SaropaDiagnosticReporter _reporter;

  bool _seenAwait = false;

  /// Per-Block guard tracking. Index N corresponds to the Nth enclosing Block
  /// currently being walked. Push on enter, pop on exit. A guard set inside a
  /// nested Block does NOT protect setState in an outer Block.
  final List<bool> _guardStack = <bool>[];

  bool get _isGuarded {
    for (int i = 0; i < _guardStack.length; i++) {
      if (_guardStack[i]) return true;
    }
    return false;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested function expressions / closures — they have their own async
    // scope. The await/guard state of the enclosing function does not apply.
  }

  @override
  void visitBlock(Block node) {
    _guardStack.add(false);
    try {
      for (final Statement stmt in node.statements) {
        // Recognize `if (!mounted) return;` only at the TOP level of a Block
        // (not nested inside `if (cond) { if (!mounted) return; }`, where the
        // guard does not actually control the path to subsequent siblings).
        if (_seenAwait && isNegatedMountedGuard(stmt)) {
          _guardStack[_guardStack.length - 1] = true;
          // Walk the children defensively — the then-branch is just `return;`
          // or `throw ...;` per `containsEarlyExit`, but a future relaxation
          // of that helper might allow more, and we still want to find any
          // setState/await inside.
          stmt.visitChildren(this);
          continue;
        }
        stmt.accept(this);
      }
    } finally {
      _guardStack.removeLast();
    }
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _seenAwait = true;
    // A new async gap invalidates every prior guard at every enclosing scope —
    // mounted may have flipped to false during the new await.
    for (int i = 0; i < _guardStack.length; i++) {
      _guardStack[i] = false;
    }
    super.visitAwaitExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      // Only report if we are past the first await AND no early-exit guard
      // is active AND this call has no inline `if (mounted)` ancestor.
      // `hasAncestorMountedCheck` covers patterns like:
      //   if (mounted) setState(...);
      //   if (mounted) { setState(...); }
      //   if (mounted && cond) { setState(...); }
      if (_seenAwait && !_isGuarded && !hasAncestorMountedCheck(node)) {
        _reporter.atNode(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a listener is added but never removed.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Listeners that are not removed can cause memory leaks and unexpected
/// behavior after the widget is disposed.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   controller.addListener(_onChanged);  // Never removed!
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   controller.addListener(_onChanged);
/// }
///
/// @override
/// void dispose() {
///   controller.removeListener(_onChanged);
///   super.dispose();
/// }
/// ```
class AlwaysRemoveListenerRule extends SaropaLintRule {
  AlwaysRemoveListenerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'always_remove_listener',
    '[always_remove_listener] Listener added via addListener() but no matching removeListener() call found in dispose(). Orphaned listeners retain references to the widget, preventing garbage collection and causing memory leaks that accumulate as users navigate between screens. {v3}',
    correctionMessage:
        'Call removeListener() in the dispose() method for every addListener() call to release references and prevent memory leaks.',
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

      final NamedType superclass = extendsClause.superclass;
      final String? superName = superclass.element?.name;
      if (superName != 'State') return;

      // Find initState and dispose methods
      MethodDeclaration? initStateMethod;
      MethodDeclaration? disposeMethod;

      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          final String name = member.name.lexeme;
          if (name == 'initState') {
            initStateMethod = member;
          } else if (name == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      if (initStateMethod == null) return;

      // Find all addListener calls in initState
      final List<_ListenerInfo> addedListeners = <_ListenerInfo>[];
      final FunctionBody initBody = initStateMethod.body;
      initBody.visitChildren(
        _AddListenerFinder((String target, String callback, AstNode srcNode) {
          addedListeners.add(_ListenerInfo(target, callback, srcNode));
        }),
      );

      if (addedListeners.isEmpty) return;

      // Find all removeListener calls in dispose
      final List<_ListenerInfo> removedListeners = <_ListenerInfo>[];
      final FunctionBody? disposeBody = disposeMethod?.body;
      if (disposeBody != null) {
        disposeBody.visitChildren(
          _RemoveListenerFinder((String target, String callback) {
            removedListeners.add(_ListenerInfo(target, callback, null));
          }),
        );
      }

      // Check if each added listener has a corresponding remove
      for (final _ListenerInfo added in addedListeners) {
        final bool hasRemove = removedListeners.any(
          (_ListenerInfo removed) =>
              removed.target == added.target &&
              removed.callback == added.callback,
        );
        if (!hasRemove && added.node != null) {
          reporter.atNode(added.node!, code);
        }
      }
    });
  }

  /// Exposed for unit tests: the receiver/callback normalization that lets the
  /// idiomatic `field!.addListener` / `field?.removeListener` pairing match.
  @visibleForTesting
  static String normalizeListenerTokenForTesting(String raw) =>
      _normalizeListenerToken(raw);
}

/// Strip a single trailing null-aware / null-assertion operator so the SAME
/// listenable or callback reached via `x!` (add, where it is known to be set in
/// initState) and `x?` (remove, where the field may be gone in dispose)
/// compares equal. Without this, `field!.addListener(cb)` in initState and
/// `field?.removeListener(cb)` in dispose have unequal receiver source text
/// (`field!` vs `field?`) and the listener is read as never removed — a false
/// positive on a dispose that DOES remove the listener.
String _normalizeListenerToken(String raw) {
  if (raw.isEmpty) return raw;
  final String last = raw.substring(raw.length - 1);
  return (last == '!' || last == '?') ? raw.substring(0, raw.length - 1) : raw;
}

class _ListenerInfo {
  _ListenerInfo(this.target, this.callback, this.node);
  final String target;
  final String callback;
  final AstNode? node;
}

class _AddListenerFinder extends RecursiveAstVisitor<void> {
  _AddListenerFinder(this.onFound);
  final void Function(String target, String callback, AstNode node) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addListener') {
      final String target = _normalizeListenerToken(
        node.realTarget?.toSource() ?? '',
      );
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = _normalizeListenerToken(args.first.toSource());
        onFound(target, callback, node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _RemoveListenerFinder extends RecursiveAstVisitor<void> {
  _RemoveListenerFinder(this.onFound);
  final void Function(String target, String callback) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'removeListener') {
      final String target = _normalizeListenerToken(
        node.realTarget?.toSource() ?? '',
      );
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = _normalizeListenerToken(args.first.toSource());
        onFound(target, callback);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Border.all is used instead of const Border.fromBorderSide.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// `Border.all` cannot be const, but `Border.fromBorderSide` can be.
///
/// Example of **bad** code:
/// ```dart
/// Border.all(color: Colors.red, width: 2)
/// ```
///
/// Example of **good** code:
/// ```dart
/// const Border.fromBorderSide(BorderSide(color: Colors.red, width: 2))
/// ```
class RequireAnimationDisposalRule extends SaropaLintRule {
  RequireAnimationDisposalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_animation_disposal',
    '[require_animation_disposal] Failing to dispose an AnimationController in the dispose() method causes it to retain resources, listeners, and animation frames, resulting in memory leaks and degraded performance. This is especially problematic in widgets that are frequently created and destroyed, such as in lists or navigation stacks, and can lead to app instability or crashes. Dispose every AnimationController to keep Flutter apps robust. {v7}',
    correctionMessage:
        "Call _controller.dispose() in your widget's dispose() method before calling super.dispose(). This releases all resources and prevents memory leaks. Audit your codebase for all AnimationController instances and verify each one is disposed.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes - StatelessWidgets receive controllers
      // as parameters and don't own them (parent disposes)
      if (!_isStateClass(node)) {
        return;
      }

      // Find AnimationController fields
      final Set<String> animationControllerFields = <String>{};

      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'AnimationController') {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              animationControllerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (animationControllerFields.isEmpty) return;

      // Check if dispose method exists and disposes all controllers
      bool hasDisposeMethod = false;
      final Set<String> disposedFields = <String>{};

      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDisposeMethod = true;
          member.body.accept(
            _DisposeCallFinder((String fieldName) {
              disposedFields.add(fieldName);
            }),
          );
        }
      }

      // Report undisposed animation controllers
      for (final String fieldName in animationControllerFields) {
        if (!hasDisposeMethod || !disposedFields.contains(fieldName)) {
          // Report at the field declaration
          for (final ClassMember member in node.bodyMembers) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
      }
    });
  }

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'State';
  }
}

class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.onFound);
  final void Function(String) onFound;

  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_disposeMethodNames.contains(node.methodName.name)) {
      final Expression? target = node.realTarget;
      if (target is SimpleIdentifier) {
        onFound(target.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Future rule: avoid-uncontrolled-text-field
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v8
///
/// Warns when TextField is used without a controller.
///
/// Example of **bad** code:
/// ```dart
/// TextField(
///   onChanged: (value) { },
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextField(
///   controller: _textController,
///   onChanged: (value) { },
/// )
/// ```
class AvoidScaffoldMessengerAfterAwaitRule extends SaropaLintRule {
  AvoidScaffoldMessengerAfterAwaitRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_scaffold_messenger_after_await',
    '[avoid_scaffold_messenger_after_await] Using ScaffoldMessenger.of(context) after await may use an invalid context. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v8}',
    correctionMessage:
        'Store ScaffoldMessenger.of(context) before the await. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlockFunctionBody((BlockFunctionBody node) {
      // Check if function is async
      if (node.keyword?.keyword != Keyword.ASYNC) return;

      // Walk the body in strict source order so a ScaffoldMessenger.of(context)
      // use lexically BEFORE the await is not reported as "after". The previous
      // per-statement scan set hasAwait for the whole statement (e.g. a try
      // block) and then flagged every ScaffoldMessenger use inside it, even
      // ones before the inner await. Mirrors the source-order fix applied to
      // use_setstate_synchronously (_OrderedSetStateScanner).
      node.accept(_OrderedScaffoldMessengerScanner(reporter));
    });
  }
}

/// Walks an async function body in source order, reporting
/// `ScaffoldMessenger.of(...)` calls only once an `await` has been seen
/// lexically before them. Nested function expressions have their own async
/// scope and are skipped.
class _OrderedScaffoldMessengerScanner extends RecursiveAstVisitor<void> {
  _OrderedScaffoldMessengerScanner(this._reporter);

  final SaropaDiagnosticReporter _reporter;
  bool _seenAwait = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip closures — their await state is independent of the outer function.
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    super.visitAwaitExpression(node);
    // Set AFTER visiting children so an awaited expression that itself contains
    // a ScaffoldMessenger.of (e.g. `await foo(ScaffoldMessenger.of(c))`) is
    // evaluated before the await completes and is therefore not "after".
    _seenAwait = true;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (!_seenAwait) return;
    final Expression? target = node.target;
    if (target is SimpleIdentifier &&
        target.name == 'ScaffoldMessenger' &&
        node.methodName.name == 'of') {
      _reporter.atNode(node);
    }
  }
}

/// Future rule: avoid-build-context-in-providers
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when BuildContext is stored in providers or state managers.
///
/// Example of **bad** code:
/// ```dart
/// class MyProvider extends ChangeNotifier {
///   late BuildContext _context;
///   void setContext(BuildContext context) => _context = context;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Use callbacks or pass context only when needed
/// class MyProvider extends ChangeNotifier {
///   void showMessage(BuildContext context, String msg) {...}
/// }
/// ```
class AvoidBuildContextInProvidersRule extends SaropaLintRule {
  AvoidBuildContextInProvidersRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_build_context_in_providers',
    '[avoid_build_context_in_providers] Storing BuildContext in providers can cause memory leaks. BuildContext is stored in providers or state managers. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v6}',
    correctionMessage:
        'Pass BuildContext as a method parameter when needed instead. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class is a provider (extends ChangeNotifier, etc.)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (!_isProviderClass(superclass)) return;

      // Check for BuildContext fields
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final TypeAnnotation? type = member.fields.type;
            if (type is NamedType && type.name.lexeme == 'BuildContext') {
              reporter.atToken(field.name, code);
            }
          }
        }
      }
    });
  }

  bool _isProviderClass(String name) {
    return name == 'ChangeNotifier' ||
        name == 'ValueNotifier' ||
        name == 'StateNotifier' ||
        name == 'Notifier' ||
        name == 'AsyncNotifier' ||
        name.endsWith('Provider') ||
        name.endsWith('Notifier');
  }
}

/// Future rule: prefer-semantic-widget-names
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Warns when widgets use generic names like Container instead of semantic alternatives.
///
/// Example of **bad** code:
/// ```dart
/// Container(
///   decoration: BoxDecoration(color: Colors.red),
///   child: child,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// DecoratedBox(
///   decoration: BoxDecoration(color: Colors.red),
///   child: child,
/// )
/// ```
class PreferWidgetStateMixinRule extends SaropaLintRule {
  PreferWidgetStateMixinRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_widget_state_mixin',
    '[prefer_widget_state_mixin] Use WidgetStateMixin for interaction states. Widgets use generic names like Container instead of semantic alternatives. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v5}',
    correctionMessage:
        'Use WidgetStateMixin to manage hover, pressed, and focus states. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass != 'State') return;

      // Check if already using WidgetStateMixin
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          if (mixin.name.lexeme.contains('WidgetStateMixin')) {
            return;
          }
        }
      }

      // Check for manual interaction-state tracking fields.
      int stateFields = 0;
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          // Only boolean fields model an interaction state (hovered/pressed/
          // focused). Restricting to bool avoids matching unrelated members
          // like `_unfocusTimer` or `_focusableItems` that merely contain the
          // substring "focus".
          if (!_isBoolField(member)) continue;
          for (final VariableDeclaration field in member.fields.variables) {
            if (_isInteractionStateName(field.name.lexeme)) {
              stateFields++;
            }
          }
        }
      }

      if (stateFields >= 2) {
        reporter.atToken(node.nameToken, code);
      }
    });
  }

  /// Interaction-state terms that, as whole tokens, indicate a hover/pressed/
  /// focused boolean state field. Whole-token matching (not substring) avoids
  /// `_unfocusTimer` / `_focusableItems` false positives.
  static const Set<String> _interactionStateTerms = <String>{
    'hover',
    'hovered',
    'hovering',
    'press',
    'pressed',
    'pressing',
    'focus',
    'focused',
    'focusing',
  };

  /// True when the field declares a boolean type (`bool`/`bool?`). A nullable
  /// or non-bool field does not model a simple interaction flag.
  static bool _isBoolField(FieldDeclaration member) {
    final TypeAnnotation? type = member.fields.type;
    if (type is NamedType) return type.name.lexeme == 'bool';
    // Untyped (inferred). Treat `_isHovered = false`-style as bool when the
    // initializer is a boolean literal; otherwise it is not a bool flag.
    for (final VariableDeclaration v in member.fields.variables) {
      if (v.initializer is BooleanLiteral) return true;
    }
    return false;
  }

  /// True when [name] contains an interaction-state term as a WHOLE word.
  /// Splits the identifier on `_` and camelCase boundaries and checks each
  /// segment, so `_isHovered` matches (`hovered`) but `_unfocusTimer` does not
  /// (`unfocus`, `timer` — neither is an interaction-state term).
  static bool _isInteractionStateName(String name) {
    for (final String segment in _identifierSegments(name)) {
      if (_interactionStateTerms.contains(segment)) return true;
    }
    return false;
  }

  /// Lowercased word segments of an identifier, split on underscores and
  /// camelCase boundaries (e.g. `_isHovered` -> {is, hovered}).
  static Iterable<String> _identifierSegments(String name) {
    return name
        .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase()
        .split('_')
        .where((s) => s.isNotEmpty);
  }
}

/// Future rule: avoid-image-without-cache-headers
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when Image.network is used without cacheWidth/cacheHeight.
///
/// Example of **bad** code:
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   cacheWidth: 200,
///   cacheHeight: 200,
/// )
/// ```
class AvoidInheritedWidgetInInitStateRule extends SaropaLintRule {
  AvoidInheritedWidgetInInitStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_inherited_widget_in_initstate',
    '[avoid_inherited_widget_in_initstate] InheritedWidget accessed in initState(), where the widget is not yet fully mounted in the element tree. This call returns stale or missing data and does not subscribe to updates, so the widget never rebuilds when the inherited value changes. {v4}',
    correctionMessage:
        'Move the InheritedWidget lookup to didChangeDependencies(), which runs after initState and re-runs whenever dependencies change.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _inheritedWidgetMethods = <String>{
    'of',
    'maybeOf',
    'dependOnInheritedWidgetOfExactType',
  };

  static const Set<String> _commonInheritedWidgets = <String>{
    'Theme',
    'MediaQuery',
    'Navigator',
    'Scaffold',
    'DefaultTextStyle',
    'Localizations',
    'Provider',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Only a real State.initState carries the unmounted-element-tree hazard.
      // A method named initState on a plain class is not a lifecycle override.
      final ClassDeclaration? enclosing = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (enclosing == null || !_isStateSubclass(enclosing)) return;

      // Visit the method body to find inherited widget access
      node.body.accept(_InheritedWidgetVisitor(reporter, code));
    });
  }
}

class _InheritedWidgetVisitor extends RecursiveAstVisitor<void> {
  _InheritedWidgetVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final String methodName = node.methodName.name;
    if (!AvoidInheritedWidgetInInitStateRule._inheritedWidgetMethods.contains(
      methodName,
    )) {
      return;
    }

    // Check if target is a common inherited widget
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      if (AvoidInheritedWidgetInInitStateRule._commonInheritedWidgets.contains(
        target.name,
      )) {
        reporter.atNode(node);
      }
    }
  }
}

/// Warns when a widget references itself in its build method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MyWidget(); // Infinite recursion
///   }
/// }
/// ```
class AvoidRecursiveWidgetCallsRule extends SaropaLintRule {
  AvoidRecursiveWidgetCallsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_recursive_widget_calls',
    '[avoid_recursive_widget_calls] Widget build method creates a new instance of itself, triggering infinite recursion. This crashes the app with a stack overflow as Flutter repeatedly builds the same widget, consuming all available stack frames within milliseconds. {v6}',
    correctionMessage:
        'Extract the repeated content into a separate widget class, or add a depth-limiting condition to terminate the recursion.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.nameToken.lexeme;

      // Check if it's a widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget' &&
          superclassName != 'StatefulWidget') {
        return;
      }

      // Resolve the enclosing class element so self-instantiation is matched by
      // element identity, not by simple-name lexeme. A different widget that
      // merely shares the same simple name (e.g. an imported `Card` distinct
      // from a local `Card`) resolves to a different element and is no longer
      // false-flagged as infinite recursion.
      final Element? classElement = node.declaredFragment?.element;

      // Find build method
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          // Check for self-instantiation in build
          member.body.accept(
            _RecursiveWidgetVisitor(className, classElement, reporter, code),
          );
        }
      }
    });
  }
}

class _RecursiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _RecursiveWidgetVisitor(
    this.className,
    this.classElement,
    this.reporter,
    this.code,
  );

  final String className;
  final Element? classElement;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final Element? createdElement = node.constructorName.type.element;
    // Prefer element identity; only compare names when the enclosing class or
    // the created type does not resolve (e.g. no Flutter SDK in context), where
    // a lexeme match is the best available signal.
    if (classElement != null && createdElement != null) {
      if (identical(createdElement, classElement)) {
        reporter.atNode(node);
      }
      return;
    }
    if (node.constructorName.type.name.lexeme == className) {
      reporter.atNode(node);
    }
  }
}

/// Warns when disposable instances are created but not disposed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   _MyWidgetState createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> {
///   late final controller = TextEditingController(); // Not disposed
/// }
/// ```
class AvoidUndisposedInstancesRule extends SaropaLintRule {
  AvoidUndisposedInstancesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_undisposed_instances',
    '[avoid_undisposed_instances] Disposable object (e.g., TextEditingController, AnimationController, StreamController) created but no matching dispose() call found. Undisposed instances retain listeners, streams, and platform resources, causing memory leaks that grow with each widget rebuild or navigation. {v7}',
    correctionMessage:
        'Call dispose() on the instance inside the State.dispose() method before calling super.dispose() to release all held resources.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'StreamController',
    'StreamSubscription',
    'Timer',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Find disposable fields
      final Set<String> disposableFields = <String>{};
      final Set<String> disposedFields = <String>{};

      // Collect all method bodies for helper method analysis
      final Map<String, FunctionBody?> methodBodies = <String, FunctionBody?>{};

      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String fieldName = variable.name.lexeme;
            final Expression? initializer = variable.initializer;

            // Check if field is a disposable type
            if (initializer is InstanceCreationExpression) {
              final String typeName =
                  initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(typeName)) {
                disposableFields.add(fieldName);
              }
            }

            // Check type annotation (handles nullable types like Timer?)
            final TypeAnnotation? typeAnnotation = member.fields.type;
            if (typeAnnotation is NamedType) {
              if (_disposableTypes.contains(typeAnnotation.name.lexeme)) {
                disposableFields.add(fieldName);
              }
            }
          }
        }

        // Collect all method bodies
        if (member is MethodDeclaration) {
          methodBodies[member.name.lexeme] = member.body;
        }
      }

      // Find dispose method and track what's disposed (including helper methods)
      final FunctionBody? disposeBody = methodBodies['dispose'];
      if (disposeBody != null) {
        final _DisposeVisitor visitor = _DisposeVisitor(
          disposedFields: disposedFields,
          methodBodies: methodBodies,
        );
        disposeBody.accept(visitor);
      }

      // Report undisposed fields
      for (final String fieldName in disposableFields) {
        if (!disposedFields.contains(fieldName)) {
          // Find the field declaration to report on
          for (final ClassMember member in node.bodyMembers) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
      }
    });
  }
}

class _DisposeVisitor extends RecursiveAstVisitor<void> {
  _DisposeVisitor({
    required this.disposedFields,
    required this.methodBodies,
    Set<String>? visitedMethods,
  }) : _visitedMethods = visitedMethods ?? <String>{};

  final Set<String> disposedFields;
  final Map<String, FunctionBody?> methodBodies;
  final Set<String> _visitedMethods;

  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
    'cancel',
    'cancelSafe',
    'close',
    'closeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final String methodName = node.methodName.name;

    // Check if this is a disposal method call on a field
    if (_disposeMethodNames.contains(methodName)) {
      // Use realTarget, not target: for a cascade section
      // (`_c?..removeListener(f)..dispose()`) the syntactic target is null
      // because the receiver is implicit. realTarget resolves to the cascade
      // receiver `_c`, so the field is recorded as disposed instead of reading
      // as a leak.
      final Expression? target = node.realTarget ?? node.target;
      _extractFieldName(target);
    }

    // Check if this is a call to a helper method within the same class
    // (no target means it's a call to a method in the same class)
    if (node.target == null && !_visitedMethods.contains(methodName)) {
      final FunctionBody? helperBody = methodBodies[methodName];
      if (helperBody != null) {
        _visitedMethods.add(methodName);
        // Visit the helper method body to find disposals there
        helperBody.accept(
          _DisposeVisitor(
            disposedFields: disposedFields,
            methodBodies: methodBodies,
            visitedMethods: _visitedMethods,
          ),
        );
      }
    }
  }

  /// Extracts the field name from various target expression types.
  void _extractFieldName(Expression? target) {
    if (target == null) return;

    // Handle simple field access: _controller.dispose() or _timer?.cancel()
    if (target is SimpleIdentifier) {
      disposedFields.add(target.name);
    }
    // Handle prefixed access: this._controller.dispose()
    else if (target is PrefixedIdentifier) {
      disposedFields.add(target.identifier.name);
    }
    // Handle property access: this._controller.dispose() (alternate AST)
    else if (target is PropertyAccess) {
      disposedFields.add(target.propertyName.name);
    }
    // Handle parenthesized expressions: (_controller).dispose()
    else if (target is ParenthesizedExpression) {
      _extractFieldName(target.expression);
    }
    // Handle cascade: _controller..dispose()
    else if (target is CascadeExpression) {
      _extractFieldName(target.target);
    }
    // Handle null-assertion / null-aware postfix on a cascade target:
    // `_controller!..dispose()` or `_controller?..removeListener(x)..dispose()`
    // resolve the cascade target to the PostfixExpression `_controller!`/`_controller?`.
    // Recurse into its operand so the field name is still extracted; otherwise
    // a controller disposed through a multi-section cascade reads as undisposed.
    else if (target is PostfixExpression) {
      _extractFieldName(target.operand);
    }
  }
}

/// Warns when State class has unnecessary overrides.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState(); // Only calls super
///   }
/// }
/// ```
class AvoidUnnecessaryOverridesInStateRule extends SaropaLintRule {
  AvoidUnnecessaryOverridesInStateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unnecessary_overrides_in_state',
    '[avoid_unnecessary_overrides_in_state] Override only calls super with no additional logic. State class has unnecessary overrides. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v4}',
    correctionMessage:
        'Remove the unnecessary override. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'dispose',
    'didChangeDependencies',
    'didUpdateWidget',
    'deactivate',
    'activate',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          if (!_lifecycleMethods.contains(methodName)) continue;

          // Check if body only contains super call
          final FunctionBody body = member.body;
          if (body is BlockFunctionBody) {
            final Block block = body.block;
            if (block.statements.length == 1) {
              final Statement stmt = block.statements.first;
              if (stmt is ExpressionStatement) {
                final Expression expr = stmt.expression;
                if (expr is MethodInvocation) {
                  if (expr.target is SuperExpression &&
                      expr.methodName.name == methodName) {
                    reporter.atNode(member);
                  }
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when fields that need disposal are not disposed.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v2
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _controller = TextEditingController();
///   // Missing dispose() override
/// }
/// ```
class DisposeFieldsRule extends SaropaLintRule {
  DisposeFieldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'dispose_widget_fields',
    '[dispose_widget_fields] Field requires disposal but dispose method is missing or incomplete. Fields that need disposal are not disposed. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v2}',
    correctionMessage:
        'Add dispose method and call dispose on this field. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'StreamController',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Find disposable fields
      final List<VariableDeclaration> disposableFields =
          <VariableDeclaration>[];
      bool hasDisposeMethod = false;

      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String typeName =
                  initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(typeName)) {
                disposableFields.add(variable);
              }
            }
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDisposeMethod = true;
        }
      }

      // Report if there are disposable fields but no dispose method
      if (disposableFields.isNotEmpty && !hasDisposeMethod) {
        for (final VariableDeclaration field in disposableFields) {
          reporter.atNode(field);
        }
      }
    });
  }
}

/// Warns when a new Future is created inside FutureBuilder.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v8
///
/// Creating a new Future inline causes it to restart on every widget rebuild,
/// leading to flickering UI, wasted network requests, and poor performance.
///
/// **Alias:** `avoid_future_builder_rebuild`
///
/// **BAD:**
/// ```dart
/// FutureBuilder(
///   future: fetchData(), // Creates new future on every build!
///   builder: (context, snapshot) => ...,
/// )
///
/// // Also bad in helper methods:
/// Widget _buildContent() {
///   return FutureBuilder(
///     future: fetchData(), // Still restarts on every rebuild!
///     builder: (context, snapshot) => ...,
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final Future<Data> _dataFuture;
///
/// void initState() {
///   super.initState();
///   _dataFuture = fetchData();
/// }
///
/// FutureBuilder(
///   future: _dataFuture,
///   builder: (context, snapshot) => ...,
/// )
/// ```
class PassExistingFutureToFutureBuilderRule extends SaropaLintRule {
  PassExistingFutureToFutureBuilderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'pass_existing_future_to_future_builder',
    '[pass_existing_future_to_future_builder] Creating new Future in FutureBuilder restarts the async operation on every widget rebuild. This causes duplicate network calls, database queries, and slow UI with visible loading states. {v8}',
    correctionMessage:
        'Cache the Future in initState() or a final field and pass the stored reference to the FutureBuilder to prevent duplicate async operations on each rebuild.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'FutureBuilder') return;

      // Check future argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'future') {
          final Expression value = arg.expression;

          // Warn if future is a method invocation (creating new future).
          // Skip the cache-method pattern: a private instance method on a class
          // that owns a Future<T>? field is the idiomatic way to return a
          // cached future when the cached value depends on dynamic input
          // (where `late final` would be wrong). See bug:
          // pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.
          if (value is MethodInvocation) {
            if (!_isCacheMethodCall(value)) {
              reporter.atNode(value);
            }
          }

          // Warn if future is a function expression
          if (value is FunctionExpression) {
            reporter.atNode(value);
          }

          // Warn if future is a Future constructor (e.g., Future.value())
          if (value is InstanceCreationExpression) {
            reporter.atNode(value);
          }
        }
      }
    });
  }

  /// Returns true when the call looks like a cache-method pattern:
  /// a private instance method on the enclosing class whose owning class
  /// declares at least one `Future<...>?` field.
  ///
  /// The combination of (implicit-this private call) + (nullable Future field
  /// on the same class) is a strong signal that the method returns a cached
  /// future rather than allocating a fresh one each call. Without this opt-out
  /// the rule criminalizes the project's idiomatic cache-method pattern, which
  /// the rule's own correction message ("cache the Future") already endorses.
  bool _isCacheMethodCall(MethodInvocation node) {
    // Must be a method call on the enclosing class (implicit-this or `this`).
    final Expression? target = node.target;
    if (target != null && target is! ThisExpression) return false;

    // Must be a private method (lives in the same library) — strong signal
    // that we can reason about its body shape from project conventions.
    if (!node.methodName.name.startsWith('_')) return false;

    final ClassDeclaration? cls = node.thisOrAncestorOfType<ClassDeclaration>();
    if (cls == null) return false;

    // Search for at least one `Future<...>?` field on the class. Nullable
    // (`?`) is the load-bearing signal: late-final non-nullable futures can
    // only be assigned once, so the cache-method reassignment pattern requires
    // the field to be nullable.
    for (final ClassMember member in cls.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      final TypeAnnotation? type = member.fields.type;
      if (type is NamedType &&
          type.name.lexeme == 'Future' &&
          type.question != null) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when a new Stream is created inside StreamBuilder.
///
/// Since: v0.1.4 | Updated: v13.11.12 | Rule version: v8
///
/// Example of **bad** code:
/// ```dart
/// StreamBuilder(
///   stream: getDataStream(), // Creates new stream on every build
///   builder: (context, snapshot) => ...,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// late final Stream<Data> _dataStream = getDataStream();
///
/// StreamBuilder(
///   stream: _dataStream,
///   builder: (context, snapshot) => ...,
/// )
/// ```
class PassExistingStreamToStreamBuilderRule extends SaropaLintRule {
  PassExistingStreamToStreamBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'pass_existing_stream_to_stream_builder',
    '[pass_existing_stream_to_stream_builder] New Stream created inline in the StreamBuilder constructor. Every build() call creates a fresh stream, discarding the previous subscription and triggering an infinite rebuild loop as each new stream emits its initial value. {v8}',
    correctionMessage:
        'Store the Stream in a field (e.g., a late final or a State variable initialized in initState) and pass the stored reference to StreamBuilder.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'StreamBuilder') return;

      // Check stream argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'stream') {
          final Expression value = arg.expression;

          // Warn if stream is a method invocation (creating new stream).
          // Skip the cache-method pattern: a private instance method on a class
          // that owns a Stream<T>? field is the idiomatic way to return a
          // cached stream when the cached value depends on dynamic input
          // (where `late final` would be wrong). Mirrors the Future sibling's
          // exemption. See bug:
          // pass_existing_stream_to_stream_builder_missing_cache_method_exemption.
          if (value is MethodInvocation) {
            if (!_isCacheMethodCall(value)) {
              reporter.atNode(value);
            }
          }

          // Warn if stream is a function expression
          if (value is FunctionExpression) {
            reporter.atNode(value);
          }
        }
      }
    });
  }

  /// Returns true when the call looks like a cache-method pattern:
  /// a private instance method on the enclosing class whose owning class
  /// declares at least one `Stream<...>?` field.
  ///
  /// The combination of (implicit-this private call) + (nullable Stream field
  /// on the same class) is a strong signal that the method returns a cached
  /// stream rather than allocating a fresh one each call. Without this opt-out
  /// the rule criminalizes the project's idiomatic cache-method pattern, which
  /// the rule's own correction message ("store the Stream in a field") already
  /// endorses.
  bool _isCacheMethodCall(MethodInvocation node) {
    // Must be a method call on the enclosing class (implicit-this or `this`).
    final Expression? target = node.target;
    if (target != null && target is! ThisExpression) return false;

    // Must be a private method (lives in the same library) — strong signal
    // that we can reason about its body shape from project conventions.
    if (!node.methodName.name.startsWith('_')) return false;

    final ClassDeclaration? cls = node.thisOrAncestorOfType<ClassDeclaration>();
    if (cls == null) return false;

    // Search for at least one `Stream<...>?` field on the class. Nullable
    // (`?`) is the load-bearing signal: late-final non-nullable streams can
    // only be assigned once, so the cache-method reassignment pattern requires
    // the field to be nullable.
    for (final ClassMember member in cls.bodyMembers) {
      if (member is! FieldDeclaration) continue;
      final TypeAnnotation? type = member.fields.type;
      if (type is NamedType &&
          type.name.lexeme == 'Stream' &&
          type.question != null) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when Text widget is created with an empty string.
///
/// Since: v1.4.0 | Updated: v4.13.0 | Rule version: v5
///
/// Empty Text widgets consume resources without displaying anything.
/// Use SizedBox.shrink() or remove the widget entirely.
///
/// Example of **bad** code:
/// ```dart
/// Text('')
/// Text("")
/// Text('', style: TextStyle())
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox.shrink()
/// // Or simply remove the widget
/// if (text.isNotEmpty) Text(text)
/// ```
class RequireScrollControllerDisposeRule extends SaropaLintRule {
  RequireScrollControllerDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_scroll_controller_dispose',
    '[require_scroll_controller_dispose] ScrollController created but not disposed. Undisposed scroll controllers retain listeners and scroll position state, causing memory leaks that accumulate as users navigate between screens with scrollable content. {v6}',
    correctionMessage:
        'Add _controller.dispose() in the State.dispose() method before calling super.dispose() to release scroll position listeners and resources.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (State<MyWidget>)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find ScrollController fields (including late fields)
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            // Ownership transfer: a controller read from `widget.*` is owned by
            // the parent that created it. Per the Flutter contract the creator
            // disposes it, so requiring disposal here (at ERROR severity) would
            // break correct code and invite a double-dispose crash. Mirrors the
            // skip in RequireDisposeRule (_isParentOwnedFieldInitializer).
            final Expression? initializer = variable.initializer;
            if (initializer != null &&
                _isParentOwnedFieldInitializer(initializer)) {
              continue;
            }

            final String? typeName = member.fields.type?.toSource();
            if (typeName == 'ScrollController' ||
                typeName == 'ScrollController?') {
              controllerNames.add(variable.name.lexeme);
              continue;
            }
            // Check initializer for inferred types
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType == 'ScrollController') {
                if (!controllerNames.contains(variable.name.lexeme)) {
                  controllerNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      final Set<String> trackedNames = controllerNames.toSet();

      // Check if each controller is disposed (regex on dispose + didUpdateWidget,
      // plus AST: local aliases, helpers, didUpdateWidget-only disposal).
      for (final String name in controllerNames) {
        final bool isDisposed = isTrackedFieldDisposedInStateLifecycle(
          node,
          name,
          trackedNames,
        );

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.bodyMembers) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Requires FocusNode fields to be disposed in State classes.
///
/// Since: v1.4.3 | Updated: v4.13.0 | Rule version: v6
///
/// FocusNode allocates focus tree resources that must be released by calling
/// dispose(). Failing to do so causes memory leaks and focus management issues.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _focusNode = FocusNode();
///   // Missing dispose - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _focusNode = FocusNode();
///
///   @override
///   void dispose() {
///     _focusNode.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireFocusNodeDisposeRule extends SaropaLintRule {
  RequireFocusNodeDisposeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_focus_node_dispose',
    '[require_focus_node_dispose] FocusNode created but not disposed. Undisposed focus nodes retain listeners and focus tree references, causing memory leaks and stale focus behavior that accumulates as users navigate between screens with form inputs. {v7}',
    correctionMessage:
        'Add _focusNode.dispose() in the State.dispose() method before calling super.dispose() to release focus tree references and listeners.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (State<MyWidget>)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find FocusNode fields (including late fields)
      final List<String> nodeNames = <String>[];
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName == 'FocusNode' ||
                typeName == 'FocusNode?' ||
                typeName == 'FocusScopeNode' ||
                typeName == 'FocusScopeNode?') {
              nodeNames.add(variable.name.lexeme);
              continue;
            }
            // Check initializer for inferred types
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType == 'FocusNode' || initType == 'FocusScopeNode') {
                if (!nodeNames.contains(variable.name.lexeme)) {
                  nodeNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (nodeNames.isEmpty) return;

      final Set<String> trackedNames = nodeNames.toSet();

      // Check if each node is disposed (regex + AST; see
      // [isTrackedFieldDisposedInStateLifecycle]).
      for (final String name in nodeNames) {
        final bool isDisposed = isTrackedFieldDisposedInStateLifecycle(
          node,
          name,
          trackedNames,
        );

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.bodyMembers) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when InheritedWidget is missing updateShouldNotify.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v4
///
/// Without updateShouldNotify, dependent widgets rebuild on every
/// ancestor rebuild, even when the inherited data has not changed.
///
/// **BAD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final int value;
///   const MyInherited({required this.value, required super.child});
///   // Missing updateShouldNotify — causes unnecessary rebuilds.
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final int value;
///   const MyInherited({required this.value, required super.child});
///
///   @override
///   bool updateShouldNotify(MyInherited oldWidget) =>
///       value != oldWidget.value;
/// }
/// ```
class RequireShouldRebuildRule extends SaropaLintRule {
  RequireShouldRebuildRule() : super(code: _code);

  /// Performance issue - unnecessary rebuilds.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_should_rebuild',
    '[require_should_rebuild] InheritedWidget missing updateShouldNotify. Causes unnecessary rebuilds. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v4}',
    correctionMessage:
        'Override updateShouldNotify to control when dependents rebuild. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((node) {
      // Check if extends InheritedWidget
      final extendsClause = node.extendsClause;
      if (extendsClause == null) {
        return;
      }

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'InheritedWidget' &&
          superName != 'InheritedNotifier' &&
          superName != 'InheritedModel') {
        return;
      }

      // Check if updateShouldNotify is overridden
      bool hasOverride = false;
      for (final member in node.bodyMembers) {
        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'updateShouldNotify') {
            hasOverride = true;
            break;
          }
        }
      }

      if (!hasOverride) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when app doesn't handle device orientation.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Apps should either lock orientation or adapt layout for both
/// portrait and landscape modes using OrientationBuilder.
///
/// **BAD:**
/// ```dart
/// // App with no orientation handling - may break in landscape
/// MaterialApp(home: MyHomePage());
/// ```
///
/// **GOOD (lock orientation):**
/// ```dart
/// void main() {
///   SystemChrome.setPreferredOrientations([
///     DeviceOrientation.portraitUp,
///   ]);
///   runApp(MyApp());
/// }
/// ```
///
/// **ALSO GOOD (adapt to orientation):**
/// ```dart
/// OrientationBuilder(
///   builder: (context, orientation) {
///     return orientation == Orientation.portrait
///         ? PortraitLayout()
///         : LandscapeLayout();
///   },
/// );
/// ```
class RequireSuperDisposeCallRule extends SaropaLintRule {
  RequireSuperDisposeCallRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_super_dispose_call',
    '[require_super_dispose_call] Missing super.dispose() prevents parent '
        'State cleanup, causing memory leaks and broken widget lifecycle. {v1}',
    correctionMessage: 'Add super.dispose() at the end of your dispose method.',
    severity: DiagnosticSeverity.ERROR,
  );

  static final RegExp _superDisposePattern = RegExp(
    r'super\.dispose\s*\(\s*\)',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'dispose') return;

      // Use thisOrAncestorOfType: a MethodDeclaration's direct parent is the
      // class BODY node, not the ClassDeclaration, so `parent is ClassDeclaration`
      // never holds and the rule would never fire. Gate on a resolved State
      // subclass so a `dispose` method on a non-State class is not flagged.
      final ClassDeclaration? parent = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (parent == null || !_isStateSubclass(parent)) return;

      final String bodySource = node.body.toSource();
      if (!_superDisposePattern.hasMatch(bodySource)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when initState() method doesn't call super.initState().
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: missing_super_init_state, super_init_state_required
///
/// In `State<T>` subclasses, initState() must call super.initState() first
/// to ensure proper framework initialization.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     // Missing super.initState()!
///     _initSomething();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     _initSomething();
///   }
/// }
/// ```
class RequireSuperInitStateCallRule extends SaropaLintRule {
  RequireSuperInitStateCallRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_super_init_state_call',
    '[require_super_init_state_call] Missing super.initState() skips parent '
        'initialization, breaking framework contracts and causing subtle bugs. {v2}',
    correctionMessage:
        'Add super.initState() at the beginning of your initState method.',
    severity: DiagnosticSeverity.ERROR,
  );

  static final RegExp _superInitStatePattern = RegExp(
    r'super\.initState\s*\(\s*\)',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // thisOrAncestorOfType: the method's direct parent is the class body, not
      // the ClassDeclaration. Gate on a resolved State subclass.
      final ClassDeclaration? parent = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (parent == null || !_isStateSubclass(parent)) return;

      final String bodySource = node.body.toSource();
      if (!_superInitStatePattern.hasMatch(bodySource)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when setState is called inside dispose().
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: set_state_in_dispose, avoid_set_state_after_dispose
///
/// Calling setState in dispose is invalid - the widget is being unmounted.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void dispose() {
///     setState(() { _value = null; });  // Error!
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class AvoidSetStateInDisposeRule extends SaropaLintRule {
  AvoidSetStateInDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_set_state_in_dispose',
    '[avoid_set_state_in_dispose] setState in dispose() throws "setState '
        'called after dispose" error, crashing the app during navigation. {v2}',
    correctionMessage:
        'Remove setState - state changes are invalid during disposal.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      // Walk up to find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) return;
      if (enclosingMethod.name.lexeme != 'dispose') return;

      // Check if in State<T> class. thisOrAncestorOfType: the method's direct
      // parent is the class body, not the ClassDeclaration. Gate on a resolved
      // State subclass.
      final ClassDeclaration? parent = enclosingMethod
          .thisOrAncestorOfType<ClassDeclaration>();
      if (parent == null || !_isStateSubclass(parent)) return;

      reporter.atNode(node.methodName, code);
    });
  }
}

/// Warns when Navigator.push/pushNamed is called inside build().
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: navigation_in_build, avoid_navigator_in_build
///
/// Navigation inside build causes issues because build can be called
/// multiple times during a frame.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   Widget build(BuildContext context) {
///     if (_shouldNavigate) {
///       Navigator.pushNamed(context, '/next');  // Bad!
///     }
///     return Container();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       if (_shouldNavigate) {
///         Navigator.pushNamed(context, '/next');
///       }
///     });
///   }
/// }
/// ```
class RequireWidgetsBindingCallbackRule extends SaropaLintRule {
  RequireWidgetsBindingCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_widgets_binding_callback',
    '[require_widgets_binding_callback] showDialog/showModalBottomSheet in '
        'initState without addPostFrameCallback may fail. {v2}',
    correctionMessage:
        'Wrap in WidgetsBinding.instance.addPostFrameCallback((_) { ... }).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Look for dialog methods called directly (not in addPostFrameCallback)
      node.body.visitChildren(
        _DialogInInitStateVisitor((dialogNode) {
          reporter.atNode(dialogNode);
        }),
      );
    });
  }
}

class _DialogInInitStateVisitor extends RecursiveAstVisitor<void> {
  _DialogInInitStateVisitor(this.onFound);

  final void Function(AstNode) onFound;
  bool _isInsidePostFrameCallback = false;

  static const Set<String> _dialogMethods = <String>{
    'showDialog',
    'showModalBottomSheet',
    'showBottomSheet',
    'showSnackBar',
    'showDatePicker',
    'showTimePicker',
    'showMenu',
    'showGeneralDialog',
    'showCupertinoDialog',
    'showCupertinoModalPopup',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Track if we're inside addPostFrameCallback
    if (node.methodName.name == 'addPostFrameCallback') {
      final oldValue = _isInsidePostFrameCallback;
      _isInsidePostFrameCallback = true;
      super.visitMethodInvocation(node);
      _isInsidePostFrameCallback = oldValue;
      return;
    }

    // Check for dialog methods outside of addPostFrameCallback
    if (_dialogMethods.contains(node.methodName.name) &&
        !_isInsidePostFrameCallback) {
      onFound(node);
    }

    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// avoid_global_keys_in_state
// =============================================================================

/// GlobalKey fields created in StatefulWidget persist across hot reload.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v3
///
/// GlobalKeys are expensive and persist state across hot reloads, which can
/// cause unexpected behavior during development. However, GlobalKey fields
/// received as constructor parameters (pass-through references) are fine
/// since the parent manages the key's lifecycle.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final GlobalKey<FormState> formKey = GlobalKey<FormState>();  // Persists!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final _formKey = GlobalKey<FormState>();  // Created in State
/// }
/// ```
///
/// **ALSO GOOD** (pass-through from parent):
/// ```dart
/// class NavIcon extends StatefulWidget {
///   const NavIcon({this.navKey});
///   final GlobalKey<State<StatefulWidget>>? navKey;  // Not owned here
/// }
/// ```
class AvoidGlobalKeysInStateRule extends SaropaLintRule {
  AvoidGlobalKeysInStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_global_keys_in_state',
    '[avoid_global_keys_in_state] GlobalKey in StatefulWidget persists '
        'across hot reload. Move to State class instead. {v3}',
    correctionMessage:
        'Move this GlobalKey to the State class where it will be properly '
        'managed during hot reload.',
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _globalKeyTypePattern = RegExp(r'\bGlobalKey\b');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.contains('StatefulWidget')) return;

      final Set<String> constructorFieldParams = <String>{};
      for (final ClassMember member in node.bodyMembers) {
        if (member is ConstructorDeclaration) {
          for (final FormalParameter param in member.parameters.parameters) {
            final FormalParameter effectiveParam =
                param is DefaultFormalParameter ? param.parameter : param;
            if (effectiveParam is FieldFormalParameter) {
              final Token? name = effectiveParam.name;
              if (name != null) {
                constructorFieldParams.add(name.lexeme);
              }
            }
          }
        }
      }

      // Check fields for GlobalKey, skip constructor parameters
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type != null && _globalKeyTypePattern.hasMatch(type.toSource())) {
            // Skip if all variables are constructor parameters
            final bool isPassThrough = member.fields.variables.every(
              (VariableDeclaration v) =>
                  constructorFieldParams.contains(v.name.lexeme),
            );
            if (!isPassThrough) {
              reporter.atNode(member);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_expensive_did_change_dependencies
// =============================================================================

/// Warns when expensive operations run inside `didChangeDependencies()`.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: no_heavy_did_change, expensive_dependency_callback
///
/// `didChangeDependencies()` runs every time an InheritedWidget changes,
/// which can be very frequent (theme changes, locale changes, media query
/// changes). Placing network calls, database queries, or heavy computation
/// here causes redundant work and jank. Use `initState()` for one-time
/// initialization or add an `_initialized` guard.
///
/// **BAD:**
/// ```dart
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   fetchUserProfile();  // Runs on EVERY dependency change!
///   await database.query('users');  // Expensive DB call repeated!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// bool _initialized = false;
///
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   if (!_initialized) {
///     _initialized = true;
///     fetchUserProfile();
///   }
///   final theme = Theme.of(context);  // Cheap, OK here
/// }
/// ```
class AvoidExpensiveDidChangeDependenciesRule extends SaropaLintRule {
  AvoidExpensiveDidChangeDependenciesRule() : super(code: _code);

  /// Expensive work in frequent callbacks causes jank.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  bool get requiresWidgets => true;

  static const LintCode _code = LintCode(
    'avoid_expensive_did_change_dependencies',
    '[avoid_expensive_did_change_dependencies] Expensive operation detected '
        'inside didChangeDependencies(). This callback runs every time an '
        'InheritedWidget dependency changes (theme, locale, media query), '
        'which can be very frequent. Network calls, database queries, and '
        'heavy computation here cause redundant work, jank, and wasted '
        'bandwidth on every dependency change. {v1}',
    correctionMessage:
        'Move one-time initialization to initState() or add an '
        '_initialized guard. Only use didChangeDependencies for '
        'lightweight InheritedWidget lookups like Theme.of(context).',
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _initGuardPatterns = <RegExp>[
    RegExp(r'\b_initialized\b'),
    RegExp(r'\b_isInitialized\b'),
    RegExp(r'\b_didInit\b'),
    RegExp(r'\b_hasInit\b'),
    RegExp(r'\b_loaded\b'),
    RegExp(r'\b_isLoaded\b'),
    RegExp(r'\b_fetched\b'),
    RegExp(r'\b_ready\b'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'didChangeDependencies') return;

      // Only the State lifecycle callback re-runs on InheritedWidget dependency
      // changes; a same-named method on a plain class does not, so it carries
      // no jank hazard. Gate on a resolved State subclass.
      final ClassDeclaration? enclosing = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (enclosing == null || !_isStateSubclass(enclosing)) return;

      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      final String bodySource = body.toSource();
      if (_initGuardPatterns.any((re) => re.hasMatch(bodySource))) {
        return;
      }

      // Look for await expressions (network/DB calls)
      _visitExpensiveOps(body.block, reporter);
    });
  }

  void _visitExpensiveOps(Block block, SaropaDiagnosticReporter reporter) {
    for (final Statement stmt in block.statements) {
      _checkStatement(stmt, reporter);
    }
  }

  void _checkStatement(Statement stmt, SaropaDiagnosticReporter reporter) {
    if (stmt is ExpressionStatement) {
      final Expression expr = stmt.expression;
      // Await expression = async operation
      if (expr is AwaitExpression) {
        reporter.atNode(stmt);
        return;
      }
      // Method call that likely triggers expensive work
      if (expr is MethodInvocation && _isExpensiveCall(expr)) {
        reporter.atNode(stmt);
        return;
      }
    }
    if (stmt is VariableDeclarationStatement) {
      for (final VariableDeclaration v in stmt.variables.variables) {
        final Expression? init = v.initializer;
        if (init is AwaitExpression) {
          reporter.atNode(stmt);
          return;
        }
      }
    }
  }

  /// Exact method names that indicate expensive operations.
  static const Set<String> _expensiveMethods = <String>{
    'fetch',
    'fetchData',
    'loadData',
    'getData',
    'compute',
    'query',
  };

  bool _isExpensiveCall(MethodInvocation node) {
    return _expensiveMethods.contains(node.methodName.name);
  }
}

// =============================================================================
// avoid_static_route_config
// =============================================================================

/// Static GoRouter configuration causes hot reload issues.
///
/// Static final router instances don't update during hot reload,
/// making route changes require a full restart.
///
/// **BAD:**
/// ```dart
/// class AppRouter {
///   static final router = GoRouter(routes: [...]);  // Won't hot reload
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final router = GoRouter(routes: [...]);  // Top-level, will hot reload
///
/// // Or use a getter
/// GoRouter get router => GoRouter(routes: [...]);
/// ```

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../async_context_utils.dart';
import '../fixes/remove_empty_set_state_fix.dart';
import '../fixes/widget_lifecycle/wrap_set_state_in_mounted_check_fix.dart';
import '../saropa_lint_rule.dart';

/// Shared regex for detecting private method calls (e.g., `_dispose()`).
/// Used by multiple rules to detect calls to private helper methods.
final RegExp _privateMethodCallPattern = RegExp(r'_(\w+)\s*\(');

class AvoidContextInInitStateDisposeRule extends SaropaLintRule {
  AvoidContextInInitStateDisposeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

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

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Check if this is a 'context' identifier
    if (node.name == 'context' && _safeCallbackDepth == 0) {
      // Make sure it's actually accessing BuildContext, not a parameter named context
      // in a callback. We check by seeing if it's the left side of a property access
      // or used as an argument.
      if (!_isContextParameter(node)) {
        unsafeContextUsages.add(node);
      }
    }
    super.visitSimpleIdentifier(node);
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
  LintImpact get impact => LintImpact.low;

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

  /// Walk ancestors to check if [node] is inside a `mounted` guard.
  ///
  /// Handles `if (mounted) setState(…)`, ternary guards, and
  /// early-return patterns (`if (!mounted) return;` before setState).
  static bool _isInsideMountedGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement &&
          current.expression.toSource().contains('mounted')) {
        return true;
      }
      if (current is ConditionalExpression &&
          current.condition.toSource().contains('mounted')) {
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
  LintImpact get impact => LintImpact.medium;

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
  LintImpact get impact => LintImpact.medium;

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
  LintImpact get impact => LintImpact.medium;

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
      for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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
      for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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
  LintImpact get impact => LintImpact.medium;

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
      if (current is IfStatement) {
        if (_isMountedCheck(current.expression)) {
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

  /// Check if an expression is a mounted check
  bool _isMountedCheck(Expression condition) {
    final String source = condition.toSource();

    // Direct mounted check
    if (source == 'mounted') {
      return true;
    }

    // mounted == true or mounted != false
    if (source.contains('mounted')) {
      return true;
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
  LintImpact get impact => LintImpact.critical;

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
      for (final ClassMember member in node.members) {
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

      // Find the dispose method and collect all method bodies
      MethodDeclaration? disposeMethod;
      final Map<String, String> methodBodies = <String, String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          methodBodies[methodName] = member.body.toSource();
          if (methodName == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      // Get the dispose method body and expand helper method calls
      String disposeBody = '';
      if (disposeMethod != null) {
        disposeBody = _expandMethodCalls(
          disposeMethod.body.toSource(),
          methodBodies,
        );
      }

      // Check each disposable field
      for (final _DisposableField field in disposableFields) {
        if (disposeMethod == null) {
          // No dispose method at all
          reporter.atNode(field.declaration.fields, code);
        } else if (!_isFieldDisposed(field, disposeBody)) {
          // Dispose method exists but doesn't dispose this field
          reporter.atNode(field.declaration.fields, code);
        }
      }
    });
  }

  /// Expand helper method calls in the body to include their implementations.
  /// This allows detecting disposal patterns like `_cancelTimer()` that
  /// internally call `_timer?.cancel()`.
  String _expandMethodCalls(
    String body,
    Map<String, String> methodBodies, {
    int depth = 0,
  }) {
    // Prevent infinite recursion
    if (depth > 3) {
      return body;
    }

    final StringBuffer expanded = StringBuffer(body);

    // Find method calls to private methods (starting with _)
    for (final RegExpMatch match in _privateMethodCallPattern.allMatches(
      body,
    )) {
      final String methodName = '_${match.group(1)}';
      final String? methodBody = methodBodies[methodName];
      if (methodBody != null) {
        // Recursively expand nested helper calls
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

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'State';
  }

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

    final String fieldName = node.fields.variables.first.name.lexeme;
    final String disposeMethod = _disposableTypes[typeName]!;

    return _DisposableField(
      name: fieldName,
      typeName: typeName,
      disposeMethod: disposeMethod,
      declaration: node,
    );
  }

  /// Check if a field is properly disposed in the dispose body
  bool _isFieldDisposed(_DisposableField field, String disposeBody) {
    final String name = field.name;
    final String method = field.disposeMethod;

    // Common disposal patterns
    final List<String> patterns = <String>[
      '$name.$method(',
      '$name?.$method(',
      '$name..$method(',
      '$name.${method}Safe(',
      '$name?.${method}Safe(',
      '$name..${method}Safe(',
    ];

    for (final String pattern in patterns) {
      if (disposeBody.contains(pattern)) {
        return true;
      }
    }

    return false;
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
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_timer_cancellation',
    '[require_timer_cancellation] Timer or StreamSubscription must be canceled in dispose(). Timers and stream subscriptions that aren\'t canceled will continue running after the widget is disposed, causing: - Crashes if they call setState on a disposed widget - Memory leaks from retained references - Wasted CPU cycles. {v5}',
    correctionMessage:
        'Add cancel() in dispose() to prevent crashes and memory leaks. Verify the change works correctly with existing tests and add coverage for the new behavior.'
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
      for (final ClassMember member in node.members) {
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

      for (final ClassMember member in node.members) {
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

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }
    return extendsClause.superclass.name.lexeme == 'State';
  }

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

    // Common cancellation patterns
    final List<String> patterns = <String>[
      '$name.cancel(',
      '$name?.cancel(',
      '$name..cancel(',
      '$name.cancelSafe(',
      '$name?.cancelSafe(',
      '$name..cancelSafe(',
    ];

    for (final String pattern in patterns) {
      if (disposeBody.contains(pattern)) {
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
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'nullify_after_dispose',
    '[nullify_after_dispose] Nullable disposable field must be set to null after disposal. When a nullable disposable field (Timer?, StreamSubscription?, etc.) is disposed/canceled, it\'s good practice to also set it to null. This: - Helps garbage collection - Prevents accidental reuse of disposed resources - Makes it clear the resource has been cleaned up. {v7}',
    correctionMessage:
        'Add `fieldName = null;` after disposing to help garbage collection. Verify the change works correctly with existing tests and add coverage for the new behavior.'
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

      // Skip if field is final or non-nullable (can't be set to null)
      final ClassDeclaration? classNode = _findContainingClass(node);
      if (classNode != null &&
          _isFieldFinalOrNonNullable(classNode, fieldName)) {
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

  /// Check if a field is final or has a non-nullable type
  bool _isFieldFinalOrNonNullable(
    ClassDeclaration classNode,
    String fieldName,
  ) {
    for (final ClassMember member in classNode.members) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          if (variable.name.lexeme == fieldName) {
            // Final fields can't be reassigned
            if (member.fields.isFinal) {
              return true;
            }
            // Non-nullable types can't be set to null
            final TypeAnnotation? type = member.fields.type;
            if (type is NamedType && type.question == null) {
              return true;
            }
            return false;
          }
        }
      }
    }
    return false;
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
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'use_setstate_synchronously',
    '[use_setstate_synchronously] setState called after async gap without mounted check. Quick fix available: Wraps the setState call in if (mounted) { .. }. This violates the widget lifecycle, risking setState-after-dispose errors or silent state corruption. {v9}',
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
      // Only check async methods with block body
      if (node.body is! BlockFunctionBody) return;
      final BlockFunctionBody body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      bool seenAwait = false;
      bool hasGuard = false;

      for (final Statement stmt in body.block.statements) {
        // Await found: enter danger zone, reset guard
        // Uses shared utility from async_context_utils.dart
        if (containsAwait(stmt)) {
          seenAwait = true;
          hasGuard = false;
        }

        // Early-exit guard protects subsequent code
        // Uses shared utility from async_context_utils.dart
        if (seenAwait && isNegatedMountedGuard(stmt)) {
          hasGuard = true;
          continue;
        }

        // Report unprotected setState calls after await
        if (seenAwait && !hasGuard) {
          _reportUnprotectedSetState(stmt, reporter);
        }
      }
    });
  }

  void _reportUnprotectedSetState(
    Statement stmt,
    SaropaDiagnosticReporter reporter,
  ) {
    // Uses shared SetStateWithMountedCheckFinder from async_context_utils.dart
    stmt.visitChildren(
      SetStateWithMountedCheckFinder((MethodInvocation node) {
        reporter.atNode(node);
      }),
    );
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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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
      final String target = node.realTarget?.toSource() ?? '';
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = args.first.toSource();
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
      final String target = node.realTarget?.toSource() ?? '';
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = args.first.toSource();
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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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

      for (final ClassMember member in node.members) {
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
          for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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

      bool hasAwait = false;
      for (final Statement statement in node.block.statements) {
        // Check for await expressions using shared utility
        if (containsAwait(statement)) {
          hasAwait = true;
        }

        // If we've seen an await, check for ScaffoldMessenger.of(context)
        if (hasAwait && _containsScaffoldMessengerOf(statement)) {
          // Find and report the specific usage
          statement.visitChildren(
            _ScaffoldMessengerFinderNew((MethodInvocation invocation) {
              reporter.atNode(invocation);
            }),
          );
        }
      }
    });
  }

  bool _containsScaffoldMessengerOf(AstNode node) {
    bool found = false;
    node.visitChildren(_ScaffoldMessengerFinderNew((_) => found = true));
    return found;
  }
}

class _ScaffoldMessengerFinderNew extends RecursiveAstVisitor<void> {
  _ScaffoldMessengerFinderNew(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier &&
        target.name == 'ScaffoldMessenger' &&
        node.methodName.name == 'of') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
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
  LintImpact get impact => LintImpact.medium;

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
      for (final ClassMember member in node.members) {
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

      // Check for manual state tracking fields
      int stateFields = 0;
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final String name = field.name.lexeme;
            if (name.contains('Hover') ||
                name.contains('hover') ||
                name.contains('Press') ||
                name.contains('press') ||
                name.contains('Focus') ||
                name.contains('focus') ||
                name == '_isHovered' ||
                name == '_isPressed' ||
                name == '_isFocused') {
              stateFields++;
            }
          }
        }
      }

      if (stateFields >= 2) {
        reporter.atToken(node.name, code);
      }
    });
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
      final String className = node.name.lexeme;

      // Check if it's a widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget' &&
          superclassName != 'StatefulWidget') {
        return;
      }

      // Find build method
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          // Check for self-instantiation in build
          member.body.accept(
            _RecursiveWidgetVisitor(className, reporter, code),
          );
        }
      }
    });
  }
}

class _RecursiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _RecursiveWidgetVisitor(this.className, this.reporter, this.code);

  final String className;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName == className) {
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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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
          for (final ClassMember member in node.members) {
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
      final Expression? target = node.target;
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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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

      for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.high;

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

          // Warn if future is a method invocation (creating new future)
          if (value is MethodInvocation) {
            reporter.atNode(value);
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
}

/// Warns when a new Stream is created inside StreamBuilder.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
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
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'pass_existing_stream_to_stream_builder',
    '[pass_existing_stream_to_stream_builder] New Stream created inline in the StreamBuilder constructor. Every build() call creates a fresh stream, discarding the previous subscription and triggering an infinite rebuild loop as each new stream emits its initial value. {v7}',
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

          // Warn if stream is a method invocation (creating new stream)
          if (value is MethodInvocation) {
            reporter.atNode(value);
          }

          // Warn if stream is a function expression
          if (value is FunctionExpression) {
            reporter.atNode(value);
          }
        }
      }
    });
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
    '[require_scroll_controller_dispose] ScrollController created but not disposed. Undisposed scroll controllers retain listeners and scroll position state, causing memory leaks that accumulate as users navigate between screens with scrollable content. {v5}',
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
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName == 'ScrollController' ||
                typeName == 'ScrollController?') {
              controllerNames.add(variable.name.lexeme);
              continue;
            }
            // Check initializer for inferred types
            final Expression? initializer = variable.initializer;
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

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each controller is disposed
      for (final String name in controllerNames) {
        // Direct disposal patterns (whitespace-tolerant)
        final bool isDirectlyDisposed =
            disposeBody != null &&
            RegExp(
              '${RegExp.escape(name)}\\s*[?.]+'
              '\\s*dispose(Safe)?\\s*\\(',
            ).hasMatch(disposeBody);

        // Iteration-based disposal
        final bool isIterationDisposed =
            disposeBody != null &&
            RegExp(
              'in\\s+${RegExp.escape(name)}(\\.values)?\\)',
            ).hasMatch(disposeBody) &&
            disposeBody.contains('.dispose()');

        final bool isDisposed = isDirectlyDisposed || isIterationDisposed;

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_focus_node_dispose',
    '[require_focus_node_dispose] FocusNode created but not disposed. Undisposed focus nodes retain listeners and focus tree references, causing memory leaks and stale focus behavior that accumulates as users navigate between screens with form inputs. {v6}',
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
      for (final ClassMember member in node.members) {
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

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each node is disposed
      for (final String name in nodeNames) {
        // Direct disposal patterns (whitespace-tolerant)
        final bool isDirectlyDisposed =
            disposeBody != null &&
            RegExp(
              '${RegExp.escape(name)}\\s*[?.]+'
              '\\s*dispose(Safe)?\\s*\\(',
            ).hasMatch(disposeBody);

        // Iteration-based disposal
        final bool isIterationDisposed =
            disposeBody != null &&
            RegExp(
              'in\\s+${RegExp.escape(name)}(\\.values)?\\)',
            ).hasMatch(disposeBody) &&
            disposeBody.contains('.dispose()');

        final bool isDisposed = isDirectlyDisposed || isIterationDisposed;

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
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
  LintImpact get impact => LintImpact.medium;

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
      for (final member in node.members) {
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
  LintImpact get impact => LintImpact.critical;

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

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'dispose') return;

      // Check if in State<T> class
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'State') return;

      // Check if super.dispose() is called
      final bodySource = node.body.toSource();
      if (!bodySource.contains('super.dispose()')) {
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
  LintImpact get impact => LintImpact.critical;

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

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Check if in State<T> class
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'State') return;

      // Check if super.initState() is called
      final bodySource = node.body.toSource();
      if (!bodySource.contains('super.initState()')) {
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
  LintImpact get impact => LintImpact.critical;

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

      // Check if in State<T> class
      final parent = enclosingMethod.parent;
      if (parent is! ClassDeclaration) return;

      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'State') return;

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
  LintImpact get impact => LintImpact.high;

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
  bool _insidePostFrameCallback = false;

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
      final oldValue = _insidePostFrameCallback;
      _insidePostFrameCallback = true;
      super.visitMethodInvocation(node);
      _insidePostFrameCallback = oldValue;
      return;
    }

    // Check for dialog methods outside of addPostFrameCallback
    if (_dialogMethods.contains(node.methodName.name) &&
        !_insidePostFrameCallback) {
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
  LintImpact get impact => LintImpact.medium;

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

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.contains('StatefulWidget')) return;

      // Collect field names set via constructor parameters (this.xxx).
      // These are pass-through references from the parent, not keys
      // created by this widget, so they should not be flagged.
      final Set<String> constructorFieldParams = <String>{};
      for (final ClassMember member in node.members) {
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
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type != null && type.toSource().contains('GlobalKey')) {
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

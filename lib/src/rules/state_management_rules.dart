// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// State management lint rules for Flutter/Dart applications.
///
/// These rules help identify common state management issues including
/// improper state updates, missing dispose calls, and anti-patterns
/// in state handling.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../saropa_lint_rule.dart';
import '../fixes/navigation/add_mounted_check_fix.dart';

/// Warns when ChangeNotifier subclass doesn't call notifyListeners.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// ChangeNotifier without notify calls won't update listeners.
///
/// **BAD:**
/// ```dart
/// class Counter extends ChangeNotifier {
///   int _count = 0;
///   void increment() {
///     _count++; // Missing notifyListeners()
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Counter extends ChangeNotifier {
///   int _count = 0;
///   void increment() {
///     _count++;
///     notifyListeners();
///   }
/// }
/// ```
class RequireNotifyListenersRule extends SaropaLintRule {
  RequireNotifyListenersRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_notify_listeners',
    '[require_notify_listeners] ChangeNotifier method modifies state properties but does not call notifyListeners(). Widgets listening to this notifier will not rebuild to reflect the updated state, displaying stale data to the user. This creates silent data synchronization bugs that are difficult to diagnose because the state appears correct in debug tools. {v5}',
    correctionMessage:
        'Add notifyListeners() as the last statement in every method that modifies observable state properties to trigger dependent widget rebuilds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends ChangeNotifier
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'ChangeNotifier') return;

      // Check each method that modifies state
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          _checkMethod(member, reporter);
        }
      }
    });
  }

  void _checkMethod(
    MethodDeclaration method,
    SaropaDiagnosticReporter reporter,
  ) {
    // Skip getters and constructors
    if (method.isGetter || method.isStatic) return;

    bool hasStateModification = false;
    bool hasNotifyListeners = false;

    method.body.visitChildren(
      _StateModificationVisitor(
        onModification: () => hasStateModification = true,
        onNotify: () => hasNotifyListeners = true,
      ),
    );

    if (hasStateModification && !hasNotifyListeners) {
      reporter.atNode(method);
    }
  }
}

class _StateModificationVisitor extends RecursiveAstVisitor<void> {
  _StateModificationVisitor({
    required this.onModification,
    required this.onNotify,
  });

  final void Function() onModification;
  final void Function() onNotify;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Check if assigning to a private field (state)
    final Expression left = node.leftHandSide;
    if (left is SimpleIdentifier && left.name.startsWith('_')) {
      onModification();
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'notifyListeners') {
      onNotify();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when StreamController is not disposed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Not closing StreamControllers causes memory leaks.
///
/// **Detection:**
/// - Direct `StreamController` or `StreamController<T>`: requires `.close()`
/// - Wrapper types (e.g., `IsarStreamController`): accepts `.close()` or `.dispose()`
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final _controller = StreamController<int>();
///   // Missing dispose
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final _controller = StreamController<int>();
///
///   @override
///   void dispose() {
///     _controller.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireStreamControllerDisposeRule extends SaropaLintRule {
  RequireStreamControllerDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_stream_controller_dispose',
    '[require_stream_controller_dispose] Not closing a StreamController in the StatefulWidget dispose method will leak memory, keep listeners active, and cause app slowdowns, crashes, or persistent background activity. This leads to stream subscription exhaustion, battery drain, and unpredictable bugs, especially in production apps with frequent widget tree rebuilds. Unclosed controllers also prevent garbage collection and block app updates. {v7}',
    correctionMessage:
        'Always call controller.close() in the dispose method of your widget or class to properly release resources and prevent memory leaks. Audit all StreamController usage for proper cleanup and add tests for resource management. Document disposal logic for maintainability.',
    severity: DiagnosticSeverity.ERROR,
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

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (not StatefulWidget, StateManager, etc.)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find StreamController and wrapper fields
      final List<_ControllerField> controllers = <_ControllerField>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeStr = member.fields.type?.toSource();
          if (typeStr != null && typeStr.contains('StreamController')) {
            for (final variable in member.fields.variables) {
              // Detect if this is a direct StreamController vs a wrapper type
              // Direct: StreamController, StreamController<T>, StreamController<dynamic>
              // Wrapper: IsarStreamController, MyStreamController<T>, etc.
              final bool isDirectStreamController =
                  typeStr == 'StreamController' ||
                  typeStr.startsWith('StreamController<');
              controllers.add(
                _ControllerField(variable, !isDirectStreamController),
              );
            }
          }
        }
      }

      if (controllers.isEmpty) return;

      // Find dispose method with close()/dispose() calls
      MethodDeclaration? disposeMethod;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod == null) return;
      final String? bodySource = disposeMethod.body.toSource();
      if (bodySource == null) return;

      for (final controller in controllers) {
        final String name = controller.variable.name.lexeme;
        final bool hasClose = bodySource.contains('$name.close()');
        final bool hasDispose = bodySource.contains('$name.dispose()');
        if (controller.isWrapper) {
          // Accept .dispose() OR .close() for wrapper types
          if (!hasDispose && !hasClose) {
            reporter.atNode(controller.variable, code);
          }
        } else {
          // Require .close() for direct StreamController
          if (!hasClose) {
            reporter.atNode(controller.variable, code);
          }
        }
      }
    });
  }
}

class _ControllerField {
  final VariableDeclaration variable;
  final bool isWrapper;
  const _ControllerField(this.variable, this.isWrapper);
}

/// Warns when ValueNotifier is used without dispose.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// ValueNotifier should be disposed to release resources.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final counter = ValueNotifier<int>(0);
///   // Missing dispose
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   final counter = ValueNotifier<int>(0);
///
///   @override
///   void dispose() {
///     counter.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// Also recognizes loop-based disposal patterns:
/// ```dart
/// final List<ValueNotifier<int>> _notifiers = [];
///
/// @override
/// void dispose() {
///   for (final n in _notifiers) { n.dispose(); }
///   // or: _notifiers.forEach((n) => n.dispose());
///   super.dispose();
/// }
/// ```
class RequireValueNotifierDisposeRule extends SaropaLintRule {
  RequireValueNotifierDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_value_notifier_dispose',
    '[require_value_notifier_dispose] If you do not dispose a ValueNotifier, it will leak memory, keep listeners attached, and trigger updates on a StatefulWidget that has already been removed from the widget tree. This causes memory leaks, unexpected UI updates, and hard-to-find bugs in your app. {v6}',
    correctionMessage:
        'Call notifier.dispose() in the dispose method of your widget or class to properly release resources and prevent memory leaks.',
    severity: DiagnosticSeverity.ERROR,
  );

  // Cached regex for performance
  static final RegExp _collectionPattern = RegExp(
    r'(List|Set|Iterable)<\s*(Safe)?ValueNotifier<',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State (not StatefulWidget or StatelessWidget)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      // Only match "State" exactly - StatefulWidget/StatelessWidget should not be checked
      // because their ValueNotifier fields are parameters passed in, not owned by them
      if (superName != 'State') return;

      // Find ValueNotifier fields that are CREATED locally (have initializers).
      // Fields without initializers are parameters passed from outside and should
      // NOT be disposed by this class - the owner is responsible for disposal.
      // Track both single notifiers and collections of notifiers separately.
      final List<String> singleNotifierNames = <String>[];
      final List<String> collectionNotifierNames = <String>[];

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            // Skip fields without initializers - they are parameters, not owned
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            final String? typeName = member.fields.type?.toSource();
            if (typeName != null) {
              // Check for collections of ValueNotifiers (List, Set, Iterable, Map values)
              if (_isCollectionOfValueNotifiers(typeName)) {
                collectionNotifierNames.add(variable.name.lexeme);
                continue;
              }
              // Check for single ValueNotifier
              if (typeName.contains('ValueNotifier')) {
                singleNotifierNames.add(variable.name.lexeme);
                continue;
              }
            }
            // Also check initializers for ValueNotifier creation
            if (initializer is InstanceCreationExpression) {
              final String? initTypeName =
                  initializer.constructorName.type.element?.name;
              if (initTypeName == 'ValueNotifier') {
                singleNotifierNames.add(variable.name.lexeme);
              }
            }
          }
        }
      }

      if (singleNotifierNames.isEmpty && collectionNotifierNames.isEmpty) {
        return;
      }

      // Find dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Check if notifiers are disposed (directly or via loop)
      final Set<String> disposedNotifiers = <String>{};
      final Set<String> loopDisposedCollections = <String>{};

      if (disposeMethod != null) {
        final visitor = _ValueNotifierDisposeVisitor(
          onDirectDispose: (String name) => disposedNotifiers.add(name),
          onLoopDispose: (String name) => loopDisposedCollections.add(name),
        );
        disposeMethod.body.visitChildren(visitor);
      }

      // Report undisposed single notifiers
      for (final String name in singleNotifierNames) {
        if (!disposedNotifiers.contains(name)) {
          _reportUndisposed(node, name, reporter);
        }
      }

      // Report undisposed collection notifiers (only if not loop-disposed)
      for (final String name in collectionNotifierNames) {
        if (!loopDisposedCollections.contains(name)) {
          _reportUndisposed(node, name, reporter);
        }
      }
    });
  }

  /// Checks if a type string represents a collection of ValueNotifiers.
  static bool _isCollectionOfValueNotifiers(String typeName) {
    // Match patterns like:
    // - List<ValueNotifier<...>>
    // - List<SafeValueNotifier<...>>
    // - Set<ValueNotifier<...>>
    // - Iterable<ValueNotifier<...>>
    return _collectionPattern.hasMatch(typeName);
  }

  void _reportUndisposed(
    ClassDeclaration classNode,
    String fieldName,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final ClassMember member in classNode.members) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          if (variable.name.lexeme == fieldName) {
            reporter.atNode(variable);
          }
        }
      }
    }
  }
}

/// Enhanced visitor that detects both direct disposal and loop-based disposal.
///
/// Recognizes patterns like:
/// - `notifier.dispose()` - direct disposal
/// - `for (var n in _notifiers) { n.dispose(); }` - for-in loop disposal
/// - `_notifiers.forEach((n) => n.dispose())` - forEach disposal
class _ValueNotifierDisposeVisitor extends RecursiveAstVisitor<void> {
  _ValueNotifierDisposeVisitor({
    required this.onDirectDispose,
    required this.onLoopDispose,
  });

  final void Function(String) onDirectDispose;
  final void Function(String) onLoopDispose;

  /// Methods that dispose resources (including *Safe extension variants).
  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
  };

  /// Track loop variables and their source collections.
  /// Key: loop variable name, Value: collection field name
  final Map<String, String> _loopVariableToCollection = <String, String>{};

  @override
  void visitForStatement(ForStatement node) {
    // Handle: for (var i = 0; i < _list.length; i++) { _list[i].dispose(); }
    // This is more complex, skip for now - for-in is more common
    super.visitForStatement(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    // Handle: for (final item in _collection)
    final String loopVarName = node.loopVariable.name.lexeme;
    final Expression iterable = node.iterable;

    if (iterable is SimpleIdentifier) {
      _loopVariableToCollection[loopVarName] = iterable.name;
    }

    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // Check for direct dispose: notifier.dispose()
    if (_disposeMethodNames.contains(methodName)) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        final String targetName = target.name;

        // Check if this is a loop variable being disposed
        final String? collectionName = _loopVariableToCollection[targetName];
        if (collectionName != null) {
          onLoopDispose(collectionName);
        } else {
          onDirectDispose(targetName);
        }
      }
    }

    // Check for forEach pattern: _collection.forEach((item) => item.dispose())
    if (methodName == 'forEach') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        final String collectionName = target.name;

        // Check if the forEach callback disposes items
        final ArgumentList args = node.argumentList;
        if (args.arguments.isNotEmpty) {
          final Expression firstArg = args.arguments.first;
          if (firstArg is FunctionExpression) {
            // Check if the function body contains a dispose call
            if (_containsDisposeCall(firstArg.body)) {
              onLoopDispose(collectionName);
            }
          }
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  /// Checks if a function body contains a dispose call.
  bool _containsDisposeCall(FunctionBody body) {
    bool hasDispose = false;
    body.visitChildren(_SimpleDisposeChecker(() => hasDispose = true));
    return hasDispose;
  }
}

/// Simple visitor that just checks if dispose is called anywhere.
class _SimpleDisposeChecker extends RecursiveAstVisitor<void> {
  _SimpleDisposeChecker(this.onFound);

  final void Function() onFound;

  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_disposeMethodNames.contains(node.methodName.name)) {
      onFound();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when setState is called with async gap.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: check_mounted_after_async
///
/// Calling setState after await may occur when widget is unmounted.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() {
///     _data = data; // Widget may be disposed
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (!mounted) return;
///   setState(() {
///     _data = data;
///   });
/// }
/// ```
class RequireMountedCheckRule extends SaropaLintRule {
  RequireMountedCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddMountedCheckFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'require_mounted_check',
    '[require_mounted_check] Calling setState after an await without checking if the StatefulWidget is still mounted in the widget tree throws a "setState called after dispose" error. This leads to runtime exceptions, app instability, and hard-to-debug crashes, especially in async code. {v4}',
    correctionMessage:
        'Add "if (!mounted) return;" before calling setState after an await to ensure the widget is still in the widget tree and prevent runtime errors.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Check if async method
      if (!node.body.isAsynchronous) return;

      // Check if in a State class
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (not StateManager, etc.)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Look for await expressions followed by setState without mounted check
      node.body.visitChildren(_AsyncSetStateVisitor(reporter, code));
    });
  }
}

class _AsyncSetStateVisitor extends RecursiveAstVisitor<void> {
  _AsyncSetStateVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool _sawAwait = false;
  bool _hasMountedCheck = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _sawAwait = true;
    _hasMountedCheck = false; // Reset mounted check after each await
    super.visitAwaitExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Skip nested lambdas - they have their own async context.
    // This prevents false positives when setState is in a callback
    // that has its own mounted check pattern.
    return;
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check for mounted check: if (!mounted) return; or if (mounted)
    final String condition = node.expression.toSource();
    if (condition.contains('mounted')) {
      _hasMountedCheck = true;
    }
    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState' && _sawAwait && !_hasMountedCheck) {
      // Double-check with ancestor mounted check
      if (!_hasAncestorMountedCheck(node)) {
        reporter.atNode(node);
      }
    }
    super.visitMethodInvocation(node);
  }

  /// Checks if node has an ancestor if statement checking mounted.
  bool _hasAncestorMountedCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('mounted')) {
          return true;
        }
      }
      // Stop at function boundaries
      if (current is FunctionExpression || current is MethodDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when a State class has no mutable state, lifecycle methods, or
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// setState calls.
///
/// A StatefulWidget is designed for widgets that maintain mutable state.
/// Using it without any state adds unnecessary complexity, increases lifecycle
/// overhead, and can confuse maintainers. Convert to StatelessWidget for
/// better performance and clearer intent.
///
/// The rule excludes State classes that have:
/// - Non-final instance fields (mutable state)
/// - Lifecycle method overrides (initState, didChangeDependencies,
///   didUpdateWidget, deactivate, dispose)
/// - Any `setState` calls in method bodies (including nested callbacks)
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// // No mutable fields, no lifecycle methods, no setState calls
/// class _MyWidgetState extends State<MyWidget> {
///   final String title = 'Hello'; // final field doesn't count as state
///
///   @override
///   Widget build(BuildContext context) => Text(title);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Convert to StatelessWidget
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
///
/// // Option 2: Has mutable state
/// class _CounterState extends State<Counter> {
///   int count = 0; // Non-final field = mutable state
///   @override
///   Widget build(BuildContext context) => Text('$count');
/// }
///
/// // Option 3: Uses setState
/// class _ToggleState extends State<Toggle> {
///   void _onTap() => setState(() {}); // Uses setState
///   @override
///   Widget build(BuildContext context) => GestureDetector(onTap: _onTap);
/// }
/// ```
///
/// **Quick fix available:** Adds a TODO comment to convert to StatelessWidget.
class AvoidStatefulWithoutStateRule extends SaropaLintRule {
  AvoidStatefulWithoutStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_stateful_without_state',
    '[avoid_stateful_without_state] Using a StatefulWidget without any state fields adds unnecessary complexity, increases lifecycle overhead, and can confuse maintainers. This leads to harder-to-read code, wasted memory allocations for the State object, and potential performance issues. {v6}',
    correctionMessage:
        'Convert the widget to a StatelessWidget if it does not manage any state. This simplifies your code and improves performance.',
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

      // Must be exactly "State" with type argument (not StateManager, etc.)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Check if has any non-final fields (actual state)
      bool hasState = false;
      bool hasLifecycleMethods = false;
      bool hasSetStateCalls = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          // Check for non-final instance fields
          if (!member.isStatic && !member.fields.isFinal) {
            hasState = true;
            break;
          }
        }
        if (member is MethodDeclaration) {
          final String name = member.name.lexeme;
          if (name == 'initState' ||
              name == 'didChangeDependencies' ||
              name == 'didUpdateWidget' ||
              name == 'deactivate' ||
              name == 'dispose') {
            hasLifecycleMethods = true;
          }

          // Check for setState calls in method body
          if (!hasSetStateCalls) {
            final _StatefulSetStateVisitor visitor = _StatefulSetStateVisitor();
            member.body.accept(visitor);
            hasSetStateCalls = visitor.hasSetState;
          }
        }
      }

      if (!hasState && !hasLifecycleMethods && !hasSetStateCalls) {
        reporter.atNode(node);
      }
    });
  }
}

/// Quick fix that adds a TODO comment suggesting conversion to StatelessWidget.
///
/// The fix adds a comment above the State class rather than performing an
/// automatic conversion because:
/// 1. The StatefulWidget class also needs to be converted/removed
/// 2. The conversion may require moving final fields to the widget class
/// 3. Automatic widget refactoring is complex and error-prone

/// Detects `setState` calls within method bodies.
///
/// Used by [AvoidStatefulWithoutStateRule] to identify State classes that
/// call setState, even if they have no mutable fields. This prevents false
/// positives for widgets that manage state through setState callbacks rather
/// than explicit field declarations.
///
/// The visitor traverses the AST and stops early once setState is found
/// for performance.
class _StatefulSetStateVisitor extends RecursiveAstVisitor<void> {
  bool hasSetState = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      hasSetState = true;
      return; // Early exit - no need to continue traversing
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when GlobalKey is created in build method.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// GlobalKeys created in build cause widget recreation on every rebuild.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final key = GlobalKey<FormState>();
///   return Form(key: key, ...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final _formKey = GlobalKey<FormState>();
///
/// Widget build(BuildContext context) {
///   return Form(key: _formKey, ...);
/// }
/// ```
class AvoidGlobalKeyInBuildRule extends SaropaLintRule {
  AvoidGlobalKeyInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_global_key_in_build',
    '[avoid_global_key_in_build] Creating a GlobalKey inside the build() method causes it to be recreated on every rebuild, which results in lost widget state, broken references, and unpredictable UI behavior. This can cause your app to lose user input or fail to maintain state across rebuilds. {v4}',
    correctionMessage:
        'Create the GlobalKey as a class field (not inside build) to preserve widget state and ensure consistent behavior.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_GlobalKeyVisitor(reporter, code));
    });
  }
}

class _GlobalKeyVisitor extends RecursiveAstVisitor<void> {
  _GlobalKeyVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && typeName.contains('GlobalKey')) {
      reporter.atNode(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when setState() is called in a large State class.
///
/// Since: v4.13.0 | Rule version: v1
///
/// When a State class is large (many lines or members), calling setState()
/// triggers a rebuild of the entire widget subtree, which can be expensive.
/// Large State classes with setState() calls are candidates for:
/// - Breaking into smaller widgets
/// - Using more granular state management (ValueNotifier, etc.)
/// - Using const child widgets to minimize rebuild scope
///
/// Default thresholds:
/// - 200+ lines in the State class body
/// - 15+ member declarations (fields + methods)
///
/// **BAD:**
/// ```dart
/// class _MyPageState extends State<MyPage> {
///   // ... 200+ lines of code, many fields and methods ...
///
///   void _onTap() {
///     setState(() {
///       _counter++; // Rebuilds entire large widget tree
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     // ... complex widget tree ...
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Break into smaller widgets
/// class _MyPageState extends State<MyPage> {
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         const HeaderWidget(), // Won't rebuild
///         CounterWidget(), // Only this rebuilds
///         const FooterWidget(), // Won't rebuild
///       ],
///     );
///   }
/// }
///
/// // Option 2: Use ValueNotifier for granular updates
/// class _MyPageState extends State<MyPage> {
///   final _counter = ValueNotifier<int>(0);
///
///   void _onTap() {
///     _counter.value++; // Only ValueListenableBuilder rebuilds
///   }
/// }
/// ```
class AvoidSetStateInLargeStateClassRule extends SaropaLintRule {
  AvoidSetStateInLargeStateClassRule() : super(code: _code);

  /// Performance issue in large state classes. May require refactoring.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_setstate_in_large_state_class',
    '[avoid_setstate_in_large_state_class] setState() in a large State class causes expensive full rebuilds. '
        'Consider breaking into smaller widgets or using granular state. {v1}',
    correctionMessage:
        'Extract parts of this widget into smaller stateless/stateful widgets, '
        'or use ValueNotifier/ValueListenableBuilder for targeted rebuilds.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Threshold for number of lines in the State class body
  static const int _lineThreshold = 200;

  /// Threshold for number of member declarations
  static const int _memberThreshold = 15;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Measure class size
      final int lineCount = _countLines(node);
      final int memberCount = node.members.length;

      // Check if class is "large"
      final bool isLargeClass =
          lineCount >= _lineThreshold || memberCount >= _memberThreshold;

      if (!isLargeClass) return;

      // Find all setState calls in this class
      final _SetStateCallVisitor visitor = _SetStateCallVisitor();
      node.accept(visitor);

      // Report each setState call in the large class
      for (final MethodInvocation setStateCall in visitor.setStateCalls) {
        reporter.atNode(setStateCall);
      }
    });
  }

  int _countLines(ClassDeclaration node) {
    final String source = node.toSource();
    return '\n'.allMatches(source).length + 1;
  }
}

/// Visitor that finds setState() calls within a class.
class _SetStateCallVisitor extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> setStateCalls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      setStateCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

// ============================================================================
// Batch 17: Additional State Management Rules

/// Warns when mutable values are used in Provider Selector.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Selector values should be immutable to ensure proper comparisons.
///
/// **BAD:**
/// ```dart
/// Selector<Model, List<Item>>(
///   selector: (_, model) => model.items, // List is mutable
///   builder: (context, items, child) => ...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Selector<Model, int>(
///   selector: (_, model) => model.items.length, // Immutable value
///   builder: (context, count, child) => ...
/// )
/// ```
class PreferImmutableSelectorValueRule extends SaropaLintRule {
  PreferImmutableSelectorValueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_immutable_selector_value',
    '[prefer_immutable_selector_value] Selector uses mutable type that may cause incorrect rebuilds. Selector values must be immutable to ensure proper comparisons. Mutable values are used in Provider Selector. {v2}',
    correctionMessage:
        'Return an immutable value or use a primitive type. Verify the state updates correctly across all affected screens and edge cases.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _mutableTypes = <String>{'List', 'Map', 'Set'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'Selector') return;

      // Check type argument
      final TypeArgumentList? typeArgs =
          node.constructorName.type.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length < 2) return;

      final TypeAnnotation selectedType = typeArgs.arguments[1];
      final String typeSource = selectedType.toSource();

      for (final String mutableType in _mutableTypes) {
        if (typeSource.startsWith('$mutableType<')) {
          reporter.atNode(selectedType);
          return;
        }
      }
    });
  }
}

/// Warns when static mutable state is used.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: global_mutable_state, static_state_antipattern
///
/// Static mutable state causes issues with testing, hot reload, and
/// can lead to subtle bugs in concurrent scenarios.
///
/// **BAD:**
/// ```dart
/// class AppState {
///   static User? currentUser;  // Global mutable state!
///   static List<String> cache = [];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use proper state management:
/// final userProvider = StateProvider<User?>((ref) => null);
/// // Or dependency injection:
/// class AppState {
///   User? currentUser;  // Instance field, not static
/// }
/// ```
class AvoidStaticStateRule extends SaropaLintRule {
  AvoidStaticStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_static_state',
    '[avoid_static_state] Static mutable state persists across hot-reloads and tests, causing stale data and inconsistent behavior. Tests fail unpredictably due to shared state leaking between runs, and production bugs become hard to reproduce across different app sessions and isolates. {v4}',
    correctionMessage:
        'Replace static mutable fields with scoped state management (Provider, Riverpod, or Bloc) to ensure proper isolation across tests and hot-reloads.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Types known to be immutable after construction.
  static const Set<String> _knownImmutableTypes = <String>{
    'RegExp',
    'DateTime',
    'String',
    'int',
    'double',
    'num',
    'bool',
    'Duration',
    'Uri',
    'Type',
  };

  /// Returns true if the type annotation names a known-immutable type.
  static bool _isKnownImmutableType(String typeSource) {
    if (typeSource.isEmpty) return false;
    return _knownImmutableTypes.any(
      (String t) => typeSource == t || typeSource == '$t?',
    );
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (!node.isStatic) return;

      // Compile-time constants are never mutable state.
      if (node.fields.isConst) return;

      // Final fields with known-immutable types cannot be reassigned
      // and hold objects that never change after construction.
      if (node.fields.isFinal) {
        final String type = node.fields.type?.toSource() ?? '';
        if (_isKnownImmutableType(type)) return;

        // Also allow final fields with const initializers
        for (final VariableDeclaration variable in node.fields.variables) {
          final Expression? init = variable.initializer;
          if (init != null && init.toSource().startsWith('const ')) {
            return;
          }
        }
      }

      // Only flag non-final (truly mutable) static fields.
      if (!node.fields.isFinal) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_optimistic_updates
// =============================================================================

/// Warns when setState is called after an await expression.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Calling setState after an await makes the UI feel slow because the user
/// must wait for the async operation to complete before seeing any visual
/// feedback. Optimistic updates update local state immediately and sync
/// to the server in the background, providing a much snappier experience.
///
/// **BAD:**
/// ```dart
/// Future<void> _onLike() async {
///   await api.likePost(postId);
///   setState(() { isLiked = true; }); // User waits for network
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _onLike() async {
///   setState(() { isLiked = true; }); // Immediate feedback
///   try {
///     await api.likePost(postId);
///   } catch (_) {
///     setState(() { isLiked = false; }); // Rollback on failure
///   }
/// }
/// ```
class PreferOptimisticUpdatesRule extends SaropaLintRule {
  PreferOptimisticUpdatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => const <String>{'setState'};

  static const LintCode _code = LintCode(
    'prefer_optimistic_updates',
    '[prefer_optimistic_updates] setState called after an await '
        'expression. The UI will not update until the async operation '
        'completes, making the app feel slow and unresponsive. Consider '
        'updating the state optimistically before the await and rolling '
        'back on failure for a snappier user experience. {v1}',
    correctionMessage:
        'Move setState before the await and add a try-catch to rollback '
        'on failure.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only check async methods
      if (!node.isAbstract && node.body is! EmptyFunctionBody) {
        final FunctionBody body = node.body;
        if (body is! BlockFunctionBody) return;
        if (!body.isAsynchronous) return;

        _checkBlockForSetStateAfterAwait(body.block, reporter);
      }
    });
  }

  void _checkBlockForSetStateAfterAwait(
    Block block,
    SaropaDiagnosticReporter reporter,
  ) {
    bool seenAwait = false;

    for (final Statement stmt in block.statements) {
      // Check if this statement contains an await
      if (_containsAwait(stmt)) {
        seenAwait = true;
      }

      // Check if this statement is a setState call after an await
      if (seenAwait && _isSetStateCall(stmt)) {
        reporter.atNode(stmt);
      }
    }
  }

  bool _containsAwait(AstNode node) {
    if (node is AwaitExpression) return true;
    for (final AstNode child in node.childEntities.whereType<AstNode>()) {
      // Don't descend into nested function bodies
      if (child is FunctionBody || child is FunctionExpression) continue;
      if (_containsAwait(child)) return true;
    }
    return false;
  }

  bool _isSetStateCall(Statement stmt) {
    if (stmt is ExpressionStatement) {
      final Expression expr = stmt.expression;
      if (expr is MethodInvocation) {
        return expr.methodName.name == 'setState';
      }
    }
    return false;
  }
}

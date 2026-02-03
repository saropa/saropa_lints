// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// State management lint rules for Flutter/Dart applications.
///
/// These rules help identify common state management issues including
/// improper state updates, missing dispose calls, and anti-patterns
/// in state handling.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when ChangeNotifier subclass doesn't call notifyListeners.
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
  const RequireNotifyListenersRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_notify_listeners',
    problemMessage:
        '[require_notify_listeners] ChangeNotifier method modifies state properties but does not call notifyListeners(). Widgets listening to this notifier will not rebuild to reflect the updated state, displaying stale data to the user. This creates silent data synchronization bugs that are difficult to diagnose because the state appears correct in debug tools.',
    correctionMessage:
        'Add notifyListeners() as the last statement in every method that modifies observable state properties to trigger dependent widget rebuilds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
      MethodDeclaration method, SaropaDiagnosticReporter reporter) {
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
      reporter.atNode(method, code);
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
  const RequireStreamControllerDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_stream_controller_dispose',
    problemMessage:
        '[require_stream_controller_dispose] Not closing a StreamController in the StatefulWidget dispose method will leak memory, keep listeners active, and cause app slowdowns, crashes, or persistent background activity. This leads to stream subscription exhaustion, battery drain, and unpredictable bugs, especially in production apps with frequent widget tree rebuilds. Unclosed controllers also prevent garbage collection and block app updates.',
    correctionMessage:
        'Always call controller.close() in the dispose method of your widget or class to properly release resources and prevent memory leaks. Audit all StreamController usage for proper cleanup and add tests for resource management. Document disposal logic for maintainability.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForStreamControllerDisposeFix()];
}

class _ControllerField {
  final VariableDeclaration variable;
  final bool isWrapper;
  const _ControllerField(this.variable, this.isWrapper);
}

class _AddTodoForStreamControllerDisposeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for missing StreamController close',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: close this StreamController in dispose()\n',
        );
      });
    });
  }
}

/// Warns when ValueNotifier is used without dispose.
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
  const RequireValueNotifierDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_value_notifier_dispose',
    problemMessage:
        '[require_value_notifier_dispose] If you do not dispose a ValueNotifier, it will leak memory, keep listeners attached, and trigger updates on a StatefulWidget that has already been removed from the widget tree. This causes memory leaks, unexpected UI updates, and hard-to-find bugs in your app.',
    correctionMessage:
        'Call notifier.dispose() in the dispose method of your widget or class to properly release resources and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // Cached regex for performance
  static final RegExp _collectionPattern = RegExp(
    r'(List|Set|Iterable)<\s*(Safe)?ValueNotifier<',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
            reporter.atNode(variable, code);
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
  const RequireMountedCheckRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_mounted_check',
    problemMessage:
        '[require_mounted_check] Calling setState after an await without checking if the StatefulWidget is still mounted in the widget tree throws a "setState called after dispose" error. This leads to runtime exceptions, app instability, and hard-to-debug crashes, especially in async code.',
    correctionMessage:
        'Add "if (!mounted) return;" before calling setState after an await to ensure the widget is still in the widget tree and prevent runtime errors.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check if async method
      if (!node.body.isAsynchronous) return;

      // Check if in a State class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
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

  @override
  List<Fix> getFixes() => <Fix>[_AddMountedCheckFix()];
}

class _AddMountedCheckFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'setState') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add mounted check before setState',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          'if (!mounted) return;\n    ',
        );
      });
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
        reporter.atNode(node, code);
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
  const AvoidStatefulWithoutStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_without_state',
    problemMessage:
        '[avoid_stateful_without_state] Using a StatefulWidget without any state fields adds unnecessary complexity, increases lifecycle overhead, and can confuse maintainers. This leads to harder-to-read code, wasted memory allocations for the State object, and potential performance issues.',
    correctionMessage:
        'Convert the widget to a StatelessWidget if it does not manage any state. This simplifies your code and improves performance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToStatelessWidgetFix()];
}

/// Quick fix that adds a TODO comment suggesting conversion to StatelessWidget.
///
/// The fix adds a comment above the State class rather than performing an
/// automatic conversion because:
/// 1. The StatefulWidget class also needs to be converted/removed
/// 2. The conversion may require moving final fields to the widget class
/// 3. Automatic widget refactoring is complex and error-prone
class _ConvertToStatelessWidgetFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO to convert to StatelessWidget',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Convert to StatelessWidget - this State has no mutable state\n',
        );
      });
    });
  }
}

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
  const AvoidGlobalKeyInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_global_key_in_build',
    problemMessage:
        '[avoid_global_key_in_build] Creating a GlobalKey inside the build() method causes it to be recreated on every rebuild, which results in lost widget state, broken references, and unpredictable UI behavior. This can cause your app to lose user input or fail to maintain state across rebuilds.',
    correctionMessage:
        'Create the GlobalKey as a class field (not inside build) to preserve widget state and ensure consistent behavior.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_GlobalKeyVisitor(reporter, code));
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForGlobalKeyInBuildFix()];
}

class _AddTodoForGlobalKeyInBuildFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for GlobalKey in build',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: move this GlobalKey to a class field\n',
        );
      });
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
      reporter.atNode(node, code);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when setState() is called in a large State class.
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
  const AvoidSetStateInLargeStateClassRule() : super(code: _code);

  /// Performance issue in large state classes. May require refactoring.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_setstate_in_large_state_class',
    problemMessage:
        '[avoid_setstate_in_large_state_class] setState() in a large State class causes expensive full rebuilds. '
        'Consider breaking into smaller widgets or using granular state.',
    correctionMessage:
        'Extract parts of this widget into smaller stateless/stateful widgets, '
        'or use ValueNotifier/ValueListenableBuilder for targeted rebuilds.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Threshold for number of lines in the State class body
  static const int _lineThreshold = 200;

  /// Threshold for number of member declarations
  static const int _memberThreshold = 15;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(setStateCall, code);
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
  const PreferImmutableSelectorValueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_immutable_selector_value',
    problemMessage:
        '[prefer_immutable_selector_value] Selector uses mutable type that may cause incorrect rebuilds.',
    correctionMessage: 'Return an immutable value or use a primitive type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _mutableTypes = <String>{
    'List',
    'Map',
    'Set',
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
      if (typeName != 'Selector') return;

      // Check type argument
      final TypeArgumentList? typeArgs =
          node.constructorName.type.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length < 2) return;

      final TypeAnnotation selectedType = typeArgs.arguments[1];
      final String typeSource = selectedType.toSource();

      for (final String mutableType in _mutableTypes) {
        if (typeSource.startsWith('$mutableType<')) {
          reporter.atNode(selectedType, code);
          return;
        }
      }
    });
  }
}

/// Warns when static mutable state is used.
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
  const AvoidStaticStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_static_state',
    problemMessage:
        '[avoid_static_state] Static mutable state persists across hot-reloads and tests, causing stale data and inconsistent behavior. Tests fail unpredictably due to shared state leaking between runs, and production bugs become hard to reproduce across different app sessions and isolates.',
    correctionMessage:
        'Replace static mutable fields with scoped state management (Provider, Riverpod, or Bloc) to ensure proper isolation across tests and hot-reloads.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.isStatic) return;
      if (node.fields.isFinal && node.fields.isConst) return;

      // Skip if final with immutable initializer
      if (node.fields.isFinal) {
        for (final variable in node.fields.variables) {
          final init = variable.initializer;
          if (init != null) {
            final initSource = init.toSource();
            // Allow final static with const initializers
            if (initSource.startsWith('const ') ||
                initSource == 'true' ||
                initSource == 'false' ||
                RegExp(r'^[\d.]+$').hasMatch(initSource) ||
                initSource.startsWith("'") ||
                initSource.startsWith('"')) {
              return;
            }
          }
        }
      }

      // Check for mutable types
      final type = node.fields.type?.toSource() ?? '';
      final isMutableCollection = type.startsWith('List') ||
          type.startsWith('Map') ||
          type.startsWith('Set');

      // Non-final static or mutable collection
      if (!node.fields.isFinal || isMutableCollection) {
        reporter.atNode(node, code);
      }
    });
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// State management lint rules for Flutter/Dart applications.
///
/// These rules help identify common state management issues including
/// improper state updates, missing dispose calls, and anti-patterns
/// in state handling.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
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
        '[require_notify_listeners] ChangeNotifier method modifies state but does not call notifyListeners.',
    correctionMessage: 'Add notifyListeners() after state modifications.',
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

  void _checkMethod(MethodDeclaration method, SaropaDiagnosticReporter reporter) {
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
        '[require_stream_controller_dispose] If you do not close a StreamController in dispose, it will leak memory, keep listeners active, and may cause app slowdowns or crashes. Always close StreamControllers to prevent resource leaks and unexpected behavior after widget disposal.',
    correctionMessage:
        'Add controller.close() in the dispose method of your widget or class to properly release resources and prevent memory leaks.',
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

      // Find StreamController fields
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName != null && typeName.contains('StreamController')) {
              controllerNames.add(variable.name.lexeme);
            }
            // Also check initializers
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String? initTypeName = initializer.constructorName.type.element?.name;
              if (initTypeName == 'StreamController') {
                controllerNames.add(variable.name.lexeme);
              }
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      // Find dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Check if controllers are closed in dispose
      final Set<String> closedControllers = <String>{};
      if (disposeMethod != null) {
        disposeMethod.body.visitChildren(
          _CloseCallVisitor((String name) => closedControllers.add(name)),
        );
      }

      // Report unclosed controllers
      for (final String name in controllerNames) {
        if (!closedControllers.contains(name)) {
          // Find the field to report on
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTodoForStreamControllerDisposeFix()];
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

class _CloseCallVisitor extends RecursiveAstVisitor<void> {
  _CloseCallVisitor(this.onClose);

  final void Function(String) onClose;

  /// Methods that close/cleanup resources (including *Safe extension variants).
  static const Set<String> _closeMethodNames = <String>{
    'close',
    'closeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_closeMethodNames.contains(node.methodName.name)) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        onClose(target.name);
      }
    }
    super.visitMethodInvocation(node);
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
        '[require_value_notifier_dispose] If you do not dispose a ValueNotifier, it will leak memory, keep listeners attached, and may update widgets that have already been disposed. This can cause memory leaks, unexpected UI updates, and hard-to-find bugs in your app.',
    correctionMessage:
        'Call notifier.dispose() in the dispose method of your widget or class to properly release resources and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
              final String? initTypeName = initializer.constructorName.type.element?.name;
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
    final collectionPattern = RegExp(
      r'(List|Set|Iterable)<\s*(Safe)?ValueNotifier<',
    );
    return collectionPattern.hasMatch(typeName);
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
        '[require_mounted_check] Calling setState after an await without checking if the widget is still mounted can throw a "setState called after dispose" error. This leads to runtime exceptions, app instability, and hard-to-debug crashes, especially in async code.',
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
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
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

/// Warns when Provider is watched unnecessarily in callbacks.
///
/// Using watch in callbacks causes unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// onPressed: () {
///   final count = context.watch<Counter>().value;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPressed: () {
///   final count = context.read<Counter>().value;
/// }
/// ```
class AvoidWatchInCallbacksRule extends SaropaLintRule {
  const AvoidWatchInCallbacksRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_watch_in_callbacks',
    problemMessage:
        '[avoid_watch_in_callbacks] Using watch in callbacks (like onPressed or onTap) creates new subscriptions on every call, leading to memory leaks, redundant widget rebuilds, and degraded app performance. This can cause your app to slow down or even crash over time.',
    correctionMessage:
        'Use ref.read instead of ref.watch in event handlers and callbacks to avoid creating unnecessary subscriptions and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'watch') return;

      // Check if inside a callback (FunctionExpression in ArgumentList)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) {
          final AstNode? funcParent = current.parent;
          if (funcParent is ArgumentList || funcParent is NamedExpression) {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when BLoC events are emitted in constructor.
///
/// Events should not be added during BLoC construction.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(Initial()) {
///     add(LoadEvent()); // Anti-pattern
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(Initial());
/// }
/// // Add event from outside: bloc.add(LoadEvent());
/// ```
class AvoidBlocEventInConstructorRule extends SaropaLintRule {
  const AvoidBlocEventInConstructorRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_in_constructor',
    problemMessage:
        '[avoid_bloc_event_in_constructor] Adding a BLoC event in the constructor runs it before listeners are attached, causing missed state updates and unpredictable app behavior. This can result in lost events, bugs that are hard to trace, and inconsistent UI state.',
    correctionMessage:
        'Dispatch initial events from the widget that creates the BLoC, not from the BLoC constructor, to ensure all listeners are attached and receive the event.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Check if in a Bloc class
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Bloc') && !superName.contains('Cubit')) return;

      // Check for add() calls in constructor body
      final FunctionBody body = node.body;
      body.visitChildren(_AddCallVisitor(reporter, code));
    });
  }
}

class _AddCallVisitor extends RecursiveAstVisitor<void> {
  _AddCallVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'add') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when InheritedWidget is used without updateShouldNotify.
///
/// Missing updateShouldNotify causes unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// class MyData extends InheritedWidget {
///   // Missing updateShouldNotify
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyData extends InheritedWidget {
///   @override
///   bool updateShouldNotify(MyData oldWidget) {
///     return data != oldWidget.data;
///   }
/// }
/// ```
class RequireUpdateShouldNotifyRule extends SaropaLintRule {
  const RequireUpdateShouldNotifyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_update_should_notify',
    problemMessage:
        '[require_update_should_notify] If an InheritedWidget does not override updateShouldNotify, all dependents rebuild on every change, causing unnecessary rebuilds, degraded performance, and battery drain. This can make your app slow and unresponsive.',
    correctionMessage:
        'Override updateShouldNotify in your InheritedWidget to control when dependents rebuild and optimize app performance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends InheritedWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('InheritedWidget') &&
          !superName.contains('InheritedNotifier') &&
          !superName.contains('InheritedModel')) {
        return;
      }

      // Check for updateShouldNotify method
      bool hasUpdateShouldNotify = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'updateShouldNotify') {
          hasUpdateShouldNotify = true;
          break;
        }
      }

      if (!hasUpdateShouldNotify) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Riverpod providers are not properly scoped.
///
/// Global providers can cause state leaks between tests.
///
/// **BAD:**
/// ```dart
/// final myProvider = StateProvider((ref) => 0);
/// // Global scope
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use ProviderScope for proper scoping
/// ProviderScope(
///   overrides: [myProvider.overrideWith(...)],
///   child: MyApp(),
/// )
/// ```
class AvoidGlobalRiverpodProvidersRule extends SaropaLintRule {
  const AvoidGlobalRiverpodProvidersRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_global_riverpod_providers',
    problemMessage:
        '[avoid_global_riverpod_providers] Defining providers at the global scope creates implicit dependencies, makes testing difficult, and can cause state to leak between tests or app sessions. This leads to flaky tests, unpredictable bugs, and hard-to-maintain code.',
    correctionMessage:
        'Define providers inside a ProviderScope or document their scope clearly to ensure test isolation and predictable state management.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'StateProvider',
    'StateNotifierProvider',
    'ChangeNotifierProvider',
    'FutureProvider',
    'StreamProvider',
    'NotifierProvider',
    'AsyncNotifierProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer is MethodInvocation) {
          // Check for provider creation
          final String methodName = initializer.methodName.name;
          if (_providerTypes.any((String t) => methodName.contains(t))) {
            reporter.atNode(variable, code);
          }
        }
        if (initializer is InstanceCreationExpression) {
          final String? typeName = initializer.constructorName.type.element?.name;
          if (typeName != null && _providerTypes.contains(typeName)) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}

/// Warns when StatefulWidget has no state.
///
/// Stateless widgets are more efficient when no state is needed.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
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
        '[avoid_stateful_without_state] Using a StatefulWidget without any state fields adds unnecessary complexity, increases lifecycle overhead, and can confuse maintainers. This leads to harder-to-read code, wasted resources, and potential performance issues.',
    correctionMessage:
        'Convert the widget to a StatelessWidget if it does not manage any state. This simplifies your code and improves performance.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
        }
      }

      if (!hasState && !hasLifecycleMethods) {
        reporter.atNode(node, code);
      }
    });
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

/// Requires Bloc/Cubit fields to be closed in dispose.
///
/// Bloc and Cubit instances created in a State class must be closed when
/// the widget is disposed to prevent memory leaks and cancel active
/// stream subscriptions.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _counterBloc = CounterBloc();
///   // Missing close - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _counterBloc = CounterBloc();
///
///   @override
///   void dispose() {
///     _counterBloc.close();
///     super.dispose();
///   }
/// }
/// ```
///
/// Note: Blocs provided via BlocProvider or dependency injection
/// are typically managed externally and don't need to be closed here.
class RequireBlocCloseRule extends SaropaLintRule {
  const RequireBlocCloseRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_close',
    problemMessage:
        '[require_bloc_close] If you do not close your Bloc or Cubit in dispose(), it will leak memory, keep listeners active, and may cause app slowdowns or crashes. Always close Blocs and Cubits to prevent resource leaks and unexpected behavior after widget disposal.',
    correctionMessage:
        'Add _bloc.close() (or cubit.close()) in the dispose() method before calling super.dispose() to properly release resources and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
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

      // Must be exactly "State" with type argument
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find Bloc/Cubit fields that are CREATED locally (have initializers)
      // Fields without initializers are typically injected and managed elsewhere
      final List<String> blocNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            // Only check fields with initializers (locally created)
            final Expression? initializer = variable.initializer;
            if (initializer == null) continue;

            final String? typeName = member.fields.type?.toSource();
            if (typeName != null &&
                (typeName.endsWith('Bloc') ||
                    typeName.endsWith('Cubit') ||
                    typeName.contains('Bloc<') ||
                    typeName.contains('Cubit<'))) {
              blocNames.add(variable.name.lexeme);
              continue;
            }

            // Check initializer type
            if (initializer is InstanceCreationExpression) {
              final String initType = initializer.constructorName.type.name.lexeme;
              if (initType.endsWith('Bloc') || initType.endsWith('Cubit')) {
                if (!blocNames.contains(variable.name.lexeme)) {
                  blocNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (blocNames.isEmpty) return;

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each bloc is closed
      for (final String name in blocNames) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$name.close(') ||
                disposeBody.contains('$name?.close(') ||
                disposeBody.contains('$name.closeSafe(') ||
                disposeBody.contains('$name?.closeSafe(') ||
                disposeBody.contains('$name..close('));

        if (!isClosed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddBlocCloseFix()];
}

class _AddBlocCloseFix extends DartFix {
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

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert close() call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.close()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.close();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method
        int insertOffset = classNode.rightBracket.offset;

        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.close()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.close();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Suggests using ConsumerWidget instead of Consumer.
///
/// ConsumerWidget provides a cleaner API than wrapping your build
/// method with Consumer widget. It's the recommended approach in Riverpod.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Consumer(
///       builder: (context, ref, child) {
///         final value = ref.watch(myProvider);
///         return Text(value);
///       },
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final value = ref.watch(myProvider);
///     return Text(value);
///   }
/// }
/// ```
class PreferConsumerWidgetRule extends SaropaLintRule {
  const PreferConsumerWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_consumer_widget',
    problemMessage:
        '[prefer_consumer_widget] Wrapping widgets with Consumer adds unnecessary nesting and boilerplate, making code harder to read and maintain. Using ConsumerWidget provides ref directly, resulting in cleaner, more maintainable code and fewer widget rebuilds.',
    correctionMessage:
        'Extend ConsumerWidget instead of wrapping with Consumer to simplify your widget tree and improve code clarity.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Consumer') return;

      // Check if this Consumer is the root of a build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ReturnStatement) {
          final AstNode? returnParent = current.parent;
          if (returnParent is Block) {
            final AstNode? blockParent = returnParent.parent;
            if (blockParent is BlockFunctionBody) {
              final AstNode? bodyParent = blockParent.parent;
              if (bodyParent is MethodDeclaration && bodyParent.name.lexeme == 'build') {
                reporter.atNode(node, code);
                return;
              }
            }
          }
        }
        // Also check for expression body: Widget build(...) => Consumer(...)
        if (current is ExpressionFunctionBody) {
          final AstNode? bodyParent = current.parent;
          if (bodyParent is MethodDeclaration && bodyParent.name.lexeme == 'build') {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Suggests using autoDispose modifier on Riverpod providers.
///
/// Providers without autoDispose will stay in memory forever once created.
/// Using autoDispose ensures the provider is disposed when no longer watched.
///
/// **BAD:**
/// ```dart
/// final myProvider = StateProvider<int>((ref) => 0);
/// ```
///
/// **GOOD:**
/// ```dart
/// final myProvider = StateProvider.autoDispose<int>((ref) => 0);
/// // Or with @riverpod annotation:
/// @riverpod
/// class MyNotifier extends _$MyNotifier { ... }
/// ```
class RequireAutoDisposeRule extends SaropaLintRule {
  const RequireAutoDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_auto_dispose',
    problemMessage:
        '[require_auto_dispose] Not using autoDispose with Riverpod providers can cause memory leaks, as providers and their resources may remain in memory after they are no longer needed. This can lead to increased memory usage and degraded app performance.',
    correctionMessage:
        'Use Provider.autoDispose, StateProvider.autoDispose, etc., to ensure providers are disposed when no longer needed and prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'StateProvider',
    'FutureProvider',
    'StreamProvider',
    'NotifierProvider',
    'AsyncNotifierProvider',
    'StateNotifierProvider',
    'ChangeNotifierProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;

        // Handle method invocations like Provider.family(...) or Provider.autoDispose(...)
        if (initializer is MethodInvocation) {
          final String methodName = initializer.methodName.name;
          final Expression? target = initializer.target;

          // Skip if already using autoDispose
          if (methodName == 'autoDispose') continue;

          // Check if target is a provider type (e.g., Provider.family)
          if (target is SimpleIdentifier) {
            final String targetName = target.name;
            if (_providerTypes.contains(targetName)) {
              // It's a provider modifier (like .family) without autoDispose
              reporter.atNode(variable, code);
            }
          }
        }

        // Handle direct construction like StateProvider<int>((ref) => 0)
        if (initializer is InstanceCreationExpression) {
          final String typeName = initializer.constructorName.type.name.lexeme;
          final String? constructorName = initializer.constructorName.name?.name;

          // Check if it's a provider without autoDispose
          if (_providerTypes.contains(typeName)) {
            // Check if it uses autoDispose constructor
            if (constructorName != 'autoDispose' && !typeName.contains('AutoDispose')) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when ref.read() is used inside a build() method body.
///
/// In Riverpod, ref.read() doesn't set up reactivity - it reads the value once.
/// Using ref.read() in build() means the widget won't rebuild when the provider
/// changes. Use ref.watch() instead for reactive updates.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final count = ref.read(counterProvider); // Won't rebuild on changes!
///     return Text('Count: $count');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final count = ref.watch(counterProvider); // Rebuilds on changes
///     return Text('Count: $count');
///   }
/// }
/// ```
///
/// **Note:** ref.read() is correct in callbacks (onPressed, etc.) where you
/// want the current value without rebuilding.
class AvoidRefInBuildBodyRule extends SaropaLintRule {
  const AvoidRefInBuildBodyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_ref_in_build_body',
    problemMessage:
        '[avoid_ref_in_build_body] Using ref.read() in build() does not trigger widget rebuilds when the provider changes, leading to stale UI, missed updates, and confusing bugs. This breaks the reactive model of Riverpod and can cause your app to display outdated information.',
    correctionMessage:
        'Use ref.watch() for reactive updates in build(), or move ref.read() to a callback like onPressed to ensure the UI updates correctly.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      // Visit the method body to find ref.read() calls
      node.body.visitChildren(_RefReadVisitor(reporter, code));
    });
  }
}

/// Visitor that finds ref.read() calls in build method bodies.
class _RefReadVisitor extends RecursiveAstVisitor<void> {
  _RefReadVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  /// Track depth inside callbacks where ref.read() is OK
  int _callbackDepth = 0;

  /// Names of callback parameters where ref.read() is acceptable.
  ///
  /// These are event handlers and Future callbacks where ref.read() is correct
  /// because you want the value at the time of the event, not reactive updates.
  static const Set<String> _callbackMethods = <String>{
    // Button/gesture callbacks
    'onPressed',
    'onTap',
    'onLongPress',
    'onDoubleTap',
    'onPanUpdate',
    'onDragEnd',
    // Form/input callbacks
    'onChanged',
    'onSubmitted',
    'onSaved',
    'onEditingComplete',
    'onFieldSubmitted',
    // Navigation/animation callbacks
    'onDismissed',
    'onEnd',
    'onStatusChanged',
    'onComplete',
    // Future/async callbacks
    'then',
    'catchError',
    'whenComplete',
    'onError',
    // Stream callbacks
    'listen',
    'add',
    'addError',
    // Lifecycle callbacks
    'addPostFrameCallback',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // Check if entering a callback context
    if (_callbackMethods.contains(methodName)) {
      _callbackDepth++;
      super.visitMethodInvocation(node);
      _callbackDepth--;
      return;
    }

    // Check for ref.read() outside callbacks
    if (methodName == 'read' && _callbackDepth == 0) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'ref') {
        reporter.atNode(node, code);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Function expressions in callbacks are OK for ref.read()
    // Only increment if parent is a callback argument
    final AstNode? parent = node.parent;
    if (parent is NamedExpression && _callbackMethods.contains(parent.name.label.name)) {
      _callbackDepth++;
      super.visitFunctionExpression(node);
      _callbackDepth--;
      return;
    }

    super.visitFunctionExpression(node);
  }
}

/// Warns when BLoC state classes are not immutable.
///
/// BLoC pattern relies on comparing old and new states to determine if the UI
/// should rebuild. Mutable state classes can lead to subtle bugs where state
/// changes aren't detected because the same object instance is being compared.
///
/// **BAD:**
/// ```dart
/// class CounterState {
///   int count;
///   CounterState({this.count = 0});
/// }
/// ```
///
/// **GOOD (with @immutable):**
/// ```dart
/// @immutable
/// class CounterState {
///   final int count;
///   const CounterState({this.count = 0});
/// }
/// ```
///
/// **GOOD (with Equatable):**
/// ```dart
/// class CounterState extends Equatable {
///   final int count;
///   const CounterState({this.count = 0});
///
///   @override
///   List<Object?> get props => [count];
/// }
/// ```
class RequireImmutableBlocStateRule extends SaropaLintRule {
  const RequireImmutableBlocStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_immutable_bloc_state',
    problemMessage:
        '[require_immutable_bloc_state] If your BLoC state is mutable, it causes unpredictable UI updates, breaks state comparison, and leads to missed widget rebuilds. This results in subtle bugs, inconsistent UI, and hard-to-maintain code.',
    correctionMessage:
        'Add the @immutable annotation or extend Equatable to ensure your BLoC state is immutable and supports proper equality comparisons. This guarantees reliable UI updates and easier debugging.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if class name ends with 'State' (BLoC convention)
      if (!className.endsWith('State')) return;

      // Skip abstract classes
      if (node.abstractKeyword != null) return;

      // Skip if it's a Flutter State (extends State<T>)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'State') return; // Flutter State class
      }

      // Check for @immutable annotation
      bool hasImmutable = false;
      for (final Annotation annotation in node.metadata) {
        final String annotationName = annotation.name.name;
        if (annotationName == 'immutable') {
          hasImmutable = true;
          break;
        }
      }

      // Check for Equatable in extends clause
      bool hasEquatable = false;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'Equatable' ||
            superName.contains('Equatable') ||
            superName == 'BlocState') {
          hasEquatable = true;
        }
      }

      // Check for Equatable in with clause (mixin)
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          final String mixinName = mixin.name.lexeme;
          if (mixinName == 'EquatableMixin' || mixinName.contains('Equatable')) {
            hasEquatable = true;
            break;
          }
        }
      }

      // Check for Equatable in implements clause
      final ImplementsClause? implementsClause = node.implementsClause;
      if (implementsClause != null) {
        for (final NamedType interface in implementsClause.interfaces) {
          final String interfaceName = interface.name.lexeme;
          if (interfaceName.contains('Equatable')) {
            hasEquatable = true;
            break;
          }
        }
      }

      if (!hasImmutable && !hasEquatable) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when Provider.of is used inside build() without listen: false.
///
/// Using Provider.of(context) in build() with listen: true (default) causes
/// the widget to rebuild whenever the provider changes. If you only need
/// the value once without rebuilding, use listen: false or context.read().
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final user = Provider.of<User>(context); // Rebuilds on every change
///   return ElevatedButton(
///     onPressed: () => user.logout(),
///     child: Text('Logout'),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ElevatedButton(
///     onPressed: () => context.read<User>().logout(),
///     child: Text('Logout'),
///   );
/// }
/// // Or if you need reactive updates:
/// Widget build(BuildContext context) {
///   final userName = context.watch<User>().name;
///   return Text(userName);
/// }
/// ```
class AvoidProviderOfInBuildRule extends SaropaLintRule {
  const AvoidProviderOfInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_provider_of_in_build',
    problemMessage:
        '[avoid_provider_of_in_build] Using Provider.of in build() causes the widget to rebuild every time the provider changes, which can lead to performance issues and unnecessary UI updates. This can make your app less efficient and harder to maintain.',
    correctionMessage:
        'Use context.watch() for reactive UI updates, or context.read() in callbacks (like onPressed) to avoid unnecessary rebuilds and improve performance.',
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

      node.body.visitChildren(_ProviderOfVisitor(reporter, code));
    });
  }
}

class _ProviderOfVisitor extends RecursiveAstVisitor<void> {
  _ProviderOfVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for Provider.of(context) pattern
    final String methodName = node.methodName.name;
    if (methodName != 'of') {
      super.visitMethodInvocation(node);
      return;
    }

    final Expression? target = node.target;
    if (target is! SimpleIdentifier || target.name != 'Provider') {
      super.visitMethodInvocation(node);
      return;
    }

    // Check if listen: false is specified
    bool hasListenFalse = false;
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'listen') {
        if (arg.expression is BooleanLiteral) {
          hasListenFalse = !(arg.expression as BooleanLiteral).value;
        }
      }
    }

    if (!hasListenFalse) {
      reporter.atNode(node, code);
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when Get.find() is used inside build() method.
///
/// Get.find() in build() fetches the controller on every rebuild. If the
/// controller doesn't exist, it throws an error. Use GetBuilder or Obx
/// for reactive updates instead.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final controller = Get.find<MyController>(); // Called on every rebuild
///   return Text(controller.value.toString());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return GetBuilder<MyController>(
///     builder: (controller) => Text(controller.value.toString()),
///   );
/// }
/// // Or with Obx:
/// Widget build(BuildContext context) {
///   return Obx(() => Text(controller.value.toString()));
/// }
/// ```
class AvoidGetFindInBuildRule extends SaropaLintRule {
  const AvoidGetFindInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_get_find_in_build',
    problemMessage:
        '[avoid_get_find_in_build] Calling Get.find() inside build() is inefficient and can cause unnecessary object creation and performance issues. This leads to wasted resources and can make your app less responsive.',
    correctionMessage:
        'Use GetBuilder<T> or Obx for reactive updates with GetX, and avoid calling Get.find() in build() to improve performance.',
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

      node.body.visitChildren(_GetFindVisitor(reporter, code));
    });
  }
}

class _GetFindVisitor extends RecursiveAstVisitor<void> {
  _GetFindVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName != 'find') {
      super.visitMethodInvocation(node);
      return;
    }

    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'Get') {
      reporter.atNode(node, code);
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when ChangeNotifier or Provider is created inside build().
///
/// Creating providers inside build() creates new instances on every rebuild,
/// losing state and causing performance issues. Providers should be created
/// once and reused.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ChangeNotifierProvider(
///     create: (_) => MyNotifier(), // New instance on every rebuild!
///     child: MyWidget(),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Create providers above the widget that rebuilds
/// class MyApp extends StatelessWidget {
///   Widget build(BuildContext context) {
///     return ChangeNotifierProvider(
///       create: (_) => MyNotifier(),
///       child: MaterialApp(...),
///     );
///   }
/// }
/// ```
class AvoidProviderRecreateRule extends SaropaLintRule {
  const AvoidProviderRecreateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_provider_recreate',
    problemMessage:
        '[avoid_provider_recreate] Creating a Provider inside a frequently rebuilding build() method causes the provider to be recreated, losing its state and causing unexpected behavior. This can result in lost user input, bugs, and degraded app performance.',
    correctionMessage:
        'Move Provider creation to a parent widget that does not rebuild often to preserve provider state and ensure consistent behavior.',
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

      // Check if this is a StatefulWidget's State class
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      // Only warn in State classes (frequent rebuilds via setState)
      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      node.body.visitChildren(_ProviderRecreateVisitor(reporter, code));
    });
  }
}

class _ProviderRecreateVisitor extends RecursiveAstVisitor<void> {
  _ProviderRecreateVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  static const Set<String> _providerWidgets = <String>{
    'ChangeNotifierProvider',
    'Provider',
    'FutureProvider',
    'StreamProvider',
    'StateNotifierProvider',
    'BlocProvider',
    'RepositoryProvider',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && _providerWidgets.contains(typeName)) {
      reporter.atNode(node.constructorName, code);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when Bloc is used for simple state that could use Cubit.
///
/// Cubit is simpler than Bloc for straightforward state changes.
/// If your Bloc only has 1-2 events with simple handlers, use Cubit.
///
/// **BAD:**
/// ```dart
/// // Overly complex for simple counter
/// abstract class CounterEvent {}
/// class IncrementPressed extends CounterEvent {}
///
/// class CounterBloc extends Bloc<CounterEvent, int> {
///   CounterBloc() : super(0) {
///     on<IncrementPressed>((event, emit) => emit(state + 1));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(state + 1);
/// }
/// ```
class PreferCubitForSimpleRule extends SaropaLintRule {
  const PreferCubitForSimpleRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_cubit_for_simple',
    problemMessage:
        '[prefer_cubit_for_simple] Using Bloc for simple state management with few events adds unnecessary boilerplate, indirection, and makes code harder to maintain. This can slow down development and introduce avoidable complexity.',
    correctionMessage:
        'Use Cubit for straightforward state management. Reserve Bloc for cases with complex event handling or multiple event types.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Count event handlers (on<Event> calls)
      final String classSource = node.toSource();

      // Count on<EventType> registrations
      final RegExp onPattern = RegExp(r'on<\w+>');
      final int eventCount = onPattern.allMatches(classSource).length;

      // If only 1-2 simple events, suggest Cubit
      if (eventCount <= 2) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when ref is used in dispose method.
///
/// The `ref` object in Riverpod becomes invalid during dispose - providers
/// may already be destroyed. Accessing ref in dispose can throw exceptions
/// or access stale data.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends ConsumerState<MyWidget> {
///   @override
///   void dispose() {
///     ref.read(someProvider); // Invalid! Provider may be disposed
///     super.dispose();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends ConsumerState<MyWidget> {
///   @override
///   void dispose() {
///     // Clean up local resources only
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class AvoidRefInDisposeRule extends SaropaLintRule {
  const AvoidRefInDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_ref_in_dispose',
    problemMessage:
        '[avoid_ref_in_dispose] Using ref in dispose() is unsafe because the provider may already be destroyed, leading to runtime errors, crashes, or accessing invalid state. This can cause unpredictable bugs and app instability.',
    correctionMessage:
        'Remove ref usage from dispose(). Access provider values earlier in the widget lifecycle if needed to ensure safe and predictable behavior.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'dispose') return;

      // Check if this is in a ConsumerState class
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      // ConsumerState, ConsumerStatefulWidget state
      if (!superName.contains('ConsumerState') && superName != 'State') return;

      // Look for ref.read(), ref.watch(), ref.listen() in dispose
      node.body.visitChildren(_RefInDisposeVisitor(reporter, code));
    });
  }
}

class _RefInDisposeVisitor extends RecursiveAstVisitor<void> {
  _RefInDisposeVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'ref') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when ProviderScope is missing from the app root.
///
/// Riverpod requires ProviderScope at the widget tree root. Without it,
/// all provider access throws "ProviderScope not found" errors at runtime.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyApp()); // Missing ProviderScope!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   runApp(
///     ProviderScope(
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class RequireProviderScopeRule extends SaropaLintRule {
  const RequireProviderScopeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_provider_scope',
    problemMessage:
        '[require_provider_scope] If your Riverpod app is missing ProviderScope at the root, any attempt to access providers will throw runtime exceptions and crash the app. This makes the app unusable and breaks all provider-based state management.',
    correctionMessage:
        'Wrap your app with ProviderScope: runApp(ProviderScope(child: MyApp())) to enable provider access and prevent crashes.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Check if using Riverpod (has ConsumerWidget, ref.watch, etc.)
      final bool usesRiverpod = bodySource.contains('Consumer') ||
          bodySource.contains('ref.watch') ||
          bodySource.contains('ref.read');

      // Also check the whole file for Riverpod patterns
      final CompilationUnit? unit = node.thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) return;

      final String fileSource = unit.toSource();
      final bool fileUsesRiverpod = fileSource.contains('ConsumerWidget') ||
          fileSource.contains('ConsumerStatefulWidget') ||
          fileSource.contains('ProviderScope') ||
          fileSource.contains('flutter_riverpod');

      if (!usesRiverpod && !fileUsesRiverpod) return;

      // Check if ProviderScope is present
      if (!bodySource.contains('ProviderScope')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when using ref.watch() for entire provider when only part is needed.
///
/// Watching an entire object rebuilds when any field changes. Use
/// ref.watch(provider.select((s) => s.field)) to rebuild only when
/// specific fields change, improving performance.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final user = ref.watch(userProvider); // Rebuilds on any user change
///   return Text(user.name); // Only uses name!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final name = ref.watch(userProvider.select((u) => u.name));
///   return Text(name); // Only rebuilds when name changes
/// }
/// ```
class PreferSelectForPartialRule extends SaropaLintRule {
  const PreferSelectForPartialRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_select_for_partial',
    problemMessage:
        '[prefer_select_for_partial] Watching the entire provider when only one field is needed causes unnecessary widget rebuilds, wasting resources and reducing app performance. This can make your UI less efficient and responsive.',
    correctionMessage:
        'Use ref.watch(provider.select((s) => s.field)) for partial watching to optimize rebuilds and improve performance.',
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

      // Collect watched providers and how they're used
      final Map<String, Set<String>> providerUsage = <String, Set<String>>{};
      final Map<String, MethodInvocation> watchCalls = <String, MethodInvocation>{};

      node.body.visitChildren(
        _ProviderUsageVisitor(
          onWatch: (String name, MethodInvocation call) {
            providerUsage.putIfAbsent(name, () => <String>{});
            watchCalls[name] = call;
          },
          onPropertyAccess: (String name, String property) {
            providerUsage[name]?.add(property);
          },
        ),
      );

      // Report providers that are watched but only one property is used
      for (final MapEntry<String, Set<String>> entry in providerUsage.entries) {
        // If watched and only 1-2 properties accessed, suggest select
        if (entry.value.isNotEmpty && entry.value.length <= 2) {
          final MethodInvocation? call = watchCalls[entry.key];
          if (call != null) {
            // Check if already using select
            final String callSource = call.toSource();
            if (!callSource.contains('.select(')) {
              reporter.atNode(call, code);
            }
          }
        }
      }
    });
  }
}

class _ProviderUsageVisitor extends RecursiveAstVisitor<void> {
  _ProviderUsageVisitor({
    required this.onWatch,
    required this.onPropertyAccess,
  });

  final void Function(String name, MethodInvocation call) onWatch;
  final void Function(String name, String property) onPropertyAccess;

  final Map<String, String> _watchedVariables = <String, String>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final Expression? initializer = node.initializer;
    if (initializer is MethodInvocation) {
      if (initializer.methodName.name == 'watch') {
        final Expression? target = initializer.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          // Track: final user = ref.watch(userProvider);
          final String varName = node.name.lexeme;
          final ArgumentList args = initializer.argumentList;
          if (args.arguments.isNotEmpty) {
            final String providerName = args.arguments.first.toSource();
            _watchedVariables[varName] = providerName;
            onWatch(providerName, initializer);
          }
        }
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Track: user.name
    final String prefix = node.prefix.name;
    final String property = node.identifier.name;

    // Check if prefix is a watched variable
    final String? providerName = _watchedVariables[prefix];
    if (providerName != null) {
      onPropertyAccess(providerName, property);
    }

    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when Riverpod provider is declared inside a widget class.
///
/// Declaring providers inside widget classes makes them instance-specific
/// and breaks Riverpod's global state model. Providers should be declared
/// at file level as top-level variables.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   final myProvider = StateProvider<int>((ref) => 0); // Wrong!
///
///   Widget build(BuildContext context, WidgetRef ref) {
///     return Text(ref.watch(myProvider).toString());
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final myProvider = StateProvider<int>((ref) => 0);
///
/// class MyWidget extends ConsumerWidget {
///   Widget build(BuildContext context, WidgetRef ref) {
///     return Text(ref.watch(myProvider).toString());
///   }
/// }
/// ```
class AvoidProviderInWidgetRule extends SaropaLintRule {
  const AvoidProviderInWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_provider_in_widget',
    problemMessage:
        '[avoid_provider_in_widget] Declaring a provider inside a widget class breaks Riverpod\'s global state model, leading to multiple provider instances, lost state, and unpredictable bugs. This can make your app behave inconsistently and is hard to debug.',
    correctionMessage:
        'Move provider declaration to the file level as a top-level final variable to ensure a single, consistent provider instance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'StateProvider',
    'FutureProvider',
    'StreamProvider',
    'NotifierProvider',
    'AsyncNotifierProvider',
    'StateNotifierProvider',
    'ChangeNotifierProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check if inside a class
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      // Check each field
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        bool isProvider = false;

        if (initializer is InstanceCreationExpression) {
          final String typeName = initializer.constructorName.type.name.lexeme;
          isProvider = _providerTypes.contains(typeName);
        }

        if (initializer is MethodInvocation) {
          final Expression? target = initializer.target;
          if (target is SimpleIdentifier) {
            isProvider = _providerTypes.contains(target.name);
          }
        }

        if (isProvider) {
          reporter.atNode(variable, code);
        }
      }
    });
  }
}

/// Warns when ref.watch is used with .family without proper parameter.
///
/// When using .family providers, you must pass the parameter to get the
/// correct provider instance. Forgetting the parameter or passing the
/// wrong one creates a new provider instance unexpectedly.
///
/// **BAD:**
/// ```dart
/// // Missing family parameter
/// final user = ref.watch(userProvider); // Error or wrong instance!
/// ```
///
/// **GOOD:**
/// ```dart
/// final user = ref.watch(userProvider(userId));
/// ```
class PreferFamilyForParamsRule extends SaropaLintRule {
  const PreferFamilyForParamsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_family_for_params',
    problemMessage:
        '[prefer_family_for_params] Not using .family for parameterized providers creates a new provider instance on each call, breaking caching and causing duplicate providers. This leads to wasted resources, memory leaks, and unpredictable app behavior.',
    correctionMessage:
        'Use Provider.family((ref, param) => ...) and watch with provider(param) to ensure proper caching and a single provider instance per parameter.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Check if it's a provider type
      if (!typeName.contains('Provider')) return;

      // Check if the create callback takes extra parameters beyond ref
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! FunctionExpression) return;

      final FormalParameterList? params = firstArg.parameters;
      if (params == null) return;

      // If callback has more than 1 parameter (ref + something else),
      // suggest using .family
      if (params.parameters.length > 1) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when BlocProvider is used without a BlocObserver setup.
///
/// BlocObserver provides centralized logging and error handling for all
/// Blocs. Without it, state changes and errors may go untracked.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(
///     BlocProvider(
///       create: (_) => AuthBloc(),
///       child: MyApp(),
///     ),
///   );
///   // No BlocObserver - no centralized logging!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   Bloc.observer = AppBlocObserver();
///   runApp(
///     BlocProvider(
///       create: (_) => AuthBloc(),
///       child: MyApp(),
///     ),
///   );
/// }
///
/// class AppBlocObserver extends BlocObserver {
///   @override
///   void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
///     log('Bloc error: $error');
///     super.onError(bloc, error, stackTrace);
///   }
/// }
/// ```
class RequireBlocObserverRule extends SaropaLintRule {
  const RequireBlocObserverRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_observer',
    problemMessage:
        '[require_bloc_observer] Without a BlocObserver, state transitions and errors are invisible, making it extremely difficult to debug production issues, track bugs, or monitor app health. This can lead to undetected failures and poor user experience.',
    correctionMessage:
        'Add Bloc.observer = AppBlocObserver() in main() to enable centralized logging and error handling for all Blocs and Cubits.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Check if using Bloc
      if (!bodySource.contains('BlocProvider') && !bodySource.contains('MultiBlocProvider')) {
        return;
      }

      // Check if BlocObserver is set
      if (!bodySource.contains('Bloc.observer') && !bodySource.contains('BlocObserver')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// ============================================================================
// Batch 10: Additional Riverpod & Bloc Rules
// ============================================================================

/// Warns when BLoC events are mutated after dispatch.
///
/// Bloc events should be immutable. Mutating an event after dispatch
/// causes race conditions and makes debugging impossible.
///
/// **BAD:**
/// ```dart
/// class UpdateEvent extends MyEvent {
///   String name; // Mutable!
/// }
///
/// bloc.add(event);
/// event.name = 'changed'; // Mutating after dispatch!
/// ```
///
/// **GOOD:**
/// ```dart
/// class UpdateEvent extends MyEvent {
///   final String name; // Immutable
///   const UpdateEvent(this.name);
/// }
/// ```
class AvoidBlocEventMutationRule extends SaropaLintRule {
  const AvoidBlocEventMutationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_mutation',
    problemMessage:
        '[avoid_bloc_event_mutation] If BLoC events are mutable, they can be modified during processing, causing race conditions, unpredictable state changes, and hard-to-debug bugs. This breaks the contract of event immutability and can destabilize your app.',
    correctionMessage:
        'Make all event fields final and use a const constructor to ensure events are immutable and safe to use in BLoC.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is an event class (naming convention)
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          if (!member.isStatic && !member.fields.isFinal) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when BLoC state is modified directly instead of using copyWith.
///
/// Directly modifying state fields breaks immutability. Use copyWith
/// to create new state instances with updated fields.
///
/// **BAD:**
/// ```dart
/// emit(state..count = 5); // Mutating existing state!
/// ```
///
/// **GOOD:**
/// ```dart
/// emit(state.copyWith(count: 5)); // New immutable state
/// ```
class PreferCopyWithForStateRule extends SaropaLintRule {
  const PreferCopyWithForStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_copy_with_for_state',
    problemMessage:
        '[prefer_copy_with_for_state] Directly modifying BLoC state breaks immutability, leading to unpredictable UI updates, missed rebuilds, and subtle bugs. This makes your app harder to debug and maintain.',
    correctionMessage:
        'Use state.copyWith(field: value) to create a new immutable state object and trigger proper UI updates.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      final Expression target = node.target;
      if (target is SimpleIdentifier && target.name == 'state') {
        for (final Expression section in node.cascadeSections) {
          if (section is AssignmentExpression) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when BlocProvider.of is used with listen:true in build method.
///
/// listen:true causes rebuilds on every state change. Use BlocBuilder
/// or BlocConsumer for controlled rebuilds.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final bloc = BlocProvider.of<MyBloc>(context); // listen:true by default
///   return Text('${bloc.state}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return BlocBuilder<MyBloc, MyState>(
///     builder: (context, state) => Text('$state'),
///   );
/// }
/// ```
class AvoidBlocListenInBuildRule extends SaropaLintRule {
  const AvoidBlocListenInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_listen_in_build',
    problemMessage:
        '[avoid_bloc_listen_in_build] Using BlocProvider.of in build() with listen:true causes the widget to rebuild on every state change, leading to performance issues and unpredictable UI updates. This can make your app less efficient and harder to maintain.',
    correctionMessage:
        'Use BlocBuilder for reactive UI updates, or context.read() for one-time access to the bloc, to avoid unnecessary rebuilds and improve performance.',
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

      node.body.visitChildren(_BlocProviderOfVisitor(reporter, code));
    });
  }
}

class _BlocProviderOfVisitor extends RecursiveAstVisitor<void> {
  _BlocProviderOfVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'of') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'BlocProvider') {
        // Check if listen: false is explicitly set
        final ArgumentList args = node.argumentList;
        bool hasListenFalse = false;
        for (final Expression arg in args.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'listen' &&
              arg.expression is BooleanLiteral &&
              !(arg.expression as BooleanLiteral).value) {
            hasListenFalse = true;
          }
        }
        if (!hasListenFalse) {
          reporter.atNode(node, code);
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when BLoC constructor doesn't pass initial state to super.
///
/// Bloc without an initial state throws at runtime. Always pass
/// initial state to super() in the constructor.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(); // Missing initial state!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   MyBloc() : super(InitialState());
/// }
/// ```
class RequireInitialStateRule extends SaropaLintRule {
  const RequireInitialStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_initial_state',
    problemMessage:
        '[require_initial_state] If a BLoC or Cubit does not provide an initial state, it will throw a LateInitializationError at runtime when BlocBuilder or BlocConsumer tries to read the state. This causes your app to crash and makes debugging difficult.',
    correctionMessage:
        'Always add an initial state: super(InitialState()) or super(const State()) in your BLoC/Cubit constructor to prevent runtime errors.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check constructors have super with argument
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          bool hasSuperWithArg = false;
          for (final ConstructorInitializer init in member.initializers) {
            if (init is SuperConstructorInvocation) {
              if (init.argumentList.arguments.isNotEmpty) {
                hasSuperWithArg = true;
              }
            }
          }
          if (!hasSuperWithArg) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when BLoC state sealed class doesn't include an error state.
///
/// States should include an error variant. Without it, errors are either
/// swallowed or crash the app instead of showing error UI.
///
/// **BAD:**
/// ```dart
/// sealed class UserState {}
/// class UserLoading extends UserState {}
/// class UserLoaded extends UserState {}
/// // Missing UserError!
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class UserState {}
/// class UserLoading extends UserState {}
/// class UserLoaded extends UserState {}
/// class UserError extends UserState {
///   final String message;
/// }
/// ```
class RequireErrorStateRule extends SaropaLintRule {
  const RequireErrorStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_error_state',
    problemMessage:
        '[require_error_state] If your BLoC state hierarchy does not include an error state, failures will be unhandled, leading to crashes or missing error UI. This makes your app less robust and harder to debug.',
    correctionMessage:
        'Add an Error state class (e.g., UserError) to your BLoC state hierarchy to handle failures gracefully and display error messages to users.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final Map<String, ClassDeclaration> stateClasses = <String, ClassDeclaration>{};
    final Set<String> sealedBases = <String>{};

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (className.endsWith('State')) {
        stateClasses[className] = node;
        if (node.sealedKeyword != null) {
          sealedBases.add(className);
        }
      }
    });

    context.addPostRunCallback(() {
      for (final String baseName in sealedBases) {
        bool hasErrorState = false;
        for (final String className in stateClasses.keys) {
          if (className.contains('Error') || className.contains('Failure')) {
            hasErrorState = true;
            break;
          }
        }
        if (!hasErrorState && stateClasses.containsKey(baseName)) {
          reporter.atNode(stateClasses[baseName]!, code);
        }
      }
    });
  }
}

/// Warns when BLoCs directly call other BLoCs.
///
/// Blocs calling other blocs directly creates tight coupling. Use a
/// parent widget or service to coordinate between blocs.
///
/// **BAD:**
/// ```dart
/// class OrderBloc extends Bloc<OrderEvent, OrderState> {
///   final UserBloc userBloc;
///   OrderBloc(this.userBloc);
///
///   void onPlaceOrder() {
///     userBloc.add(UpdatePoints()); // Direct coupling!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Coordinate in widget or use streams
/// BlocListener<OrderBloc, OrderState>(
///   listener: (context, state) {
///     if (state is OrderPlaced) {
///       context.read<UserBloc>().add(UpdatePoints());
///     }
///   },
///   child: ...
/// )
/// ```
class AvoidBlocInBlocRule extends SaropaLintRule {
  const AvoidBlocInBlocRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_in_bloc',
    problemMessage:
        '[avoid_bloc_in_bloc] BLoC should not directly call another BLoC. This creates tight coupling.',
    correctionMessage: 'Coordinate between BLoCs at the widget layer or use streams.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for Bloc fields that are used with .add()
      final Set<String> blocFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final String fieldType = member.fields.type?.toSource() ?? '';
            if (fieldType.contains('Bloc') || fieldType.contains('Cubit')) {
              blocFields.add(field.name.lexeme);
            }
          }
        }
      }

      // Check for .add() calls on bloc fields
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          member.body.visitChildren(_BlocAddVisitor(reporter, code, blocFields));
        }
      }
    });
  }
}

class _BlocAddVisitor extends RecursiveAstVisitor<void> {
  _BlocAddVisitor(this.reporter, this.code, this.blocFields);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> blocFields;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'add' || node.methodName.name == 'emit') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && blocFields.contains(target.name)) {
        reporter.atNode(node, code);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when BLoC events don't use sealed classes.
///
/// Sealed classes for events enable exhaustive switch statements, so
/// the compiler catches unhandled events.
///
/// **BAD:**
/// ```dart
/// abstract class CounterEvent {}
/// class Increment extends CounterEvent {}
/// class Decrement extends CounterEvent {}
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class CounterEvent {}
/// class Increment extends CounterEvent {}
/// class Decrement extends CounterEvent {}
/// ```
class PreferSealedEventsRule extends SaropaLintRule {
  const PreferSealedEventsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_sealed_events',
    problemMessage: '[prefer_sealed_events] Non-sealed events allow subclassing anywhere, '
        'preventing compiler exhaustiveness checks in switch statements.',
    correctionMessage: 'Use sealed class instead of abstract class for event hierarchy.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check if abstract but not sealed
      if (node.abstractKeyword != null && node.sealedKeyword == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when ref.read is used instead of ref.watch in build methods.
///
/// ref.read doesn't subscribe to changes - widget won't rebuild when
/// provider updates. Use ref.watch in build methods for reactive updates.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   Widget build(context, ref) {
///     final count = ref.read(counterProvider); // Won't rebuild!
///     return Text('$count');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   Widget build(context, ref) {
///     final count = ref.watch(counterProvider); // Rebuilds on change
///     return Text('$count');
///   }
/// }
/// ```
class PreferRefWatchOverReadRule extends SaropaLintRule {
  const PreferRefWatchOverReadRule() : super(code: _code);

  /// ref.read in build() won't trigger rebuilds when provider changes.
  /// UI will show stale data until something else triggers a rebuild.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_ref_watch_over_read',
    problemMessage:
        '[prefer_ref_watch_over_read] ref.read in build() won\'t rebuild widget when provider changes.',
    correctionMessage: 'Use ref.watch() in build methods for reactive updates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'read') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'ref') return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration) {
          if (current.name.lexeme == 'build') {
            reporter.atNode(node, code);
          }
          return;
        }
        current = current.parent;
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceReadWithWatchFix()];
}

class _ReplaceReadWithWatchFix extends DartFix {
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
      if (node.methodName.name != 'read') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace ref.read with ref.watch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'watch',
        );
      });
    });
  }
}

/// Warns when ChangeNotifier is created inside build().
///
/// Creating ChangeNotifier in build() creates new instances on every rebuild,
/// losing state and causing memory leaks. Create in provider or StatefulWidget.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   final notifier = MyChangeNotifier(); // New instance every build!
///   return ChangeNotifierProvider.value(
///     value: notifier,
///     child: ...,
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // In provider
/// final myProvider = ChangeNotifierProvider((ref) => MyChangeNotifier());
///
/// // Or in StatefulWidget
/// late MyChangeNotifier _notifier;
///
/// @override
/// void initState() {
///   super.initState();
///   _notifier = MyChangeNotifier();
/// }
/// ```
class AvoidChangeNotifierInWidgetRule extends SaropaLintRule {
  const AvoidChangeNotifierInWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_change_notifier_in_widget',
    problemMessage:
        '[avoid_change_notifier_in_widget] ChangeNotifier created in build() loses state on every rebuild.',
    correctionMessage: 'Create in ChangeNotifierProvider or StatefulWidget.initState().',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      // Check if the created type extends ChangeNotifier
      final String typeName = node.constructorName.type.name.lexeme;

      // Common ChangeNotifier patterns
      if (!typeName.contains('Notifier') &&
          !typeName.contains('Controller') &&
          !typeName.contains('ViewModel') &&
          !typeName.contains('Model')) {
        return;
      }

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration) {
          if (current.name.lexeme == 'build') {
            reporter.atNode(node.constructorName, code);
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when ChangeNotifierProvider is used without dispose callback.
///
/// ChangeNotifier and other resources must be disposed. Use create with
/// dispose callback, or ChangeNotifierProvider which auto-disposes.
///
/// **BAD:**
/// ```dart
/// Provider<MyNotifier>(
///   create: (context) => MyNotifier(),
///   // Missing dispose! Memory leak.
///   child: ...,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ChangeNotifierProvider(
///   create: (context) => MyNotifier(), // Auto-disposes
///   child: ...,
/// )
/// // Or with manual dispose:
/// Provider<MyNotifier>(
///   create: (context) => MyNotifier(),
///   dispose: (context, notifier) => notifier.dispose(),
///   child: ...,
/// )
/// ```
class RequireProviderDisposeRule extends SaropaLintRule {
  const RequireProviderDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_provider_dispose',
    problemMessage:
        '[require_provider_dispose] Provider creating ChangeNotifier without dispose callback leaks listeners and memory.',
    correctionMessage: 'Use ChangeNotifierProvider (auto-disposes) or add dispose callback.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Only check Provider (not ChangeNotifierProvider which auto-disposes)
      if (typeName != 'Provider') return;

      // Check if create callback creates a ChangeNotifier-like object
      bool createsNotifier = false;
      bool hasDispose = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;

          if (name == 'dispose') {
            hasDispose = true;
          }

          if (name == 'create') {
            final String createSource = arg.expression.toSource();
            if (createSource.contains('Notifier') ||
                createSource.contains('Controller') ||
                createSource.contains('ViewModel')) {
              createsNotifier = true;
            }
          }
        }
      }

      if (createsNotifier && !hasDispose) {
        reporter.atNode(node.constructorName, code);
      }
    });
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
    correctionMessage: 'Extract parts of this widget into smaller stateless/stateful widgets, '
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
      final bool isLargeClass = lineCount >= _lineThreshold || memberCount >= _memberThreshold;

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
// ============================================================================

/// Warns when Riverpod providers reference each other in a cycle.
///
/// Circular dependencies between providers cause runtime errors or infinite
/// loops. Analyze your dependency graph to break cycles.
///
/// **BAD:**
/// ```dart
/// final providerA = Provider((ref) {
///   final b = ref.watch(providerB); // A depends on B
///   return 'A: $b';
/// });
///
/// final providerB = Provider((ref) {
///   final a = ref.watch(providerA); // B depends on A - circular!
///   return 'B: $a';
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// final providerA = Provider((ref) => 'A');
/// final providerB = Provider((ref) {
///   final a = ref.watch(providerA); // One-way dependency
///   return 'B: $a';
/// });
/// ```
class AvoidCircularProviderDepsRule extends SaropaLintRule {
  const AvoidCircularProviderDepsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_circular_provider_deps',
    problemMessage:
        '[avoid_circular_provider_deps] Circular dependencies between providers cause stack overflows, infinite loops, and unpredictable initialization order. This leads to runtime crashes, hard-to-debug errors, and broken state management. If not fixed, your app may crash or behave unpredictably in production. Always design provider graphs to be acyclic for reliability and maintainability.',
    correctionMessage:
        'Analyze the provider dependency graph and break cycles by extracting shared logic, refactoring providers, or using ref.read in callbacks instead of ref.watch. Ensure no provider directly or indirectly depends on itself. Use tools or diagrams to visualize dependencies if needed.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track provider definitions and their dependencies
    final Map<String, Set<String>> providerDeps = <String, Set<String>>{};
    final Map<String, AstNode> providerNodes = <String, AstNode>{};

    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final String providerName = variable.name.lexeme;
        final Expression? initializer = variable.initializer;

        if (initializer == null) continue;

        // Check if this is a provider
        final String initSource = initializer.toSource();
        if (!initSource.contains('Provider') && !initSource.contains('Notifier')) {
          continue;
        }

        providerNodes[providerName] = variable;
        providerDeps[providerName] = <String>{};

        // Find ref.watch and ref.read calls to identify dependencies
        final _ProviderDepVisitor depVisitor = _ProviderDepVisitor();
        initializer.visitChildren(depVisitor);

        providerDeps[providerName]!.addAll(depVisitor.dependencies);
      }
    });

    context.addPostRunCallback(() {
      // Check for circular dependencies
      for (final String provider in providerDeps.keys) {
        final Set<String> visited = <String>{};
        if (_hasCircularDep(provider, provider, providerDeps, visited)) {
          final AstNode? node = providerNodes[provider];
          if (node != null) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  bool _hasCircularDep(
    String start,
    String current,
    Map<String, Set<String>> deps,
    Set<String> visited,
  ) {
    if (visited.contains(current)) {
      return current == start;
    }
    visited.add(current);

    final Set<String>? currentDeps = deps[current];
    if (currentDeps == null) return false;

    for (final String dep in currentDeps) {
      if (dep == start) return true;
      if (_hasCircularDep(start, dep, deps, visited)) return true;
    }

    return false;
  }
}

class _ProviderDepVisitor extends RecursiveAstVisitor<void> {
  final Set<String> dependencies = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'watch' || methodName == 'read' || methodName == 'listen') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'ref') {
        // Get the provider name from arguments
        if (node.argumentList.arguments.isNotEmpty) {
          final String depSource = node.argumentList.arguments.first.toSource();
          // Extract provider name (handle .notifier, .future, etc.)
          final String depName = depSource.split('.').first;
          dependencies.add(depName);
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when async provider lacks error handling.
///
/// FutureProvider and AsyncNotifierProvider can fail. Without onError or
/// try-catch, errors crash the app or show uncaught exception UI.
///
/// **BAD:**
/// ```dart
/// final userProvider = FutureProvider((ref) async {
///   return await fetchUser(); // Throws on network error
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// final userProvider = FutureProvider((ref) async {
///   try {
///     return await fetchUser();
///   } catch (e) {
///     throw UserFetchException(e.toString());
///   }
/// });
///
/// // Or handle in UI:
/// ref.watch(userProvider).when(
///   data: (user) => Text(user.name),
///   loading: () => CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
class RequireErrorHandlingInAsyncRule extends SaropaLintRule {
  const RequireErrorHandlingInAsyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_error_handling_in_async',
    problemMessage:
        '[require_error_handling_in_async] Async provider without error handling. Errors will propagate unhandled.',
    correctionMessage: 'Add try-catch in provider or handle AsyncValue.error in UI with .when().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _asyncProviderTypes = <String>{
    'FutureProvider',
    'AsyncNotifierProvider',
    'StreamProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        String? providerType;

        if (initializer is InstanceCreationExpression) {
          providerType = initializer.constructorName.type.name.lexeme;
        } else if (initializer is MethodInvocation) {
          final Expression? target = initializer.target;
          if (target is SimpleIdentifier) {
            providerType = target.name;
          }
        }

        if (providerType == null || !_asyncProviderTypes.contains(providerType)) {
          continue;
        }

        // Check if callback has try-catch
        final String initSource = initializer.toSource();
        if (!initSource.contains('try') && !initSource.contains('catch')) {
          reporter.atNode(variable, code);
        }
      }
    });
  }
}

/// Warns when StateProvider is used instead of StateNotifierProvider/Notifier.
///
/// StateProvider is fine for simple state but Notifier provides:
/// - Encapsulated business logic
/// - Methods instead of raw state mutation
/// - Better testability
///
/// **BAD:**
/// ```dart
/// final counterProvider = StateProvider<int>((ref) => 0);
///
/// // Consumer directly mutates state
/// ref.read(counterProvider.notifier).state++;
/// ref.read(counterProvider.notifier).state += 10;
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterNotifier extends Notifier<int> {
///   @override
///   int build() => 0;
///
///   void increment() => state++;
///   void add(int value) => state += value;
/// }
///
/// final counterProvider = NotifierProvider<CounterNotifier, int>(
///   CounterNotifier.new,
/// );
/// ```
class PreferNotifierOverStateRule extends SaropaLintRule {
  const PreferNotifierOverStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_notifier_over_state',
    problemMessage:
        '[prefer_notifier_over_state] StateProvider allows uncontrolled state mutation. Consider Notifier.',
    correctionMessage:
        'Use NotifierProvider for encapsulated business logic and better testability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track StateProvider usages
    final Map<String, int> stateProviderMutations = <String, int>{};
    final Map<String, AstNode> stateProviderDecls = <String, AstNode>{};

    context.registry.addTopLevelVariableDeclaration((
      TopLevelVariableDeclaration node,
    ) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        final String initSource = initializer.toSource();
        if (initSource.contains('StateProvider')) {
          final String name = variable.name.lexeme;
          stateProviderMutations[name] = 0;
          stateProviderDecls[name] = variable;
        }
      }
    });

    // Count .notifier.state mutations
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      final String source = node.leftHandSide.toSource();
      if (source.contains('.notifier.state')) {
        // Extract provider name
        for (final String name in stateProviderMutations.keys) {
          if (source.contains(name)) {
            stateProviderMutations[name] = stateProviderMutations[name]! + 1;
          }
        }
      }
    });

    context.addPostRunCallback(() {
      // Report StateProviders with multiple mutation sites
      for (final MapEntry<String, int> entry in stateProviderMutations.entries) {
        if (entry.value >= 3) {
          final AstNode? decl = stateProviderDecls[entry.key];
          if (decl != null) {
            reporter.atNode(decl, code);
          }
        }
      }
    });
  }
}

/// Warns when GetX controller doesn't call dispose on resources.
///
/// GetxController.onClose() must dispose controllers, streams, and
/// subscriptions to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///   late StreamSubscription sub;
///
///   @override
///   void onInit() {
///     sub = stream.listen((_) {});
///     super.onInit();
///   }
///   // Missing onClose! Memory leak.
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///   late StreamSubscription sub;
///
///   @override
///   void onClose() {
///     textController.dispose();
///     sub.cancel();
///     super.onClose();
///   }
/// }
/// ```
class RequireGetxControllerDisposeRule extends SaropaLintRule {
  const RequireGetxControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_getx_controller_dispose',
    problemMessage:
        '[require_getx_controller_dispose] GetxController has TextEditingController/StreamSubscription but no onClose() to dispose them.',
    correctionMessage: 'Override onClose() to dispose controllers, cancel subscriptions, etc.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'StreamSubscription',
    'StreamController',
    'FocusNode',
    'Timer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'GetxController' &&
          superName != 'GetXController' &&
          superName != 'FullLifeCycleController') {
        return;
      }

      bool hasDisposable = false;
      bool hasOnClose = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposable in _disposableTypes) {
              if (typeName.contains(disposable)) {
                hasDisposable = true;
                break;
              }
            }
          }
        }

        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'onClose') {
            hasOnClose = true;
          }
        }
      }

      if (hasDisposable && !hasOnClose) {
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddOnCloseFix()];
}

/// Quick fix that adds an onClose() method skeleton to a GetxController.
class _AddOnCloseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.name.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add onClose() method',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find position to insert (before closing brace)
        final int insertOffset = node.rightBracket.offset;

        builder.addSimpleInsertion(
          insertOffset,
          '\n\n  @override\n  void onClose() {\n    // HACK: Dispose resources here\n    super.onClose();\n  }\n',
        );
      });
    });
  }
}

/// Warns when .obs is used outside a GetxController.
///
/// Observable (.obs) should be encapsulated in GetxController for proper
/// lifecycle management. Using .obs in widgets causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final count = 0.obs; // Reactive variable outside controller!
///
///   Widget build(context) => Obx(() => Text('${count.value}'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final count = 0.obs;
///   void increment() => count.value++;
/// }
///
/// class MyWidget extends StatelessWidget {
///   final controller = Get.find<MyController>();
///
///   Widget build(context) => Obx(() => Text('${controller.count.value}'));
/// }
/// ```
class AvoidObsOutsideControllerRule extends SaropaLintRule {
  const AvoidObsOutsideControllerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_obs_outside_controller',
    problemMessage:
        '[avoid_obs_outside_controller] .obs used outside GetxController causes memory leaks and lifecycle issues.',
    correctionMessage: 'Move observable state to a GetxController for proper lifecycle management.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// GetX controller class names that are allowed to use .obs
  static const Set<String> _getxControllerTypes = <String>{
    'GetxController',
    'GetXController',
    'FullLifeCycleController',
    'SuperController',
    'GetxService',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for .obs in field declarations (most common case)
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      // Check if this class extends a GetX controller type
      if (_isGetxController(classDecl)) return;

      // Check for .obs in field initializer
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? init = variable.initializer;
        if (init != null && init.toSource().endsWith('.obs')) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  /// Returns true if the class extends a known GetX controller type.
  bool _isGetxController(ClassDeclaration classDecl) {
    final ExtendsClause? extendsClause = classDecl.extendsClause;
    if (extendsClause == null) return false;

    final String superName = extendsClause.superclass.name.lexeme;
    return _getxControllerTypes.contains(superName);
  }
}

/// Warns when Bloc event handlers don't use EventTransformer.
///
/// Without EventTransformer, rapid events are processed sequentially.
/// Use transformers for debouncing, throttling, or concurrent processing.
///
/// **BAD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>((event, emit) async {
///       // Processes every keystroke - excessive API calls!
///       final results = await search(event.query);
///       emit(SearchResults(results));
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(
///       (event, emit) async {
///         final results = await search(event.query);
///         emit(SearchResults(results));
///       },
///       transformer: debounce(Duration(milliseconds: 300)),
///     );
///   }
/// }
/// ```
class RequireBlocTransformerRule extends SaropaLintRule {
  const RequireBlocTransformerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_transformer',
    problemMessage:
        '[require_bloc_transformer] Bloc on<Event> without transformer processes all events sequentially.',
    correctionMessage: 'Add transformer: for debounce, throttle, or concurrent event handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Event names that commonly benefit from transformers
  static const Set<String> _transformerSuggestedEvents = <String>{
    'SearchQueryChanged',
    'TextChanged',
    'InputChanged',
    'ScrollPositionChanged',
    'FilterChanged',
    'QueryChanged',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for on<EventType>(...) pattern
      if (node.methodName.name != 'on') return;

      // Check if it has type arguments (on<EventType>)
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final String eventType = typeArgs.arguments.first.toSource();

      // Check if this event type would benefit from a transformer
      bool needsTransformer = false;
      for (final String pattern in _transformerSuggestedEvents) {
        if (eventType.contains(pattern)) {
          needsTransformer = true;
          break;
        }
      }

      if (!needsTransformer) return;

      // Check if transformer argument is present
      bool hasTransformer = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'transformer') {
          hasTransformer = true;
          break;
        }
      }

      if (!hasTransformer) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc event handlers are too long.
///
/// Long event handlers indicate the handler is doing too much. Extract
/// business logic to separate methods or services for testability.
///
/// **BAD:**
/// ```dart
/// on<SubmitForm>((event, emit) async {
///   emit(Loading());
///   // 50+ lines of validation, API calls, error handling...
///   final validated = validateForm(event.data);
///   if (!validated.isValid) {
///     emit(Error(validated.errors));
///     return;
///   }
///   final user = await api.createUser(validated.data);
///   // ... more logic ...
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// on<SubmitForm>(_onSubmitForm);
///
/// Future<void> _onSubmitForm(SubmitForm event, Emitter<State> emit) async {
///   emit(Loading());
///   final result = await _submitFormUseCase(event.data);
///   emit(result.fold(
///     (error) => Error(error),
///     (user) => Success(user),
///   ));
/// }
/// ```
class AvoidLongEventHandlersRule extends SaropaLintRule {
  const AvoidLongEventHandlersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_long_event_handlers',
    problemMessage:
        '[avoid_long_event_handlers] Bloc event handler is too long. Extract logic to separate methods.',
    correctionMessage: 'Move complex logic to named methods or use cases for better testability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Maximum lines before warning
  static const int _maxLines = 30;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'on') return;

      // Find the handler function in arguments
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          final String source = arg.body.toSource();
          final int lineCount = '\n'.allMatches(source).length + 1;

          if (lineCount > _maxLines) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when a Riverpod project doesn't include riverpod_lint.
///
/// The official riverpod_lint package catches Riverpod-specific mistakes
/// that general linters miss. Use it alongside saropa_lints for complete
/// coverage.
///
/// **BAD:**
/// ```yaml
/// # pubspec.yaml
/// dependencies:
///   flutter_riverpod: ^2.0.0
/// dev_dependencies:
///   # No riverpod_lint - missing Riverpod-specific checks
/// ```
///
/// **GOOD:**
/// ```yaml
/// # pubspec.yaml
/// dependencies:
///   flutter_riverpod: ^2.0.0
/// dev_dependencies:
///   riverpod_lint: ^2.0.0
/// ```
class RequireRiverpodLintRule extends SaropaLintRule {
  const RequireRiverpodLintRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_riverpod_lint',
    problemMessage:
        '[require_riverpod_lint] Project uses Riverpod but riverpod_lint is not configured.',
    correctionMessage: 'Add riverpod_lint to dev_dependencies for Riverpod-specific linting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This rule checks file-level imports for Riverpod usage
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // Check if using Riverpod
      if (!uri.contains('riverpod') && !uri.contains('flutter_riverpod')) {
        return;
      }

      // This is a heuristic check - we found Riverpod imports
      // In a real implementation, we'd check pubspec.yaml for riverpod_lint
      // For now, we flag when Riverpod is imported without riverpod_lint
      // annotations being visible in the same file

      // Check if file has riverpod_lint annotations
      final AstNode root = node.root;
      if (root is CompilationUnit) {
        final String source = root.toSource();

        // Look for riverpod_lint annotations or generated code
        if (source.contains('@riverpod') ||
            source.contains('.g.dart') ||
            source.contains('riverpod_annotation')) {
          // Using code generation - riverpod_lint likely configured
          return;
        }

        // Check for classic provider definitions without lint annotations
        if (source.contains('Provider(') ||
            source.contains('StateProvider(') ||
            source.contains('FutureProvider(') ||
            source.contains('StreamProvider(')) {
          // Using classic providers - suggest riverpod_lint
          // Only report once per file
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Provider package uses nested Provider widgets instead of
/// MultiProvider.
///
/// Nested Provider widgets create deep indentation. MultiProvider flattens
/// the tree and is easier to read and maintain.
///
/// **BAD:**
/// ```dart
/// Provider<A>(
///   create: (_) => A(),
///   child: Provider<B>(
///     create: (_) => B(),
///     child: Provider<C>(
///       create: (_) => C(),
///       child: MyApp(),
///     ),
///   ),
/// ),
/// ```
///
/// **GOOD:**
/// ```dart
/// MultiProvider(
///   providers: [
///     Provider<A>(create: (_) => A()),
///     Provider<B>(create: (_) => B()),
///     Provider<C>(create: (_) => C()),
///   ],
///   child: MyApp(),
/// ),
/// ```
class RequireMultiProviderRule extends SaropaLintRule {
  const RequireMultiProviderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_multi_provider',
    problemMessage:
        '[require_multi_provider] Nested Provider widgets. Use MultiProvider for better readability.',
    correctionMessage: 'Replace nested Providers with MultiProvider(providers: [...], child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _providerTypes = {
    'Provider',
    'ChangeNotifierProvider',
    'FutureProvider',
    'StreamProvider',
    'ListenableProvider',
    'ValueListenableProvider',
    'ProxyProvider',
    'ProxyProvider2',
    'ProxyProvider3',
    'ProxyProvider4',
    'ProxyProvider5',
    'ProxyProvider6',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (!_providerTypes.contains(typeName)) return;

      // Check if parent is also a Provider (nested pattern)
      AstNode? current = node.parent;
      int nestingDepth = 0;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (_providerTypes.contains(parentType)) {
            nestingDepth++;
          }
        }
        current = current.parent;
      }

      // If nested 2+ levels deep, suggest MultiProvider
      if (nestingDepth >= 2) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Provider widgets are deeply nested.
///
/// Deeply nested provider trees are hard to reason about and maintain.
/// Flatten with MultiProvider and avoid provider-in-provider patterns
/// where possible.
///
/// **BAD:**
/// ```dart
/// Provider<A>(
///   create: (_) => A(),
///   child: Consumer<A>(
///     builder: (_, a, child) => Provider<B>(
///       create: (_) => B(a), // Provider inside Consumer
///       child: child,
///     ),
///   ),
/// ),
/// ```
///
/// **GOOD:**
/// ```dart
/// MultiProvider(
///   providers: [
///     Provider<A>(create: (_) => A()),
///     ProxyProvider<A, B>(update: (_, a, __) => B(a)),
///   ],
///   child: MyApp(),
/// ),
/// ```
class AvoidNestedProvidersRule extends SaropaLintRule {
  const AvoidNestedProvidersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_nested_providers',
    problemMessage:
        '[avoid_nested_providers] Provider created inside Consumer or builder callback.',
    correctionMessage: 'Use ProxyProvider or move provider to MultiProvider at tree root.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _providerTypes = {
    'Provider',
    'ChangeNotifierProvider',
    'FutureProvider',
    'StreamProvider',
    'ListenableProvider',
    'ValueListenableProvider',
  };

  static const Set<String> _consumerTypes = {
    'Consumer',
    'Consumer2',
    'Consumer3',
    'Consumer4',
    'Consumer5',
    'Consumer6',
    'Selector',
    'Selector2',
    'Selector3',
    'Selector4',
    'Selector5',
    'Selector6',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (!_providerTypes.contains(typeName)) return;

      // Check if inside a Consumer's builder callback
      AstNode? current = node.parent;

      while (current != null) {
        // Check for builder callback pattern
        if (current is NamedExpression &&
            (current.name.label.name == 'builder' || current.name.label.name == 'selector')) {
          // Check if this builder belongs to a Consumer
          AstNode? builderParent = current.parent;
          while (builderParent != null) {
            if (builderParent is InstanceCreationExpression) {
              final String parentType = builderParent.constructorName.type.name.lexeme;
              if (_consumerTypes.contains(parentType)) {
                reporter.atNode(node, code);
                return;
              }
            }
            builderParent = builderParent.parent;
          }
        }

        // Also check for direct nesting in child argument of other providers
        if (current is NamedExpression && current.name.label.name == 'child') {
          AstNode? childParent = current.parent;
          while (childParent != null) {
            if (childParent is InstanceCreationExpression) {
              final String parentType = childParent.constructorName.type.name.lexeme;
              if (_providerTypes.contains(parentType)) {
                // This is direct nesting - handled by RequireMultiProviderRule
                return;
              }
            }
            childParent = childParent.parent;
          }
        }

        current = current.parent;
      }
    });
  }
}

/// Warns when nested `BlocProvider` widgets are used.
///
/// Use `MultiBlocProvider` when providing multiple blocs to reduce nesting
/// and improve readability.
///
/// **BAD:**
/// ```dart
/// BlocProvider<AuthBloc>(
///   create: (_) => AuthBloc(),
///   child: BlocProvider<UserBloc>(
///     create: (_) => UserBloc(),
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MultiBlocProvider(
///   providers: [
///     BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
///     BlocProvider<UserBloc>(create: (_) => UserBloc()),
///   ],
///   child: MyApp(),
/// )
/// ```
///
/// **Quick fix available:** Adds a `TODO` comment for manual conversion.
class PreferMultiBlocProviderRule extends SaropaLintRule {
  const PreferMultiBlocProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_multi_bloc_provider',
    problemMessage:
        '[prefer_multi_bloc_provider] Nested BlocProviders should use MultiBlocProvider instead.',
    correctionMessage: 'Combine into MultiBlocProvider(providers: [...], child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Check if child is also a BlocProvider
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (childExpr is InstanceCreationExpression) {
            final String childType = childExpr.constructorName.type.name.lexeme;
            if (childType == 'BlocProvider') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when `BlocProvider.value` receives a newly created bloc instance.
///
/// `BlocProvider.value` should only receive existing bloc instances.
/// Creating a new bloc in the value parameter will not properly manage
/// the bloc's lifecycle (it won't be automatically closed).
///
/// **BAD:**
/// ```dart
/// BlocProvider.value(
///   value: AuthBloc(), // New instance - won't be automatically closed!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocProvider(
///   create: (_) => AuthBloc(), // Properly managed by BlocProvider
///   child: MyWidget(),
/// )
/// // OR for existing instances:
/// BlocProvider.value(
///   value: existingBloc, // Variable reference is correct
///   child: MyWidget(),
/// )
/// ```
class AvoidInstantiatingInBlocValueProviderRule extends SaropaLintRule {
  const AvoidInstantiatingInBlocValueProviderRule() : super(code: _code);

  /// Critical - memory leak potential.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_instantiating_in_bloc_value_provider',
    problemMessage:
        '[avoid_instantiating_in_bloc_value_provider] Creating a new bloc instance inside BlocProvider.value prevents the bloc from being automatically closed, leading to memory leaks and unpredictable state. This is a critical resource management issue that can degrade app performance and reliability.',
    correctionMessage:
        'Always use BlocProvider(create: ...) to create new bloc instances, or pass an existing bloc variable to BlocProvider.value. Never instantiate a bloc directly inside BlocProvider.value.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Check if this is BlocProvider.value
      if (constructorName.name?.name != 'value') return;

      // Check if value parameter is an instance creation (new bloc)
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          final Expression valueExpr = arg.expression;
          if (valueExpr is InstanceCreationExpression) {
            // This is creating a new instance in value - BAD
            reporter.atNode(valueExpr, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when `BlocProvider(create: ...)` returns an existing bloc instance.
///
/// `BlocProvider(create: ...)` should create a new bloc instance.
/// Returning an existing variable will cause the bloc to be closed when
/// the provider is disposed, even though it may still be in use elsewhere.
///
/// **BAD:**
/// ```dart
/// final myBloc = AuthBloc();
/// // ...
/// BlocProvider(
///   create: (_) => myBloc, // Existing instance - will be closed unexpectedly!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocProvider(
///   create: (_) => AuthBloc(), // New instance - proper lifecycle
///   child: MyWidget(),
/// )
/// // OR for existing instances:
/// BlocProvider.value(
///   value: myBloc, // Use .value for existing instances
///   child: MyWidget(),
/// )
/// ```
class AvoidExistingInstancesInBlocProviderRule extends SaropaLintRule {
  const AvoidExistingInstancesInBlocProviderRule() : super(code: _code);

  /// Critical - unexpected bloc closure.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_existing_instances_in_bloc_provider',
    problemMessage:
        '[avoid_existing_instances_in_bloc_provider] Returning an existing bloc instance from BlocProvider(create: ...) causes the bloc to be closed when the provider disposes, even if it is still used elsewhere. This can lead to unexpected state loss, runtime errors, and hard-to-debug bugs. Always use the correct provider pattern for new vs. existing blocs.',
    correctionMessage:
        'For existing bloc instances, use BlocProvider.value(value: existingBloc). Only use BlocProvider(create: ...) to create new bloc instances. This ensures proper lifecycle management and prevents accidental closure of shared blocs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Skip BlocProvider.value - that's what they should use for existing
      if (constructorName.name?.name == 'value') return;

      // Check if create parameter returns an existing variable
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            final FunctionBody body = createExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression returnExpr = body.expression;
              // Check if return is just a simple identifier (variable)
              if (returnExpr is SimpleIdentifier) {
                // Check it's not calling a constructor
                // A simple identifier returning means it's an existing variable
                reporter.atNode(returnExpr, code);
                return;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when the wrong BlocProvider variant is used for the use case.
///
/// - Use `BlocProvider(create: ...)` when you need to create AND manage a bloc
/// - Use `BlocProvider.value(value: ...)` when providing an already-existing bloc
///
/// This rule identifies common mismatches between provider type and usage.
///
/// **BAD:**
/// ```dart
/// // Using create but immediately closing the bloc elsewhere
/// BlocProvider(
///   create: (_) => context.read<AuthBloc>(), // Getting existing bloc!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use .value for accessing blocs from context
/// BlocProvider.value(
///   value: context.read<AuthBloc>(),
///   child: MyWidget(),
/// )
/// ```
class PreferCorrectBlocProviderRule extends SaropaLintRule {
  const PreferCorrectBlocProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_correct_bloc_provider',
    problemMessage:
        '[prefer_correct_bloc_provider] Using context.read() in BlocProvider.create returns an existing bloc. '
        'Use BlocProvider.value instead.',
    correctionMessage: 'Replace with BlocProvider.value(value: context.read<T>(), ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'BlocProvider') return;

      // Only check BlocProvider(create: ...)
      if (constructorName.name?.name == 'value') return;

      // Check if create parameter uses context.read()
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            final FunctionBody body = createExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression returnExpr = body.expression;
              // Check for context.read<T>() pattern
              if (returnExpr is MethodInvocation) {
                final String methodName = returnExpr.methodName.name;
                if (methodName == 'read' || methodName == 'watch') {
                  reporter.atNode(node, code);
                  return;
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when nested `Provider` widgets are used.
///
/// Use `MultiProvider` when providing multiple objects to reduce nesting
/// and improve readability.
///
/// **BAD:**
/// ```dart
/// Provider<AuthService>(
///   create: (_) => AuthService(),
///   child: Provider<UserService>(
///     create: (_) => UserService(),
///     child: MyApp(),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MultiProvider(
///   providers: [
///     Provider<AuthService>(create: (_) => AuthService()),
///     Provider<UserService>(create: (_) => UserService()),
///   ],
///   child: MyApp(),
/// )
/// ```
class PreferMultiProviderRule extends SaropaLintRule {
  const PreferMultiProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_multi_provider',
    problemMessage: '[prefer_multi_provider] Nested Providers should use MultiProvider instead.',
    correctionMessage: 'Combine into MultiProvider(providers: [...], child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'ChangeNotifierProvider',
    'ListenableProvider',
    'ValueListenableProvider',
    'StreamProvider',
    'FutureProvider',
    'ProxyProvider',
    'ChangeNotifierProxyProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_providerTypes.contains(typeName)) return;

      // Skip if this is .value constructor
      if (node.constructorName.name?.name == 'value') return;

      // Check if child is also a Provider
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (childExpr is InstanceCreationExpression) {
            final String childType = childExpr.constructorName.type.name.lexeme;
            if (_providerTypes.contains(childType)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when `Provider.value` receives a newly created instance.
///
/// `Provider.value` should only receive existing instances.
/// Creating a new instance in the value parameter will not properly manage
/// the instance's lifecycle.
///
/// **BAD:**
/// ```dart
/// Provider.value(
///   value: AuthService(), // New instance - not managed!
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Provider(
///   create: (_) => AuthService(), // Properly managed
///   child: MyWidget(),
/// )
/// // OR for existing instances:
/// Provider.value(
///   value: existingService, // Variable reference is correct
///   child: MyWidget(),
/// )
/// ```
class AvoidInstantiatingInValueProviderRule extends SaropaLintRule {
  const AvoidInstantiatingInValueProviderRule() : super(code: _code);

  /// Critical - lifecycle management issue.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_instantiating_in_value_provider',
    problemMessage:
        '[avoid_instantiating_in_value_provider] Creating a new instance inside Provider.value prevents proper lifecycle management, leading to memory leaks, resource retention, and unpredictable behavior. This is a critical issue for stateful objects like ChangeNotifiers and ValueListenables.',
    correctionMessage:
        'Always use Provider(create: ...) to create new instances, or pass an existing instance variable to Provider.value. Never instantiate objects directly inside Provider.value.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'ChangeNotifierProvider',
    'ListenableProvider',
    'ValueListenableProvider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (!_providerTypes.contains(typeName)) return;

      // Check if this is .value constructor
      if (constructorName.name?.name != 'value') return;

      // Check if value parameter is an instance creation
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          final Expression valueExpr = arg.expression;
          if (valueExpr is InstanceCreationExpression) {
            reporter.atNode(valueExpr, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when `Provider` lacks a dispose callback for disposable instances.
///
/// When providing disposable resources like controllers or services,
/// always provide a dispose callback to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// Provider<ApiService>(
///   create: (_) => ApiService(), // No dispose - may leak resources!
///   child: MyApp(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Provider<ApiService>(
///   create: (_) => ApiService(),
///   dispose: (_, service) => service.dispose(),
///   child: MyApp(),
/// )
/// ```
///
/// Note: This rule flags all Providers without dispose. If your instance
/// doesn't need disposal, add `dispose: (_, __) {}` to silence the warning.
class DisposeProvidersRule extends SaropaLintRule {
  const DisposeProvidersRule() : super(code: _code);

  /// High impact - memory leak prevention.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'dispose_provider_instances',
    problemMessage:
        '[dispose_provider_instances] Provider creating disposable instance without dispose callback leaks controllers and streams.',
    correctionMessage: 'Add dispose: (_, instance) => instance.dispose() to clean up resources.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;

      // Only check Provider (not ChangeNotifierProvider which auto-disposes)
      if (typeName != 'Provider') return;

      // Skip .value constructor
      if (constructorName.name?.name == 'value') return;

      // Check if dispose parameter is present
      bool hasDispose = false;
      bool hasCreate = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'dispose') hasDispose = true;
          if (name == 'create') hasCreate = true;
        }
      }

      // Only report if has create but no dispose
      if (hasCreate && !hasDispose) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when GetxController overrides `onInit` or `onClose` without calling super.
///
/// Not calling the super method in lifecycle overrides can break the
/// controller's internal state management and cause unexpected behavior.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     // Missing super.onInit()!
///     loadData();
///   }
///
///   @override
///   void onClose() {
///     // Missing super.onClose()!
///     cleanup();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     super.onInit();
///     loadData();
///   }
///
///   @override
///   void onClose() {
///     cleanup();
///     super.onClose();
///   }
/// }
/// ```
class ProperGetxSuperCallsRule extends SaropaLintRule {
  const ProperGetxSuperCallsRule() : super(code: _code);

  /// Critical - broken lifecycle management.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'proper_getx_super_calls',
    problemMessage:
        '[proper_getx_super_calls] Omitting a call to super in GetxController lifecycle methods (onInit, onReady, onClose) breaks the controller lifecycle, causing incomplete initialization, missed cleanup, and unpredictable behavior. This can lead to memory leaks, resource retention, and subtle bugs that are hard to diagnose.',
    correctionMessage:
        'Always call the corresponding super method (e.g., super.onInit(), super.onClose()) in GetxController lifecycle overrides. Place super.onInit() at the start and super.onClose() at the end to ensure proper initialization and cleanup.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'onInit',
    'onReady',
    'onClose',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      if (!_lifecycleMethods.contains(methodName)) return;

      // Check if this method has @override annotation
      bool hasOverride = false;
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          hasOverride = true;
          break;
        }
      }

      if (!hasOverride) return;

      // Check if method body contains super call
      final FunctionBody body = node.body;
      if (body is EmptyFunctionBody) return;

      final _SuperCallVisitor visitor = _SuperCallVisitor(methodName);
      body.accept(visitor);

      if (!visitor.hasSuperCall) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _SuperCallVisitor extends RecursiveAstVisitor<void> {
  _SuperCallVisitor(this.methodName);

  final String methodName;
  bool hasSuperCall = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == methodName) {
      hasSuperCall = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when GetX reactive workers are created without cleanup.
///
/// Workers like `ever()`, `once()`, `debounce()`, and `interval()` create
/// subscriptions that must be cancelled in `onClose()` to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     super.onInit();
///     ever(count, (_) => print('changed'));  // No cleanup!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///
///   @override
///   void onClose() {
///     _worker.dispose();
///     super.onClose();
///   }
/// }
/// ```
class AlwaysRemoveGetxListenerRule extends SaropaLintRule {
  const AlwaysRemoveGetxListenerRule() : super(code: _code);

  /// High impact - memory leak prevention.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'always_remove_getx_listener',
    problemMessage:
        '[always_remove_getx_listener] GetX worker is not assigned to a variable for cleanup. '
        'This will cause a memory leak.',
    correctionMessage: 'Assign the worker to a variable and call dispose() in onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _workerMethods = <String>{
    'ever',
    'once',
    'debounce',
    'interval',
    'everAll',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_workerMethods.contains(methodName)) return;

      // Check if this is a statement by itself (not assigned to variable)
      final AstNode? parent = node.parent;
      if (parent is ExpressionStatement) {
        // Not assigned - potential leak
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Flutter Hooks are called outside of a build method.
///
/// Hooks (functions starting with `use`) must be called from within
/// the build method of a HookWidget. Calling them elsewhere violates
/// the rules of hooks and causes runtime errors.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   void initData() {
///     final controller = useTextEditingController(); // Wrong!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final controller = useTextEditingController(); // Correct!
///     return TextField(controller: controller);
///   }
/// }
/// ```
class AvoidHooksOutsideBuildRule extends SaropaLintRule {
  const AvoidHooksOutsideBuildRule() : super(code: _code);

  /// Critical - runtime error.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hooks_outside_build',
    problemMessage: '[avoid_hooks_outside_build] Hook function called outside of build method. '
        'Hooks must only be called from build().',
    correctionMessage: 'Move this hook call inside the build() method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a hook function (use + PascalCase, e.g., useState, useEffect)
      if (!_isHookFunction(methodName)) return;

      // Check if we're inside a build method
      if (!_isInsideBuildMethod(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      current = current.parent;
    }
    return false;
  }
}

/// Checks if a method name follows the Flutter hooks naming convention.
///
/// Flutter hooks use the pattern `use` + PascalCase identifier:
/// - `useState`, `useEffect`, `useCallback` ✓
/// - `userDOB`, `usefulHelper`, `username` ✗
bool _isHookFunction(String methodName) {
  // Must start with 'use' and have at least one more character
  if (!methodName.startsWith('use')) return false;
  if (methodName.length < 4) return false;

  // The character after 'use' must be uppercase (PascalCase convention)
  // This distinguishes useState from userDOB
  final charAfterUse = methodName[3];
  return charAfterUse == charAfterUse.toUpperCase() && charAfterUse != charAfterUse.toLowerCase();
}

/// Warns when Flutter Hooks are called inside conditionals.
///
/// Hooks must be called unconditionally in the same order every build.
/// Calling hooks inside if/else, switch, or ternary expressions violates
/// the rules of hooks and causes runtime errors.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (condition) {
///     final value = useState(0); // Wrong!
///   }
///   return condition ? useCallback() : null; // Wrong!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final value = useState(0); // Called unconditionally
///   if (condition) {
///     value.value = 42; // Use the value conditionally, not the hook
///   }
///   return Container();
/// }
/// ```
class AvoidConditionalHooksRule extends SaropaLintRule {
  const AvoidConditionalHooksRule() : super(code: _code);

  /// Critical - runtime error.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_conditional_hooks',
    problemMessage: '[avoid_conditional_hooks] Hook function called conditionally. '
        'Hooks must be called unconditionally in the same order.',
    correctionMessage:
        'Move hook calls outside of conditionals. Use the hook value conditionally instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a hook function (use + PascalCase, e.g., useState, useEffect)
      if (!_isHookFunction(methodName)) return;

      // Check if inside build method first
      if (!_isInsideBuildMethod(node)) return;

      // Check if inside a conditional
      if (_isInsideConditional(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInsideConditional(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      // Stop at build method level
      if (current is MethodDeclaration) break;

      // Check for conditionals
      if (current is IfStatement ||
          current is ConditionalExpression ||
          current is SwitchStatement ||
          current is SwitchExpression) {
        return true;
      }

      // Check for loop bodies (hooks shouldn't be in loops either)
      if (current is ForStatement ||
          current is ForEachParts ||
          current is WhileStatement ||
          current is DoStatement) {
        return true;
      }

      current = current.parent;
    }
    return false;
  }
}

/// Warns when a HookWidget doesn't use any hooks.
///
/// If a widget extends HookWidget but doesn't call any hook functions,
/// it should be a regular StatelessWidget instead.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Text('No hooks used!'); // Should be StatelessWidget
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final counter = useState(0); // Using hooks!
///     return Text('${counter.value}');
///   }
/// }
/// ```
class AvoidUnnecessaryHookWidgetsRule extends SaropaLintRule {
  const AvoidUnnecessaryHookWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_hook_widgets',
    problemMessage:
        '[avoid_unnecessary_hook_widgets] HookWidget without any hook calls. Use StatelessWidget instead.',
    correctionMessage: 'Change to StatelessWidget if no hooks are needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends HookWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'HookWidget' && superclassName != 'HookConsumerWidget') {
        return;
      }

      // Find build method
      MethodDeclaration? buildMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          buildMethod = member;
          break;
        }
      }

      if (buildMethod == null) return;

      // Check if build method contains any hook calls
      final _HookCallVisitor visitor = _HookCallVisitor();
      buildMethod.body.accept(visitor);

      if (!visitor.hasHookCall) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _HookCallVisitor extends RecursiveAstVisitor<void> {
  bool hasHookCall = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    // Use the proper hook detection (use + PascalCase)
    if (_isHookFunction(methodName)) {
      hasHookCall = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when emit() is called after an await without checking isClosed.
///
/// Bloc can be closed while awaiting, leading to state emissions on a
/// closed bloc which causes errors.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// on<LoadEvent>((event, emit) async {
///   final data = await fetchData();
///   emit(LoadedState(data)); // Bloc might be closed!
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// on<LoadEvent>((event, emit) async {
///   final data = await fetchData();
///   if (!isClosed) {
///     emit(LoadedState(data));
///   }
/// });
/// ```
class CheckIsNotClosedAfterAsyncGapRule extends SaropaLintRule {
  const CheckIsNotClosedAfterAsyncGapRule() : super(code: _code);

  /// Critical bug. Emit after close causes crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'check_is_not_closed_after_async_gap',
    problemMessage: '[check_is_not_closed_after_async_gap] Emitting to closed Bloc throws '
        'StateError, crashing the app when widget is disposed during async.',
    correctionMessage: 'Add if (!isClosed) check before emit() after async operations.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Look for on<Event> handler registration
      if (node.methodName.name != 'on') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      // Get the callback
      final Expression callback = args.arguments.first;
      if (callback is! FunctionExpression) return;

      final FunctionBody body = callback.body;
      if (!body.isAsynchronous) return;

      // Find emit calls after await
      final _EmitAfterAwaitVisitor visitor = _EmitAfterAwaitVisitor();
      body.accept(visitor);

      for (final MethodInvocation emitCall in visitor.emitCallsAfterAwait) {
        reporter.atNode(emitCall, code);
      }
    });
  }
}

class _EmitAfterAwaitVisitor extends RecursiveAstVisitor<void> {
  bool _foundAwait = false;
  bool _insideClosedCheck = false;
  final List<MethodInvocation> emitCallsAfterAwait = <MethodInvocation>[];

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _foundAwait = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check for if (!isClosed) or if (isClosed) return patterns
    final Expression condition = node.expression;
    if (_isClosedCheck(condition)) {
      _insideClosedCheck = true;
      node.thenStatement.accept(this);
      _insideClosedCheck = false;
      node.elseStatement?.accept(this);
    } else {
      super.visitIfStatement(node);
    }
  }

  bool _isClosedCheck(Expression expr) {
    // Check for !isClosed or isClosed
    if (expr is PrefixExpression && expr.operator.lexeme == '!') {
      final Expression operand = expr.operand;
      return operand is SimpleIdentifier && operand.name == 'isClosed';
    }
    if (expr is SimpleIdentifier) {
      return expr.name == 'isClosed';
    }
    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emit' && _foundAwait && !_insideClosedCheck) {
      emitCallsAfterAwait.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when multiple handlers are registered for the same event type.
///
/// Bloc doesn't support multiple handlers for the same event. The second
/// handler will override the first, leading to unexpected behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(InitialState()) {
///     on<LoadEvent>((e, emit) => emit(Loading()));
///     on<LoadEvent>((e, emit) => emit(Loaded())); // Duplicate!
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(InitialState()) {
///     on<LoadEvent>((e, emit) {
///       emit(Loading());
///       // ... then emit Loaded
///     });
///   }
/// }
/// ```
class AvoidDuplicateBlocEventHandlersRule extends SaropaLintRule {
  const AvoidDuplicateBlocEventHandlersRule() : super(code: _code);

  /// Critical bug. Duplicate handlers cause unexpected behavior.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_bloc_event_handlers',
    problemMessage: '[avoid_duplicate_bloc_event_handlers] Second handler for same event '
        'type is ignored, causing silent bugs when expected logic runs.',
    correctionMessage: 'Combine handlers into one on<Event> call. Only one handler per event type.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends Bloc
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'Bloc') return;

      // Find constructor
      ConstructorDeclaration? constructor;
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.name == null) {
          constructor = member;
          break;
        }
      }

      if (constructor == null) return;

      // Find all on<Event> calls
      final Map<String, List<MethodInvocation>> eventHandlers = <String, List<MethodInvocation>>{};

      final _OnCallVisitor visitor = _OnCallVisitor();
      constructor.body.accept(visitor);

      for (final MethodInvocation onCall in visitor.onCalls) {
        final TypeArgumentList? typeArgs = onCall.typeArguments;
        if (typeArgs == null || typeArgs.arguments.isEmpty) continue;

        final String eventType = typeArgs.arguments.first.toSource();
        eventHandlers.putIfAbsent(eventType, () => <MethodInvocation>[]);
        eventHandlers[eventType]!.add(onCall);
      }

      // Report duplicates
      for (final String eventType in eventHandlers.keys) {
        final List<MethodInvocation> handlers = eventHandlers[eventType]!;
        if (handlers.length > 1) {
          // Report all but the first one
          for (int i = 1; i < handlers.length; i++) {
            reporter.atNode(handlers[i], code);
          }
        }
      }
    });
  }
}

class _OnCallVisitor extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> onCalls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'on') {
      onCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Bloc event classes have mutable fields.
///
/// Bloc events should be immutable for predictable state management.
/// Mutable events can be changed after dispatch, causing bugs.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class UpdateUserEvent extends UserEvent {
///   String name; // Mutable!
///   UpdateUserEvent(this.name);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class UpdateUserEvent extends UserEvent {
///   final String name; // Immutable
///   const UpdateUserEvent(this.name);
/// }
/// ```
class PreferImmutableBlocEventsRule extends SaropaLintRule {
  const PreferImmutableBlocEventsRule() : super(code: _code);

  /// Bug risk. Mutable events can cause unexpected behavior.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_immutable_bloc_events',
    problemMessage: '[prefer_immutable_bloc_events] Mutable event fields can be changed '
        'during processing, causing inconsistent state and debugging nightmares.',
    correctionMessage: 'Mark all fields as final for immutable events.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal && !fields.isConst) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Bloc state classes have mutable fields.
///
/// Bloc states should be immutable for predictable state management.
/// Mutable states can be changed outside the bloc, breaking the pattern.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class LoadedState extends UserState {
///   List<User> users; // Mutable!
///   LoadedState(this.users);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class LoadedState extends UserState {
///   final List<User> users; // Immutable reference
///   const LoadedState(this.users);
/// }
/// ```
class PreferImmutableBlocStateRule extends SaropaLintRule {
  const PreferImmutableBlocStateRule() : super(code: _code);

  /// Bug risk. Mutable state breaks bloc pattern.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_immutable_bloc_state',
    problemMessage: '[prefer_immutable_bloc_state] Mutable state fields break equality '
        'comparison, causing BlocBuilder to miss or duplicate updates.',
    correctionMessage: 'Mark all fields as final for immutable state.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with State
      final String className = node.name.lexeme;
      if (!className.endsWith('State')) return;

      // Exclude Flutter's State class by checking for extends StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'State') return; // Flutter State, not Bloc state
      }

      // Check for mutable fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration && !member.isStatic) {
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal && !fields.isConst) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Bloc event classes are not sealed.
///
/// Sealed event classes ensure exhaustive pattern matching in handlers
/// and prevent unexpected event subtypes from being created.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// abstract class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
///
/// #### GOOD:
/// ```dart
/// sealed class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
class PreferSealedBlocEventsRule extends SaropaLintRule {
  const PreferSealedBlocEventsRule() : super(code: _code);

  /// Code quality. Sealed classes improve type safety.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_sealed_bloc_events',
    problemMessage: '[prefer_sealed_bloc_events] Bloc event base class should be sealed.',
    correctionMessage: 'Use sealed keyword for exhaustive pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final String className = node.name.lexeme;
      if (!className.endsWith('Event')) return;

      // Check if it's a base class (abstract without extending another Event)
      if (node.abstractKeyword == null) return;

      // Check if it's already sealed
      if (node.sealedKeyword != null) return;

      // Check if it doesn't extend another Event class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName.endsWith('Event')) return; // Not a base class
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when Bloc state classes are not sealed.
///
/// Sealed state classes ensure exhaustive pattern matching in widgets
/// and prevent unexpected state subtypes from being created.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// abstract class UserState {}
/// class LoadingState extends UserState {}
/// ```
///
/// #### GOOD:
/// ```dart
/// sealed class UserState {}
/// class LoadingState extends UserState {}
/// ```
class PreferSealedBlocStateRule extends SaropaLintRule {
  const PreferSealedBlocStateRule() : super(code: _code);

  /// Code quality. Sealed classes improve type safety.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_sealed_bloc_state',
    problemMessage: '[prefer_sealed_bloc_state] Bloc state base class should be sealed.',
    correctionMessage: 'Use sealed keyword for exhaustive pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with State
      final String className = node.name.lexeme;
      if (!className.endsWith('State')) return;

      // Check if it's a base class (abstract without extending another State)
      if (node.abstractKeyword == null) return;

      // Check if it's already sealed
      if (node.sealedKeyword != null) return;

      // Check if it doesn't extend another State class (excluding Flutter State)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName.endsWith('State') && superName != 'State') {
          return; // Not a base class
        }
      }

      reporter.atNode(node, code);
    });
  }
}

/// Suggests that Bloc event classes end with 'Event' suffix.
///
/// Consistent naming helps identify Bloc event classes quickly.
///
/// **BAD:**
/// ```dart
/// abstract class UserAction {}  // Should end with Event
/// class LoadUser extends UserAction {}
/// ```
///
/// **GOOD:**
/// ```dart
/// abstract class UserEvent {}
/// class LoadUserEvent extends UserEvent {}
/// ```
class PreferBlocEventSuffixRule extends SaropaLintRule {
  const PreferBlocEventSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_event_suffix',
    problemMessage: '[prefer_bloc_event_suffix] Bloc event class should end with "Event" suffix.',
    correctionMessage: 'Rename class to include Event suffix (e.g., LoadUserEvent).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;

      // Check if this class extends something that ends with Event
      // but this class itself doesn't end with Event
      if (superName.endsWith('Event')) {
        final String className = node.name.lexeme;
        if (!className.endsWith('Event')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Suggests that Bloc state classes end with 'State' suffix.
///
/// Consistent naming helps identify Bloc state classes quickly.
///
/// **BAD:**
/// ```dart
/// abstract class UserStatus {}  // Should end with State
/// class UserLoading extends UserStatus {}
/// ```
///
/// **GOOD:**
/// ```dart
/// abstract class UserState {}
/// class UserLoadingState extends UserState {}
/// ```
class PreferBlocStateSuffixRule extends SaropaLintRule {
  const PreferBlocStateSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_state_suffix',
    problemMessage: '[prefer_bloc_state_suffix] Bloc state class should end with "State" suffix.',
    correctionMessage: 'Rename class to include State suffix (e.g., UserLoadingState).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;

      // Check if this class extends something that ends with State (but not Flutter's State)
      // and this class itself doesn't end with State
      if (superName.endsWith('State') && superName != 'State') {
        final String className = node.name.lexeme;
        if (!className.endsWith('State')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

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
      final TypeArgumentList? typeArgs = node.constructorName.type.typeArguments;
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

/// Warns when long Provider access chains are used.
///
/// Long chains like context.read<A>().read<B>().value are hard to read.
/// Consider using extension methods.
///
/// **BAD:**
/// ```dart
/// final value = context.read<MyProvider>().read<SubProvider>().value;
/// ```
///
/// **GOOD:**
/// ```dart
/// extension MyProviderX on BuildContext {
///   MyValue get myValue => read<MyProvider>().read<SubProvider>().value;
/// }
/// final value = context.myValue;
/// ```
class PreferProviderExtensionsRule extends SaropaLintRule {
  const PreferProviderExtensionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_provider_extensions',
    problemMessage: '[prefer_provider_extensions] Long provider access chain is hard to read.',
    correctionMessage: 'Consider using an extension method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'read' && methodName != 'watch' && methodName != 'select') {
        return;
      }

      // Check if this is a chained call (target is also a method invocation)
      final Expression? target = node.target;
      if (target is MethodInvocation) {
        final String targetMethod = target.methodName.name;
        if (targetMethod == 'read' || targetMethod == 'watch') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when .obs is used inside build() method.
///
/// Creating reactive variables in build() causes memory leaks and
/// unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final count = 0.obs; // Creates new Rx every rebuild!
///   return Obx(() => Text('$count'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final count = 0.obs;
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Obx(() => Text('${controller.count}'));
/// }
/// ```
class AvoidGetxRxInsideBuildRule extends SaropaLintRule {
  const AvoidGetxRxInsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_rx_inside_build',
    problemMessage: '[avoid_getx_rx_inside_build] Creating .obs in build() causes memory leaks.',
    correctionMessage: 'Move reactive variables to a GetxController.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Visit method body for .obs usage
      node.body.visitChildren(_ObsVisitor(reporter, code));
    });
  }
}

class _ObsVisitor extends RecursiveAstVisitor<void> {
  _ObsVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'obs') {
      reporter.atNode(node, code);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'obs') {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when Rx variables are reassigned instead of updated.
///
/// Reassigning Rx variables breaks the reactive chain.
///
/// **BAD:**
/// ```dart
/// count = 5.obs; // Breaks reactivity!
/// ```
///
/// **GOOD:**
/// ```dart
/// count.value = 5; // Properly updates value
/// count(5); // Or use callable syntax
/// ```
class AvoidMutableRxVariablesRule extends SaropaLintRule {
  const AvoidMutableRxVariablesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_mutable_rx_variables',
    problemMessage: '[avoid_mutable_rx_variables] Reassigning Rx variable breaks reactivity.',
    correctionMessage: 'Use .value = or callable syntax to update.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check if right side is .obs call
      final Expression right = node.rightHandSide;
      if (right is PropertyAccess && right.propertyName.name == 'obs') {
        reporter.atNode(node, code);
      }
      if (right is PrefixedIdentifier && right.identifier.name == 'obs') {
        reporter.atNode(node, code);
      }
      // Check for direct Rx constructor
      if (right is InstanceCreationExpression) {
        final String? typeName = right.constructorName.type.element?.name;
        if (typeName != null && _rxTypes.contains(typeName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  static const Set<String> _rxTypes = <String>{
    'Rx',
    'RxInt',
    'RxDouble',
    'RxString',
    'RxBool',
    'RxList',
    'RxMap',
    'RxSet',
  };
}

/// Warns when Provider.create returns a disposable instance without dispose callback.
///
/// When a Provider creates an instance that has a dispose() method, it should
/// also provide a dispose callback to clean up the instance.
///
/// **BAD:**
/// ```dart
/// Provider<MyService>(
///   create: (_) => MyService(), // MyService has dispose()!
///   child: MyApp(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Provider<MyService>(
///   create: (_) => MyService(),
///   dispose: (_, service) => service.dispose(),
///   child: MyApp(),
/// )
/// ```
class DisposeProvidedInstancesRule extends SaropaLintRule {
  const DisposeProvidedInstancesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'dispose_provided_instances',
    problemMessage:
        '[dispose_provided_instances] Provider creates disposable instance without dispose callback, causing memory leaks.',
    correctionMessage: 'Add dispose: (_, instance) => instance.dispose() to clean up.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'FocusNode',
    'StreamController',
    'StreamSubscription',
    'Timer',
    'ChangeNotifier',
    'ValueNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;

      if (typeName != 'Provider') return;
      if (constructorName.name?.name == 'value') return;

      bool hasDispose = false;
      Expression? createExpression;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'dispose') hasDispose = true;
          if (name == 'create') createExpression = arg.expression;
        }
      }

      if (hasDispose || createExpression == null) return;

      // Check if create returns a disposable type
      if (createExpression is FunctionExpression) {
        final FunctionBody body = createExpression.body;
        if (body is ExpressionFunctionBody) {
          final Expression expr = body.expression;
          if (expr is InstanceCreationExpression) {
            final String? createdType =
                expr.constructorName.type.element?.name ?? expr.constructorName.type.name.lexeme;
            if (_disposableTypes.contains(createdType)) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when GetxController has Worker fields that are not disposed.
///
/// Workers created with ever(), once(), debounce(), etc. must be stored
/// and disposed in onClose() to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///   // Missing onClose with _worker.dispose()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///
///   @override
///   void onClose() {
///     _worker.dispose();
///     super.onClose();
///   }
/// }
/// ```
class DisposeGetxFieldsRule extends SaropaLintRule {
  const DisposeGetxFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'dispose_getx_fields',
    problemMessage: '[dispose_getx_fields] Undisposed Worker keeps timer running after '
        'GetxController closes, causing memory leaks and stale updates.',
    correctionMessage: 'Call dispose() on Worker fields in onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends GetxController
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'GetxController' && superName != 'GetxService') return;

      // Find Worker fields
      final List<String> workerFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName == 'Worker' || typeName == 'Worker?') {
            for (final VariableDeclaration variable in member.fields.variables) {
              workerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (workerFields.isEmpty) return;

      // Check if onClose exists and disposes all workers
      bool hasOnClose = false;
      final Set<String> disposedFields = <String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'onClose') {
          hasOnClose = true;
          // Check for dispose calls
          member.body.visitChildren(_DisposeVisitor(
            onDispose: (String fieldName) {
              disposedFields.add(fieldName);
            },
          ));
        }
      }

      // Report if no onClose or missing dispose calls
      if (!hasOnClose && workerFields.isNotEmpty) {
        reporter.atNode(node, code);
      } else {
        for (final String field in workerFields) {
          if (!disposedFields.contains(field)) {
            reporter.atNode(node, code);
            break;
          }
        }
      }
    });
  }
}

class _DisposeVisitor extends RecursiveAstVisitor<void> {
  _DisposeVisitor({required this.onDispose});

  final void Function(String) onDispose;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        onDispose(target.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Provider type parameter is non-nullable but create returns null.
///
/// When a Provider's create callback explicitly returns null, the type
/// parameter should be nullable to prevent runtime errors.
///
/// **BAD:**
/// ```dart
/// Provider<User>( // Non-nullable but returns null!
///   create: (_) => null,
///   child: MyApp(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Provider<User?>( // Nullable type matches reality
///   create: (_) => currentUser,
///   child: MyApp(),
/// )
/// ```
class PreferNullableProviderTypesRule extends SaropaLintRule {
  const PreferNullableProviderTypesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_nullable_provider_types',
    problemMessage:
        '[prefer_nullable_provider_types] Provider type is non-nullable but create may return null.',
    correctionMessage: 'Use nullable type parameter: Provider<Type?>.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;

      if (typeName != 'Provider') return;

      // Check if type argument is nullable
      final TypeArgumentList? typeArgs = constructorName.type.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final TypeAnnotation typeArg = typeArgs.arguments.first;
      final bool isNullable = typeArg.question != null;

      if (isNullable) return; // Already nullable, good!

      // Check if create callback contains null return or null literal
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            // Check body for null returns
            final _NullReturnVisitor visitor = _NullReturnVisitor();
            createExpr.body.accept(visitor);
            if (visitor.hasNullReturn) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

class _NullReturnVisitor extends RecursiveAstVisitor<void> {
  bool hasNullReturn = false;

  @override
  void visitNullLiteral(NullLiteral node) {
    // Check if this null is being returned
    final AstNode? parent = node.parent;
    if (parent is ReturnStatement ||
        parent is ExpressionFunctionBody ||
        parent is ConditionalExpression) {
      hasNullReturn = true;
    }
    super.visitNullLiteral(node);
  }
}

// =============================================================================
// Part 6 Rules: Additional State Management Rules
// =============================================================================

/// Warns when yield is used inside Bloc event handler.
///
/// In Bloc 8.0+, yield was replaced with emit(). Using yield in `on<Event>`
/// handlers is deprecated and won't work correctly.
///
/// **BAD:**
/// ```dart
/// on<MyEvent>((event, emit) async* {
///   yield LoadingState();  // Wrong!
///   yield LoadedState();
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// on<MyEvent>((event, emit) async {
///   emit(LoadingState());
///   emit(LoadedState());
/// });
/// ```
class AvoidYieldInOnEventRule extends SaropaLintRule {
  const AvoidYieldInOnEventRule() : super(code: _code);

  /// Using yield in Bloc handlers is deprecated and broken.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_yield_in_on_event',
    problemMessage: '[avoid_yield_in_on_event] yield breaks Bloc 8.0+ concurrency and '
        'event ordering, causing unpredictable state updates.',
    correctionMessage: 'Replace yield with emit() - yield is deprecated in Bloc 8.0+.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addYieldStatement((YieldStatement node) {
      // Check if inside on<Event> handler
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodInvocation) {
          final String methodName = current.methodName.name;
          if (methodName == 'on') {
            reporter.atNode(node, code);
            return;
          }
        }
        if (current is ClassDeclaration) break;
        current = current.parent;
      }
    });
  }
}

/// Warns when `Provider.of<T>(context)` sis used in build method.
///
/// Provider.of rebuilds on every change. Use Consumer or context.watch
/// for more granular rebuilds.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final user = Provider.of<User>(context);
///   return Text(user.name);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Consumer<User>(
///     builder: (context, user, child) => Text(user.name),
///   );
/// }
/// ```
class PreferConsumerOverProviderOfRule extends SaropaLintRule {
  const PreferConsumerOverProviderOfRule() : super(code: _code);

  /// Provider.of causes unnecessary rebuilds compared to Consumer.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_consumer_over_provider_of',
    problemMessage:
        '[prefer_consumer_over_provider_of] Provider.of in build. Use Consumer for granular rebuilds.',
    correctionMessage: 'Replace with Consumer<T> or context.select() for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Provider.of
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Provider') return;
      if (node.methodName.name != 'of') return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when context.watch() is used inside async callback.
///
/// watch() subscribes to changes and should only be used synchronously
/// in build. Using it in async callbacks causes subscription leaks.
///
/// **BAD:**
/// ```dart
/// onPressed: () async {
///   final data = context.watch<MyData>();  // Wrong!
///   await doSomething(data);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPressed: () async {
///   final data = context.read<MyData>();  // Correct
///   await doSomething(data);
/// }
/// ```
class AvoidListenInAsyncRule extends SaropaLintRule {
  const AvoidListenInAsyncRule() : super(code: _code);

  /// watch() in async callbacks causes subscription leaks.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_listen_in_async',
    problemMessage:
        '[avoid_listen_in_async] context.watch() in async callback triggers rebuild during async, causing stale closures.',
    correctionMessage: 'Replace watch() with read() in async callbacks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'watch') return;

      // Check if target is context
      final Expression? target = node.target;
      if (target == null) return;
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('context')) return;

      // Check if inside async function
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) {
          if (current.body.isAsynchronous) {
            reporter.atNode(node, code);
            return;
          }
        }
        if (current is MethodDeclaration) {
          if (current.body.isAsynchronous) {
            // Only report if not in build method
            if (current.name.lexeme != 'build') {
              reporter.atNode(node, code);
            }
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when .obs property is accessed without Obx wrapper.
///
/// GetX reactive variables (.obs) must be inside Obx/GetX builder
/// to trigger rebuilds. Direct access won't update the UI.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   return Text(controller.count.value.toString());  // No rebuild!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(context) {
///   return Obx(() => Text(controller.count.value.toString()));
/// }
/// ```
class PreferGetxBuilderRule extends SaropaLintRule {
  const PreferGetxBuilderRule() : super(code: _code);

  /// Accessing .obs without Obx won't trigger UI rebuilds.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_getx_builder',
    problemMessage:
        '[prefer_getx_builder] .obs value accessed without Obx wrapper. UI won\'t rebuild.',
    correctionMessage: 'Wrap in Obx(() => ...) to enable reactive updates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'value') return;

      // Check if target ends with .obs pattern
      final Expression target = node.target!;
      final String targetSource = target.toSource();
      if (!targetSource.contains('.obs') &&
          !targetSource.contains('Rx') &&
          !targetSource.contains('rx')) {
        return;
      }

      // Check if inside build method but NOT inside Obx
      bool insideBuild = false;
      bool insideObx = false;

      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          insideBuild = true;
        }
        if (current is MethodInvocation) {
          final String methodName = current.methodName.name;
          if (methodName == 'Obx' || methodName == 'GetX' || methodName == 'GetBuilder') {
            insideObx = true;
          }
        }
        if (current is InstanceCreationExpression) {
          final String typeName = current.constructorName.type.name.lexeme;
          if (typeName == 'Obx' || typeName == 'GetX' || typeName == 'GetBuilder') {
            insideObx = true;
          }
        }
        current = current.parent;
      }

      if (insideBuild && !insideObx) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc state is mutated with cascade instead of new instance.
///
/// Bloc states should be immutable. Using cascade (..) to mutate existing
/// state breaks Bloc's equality comparison and causes missed rebuilds.
///
/// **BAD:**
/// ```dart
/// emit(state..items.add(newItem));  // Mutation!
/// emit(state..count = newCount);
/// ```
///
/// **GOOD:**
/// ```dart
/// emit(state.copyWith(items: [...state.items, newItem]));
/// emit(MyState(count: newCount));
/// ```
class EmitNewBlocStateInstancesRule extends SaropaLintRule {
  const EmitNewBlocStateInstancesRule() : super(code: _code);

  /// State mutation breaks Bloc equality and causes bugs.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'emit_new_bloc_state_instances',
    problemMessage: '[emit_new_bloc_state_instances] Mutating state object breaks equality '
        'checks, preventing BlocBuilder from detecting changes.',
    correctionMessage: 'Use copyWith() or constructor to create new state.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'emit') return;

      // Check argument for cascade expression
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression arg = args.first;
      if (arg is CascadeExpression) {
        // Check if target is 'state'
        final String targetSource = arg.target.toSource();
        if (targetSource == 'state') {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when Bloc has public non-final fields.
///
/// Bloc internals should be private. Public fields expose implementation
/// details and allow external modification of state.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   int counter = 0;  // Public mutable field
///   List<Item> items = [];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   int _counter = 0;  // Private
///   final List<Item> _items = [];
/// }
/// ```
class AvoidBlocPublicFieldsRule extends SaropaLintRule {
  const AvoidBlocPublicFieldsRule() : super(code: _code);

  /// Public fields expose Bloc internals and break encapsulation.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_public_fields',
    problemMessage: '[avoid_bloc_public_fields] Public field in Bloc. Keep internals private.',
    correctionMessage: 'Make field private (_fieldName) or final.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc or Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check for public non-final fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          // Skip if private (starts with _)
          for (final VariableDeclaration field in member.fields.variables) {
            final String fieldName = field.name.lexeme;
            if (!fieldName.startsWith('_') && !member.fields.isFinal) {
              reporter.atNode(field, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Bloc has public methods other than add().
///
/// Bloc should only expose add() for events. Other public methods
/// break the event-driven architecture and make testing harder.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void loadData() { ... }  // Direct method call!
///   void reset() { ... }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   // Use events instead
///   // bloc.add(LoadDataEvent());
///   // bloc.add(ResetEvent());
/// }
/// ```
class AvoidBlocPublicMethodsRule extends SaropaLintRule {
  const AvoidBlocPublicMethodsRule() : super(code: _code);

  /// Public methods bypass Bloc's event-driven architecture.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_public_methods',
    problemMessage:
        '[avoid_bloc_public_methods] Public method in Bloc. Use events via add() instead.',
    correctionMessage: 'Convert to event class and handle in on<Event>().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _allowedMethods = <String>{
    'add',
    'close',
    'emit',
    'on',
    'onChange',
    'onError',
    'onEvent',
    'onTransition',
    'toString',
    'hashCode',
    'noSuchMethod',
    'runtimeType',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Check for public methods
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          // Skip private, allowed, and overrides
          if (methodName.startsWith('_')) continue;
          if (_allowedMethods.contains(methodName)) continue;
          if (member.metadata.any((a) => a.name.name == 'override')) continue;

          reporter.atToken(member.name, code);
        }
      }
    });
  }
}

/// Warns when AsyncValue.when() has incorrect parameter order.
///
/// The standard order is data, error, loading. Incorrect order makes
/// code harder to read and may indicate confusion about the API.
///
/// **BAD:**
/// ```dart
/// asyncValue.when(
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => ErrorWidget(e),
///   data: (d) => DataWidget(d),  // Wrong order
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// asyncValue.when(
///   data: (d) => DataWidget(d),
///   error: (e, s) => ErrorWidget(e),
///   loading: () => CircularProgressIndicator(),
/// );
/// ```
class RequireAsyncValueOrderRule extends SaropaLintRule {
  const RequireAsyncValueOrderRule() : super(code: _code);

  /// Consistent ordering improves code readability.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_async_value_order',
    problemMessage:
        '[require_async_value_order] AsyncValue.when() has non-standard parameter order.',
    correctionMessage: 'Use order: data, error, loading for consistency.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'when') return;

      // Check named arguments order
      final List<String> paramOrder = <String>[];

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'data' || name == 'error' || name == 'loading') {
            paramOrder.add(name);
          }
        }
      }

      // Expected order: data, error, loading
      if (paramOrder.length == 3) {
        if (paramOrder[0] != 'data' || paramOrder[1] != 'error' || paramOrder[2] != 'loading') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when BlocBuilder accesses only one field from state.
///
/// Using BlocSelector instead of BlocBuilder when you only need one
/// field prevents unnecessary rebuilds when other fields change.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<MyBloc, MyState>(
///   builder: (context, state) {
///     return Text(state.name);  // Only uses one field
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocSelector<MyBloc, MyState, String>(
///   selector: (state) => state.name,
///   builder: (context, name) {
///     return Text(name);
///   },
/// )
/// ```
class RequireBlocSelectorRule extends SaropaLintRule {
  const RequireBlocSelectorRule() : super(code: _code);

  /// BlocSelector provides more targeted rebuilds.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_selector',
    problemMessage:
        '[require_bloc_selector] BlocBuilder accessing single field. Use BlocSelector instead.',
    correctionMessage: 'Replace with BlocSelector for targeted rebuilds on specific field.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocBuilder') return;

      // Find builder parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            // Count state property accesses
            final _StateAccessCounter counter = _StateAccessCounter();
            builderExpr.body.accept(counter);

            // If only one unique field is accessed, suggest BlocSelector
            if (counter.accessedFields.length == 1 && counter.accessCount <= 2) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

class _StateAccessCounter extends RecursiveAstVisitor<void> {
  final Set<String> accessedFields = <String>{};
  int accessCount = 0;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'state') {
      accessedFields.add(node.propertyName.name);
      accessCount++;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'state') {
      accessedFields.add(node.identifier.name);
      accessCount++;
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when context.watch<T>() is used without select().
///
/// watch() rebuilds on any change to the provider. Using select()
/// limits rebuilds to specific property changes.
///
/// **BAD:**
/// ```dart
/// final user = context.watch<UserNotifier>().user;
/// // Rebuilds on ANY UserNotifier change
/// ```
///
/// **GOOD:**
/// ```dart
/// final user = context.select<UserNotifier, User>((n) => n.user);
/// // Only rebuilds when user changes
/// ```
class PreferSelectorRule extends SaropaLintRule {
  const PreferSelectorRule() : super(code: _code);

  /// select() provides more granular rebuild control.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_context_selector',
    problemMessage:
        '[prefer_context_selector] context.watch() accessing property. Use select() for efficiency.',
    correctionMessage: 'Replace with context.select((notifier) => notifier.field).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check if target is context.watch()
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      if (target.methodName.name != 'watch') return;

      // Check if called on context
      final Expression? watchTarget = target.target;
      if (watchTarget == null) return;
      final String watchTargetSource = watchTarget.toSource().toLowerCase();
      if (!watchTargetSource.contains('context')) return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when GetxController is used without proper Binding registration.
///
/// GetX controllers should be registered via Bindings for proper
/// lifecycle management and dependency injection.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   // Used directly without binding
/// }
///
/// // In widget:
/// final controller = Get.put(MyController());
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBinding extends Bindings {
///   @override
///   void dependencies() {
///     Get.lazyPut(() => MyController());
///   }
/// }
///
/// // In route:
/// GetPage(name: '/my', page: () => MyPage(), binding: MyBinding());
/// ```
class RequireGetxBindingRule extends SaropaLintRule {
  const RequireGetxBindingRule() : super(code: _code);

  /// Architecture issue - improper dependency management.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_getx_binding',
    problemMessage:
        '[require_getx_binding] Get.put() in widget. Consider using Bindings for lifecycle management.',
    correctionMessage: 'Create a Binding class and register via GetPage binding parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Get.put() or Get.find()
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Get') return;

      if (node.methodName.name != 'put') return;

      // Check if inside a widget build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// Part 4: Missing Parameter Rules
// =============================================================================

/// Warns when Provider.of is used without a generic type parameter.
///
/// Alias: provider_missing_type, provider_generic_required
///
/// Provider.of without a type parameter returns dynamic, losing type safety.
///
/// **BAD:**
/// ```dart
/// final model = Provider.of(context);  // Returns dynamic!
/// ```
///
/// **GOOD:**
/// ```dart
/// final model = Provider.of<MyModel>(context);
/// // Or better, use context.read/watch:
/// final model = context.read<MyModel>();
/// ```
class RequireProviderGenericTypeRule extends SaropaLintRule {
  const RequireProviderGenericTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_provider_generic_type',
    problemMessage: '[require_provider_generic_type] Missing generic type causes runtime '
        'cast errors when Provider returns dynamic instead of expected type.',
    correctionMessage: 'Add <Type> to Provider.of<Type>(context).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Provider.of
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Provider') return;
      if (node.methodName.name != 'of') return;

      // Check if type argument is missing
      final typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

// =============================================================================
// Part 5: Bloc API Pattern Rules
// =============================================================================

/// Warns when emit() is called without checking isClosed in async handlers.
///
/// Alias: bloc_emit_after_close, unsafe_emit
///
/// After async operations, the Bloc may have been closed. Emitting to a
/// closed Bloc throws an error.
///
/// **BAD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();
///   emit(LoadedState(data));  // Bloc might be closed!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();
///   if (!isClosed) {
///     emit(LoadedState(data));
///   }
/// }
/// ```
class AvoidBlocEmitAfterCloseRule extends SaropaLintRule {
  const AvoidBlocEmitAfterCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_emit_after_close',
    problemMessage:
        '[avoid_bloc_emit_after_close] Calling emit() after an await may throw an exception if the Bloc has been closed, leading to runtime errors and unpredictable state changes. This can cause crashes or silent failures, especially in asynchronous event handlers. Always check that the Bloc is still open before emitting new states after an await.',
    correctionMessage:
        'Before calling emit() after an await, add an "if (!isClosed)" check to ensure the Bloc is still active. This prevents exceptions and ensures state updates are only performed on open Blocs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'emit') return;

      // Find enclosing method
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

      // Check if method is async
      if (enclosingMethod.body is! BlockFunctionBody) return;
      final body = enclosingMethod.body as BlockFunctionBody;
      if (body.keyword?.lexeme != 'async') return;

      // Check if emit is after an await expression
      final methodSource = enclosingMethod.body.toSource();
      final emitOffset = node.offset - enclosingMethod.body.offset;

      // Simple heuristic: check if there's an await before this emit
      final beforeEmit = methodSource.substring(0, emitOffset.clamp(0, methodSource.length));
      if (!beforeEmit.contains('await ')) return;

      // Check if there's an isClosed check protecting this emit
      AstNode? parentNode = node.parent;
      bool hasIsClosedCheck = false;

      while (parentNode != null && parentNode != enclosingMethod) {
        if (parentNode is IfStatement) {
          final condition = parentNode.expression.toSource();
          if (condition.contains('isClosed') || condition.contains('!isClosed')) {
            hasIsClosedCheck = true;
            break;
          }
        }
        parentNode = parentNode.parent;
      }

      if (!hasIsClosedCheck) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Bloc state is mutated directly instead of using copyWith.
///
/// Alias: bloc_state_direct_mutation, immutable_bloc_state
///
/// Bloc states should be immutable. Direct mutation causes bugs because
/// the framework compares by reference.
///
/// **BAD:**
/// ```dart
/// void _onUpdate(UpdateEvent event, Emitter<State> emit) {
///   state.name = event.name;  // Direct mutation!
///   emit(state);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _onUpdate(UpdateEvent event, Emitter<State> emit) {
///   emit(state.copyWith(name: event.name));
/// }
/// ```
class AvoidBlocStateMutationRule extends SaropaLintRule {
  const AvoidBlocStateMutationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_state_mutation',
    problemMessage: '[avoid_bloc_state_mutation] Direct mutation bypasses equality checks, '
        'preventing UI rebuild and causing stale data display.',
    correctionMessage: 'Use state.copyWith() to create a new state instance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check for state.field = value pattern
      final leftSide = node.leftHandSide;
      if (leftSide is! PropertyAccess) return;

      final target = leftSide.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'state') return;

      // Check if inside a Bloc class
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ClassDeclaration) {
          final extendsClause = current.extendsClause;
          if (extendsClause != null) {
            final superName = extendsClause.superclass.name.lexeme;
            if (superName == 'Bloc' || superName == 'Cubit') {
              reporter.atNode(leftSide, code);
              return;
            }
          }
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when Bloc constructor doesn't call super with initial state.
///
/// Alias: bloc_missing_initial_state, bloc_super_required
///
/// Every Bloc must specify its initial state in the super() constructor call.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() {  // Missing super call!
///     on<MyEvent>(_onEvent);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc() : super(MyInitialState()) {
///     on<MyEvent>(_onEvent);
///   }
/// }
/// ```
class RequireBlocInitialStateRule extends SaropaLintRule {
  const RequireBlocInitialStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_initial_state',
    problemMessage: '[require_bloc_initial_state] Missing initial state throws '
        'LateInitializationError when BlocBuilder tries to read state.',
    correctionMessage: 'Add : super(InitialState()) to the constructor.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Find constructors
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          // Check for super initializer
          bool hasSuperInit = false;
          for (final initializer in member.initializers) {
            if (initializer is SuperConstructorInvocation) {
              hasSuperInit = true;
              break;
            }
          }

          if (!hasSuperInit) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// Part 6: Additional Rules - Freezed
// =============================================================================

/// Warns when both @freezed and @JsonSerializable are used on same class.
///
/// Alias: freezed_json_conflict, duplicate_json_annotation
///
/// @freezed already generates JSON serialization. Adding @JsonSerializable
/// causes conflicts and duplicate code.
///
/// **BAD:**
/// ```dart
/// @freezed
/// @JsonSerializable()  // Conflict!
/// class User with _$User {
///   factory User({String? name}) = _User;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({String? name}) = _User;
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
/// }
/// ```
class AvoidFreezedJsonSerializableConflictRule extends SaropaLintRule {
  const AvoidFreezedJsonSerializableConflictRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_freezed_json_serializable_conflict',
    problemMessage:
        '[avoid_freezed_json_serializable_conflict] Applying both @freezed and @JsonSerializable to the same class causes code generation conflicts and unpredictable serialization behavior. This can result in broken toJson/fromJson methods, runtime errors, and maintenance headaches. Only one annotation should be used for JSON serialization.',
    correctionMessage:
        'Remove the @JsonSerializable annotation when using @freezed. The @freezed package provides its own JSON serialization logic and does not require @JsonSerializable.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      bool hasFreezed = false;
      Annotation? jsonSerializableAnnotation;

      for (final annotation in node.metadata) {
        final name = annotation.name.name.toLowerCase();
        if (name == 'freezed') {
          hasFreezed = true;
        }

        // cspell:ignore jsonserializable
        if (name == 'jsonserializable') {
          jsonSerializableAnnotation = annotation;
        }
      }

      if (hasFreezed && jsonSerializableAnnotation != null) {
        reporter.atNode(jsonSerializableAnnotation, code);
      }
    });
  }
}

// cspell:ignore freezed_fromjson_syntax
/// Warns when Freezed fromJson has block body instead of arrow syntax.
///
/// Alias: freezed_fromjson_syntax, freezed_arrow_required
///
/// Freezed fromJson factory must use arrow syntax for code generation.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User.fromJson(Map<String, dynamic> json) {
///     return _$UserFromJson(json);  // Block body - won't work!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
/// }
/// ```
class RequireFreezedArrowSyntaxRule extends SaropaLintRule {
  const RequireFreezedArrowSyntaxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_arrow_syntax',
    problemMessage:
        '[require_freezed_arrow_syntax] The fromJson factory in a @freezed class must use arrow syntax (=>) to ensure correct code generation. Using block syntax ({}) breaks the generated code, causing runtime errors, missing serialization, and build_runner failures. This leads to broken deserialization and hard-to-debug bugs in your models.',
    correctionMessage:
        'Change the fromJson factory to use arrow syntax. Example: factory User.fromJson(Map<String, dynamic> json) => _\$UserFromJson(json);',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check for @freezed annotation
      bool hasFreezed = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'freezed') {
          hasFreezed = true;
          break;
        }
      }

      if (!hasFreezed) return;

      // Check fromJson factory
      for (final member in node.members) {
        if (member is ConstructorDeclaration &&
            member.factoryKeyword != null &&
            member.name?.lexeme == 'fromJson') {
          // Check if it uses block body instead of arrow
          final body = member.body;
          if (body is BlockFunctionBody) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Freezed class is missing the private constructor.
///
/// Alias: freezed_private_ctor, freezed_underscore_ctor
///
/// Freezed classes need a private constructor for methods like copyWith.
///
/// **BAD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   factory User({String? name}) = _User;
///   // Missing: const User._();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @freezed
/// class User with _$User {
///   const User._();  // Required for custom methods
///   factory User({String? name}) = _User;
/// }
/// ```
class RequireFreezedPrivateConstructorRule extends SaropaLintRule {
  const RequireFreezedPrivateConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_freezed_private_constructor',
    problemMessage: '[require_freezed_private_constructor] Missing private constructor '
        'breaks code generation, causing build_runner to fail.',
    correctionMessage: 'Add: const ClassName._();',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check for @freezed annotation
      bool hasFreezed = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'freezed') {
          hasFreezed = true;
          break;
        }
      }

      if (!hasFreezed) return;

      // Check for private constructor (ClassName._)
      bool hasPrivateConstructor = false;
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          final ctorName = member.name?.lexeme ?? '';
          if (ctorName == '_') {
            hasPrivateConstructor = true;
            break;
          }
        }
      }

      // Only warn if class has custom methods that need the private ctor
      bool hasCustomMethods = false;
      for (final member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme != 'toString' &&
            member.name.lexeme != 'toJson') {
          hasCustomMethods = true;
          break;
        }
      }

      if (!hasPrivateConstructor && hasCustomMethods) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Part 6: Additional Rules - Equatable
// =============================================================================

/// Warns when Equatable class has non-final fields.
///
/// Alias: equatable_mutable_field, immutable_equatable
///
/// Equatable classes must be immutable for equality to work correctly.
///
/// **BAD:**
/// ```dart
/// class User extends Equatable {
///   String name;  // Non-final!
///   @override
///   List<Object?> get props => [name];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class User extends Equatable {
///   final String name;
///   const User(this.name);
///   @override
///   List<Object?> get props => [name];
/// }
/// ```
class RequireEquatableImmutableRule extends SaropaLintRule {
  const RequireEquatableImmutableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_equatable_immutable',
    problemMessage: '[require_equatable_immutable] Mutable fields break equality after '
        'modification, causing BlocBuilder to miss state changes.',
    correctionMessage: 'Make all fields final.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'Equatable') return;

      // Check for non-final fields
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          if (!member.fields.isFinal && !member.isStatic) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Equatable class doesn't override props.
///
/// Alias: equatable_missing_props, props_override_required
///
/// Equatable requires props getter to define which fields affect equality.
///
/// **BAD:**
/// ```dart
/// class User extends Equatable {
///   final String name;
///   // Missing props!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class User extends Equatable {
///   final String name;
///   @override
///   List<Object?> get props => [name];
/// }
/// ```
class RequireEquatablePropsOverrideRule extends SaropaLintRule {
  const RequireEquatablePropsOverrideRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_equatable_props_override',
    problemMessage: '[require_equatable_props_override] Without props override, equality '
        'defaults to identity comparison, breaking state deduplication.',
    correctionMessage: 'Add: List<Object?> get props => [field1, field2];',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'Equatable') return;

      // Check for props getter
      bool hasProps = false;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.isGetter && member.name.lexeme == 'props') {
          hasProps = true;
          break;
        }
      }

      if (!hasProps) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Equatable uses mutable collections in props.
///
/// Alias: equatable_mutable_collection, immutable_props
///
/// Mutable List/Map in Equatable can change after creation, breaking equality.
///
/// **BAD:**
/// ```dart
/// class User extends Equatable {
///   final List<String> tags;  // Mutable list!
///   @override
///   List<Object?> get props => [tags];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class User extends Equatable {
///   final List<String> tags;
///   @override
///   List<Object?> get props => [List.unmodifiable(tags)];
///   // Or use IList from fast_immutable_collections
/// }
/// ```
class AvoidEquatableMutableCollectionsRule extends SaropaLintRule {
  const AvoidEquatableMutableCollectionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_equatable_mutable_collections',
    problemMessage:
        '[avoid_equatable_mutable_collections] Mutable collections in Equatable can break equality comparison.',
    correctionMessage: 'Use List.unmodifiable() or immutable collections like IList.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Equatable
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.name.lexeme != 'Equatable') return;

      // Check fields for mutable collections
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type?.toSource() ?? '';
          if (type.startsWith('List<') || type.startsWith('Map<') || type.startsWith('Set<')) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// Part 6: Additional Rules - Bloc & Static State
// =============================================================================

/// Warns when Bloc async handler doesn't emit loading state.
///
/// Alias: bloc_missing_loading, async_loading_state
///
/// Async operations should emit loading state to show UI feedback.
///
/// **BAD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   final data = await api.fetch();  // No loading state!
///   emit(LoadedState(data));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _onFetch(FetchEvent event, Emitter<State> emit) async {
///   emit(LoadingState());
///   final data = await api.fetch();
///   emit(LoadedState(data));
/// }
/// ```
class RequireBlocLoadingStateRule extends SaropaLintRule {
  const RequireBlocLoadingStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_loading_state',
    problemMessage: '[require_bloc_loading_state] Async Bloc handler should emit loading state.',
    correctionMessage: 'Add emit(LoadingState()) before async operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check if async method
      if (node.body is! BlockFunctionBody) return;
      final body = node.body as BlockFunctionBody;
      if (body.keyword?.lexeme != 'async') return;

      // Check if in Bloc class
      final parent = node.parent;
      if (parent is! ClassDeclaration) return;
      final extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check if method has Emitter parameter (Bloc handler)
      bool hasEmitter = false;
      for (final param in node.parameters?.parameters ?? <FormalParameter>[]) {
        final paramSource = param.toSource();
        if (paramSource.contains('Emitter')) {
          hasEmitter = true;
          break;
        }
      }

      if (!hasEmitter) return;

      // Check if emit is called before await
      final methodSource = body.toSource();
      final awaitIndex = methodSource.indexOf('await ');
      if (awaitIndex == -1) return;

      final beforeAwait = methodSource.substring(0, awaitIndex);

      // cspell:ignore inprogress
      final hasLoadingEmit = beforeAwait.contains('emit(') &&
          (beforeAwait.toLowerCase().contains('loading') ||
              beforeAwait.toLowerCase().contains('inprogress'));

      if (!hasLoadingEmit) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc state sealed class doesn't have an error case.
///
/// Alias: bloc_missing_error_state, state_error_handling
///
/// Bloc states should include an error case for proper error handling.
///
/// **BAD:**
/// ```dart
/// sealed class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoaded extends UserState {}
/// // Missing error state!
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoaded extends UserState {}
/// class UserError extends UserState {}
/// ```
class RequireBlocErrorStateRule extends SaropaLintRule {
  const RequireBlocErrorStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_error_state',
    problemMessage: '[require_bloc_error_state] Bloc state sealed class should have an error case.',
    correctionMessage: 'Add an error state class (e.g., UserError).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if sealed class ending with State
      if (node.sealedKeyword == null) return;
      if (!node.name.lexeme.endsWith('State')) return;

      // This is a sealed state class - check file for error subclass
      final fileSource = resolver.source.contents.data;
      final className = node.name.lexeme;
      final baseName = className.replaceAll('State', '');

      // Look for error/failure subclass
      final hasError = fileSource.contains('${baseName}Error') ||
          fileSource.contains('${baseName}Failure') ||
          fileSource.contains('${className}Error') ||
          fileSource.contains('Error extends $className');

      if (!hasError) {
        reporter.atNode(node, code);
      }
    });
  }
}

// cspell:ignore antipattern
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
        '[avoid_static_state] Static mutable state can cause testing and hot-reload issues.',
    correctionMessage: 'Use proper state management (Provider, Riverpod, Bloc) instead.',
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
      final isMutableCollection =
          type.startsWith('List') || type.startsWith('Map') || type.startsWith('Set');

      // Non-final static or mutable collection
      if (!node.fields.isFinal || isMutableCollection) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT Part 7 Rules - Provider
// =============================================================================

/// Warns when Provider.of or context.read/watch is used in initState.
///
/// Alias: provider_in_init_state, read_in_init_state
///
/// Using Provider.of in initState can cause issues because the widget
/// tree may not be fully built yet. Use didChangeDependencies instead.
///
/// **BAD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   final user = Provider.of<User>(context); // May fail!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   final user = Provider.of<User>(context);
/// }
/// ```
class AvoidProviderInInitStateRule extends SaropaLintRule {
  const AvoidProviderInInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_provider_in_init_state',
    problemMessage:
        '[avoid_provider_in_init_state] Provider access in initState() may fail because context is not fully ready.',
    correctionMessage: 'Move to didChangeDependencies() instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Provider.of, context.read, context.watch
      bool isProviderCall = false;

      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Provider') {
        if (methodName == 'of') isProviderCall = true;
      } else if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        if (targetSource.contains('context') && (methodName == 'read' || methodName == 'watch')) {
          isProviderCall = true;
        }
      }

      if (!isProviderCall) return;

      // Check if inside initState
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration) {
          if (current.name.lexeme == 'initState') {
            reporter.atNode(node, code);
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Suggests using context.read instead of context.watch in callbacks.
///
/// Alias: watch_in_callbacks, read_for_callbacks
///
/// Using context.watch in button callbacks or event handlers will cause
/// unnecessary rebuilds. Use context.read for one-time access in callbacks.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     context.watch<Counter>().increment(); // Causes rebuild!
///   },
///   child: Text('Increment'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     context.read<Counter>().increment(); // One-time access
///   },
///   child: Text('Increment'),
/// )
/// ```
class PreferContextReadInCallbacksRule extends SaropaLintRule {
  const PreferContextReadInCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_context_read_in_callbacks',
    problemMessage:
        '[prefer_context_read_in_callbacks] context.watch should not be used in callbacks.',
    correctionMessage: 'Use context.read instead for one-time access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'watch') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('context')) return;

      // Check if inside a callback (FunctionExpression)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) {
          // Check if this is an event callback
          final AstNode? funcParent = current.parent;
          if (funcParent is NamedExpression) {
            final String paramName = funcParent.name.label.name;
            // Check for Flutter callback convention: onX where X is uppercase
            // This avoids false positives on 'once', 'only', etc.
            if (_isFlutterCallbackName(paramName) ||
                paramName == 'builder' ||
                paramName == 'callback') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
        if (current is MethodDeclaration) {
          // Check if inside build method - watch is OK there
          if (current.name.lexeme == 'build') return;
          break;
        }
        current = current.parent;
      }
    });
  }

  /// Check if parameter name follows Flutter callback convention: onX where X is uppercase.
  /// This avoids false positives on words like 'once', 'only', 'ongoing'.
  bool _isFlutterCallbackName(String name) {
    if (!name.startsWith('on')) return false;
    if (name.length < 3) return false;
    // The character after 'on' must be uppercase (e.g., onPressed, onTap)
    return name.codeUnitAt(2) >= 65 && name.codeUnitAt(2) <= 90; // A-Z
  }
}

// =============================================================================
// Bloc Disposal Rules
// =============================================================================

/// Warns when Bloc/Cubit has controllers or streams without close() cleanup.
///
/// Alias: bloc_dispose, bloc_close, cubit_dispose
///
/// Bloc and Cubit subclasses that create StreamControllers, TextEditingControllers,
/// or other disposable resources must override close() to dispose of them.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   final _controller = StreamController<int>();
///   final _textController = TextEditingController();
///
///   MyBloc() : super(MyInitial());
///   // Missing close() - resources leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   final _controller = StreamController<int>();
///   final _textController = TextEditingController();
///
///   MyBloc() : super(MyInitial());
///
///   @override
///   Future<void> close() {
///     _controller.close();
///     _textController.dispose();
///     return super.close();
///   }
/// }
/// ```
class RequireBlocManualDisposeRule extends SaropaLintRule {
  const RequireBlocManualDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_bloc_manual_dispose',
    problemMessage:
        '[require_bloc_manual_dispose] Bloc/Cubit has StreamController/Timer but no close() override to dispose them.',
    correctionMessage: 'Override close() to dispose controllers and close streams.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that require disposal in Bloc/Cubit close() method
  static const Set<String> _disposableTypes = <String>{
    'StreamController',
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'FocusNode',
    'Timer',
    'StreamSubscription',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc or Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Bloc') && !superName.contains('Cubit')) {
        return;
      }

      // Find disposable fields
      final List<String> disposableFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposableType in _disposableTypes) {
              if (typeName.contains(disposableType)) {
                for (final VariableDeclaration variable in member.fields.variables) {
                  disposableFields.add(variable.name.lexeme);
                }
                break;
              }
            }
          }
          // Also check initializers
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String initType = initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(initType)) {
                if (!disposableFields.contains(variable.name.lexeme)) {
                  disposableFields.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (disposableFields.isEmpty) return;

      // Check for close() method
      bool hasCloseMethod = false;
      String? closeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'close') {
          hasCloseMethod = true;
          closeBody = member.body.toSource();
          break;
        }
      }

      if (!hasCloseMethod) {
        // No close() method at all
        reporter.atToken(node.name, code);
        return;
      }

      // Check if all disposable fields are cleaned up
      for (final String fieldName in disposableFields) {
        final bool isCleaned = closeBody != null &&
            (closeBody.contains('$fieldName.close()') ||
                closeBody.contains('$fieldName?.close()') ||
                closeBody.contains('$fieldName.dispose()') ||
                closeBody.contains('$fieldName?.dispose()') ||
                closeBody.contains('$fieldName.cancel()') ||
                closeBody.contains('$fieldName?.cancel()'));

        if (!isCleaned) {
          // Report the specific field that's not cleaned up
          for (final ClassMember member in node.members) {
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
    });
  }
}

// =============================================================================
// Provider Dependency Rules
// =============================================================================

/// Warns when Provider depends on another provider but doesn't use ProxyProvider.
///
/// When a Provider needs to depend on another provider's value, using a plain
/// Provider with context.read() or context.watch() is fragile and error-prone.
/// ProxyProvider ensures proper dependency tracking and rebuild behavior.
///
/// **BAD:**
/// ```dart
/// Provider<MyService>(
///   create: (context) {
///     final auth = context.read<AuthService>(); // Dependency hidden in create
///     return MyService(auth);
///   },
///   child: ...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ProxyProvider<AuthService, MyService>(
///   update: (context, auth, previous) => MyService(auth),
///   child: ...
/// )
/// ```
class PreferProxyProviderRule extends SaropaLintRule {
  const PreferProxyProviderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_proxy_provider',
    problemMessage:
        '[prefer_proxy_provider] Provider.create() accesses other providers. Use ProxyProvider instead.',
    correctionMessage:
        'Use ProxyProvider, ProxyProvider2, etc. to properly declare provider dependencies.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Provider widget types that should use ProxyProvider for dependencies
  static const Set<String> _providerTypes = <String>{
    'Provider',
    'ChangeNotifierProvider',
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Only check Provider and ChangeNotifierProvider
      if (!_providerTypes.contains(typeName)) return;

      // Skip if this is already a ProxyProvider or MultiProvider
      if (typeName.contains('Proxy') || typeName.contains('Multi')) return;

      // Find the create callback argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final Expression createExpr = arg.expression;

          // Check if the create callback accesses other providers
          final _ProxyProviderAccessVisitor visitor = _ProxyProviderAccessVisitor();
          createExpr.visitChildren(visitor);

          if (visitor.accessesProviders) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Visitor that checks if code accesses other providers via context.read/watch.
class _ProxyProviderAccessVisitor extends RecursiveAstVisitor<void> {
  bool accessesProviders = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // Check for context.read<T>() or context.watch<T>() or Provider.of<T>()
    if (methodName == 'read' || methodName == 'watch') {
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource();
        if (targetSource.contains('context')) {
          accessesProviders = true;
        }
      }
    }

    // Check for Provider.of<T>(context)
    if (methodName == 'of') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Provider') {
        accessesProviders = true;
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when ProxyProvider doesn't properly handle the update callback.
///
/// ProxyProvider.update is called whenever a dependency changes. If the
/// callback doesn't properly handle the `previous` parameter, it may
/// cause memory leaks or miss important cleanup logic.
///
/// **BAD:**
/// ```dart
/// ProxyProvider<AuthService, MyService>(
///   update: (context, auth, _) => MyService(auth), // Ignores previous!
///   child: ...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ProxyProvider<AuthService, MyService>(
///   update: (context, auth, previous) {
///     // Dispose previous if needed, or reuse it
///     previous?.dispose();
///     return MyService(auth);
///   },
///   dispose: (context, service) => service.dispose(),
///   child: ...
/// )
/// ```
///
/// **ALSO GOOD (when previous doesn't need disposal):**
/// ```dart
/// ProxyProvider<AuthService, MyService>(
///   update: (context, auth, previous) => previous ?? MyService(auth),
///   child: ...
/// )
/// ```
class RequireUpdateCallbackRule extends SaropaLintRule {
  const RequireUpdateCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_update_callback',
    problemMessage:
        '[require_update_callback] ProxyProvider.update ignores the previous value. This may cause resource leaks.',
    correctionMessage:
        'Handle the previous parameter to dispose resources or reuse the existing instance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// ProxyProvider variants that have an update callback
  static const Set<String> _proxyProviderTypes = <String>{
    'ProxyProvider',
    'ProxyProvider0',
    'ProxyProvider2',
    'ProxyProvider3',
    'ProxyProvider4',
    'ProxyProvider5',
    'ProxyProvider6',
    'ChangeNotifierProxyProvider',
    'ChangeNotifierProxyProvider0',
    'ChangeNotifierProxyProvider2',
    'ChangeNotifierProxyProvider3',
    'ChangeNotifierProxyProvider4',
    'ChangeNotifierProxyProvider5',
    'ChangeNotifierProxyProvider6',
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Only check ProxyProvider variants
      if (!_proxyProviderTypes.contains(typeName)) return;

      // Find the update callback argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'update') {
          final Expression updateExpr = arg.expression;

          // Check if it's a function expression
          if (updateExpr is FunctionExpression) {
            _checkUpdateCallback(updateExpr, node, reporter);
          }
        }
      }
    });
  }

  void _checkUpdateCallback(
    FunctionExpression updateFunc,
    InstanceCreationExpression providerNode,
    SaropaDiagnosticReporter reporter,
  ) {
    final FormalParameterList? params = updateFunc.parameters;
    if (params == null) return;

    // The last parameter should be 'previous'
    final List<FormalParameter> paramList = params.parameters.toList();
    if (paramList.isEmpty) return;

    final FormalParameter lastParam = paramList.last;
    final String lastParamName = lastParam.name?.lexeme ?? '';

    // Check if the previous parameter is unused (named _ or starts with _)
    if (lastParamName == '_' || lastParamName.startsWith('_')) {
      // Previous is explicitly ignored, which is suspicious
      reporter.atNode(providerNode.constructorName, code);
      return;
    }

    // Check if the previous parameter is actually used in the body
    final FunctionBody body = updateFunc.body;
    final _UpdateCallbackParameterUsageVisitor usageVisitor =
        _UpdateCallbackParameterUsageVisitor(lastParamName);
    body.visitChildren(usageVisitor);

    if (!usageVisitor.isUsed) {
      reporter.atNode(providerNode.constructorName, code);
    }
  }
}

/// Visitor that checks if a parameter name is used in the code.
class _UpdateCallbackParameterUsageVisitor extends RecursiveAstVisitor<void> {
  _UpdateCallbackParameterUsageVisitor(this.paramName);

  final String paramName;
  bool isUsed = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == paramName) {
      isUsed = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

// =============================================================================
// Widget/API Replacement Suggestions
// =============================================================================

/// Suggests using Selector instead of Consumer for granular rebuilds.
///
/// Consumer rebuilds on any change to the provider. Selector only rebuilds
/// when the selected value changes, providing more granular control.
///
/// **BAD:**
/// ```dart
/// Consumer(
///   builder: (context, ref, child) {
///     final user = ref.watch(userProvider);
///     return Text(user.name); // Rebuilds on ANY user change
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Selector<UserNotifier, String>(
///   selector: (_, notifier) => notifier.user.name,
///   builder: (_, name, __) => Text(name), // Only rebuilds when name changes
/// )
/// // Or with Riverpod:
/// Consumer(
///   builder: (context, ref, child) {
///     final name = ref.watch(userProvider.select((u) => u.name));
///     return Text(name);
///   },
/// )
/// ```
class PreferSelectorOverConsumerRule extends SaropaLintRule {
  const PreferSelectorOverConsumerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_selector_over_consumer',
    problemMessage:
        '[prefer_selector_over_consumer] Consumer accessing single property. Use Selector for granular rebuilds.',
    correctionMessage: 'Use Selector widget or ref.watch(provider.select(...)) for efficiency.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Consumer') return;

      // Find the builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            // Analyze the builder body for property access patterns
            final String bodySource = builderExpr.body.toSource();

            // Check for patterns like ref.watch(provider).property or
            // ref.watch(provider).field
            // This suggests the Consumer is only using one property
            final RegExp singlePropertyPattern = RegExp(
              r'ref\.watch\([^)]+\)\.(\w+)[^.\w]',
            );

            final Iterable<RegExpMatch> matches = singlePropertyPattern.allMatches(bodySource);

            // If we only see one property being accessed from the watched
            // provider, suggest using Selector
            if (matches.length == 1) {
              // Also check that there's no .select() already being used
              if (!bodySource.contains('.select(')) {
                reporter.atNode(node.constructorName, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Suggests using Cubit instead of Bloc when only one event type exists.
///
/// Bloc is designed for complex state management with multiple events.
/// When a Bloc only has one event type, a Cubit is simpler and more direct.
///
/// **BAD:**
/// ```dart
/// // Events
/// abstract class CounterEvent {}
/// class IncrementEvent extends CounterEvent {}
///
/// // Bloc with only one event type
/// class CounterBloc extends Bloc<CounterEvent, int> {
///   CounterBloc() : super(0) {
///     on<IncrementEvent>((event, emit) => emit(state + 1));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class CounterCubit extends Cubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(state + 1);
/// }
/// ```
class PreferCubitForSimpleStateRule extends SaropaLintRule {
  const PreferCubitForSimpleStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_cubit_for_simple_state',
    problemMessage:
        '[prefer_cubit_for_simple_state] Bloc with single event type. Consider using Cubit for simpler code.',
    correctionMessage: 'Replace with Cubit when only one event/action is needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends Bloc<Event, State>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc') return;

      // Count the number of on<EventType> handlers
      int eventHandlerCount = 0;
      final Set<String> eventTypes = <String>{};

      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final String bodySource = member.body.toSource();

          // Find all on<EventType> patterns
          final RegExp onEventPattern = RegExp(r'on<(\w+)>');
          final Iterable<RegExpMatch> matches = onEventPattern.allMatches(bodySource);

          for (final RegExpMatch match in matches) {
            eventHandlerCount++;
            eventTypes.add(match.group(1)!);
          }
        }
      }

      // If only one event type is handled, suggest Cubit
      if (eventHandlerCount == 1 && eventTypes.length == 1) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when side effects (navigation, snackbar) are performed in BlocBuilder.
///
/// BlocBuilder is for building UI based on state. Side effects should be
/// handled in BlocListener to ensure they only execute once per state change.
///
/// **BAD:**
/// ```dart
/// BlocBuilder<AuthBloc, AuthState>(
///   builder: (context, state) {
///     if (state is AuthSuccess) {
///       Navigator.pushNamed(context, '/home'); // Called on every rebuild!
///     }
///     return Container();
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthSuccess) {
///       Navigator.pushNamed(context, '/home'); // Called once per state
///     }
///   },
///   child: BlocBuilder<AuthBloc, AuthState>(
///     builder: (context, state) => Container(),
///   ),
/// )
/// // Or use BlocConsumer for both
/// ```
class PreferBlocListenerForSideEffectsRule extends SaropaLintRule {
  const PreferBlocListenerForSideEffectsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_listener_for_side_effects',
    problemMessage:
        '[prefer_bloc_listener_for_side_effects] Side effect in BlocBuilder. Use BlocListener for navigation/snackbars.',
    correctionMessage: 'Move side effects to BlocListener or use BlocConsumer.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Patterns that indicate side effects
  static const Set<String> _sideEffectPatterns = <String>{
    'Navigator.',
    'Navigator.of(',
    '.pushNamed(',
    '.push(',
    '.pop(',
    '.pushReplacement',
    'context.go(',
    'context.push(',
    'GoRouter.of(',
    'showDialog(',
    'showModalBottomSheet(',
    'showSnackBar(',
    'ScaffoldMessenger.',
    'Scaffold.of(',
    '.showSnackBar(',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocBuilder') return;

      // Find the builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check for side effect patterns
          for (final String pattern in _sideEffectPatterns) {
            if (builderSource.contains(pattern)) {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Suggests using BlocConsumer when both BlocListener and BlocBuilder are nested.
///
/// When you need both listener (for side effects) and builder (for UI),
/// BlocConsumer provides a cleaner single-widget solution.
///
/// **BAD:**
/// ```dart
/// BlocListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthError) showSnackBar(...);
///   },
///   child: BlocBuilder<AuthBloc, AuthState>(
///     builder: (context, state) {
///       return Text(state.toString());
///     },
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BlocConsumer<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is AuthError) showSnackBar(...);
///   },
///   builder: (context, state) {
///     return Text(state.toString());
///   },
/// )
/// ```
class RequireBlocConsumerWhenBothRule extends SaropaLintRule {
  const RequireBlocConsumerWhenBothRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_bloc_consumer_when_both',
    problemMessage:
        '[require_bloc_consumer_when_both] Nested BlocListener + BlocBuilder. Use BlocConsumer instead.',
    correctionMessage: 'Replace with BlocConsumer which combines listener and builder.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'BlocListener') return;

      // Check if the child is a BlocBuilder
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;

          if (childExpr is InstanceCreationExpression) {
            final String childTypeName = childExpr.constructorName.type.name.lexeme;
            if (childTypeName == 'BlocBuilder') {
              // Check if they're for the same Bloc type
              final TypeArgumentList? listenerTypeArgs = node.constructorName.type.typeArguments;
              final TypeArgumentList? builderTypeArgs =
                  childExpr.constructorName.type.typeArguments;

              if (listenerTypeArgs != null && builderTypeArgs != null) {
                final String listenerType = listenerTypeArgs.toSource();
                final String builderType = builderTypeArgs.toSource();

                // If same Bloc type, suggest BlocConsumer
                if (listenerType == builderType) {
                  reporter.atNode(node.constructorName, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when BuildContext is passed to Bloc constructor.
///
/// Alias: bloc_context, context_in_bloc
///
/// Blocs should be independent of the widget tree. Passing BuildContext
/// to a Bloc couples it to the UI and makes testing difficult.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc(BuildContext context) : super(MyInitial()) {
///     // Using context in bloc
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> {
///   MyBloc(MyRepository repository) : super(MyInitial()) {
///     // Inject dependencies, not context
///   }
/// }
/// ```
class AvoidBlocContextDependencyRule extends SaropaLintRule {
  const AvoidBlocContextDependencyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_context_dependency',
    problemMessage:
        '[avoid_bloc_context_dependency] Bloc should not depend on BuildContext. This couples Bloc to UI.',
    correctionMessage: 'Inject dependencies through constructor instead of passing context.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _blocSuperclasses = <String>{
    'Bloc',
    'Cubit',
    'StateNotifier',
    'ChangeNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a Bloc/Cubit
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (!_blocSuperclasses.contains(superclassName)) return;

      // Check constructors for BuildContext parameter
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final FormalParameterList? params = member.parameters;
          if (params == null) continue;

          for (final FormalParameter param in params.parameters) {
            final String paramSource = param.toSource();
            if (paramSource.contains('BuildContext')) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Provider.value is used with inline notifier creation.
///
/// Alias: provider_value_inline, notifier_in_provider_value
///
/// Provider.value should only be used with existing notifiers. Creating
/// a notifier inline causes it to be recreated on every build.
///
/// **BAD:**
/// ```dart
/// Provider.value(
///   value: MyNotifier(), // Created inline!
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Create notifier in state
/// final _notifier = MyNotifier();
///
/// Provider.value(
///   value: _notifier, // Existing instance
///   child: child,
/// )
///
/// // Or use Provider constructor
/// Provider(
///   create: (_) => MyNotifier(),
///   child: child,
/// )
/// ```
class AvoidProviderValueRebuildRule extends SaropaLintRule {
  const AvoidProviderValueRebuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_provider_value_rebuild',
    problemMessage:
        '[avoid_provider_value_rebuild] Provider.value with inline creation. Notifier recreated every build.',
    correctionMessage: 'Use existing instance with Provider.value or use Provider constructor.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Check for Provider.value, ChangeNotifierProvider.value, etc.
      final String constructorName = node.constructorName.toSource();
      if (!constructorName.contains('.value')) return;

      // Check if it's a Provider-like class
      final String typeName = node.constructorName.type.name.lexeme;
      if (!typeName.contains('Provider')) return;

      // Check value parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          final Expression valueExpr = arg.expression;
          // Check if value is an inline constructor call
          if (valueExpr is InstanceCreationExpression) {
            reporter.atNode(valueExpr, code);
          } else if (valueExpr is MethodInvocation) {
            // Also check for factory methods like MyNotifier.create()
            reporter.atNode(valueExpr, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when Riverpod Notifiers are instantiated in build methods.
///
/// Alias: riverpod_notifier_build, no_notifier_in_build
///
/// Creating StateNotifier or Notifier instances in build methods causes
/// them to be recreated on every rebuild, losing state.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   Widget build(BuildContext context, WidgetRef ref) {
///     final notifier = StateNotifier<int>(0); // Recreated every build!
///     return Text('$notifier');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final counterProvider = StateNotifierProvider<CounterNotifier, int>(
///   (ref) => CounterNotifier(),
/// );
///
/// class MyWidget extends ConsumerWidget {
///   Widget build(BuildContext context, WidgetRef ref) {
///     final count = ref.watch(counterProvider);
///     return Text('$count');
///   }
/// }
/// ```
class AvoidRiverpodNotifierInBuildRule extends SaropaLintRule {
  const AvoidRiverpodNotifierInBuildRule() : super(code: _code);

  /// State is lost on every rebuild.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_riverpod_notifier_in_build',
    problemMessage:
        '[avoid_riverpod_notifier_in_build] Notifier created in build. State will be lost on every rebuild.',
    correctionMessage: 'Define the provider outside the widget and use ref.watch() to access it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Notifier types that shouldn't be created in build.
  static const Set<String> _notifierTypes = <String>{
    'StateNotifier',
    'ChangeNotifier',
    'ValueNotifier',
    'Notifier',
    'AsyncNotifier',
    'StreamNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check if it's a Notifier type
      bool isNotifier = _notifierTypes.contains(typeName);
      if (!isNotifier) {
        // Also check if type ends with Notifier
        isNotifier = typeName.endsWith('Notifier');
      }

      if (!isNotifier) return;

      // Check if inside a build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when try-catch is used instead of AsyncValue.guard in Riverpod.
///
/// Alias: use_async_value_guard, riverpod_error_handling
///
/// AsyncValue.guard provides better error handling and state management
/// for async operations in Riverpod providers.
///
/// **BAD:**
/// ```dart
/// class MyNotifier extends AsyncNotifier<Data> {
///   Future<Data> build() async {
///     try {
///       return await fetchData();
///     } catch (e) {
///       throw e; // Poor error handling
///     }
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyNotifier extends AsyncNotifier<Data> {
///   Future<Data> build() async {
///     return AsyncValue.guard(() => fetchData());
///   }
/// }
/// ```
class RequireRiverpodAsyncValueGuardRule extends SaropaLintRule {
  const RequireRiverpodAsyncValueGuardRule() : super(code: _code);

  /// AsyncValue.guard provides consistent error state handling.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_riverpod_async_value_guard',
    problemMessage:
        '[require_riverpod_async_value_guard] Try-catch in async provider. Consider using AsyncValue.guard for consistent error handling.',
    correctionMessage: 'Replace try-catch with AsyncValue.guard(() => yourAsyncOperation()).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      // Check if inside an AsyncNotifier or async provider
      AstNode? current = node.parent;
      bool inAsyncNotifier = false;

      while (current != null) {
        if (current is ClassDeclaration) {
          final String? extendsName = current.extendsClause?.superclass.name2.lexeme;
          if (extendsName != null &&
              (extendsName.contains('AsyncNotifier') || extendsName.contains('FutureProvider'))) {
            inAsyncNotifier = true;
          }
          break;
        }
        current = current.parent;
      }

      if (!inAsyncNotifier) return;

      // Check if catch block just rethrows
      for (final CatchClause catchClause in node.catchClauses) {
        final Block body = catchClause.body;
        if (body.statements.length == 1) {
          final Statement stmt = body.statements.first;
          if (stmt is ExpressionStatement) {
            final Expression expr = stmt.expression;
            if (expr is ThrowExpression || expr is RethrowExpression) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when Bloc contains BuildContext usage or UI dependencies.
///
/// Alias: bloc_no_context, bloc_separation, bloc_business_logic
///
/// Blocs should contain only business logic, not UI-related code.
/// BuildContext dependencies make Blocs harder to test and reuse.
///
/// **BAD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void _onEvent(Event event, Emitter<State> emit) {
///     Navigator.of(context).push(...); // UI in Bloc!
///     ScaffoldMessenger.of(context).showSnackBar(...); // UI in Bloc!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBloc extends Bloc<Event, State> {
///   void _onEvent(Event event, Emitter<State> emit) {
///     emit(NavigateToDetailState()); // Emit state for UI to handle
///   }
/// }
/// ```
class AvoidBlocBusinessLogicInUiRule extends SaropaLintRule {
  const AvoidBlocBusinessLogicInUiRule() : super(code: _code);

  /// Blocs with UI code are hard to test and violate separation.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_business_logic_in_ui',
    problemMessage:
        '[avoid_bloc_business_logic_in_ui] UI code in Bloc breaks separation of concerns and makes testing impossible.',
    correctionMessage: 'Emit a state instead and handle the UI action in BlocListener.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods that indicate UI code.
  static const Set<String> _uiMethods = <String>{
    'showSnackBar',
    'showDialog',
    'showModalBottomSheet',
    'push',
    'pushNamed',
    'pop',
    'pushReplacement',
    'pushReplacementNamed',
    'showDatePicker',
    'showTimePicker',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_uiMethods.contains(methodName)) return;

      // Check if inside a Bloc class
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ClassDeclaration) {
          final String? extendsName = current.extendsClause?.superclass.name2.lexeme;
          if (extendsName != null && (extendsName == 'Bloc' || extendsName == 'Cubit')) {
            reporter.atNode(node, code);
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 4 - State Management Rules
// =============================================================================

/// Warns when Provider.of is used without listen: false in non-build contexts.
///
/// Alias: provider_of_listen, change_notifier_proxy, provider_proxy
///
/// Using Provider.of without listen: false outside build() causes unnecessary
/// rebuilds. For one-time reads or actions, use `listen: false`.
///
/// **BAD:**
/// ```dart
/// void onTap() {
///   final user = Provider.of<UserModel>(context); // Rebuilds on change!
///   user.updateName('New Name');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void onTap() {
///   final user = Provider.of<UserModel>(context, listen: false);
///   user.updateName('New Name');
/// }
///
/// // Or use context.read():
/// void onTap() {
///   context.read<UserModel>().updateName('New Name');
/// }
/// ```
class PreferChangeNotifierProxyRule extends SaropaLintRule {
  const PreferChangeNotifierProxyRule() : super(code: _code);

  /// Performance issue. Causes unnecessary rebuilds.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_change_notifier_proxy',
    problemMessage:
        '[prefer_change_notifier_proxy] Provider.of without listen:false in callback. Use context.read() or add listen: false.',
    correctionMessage: 'Add listen: false parameter, or use context.read<T>() for one-time reads.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Provider.of<T>(context)
      if (node.methodName.name != 'of') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Provider') return;

      // Check if listen: false is provided
      final args = node.argumentList.arguments;
      final hasListenFalse = args.any((arg) {
        if (arg is NamedExpression && arg.name.label.name == 'listen') {
          final value = arg.expression;
          return value is BooleanLiteral && !value.value;
        }
        return false;
      });

      if (hasListenFalse) return;

      // Check if inside build() method - that's OK
      if (_isInsideBuildMethod(node)) return;

      // Check if inside callback (onTap, onPressed, etc.)
      if (_isInsideCallback(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && current.name.lexeme == 'build') {
        // Make sure we're directly in build, not in a callback inside build
        return _isDirectChildOfMethod(node, current);
      }
      current = current.parent;
    }
    return false;
  }

  bool _isDirectChildOfMethod(AstNode node, MethodDeclaration method) {
    AstNode? current = node.parent;
    while (current != null && current != method) {
      // If we hit a FunctionExpression, we're in a callback
      if (current is FunctionExpression) {
        return false;
      }
      current = current.parent;
    }
    return true;
  }

  bool _isInsideCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        // Check if parent is a callback argument
        final parent = current.parent;
        if (parent is NamedExpression) {
          final name = parent.name.label.name;
          if (name == 'onTap' ||
              name == 'onPressed' ||
              name == 'onChanged' ||
              name == 'onSubmitted' ||
              name == 'builder' ||
              name.startsWith('on')) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Consumer/Selector rebuilds entire subtree unnecessarily.
///
/// Alias: selector_widget, consumer_selector, provider_selector
///
/// Using Consumer to rebuild an entire widget tree when only part needs
/// updating is wasteful. Use Selector to rebuild only what changed.
///
/// **BAD:**
/// ```dart
/// Consumer<CartModel>(
///   builder: (context, cart, child) {
///     return Column(
///       children: [
///         ExpensiveWidget(), // Rebuilds unnecessarily!
///         Text('Items: ${cart.itemCount}'),
///       ],
///     );
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(
///   children: [
///     ExpensiveWidget(), // Doesn't rebuild
///     Selector<CartModel, int>(
///       selector: (_, cart) => cart.itemCount,
///       builder: (_, count, __) => Text('Items: $count'),
///     ),
///   ],
/// );
/// ```
class PreferSelectorWidgetRule extends SaropaLintRule {
  const PreferSelectorWidgetRule() : super(code: _code);

  /// Performance improvement suggestion.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_selector_widget',
    problemMessage:
        '[prefer_selector_widget] Consumer rebuilds entire subtree. Consider Selector for targeted rebuilds.',
    correctionMessage:
        'Use Selector<Model, T> to rebuild only widgets that depend on specific values.',
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
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Consumer') return;

      // Check if builder has complex widget tree
      final args = node.argumentList.arguments;
      for (final arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            final body = builderExpr.body;
            if (body is ExpressionFunctionBody) {
              // Check if returning complex widget
              if (_isComplexWidgetReturn(body.expression)) {
                reporter.atNode(node, code);
              }
            } else if (body is BlockFunctionBody) {
              // Check return statements
              for (final stmt in body.block.statements) {
                if (stmt is ReturnStatement) {
                  final returnExpr = stmt.expression;
                  if (returnExpr != null && _isComplexWidgetReturn(returnExpr)) {
                    reporter.atNode(node, code);
                    break;
                  }
                }
              }
            }
          }
        }
      }
    });
  }

  bool _isComplexWidgetReturn(Expression expr) {
    if (expr is! InstanceCreationExpression) return false;

    final typeName = expr.constructorName.type.name.lexeme;
    // Complex container widgets
    const complexWidgets = <String>{
      'Column',
      'Row',
      'Stack',
      'ListView',
      'GridView',
      'Wrap',
      'CustomScrollView',
    };

    return complexWidgets.contains(typeName);
  }
}

/// Warns when Bloc events are not sealed classes.
///
/// Alias: bloc_event_sealed, sealed_bloc_event, event_sealed
///
/// Using sealed classes for Bloc events enables exhaustive pattern matching
/// and prevents invalid event subtypes.
///
/// **BAD:**
/// ```dart
/// abstract class CounterEvent {}
/// class IncrementEvent extends CounterEvent {}
/// class DecrementEvent extends CounterEvent {}
/// ```
///
/// **GOOD:**
/// ```dart
/// sealed class CounterEvent {}
/// final class IncrementEvent extends CounterEvent {}
/// final class DecrementEvent extends CounterEvent {}
/// ```
class RequireBlocEventSealedRule extends SaropaLintRule {
  const RequireBlocEventSealedRule() : super(code: _code);

  /// Type safety improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_event_sealed',
    problemMessage:
        '[require_bloc_event_sealed] Bloc event hierarchy should use sealed class for exhaustive matching.',
    correctionMessage:
        'Change abstract class XEvent to sealed class XEvent for Dart 3+ pattern matching.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class name ends with Event
      final name = node.name.lexeme;
      if (!name.endsWith('Event')) return;

      // Check if it's abstract but not sealed
      if (node.abstractKeyword != null && node.sealedKeyword == null) {
        // Make sure it looks like a Bloc event (has subclasses pattern)
        if (node.members.isEmpty || _looksLikeBlocEvent(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _looksLikeBlocEvent(ClassDeclaration node) {
    // Empty body is common for event base classes
    if (node.members.isEmpty) return true;

    // Only has constructors
    return node.members.every((member) => member is ConstructorDeclaration);
  }
}

/// Warns when Bloc directly depends on repository implementations.
///
/// Alias: bloc_repository, bloc_abstract_repo, bloc_di
///
/// Blocs should depend on abstract repository interfaces, not concrete
/// implementations. This enables testing and swapping implementations.
///
/// **BAD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc() : super(UserInitial()) {
///     _repo = FirebaseUserRepository(); // Concrete implementation!
///   }
///   late final FirebaseUserRepository _repo;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> {
///   UserBloc(this._repo) : super(UserInitial());
///   final UserRepository _repo; // Abstract interface
/// }
/// ```
class RequireBlocRepositoryAbstractionRule extends SaropaLintRule {
  const RequireBlocRepositoryAbstractionRule() : super(code: _code);

  /// Architecture improvement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'require_bloc_repository_abstraction',
    problemMessage:
        '[require_bloc_repository_abstraction] Bloc depends on concrete repository. Use abstract interface for testability.',
    correctionMessage: 'Inject UserRepository interface instead of FirebaseUserRepository.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Prefixes that indicate concrete implementations.
  static const Set<String> _concretePrefixes = <String>{
    'Firebase',
    'Postgres',
    'Mysql',
    'Sqlite',
    'Http',
    'Rest',
    'Grpc',
    'Mock',
    'Fake',
    'Real',
    'Local',
    'Remote',
    'Cached',
    'Impl',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class is a Bloc
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superName = extendsClause.superclass.name.lexeme;
      if (superName != 'Bloc' && superName != 'Cubit') return;

      // Check fields for concrete repository types
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type == null) continue;

          final typeName = type.toSource();
          for (final prefix in _concretePrefixes) {
            if (typeName.startsWith(prefix) &&
                (typeName.contains('Repository') ||
                    typeName.contains('Service') ||
                    typeName.contains('DataSource'))) {
              reporter.atNode(member, code);
              break;
            }
          }
        }
      }
    });
  }
}

/// Warns when GetX global state is used instead of reactive state.
///
/// Alias: getx_global, getx_reactive, avoid_get_put
///
/// Using Get.put() for global state makes testing difficult and
/// creates implicit dependencies. Prefer reactive state with GetBuilder.
///
/// **BAD:**
/// ```dart
/// void main() {
///   Get.put(UserController()); // Global state
///   runApp(MyApp());
/// }
///
/// class MyWidget extends StatelessWidget {
///   final ctrl = Get.find<UserController>(); // Implicit dependency
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   Widget build(BuildContext context) {
///     return GetBuilder<UserController>(
///       init: UserController(),
///       builder: (controller) => Text(controller.userName),
///     );
///   }
/// }
/// ```
class AvoidGetxGlobalStateRule extends SaropaLintRule {
  const AvoidGetxGlobalStateRule() : super(code: _code);

  /// Testing difficulty.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_global_state',
    problemMessage:
        '[avoid_getx_global_state] Global GetX state (Get.put/Get.find) makes testing difficult.',
    correctionMessage: 'Use GetBuilder with init: parameter, or inject controller via constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;

      // Check for Get.put() and Get.find()
      if (methodName != 'put' && methodName != 'find') return;

      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Get') return;

      // Check if this is at top level (main) or in a field initializer
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionDeclaration && current.name.lexeme == 'main') {
          reporter.atNode(node, code);
          return;
        }
        if (current is FieldDeclaration) {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when Bloc doesn't use transform for event debouncing/throttling.
///
/// Alias: bloc_transform, event_transformer, debounce_bloc
///
/// For events like search queries, use EventTransformer to debounce or
/// throttle, preventing excessive API calls.
///
/// **BAD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(_onQueryChanged); // No debounce!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class SearchBloc extends Bloc<SearchEvent, SearchState> {
///   SearchBloc() : super(SearchInitial()) {
///     on<SearchQueryChanged>(
///       _onQueryChanged,
///       transformer: debounce(Duration(milliseconds: 300)),
///     );
///   }
/// }
/// ```
class PreferBlocTransformRule extends SaropaLintRule {
  const PreferBlocTransformRule() : super(code: _code);

  /// Performance suggestion.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    name: 'prefer_bloc_transform',
    problemMessage:
        '[prefer_bloc_transform] Search/input event without transformer. Consider debounce/throttle.',
    correctionMessage: 'Add transformer: debounce(Duration(milliseconds: 300)) to on<Event>().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Event name patterns that typically need debouncing.
  static const Set<String> _debounceCandidates = <String>{
    'SearchQueryChanged',
    'SearchTextChanged',
    'QueryChanged',
    'TextChanged',
    'InputChanged',
    'FilterChanged',
    'TypeaheadChanged',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'on') return;

      // Check if inside a Bloc constructor
      if (!_isInsideBlocConstructor(node)) return;

      // Check type argument
      final typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final eventType = typeArgs.arguments.first.toSource();

      // Check if event looks like it needs debouncing
      final needsDebounce = _debounceCandidates.any(
        (candidate) => eventType.contains(candidate),
      );

      if (!needsDebounce) return;

      // Check if transformer is provided
      final args = node.argumentList.arguments;
      final hasTransformer = args.any((arg) {
        return arg is NamedExpression && arg.name.label.name == 'transformer';
      });

      if (!hasTransformer) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBlocConstructor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ConstructorDeclaration) {
        // Check if constructor belongs to a Bloc
        final parent = current.parent;
        if (parent is ClassDeclaration) {
          final extendsClause = parent.extendsClause;
          if (extendsClause != null) {
            final superName = extendsClause.superclass.name.lexeme;
            return superName == 'Bloc';
          }
        }
      }
      current = current.parent;
    }
    return false;
  }
}

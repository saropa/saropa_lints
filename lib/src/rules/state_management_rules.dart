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

  static const LintCode _code = LintCode(
    name: 'require_notify_listeners',
    problemMessage:
        'ChangeNotifier method modifies state but does not call notifyListeners.',
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

  static const LintCode _code = LintCode(
    name: 'require_stream_controller_dispose',
    problemMessage: 'StreamController is not closed in dispose.',
    correctionMessage: 'Add controller.close() in dispose method.',
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
              final String? initTypeName =
                  initializer.constructorName.type.element?.name;
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
              for (final VariableDeclaration variable
                  in member.fields.variables) {
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
        message: 'Add TODO comment for missing StreamController close',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: close this StreamController in dispose()\n',
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

  static const LintCode _code = LintCode(
    name: 'require_value_notifier_dispose',
    problemMessage: 'ValueNotifier is not disposed.',
    correctionMessage: 'Add notifier.dispose() in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

  static const LintCode _code = LintCode(
    name: 'require_mounted_check',
    problemMessage: 'setState called after await without mounted check.',
    correctionMessage: 'Add "if (!mounted) return;" before setState.',
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
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
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

  static const LintCode _code = LintCode(
    name: 'avoid_watch_in_callbacks',
    problemMessage: 'Avoid using watch inside callbacks.',
    correctionMessage: 'Use read instead of watch in event handlers.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_in_constructor',
    problemMessage: 'Avoid adding BLoC events in constructor.',
    correctionMessage:
        'Add initial events from the widget that creates the BLoC.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Check if in a Bloc class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
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

  static const LintCode _code = LintCode(
    name: 'require_update_should_notify',
    problemMessage: 'InheritedWidget should override updateShouldNotify.',
    correctionMessage:
        'Add updateShouldNotify to control when dependents rebuild.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
        if (member is MethodDeclaration &&
            member.name.lexeme == 'updateShouldNotify') {
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

  static const LintCode _code = LintCode(
    name: 'avoid_global_riverpod_providers',
    problemMessage: 'Consider scoping Riverpod providers appropriately.',
    correctionMessage:
        'Document provider scope or use ProviderScope for isolation.',
    errorSeverity: DiagnosticSeverity.INFO,
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
          final String? typeName =
              initializer.constructorName.type.element?.name;
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

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_without_state',
    problemMessage:
        'StatefulWidget has no state fields - consider StatelessWidget.',
    correctionMessage:
        'Convert to StatelessWidget if no state is being managed.',
    errorSeverity: DiagnosticSeverity.INFO,
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

  static const LintCode _code = LintCode(
    name: 'avoid_global_key_in_build',
    problemMessage: 'GlobalKey should not be created in build method.',
    correctionMessage: 'Create GlobalKey as a class field instead.',
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
        message: 'Add TODO comment for GlobalKey in build',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: move this GlobalKey to a class field\n',
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

  static const LintCode _code = LintCode(
    name: 'require_bloc_close',
    problemMessage:
        'Bloc/Cubit is not closed in dispose(). This causes memory leaks.',
    correctionMessage:
        'Add _bloc.close() in the dispose() method before super.dispose().',
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
              final String initType =
                  initializer.constructorName.type.name.lexeme;
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
              for (final VariableDeclaration variable
                  in member.fields.variables) {
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

  static const LintCode _code = LintCode(
    name: 'prefer_consumer_widget',
    problemMessage:
        'Consider using ConsumerWidget instead of Consumer for cleaner code.',
    correctionMessage:
        'Extend ConsumerWidget instead of wrapping with Consumer.',
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
              if (bodyParent is MethodDeclaration &&
                  bodyParent.name.lexeme == 'build') {
                reporter.atNode(node, code);
                return;
              }
            }
          }
        }
        // Also check for expression body: Widget build(...) => Consumer(...)
        if (current is ExpressionFunctionBody) {
          final AstNode? bodyParent = current.parent;
          if (bodyParent is MethodDeclaration &&
              bodyParent.name.lexeme == 'build') {
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

  static const LintCode _code = LintCode(
    name: 'require_auto_dispose',
    problemMessage:
        'Riverpod provider should use autoDispose to prevent memory leaks.',
    correctionMessage:
        'Use Provider.autoDispose, StateProvider.autoDispose, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
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
          final String? constructorName =
              initializer.constructorName.name?.name;

          // Check if it's a provider without autoDispose
          if (_providerTypes.contains(typeName)) {
            // Check if it uses autoDispose constructor
            if (constructorName != 'autoDispose' &&
                !typeName.contains('AutoDispose')) {
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

  static const LintCode _code = LintCode(
    name: 'avoid_ref_in_build_body',
    problemMessage:
        'ref.read() in build() won\'t trigger rebuilds when the provider changes.',
    correctionMessage:
        'Use ref.watch() for reactive updates in build(), or move ref.read() '
        'to a callback like onPressed.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    if (parent is NamedExpression &&
        _callbackMethods.contains(parent.name.label.name)) {
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

  static const LintCode _code = LintCode(
    name: 'require_immutable_bloc_state',
    problemMessage: 'BLoC state classes should be immutable.',
    correctionMessage:
        'Add @immutable annotation or extend Equatable to ensure state '
        'immutability and proper equality comparisons.',
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
          if (mixinName == 'EquatableMixin' ||
              mixinName.contains('Equatable')) {
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

  static const LintCode _code = LintCode(
    name: 'avoid_provider_of_in_build',
    problemMessage:
        'Provider.of in build() causes rebuilds. Use context.read() for actions.',
    correctionMessage:
        'Use context.watch() for reactive UI or context.read() in callbacks.',
    errorSeverity: DiagnosticSeverity.INFO,
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

  static const LintCode _code = LintCode(
    name: 'avoid_get_find_in_build',
    problemMessage:
        'Get.find() in build() is inefficient. Use GetBuilder or Obx instead.',
    correctionMessage:
        'Use GetBuilder<T> or Obx for reactive updates with GetX.',
    errorSeverity: DiagnosticSeverity.INFO,
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

  static const LintCode _code = LintCode(
    name: 'avoid_provider_recreate',
    problemMessage:
        'Provider created in frequently rebuilding build() loses state.',
    correctionMessage:
        'Move Provider creation to a parent widget that does not rebuild often.',
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

      // Check if this is a StatefulWidget's State class
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
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

  static const LintCode _code = LintCode(
    name: 'prefer_cubit_for_simple',
    problemMessage:
        'Simple Bloc with few events could be a Cubit for simpler code.',
    correctionMessage:
        'Cubit is simpler for straightforward state. Use Bloc for complex event handling.',
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
        'Using ref in dispose() is unsafe - the provider may already be destroyed.',
    correctionMessage:
        'Remove ref usage from dispose(). Access provider values earlier if needed.',
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
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
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

  static const LintCode _code = LintCode(
    name: 'require_provider_scope',
    problemMessage:
        'Riverpod app is missing ProviderScope at root. Provider access will crash.',
    correctionMessage:
        'Wrap your app with ProviderScope: runApp(ProviderScope(child: MyApp()))',
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
      final CompilationUnit? unit =
          node.thisOrAncestorOfType<CompilationUnit>();
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

  static const LintCode _code = LintCode(
    name: 'prefer_select_for_partial',
    problemMessage:
        'Watching entire provider when only one field is used causes unnecessary rebuilds.',
    correctionMessage:
        'Use ref.watch(provider.select((s) => s.field)) for partial watching.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      final Map<String, MethodInvocation> watchCalls =
          <String, MethodInvocation>{};

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

  static const LintCode _code = LintCode(
    name: 'avoid_provider_in_widget',
    problemMessage:
        'Provider declared inside widget class breaks Riverpod\'s global state model.',
    correctionMessage:
        'Move provider declaration to file level as a top-level final variable.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
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

  static const LintCode _code = LintCode(
    name: 'prefer_family_for_params',
    problemMessage:
        'Provider with parameters should use .family modifier for proper caching.',
    correctionMessage:
        'Use Provider.family((ref, param) => ...) and watch with provider(param).',
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

  static const LintCode _code = LintCode(
    name: 'require_bloc_observer',
    problemMessage:
        'Using BlocProvider without BlocObserver setup. Consider adding centralized logging.',
    correctionMessage:
        'Add Bloc.observer = AppBlocObserver() in main() for centralized logging and error handling.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      if (!bodySource.contains('BlocProvider') &&
          !bodySource.contains('MultiBlocProvider')) {
        return;
      }

      // Check if BlocObserver is set
      if (!bodySource.contains('Bloc.observer') &&
          !bodySource.contains('BlocObserver')) {
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

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_mutation',
    problemMessage:
        'BLoC event has mutable fields. Events should be immutable.',
    correctionMessage: 'Make event fields final and use const constructor.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_copy_with_for_state',
    problemMessage: 'Directly modifying state breaks immutability.',
    correctionMessage: 'Use state.copyWith(field: value) to create new state.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_listen_in_build',
    problemMessage:
        'BlocProvider.of in build() causes rebuilds. Use BlocBuilder instead.',
    correctionMessage: 'Use BlocBuilder or context.read() for one-time access.',
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

  static const LintCode _code = LintCode(
    name: 'require_initial_state',
    problemMessage: 'BLoC constructor must pass initial state to super().',
    correctionMessage:
        'Add initial state: super(InitialState()) or super(const State()).',
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

  static const LintCode _code = LintCode(
    name: 'require_error_state',
    problemMessage: 'BLoC state hierarchy should include an error state.',
    correctionMessage:
        'Add an Error state class (e.g., UserError) to handle failures.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final Map<String, ClassDeclaration> stateClasses =
        <String, ClassDeclaration>{};
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

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_in_bloc',
    problemMessage:
        'BLoC should not directly call another BLoC. This creates tight coupling.',
    correctionMessage:
        'Coordinate between BLoCs at the widget layer or use streams.',
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
          member.body
              .visitChildren(_BlocAddVisitor(reporter, code, blocFields));
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

  static const LintCode _code = LintCode(
    name: 'prefer_sealed_events',
    problemMessage:
        'BLoC event base class should be sealed for exhaustive handling.',
    correctionMessage:
        'Use sealed class instead of abstract class for event hierarchy.',
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

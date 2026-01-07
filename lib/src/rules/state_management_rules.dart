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
  List<Fix> getFixes() => <Fix>[_AddHackForStreamControllerDisposeFix()];
}

class _AddHackForStreamControllerDisposeFix extends DartFix {
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
  List<Fix> getFixes() => <Fix>[_AddHackForMountedCheckFix()];
}

class _AddHackForMountedCheckFix extends DartFix {
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
        message: 'Add HACK comment for missing mounted check',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: add "if (!mounted) return;" before this setState\n',
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
  List<Fix> getFixes() => <Fix>[_AddHackForGlobalKeyInBuildFix()];
}

class _AddHackForGlobalKeyInBuildFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO: close ${node.name.lexeme} in dispose()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: Add ${node.name.lexeme}.close() in dispose() method\n  ',
        );
      });
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
          final String? constructorName = initializer.constructorName.name?.name;

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

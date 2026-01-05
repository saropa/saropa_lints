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
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
class RequireNotifyListenersRule extends DartLintRule {
  const RequireNotifyListenersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_notify_listeners',
    problemMessage:
        'ChangeNotifier method modifies state but does not call notifyListeners.',
    correctionMessage: 'Add notifyListeners() after state modifications.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  void _checkMethod(MethodDeclaration method, DiagnosticReporter reporter) {
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
class RequireStreamControllerDisposeRule extends DartLintRule {
  const RequireStreamControllerDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_stream_controller_dispose',
    problemMessage: 'StreamController is not closed in dispose.',
    correctionMessage: 'Add controller.close() in dispose method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('State')) return;

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

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'close') {
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
class RequireValueNotifierDisposeRule extends DartLintRule {
  const RequireValueNotifierDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_value_notifier_dispose',
    problemMessage: 'ValueNotifier is not disposed.',
    correctionMessage: 'Add notifier.dispose() in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('State')) return;

      // Find ValueNotifier fields
      final List<String> notifierNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName != null && typeName.contains('ValueNotifier')) {
              notifierNames.add(variable.name.lexeme);
            }
            // Also check initializers
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String? initTypeName =
                  initializer.constructorName.type.element?.name;
              if (initTypeName == 'ValueNotifier') {
                notifierNames.add(variable.name.lexeme);
              }
            }
          }
        }
      }

      if (notifierNames.isEmpty) return;

      // Find dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Check if notifiers are disposed
      final Set<String> disposedNotifiers = <String>{};
      if (disposeMethod != null) {
        disposeMethod.body.visitChildren(
          _DisposeCallVisitor((String name) => disposedNotifiers.add(name)),
        );
      }

      // Report undisposed notifiers
      for (final String name in notifierNames) {
        if (!disposedNotifiers.contains(name)) {
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
}

class _DisposeCallVisitor extends RecursiveAstVisitor<void> {
  _DisposeCallVisitor(this.onDispose);

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
class RequireMountedCheckRule extends DartLintRule {
  const RequireMountedCheckRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_mounted_check',
    problemMessage: 'setState called after await without mounted check.',
    correctionMessage: 'Add "if (!mounted) return;" before setState.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('State')) return;

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

  final DiagnosticReporter reporter;
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
class AvoidWatchInCallbacksRule extends DartLintRule {
  const AvoidWatchInCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_watch_in_callbacks',
    problemMessage: 'Avoid using watch inside callbacks.',
    correctionMessage: 'Use read instead of watch in event handlers.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidBlocEventInConstructorRule extends DartLintRule {
  const AvoidBlocEventInConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_bloc_event_in_constructor',
    problemMessage: 'Avoid adding BLoC events in constructor.',
    correctionMessage:
        'Add initial events from the widget that creates the BLoC.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  final DiagnosticReporter reporter;
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
class RequireUpdateShouldNotifyRule extends DartLintRule {
  const RequireUpdateShouldNotifyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_update_should_notify',
    problemMessage: 'InheritedWidget should override updateShouldNotify.',
    correctionMessage:
        'Add updateShouldNotify to control when dependents rebuild.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidGlobalRiverpodProvidersRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidStatefulWithoutStateRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.startsWith('State')) return;

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
class AvoidGlobalKeyInBuildRule extends DartLintRule {
  const AvoidGlobalKeyInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_global_key_in_build',
    problemMessage: 'GlobalKey should not be created in build method.',
    correctionMessage: 'Create GlobalKey as a class field instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  final DiagnosticReporter reporter;
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

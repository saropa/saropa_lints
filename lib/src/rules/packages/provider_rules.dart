// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Provider package-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the provider package,
/// including ChangeNotifier patterns, Consumer/Selector widgets,
/// proper disposal, and avoiding common anti-patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// PROVIDER RULES
// =============================================================================

/// Warns when Provider is watched unnecessarily in callbacks.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidWatchInCallbacksRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_watch_in_callbacks',
    '[avoid_watch_in_callbacks] Using watch in callbacks (like onPressed or onTap) creates new subscriptions on every call, leading to memory leaks, redundant widget rebuilds, and degraded app performance. This can cause your app to slow down or even crash over time. {v4}',
    correctionMessage:
        'Use ref.read instead of ref.watch in event handlers and callbacks to avoid creating unnecessary subscriptions and prevent memory leaks.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'watch') return;

      // Check if inside a callback (FunctionExpression in ArgumentList)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) {
          final AstNode? funcParent = current.parent;
          if (funcParent is ArgumentList || funcParent is NamedExpression) {
            reporter.atNode(node);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when InheritedWidget is used without updateShouldNotify.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireUpdateShouldNotifyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: require_update_should_notify_context
  static const LintCode _code = LintCode(
    'require_update_should_notify',
    '[require_update_should_notify] If an InheritedWidget does not override updateShouldNotify, all dependents rebuild on every change, causing unnecessary rebuilds, degraded performance, and battery drain. This can make your app slow and unresponsive. {v5}',
    correctionMessage:
        'Override updateShouldNotify in your InheritedWidget to control when dependents rebuild and optimize app performance.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends InheritedWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'InheritedWidget' &&
          superName != 'InheritedNotifier' &&
          superName != 'InheritedModel') {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Provider.of is used inside build() without listen: false.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
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
  AvoidProviderOfInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  /// Alias: avoid_provider_of_in_build_method
  static const LintCode _code = LintCode(
    'avoid_provider_of_in_build',
    '[avoid_provider_of_in_build] Using Provider.of in build() causes the widget to rebuild every time the provider changes, which can lead to performance issues and unnecessary UI updates. This can make your app less efficient and harder to maintain. {v3}',
    correctionMessage:
        'Use context.watch() for reactive UI updates, or context.read() in callbacks (like onPressed) to avoid unnecessary rebuilds and improve performance.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
      reporter.atNode(node);
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when ChangeNotifier or Provider is created inside build().
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
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
  AvoidProviderRecreateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'avoid_provider_recreate',
    '[avoid_provider_recreate] Creating a Provider inside a frequently rebuilding build() method causes the provider to be recreated, losing its state and causing unexpected behavior. This can result in lost user input, bugs, and degraded app performance. {v3}',
    correctionMessage:
        'Move Provider creation to a parent widget that does not rebuild often to preserve provider state and ensure consistent behavior.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check if this is a StatefulWidget's State class
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
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

/// Warns when Riverpod provider is declared inside a widget class.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
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
  AvoidProviderInWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_provider_in_widget',
    '[avoid_provider_in_widget] Declaring a provider inside a widget class breaks Riverpod\'s global state model, leading to multiple provider instances, lost state, and unpredictable bugs. This can make your app behave inconsistently and is hard to debug. {v2}',
    correctionMessage:
        'Move provider declaration to the file level as a top-level final variable to ensure a single, consistent provider instance.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Check if inside a class
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
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
          reporter.atNode(variable);
        }
      }
    });
  }
}

/// Warns when ChangeNotifier is created inside build().
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v5
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
  AvoidChangeNotifierInWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_change_notifier_in_widget',
    '[avoid_change_notifier_in_widget] ChangeNotifier created inside build() is re-instantiated on every widget rebuild, losing all accumulated state and listener registrations. This causes flickering UI, lost user input, and wasted allocations that trigger unnecessary garbage collection. {v5}',
    correctionMessage:
        'Create the ChangeNotifier in a ChangeNotifierProvider or in StatefulWidget.initState() to preserve state across rebuilds and ensure proper disposal.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Resolve the actual type to check the class hierarchy
      if (!_isChangeNotifierType(node)) {
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

  /// Check if the constructed type extends ChangeNotifier
  static bool _isChangeNotifierType(InstanceCreationExpression node) {
    final Element? element = node.constructorName.type.element;
    if (element is! InterfaceElement) {
      // Fall back to name matching when type can't be resolved
      final String typeName = node.constructorName.type.name.lexeme;
      return typeName.endsWith('Notifier') ||
          typeName.endsWith('Controller') ||
          typeName.endsWith('ViewModel');
    }

    // Check the class itself and all supertypes
    if (element.name == 'ChangeNotifier') {
      return true;
    }
    for (final InterfaceType supertype in element.allSupertypes) {
      if (supertype.element.name == 'ChangeNotifier') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when ChangeNotifierProvider is used without dispose callback.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v4
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
  RequireProviderDisposeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_provider_dispose',
    '[require_provider_dispose] Provider creating a ChangeNotifier without a dispose callback leaks listener registrations and memory. Over time, leaked notifiers accumulate stale listeners that fire after the StatefulWidget is removed from the tree, causing setState-after-dispose errors and increasing memory pressure. {v4}',
    correctionMessage:
        'Use ChangeNotifierProvider (auto-disposes) or add a dispose callback that calls notifier.dispose() to release all listener registrations.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
            if (createSource.endsWith('Notifier()') ||
                createSource.endsWith('Controller()') ||
                createSource.endsWith('ViewModel()')) {
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

/// Warns when Provider package uses nested Provider widgets instead of
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v2
///
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
  RequireMultiProviderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'require_multi_provider',
    '[require_multi_provider] Nested Provider widgets. Use MultiProvider to improve readability. Nested Provider widgets create deep indentation. MultiProvider flattens the tree and is easier to read and maintain. {v2}',
    correctionMessage:
        'Replace nested Providers with MultiProvider(providers: [..], child: ..). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Provider widgets are deeply nested.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
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
  AvoidNestedProvidersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'avoid_nested_providers',
    '[avoid_nested_providers] Provider created inside Consumer or builder callback. Deeply nested provider trees are hard to reason about and maintain. Flatten with MultiProvider and avoid provider-in-provider patterns where possible. {v4}',
    correctionMessage:
        'Use ProxyProvider or move provider to MultiProvider at tree root. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (!_providerTypes.contains(typeName)) return;

      // Check if inside a Consumer's builder callback
      AstNode? current = node.parent;

      while (current != null) {
        // Check for builder callback pattern
        if (current is NamedExpression &&
            (current.name.label.name == 'builder' ||
                current.name.label.name == 'selector')) {
          // Check if this builder belongs to a Consumer
          AstNode? builderParent = current.parent;
          while (builderParent != null) {
            if (builderParent is InstanceCreationExpression) {
              final String parentType =
                  builderParent.constructorName.type.name.lexeme;
              if (_consumerTypes.contains(parentType)) {
                reporter.atNode(node);
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
              final String parentType =
                  childParent.constructorName.type.name.lexeme;
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

/// Warns when nested `Provider` widgets are used.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferMultiProviderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'prefer_multi_provider',
    '[prefer_multi_provider] Nested Providers should use MultiProvider instead. Use MultiProvider when providing multiple objects to reduce nesting and improve readability. Nested Provider widgets are used. {v2}',
    correctionMessage:
        'Combine into MultiProvider(providers: [..], child: ..). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
              reporter.atNode(node);
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidInstantiatingInValueProviderRule() : super(code: _code);

  /// Critical - lifecycle management issue.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'avoid_instantiating_in_value_provider',
    '[avoid_instantiating_in_value_provider] Creating a new instance inside Provider.value prevents proper lifecycle management, leading to memory leaks, resource retention, and unpredictable behavior. This is a critical issue for stateful objects like ChangeNotifiers and ValueListenables. {v2}',
    correctionMessage:
        'Always use Provider(create: ...) to create new instances, or pass an existing instance variable to Provider.value. Never instantiate objects directly inside Provider.value.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _providerTypes = <String>{
    'Provider',
    'ChangeNotifierProvider',
    'ListenableProvider',
    'ValueListenableProvider',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
            reporter.atNode(valueExpr);
            return;
          }
        }
      }
    });
  }
}

/// Warns when `Provider` lacks a dispose callback for disposable instances.
///
/// Since: v4.1.3 | Updated: v4.13.0 | Rule version: v4
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
  DisposeProvidersRule() : super(code: _code);

  /// High impact - memory leak prevention.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'dispose_provider_instances',
    '[dispose_provider_instances] Provider creating a disposable instance without a dispose callback leaks stream subscriptions and controllers. These undisposed resources accumulate across navigation, increasing memory usage and leaving background listeners that fire after the parent StatefulWidget is removed from the tree. {v4}',
    correctionMessage:
        'Add dispose: (_, instance) => instance.dispose() to the Provider constructor to release stream subscriptions and controllers on removal.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when long Provider access chains are used.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Long chains like `context.read<A>().read<B>().value` are hard to read.
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
  PreferProviderExtensionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'prefer_provider_extensions',
    '[prefer_provider_extensions] Long provider access chain is hard to read. Long chains like context.read<A>().read<B>().value are hard to read. Use extension methods. {v2}',
    correctionMessage:
        'Use an extension method. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'read' &&
          methodName != 'watch' &&
          methodName != 'select') {
        return;
      }

      // Check if this is a chained call (target is also a method invocation)
      final Expression? target = node.target;
      if (target is MethodInvocation) {
        final String targetMethod = target.methodName.name;
        if (targetMethod == 'read' || targetMethod == 'watch') {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when Provider.create returns a disposable instance without dispose callback.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
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
  DisposeProvidedInstancesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'dispose_provided_instances',
    '[dispose_provided_instances] Provider creates a disposable instance without a dispose callback, causing memory leaks. Undisposed stream subscriptions and controllers persist after the parent StatefulWidget is removed from the tree, continuing to hold resources and fire callbacks that trigger setState-after-dispose errors. {v4}',
    correctionMessage:
        'Add dispose: (_, instance) => instance.dispose() to the Provider constructor to release stream subscriptions and controllers on removal.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
                expr.constructorName.type.element?.name ??
                expr.constructorName.type.name.lexeme;
            if (_disposableTypes.contains(createdType)) {
              reporter.atNode(node);
            }
          }
        }
      }
    });
  }
}

/// Warns when Provider type parameter is non-nullable but create returns null.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferNullableProviderTypesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  /// Alias: prefer_nullable_provider_types_pattern
  static const LintCode _code = LintCode(
    'prefer_nullable_provider_types',
    '[prefer_nullable_provider_types] Provider type is non-nullable but create may return null. When a Provider\'s create callback explicitly returns null, the type parameter must be nullable to prevent runtime errors. {v2}',
    correctionMessage:
        'Use nullable type parameter: Provider<Type?>. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
              reporter.atNode(node);
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

/// Warns when `Provider.of<T>(context)` is used in build method.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferConsumerOverProviderOfRule() : super(code: _code);

  /// Provider.of causes unnecessary rebuilds compared to Consumer.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'prefer_consumer_over_provider_of',
    '[prefer_consumer_over_provider_of] Provider.of in build. Use Consumer for granular rebuilds. Provider.of<T>(context) is used in build method. This pattern increases maintenance cost and the likelihood of introducing bugs during future changes. {v2}',
    correctionMessage:
        'Replace with Consumer<T> or context.select() to improve performance. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Provider.of
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Provider') return;
      if (node.methodName.name != 'of') return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when Provider.of is used without a generic type parameter.
///
/// Since: v4.13.0 | Rule version: v1
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
  RequireProviderGenericTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'require_provider_generic_type',
    '[require_provider_generic_type] Missing generic type causes runtime '
        'cast errors when Provider returns dynamic instead of expected type. {v1}',
    correctionMessage: 'Add <Type> to Provider.of<Type>(context).',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

/// Warns when Provider.of or context.read/watch is used in initState.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v4
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
  AvoidProviderInInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_provider_in_init_state',
    '[avoid_provider_in_init_state] Accessing Provider in initState() may fail because the widget context is not fully mounted in the element tree. This can throw a ProviderNotFoundException or return stale data, causing initialization logic to operate on incorrect values or crash on first render. {v4}',
    correctionMessage:
        'Move Provider access to didChangeDependencies() where the BuildContext is fully mounted and InheritedWidget lookups are safe.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Provider.of, context.read, context.watch
      bool isProviderCall = false;

      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Provider') {
        if (methodName == 'of') isProviderCall = true;
      } else if (target != null) {
        // Match exact 'context' identifier, not variables containing "context"
        if (target is SimpleIdentifier &&
            target.name == 'context' &&
            (methodName == 'read' || methodName == 'watch')) {
          isProviderCall = true;
        }
      }

      if (!isProviderCall) return;

      // Check if inside initState
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration) {
          if (current.name.lexeme == 'initState') {
            reporter.atNode(node);
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
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferContextReadInCallbacksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_context_read_in_callbacks',
    '[prefer_context_read_in_callbacks] context.watch must not be used in callbacks. Using context.watch in button callbacks or event handlers will cause unnecessary rebuilds. Use context.read for one-time access in callbacks. {v2}',
    correctionMessage:
        'Use context.read instead for one-time access. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'watch') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Match exact 'context' identifier, not variables containing "context"
      if (target is! SimpleIdentifier || target.name != 'context') return;

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
              reporter.atNode(node);
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

/// Warns when Provider depends on another provider but doesn't use ProxyProvider.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
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
  PreferProxyProviderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'prefer_proxy_provider',
    '[prefer_proxy_provider] Provider.create() accesses other providers. Use ProxyProvider instead. When a Provider needs to depend on another provider\'s value, using a plain Provider with context.read() or context.watch() is fragile and error-prone. ProxyProvider ensures proper dependency tracking and rebuild behavior. {v2}',
    correctionMessage:
        'Use ProxyProvider, ProxyProvider2, etc. to properly declare provider dependencies.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Provider widget types that should use ProxyProvider for dependencies
  static const Set<String> _providerTypes = <String>{
    'Provider',
    'ChangeNotifierProvider',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          final _ProxyProviderAccessVisitor visitor =
              _ProxyProviderAccessVisitor();
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
        // Match exact 'context' identifier
        if (target is SimpleIdentifier && target.name == 'context') {
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
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
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
  RequireUpdateCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_update_callback',
    '[require_update_callback] ProxyProvider.update ignores the previous value. This may cause resource leaks. ProxyProvider.update is called whenever a dependency changes. If the callback doesn\'t properly handle the previous parameter, it may cause memory leaks or miss important cleanup logic. {v2}',
    correctionMessage:
        'Handle the previous parameter to dispose resources or reuse the existing instance.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

/// Suggests using Selector instead of Consumer for granular rebuilds.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
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
  PreferSelectorOverConsumerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'prefer_selector_over_consumer',
    '[prefer_selector_over_consumer] Consumer accessing single property. Use Selector for granular rebuilds. Consumer rebuilds on any change to the provider. Selector only rebuilds when the selected value changes, providing more granular control. {v3}',
    correctionMessage:
        'Use Selector widget or ref.watch(provider.select(..)) for efficiency. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

            final Iterable<RegExpMatch> matches = singlePropertyPattern
                .allMatches(bodySource);

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

/// Warns when Provider.value is used with inline notifier creation.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v6
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
  AvoidProviderValueRebuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    'avoid_provider_value_rebuild',
    '[avoid_provider_value_rebuild] Provider.value with inline object creation recreates the notifier on every widget build. This discards accumulated user data, resets form state, and can trigger infinite rebuild loops that freeze the UI as each rebuild creates a new instance that triggers another rebuild. {v6}',
    correctionMessage:
        'Store the notifier instance in a variable and reuse it with Provider.value, or use the Provider constructor to create and manage the instance lifecycle automatically.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
            reporter.atNode(valueExpr);
          } else if (valueExpr is MethodInvocation) {
            // Also check for factory methods like MyNotifier.create()
            reporter.atNode(valueExpr);
          }
        }
      }
    });
  }
}

/// Warns when Provider.of is used without listen: false in non-build contexts.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferChangeNotifierProxyRule() : super(code: _code);

  /// Performance issue. Causes unnecessary rebuilds.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_change_notifier_proxy',
    '[prefer_change_notifier_proxy] Provider.of without listen:false in callback. Use context.read() or add listen: false. This pattern increases maintenance cost and the likelihood of introducing bugs during future changes. {v2}',
    correctionMessage:
        'Add listen: false parameter, or use context.read<T>() for one-time reads. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
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
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferSelectorWidgetRule() : super(code: _code);

  /// Performance improvement suggestion.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Alias: prefer_selector_widget_pattern
  static const LintCode _code = LintCode(
    'prefer_selector_widget',
    '[prefer_selector_widget] Consumer rebuilds entire subtree. Prefer Selector for targeted rebuilds. Using Consumer to rebuild an entire widget tree when only part needs updating is wasteful. Use Selector to rebuild only what changed. {v2}',
    correctionMessage:
        'Use Selector<Model, T> to rebuild only widgets that depend on specific values. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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
                reporter.atNode(node);
              }
            } else if (body is BlockFunctionBody) {
              // Check return statements
              for (final stmt in body.block.statements) {
                if (stmt is ReturnStatement) {
                  final returnExpr = stmt.expression;
                  if (returnExpr != null &&
                      _isComplexWidgetReturn(returnExpr)) {
                    reporter.atNode(node);
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

/// Warns when ChangeNotifierProvider update accesses another provider directly.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Use ChangeNotifierProxyProvider when a ChangeNotifier depends on another
/// provider's value to avoid stale data and proper dependency management.
///
/// **BAD:**
/// ```dart
/// ChangeNotifierProvider(
///   create: (context) {
///     final auth = context.read<AuthService>();
///     return UserNotifier(auth); // auth won't update!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ChangeNotifierProxyProvider<AuthService, UserNotifier>(
///   create: (_) => UserNotifier(),
///   update: (_, auth, previous) => previous!..updateAuth(auth),
/// )
/// ```
class PreferChangeNotifierProxyProviderRule extends SaropaLintRule {
  PreferChangeNotifierProxyProviderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_change_notifier_proxy_provider',
    '[prefer_change_notifier_proxy_provider] ChangeNotifierProvider.create '
        'accesses another provider. Use ChangeNotifierProxyProvider instead. {v2}',
    correctionMessage:
        'Use ChangeNotifierProxyProvider for proper dependency tracking.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'ChangeNotifierProvider') return;

      // Find create parameter
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final createExpr = arg.expression;
          if (createExpr is FunctionExpression) {
            // Check if body contains context.read or context.watch
            final body = createExpr.body.toSource();
            if (body.contains('context.read') ||
                body.contains('context.watch') ||
                body.contains('Provider.of')) {
              reporter.atNode(node);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// Provider listen:false in build Rules
// =============================================================================

/// Warns when Provider.of(context, listen: false) is used inside a build()
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// method.
///
/// Using listen: false in build means the widget will not rebuild when the
/// provided value changes, causing the UI to display stale data. In build(),
/// you almost always want listen: true (the default) so the widget rebuilds.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final counter = Provider.of<Counter>(context, listen: false);
///   return Text('${counter.value}'); // Shows stale data!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final counter = Provider.of<Counter>(context); // listen: true by default
///   return Text('${counter.value}');
/// }
/// ```
class AvoidProviderListenFalseInBuildRule extends SaropaLintRule {
  AvoidProviderListenFalseInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_provider_listen_false_in_build',
    '[avoid_provider_listen_false_in_build] Provider.of() is called with listen: false inside a build() method. This prevents the widget from rebuilding when the provided value changes, causing the UI to display stale data that does not reflect the current application state. Users see outdated information until something else triggers a rebuild, creating confusing and inconsistent UI behavior that is difficult to debug. {v2}',
    correctionMessage:
        'Remove the listen: false parameter so that Provider.of() uses the default listen: true, or use context.watch<T>() which always rebuilds on change.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Provider.of() call
      if (node.methodName.name != 'of') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Provider') return;

      // Check for listen: false named argument
      bool hasListenFalse = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'listen' &&
            arg.expression is BooleanLiteral &&
            (arg.expression as BooleanLiteral).value == false) {
          hasListenFalse = true;
          break;
        }
      }
      if (!hasListenFalse) return;

      // Check if inside a build() method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

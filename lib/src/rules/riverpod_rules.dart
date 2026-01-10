// ignore_for_file: depend_on_referenced_packages

// Riverpod-specific lint rules for Saropa Lints
// Implements rules 45–52 from the roadmap

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when `ref.read()` is used inside a `build()` method.
///
/// Alias: no_ref_read_in_build, use_ref_watch, ref_read_in_build
///
/// `ref.read()` does not set up subscriptions, so the widget won't rebuild
/// when the provider value changes. Use `ref.watch()` in build methods
/// to ensure reactivity.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final value = ref.read(myProvider); // Won't rebuild on changes
///   return Text(value);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final value = ref.watch(myProvider); // Rebuilds on changes
///   return Text(value);
/// }
/// ```
class AvoidRefReadInsideBuildRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_ref_read_inside_build',
    problemMessage: 'ref.read() should not be used inside build().',
    correctionMessage: 'Use ref.watch() in build() for reactivity.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const AvoidRefReadInsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;
      node.body.visitChildren(_RefReadVisitor(reporter, code));
    });
  }
}

class _RefReadVisitor extends RecursiveAstVisitor<void> {
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  _RefReadVisitor(this.reporter, this.code);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'read' &&
        node.target != null &&
        node.target.toString() == 'ref') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when `ref.watch()` is used outside a `build()` method.
///
/// Alias: ref_watch_in_callback, ref_watch_leak, ref_watch_outside_build
///
/// `ref.watch()` creates subscriptions that expect to be managed by
/// widget lifecycle. Using it outside build causes subscription leaks
/// and unpredictable behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void someMethod(WidgetRef ref) {
///   ref.watch(myProvider); // Subscription leak!
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   ref.watch(myProvider); // Proper lifecycle management
/// }
/// ```
class AvoidRefWatchOutsideBuildRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_ref_watch_outside_build',
    problemMessage: 'ref.watch() should only be used inside build().',
    correctionMessage: 'Move ref.watch() calls into build().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidRefWatchOutsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'watch' &&
          node.target != null &&
          node.target.toString() == 'ref') {
        // Find parent method
        AstNode? parent = node;
        while (parent != null && parent is! MethodDeclaration) {
          parent = parent.parent;
        }
        if (parent is MethodDeclaration && parent.name.lexeme == 'build') {
          // OK
        } else {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when `ref` is accessed inside a `dispose()` method.
///
/// Alias: ref_in_dispose, dispose_ref_access, cache_ref_in_initstate
///
/// The `ref` object is not available during widget disposal. Accessing it
/// in `dispose()` causes runtime errors. Cache values you need in
/// `initState()` instead.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// @override
/// void dispose() {
///   ref.read(myProvider).close(); // ref not available!
///   super.dispose();
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// late final MyValue _cachedValue;
///
/// @override
/// void initState() {
///   super.initState();
///   _cachedValue = ref.read(myProvider);
/// }
///
/// @override
/// void dispose() {
///   _cachedValue.close(); // Use cached value
///   super.dispose();
/// }
/// ```
class AvoidRefInsideStateDisposeRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_ref_inside_state_dispose',
    problemMessage: 'Do not use ref in dispose().',
    correctionMessage: 'Cache values in initState instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidRefInsideStateDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'dispose') return;
      node.body.visitChildren(_RefAccessVisitor(reporter, code));
    });
  }
}

class _RefAccessVisitor extends RecursiveAstVisitor<void> {
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  _RefAccessVisitor(this.reporter, this.code);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'ref') {
      reporter.atNode(node, code);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when `ref.read()` is called after an `await` in an async method.
///
/// Alias: ref_read_after_await, stale_ref_read, cache_ref_before_await
///
/// After an async gap, provider state may have changed. Call `ref.read()`
/// before the await and cache the result to avoid stale data.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Future<void> load(WidgetRef ref) async {
///   await Future.delayed(Duration(seconds: 1));
///   final value = ref.read(myProvider); // Provider may have changed!
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Future<void> load(WidgetRef ref) async {
///   final value = ref.read(myProvider); // Cache before await
///   await Future.delayed(Duration(seconds: 1));
///   // Use cached value
/// }
/// ```
class UseRefReadSynchronouslyRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'use_ref_read_synchronously',
    problemMessage: 'ref.read() should be called before await.',
    correctionMessage: 'Cache ref.read() result before async gap.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const UseRefReadSynchronouslyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.body.isAsynchronous) return;
      node.body.visitChildren(_RefReadAfterAwaitVisitor(reporter, code));
    });
  }
}

class _RefReadAfterAwaitVisitor extends RecursiveAstVisitor<void> {
  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool foundAwait = false;

  _RefReadAfterAwaitVisitor(this.reporter, this.code);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    foundAwait = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (foundAwait &&
        node.methodName.name == 'read' &&
        node.target != null &&
        node.target.toString() == 'ref') {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when `ref` is used after an await in an async method.
///
/// After an async gap, the provider state may have changed. Access `ref`
/// before the await or cache values you need.
///
/// Note: This rule only flags `ref` usage, not `state`, as `state` is too
/// common a variable name to reliably detect Riverpod-specific usage.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Future<void> load(WidgetRef ref) async {
///   await Future.delayed(...);
///   print(ref);  // ref might be stale
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Future<void> load(WidgetRef ref) async {
///   final r = ref;  // cache before await
///   await Future.delayed(...);
///   print(r);
/// }
/// ```
class UseRefAndStateSynchronouslyRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'use_ref_and_state_synchronously',
    problemMessage: 'ref should be used before async gap.',
    correctionMessage: 'Cache ref before await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const UseRefAndStateSynchronouslyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.body.isAsynchronous) return;
      node.body.visitChildren(_RefAfterAwaitVisitor(reporter, code));
    });
  }
}

class _RefAfterAwaitVisitor extends RecursiveAstVisitor<void> {
  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool foundAwait = false;

  _RefAfterAwaitVisitor(this.reporter, this.code);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    foundAwait = true;
    super.visitAwaitExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Only flag 'ref' - 'state' is too common a variable name
    if (foundAwait && node.name == 'ref') {
      reporter.atNode(node, code);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when assigning directly to a Riverpod notifier variable.
///
/// Notifiers manage their own state through provider lifecycle.
/// Direct assignment breaks the provider contract and can cause
/// unexpected behavior.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// notifier = SomeNotifier();
/// myNotifier = anotherNotifier;
/// ```
///
/// #### GOOD:
/// ```dart
/// // Use provider's own lifecycle
/// ref.read(myProvider.notifier).updateState(newValue);
/// ```
class AvoidAssigningNotifiersRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_assigning_notifiers',
    problemMessage: 'Do not assign to notifier variables.',
    correctionMessage: 'Notifiers manage their own state.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidAssigningNotifiersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      final lhs = node.leftHandSide;
      // Only match exact 'notifier' or variables that are exactly named
      // with 'notifier' as a word boundary (e.g., 'myNotifier' but not 'notifierWrapper')
      if (lhs is SimpleIdentifier) {
        final name = lhs.name.toLowerCase();
        // Match 'notifier' exactly or as a suffix (e.g., 'myNotifier')
        if (name == 'notifier' || name.endsWith('notifier')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a Riverpod Notifier class has an explicit constructor.
///
/// Notifier classes should use the `build()` method for initialization,
/// not constructors. Constructors run before the provider is set up.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyNotifier extends Notifier<int> {
///   MyNotifier() {
///     // initialization - runs before provider ready
///   }
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyNotifier extends Notifier<int> {
///   @override
///   int build() {
///     // initialization - runs when provider is ready
///     return 0;
///   }
/// }
/// ```
class AvoidNotifierConstructorsRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_notifier_constructors',
    problemMessage: 'Avoid using constructors for Notifiers.',
    correctionMessage: 'Use build() method for initialization.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const AvoidNotifierConstructorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  /// Known Riverpod Notifier base class names.
  static const Set<String> _notifierBaseClasses = <String>{
    'Notifier',
    'AsyncNotifier',
    'FamilyNotifier',
    'AsyncNotifierFamily',
    'AutoDisposeNotifier',
    'AutoDisposeAsyncNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends a known Notifier base class
      final extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final superclassName = extendsClause.superclass.name.lexeme;
      if (!_notifierBaseClasses.contains(superclassName)) return;

      // Find constructors with body (not just redirecting or empty)
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          final body = member.body;
          // Skip factory constructors and redirecting constructors
          if (member.factoryKeyword != null) continue;
          if (member.redirectedConstructor != null) continue;

          // Flag if constructor has a body with statements
          if (body is BlockFunctionBody && body.block.statements.isNotEmpty) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Suggests marking provider function arguments as `final`.
///
/// Provider arguments should be immutable for consistent behavior.
/// Mutable arguments can lead to unexpected state changes within
/// the provider callback.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final myProvider = Provider((ref) {
///   int value = 0; // mutable
///   value = 1; // can change unexpectedly
///   return value;
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// final myProvider = Provider((ref) {
///   final value = 0; // immutable
///   return value;
/// });
/// ```
class PreferImmutableProviderArgumentsRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'prefer_immutable_provider_arguments',
    problemMessage: 'Provider arguments should be immutable.',
    correctionMessage: 'Use final for provider arguments.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  const PreferImmutableProviderArgumentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme.endsWith('Provider')) {
        final parameters = node.functionExpression.parameters?.parameters;
        if (parameters != null) {
          for (final param in parameters) {
            if (param is SimpleFormalParameter && !param.isFinal) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when ConsumerWidget doesn't use ref.
///
/// If a widget extends ConsumerWidget but doesn't use ref, it should
/// be a regular StatelessWidget instead.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     return Text('Hello'); // ref not used
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Text('Hello');
///   }
/// }
/// ```
class AvoidUnnecessaryConsumerWidgetsRule extends SaropaLintRule {
  const AvoidUnnecessaryConsumerWidgetsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_consumer_widgets',
    problemMessage: 'ConsumerWidget does not use ref parameter.',
    correctionMessage: 'Use StatelessWidget instead if ref is not needed.',
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
      if (superName != 'ConsumerWidget' &&
          superName != 'ConsumerStatefulWidget') {
        return;
      }

      // Find build method
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          // Check if ref is used in the body
          bool usesRef = false;
          member.body.visitChildren(_RefUsageVisitor(onRefFound: () {
            usesRef = true;
          }));

          if (!usesRef) {
            reporter.atNode(node, code);
          }
          break;
        }
      }
    });
  }
}

class _RefUsageVisitor extends RecursiveAstVisitor<void> {
  _RefUsageVisitor({required this.onRefFound});

  final void Function() onRefFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'ref') {
      onRefFound();
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when nullable AsyncValue patterns are used incorrectly.
///
/// AsyncValue should be used with proper when/map methods, not
/// nullable access patterns.
///
/// **BAD:**
/// ```dart
/// final data = asyncValue.value; // Can be null during loading/error
/// if (asyncValue.value != null) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// asyncValue.when(
///   data: (value) => Text('$value'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// )
/// ```
class AvoidNullableAsyncValuePatternRule extends SaropaLintRule {
  const AvoidNullableAsyncValuePatternRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_async_value_pattern',
    problemMessage: 'Avoid nullable access on AsyncValue.',
    correctionMessage: 'Use when() or map() for safe AsyncValue handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;
      if (propertyName != 'value') return;

      // Check if target looks like asyncValue access
      final String targetSource = node.target?.toSource() ?? '';
      if (targetSource.contains('AsyncValue') ||
          targetSource.endsWith('async') ||
          targetSource.endsWith('Async')) {
        reporter.atNode(node, code);
      }
    });

    // Also check simple identifier access like asyncValue.value
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'value') return;

      final String prefixName = node.prefix.name.toLowerCase();
      if (prefixName.contains('async') ||
          prefixName.endsWith('state') ||
          prefixName.endsWith('provider')) {
        // This is a heuristic - may have some false positives
        // Only flag if the name strongly suggests AsyncValue
        if (prefixName.contains('async')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: Riverpod Advanced Rules
// =============================================================================

/// Warns when AsyncValue is used without error handling.
///
/// AsyncValue can be loading, data, or error. Always handle all states.
///
/// **BAD:**
/// ```dart
/// final value = ref.watch(myAsyncProvider);
/// return Text(value.value.toString()); // Crashes on loading/error!
/// ```
///
/// **GOOD:**
/// ```dart
/// return ref.watch(myAsyncProvider).when(
///   data: (data) => Text(data.toString()),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
class RequireRiverpodErrorHandlingRule extends SaropaLintRule {
  const RequireRiverpodErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_riverpod_error_handling',
    problemMessage:
        'AsyncValue accessed without error handling. Handle loading/error states.',
    correctionMessage:
        'Use .when() or .maybeWhen() to handle all AsyncValue states.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check for direct .value access on AsyncValue
      if (node.propertyName.name != 'value') return;

      final Expression target = node.target!;
      final String targetSource = target.toSource().toLowerCase();

      // Check if it looks like AsyncValue access
      if (targetSource.contains('ref.watch') ||
          targetSource.contains('ref.read')) {
        // Check if the provider name suggests async
        if (targetSource.contains('async') ||
            targetSource.contains('future') ||
            targetSource.contains('stream')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when state is mutated directly instead of using state assignment.
///
/// In Riverpod Notifiers, state should be replaced, not mutated.
///
/// **BAD:**
/// ```dart
/// class MyNotifier extends Notifier<MyState> {
///   void update() {
///     state.items.add(item); // Mutation doesn't trigger rebuild!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void update() {
///   state = state.copyWith(items: [...state.items, item]);
/// }
/// ```
class AvoidRiverpodStateMutationRule extends SaropaLintRule {
  const AvoidRiverpodStateMutationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_riverpod_state_mutation',
    problemMessage:
        'State mutated directly. Mutations don\'t trigger rebuilds.',
    correctionMessage:
        'Use state = state.copyWith(...) to replace state.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _mutatingMethods = <String>{
    'add',
    'addAll',
    'remove',
    'removeAt',
    'removeWhere',
    'clear',
    'insert',
    'insertAll',
    'sort',
    'shuffle',
    'fillRange',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_mutatingMethods.contains(methodName)) return;

      // Check if called on state.something
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource.startsWith('state.') || targetSource == 'state') {
        // Check if inside a Notifier class
        AstNode? current = node.parent;
        while (current != null) {
          if (current is ClassDeclaration) {
            final String? extendsName =
                current.extendsClause?.superclass.name.lexeme;
            if (extendsName != null &&
                (extendsName.contains('Notifier') ||
                    extendsName.contains('StateNotifier'))) {
              reporter.atNode(node, code);
            }
            break;
          }
          current = current.parent;
        }
      }
    });
  }
}

/// Warns when ref.watch is used to access only one field.
///
/// Using select() limits rebuilds to when that specific field changes.
///
/// **BAD:**
/// ```dart
/// final name = ref.watch(userProvider).name;
/// // Rebuilds on ANY user change
/// ```
///
/// **GOOD:**
/// ```dart
/// final name = ref.watch(userProvider.select((u) => u.name));
/// // Only rebuilds when name changes
/// ```
class PreferRiverpodSelectRule extends SaropaLintRule {
  const PreferRiverpodSelectRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_riverpod_select',
    problemMessage:
        'ref.watch() accessing single field. Use .select() for efficiency.',
    correctionMessage:
        'Use ref.watch(provider.select((s) => s.field)) for targeted rebuilds.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check pattern: ref.watch(provider).field
      final Expression? target = node.target;
      if (target is! MethodInvocation) return;

      if (target.methodName.name != 'watch') return;

      // Check if ref.watch
      final Expression? refTarget = target.target;
      if (refTarget == null) return;

      final String refSource = refTarget.toSource().toLowerCase();
      if (!refSource.contains('ref')) return;

      // Check that it's not already using select
      final String watchSource = target.toSource();
      if (watchSource.contains('.select(')) return;

      reporter.atNode(node, code);
    });
  }
}

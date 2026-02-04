// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

// Riverpod-specific lint rules for Saropa Lints
// Implements rules 45–52 from the roadmap

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

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
    problemMessage:
        '[avoid_ref_read_inside_build] ref.read() called inside build() bypasses Riverpod reactivity. The widget will not rebuild when the provider state changes, resulting in stale data displayed to the user. This creates inconsistent UI state that fails silently and produces hard-to-diagnose rendering errors across dependent widgets.',
    correctionMessage:
        'Replace ref.read() with ref.watch() inside build() to subscribe to provider changes and trigger automatic widget rebuilds on state updates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const AvoidRefReadInsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
    problemMessage:
        '[avoid_ref_watch_outside_build] ref.watch() detected outside build() method, breaking the Riverpod widget lifecycle. Subscriptions created outside build() leak memory, produce stale data, and cause missed UI updates that lead to inconsistent state and hard-to-debug rendering errors across dependent widgets.',
    correctionMessage:
        'Move ref.watch() calls into the build() method where Riverpod manages subscription lifecycle and automatic widget rebuilds on provider state changes.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidRefWatchOutsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
/// Alias: ref_in_dispose, dispose_ref_access, cache_ref_in_initstate, avoid_riverpod_ref_in_dispose
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
    problemMessage:
        '[avoid_ref_inside_state_dispose] Ref may already be disposed when '
        'dispose() runs, causing "already disposed" errors or crashes.',
    correctionMessage: 'Cache values in initState instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidRefInsideStateDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
    problemMessage:
        '[use_ref_read_synchronously] ref.read() after await may access a '
        'disposed or invalidated provider, causing crashes or stale reads.',
    correctionMessage: 'Cache ref.read() result before async gap.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const UseRefReadSynchronouslyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
    problemMessage:
        '[use_ref_and_state_synchronously] Using ref after await risks '
        'accessing disposed provider, causing runtime errors or stale data.',
    correctionMessage: 'Cache ref values before await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const UseRefAndStateSynchronouslyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
/// **Note:** This rule intentionally excludes:
/// - Files that don't import Riverpod packages
/// - Flutter's `ValueNotifier`, `ChangeNotifier`, and related types
/// - Assignments inside `initState()` or other lifecycle methods
///
/// **Quick fix available:** Comments out the problematic assignment.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// notifier = SomeNotifier();  // Riverpod notifier reassignment
/// myNotifier = anotherNotifier;
/// ```
///
/// #### GOOD:
/// ```dart
/// // Use provider's own lifecycle
/// ref.read(myProvider.notifier).updateState(newValue);
///
/// // Flutter ValueNotifier in initState is OK
/// @override
/// void initState() {
///   super.initState();
///   _textNotifier = ValueNotifier<String>('');  // OK - Flutter type in initState
/// }
/// ```
class AvoidAssigningNotifiersRule extends SaropaLintRule {
  static const LintCode _code = LintCode(
    name: 'avoid_assigning_notifiers',
    problemMessage:
        '[avoid_assigning_notifiers] Reassigning Notifier breaks provider '
        'contract. State updates are lost and listeners receive stale data.',
    correctionMessage: 'Modify state through Notifier methods instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  const AvoidAssigningNotifiersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  /// Flutter notifier types that should NOT trigger this rule.
  static const Set<String> _flutterNotifierTypes = <String>{
    'ValueNotifier',
    'ChangeNotifier',
    'SafeValueNotifier',
    'TextEditingController',
    'ScrollController',
    'AnimationController',
    'TabController',
    'PageController',
    'FocusNode',
  };

  /// Lifecycle methods where notifier initialization is valid.
  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'didChangeDependencies',
    'didUpdateWidget',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Use direct assignment expression callback for reliable detection
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      final lhs = node.leftHandSide;

      // Only match variables ending with 'notifier'
      if (lhs is! SimpleIdentifier) return;

      final name = lhs.name.toLowerCase();
      if (name != 'notifier' && !name.endsWith('notifier')) return;

      // Check if file imports Riverpod - if not, skip entirely
      if (!_fileImportsRiverpod(node)) return;

      // Skip if inside a lifecycle method - initial construction is valid there
      if (_isInsideLifecycleMethod(node)) return;

      // Check if the RHS type is a Flutter notifier (not Riverpod)
      final rhs = node.rightHandSide;
      if (_isFlutterNotifierConstruction(rhs)) return;

      // Check if the variable's declared type is a Flutter notifier
      final declaredType = lhs.staticType?.getDisplayString();
      if (declaredType != null && _isFlutterNotifierType(declaredType)) return;

      // Also check RHS static type for cases where LHS type isn't resolved
      final rhsType = rhs.staticType?.getDisplayString();
      if (rhsType != null && _isFlutterNotifierType(rhsType)) return;

      reporter.atNode(node, code);
    });
  }

  /// Check if the containing file imports Riverpod packages.
  bool _fileImportsRiverpod(AstNode node) =>
      fileImportsPackage(node, PackageImports.riverpod);

  /// Check if the node is inside a lifecycle method where initialization is valid.
  bool _isInsideLifecycleMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        if (_lifecycleMethods.contains(current.name.lexeme)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  /// Check if the expression is constructing a Flutter notifier type.
  bool _isFlutterNotifierConstruction(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final typeName = expr.constructorName.type.name.lexeme;
      return _flutterNotifierTypes.contains(typeName) ||
          typeName.contains('ValueNotifier') ||
          typeName.contains('ChangeNotifier');
    }
    return false;
  }

  /// Check if a type string indicates a Flutter notifier.
  bool _isFlutterNotifierType(String typeString) {
    for (final flutterType in _flutterNotifierTypes) {
      if (typeString.contains(flutterType)) return true;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutNotifierAssignmentFix()];
}

/// Quick fix that comments out the problematic notifier assignment.
class _CommentOutNotifierAssignmentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final statement = node.thisOrAncestorOfType<ExpressionStatement>();
      if (statement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out notifier assignment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          statement.sourceRange,
          '// HACK: Notifier assignment - use ref.read(provider.notifier) instead\n'
          '// ${statement.toSource()}',
        );
      });
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
  /// Alias: avoid_notifier_constructors_usage

  static const LintCode _code = LintCode(
    name: 'avoid_notifier_constructors',
    problemMessage:
        '[avoid_notifier_constructors] Notifier constructors break Riverpod '
        'lifecycle management. Initialization logic is skipped during rebuild.',
    correctionMessage: 'Use build() method for initialization.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  const AvoidNotifierConstructorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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
  /// Alias: prefer_immutable_provider_arguments_type

  static const LintCode _code = LintCode(
    name: 'prefer_immutable_provider_arguments',
    problemMessage:
        '[prefer_immutable_provider_arguments] Mutable provider arguments cause unpredictable rebuilds. Provider arguments must be immutable for consistent behavior. Mutable arguments can lead to unexpected state changes within the provider callback.',
    correctionMessage:
        'Use final for provider arguments. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  const PreferImmutableProviderArgumentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_consumer_widgets',
    problemMessage:
        '[avoid_unnecessary_consumer_widgets] ConsumerWidget does not use ref parameter. If a widget extends ConsumerWidget but doesn\'t use ref, it must be a regular StatelessWidget instead.',
    correctionMessage:
        'Use StatelessWidget instead if ref is not needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_nullable_async_value_pattern',
    problemMessage:
        '[avoid_nullable_async_value_pattern] Nullable access on AsyncValue bypasses the type system error and loading state handling. '
        'Accessing .value directly returns null during loading and error states, which can propagate nulls through the UI and hide error conditions that users should see.',
    correctionMessage:
        'Use when() or map() to handle all three AsyncValue states (data, loading, error) explicitly. '
        'This ensures loading indicators are shown, errors are surfaced to the user, and the data path only executes when a value is actually available.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_riverpod_error_handling',
    problemMessage:
        '[require_riverpod_error_handling] AsyncValue from a Riverpod provider accessed without handling error and loading states. When the async operation fails or is in progress, accessing .value directly throws a StateError or returns null, causing crashes or displaying stale data. Users see broken UI instead of loading indicators or error messages.',
    correctionMessage:
        'Use .when(data: _, loading: _, error: _) or .maybeWhen() to handle all AsyncValue states explicitly, providing loading indicators and error messages.',
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'avoid_riverpod_state_mutation',
    problemMessage:
        '[avoid_riverpod_state_mutation] Riverpod state mutated directly instead of replaced. Direct mutations don\'t trigger Notifier rebuilds, causing the UI to display stale, inconsistent data. Listeners and consumers will not receive the updated values.',
    correctionMessage:
        'Use state = state.copyWith(..) to replace state. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_riverpod_select',
    problemMessage:
        '[prefer_riverpod_select] ref.watch() accessing single field. Use .select() for efficiency. This pattern increases maintenance cost and the likelihood of introducing bugs during future changes.',
    correctionMessage:
        'Use ref.watch(provider.select((s) => s.field)) for targeted rebuilds. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

// =============================================================================
// Part 5: API Pattern Rules
// =============================================================================

/// Warns when `riverpod` is imported without `flutter_riverpod` in Flutter.
///
/// Alias: wrong_riverpod_import, riverpod_without_flutter
///
/// In Flutter apps, use `flutter_riverpod` not the base `riverpod` package.
/// The base package lacks Flutter-specific widgets like ConsumerWidget.
///
/// **BAD:**
/// ```dart
/// import 'package:riverpod/riverpod.dart';  // Wrong in Flutter!
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// ```
class RequireFlutterRiverpodPackageRule extends SaropaLintRule {
  const RequireFlutterRiverpodPackageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'require_flutter_riverpod_package',
    problemMessage:
        '[require_flutter_riverpod_package] Base riverpod package lacks '
        'Flutter widgets (ProviderScope, ConsumerWidget), causing errors.',
    correctionMessage:
        'Import package:flutter_riverpod/flutter_riverpod.dart instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // Check for plain riverpod import
      if (uri == 'package:riverpod/riverpod.dart') {
        // This is likely wrong in a Flutter app - should use flutter_riverpod
        reporter.atNode(node.uri, code);
      }
    });
  }
}

// =============================================================================
// prefer_riverpod_auto_dispose
// =============================================================================

/// Providers should use autoDispose to free memory when unused.
///
/// Without autoDispose, providers live forever and can cause memory leaks.
/// Use .autoDispose modifier to automatically dispose providers when
/// no longer watched.
///
/// **BAD:**
/// ```dart
/// final myProvider = StateProvider<int>((ref) => 0);
/// ```
///
/// **GOOD:**
/// ```dart
/// final myProvider = StateProvider.autoDispose<int>((ref) => 0);
/// ```
class PreferRiverpodAutoDisposeRule extends SaropaLintRule {
  const PreferRiverpodAutoDisposeRule() : super(code: _code);

  /// Memory leaks from retained providers.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_riverpod_auto_dispose',
    problemMessage:
        '[prefer_riverpod_auto_dispose] Provider declared without the autoDispose modifier retains its state and resources indefinitely even after all listening child widgets are destroyed from the widget tree. This causes memory leaks, stale data accumulation, and unnecessary background computation that grows over the app lifetime, degrading performance progressively.',
    correctionMessage:
        'Add the .autoDispose modifier to the provider declaration (e.g., StateProvider.autoDispose<T>) so resources are released when no consumer is actively listening.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Provider constructors that have autoDispose variants.
  static const Set<String> _providerTypes = <String>{
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
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final Expression? initializer = node.initializer;
      if (initializer == null) return;

      // Check for direct provider construction
      if (initializer is MethodInvocation) {
        final String? typeName = _getProviderTypeName(initializer);
        if (typeName == null || !_providerTypes.contains(typeName)) return;

        // Check if already using autoDispose
        final String source = initializer.toSource();
        if (source.contains('.autoDispose')) return;

        reporter.atNode(initializer, code);
      }
    });
  }

  String? _getProviderTypeName(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      return target.name;
    }
    return null;
  }
}

// =============================================================================
// prefer_riverpod_family_for_params
// =============================================================================

/// Providers with parameters should use .family modifier.
///
/// Using state to pass parameters to providers is error-prone. The .family
/// modifier provides type-safe parameter passing.
///
/// **BAD:**
/// ```dart
/// final userProvider = StateProvider<User?>((ref) => null);
/// // Then: ref.read(userProvider.notifier).state = fetchUser(userId);
/// ```
///
/// **GOOD:**
/// ```dart
/// final userProvider = FutureProvider.family<User, String>((ref, userId) {
///   return fetchUser(userId);
/// });
/// // Usage: ref.watch(userProvider(userId));
/// ```
class PreferRiverpodFamilyForParamsRule extends SaropaLintRule {
  const PreferRiverpodFamilyForParamsRule() : super(code: _code);

  /// Improves type safety and cache behavior.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.provider};

  static const LintCode _code = LintCode(
    name: 'prefer_riverpod_family_for_params',
    problemMessage:
        '[prefer_riverpod_family_for_params] Provider uses nullable state for parameterized data. Use .family instead. Using state to pass parameters to providers is error-prone. The .family modifier provides type-safe parameter passing.',
    correctionMessage:
        'Use FutureProvider.family<T, Param>((ref, param) => ..) for parameterized providers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final Expression? initializer = node.initializer;
      if (initializer == null) return;

      // Look for StateProvider<T?> or StateProvider<SomeType?>
      final String source = initializer.toSource();

      // Check if it's a StateProvider with nullable type (ends with ?>)
      if (!source.startsWith('StateProvider<')) return;

      // Check for nullable type parameter pattern
      final RegExp nullablePattern = RegExp(r'StateProvider<\w+\?>');
      if (!nullablePattern.hasMatch(source)) return;

      // Check if the initializer returns null (pattern: (ref) => null)
      if (!source.contains('=> null')) return;

      reporter.atNode(initializer, code);
    });
  }
}

// =============================================================================
// RIVERPOD RULES (from state_management_rules.dart)
// =============================================================================

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

/// Warns when Consumer widget is used instead of ConsumerWidget.
///
/// Wrapping widgets with Consumer adds unnecessary nesting and boilerplate
/// instead of using ConsumerWidget directly.
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

  /// Alias: prefer_consumer_widget_pattern
  static const LintCode _code = LintCode(
    name: 'prefer_consumer_widget',
    problemMessage:
        '[prefer_consumer_widget] Wrapping widgets with Consumer adds unnecessary nesting and boilerplate instead of using ConsumerWidget directly. The extra widget layer causes redundant rebuilds and increases the widget tree depth, leading to harder-to-debug rebuild cascades and degraded rendering performance.',
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
      node.body.visitChildren(_RefReadInBuildVisitor(reporter, code));
    });
  }
}

/// Visitor that finds ref.read() calls in build method bodies.
class _RefReadInBuildVisitor extends RecursiveAstVisitor<void> {
  _RefReadInBuildVisitor(this.reporter, this.code);

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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: prefer_select_for_partial_state
  static const LintCode _code = LintCode(
    name: 'prefer_select_for_partial',
    problemMessage:
        '[prefer_select_for_partial] Watching the entire provider when only one field is needed causes unnecessary widget tree rebuilds, wasting memory and CPU cycles and reducing app performance. This makes your UI less efficient and responsive.',
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

  /// Alias: prefer_family_for_params_pattern
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
        '[prefer_ref_watch_over_read] ref.read in build() won\'t rebuild widget when provider changes. ref.read doesn\'t subscribe to changes - widget won\'t rebuild when provider updates. Use ref.watch in build methods for reactive updates.',
    correctionMessage:
        'Use ref.watch() in build methods for reactive updates. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
        if (!initSource.contains('Provider') &&
            !initSource.contains('Notifier')) {
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
    if (methodName == 'watch' ||
        methodName == 'read' ||
        methodName == 'listen') {
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
        '[require_error_handling_in_async] Async provider without error handling allows exceptions to propagate unhandled. Unhandled errors in FutureProvider or StreamProvider surface as uncaught exceptions that crash the app or leave the UI in a permanent loading state with no recovery path.',
    correctionMessage:
        'Add try-catch in the provider body or handle AsyncValue.error in the UI with .when() to show error states and enable user recovery.',
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

        if (providerType == null ||
            !_asyncProviderTypes.contains(providerType)) {
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
        '[prefer_notifier_over_state] StateProvider exposes raw state to uncontrolled mutation. StateProvider is fine for simple state but Notifier provides: - Encapsulated business logic - Methods instead of raw state mutation - Better testability.',
    correctionMessage:
        'Use NotifierProvider for encapsulated business logic and testability. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      for (final MapEntry<String, int> entry
          in stateProviderMutations.entries) {
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
        '[require_riverpod_lint] Project uses Riverpod but riverpod_lint is not configured. The official riverpod_lint package catches Riverpod-specific mistakes that general linters miss. Use it alongside saropa_lints for complete coverage.',
    correctionMessage:
        'Add riverpod_lint to dev_dependencies for Riverpod-specific linting. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
        '[avoid_listen_in_async] Using context.watch() inside an async callback triggers widget rebuilds during asynchronous execution, creating stale closures that capture outdated state. This causes data races where async operations complete with wrong values, leading to corrupted state or duplicate side effects.',
    correctionMessage:
        'Replace context.watch() with context.read() in async callbacks to capture the current value without subscribing to rebuilds.',
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
        '[require_async_value_order] AsyncValue.when() has non-standard parameter order. The standard order is data, error, loading. Incorrect order makes code harder to read and may indicate confusion about the API.',
    correctionMessage:
        'Use order: data, error, loading for consistency. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
        if (paramOrder[0] != 'data' ||
            paramOrder[1] != 'error' ||
            paramOrder[2] != 'loading') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when `context.watch<T>()` is used without `select()`.
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
        '[prefer_context_selector] context.watch() accessing property. Use select() for efficiency. watch() rebuilds on any change to the provider. Using select() limits rebuilds to specific property changes.',
    correctionMessage:
        'Replace with context.select((notifier) => notifier.field). Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
        '[avoid_riverpod_notifier_in_build] Creating a Riverpod Notifier inside the build method reinstantiates it on every widget rebuild, discarding all accumulated state. Users experience lost form input, reset scroll positions, and flickering UI as the notifier repeatedly initializes from scratch.',
    correctionMessage:
        'Define the provider outside the widget class (at the file level as a global) and use ref.watch() to access it, ensuring stable state across rebuilds.',
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
        '[require_riverpod_async_value_guard] Try-catch in async provider. Use AsyncValue.guard for consistent error handling. AsyncValue.guard provides better error handling and state management for async operations in Riverpod providers.',
    correctionMessage:
        'Replace try-catch with AsyncValue.guard(() => yourAsyncOperation()). Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
          final String? extendsName =
              current.extendsClause?.superclass.name2.lexeme;
          if (extendsName != null &&
              (extendsName.contains('AsyncNotifier') ||
                  extendsName.contains('FutureProvider'))) {
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

/// Flutter apps need flutter_riverpod, not just riverpod.
///
/// The base `riverpod` package doesn't include Flutter-specific widgets
/// like `ConsumerWidget` and `ProviderScope`. Flutter apps need
/// `flutter_riverpod` or `hooks_riverpod`.
///
/// **BAD:**
/// ```dart
/// import 'package:riverpod/riverpod.dart';  // Missing Flutter bindings!
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:flutter_riverpod/flutter_riverpod.dart';
/// // or
/// import 'package:hooks_riverpod/hooks_riverpod.dart';
/// ```
class RequireFlutterRiverpodNotRiverpodRule extends SaropaLintRule {
  const RequireFlutterRiverpodNotRiverpodRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_flutter_riverpod_not_riverpod',
    problemMessage:
        '[require_flutter_riverpod_not_riverpod] Flutter apps should use '
        'flutter_riverpod, not riverpod package directly.',
    correctionMessage: 'Replace "package:riverpod/riverpod.dart" with '
        '"package:flutter_riverpod/flutter_riverpod.dart".',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // Check for base riverpod import
      if (uri == 'package:riverpod/riverpod.dart') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Riverpod shouldn't handle navigation via global navigator keys.
///
/// Navigation belongs in widgets, not state management. Using Riverpod
/// to control navigation creates tight coupling and makes testing harder.
///
/// **BAD:**
/// ```dart
/// final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());
///
/// class MyNotifier extends StateNotifier<MyState> {
///   final GlobalKey<NavigatorState> navigatorKey;
///
///   void goToDetails() {
///     navigatorKey.currentState?.pushNamed('/details');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Navigate in widgets instead
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     return ElevatedButton(
///       onPressed: () => Navigator.of(context).pushNamed('/details'),
///       child: Text('Details'),
///     );
///   }
/// }
/// ```
class AvoidRiverpodNavigationRule extends SaropaLintRule {
  const AvoidRiverpodNavigationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_riverpod_navigation',
    problemMessage:
        '[avoid_riverpod_navigation] Riverpod provider managing navigation. '
        'Navigation belongs in widgets, not state management.',
    correctionMessage:
        'Move navigation logic to widgets using Navigator.of(context).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for GlobalKey<NavigatorState> in providers
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final String? typeName = node.parent is VariableDeclarationList
          ? (node.parent as VariableDeclarationList).type?.toSource()
          : null;

      if (typeName == null) return;

      // Check for GlobalKey<NavigatorState> in provider context
      if (typeName.contains('GlobalKey<NavigatorState>')) {
        // Check if this is inside a Provider
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodInvocation) {
            final String methodName = current.methodName.name;
            if (methodName == 'Provider' ||
                methodName == 'StateProvider' ||
                methodName == 'FutureProvider' ||
                methodName == 'StreamProvider') {
              reporter.atNode(node, code);
              return;
            }
          }
          if (current is FunctionExpression) {
            final AstNode? funcParent = current.parent;
            if (funcParent is ArgumentList) {
              final AstNode? invocation = funcParent.parent;
              if (invocation is MethodInvocation) {
                final target = invocation.target;
                if (target is SimpleIdentifier &&
                    (target.name == 'Provider' ||
                        target.name == 'StateProvider')) {
                  reporter.atNode(node, code);
                  return;
                }
              }
            }
          }
          current = current.parent;
        }
      }
    });

    // Check for navigation calls in StateNotifier/Notifier classes
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Navigation methods
      if (methodName != 'push' &&
          methodName != 'pushNamed' &&
          methodName != 'pushReplacement' &&
          methodName != 'pop') {
        return;
      }

      // Check if called on navigatorKey or globalKey
      final target = node.target;
      if (target is PrefixedIdentifier) {
        final prefix = target.prefix.name;
        final identifier = target.identifier.name;
        if (identifier == 'currentState' &&
            (prefix.contains('navigator') || prefix.contains('Navigator'))) {
          // Check if inside Notifier/StateNotifier class
          AstNode? current = node.parent;
          while (current != null) {
            if (current is ClassDeclaration) {
              final extendsClause = current.extendsClause;
              if (extendsClause != null) {
                final superName = extendsClause.superclass.toSource();
                if (superName.contains('StateNotifier') ||
                    superName.contains('Notifier') ||
                    superName.contains('AsyncNotifier')) {
                  reporter.atNode(node, code);
                  return;
                }
              }
            }
            current = current.parent;
          }
        }
      }
    });
  }
}

/// Warns when Riverpod is used only for network/API access.
///
/// `[HEURISTIC]` - Detects providers that only wrap HTTP clients.
///
/// Using Riverpod just to access a network layer when direct injection
/// would suffice adds unnecessary complexity.
///
/// **BAD:**
/// ```dart
/// final apiProvider = Provider((ref) => ApiClient());
/// // Then only used as: ref.read(apiProvider).get(...)
/// ```
///
/// **GOOD:**
/// ```dart
/// // Direct injection for simple network access
/// class MyService {
///   MyService(this.apiClient);
///   final ApiClient apiClient;
/// }
/// ```
class AvoidRiverpodForNetworkOnlyRule extends SaropaLintRule {
  const AvoidRiverpodForNetworkOnlyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_riverpod_for_network_only',
    problemMessage:
        '[avoid_riverpod_for_network_only] Provider adds unnecessary indirection for a simple network client. Harder to debug. Using Riverpod just to access a network layer when direct injection would suffice adds unnecessary complexity.',
    correctionMessage:
        'Use direct dependency injection instead of wrapping in a Provider. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _networkClientPattern = RegExp(
    r'(HttpClient|Dio|Client|ApiClient|RestClient|Http)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        final String initSource = initializer.toSource();

        // Check if it's a Provider
        if (!initSource.contains('Provider(')) continue;

        // Check if it only creates a network client
        if (_networkClientPattern.hasMatch(initSource)) {
          // Check if the provider body is simple (just returns client)
          if (!initSource.contains('ref.watch') &&
              !initSource.contains('ref.read') &&
              !initSource.contains('ref.listen')) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}

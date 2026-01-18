// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - State Management Best Practices
// =============================================================================

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
        '[avoid_riverpod_for_network_only] Provider only wraps network client. Consider direct injection.',
    correctionMessage:
        'For simple network access, direct dependency injection may be simpler than Riverpod.',
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

/// Warns when a Bloc class has too many event handlers.
///
/// `[HEURISTIC]` - Counts `on<Event>` registrations in constructor.
///
/// Blocs handling too many responsibilities become hard to maintain.
/// Keep Blocs focused on a single domain.
///
/// **BAD:**
/// ```dart
/// class KitchenSinkBloc extends Bloc<Event, State> {
///   KitchenSinkBloc() : super(Initial()) {
///     on<LoadUser>(_onLoadUser);
///     on<UpdateProfile>(_onUpdateProfile);
///     on<LoadOrders>(_onLoadOrders);
///     on<ProcessPayment>(_onProcessPayment);
///     on<SendNotification>(_onSendNotification);
///     // ... 10+ more handlers
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserBloc extends Bloc<UserEvent, UserState> { /* User only */ }
/// class OrderBloc extends Bloc<OrderEvent, OrderState> { /* Orders only */ }
/// class PaymentBloc extends Bloc<PaymentEvent, PaymentState> { /* Payments only */ }
/// ```
class AvoidLargeBlocRule extends SaropaLintRule {
  const AvoidLargeBlocRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_large_bloc',
    problemMessage:
        '[avoid_large_bloc] Bloc has too many event handlers. Consider splitting into smaller Blocs.',
    correctionMessage:
        'Keep Blocs focused on a single domain. Split into UserBloc, OrderBloc, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxEventHandlers = 7;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.toSource();
      if (!superclass.startsWith('Bloc<')) return;

      // Count on<Event> calls in the class
      int eventHandlerCount = 0;
      final String classSource = node.toSource();

      // Count on< patterns (event handler registrations)
      final RegExp onPattern = RegExp(r'\bon<\w+>\s*\(');
      eventHandlerCount = onPattern.allMatches(classSource).length;

      if (eventHandlerCount > _maxEventHandlers) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Bloc states are over-engineered.
///
/// `[HEURISTIC]` - Detects state classes with redundant states.
///
/// Separate states for "loading" and "idle" when a boolean would suffice.
/// Simpler state machines are easier to reason about.
///
/// **BAD:**
/// ```dart
/// abstract class UserState {}
/// class UserInitial extends UserState {}
/// class UserLoading extends UserState {}
/// class UserIdle extends UserState {}  // Redundant with Initial
/// class UserLoadingMore extends UserState {}  // Could be bool
/// class UserRefreshing extends UserState {}  // Could be bool
/// class UserLoaded extends UserState { final User user; }
/// class UserError extends UserState { final String message; }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserState {
///   final User? user;
///   final bool isLoading;
///   final String? error;
///   // Single state class with clear properties
/// }
/// ```
class AvoidOverengineeredBlocStatesRule extends SaropaLintRule {
  const AvoidOverengineeredBlocStatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_overengineered_bloc_states',
    problemMessage:
        '[avoid_overengineered_bloc_states] Too many state subclasses. Consider using a single state with properties.',
    correctionMessage:
        'Use a single state class with isLoading, error, data properties instead of many subclasses.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxStateSubclasses = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track state base classes and their subclasses
    final Map<String, List<ClassDeclaration>> stateHierarchy =
        <String, List<ClassDeclaration>>{};

    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if this is a state base class (abstract class ending in State)
      if (node.abstractKeyword != null && className.endsWith('State')) {
        stateHierarchy[className] = <ClassDeclaration>[];
      }

      // Check if this extends a state class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superclass = extendsClause.superclass.toSource();
        if (superclass.endsWith('State')) {
          stateHierarchy.putIfAbsent(superclass, () => <ClassDeclaration>[]);
          stateHierarchy[superclass]!.add(node);
        }
      }
    });

    // After processing, check for over-engineered hierarchies
    // Note: This runs per-file, so we check accumulated state
    for (final MapEntry<String, List<ClassDeclaration>> entry
        in stateHierarchy.entries) {
      if (entry.value.length > _maxStateSubclasses) {
        // Report on the first subclass as a hint
        reporter.atNode(entry.value.first, code);
      }
    }
  }
}

/// Warns when GetX static context methods are used.
///
/// `[HEURISTIC]` - Detects Get.offNamed, Get.dialog, etc.
///
/// Get.offNamed and Get.dialog use static context internally which
/// cannot be unit tested. Consider abstraction for testability.
///
/// **BAD:**
/// ```dart
/// void navigateToHome() {
///   Get.offNamed('/home'); // Static context, untestable
/// }
///
/// void showConfirmation() {
///   Get.dialog(AlertDialog(...)); // Static context, untestable
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class NavigationService {
///   void navigateToHome() => Get.offNamed('/home');
/// }
/// // Inject NavigationService for testability
/// ```
class AvoidGetxStaticContextRule extends SaropaLintRule {
  const AvoidGetxStaticContextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_static_context',
    problemMessage:
        '[avoid_getx_static_context] GetX static context method used. Hard to unit test.',
    correctionMessage:
        'Wrap GetX navigation in a service class for testability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _staticContextMethods = {
    'offNamed',
    'offAllNamed',
    'offAndToNamed',
    'offNamedUntil',
    'dialog',
    'defaultDialog',
    'bottomSheet',
    'snackbar',
    'rawSnackbar',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_staticContextMethods.contains(methodName)) return;

      // Check if called on Get
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Get') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when GetX is used excessively throughout a file.
///
/// `[HEURISTIC]` - Counts Get.* usages in a file.
///
/// Using GetX for everything leads to tight coupling and hard-to-test code.
/// Use only necessary features.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends GetView<MyController> {
///   Widget build(BuildContext context) {
///     return Obx(() => Column(children: [
///       Text(controller.name.value),
///       Text(Get.find<UserController>().email.value),
///       ElevatedButton(onTap: () => Get.to(() => NextPage())),
///     ]));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use GetX selectively, not for everything
/// class MyWidget extends StatelessWidget {
///   final MyController controller;
///   // Direct injection for testability
/// }
/// ```
class AvoidTightCouplingWithGetxRule extends SaropaLintRule {
  const AvoidTightCouplingWithGetxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_tight_coupling_with_getx',
    problemMessage:
        '[avoid_tight_coupling_with_getx] Heavy GetX usage detected. Consider reducing coupling.',
    correctionMessage:
        'Use GetX selectively. Consider direct dependency injection for testability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxGetxUsagesPerClass = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Count GetX-specific patterns
      int getxUsages = 0;

      // Get.find, Get.put, Get.to, Get.off, etc.
      getxUsages += RegExp(r'\bGet\.\w+').allMatches(classSource).length;

      // Obx widgets
      getxUsages += RegExp(r'\bObx\s*\(').allMatches(classSource).length;

      // GetBuilder
      getxUsages += RegExp(r'\bGetBuilder\s*<').allMatches(classSource).length;

      // .obs reactive variables
      getxUsages += RegExp(r'\.obs\b').allMatches(classSource).length;

      if (getxUsages > _maxGetxUsagesPerClass) {
        reporter.atNode(node, code);
      }
    });
  }
}

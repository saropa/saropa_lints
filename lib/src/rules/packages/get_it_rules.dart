// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Get_It dependency injection-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the get_it service locator package,
/// including avoiding service locator calls in build methods, proper
/// registration ordering, and test cleanup.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// GET_IT RULES
// =============================================================================

/// Warns when GetIt.I or GetIt.instance is used inside build().
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: getit_in_build, service_locator_in_build, inject_dependencies
///
/// Service locator calls in build() hide dependencies and make
/// testing difficult. Inject dependencies via constructor instead.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final service = GetIt.I<MyService>();
///   return Text(service.value);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   const MyWidget({required this.service});
///   final MyService service;
///
///   @override
///   Widget build(BuildContext context) {
///     return Text(service.value);
///   }
/// }
/// ```
class AvoidGetItInBuildRule extends SaropaLintRule {
  AvoidGetItInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_getit_in_build',
    '[avoid_getit_in_build] GetIt service locator in build() hides dependencies. Service locator calls in build() hide dependencies and make testing difficult. Inject dependencies via constructor instead. {v2}',
    correctionMessage:
        'Inject dependencies via constructor or access in initState(). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      final String bodySource = node.body.toSource();
      if (bodySource.contains('GetIt.I') ||
          bodySource.contains('GetIt.instance') ||
          bodySource.contains('getIt<') ||
          bodySource.contains('getIt(')) {
        // Find the actual GetIt usage
        node.body.visitChildren(_GetItBuildVisitor(reporter, code));
      }
    });
  }
}

class _GetItBuildVisitor extends RecursiveAstVisitor<void> {
  _GetItBuildVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'GetIt' &&
        (node.identifier.name == 'I' || node.identifier.name == 'instance')) {
      reporter.atNode(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String? targetName = node.target?.toSource();
    if (targetName == 'GetIt.I' || targetName == 'GetIt.instance') {
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================

/// Warns when GetIt registration order may cause unresolved dependencies.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: getit_order, getit_registration_sequence, di_order
///
/// When registering services with GetIt, dependent services must be
/// registered before services that use them. Order matters for eager singletons.
///
/// **BAD:**
/// ```dart
/// getIt.registerSingleton<UserService>(UserService(getIt<AuthService>()));
/// getIt.registerSingleton<AuthService>(AuthServiceImpl()); // Too late!
/// ```
///
/// **GOOD:**
/// ```dart
/// getIt.registerSingleton<AuthService>(AuthServiceImpl());
/// getIt.registerSingleton<UserService>(UserService(getIt<AuthService>()));
/// ```
class RequireGetItRegistrationOrderRule extends SaropaLintRule {
  RequireGetItRegistrationOrderRule() : super(code: _code);

  /// Wrong registration order crashes at startup.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_getit_registration_order',
    '[require_getit_registration_order] GetIt registration uses a dependency not yet registered at this point in the setup sequence. This causes runtime errors when the service locator attempts to resolve an unregistered type, resulting in app crashes during startup or lazy initialization that are difficult to reproduce and debug in production. {v3}',
    correctionMessage:
        'Register dependencies before services that depend on them, or use registerLazySingleton.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track registered types in the current function scope
    context.addFunctionBody((FunctionBody body) {
      if (body is! BlockFunctionBody) return;

      final Set<String> registeredTypes = <String>{};
      final List<(MethodInvocation, Set<String>)> registrations = [];

      // First pass: collect all registrations and their dependencies
      body.accept(
        _GetItRegistrationVisitor(
          onRegistration:
              (
                MethodInvocation node,
                String? registeredType,
                Set<String> dependencies,
              ) {
                registrations.add((node, dependencies));
                if (registeredType != null) {
                  registeredTypes.add(registeredType);
                }
              },
        ),
      );

      // Second pass: check for unregistered dependencies at registration time
      final Set<String> seenTypes = <String>{};
      for (final registration in registrations) {
        final node = registration.$1;
        final deps = registration.$2;

        // Check if any dependency wasn't registered before this point
        for (final dep in deps) {
          if (!seenTypes.contains(dep) && registeredTypes.contains(dep)) {
            // This dependency exists but wasn't registered yet
            reporter.atNode(node);
            break;
          }
        }

        // Get the type being registered from this node
        final typeArg = _extractRegisteredType(node);
        if (typeArg != null) {
          seenTypes.add(typeArg);
        }
      }
    });
  }

  static String? _extractRegisteredType(MethodInvocation node) {
    final TypeArgumentList? typeArgs = node.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      return typeArgs.arguments.first.toSource();
    }
    return null;
  }
}

class _GetItRegistrationVisitor extends RecursiveAstVisitor<void> {
  _GetItRegistrationVisitor({required this.onRegistration});

  final void Function(MethodInvocation, String?, Set<String>) onRegistration;

  static const Set<String> _registerMethods = <String>{
    'registerSingleton',
    'registerLazySingleton',
    'registerFactory',
    'registerFactoryParam',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    if (_registerMethods.contains(methodName)) {
      // Get registered type
      String? registeredType;
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        registeredType = typeArgs.arguments.first.toSource();
      }

      // Find dependencies (getIt<T>() calls in the registration)
      final Set<String> dependencies = <String>{};
      node.argumentList.accept(_DependencyFinder(dependencies));

      onRegistration(node, registeredType, dependencies);
    }

    super.visitMethodInvocation(node);
  }
}

class _DependencyFinder extends RecursiveAstVisitor<void> {
  _DependencyFinder(this.dependencies);

  final Set<String> dependencies;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Look for getIt<Type>() or GetIt.I<Type>() patterns
    if (node.methodName.name == 'call' || node.methodName.name == 'get') {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        dependencies.add(typeArgs.arguments.first.toSource());
      }
    }

    // Also check for getIt<Type>() pattern (function call on getIt variable)
    final Expression? target = node.target;
    if (target is SimpleIdentifier &&
        (target.name == 'getIt' || target.name == 'GetIt')) {
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        dependencies.add(typeArgs.arguments.first.toSource());
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // Handle getIt<Type>() syntax
    final TypeArgumentList? typeArgs = node.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      final Expression function = node.function;
      if (function is SimpleIdentifier &&
          (function.name == 'getIt' || function.name.contains('GetIt'))) {
        dependencies.add(typeArgs.arguments.first.toSource());
      }
    }

    super.visitFunctionExpressionInvocation(node);
  }
}

// =============================================================================

/// Warns when GetIt is used in tests without reset in setUp.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
///
/// GetIt singletons persist across tests, causing test pollution.
/// Reset the container in setUp to ensure test isolation.
///
/// **BAD:**
/// ```dart
/// void main() {
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///     // Uses stale singleton from previous test!
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   setUp(() {
///     GetIt.I.reset();
///     GetIt.I.registerSingleton<MyService>(MockMyService());
///   });
///
///   test('my test', () {
///     final service = GetIt.I<MyService>();
///   });
/// }
/// ```
///
/// **Quick fix available:** Adds a reminder comment.
class RequireGetItResetInTestsRule extends SaropaLintRule {
  RequireGetItResetInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  // cspell:ignore getit
  static const LintCode _code = LintCode(
    'require_getit_reset_in_tests',
    '[require_getit_reset_in_tests] GetIt singletons are not automatically reset between tests. If you do not call GetIt.I.reset(), state from one test can leak into others, causing unpredictable, flaky, or misleading results. This can hide real bugs and make tests unreliable. {v3}',
    correctionMessage:
        'To ensure each test runs in isolation, add GetIt.I.reset() in setUp() or setUpAll() of your test suite.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only run in test files
    final String path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('_test.dart') && !path.contains('/test/')) {
      return;
    }

    context.addCompilationUnit((CompilationUnit unit) {
      final String source = unit.toSource();

      // Check if GetIt is used
      if (!source.contains('GetIt.I') && !source.contains('GetIt.instance')) {
        return;
      }

      // Check if reset is called (typically in setUp/setUpAll)
      final bool hasReset =
          source.contains('.reset()') ||
          source.contains('.resetLazySingleton') ||
          source.contains('GetIt.I.reset') ||
          source.contains('getIt.reset');

      // Only report if GetIt is used but never reset
      if (!hasReset) {
        // Find the first GetIt usage and report there
        unit.visitChildren(_GetItUsageVisitor(reporter, code));
      }
    });
  }
}

class _GetItUsageVisitor extends RecursiveAstVisitor<void> {
  _GetItUsageVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool _reported = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_reported) return;

    if (node.prefix.name == 'GetIt' &&
        (node.identifier.name == 'I' || node.identifier.name == 'instance')) {
      reporter.atNode(node);
      _reported = true;
    }
    super.visitPrefixedIdentifier(node);
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Dependency injection lint rules for Flutter/Dart applications.
///
/// These rules help enforce proper dependency injection patterns,
/// improving testability, maintainability, and separation of concerns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when service locator is accessed directly in widgets.
///
/// Widgets should receive dependencies through constructors or providers,
/// not by directly accessing a service locator. This improves testability
/// and makes dependencies explicit.
///
/// **BAD:**
/// ```dart
/// class UserWidget extends StatelessWidget {
///   Widget build(BuildContext context) {
///     final userService = GetIt.I<UserService>(); // Direct access
///     return Text(userService.currentUser.name);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserWidget extends StatelessWidget {
///   const UserWidget({required this.userService});
///   final UserService userService;
///
///   Widget build(BuildContext context) {
///     return Text(userService.currentUser.name);
///   }
/// }
/// ```
class AvoidServiceLocatorInWidgetsRule extends SaropaLintRule {
  const AvoidServiceLocatorInWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_service_locator_in_widgets',
    problemMessage:
        '[avoid_service_locator_in_widgets] Service locator in widget hides dependencies. Cannot mock in widget tests. This reduces testability, maintainability, and makes code harder to refactor.',
    correctionMessage:
        'Add required constructor parameter: MyWidget({required this.service}).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _serviceLocatorPatterns = <String>{
    'GetIt.I',
    'GetIt.instance',
    'getIt(',
    'getIt<',
    'locator(',
    'locator<',
    'sl(',
    'sl<',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Widget') && !superName.contains('State')) {
        return;
      }

      // Check the class body for service locator access
      final String classSource = node.toSource();
      for (final String pattern in _serviceLocatorPatterns) {
        if (classSource.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when constructor has too many dependencies.
///
/// Classes with many dependencies often violate single responsibility.
/// Consider breaking the class into smaller, focused components.
///
/// **BAD:**
/// ```dart
/// class OrderService {
///   OrderService(
///     this.userRepo,
///     this.productRepo,
///     this.paymentService,
///     this.shippingService,
///     this.notificationService,
///     this.analyticsService,
///     this.cacheService,
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class OrderService {
///   OrderService(this.orderProcessor, this.orderNotifier);
///   final OrderProcessor orderProcessor;
///   final OrderNotifier orderNotifier;
/// }
/// ```
class AvoidTooManyDependenciesRule extends SaropaLintRule {
  const AvoidTooManyDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_too_many_dependencies',
    problemMessage:
        '[avoid_too_many_dependencies] Constructor has >5 dependencies. Class likely violates Single Responsibility.',
    correctionMessage:
        'Group related dependencies into a facade class, or split this class.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Maximum recommended number of constructor dependencies.
  static const int _maxDependencies = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      // Skip factory constructors and named constructors
      if (node.factoryKeyword != null) return;
      if (node.name != null) return; // Named constructor

      final FormalParameterList params = node.parameters;
      int dependencyCount = 0;

      for (final FormalParameter param in params.parameters) {
        // Count parameters that are likely dependencies (not primitives)
        final String? typeName = _getParameterTypeName(param);
        if (typeName != null && _isDependencyType(typeName)) {
          dependencyCount++;
        }
      }

      if (dependencyCount > _maxDependencies) {
        reporter.atNode(node, code);
      }
    });
  }

  String? _getParameterTypeName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      return _getParameterTypeName(param.parameter);
    } else if (param is FieldFormalParameter) {
      return param.type?.toSource();
    }
    return null;
  }

  bool _isDependencyType(String typeName) {
    // Exclude primitive types and common value types
    const Set<String> primitiveTypes = <String>{
      'String',
      'int',
      'double',
      'bool',
      'num',
      'List',
      'Map',
      'Set',
      'Duration',
      'DateTime',
      'Key',
      'Color',
    };

    for (final String primitive in primitiveTypes) {
      if (typeName == primitive || typeName.startsWith('$primitive<')) {
        return false;
      }
    }
    return true;
  }
}

/// Warns when dependencies are created inside the class instead of injected.
///
/// Creating dependencies internally makes testing difficult and creates
/// tight coupling. Dependencies should be injected from outside.
///
/// **BAD:**
/// ```dart
/// class UserViewModel {
///   final _userRepo = UserRepository(); // Created internally
///   final _api = ApiClient(); // Created internally
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserViewModel {
///   UserViewModel(this._userRepo, this._api);
///   final UserRepository _userRepo;
///   final ApiClient _api;
/// }
/// ```
class AvoidInternalDependencyCreationRule extends SaropaLintRule {
  const AvoidInternalDependencyCreationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_internal_dependency_creation',
    problemMessage:
        '[avoid_internal_dependency_creation] Dependency created internally. Cannot substitute mock for testing.',
    correctionMessage:
        'Add constructor parameter: MyClass(this._repo); then inject from outside.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dependencySuffixes = <String>{
    'Repository',
    'Service',
    'Client',
    'Api',
    'Provider',
    'Manager',
    'Handler',
    'Controller',
    'UseCase',
    'Interactor',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check for field initializers that create dependencies
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        if (initializer is InstanceCreationExpression) {
          final String? typeName =
              initializer.constructorName.type.element?.name;
          if (typeName != null) {
            for (final String suffix in _dependencySuffixes) {
              if (typeName.endsWith(suffix)) {
                reporter.atNode(initializer, code);
                break;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when abstract class is not used for dependency contracts.
///
/// Dependencies should depend on abstractions (interfaces/abstract classes),
/// not concrete implementations, following the Dependency Inversion Principle.
///
/// **BAD:**
/// ```dart
/// class OrderService {
///   OrderService(this.repo);
///   final PostgresUserRepository repo; // Depends on concrete class
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class OrderService {
///   OrderService(this.repo);
///   final UserRepository repo; // Depends on abstraction
/// }
/// ```
class PreferAbstractDependenciesRule extends SaropaLintRule {
  const PreferAbstractDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_abstract_dependencies',
    problemMessage:
        '[prefer_abstract_dependencies] Depends on concrete implementation. Tight coupling prevents substitution.',
    correctionMessage:
        'Use abstract type: replace PostgresUserRepo with UserRepository interface.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _concretePrefixes = <String>{
    'Postgres',
    'Mysql',
    'Sqlite',
    'Http',
    'Rest',
    'Grpc',
    'Firebase',
    'Aws',
    'Mock',
    'Fake',
    'Real',
    'Default',
    'Impl',
    'Concrete',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final FormalParameter param in node.parameters.parameters) {
        final String? typeName = _getParameterTypeName(param);
        if (typeName == null) continue;

        for (final String prefix in _concretePrefixes) {
          if (typeName.startsWith(prefix)) {
            reporter.atNode(param, code);
            break;
          }
        }

        // Also check for Impl suffix
        if (typeName.endsWith('Impl')) {
          reporter.atNode(param, code);
        }
      }
    });
  }

  String? _getParameterTypeName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      return _getParameterTypeName(param.parameter);
    } else if (param is FieldFormalParameter) {
      return param.type?.toSource();
    }
    return null;
  }
}

/// Warns when scoped dependencies are registered as singletons.
///
/// Some dependencies should be scoped to a specific lifecycle (e.g., per request,
/// per screen) rather than being global singletons.
///
/// **BAD:**
/// ```dart
/// // User session data as singleton persists across logouts
/// getIt.registerSingleton(UserSession());
/// getIt.registerSingleton(ShoppingCart());
/// ```
///
/// **GOOD:**
/// ```dart
/// // Scope to authenticated user session
/// getIt.registerFactory(() => UserSession());
/// getIt.registerFactoryParam((userId, _) => ShoppingCart(userId));
/// ```
class AvoidSingletonForScopedDependenciesRule extends SaropaLintRule {
  const AvoidSingletonForScopedDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_singleton_for_scoped_dependencies',
    problemMessage:
        '[avoid_singleton_for_scoped_dependencies] Scoped data as singleton. State will persist across sessions/screens.',
    correctionMessage:
        'Use registerFactory(() => MySession()) for fresh instance per scope.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scopedTypePatterns = <String>{
    'Session',
    'Cart',
    'Checkout',
    'Form',
    'Wizard',
    'Flow',
    'Dialog',
    'Modal',
    'Editor',
    'Draft',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'registerSingleton') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();

      for (final String pattern in _scopedTypePatterns) {
        if (argSource.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when circular dependencies are detected in DI registration.
///
/// Circular dependencies cause runtime errors or infinite loops during
/// dependency resolution.
///
/// **BAD:**
/// ```dart
/// class ServiceA {
///   ServiceA(this.serviceB);
///   final ServiceB serviceB;
/// }
/// class ServiceB {
///   ServiceB(this.serviceA); // Circular!
///   final ServiceA serviceA;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ServiceA {
///   ServiceA(this.serviceB);
///   final ServiceB serviceB;
/// }
/// class ServiceB {
///   ServiceB(this.dataProvider); // No circular reference
///   final DataProvider dataProvider;
/// }
/// ```
class AvoidCircularDiDependenciesRule extends SaropaLintRule {
  const AvoidCircularDiDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_circular_di_dependencies',
    problemMessage:
        '[avoid_circular_di_dependencies] Potential circular dependency detected.',
    correctionMessage:
        'Refactor to break the cycle using interfaces or events.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Find constructor parameters
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration && member.name == null) {
          for (final FormalParameter param in member.parameters.parameters) {
            final String? typeName = _getParameterTypeName(param);
            if (typeName == null) continue;

            // Check if this type might depend back on us
            // Simple heuristic: if they share a suffix pattern
            if (_mightBeCircular(className, typeName)) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }

  String? _getParameterTypeName(FormalParameter param) {
    if (param is SimpleFormalParameter) {
      return param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      return _getParameterTypeName(param.parameter);
    } else if (param is FieldFormalParameter) {
      return param.type?.toSource();
    }
    return null;
  }

  bool _mightBeCircular(String className, String dependencyType) {
    // Heuristic: if both end with Service, Repository, etc.
    // and one name contains the other, might be circular
    const List<String> patterns = <String>[
      'Service',
      'Repository',
      'Manager',
      'Controller',
      'Handler',
    ];

    for (final String pattern in patterns) {
      if (className.endsWith(pattern) && dependencyType.endsWith(pattern)) {
        // Check if names suggest relationship
        final String classBase =
            className.substring(0, className.length - pattern.length);
        final String depBase =
            dependencyType.substring(0, dependencyType.length - pattern.length);

        if (classBase.contains(depBase) || depBase.contains(classBase)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when optional dependencies use null instead of null object pattern.
///
/// Using null for optional dependencies leads to null checks everywhere.
/// The null object pattern provides a default implementation instead.
///
/// **BAD:**
/// ```dart
/// class AnalyticsService {
///   AnalyticsService({this.logger}); // Nullable
///   final Logger? logger;
///
///   void track(String event) {
///     logger?.log(event); // Null checks everywhere
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class AnalyticsService {
///   AnalyticsService({Logger? logger}) : logger = logger ?? NoOpLogger();
///   final Logger logger;
///
///   void track(String event) {
///     logger.log(event); // No null checks needed
///   }
/// }
/// ```
class PreferNullObjectPatternRule extends SaropaLintRule {
  const PreferNullObjectPatternRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_null_object_pattern',
    problemMessage:
        '[prefer_null_object_pattern] Consider using null object pattern for optional dependency.',
    correctionMessage: 'Provide a no-op implementation instead of using null.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _optionalDependencySuffixes = <String>{
    'Logger',
    'Analytics',
    'Tracker',
    'Reporter',
    'Monitor',
    'Observer',
    'Listener',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type == null) return;

      final String typeSource = type.toSource();

      // Check if it's a nullable optional dependency type
      if (!typeSource.endsWith('?')) return;

      final String baseType = typeSource.substring(0, typeSource.length - 1);
      for (final String suffix in _optionalDependencySuffixes) {
        if (baseType.endsWith(suffix)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when dependency registration lacks type safety.
///
/// Untyped registrations can cause runtime errors that are hard to debug.
///
/// **BAD:**
/// ```dart
/// getIt.registerSingleton(UserService()); // Type not explicit
/// ```
///
/// **GOOD:**
/// ```dart
/// getIt.registerSingleton<UserService>(UserService());
/// getIt.registerSingleton<IUserService>(UserServiceImpl());
/// ```
class RequireTypedDiRegistrationRule extends SaropaLintRule {
  const RequireTypedDiRegistrationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_typed_di_registration',
    problemMessage:
        '[require_typed_di_registration] DI registration should have explicit type parameter.',
    correctionMessage:
        'Add type parameter like registerSingleton<Type>(instance).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _registrationMethods = <String>{
    'registerSingleton',
    'registerLazySingleton',
    'registerFactory',
    'registerFactoryParam',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_registrationMethods.contains(methodName)) return;

      // Check for type arguments
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function literal is passed to registerSingleton.
///
/// registerSingleton expects an already-created instance, not a factory
/// function. Use registerLazySingleton or registerFactory for factories.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// getIt.registerSingleton<UserService>(() => UserService()); // Function!
/// getIt.registerSingleton(() => MyService()); // Wrong!
/// ```
///
/// #### GOOD:
/// ```dart
/// getIt.registerSingleton<UserService>(UserService()); // Instance
/// // OR for lazy initialization:
/// getIt.registerLazySingleton<UserService>(() => UserService());
/// // OR for factories:
/// getIt.registerFactory<UserService>(() => UserService());
/// ```
class AvoidFunctionsInRegisterSingletonRule extends SaropaLintRule {
  const AvoidFunctionsInRegisterSingletonRule() : super(code: _code);

  /// Potential bug. Wrong method used.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_functions_in_register_singleton',
    problemMessage:
        '[avoid_functions_in_register_singleton] registerSingleton expects an instance, not a factory function.',
    correctionMessage:
        'Use registerLazySingleton(() => ...) or registerFactory(() => ...) '
        'for lazy instantiation. Use registerSingleton(MyService()) for eager.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'registerSingleton') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      // Get the first positional argument
      Expression? firstArg;
      for (final Expression arg in args.arguments) {
        if (arg is! NamedExpression) {
          firstArg = arg;
          break;
        }
      }

      if (firstArg == null) return;

      // Check if it's a function expression
      if (firstArg is FunctionExpression) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when GetIt registration order may cause unresolved dependencies.
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
  const RequireGetItRegistrationOrderRule() : super(code: _code);

  /// Wrong registration order crashes at startup.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_getit_registration_order',
    problemMessage:
        '[require_getit_registration_order] GetIt registration uses dependency not yet registered at this point. This can cause runtime errors and unpredictable dependency resolution.',
    correctionMessage:
        'Register dependencies before services that depend on them, or use registerLazySingleton.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track registered types in the current function scope
    context.registry.addFunctionBody((FunctionBody body) {
      if (body is! BlockFunctionBody) return;

      final Set<String> registeredTypes = <String>{};
      final List<(MethodInvocation, Set<String>)> registrations = [];

      // First pass: collect all registrations and their dependencies
      body.accept(_GetItRegistrationVisitor(
        onRegistration: (MethodInvocation node, String? registeredType,
            Set<String> dependencies) {
          registrations.add((node, dependencies));
          if (registeredType != null) {
            registeredTypes.add(registeredType);
          }
        },
      ));

      // Second pass: check for unregistered dependencies at registration time
      final Set<String> seenTypes = <String>{};
      for (final registration in registrations) {
        final node = registration.$1;
        final deps = registration.$2;

        // Check if any dependency wasn't registered before this point
        for (final dep in deps) {
          if (!seenTypes.contains(dep) && registeredTypes.contains(dep)) {
            // This dependency exists but wasn't registered yet
            reporter.atNode(node, code);
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

/// Warns when config access doesn't provide defaults for missing values.
///
/// Alias: config_default, env_default, settings_fallback
///
/// Environment variables and config values can be missing. Always provide
/// defaults or validate required values at startup.
///
/// **BAD:**
/// ```dart
/// final apiUrl = dotenv.get('API_URL'); // Crashes if missing
/// final timeout = int.parse(env['TIMEOUT']!); // Null pointer if missing
/// ```
///
/// **GOOD:**
/// ```dart
/// final apiUrl = dotenv.get('API_URL', fallback: 'https://api.example.com');
/// final timeout = int.tryParse(env['TIMEOUT'] ?? '') ?? 30;
/// ```
class RequireDefaultConfigRule extends SaropaLintRule {
  const RequireDefaultConfigRule() : super(code: _code);

  /// Missing config causes startup crashes in production.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_default_config',
    problemMessage:
        '[require_default_config] Accessing configuration values without providing a default or fallback can cause runtime crashes if the value is missing or misconfigured. This leads to unpredictable app behavior, poor user experience, and failed startup. It may also result in app store rejection for reliability issues.',
    correctionMessage:
        'Always provide a fallback value or use nullable access with a null check when reading config values. Document default values and ensure your app can start and function even if a config value is missing.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods that get config values.
  static const Set<String> _configMethods = <String>{
    'get',
    'getString',
    'getInt',
    'getDouble',
    'getBool',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_configMethods.contains(methodName)) return;

      // Check if target looks like config/env
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('dotenv') &&
          !targetSource.contains('config') &&
          !targetSource.contains('env') &&
          !targetSource.contains('prefs')) {
        return;
      }

      // Check if a default/fallback is provided
      final ArgumentList args = node.argumentList;
      final bool hasDefault = args.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          return name == 'fallback' ||
              name == 'defaultValue' ||
              name == 'orElse';
        }
        return false;
      });

      if (!hasDefault) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - Dependency Injection Rules
// =============================================================================

/// Warns when setter injection is used instead of constructor injection.
///
/// Alias: constructor_injection, di_constructor, setter_injection
///
/// Constructor injection makes dependencies explicit and ensures objects are
/// fully initialized when created. Setter injection allows partially initialized
/// objects and makes dependencies implicit.
///
/// **BAD:**
/// ```dart
/// class UserService {
///   late UserRepository _repo; // Setter injection
///   late AnalyticsService _analytics;
///
///   set repository(UserRepository repo) => _repo = repo;
///   set analytics(AnalyticsService a) => _analytics = a;
///
///   void configure(UserRepository repo) { // Method injection
///     _repo = repo;
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserService {
///   const UserService(this._repo, this._analytics);
///
///   final UserRepository _repo;
///   final AnalyticsService _analytics;
/// }
/// ```
///
/// **Also flags:**
/// - `late` fields for service types that should be constructor-injected
/// - Setter methods for dependency types
/// - `init()` or `configure()` methods that set dependencies
class PreferConstructorInjectionRule extends SaropaLintRule {
  const PreferConstructorInjectionRule() : super(code: _code);

  /// Code quality issue. Makes testing harder.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_constructor_injection',
    problemMessage:
        '[prefer_constructor_injection] Setter/method injection hides dependencies. Use constructor injection.',
    correctionMessage:
        'Make this a final field and add a constructor parameter: '
        'MyClass(this._service);',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Suffixes that identify dependency types (services, repos, etc.).
  static const Set<String> _dependencySuffixes = <String>{
    'Service',
    'Repository',
    'Repo',
    'Client',
    'Api',
    'Provider',
    'Manager',
    'Handler',
    'Controller',
    'UseCase',
    'Interactor',
    'Gateway',
    'Store',
    'Bloc',
    'Cubit',
    'Notifier',
  };

  /// Methods that suggest setter/method injection patterns.
  static const Set<String> _injectionMethodNames = <String>{
    'init',
    'initialize',
    'configure',
    'setup',
    'inject',
    'setDependencies',
    'setServices',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip abstract classes and mixins
      if (node.abstractKeyword != null) return;

      for (final ClassMember member in node.members) {
        // Check for late fields with dependency types
        if (member is FieldDeclaration) {
          _checkLateDependencyField(member, reporter);
        }

        // Check for setter methods that set dependencies
        if (member is MethodDeclaration && member.isSetter) {
          _checkDependencySetter(member, reporter);
        }

        // Check for init/configure methods that set dependencies
        if (member is MethodDeclaration && !member.isSetter) {
          _checkInjectionMethod(member, reporter);
        }
      }
    });
  }

  void _checkLateDependencyField(
    FieldDeclaration field,
    SaropaDiagnosticReporter reporter,
  ) {
    // Check if field has late keyword
    if (field.fields.lateKeyword == null) return;

    // Check if field type is a dependency
    final TypeAnnotation? type = field.fields.type;
    if (type == null) return;

    final String typeStr = type.toSource();
    for (final String suffix in _dependencySuffixes) {
      if (typeStr.contains(suffix)) {
        reporter.atNode(field, code);
        return;
      }
    }
  }

  void _checkDependencySetter(
    MethodDeclaration setter,
    SaropaDiagnosticReporter reporter,
  ) {
    // Check parameter type
    final FormalParameterList? params = setter.parameters;
    if (params == null || params.parameters.isEmpty) return;

    final FormalParameter param = params.parameters.first;
    String? typeStr;

    if (param is SimpleFormalParameter) {
      typeStr = param.type?.toSource();
    } else if (param is DefaultFormalParameter) {
      final innerParam = param.parameter;
      if (innerParam is SimpleFormalParameter) {
        typeStr = innerParam.type?.toSource();
      }
    }

    if (typeStr != null) {
      for (final String suffix in _dependencySuffixes) {
        if (typeStr.contains(suffix)) {
          reporter.atNode(setter, code);
          return;
        }
      }
    }
  }

  void _checkInjectionMethod(
    MethodDeclaration method,
    SaropaDiagnosticReporter reporter,
  ) {
    final String methodName = method.name.lexeme.toLowerCase();

    // Check if method name suggests dependency injection
    if (!_injectionMethodNames.any((name) => methodName.contains(name))) {
      return;
    }

    // Check if method has dependency-type parameters
    final FormalParameterList? params = method.parameters;
    if (params == null) return;

    for (final FormalParameter param in params.parameters) {
      String? typeStr;

      if (param is SimpleFormalParameter) {
        typeStr = param.type?.toSource();
      } else if (param is DefaultFormalParameter) {
        final innerParam = param.parameter;
        if (innerParam is SimpleFormalParameter) {
          typeStr = innerParam.type?.toSource();
        }
      }

      if (typeStr != null) {
        for (final String suffix in _dependencySuffixes) {
          if (typeStr.contains(suffix)) {
            reporter.atNode(method, code);
            return;
          }
        }
      }
    }
  }
}

// =============================================================================
// require_di_scope_awareness
// =============================================================================

/// Understand singleton vs factory vs lazySingleton scopes in GetIt.
///
/// Misusing DI scopes causes lifecycle bugs:
/// - singleton: Created once, lives forever
/// - lazySingleton: Created on first access, lives forever
/// - factory: Created fresh each time
///
/// **Potential issues:**
/// ```dart
/// // BAD: Stateful service as singleton
/// GetIt.I.registerSingleton(UserSessionService());  // Retains old user data!
///
/// // BAD: Expensive service as factory
/// GetIt.I.registerFactory(() => DatabaseConnection());  // Creates connection each time!
/// ```
///
/// **GOOD:**
/// ```dart
/// GetIt.I.registerLazySingleton(() => DatabaseConnection());
/// GetIt.I.registerFactory(() => RequestHandler());  // Stateless, OK as factory
/// ```
class RequireDiScopeAwarenessRule extends SaropaLintRule {
  const RequireDiScopeAwarenessRule() : super(code: _code);

  /// Memory leaks or stale data from wrong scope.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_di_scope_awareness',
    problemMessage:
        '[require_di_scope_awareness] Review DI scope: singleton retains state, factory creates each time.',
    correctionMessage:
        'Use lazySingleton for expensive objects, factory for stateless handlers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Service types that might have scope issues.
  static const Set<String> _statefulSuffixes = <String>{
    'Session',
    'Cache',
    'Store',
    'State',
    'Manager',
    'Controller',
  };

  static const Set<String> _expensiveSuffixes = <String>{
    'Connection',
    'Database',
    'Client',
    'Service',
    'Repository',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for GetIt registration methods
      if (methodName != 'registerSingleton' &&
          methodName != 'registerFactory' &&
          methodName != 'registerLazySingleton') {
        return;
      }

      // Check if target is GetIt
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('GetIt') &&
          !targetSource.contains('sl') &&
          !targetSource.contains('locator') &&
          !targetSource.contains('getIt')) {
        return;
      }

      // Get the registered type
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final String argSource = args.arguments.first.toSource();

      // Check for potentially misused scopes
      if (methodName == 'registerSingleton') {
        // Stateful services as singleton may cause stale data
        for (final String suffix in _statefulSuffixes) {
          if (argSource.contains(suffix)) {
            reporter.atNode(node, code);
            return;
          }
        }
      } else if (methodName == 'registerFactory') {
        // Expensive services as factory waste resources
        for (final String suffix in _expensiveSuffixes) {
          if (argSource.contains(suffix)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_di_in_widgets
// =============================================================================

/// Widgets should get dependencies via InheritedWidget/Provider, not GetIt.
///
/// Direct service locator calls in widgets:
/// - Couple widgets tightly to DI container
/// - Make widgets harder to test
/// - Prevent proper dependency injection patterns
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final service = GetIt.I<UserService>();  // Direct locator call
///     return Text(service.userName);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final service = context.read<UserService>();  // Via Provider
///     return Text(service.userName);
///   }
/// }
/// ```
class AvoidDiInWidgetsRule extends SaropaLintRule {
  const AvoidDiInWidgetsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_di_in_widgets',
    problemMessage:
        '[avoid_di_in_widgets] Avoid GetIt.I in widgets. Use Provider or '
        'InheritedWidget for dependency injection in UI.',
    correctionMessage:
        'Pass dependencies via constructor or use context.read<T>() instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check if inside a widget class
      if (!_isInsideWidgetClass(node)) return;

      // Check for GetIt access patterns
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      final String methodName = node.methodName.name;

      // Match GetIt.I<T>(), GetIt.instance<T>(), sl<T>(), locator<T>()
      if (_isServiceLocatorCall(targetSource, methodName)) {
        reporter.atNode(node, code);
      }
    });

    // Also check for GetIt.I.get<T>() patterns
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!_isInsideWidgetClass(node)) return;

      final String source = node.toSource();
      if (source == 'GetIt.I' ||
          source == 'GetIt.instance' ||
          source == 'GetIt.asNewInstance') {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideWidgetClass(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) {
        final ExtendsClause? extendsClause = current.extendsClause;
        if (extendsClause != null) {
          final String superclass = extendsClause.superclass.toSource();
          return superclass.contains('Widget') || superclass.contains('State<');
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _isServiceLocatorCall(String targetSource, String methodName) {
    // GetIt patterns
    if (targetSource.contains('GetIt') && methodName == 'call') return true;
    if (targetSource.contains('GetIt') && methodName == 'get') return true;

    // Common service locator aliases
    if ((targetSource == 'sl' || targetSource == 'locator') &&
        methodName == 'call') {
      return true;
    }

    return false;
  }
}

// =============================================================================
// prefer_abstraction_injection
// =============================================================================

/// Inject interfaces/abstract classes, not concrete implementations.
///
/// Injecting concrete types:
/// - Prevents mocking in tests
/// - Creates tight coupling
/// - Makes it harder to swap implementations
///
/// **BAD:**
/// ```dart
/// class OrderService {
///   OrderService(this._httpClient);  // Concrete type
///   final HttpClient _httpClient;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class OrderService {
///   OrderService(this._client);  // Abstract type
///   final ApiClient _client;  // Where ApiClient is abstract
/// }
/// ```
class PreferAbstractionInjectionRule extends SaropaLintRule {
  const PreferAbstractionInjectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_abstraction_injection',
    problemMessage:
        '[prefer_abstraction_injection] Injecting concrete implementation. '
        'Prefer injecting abstract types for testability.',
    correctionMessage:
        'Create an abstract class or interface and inject that instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Concrete type patterns that suggest implementation injection.
  static const Set<String> _concretePatterns = <String>{
    'Impl',
    'Implementation',
    'Concrete',
    'Default',
    'Real',
    'Actual',
    'Http',
    'Dio',
    'Socket',
    'Sql',
    'Sqlite',
    'Firebase',
    'Supabase',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConstructorDeclaration((ConstructorDeclaration node) {
      final FormalParameterList? params = node.parameters;
      if (params == null) return;

      for (final FormalParameter param in params.parameters) {
        String? typeStr;

        if (param is SimpleFormalParameter) {
          typeStr = param.type?.toSource();
        } else if (param is DefaultFormalParameter) {
          final innerParam = param.parameter;
          if (innerParam is SimpleFormalParameter) {
            typeStr = innerParam.type?.toSource();
          }
        } else if (param is FieldFormalParameter) {
          typeStr = param.type?.toSource();
        }

        if (typeStr != null && _isLikelyConcrete(typeStr)) {
          reporter.atNode(param, code);
        }
      }
    });
  }

  bool _isLikelyConcrete(String typeName) {
    for (final String pattern in _concretePatterns) {
      if (typeName.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// Lazy Singleton Rules (from v4.1.7)
// =============================================================================

/// Warns when eager singleton registration is used for expensive objects.
///
/// `[HEURISTIC]` - Detects registerSingleton with expensive constructors.
///
/// Eager registration creates all singletons at startup.
/// Use registerLazySingleton for expensive objects.
///
/// **BAD:**
/// ```dart
/// void setupDI() {
///   GetIt.I.registerSingleton(DatabaseService()); // Created immediately!
///   GetIt.I.registerSingleton(AnalyticsService()); // Created immediately!
///   GetIt.I.registerSingleton(CacheService()); // All at startup!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void setupDI() {
///   GetIt.I.registerLazySingleton(() => DatabaseService()); // Created on first use
///   GetIt.I.registerLazySingleton(() => AnalyticsService());
///   GetIt.I.registerLazySingleton(() => CacheService());
/// }
/// ```
class PreferLazySingletonRegistrationRule extends SaropaLintRule {
  const PreferLazySingletonRegistrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_lazy_singleton_registration',
    problemMessage:
        '[prefer_lazy_singleton_registration] Eager singleton registration. Consider lazy registration.',
    correctionMessage:
        'Use registerLazySingleton(() => Service()) for deferred initialization.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _expensiveServicePattern = RegExp(
    r'(Database|Analytics|Cache|Logger|Http|Api|Network|Storage|Auth)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'registerSingleton') return;

      // Check arguments for potentially expensive services
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();

      // Check if registering a potentially expensive service
      if (_expensiveServicePattern.hasMatch(argSource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

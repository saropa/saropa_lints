// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Dependency injection lint rules for Flutter/Dart applications.
///
/// These rules help enforce proper dependency injection patterns,
/// improving testability, maintainability, and separation of concerns.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';
import '../type_annotation_utils.dart';

/// Warns when service locator is accessed directly in widgets.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidServiceLocatorInWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_service_locator_in_widgets',
    '[avoid_service_locator_in_widgets] Service locator in widget hides dependencies. Cannot mock in widget tests. This reduces testability, maintainability, and makes code harder to refactor. {v5}',
    correctionMessage:
        'Add required constructor parameter: MyWidget({required this.service}). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when constructor has too many dependencies.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidTooManyDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_too_many_dependencies',
    '[avoid_too_many_dependencies] Constructor has >5 dependencies. Class likely violates Single Responsibility. Classes with many dependencies often violate single responsibility. Break the class into smaller, focused components. {v5}',
    correctionMessage:
        'Group related dependencies into a facade class, or split this class. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Maximum recommended number of constructor dependencies.
  static const int _maxDependencies = 5;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
        reporter.atNode(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidInternalDependencyCreationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_internal_dependency_creation',
    '[avoid_internal_dependency_creation] Dependency created internally instead of being injected. Cannot substitute mock implementations for testing. This tight coupling reduces testability and makes the component harder to reuse. {v5}',
    correctionMessage:
        'Add constructor parameter: MyClass(this._repo); then inject from outside. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
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
                reporter.atNode(initializer);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  PreferAbstractDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_abstract_dependencies',
    '[prefer_abstract_dependencies] Depends on concrete implementation. Tight coupling prevents substitution. Dependencies should depend on abstractions (interfaces/abstract classes), not concrete implementations, following the Dependency Inversion Principle. {v5}',
    correctionMessage:
        'Use abstract type: replace PostgresUserRepo with UserRepository interface. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      for (final FormalParameter param in node.parameters.parameters) {
        final String? typeName = _getParameterTypeName(param);
        if (typeName == null) continue;

        for (final String prefix in _concretePrefixes) {
          if (typeName.startsWith(prefix)) {
            reporter.atNode(param);
            break;
          }
        }

        // Also check for Impl suffix
        if (typeName.endsWith('Impl')) {
          reporter.atNode(param);
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
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v6
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
  AvoidSingletonForScopedDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_singleton_for_scoped_dependencies',
    '[avoid_singleton_for_scoped_dependencies] Scoped data as singleton. State will persist across sessions/screens. Some dependencies must be scoped to a specific lifecycle (e.g., per request, per screen) rather than being global singletons. {v6}',
    correctionMessage:
        'Use registerFactory(() => MySession()) for fresh instance per scope. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'registerSingleton') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();

      for (final String pattern in _scopedTypePatterns) {
        if (argSource.contains(pattern)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when circular dependencies are detected in DI registration.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidCircularDiDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_circular_di_dependencies',
    '[avoid_circular_di_dependencies] Potential circular dependency detected. Circular dependencies cause runtime errors or infinite loops during dependency resolution. Circular dependencies are detected in DI registration. {v5}',
    correctionMessage:
        'Refactor to break the cycle using interfaces or events. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
              reporter.atNode(param);
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
        final String classBase = className.substring(
          0,
          className.length - pattern.length,
        );
        final String depBase = dependencyType.substring(
          0,
          dependencyType.length - pattern.length,
        );

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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  PreferNullObjectPatternRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_null_object_pattern',
    '[prefer_null_object_pattern] Optional dependency (Logger, Analytics, etc.) registered as nullable type. Callers must perform null checks before every use, scattering defensive code throughout the application and increasing the risk of NullPointerExceptions. {v5}',
    correctionMessage:
        'Implement a no-op or stub version of the dependency interface and register it instead of null. This eliminates null checks at call sites while preserving the optional behavior through safe default implementation.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      final TypeAnnotation? type = node.fields.type;
      if (type == null) return;

      // Check if outer type is nullable
      if (type is! NamedType || !isOuterTypeNullable(type)) return;

      final String baseType = type.name.lexeme;
      for (final String suffix in _optionalDependencySuffixes) {
        if (baseType.endsWith(suffix)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when dependency registration lacks type safety.
///
/// Since: v4.9.0 | Updated: v4.13.0 | Rule version: v6
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
  RequireTypedDiRegistrationRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_typed_di_registration',
    '[require_typed_di_registration] Dependency injection registration lacks explicit type parameter, relying on type inference. Type inference can fail or infer incorrect types when implementations differ from interfaces, causing runtime resolution errors that could be caught at compile time. {v6}',
    correctionMessage:
        'Add explicit type parameter to the registration method (e.g., registerSingleton<UserRepository>(UserRepositoryImpl())) to document the registered type and catch mismatches early during development.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _registrationMethods = <String>{
    'registerSingleton',
    'registerLazySingleton',
    'registerFactory',
    'registerFactoryParam',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_registrationMethods.contains(methodName)) return;

      // Check for type arguments
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a function literal is passed to registerSingleton.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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
  AvoidFunctionsInRegisterSingletonRule() : super(code: _code);

  /// Potential bug. Wrong method used.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_functions_in_register_singleton',
    '[avoid_functions_in_register_singleton] registerSingleton expects an instance, not a factory function. {v3}',
    correctionMessage:
        'Use registerLazySingleton(() => ...) or registerFactory(() => ...) '
        'for lazy instantiation. Use registerSingleton(MyService()) for eager.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(firstArg);
      }
    });
  }
}

/// Warns when config access doesn't provide defaults for missing values.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v4
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
  RequireDefaultConfigRule() : super(code: _code);

  /// Missing config causes startup crashes in production.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_default_config',
    '[require_default_config] Accessing configuration values without providing a default or fallback can cause runtime crashes if the value is missing or misconfigured. This leads to unpredictable app behavior, poor user experience, and failed startup. It may also result in app store rejection for reliability issues. {v4}',
    correctionMessage:
        'Always provide a fallback value or use nullable access with a null check when reading config values. Document default values and ensure your app can start and function even if a config value is missing.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - Dependency Injection Rules
// =============================================================================

/// Warns when setter injection is used instead of constructor injection.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferConstructorInjectionRule() : super(code: _code);

  /// Code quality issue. Makes testing harder.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_constructor_injection',
    '[prefer_constructor_injection] Setter/method injection hides dependencies. Use constructor injection. Constructor injection makes dependencies explicit and ensures objects are fully initialized when created. Setter injection allows partially initialized objects and makes dependencies implicit. {v2}',
    correctionMessage:
        'Make this a final field and add a constructor parameter:. Verify the change works correctly with existing tests and add coverage for the new behavior.'
        'MyClass(this._service);',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(field);
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
          reporter.atNode(setter);
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
            reporter.atNode(method);
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
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireDiScopeAwarenessRule() : super(code: _code);

  /// Memory leaks or stale data from wrong scope.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_di_scope_awareness',
    '[require_di_scope_awareness] Review DI scope: singleton retains state, factory creates each time. Misusing DI scopes causes lifecycle bugs: - singleton: Created once, lives forever - lazySingleton: Created on first access, lives forever - factory: Created fresh each time. {v2}',
    correctionMessage:
        'Use lazySingleton for expensive objects, factory for stateless handlers. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(node);
            return;
          }
        }
      } else if (methodName == 'registerFactory') {
        // Expensive services as factory waste resources
        for (final String suffix in _expensiveSuffixes) {
          if (argSource.contains(suffix)) {
            reporter.atNode(node);
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
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v3
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
  AvoidDiInWidgetsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_di_in_widgets',
    '[avoid_di_in_widgets] GetIt.I access in widgets creates hidden dependencies that break testability and widget reuse. '
        'Direct service locator calls tightly couple widgets to the DI container, making it impossible to substitute mock dependencies in tests and preventing widget extraction to other packages. {v3}',
    correctionMessage:
        'Pass dependencies via constructor injection or use context-based lookup (e.g., context.read<T>() with Provider, or InheritedWidget). '
        'This makes dependencies explicit, enables easy mocking in widget tests, and keeps widgets reusable across different dependency configurations.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check if inside a widget class
      if (!_isInsideWidgetClass(node)) return;

      // Check for GetIt access patterns
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      final String methodName = node.methodName.name;

      // Match GetIt.I<T>(), GetIt.instance<T>(), sl<T>(), locator<T>()
      if (_isServiceLocatorCall(targetSource, methodName)) {
        reporter.atNode(node);
      }
    });

    // Also check for GetIt.I.get<T>() patterns
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!_isInsideWidgetClass(node)) return;

      final String source = node.toSource();
      if (source == 'GetIt.I' ||
          source == 'GetIt.instance' ||
          source == 'GetIt.asNewInstance') {
        reporter.atNode(node);
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
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
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
  PreferAbstractionInjectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_abstraction_injection',
    '[prefer_abstraction_injection] Injecting concrete implementation. '
        'Prefer injecting abstract types for testability. {v2}',
    correctionMessage:
        'Create an abstract class or interface and inject that instead.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
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
          reporter.atNode(param);
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
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v3
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
  PreferLazySingletonRegistrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_lazy_singleton_registration',
    '[prefer_lazy_singleton_registration] Expensive service (Database, Analytics, Cache) registered as eager singleton. The service initializes immediately at app startup, slowing down launch time and consuming resources even if the service is never used during the session. {v3}',
    correctionMessage:
        'Replace registerSingleton with registerLazySingleton(() => Service()) to defer initialization until first access. This improves app startup time and reduces memory usage when features are conditionally accessed.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _expensiveServicePattern = RegExp(
    r'(Database|Analytics|Cache|Logger|Http|Api|Network|Storage|Auth)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'registerSingleton') return;

      // Check arguments for potentially expensive services
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();

      // Check if registering a potentially expensive service
      if (_expensiveServicePattern.hasMatch(argSource)) {
        reporter.atNode(node);
      }
    });
  }
}

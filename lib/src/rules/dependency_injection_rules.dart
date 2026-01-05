// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Dependency injection lint rules for Flutter/Dart applications.
///
/// These rules help enforce proper dependency injection patterns,
/// improving testability, maintainability, and separation of concerns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
class AvoidServiceLocatorInWidgetsRule extends DartLintRule {
  const AvoidServiceLocatorInWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_service_locator_in_widgets',
    problemMessage: 'Avoid accessing service locator directly in widgets.',
    correctionMessage: 'Inject dependencies through constructor or use Provider/Riverpod.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidTooManyDependenciesRule extends DartLintRule {
  const AvoidTooManyDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_too_many_dependencies',
    problemMessage: 'Class has too many constructor dependencies.',
    correctionMessage: 'Consider splitting into smaller classes or using a facade pattern.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Maximum recommended number of constructor dependencies.
  static const int _maxDependencies = 5;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidInternalDependencyCreationRule extends DartLintRule {
  const AvoidInternalDependencyCreationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_internal_dependency_creation',
    problemMessage: 'Dependencies should be injected, not created internally.',
    correctionMessage: 'Accept the dependency as a constructor parameter instead.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check for field initializers that create dependencies
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        if (initializer is InstanceCreationExpression) {
          final String? typeName = initializer.constructorName.type.element?.name;
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
class PreferAbstractDependenciesRule extends DartLintRule {
  const PreferAbstractDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_abstract_dependencies',
    problemMessage: 'Depend on abstractions rather than concrete implementations.',
    correctionMessage: 'Use an interface or abstract class for better testability.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidSingletonForScopedDependenciesRule extends DartLintRule {
  const AvoidSingletonForScopedDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_singleton_for_scoped_dependencies',
    problemMessage: 'This dependency should be scoped, not a singleton.',
    correctionMessage: 'Use registerFactory or registerLazySingleton with proper scoping.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidCircularDiDependenciesRule extends DartLintRule {
  const AvoidCircularDiDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_circular_di_dependencies',
    problemMessage: 'Potential circular dependency detected.',
    correctionMessage: 'Refactor to break the cycle using interfaces or events.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        final String classBase = className.substring(0, className.length - pattern.length);
        final String depBase = dependencyType.substring(0, dependencyType.length - pattern.length);

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
class PreferNullObjectPatternRule extends DartLintRule {
  const PreferNullObjectPatternRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_null_object_pattern',
    problemMessage: 'Consider using null object pattern for optional dependency.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireTypedDiRegistrationRule extends DartLintRule {
  const RequireTypedDiRegistrationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_typed_di_registration',
    problemMessage: 'DI registration should have explicit type parameter.',
    correctionMessage: 'Add type parameter like registerSingleton<Type>(instance).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _registrationMethods = <String>{
    'registerSingleton',
    'registerLazySingleton',
    'registerFactory',
    'registerFactoryParam',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

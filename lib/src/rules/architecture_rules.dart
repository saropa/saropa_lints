// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Architecture lint rules for Flutter/Dart applications.
///
/// These rules help enforce clean architecture patterns and prevent
/// common architectural anti-patterns that lead to unmaintainable code.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when UI layer directly accesses data layer.
///
/// UI should go through domain/business logic layer, not directly
/// access repositories or data sources.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final UserRepository repository; // Direct data access
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final UserViewModel viewModel; // Through presentation layer
/// }
/// ```
class AvoidDirectDataAccessInUiRule extends DartLintRule {
  const AvoidDirectDataAccessInUiRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_direct_data_access_in_ui',
    problemMessage: 'UI layer should not directly access data layer.',
    correctionMessage: 'Use a ViewModel, Cubit, or Controller to mediate data access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _dataLayerPatterns = <String>{
    'Repository',
    'DataSource',
    'ApiClient',
    'DatabaseHelper',
    'Storage',
    'Cache',
    'Dao',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a UI class (Widget or State)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Widget') && !superName.contains('State')) {
        return;
      }

      // Check fields for data layer dependencies
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String pattern in _dataLayerPatterns) {
              if (typeName.contains(pattern)) {
                reporter.atNode(member, code);
                break;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when business logic is in UI layer.
///
/// Business logic should be in domain layer, not in widgets.
///
/// **BAD:**
/// ```dart
/// class CartWidget extends StatelessWidget {
///   double calculateTotal() {
///     return items.fold(0, (sum, item) =>
///       sum + item.price * item.quantity * (1 - item.discount));
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // In domain layer
/// class Cart {
///   double calculateTotal() { ... }
/// }
///
/// // In UI layer
/// class CartWidget extends StatelessWidget {
///   Widget build(context) => Text(cart.calculateTotal().toString());
/// }
/// ```
class AvoidBusinessLogicInUiRule extends DartLintRule {
  const AvoidBusinessLogicInUiRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_business_logic_in_ui',
    problemMessage: 'Business logic should not be in UI layer.',
    correctionMessage: 'Move calculations and business rules to domain/service layer.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _businessLogicIndicators = <String>{
    'calculate',
    'compute',
    'validate',
    'process',
    'transform',
    'convert',
    'parse',
    'format',
    'filter',
    'sort',
    'aggregate',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a UI class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('Widget') && !superName.contains('State')) {
        return;
      }

      // Check methods for business logic
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme.toLowerCase();

          // Skip build and lifecycle methods
          if (methodName == 'build' || methodName == 'initstate' || methodName == 'dispose') {
            continue;
          }

          for (final String indicator in _businessLogicIndicators) {
            if (methodName.contains(indicator)) {
              reporter.atNode(member, code);
              break;
            }
          }
        }
      }
    });
  }
}

/// Warns when circular dependencies are detected.
///
/// Circular dependencies make code hard to test and maintain.
///
/// **BAD:**
/// ```dart
/// // user_service.dart
/// import 'order_service.dart';
/// class UserService { OrderService orders; }
///
/// // order_service.dart
/// import 'user_service.dart';
/// class OrderService { UserService users; }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Break cycle with interfaces or event bus
/// abstract class IUserService { ... }
/// class OrderService { IUserService users; }
/// ```
class AvoidCircularDependenciesRule extends DartLintRule {
  const AvoidCircularDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_circular_dependencies',
    problemMessage: 'Potential circular dependency detected.',
    correctionMessage: 'Break the cycle using interfaces, dependency injection, or events.',
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

      // Check constructor parameters for same-package service dependencies
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          for (final FormalParameter param in member.parameters.parameters) {
            String? paramType;
            if (param is SimpleFormalParameter) {
              paramType = param.type?.toSource();
            } else if (param is DefaultFormalParameter) {
              final NormalFormalParameter normalParam = param.parameter;
              if (normalParam is SimpleFormalParameter) {
                paramType = normalParam.type?.toSource();
              }
            }

            if (paramType != null && _isSameLayerDependency(className, paramType)) {
              reporter.atNode(param, code);
            }
          }
        }
      }
    });
  }

  bool _isSameLayerDependency(String className, String dependencyType) {
    // Simple heuristic: if both end with same suffix, might be circular
    const List<String> layerSuffixes = <String>[
      'Service',
      'Repository',
      'Controller',
      'Manager',
      'Handler',
      'Provider',
    ];

    for (final String suffix in layerSuffixes) {
      if (className.endsWith(suffix) && dependencyType.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when God class is detected (too many responsibilities).
///
/// Classes with too many fields/methods violate Single Responsibility.
///
/// **BAD:**
/// ```dart
/// class AppManager {
///   // 20+ fields and 30+ methods doing everything
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserManager { ... }
/// class AuthManager { ... }
/// class CacheManager { ... }
/// ```
class AvoidGodClassRule extends DartLintRule {
  const AvoidGodClassRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_god_class',
    problemMessage: 'Class has too many responsibilities.',
    correctionMessage: 'Split into smaller classes with single responsibilities.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const int _maxFields = 15;
  static const int _maxMethods = 20;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      int fieldCount = 0;
      int methodCount = 0;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          fieldCount += member.fields.variables.length;
        } else if (member is MethodDeclaration) {
          if (!member.isGetter && !member.isSetter) {
            methodCount++;
          }
        }
      }

      if (fieldCount > _maxFields || methodCount > _maxMethods) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when presentation logic is in domain layer.
///
/// Domain layer should be UI-framework agnostic.
///
/// **BAD:**
/// ```dart
/// // In domain layer
/// class User {
///   Widget toWidget() => Text(name); // Flutter dependency
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Domain layer
/// class User { String name; }
///
/// // Presentation layer
/// class UserWidget extends StatelessWidget {
///   Widget build(context) => Text(user.name);
/// }
/// ```
class AvoidUiInDomainLayerRule extends DartLintRule {
  const AvoidUiInDomainLayerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_ui_in_domain_layer',
    problemMessage: 'Domain layer should not have UI dependencies.',
    correctionMessage: 'Remove Flutter/UI imports from domain models and services.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _uiTypes = <String>{
    'Widget',
    'BuildContext',
    'State',
    'Color',
    'TextStyle',
    'Icon',
    'Image',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if file is in domain layer (heuristic based on path)
    final String path = resolver.source.fullName;

    final bool isDomainLayer =
        path.contains('/domain/') || path.contains('/models/') || path.contains('/entities/');

    if (!isDomainLayer) return;

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Check return type
      final String? returnType = node.returnType?.toSource();
      if (returnType != null) {
        for (final String uiType in _uiTypes) {
          if (returnType.contains(uiType)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }

      // Check parameters
      for (final FormalParameter param in node.parameters?.parameters ?? <FormalParameter>[]) {
        String? paramType;
        if (param is SimpleFormalParameter) {
          paramType = param.type?.toSource();
        }
        if (paramType != null) {
          for (final String uiType in _uiTypes) {
            if (paramType.contains(uiType)) {
              reporter.atNode(param, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when feature module has external dependencies.
///
/// Features should be self-contained for better modularity.
///
/// **BAD:**
/// ```dart
/// // In features/cart/cart_screen.dart
/// import 'package:app/features/user/user_service.dart';
/// ```
///
/// **GOOD:**
/// ```dart
/// // In features/cart/cart_screen.dart
/// import 'package:app/core/services/user_service.dart';
/// // Or use dependency injection
/// ```
class AvoidCrossFeatureDependenciesRule extends DartLintRule {
  const AvoidCrossFeatureDependenciesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_cross_feature_dependencies',
    problemMessage: 'Feature module depends on another feature.',
    correctionMessage: 'Move shared code to core/shared layer or use dependency injection.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String currentPath = resolver.source.fullName;

    // Extract current feature name
    final RegExp featurePattern = RegExp(r'/features/([^/]+)/');
    final RegExpMatch? currentMatch = featurePattern.firstMatch(currentPath);
    if (currentMatch == null) return;

    final String currentFeature = currentMatch.group(1)!;

    context.registry.addImportDirective((ImportDirective node) {
      final String importPath = node.uri.stringValue ?? '';

      // Check if importing from another feature
      final RegExpMatch? importMatch = featurePattern.firstMatch(importPath);
      if (importMatch != null) {
        final String importedFeature = importMatch.group(1)!;
        if (importedFeature != currentFeature) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when singleton pattern is overused.
///
/// Singletons make testing difficult and hide dependencies.
///
/// **BAD:**
/// ```dart
/// class UserService {
///   static final UserService _instance = UserService._();
///   factory UserService() => _instance;
///   UserService._();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use dependency injection
/// class UserService {
///   UserService(this.apiClient);
///   final ApiClient apiClient;
/// }
///
/// // Register in DI container
/// getIt.registerSingleton(UserService(ApiClient()));
/// ```
class AvoidSingletonPatternRule extends DartLintRule {
  const AvoidSingletonPatternRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_singleton_pattern',
    problemMessage: 'Singleton pattern makes testing difficult.',
    correctionMessage: 'Use dependency injection container instead of static singletons.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      bool hasStaticInstance = false;
      bool hasFactoryConstructor = false;
      bool hasPrivateConstructor = false;

      for (final ClassMember member in node.members) {
        // Check for static instance field
        if (member is FieldDeclaration && member.isStatic) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName == node.name.lexeme) {
            hasStaticInstance = true;
          }
        }

        // Check for factory constructor
        if (member is ConstructorDeclaration) {
          if (member.factoryKeyword != null) {
            hasFactoryConstructor = true;
          }
          // Check for private constructor
          if (member.name?.lexeme.startsWith('_') ?? false) {
            hasPrivateConstructor = true;
          }
        }
      }

      // Singleton pattern detected
      if (hasStaticInstance && hasFactoryConstructor && hasPrivateConstructor) {
        reporter.atNode(node, code);
      }
    });
  }
}

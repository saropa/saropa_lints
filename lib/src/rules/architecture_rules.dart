// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Architecture lint rules for Flutter/Dart applications.
///
/// These rules help enforce clean architecture patterns and prevent
/// common architectural anti-patterns that lead to unmaintainable code.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

/// Warns when UI layer directly accesses data layer.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidDirectDataAccessInUiRule extends SaropaLintRule {
  AvoidDirectDataAccessInUiRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_direct_data_access_in_ui',
    '[avoid_direct_data_access_in_ui] Widget class declares a field typed as Repository, DataSource, ApiClient, or similar data-layer class, creating a direct coupling between the UI and data implementation. This bypasses the domain/business logic layer, making the widget untestable in isolation, difficult to refactor when data sources change, and prone to leaking data concerns into the presentation layer. {v5}',
    correctionMessage:
        'Inject a ViewModel, Cubit, or Controller that wraps the data layer and exposes only presentation-ready state.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
                reporter.atNode(member);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidBusinessLogicInUiRule extends SaropaLintRule {
  AvoidBusinessLogicInUiRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_business_logic_in_ui',
    '[avoid_business_logic_in_ui] Widget class contains methods named with calculation or transformation verbs (calculate, compute, validate, process, etc.), indicating business logic embedded in the UI layer. This violates separation of concerns, making the logic impossible to reuse across screens, untestable without widget infrastructure, and tightly coupled to Flutter framework classes. {v5}',
    correctionMessage:
        'Move calculations and business rules to a domain or service layer class that can be tested and reused independently.',
    severity: DiagnosticSeverity.INFO,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
          if (methodName == 'build' ||
              methodName == 'initstate' ||
              methodName == 'dispose') {
            continue;
          }

          for (final String indicator in _businessLogicIndicators) {
            if (methodName.contains(indicator)) {
              reporter.atNode(member);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidCircularDependenciesRule extends SaropaLintRule {
  AvoidCircularDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_circular_dependencies',
    '[avoid_circular_dependencies] Service class constructor depends on another service of the same architectural layer (both end with Service, Repository, Controller, etc.). This creates circular dependency chains that break initialization order, prevent unit testing with mocks, and produce tightly coupled modules that cannot be modified or deployed independently. {v5}',
    correctionMessage:
        'Extract shared logic to a new service, define interfaces for cross-service contracts, or communicate via an event bus.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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

            if (paramType != null &&
                _isSameLayerDependency(className, paramType)) {
              reporter.atNode(param);
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
/// Since: v0.1.4 | Updated: v5.0.0-beta.16 | Rule version: v6
///
/// Classes with too many fields (>15) or methods (>20) violate Single
/// Responsibility. Static const and static final fields are excluded from
/// the field count because they represent compile-time constants, not
/// instance state.
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
///
/// // Static-const namespaces are NOT flagged regardless of field count:
/// abstract final class DateConstants {
///   static const int minMonth = 1;
///   static const int maxMonth = 12;
///   // ... 15+ static const fields are fine
/// }
/// ```
class AvoidGodClassRule extends SaropaLintRule {
  AvoidGodClassRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_god_class',
    '[avoid_god_class] Class declares more than 15 fields or 20 methods, violating the Single Responsibility Principle. God classes accumulate unrelated responsibilities, making them difficult to understand, test, and maintain. Changes to one responsibility risk breaking others, and the class becomes a merge-conflict magnet as multiple developers modify it concurrently. {v6}',
    correctionMessage:
        'Extract cohesive groups of related fields and methods into focused helper or delegate classes with clear responsibilities.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const int _maxFields = 15;
  static const int _maxMethods = 20;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      int fieldCount = 0;
      int methodCount = 0;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          // Skip static const/final fields — they are compile-time or
          // lazy constants, not instance state indicating a god class.
          final bool isStaticConstant =
              member.isStatic &&
              (member.fields.isConst || member.fields.isFinal);
          if (!isStaticConstant) {
            fieldCount += member.fields.variables.length;
          }
        } else if (member is MethodDeclaration) {
          if (!member.isGetter && !member.isSetter) {
            methodCount++;
          }
        }
      }

      if (fieldCount > _maxFields || methodCount > _maxMethods) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when presentation logic is in domain layer.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidUiInDomainLayerRule extends SaropaLintRule {
  AvoidUiInDomainLayerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_ui_in_domain_layer',
    '[avoid_ui_in_domain_layer] Domain-layer file (models, entities, or domain directory) references Flutter UI types such as Widget, BuildContext, Color, or TextStyle. This couples domain logic to the Flutter framework, preventing code reuse in non-Flutter contexts (CLI tools, server-side Dart, packages), breaking testability without widget infrastructure, and violating clean architecture boundaries. {v5}',
    correctionMessage:
        'Remove Flutter/UI imports from domain models and services, and move presentation concerns to the UI layer.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check if file is in domain layer (heuristic based on path)
    final String path = context.filePath;

    final bool isDomainLayer =
        path.contains('/domain/') ||
        path.contains('/models/') ||
        path.contains('/entities/');

    if (!isDomainLayer) return;

    context.addMethodDeclaration((MethodDeclaration node) {
      // Check return type
      final String? returnType = node.returnType?.toSource();
      if (returnType != null) {
        for (final String uiType in _uiTypes) {
          if (returnType.contains(uiType)) {
            reporter.atNode(node);
            return;
          }
        }
      }

      // Check parameters
      for (final FormalParameter param
          in node.parameters?.parameters ?? <FormalParameter>[]) {
        String? paramType;
        if (param is SimpleFormalParameter) {
          paramType = param.type?.toSource();
        }
        if (paramType != null) {
          for (final String uiType in _uiTypes) {
            if (paramType.contains(uiType)) {
              reporter.atNode(param);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidCrossFeatureDependenciesRule extends SaropaLintRule {
  AvoidCrossFeatureDependenciesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_cross_feature_dependencies',
    '[avoid_cross_feature_dependencies] File inside a feature module imports from a different feature module directory, creating a direct cross-feature dependency. This breaks feature isolation, prevents independent development and testing of features, and makes it impossible to extract or remove a feature without cascading changes across the codebase. Cross-feature coupling also increases merge conflicts and deployment risks. {v5}',
    correctionMessage:
        'Move shared code to a core or shared layer, or use dependency injection to decouple features from each other.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String currentPath = context.filePath;

    // Extract current feature name
    final RegExp featurePattern = RegExp(r'/features/([^/]+)/');
    final RegExpMatch? currentMatch = featurePattern.firstMatch(currentPath);
    if (currentMatch == null) return;

    final String currentFeature = currentMatch.group(1)!;

    context.addImportDirective((ImportDirective node) {
      final String importPath = node.uri.stringValue ?? '';

      // Check if importing from another feature
      final RegExpMatch? importMatch = featurePattern.firstMatch(importPath);
      if (importMatch != null) {
        final String importedFeature = importMatch.group(1)!;
        if (importedFeature != currentFeature) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when singleton pattern is overused.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidSingletonPatternRule extends SaropaLintRule {
  AvoidSingletonPatternRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_singleton_pattern',
    '[avoid_singleton_pattern] Class uses the singleton pattern (static instance field, factory constructor, and private constructor). Singletons hide dependencies, prevent mocking in unit tests, make it impossible to run tests in parallel with isolated state, and create implicit global state that is difficult to reason about and reset between test cases. {v5}',
    correctionMessage:
        'Use a DI container (e.g., getIt.registerSingleton(MyService())) and inject the instance where needed for testability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when GestureDetector only handles touch gestures.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Desktop and web apps support secondary click (right-click) and hover.
/// Touch-only gesture handlers reduce accessibility on these platforms.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   child: ListTile(...),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   onSecondaryTap: () => showContextMenu(),
///   onLongPress: () => showContextMenu(), // Mobile fallback
///   child: ListTile(...),
/// );
/// ```
class AvoidTouchOnlyGesturesRule extends SaropaLintRule {
  AvoidTouchOnlyGesturesRule() : super(code: _code);

  /// Accessibility issue on desktop/web platforms.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_touch_only_gestures',
    '[avoid_touch_only_gestures] GestureDetector with only onTap. Missing desktop/web interactions. Desktop and web apps support secondary click (right-click) and hover. Touch-only gesture handlers reduce accessibility on these platforms. {v4}',
    correctionMessage:
        'Add onSecondaryTap for right-click context menus and onLongPress as a mobile fallback for desktop interactions.',
    severity: DiagnosticSeverity.INFO,
  );
  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'GestureDetector' && typeName != 'InkWell') {
        return;
      }

      bool hasOnTap = false;
      bool hasSecondaryOrHover = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          if (name == 'onTap' || name == 'onTapDown') {
            hasOnTap = true;
          }
          if (name == 'onSecondaryTap' ||
              name == 'onSecondaryTapDown' ||
              name == 'onHover' ||
              name == 'onLongPress') {
            hasSecondaryOrHover = true;
          }
        }
      }

      if (hasOnTap && !hasSecondaryOrHover) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Detects circular import dependencies between files.
///
/// Since: v3.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Circular imports create tight coupling between modules and can cause:
/// - Initialization order issues
/// - Difficulty testing in isolation
/// - Hard-to-follow dependency chains
///
/// This rule uses the cached import graph to efficiently detect cycles.
/// The import graph is built once and reused across all files in the project.
///
/// **BAD:**
/// ```dart
/// // file_a.dart
/// import 'file_b.dart'; // file_b imports file_a → cycle!
///
/// // file_b.dart
/// import 'file_a.dart';
/// ```
///
/// **GOOD:**
/// ```dart
/// // file_a.dart
/// import 'shared_types.dart';
///
/// // file_b.dart
/// import 'shared_types.dart';
/// // Both depend on shared module, no cycle
/// ```
class AvoidCircularImportsRule extends SaropaLintRule {
  AvoidCircularImportsRule() : super(code: _code);

  /// Architecture issue. Circular dependencies break modularity.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_circular_imports',
    '[avoid_circular_imports] Circular import detected. This file is part '
        'of an import cycle. {v2}',
    correctionMessage:
        'Extract shared types to a separate file that both modules can import, '
        'or use dependency injection to break the cycle.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get requiredPatterns => const {'import'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final filePath = context.filePath;

    // Build import graph if not already built
    // Note: In production, this would be triggered once at analysis start
    _ensureImportGraphBuilt(filePath);

    // Detect cycles involving this file
    final cycles = ImportGraphCache.detectCircularImports(filePath);

    if (cycles.isEmpty) return;

    // Report on import directives that are part of cycles
    context.addImportDirective((ImportDirective node) {
      final importUri = node.uri.stringValue;
      if (importUri == null) return;

      // Check if this import is part of any detected cycle
      for (final cycle in cycles) {
        // Resolve the import to absolute path
        final resolvedPath = _resolveImportPath(importUri, filePath);
        if (resolvedPath != null && cycle.contains(resolvedPath)) {
          // This import is part of a cycle
          reporter.atNode(
            node,
            LintCode(
              'avoid_circular_imports',
              '[avoid_circular_imports] Circular import detected: '
                  '${_formatCycle(cycle)}',
              correctionMessage:
                  'Extract shared types to break the cycle, or use dependency '
                  'injection.',
              severity: DiagnosticSeverity.WARNING,
            ),
          );
          break;
        }
      }
    });
  }

  /// Ensure the import graph is built for the project containing this file.
  void _ensureImportGraphBuilt(String filePath) {
    // Check if already built
    if (ImportGraphCache.hasFile(filePath)) return;

    // Find project root (look for pubspec.yaml)
    var dir = filePath;
    var projectRoot = '';

    // Walk up to find pubspec.yaml
    while (dir.isNotEmpty) {
      final separator = dir.contains('/') ? '/' : '\\';
      final lastSep = dir.lastIndexOf(separator);
      if (lastSep < 0) break;

      dir = dir.substring(0, lastSep);
      // Check for pubspec.yaml (simplified check)
      if (dir.endsWith('/lib') || dir.endsWith('\\lib')) {
        projectRoot = dir.substring(0, dir.length - 4);
        break;
      }
    }

    if (projectRoot.isEmpty) return;

    // Build graph synchronously (blocking but only happens once per session)
    // In practice, this would be triggered at plugin initialization
    ImportGraphCache.buildFromDirectory(projectRoot);
  }

  /// Resolve an import URI to an absolute file path.
  String? _resolveImportPath(String importUri, String fromFile) {
    // Package imports - cannot resolve without pubspec context
    if (importUri.startsWith('package:') || importUri.startsWith('dart:')) {
      return null;
    }

    // Relative import
    final separator = fromFile.contains('/') ? '/' : '\\';
    final fromDir = fromFile.substring(0, fromFile.lastIndexOf(separator));

    var resolved = '$fromDir$separator$importUri';

    // Normalize path
    resolved = resolved.replaceAll('\\', '/');
    final parts = resolved.split('/');
    final normalized = <String>[];

    for (final part in parts) {
      if (part == '..') {
        if (normalized.isNotEmpty) normalized.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        normalized.add(part);
      }
    }

    return normalized.join('/');
  }

  /// Format a cycle for display in the error message.
  String _formatCycle(List<String> cycle) {
    if (cycle.isEmpty) return '';

    // Extract just file names for readability
    final names = cycle.map((path) {
      final separator = path.contains('/') ? '/' : '\\';
      final lastSep = path.lastIndexOf(separator);
      return lastSep >= 0 ? path.substring(lastSep + 1) : path;
    }).toList();

    if (names.length <= 3) {
      return names.join(' → ');
    }

    // Truncate long cycles
    return '${names[0]} → ${names[1]} → ... → ${names.last}';
  }
}

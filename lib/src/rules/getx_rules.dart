// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// GetX state management rules for Flutter applications.
///
/// These rules detect common GetX anti-patterns, memory leaks,
/// and lifecycle management issues.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// GetX Worker and Permanent Disposal Rules
// =============================================================================

/// Warns when GetX Workers (ever, debounce, interval, once) are stored
/// in fields but not disposed in onClose().
///
/// Alias: getx_worker_dispose, getx_worker_cleanup
///
/// Workers created with ever(), once(), debounce(), and interval() return
/// Worker objects that must be stored and disposed in onClose().
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _countWorker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _countWorker = ever(count, (_) => print('changed'));
///   }
///   // Missing onClose with _countWorker.dispose()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _countWorker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _countWorker = ever(count, (_) => print('changed'));
///   }
///
///   @override
///   void onClose() {
///     _countWorker.dispose();
///     super.onClose();
///   }
/// }
/// ```
class RequireGetxWorkerDisposeRule extends SaropaLintRule {
  const RequireGetxWorkerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_getx_worker_dispose',
    problemMessage:
        '[require_getx_worker_dispose] GetX Worker field is not disposed in onClose(). This causes memory leaks.',
    correctionMessage:
        'Call worker.dispose() in onClose() before super.onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends GetxController or GetxService
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'GetxController' &&
          superName != 'GetXController' &&
          superName != 'GetxService' &&
          superName != 'FullLifeCycleController') {
        return;
      }

      // Find Worker fields
      final List<String> workerFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'Worker' ||
                  typeName == 'Worker?' ||
                  typeName.contains('List<Worker>'))) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              workerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (workerFields.isEmpty) return;

      // Find onClose method and check for dispose calls
      String? onCloseBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'onClose') {
          onCloseBody = member.body.toSource();
          break;
        }
      }

      // Report workers not disposed in onClose
      for (final String fieldName in workerFields) {
        final bool isDisposed = onCloseBody != null &&
            (onCloseBody.contains('$fieldName.dispose()') ||
                onCloseBody.contains('$fieldName?.dispose()'));

        if (!isDisposed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when Get.put(permanent: true) is used without manual cleanup.
///
/// Alias: getx_permanent_cleanup, getx_permanent_delete
///
/// Controllers registered with `permanent: true` are never automatically
/// deleted. They require explicit `Get.delete<T>()` calls to clean up.
/// This can cause memory leaks if not handled properly.
///
/// **BAD:**
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   void initState() {
///     Get.put(AuthController(), permanent: true);
///     // Never cleaned up!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   void initState() {
///     Get.put(AuthController(), permanent: true);
///   }
///
///   void logout() {
///     // Manually clean up when no longer needed
///     Get.delete<AuthController>();
///   }
/// }
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// // Document the intentional permanent registration
/// // ignore: require_getx_permanent_cleanup
/// Get.put(GlobalConfig(), permanent: true);
/// ```
class RequireGetxPermanentCleanupRule extends SaropaLintRule {
  const RequireGetxPermanentCleanupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_getx_permanent_cleanup',
    problemMessage:
        '[require_getx_permanent_cleanup] Get.put(permanent: true) bypasses automatic GetxController disposal. Without explicit Get.delete(), the GetxController remains in memory forever, causing memory leaks.',
    correctionMessage:
        'Add Get.delete<T>() when the controller is no longer needed, or document why permanent is required. Otherwise, unused controllers may accumulate and waste resources.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Get.put()
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Get') return;
      if (node.methodName.name != 'put') return;

      // Check for permanent: true argument
      bool hasPermanent = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'permanent') {
          final Expression value = arg.expression;
          if (value is BooleanLiteral && value.value == true) {
            hasPermanent = true;
            break;
          }
        }
      }

      if (!hasPermanent) return;

      // Check if there's a corresponding Get.delete<T>() in the same class
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) {
        // Top-level permanent put - warn
        reporter.atNode(node, code);
        return;
      }

      // Get the type being put
      String? controllerType;
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is! NamedExpression) {
          final String argSource = firstArg.toSource();
          // Try to extract type from constructor call
          final RegExp typePattern = RegExp(r'^(\w+)\(');
          final RegExpMatch? match = typePattern.firstMatch(argSource);
          if (match != null) {
            controllerType = match.group(1);
          }
        }
      }

      // Check if class has Get.delete() for this type
      final String classSource = enclosingClass.toSource();
      final bool hasDelete = classSource.contains('Get.delete') ||
          classSource.contains('Get.deleteAll') ||
          (controllerType != null &&
              classSource.contains('Get.delete<$controllerType>'));

      if (!hasDelete) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Get.context, Get.overlayContext, or similar is used outside widget classes.
///
/// GetX provides global access to BuildContext via Get.context and Get.overlayContext,
/// but using these outside of Widget classes (in controllers, services, or repositories)
/// is dangerous because:
/// - The context may be null or stale
/// - It breaks the widget lifecycle
/// - It makes testing difficult
/// - It creates implicit dependencies on UI state
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   void showMessage(String msg) {
///     ScaffoldMessenger.of(Get.context!).showSnackBar(
///       SnackBar(content: Text(msg)),
///     );
///   }
///
///   void navigate() {
///     Navigator.of(Get.overlayContext!).push(...);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Use GetX snackbar/dialog methods
/// class MyController extends GetxController {
///   void showMessage(String msg) {
///     Get.snackbar('Title', msg);
///   }
///
///   void navigate() {
///     Get.to(MyPage());
///   }
/// }
///
/// // Option 2: Trigger UI from widget using reactive state
/// class MyController extends GetxController {
///   final message = RxnString();
///
///   void triggerMessage(String msg) {
///     message.value = msg;
///   }
/// }
///
/// // In widget:
/// ever(controller.message, (msg) {
///   if (msg != null) showSnackBar(context, msg);
/// });
/// ```
class AvoidGetxContextOutsideWidgetRule extends SaropaLintRule {
  const AvoidGetxContextOutsideWidgetRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_getx_context_outside_widget',
    problemMessage:
        '[avoid_getx_context_outside_widget] Get.context or Get.overlayContext used outside widget class. '
        'This is unsafe and may cause crashes.',
    correctionMessage:
        'Use GetX navigation methods (Get.to, Get.snackbar, etc.) or pass context explicitly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// GetX context access patterns that should only be used in widgets
  static const Set<String> _contextProperties = <String>{
    'context',
    'overlayContext',
  };

  /// Widget base classes where Get.context is acceptable
  static const Set<String> _widgetBaseClasses = <String>{
    'StatelessWidget',
    'StatefulWidget',
    'State',
    'GetView',
    'GetWidget',
    'GetResponsiveView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      final String propertyName = node.propertyName.name;

      // Check if accessing Get.context or Get.overlayContext
      if (!_contextProperties.contains(propertyName)) return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Get') return;

      // Check if this is inside a widget class
      final ClassDeclaration? enclosingClass =
          node.thisOrAncestorOfType<ClassDeclaration>();

      if (enclosingClass == null) {
        // Top-level or function scope - not in a widget
        reporter.atNode(node, code);
        return;
      }

      // Check if the class extends a widget type
      final ExtendsClause? extendsClause = enclosingClass.extendsClause;
      if (extendsClause == null) {
        // No extends clause - not a widget
        reporter.atNode(node, code);
        return;
      }

      final String superName = extendsClause.superclass.name.lexeme;
      if (!_isWidgetClass(superName)) {
        reporter.atNode(node, code);
      }
    });

    // Also check for Get.context in prefixed identifier form
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      final String identifierName = node.identifier.name;

      // Check if accessing Get.context or Get.overlayContext
      if (!_contextProperties.contains(identifierName)) return;

      final String prefix = node.prefix.name;
      if (prefix != 'Get') return;

      // Check if this is inside a widget class
      final ClassDeclaration? enclosingClass =
          node.thisOrAncestorOfType<ClassDeclaration>();

      if (enclosingClass == null) {
        // Top-level or function scope - not in a widget
        reporter.atNode(node, code);
        return;
      }

      // Check if the class extends a widget type
      final ExtendsClause? extendsClause = enclosingClass.extendsClause;
      if (extendsClause == null) {
        // No extends clause - not a widget
        reporter.atNode(node, code);
        return;
      }

      final String superName = extendsClause.superclass.name.lexeme;
      if (!_isWidgetClass(superName)) {
        reporter.atNode(node, code);
      }
    });
  }

  /// Check if a class name represents a widget base class
  bool _isWidgetClass(String className) {
    // Check direct matches
    if (_widgetBaseClasses.contains(className)) return true;

    // Check if it's a State<T> pattern
    if (className == 'State') return true;

    // Check for custom widget base classes (common naming patterns)
    if (className.endsWith('Widget')) return true;
    if (className.endsWith('View') && className.startsWith('Get')) return true;
    if (className.endsWith('Page')) return true;
    if (className.endsWith('Screen')) return true;

    return false;
  }
}

// =============================================================================
// avoid_getx_global_navigation
// =============================================================================

/// Get.to() uses global context, hurting testability.
///
/// GetX navigation methods bypass the widget tree's context, making
/// testing and navigation state management difficult.
///
/// **BAD:**
/// ```dart
/// Get.to(NextPage());
/// Get.off(HomePage());
/// Get.toNamed('/details');
/// ```
///
/// **GOOD:**
/// ```dart
/// Navigator.of(context).push(...);
/// // Or use GoRouter, AutoRoute, etc.
/// ```
class AvoidGetxGlobalNavigationRule extends SaropaLintRule {
  const AvoidGetxGlobalNavigationRule() : super(code: _code);

  /// Testability and navigation predictability issues.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_global_navigation',
    problemMessage:
        '[avoid_getx_global_navigation] GetX global navigation (Get.to, Get.off) bypasses widget context.',
    correctionMessage:
        'Use Navigator.of(context) or a typed routing solution like GoRouter.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Navigation methods that use global context.
  static const Set<String> _globalNavMethods = <String>{
    'to',
    'toNamed',
    'off',
    'offNamed',
    'offAll',
    'offAllNamed',
    'offAndToNamed',
    'offUntil',
    'offNamedUntil',
    'back',
    'close',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_globalNavMethods.contains(methodName)) return;

      // Check if target is Get
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Get') return;

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// require_getx_binding_routes
// =============================================================================

/// GetX routes should use Bindings for dependency injection.
///
/// GetPage without a binding forces manual controller creation and
/// lifecycle management in widgets.
///
/// **BAD:**
/// ```dart
/// GetPage(
///   name: '/home',
///   page: () => HomePage(),
///   // Missing binding!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GetPage(
///   name: '/home',
///   page: () => HomePage(),
///   binding: HomeBinding(),
/// )
/// ```
class RequireGetxBindingRoutesRule extends SaropaLintRule {
  const RequireGetxBindingRoutesRule() : super(code: _code);

  /// DI and lifecycle management consistency.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_getx_binding_routes',
    problemMessage:
        '[require_getx_binding_routes] GetPage without binding parameter.',
    correctionMessage: 'Add binding: YourBinding() for proper DI lifecycle.',
    errorSeverity: DiagnosticSeverity.INFO,
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
      if (typeName != 'GetPage') return;

      // Check for binding parameter
      final ArgumentList args = node.argumentList;
      bool hasBinding = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'binding' ||
              arg.name.label.name == 'bindings') {
            hasBinding = true;
            break;
          }
        }
      }

      if (!hasBinding) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - GetX Rules
// =============================================================================

/// Warns when Get.snackbar or Get.dialog is called in GetxController.
///
/// Dialogs and snackbars in controllers can't be tested and couple
/// UI concerns with business logic. Return state/events instead.
///
/// **BAD:**
/// ```dart
/// class UserController extends GetxController {
///   Future<void> deleteUser() async {
///     await repository.deleteUser();
///     Get.snackbar('Success', 'User deleted'); // UI in controller!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserController extends GetxController {
///   final message = Rx<String?>(null);
///
///   Future<void> deleteUser() async {
///     await repository.deleteUser();
///     message.value = 'User deleted'; // Let UI react to this
///   }
/// }
/// ```
class AvoidGetxDialogSnackbarInControllerRule extends SaropaLintRule {
  const AvoidGetxDialogSnackbarInControllerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_dialog_snackbar_in_controller',
    problemMessage:
        '[avoid_getx_dialog_snackbar_in_controller] Get.snackbar/dialog in '
        'controller couples UI to business logic and prevents testing.',
    correctionMessage:
        'Use reactive state or events to trigger UI feedback instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _uiMethods = <String>{
    'snackbar',
    'dialog',
    'bottomSheet',
    'defaultDialog',
    'generalDialog',
    'rawSnackbar',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check if it's Get.snackbar, Get.dialog, etc.
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Get') return;

      final String methodName = node.methodName.name;
      if (!_uiMethods.contains(methodName)) return;

      // Check if inside a GetxController
      if (_isInsideGetxController(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideGetxController(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) {
        final ExtendsClause? extendsClause = current.extendsClause;
        if (extendsClause != null) {
          final String superName = extendsClause.superclass.name.lexeme;
          return superName == 'GetxController' ||
              superName == 'GetXController' ||
              superName == 'FullLifeCycleController' ||
              superName == 'GetxService';
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Get.put is used for controllers that might not be needed immediately.
///
/// Use Get.lazyPut for lazy initialization to improve startup performance
/// and reduce memory usage for rarely-used controllers.
///
/// **BAD:**
/// ```dart
/// void main() {
///   Get.put(SettingsController()); // Initialized immediately
///   Get.put(ProfileController());   // Even if user never visits profile
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   Get.lazyPut(() => SettingsController());
///   Get.lazyPut(() => ProfileController());
/// }
/// ```
class RequireGetxLazyPutRule extends SaropaLintRule {
  const RequireGetxLazyPutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_getx_lazy_put',
    problemMessage:
        '[require_getx_lazy_put] Consider using Get.lazyPut() for controllers '
        'that may not be needed immediately. This improves startup performance.',
    correctionMessage:
        'Use Get.lazyPut(() => Controller()) instead of Get.put(Controller()).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Get.put
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Get') return;

      if (node.methodName.name != 'put') return;

      // Check if this is in main() or a global initialization context
      if (_isInGlobalContext(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInGlobalContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionDeclaration) {
        // Check if it's main() or setup-like function
        final String name = current.name.lexeme;
        if (name == 'main' ||
            name.contains('init') ||
            name.contains('setup') ||
            name.contains('configure')) {
          return true;
        }
      }
      if (current is ClassDeclaration) {
        // Check if inside a Bindings class
        final String className = current.name.lexeme;
        if (className.contains('Binding') || className.contains('Module')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

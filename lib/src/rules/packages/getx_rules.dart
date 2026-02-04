// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// GetX state management rules for Flutter applications.
///
/// These rules detect common GetX anti-patterns, memory leaks,
/// and lifecycle management issues.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

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
        '[require_getx_worker_dispose] GetX Worker field has no corresponding dispose() call in onClose(). Without disposing the Worker, its internal stream subscription remains active after the GetxController is destroyed. This creates a memory leak where the Worker, its closure, and all captured references are retained in memory indefinitely.',
    correctionMessage:
        'Call worker.dispose() inside the onClose() method before calling super.onClose() to properly clean up the Worker stream subscription and prevent memory leaks.',
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
        '[require_getx_permanent_cleanup] Get.put(permanent: true) registers a navigation, scroll, or animation controller that will never be automatically deleted. This can cause memory leaks if you do not manually clean up. Instances registered as permanent remain in memory for the lifetime of the app unless explicitly deleted. This is especially risky for feature-specific or page-scoped controllers that may not always be needed.',
    correctionMessage:
        'Always call Get.delete<T>() when the navigation, animation, or page controller is no longer needed, such as during logout or app shutdown. If the instance must remain for the entire app lifetime, document the reason with a code comment or ignore. Avoid using permanent: true for feature-specific controllers unless absolutely necessary.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance - extracts type from constructor call
  static final RegExp _typePattern = RegExp(r'^(\w+)\(');

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
          final RegExpMatch? match = _typePattern.firstMatch(argSource);
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

// =============================================================================
// GETX RULES (from state_management_rules.dart)
// =============================================================================

/// Warns when Get.find() is used inside build() method.
///
/// Get.find() in build() fetches the controller on every rebuild. If the
/// controller doesn't exist, it throws an error. Use GetBuilder or Obx
/// for reactive updates instead.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final controller = Get.find<MyController>(); // Called on every rebuild
///   return Text(controller.value.toString());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return GetBuilder<MyController>(
///     builder: (controller) => Text(controller.value.toString()),
///   );
/// }
/// // Or with Obx:
/// Widget build(BuildContext context) {
///   return Obx(() => Text(controller.value.toString()));
/// }
/// ```
class AvoidGetFindInBuildRule extends SaropaLintRule {
  const AvoidGetFindInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: avoid_get_find_in_build_method
  static const LintCode _code = LintCode(
    name: 'avoid_get_find_in_build',
    problemMessage:
        '[avoid_get_find_in_build] Calling Get.find() inside the build method is inefficient and can cause unnecessary object creation and performance issues. This leads to wasted memory allocations on every rebuild and makes your app less responsive.',
    correctionMessage:
        'Use GetBuilder<T> or Obx for reactive updates with GetX, and avoid calling Get.find() in build() to improve performance.',
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

      node.body.visitChildren(_GetFindVisitor(reporter, code));
    });
  }
}

class _GetFindVisitor extends RecursiveAstVisitor<void> {
  _GetFindVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName != 'find') {
      super.visitMethodInvocation(node);
      return;
    }

    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'Get') {
      reporter.atNode(node, code);
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when GetX controller doesn't call dispose on resources.
///
/// GetxController.onClose() must dispose controllers, streams, and
/// subscriptions to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///   late StreamSubscription sub;
///
///   @override
///   void onInit() {
///     sub = stream.listen((_) {});
///     super.onInit();
///   }
///   // Missing onClose! Memory leak.
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///   late StreamSubscription sub;
///
///   @override
///   void onClose() {
///     textController.dispose();
///     sub.cancel();
///     super.onClose();
///   }
/// }
/// ```
class RequireGetxControllerDisposeRule extends SaropaLintRule {
  const RequireGetxControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_getx_controller_dispose',
    problemMessage:
        '[require_getx_controller_dispose] GetxController holds TextEditingController or StreamSubscription fields but does not override onClose() to dispose them. Undisposed controllers and subscriptions leak native resources and continue processing events after the screen is removed, causing crashes.',
    correctionMessage:
        'Override onClose() to dispose TextEditingController, ScrollController, and cancel StreamSubscription fields before calling super.onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'StreamSubscription',
    'StreamController',
    'FocusNode',
    'Timer',
  };

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
      if (superName != 'GetxController' &&
          superName != 'GetXController' &&
          superName != 'FullLifeCycleController') {
        return;
      }

      bool hasDisposable = false;
      bool hasOnClose = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposable in _disposableTypes) {
              if (typeName.contains(disposable)) {
                hasDisposable = true;
                break;
              }
            }
          }
        }

        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'onClose') {
            hasOnClose = true;
          }
        }
      }

      if (hasDisposable && !hasOnClose) {
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddOnCloseFix()];
}

/// Quick fix that adds an onClose() method skeleton to a GetxController.
class _AddOnCloseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.name.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add onClose() method',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find position to insert (before closing brace)
        final int insertOffset = node.rightBracket.offset;

        builder.addSimpleInsertion(
          insertOffset,
          '\n\n  @override\n  void onClose() {\n    // HACK: Dispose resources here\n    super.onClose();\n  }\n',
        );
      });
    });
  }
}

/// Warns when .obs is used outside a GetxController.
///
/// Observable (.obs) should be encapsulated in GetxController for proper
/// lifecycle management. Using .obs in widgets causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final count = 0.obs; // Reactive variable outside controller!
///
///   Widget build(context) => Obx(() => Text('${count.value}'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final count = 0.obs;
///   void increment() => count.value++;
/// }
///
/// class MyWidget extends StatelessWidget {
///   final controller = Get.find<MyController>();
///
///   Widget build(context) => Obx(() => Text('${controller.count.value}'));
/// }
/// ```
class AvoidObsOutsideControllerRule extends SaropaLintRule {
  const AvoidObsOutsideControllerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_obs_outside_controller',
    problemMessage:
        '[avoid_obs_outside_controller] .obs used outside a Getx stream controller (GetxController or GetxService) creates observables without proper lifecycle management. These observables cause memory leaks because they are never disposed when the widget tree rebuilds.',
    correctionMessage:
        'Move observable state into a GetxController or GetxService, where onClose() automatically disposes Rx stream subscriptions and prevents memory leaks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// GetX controller class names that are allowed to use .obs
  static const Set<String> _getxControllerTypes = <String>{
    'GetxController',
    'GetXController',
    'FullLifeCycleController',
    'SuperController',
    'GetxService',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for .obs in field declarations (most common case)
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final ClassDeclaration? classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      // Check if this class extends a GetX controller type
      if (_isGetxController(classDecl)) return;

      // Check for .obs in field initializer
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? init = variable.initializer;
        if (init != null && init.toSource().endsWith('.obs')) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  /// Returns true if the class extends a known GetX controller type.
  bool _isGetxController(ClassDeclaration classDecl) {
    final ExtendsClause? extendsClause = classDecl.extendsClause;
    if (extendsClause == null) return false;

    final String superName = extendsClause.superclass.name.lexeme;
    return _getxControllerTypes.contains(superName);
  }
}

/// Warns when GetxController overrides `onInit` or `onClose` without calling super.
///
/// Not calling the super method in lifecycle overrides can break the
/// controller's internal state management and cause unexpected behavior.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     // Missing super.onInit()!
///     loadData();
///   }
///
///   @override
///   void onClose() {
///     // Missing super.onClose()!
///     cleanup();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     super.onInit();
///     loadData();
///   }
///
///   @override
///   void onClose() {
///     cleanup();
///     super.onClose();
///   }
/// }
/// ```
class ProperGetxSuperCallsRule extends SaropaLintRule {
  const ProperGetxSuperCallsRule() : super(code: _code);

  /// Critical - broken lifecycle management.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'proper_getx_super_calls',
    problemMessage:
        '[proper_getx_super_calls] Omitting a call to super in GetxController lifecycle methods (onInit, onReady, onClose) breaks the controller lifecycle, causing incomplete initialization, missed cleanup, and unpredictable behavior. This can lead to memory leaks, resource retention, and subtle bugs that are hard to diagnose.',
    correctionMessage:
        'Always call the corresponding super method (e.g., super.onInit(), super.onClose()) in GetxController lifecycle overrides. Place super.onInit() at the start and super.onClose() at the end to ensure proper initialization and cleanup.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'onInit',
    'onReady',
    'onClose',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      if (!_lifecycleMethods.contains(methodName)) return;

      // Check if this method has @override annotation
      bool hasOverride = false;
      for (final Annotation annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          hasOverride = true;
          break;
        }
      }

      if (!hasOverride) return;

      // Check if method body contains super call
      final FunctionBody body = node.body;
      if (body is EmptyFunctionBody) return;

      final _SuperCallVisitor visitor = _SuperCallVisitor(methodName);
      body.accept(visitor);

      if (!visitor.hasSuperCall) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _SuperCallVisitor extends RecursiveAstVisitor<void> {
  _SuperCallVisitor(this.methodName);

  final String methodName;
  bool hasSuperCall = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == methodName) {
      hasSuperCall = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when GetX reactive workers are created without cleanup.
///
/// Workers like `ever()`, `once()`, `debounce()`, and `interval()` create
/// subscriptions that must be cancelled in `onClose()` to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   @override
///   void onInit() {
///     super.onInit();
///     ever(count, (_) => print('changed'));  // No cleanup!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///
///   @override
///   void onClose() {
///     _worker.dispose();
///     super.onClose();
///   }
/// }
/// ```
class AlwaysRemoveGetxListenerRule extends SaropaLintRule {
  const AlwaysRemoveGetxListenerRule() : super(code: _code);

  /// High impact - memory leak prevention.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'always_remove_getx_listener',
    problemMessage:
        '[always_remove_getx_listener] GetX worker is not assigned to a variable for cleanup. '
        'This will cause a memory leak.',
    correctionMessage:
        'Assign the worker to a variable and call dispose() in onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _workerMethods = <String>{
    'ever',
    'once',
    'debounce',
    'interval',
    'everAll',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_workerMethods.contains(methodName)) return;

      // Check if this is a statement by itself (not assigned to variable)
      final AstNode? parent = node.parent;
      if (parent is ExpressionStatement) {
        // Not assigned - potential leak
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when .obs is used inside build() method.
///
/// Creating reactive variables in build() causes memory leaks and
/// unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final count = 0.obs; // Creates new Rx every rebuild!
///   return Obx(() => Text('$count'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final count = 0.obs;
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Obx(() => Text('${controller.count}'));
/// }
/// ```
class AvoidGetxRxInsideBuildRule extends SaropaLintRule {
  const AvoidGetxRxInsideBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_rx_inside_build',
    problemMessage:
        '[avoid_getx_rx_inside_build] Creating .obs reactive variables inside build() allocates a new Rx instance on every rebuild. Each instance leaks because it is never disposed, and the widget observes a fresh variable each time, losing all previous state and accumulating orphaned subscriptions.',
    correctionMessage:
        'Move reactive .obs variables into a GetxController and access them via GetBuilder or Obx to preserve state across rebuilds.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Visit method body for .obs usage
      node.body.visitChildren(_ObsVisitor(reporter, code));
    });
  }
}

class _ObsVisitor extends RecursiveAstVisitor<void> {
  _ObsVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'obs') {
      reporter.atNode(node, code);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'obs') {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// Warns when Rx variables are reassigned instead of updated.
///
/// Reassigning Rx variables breaks the reactive chain.
///
/// **BAD:**
/// ```dart
/// count = 5.obs; // Breaks reactivity!
/// ```
///
/// **GOOD:**
/// ```dart
/// count.value = 5; // Properly updates value
/// count(5); // Or use callable syntax
/// ```
class AvoidMutableRxVariablesRule extends SaropaLintRule {
  const AvoidMutableRxVariablesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_mutable_rx_variables',
    problemMessage:
        '[avoid_mutable_rx_variables] Reassigning an Rx variable with = replaces the entire reactive wrapper, breaking all existing Obx listeners that still reference the old instance. The build method stops receiving updates because child widgets observe a stale object, leading to a frozen interface that appears unresponsive.',
    correctionMessage:
        'Use .value = or callable syntax to update the Rx variable without replacing the reactive wrapper that Obx listeners depend on.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check if right side is .obs call
      final Expression right = node.rightHandSide;
      if (right is PropertyAccess && right.propertyName.name == 'obs') {
        reporter.atNode(node, code);
      }
      if (right is PrefixedIdentifier && right.identifier.name == 'obs') {
        reporter.atNode(node, code);
      }
      // Check for direct Rx constructor
      if (right is InstanceCreationExpression) {
        final String? typeName = right.constructorName.type.element?.name;
        if (typeName != null && _rxTypes.contains(typeName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  static const Set<String> _rxTypes = <String>{
    'Rx',
    'RxInt',
    'RxDouble',
    'RxString',
    'RxBool',
    'RxList',
    'RxMap',
    'RxSet',
  };
}

/// Warns when GetxController has Worker fields that are not disposed.
///
/// Workers created with ever(), once(), debounce(), etc. must be stored
/// and disposed in onClose() to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///   // Missing onClose with _worker.dispose()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   late Worker _worker;
///
///   @override
///   void onInit() {
///     super.onInit();
///     _worker = ever(count, (_) => print('changed'));
///   }
///
///   @override
///   void onClose() {
///     _worker.dispose();
///     super.onClose();
///   }
/// }
/// ```
class DisposeGetxFieldsRule extends SaropaLintRule {
  const DisposeGetxFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'dispose_getx_fields',
    problemMessage:
        '[dispose_getx_fields] Undisposed Worker keeps timer running after '
        'GetxController closes, causing memory leaks and stale updates.',
    correctionMessage: 'Call dispose() on Worker fields in onClose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends GetxController
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'GetxController' && superName != 'GetxService') return;

      // Find Worker fields
      final List<String> workerFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName == 'Worker' || typeName == 'Worker?') {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              workerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (workerFields.isEmpty) return;

      // Check if onClose exists and disposes all workers
      bool hasOnClose = false;
      final Set<String> disposedFields = <String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'onClose') {
          hasOnClose = true;
          // Check for dispose calls
          member.body.visitChildren(_DisposeVisitor(
            onDispose: (String fieldName) {
              disposedFields.add(fieldName);
            },
          ));
        }
      }

      // Report if no onClose or missing dispose calls
      if (!hasOnClose && workerFields.isNotEmpty) {
        reporter.atNode(node, code);
      } else {
        for (final String field in workerFields) {
          if (!disposedFields.contains(field)) {
            reporter.atNode(node, code);
            break;
          }
        }
      }
    });
  }
}

class _DisposeVisitor extends RecursiveAstVisitor<void> {
  _DisposeVisitor({required this.onDispose});

  final void Function(String) onDispose;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        onDispose(target.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when .obs property is accessed without Obx wrapper.
///
/// GetX reactive variables (.obs) must be inside Obx/GetX builder
/// to trigger rebuilds. Direct access won't update the UI.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   return Text(controller.count.value.toString());  // No rebuild!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(context) {
///   return Obx(() => Text(controller.count.value.toString()));
/// }
/// ```
class PreferGetxBuilderRule extends SaropaLintRule {
  const PreferGetxBuilderRule() : super(code: _code);

  /// Accessing .obs without Obx won't trigger UI rebuilds.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_getx_builder',
    problemMessage:
        '[prefer_getx_builder] .obs value accessed without Obx wrapper. UI won\'t rebuild.',
    correctionMessage: 'Wrap in Obx(() => ...) to enable reactive updates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'value') return;

      // Check if target ends with .obs pattern
      final Expression target = node.target!;
      final String targetSource = target.toSource();
      if (!targetSource.contains('.obs') &&
          !targetSource.contains('Rx') &&
          !targetSource.contains('rx')) {
        return;
      }

      // Check if inside build method but NOT inside Obx
      bool insideBuild = false;
      bool insideObx = false;

      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          insideBuild = true;
        }
        if (current is MethodInvocation) {
          final String methodName = current.methodName.name;
          if (methodName == 'Obx' ||
              methodName == 'GetX' ||
              methodName == 'GetBuilder') {
            insideObx = true;
          }
        }
        if (current is InstanceCreationExpression) {
          final String typeName = current.constructorName.type.name.lexeme;
          if (typeName == 'Obx' ||
              typeName == 'GetX' ||
              typeName == 'GetBuilder') {
            insideObx = true;
          }
        }
        current = current.parent;
      }

      if (insideBuild && !insideObx) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when GetxController is used without proper Binding registration.
///
/// GetX controllers should be registered via Bindings for proper
/// lifecycle management and dependency injection.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   // Used directly without binding
/// }
///
/// // In widget:
/// final controller = Get.put(MyController());
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyBinding extends Bindings {
///   @override
///   void dependencies() {
///     Get.lazyPut(() => MyController());
///   }
/// }
///
/// // In route:
/// GetPage(name: '/my', page: () => MyPage(), binding: MyBinding());
/// ```
class RequireGetxBindingRule extends SaropaLintRule {
  const RequireGetxBindingRule() : super(code: _code);

  /// Architecture issue - improper dependency management.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_getx_binding',
    problemMessage:
        '[require_getx_binding] Get.put() in widget. Consider using Bindings for lifecycle management.',
    correctionMessage:
        'Create a Binding class and register via GetPage binding parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Get.put() or Get.find()
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Get') return;

      if (node.methodName.name != 'put') return;

      // Check if inside a widget build method
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

/// Warns when GetX global state is used instead of reactive state.
///
/// Alias: getx_global, getx_reactive, avoid_get_put
///
/// Using Get.put() for global state makes testing difficult and
/// creates implicit dependencies. Prefer reactive state with GetBuilder.
///
/// **BAD:**
/// ```dart
/// void main() {
///   Get.put(UserController()); // Global state
///   runApp(MyApp());
/// }
///
/// class MyWidget extends StatelessWidget {
///   final ctrl = Get.find<UserController>(); // Implicit dependency
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   Widget build(BuildContext context) {
///     return GetBuilder<UserController>(
///       init: UserController(),
///       builder: (controller) => Text(controller.userName),
///     );
///   }
/// }
/// ```
class AvoidGetxGlobalStateRule extends SaropaLintRule {
  const AvoidGetxGlobalStateRule() : super(code: _code);

  /// Testing difficulty.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_getx_global_state',
    problemMessage:
        '[avoid_getx_global_state] Global GetX state (Get.put/Get.find) makes testing difficult.',
    correctionMessage:
        'Use GetBuilder with init: parameter, or inject controller via constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;

      // Check for Get.put() and Get.find()
      if (methodName != 'put' && methodName != 'find') return;

      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Get') return;

      // Check if this is at top level (main) or in a field initializer
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionDeclaration && current.name.lexeme == 'main') {
          reporter.atNode(node, code);
          return;
        }
        if (current is FieldDeclaration) {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
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
        '[avoid_tight_coupling_with_getx] Class with 5+ GetX usages becomes tightly coupled and difficult to unit test.',
    correctionMessage:
        'Use direct dependency injection for core logic. Reserve GetX for UI bindings.',
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

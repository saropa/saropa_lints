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

import '../saropa_lint_rule.dart';

/// Warns when GetxController has disposable resources without onClose().
///
/// Alias: getx_dispose, getx_onclose
///
/// GetxController subclasses with TextEditingController, StreamSubscription,
/// etc. must override onClose() to dispose them.
///
/// **BAD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///   // No onClose()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController extends GetxController {
///   final textController = TextEditingController();
///
///   @override
///   void onClose() {
///     textController.dispose();
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
        '[require_getx_controller_dispose] Missing onClose() leaves resources '
        'undisposed. Subscriptions and controllers leak memory when widget closes.',
    correctionMessage:
        'Override onClose() to dispose controllers, cancel subscriptions, etc.',
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
/// Alias: obs_in_widget, getx_state_leak
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
        '[avoid_obs_outside_controller] .obs used outside GetxController causes memory leaks and lifecycle issues.',
    correctionMessage:
        'Move observable state to a GetxController for proper lifecycle management.',
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

/// Warns when GetxController lifecycle methods don't call super.
///
/// Alias: getx_super_call, getx_lifecycle
///
/// GetxController lifecycle methods (onInit, onReady, onClose) must call
/// their super methods for proper lifecycle management.
///
/// **BAD:**
/// ```dart
/// @override
/// void onInit() {
///   loadData();  // Missing super.onInit()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void onInit() {
///   super.onInit();
///   loadData();
/// }
///
/// @override
/// void onClose() {
///   cleanup();
///   super.onClose();
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
        '[proper_getx_super_calls] GetxController lifecycle method must call super. '
        'Missing super call breaks controller lifecycle.',
    correctionMessage:
        'Add super.onInit() at the start or super.onClose() at the end.',
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
/// Alias: getx_worker_leak, getx_worker_dispose
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

/// Warns when .obs is created inside build() method.
///
/// Alias: obs_in_build, getx_build_leak
///
/// Creating .obs in build() causes memory leaks and unexpected behavior
/// because build() is called repeatedly.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   final count = 0.obs;  // Creates new observable every rebuild!
///   return Obx(() => Text('${count.value}'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final MyController controller = Get.find();
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
        '[avoid_getx_rx_inside_build] Creating .obs in build() causes memory leaks.',
    correctionMessage: 'Move reactive variables to a GetxController.',
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
/// Alias: rx_reassign, getx_reactivity_break
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
        '[avoid_mutable_rx_variables] Reassigning Rx variable breaks reactivity.',
    correctionMessage: 'Use .value = or callable syntax to update.',
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
/// Alias: getx_worker_field_dispose, worker_leak
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
/// Alias: obs_without_obx, getx_no_rebuild
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
      final Expression? target = node.target;
      if (target == null) return;
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

/// Warns when Get.put() is used in build method instead of Bindings.
///
/// Alias: getx_binding, getx_put_in_build
///
/// Using Get.put() in build method is discouraged. Use Bindings for
/// proper dependency injection and lifecycle management.
///
/// **BAD:**
/// ```dart
/// Widget build(context) {
///   Get.put(MyController());  // Wrong place!
///   return MyWidget();
/// }
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
        '[require_getx_permanent_cleanup] Get.put(permanent: true) requires manual Get.delete() call for cleanup. Consequence: Not cleaning up permanent controllers can cause memory leaks and unexpected behavior.',
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

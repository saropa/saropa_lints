// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// awesome_notifications package lint rules.
///
/// Covers seven correctness and best-practice checks for the
/// `awesome_notifications` Flutter plugin:
///   - Non-static handler passed to setListeners() → runtime error.
///   - Handler with wrong first-parameter type → runtime cast failure.
///   - Static handler missing @pragma('vm:entry-point') → tree-shaken in release.
///   - NotificationContent(channelKey:) value absent from initialize() channels
///     → notification silently discarded.
///   - createNotification() with no prior isNotificationAllowed() await → silent
///     OS drop on Android 13+ / iOS.
///   - NotificationContent(id: <negative>) → ID silently randomized by plugin,
///     cancel(id) ineffective. Provides a quick fix.
///   - createNotification() / requestPermissionToSendNotifications() invoked
///     before setListeners() in the same block → events delivered to no handler.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// Named arguments accepted by `AwesomeNotifications().setListeners(...)`.
const Set<String> _listenerArgNames = {
  'onActionReceivedMethod',
  'onNotificationCreatedMethod',
  'onNotificationDisplayedMethod',
  'onDismissActionReceivedMethod',
};

/// Listener arg names whose handler receives a `ReceivedAction` (action/dismiss).
const Set<String> _actionArgNames = {
  'onActionReceivedMethod',
  'onDismissActionReceivedMethod',
};

/// Returns the [CompilationUnit] ancestor of [node], or null if unreachable.
CompilationUnit? _compilationUnit(AstNode node) {
  AstNode? current = node;
  while (current != null && current is! CompilationUnit) {
    current = current.parent;
  }
  return current is CompilationUnit ? current : null;
}

/// True when [node]'s file imports `package:awesome_notifications/`.
bool _importsAwesome(AstNode node) =>
    fileImportsPackage(node, PackageImports.awesomeNotifications);

/// True when [path] looks like a test file (ends in `_test.dart` or lives
/// under a `/test/` directory segment). Used to suppress false positives in
/// test code where permission checks are typically mocked.
bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

/// Returns true when [target] looks like an `AwesomeNotifications()` receiver
/// (syntactic name match only — avoids requiring full type resolution).
bool _isAwesomeReceiver(Expression? target) {
  if (target == null) return false;
  final src = target.toSource();
  return src.contains('AwesomeNotifications');
}

/// Walks up to the nearest [BlockFunctionBody] that is also the body of a
/// [FunctionDeclaration] or [MethodDeclaration].  Returns null if not found.
BlockFunctionBody? _enclosingBlock(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is BlockFunctionBody) {
      final parent = current.parent;
      if (parent is FunctionExpression || parent is MethodDeclaration) {
        return current;
      }
    }
    current = current.parent;
  }
  return null;
}

// =============================================================================
// awesome_notifications_non_static_listener
// =============================================================================

/// Flags an instance (non-static) method passed as a `setListeners` handler.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `AwesomeNotifications().setListeners(...)` requires all handler arguments to
/// be either top-level functions or **static** class methods. When an instance
/// method is passed, the package logs a runtime error at the first notification
/// event: `"[Awesome Notifications - ERROR]: onActionNotificationMethod is not
/// a valid global or static method."` Because this is a log message rather than
/// an exception, it is silently swallowed in release mode and the handler never
/// runs. Background notifications are lost with no visible failure.
///
/// **BAD:**
/// ```dart
/// AwesomeNotifications().setListeners(
///   onActionReceivedMethod: _handleAction, // instance method — WRONG
/// );
/// Future<void> _handleAction(ReceivedAction action) async {}
/// ```
///
/// **GOOD:**
/// ```dart
/// AwesomeNotifications().setListeners(
///   onActionReceivedMethod: MyHandler.handleAction, // static — correct
/// );
/// @pragma('vm:entry-point')
/// static Future<void> handleAction(ReceivedAction action) async {}
/// ```
class AwesomeNotificationsNonStaticListenerRule extends SaropaLintRule {
  AwesomeNotificationsNonStaticListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_non_static_listener',
    '[awesome_notifications_non_static_listener] An instance (non-static) method'
        ' is passed as a setListeners handler argument. The awesome_notifications'
        ' package requires all handler arguments to be static class methods or'
        ' top-level functions. Passing an instance method causes a runtime log'
        ' error ("is not a valid global or static method") and the handler never'
        ' runs — background notifications are silently lost. {v1}',
    correctionMessage:
        'Make the handler method static (and add @pragma(\'vm:entry-point\')'
        ' to prevent tree-shaking in release builds), or convert it to a'
        ' top-level function.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setListeners') return;
      if (!_importsAwesome(node)) return;
      if (!_isAwesomeReceiver(node.target)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (!_listenerArgNames.contains(arg.name.label.name)) continue;

        final expr = arg.expression;
        // Resolve the expression to the MethodDeclaration it refers to.
        final method = _resolveToMethod(expr, node);
        if (method == null) continue;

        // Top-level functions (parent is CompilationUnit) are always valid.
        if (method.parent is! ClassDeclaration) continue;

        // Instance (non-static) methods are the violation.
        if (!method.isStatic) {
          reporter.atNode(expr);
        }
      }
    });
  }
}

// =============================================================================
// awesome_notifications_handler_wrong_parameter_type
// =============================================================================

/// Flags a `setListeners` handler whose first parameter type is wrong.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `setListeners` uses:
///   `typedef ActionHandler = Future<void> Function(ReceivedAction)`
///   for `onActionReceivedMethod` / `onDismissActionReceivedMethod`, and
///   `typedef NotificationHandler = Future<void> Function(ReceivedNotification)`
///   for `onNotificationCreatedMethod` / `onNotificationDisplayedMethod`.
///
/// Passing a handler whose first parameter is the wrong concrete type
/// (e.g. `ReceivedNotification` to an action slot) compiles but throws a
/// cast exception at runtime when the handler is invoked.
///
/// **BAD:**
/// ```dart
/// // onActionReceivedMethod expects ReceivedAction, not ReceivedNotification
/// AwesomeNotifications().setListeners(
///   onActionReceivedMethod: _wrongType,
/// );
/// static Future<void> _wrongType(ReceivedNotification n) async {}
/// ```
///
/// **GOOD:**
/// ```dart
/// AwesomeNotifications().setListeners(
///   onActionReceivedMethod: _handleAction,
/// );
/// static Future<void> _handleAction(ReceivedAction action) async {}
/// ```
class AwesomeNotificationsHandlerWrongParameterTypeRule extends SaropaLintRule {
  AwesomeNotificationsHandlerWrongParameterTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_handler_wrong_parameter_type',
    '[awesome_notifications_handler_wrong_parameter_type] A setListeners handler'
        ' has the wrong first-parameter type. The awesome_notifications package'
        ' defines ActionHandler as Future<void> Function(ReceivedAction) for'
        ' onActionReceivedMethod/onDismissActionReceivedMethod, and'
        ' NotificationHandler as Future<void> Function(ReceivedNotification) for'
        ' onNotificationCreatedMethod/onNotificationDisplayedMethod. A mismatch'
        ' compiles without error but throws a cast exception at runtime when the'
        ' handler fires, silently killing background notification delivery. {v1}',
    correctionMessage:
        'Change the first parameter type to ReceivedAction (for action/dismiss'
        ' handlers) or ReceivedNotification (for created/displayed handlers),'
        ' both from package:awesome_notifications/awesome_notifications.dart.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setListeners') return;
      if (!_importsAwesome(node)) return;
      if (!_isAwesomeReceiver(node.target)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final argName = arg.name.label.name;
        if (!_listenerArgNames.contains(argName)) continue;

        final method = _resolveToMethod(arg.expression, node);
        if (method == null) continue;

        final params = method.parameters?.parameters;
        if (params == null || params.isEmpty) continue;

        final firstParam = params.first;
        final typeName = _paramTypeName(firstParam);
        // Skip when type is unresolvable (dynamic / omitted / complex).
        if (typeName == null) continue;

        // For action/dismiss slots the first param must be ReceivedAction.
        // For created/displayed slots it must be ReceivedNotification.
        final bool isActionSlot = _actionArgNames.contains(argName);
        final String expectedType = isActionSlot
            ? 'ReceivedAction'
            : 'ReceivedNotification';
        final String wrongType = isActionSlot
            ? 'ReceivedNotification'
            : 'ReceivedAction';

        // Only flag when the type is concretely the wrong awesome type.
        // Skip 'dynamic', base types, or anything else — those are a
        // separate concern and skipping avoids false positives.
        if (typeName == wrongType) {
          reporter.atNode(arg.expression);
        }
      }
    });
  }
}

// =============================================================================
// awesome_notifications_missing_pragma_annotation
// =============================================================================

/// Flags a static handler in a class that lacks `@pragma('vm:entry-point')`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The AOT tree-shaker removes Dart symbols that are not reachable through the
/// normal call graph unless preserved by `@pragma('vm:entry-point')`. A static
/// handler that compiles and works in debug mode (tree-shaking disabled) is
/// silently dropped in profile/release, causing background notifications to be
/// received with no Dart handler executing. The awesome_notifications README
/// explicitly documents this annotation requirement for all static handlers.
///
/// Top-level functions do NOT require this annotation (they are implicitly
/// preserved). Only static class methods are checked.
///
/// **BAD:**
/// ```dart
/// class MyHandler {
///   // Missing @pragma('vm:entry-point') — tree-shaken in release builds.
///   static Future<void> onAction(ReceivedAction action) async {}
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyHandler {
///   @pragma('vm:entry-point')
///   static Future<void> onAction(ReceivedAction action) async {}
/// }
/// ```
class AwesomeNotificationsMissingPragmaAnnotationRule extends SaropaLintRule {
  AwesomeNotificationsMissingPragmaAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_missing_pragma_annotation',
    '[awesome_notifications_missing_pragma_annotation] A static class method is'
        ' passed as a setListeners handler but lacks @pragma(\'vm:entry-point\').'
        ' The Dart AOT tree-shaker removes this method in profile/release builds'
        ' because it is not reachable through the normal call graph. Without the'
        ' annotation, background notifications are received by the native layer'
        ' but no Dart handler executes — the failure is silent in release mode.'
        ' The awesome_notifications README explicitly requires this annotation for'
        ' all static handlers. {v1}',
    correctionMessage:
        'Add @pragma(\'vm:entry-point\') on the line immediately before the'
        ' static handler method declaration to prevent the tree-shaker from'
        ' removing it in release builds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setListeners') return;
      if (!_importsAwesome(node)) return;
      if (!_isAwesomeReceiver(node.target)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (!_listenerArgNames.contains(arg.name.label.name)) continue;

        final method = _resolveToMethod(arg.expression, node);
        if (method == null) continue;

        // Top-level functions (not inside a ClassDeclaration) are exempt.
        if (method.parent is! ClassDeclaration) continue;

        // Non-static instance methods are a different rule; skip here to
        // avoid double-reporting when both rules are active.
        if (!method.isStatic) continue;

        // Check annotations for @pragma('vm:entry-point').
        if (!_hasPragmaEntryPoint(method)) {
          reporter.atNode(arg.expression);
        }
      }
    });
  }
}

// =============================================================================
// awesome_notifications_undeclared_channel_key
// =============================================================================

/// Flags a `NotificationContent(channelKey:)` whose value was not declared in
/// the same file's `initialize()` channel list.
///
/// Since: v4.17.0 | Rule version: v1
///
/// Notifications sent to a channel not declared in `AwesomeNotifications`
/// `.initialize(...)` are silently discarded — no exception, no log in release
/// mode. This is confirmed in GitHub issue #482 and the official docs: "If you
/// create a notification using an invalid channel key, the notification will be
/// discarded." Only literal-to-literal comparisons are performed; if any channel
/// key in `initialize()` is non-literal the rule bails out to avoid false
/// positives.
///
/// **BAD:**
/// ```dart
/// // initialize() declares 'alerts', but createNotification uses 'basic'
/// await AwesomeNotifications().initialize(null, [
///   NotificationChannel(channelKey: 'alerts', channelName: 'Alerts', ...),
/// ]);
/// await AwesomeNotifications().createNotification(
///   content: NotificationContent(channelKey: 'basic', ...),  // LINT
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// await AwesomeNotifications().createNotification(
///   content: NotificationContent(channelKey: 'alerts', ...),
/// );
/// ```
class AwesomeNotificationsUndeclaredChannelKeyRule extends SaropaLintRule {
  AwesomeNotificationsUndeclaredChannelKeyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_undeclared_channel_key',
    '[awesome_notifications_undeclared_channel_key] A NotificationContent uses a'
        ' channelKey value that does not appear in the NotificationChannel list'
        ' passed to AwesomeNotifications().initialize() in the same file.'
        ' awesome_notifications silently discards notifications whose channelKey'
        ' was not declared at initialization — no exception and no log message in'
        ' release mode. This is documented in GitHub issue #482 and in the'
        ' official docs. Only literal string keys are compared; non-literal keys'
        ' in initialize() suppress this rule. {v1}',
    correctionMessage:
        'Add a NotificationChannel(channelKey: \'<key>\') entry to the channel'
        ' list in AwesomeNotifications().initialize(), or correct the typo in the'
        ' channelKey argument.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Both the channel-key collector and the content checker operate on the
    // same CompilationUnit, so a file-level scan is done once per context
    // registration by using addInstanceCreationExpression.
    //
    // Strategy: on each NotificationContent creation, walk up to the
    // CompilationUnit, collect declared channel keys from initialize() calls
    // in that unit, then validate the channelKey argument.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_importsAwesome(node)) return;
      final ctorName = node.constructorName.type.name.lexeme;
      if (ctorName != 'NotificationContent') return;

      // Extract the channelKey argument from NotificationContent(...)
      final channelKeyArg = _namedStringArg(node.argumentList, 'channelKey');
      if (channelKeyArg == null) return;

      // Collect the declared channel keys from initialize() in this file.
      final unit = _compilationUnit(node);
      if (unit == null) return;

      final Set<String>? declared = _collectDeclaredChannelKeys(unit);
      // Bail when no literal channel keys found — cannot safely validate.
      if (declared == null || declared.isEmpty) return;

      if (!declared.contains(channelKeyArg)) {
        reporter.atNode(_findNamedArg(node.argumentList, 'channelKey') ?? node);
      }
    });
  }

  /// Returns the Set of literal channelKey strings declared in
  /// `NotificationChannel(channelKey: '...')` nodes inside any
  /// `AwesomeNotifications().initialize(...)` call in the [unit].
  ///
  /// Returns null when any channel key is non-literal (bail signal).
  /// Returns an empty set when initialize() is not found in the unit.
  Set<String>? _collectDeclaredChannelKeys(CompilationUnit unit) {
    final collector = _InitializeChannelKeyCollector();
    unit.accept(collector);
    if (collector.foundNonLiteral) return null;
    return collector.keys;
  }
}

/// Collects literal channelKey strings from NotificationChannel(...) nodes
/// that appear inside an AwesomeNotifications().initialize(...) invocation.
///
/// Sets [foundNonLiteral] = true when a non-literal channelKey is encountered
/// so the caller can bail out to avoid false positives.
class _InitializeChannelKeyCollector extends RecursiveAstVisitor<void> {
  final Set<String> keys = {};
  bool foundNonLiteral = false;

  // Track whether we are currently inside an initialize() argument list.
  int _initializeDepth = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'initialize' &&
        _isAwesomeReceiver(node.target)) {
      _initializeDepth++;
      super.visitMethodInvocation(node);
      _initializeDepth--;
    } else {
      super.visitMethodInvocation(node);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_initializeDepth > 0) {
      final name = node.constructorName.type.name.lexeme;
      if (name == 'NotificationChannel') {
        final arg = _namedStringArg(node.argumentList, 'channelKey');
        if (arg != null) {
          keys.add(arg);
        } else {
          // channelKey is present but non-literal — bail signal.
          final hasKey = node.argumentList.arguments.any(
            (a) => a is NamedExpression && a.name.label.name == 'channelKey',
          );
          if (hasKey) foundNonLiteral = true;
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

// =============================================================================
// awesome_notifications_create_without_permission_check
// =============================================================================

/// Flags `createNotification()` with no prior `isNotificationAllowed()` await.
///
/// Since: v4.17.0 | Rule version: v1
///
/// On Android 13+ (API 33+) and all iOS versions, showing a notification
/// without OS-level permission being granted results in a silently ignored
/// notification (Android) or an unexpected permission dialog (iOS).
/// `createNotification()` returns `true` even when the OS blocks the
/// notification, making this failure invisible without an explicit permission
/// check. The official documentation and example code both require:
/// ```dart
/// bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
/// if (!isAllowed) return;
/// ```
/// before every `createNotification()` call.
///
/// **BAD:**
/// ```dart
/// Future<void> sendAlert() async {
///   // No isNotificationAllowed() check — silently ignored on Android 13+ / iOS
///   await AwesomeNotifications().createNotification(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> sendAlert() async {
///   if (!await AwesomeNotifications().isNotificationAllowed()) return;
///   await AwesomeNotifications().createNotification(...);
/// }
/// ```
class AwesomeNotificationsCreateWithoutPermissionCheckRule
    extends SaropaLintRule {
  AwesomeNotificationsCreateWithoutPermissionCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_create_without_permission_check',
    '[awesome_notifications_create_without_permission_check] A call to'
        ' AwesomeNotifications().createNotification() was found in a function'
        ' body that contains no prior await of isNotificationAllowed(). On'
        ' Android 13+ and all iOS versions, displaying a notification without'
        ' OS-level permission being granted results in a silently discarded'
        ' notification — createNotification() returns true even when the OS'
        ' blocks it, making this failure completely invisible to the caller.'
        ' The official docs and example both require an isNotificationAllowed()'
        ' guard before any createNotification() call. {v1}',
    correctionMessage:
        'Add `if (!await AwesomeNotifications().isNotificationAllowed()) return;`'
        ' before the createNotification() call, or gate the entire function on a'
        ' bool parameter whose name contains allowed/permitted/isNotification.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'createNotification') return;
      if (!_importsAwesome(node)) return;
      if (!_isAwesomeReceiver(node.target)) return;

      // Skip test files — permission checks are typically mocked there.
      if (_isTestFilePath(context.filePath)) return;

      final body = _enclosingBlock(node);
      if (body == null) return;

      // Suppress when the enclosing function has a bool parameter whose name
      // contains 'allowed', 'permitted', or 'isNotification' — the caller
      // was responsible for the guard and passed the result in.
      if (_enclosingFunctionHasPermissionParam(node)) return;

      // Search the block for any prior isNotificationAllowed() await.
      final scanner = _PermissionCheckScanner();
      body.accept(scanner);
      if (!scanner.foundCheck) {
        reporter.atNode(node);
      }
    });
  }

  /// True when the nearest enclosing function/method has a bool parameter
  /// whose name (lowercased) contains 'allowed', 'permitted', or
  /// 'isnotification' — indicating the permission check was done by the caller.
  bool _enclosingFunctionHasPermissionParam(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      FormalParameterList? params;
      if (current is FunctionDeclaration) {
        params = current.functionExpression.parameters;
      } else if (current is MethodDeclaration) {
        params = current.parameters;
      }
      if (params != null) {
        for (final param in params.parameters) {
          final name = param.name?.lexeme.toLowerCase() ?? '';
          if (name.contains('allowed') ||
              name.contains('permitted') ||
              name.contains('isnotification')) {
            return true;
          }
        }
        return false;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Scans a block for `await AwesomeNotifications().isNotificationAllowed()`.
class _PermissionCheckScanner extends RecursiveAstVisitor<void> {
  bool foundCheck = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    final expr = node.expression;
    if (expr is MethodInvocation &&
        expr.methodName.name == 'isNotificationAllowed' &&
        _isAwesomeReceiver(expr.target)) {
      foundCheck = true;
    }
    super.visitAwaitExpression(node);
  }
}

// =============================================================================
// awesome_notifications_negative_notification_id
// =============================================================================

/// Flags `NotificationContent(id: <negative literal>)` with a quick fix.
///
/// Since: v4.17.0 | Rule version: v1
///
/// Since awesome_notifications v0.6.14, any negative `id` value in
/// `NotificationContent` is silently replaced with a random integer by the
/// plugin. This makes `AwesomeNotifications().cancel(id)` ineffective because
/// the ID the caller holds is not the ID the notification was registered under.
/// `id: -1` is a common copy-paste from tutorials including the official example
/// and gives a false sense of explicit ID control.
///
/// The quick fix replaces the negative literal with
/// `Random().nextInt(2147483647)`. The caller must store the returned ID to
/// be able to cancel the notification later; import `dart:math` if needed.
///
/// **BAD:**
/// ```dart
/// NotificationContent(id: -1, channelKey: 'alerts', title: 'Hi')
/// ```
///
/// **GOOD:**
/// ```dart
/// // Store the ID to cancel later; ensure dart:math is imported.
/// final id = Random().nextInt(2147483647);
/// NotificationContent(id: id, channelKey: 'alerts', title: 'Hi')
/// ```
class AwesomeNotificationsNegativeNotificationIdRule extends SaropaLintRule {
  AwesomeNotificationsNegativeNotificationIdRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'awesome_notifications_negative_notification_id',
    '[awesome_notifications_negative_notification_id] A negative integer literal'
        ' is passed as the id argument of NotificationContent. Since'
        ' awesome_notifications v0.6.14, negative IDs are silently replaced by a'
        ' random value by the plugin (documented in the v0.6.14 changelog:"Defined'
        ' the final standard to replace negative IDs by random values"). This'
        ' makes AwesomeNotifications().cancel(id) ineffective because the ID the'
        ' caller holds does not match the ID the notification was registered'
        ' under. id: -1 is a common copy-paste from tutorials and gives a false'
        ' sense of explicit control. {v1}',
    correctionMessage:
        'Replace the negative literal with Random().nextInt(2147483647) and'
        ' store the result to cancel the notification later. Add'
        ' import \'dart:math\'; to the file if not already present.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplaceNegativeIdFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_importsAwesome(node)) return;
      if (node.constructorName.type.name.lexeme != 'NotificationContent') {
        return;
      }

      final idArg = _findNamedArg(node.argumentList, 'id');
      if (idArg == null) return;

      final expr = idArg.expression;
      // A PrefixExpression with operator '-' whose operand is an IntegerLiteral
      // is the syntactic form of `id: -1`.
      if (expr is PrefixExpression &&
          expr.operator.lexeme == '-' &&
          expr.operand is IntegerLiteral) {
        reporter.atNode(expr);
        return;
      }
      // Also match a bare negative IntegerLiteral (parser may fold these).
      if (expr is IntegerLiteral) {
        final value = expr.value;
        if (value != null && value < 0) {
          reporter.atNode(expr);
        }
      }
    });
  }
}

/// Quick fix: replace a negative id literal with `Random().nextInt(2147483647)`.
class _ReplaceNegativeIdFix extends ReplaceNodeFix {
  _ReplaceNegativeIdFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.replaceNegativeNotificationId',
    80,
    'Replace with Random().nextInt(2147483647)',
  );

  @override
  String computeReplacement(AstNode node) => 'Random().nextInt(2147483647)';
}

// =============================================================================
// awesome_notifications_listeners_before_display
// =============================================================================

/// Flags `createNotification()` or `requestPermissionToSendNotifications()`
/// appearing before `setListeners()` in the same block body.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The package documentation states: "Only after `setListeners` being called,
/// the notification events start to be delivered." In `main()` or `initState()`,
/// calling `createNotification()` before `setListeners()` means any event that
/// fires immediately (e.g., the action that re-launched the app from a tapped
/// notification) is lost because no listener is registered. The correct startup
/// order is: `initialize()` → `setListeners()` → other calls.
///
/// Detection is limited to the same `BlockFunctionBody` (no cross-function
/// ordering) and uses statement index — a conservative analysis that may miss
/// conditional cases but avoids false positives from control flow.
///
/// **BAD:**
/// ```dart
/// void main() async {
///   await AwesomeNotifications().initialize(...);
///   await AwesomeNotifications().createNotification(...); // before setListeners
///   await AwesomeNotifications().setListeners(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   await AwesomeNotifications().initialize(...);
///   await AwesomeNotifications().setListeners(...);
///   await AwesomeNotifications().createNotification(...);
/// }
/// ```
class AwesomeNotificationsListenersBeforeDisplayRule extends SaropaLintRule {
  AwesomeNotificationsListenersBeforeDisplayRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'awesome_notifications_listeners_before_display',
    '[awesome_notifications_listeners_before_display] A call to'
        ' createNotification() or requestPermissionToSendNotifications() appears'
        ' before setListeners() in the same function body. The'
        ' awesome_notifications package only begins delivering notification events'
        ' after setListeners() has been called. Any notification event that fires'
        ' immediately (such as the action that re-launched the app from a tapped'
        ' notification) is lost because no handler is registered at that point.'
        ' The correct startup order is: initialize() → setListeners() → other'
        ' notification calls. {v1}',
    correctionMessage:
        'Move the setListeners() call to before any createNotification() or'
        ' requestPermissionToSendNotifications() calls in this function body.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Match the display/permission calls that should come after setListeners.
      const Set<String> displayMethods = {
        'createNotification',
        'requestPermissionToSendNotifications',
      };
      if (!displayMethods.contains(node.methodName.name)) return;
      if (!_importsAwesome(node)) return;
      if (!_isAwesomeReceiver(node.target)) return;

      // Restrict to the same block; cross-function ordering is out of scope.
      final body = _enclosingBlock(node);
      if (body == null) return;

      final block = body.block;
      final statements = block.statements;

      // Find the index of the first setListeners() call in the same block.
      int? setListenersIndex;
      for (var i = 0; i < statements.length; i++) {
        if (_statementContainsCall(statements[i], 'setListeners')) {
          setListenersIndex = i;
          break;
        }
      }

      // No setListeners() in this block at all — cannot reason about order.
      if (setListenersIndex == null) return;

      // Find the index of the display call node itself in the block statements.
      final displayIndex = _statementIndexOf(statements, node);
      if (displayIndex == null) return;

      // Report when the display call appears before setListeners.
      if (displayIndex < setListenersIndex) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns the ordinal index in [statements] of the statement that contains
  /// [target], or null if [target] is not a direct child of this block.
  int? _statementIndexOf(List<Statement> statements, AstNode target) {
    for (var i = 0; i < statements.length; i++) {
      if (_nodeIsWithinStatement(statements[i], target)) return i;
    }
    return null;
  }

  /// True when [target] is [stmt] itself or a descendant of [stmt].
  bool _nodeIsWithinStatement(Statement stmt, AstNode target) {
    if (identical(stmt, target)) return true;
    // Use offset/end as a fast containment check.
    return target.offset >= stmt.offset && target.end <= stmt.end;
  }

  /// True when [stmt] contains a MethodInvocation named [name] on an
  /// AwesomeNotifications receiver.
  bool _statementContainsCall(Statement stmt, String name) {
    final finder = _CallFinder(name);
    stmt.accept(finder);
    return finder.found;
  }
}

/// Visits an AST subtree looking for a MethodInvocation with a given name on
/// an AwesomeNotifications receiver.
class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.name);
  final String name;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name && _isAwesomeReceiver(node.target)) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// SHARED AST HELPERS
// =============================================================================

/// Resolves [expr] (a SimpleIdentifier or PrefixedIdentifier) to the
/// [MethodDeclaration] it references within the same [CompilationUnit] as
/// [context]. Returns null when the reference is unresolvable (e.g. imported
/// method, lambda, or non-method reference).
MethodDeclaration? _resolveToMethod(Expression expr, AstNode context) {
  String? className;
  String? methodName;

  if (expr is PrefixedIdentifier) {
    // Form: ClassName.methodName
    className = expr.prefix.name;
    methodName = expr.identifier.name;
  } else if (expr is SimpleIdentifier) {
    // Form: methodName (bare reference — instance or static in enclosing class)
    methodName = expr.name;
  } else {
    return null;
  }

  final unit = _compilationUnit(context);
  if (unit == null) return null;

  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration && className == null) {
      // Top-level function match.
      if (decl.name.lexeme == methodName) {
        return null; // Top-level function — callers handle this case themselves.
      }
    } else if (decl is ClassDeclaration) {
      // analyzer 12.x pins these behind the project's compat extensions:
      // ClassDeclaration.name / .members are not on the package-pinned type,
      // so use nameToken / bodyMembers (lib/src/analyzer_compat.dart).
      if (className != null && decl.nameToken.lexeme != className) continue;
      for (final member in decl.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == methodName) {
          return member;
        }
      }
    }
  }
  return null;
}

/// Returns the string value of a named argument [argName] from [argList] when
/// the value is a [SimpleStringLiteral]. Returns null otherwise.
String? _namedStringArg(ArgumentList argList, String argName) {
  for (final arg in argList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == argName) {
      final expr = arg.expression;
      if (expr is SimpleStringLiteral) return expr.value;
      if (expr is StringInterpolation) return null; // non-literal
    }
  }
  return null;
}

/// Returns the [NamedExpression] for [argName] in [argList], or null.
NamedExpression? _findNamedArg(ArgumentList argList, String argName) {
  for (final arg in argList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == argName) return arg;
  }
  return null;
}

/// Returns the simple type name of the first parameter of [param], or null
/// when the type is absent, dynamic, or not a simple named type.
String? _paramTypeName(FormalParameter param) {
  TypeAnnotation? type;
  if (param is SimpleFormalParameter) {
    type = param.type;
  } else if (param is DefaultFormalParameter) {
    final inner = param.parameter;
    if (inner is SimpleFormalParameter) type = inner.type;
  }
  if (type == null) return null;
  if (type is NamedType) return type.name.lexeme;
  return null;
}

/// True when [method] bears a `@pragma('vm:entry-point')` annotation.
bool _hasPragmaEntryPoint(MethodDeclaration method) {
  for (final annotation in method.metadata) {
    // Match @pragma(...) by name.
    final name = annotation.name.name;
    if (name != 'pragma') continue;

    // Check the first argument is the literal string 'vm:entry-point'.
    final args = annotation.arguments?.arguments;
    if (args == null || args.isEmpty) continue;
    final first = args.first;
    if (first is SimpleStringLiteral && first.value == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}

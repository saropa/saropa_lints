// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// home_widget package lint rules.
///
/// Enforce the home-screen-widget contract: interactivity callbacks must be
/// top-level and annotated for AOT, saved data must be followed by an update,
/// updateWidget needs a target name, and iOS data sharing needs an App Group.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The static `HomeWidget` facade all relevant calls go through.
const String _homeWidgetType = 'HomeWidget';

/// The two callback-registration entry points (the modern + legacy name).
const Set<String> _registerMethods = <String>{
  'registerInteractivityCallback',
  'registerBackgroundCallback',
};

/// The four widget-targeting named parameters of `updateWidget`.
const Set<String> _updateNameParams = <String>{
  'name',
  'androidName',
  'iOSName',
  'qualifiedAndroidName',
};

/// True when [node] is a static call `HomeWidget.<name>(...)` for one of
/// [names]. home_widget exposes only static members, so the receiver is the
/// class identifier (no instance static type to resolve). Combined with
/// [fileImportsPackage] this is the type-safe gate.
bool _isHomeWidgetCall(MethodInvocation node, Set<String> names) {
  if (!names.contains(node.methodName.name)) return false;
  final Expression? target = node.realTarget;
  return target is SimpleIdentifier && target.name == _homeWidgetType;
}

/// Resolves the enclosing member body (method / function / constructor).
FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// Finds a top-level function declaration named [name] in [node]'s compilation
/// unit. Used by the pragma rule to inspect the callback's annotations when the
/// declaration is in the same file (cross-file declarations are skipped — see
/// the rule doc).
FunctionDeclaration? _topLevelFunctionInUnit(AstNode node, String name) {
  final CompilationUnit? unit = node.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null) return null;
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is FunctionDeclaration && member.name.lexeme == name) {
      return member;
    }
  }
  return null;
}

/// True when [decl] carries `@pragma('vm:entry-point')`.
bool _hasVmEntryPointPragma(AnnotatedNode decl) {
  for (final Annotation annotation in decl.metadata) {
    if (annotation.name.name != 'pragma') continue;
    final args = annotation.arguments?.arguments;
    if (args == null || args.isEmpty) continue;
    final Expression first = args.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}

/// True when [node] has a named argument [name] whose value is non-null.
bool _hasNonNullNamedArg(MethodInvocation node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression is! NullLiteral;
    }
  }
  return false;
}

/// True for files under `test/` or named `*_test.dart`.
bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

/// Collects method invocations and `HomeWidget.widgetClicked` accesses across a
/// class, so the class-scoped rules need one traversal.
class _HomeWidgetScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  final List<PrefixedIdentifier> widgetClickedAccesses = <PrefixedIdentifier>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == _homeWidgetType &&
        node.identifier.name == 'widgetClicked') {
      widgetClickedAccesses.add(node);
    }
    super.visitPrefixedIdentifier(node);
  }
}

// =============================================================================
// home_widget_callback_missing_pragma
// =============================================================================

/// Flags an interactivity callback whose same-file declaration lacks
/// `@pragma('vm:entry-point')`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// In AOT (release) builds, a callback without this annotation is tree-shaken,
/// so `getCallbackHandle` returns null and widget taps silently do nothing — a
/// regression invisible in debug (JIT) builds.
///
/// **BAD:**
/// ```dart
/// void onWidgetTap(Uri? uri) {}              // no annotation
/// HomeWidget.registerInteractivityCallback(onWidgetTap);
/// ```
///
/// **GOOD:**
/// ```dart
/// @pragma('vm:entry-point')
/// void onWidgetTap(Uri? uri) {}
/// HomeWidget.registerInteractivityCallback(onWidgetTap);
/// ```
class HomeWidgetCallbackMissingPragmaRule extends SaropaLintRule {
  HomeWidgetCallbackMissingPragmaRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'registerInteractivity'};

  static const LintCode _code = LintCode(
    'home_widget_callback_missing_pragma',
    '[home_widget_callback_missing_pragma] The function passed to registerInteractivityCallback / registerBackgroundCallback is not annotated @pragma(\'vm:entry-point\'). In AOT (release) builds the Dart compiler tree-shakes the unannotated function, so getCallbackHandle returns null and a widget tap calls back into an empty handler — the interaction silently does nothing, a regression that never appears in debug (JIT) builds. {v1}',
    correctionMessage:
        'Annotate the callback declaration with @pragma(\'vm:entry-point\') so it survives release-mode tree-shaking. The function must also be top-level or static.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isHomeWidgetCall(node, _registerMethods)) return;
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;
      final Expression arg = args.first;
      // Only a bare tear-off can be verified here; closures / instance methods
      // are handled by home_widget_callback_not_top_level.
      if (arg is! SimpleIdentifier) return;

      // Cross-file declarations cannot be inspected from the call site without
      // a heavier element walk; restrict to same-unit top-level functions to
      // avoid false positives (the cross-file case is documented as report-only
      // in the plan).
      final FunctionDeclaration? decl = _topLevelFunctionInUnit(node, arg.name);
      if (decl == null) return;
      if (_hasVmEntryPointPragma(decl)) return;

      reporter.atNode(arg);
    });
  }
}

// =============================================================================
// home_widget_callback_not_top_level
// =============================================================================

/// Flags an interactivity callback that is a closure, instance method, or other
/// non-top-level reference.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `PluginUtilities.getCallbackHandle` can only locate top-level functions and
/// static methods. A closure or instance-method tear-off returns null and the
/// widget interaction never reaches Dart.
///
/// **BAD:**
/// ```dart
/// HomeWidget.registerInteractivityCallback((uri) {});       // closure
/// HomeWidget.registerInteractivityCallback(service.onTap);  // instance method
/// ```
///
/// **GOOD:**
/// ```dart
/// HomeWidget.registerInteractivityCallback(onWidgetTap);    // top-level
/// ```
class HomeWidgetCallbackNotTopLevelRule extends SaropaLintRule {
  HomeWidgetCallbackNotTopLevelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'register'};

  static const LintCode _code = LintCode(
    'home_widget_callback_not_top_level',
    '[home_widget_callback_not_top_level] The function passed to registerInteractivityCallback / registerBackgroundCallback is a closure, instance method, or other non-top-level reference. PluginUtilities.getCallbackHandle can only serialize top-level functions and static methods; a closure or instance-method tear-off carries un-serializable context, returns null, and the widget interaction silently never reaches Dart. {v1}',
    correctionMessage:
        'Extract the callback to a top-level function (or a static method) and pass it by reference. Do not pass a closure or instance method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isHomeWidgetCall(node, _registerMethods)) return;
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;
      final Expression arg = args.first;

      // Closures and instance-method / this-qualified tear-offs cannot be
      // serialized. A bare SimpleIdentifier (top-level or static, possibly via
      // a `Class.method` PrefixedIdentifier) is left to the pragma rule.
      // Note: a static `Class.method` tear-off is a PrefixedIdentifier and may
      // be over-reported here — the same accepted approximation the firebase
      // notification-handler rule uses.
      if (arg is FunctionExpression ||
          arg is PropertyAccess ||
          arg is PrefixedIdentifier) {
        reporter.atNode(arg);
      }
    });
  }
}

// =============================================================================
// home_widget_save_without_update
// =============================================================================

/// Flags `saveWidgetData` in a member that never calls `updateWidget`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `saveWidgetData` persists to shared storage but does NOT re-render the home
/// screen widget; without an `updateWidget` the widget shows stale data until an
/// unrelated reload. Detection is member-scoped presence (not strict flow
/// order): an `updateWidget` anywhere in the same member clears the report.
///
/// **BAD:**
/// ```dart
/// await HomeWidget.saveWidgetData('count', 1);
/// ```
///
/// **GOOD:**
/// ```dart
/// await HomeWidget.saveWidgetData('count', 1);
/// await HomeWidget.updateWidget(name: 'MyWidget');
/// ```
class HomeWidgetSaveWithoutUpdateRule extends SaropaLintRule {
  HomeWidgetSaveWithoutUpdateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'saveWidgetData'};

  static const LintCode _code = LintCode(
    'home_widget_save_without_update',
    '[home_widget_save_without_update] saveWidgetData is called in a member that never calls updateWidget. saveWidgetData persists the value to shared storage but does not signal the OS to re-render the home-screen widget, so the on-screen widget keeps showing stale data until an unrelated reload event. The two calls are a required pair. A helper that only saves (and whose caller updates) is a known false positive — suppress with a verified // ignore:. {v1}',
    correctionMessage:
        'Call HomeWidget.updateWidget(name: ...) after saveWidgetData in the same flow to refresh the on-screen widget.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isHomeWidgetCall(node, const <String>{'saveWidgetData'})) return;
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      final _HomeWidgetScan scan = _HomeWidgetScan();
      body.accept(scan);

      final bool hasUpdate = scan.invocations.any(
        (MethodInvocation inv) =>
            _isHomeWidgetCall(inv, const <String>{'updateWidget'}),
      );
      if (hasUpdate) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// home_widget_update_no_name
// =============================================================================

/// Flags `updateWidget()` with no widget-targeting name argument.
///
/// Since: v4.16.0 | Rule version: v1
///
/// With all of `name` / `androidName` / `iOSName` / `qualifiedAndroidName`
/// absent or null, neither platform can resolve a widget provider, so the
/// update is a silent no-op.
///
/// **BAD:**
/// ```dart
/// await HomeWidget.updateWidget();
/// ```
///
/// **GOOD:**
/// ```dart
/// await HomeWidget.updateWidget(name: 'MyWidgetProvider');
/// ```
class HomeWidgetUpdateNoNameRule extends SaropaLintRule {
  HomeWidgetUpdateNoNameRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'updateWidget'};

  static const LintCode _code = LintCode(
    'home_widget_update_no_name',
    '[home_widget_update_no_name] updateWidget() is called with none of name, androidName, iOSName, or qualifiedAndroidName provided (all absent or null). With no widget identifier, neither Android nor iOS can find the widget provider to refresh, so the native side returns false without throwing and the update silently targets nothing. {v1}',
    correctionMessage:
        'Pass at least one widget name — name, androidName, iOSName, or qualifiedAndroidName — matching your native widget provider.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isHomeWidgetCall(node, const <String>{'updateWidget'})) return;
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;

      final bool anyProvided = _updateNameParams.any(
        (String name) => _hasNonNullNamedArg(node, name),
      );
      if (anyProvided) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// home_widget_ios_missing_app_group
// =============================================================================

/// Flags `saveWidgetData`/`getWidgetData` in a class with no `setAppGroupId`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// iOS data sharing uses the App Group container; without `setAppGroupId` (or a
/// per-call `appGroupId:`) reads/writes silently fail or return stale data on
/// iOS. Class-scoped — a `setAppGroupId` in a mixin/base class is a known false
/// positive (suppress with a verified // ignore:).
///
/// **BAD:**
/// ```dart
/// await HomeWidget.saveWidgetData('count', 1); // no setAppGroupId in class
/// ```
///
/// **GOOD:**
/// ```dart
/// await HomeWidget.setAppGroupId('group.com.example.app');
/// await HomeWidget.saveWidgetData('count', 1);
/// ```
class HomeWidgetIosMissingAppGroupRule extends SaropaLintRule {
  HomeWidgetIosMissingAppGroupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'WidgetData'};

  static const LintCode _code = LintCode(
    'home_widget_ios_missing_app_group',
    '[home_widget_ios_missing_app_group] This class calls saveWidgetData / getWidgetData but never calls setAppGroupId, and the call does not pass a per-call appGroupId. On iOS the App Group shared container must be configured via setAppGroupId before any widget data read or write; without it the storage path is inaccessible to the widget extension and data sharing silently fails or returns stale values. A setAppGroupId in a mixin or base class is a known false positive. {v1}',
    correctionMessage:
        'Call HomeWidget.setAppGroupId(\'group.<bundle-id>\') before saveWidgetData/getWidgetData, or pass the appGroupId: argument per call.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;
      if (_isTestFilePath(context.filePath)) return;

      final _HomeWidgetScan scan = _HomeWidgetScan();
      node.accept(scan);

      // Data calls that pass their own appGroupId: are individually guarded.
      final List<MethodInvocation> unguarded = scan.invocations
          .where(
            (MethodInvocation inv) =>
                _isHomeWidgetCall(
                  inv,
                  const <String>{'saveWidgetData', 'getWidgetData'},
                ) &&
                !_hasNonNullNamedArg(inv, 'appGroupId'),
          )
          .toList();
      if (unguarded.isEmpty) return;

      final bool hasSetGroup = scan.invocations.any(
        (MethodInvocation inv) =>
            _isHomeWidgetCall(inv, const <String>{'setAppGroupId'}),
      );
      if (hasSetGroup) return;

      for (final MethodInvocation call in unguarded) {
        reporter.atNode(call);
      }
    });
  }
}

// =============================================================================
// home_widget_widget_clicked_without_initial_launch
// =============================================================================

/// Flags a class listening to `HomeWidget.widgetClicked` with no
/// `initiallyLaunchedFromHomeWidget()` call.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `widgetClicked` fires only when the app is already running; a cold-start
/// widget tap is delivered solely via `initiallyLaunchedFromHomeWidget()`.
/// Missing the latter drops cold-start taps. INFO — the cold-start handler may
/// live in a separate router class (a known false positive).
///
/// **BAD:**
/// ```dart
/// HomeWidget.widgetClicked.listen(_onTap); // no initiallyLaunched check
/// ```
///
/// **GOOD:**
/// ```dart
/// HomeWidget.widgetClicked.listen(_onTap);
/// final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
/// ```
class HomeWidgetWidgetClickedWithoutInitialLaunchRule extends SaropaLintRule {
  HomeWidgetWidgetClickedWithoutInitialLaunchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'widgetClicked'};

  static const LintCode _code = LintCode(
    'home_widget_widget_clicked_without_initial_launch',
    '[home_widget_widget_clicked_without_initial_launch] This class listens to HomeWidget.widgetClicked but never calls initiallyLaunchedFromHomeWidget(). widgetClicked only fires when the app is already running; a widget tap that cold-starts the app is delivered solely through initiallyLaunchedFromHomeWidget(). Without it the cold-start tap is dropped and the app opens to its default screen. Reported at INFO because the cold-start handler may live in a separate router or lifecycle class. {v1}',
    correctionMessage:
        'Also call HomeWidget.initiallyLaunchedFromHomeWidget() at startup to handle a widget tap that cold-started the app.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.homeWidget)) return;
      if (_isTestFilePath(context.filePath)) return;

      final _HomeWidgetScan scan = _HomeWidgetScan();
      node.accept(scan);
      if (scan.widgetClickedAccesses.isEmpty) return;

      final bool hasInitialLaunch = scan.invocations.any(
        (MethodInvocation inv) => _isHomeWidgetCall(
          inv,
          const <String>{'initiallyLaunchedFromHomeWidget'},
        ),
      );
      if (hasInitialLaunch) return;

      for (final PrefixedIdentifier access in scan.widgetClickedAccesses) {
        reporter.atNode(access);
      }
    });
  }
}

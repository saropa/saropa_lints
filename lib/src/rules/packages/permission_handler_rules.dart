// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// permission_handler package lint rules (new coverage only).
///
/// The repo already ships permission_handler coverage for the most common
/// failure modes: the permanently-denied recovery flow
/// (`require_permission_permanent_denial_handling`, error_handling_rules.dart;
/// `require_permission_denied_handling`, api_network_rules.dart), the
/// shouldShowRequestRationale convention (`require_permission_rationale`,
/// api_network_rules.dart), reading a gated feature without a status check
/// (`require_permission_status_check`, api_network_rules.dart), the
/// request-in-a-loop spam (`avoid_permission_request_loop`) and over-broad
/// request lists (`prefer_permission_minimal_request`) in permission_rules.dart,
/// plus the pre-8.0 null-safety migration (`avoid_permission_handler_null_safety`).
///
/// These rules cover the gaps those do NOT: requesting inside build(), the
/// Android locationAlways-before-whenInUse ordering trap, the deprecated
/// `Permission.calendar` enum value, status checked but never requested, and
/// multiple un-batched sequential requests.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// Permission-status getters and the `.status` accessor that read state without
/// elevating it. Reading any of these means the code observes a permission but
/// cannot move it from denied to granted unless `.request()` is also called.
const Set<String> _statusGetters = <String>{
  'isGranted',
  'isDenied',
  'isPermanentlyDenied',
  'isRestricted',
  'isLimited',
  'status',
};

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

/// The nearest enclosing executable function body, walking up from [node].
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

/// True when [body] contains a `.request()` invocation whose receiver text
/// starts with `Permission` (covers both `Permission.x.request()` and a
/// `[Permission.x, ...].request()` list call). Type resolution is unavailable
/// for these enum receivers across the platform-interface split, so this gates
/// on the receiver text plus the file-level package import.
bool _bodyHasPermissionRequest(AstNode body) {
  final _RequestScan scan = _RequestScan();
  body.accept(scan);
  return scan.matched;
}

class _RequestScan extends RecursiveAstVisitor<void> {
  bool matched = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'request') {
      final Expression? target = node.target;
      if (target != null && target.toSource().startsWith('Permission')) {
        matched = true;
      }
      // A `[Permission.x, Permission.y].request()` list call also counts.
      // Inspect the elements (AST) instead of substring-scanning the source —
      // the latter tripped the .contains() false-positive guard and matched
      // any identifier merely containing "Permission".
      if (target is ListLiteral) {
        for (final CollectionElement element in target.elements) {
          if (element is PrefixedIdentifier &&
              element.prefix.name == 'Permission') {
            matched = true;
            break;
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// permission_handler_request_in_build
// =============================================================================

/// Flags `Permission.x.request()` called directly in an overridden `build()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `build()` runs on every rebuild (scroll, parent rebuild, hot-reload).
/// Requesting a permission there pops the system dialog repeatedly and violates
/// the rule that `build()` must be pure. Request in `initState` +
/// `addPostFrameCallback`, or on a user gesture. Calls inside a nested closure
/// (a `Builder` / `onPressed` defined in build but executed later) are skipped.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   Permission.camera.request(); // fires on every rebuild
///   return const SizedBox();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ElevatedButton(
///     onPressed: () => Permission.camera.request(),
///     child: const Text('Allow'),
///   );
/// }
/// ```
class PermissionHandlerRequestInBuildRule extends SaropaLintRule {
  PermissionHandlerRequestInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'request', 'build'};

  static const LintCode _code = LintCode(
    'permission_handler_request_in_build',
    '[permission_handler_request_in_build] A permission_handler request() call runs synchronously inside an overridden build() method. build() is invoked on every rebuild (scroll, parent rebuild, hot-reload), so the OS permission dialog re-appears repeatedly, and the call violates the Flutter contract that build() must be a pure function of its inputs. Move the request to initState with WidgetsBinding.instance.addPostFrameCallback, or fire it from a user gesture. {v1}',
    correctionMessage:
        'Request the permission from initState (via addPostFrameCallback) or a user-initiated callback, not from build().',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      final Expression? target = node.target;
      if (target == null || !target.toSource().startsWith('Permission')) {
        return;
      }

      // Walk up: only fire when the nearest enclosing function is a build()
      // method body itself. A FunctionExpression between the call and build()
      // means the call lives in a nested closure (Builder / onPressed) that
      // build does NOT execute synchronously — that is the documented FP.
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) return;
        if (current is MethodDeclaration) {
          if (current.name.lexeme == 'build') reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// permission_handler_location_always_before_when_in_use
// =============================================================================

/// Flags `Permission.locationAlways.request()` with no preceding
/// `locationWhenInUse` / `location` request in the same function body.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Android 10+ enforces a two-step flow: the app must already hold
/// `locationWhenInUse` (foreground) before it can request `locationAlways`
/// (background). Requesting background first is silently ignored — the OS
/// returns `denied` with no dialog. Scope is the function body (a floor: a
/// two-method split flow is not visible here).
///
/// **BAD:**
/// ```dart
/// await Permission.locationAlways.request(); // no foreground grant first
/// ```
///
/// **GOOD:**
/// ```dart
/// await Permission.locationWhenInUse.request();
/// await Permission.locationAlways.request();
/// ```
class PermissionHandlerLocationAlwaysBeforeWhenInUseRule
    extends SaropaLintRule {
  PermissionHandlerLocationAlwaysBeforeWhenInUseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'locationAlways'};

  static const LintCode _code = LintCode(
    'permission_handler_location_always_before_when_in_use',
    '[permission_handler_location_always_before_when_in_use] Permission.locationAlways.request() is called with no preceding Permission.locationWhenInUse or Permission.location request in the same function body. Android 10 (API 29) and later require the app to already hold foreground location before background (always) location can be granted; requesting always first is silently ignored and returns denied with no dialog, leaving the user no path to recover except app settings. This scope is the function body and is a floor — a two-method split flow is not visible here. {v1}',
    correctionMessage:
        'Request Permission.locationWhenInUse (or Permission.location) and confirm it is granted before requesting Permission.locationAlways.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      final Expression? target = node.target;
      if (target == null || target.toSource() != 'Permission.locationAlways') {
        return;
      }

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      // A foreground-location request earlier in the same body satisfies the
      // ordering, regardless of textual position — the floor only checks the
      // body, so any presence clears the report.
      final _ForegroundLocationScan scan = _ForegroundLocationScan();
      body.accept(scan);
      if (scan.matched) return;

      reporter.atNode(node);
    });
  }
}

/// Detects a `request()` on `Permission.locationWhenInUse` or
/// `Permission.location` anywhere in the scanned body.
class _ForegroundLocationScan extends RecursiveAstVisitor<void> {
  bool matched = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'request') {
      final String? targetSource = node.target?.toSource();
      if (targetSource == 'Permission.locationWhenInUse' ||
          targetSource == 'Permission.location') {
        matched = true;
      }
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// permission_handler_deprecated_calendar
// =============================================================================

/// Flags `Permission.calendar`, deprecated in permission_handler 11.4.0.
///
/// Since: v4.16.0 | Rule version: v1
///
/// iOS 17 split calendar access into write-only and full-access levels.
/// `Permission.calendar` was deprecated and now behaves like the most
/// permissive `calendarFullAccess`. The quick fix replaces the identifier with
/// `Permission.calendarFullAccess` (the documented behavior-equivalent path);
/// switch to `calendarWriteOnly` manually if the app only writes events.
///
/// **BAD:**
/// ```dart
/// await Permission.calendar.request();
/// ```
///
/// **GOOD:**
/// ```dart
/// await Permission.calendarFullAccess.request();
/// ```
class PermissionHandlerDeprecatedCalendarRule extends SaropaLintRule {
  PermissionHandlerDeprecatedCalendarRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'calendar'};

  static const LintCode _code = LintCode(
    'permission_handler_deprecated_calendar',
    '[permission_handler_deprecated_calendar] Permission.calendar was deprecated in permission_handler 11.4.0 when iOS 17 split calendar access into write-only and full-access levels. The old value now silently delegates to calendarFullAccess, the most permissive level, so apps that only need to write events request broader access than necessary. Replace with Permission.calendarFullAccess (behavior-equivalent) or Permission.calendarWriteOnly if write access is sufficient. {v1}',
    correctionMessage:
        'Replace Permission.calendar with Permission.calendarFullAccess, or Permission.calendarWriteOnly if the app only adds or edits events.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplaceCalendarFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // `Permission.calendar` parses as a PrefixedIdentifier (prefix `Permission`,
    // identifier `calendar`). Match the resolved member access shape rather than
    // a bare `calendar` so string literals and unrelated `.calendar` getters do
    // not trigger.
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'calendar') return;
      if (node.prefix.name != 'Permission') return;
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      reporter.atNode(node);
    });
  }
}

/// Quick fix: replace `Permission.calendar` with `Permission.calendarFullAccess`.
class _ReplaceCalendarFix extends ReplaceNodeFix {
  _ReplaceCalendarFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.replaceDeprecatedCalendar',
    80,
    'Replace with Permission.calendarFullAccess',
  );

  @override
  String computeReplacement(AstNode node) => 'Permission.calendarFullAccess';
}

// =============================================================================
// permission_handler_status_without_request
// =============================================================================

/// Flags a permission status check in a file that never calls `.request()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Checking `Permission.x.isGranted` / `.status` without ever calling
/// `.request()` in the same file means the code can observe a permission but
/// can never move it from denied to granted — the feature silently never works
/// after first install. Distinct from `require_permission_status_check`, which
/// flags the inverse (a gated feature used with NO status check). INFO: the
/// request may legitimately live in a centralized service in another file.
///
/// **BAD:**
/// ```dart
/// if (await Permission.camera.isGranted) openCamera(); // never requested
/// ```
///
/// **GOOD:**
/// ```dart
/// final status = await Permission.camera.request();
/// if (status.isGranted) openCamera();
/// ```
class PermissionHandlerStatusWithoutRequestRule extends SaropaLintRule {
  PermissionHandlerStatusWithoutRequestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'permission_handler_status_without_request',
    '[permission_handler_status_without_request] A permission_handler status check (isGranted / isDenied / status, etc.) appears in a file that never calls request(). Reading the status without ever requesting means the permission can never transition from denied to granted within this code path, so the feature silently never works after a fresh install. Reported at INFO because the request may legitimately live in a centralized permission service in another file. {v1}',
    correctionMessage:
        'Ensure Permission.x.request() is called (here or in a shared service) so the permission can actually be granted, not just observed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // File-level check: collect status reads and request calls across the whole
    // unit, then report the first status read only when no request exists.
    context.addCompilationUnit((CompilationUnit node) {
      if (_isTestFilePath(context.filePath)) return;
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      // A request anywhere in the file clears the whole unit.
      if (_bodyHasPermissionRequest(node)) return;

      final _PermissionStatusReadScan scan = _PermissionStatusReadScan();
      node.accept(scan);
      final AstNode? firstRead = scan.firstRead;
      if (firstRead != null) reporter.atNode(firstRead);
    });
  }
}

/// Finds the first `Permission.x.<statusGetter>` read in a unit. Gating on a
/// `Permission` receiver text avoids matching unrelated `isGranted` getters on
/// other objects.
class _PermissionStatusReadScan extends RecursiveAstVisitor<void> {
  AstNode? firstRead;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (firstRead == null &&
        _statusGetters.contains(node.identifier.name) &&
        node.prefix.toSource().startsWith('Permission')) {
      firstRead = node;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (firstRead == null &&
        _statusGetters.contains(node.propertyName.name) &&
        (node.realTarget.toSource().startsWith('Permission'))) {
      firstRead = node;
    }
    super.visitPropertyAccess(node);
  }
}

// =============================================================================
// permission_handler_batched_request_preferred
// =============================================================================

/// Flags two or more separate `Permission.x.request()` calls in one body that
/// are not result-gated (could be a single batched list request).
///
/// Since: v4.16.0 | Rule version: v1
///
/// `[Permission.a, Permission.b].request()` batches into the fewest dialogs the
/// OS allows and returns a `Map`. Firing N separate `await request()` calls
/// shows N dialogs. Sequential-by-design flows (the second request inside an
/// `if`/`switch` on the first result, e.g. locationAlways after locationWhenInUse
/// is granted) are skipped. INFO.
///
/// **BAD:**
/// ```dart
/// await Permission.camera.request();
/// await Permission.microphone.request();
/// ```
///
/// **GOOD:**
/// ```dart
/// await [Permission.camera, Permission.microphone].request();
/// ```
class PermissionHandlerBatchedRequestPreferredRule extends SaropaLintRule {
  PermissionHandlerBatchedRequestPreferredRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'request'};

  static const LintCode _code = LintCode(
    'permission_handler_batched_request_preferred',
    '[permission_handler_batched_request_preferred] Two or more separate Permission.x.request() calls appear in the same function body without being result-gated. Each separate request shows its own system dialog, interrupting the user once per permission; the package supports [Permission.a, Permission.b].request() which batches into the fewest dialogs the OS allows and returns a Map<Permission, PermissionStatus>. Sequential flows where a later request is conditioned on an earlier result are intentionally skipped. {v1}',
    correctionMessage:
        'Combine the independent requests into a single [Permission.a, Permission.b].request() list call and read the returned Map.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Per-body analysis: report the second+ single-permission request only when
    // no if/switch sits between it and the first (a guard implies the later
    // request is gated on the earlier result — intentional sequential logic).
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;
      if (!fileImportsPackage(node, PackageImports.permissionHandler)) return;

      final Expression? target = node.target;
      // Only single-permission requests batch; a list request is already batched.
      if (target == null || target is ListLiteral) return;
      if (!target.toSource().startsWith('Permission')) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      final _SingleRequestCollector collector = _SingleRequestCollector();
      body.accept(collector);
      final List<MethodInvocation> requests = collector.requests;
      if (requests.length < 2) return;

      // Report on the first request that is not the earliest and is not nested
      // inside a conditional branch (which would mean it is result-gated).
      final MethodInvocation first = requests.first;
      if (node == first) return;
      if (_insideConditional(node, body)) return;

      reporter.atNode(node);
    });
  }

  /// True when [node] sits inside an `if`/`switch` that lives below [body],
  /// indicating the request is gated on a prior result rather than fired flat.
  bool _insideConditional(AstNode node, FunctionBody body) {
    AstNode? current = node.parent;
    while (current != null && current != body) {
      if (current is IfStatement || current is SwitchStatement) return true;
      current = current.parent;
    }
    return false;
  }
}

/// Collects single-permission `Permission.x.request()` calls (excludes list
/// requests, which are already batched) in textual order.
class _SingleRequestCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> requests = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'request') {
      final Expression? target = node.target;
      if (target != null &&
          target is! ListLiteral &&
          target.toSource().startsWith('Permission')) {
        requests.add(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// app_links package lint rules (new coverage only).
///
/// The repo already ships deep-link safety coverage in
/// `avoid_app_links_sensitive_params` (tokens/passwords in deep-link URLs), and
/// the generic stream-disposal rules `require_stream_subscription_cancel` /
/// `avoid_unassigned_stream_subscriptions` already cover an un-canceled
/// `uriLinkStream.listen(...)` subscription. These rules cover the gaps those do
/// NOT: subscribing to the link stream inside `build()` (rebuild leak), calling
/// the raw-`String` link API instead of the validated `Uri` surface, and
/// `listen(...)` on the link stream with no `onError:` handler.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The two `AppLinks` getters that return the broadcast deep-link stream.
const Set<String> _linkStreamGetters = <String>{
  'uriLinkStream',
  'stringLinkStream',
};

/// The raw-`String` link accessors the `Uri` surface should be preferred over.
/// Each maps to its validated `Uri`-returning counterpart for the quick fix.
const Map<String, String> _stringLinkToUriMethod = <String, String>{
  'getInitialLinkString': 'getInitialLink',
  'getLatestLinkString': 'getLatestLink',
};

/// The getter name of a `<AppLinks>.uriLinkStream` / `.stringLinkStream`
/// receiver, or null when [receiver] is not one of those property reads.
///
/// The link stream is reached as either a `PrefixedIdentifier`
/// (`appLinks.uriLinkStream`) or a `PropertyAccess`
/// (`AppLinks().uriLinkStream`), so both forms are matched.
String? _linkStreamGetterName(Expression? receiver) {
  if (receiver is PrefixedIdentifier &&
      _linkStreamGetters.contains(receiver.identifier.name)) {
    return receiver.identifier.name;
  }
  if (receiver is PropertyAccess &&
      _linkStreamGetters.contains(receiver.propertyName.name)) {
    return receiver.propertyName.name;
  }
  return null;
}

/// True when [node] is the Flutter `Widget build(BuildContext context)`
/// override (or any method literally named `build`).
///
/// Used to confine the late-init rule to the rebuild path. We match by method
/// name rather than resolving the `Widget`/`BuildContext` types because the
/// only relevant `build` in an app_links-importing file is the widget one, and
/// the name check is allocation-free.
bool _isInsideBuildMethod(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) {
      return current.name.lexeme == 'build';
    }
    // A function/closure boundary that is not a method means we left the
    // widget body (e.g. a builder callback defined elsewhere); stop.
    if (current is FunctionDeclaration) return false;
    current = current.parent;
  }
  return false;
}

// =============================================================================
// app_links_listen_in_build
// =============================================================================

/// Flags `uriLinkStream`/`stringLinkStream`.listen(...) inside `build()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `build()` runs on every rebuild. Subscribing to the broadcast link stream
/// there creates a new `StreamSubscription` per frame; the subscriptions are
/// never canceled (build has no disposal hook) and the deep-link callback fires
/// once per accumulated subscription. Subscribe once in `initState()`, a
/// constructor, or a service — not in `build()`.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   appLinks.uriLinkStream.listen(_handle);
///   return const SizedBox();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void initState() {
///   _sub = appLinks.uriLinkStream.listen(_handle);
/// }
/// ```
class AppLinksListenInBuildRule extends SaropaLintRule {
  AppLinksListenInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'uriLinkStream',
    'stringLinkStream',
  };

  static const LintCode _code = LintCode(
    'app_links_listen_in_build',
    '[app_links_listen_in_build] An app_links deep-link stream (uriLinkStream / stringLinkStream) is subscribed to with .listen(...) inside a build() method. build() runs on every rebuild, so this creates a new StreamSubscription per frame that is never canceled and fires the deep-link callback once per accumulated subscription, leaking subscriptions and duplicating navigation. Subscribe once in initState(), a constructor, or a startup service instead. {v1}',
    correctionMessage:
        'Move the .listen(...) call out of build() into initState() (storing the subscription for cancel) or a one-time service initializer.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;
      if (_linkStreamGetterName(node.realTarget) == null) return;
      if (!fileImportsPackage(node, PackageImports.appLinks)) return;
      if (!_isInsideBuildMethod(node)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// app_links_uncaught_stream_error
// =============================================================================

/// Flags `uriLinkStream`/`stringLinkStream`.listen(...) with no `onError:`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The link stream surfaces platform-channel failures and malformed-URI errors
/// as stream errors. A `.listen(...)` with no `onError:` callback lets them
/// reach the zone's uncaught handler, which in release builds can silently drop
/// the error or crash. Report-only: a mechanical handler body would be a no-op
/// stub, and the project bans insert-TODO fixes. INFO.
///
/// **BAD:**
/// ```dart
/// appLinks.uriLinkStream.listen(_handle);
/// ```
///
/// **GOOD:**
/// ```dart
/// appLinks.uriLinkStream.listen(_handle, onError: _handleError);
/// ```
class AppLinksUncaughtStreamErrorRule extends SaropaLintRule {
  AppLinksUncaughtStreamErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'uriLinkStream',
    'stringLinkStream',
  };

  static const LintCode _code = LintCode(
    'app_links_uncaught_stream_error',
    '[app_links_uncaught_stream_error] An app_links deep-link stream (uriLinkStream / stringLinkStream) is subscribed with .listen(...) but no onError: callback. The stream surfaces platform-channel failures and malformed-URI errors as stream errors; without onError they propagate to the zone uncaught handler, which in release builds can silently drop the error or crash the app. Add an onError: handler that logs or recovers. {v1}',
    correctionMessage:
        'Add an onError: (Object error, StackTrace stack) { ... } argument to listen(), or chain .handleError(...) before .listen(...).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;
      if (_linkStreamGetterName(node.realTarget) == null) return;
      if (!fileImportsPackage(node, PackageImports.appLinks)) return;

      // A .handleError(...) hop on the immediate receiver already routes errors;
      // only the direct getter-then-listen shape is unhandled.
      final Expression target = node.realTarget!;
      if (target is MethodInvocation &&
          target.methodName.name == 'handleError') {
        return;
      }

      final bool hasOnError = node.argumentList.arguments.any(
        (Expression arg) =>
            arg is NamedExpression && arg.name.label.name == 'onError',
      );
      if (hasOnError) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// app_links_avoid_get_initial_link_string
// =============================================================================

/// Flags the raw-`String` link API in favor of the `Uri` surface.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `getInitialLinkString()` / `getLatestLinkString()` return a raw `String` URL
/// the caller must re-parse with `Uri.parse`, reintroducing parse-failure
/// modes. The `Uri`-returning variants (`getInitialLink()` / `getLatestLink()`)
/// hand back a pre-validated `Uri?`. The fix swaps to the `Uri` method. INFO —
/// raw-string use for logging is sometimes intentional.
///
/// **BAD:**
/// ```dart
/// final s = await appLinks.getInitialLinkString();
/// ```
///
/// **GOOD:**
/// ```dart
/// final uri = await appLinks.getInitialLink();
/// ```
class AppLinksAvoidGetInitialLinkStringRule extends SaropaLintRule {
  AppLinksAvoidGetInitialLinkStringRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'getInitialLinkString',
    'getLatestLinkString',
  };

  static const LintCode _code = LintCode(
    'app_links_avoid_get_initial_link_string',
    '[app_links_avoid_get_initial_link_string] A raw-String app_links accessor (getInitialLinkString / getLatestLinkString) is used instead of the validated Uri surface. The String variant returns a raw URL the caller must re-parse with Uri.parse, reintroducing parse-failure modes the Uri-returning methods (getInitialLink / getLatestLink) already handle by giving back a pre-validated Uri?. Reported at INFO because raw-string use for logging or analytics is sometimes intentional. {v1}',
    correctionMessage:
        'Call getInitialLink() / getLatestLink() (returns Uri?) instead of the String variant, unless the raw string is needed for logging.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _SwapToUriMethodFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_stringLinkToUriMethod.containsKey(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.appLinks)) return;

      reporter.atNode(node.methodName);
    });
  }
}

/// Quick fix: swap a raw-String link accessor for its Uri-returning variant.
///
/// Only the method name changes; the call shape and the awaited Future shape
/// are identical apart from the element type (String vs Uri), so a name-only
/// replacement is safe.
class _SwapToUriMethodFix extends ReplaceNodeFix {
  _SwapToUriMethodFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.appLinksSwapToUriMethod',
    80,
    'Use the Uri-returning link method',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is SimpleIdentifier) {
      final String? replacement = _stringLinkToUriMethod[node.name];
      if (replacement != null) return replacement;
    }
    return node.toSource();
  }
}

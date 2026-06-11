// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// in_app_review package lint rules.
///
/// Enforce the documented requestReview() contract — availability check first,
/// never on a button or in initState — and the openStoreListing() App Store ID
/// requirement on Apple targets.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The in_app_review singleton type. All three relevant methods
/// (`isAvailable`, `requestReview`, `openStoreListing`) resolve to it.
const String _inAppReviewType = 'InAppReview';

/// Canonical Flutter/Material interactive-callback named arguments. A
/// `requestReview()` call nested directly in one of these closures is the
/// button anti-pattern. The set is exhaustive for the framework's button/
/// gesture callbacks — not expanded speculatively (would invite false hits on
/// bespoke callback params).
const Set<String> _buttonCallbackNames = <String>{
  'onPressed',
  'onTap',
  'onLongPress',
  'onDoubleTap',
  'onSubmitted',
  'onEditingComplete',
};

/// True when [node] is a method call on a resolved `InAppReview` receiver with
/// the given [name]. Type-safe: keys on the receiver's resolved static type,
/// never a bare-name match on the variable.
bool _isInAppReviewCall(MethodInvocation node, String name) {
  if (node.methodName.name != name) return false;
  return node.realTarget?.staticType?.element?.name == _inAppReviewType;
}

/// Resolves the enclosing member body (method / function / constructor) — the
/// outermost one — so the availability check can be found even when it sits in
/// an `if (await isAvailable()) { requestReview(); }` that nests the call in a
/// block under the same member.
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

/// Collects method invocations and interactive-callback presence in a subtree.
/// Shared by the class-scoped fallback rule so one traversal answers both
/// "is requestReview/openStoreListing present" and "is there a button".
class _ReviewScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  bool hasButtonCallback = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (_buttonCallbackNames.contains(node.name.label.name)) {
      hasButtonCallback = true;
    }
    super.visitNamedExpression(node);
  }
}

// =============================================================================
// in_app_review_missing_availability_check
// =============================================================================

/// Flags `requestReview()` with no `isAvailable()` check in the same member.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The package README requires checking `isAvailable()` before
/// `requestReview()`. Without it the call silently no-ops on unsupported
/// platforms (Windows, Android without Play Store, iOS < 10.3), wasting the
/// review quota and confusing the user.
///
/// **BAD:**
/// ```dart
/// InAppReview.instance.requestReview();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await InAppReview.instance.isAvailable()) {
///   await InAppReview.instance.requestReview();
/// }
/// ```
class InAppReviewMissingAvailabilityCheckRule extends SaropaLintRule {
  InAppReviewMissingAvailabilityCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'requestReview'};

  static const LintCode _code = LintCode(
    'in_app_review_missing_availability_check',
    '[in_app_review_missing_availability_check] requestReview() is called without an isAvailable() check on the InAppReview instance in the same member. The package requires gating the request on isAvailable(); without it the call silently no-ops on unsupported platforms (Windows, Android without the Play Store, iOS below 10.3), wasting the one-per-year review quota and showing the user nothing. {v1}',
    correctionMessage:
        'Gate the call: if (await InAppReview.instance.isAvailable()) { await InAppReview.instance.requestReview(); }. If the check lives in a shared helper, suppress with a verified // ignore: and a comment.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isInAppReviewCall(node, 'requestReview')) return;
      if (!fileImportsPackage(node, PackageImports.inAppReview)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      final _ReviewScan scan = _ReviewScan();
      body.accept(scan);

      // Element-based: an isAvailable() call on an InAppReview receiver
      // anywhere in the member satisfies the contract (not a source-substring
      // scan, which would match comments / unrelated identifiers).
      final bool hasAvailabilityCheck = scan.invocations.any(
        (MethodInvocation inv) => _isInAppReviewCall(inv, 'isAvailable'),
      );
      if (hasAvailabilityCheck) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// in_app_review_button_callback_request
// =============================================================================

/// Flags `requestReview()` called directly inside a button/gesture callback.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The README and both store guidelines prohibit wiring `requestReview()` to a
/// tappable control: once the quota is spent the tap shows nothing. Use
/// `openStoreListing()` (no quota) for an explicit "rate us" button.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () => InAppReview.instance.requestReview(),
///   child: const Text('Rate us'),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () => InAppReview.instance.openStoreListing(appStoreId: '123'),
///   child: const Text('Rate us'),
/// );
/// ```
class InAppReviewButtonCallbackRequestRule extends SaropaLintRule {
  InAppReviewButtonCallbackRequestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'requestReview'};

  static const LintCode _code = LintCode(
    'in_app_review_button_callback_request',
    '[in_app_review_button_callback_request] requestReview() is wired directly to a button or gesture callback. The package README and both the Apple and Google Play guidelines prohibit this: when the review quota is already spent the call silently no-ops, so the user taps the control and sees nothing with no explanation. Explicit rate buttons should open the store listing instead. {v1}',
    correctionMessage:
        'For an explicit "rate this app" button use openStoreListing(appStoreId: ...), which has no quota. Reserve requestReview() for a post-engagement trigger, not a tap handler.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isInAppReviewCall(node, 'requestReview')) return;
      if (!fileImportsPackage(node, PackageImports.inAppReview)) return;

      final FunctionExpression? closure = node
          .thisOrAncestorOfType<FunctionExpression>();
      final AstNode? closureParent = closure?.parent;
      if (closureParent is! NamedExpression) return;
      if (!_buttonCallbackNames.contains(closureParent.name.label.name)) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// in_app_review_request_in_init_state
// =============================================================================

/// Flags `requestReview()` called inside a `State.initState()` override.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Prompting in `initState` fires on first mount, before the user has engaged,
/// burning the once-a-year quota at the worst moment and violating both store
/// guidelines.
///
/// **BAD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   InAppReview.instance.requestReview();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Trigger after a positive engagement milestone, not on mount.
/// void onTaskCompleted() => InAppReview.instance.requestReview();
/// ```
class InAppReviewRequestInInitStateRule extends SaropaLintRule {
  InAppReviewRequestInInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'requestReview'};

  static const LintCode _code = LintCode(
    'in_app_review_request_in_init_state',
    '[in_app_review_request_in_init_state] requestReview() is called inside a State.initState() override. This fires the review prompt every time the widget first mounts — on cold launch, before the user has engaged — silently consuming the one-per-year quota at the worst possible moment and violating both the Apple and Google Play "prompt after engagement" guidelines. {v1}',
    correctionMessage:
        'Move requestReview() to a post-engagement trigger (after the user completes a meaningful task), not the initState lifecycle method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isInAppReviewCall(node, 'requestReview')) return;
      if (!fileImportsPackage(node, PackageImports.inAppReview)) return;

      final MethodDeclaration? method = node
          .thisOrAncestorOfType<MethodDeclaration>();
      if (method == null || method.name.lexeme != 'initState') return;

      // Resolve the enclosing class's supertype chain rather than bare-matching
      // the name 'State' — eliminates a non-Flutter class with an initState().
      final ClassDeclaration? cls = node
          .thisOrAncestorOfType<ClassDeclaration>();
      final element = cls?.declaredFragment?.element;
      if (element == null) return;
      final bool extendsState = element.allSupertypes.any(
        (t) => t.element.name == 'State',
      );
      if (!extendsState) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// in_app_review_missing_store_listing_fallback
// =============================================================================

/// Flags a class that calls `requestReview()` from a button but never offers an
/// `openStoreListing()` fallback.
///
/// Since: v4.16.0 | Rule version: v1
///
/// When the quota is spent `requestReview()` no-ops; an interactive "rate us"
/// control with no `openStoreListing()` escape hatch leaves the user unable to
/// review. INFO because the fallback is a UX improvement, not a crash.
///
/// **BAD:**
/// ```dart
/// // class with an onPressed -> requestReview() and no openStoreListing anywhere
/// ```
///
/// **GOOD:**
/// ```dart
/// // same class also exposes openStoreListing(appStoreId: ...) as a fallback
/// ```
class InAppReviewMissingStoreListingFallbackRule extends SaropaLintRule {
  InAppReviewMissingStoreListingFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'requestReview'};

  static const LintCode _code = LintCode(
    'in_app_review_missing_store_listing_fallback',
    '[in_app_review_missing_store_listing_fallback] This class wires requestReview() to an interactive control but never calls openStoreListing(). Once the review quota is exhausted requestReview() silently no-ops, so a user tapping "rate this app" has no working path to the store. openStoreListing() has no quota and reliably reaches the review form. Reported at INFO because the fallback is a UX improvement, not a correctness bug; a fallback in a separate service may be a false positive. {v1}',
    correctionMessage:
        'Provide an openStoreListing(appStoreId: ...) fallback for explicit rate buttons so users can still review after the requestReview() quota is spent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.inAppReview)) return;

      final _ReviewScan scan = _ReviewScan();
      node.accept(scan);

      final List<MethodInvocation> requestCalls = scan.invocations
          .where((MethodInvocation inv) => _isInAppReviewCall(inv, 'requestReview'))
          .toList();
      if (requestCalls.isEmpty) return;

      // Only nag when the class also exposes an interactive control — a
      // post-engagement requestReview() with no button needs no fallback.
      if (!scan.hasButtonCallback) return;

      final bool hasOpenStore = scan.invocations.any(
        (MethodInvocation inv) => _isInAppReviewCall(inv, 'openStoreListing'),
      );
      if (hasOpenStore) return;

      for (final MethodInvocation call in requestCalls) {
        reporter.atNode(call);
      }
    });
  }
}

// =============================================================================
// in_app_review_ios_store_listing_missing_app_id
// =============================================================================

/// Flags `openStoreListing()` with no `appStoreId` on a project that targets
/// iOS or macOS.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `appStoreId` is typed `String?` but is required at runtime on Apple
/// platforms (Android resolves the id from the manifest; Apple has no
/// equivalent). Omitting it produces a silent runtime no-op the compiler can't
/// catch.
///
/// **BAD:**
/// ```dart
/// InAppReview.instance.openStoreListing(); // no appStoreId, iOS target
/// ```
///
/// **GOOD:**
/// ```dart
/// InAppReview.instance.openStoreListing(appStoreId: '1234567890');
/// ```
class InAppReviewIosStoreListingMissingAppIdRule extends SaropaLintRule {
  InAppReviewIosStoreListingMissingAppIdRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'openStoreListing'};

  static const LintCode _code = LintCode(
    'in_app_review_ios_store_listing_missing_app_id',
    '[in_app_review_ios_store_listing_missing_app_id] openStoreListing() is called without an appStoreId on a project that targets iOS or macOS. appStoreId is typed String? but is required at runtime on Apple platforms — Android auto-resolves the id from the manifest, Apple has no equivalent — so omitting it produces a silent runtime no-op the compiler cannot catch. {v1}',
    correctionMessage:
        'Pass appStoreId (the 9-10 digit App Store Connect Apple ID), e.g. openStoreListing(appStoreId: "1234567890").',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only relevant for Flutter projects that actually target an Apple
    // platform — the same project-root probe geolocator_rules uses. Eliminates
    // the Android-only false-positive class without guessing.
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;
    final String? root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;
    final bool targetsApple =
        Directory('$root/ios').existsSync() ||
        Directory('$root/macos').existsSync();
    if (!targetsApple) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (!_isInAppReviewCall(node, 'openStoreListing')) return;
      if (!fileImportsPackage(node, PackageImports.inAppReview)) return;

      // Flag when appStoreId is omitted entirely or explicitly null.
      Expression? appStoreId;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'appStoreId') {
          appStoreId = arg.expression;
          break;
        }
      }
      if (appStoreId != null && appStoreId is! NullLiteral) return;

      reporter.atNode(node);
    });
  }
}

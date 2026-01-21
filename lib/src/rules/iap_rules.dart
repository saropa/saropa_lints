// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// In-App Purchase lint rules for Flutter applications.
///
/// These rules help ensure proper IAP implementation including sandbox/production
/// environment handling, subscription status checking, and price localization.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../mode_constants_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// avoid_purchase_in_sandbox_production
// =============================================================================

/// Warns when sandbox/production environment handling may be incorrect.
///
/// Alias: iap_environment, sandbox_production_mismatch
///
/// Sandbox purchases in production or vice versa fail validation. Use correct
/// environment configuration and verify receipts against the right server.
///
/// **BAD:**
/// ```dart
/// // Hardcoded sandbox URL in production code
/// final response = await http.post(
///   Uri.parse('https://sandbox.itunes.apple.com/verifyReceipt'),
///   body: receiptData,
/// );
///
/// // No environment check for purchases
/// await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
/// ```
///
/// **GOOD:**
/// ```dart
/// final verifyUrl = kReleaseMode
///     ? 'https://buy.itunes.apple.com/verifyReceipt'
///     : 'https://sandbox.itunes.apple.com/verifyReceipt';
///
/// // Or use RevenueCat/other SDK that handles this automatically
/// await Purchases.purchaseProduct(productId);
/// ```
class AvoidPurchaseInSandboxProductionRule extends SaropaLintRule {
  const AvoidPurchaseInSandboxProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_purchase_in_sandbox_production',
    problemMessage: '[avoid_purchase_in_sandbox_production] Hardcoded IAP environment URL '
        'detected. Sandbox receipts fail in production and vice versa.',
    correctionMessage: 'Use kReleaseMode or kDebugMode to select the correct verification URL.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for hardcoded Apple sandbox/production URLs
      final String nodeSource = node.toSource();

      if (nodeSource.contains('sandbox.itunes.apple.com') ||
          nodeSource.contains('buy.itunes.apple.com')) {
        // Check if there's environment checking nearby
        AstNode? functionBody;
        AstNode? current = node.parent;

        while (current != null) {
          if (current is FunctionBody) {
            functionBody = current;
            break;
          }
          current = current.parent;
        }

        if (functionBody != null) {
          final String bodySource = functionBody.toSource();
          // If there's environment checking, it's likely handled correctly
          if (usesFlutterModeConstants(bodySource) ||
              bodySource.contains('Environment.') ||
              bodySource.contains('isProduction') ||
              bodySource.contains('isSandbox')) {
            return;
          }
        }

        reporter.atNode(node, code);
      }
    });

    // Also check for string literals with these URLs
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.contains('sandbox.itunes.apple.com') || value.contains('buy.itunes.apple.com')) {
        // Check context for environment handling
        AstNode? functionBody;
        AstNode? current = node.parent;

        while (current != null) {
          if (current is FunctionBody) {
            functionBody = current;
            break;
          }
          if (current is ConditionalExpression) {
            // Already in a conditional, likely handled
            return;
          }
          current = current.parent;
        }

        if (functionBody != null) {
          final String bodySource = functionBody.toSource();
          if (!usesFlutterModeConstants(bodySource) &&
              !bodySource.contains('isProduction') &&
              !bodySource.contains('isSandbox')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// require_subscription_status_check
// =============================================================================

/// Warns when subscription features are accessed without status verification.
///
/// Alias: check_subscription, verify_subscription_status
///
/// Subscriptions can be cancelled, refunded, or expired. Check status on app
/// launch, not just after purchase. Users may have cancelled via App Store.
///
/// Detection uses word boundary matching to avoid false positives. For example,
/// `isProportional` will NOT trigger this rule even though it contains `isPro`
/// as a substring.
///
/// **BAD:**
/// ```dart
/// // Only checking once after purchase
/// class PremiumFeature extends StatelessWidget {
///   Widget build(context) {
///     // Just assuming subscription is still valid
///     return PremiumContent();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class PremiumFeature extends StatelessWidget {
///   Widget build(context) {
///     return FutureBuilder<bool>(
///       future: SubscriptionService.checkStatus(),
///       builder: (context, snapshot) {
///         if (snapshot.data == true) return PremiumContent();
///         return UpgradePrompt();
///       },
///     );
///   }
/// }
/// ```
class RequireSubscriptionStatusCheckRule extends SaropaLintRule {
  const RequireSubscriptionStatusCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_subscription_status_check',
    problemMessage: '[require_subscription_status_check] Premium/subscription content '
        'displayed without status verification. Subscription may have expired.',
    correctionMessage: 'Check subscription status before showing premium content. Use RevenueCat '
        'or InAppPurchase.instance.purchaseStream to verify entitlements.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Keywords that suggest premium/subscription-gated content
  static const Set<String> _premiumIndicators = <String>{
    'premium',
    'pro',
    'subscription',
    'subscribed',
    'isPremium',
    'is_premium',
    'isPro',
    'is_pro',
    'hasSubscription',
    'has_subscription',
    'isSubscribed',
    'is_subscribed',
    'entitlement',
    'unlocked',
    'purchased',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check if build method references premium features
      // Use word boundary regex to avoid false positives
      // (e.g., "isProportional" should not match "isPro")
      bool hasPremiumReference = false;
      for (final String indicator in _premiumIndicators) {
        final RegExp pattern = RegExp(
          r'\b' + RegExp.escape(indicator) + r'\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(bodySource)) {
          hasPremiumReference = true;
          break;
        }
      }

      if (!hasPremiumReference) return;

      // Check if there's a status check
      if (bodySource.contains('FutureBuilder') ||
          bodySource.contains('StreamBuilder') ||
          bodySource.contains('checkStatus') ||
          bodySource.contains('checkSubscription') ||
          bodySource.contains('verifyPurchase') ||
          bodySource.contains('getEntitlements') ||
          bodySource.contains('customerInfo') ||
          bodySource.contains('purchaseStream') ||
          bodySource.contains('Consumer<') ||
          bodySource.contains('BlocBuilder') ||
          bodySource.contains('watch(') ||
          bodySource.contains('ref.watch')) {
        return; // Has proper subscription checking
      }

      // TODO: Add quick fix support when custom_lint supports it for this rule type.
      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// require_price_localization
// =============================================================================

/// Warns when hardcoded prices are used instead of store-provided prices.
///
/// Alias: localize_price, store_price
///
/// Show prices from store (with currency) not hardcoded. $4.99 in US might be
/// €5.49 in EU. Use productDetails.price for correct localized formatting.
///
/// **BAD:**
/// ```dart
/// Text('Only \$4.99/month!')
/// Text('Price: \$9.99')
/// ```
///
/// **GOOD:**
/// ```dart
/// Text('Only ${productDetails.price}/month!')
/// Text('Price: ${product.priceString}')
/// ```
class RequirePriceLocalizationRule extends SaropaLintRule {
  const RequirePriceLocalizationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_price_localization',
    problemMessage: '[require_price_localization] Hardcoded price detected. Prices vary by '
        'region and currency. Users may see incorrect amounts.',
    correctionMessage: 'Use productDetails.price or priceString from the store SDK.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Pattern to match hardcoded prices like $4.99, €9.99, £19.99
  static final RegExp _pricePattern = RegExp(
    r'[\$€£¥₹]\s*\d+[.,]\d{2}',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check for hardcoded price patterns
      if (_pricePattern.hasMatch(value)) {
        // Check context to see if this is in a UI context
        AstNode? current = node.parent;
        bool isInUiContext = false;

        while (current != null) {
          if (current is InstanceCreationExpression) {
            final String typeName = current.constructorName.type.name.lexeme;
            if (typeName == 'Text' || typeName == 'RichText' || typeName == 'TextSpan') {
              isInUiContext = true;
              break;
            }
          }
          if (current is MethodDeclaration && current.name.lexeme == 'build') {
            isInUiContext = true;
            break;
          }
          current = current.parent;
        }

        if (isInUiContext) {
          reporter.atNode(node, code);
        }
      }
    });

    // Also check string interpolations
    context.registry.addStringInterpolation((StringInterpolation node) {
      final String fullString = node.toSource();

      if (_pricePattern.hasMatch(fullString)) {
        // Check if it's in a UI context
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodDeclaration && current.name.lexeme == 'build') {
            reporter.atNode(node, code);
            return;
          }
          current = current.parent;
        }
      }
    });
  }
}

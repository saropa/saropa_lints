# Task: `avoid_entitlement_without_server`

## Summary
- **Rule Name**: `avoid_entitlement_without_server`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.16 Payment & In-App Purchase Rules
- **OWASP**: M1: Improper Credential Usage / M4: Insufficient Input/Output Validation

## Problem Statement

In-app purchase entitlements (subscription status, purchased content) must be verified server-side. Client-side verification uses Apple/Google receipts that can be:
1. **Manipulated** on jailbroken/rooted devices (tools like Freedom can fake purchase responses)
2. **Replayed** from another device or account
3. **Bypassed** by runtime manipulation

The correct pattern is:
1. Client receives a purchase receipt/token from App Store/Play Store
2. Client sends the receipt to YOUR server
3. Server verifies the receipt with Apple/Google's verification API
4. Server grants/revokes entitlement in its database
5. Client checks entitlement status from your server (not from the purchase SDK)

Apps that check `purchaseDetails.status == PurchaseStatus.purchased` directly in Flutter code and unlock features are vulnerable.

## Description (from ROADMAP)

> Client-side entitlement checks can be bypassed. Verify subscription status server-side for valuable content.

## Trigger Conditions

1. Direct access to `PurchaseDetails.status` (from `in_app_purchase` package) used to gate feature access
2. `purchaseDetails.status == PurchaseStatus.purchased` used in `if` condition that unlocks premium features
3. No server verification endpoint visible in the code

## Implementation Approach

### Package Detection
Only fire if `ProjectContext.usesPackage('in_app_purchase')` or `ProjectContext.usesPackage('purchases_flutter')` (RevenueCat).

### AST Visitor Pattern

```dart
context.registry.addBinaryExpression((node) {
  if (!_isPurchaseStatusCheck(node)) return;
  // Check if this status check is directly unlocking content
  if (!_isInsideFeatureGate(node)) return;
  reporter.atNode(node, code);
});
```

`_isPurchaseStatusCheck`: detect `purchaseDetails.status == PurchaseStatus.purchased`, `purchaseDetails.pendingCompletePurchase`, etc.
`_isInsideFeatureGate`: check if the comparison result is used in an `if` condition that calls a feature-unlock method (setter, navigation, visibility toggle).

### RevenueCat Exception
RevenueCat performs its own server-side validation. Detect usage:
- `Purchases.getCustomerInfo()` - this IS a server-verified entitlement check
- Suppress when `CustomerInfo.entitlements.active` is used (RevenueCat already validates server-side)

## Code Examples

### Bad (Should trigger)
```dart
// Direct client-side entitlement check
void _handlePurchase(PurchaseDetails purchase) {
  if (purchase.status == PurchaseStatus.purchased) {  // ← trigger
    _unlockPremiumContent();  // no server verification
  }
}

// Checking subscription status from SharedPreferences (client-stored)
if (prefs.getBool('is_premium') == true) {  // ← trigger if set from client purchase
  showPremiumContent();
}
```

### Good (Should NOT trigger)
```dart
// Server-side verification ✓
void _handlePurchase(PurchaseDetails purchase) async {
  if (purchase.status == PurchaseStatus.purchased) {
    // Send to server for verification
    final isValid = await serverApi.verifyPurchase(
      receipt: purchase.verificationData.serverVerificationData,
      productId: purchase.productID,
    );
    if (isValid) {
      _unlockPremiumContent();  // only after server confirms
    }
  }
}

// Using RevenueCat (server-verified) ✓
final customerInfo = await Purchases.getCustomerInfo();
if (customerInfo.entitlements.active.containsKey('premium')) {
  showPremiumContent();
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| RevenueCat `customerInfo.entitlements` check | **Suppress** — RevenueCat is server-verified | `Purchases.getCustomerInfo()` = server call |
| Using `PurchaseStatus.purchased` for analytics/logging (not feature gate) | **Suppress** — not gating access | Check what happens inside the `if` |
| `PurchaseStatus.error` handling (not feature unlock) | **Suppress** — error handling is fine | Check status value |
| `PurchaseStatus.pending` | **Suppress** — pending is not a grant | |
| Test file with mock purchases | **Suppress** | |
| Free content (no actual entitlement needed) | **False positive** — developer may be checking for analytics only | Hard to know intent |
| Purchase verification done in calling code | **False positive** — verification may happen elsewhere | Known limitation of Phase 1 |

## Unit Tests

### Violations
1. `if (purchase.status == PurchaseStatus.purchased) { _unlockFeature(); }` → 1 lint
2. Status check directly controlling `Navigator.push` to premium screen → 1 lint

### Non-Violations
1. Same check followed by `await serverApi.verify(...)` call → no lint
2. `customerInfo.entitlements.active` (RevenueCat) → no lint
3. Status check used only for logging → no lint
4. Test file → no lint

## Quick Fix

No automated fix — server verification setup is architectural.

```
correctionMessage: 'Verify purchase receipts server-side using Apple/Google verification APIs. Client-side entitlement checks can be bypassed on rooted/jailbroken devices.'
```

## Notes & Issues

1. **HIGH impact security rule** — bypassed entitlements are a direct revenue loss. Consider escalating to ERROR for Essential tier.
2. **RevenueCat** is the most popular IAP abstraction library and performs server-side verification. Detecting its usage and suppressing accordingly is critical to avoid false positives.
3. **`PurchaseStatus.purchased`** is the primary target. `purchaseDetails.pendingCompletePurchase` is also important — pending purchases must also be server-verified before granting entitlements.
4. **The "feature gate" detection** is the hardest part — knowing that an `if` block "unlocks premium content" requires understanding the domain logic. In Phase 1, any `if` on `PurchaseStatus.purchased` should trigger the warning.
